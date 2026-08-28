extends Control

@onready var background: TextureRect = $Background

var gamemode_title: TextureRect
var classic_image: TextureRect
var chaos_image: TextureRect
var classic_title: TextureRect
var chaos_title: TextureRect
var start_button: TextureButton

var is_transitioning: bool = false
var selected_mode: String = ""
var start_button_base_scale: float = 0.5

var button_hover_sound: AudioStreamPlayer = null
var button_click_sound: AudioStreamPlayer = null
var start_game_sound: AudioStreamPlayer = null

# ══════════════════════════════════════════════════════════════════════
#  LAYOUT
#
#  Everything is mirrored around the viewport's horizontal centre rather
#  than hardcoded to fixed x values, so the whole screen stays centred if
#  the resolution ever changes and the two cards can't drift apart.
#
#  Deliberately NOT using HBoxContainer or anchors here. A container owns
#  its children's position and size, and it fights the hover tween — that's
#  the usual reason "centre it" and "keep the hover animation" feel like
#  they can't both work. Manual positioning keeps the tweens untouched.
# ══════════════════════════════════════════════════════════════════════

var card_size: Vector2 = Vector2(400, 290)
var card_gap: float = 80.0            # horizontal space between the two cards
var card_y: float = 210.0
var title_center_y: float = 525.0     # vertical CENTRE of both mode titles
var classic_title_width: float = 240.0
var chaos_title_width: float = 220.0
var gamemode_title_width: float = 450.0
var gamemode_title_y: float = 55.0
var start_button_y: float = 550.0

# ====== SCALE STATES ======
# Mode cards. Idle is what both cards sit at on load, so "nothing selected"
# looks identical to "deselected" — set mode_scale_idle to 0.9 if you'd
# rather the unpicked card visibly shrink away from the picked one.
var mode_scale_idle: float = 1.0
var mode_scale_hover: float = 1.05
var mode_scale_selected: float = 1.1

# Start button. It sits small until a mode is picked, then grows slightly to
# signal it's live. Hover multiplies whichever of the two it's currently at.
var start_scale_idle: float = 0.5
var start_scale_ready: float = 0.56
var start_hover_multiplier: float = 1.15

# Two separate controllers:
# mode_controller handles left/right between classic and chaos (horizontal)
# start_controller handles the start button (just confirm)
var mode_controller: MenuController
var start_controller: MenuController
# -1 = mouse mode. Starting here means nothing is selected on load, and the
# first controller input picks classic rather than doing nothing.
var active_controller_area: int = -1

var start_button_hovered: bool = false

var nav_cooldown: float = 0.0
const NAV_COOLDOWN_TIME: float = 0.25

func _ready():
	print("=== Mode Selection Loading ===")

	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture

	setup_sounds()
	setup_ui()

	print("=== Mode Selection Ready ===")

func setup_sounds():
	button_hover_sound = AudioStreamPlayer.new()
	button_hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	button_hover_sound.volume_db = -5
	button_hover_sound.bus = "SFX"
	add_child(button_hover_sound)

	button_click_sound = AudioStreamPlayer.new()
	button_click_sound.stream = load("res://assets/sounds/button_click.mp3")
	button_click_sound.volume_db = 0
	button_click_sound.bus = "SFX"
	add_child(button_click_sound)

	start_game_sound = AudioStreamPlayer.new()
	start_game_sound.stream = load("res://assets/sounds/start_game.mp3")
	start_game_sound.volume_db = 0
	start_game_sound.bus = "SFX"
	add_child(start_game_sound)

