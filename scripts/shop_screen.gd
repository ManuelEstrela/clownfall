extends Control
class_name ShopScreen

# ══════════════════════════════════════════════════════════════
#  SHOP — claw machine gacha for UI colour themes
#
#  Press the red button, spend stars, and the claw fishes a capsule
#  out of the pile. The capsule cracks open and the colour inside is
#  unlocked and applied.
#
#  Every capsule is drawn in one of the six theme colours, and the
#  colour you see IS the prize — no hidden mapping. The claw is aimed
#  at a capsule of whichever theme was rolled, so the machine never
#  appears to grab one colour and hand you another.
#
#  Everything here is drawn in code (_draw / ColorRect). Swap the
#  pieces for artwork whenever you have it; none of the animation
#  logic depends on how they look.
# ══════════════════════════════════════════════════════════════

# ── COST ──────────────────────────────────────────────────────
const ROLL_COST := 10

# Set true to let the machine hand out colours you already own.
# False guarantees something new every roll, which is far less
# annoying while testing.
const ALLOW_DUPLICATES := false

# ── MACHINE LAYOUT ────────────────────────────────────────────
# Cabinet margin is applied to BOTH sides, so the machine always sits
# centred no matter the resolution.
const CABINET_MARGIN_X := 90.0
const CABINET_TOP := 40.0
const CABINET_BOTTOM_MARGIN := 60.0
const MARQUEE_H := 92.0
const GLASS_INSET_X := 40.0
const GLASS_TOP := 175.0
const GLASS_H := 350.0

const CAPSULE_RADIUS := 36.0
const CAPSULE_COLS := 12
const CAPSULE_ROWS := 3

# ── ANIMATION TIMING (seconds) ────────────────────────────────
# How many capsules the claw teases before committing to the real one.
const DECOY_COUNT := 3
const T_DECOY_TRAVEL := 0.75
const T_DECOY_DIP := 0.45
const T_DECOY_HOLD := 0.35
# How far down the claw dips on a fake-out, as a fraction of the way
# to the capsule. Under 1.0 so it visibly stops short.
const DECOY_DIP_FRACTION := 0.55

const T_TRAVEL := 1.0
const T_DESCEND := 0.8
const T_GRAB := 0.35
const T_LIFT := 0.7
const T_TO_CHUTE := 1.1
const T_RELEASE := 0.4
const T_REVEAL_FLY := 0.6
const T_CRACK := 0.7

# Debug hotkey: Ctrl + Shift + R wipes theme unlocks and refunds spent
# stars so the gacha can be tested from scratch. Set false before shipping.
const DEBUG_RESET_ENABLED := true

const THEME_COLORS := {
	"purple": Color(0.62, 0.42, 0.92),
	"blue":   Color(0.35, 0.55, 0.95),
	"pink":   Color(0.95, 0.50, 0.72),
	"red":    Color(0.92, 0.38, 0.38),
	"yellow": Color(0.96, 0.78, 0.28),
	"green":  Color(0.55, 0.80, 0.25),
}

var settings: Node
var custom_font: Font

# ── COMPUTED LAYOUT ───────────────────────────────────────────
var cabinet: Rect2
var glass: Rect2
var chute: Rect2
var claw_rest: Vector2

# ── NODES ─────────────────────────────────────────────────────
var machine_layer: Node2D
var machine_frame: MachineFrame
var theme_label: Label
var claw: Node2D
var capsules: Array = []
var carried_capsule = null
var star_label: Label
var status_label: Label
var roll_button: Control
var reveal_layer: Node2D
var back_button: TextureButton

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

var rolling: bool = false
var _navigating_away: bool = false

func _ready():
	settings = get_node_or_null("/root/SettingsManager")
	custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	_compute_layout()

	setup_sounds()
	setup_background()
	setup_machine()
	setup_glass_walls()
	setup_capsules()
	setup_claw()
	setup_panel_buttons()
	setup_hud()
	setup_back_button()

	reveal_layer = Node2D.new()
	reveal_layer.z_index = 500
	add_child(reveal_layer)

	refresh_hud()
	print("Shop ready")

