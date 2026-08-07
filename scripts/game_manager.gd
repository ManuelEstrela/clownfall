extends Node2D
class_name GameManager

# Theme manager
var theme_manager = preload("res://scripts/theme_manager.gd").new()

# Preload scenes and script
const ClownBallScene = preload("res://scenes/clown_ball.tscn")
const ClownBallScript = preload("res://scripts/clown_ball.gd")

# ====== EASY POSITIONING & SIZING CONTROLS ======

# SCORE BALLOON (Top Left)
var score_balloon_x: float = 220
var score_balloon_y: float = 155
var score_balloon_scale: float = 1.4

# NEXT BALLOON (Top Right)
var next_balloon_x_offset: float = 210
var next_balloon_y: float = 190
var next_balloon_scale: float = 1.6

# CLOWN CYCLE (Bottom Right decoration)
var clown_cycle_x_offset: float = 220
var clown_cycle_y_offset: float = 200
var clown_cycle_scale: float = 0.9

# BOX CONTAINER - VISUAL ONLY
var box_visual_scale: float = 1.3
var box_vertical_offset: float = 50
var box_visual_offset_y: float = 37

# BOX CONTAINER - COLLISION WALLS
var box_collision_scale: float = 0.95
var wall_horizontal_padding: float = 28.0

# VAN
var van_y_offset: float = 40
var van_scale: float = 0.87

# ====== BALLOON FLOAT ANIMATION ======
var balloon_float_amount: float = 12.0
var balloon_float_duration: float = 4.2

# ====== CONTROLLER ======
var controller_speed: float = 800.0  # pixels per second — tweak to feel right

# ====== MERGE FEEL ======
# Merged clowns used to always spawn at rotation 0 (bolt upright), which made
# every merge look identical and unnaturally tidy. These control how much the
# new clown inherits its orientation/motion from the two clowns that made it.

# How hard the merged clown pops out. (Was hardcoded as 200.)
var merge_pop_strength: float = 200.0
# Random tilt added on top of the inherited rotation, in radians.
# 0.0 = child exactly matches its parents' average tilt. 0.25 ≈ ±14°.
# Raise for messier, more chaotic spawns.
var merge_rotation_jitter: float = 0.25
# How much of the parents' spin the child keeps (0 = none, 1 = full).
var merge_spin_inherit: float = 0.5
# Random spin kick on spawn, in radians/sec.
var merge_spin_jitter: float = 2.0
# How much of the parents' linear velocity carries over (0–1).
var merge_velocity_inherit: float = 0.3
# How much the merge axis bends the pop direction away from straight up.
# 0.0 = always straight up (old behaviour). 1.0 = fully perpendicular to the
# axis between the two parents. 0.35 is a subtle, natural lean.
var merge_axis_influence: float = 0.35

# ====== POLICE JAIL (classic mode only) ======
# Every drop adds exactly 1 Police Heat. When the meter fills, the player
# banks an arrest: press CTRL to enter selection, hover a clown in the
# container, click it, and it is removed from the physics sim and shown
# behind bars.
#
# NOTE: chaotic_manager.gd EXTENDS this script, so it would inherit all of
# this for free. _is_classic_mode() keeps the jail out of chaos mode
# without needing any edit to chaotic_manager.gd.

# How many drops fill the meter once.
var drops_per_arrest: int = 10
# How many clowns fit behind bars (3 columns x 2 rows). Lower this to 3 when
# you want capacity to actually bite and force the player to ration arrests.
var jail_capacity: int = 6
# How many unspent arrests can be held at once.
var max_banked_arrests: int = 1
# How much the hovered clown swells while you're aiming at it.
var arrest_hover_scale: float = 1.28

# Jail panel layout (screen coords — this is where the leaderboard used to sit)
var jail_x: float = 215.0
var jail_y: float = 500.0
var jail_width: float = 300.0
var jail_height: float = 210.0
var jail_meter_height: float = 28.0
var jail_meter_gap: float = 14.0
var jail_slots_per_row: int = 3

# ── HEAT BAR ART ──────────────────────────────────────────────
# Reuses the collection screen's progress bar. The asset is 258x66 and is
# NOT a hollow frame — its interior is solid blue — so a fill drawn behind
# it would be invisible. The fill goes on top instead, inset into the
# interior, with a dark track underneath so "empty" reads as empty.
const HEAT_BAR_ASSET := "res://assets/images/collection/progress_bar.png"
const HEAT_BAR_ASSET_SIZE := Vector2(258.0, 66.0)
# Measured off the PNG: the fillable interior, as fractions of the asset.
# Outside this sits the navy border and the light rim.
const HEAT_BAR_INNER_LEFT := 24.0 / 258.0
const HEAT_BAR_INNER_RIGHT := 232.0 / 258.0
const HEAT_BAR_INNER_TOP := 24.0 / 66.0
const HEAT_BAR_INNER_BOTTOM := 42.0 / 66.0
# Roughly 44% of the asset's height is transparent padding, so the bar you
# actually SEE is centred at this fraction, not at 0.5. Used to line the
# visible bar up with where the old flat meter sat.
const HEAT_BAR_VISIBLE_CENTER := 31.5 / 66.0

# ── JAIL MERGING ──────────────────────────────────────────────
# Two identical clowns in the same jail column merge into the next tier,
# landing in the bottom slot and freeing the top one.
var jail_merge_enabled: bool = true
var jail_merge_awards_score: bool = true
var jail_merge_counts_for_collection: bool = true
# A clown produced BY a jail merge is handcuffed and can never merge again.
# Without this the jail is effectively unlimited: every merge frees a slot,
# so the six cells could be recycled forever. Handcuffing caps it at one
# merge per column — three per run — so a merge is a real trade (a free slot
# now, that column dead afterwards) instead of an infinite supply.
var jail_handcuff_merged: bool = true
# Drop a file here and it replaces the drawn placeholder automatically.
const HANDCUFF_ASSET := "res://assets/images/handcuffs.png"
# Size of the handcuff mark relative to a jail cell.
var handcuff_size_fraction: float = 0.55

# ====== DROP GUIDE LINE (classic mode only) ======
# Dotted vertical line under the van showing where the clown will land.
# The dashes crawl downward so the line always has a little life in it.
var guide_dash_length: float = 9.0
var guide_gap_length: float = 11.0
var guide_thickness: float = 3.0
var guide_scroll_speed: float = 55.0     # px/sec the dashes travel down
var guide_color: Color = Color(1, 1, 1, 0.5)

# ====== DANGER LINE (classic mode only) ======
# Horizontal red line marking the height that ends the run. Hidden while the
# pile is low, fading in as clowns approach so it isn't permanent clutter.
var danger_line_thickness: float = 5.5
var danger_line_color: Color = Color(0.95, 0.22, 0.22)
var danger_line_max_alpha: float = 0.9
# How far below the limit a clown must be before the line starts appearing.
var danger_warning_range: float = 200.0
# Where the real limit sits relative to the top of the container's painted
# walls. 0 puts it exactly on the rim; positive moves it down into the box
# (harsher), negative lifts it above the rim (more forgiving).
var danger_limit_offset: float = 0.0
# A clown must stay inside the warning band this long before the line appears,
# so a clown merely falling past it never flashes the warning up.
var danger_warning_delay: float = 3.0
# Above this speed a clown counts as still in flight, and is ignored by both
# the warning and the game-over test.
var danger_settle_speed: float = 50.0

# ====== SPRITE CLIPPING ======
# Hitboxes are perfect circles but the art isn't, so hair and hats poke
# through the container walls and floor. A shader clips every clown sprite to
# the container's interior. Positive values let art spill that many px past
# the line — raise them if the clip sits inside the painted edge, lower (go
# negative) if art still shows outside it.
var clip_expand_x: float = 0.0
var clip_expand_y: float = 0.0
# Where the container's painted side walls BEGIN, as a fraction of the box
# texture's height. Above this line the sides aren't clipped at all, so a
# clown being dropped over the rim keeps its full hair. This is the number to
# nudge if the side cut doesn't start exactly at the top of the painted walls.
var box_rim_ratio: float = 0.256
# Draws all four clip edges in cyan so you can line them up with the art.
var debug_clip_bounds: bool = false

