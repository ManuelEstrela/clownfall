extends Control
class_name LoreScreen

# ══════════════════════════════════════════════════════════════
#  LORE SCREEN
#
#  Opened by clicking a card in the collection. Card art on the
#  left with a 3D inspect tilt, lore text on the right.
#
#  The card which opened this screen is passed through the static
#  `requested_clown_index` below. A static var survives the scene
#  change without needing an autoload — collection_menu.gd sets it
#  immediately before calling change_scene_to_file().
# ══════════════════════════════════════════════════════════════

static var requested_clown_index: int = 0

var clown_index: int = 0
var settings: Node
var custom_font: Font

# ── CARD SIZE ─────────────────────────────────────────────────
# The card art is 283x320. Height is derived from the width so the
# ratio is always exact — change CARD_WIDTH and nothing distorts.
const CARD_ASSET_SIZE := Vector2(283.0, 320.0)
const CARD_WIDTH := 360.0
const CARD_LEFT := 110.0

# ── INSPECT EFFECT ────────────────────────────────────────────
# How much the card pops toward you on hover. 1.0 = no pop.
const POP_SCALE := 1.05
const POP_TIME := 0.18
# How hard the card tilts. This is perspective strength, not an angle —
# around 0.10 is a gentle lean, 0.30 is dramatic.
const TILT_STRENGTH := 0.16
# false = the edge you hover leans TOWARD you (like lifting that corner)
# true  = the edge you hover leans AWAY from you
const TILT_INVERT := false
# How quickly the tilt chases the cursor. Lower = heavier and more
# object-like, higher = snappier.
const TILT_LERP_SPEED := 11.0
# Brightness of the highlight that follows the cursor across the art.
const SHEEN_STRENGTH := 1.0
# Spare room around the card so the tilt has somewhere to go.
#
# A perspective-projected rectangle is a trapezoid, and its far edge ends
# up OUTSIDE the original rect: solving the homography for where the card's
# edge lands gives ±0.5 / (1 - 0.5 * tilt), which is past ±0.5 for any
# nonzero tilt. Without slack there, that overhang falls outside the
# TextureRect and gets discarded — which is the sliver of card that went
# missing, and why it got worse the harder the card leaned.
#
# Derived from TILT_STRENGTH so raising the tilt widens the margin
# automatically. Costs nothing visually: the extra area is transparent.
const TILT_OVERFLOW := 2.5

# ── CARD OVERLAYS ─────────────────────────────────────────────
# Same look as the collection screen's bottom row, expressed as
# fractions of the card so it scales with CARD_WIDTH instead of
# needing a fresh set of pixel values.
const BAR_WIDTH_FRACTION := 0.8
const BAR_Y_FRACTION := 0.5
const BAR_BOX_HEIGHT_FRACTION := 0.606
const PROGRESS_TEXT_Y_FRACTION := 0.2545
const PROGRESS_FONT_FRACTION := 0.08
const STARS_X_FRACTION := 0.44
const STARS_Y_FRACTION := 0.68
# Slightly smaller than the collection screen's 0.08 — the card is bigger
# here, and at matching proportions the stars read as oversized.
const STARS_FONT_FRACTION := 0.066
const STARS_BOX_HEIGHT_FRACTION := 0.0788

# ── TEXT ──────────────────────────────────────────────────────
const TEXT_LEFT := 540.0
const TEXT_RIGHT_MARGIN := 80.0
const TEXT_TOP := 150.0
const NAME_FONT_SIZE := 46
const LORE_FONT_SIZE := 20

# Tessa can never be produced by a merge, so her card counts drops
# instead. Matches DROP_COUNTED_CLOWN_INDEX in collection_menu.gd.
const DROP_COUNTED_CLOWN_INDEX := 0

const CLOWN_NAMES = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel",
	"Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]

const CARD_ASSET_PATHS = {
	0: "res://assets/images/collection/tessa_card.png",
	1: "res://assets/images/collection/twinkles_card.png",
	4: "res://assets/images/collection/hazel_card.png",
}
const FALLBACK_CARD_ASSET := "res://assets/images/collection/hazel_card.png"

