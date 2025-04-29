extends Node

class_name HttpApiRequest

@export var DEFAULT_HTTP_REQUEST_SITE: String = ""
@export var DEFAULT_HTTP_HEADERS: Array[String] = []
@export var REQUEST_HISTORY_SIZE: int = 10
@export var DebugLog: bool = false

signal http_error_signal(error:Error, message:String)

const METHOD_STRING = ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"]

var TAG = "HttpApiRequest"

class RequestInfo:
	var api_path: String
	var method: HTTPClient.Method
	var result: HTTPRequest.Result
	var response_code: int
	var response_headers: PackedStringArray
	var body: PackedByteArray
	var time_started: String
	var time_completed: String
	var duration_ms: int

var request_history: Array[RequestInfo]

class HttpHeaderParser:
	var values: Dictionary
	var content_type: String
	var charset: String
	var boundary: String

	func _init(packed_string_array: PackedStringArray):
		_parse_values(packed_string_array)

	func _convert_to_dictionary(packed_string_array: PackedStringArray) -> Dictionary:
		var result = Dictionary()

		for item in packed_string_array:
			if item.contains(":"):
				var key = item.get_slice(":", 0).strip_edges()  # Remove any whitespace around the key
				var value = item.get_slice(":", 1).strip_edges()  # Remove any whitespace around the value
				result[key] = value
			else:
				print("Invalid format for item: ", item)

		return result

	func _parse_values(packed_string_array: PackedStringArray):
		self.values = _convert_to_dictionary(packed_string_array)
		for key in self.values:
			if key == "Content-Type":
				var lines = self.values[key].split(";")
				for line:String in lines:
					var stripped = line.strip_edges()
					if stripped.begins_with("charset"):
						self.charset = line.split("=")[1].strip_edges()
					elif stripped.begins_with("boundary"):
						self.boundary = line.split("=")[1].strip_edges()
					else:
						self.content_type = stripped
		pass

# Called when the node enters the scene tree for the first time.
#func _ready():
	#pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
	#pass

func _logS(msg: String):
	if DebugLog:
		print(TAG + ": " + msg)

func _check_error(result, response_code) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		var err_str = "Request failed with result=" + str(result) + " response_code=" + str(response_code)
		http_error_signal.emit(FAILED, err_str)
		push_error(err_str)
		return true
	return false



func has_active_requests():
	return get_child_count() > 0
	
## Sends http request to the server
## Settings dictionary:
## 	custom_headers: Array of strings
## 	method: HTTPClient.Method
## 	data: Dictionary
## 	default_headers: bool
## 	debug_log: bool
func process_request(
		user_callback: Callable,
		api_path: String = "", 
		settings: Dictionary = {}):
			
	# user_callback.call({"error": 1, "response_code":2})
	# return null

	var request = HTTPRequest.new()
	add_child(request)

	var all_settings = {
		"custom_headers": PackedStringArray(),
		"method": HTTPClient.METHOD_GET,
		"data": {},
		"default_headers": true,
		"debug_log": false
	}
	all_settings.merge(settings, true)

	DebugLog = all_settings["debug_log"]

	var method: HTTPClient.Method = all_settings["method"]

	var request_info : RequestInfo = RequestInfo.new()
	if request_history.size() >= REQUEST_HISTORY_SIZE:
		request_history.pop_front()
	request_history.append(request_info)
	request_info.api_path = api_path
	request_info.method = all_settings["method"]
	request_info.time_started = Time.get_datetime_string_from_system()
	var time_start = Time.get_ticks_msec()
	
	var on_completed = func request_complete(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray):
		request_info.time_completed = Time.get_datetime_string_from_system()
		request_info.duration_ms = Time.get_ticks_msec() - time_start
		request_info.result = result as HTTPRequest.Result
		request_info.response_code = response_code
		request_info.response_headers = response_headers
		request_info.body = body
		
		remove_child(request)
		
		if _check_error(result, response_code):
			user_callback.call({"error": result, "response_code": response_code})
			return
		
		_logS("response code: " + str(response_code))
		
		if body:
			var http_headers: HttpHeaderParser = HttpHeaderParser.new(response_headers)

			var content_type = http_headers.content_type # headers_kv.get("Content-Type")
			match content_type:
				"text/json", "application/json":
					var json = JSON.parse_string(body.get_string_from_utf8())
					var status = json.get("status")
					if status && status != "success":
						_logS("http error occured! status: %s message: %s"%[json.status, json.message])
					#print(JSON.stringify(json), "\t")
					json["error"] = 0
					json["response_code"] = response_code
					user_callback.call(json)
				"text/plain":
					var text = body.get_string_from_utf8()
					user_callback.call({
						"error":0,
						"response_code":0,
						"data":text
						})
		pass
	
	request.request_completed.connect(on_completed)
	var path : String = api_path
	if !DEFAULT_HTTP_REQUEST_SITE.is_empty():		
		path = DEFAULT_HTTP_REQUEST_SITE + "/" + api_path 
	var headers : Array[String] = []
	
	if (api_path.begins_with("http")):
		path = api_path
	
	if all_settings["default_headers"]:
		if all_settings["data"].size() > 0:
			headers.append("Content-Type: application/json")
		if !DEFAULT_HTTP_HEADERS.is_empty():
			headers.append_array(DEFAULT_HTTP_HEADERS)
		#if method == HTTPClient.METHOD_POST:
		#headers.append("Content-Type: application/json")
		
	headers.append_array(all_settings["custom_headers"])
	var data_to_send = JSON.stringify(all_settings["data"])
	
	_logS("process_request: %s path: %s data: %s"%[METHOD_STRING[method], path, data_to_send])
	var error = request.request(path, headers, method, data_to_send)
	if error != OK:
		http_error_signal.emit(error, "An error occurred in the HTTP request. Error: " + str(error))
		push_error("An error occurred in the HTTP request. Error: " + str(error))
		user_callback.call({"error": error, "response_code": 0})
	return request	