# ================================================

# Game state
var score: int = 0
var game_over: bool = false
var can_drop: bool = true
var current_clown_type: int = 0
var next_clown_type: int = 0

var debug_hitboxes: bool = false
var test_mode: bool = false
var test_clown_index: int = 0

# Preview clown
var preview_clown = null
var van_sprite: Sprite2D = null
var background_sprite: Sprite2D = null
var clown_cycle_sprite: Sprite2D = null
var box_square_sprite: Sprite2D = null

# UI Elements
var score_balloon: Sprite2D = null
var score_label: Label = null
var next_balloon: Sprite2D = null
var next_clown_sprite: Sprite2D = null

# Balloon group roots
var score_balloon_root: Node2D = null
var next_balloon_root: Node2D = null

# Audio players
var click_sound: AudioStreamPlayer = null
var game_over_sound: AudioStreamPlayer = null
var pop_sounds: Array[AudioStreamPlayer] = []

# Collision sounds (size-grouped)
var collision_sound_small: AudioStreamPlayer = null
var collision_sound_medium: AudioStreamPlayer = null
var collision_sound_large: AudioStreamPlayer = null

# Police Jail state
var jail_enabled: bool = false
var police_heat: int = 0
var arrests_banked: int = 0
# One entry per jail slot, null when empty. Index order is bottom row
# left-to-right, then top row — so slot 0 sits directly below slot 3.
# A plain append-only list can't express this: merging frees a slot in the
# middle, and the next arrest has to be able to refill that gap.
var jail_slots: Array = []
var arrest_mode: bool = false
var hovered_clown = null
var frozen_for_arrest: Array = []

# Police Jail nodes
var jail_root: Node2D = null
var jail_meter_fill: ColorRect = null
# Plain Control, not a Panel: it's now just a positioned container holding
# the bar artwork, the track and the fill. It stopped needing a StyleBox of
# its own the moment the drawn meter was replaced with the asset.
var jail_meter_bg: Control = null
var jail_meter_label: Label = null
var jail_frame: Panel = null
var jail_bars_root: Node2D = null
var jail_prisoners: Node2D = null
var jail_dim_overlay: ColorRect = null

# Drop guide
var drop_guide = null

# Danger line
var danger_line = null
var danger_limit_y: float = 0.0
var danger_warning_timer: float = 0.0

# True only in classic mode. Gates the features chaos mode shouldn't inherit.
var classic_features: bool = false

# Sprite clipping
var clip_material: ShaderMaterial = null
var clip_left: float = 0.0
var clip_right: float = 0.0
var clip_bottom: float = 0.0
var clip_top: float = 0.0

# Boundaries
var play_area_left: float
var play_area_right: float
var drop_y: float
var danger_y: float
var floor_top_y: float
var container_center_x: float
var container_center_y: float

# Signals
signal score_changed(new_score: int)
signal game_over_triggered(final_score: int)
signal clown_dropped(clown_type: int)
signal arrest_banked()
signal clown_arrested(clown_type: int)

func _ready():
	randomize()

	if debug_hitboxes:
		print("🔍 DEBUG MODE: Hitbox visualization ENABLED")
		get_tree().debug_collisions_hint = true

	var viewport_size = get_viewport_rect().size

	container_center_x = viewport_size.x / 2.0
	container_center_y = (viewport_size.y / 2.0) + box_vertical_offset

	# Background
	background_sprite = Sprite2D.new()
	background_sprite.texture = load("res://assets/images/landing_background.png")
	background_sprite.z_index = -100
	add_child(background_sprite)
	background_sprite.position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
	var bg_scale_x = viewport_size.x / background_sprite.texture.get_width()
	var bg_scale_y = viewport_size.y / background_sprite.texture.get_height()
	var bg_scale = max(bg_scale_x, bg_scale_y)
	background_sprite.scale = Vector2(bg_scale, bg_scale)

	# Container sprite
	var container = $Container
	container.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)
	container.z_index = 0
	container.texture = theme_manager.get_box_texture()

	var original_width = 1024.0
	var original_height = 1536.0
	var target_height = viewport_size.y * box_collision_scale
	var container_scale = target_height / original_height
	var visual_scale = container_scale * box_visual_scale
	container.scale = Vector2(visual_scale, visual_scale)

	# Box square overlay
	box_square_sprite = Sprite2D.new()
	box_square_sprite.texture = theme_manager.get_box_square_texture()
	box_square_sprite.z_index = 150
	add_child(box_square_sprite)
	box_square_sprite.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)
	box_square_sprite.scale = Vector2(visual_scale, visual_scale)
	print("🎨 Box square overlay added on top")

	# Collision walls
	var scaled_width = original_width * container_scale
	var scaled_height = original_height * container_scale
	var container_half_width = scaled_width / 2.0
	var container_half_height = scaled_height / 2.0
	var wall_thickness = 40.0 * container_scale
	var side_padding = 25.0 * container_scale
	var top_padding = 180.0 * container_scale

	play_area_left = container_center_x - container_half_width + side_padding + (wall_horizontal_padding * container_scale)
	play_area_right = container_center_x + container_half_width - side_padding - (wall_horizontal_padding * container_scale)
	drop_y = container_center_y - container_half_height + top_padding
	danger_y = drop_y + 120

	var left_wall_collision = $Walls/StaticBody2D/LeftWall
	var floor_collision = $Walls/StaticBody2D2/Floor
	var right_wall_collision = $Walls/StaticBody2D3/RightWall

	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(wall_thickness, scaled_height)
	left_wall_collision.shape = left_shape
	left_wall_collision.position = Vector2(
		container_center_x - container_half_width + wall_thickness/2 + (wall_horizontal_padding * container_scale),
		container_center_y
	)

	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(wall_thickness, scaled_height)
	right_wall_collision.shape = right_shape
	right_wall_collision.position = Vector2(
		container_center_x + container_half_width - wall_thickness/2 - (wall_horizontal_padding * container_scale),
		container_center_y
	)

	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(scaled_width - (side_padding * 2), wall_thickness)
	floor_collision.shape = floor_shape
	var container_floor_offset = 200.0 * container_scale
	floor_collision.position = Vector2(
		container_center_x,
		container_center_y + container_half_height - container_floor_offset
	)

	# Top surface of the floor — the drop guide falls back to this when the
	# raycast finds nothing in the way.
	floor_top_y = floor_collision.position.y - wall_thickness / 2.0

	# Interior faces of the container, used for sprite clipping and for
	# sizing the danger line.
	clip_left = container_center_x - container_half_width + wall_thickness \
		+ (wall_horizontal_padding * container_scale) - clip_expand_x
	clip_right = container_center_x + container_half_width - wall_thickness \
		- (wall_horizontal_padding * container_scale) + clip_expand_x
	clip_bottom = floor_top_y + clip_expand_y

	# Top of the container's painted side walls. The collision walls actually
	# run much higher than the art does — they reach up past the rim to catch
	# clowns before they enter the box — so the walls can't tell us where the
	# painted sides start. We take it from the box texture instead.
	var box_drawn_height = original_height * visual_scale
	var box_top_y = (container_center_y + box_visual_offset_y) - box_drawn_height / 2.0
	clip_top = box_top_y + box_drawn_height * box_rim_ratio

	# The real game-over height. Sits on the rim by default, which is also
	# where the red line gets drawn — the two are the same number so the line
	# can't lie about where the limit is.
	danger_limit_y = clip_top + danger_limit_offset

	print("=== Game Setup ===")
	print("Viewport size: ", viewport_size)

	setup_audio()

	if test_mode:
		print("=== TEST MODE: Dropping all clowns in order ===")
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		current_clown_type = randi() % 5
		next_clown_type = randi() % 5

	setup_ui_balloons(viewport_size, container_scale)
	update_next_preview()

	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(van_scale, van_scale) * container_scale
	van_sprite.z_index = 100
	add_child(van_sprite)
	van_sprite.global_position = Vector2(container_center_x, drop_y - van_y_offset)

	add_clown_cycle_decoration(viewport_size, container_scale)
	spawn_preview()

	# ── Classic-mode-only features ──
	if _is_classic_mode():
		classic_features = true
		jail_enabled = true
		hide_leaderboard()
		setup_police_jail()
		setup_drop_guide()
		setup_clip_material()
		setup_danger_line()
		if debug_clip_bounds:
			draw_debug_clip_bounds()

