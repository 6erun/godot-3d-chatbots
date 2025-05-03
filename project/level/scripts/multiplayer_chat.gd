class_name MultiplayerChat
extends Control

@onready var message: LineEdit = $Container/Message
@onready var send: Button = $Container/Send
@onready var chat: TextEdit = $Container/Chat

signal new_message(msg: String)

# Called when the node enters the scene tree for the first time.
func _ready():
	send.pressed.connect(_on_send_pressed)
	pass # Replace with function body.

func _input(event):
	if event is InputEventKey and event.keycode == KEY_ENTER:
		_on_send_pressed()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func is_chat_active() -> bool:
	return is_visible() and message.has_focus()

func toggle_chat(_grab_focus: bool = true):
	if get_tree().paused:
		return

	if is_visible():
		hide()
		get_viewport().set_input_as_handled()
	else:
		show()
		message.text = ""
		if _grab_focus:
			message.grab_focus()

func add_message(nick: String, msg: String):
	var lines = msg.split("\n")
	for line in lines:
		if line.strip_edges() == "":
			continue
		chat.text += str(nick, " : ", line, "\n")

	chat.scroll_vertical = chat.get_line_count()

func _on_send_pressed() -> void:
	var trimmed_message = message.text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	new_message.emit(trimmed_message)
	message.text = ""
	message.grab_focus()
