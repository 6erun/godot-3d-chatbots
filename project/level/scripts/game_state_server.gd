class_name GameStateServer
extends GameState

class Player:
	var id: int
	var nickname: String
	var character: Character

var bots = {}
var players = {}

@onready var bots_container: Node = $/root/Level/BotsContainer
@onready var level_floor_mesh: MeshInstance3D = $/root/Level/Environment/Floor/MeshInstance3D

var prompt_jack = "you are an eloquent internet troll named Jack chatting on internet. Keep responses short and concise"
var prompt_mark = "you are a philosopher named Mark chatting on internet. Keep responses short and concise"

#region Node
func _init():
	super()
	self.TAG = "Server"

# Called when the node enters the scene tree for the first time.
func _ready():
	spawn_points = _generate_spawn_points(Vector2(40, 40))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
#endregion

func _initialized():
	_start_host()

func _start_host():
	print("starting server on port " + str(Network.SERVER_PORT) + " ... ")
	self.TAG = "server"
	Network.start_host()
	
	_add_bot("Jack", prompt_jack)
	_add_bot("Mark", prompt_mark)

func _add_bot(nickname: String = "Bot", prompt: String = ""):
	if not multiplayer.is_server():
		return

	var bot = Bot.new(self, nickname, get_spawn_point())
	bot.player_scene = player_scene
	if prompt and !prompt.is_empty():
		bot.system_prompt = prompt
	bot.create_player(players_container)
	bots[nickname] = bot
	bots_container.add_child(bot)
	rpc("sync_player_position", 1, nickname, bot.player.position)

func _sync_bot_info(peer_id):
	for bot in bots.values():
		bot.sync_info(peer_id)		
	pass

func _on_player_connected(peer_id, player_info):
	_add_player(peer_id, player_info)
	_sync_bot_info(peer_id)

	super(peer_id, player_info)

func _remove_player(id):
	assert(multiplayer.is_server())
	players.erase(id)
	if not players_container.has_node(str(id)):
		return
		
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

func _add_player(id: int, player_info : Dictionary):
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		return

	_logS("Adding player: " + str(id))
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)
		
	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	var skin_name = player_info["skin"]
	rpc("sync_player_skin", id, str(id), skin_name)
	
	rpc("sync_player_position", id, str(id), player.position)
	
	var new_player = Player.new()
	new_player.id = id
	new_player.nickname = nick
	new_player.character = player
	players[id] = new_player
	
var spawn_points : Array[Vector2]

func _generate_spawn_points(max_size: Vector2) -> Array[Vector2]:
	var points : Array[Vector2]
	var aabb : AABB = level_floor_mesh.get_aabb()
	var size = Vector2(aabb.size.x, aabb.size.z)
	size.x = min(max_size.x, size.x)
	size.y = min(max_size.y, size.y)
	
	var center = aabb.get_center()
	var start_x = center.x - size.x / 2
	var start_z = center.z - size.y / 2
	var step_x = size.x / Bot.MAX_INTERACTION_DISTANCE
	var step_z = size.y / Bot.MAX_INTERACTION_DISTANCE

	var num_x = int(size.x / step_x)
	var num_z = int(size.y / step_z)

	for x in range(num_x):
		for z in range(num_z):
			points.append(Vector2(start_x + x * step_x, start_z + z * step_z))

	return points

func get_spawn_point() -> Vector3:
	var cell_index = randi() % spawn_points.size()
	var cell : Vector2 = spawn_points[cell_index]
	var point = Vector3(cell.x, 0.0, cell.y)

	if spawn_points.size() > 1:
		spawn_points[cell_index] = spawn_points.back()
	spawn_points.pop_back()

	_logS("spawn point: " + str(point))
	return point

func msg_rpc(nick, msg):
	if nick in bots.keys():
		return
		
	for bot in bots.values():
		bot.on_message(nick, msg)
	pass