func _compute_layout():
	var viewport_size = get_viewport_rect().size
	cabinet = Rect2(
		CABINET_MARGIN_X,
		CABINET_TOP,
		viewport_size.x - CABINET_MARGIN_X * 2.0,
		viewport_size.y - CABINET_TOP - CABINET_BOTTOM_MARGIN
	)
	glass = Rect2(
		cabinet.position.x + GLASS_INSET_X,
		GLASS_TOP,
		cabinet.size.x - GLASS_INSET_X * 2.0,
		GLASS_H
	)
	chute = Rect2(glass.end.x - 150, glass.end.y + 18, 150, 72)
	claw_rest = Vector2(glass.position.x + glass.size.x * 0.5, glass.position.y + 34)

func setup_sounds():
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/button_click.mp3")
	click_sound.bus = "SFX"
	add_child(click_sound)

	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	hover_sound.volume_db = -5
	hover_sound.bus = "SFX"
	add_child(hover_sound)

func setup_background():
	var bg = TextureRect.new()
	bg.texture = load("res://assets/images/landing_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

# ══════════════════════════════════════════════════════════════
#  MACHINE
# ══════════════════════════════════════════════════════════════

func setup_machine():
	machine_layer = Node2D.new()
	machine_layer.z_index = 10
	add_child(machine_layer)

	machine_frame = MachineFrame.new()
	machine_frame.cabinet = cabinet
	machine_frame.marquee_height = MARQUEE_H
	machine_frame.glass = glass
	machine_frame.chute = chute
	machine_layer.add_child(machine_frame)

	var title = Label.new()
	if custom_font:
		title.add_theme_font_override("font", custom_font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.62, 0.10, 0.14))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = "CLOWNFALL"
	title.size = Vector2(cabinet.size.x, MARQUEE_H)
	title.position = Vector2(cabinet.position.x, cabinet.position.y + 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

# Floor and side walls for the pile. Without these the capsules would
# fall straight out the bottom of the glass — they're real rigid bodies
# now, not decorations parked at fixed coordinates.
func setup_glass_walls():
	var walls = StaticBody2D.new()
	machine_layer.add_child(walls)

	var thickness := 40.0
	var pieces = [
		# floor
		{"size": Vector2(glass.size.x, thickness),
		 "pos": Vector2(glass.position.x + glass.size.x / 2.0, glass.end.y + thickness / 2.0)},
		# left wall
		{"size": Vector2(thickness, glass.size.y * 3.0),
		 "pos": Vector2(glass.position.x - thickness / 2.0, glass.end.y - glass.size.y * 1.5)},
		# right wall
		{"size": Vector2(thickness, glass.size.y * 3.0),
		 "pos": Vector2(glass.end.x + thickness / 2.0, glass.end.y - glass.size.y * 1.5)},
	]

	for piece in pieces:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = piece.size
		shape.shape = rect
		shape.position = piece.pos
		walls.add_child(shape)

# Capsules drop from a spread-out grid and settle into a heap. The grid
# only exists so nothing spawns overlapping — two circles born inside
# each other blast apart the instant physics wakes up.
func setup_capsules():
	var ids: Array = THEME_COLORS.keys()

	# Even number of each colour, then shuffled, so the pile is properly
	# mixed rather than banded by colour.
	var pool: Array = []
	var per_color = int(ceil(float(CAPSULE_COLS * CAPSULE_ROWS) / float(ids.size())))
	for id in ids:
		for i in range(per_color):
			pool.append(id)
	pool.shuffle()

	var col_spacing = glass.size.x / float(CAPSULE_COLS)
	var index := 0

	for row in range(CAPSULE_ROWS):
		for col in range(CAPSULE_COLS):
			if index >= pool.size():
				break
			var capsule = Capsule.new()
			capsule.radius = CAPSULE_RADIUS
			capsule.theme_id = pool[index]
			capsule.base_color = THEME_COLORS[capsule.theme_id]
			capsule.position = Vector2(
				glass.position.x + col_spacing * (col + 0.5) + randf_range(-6, 6),
				glass.position.y + 60 + row * (CAPSULE_RADIUS * 2.4) + randf_range(-8, 8)
			)
			capsule.z_index = 20
			machine_layer.add_child(capsule)
			capsule.configure()
			capsules.append(capsule)
			index += 1

	refresh_capsule_marks()

# Owned colours get a tick so it's obvious at a glance which capsules
# are worth anything to you.
func refresh_capsule_marks():
	if settings == null:
		return
	for capsule in capsules:
		if is_instance_valid(capsule):
			capsule.owned = settings.is_theme_unlocked(capsule.theme_id)
			capsule.queue_redraw()

func setup_claw():
	claw = ClawHead.new()
	claw.position = claw_rest
	claw.z_index = 60
	claw.rail_y = glass.position.y - 8.0
	machine_layer.add_child(claw)

func _process(_delta):
	if claw:
		# The cable is drawn in the claw's local space, so it has to be
		# told how far it currently hangs below the rail.
		claw.cable_length = claw.position.y - claw.rail_y
		claw.queue_redraw()
	if carried_capsule and is_instance_valid(carried_capsule):
		carried_capsule.position = claw.position + Vector2(0, CAPSULE_RADIUS * 0.7)

# ══════════════════════════════════════════════════════════════
#  CONTROL PANEL
# ══════════════════════════════════════════════════════════════

func setup_panel_buttons():
	var colors = [Color(0.96, 0.78, 0.28), Color(0.85, 0.15, 0.15), Color(0.20, 0.30, 0.85)]
	var start_x = cabinet.position.x + 160.0
	var y = glass.end.y + 24.0

	# yellow = previous colour, red = roll, blue = next colour
	var arrows = [-1, 0, 1]

	for i in range(3):
		var button = Control.new()
		button.size = Vector2(54, 54)
		button.position = Vector2(start_x + i * 68, y)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(button)

		var face = PanelButtonFace.new()
		face.button_color = colors[i]
		face.arrow = arrows[i]
		face.size = button.size
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(face)

		button.mouse_entered.connect(func():
			if hover_sound:
				hover_sound.play()
		)

		if i == 1:
			# Middle (red) is the one that actually rolls.
			roll_button = button
			button.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
					_on_roll_pressed()
			)
		else:
			var step = arrows[i]
			button.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
					_cycle_theme(step)
			)

	var hint = Label.new()
	if custom_font:
		hint.add_theme_font_override("font", custom_font)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.text = "PRESS RED  -  %d STARS" % ROLL_COST
	hint.position = Vector2(start_x - 90, y + 62)
	hint.size = Vector2(340, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

# ══════════════════════════════════════════════════════════════
#  HUD
# ══════════════════════════════════════════════════════════════

func setup_hud():
	star_label = Label.new()
	if custom_font:
		star_label.add_theme_font_override("font", custom_font)
	star_label.add_theme_font_size_override("font_size", 34)
	star_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	star_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	star_label.add_theme_constant_override("outline_size", 6)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	star_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Sits in the marquee's right end now that the cabinet spans the screen.
	star_label.position = Vector2(cabinet.end.x - 260, cabinet.position.y + 20)
	star_label.size = Vector2(230, MARQUEE_H)
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(star_label)

	# Shows which colour is currently equipped, sat between the arrow buttons.
	theme_label = Label.new()
	if custom_font:
		theme_label.add_theme_font_override("font", custom_font)
	theme_label.add_theme_font_size_override("font_size", 22)
	theme_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	theme_label.add_theme_constant_override("outline_size", 5)
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_label.position = Vector2(cabinet.position.x + 30, glass.end.y - 6)
	theme_label.size = Vector2(340, 26)
	theme_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(theme_label)

	status_label = Label.new()
	if custom_font:
		status_label.add_theme_font_override("font", custom_font)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(cabinet.position.x, cabinet.end.y + 8)
	status_label.size = Vector2(cabinet.size.x, 26)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

func refresh_hud():
	if settings == null:
		return
	star_label.text = "★ %d" % settings.get_available_stars()
	if theme_label:
		theme_label.text = settings.current_theme.to_upper()
		theme_label.add_theme_color_override("font_color", _current_accent())
	apply_theme_preview()

func _current_accent() -> Color:
	if settings == null:
		return THEME_COLORS["purple"]
	return THEME_COLORS.get(settings.current_theme, THEME_COLORS["purple"])

# Recolours the machine's own frame to whatever theme is active. Stands in
# for previewing the real UI until themed shop art exists — the point is
# that switching colours has a visible effect on this screen.
func apply_theme_preview():
	if machine_frame:
		machine_frame.accent = _current_accent()
		machine_frame.queue_redraw()

func _cycle_theme(step: int):
	if settings == null:
		return
	if settings.get_unlocked_themes_ordered().size() <= 1:
		set_status("UNLOCK MORE COLOURS FIRST")
		return
	if click_sound:
		click_sound.play()
	settings.cycle_theme(step)
	refresh_hud()
	refresh_capsule_marks()
	set_status("")

func set_status(text: String):
	if status_label:
		status_label.text = text

# ══════════════════════════════════════════════════════════════
#  THE ROLL
# ══════════════════════════════════════════════════════════════

func _on_roll_pressed():
	if rolling or _navigating_away or settings == null:
		return

	var pool: Array = settings.get_locked_themes() if not ALLOW_DUPLICATES \
		else settings.THEME_IDS.duplicate()

	if pool.is_empty():
		set_status("EVERY COLOUR UNLOCKED")
		return

	if settings.get_available_stars() < ROLL_COST:
		set_status("NOT ENOUGH STARS - NEED %d" % ROLL_COST)
		return

	# Charge only after every reason to refuse has been ruled out, so a
	# rejected roll can never quietly take stars.
	if not settings.spend_stars(ROLL_COST):
		set_status("NOT ENOUGH STARS - NEED %d" % ROLL_COST)
		return

	rolling = true
	if click_sound:
		click_sound.play()
	refresh_hud()
	set_status("")

	var prize: String = pool[randi() % pool.size()]
	_run_claw_sequence(_pick_capsule_for(prize), prize)

# Prefers capsules near the top of the heap. The claw isn't a physics
# body, so it passes straight through anything above its target —
# picking a buried capsule would look like the claw reaching through
# solid balls.
func _pick_capsule_for(theme_id: String):
	var matches: Array = []
	for capsule in capsules:
		if is_instance_valid(capsule) and capsule.theme_id == theme_id and not capsule.taken:
			matches.append(capsule)
	if matches.is_empty():
		return null
	matches.sort_custom(func(a, b): return a.position.y < b.position.y)
	# Top third of the available ones, so it's still a bit random.
	var window = maxi(1, matches.size() / 3)
	return matches[randi() % window]

# ── Claw movement helpers ─────────────────────────────────────
# These await their own tweens rather than being chained into one long
# tween, because the pile is live physics: capsule positions shift as
# balls settle, so each leg has to read where the target actually IS at
# the moment the claw sets off, not where it was when the roll started.

func _claw_move_x(target_x: float, duration: float) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(claw, "position:x", target_x, duration)
	await tween.finished

func _claw_move_y(target_y: float, duration: float, trans := Tween.TRANS_SINE) -> void:
	var tween = create_tween()
	tween.set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(claw, "position:y", target_y, duration)
	await tween.finished

func _claw_set_open(value: float, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(claw, "open_amount", value, duration)
	await tween.finished

func _run_claw_sequence(target, prize: String) -> void:
	if target == null:
		_finish_roll(prize)
		rolling = false
		return

	# ── Fake-outs ──
	# The claw visits a few other capsules first and dips toward each
	# without ever closing, so the player keeps thinking "that one".
	for decoy in _pick_decoys(target, DECOY_COUNT):
		if not is_instance_valid(decoy):
			continue
		await _claw_move_x(decoy.position.x, T_DECOY_TRAVEL)
		var dip_y = lerpf(claw_rest.y, decoy.position.y - CAPSULE_RADIUS, DECOY_DIP_FRACTION)
		await _claw_move_y(dip_y, T_DECOY_DIP)
		await get_tree().create_timer(T_DECOY_HOLD).timeout
		await _claw_move_y(claw_rest.y, T_DECOY_DIP)

	if not is_instance_valid(target):
		target = _pick_capsule_for(prize)
		if target == null:
			_finish_roll(prize)
			rolling = false
			return

	# ── The real grab ──
	await _claw_move_x(target.position.x, T_TRAVEL)
	await _claw_move_y(target.position.y - CAPSULE_RADIUS * 0.7, T_DESCEND)
	await _claw_set_open(0.0, T_GRAB)

	# Freeze it before carrying: it's a rigid body, and gravity would keep
	# pulling it out of the claw's grip otherwise.
	target.freeze = true
	target.z_index = 70
	carried_capsule = target

	await _claw_move_y(claw_rest.y, T_LIFT)
	await _claw_move_x(chute.position.x + chute.size.x / 2.0, T_TO_CHUTE)
	await _claw_set_open(1.0, T_RELEASE)

	carried_capsule = null

	var drop = create_tween()
	drop.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(target, "position",
		Vector2(chute.position.x + chute.size.x / 2.0, chute.position.y + chute.size.y / 2.0),
		T_RELEASE)
	await drop.finished

	target.taken = true
	target.visible = false

	# Send the claw home while the reveal plays.
	var home = create_tween()
	home.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	home.tween_property(claw, "position", claw_rest, T_TO_CHUTE)

	await _reveal(prize)

# Decoys are picked to be far apart in x, so the claw makes a visible
# journey between them instead of twitching in place.
func _pick_decoys(target, count: int) -> Array:
	var options: Array = []
	for capsule in capsules:
		if is_instance_valid(capsule) and capsule != target and not capsule.taken:
			options.append(capsule)
	if options.is_empty():
		return []

	options.shuffle()
	var chosen: Array = []
	for capsule in options:
		if chosen.size() >= count:
			break
		var far_enough := true
		for picked in chosen:
			if abs(picked.position.x - capsule.position.x) < 160.0:
				far_enough = false
				break
		if abs(capsule.position.x - target.position.x) < 120.0:
			far_enough = false
		if far_enough:
			chosen.append(capsule)
	return chosen

# ══════════════════════════════════════════════════════════════
#  REVEAL — the capsule flies out and cracks open
# ══════════════════════════════════════════════════════════════

func _reveal(prize: String) -> void:
	var color: Color = THEME_COLORS[prize]
	var centre = get_viewport_rect().size / 2.0

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.size = get_viewport_rect().size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.z_index = -1
	reveal_layer.add_child(dim)

	var big = RevealCapsule.new()
	big.radius = CAPSULE_RADIUS
	big.base_color = color
	big.position = Vector2(chute.position.x + chute.size.x / 2.0, chute.position.y + chute.size.y / 2.0)
	reveal_layer.add_child(big)

	var fly = create_tween()
	fly.set_parallel(true)
	fly.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.tween_property(big, "position", centre, T_REVEAL_FLY)
	fly.tween_property(big, "scale", Vector2(2.6, 2.6), T_REVEAL_FLY)
	fly.tween_property(dim, "color:a", 0.55, T_REVEAL_FLY)
	await fly.finished

	# Swap the whole capsule for two halves at the same size, then pull
	# them apart. Splitting the original in place would mean animating one
	# node into two, which tweens can't do.
	big.visible = false
	var scale_now = big.scale

	var top_half = CapsuleHalf.new()
	top_half.radius = CAPSULE_RADIUS
	top_half.half_color = color
	top_half.is_top = true
	top_half.position = centre
	top_half.scale = scale_now
	reveal_layer.add_child(top_half)

	var bottom_half = CapsuleHalf.new()
	bottom_half.radius = CAPSULE_RADIUS
	bottom_half.half_color = color
	bottom_half.is_top = false
	bottom_half.position = centre
	bottom_half.scale = scale_now
	reveal_layer.add_child(bottom_half)

	var crack = create_tween()
	crack.set_parallel(true)
	crack.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	crack.tween_property(top_half, "position", centre + Vector2(-40, -120), T_CRACK)
	crack.tween_property(top_half, "rotation_degrees", -35.0, T_CRACK)
	crack.tween_property(bottom_half, "position", centre + Vector2(40, 120), T_CRACK)
	crack.tween_property(bottom_half, "rotation_degrees", 35.0, T_CRACK)
	await crack.finished

	var prize_label = Label.new()
	if custom_font:
		prize_label.add_theme_font_override("font", custom_font)
	prize_label.add_theme_font_size_override("font_size", 46)
	prize_label.add_theme_color_override("font_color", color)
	prize_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prize_label.add_theme_constant_override("outline_size", 8)
	prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_label.text = "YOU GOT %s!" % prize.to_upper()
	prize_label.size = Vector2(600, 60)
	prize_label.position = centre - Vector2(300, 30)
	prize_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_layer.add_child(prize_label)

	_finish_roll(prize)

	await get_tree().create_timer(1.8).timeout

	var fade = create_tween()
	fade.set_parallel(true)
	for child in reveal_layer.get_children():
		fade.tween_property(child, "modulate:a", 0.0, 0.4)
	await fade.finished

	for child in reveal_layer.get_children():
		child.queue_free()

	rolling = false

func _finish_roll(prize: String):
	if settings == null:
		return
	# Newly unlocked colours are equipped immediately — with one prize type
	# there's nothing to choose between yet, and it makes the unlock visible
	# the moment you go back to the game.
	if settings.unlock_theme(prize):
		settings.set_current_theme(prize)
	refresh_hud()
	refresh_capsule_marks()

# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════

func setup_back_button():
	back_button = TextureButton.new()
	back_button.texture_normal = load("res://assets/images/button_back.png")
	back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_button.custom_minimum_size = Vector2(160, 55)
	back_button.position = Vector2(cabinet.position.x + 20, cabinet.end.y - 70)
	back_button.pressed.connect(_on_back_pressed)
	if settings and settings.has_method("set_hover_cursor"):
		settings.set_hover_cursor(back_button)
	add_child(back_button)

# project.godot maps Escape to "ui-cancel" — with a hyphen. Godot's built-in
# "ui_cancel" (underscore) is a different action and is not what the key is
# bound to.
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
	if _navigating_away:
		return
	if DEBUG_RESET_ENABLED and _is_debug_reset(event):
		_debug_reset()
		get_viewport().set_input_as_handled()
		return
	if _is_back_pressed(event):
		_on_back_pressed()

func _is_debug_reset(event) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_R and event.ctrl_pressed and event.shift_pressed

# Puts the shop back to a fresh state so the gacha can be run through
# again: unlocks wiped, spent stars refunded, and the capsules the claw
# already took put back in the machine.
func _debug_reset():
	if settings == null or rolling:
		return
	settings.debug_reset_themes()

	for capsule in capsules:
		if not is_instance_valid(capsule):
			continue
		if capsule.taken:
			capsule.taken = false
			capsule.visible = true
			capsule.freeze = false
			# Drop it back in from above so it rejoins the pile naturally
			# instead of appearing inside whatever has settled since.
			capsule.position = Vector2(
				randf_range(glass.position.x + CAPSULE_RADIUS, glass.end.x - CAPSULE_RADIUS),
				glass.position.y + CAPSULE_RADIUS
			)
			capsule.linear_velocity = Vector2.ZERO
			capsule.z_index = 20

	refresh_hud()
	refresh_capsule_marks()
	set_status("DEBUG: UNLOCKS RESET, STARS REFUNDED")

func _on_back_pressed():
	if _navigating_away:
		return
	_navigating_away = true
	if click_sound:
		click_sound.play()
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ══════════════════════════════════════════════════════════════
#  DRAWN PARTS
#  All placeholders. Replace with sprites when the art exists.
# ══════════════════════════════════════════════════════════════

class MachineFrame extends Node2D:
	var cabinet: Rect2
	var marquee_height: float = 92.0
	var glass: Rect2
	var chute: Rect2
	# Set from the equipped theme — this is the live preview of the colour
	# the player currently has selected.
	var accent: Color = Color(0.20, 0.35, 0.85)

	func _draw():
		var body = Color(accent.r, accent.g, accent.b, 0.28)
		var edge = accent
		var trim = Color(0.62, 0.10, 0.14)

		draw_rect(cabinet, body, true)
		draw_rect(cabinet, edge, false, 5.0)

		var marquee = Rect2(cabinet.position + Vector2(30, 20),
			Vector2(cabinet.size.x - 60, marquee_height))
		draw_rect(marquee, Color(1, 1, 1, 0.10), true)
		draw_rect(marquee, trim, false, 5.0)

		var bulb_colors = [
			Color(0.98, 0.55, 0.15), Color(0.96, 0.78, 0.28),
			Color(0.55, 0.80, 0.95), Color(0.60, 0.85, 0.25),
		]
		var bulb_count = 12
		for i in range(bulb_count):
			var t = float(i) / float(bulb_count - 1)
			var x = marquee.position.x + 24 + t * (marquee.size.x - 48)
			draw_circle(Vector2(x, marquee.end.y - 4), 8.0, bulb_colors[i % bulb_colors.size()])

		draw_rect(glass, Color(1, 1, 1, 0.06), true)
		draw_rect(glass, edge, false, 4.0)

		draw_rect(chute, Color(0.96, 0.78, 0.28, 0.18), true)
		draw_rect(chute, Color(0.96, 0.78, 0.28), false, 4.0)

# A real rigid body so the capsules pile up and jostle. lock_rotation is
# on deliberately: the ticks and highlights are drawn in local space, and
# a tumbling capsule would spin its tick upside down.
class Capsule extends RigidBody2D:
	var radius: float = 36.0
	var base_color: Color = Color.WHITE
	var theme_id: String = ""
	var taken: bool = false
	var owned: bool = false

	func configure():
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)

		lock_rotation = true
		linear_damp = 0.7
		angular_damp = 3.0
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.75
		physics_material_override.bounce = 0.12

	func _draw():
		draw_circle(Vector2.ZERO, radius, base_color)
		draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(0, 0, 0, 0.28), 2.0)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.35), radius * 0.22, Color(1, 1, 1, 0.35))

		if owned:
			# Dim it and stamp a tick — this colour is already yours.
			draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.42))
			var tick = Color(1, 1, 1, 0.95)
			var thickness = radius * 0.15
			draw_line(Vector2(-radius * 0.34, radius * 0.02),
				Vector2(-radius * 0.08, radius * 0.30), tick, thickness)
			draw_line(Vector2(-radius * 0.08, radius * 0.30),
				Vector2(radius * 0.38, -radius * 0.28), tick, thickness)