func setup_audio():
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/assets_click.mp3")
	click_sound.volume_db = 0
	click_sound.bus = "SFX"
	add_child(click_sound)

	game_over_sound = AudioStreamPlayer.new()
	game_over_sound.stream = load("res://assets/sounds/game_over.mp3")
	game_over_sound.volume_db = 0
	game_over_sound.bus = "SFX"
	add_child(game_over_sound)

	for i in range(11):
		var pop_player = AudioStreamPlayer.new()
		pop_player.stream = load("res://assets/sounds/assets_pop" + str(i) + ".mp3")
		pop_player.volume_db = 0
		pop_player.bus = "SFX"
		add_child(pop_player)
		pop_sounds.append(pop_player)

	collision_sound_small = AudioStreamPlayer.new()
	collision_sound_small.stream = load("res://assets/sounds/collision/clown_collision_1.wav")
	collision_sound_small.volume_db = 0
	collision_sound_small.bus = "SFX"
	add_child(collision_sound_small)

	collision_sound_medium = AudioStreamPlayer.new()
	collision_sound_medium.stream = load("res://assets/sounds/collision/clown_collision_2.wav")
	collision_sound_medium.volume_db = 0
	collision_sound_medium.bus = "SFX"
	add_child(collision_sound_medium)

	collision_sound_large = AudioStreamPlayer.new()
	collision_sound_large.stream = load("res://assets/sounds/collision/clown_collision_3.wav")
	collision_sound_large.volume_db = 0
	collision_sound_large.bus = "SFX"
	add_child(collision_sound_large)

	print("✅ Audio setup complete (including collision sounds)!")

func setup_ui_balloons(viewport_size: Vector2, container_scale: float):
	var balloon_texture = theme_manager.get_balloon_texture()
	var custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	# ── SCORE GROUP ──────────────────────────────────────────────
	score_balloon_root = Node2D.new()
	score_balloon_root.z_index = 200
	score_balloon_root.position = Vector2(score_balloon_x, score_balloon_y)
	add_child(score_balloon_root)

	score_balloon = Sprite2D.new()
	score_balloon.texture = balloon_texture
	var final_score_scale = score_balloon_scale * container_scale
	score_balloon.scale = Vector2(final_score_scale, final_score_scale)
	score_balloon.position = Vector2.ZERO
	score_balloon_root.add_child(score_balloon)

	score_label = Label.new()
	score_balloon.add_child(score_label)
	if custom_font:
		score_label.add_theme_font_override("font", custom_font)
	score_label.add_theme_font_size_override("font_size", int(48 / final_score_scale))
	score_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	score_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	score_label.add_theme_constant_override("outline_size", int(2 / final_score_scale))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.position = Vector2(-80 / final_score_scale, -50 / final_score_scale)
	score_label.size = Vector2(160 / final_score_scale, 80 / final_score_scale)
	score_label.text = "0"

	# ── NEXT GROUP ───────────────────────────────────────────────
	next_balloon_root = Node2D.new()
	next_balloon_root.z_index = 200
	next_balloon_root.position = Vector2(viewport_size.x - next_balloon_x_offset, next_balloon_y)
	add_child(next_balloon_root)

	next_balloon = Sprite2D.new()
	next_balloon.texture = balloon_texture
	var final_next_scale = next_balloon_scale * container_scale
	next_balloon.scale = Vector2(final_next_scale, final_next_scale)
	next_balloon.position = Vector2.ZERO
	next_balloon_root.add_child(next_balloon)

	var next_label = Label.new()
	next_balloon.add_child(next_label)
	if custom_font:
		next_label.add_theme_font_override("font", custom_font)
	next_label.add_theme_font_size_override("font_size", int(32 / final_next_scale))
	next_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	next_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	next_label.add_theme_constant_override("outline_size", int(2 / final_next_scale))
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.position = Vector2(-60 / final_next_scale, -80 / final_next_scale)
	next_label.size = Vector2(120 / final_next_scale, 40 / final_next_scale)
	next_label.text = "NEXT"

	next_clown_sprite = Sprite2D.new()
	next_balloon.add_child(next_clown_sprite)
	next_clown_sprite.z_index = 1
	next_clown_sprite.position = Vector2(0, 10 / final_next_scale)

	# ── START FLOAT ANIMATIONS ───────────────────────────────────
	_start_balloon_float(score_balloon_root, 0.0)
	_start_balloon_float(next_balloon_root, balloon_float_duration * 0.4)

func _start_balloon_float(root: Node2D, phase_offset: float):
	var rest_y = root.position.y

	var start_tween = func():
		var tween = create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(root, "position:y",
			rest_y - balloon_float_amount,
			balloon_float_duration / 2.0)
		tween.tween_property(root, "position:y",
			rest_y + balloon_float_amount,
			balloon_float_duration / 2.0)

	if phase_offset > 0.0:
		await get_tree().create_timer(phase_offset).timeout
	start_tween.call()

func add_clown_cycle_decoration(viewport_size: Vector2, container_scale: float):
	clown_cycle_sprite = Sprite2D.new()
	clown_cycle_sprite.texture = theme_manager.get_clown_cycle_texture()
	clown_cycle_sprite.z_index = 5
	add_child(clown_cycle_sprite)

	var cycle_x = play_area_right + clown_cycle_x_offset
	var cycle_y = viewport_size.y - clown_cycle_y_offset
	clown_cycle_sprite.global_position = Vector2(cycle_x, cycle_y)
	clown_cycle_sprite.scale = Vector2(clown_cycle_scale, clown_cycle_scale) * container_scale

# ══════════════════════════════════════════════════════════════════════
#  POLICE JAIL — SETUP
# ══════════════════════════════════════════════════════════════════════

# chaotic_manager.gd extends this script, so without this check chaos mode
# would build a jail too. scene_file_path is the .tscn this node is the root
# of, which tells the two modes apart with no edit to chaotic_manager.gd.
func _is_classic_mode() -> bool:
	return scene_file_path == "res://scenes/game_world_normal.tscn"

# The jail takes over the leaderboard's slot on screen, so the leaderboard
# gets hidden rather than deleted — no scene edit needed, and chaos mode
# keeps its leaderboard untouched.
func hide_leaderboard():
	var found = _find_leaderboard(get_tree().current_scene)
	if found:
		found.visible = false
		print("🚔 Leaderboard hidden — Police Jail takes its place")

func _find_leaderboard(node: Node):
	if node == null:
		return null
	var s = node.get_script()
	if s and s.resource_path.ends_with("leaderboard_ui.gd"):
		return node
	for child in node.get_children():
		var found = _find_leaderboard(child)
		if found:
			return found
	return null