# ══════════════════════════════════════════════════════════════
#  PLACEHOLDER LORE — replace all of this with your real writing.
#  Keys are the clown index (same order as CLOWNS in clown_ball.gd).
#  Blank lines separate paragraphs. Nothing else reads this dict, so
#  you can rewrite every entry freely without touching the code.
# ══════════════════════════════════════════════════════════════
const LORE = {
	0: "Tessa grew up in an unhealthy household. Her parents, Don and Tina, were alcoholics who constantly fought. If she didn't make herself scarce, they would turn their anger onto her. She only found solace in her pet dog, Maisy, who they also relentlessly abused in Tessa's place. When she was abused, Tessa would often protect herself by disassociating, if Maisy couldn't keep her distracted.\n\nHer parents were irresponsible and didn't get Maisy fixed, so she ended up pregnant with five puppies. When Maisy gave birth, Tessa was elated and spent the day tending to her, bringing things to her so the puppies would be safe and warm. However, that night her father came home drunk and angry with her mother, who was also very drunk. They appeared to have had a physical fight, and Tessa did not want to be found while they were acting that way, so she hid from them. Her mother didn't even register that Tessa was missing and passed out on the bed, leaving Tessa to the mercy of her father. When he found her, she was hiding outside with Maisy.\n\nHe wrenched Tessa up by her arm, revealing the puppies she was covering with her legs. He became more angry and reached for them, but Maisy snapped and bit him. Then he was furious. He beat Maisy until she wasn't moving and then turned to the puppies. He stole them away, taking them into the woods in a sack while Tessa begged him to leave them be. When he got tired of her hitting his legs as he walked, he beat her senseless and drunkenly proceeded with what he was doing. She could not stop what happened next, and was dragged into the house afterwards. She begged him to let Maisy inside so she could check on her, but he refused and told her that he would shoot the dog in the morning if she wasn't already dead. She didn't know where he went after that, but assumed he was asleep because the house was finally quiet.\n\nWith her only source of comfort gone, something broke in Tessa. That night she set the house on fire, ending with the death of her parents. This caused intense scarring on her hands. She has said that this was 'the only way'. This event is something that she scarcely recalls, and it was probably the point at which Mary Wolf, her alter, came to exist. She spent the rest of her childhood in foster care, enduring not much better treatment in that system, but eventually aged out and found a life for herself. She is very smart and became well adjusted as an adult in spite of her childhood and family.\n\nHer adoptive family is far more important to her however, with her late father being Sam Baas, with all of his other adopted kids, especially Eve Summers, and her cousin that she sees as a brother Johnny Divine.\n\n",
	1: "Eugene Anwar was born in the circus where his father Raul was apart of a clown troupe called 'Happy Slappy Buffoons'. His mother Lisa was an acrobat who specialized in the flying trapeze, she was a part of the 'Los Cuatro Voladores' Spanish for 'The Flying Four'. The 'Happy Slappy Buffoons' were not as popular as the other performers, Raul's creativity over the next 3 years allowed the troupe to gain some traction and love with his ideas that he brought forth. His hard work and determination allowed him to become a ringmaster. Shortly thereafter Eugene was born, while Raul stayed as a ringmaster, Lisa quit being a part of the 'Los Cuatro Voladores' to take care of Eugene and enjoy her time with her son. Growing up Eugene had a loving father and mother who cared for him very much. This all started to change when he was 5 years old when his father took a trip back home to check in on his family. Raul learned during the trip that his family tragically passed away 3 years ago in a car accident against an 18 wheeler truck that pinned down the vehicle his parents were in against a wall after the driver lost control. Raul was devastated to hear the news even though he hasn’t seen his parents in almost a decade. Shortly after spending a few days in the city, Raul returned back to the circus and told Lisa the news about his mother. Ever since then Raul kept thinking about the passing of his mother and how he wasn’t able to say goodbye and the guilt was eating at him for leaving abruptly in the past. His guilty conscience was eating at him and started to develop a drinking addiction and using drugs to numb the pain away. His performance started to hinder as a ringmaster and he knew if this kept up he’d be out of his position. Taking out the frustration and anger that was building up inside of him, he started to become abusive towards his family. Two years later, Lisa eventually got fed up with Raul and decided that she couldn’t take it anymore, she decided it was time to leave with her son. A note was found on Raul's bed 'I can’t do this anymore. I'm leaving and taking our son with me.' said the note. Raul got furious reading this note and all he could think about was being left alone for the rest of his life. He was able to catch up to Lisa and they had an argument when he confronted her. This argument led to Raul getting upset and killed Lisa in the process to stop her from leaving and taking his son. This led to Eugene having to deal with his father blaming him for why she wanted to leave in the first place, that it was all his fault and he forced Eugene to become a part of the circus and molded him into what he wanted Eugene to become.\n\nRaul covered up her disappearance with a fake note and left it in public to be found. Rumor had it going around the circus that Raul had something to do with why Lisa disappeared, everyone knew how much she loved her son and wouldn’t leave him behind alone with an abusive father. People believed that he murdered her and was the one who wrote the note that was found by the Flying Four. Raul wanted Eugene to become a clown just like him and was constantly deciding how he should act, and what performances to do. Whenever Eugene would mess up a performance or not do it exactly as planned, he would get punished for messing up. Eugene was not allowed to have any friends and wasn’t allowed to interact with any of the other performers because Raul knew that they would fill his head with 'nonsense' as he would call it and possibly Eugene would turn on him. Not being able to have friends, Eugene had an imaginary friend that he would talk to, he called him Twinkles, after the nursery rhyme his mother used to sing to him every night before bed. He would talk to Twinkles daily and would claim that he hears voices talking back to him when he interacted with them. Raul believed his son to be crazy for talking to himself but paid not much mind to it as long as it didn’t hinder his performance during the acts.\n\nWhen Eugene got older he finally felt like he lived up to his fathers expectations, to Eugene the performance he did that night felt like that was the day he was going to get praised from his father, unfortunately that is not how Raul deemed it, believing he could do better and claiming he messed up multiple times when he did not. Eugene was tired of dealing with his father and constant remarks telling him how much of a failure of a son he is and that he’ll become a nobody in life. Tired of dealing with his father, he finally decided to speak back and blamed his father for why mother left and how everyone believed that he killed her. Raul got furious and punched Eugene in the face, not holding back at all. At this point a spark lit up in Eugene, he reached over the table and found a knife and proceeded to stab his father in the stomach and in the leg, but as he went for the heart his father overpowered him and made sure that Eugene would never do something like this again. Breaking his left arm along with crushing his right hand with a hammer, and cutting his face as a reminder that he’s weak and useless. To cover up the cuts Eugene was constantly putting on clown makeup on to cover up his scars. Deeming this was not enough to cover what his father had done, he started to wear a mask . As Eugene recovered from this incident he started to plan on how he could get rid of his father and finally be free of his clutches. Fortunately for Eugene he would not have to act in performances as he was recovering and this led up to having a lot of free time and talking to his friend Twinkles for where they plotted to make sure his father suffers for all the years of suffering he has endured through. Eugene thought of hurting his father while he was asleep but that was too easy and wanted Raul to be awake for what he had planned. Eugene wanted to hang his father upside down, figuring that the blood would be rushing to the brain and this would make sure that Raul doesn’t pass out, then start cutting his father apart little by little, taking his time and finally burning him alive.\n\nBefore that could happen, Twinkles was thinking about stepping in at the right moment to take over and put Eugene to sleep. Eugene set up a trap for his father with a note saying 'I know you killed Lisa. I found her body. Meet me at midnight in your dressing room' knowing that this will get his father nervous and to show up. After getting his father where he wanted him to be, he was able to ambush him in the dark as he was walking to his dressing room. Tying up Raul as he was being dragged into the main ring where all the big performances are held. As he was dragging Raul, Eugene started talking to the voice in his head. 'I’m finally going to be free' he kept repeating as he laughed along the way. When they finally arrived Raul was starting to get tied upside down to catch bars that the 'Los Cuatro Voladores' uses. Eugene was getting excited that it was time for him to finally pay for all the years of suffering he went through. To return the favor, first Eugene made sure to cut his fathers face the same way that he cut up Eugene's face a few months prior. The screams made Eugene smile as he was doing his 'act' as he liked to call it. 'Look father, I did the same as you did to me. I made sure not to mess up this time, I know how much you like perfection.' He left the main ring and came back with a mirror, 'I hope you like your new look' he said as he put the mirror up to Raul as he was laying upside down and his face was all bloody. 'You can’t see much now, but don’t worry I can wash your face so you can get a better look later' Eugene said with a smile on his face. 'Now the real fun is about to start. Should we start with the left or right hand?' Eugene mentioned as he held a knife in his hand. Eugene was getting very emotional and was in a vulnerable state, now that he finally is going to have some fun and do what he wants for once, Twinkles saw this as an opportunity to step in and take over Eugene's body. They both hated father with a passion for what he’s done, but the one who hated him most was Eugene. Twinkles knew that it wasn’t his place to do the job that Eugene was set out to do and that it would cause pain and regret in the future, he decided to leave father hanging upside down from the catch bars and left the circus and was set out to find a new place to live. Over the years as he traveled throughout the country, Twinkles would perform at parties to earn money as a living since this was all Twinkles knew and this is how he got by. A Los Santos resident who was attending his niece’s birthday party saw Twinkles performance and wanted him to perform at their kids birthday party that is located in Los Santos and he agreed to do it.\n\nDuring their travels Twinkles figured that it was best for him to forget the last moments he had with his father so he made sure to remove all of that from his memory.",
	2: "Reina Jones is a member of the The Funhouse Clowns and the Pingafria Family. Previously, she was a hangaround for 3PAS.\n\nReina’s personality is anxious and timid but once you’ve gotten to know her she can be a goofy, funny character that cares deeply for her friends. Reina has a job at Happy Motors as a mechanic after quitting Project R and being fired from working at Abra Kebabra.\n\nNew to the city, Reina was a shy and scared girl with a load of anxiety. Reina used to always be by herself but later ended up getting a job at Auto Autos. One day, a gang took Reina hostage for a bank job, where she met her adoptive mother Tina. One day Tina came into Auto Autos and Reina asked her how to boost, in which Tina took her under her wing and taught Reina to sell lockpicks and repair kits. Tina eventually adopted Reina with William 'Wolfie' Wolf being her adopted father.\n\nSoon after the city reopened from the collapse, Reina met up with Zale (one of her old friends) in which he got her in contact with her brother Jordan Bones.",
	3: "Lore for Osvaldo goes here.\n\nReplace this text with the real thing.",
	4: "Lore for Hazel goes here.\n\nReplace this text with the real thing.",
	5: "Lore for Mumbles goes here.\n\nReplace this text with the real thing.",
	6: "Lore for Sneaky goes here.\n\nReplace this text with the real thing.",
	7: "Lore for Wendy goes here.\n\nReplace this text with the real thing.",
	8: "Lore for Chatty goes here.\n\nReplace this text with the real thing.",
	9: "Lore for Cups goes here.\n\nReplace this text with the real thing.",
	10: "Lore for Kirk goes here.\n\nReplace this text with the real thing.",
}

