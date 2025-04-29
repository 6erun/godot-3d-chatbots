extends Node3D

# multiplayer chat
@onready var chat: TextEdit = $MultiplayerChat/Container/Chat
@onready var multiplayer_chat: Control = $MultiplayerChat

var TAG = "Game"
var game_state: GameState

func _logS(msg: String):
	print(TAG + ": " + msg)

func _ready():
	#multiplayer_chat.hide()
	#if not multiplayer.is_server():
		#return		
	if OS.has_feature("dedicated_server"):
		game_state = GameStateServer.new() 
		add_child(game_state)
	else:
		game_state = GameStateClient.new() 
		add_child(game_state)

	game_state.initialize()
