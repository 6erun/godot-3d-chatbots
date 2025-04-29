class_name GameStateClient
extends GameState

@onready var skin_input: LineEdit = $/root/Level/Menu/MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $/root/Level/Menu/MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $/root/Level/Menu/MainContainer/MainMenu/Option3/AddressInput
@onready var join_button: Button = $/root/Level/Menu/MainContainer/MainMenu/Buttons/Join
@onready var quit_button: Button = $/root/Level/Menu/MainContainer/MainMenu/Option4/Quit
@onready var message: LineEdit = $/root/Level/MultiplayerChat/Container/Message
@onready var send: Button = $/root/Level/MultiplayerChat/Container/Send
@onready var chat: TextEdit = $/root/Level/MultiplayerChat/Container/Chat
@onready var menu: Control = $/root/Level/Menu
@onready var multiplayer_chat: MultiplayerChat = $/root/Level/MultiplayerChat

var chat_visible = false

func _init():
	super()
	self.TAG = "Client"

# Called when the node enters the scene tree for the first time.
func _ready():
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	multiplayer_chat.new_message.connect(_on_new_message)
	chat_visible = multiplayer_chat.visible
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _initialized():
	menu.show()
	multiplayer_chat.set_process_input(true)

	var display_size = DisplayServer.screen_get_size()
	get_window().size = display_size / 2

func _on_host_pressed():
	menu.hide()
	#_start_host()

func _on_join_pressed():
	var ip:String = address_input.text.strip_edges()
	if ip.is_empty():
		ip = Network.SERVER_ADDRESS
	if not ip.is_valid_ip_address():
		push_error("Invalid server ip:" + ip)
		return
	menu.hide()
	toggle_chat(false)
	Network.join_game(nick_input.text.strip_edges(), skin_input.text.strip_edges().to_lower(), ip)
		
func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------- MULTIPLAYER CHAT ----------
func toggle_chat(grab_focus: bool = true):
	if menu.visible:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.show()
		if grab_focus:
			message.grab_focus()
	else:
		message.text = ""
		multiplayer_chat.hide()
		get_viewport().set_input_as_handled()

func is_chat_visible() -> bool:
	return chat_visible
	
func is_chat_active() -> bool:
	return is_chat_visible() and message.has_focus()

func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()

func _on_new_message(msg: String):
	var nick = Network.players[multiplayer.get_unique_id()]["nick"]
	rpc("msg_rpc", nick, msg)

func msg_rpc(nick, msg):
	multiplayer_chat.add_message(nick, msg)