# Same look, no physics — used for the reveal so it isn't yanked
# downward by gravity mid-animation.
class RevealCapsule extends Node2D:
	var radius: float = 36.0
	var base_color: Color = Color.WHITE

	func _draw():
		draw_circle(Vector2.ZERO, radius, base_color)
		draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(0, 0, 0, 0.28), 2.0)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.35), radius * 0.22, Color(1, 1, 1, 0.35))

class CapsuleHalf extends Node2D:
	var radius: float = 36.0
	var half_color: Color = Color.WHITE
	var is_top: bool = true

	func _draw():
		# Semicircle built as a fan of arc points. draw_circle can't do half
		# a disc, and a polygon keeps the curved edge smooth.
		var points: PackedVector2Array = []
		var steps := 24
		for i in range(steps + 1):
			var angle = PI * float(i) / float(steps)
			if is_top:
				angle = PI + angle
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		points.append(Vector2.ZERO)
		draw_colored_polygon(points, half_color)
		draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(0, 0, 0, 0.28), 2.0)

class ClawHead extends Node2D:
	var open_amount: float = 1.0
	var cable_length: float = 0.0
	var rail_y: float = 0.0

	func _draw():
		var metal = Color(0.82, 0.84, 0.90)
		var dark = Color(0.35, 0.37, 0.44)

		draw_line(Vector2(0, -cable_length), Vector2.ZERO, dark, 4.0)
		draw_rect(Rect2(-22, -14, 44, 22), metal, true)
		draw_rect(Rect2(-22, -14, 44, 22), dark, false, 3.0)

		var spread = lerpf(8.0, 30.0, open_amount)
		var drop = lerpf(46.0, 34.0, open_amount)
		for side in [-1.0, 1.0]:
			var hinge = Vector2(side * 16, 8)
			var elbow = Vector2(side * spread, 8 + drop * 0.55)
			var tip = Vector2(side * (spread * 0.55), 8 + drop)
			draw_line(hinge, elbow, metal, 7.0)
			draw_line(elbow, tip, metal, 7.0)
			draw_circle(elbow, 4.0, dark)

class PanelButtonFace extends Control:
	var button_color: Color = Color.RED
	# -1 draws a left arrow, 1 a right arrow, 0 leaves the button plain.
	var arrow: int = 0

	func _draw():
		var centre = size / 2.0
		draw_circle(centre, size.x / 2.0, Color(0, 0, 0, 0.45))
		draw_circle(centre, size.x / 2.0 - 4.0, button_color)
		draw_circle(centre - Vector2(size.x * 0.12, size.y * 0.14),
			size.x * 0.14, Color(1, 1, 1, 0.4))

		if arrow != 0:
			var dir = float(arrow)
			var w = size.x * 0.17
			var h = size.y * 0.20
			var points := PackedVector2Array([
				centre + Vector2(dir * w, -h),
				centre + Vector2(dir * w, h),
				centre + Vector2(-dir * w, 0),
			])
			draw_colored_polygon(points, Color(0.1, 0.1, 0.12, 0.9))
