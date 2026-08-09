extends RefCounted
class_name MenuController

# ══════════════════════════════════════════════════════════════════════
#  MENU CONTROLLER — 2D navigation
#
#  Replaces the old single-ring version, which could only step forward and
#  backward through one flat list. That worked for a plain vertical column
#  but couldn't express the main menu, where a centre column feeds into a
#  bottom-left pair and a bottom-right trio.
#
#  Two ways to define movement:
#    * set_links()  — an explicit graph. Use this when the reading order
#                     matters more than the pixel layout.
#    * geometry     — the fallback. Picks the nearest button in the pushed
#                     direction, preferring ones that line up with the
#                     current selection.
#
#  Both the left stick and the d-pad are handled directly rather than
#  relying only on input actions, because project.godot binds ui-up /
#  ui-down / move_left / move_right to keys and only some joypad inputs.
# ══════════════════════════════════════════════════════════════════════

const NAV_COOLDOWN_TIME: float = 0.22
# Push past this to move; fall back under RELEASE before it'll move again.
# The gap is what stops a held stick from scrolling continuously.
const AXIS_ACTIVATION_THRESHOLD: float = 0.55
const AXIS_RELEASE_THRESHOLD: float = 0.35

var buttons: Array = []
var selected_index: int = 0
var using_controller: bool = false
var mouse_has_moved: bool = false
var nav_cooldown: float = 0.0
var horizontal: bool = false

# index -> {"up": i, "down": i, "left": i, "right": i}. Partial maps are
# fine; any direction left out falls through to geometry.
var links: Dictionary = {}

# Each button keeps its OWN resting scale. The old version stored a single
# base for the whole menu, which meant highlighting a 0.55-scale corner
# button snapped it to the main column's 1.0 and left it there.
var _base_scales: Dictionary = {}
var _hover_factor: float = 1.08
var _hover_sound: AudioStreamPlayer = null
var _owner_node: Node = null

var _axis_latched: Dictionary = {"x": 0, "y": 0}

func setup(owner: Node, btn_array: Array, base_scale: Vector2, hover_scale: Vector2, hover_sound: AudioStreamPlayer = null, is_horizontal: bool = false):
	_owner_node = owner
	buttons = btn_array
	_hover_sound = hover_sound
	horizontal = is_horizontal
	using_controller = false
	mouse_has_moved = false

	if base_scale.x > 0.0:
		_hover_factor = hover_scale.x / base_scale.x

	# Base scales are captured LAZILY, on the first grow or shrink — not
	# here. main_menu.gd's load_button_texture() awaits a frame before it
	# applies button.scale, and it's called without await, so at setup time
	# those buttons are still at 1.0 rather than their real 0.6. Recording
	# now would treat 1.0 as the resting size: every highlight would blow the
	# button up to 1.2 and every un-highlight would leave it stuck at 1.0.
	# By the time anything is actually highlighted the real scale is in
	# place, so sampling then is correct.
	_base_scales.clear()
	for btn in buttons:
		if btn == null:
			continue
		_connect_hover(btn)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Explicit navigation graph. Keys are indices into the button array.
func set_links(link_map: Dictionary):
	links = link_map

func tick(delta: float):
	if nav_cooldown > 0.0:
		nav_cooldown -= delta

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		mouse_has_moved = true
		if using_controller:
			_leave_controller_mode()
		return false

	if event is InputEventMouseButton:
		if mouse_has_moved and using_controller:
			_leave_controller_mode()
		return false

	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false

	var direction = _direction_from(event)

	# Ignore stick noise entirely — otherwise the tiniest drift would flip
	# the menu into controller mode and hide the cursor mid-click.
	if event is InputEventJoypadMotion and direction == "":
		return false

	if not using_controller:
		using_controller = true
		mouse_has_moved = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_grow(_current())
		return true

	if _is_confirm(event):
		var btn = _current()
		if btn:
			btn.emit_signal("pressed")
		return true

	if direction != "" and nav_cooldown <= 0.0:
		var target = _neighbour(direction)
		if target != -1 and target != selected_index:
			set_selected(target)
			nav_cooldown = NAV_COOLDOWN_TIME
			if _hover_sound:
				_hover_sound.play()
		return true

	return false

# ── Direction decoding ────────────────────────────────────────────────

