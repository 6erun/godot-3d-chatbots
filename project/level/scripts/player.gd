extends CharacterBody3D
class_name Character

const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10

@onready var nickname: Label3D = $PlayerNick/Nickname

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_npc = false
var target_distance = 0
var target_direction = Vector2(0, 1)
var look_at_point = Vector3(0, 0, 1)

func _enter_tree():
	var id_str = str(name)
	var owner_id = id_str.to_int() if id_str.is_valid_int() else 1
	is_npc = !id_str.is_valid_int()

	set_multiplayer_authority(owner_id)
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()
	
func _ready():
	if multiplayer.is_server():
		$SpringArmOffset/SpringArm3D/Camera3D.current = false
	
func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	if !is_npc:
		var current_scene = get_tree().get_current_scene()
		var client : GameStateClient = current_scene.get("game_state")

		if client.is_chat_active() and is_on_floor():
			freeze()
			return
				
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= gravity * delta
	
	_move()
	move_and_slide()
	_body.animate(velocity)
	_check_fall_and_respawn()
	
	if is_npc:
		if target_distance > 0:
			target_distance -= delta * _current_speed	
		else:
			target_distance = 0
			target_direction = Vector2.ZERO
			look_at(look_at_point, Vector3(0, 1, 0), true)
	
func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)
	
func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	var _direction: Vector3
	
	if is_multiplayer_authority():		
		if is_npc:
			_input_direction = target_direction.normalized()
			_direction = Vector3(_input_direction.x, 0, _input_direction.y).normalized()
		else:
			_input_direction = Input.get_vector(
				"move_left", "move_right",
				"move_forward", "move_backward"
				)
			_direction = transform.basis * Vector3(_input_direction.x, 0, _input_direction.y).normalized()
	
	is_running()
	_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)
	
	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		_body.apply_rotation(velocity)
		return
	
	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)	
	

# Add this function to get the forward direction vector
func get_forward_direction() -> Vector3:
	# Use the -Z axis transformed by the player's basis
	# The negative Z is forward in Godot's coordinate system
	return -transform.basis.z.normalized()

# Or modify your move_forward function to use the forward direction
func move_forward(distance: float) -> void:
	target_distance = distance
	# Convert the forward direction to XZ plane for the target_direction
	var forward = get_forward_direction()
	target_direction = Vector2(forward.x, forward.z)
	
func set_look_at_point(point: Vector3):
	look_at_point = point
	
func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false
		
func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()
		
func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	
@rpc("any_peer", "reliable", "call_local")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick
		
func get_texture_from_name(skin_name: String) -> CompressedTexture2D:
	match skin_name:
		"blue": return blue_texture
		"green": return green_texture
		"red": return red_texture
		"yellow": return yellow_texture
		_: return blue_texture
		
@rpc("any_peer", "reliable")
func set_player_skin(skin_name: String) -> void:
	var texture = get_texture_from_name(skin_name)
	var bottom: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
	var chest: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
	var face: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
	var limbs_head: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
	
	set_mesh_texture(bottom, texture)
	set_mesh_texture(chest, texture)
	set_mesh_texture(face, texture)
	set_mesh_texture(limbs_head, texture)
	
func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)
			