func setup_police_jail():
	var custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")
	var accent = _jail_accent_color()

	# Dim overlay shown only while choosing a target. z_index sits between
	# the background (-100) and the container (0), so it darkens the backdrop
	# while leaving every clown fully lit. Careful if you change this: clowns
	# use z_index = 100 - (clown_type * 10), so Kirk sits at 0 — any positive
	# value here would dim the biggest clowns, the ones you most want to see.
	jail_dim_overlay = ColorRect.new()
	jail_dim_overlay.color = Color(0, 0, 0, 0.45)
	jail_dim_overlay.size = get_viewport_rect().size
	jail_dim_overlay.position = Vector2.ZERO
	jail_dim_overlay.z_index = -50
	jail_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_dim_overlay.visible = false
	add_child(jail_dim_overlay)

	jail_root = Node2D.new()
	jail_root.position = Vector2(jail_x, jail_y)
	jail_root.z_index = 200
	add_child(jail_root)

	var half = Vector2(jail_width / 2.0, jail_height / 2.0)

	# ── Heat meter ──
	# Drawn at the asset's true 258:66 ratio, never squashed. Because the
	# PNG carries transparent padding, the bar only LOOKS about 43px tall at
	# this width — it's positioned by its visible centre so it lands where
	# the old flat meter sat rather than where its bounding box would.
	var bar_scale = jail_width / HEAT_BAR_ASSET_SIZE.x
	var bar_size = HEAT_BAR_ASSET_SIZE * bar_scale
	var old_meter_center_y = -half.y - jail_meter_gap - jail_meter_height / 2.0
	var bar_top = old_meter_center_y - bar_size.y * HEAT_BAR_VISIBLE_CENTER

	jail_meter_bg = Control.new()
	jail_meter_bg.size = bar_size
	jail_meter_bg.position = Vector2(-half.x, bar_top)
	jail_meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_root.add_child(jail_meter_bg)

	# Interior region of the asset, in local pixels.
	var inner_x = bar_size.x * HEAT_BAR_INNER_LEFT
	var inner_w = bar_size.x * (HEAT_BAR_INNER_RIGHT - HEAT_BAR_INNER_LEFT)
	var inner_y = bar_size.y * HEAT_BAR_INNER_TOP
	var inner_h = bar_size.y * (HEAT_BAR_INNER_BOTTOM - HEAT_BAR_INNER_TOP)

	# The artwork goes down FIRST, with the track and fill layered over its
	# interior. The other way round doesn't work: the asset's interior is
	# opaque blue, so drawing it last would simply hide the fill. Painting
	# over the interior leaves the border and rim showing as a frame.
	var bar_art = TextureRect.new()
	bar_art.texture = load(HEAT_BAR_ASSET)
	bar_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_art.stretch_mode = TextureRect.STRETCH_SCALE
	bar_art.size = bar_size
	bar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_meter_bg.add_child(bar_art)

	# Dark track next. Without it an empty meter would show the asset's own
	# blue interior and read as already full.
	var track = ColorRect.new()
	track.color = Color(0.02, 0.05, 0.13, 1.0)
	track.position = Vector2(inner_x, inner_y)
	track.size = Vector2(inner_w, inner_h)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_meter_bg.add_child(track)

	# ── Heat meter fill (colour-shifting, as before) ──
	jail_meter_fill = ColorRect.new()
	jail_meter_fill.color = Color(0.35, 0.62, 0.95)
	jail_meter_fill.position = Vector2(inner_x, inner_y)
	jail_meter_fill.size = Vector2(0, inner_h)
	jail_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_meter_bg.add_child(jail_meter_fill)
	# Stored so update_jail_ui knows how wide "full" is without recomputing.
	jail_meter_fill.set_meta("full_width", inner_w)

	# ── Meter label (this is the only status text — it doubles as the
	#    prompt once an arrest is banked) ──
	jail_meter_label = Label.new()
	if custom_font:
		jail_meter_label.add_theme_font_override("font", custom_font)
	jail_meter_label.add_theme_font_size_override("font_size", 16)
	jail_meter_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	jail_meter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	jail_meter_label.add_theme_constant_override("outline_size", 4)
	jail_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jail_meter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jail_meter_label.size = Vector2(bar_size.x, inner_h + 6)
	jail_meter_label.position = Vector2(0, inner_y - 3)
	jail_meter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jail_meter_bg.add_child(jail_meter_label)

	# ── Cell frame (back wall) ──
	jail_frame = Panel.new()
	jail_frame.size = Vector2(jail_width, jail_height)
	jail_frame.position = -half
	jail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.10, 0.09, 0.13, 0.92)
	frame_style.border_color = accent.darkened(0.45)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(10)
	jail_frame.add_theme_stylebox_override("panel", frame_style)
	jail_root.add_child(jail_frame)

	# ── Prisoners layer (between wall and bars) ──
	jail_prisoners = Node2D.new()
	jail_prisoners.z_index = 1
	jail_root.add_child(jail_prisoners)

	# ── Bars, drawn in front of the prisoners ──
	jail_bars_root = Node2D.new()
	jail_bars_root.z_index = 2
	jail_root.add_child(jail_bars_root)

	var bar_count = 7
	var bar_margin = 16.0
	var span = jail_width - bar_margin * 2.0
	for i in range(bar_count):
		var bar = ColorRect.new()
		bar.color = Color(0.78, 0.80, 0.86, 0.95)
		bar.size = Vector2(5, jail_height - 28)
		bar.position = Vector2(
			-half.x + bar_margin + span * (float(i) / float(bar_count - 1)) - 2.5,
			-half.y + 14
		)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jail_bars_root.add_child(bar)

	# Top and bottom rails
	for y in [-half.y + 16.0, half.y - 21.0]:
		var rail = ColorRect.new()
		rail.color = Color(0.78, 0.80, 0.86, 0.95)
		rail.size = Vector2(jail_width - bar_margin * 2.0 + 8, 5)
		rail.position = Vector2(-half.x + bar_margin - 4, y)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jail_bars_root.add_child(rail)

	jail_slots.clear()
	jail_slots.resize(jail_capacity)

	update_jail_ui()

# Matches the jail to whichever UI theme is active.
func _jail_accent_color() -> Color:
	match theme_manager.current_theme:
		"blue":   return Color(0.35, 0.55, 0.95)
		"green":  return Color(0.40, 0.80, 0.45)
		"pink":   return Color(0.95, 0.50, 0.72)
		"red":    return Color(0.92, 0.38, 0.38)
		"yellow": return Color(0.96, 0.78, 0.28)
		_:        return Color(0.62, 0.42, 0.92)

# ══════════════════════════════════════════════════════════════════════
#  POLICE JAIL — HEAT
# ══════════════════════════════════════════════════════════════════════

func add_police_heat():
	if not jail_enabled or game_over:
		return
	# Meter pins when there's nowhere to put a prisoner, or the player is
	# already sitting on an unspent arrest.
	if is_jail_full() or arrests_banked >= max_banked_arrests:
		update_jail_ui()
		return

	police_heat += 1
	if police_heat >= drops_per_arrest:
		police_heat = 0
		arrests_banked += 1
		arrest_banked.emit()
		pulse_jail_frame()
	update_jail_ui()

func is_jail_full() -> bool:
	return jail_occupied_count() >= jail_capacity

func jail_occupied_count() -> int:
	var count := 0
	for slot in jail_slots:
		if slot != null:
			count += 1
	return count

# Lowest free slot. Bottom row fills left to right, then the top row — and
# because merging empties a slot mid-row, this deliberately scans for the
# first gap rather than appending to the end.
func first_free_jail_slot() -> int:
	for i in range(jail_slots.size()):
		if jail_slots[i] == null:
			return i
	return -1

func can_arrest() -> bool:
	return jail_enabled and not game_over and arrests_banked > 0 and not is_jail_full()

func heat_ratio() -> float:
	if is_jail_full() or arrests_banked >= max_banked_arrests:
		return 1.0
	return clampf(float(police_heat) / float(max(1, drops_per_arrest)), 0.0, 1.0)

func update_jail_ui():
	if not jail_enabled or jail_meter_fill == null:
		return

	var ratio = heat_ratio()
	var full_width = jail_meter_fill.get_meta("full_width", jail_width - 10.0)
	var target_width = full_width * ratio

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(jail_meter_fill, "size:x", target_width, 0.25)

	# Cool blue when calm, hot red as the heat builds.
	jail_meter_fill.color = Color(0.35, 0.62, 0.95).lerp(Color(0.95, 0.28, 0.25), ratio)

	if jail_meter_label and not arrest_mode:
		if is_jail_full():
			jail_meter_label.text = "JAIL FULL  %d/%d" % [jail_occupied_count(), jail_capacity]
		elif arrests_banked > 0:
			jail_meter_label.text = "PRESS CTRL TO ARREST"
		else:
			jail_meter_label.text = "POLICE HEAT %d/%d" % [police_heat, drops_per_arrest]

