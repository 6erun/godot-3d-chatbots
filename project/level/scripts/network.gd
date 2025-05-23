extends Node

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 8080
const MAX_PLAYERS : int = 10

var TAG = "Network"

var players = {}
var player_info = {
	"nick" : "host",
	"skin" : "blue"
}

signal player_connected(peer_id, player_info)
signal server_disconnected

func _logS(msg: String):
	print(TAG + ": " + msg)

func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
		
func _ready() -> void:
	# Emitted when this MultiplayerAPI's multiplayer_peer disconnects from server. Only emitted on clients.
	multiplayer.server_disconnected.connect(_on_connection_failed)
	multiplayer.connection_failed.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	# Emitted when this MultiplayerAPI's multiplayer_peer connects with a new peer. 
	# ID is the peer ID of the new peer. Clients get notified when other clients connect to the same server. 
	# Upon connecting to a server, a client also receives this signal for the server (with ID being 1).
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, MAX_PLAYERS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	
func join_game(nickname: String, skin_color: String, address: String = SERVER_ADDRESS):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, SERVER_PORT)
	if error:
		return error

	multiplayer.multiplayer_peer = peer
	if !nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())
	if !skin_color or (skin_color != "red" and skin_color != "blue" and skin_color != "green" and skin_color != "yellow"):
		skin_color = "blue"
	player_info["nick"] = nickname
	player_info["skin"] = skin_color
	
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	
func _on_player_connected(id):
	_logS("Player connected: " + str(id))
	# send info to new player
	_register_player.rpc_id(id, player_info)
	
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	#print("debug function _register_player on Network.gd: ", players, "\n")
	
func _on_player_disconnected(id):
	players.erase(id)
	
func _on_connection_failed():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	
