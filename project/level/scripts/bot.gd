class_name Bot
extends Node

@export var player_scene: PackedScene

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

func _init(state: GameStateServer, nick: String = "Bot", position: Vector3 = Vector3.ZERO):
	id = _bot_next_id
	_bot_next_id += 1
	skin = "red"
	self.game_state = state
	self.nickname = nick
	self.name = nick
	self.spawn_position = position

func _ready():
	self.ollama = OllamaApi.new()
	if self.system_prompt and !self.system_prompt.is_empty():
		self.ollama.system_prompt = self.system_prompt
	add_child(self.ollama)
	pass

func _process(delta):
	var result = find_player_by_distance(10)
	if result.is_empty() or !ollama.is_ready():
		if !self.selected_player.is_empty():
			self.selected_player = ""
			self.game_state.rpc("sync_player_look_at", 1, self.nickname, self.player.global_position + Vector3(0, 0, 1))
	else:
		self.selected_player = result[0]
		var ts = Time.get_ticks_msec()
		if ts - selected_player_updated > 500:
			var dir_to_target = (result[1].global_position - self.player.global_position).normalized()
			var dir_to_target_xz = Vector3(dir_to_target.x, 0, dir_to_target.z).normalized()
			var look_at = self.player.global_position + dir_to_target_xz
			self.game_state.rpc("sync_player_look_at", 1, self.nickname, look_at)
			selected_player_updated = ts
		
func _logS(msg: String):
	print(TAG + ": " + msg)

func find_player_by_distance(max_dist: float) -> Array:
	for p in game_state.players.values():
		var distance = self.player.global_position.distance_to(p.character.global_position)
		if distance <= max_dist and !is_player_selected_by_any(p.nickname):
			return [p.nickname, p.character]
	return []
	
func is_player_selected_by_any(nickname: String) -> bool:
	for b in game_state.bots.values():
		if b != self and  b.selected_player == nickname:
			return true
	return false

func create_player(container : Node3D):
	self.player = player_scene.instantiate()
	self.player.name = self.name
	self.player.position = spawn_position
	#players_container.add_child(player, true)	
	#self.add_child(player, true)
	container.add_child(self.player, true)
	self.player.rpc("change_nick", name)
	
func on_message(nickname: String, message: String):
	if nickname == self.nickname:
		return
		
	if nickname != self.selected_player:
		return

	if !ollama.is_ready():
		_logS("ollama is not ready yet.")
		return

	if message.begins_with("/"):
		process_command(message.substr(1, message.length() - 1), nickname)
		return

	if nickname in messages.keys():
		messages[nickname].append(message)
	else:
		messages[nickname] = [message]

	ollama.chat(messages[nickname], func (result):
		var response : OllamaApi.ChatResponse = result
		messages[nickname].append(response.message)
		self.game_state.rpc("msg_rpc", self.nickname, response.message.content)
		pass
	)

func process_command(command: String, peer_nickname: String):
	command = command.strip_edges().to_lower()
	var args = command.split(" ")

	if args.size() == 0:
		return
	
	match args[0]:
		"help":
			game_state.rpc("msg_rpc", self.nickname, "Available commands: help, clear_memory, model, system_prompt")
		"system_prompt":
			if args.size() > 1:
				var prompt = " ".join(args.slice(1, args.size()))
				ollama.system_prompt = prompt
				game_state.rpc("msg_rpc", self.nickname, "System prompt set to: " + prompt)
			else:
				game_state.rpc("msg_rpc", self.nickname, "Current system prompt: " + self.ollama.system_prompt)
		"model":
			if args.size() > 1:
				var model_name = args[1]
				ollama.model = model_name
				ollama._pull_models()
			else:
				game_state.rpc("msg_rpc", self.nickname, "Current model: " + self.ollama.model)		
		"clear_memory":
			messages[peer_nickname].clear()
			game_state.rpc("msg_rpc", self.nickname, "Chat cleared.")

		_:
			game_state.rpc("msg_rpc", self.nickname, "Unknown command: " + command)
	