func pulse_jail_frame():
	if jail_frame == null:
		return
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(jail_frame, "modulate", Color(1.7, 1.7, 1.7), 0.12)
	tween.tween_property(jail_frame, "modulate", Color.WHITE, 0.35)

# ══════════════════════════════════════════════════════════════════════
#  POLICE JAIL — SELECTION
# ══════════════════════════════════════════════════════════════════════

# Everything the player is allowed to arrest. Deliberately excludes the
# preview clown (which is also a ClownBall child of this node), anything
# already frozen, and anything committed to a merge.
func get_arrestable_clowns() -> Array:
	var result: Array = []
	if game_over:
		return result
	for child in get_children():
		if not (child is ClownBall):
			continue
		if child == preview_clown:
			continue
		if child.is_merging or not child.can_merge:
			continue
		if child.freeze and not frozen_for_arrest.has(child):
			continue
		result.append(child)
	return result

func enter_arrest_mode():
	if arrest_mode or not can_arrest():
		return

	arrest_mode = true

	# "Pause" the pile. We can't use get_tree().paused — the pause menu owns
	# that — and RigidBody2D.freeze zeroes velocity, so we stash each body's
	# motion first and hand it back on exit. Freezing also stops merges and
	# the danger-zone timer, since clown_ball.gd and check_danger_zone both
	# skip frozen bodies. That's exactly what we want while aiming.
	frozen_for_arrest.clear()
	for child in get_children():
		if not (child is ClownBall):
			continue
		if child == preview_clown or child.freeze:
			continue
		child.set_meta("arrest_saved_linear", child.linear_velocity)
		child.set_meta("arrest_saved_angular", child.angular_velocity)
		child.freeze = true
		frozen_for_arrest.append(child)

	if jail_dim_overlay:
		jail_dim_overlay.visible = true
	if jail_meter_label:
		jail_meter_label.text = "CLICK A CLOWN"

func exit_arrest_mode():
	if not arrest_mode:
		return

	arrest_mode = false
	clear_hover()

	for clown in frozen_for_arrest:
		if not is_instance_valid(clown):
			continue
		clown.freeze = false
		if clown.has_meta("arrest_saved_linear"):
			clown.linear_velocity = clown.get_meta("arrest_saved_linear")
			clown.remove_meta("arrest_saved_linear")
		if clown.has_meta("arrest_saved_angular"):
			clown.angular_velocity = clown.get_meta("arrest_saved_angular")
			clown.remove_meta("arrest_saved_angular")
		# The clown sat still while frozen, so don't let stale danger time
		# carry over into an instant game over on resume.
		if clown.has_meta("danger_timer"):
			clown.set_meta("danger_timer", 0.0)
	frozen_for_arrest.clear()

	if jail_dim_overlay:
		jail_dim_overlay.visible = false
	update_jail_ui()

func update_arrest_hover():
	var mouse = get_viewport().get_mouse_position()
	var found = clown_under_point(mouse)
	if found == hovered_clown:
		return

	clear_hover()

	if is_instance_valid(found):
		hovered_clown = found
		var sprite = found.get_node_or_null("Sprite")
		if sprite:
			# Scale the SPRITE, never the RigidBody2D — scaling the body
			# doesn't scale its collision shape and desyncs the physics.
			found.set_meta("arrest_base_scale", sprite.scale)
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", sprite.scale * arrest_hover_scale, 0.15)
		found.modulate = Color(1.35, 1.18, 0.6)

func clear_hover():
	if is_instance_valid(hovered_clown):
		var sprite = hovered_clown.get_node_or_null("Sprite")
		if sprite and hovered_clown.has_meta("arrest_base_scale"):
			var base = hovered_clown.get_meta("arrest_base_scale")
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", base, 0.12)
			hovered_clown.remove_meta("arrest_base_scale")
		hovered_clown.modulate = Color.WHITE
	hovered_clown = null

func clown_under_point(point: Vector2):
	var best = null
	var best_distance := INF
	for clown in get_arrestable_clowns():
		if not is_instance_valid(clown):
			continue
		var d = clown.global_position.distance_to(point)
		# merge_radius is cached in ClownBall.setup(); fall back if unset.
		var radius = clown.merge_radius if clown.merge_radius > 0.0 else clown.clown_size / 2.0
		if d <= radius and d < best_distance:
			best = clown
			best_distance = d
	return best

func confirm_arrest():
	if not is_instance_valid(hovered_clown):
		return

	var target = hovered_clown
	# Take it off the frozen list first — exit_arrest_mode must not try to
	# unfreeze a node that's on its way out.
	frozen_for_arrest.erase(target)
	hovered_clown = null

	var clown_type: int = target.clown_type
	var from_pos: Vector2 = target.global_position
	var texture: Texture2D = null
	var sprite = target.get_node_or_null("Sprite")
	if sprite:
		texture = sprite.texture

	remove_clown(target)

	arrests_banked -= 1

	var slot = first_free_jail_slot()

	var settings = get_node_or_null("/root/SettingsManager")
	if settings and settings.has_method("add_clown_arrest"):
		settings.add_clown_arrest(clown_type)

	exit_arrest_mode()

	if slot == -1:
		# Shouldn't happen — can_arrest() blocks a full jail — but bail
		# rather than dropping a sprite at an undefined position.
		update_jail_ui()
		return

	send_to_jail_visual(texture, from_pos, slot, clown_type)
	clown_arrested.emit(clown_type)

	if is_jail_full():
		police_heat = 0

	update_jail_ui()

# Pull a clown out of the simulation safely.
#
# Order matters. A queue_free'd node stays is_instance_valid() until the end
# of the frame, and clown_ball.gd's safety-net scan runs on EVERY ball each
# physics tick — so without marking this one unavailable first, a neighbour
# can still pick it as a merge partner and call merge_clowns() on a node
# that's already on its way out.
func remove_clown(clown) -> void:
	if not is_instance_valid(clown):
		return
	if has_meta("last_dropped_clown") and get_meta("last_dropped_clown") == clown:
		remove_meta("last_dropped_clown")
	clown.can_merge = false
	clown.is_merging = true
	clown.queue_free()

# ══════════════════════════════════════════════════════════════════════
#  POLICE JAIL — PRISONER DISPLAY
# ══════════════════════════════════════════════════════════════════════

func jail_cell_position(index: int) -> Vector2:
	var rows = int(ceil(float(jail_capacity) / float(jail_slots_per_row)))
	var row = index / jail_slots_per_row
	var col = index % jail_slots_per_row

	var usable_w = jail_width - 44.0
	var usable_h = jail_height - 56.0
	var cell_w = usable_w / float(jail_slots_per_row)
	var cell_h = usable_h / float(max(1, rows))

	# Fill from the bottom row up so prisoners rest on the floor.
	var x = -usable_w / 2.0 + cell_w * (col + 0.5)
	var y = usable_h / 2.0 - cell_h * (row + 0.5) + 14.0
	return Vector2(x, y)

func jail_cell_size() -> float:
	var rows = int(ceil(float(jail_capacity) / float(jail_slots_per_row)))
	var cell_w = (jail_width - 44.0) / float(jail_slots_per_row)
	var cell_h = (jail_height - 56.0) / float(max(1, rows))
	return min(cell_w, cell_h) * 0.85

# The arrested body is gone by now; this is a plain Sprite2D stand-in that
# flies from the container into the cell. There's no Camera2D in this
# project, so world coords and screen coords line up directly.
func send_to_jail_visual(texture: Texture2D, from_pos: Vector2, index: int, clown_type: int):
	if jail_prisoners == null:
		return
	if texture == null:
		texture = load(ClownBallScript.CLOWNS[clown_type].image)

	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	jail_prisoners.add_child(sprite)

	var start_scale = ClownBallScript.CLOWNS[clown_type].size / float(texture.get_width())
	var end_scale = jail_cell_size() / float(texture.get_width())

	sprite.global_position = from_pos
	sprite.scale = Vector2.ONE * start_scale

	var target_local = jail_cell_position(index)

	jail_slots[index] = {"type": clown_type, "sprite": sprite, "handcuffed": false}

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", target_local, 0.5)
	tween.tween_property(sprite, "scale", Vector2.ONE * end_scale, 0.5)
	tween.tween_property(sprite, "rotation", randf_range(-0.2, 0.2), 0.5)

	print("🚔 ", ClownBallScript.CLOWNS[clown_type].name, " sent to jail (",
		jail_occupied_count(), "/", jail_capacity, ")")

	# Wait for the prisoner to land before checking the column, so the merge
	# reads as a reaction to it arriving rather than happening mid-flight.
	tween.chain().tween_callback(func(): check_jail_merge(index))

