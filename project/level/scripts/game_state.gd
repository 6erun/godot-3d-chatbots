class_name GameState
extends Node

var TAG = "GameState"

var player_scene: PackedScene = preload("res://level/scenes/player.tscn")
@onready var players_container: Node3D = $/root/Level/PlayersContainer

func _init():
	self.name = "GameState"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _logS(msg: String):
	print(TAG + ": " + msg)

func initialize():
	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)
	
	_initialized()
	pass
	
func _initialized():
	pass
	
func _on_player_connected(peer_id, player_info):
	_logS("Player connected: " + str(peer_id))

	for id in Network.players.keys():
		var player_data = Network.players[id]
		if id != peer_id:
			rpc_id(peer_id, "sync_player_skin", id, str(id), player_data["skin"])

func _remove_player(id):
	pass

@rpc("any_peer", "call_local")
func sync_player_position(_id: int, node_name: String, new_position: Vector3):
	var player = players_container.get_node(node_name)
	if player:
		player.position = new_position
		
@rpc("any_peer", "call_local")
func sync_player_skin(id: int, node_name: String, skin_name: String):
	_logS("sync_player_skin: " + str(id) + " " + skin_name)
	#if id == 1: return # ignore host
	var player = players_container.get_node(node_name)
	if player:
		player.set_player_skin(skin_name)

@rpc("any_peer", "call_local")
func sync_player_look_at(_id: int, node_name: String, new_position: Vector3):
	var player: Character = players_container.get_node(node_name)
	if player:
		player.look_at(new_position, Vector3(0, 1, 0), true)

@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	pass
	