# ── NODES ─────────────────────────────────────────────────────
var background: TextureRect
var back_button: TextureButton
var card_viewport: SubViewport   # renders art + overlays as one image
var card_root: Control           # hover target, handles the pop
var card_display: TextureRect    # shows the viewport, carries the tilt shader
var name_label: Label
var lore_label: RichTextLabel

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

# ── EFFECT STATE ──────────────────────────────────────────────
var card_size: Vector2 = Vector2.ZERO
var hovering_card: bool = false
# Cursor position over the card, 0..1 on each axis. Starts centred so
# the card sits flat before the mouse ever touches it.
var tilt_target: Vector2 = Vector2(0.5, 0.5)
var tilt_current: Vector2 = Vector2(0.5, 0.5)
var tilt_amount: float = 0.0
var tilt_amount_target: float = 0.0

var _navigating_away: bool = false

func _ready():
	clown_index = clampi(requested_clown_index, 0, CLOWN_NAMES.size() - 1)
	settings = get_node_or_null("/root/SettingsManager")
	custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	card_size = Vector2(CARD_WIDTH, CARD_WIDTH * CARD_ASSET_SIZE.y / CARD_ASSET_SIZE.x)

	setup_sounds()
	setup_background()
	setup_back_button()
	setup_card()
	setup_text()

	print("Lore screen ready: ", CLOWN_NAMES[clown_index])

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
	background = TextureRect.new()
	background.texture = load("res://assets/images/collection/collection_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = get_viewport_rect().size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func setup_back_button():
	back_button = TextureButton.new()
	back_button.texture_normal = load("res://assets/images/button_back.png")
	back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_button.custom_minimum_size = Vector2(160, 55)
	back_button.position = Vector2(50, get_viewport_rect().size.y - 90)
	back_button.pressed.connect(_on_back_pressed)
	if settings and settings.has_method("set_hover_cursor"):
		settings.set_hover_cursor(back_button)
	add_child(back_button)

# ══════════════════════════════════════════════════════════════
#  CARD
#
#  The art and its overlays are rendered into a SubViewport, and the
#  resulting image is what gets tilted. That matters: the tilt is a
#  fragment shader, so it can only warp what's inside a single
#  texture. If the progress bar and stars were ordinary sibling nodes
#  they'd stay perfectly flat while the art behind them leaned, which
#  instantly breaks the illusion. Rendering them into the card first
#  means the whole card tilts as one solid object.
# ══════════════════════════════════════════════════════════════

# Fake perspective via a homography. Dividing the centred UV by
# (1 + dot(p, tilt)) is exactly what a real perspective projection does
# to a rotated plane: one edge's texels spread out (near, looks bigger)
# while the opposite edge's bunch up (far, looks smaller). Cheaper than
# moving to actual 3D nodes, and unlike warping the quad's four vertices
# it avoids the diagonal seam that affine texture mapping produces
# across the two triangles.
const TILT_SHADER_CODE := """
shader_type canvas_item;

uniform vec2 tilt = vec2(0.0, 0.0);
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float sheen = 0.0;
uniform float expand = 1.0;

void fragment() {
	// The rect is `expand` times bigger than the card, so scale UV back
	// out to card space first. The card then occupies the middle 1/expand
	// of the rect at its true size, with the rest as overhang room.
	vec2 p = (UV - 0.5) * expand;
	float w = 1.0 + dot(p, tilt);
	vec2 src = p / w + 0.5;

	// Genuinely outside the card — this is the transparent margin.
	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) {
		discard;
	}

	vec4 col = texture(TEXTURE, src);

	// Highlight tracks the cursor in the CARD's space, so it stays stuck
	// to the same spot on the art as the card leans.
	float d = distance(src, mouse_uv);
	col.rgb += vec3(smoothstep(0.55, 0.0, d) * sheen * 0.12) * col.a;

	COLOR = col;
}
"""

func setup_card():
	var card_y = (get_viewport_rect().size.y - card_size.y) / 2.0

	# ── Off-screen render of the card and its overlays ──
	card_viewport = SubViewport.new()
	card_viewport.size = Vector2i(roundi(card_size.x), roundi(card_size.y))
	card_viewport.transparent_bg = true
	card_viewport.disable_3d = true
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(card_viewport)

	var card_content = Control.new()
	card_content.size = card_size
	card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(card_content)

	var art = TextureRect.new()
	art.texture = load(CARD_ASSET_PATHS.get(clown_index, FALLBACK_CARD_ASSET))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# STRETCH_SCALE is safe here only because card_size keeps the art's
	# native 283:320 ratio — it fills the rect exactly, no distortion.
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = card_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_content.add_child(art)

	_add_card_overlays(card_content)

	# ── On-screen, tiltable copy ──
	card_root = Control.new()
	card_root.size = card_size
	card_root.position = Vector2(CARD_LEFT, card_y)
	card_root.pivot_offset = card_size / 2.0
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	card_root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(card_root)

	# card_root stays exactly card-sized so the hover area matches the card
	# the player sees. Only the display rect is oversized, and it overflows
	# card_root freely — no clip_contents anywhere on this path.
	var expand = 1.0 + TILT_OVERFLOW * TILT_STRENGTH

	card_display = TextureRect.new()
	card_display.texture = card_viewport.get_texture()
	card_display.size = card_size * expand
	card_display.position = -card_size * (expand - 1.0) / 2.0
	card_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_display.stretch_mode = TextureRect.STRETCH_SCALE
	card_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = TILT_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("expand", expand)
	card_display.material = mat
	card_root.add_child(card_display)

	card_root.mouse_entered.connect(func():
		hovering_card = true
		tilt_amount_target = 1.0
		if hover_sound:
			hover_sound.play()
		_pop(true)
	)
	card_root.mouse_exited.connect(func():
		hovering_card = false
		tilt_amount_target = 0.0
		# Settle back to flat rather than freezing at the last angle.
		tilt_target = Vector2(0.5, 0.5)
		_pop(false)
	)
	card_root.gui_input.connect(_on_card_input)

func _pop(is_hovering: bool):
	var target = POP_SCALE if is_hovering else 1.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_root, "scale", Vector2(target, target), POP_TIME)