# Two identical clowns stacked in the same column merge into the next tier.
#
# Only ever checks a column (bottom slot vs the one directly above it), which
# is why no cascade is possible: with two rows, a merge leaves the column
# holding exactly one clown. If you ever add a third row this needs to loop.
func check_jail_merge(placed_index: int):
	if not jail_merge_enabled or game_over:
		return
	if placed_index < 0 or placed_index >= jail_slots.size():
		return

	var column = placed_index % jail_slots_per_row
	var bottom = column
	var top = column + jail_slots_per_row
	if top >= jail_slots.size():
		return

	var bottom_slot = jail_slots[bottom]
	var top_slot = jail_slots[top]
	if bottom_slot == null or top_slot == null:
		return
	if bottom_slot.type != top_slot.type:
		return
	# A handcuffed clown is out of the merge pool for good, and so is
	# anything stacked on top of it.
	if bottom_slot.get("handcuffed", false) or top_slot.get("handcuffed", false):
		return
	# Top-tier clown has nothing to become.
	if bottom_slot.type >= ClownBallScript.CLOWNS.size() - 1:
		return

	var new_type = bottom_slot.type + 1
	merge_jail_pair(bottom, top, new_type)

func merge_jail_pair(bottom: int, top: int, new_type: int):
	var bottom_sprite = jail_slots[bottom].sprite
	var top_sprite = jail_slots[top].sprite

	# Free both slots up front. The animation runs afterwards, and an arrest
	# landing mid-animation must not be handed a slot that still looks taken.
	jail_slots[bottom] = null
	jail_slots[top] = null

	var landing = jail_cell_position(bottom)

	# Slide the upper one down onto the lower one, then swap both for the
	# merged clown — same shape as a container merge, just on a grid.
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(top_sprite):
		tween.tween_property(top_sprite, "position", landing, 0.22)
	if is_instance_valid(bottom_sprite):
		tween.tween_property(bottom_sprite, "modulate:a", 0.0, 0.22)
	await tween.finished

	if is_instance_valid(top_sprite):
		top_sprite.queue_free()
	if is_instance_valid(bottom_sprite):
		bottom_sprite.queue_free()

	var texture = load(ClownBallScript.CLOWNS[new_type].image)
	var merged = Sprite2D.new()
	merged.texture = texture
	merged.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	jail_prisoners.add_child(merged)

	var end_scale = jail_cell_size() / float(texture.get_width())
	merged.position = landing
	merged.scale = Vector2.ONE * end_scale * 0.4
	merged.rotation = randf_range(-0.2, 0.2)

	jail_slots[bottom] = {
		"type": new_type,
		"sprite": merged,
		"handcuffed": jail_handcuff_merged,
	}

	if jail_handcuff_merged:
		add_handcuff_mark(merged, end_scale)

	var pop = create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(merged, "scale", Vector2.ONE * end_scale, 0.28)

	if new_type < pop_sounds.size():
		pop_sounds[new_type].play()

	if jail_merge_awards_score:
		score += ClownBallScript.CLOWNS[new_type].score
		score_changed.emit(score)
		if score_label:
			score_label.text = str(score)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings and jail_merge_counts_for_collection:
		settings.update_highest_tier(new_type)
		settings.add_clown_merge(new_type)

	print("🚔 Jail merge -> ", ClownBallScript.CLOWNS[new_type].name)

	update_jail_ui()

# Stamps the handcuff marker over a jailed clown.
#
# The marker is a CHILD of the sprite, with its scale inverted against the
# sprite's own. That keeps it authored in screen pixels regardless of how
# far the clown's texture had to be scaled down to fit its cell, while
# still riding along with the pop tween and getting freed automatically
# when the sprite does.
func add_handcuff_mark(sprite: Sprite2D, sprite_scale: float):
	if sprite == null or sprite_scale <= 0.0:
		return

	var mark_size = jail_cell_size() * handcuff_size_fraction

	if ResourceLoader.exists(HANDCUFF_ASSET):
		var texture = load(HANDCUFF_ASSET)
		var icon = Sprite2D.new()
		icon.texture = texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		icon.scale = Vector2.ONE * (mark_size / float(texture.get_width())) / sprite_scale
		sprite.add_child(icon)
		return

	var mark = HandcuffMark.new()
	mark.mark_size = mark_size
	mark.scale = Vector2.ONE / sprite_scale
	sprite.add_child(mark)

# Placeholder handcuffs: two open rings and a short chain, drawn as outlines
# so the clown's face still reads through them.
class HandcuffMark extends Node2D:
	var mark_size: float = 26.0

	func _draw():
		var metal = Color(0.88, 0.90, 0.96)
		var dark = Color(0.10, 0.11, 0.15)
		var ring = mark_size * 0.30
		var offset = mark_size * 0.36
		var thickness = mark_size * 0.11

		draw_line(Vector2(-offset, 0), Vector2(offset, 0), dark, thickness * 1.7)
		draw_line(Vector2(-offset, 0), Vector2(offset, 0), metal, thickness)

		for side in [-1.0, 1.0]:
			var centre = Vector2(side * offset, 0)
			draw_arc(centre, ring, 0, TAU, 28, dark, thickness * 1.7, true)
			draw_arc(centre, ring, 0, TAU, 28, metal, thickness, true)

# ══════════════════════════════════════════════════════════════════════
#  SPRITE CLIPPING
#
#  The obvious fix — parent every clown to a node with clip_children set —
#  isn't available here. clown_ball.gd reaches the manager through
#  get_parent(), and _scan_for_missed_merge() walks get_parent()'s children,
#  so clowns have to stay direct children of this node. Reparenting them
#  under a clipping node would silently break merging.
#
#  Instead each clown's Sprite2D gets a shader that discards any fragment
#  outside the container's interior. No reparenting, no physics changes, and
#  the collision circles are untouched — this is purely what gets drawn.
#  The top is deliberately NOT clipped: clowns above the rim must stay
#  visible, since that's the danger zone.
# ══════════════════════════════════════════════════════════════════════

const CLIP_SHADER_CODE := """
shader_type canvas_item;

uniform float clip_left;
uniform float clip_right;
uniform float clip_bottom;
uniform float clip_top;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Floor: always clipped, nothing should ever show under the box.
	if (world_pos.y > clip_bottom) {
		discard;
	}
	// Sides: only clipped from the rim downward. Above the rim there are no
	// painted walls to hide behind, so a clown being dropped near the left or
	// right edge must keep its full silhouette.
	if (world_pos.y > clip_top && (world_pos.x < clip_left || world_pos.x > clip_right)) {
		discard;
	}
}
"""

func setup_clip_material():
	var shader = Shader.new()
	shader.code = CLIP_SHADER_CODE

	# One shared material across every clown — the bounds are identical, so
	# there's no reason to allocate one per ball.
	clip_material = ShaderMaterial.new()
	clip_material.shader = shader
	clip_material.set_shader_parameter("clip_left", clip_left)
	clip_material.set_shader_parameter("clip_right", clip_right)
	clip_material.set_shader_parameter("clip_bottom", clip_bottom)
	clip_material.set_shader_parameter("clip_top", clip_top)

# Called for every clown that lives in the container. NOT called for the
# preview clown: it floats above the rim where there's nothing to clip
# against, and clipping it would shave its edges when the van sits near a wall.
func apply_clip_material(clown):
	if clip_material == null or not is_instance_valid(clown):
		return
	var s = clown.get_node_or_null("Sprite")
	if s:
		s.material = clip_material

