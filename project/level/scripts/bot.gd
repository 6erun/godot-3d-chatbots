class_name Bot
extends Node

@export var player_scene: PackedScene

const MAX_INTERACTION_DISTANCE = 10

var ollama : OllamaApi
var _bot_next_id : int = 10

var id : int
var skin : String
var spawn_position : Vector3
var player : Character
var nickname : String
var system_prompt : String

var game_state : GameStateServer
var messages = {}

var TAG = "Bot"

var selected_player : String
var selected_player_updated : int = 0

var ollama_tools = []

enum BotState {
	INIT,
	WAITING,
	TALKING,
	ERROR
}

var bot_state : BotState = BotState.INIT

func _init(state: GameStateServer, nick: String = "Bot", position: Vector3 = Vector3.ZERO):
	id = _bot_next_id
	_bot_next_id += 1
	skin = "red"
	self.game_state = state
	self.nickname = nick
	self.name = nick
	self.spawn_position = position

func _ready():
	var tool1 = {
		'type': 'function',
		'function': {
			'name': 'subtract_two_numbers',
			'description': 'Subtract two numbers',
			'parameters': {
			'type': 'object',
			'required': ['a', 'b'],
			'properties': {
				'a': {'type': 'integer', 'description': 'The first number'},
				'b': {'type': 'integer', 'description': 'The second number'},
			},
			},
		},
	}
	var tool2 = {
		'type': 'function',
		'function': {
			'name': 'move_forward',
			'description': 'Move forward by a certain distance',
			'parameters': {
			'type': 'object',
			'required': ['a'],
			'properties': {
				'a': {'type': 'integer', 'description': 'The distance to move forward'},
			},
			},
		},
	}
	self.ollama_tools.append_array([tool1, tool2])

	self.ollama = OllamaApi.new()
	if self.system_prompt and !self.system_prompt.is_empty():
		self.ollama.system_prompt = self.system_prompt
	add_child(self.ollama)
	pass

func _process(_delta):
	var result = _find_player_by_distance(MAX_INTERACTION_DISTANCE)
	if result.is_empty() or !ollama.is_ready():
		if !self.selected_player.is_empty():
			self.selected_player = ""
	else:
		self.selected_player = result[0]
		var ts = Time.get_ticks_msec()
		if ts - selected_player_updated > 500:
			var look_at = result[1].global_position
			look_at.y = self.player.global_position.y
			player.set_look_at_point(look_at)
			selected_player_updated = ts

	var prev_state = bot_state		
	if ollama.is_ready():
		if self.selected_player.is_empty():
			bot_state = BotState.WAITING
		else:
			bot_state = BotState.TALKING
	else:
		if ollama.state == OllamaApi.InitState.ERROR:
			bot_state = BotState.ERROR
		else:
			bot_state = BotState.INIT
	if prev_state != bot_state:
		_update_nick()

func _logS(msg: String):
	var prefix = TAG if self.nickname.is_empty() else TAG + " " + self.nickname
	print(prefix + ": " + msg)

func sync_info(peer_id: int):
	self.game_state.rpc_id(peer_id, "sync_player_skin", 1, self.name, self.skin)
	self.game_state.rpc_id(peer_id, "sync_player_position", 1, self.nickname, self.player.position)
	self.player.rpc_id(peer_id, "change_nick", _get_nick_text())

func _update_nick():
	self.player.rpc("change_nick", _get_nick_text())

func _get_nick_text() -> String:
	match self.bot_state:
		BotState.INIT:
			return self.nickname + "\nInitializing..."
		BotState.WAITING:
			return self.nickname + "\nwaiting for a player"
		BotState.TALKING:
			return self.nickname + "\ntalking to " + self.selected_player
		BotState.ERROR:
			return self.nickname + "\nhas an error!"

	return self.nickname