func setup_ui():
	var viewport_size = get_viewport_rect().size

	# Every horizontal position on this screen derives from these three.
	var center_x = viewport_size.x / 2.0
	var classic_center_x = center_x - (card_size.x + card_gap) / 2.0
	var chaos_center_x = center_x + (card_size.x + card_gap) / 2.0

	# === GAMEMODE TITLE ===
	gamemode_title = TextureRect.new()
	gamemode_title.texture = load("res://assets/images/gamemode_title.png")
	gamemode_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	gamemode_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(gamemode_title)

	if gamemode_title.texture:
		var title_ratio = gamemode_title.texture.get_height() / float(gamemode_title.texture.get_width())
		gamemode_title.size = Vector2(gamemode_title_width, gamemode_title_width * title_ratio)
		gamemode_title.position = Vector2(center_x - gamemode_title_width / 2.0, gamemode_title_y)

	# === CLASSIC MODE ===
	classic_image = TextureRect.new()
	classic_image.texture = load("res://assets/images/classic_image.png")
	classic_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_image.size = card_size
	classic_image.position = Vector2(classic_center_x - card_size.x / 2.0, card_y)
	# pivot at the centre means the hover tween grows the card outward from
	# its middle instead of shoving it right and down.
	classic_image.pivot_offset = card_size / 2.0
	classic_image.mouse_filter = Control.MOUSE_FILTER_STOP
	classic_image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(classic_image)

	classic_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("classic")
	)
	classic_image.mouse_entered.connect(func():
		if selected_mode != "classic":
			button_hover_sound.play()
			animate_hover(classic_image, classic_title, true)
	)
	classic_image.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)

	classic_title = TextureRect.new()
	classic_title.texture = load("res://assets/images/classic_title.png")
	classic_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	classic_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_title.mouse_filter = Control.MOUSE_FILTER_STOP
	classic_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(classic_title)

	if classic_title.texture:
		_place_title(classic_title, classic_title_width, classic_center_x)

	classic_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("classic")
	)
	classic_title.mouse_entered.connect(func():
		if selected_mode != "classic":
			button_hover_sound.play()
			animate_hover(classic_image, classic_title, true)
	)
	classic_title.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)

	# === CHAOS MODE ===
	chaos_image = TextureRect.new()
	chaos_image.texture = load("res://assets/images/chaos_image.png")
	chaos_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chaos_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_image.size = card_size
	chaos_image.position = Vector2(chaos_center_x - card_size.x / 2.0, card_y)
	chaos_image.pivot_offset = card_size / 2.0
	chaos_image.mouse_filter = Control.MOUSE_FILTER_STOP
	chaos_image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(chaos_image)

	chaos_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("chaos")
	)
	chaos_image.mouse_entered.connect(func():
		if selected_mode != "chaos":
			button_hover_sound.play()
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_image.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)

	chaos_title = TextureRect.new()
	chaos_title.texture = load("res://assets/images/chaos_title.png")
	chaos_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	chaos_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_title.mouse_filter = Control.MOUSE_FILTER_STOP
	chaos_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(chaos_title)

	if chaos_title.texture:
		_place_title(chaos_title, chaos_title_width, chaos_center_x)

	chaos_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("chaos")
	)
	chaos_title.mouse_entered.connect(func():
		if selected_mode != "chaos":
			button_hover_sound.play()
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_title.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)

	# === START BUTTON ===
	start_button = TextureButton.new()
	start_button.texture_normal = load("res://assets/images/button_start.png")
	add_child(start_button)

	if start_button.texture_normal:
		var button_scale = start_scale_idle
		start_button_base_scale = button_scale
		var texture_width = start_button.texture_normal.get_width()
		var texture_height = start_button.texture_normal.get_height()
		start_button.scale = Vector2(button_scale, button_scale)
		start_button.pivot_offset = Vector2(texture_width / 2.0, texture_height / 2.0)

		# A scaled Control does NOT draw at `position`. Godot maps a local
		# point v to:  position + pivot_offset + (v - pivot_offset) * scale
		# With the pivot at the texture's centre, the drawn centre lands at
		# position + pivot_offset — the scale cancels out entirely.
		#
		# So centring means subtracting the FULL half-width, not the scaled
		# half-width. The old code subtracted (texture_width / 2) * scale,
		# which left the button sitting texture_width / 4 too far right —
		# about 150px at this texture size, which is what you were seeing.
		#
		# The upside of pivoting at the centre: the hover tween scales the
		# button in place, because the drawn centre doesn't depend on scale.
		# Move the pivot to fix centring and the hover starts sliding the
		# button around instead.
		start_button.position = Vector2(
			center_x - texture_width / 2.0,
			start_button_y
		)

	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(func():
		button_hover_sound.play()
		animate_button_hover(start_button, true)
	)
	start_button.mouse_exited.connect(func():
		if active_controller_area != 1 or not _any_controller_active():
			animate_button_hover(start_button, false)
	)
	SettingsManager.set_hover_cursor(start_button)

	# === MODE CONTROLLER (horizontal — classic vs chaos) ===
	# We use TextureRects not TextureButtons so we manage this manually
	# mode_controller is used only for device-switching detection here
	# actual mode selection is handled in _input below

	print("✅ UI setup complete")