func _on_card_input(event: InputEvent):
	if event is InputEventMouseMotion:
		tilt_target = Vector2(
			clampf(event.position.x / card_size.x, 0.0, 1.0),
			clampf(event.position.y / card_size.y, 0.0, 1.0)
		)

func _process(delta: float):
	if _navigating_away or card_display == null:
		return

	# clampf guards the lerp weight: at very low framerates delta * speed
	# can exceed 1, which overshoots instead of easing.
	var weight = clampf(delta * TILT_LERP_SPEED, 0.0, 1.0)
	tilt_current = tilt_current.lerp(tilt_target, weight)
	tilt_amount = lerpf(tilt_amount, tilt_amount_target, weight)

	# Remap 0..1 cursor position to a -1..1 offset from the card's centre.
	var offset = (tilt_current - Vector2(0.5, 0.5)) * 2.0
	var direction = 1.0 if TILT_INVERT else -1.0
	var tilt = offset * TILT_STRENGTH * tilt_amount * direction

	var mat = card_display.material
	if mat:
		mat.set_shader_parameter("tilt", tilt)
		mat.set_shader_parameter("mouse_uv", tilt_current)
		mat.set_shader_parameter("sheen", tilt_amount * SHEEN_STRENGTH)

# Progress bar and stars, matching the collection screen's bottom-row
# styling. Drawn into the SubViewport alongside the art so they tilt
# with it.
func _add_card_overlays(card: Control):
	var progress_data = _get_progress_for(clown_index)

	var bar_width = card_size.x * BAR_WIDTH_FRACTION
	var bar_x = card_size.x * (1.0 - BAR_WIDTH_FRACTION) / 2.0
	var bar_box_height = card_size.y * BAR_BOX_HEIGHT_FRACTION
	var progress_font = int(card_size.x * PROGRESS_FONT_FRACTION)
	var stars_font = int(card_size.x * STARS_FONT_FRACTION)

	var bar_tex = TextureRect.new()
	bar_tex.texture = load("res://assets/images/collection/progress_bar.png")
	bar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_tex.size = Vector2(bar_width, bar_box_height)
	bar_tex.position = Vector2(bar_x, card_size.y * BAR_Y_FRACTION)
	card.add_child(bar_tex)

	var progress_label = Label.new()
	progress_label.text = str(progress_data.total_merges) + " / " + str(progress_data.goal)
	if custom_font:
		progress_label.add_theme_font_override("font", custom_font)
	progress_label.add_theme_font_size_override("font_size", progress_font)
	progress_label.add_theme_color_override("font_color", Color(1, 1, 1))
	progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	progress_label.add_theme_constant_override("outline_size", 3)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.size = bar_tex.size
	progress_label.position = Vector2(
		bar_tex.position.x,
		bar_tex.position.y + card_size.y * PROGRESS_TEXT_Y_FRACTION
	)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(progress_label)

	var stars_label = Label.new()
	stars_label.text = "★ " + str(progress_data.stars)
	if custom_font:
		stars_label.add_theme_font_override("font", custom_font)
	stars_label.add_theme_font_size_override("font_size", stars_font)
	stars_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	stars_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	stars_label.add_theme_constant_override("outline_size", 3)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars_label.size = Vector2(card_size.x * 0.4, card_size.y * STARS_BOX_HEIGHT_FRACTION)
	stars_label.position = Vector2(
		card_size.x * STARS_X_FRACTION,
		card_size.y * STARS_Y_FRACTION
	)
	stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stars_label)

