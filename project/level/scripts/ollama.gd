class_name OllamaApi
extends Node

const DEFAULT_MODEL = "llama3.1:8b"
#const DEFAULT_MODEL = "gemma3:4b"
const DEFAULT_API_SITE = "http://localhost:11434/api"

var TAG = "ollama"

@export var model = DEFAULT_MODEL
@export var system_prompt = "you are an internet troll chatting on internet. Keep responses short and concise"

var http_debug_log = true

enum InitState {
	INIT,
	LOADING,
	READY,
	ERROR
}

enum ChatRole {
	USER,
	SYSTEM,
	ASSISTANT,
	TOOL
}

class OllamaApiResponse:
	var error: int
	var response_code: int

class ListResponse extends OllamaApiResponse:
	var models: Array

# To calculate how fast the response is generated in tokens per second (token/s), 
# divide eval_count / eval_duration * 10^9.
class GenerateResponse extends OllamaApiResponse:
	var created_at: String
	var model: String
	var response : String
	var done: bool
	var context: Array	
	var total_duration: int
	var load_duration: int
	var prompt_eval_count: int
	var prompt_eval_duration: int
	var eval_count: int
	var eval_duration: int

class ChatResponse extends OllamaApiResponse:
	var created_at: String
	var model: String
	var message : Dictionary
	var done: bool
	var total_duration: int
	var load_duration: int
	var prompt_eval_count: int
	var prompt_eval_duration: int
	var eval_count: int
	var eval_duration: int

class Model:
	var name: String
	var modified_at: String
	var size: int
	var digest: String
	var details: Dictionary

func _logS(msg: String):
	print(TAG + ": " + msg)

var requests: HttpApiRequest
var state: InitState = InitState.INIT

#region Node
# Called when the node enters the scene tree for the first time.
func _ready():
	requests = HttpApiRequest.new()
	add_child(requests)

	# Parse command line arguments
	var args = OS.get_cmdline_args()
	var parsed_args = _parse_cli_args(args)
	if parsed_args.has("model"):
		model = parsed_args["model"]
		_logS("Model: " + model)
	else:
		_logS("No model specified, using default: " + DEFAULT_MODEL)

	if parsed_args.has("debug_log"):
		http_debug_log = str(parsed_args["debug_log"]).to_lower() == "true"
	_logS("Debug log: " + str(http_debug_log))

	_prepare_models()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#endregion

#region Ollama API
func list_models(result_cb: Callable):
	var cb = func(body: Dictionary):
		var cb_response : ListResponse = ListResponse.new()
		var error = body.error
		var response_code = body.response_code

		cb_response.error = error
		cb_response.response_code = response_code
		
		if response_code == 0 or error == 0:
			cb_response.models = body["models"] if body.has("models") else ""
			for i in range(len(cb_response.models)):
				var model = Model.new()
				fill_properties(model, cb_response.models[i])
				cb_response.models[i] = model
		
		result_cb.call(cb_response)	
					
	requests.process_request(cb, DEFAULT_API_SITE + "/tags", {
		"method" : HTTPClient.METHOD_GET,
		"debug_log" : self.http_debug_log,
	})	

func pull_model(model_to_pull: String, result_cb: Callable):
	var cb = func(body: Dictionary):
		var cb_response : OllamaApiResponse = OllamaApiResponse.new()
		var error = body.error
		var response_code = body.response_code

		cb_response.error = error
		cb_response.response_code = response_code
		result_cb.call(cb_response)	
					
	requests.process_request(cb, DEFAULT_API_SITE + "/pull", {
		"data" : {
			"model" : model_to_pull,
			"stream" : false
		},
		"method" : HTTPClient.METHOD_POST,
		"debug_log" : self.http_debug_log,
	})	