# Sizes a mode title from its texture's aspect ratio, then centres it under
# its card and on the shared title centre line. The two titles have different
# widths (the words aren't the same length), so aligning their TOPS would
# leave them sitting at visibly different heights — centres are what should
# match, not tops.
func _place_title(title: TextureRect, title_width: float, center_of_card_x: float):
	var ratio = title.texture.get_height() / float(title.texture.get_width())
	var title_height = title_width * ratio
	title.size = Vector2(title_width, title_height)
	title.position = Vector2(
		center_of_card_x - title_width / 2.0,
		title_center_y - title_height / 2.0
	)
	title.pivot_offset = title.size / 2.0

func _any_controller_active() -> bool:
	return (mode_controller and mode_controller.using_controller) or \
		   (start_controller and start_controller.using_controller)

func _process(delta):
	if nav_cooldown > 0.0:
		nav_cooldown -= delta

# project.godot binds Escape to "ui-cancel" — with a HYPHEN, alongside
# ui-up / ui-down / ui-confirm / ui-pause. This screen was checking Godot's
# built-in "ui_cancel" with an underscore, which isn't the action the key is
# mapped to, so Escape did nothing here. All three checks are guarded so this
# keeps working whichever way the input map is edited later.
func _is_back_pressed(event) -> bool:
	if InputMap.has_action("ui-cancel") and event.is_action_pressed("ui-cancel"):
		return true
	if InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_ESCAPE:
		return true
	return false

func _input(event):
	if is_transitioning:
		return

	if _is_back_pressed(event):
		# Consume the event BEFORE swapping scenes, and guard the viewport.
		# change_scene_to_file() tears this scene down, and once this node is
		# out of the tree get_viewport() returns null — which is exactly the
		# "Cannot call method set_input_as_handled on a null value" error.
		# is_transitioning also stops a second Escape from firing a second
		# scene change while the first is still resolving.
		is_transitioning = true
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# Mouse → clear any controller highlights
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if active_controller_area == 0 and selected_mode != "":
			# deselect controller highlight, let mouse hover take over
			_controller_deselect_modes()
		elif active_controller_area == 1:
			animate_button_hover(start_button, false)
		active_controller_area = -1  # mouse mode
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# Controller input
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	# Ignore stick noise.
	#
	# A resting analogue stick emits InputEventJoypadMotion continuously with
	# tiny nonzero values. Without this filter every one of those counted as
	# "the player used the controller", so the cursor was hidden by drift,
	# shown again by mouse motion, hidden by the next drift — which is the
	# flicker, and why it vanished the moment the mouse stopped moving.
	if event is InputEventJoypadMotion and abs(event.axis_value) < STICK_THRESHOLD:
		return

	# First real controller input — activate controller mode, on Classic
	if active_controller_area == -1:
		active_controller_area = 0
		select_mode("classic")
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		return

	if nav_cooldown > 0.0:
		return

	if active_controller_area == 0:
		# Navigating between classic and chaos
		if _pressed_left(event):
			select_mode("classic")
			nav_cooldown = NAV_COOLDOWN_TIME
			get_viewport().set_input_as_handled()

		elif _pressed_right(event):
			select_mode("chaos")
			nav_cooldown = NAV_COOLDOWN_TIME
			get_viewport().set_input_as_handled()

		elif _pressed_down(event):
			# Move focus to start button
			active_controller_area = 1
			if button_hover_sound:
				button_hover_sound.play()
			animate_button_hover(start_button, true)
			nav_cooldown = NAV_COOLDOWN_TIME
			get_viewport().set_input_as_handled()

		elif _pressed_confirm(event):
			# First confirm picks the mode and moves to start
			if selected_mode != "":
				active_controller_area = 1
				if button_hover_sound:
					button_hover_sound.play()
				animate_button_hover(start_button, true)
			get_viewport().set_input_as_handled()

	elif active_controller_area == 1:
		# Start button focused
		if _pressed_up(event):
			active_controller_area = 0
			if button_hover_sound:
				button_hover_sound.play()
			animate_button_hover(start_button, false)
			# selected_mode is never cleared on the way down, so going back
			# up simply lands on whichever card was picked. Re-asserting it
			# guards the case where focus reached Start without a mode
			# somehow being set.
			if selected_mode == "":
				select_mode("classic")
			nav_cooldown = NAV_COOLDOWN_TIME
			get_viewport().set_input_as_handled()

		elif _pressed_confirm(event):
			_on_start_pressed()
			get_viewport().set_input_as_handled()

# The d-pad and left stick aren't bound to the ui-* actions in
# project.godot, so they're read directly here alongside the actions. The
# stick uses a threshold rather than any value, otherwise resting drift
# would count as a press.
const STICK_THRESHOLD := 0.55