# Same source of truth as the collection screen: Tessa reads her drop
# count, everyone else reads merges.
func _get_progress_for(index: int) -> Dictionary:
	var total_merges = 0
	if settings:
		if index == DROP_COUNTED_CLOWN_INDEX:
			if index < settings.drops_per_clown.size():
				total_merges = settings.drops_per_clown[index]
		elif index < settings.merges_per_clown.size():
			total_merges = settings.merges_per_clown[index]

	var goal_data = ClownCollectionData.get_current_goal(index, total_merges)
	return {
		"total_merges": total_merges,
		"goal": goal_data.goal,
		"stars": goal_data.stars
	}

# ══════════════════════════════════════════════════════════════
#  TEXT
# ══════════════════════════════════════════════════════════════

func setup_text():
	var viewport_size = get_viewport_rect().size
	var text_width = viewport_size.x - TEXT_LEFT - TEXT_RIGHT_MARGIN

	name_label = Label.new()
	if custom_font:
		name_label.add_theme_font_override("font", custom_font)
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.text = CLOWN_NAMES[clown_index].to_upper()
	name_label.position = Vector2(TEXT_LEFT, TEXT_TOP - 70)
	name_label.size = Vector2(text_width, 60)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	lore_label = RichTextLabel.new()
	if custom_font:
		lore_label.add_theme_font_override("normal_font", custom_font)
	lore_label.add_theme_font_size_override("normal_font_size", LORE_FONT_SIZE)
	lore_label.add_theme_color_override("default_color", Color(1, 1, 1, 0.95))
	lore_label.bbcode_enabled = true
	lore_label.scroll_active = true
	lore_label.position = Vector2(TEXT_LEFT, TEXT_TOP)
	lore_label.size = Vector2(text_width, viewport_size.y - TEXT_TOP - 120)
	lore_label.text = LORE.get(clown_index, "")
	lore_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(lore_label)

# ══════════════════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════════════════

# project.godot maps Escape to "ui-cancel" — with a hyphen, alongside
# ui-up / ui-down / ui-confirm / ui-pause. Godot's built-in "ui_cancel"
# (underscore) is a different action and is NOT what the key is bound
# to, so checking only that one silently does nothing.
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
	if _is_back_pressed(event):
		_on_back_pressed()

func _on_back_pressed():
	if _navigating_away:
		return
	_navigating_away = true
	if click_sound:
		click_sound.play()
	# Mark the input consumed BEFORE the scene change. change_scene_to_file
	# tears this node out of the tree, after which get_viewport() is null.
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()
	get_tree().change_scene_to_file("res://scenes/CollectionMenu.tscn")