func generate(prompt: String, result_cb: Callable):
	var cb = func(body: Dictionary):
		var cb_response : GenerateResponse = GenerateResponse.new()
		var error = body.error
		var response_code = body.response_code

		cb_response.error = error
		cb_response.response_code = response_code
		
		if response_code != 200 or error != 0:
			_logS("Error: " + str(error) + " response code: " + str(response_code))
		else:			
			fill_properties(cb_response, body)
	
		result_cb.call(cb_response)
		pass
		
	requests.process_request(cb, DEFAULT_API_SITE + "/generate", {
		"data" : {
			"model" : self.model,
			"prompt" : prompt,
			"stream" : false,
			"system" : self.system_prompt
		},
		"method" : HTTPClient.METHOD_POST,
		"debug_log" : self.http_debug_log,
	})
			
func chat(messages: Array, result_cb: Callable, tools: Array = []):
	var cb = func(body: Dictionary):
		var cb_response : ChatResponse = ChatResponse.new()
		var error = body.error
		var response_code = body.response_code

		cb_response.error = error
		cb_response.response_code = response_code
		
		if response_code != 200 or error != 0:
			_logS("Error: " + str(error) + " response code: " + str(response_code))
		else:			
			fill_properties(cb_response, body)
	
		result_cb.call(cb_response)
		pass

	var msg_list = _prepare_message_list(messages)

	requests.process_request(cb, DEFAULT_API_SITE + "/chat", {
		"data" : {
			"model" : self.model,
			"messages" : msg_list,
			"tools" : tools,
			"stream" : false,
		},
		"method" : HTTPClient.METHOD_POST,
		"debug_log" : self.http_debug_log,
	})

#endregion

#region Public methods
func is_ready() -> bool:
	return self.state == InitState.READY
#endregion

#region Helpers
func _parse_cli_args(args: Array) -> Dictionary:
	var parsed_args = {}
	for i in range(args.size()):
		if args[i].find("=") != -1:
			var key_value = args[i].split("=")
			if key_value.size() == 2:
				parsed_args[key_value[0]] = key_value[1]
		else:
			parsed_args[args[i]] = true
	return parsed_args

func _prepare_models():
	list_models(func (result):
		_logS("local models: ")
		for m in result.models:
			if m.name == model:
				state = InitState.READY
				_logS("selected model: " + m.name)
				_test_model()
				return
			_logS(m.name)

		_pull_models()
		pass
		)
	
func _pull_models():
	self.state = InitState.LOADING
	pull_model(model, func (result):
		if result.error == 0 and result.response_code == 200:
			_logS("Model downloaded!")
			self.state = InitState.READY
			_test_model()
		else:
			self.state = InitState.ERROR
			_logS("Error occured when pulling the model: " + str(result.error))
		pass
	)
	pass

func _test_model():
	generate("Why is the sky blue?", func (result):
		_logS("response: " + result.response)
		var speed = result.eval_count *  1e9 / result.eval_duration
		_logS("speed: " + str(speed) + " tokens/s")
		_logS("model: " + result.model)
		pass
		)
		
func fill_properties(obj: Object, item: Dictionary):
	var prop_list = obj.get_property_list()
	var prop_map = {}
	for p in prop_list:
		if item.has(p.name):
			prop_map[p.name] = p
		
	for k in item:
		if prop_map.has(k):
			#print("has property "+k)
			obj.set(k, item[k])
	
	obj.set_meta("item", item)
	pass
	
func _prepare_message_list(messages: Array) -> Array:
	var msg_list = []

	msg_list.append({
		"role": "system",
		"content": self.system_prompt
	})

	for i in range(messages.size()):
		var msg = messages[i]
		if msg is String:
			msg_list.append({
				"role": "user",
				"content": msg
			})
		elif msg is Dictionary:
			if msg.has("content"):
				msg_list.append({
					"role": msg["role"] if msg.has("role") else "user",
					"content": msg["content"]
				})
		else:
			_logS("Invalid message type: " + str(msg))
			continue
	return msg_list
#endregion