func draw_debug_clip_bounds():
	for edge in [
		{"pos": Vector2(clip_left, container_center_y), "size": Vector2(2, 900)},
		{"pos": Vector2(clip_right, container_center_y), "size": Vector2(2, 900)},
		{"pos": Vector2(container_center_x, clip_bottom), "size": Vector2(900, 2)},
		{"pos": Vector2(container_center_x, clip_top), "size": Vector2(900, 2)},
	]:
		var rect = ColorRect.new()
		rect.color = Color(0, 1, 1, 0.8)
		rect.size = edge.size
		rect.position = edge.pos - edge.size / 2.0
		rect.z_index = 300
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)

# ══════════════════════════════════════════════════════════════════════
#  DANGER LINE
# ══════════════════════════════════════════════════════════════════════

func setup_danger_line():
	danger_line = DangerLine.new()
	danger_line.line_width = clip_right - clip_left
	danger_line.thickness = danger_line_thickness
	danger_line.line_color = danger_line_color
	danger_line.position = Vector2((clip_left + clip_right) / 2.0, danger_limit_y)
	# Above the clowns so it reads clearly, below the box overlay (150).
	danger_line.z_index = 140
	add_child(danger_line)

# Fades the line in as the pile approaches the limit, and pulses it once a
# clown has actually crossed.
#
# Two filters keep it from flashing on every drop. First, a clown moving
# faster than danger_settle_speed is still in flight and doesn't count — a
# dropped clown falls straight through the warning band on its way down, and
# without this the line lit up every single time. Second, the condition has
# to hold continuously for danger_warning_delay before the line appears, so a
# clown that bounces up into the band and settles back down never shows it.
func update_danger_line(delta: float):
	if danger_line == null:
		return
	if game_over:
		danger_line.target_alpha = 0.0
		danger_line.pulse = false
		danger_warning_timer = 0.0
		return

	var highest := INF
	var breached := false
	for child in get_children():
		if not (child is ClownBall):
			continue
		if child == preview_clown:
			continue
		# A clown that hasn't entered the box yet doesn't count for anything.
		#
		# This is what was flashing the line on every drop: a clown spawns at
		# drop_y, which is ABOVE the limit line, and for the first couple of
		# frames it hasn't accelerated past danger_settle_speed — so it looked
		# like a settled clown sitting over the line, which is the emergency
		# case that skips the delay. The clown starts counting once its top
		# edge has dropped below the rim, i.e. it's fully inside the
		# container. After that it counts forever, so a real stack that grows
		# back up past the rim still triggers the warning.
		if not child.has_meta("entered_container"):
			if child.global_position.y - child.merge_radius > clip_top:
				child.set_meta("entered_container", true)
			else:
				continue
		if child.linear_velocity.length() > danger_settle_speed:
			continue
		var top_edge = child.global_position.y - child.merge_radius
		if top_edge < highest:
			highest = top_edge
		if top_edge < danger_limit_y:
			breached = true

	var in_band = highest != INF and (highest - danger_limit_y) <= danger_warning_range

	# A clown already over the line is an emergency — show it immediately
	# rather than making the player wait out the delay.
	if breached:
		danger_warning_timer = danger_warning_delay
	elif in_band:
		danger_warning_timer += delta
	else:
		danger_warning_timer = 0.0

	if not in_band or danger_warning_timer < danger_warning_delay:
		danger_line.target_alpha = 0.0
		danger_line.pulse = false
		return

	var closeness = 1.0 - clampf((highest - danger_limit_y) / danger_warning_range, 0.0, 1.0)
	danger_line.target_alpha = closeness * danger_line_max_alpha
	danger_line.pulse = breached

# Solid horizontal line with rounded ends. draw_line() has no cap style, so
# the ends are capped with circles.
class DangerLine extends Node2D:
	var line_width: float = 400.0
	var thickness: float = 4.0
	var line_color: Color = Color(0.95, 0.22, 0.22)
	var target_alpha: float = 0.0
	var current_alpha: float = 0.0
	var pulse: bool = false
	var pulse_time: float = 0.0

	func _process(delta):
		current_alpha = lerpf(current_alpha, target_alpha, clampf(delta * 6.0, 0.0, 1.0))
		pulse_time = pulse_time + delta if pulse else 0.0
		queue_redraw()

	func _draw():
		var a = current_alpha
		if pulse:
			a *= 0.72 + 0.28 * sin(pulse_time * 9.0)
		if a <= 0.01:
			return
		var c = Color(line_color.r, line_color.g, line_color.b, a)
		var radius = thickness / 2.0
		var half = line_width / 2.0 - radius
		draw_line(Vector2(-half, 0), Vector2(half, 0), c, thickness, true)
		draw_circle(Vector2(-half, 0), radius, c)
		draw_circle(Vector2(half, 0), radius, c)

# ══════════════════════════════════════════════════════════════════════
#  DROP GUIDE LINE
# ══════════════════════════════════════════════════════════════════════

func setup_drop_guide():
	drop_guide = DropGuideLine.new()
	drop_guide.dash_length = guide_dash_length
	drop_guide.gap_length = guide_gap_length
	drop_guide.thickness = guide_thickness
	drop_guide.scroll_speed = guide_scroll_speed
	drop_guide.line_color = guide_color
	# Just under the preview clown (z 50) so the clown always reads on top
	# of its own guide, but above the pile so the line stays visible.
	drop_guide.z_index = 49
	add_child(drop_guide)

# Raycasts straight down from the preview clown so the line stops on top of
# the pile instead of running through it. Lives in _physics_process because
# direct_space_state can't be safely queried from _process.
func _physics_process(_delta):
	update_drop_guide()

func update_drop_guide():
	if drop_guide == null:
		return

	if game_over or arrest_mode or preview_clown == null or not is_instance_valid(preview_clown):
		drop_guide.visible = false
		return

	drop_guide.visible = true

	var x = preview_clown.global_position.x
	var start_y = drop_y + (preview_clown.clown_size / 2.0) + 8.0
	var end_y = floor_top_y

	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(Vector2(x, start_y), Vector2(x, end_y))
	query.exclude = [preview_clown.get_rid()]
	query.collide_with_areas = false
	var hit = space.intersect_ray(query)
	if hit:
		end_y = hit.position.y - 4.0

	drop_guide.position = Vector2(x, start_y)
	drop_guide.length = maxf(0.0, end_y - start_y)

# A vertical dashed line with rounded ends whose dashes crawl downward.
# draw_line() has no cap style in Godot, so each dash is a line plus a
# circle at each end to round it off.
class DropGuideLine extends Node2D:
	var length: float = 0.0
	var dash_length: float = 9.0
	var gap_length: float = 11.0
	var thickness: float = 3.0
	var scroll_speed: float = 55.0
	var line_color: Color = Color(1, 1, 1, 0.5)
	var scroll_offset: float = 0.0

	func _process(delta):
		if not visible:
			return
		scroll_offset = fmod(scroll_offset + scroll_speed * delta, dash_length + gap_length)
		queue_redraw()

	func _draw():
		if length <= 0.0:
			return
		var period = dash_length + gap_length
		var radius = thickness / 2.0
		# Start one period above 0 so a dash can be partway into view,
		# which is what sells the downward crawl.
		var y = scroll_offset - period
		while y < length:
			var top = maxf(y, 0.0)
			var bottom = minf(y + dash_length, length)
			if bottom > top:
				draw_line(Vector2(0, top), Vector2(0, bottom), line_color, thickness, true)
				draw_circle(Vector2(0, top), radius, line_color)
				draw_circle(Vector2(0, bottom), radius, line_color)
			y += period

# ══════════════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════════════

func _input(event):
	if game_over:
		return

	# ── Police Jail: CTRL toggles selection ──
	if jail_enabled and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_CTRL or event.physical_keycode == KEY_CTRL:
			if arrest_mode:
				exit_arrest_mode()
			else:
				enter_arrest_mode()
			get_viewport().set_input_as_handled()
			return

	# While aiming, clicks pick a target instead of dropping.
	if arrest_mode:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				confirm_arrest()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				exit_arrest_mode()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if van_sprite:
			var mouse_x = get_viewport().get_mouse_position().x
			var clamped_x = clampf(mouse_x, play_area_left, play_area_right)
			van_sprite.global_position.x = clamped_x
			if preview_clown:
				preview_clown.global_position.x = clamped_x

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drop_clown()

	# Controller drop
	if event.is_action_pressed("drop"):
		drop_clown()