func _find_player_by_distance(max_dist: float) -> Array:
	for p in game_state.players.values():
		var distance = self.player.global_position.distance_to(p.character.global_position)
		if distance <= max_dist and !_is_player_selected_by_any(p.nickname):
			return [p.nickname, p.character]
	return []
	
func _is_player_selected_by_any(nick: String) -> bool:
	for b in game_state.bots.values():
		if b != self and  b.selected_player == nick:
			return true
	return false

func create_player(container : Node3D):
	self.player = player_scene.instantiate()
	self.player.name = self.name
	self.player.position = spawn_position
	#players_container.add_child(player, true)	
	#self.add_child(player, true)
	container.add_child(self.player, true)
	_update_nick()
	
func on_message(nick: String, message: String):
	if nick == self.nickname:
		return
		
	if nick != self.selected_player:
		return

	if !ollama.is_ready():
		_logS("ollama is not ready yet.")
		return

	var peer_id = game_state.multiplayer.get_remote_sender_id()
	_logS("on_message: " + nick + "(" + str(peer_id) + "): " + message)

	if message.begins_with("/"):
		_process_command(message.substr(1, message.length() - 1), nick, peer_id)
		return

	_chat_ollama(nick, message)

func _chat_ollama(nick: String, message: Variant):
	if nick in messages.keys():
		messages[nick].append(message)
	else:
		messages[nick] = [message]

	var handler = func (result):
		var response : OllamaApi.ChatResponse = result
		messages[nick].append(response.message)
		if response.message.has("tool_calls"):
			_process_function_call(nick, response.message.tool_calls)
		else:
			_send_response(response.message.content)
		pass

	ollama.chat(messages[nick], handler, ollama_tools)	

func _send_response(message: String, peer_id: int = 0):
	_logS("response: " + message)
	if peer_id > 1:
		self.game_state.rpc_id(peer_id, "msg_rpc", self.nickname, message)
	else:
		self.game_state.rpc("msg_rpc", self.nickname, message)

func _process_function_call(nick: String, calls: Array):
	for f in calls:
		_logS("function " + f.function.name + " args: " + str(f.function.arguments))
		match f.function.name:
			"subtract_two_numbers":
				var result = subtract_two_numbers(f.function.arguments)
				_chat_ollama(nick, {
					"role": "tool",
					"name": f.function.name,
					"content" : result
				})
			"move_forward":
				var result = move_forward(f.function.arguments)
				_chat_ollama(nick, {
					"role": "tool",
					"name": f.function.name,
					"content" : result
				})
			_:
				_logS("Unknown function call: " + f.function.name)
			
	pass

func _process_command(command: String, peer_nickname: String, peer_id: int):
	command = command.strip_edges().to_lower()
	var args = command.split(" ")

	if args.size() == 0:
		return
	
	match args[0]:
		"help":
			_send_response("Available commands: help, clear_memory, model, system_prompt", peer_id)
		"system_prompt":
			if args.size() > 1:
				var prompt = " ".join(args.slice(1, args.size()))
				ollama.system_prompt = prompt
				_send_response("System prompt set to: " + prompt, peer_id)
			else:
				_send_response("Current system prompt: " + self.ollama.system_prompt, peer_id)
		"model":
			if args.size() > 1:
				var model_name = args[1]
				ollama.model = model_name
				ollama._pull_models()
			else:
				_send_response("Current model: " + self.ollama.model, peer_id)
		"clear_memory":
			messages[peer_nickname].clear()
			_send_response("Chat cleared.", peer_id)

		_:
			_send_response("Unknown command: " + command, peer_id)
	
func subtract_two_numbers(args: Dictionary):
	if args.has("a") and args.has("b"):
		var a = args["a"]
		var b = args["b"]
		var result = a - b
		return str(result)
	else:
		return "Invalid arguments"

func move_forward(args: Dictionary) -> String:
	if args.has("a"):
		var distance = args["a"]
		self.player.move_forward(float(distance))
		return "ok"
	else:
		return "Invalid arguments"