func _direction_from(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		return _direction_from_axis(event)

	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: return "up"
			JOY_BUTTON_DPAD_DOWN: return "down"
			JOY_BUTTON_DPAD_LEFT: return "left"
			JOY_BUTTON_DPAD_RIGHT: return "right"

	if event.is_action_pressed("ui-up"):
		return "up"
	if event.is_action_pressed("ui-down"):
		return "down"
	if event.is_action_pressed("move_left"):
		return "left"
	if event.is_action_pressed("move_right"):
		return "right"
	return ""

# Latching: a direction only fires when the stick crosses the activation
# threshold, and won't fire again until it falls back below release. Without
# this a held stick emits motion events every frame and the menu bolts.
func _direction_from_axis(event: InputEventJoypadMotion) -> String:
	var axis_key := ""
	if event.axis == JOY_AXIS_LEFT_X:
		axis_key = "x"
	elif event.axis == JOY_AXIS_LEFT_Y:
		axis_key = "y"
	else:
		return ""

	var value = event.axis_value
	var sign_now = 0
	if value > AXIS_ACTIVATION_THRESHOLD:
		sign_now = 1
	elif value < -AXIS_ACTIVATION_THRESHOLD:
		sign_now = -1

	if abs(value) < AXIS_RELEASE_THRESHOLD:
		_axis_latched[axis_key] = 0
		return ""

	if sign_now == 0 or _axis_latched[axis_key] == sign_now:
		return ""

	_axis_latched[axis_key] = sign_now
	if axis_key == "x":
		return "right" if sign_now > 0 else "left"
	return "down" if sign_now > 0 else "up"

func _is_confirm(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed \
		and event.button_index == JOY_BUTTON_A:
		return true
	return event.is_action_pressed("ui-confirm")

# ── Neighbour resolution ──────────────────────────────────────────────

func _neighbour(direction: String) -> int:
	if links.has(selected_index):
		var entry: Dictionary = links[selected_index]
		if entry.has(direction):
			return entry[direction]
		# An explicit entry that omits a direction means "nothing that way".
		return -1
	return _geometric_neighbour(direction)

# Scores every other button by how far it sits in the pushed direction and
# how badly it's off-axis. The across-axis penalty is weighted heavier so a
# button that lines up wins over a closer one sitting diagonally.
func _geometric_neighbour(direction: String) -> int:
	var from = _centre(_current())
	var best := -1
	var best_score := INF

	for i in range(buttons.size()):
		if i == selected_index or buttons[i] == null:
			continue
		var delta = _centre(buttons[i]) - from
		var along := 0.0
		var across := 0.0
		match direction:
			"up":    along = -delta.y; across = abs(delta.x)
			"down":  along = delta.y;  across = abs(delta.x)
			"left":  along = -delta.x; across = abs(delta.y)
			_:       along = delta.x;  across = abs(delta.y)
		if along <= 1.0:
			continue
		var score = along + across * 2.0
		if score < best_score:
			best_score = score
			best = i
	return best

func _centre(btn) -> Vector2:
	if btn == null:
		return Vector2.ZERO
	var scale_now: Vector2 = btn.scale if "scale" in btn else Vector2.ONE
	return btn.global_position + (btn.size * scale_now) / 2.0

func _current():
	if selected_index < 0 or selected_index >= buttons.size():
		return null
	return buttons[selected_index]

# ── Selection & highlight ─────────────────────────────────────────────

func set_selected(new_index: int):
	if new_index < 0 or new_index >= buttons.size():
		return
	_shrink(_current())
	selected_index = new_index
	_grow(_current())

func reset_to_first():
	select_index_silently(0)

# Moves the selection without animating anything — for setting the starting
# button before the player has touched a controller.
func select_index_silently(index: int):
	if index < 0 or index >= buttons.size():
		return
	if using_controller:
		set_selected(index)
	else:
		selected_index = index

func _leave_controller_mode():
	using_controller = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_shrink(_current())

func _connect_hover(btn):
	btn.mouse_entered.connect(func():
		if not mouse_has_moved or using_controller:
			return
		if _hover_sound:
			_hover_sound.play()
		_grow(btn)
	)
	btn.mouse_exited.connect(func():
		if not mouse_has_moved:
			return
		# Only protect the selected button from shrinking when the
		# controller is actually driving — not merely because
		# selected_index happens to point at it while in mouse mode.
		if using_controller and _current() == btn:
			return
		_shrink(btn)
	)

# Records the button's resting scale the first time we touch it. Nothing has
# grown it at that point, so whatever it's sitting at IS the base.
func _ensure_base(btn):
	if btn != null and not _base_scales.has(btn):
		_base_scales[btn] = btn.scale

func _base_of(btn) -> Vector2:
	return _base_scales.get(btn, Vector2.ONE)

func _grow(btn):
	if btn == null or _owner_node == null:
		return
	_ensure_base(btn)
	var tw = _owner_node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", _base_of(btn) * _hover_factor, 0.15)

func _shrink(btn):
	if btn == null or _owner_node == null:
		return
	_ensure_base(btn)
	var tw = _owner_node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "scale", _base_of(btn), 0.15)
