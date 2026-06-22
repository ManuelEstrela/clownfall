extends RefCounted
class_name MenuController

const NAV_COOLDOWN_TIME: float = 0.25
const AXIS_ACTIVATION_THRESHOLD: float = 0.3

var buttons: Array = []
var selected_index: int = 0
var using_controller: bool = false
var mouse_has_moved: bool = false
var nav_cooldown: float = 0.0
var horizontal: bool = false

var _base_scale: Vector2 = Vector2(1.0, 1.0)
var _hover_scale: Vector2 = Vector2(1.08, 1.08)
var _hover_sound: AudioStreamPlayer = null
var _owner_node: Node = null

func setup(owner: Node, btn_array: Array, base_scale: Vector2, hover_scale: Vector2, hover_sound: AudioStreamPlayer = null, is_horizontal: bool = false):
	_owner_node = owner
	buttons = btn_array
	_base_scale = base_scale
	_hover_scale = hover_scale
	_hover_sound = hover_sound
	horizontal = is_horizontal
	using_controller = false
	mouse_has_moved = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for btn in buttons:
		_connect_hover(btn)

func tick(delta: float):
	if nav_cooldown > 0.0:
		nav_cooldown -= delta

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		mouse_has_moved = true
		if using_controller:
			using_controller = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_shrink(buttons[selected_index])
		return false

	if event is InputEventMouseButton:
		if mouse_has_moved and using_controller:
			using_controller = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_shrink(buttons[selected_index])
		return false

	if event is InputEventJoypadMotion:
		if abs(event.axis_value) < AXIS_ACTIVATION_THRESHOLD:
			return false

	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false

	if not using_controller:
		using_controller = true
		mouse_has_moved = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_grow(buttons[selected_index])
		return true

	var next_action = "ui-down" if not horizontal else "move_right"
	var prev_action = "ui-up"   if not horizontal else "move_left"

	if event.is_action_pressed(next_action) and nav_cooldown <= 0.0:
		set_selected((selected_index + 1) % buttons.size())
		nav_cooldown = NAV_COOLDOWN_TIME
		return true

	if event.is_action_pressed(prev_action) and nav_cooldown <= 0.0:
		set_selected((selected_index - 1 + buttons.size()) % buttons.size())
		nav_cooldown = NAV_COOLDOWN_TIME
		return true

	if event.is_action_pressed("ui-confirm"):
		buttons[selected_index].emit_signal("pressed")
		return true

	return false

func set_selected(new_index: int):
	_shrink(buttons[selected_index])
	selected_index = new_index
	_grow(buttons[selected_index])

func reset_to_first():
	var old = selected_index
	selected_index = 0
	if using_controller:
		if old != 0:
			_shrink(buttons[old])
		_grow(buttons[0])

func _connect_hover(btn):
	btn.mouse_entered.connect(func():
		if not mouse_has_moved:
			return
		if using_controller:
			return
		if _hover_sound:
			_hover_sound.play()
		_grow(btn)
	)
	btn.mouse_exited.connect(func():
		if not mouse_has_moved:
			return
		# Only protect the selected button from shrinking when
		# controller is actually active — not just because selected_index happens
		# to point at this button while in mouse mode
		if using_controller and buttons[selected_index] == btn:
			return
		_shrink(btn)
	)

func _grow(btn):
	var tw = _owner_node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", _hover_scale, 0.15)

func _shrink(btn):
	var tw = _owner_node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "scale", _base_scale, 0.15)