func _process(delta):
	if game_over:
		return

	update_danger_line(delta)

	if arrest_mode:
		update_arrest_hover()
		return  # world is frozen while aiming

	_handle_controller_input(delta)
	check_danger_zone(delta)

func _handle_controller_input(delta: float):
	if game_over or not van_sprite:
		return

	var stick_x = Input.get_axis("move_left", "move_right")
	if abs(stick_x) > 0.1:
		var new_x = clampf(
			van_sprite.global_position.x + stick_x * controller_speed * delta,
			play_area_left,
			play_area_right
		)
		van_sprite.global_position.x = new_x
		if preview_clown:
			preview_clown.global_position.x = new_x

func spawn_preview():
	if game_over:
		return

	var start_x = container_center_x
	if van_sprite:
		start_x = van_sprite.global_position.x

	preview_clown = ClownBallScene.instantiate()
	add_child(preview_clown)
	preview_clown.setup(current_clown_type)
	preview_clown.freeze = true
	preview_clown.can_merge = false
	preview_clown.modulate.a = 0.9
	preview_clown.z_index = 50
	preview_clown.global_position = Vector2(start_x, drop_y)

func update_next_preview():
	if next_clown_sprite:
		var next_clown_data = ClownBallScript.CLOWNS[next_clown_type]
		next_clown_sprite.texture = load(next_clown_data.image)

		var balloon_scale = next_balloon.scale.x if next_balloon else 1.0
		var target_size = 60.0 / balloon_scale
		var clown_texture_size = next_clown_sprite.texture.get_width()
		var scale_factor = target_size / clown_texture_size
		next_clown_sprite.scale = Vector2(scale_factor, scale_factor)

func drop_clown():
	if not preview_clown or not can_drop or game_over:
		return
	if arrest_mode:
		return

	can_drop = false

	if click_sound:
		click_sound.play()

	var drop_x = preview_clown.global_position.x
	var drop_type = current_clown_type

	preview_clown.queue_free()
	preview_clown = null

	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(drop_type)
	new_clown.global_position = Vector2(drop_x, drop_y)
	new_clown.freeze = false
	new_clown.can_merge = true
	apply_clip_material(new_clown)

	set_meta("last_dropped_clown", new_clown)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.add_clowns_dropped(1)
		settings.add_clown_drop(drop_type)

	clown_dropped.emit(drop_type)
	add_police_heat()

	if test_mode:
		test_clown_index += 1
		if test_clown_index >= ClownBallScript.CLOWNS.size():
			test_clown_index = 0
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		current_clown_type = next_clown_type
		next_clown_type = randi() % min(5, current_clown_type + 2)

	update_next_preview()

	await get_tree().create_timer(0.5).timeout
	if not game_over:
		can_drop = true
		spawn_preview()

# Averages two angles correctly, handling the wrap at ±PI. A naive (a + b) / 2
# would turn 179° and -179° (which are 2° apart) into 0° — snapping the child
# bolt upright, which is exactly the bug we're fixing. angle_difference() takes
# the short way around the circle instead.
func _average_angle(a: float, b: float) -> float:
	return a + angle_difference(a, b) / 2.0

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)

	var merge_sound_index = clown1.clown_type
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()

	var points = ClownBallScript.CLOWNS[new_type].score
	score += points
	score_changed.emit(score)

	if score_label:
		score_label.text = str(score)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.update_highest_tier(new_type)
		settings.add_clown_merge(new_type)

	# ── Capture the parents' orientation/motion BEFORE they're freed ──
	# The new clown inherits the average tilt of the two clowns that made it,
	# so it's born leaning the way they were leaning instead of always snapping
	# upright. We also keep some of their spin and velocity so the merge carries
	# its own momentum, and remember the axis they were sitting along.
	var merge_rotation = _average_angle(clown1.rotation, clown2.rotation)
	var inherited_spin = (clown1.angular_velocity + clown2.angular_velocity) / 2.0
	var inherited_velocity = (clown1.linear_velocity + clown2.linear_velocity) / 2.0
	var merge_axis = (clown2.global_position - clown1.global_position).normalized()

	if has_meta("last_dropped_clown"):
		var last = get_meta("last_dropped_clown")
		if last == clown1 or last == clown2:
			remove_meta("last_dropped_clown")

	# If either parent was frozen for an arrest, drop it from that list so
	# exit_arrest_mode() doesn't touch a freed node.
	frozen_for_arrest.erase(clown1)
	frozen_for_arrest.erase(clown2)

	clown1.queue_free()
	clown2.queue_free()

	await get_tree().create_timer(0.05).timeout

	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(new_type)
	new_clown.global_position = merge_pos
	new_clown.rotation = merge_rotation + randf_range(-merge_rotation_jitter, merge_rotation_jitter)
	new_clown.freeze = false
	apply_clip_material(new_clown)
	# Born from a pair already in the box, so it counts toward the danger
	# warning right away — even if the merge happened up near the rim.
	new_clown.set_meta("entered_container", true)

	await get_tree().create_timer(0.01).timeout

	# Pop mostly upward, but nudged perpendicular to the merge axis, so a
	# side-by-side merge pops differently than a stacked one.
	var pop_dir = Vector2(0, -1).lerp(
		Vector2(-merge_axis.y, merge_axis.x),
		merge_axis_influence
	).normalized()
	new_clown.apply_central_impulse(
		pop_dir * merge_pop_strength + inherited_velocity * merge_velocity_inherit
	)
	new_clown.angular_velocity = inherited_spin * merge_spin_inherit \
		+ randf_range(-merge_spin_jitter, merge_spin_jitter)

# In classic mode the test uses each clown's TOP EDGE against danger_limit_y,
# which is the exact height the red line is drawn at. The old test compared
# the clown's CENTRE against danger_y — that's why a clown could sit visibly
# above the line without ending the run: its centre was still below. Since
# the offset was one radius, the discrepancy was small for a Tessa and huge
# for a Kirk, so no fixed line position could ever have been honest.
#
# Chaos mode keeps the original centre-based rule, since chaotic_manager.gd
# calls super.check_danger_zone() and its balance is tuned around it.
func check_danger_zone(delta: float):
	var limit = danger_limit_y if classic_features else danger_y
	for child in get_children():
		if child is ClownBall and not child.freeze:
			var height = child.global_position.y
			if classic_features:
				height -= child.merge_radius
			if height < limit:
				if child.linear_velocity.length() < danger_settle_speed:
					if not child.has_meta("danger_timer"):
						child.set_meta("danger_timer", 0.0)
					var timer = child.get_meta("danger_timer") + delta
					child.set_meta("danger_timer", timer)
					if timer > 1.0:
						trigger_game_over()
						return
			else:
				if child.has_meta("danger_timer"):
					child.set_meta("danger_timer", 0.0)

func trigger_game_over():
	if game_over:
		return

	# Make sure we're not stranded mid-arrest with a dimmed screen and a
	# pile of frozen clowns.
	if arrest_mode:
		exit_arrest_mode()

	game_over = true
	can_drop = false

	if game_over_sound:
		game_over_sound.play()

	print("Game Over! Final Score: ", score)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.update_best_score(score)
		settings.increment_total_runs()

	var steam = get_node_or_null("/root/SteamManager")
	if steam and steam.is_on_steam:
		print("📤 Uploading score to Steam leaderboard...")
		steam.upload_score(score)
	else:
		print("⚠️ Steam not available, score not uploaded")

	if preview_clown:
		preview_clown.queue_free()
		preview_clown = null
	if van_sprite:
		van_sprite.queue_free()
		van_sprite = null

	for child in get_children():
		if child is ClownBall:
			child.freeze = true

	game_over_triggered.emit(score)

	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