func _stick(event, axis: int, want_positive: bool) -> bool:
	if not (event is InputEventJoypadMotion) or event.axis != axis:
		return false
	return event.axis_value > STICK_THRESHOLD if want_positive \
		else event.axis_value < -STICK_THRESHOLD

func _dpad(event, button: int) -> bool:
	return event is InputEventJoypadButton and event.pressed \
		and event.button_index == button

func _pressed_left(event) -> bool:
	return event.is_action_pressed("move_left") \
		or _dpad(event, JOY_BUTTON_DPAD_LEFT) \
		or _stick(event, JOY_AXIS_LEFT_X, false)

func _pressed_right(event) -> bool:
	return event.is_action_pressed("move_right") \
		or _dpad(event, JOY_BUTTON_DPAD_RIGHT) \
		or _stick(event, JOY_AXIS_LEFT_X, true)

func _pressed_up(event) -> bool:
	return event.is_action_pressed("ui-up") \
		or _dpad(event, JOY_BUTTON_DPAD_UP) \
		or _stick(event, JOY_AXIS_LEFT_Y, false)

func _pressed_down(event) -> bool:
	return event.is_action_pressed("ui-down") \
		or _dpad(event, JOY_BUTTON_DPAD_DOWN) \
		or _stick(event, JOY_AXIS_LEFT_Y, true)

func _pressed_confirm(event) -> bool:
	return event.is_action_pressed("ui-confirm") \
		or _dpad(event, JOY_BUTTON_A)

func _controller_deselect_modes():
	animate_selection(classic_image, classic_title, false)
	animate_selection(chaos_image, chaos_title, false)

func select_mode(mode: String):
	# Every hover sound in this file sits inside a mouse_entered handler, so
	# controller navigation was silent.
	#
	# Two gates. Only when the selection actually CHANGES, so returning from
	# the Start button to the mode already picked doesn't retrigger it. And
	# only in controller mode (-1 means mouse), because the mouse path
	# already plays its own hover sound on mouse_entered and would otherwise
	# stack two sounds on one click.
	if mode != selected_mode and active_controller_area != -1 and button_hover_sound:
		button_hover_sound.play()

	selected_mode = mode
	if mode == "classic":
		animate_selection(classic_image, classic_title, true)
		animate_selection(chaos_image, chaos_title, false)
		print("🎪 Classic mode selected")
	else:
		animate_selection(chaos_image, chaos_title, true)
		animate_selection(classic_image, classic_title, false)
		print("🎪 Chaos mode selected")
	refresh_start_button()

func animate_hover(image: TextureRect, title: TextureRect, is_hovering: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	var v = mode_scale_hover if is_hovering else mode_scale_idle
	tween.tween_property(image, "scale", Vector2(v, v), 0.2)
	tween.tween_property(title, "scale", Vector2(v, v), 0.2)

func animate_selection(image: TextureRect, title: TextureRect, is_selected: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	var v = mode_scale_selected if is_selected else mode_scale_idle
	tween.tween_property(image, "scale", Vector2(v, v), 0.3)
	tween.tween_property(title, "scale", Vector2(v, v), 0.3)

# The start button's size is derived from two independent things: whether a
# mode is selected (small → ready) and whether it's being hovered. Working it
# out from state each time avoids the two fighting — e.g. picking a mode
# while the cursor already rests on the button.
func start_button_target_scale() -> float:
	var base = start_scale_ready if selected_mode != "" else start_scale_idle
	if start_button_hovered or active_controller_area == 1:
		base *= start_hover_multiplier
	return base

func refresh_start_button():
	if start_button == null:
		return
	var v = start_button_target_scale()
	start_button_base_scale = start_scale_ready if selected_mode != "" else start_scale_idle
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(start_button, "scale", Vector2(v, v), 0.2)

func animate_button_hover(_button: TextureButton, is_hovering: bool):
	start_button_hovered = is_hovering
	refresh_start_button()

func _on_start_pressed():
	if is_transitioning:
		return
	if selected_mode == "":
		print("⚠️ Please select a game mode first!")
		return
	button_click_sound.play()
	start_game_sound.play()
	is_transitioning = true
	start_button.disabled = true
	fade_out_and_start_game()

func fade_out_and_start_game():
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = get_viewport_rect().size
	fade_overlay.z_index = 1000
	add_child(fade_overlay)
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	await tween.finished
	if selected_mode == "chaos":
		get_tree().change_scene_to_file("res://scenes/game_world_chaotic.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_world_normal.tscn")
