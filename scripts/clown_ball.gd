extends RigidBody2D
class_name ClownBall

# Clown data
var clown_type: int = 0
var clown_size: float = 35.0
var clown_score: int = 1
var can_merge: bool = true
var is_merging: bool = false
var just_spawned: bool = true

# Collision sound state
var collision_cooldown: float = 0.0
const COLLISION_COOLDOWN_DURATION: float = 0.25
const COLLISION_VELOCITY_THRESHOLD: float = 150.0

# ── MERGE SAFETY NET ────────────────────────────────────────────
# body_entered is a ONE-SHOT signal: it only fires at the instant two bodies
# begin touching. That makes it unreliable as the sole merge trigger, because:
#   1. If the pair touches while either is still `just_spawned`, we reject the
#      signal — and it never fires again, since they're already in contact.
#   2. body_entered isn't guaranteed to fire on BOTH bodies, so an
#      instance-ID tiebreak can silently drop the merge entirely.
#   3. With contact reporting capped, a clown already touching several things
#      in a dense pile may never report the new contact at all.
#
# So we keep body_entered as the fast path, but also poll for touching
# same-type neighbours every physics frame. Anything the signal missed gets
# caught here.

# How often the safety-net scan runs. 0.0 = every physics frame.
#
# This used to be 0.1s, which was the main cause of the "I dropped a Tessa
# right on another Tessa and they just bounced" bug. A dropped clown hits at
# speed, and a bounce can start and finish inside a single 100ms window — so
# the scan looked before contact and again after separation, and never saw
# the two touching at all. At 60fps a clown moving 600px/s covers 60px in
# that window, which is nearly twice a Tessa's whole diameter.
const MERGE_SCAN_INTERVAL: float = 0.0

# Extra slack (px) on the "are they touching?" distance test. Physics lets
# bodies overlap slightly, and resting contact can leave a hairline gap, so a
# strict radius sum would miss real contacts. Positive = more forgiving.
const MERGE_CONTACT_TOLERANCE: float = 3.0

# How long the spawn lockout lasts before a clown may merge.
#
# This was 0.15s, and it was the OTHER half of the bounce bug. Drop a Tessa
# onto a Tessa: they touch within a few frames, body_entered fires, and the
# handler rejects it because the dropped clown is still inside its lockout.
# body_entered never fires again for a pair already in contact — so by the
# time the clown became eligible, the bounce had already pushed them apart
# and the merge was gone for good.
#
# The lockout only exists to stop a freshly *merged* clown from resolving
# before physics has settled, and 0.05s is plenty for that. The
# is_merging / can_merge guards are what actually prevent double-merges.
const SPAWN_MERGE_LOCKOUT: float = 0.05

# When a contact is rejected because of the spawn lockout, we remember the
# partner instead of throwing the contact away. Once both are eligible, the
# pair merges if they're still nearby — which catches the bounce case even
# after they've drifted apart a little.
const PENDING_CONTACT_MEMORY_MS: int = 400
# How far apart a remembered pair may be and still merge, as a multiple of
# their combined radii. 1.0 = must still be touching. Higher is more
# forgiving but merges from further away.
const PENDING_CONTACT_GRACE: float = 1.7

var merge_scan_timer: float = 0.0
var pending_contacts: Dictionary = {}

# Effective collision radius, cached at setup() so the scan doesn't have to
# dig into the shape every frame.
var merge_radius: float = 0.0

# References
@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

# Clown config with individual hitbox scales AND vertical offsets
const CLOWNS = [
	{"name": "Tessa",    "size": 35,  "score": 1,  "hitbox_scale": 0.95, "hitbox_offset_y": 0,  "image": "res://assets/images/tessa.png"},
	{"name": "Twinkles", "size": 42,  "score": 3,  "hitbox_scale": 0.94, "hitbox_offset_y": 0,  "image": "res://assets/images/twinkles.png"},
	{"name": "Reina",    "size": 48,  "score": 6,  "hitbox_scale": 0.90, "hitbox_offset_y": -2, "image": "res://assets/images/reina.png"},
	{"name": "Osvaldo",  "size": 58,  "score": 10, "hitbox_scale": 0.92, "hitbox_offset_y": 0,  "image": "res://assets/images/osvaldo.png"},
	{"name": "Hazel",    "size": 72,  "score": 15, "hitbox_scale": 0.92, "hitbox_offset_y": 0,  "image": "res://assets/images/hazel.png"},
	{"name": "Mumbles",  "size": 80,  "score": 21, "hitbox_scale": 0.90, "hitbox_offset_y": 4,  "image": "res://assets/images/mumbles.png"},
	{"name": "Sneaky",   "size": 92,  "score": 28, "hitbox_scale": 0.90, "hitbox_offset_y": 2,  "image": "res://assets/images/sneaky.png"},
	{"name": "Wendy",    "size": 100, "score": 36, "hitbox_scale": 0.94, "hitbox_offset_y": -1, "image": "res://assets/images/wendy.png"},
	{"name": "Chatty",   "size": 130, "score": 45, "hitbox_scale": 0.82, "hitbox_offset_y": 5,  "image": "res://assets/images/chatty.png"},
	{"name": "Cups",     "size": 150, "score": 55, "hitbox_scale": 0.92, "hitbox_offset_y": -1, "image": "res://assets/images/cups.png"},
	{"name": "Kirk",     "size": 192, "score": 66, "hitbox_scale": 0.82, "hitbox_offset_y": 1,  "image": "res://assets/images/kirk.png"},
]

func setup(type: int):
	clown_type = type
	var data = CLOWNS[type]
	
	clown_size = data.size
	clown_score = data.score
	var hitbox_scale = data.get("hitbox_scale", 1.0)
	var hitbox_offset_y = data.get("hitbox_offset_y", 0.0)
	
	if not sprite:
		await ready
	
	sprite.texture = load(data.image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.scale = Vector2.ONE * (clown_size / sprite.texture.get_width())
	
	var radius = (clown_size / 2.0) * hitbox_scale
	collision.shape = CircleShape2D.new()
	collision.shape.radius = radius
	collision.position = Vector2(0, hitbox_offset_y)
	
	# Cache for the merge safety-net scan
	merge_radius = radius
	
	print("🎪 ", data.name, " - Size: ", clown_size,
		  " | Hitbox Scale: ", hitbox_scale,
		  " | Radius: ", radius,
		  " | Y Offset: ", hitbox_offset_y)
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.15
	linear_damp = 0.3
	angular_damp = 2.0
	
	collision_layer = 1
	collision_mask = 1
	
	z_index = 100 - (clown_type * 10)

func _ready():
	body_entered.connect(_on_body_entered)
	contact_monitor = true
	# Raised from 4. In a dense pile a clown can easily touch the floor, a wall,
	# and several neighbours at once. Once the cap is hit, further contacts are
	# silently NOT reported — so the one contact that should have triggered a
	# merge never fires body_entered at all.
	max_contacts_reported = 12
	
	await get_tree().create_timer(SPAWN_MERGE_LOCKOUT).timeout
	just_spawned = false

func _process(delta):
	if collision_cooldown > 0.0:
		collision_cooldown -= delta

func _physics_process(delta):
	if is_merging or not can_merge or just_spawned:
		return
	
	# Contacts we had to turn away during the spawn lockout get first refusal,
	# since they represent a merge the player actually aimed for.
	if _resolve_pending_contacts():
		return
	
	merge_scan_timer -= delta
	if merge_scan_timer > 0.0:
		return
	merge_scan_timer = MERGE_SCAN_INTERVAL
	
	_scan_for_missed_merge()

# Remember a same-type contact we couldn't act on yet. Recorded on BOTH
# bodies, because body_entered may only fire on one of them.
func _remember_pending(other: ClownBall):
	var now = Time.get_ticks_msec()
	pending_contacts[other.get_instance_id()] = now
	other.pending_contacts[get_instance_id()] = now

# Returns true if a merge was started.
func _resolve_pending_contacts() -> bool:
	if pending_contacts.is_empty():
		return false
	if clown_type >= CLOWNS.size() - 1:
		pending_contacts.clear()
		return false
	
	var now = Time.get_ticks_msec()
	# .keys() returns a copy, so erasing while iterating is safe here.
	for id in pending_contacts.keys():
		if now - pending_contacts[id] > PENDING_CONTACT_MEMORY_MS:
			pending_contacts.erase(id)
			continue
		
		var other = instance_from_id(id)
		if other == null or not is_instance_valid(other) or not (other is ClownBall):
			pending_contacts.erase(id)
			continue
		if other.clown_type != clown_type:
			pending_contacts.erase(id)
			continue
		if other.is_merging or not other.can_merge or other.just_spawned:
			continue
		if other.freeze or freeze:
			continue
		
		var grace = (merge_radius + other.merge_radius) * PENDING_CONTACT_GRACE
		if global_position.distance_to(other.global_position) > grace:
			continue
		
		pending_contacts.erase(id)
		other.pending_contacts.erase(get_instance_id())
		
		if get_instance_id() < other.get_instance_id():
			attempt_merge(other)
		else:
			other.attempt_merge(self)
		return true
	return false

# Looks for a same-type clown we are physically overlapping/touching but never
# merged with. Only the lower instance ID actually initiates, so a pair can't
# both fire at once — but unlike body_entered, this runs on BOTH bodies every
# scan, so the merge can never be silently dropped just because one body's
# signal didn't fire.
func _scan_for_missed_merge():
	# Top-tier clown can't merge into anything
	if clown_type >= CLOWNS.size() - 1:
		return
	
	var parent = get_parent()
	if not parent:
		return
	
	# How far either body can travel in one physics step. Without this, a
	# fast pair can pass from "not yet touching" to "already bouncing apart"
	# between two consecutive frames and never register as in contact.
	var step = get_physics_process_delta_time()
	
	for other in parent.get_children():
		if other == self:
			continue
		if not (other is ClownBall):
			continue
		if other.clown_type != clown_type:
			continue
		if other.is_merging or not other.can_merge or other.just_spawned:
			continue
		if other.freeze or freeze:
			continue
		
		# Are the two collision circles actually touching?
		var closing_speed = (linear_velocity - other.linear_velocity).length()
		var contact_distance = merge_radius + other.merge_radius \
			+ MERGE_CONTACT_TOLERANCE + closing_speed * step
		if global_position.distance_to(other.global_position) > contact_distance:
			continue
		
		# Deterministic initiator so the pair can't double-merge
		if get_instance_id() < other.get_instance_id():
			attempt_merge(other)
		else:
			other.attempt_merge(self)
		return

func _on_body_entered(body):
	if body is ClownBall:
		if is_merging or not can_merge:
			return
		if not body.can_merge or body.is_merging:
			return
		if body.clown_type != clown_type or clown_type >= CLOWNS.size() - 1:
			# Different clown type, no merge — play collision sound
			_try_play_collision_sound()
			return
		
		if just_spawned or body.just_spawned:
			# Not eligible yet. body_entered will NEVER fire again for this
			# pair, so remembering it here is what stops an intentional
			# drop-on-match from being lost when the two bounce apart.
			_remember_pending(body)
			return
		
		# Tiebreak so only one of the pair initiates. If the other body's
		# signal is the only one that fired, the safety-net scan covers it.
		if get_instance_id() < body.get_instance_id():
			attempt_merge(body)
		return  # Merge happening (or partner will initiate) — no collision sound
	else:
		# Wall or floor (StaticBody2D) — play collision sound
		_try_play_collision_sound()

func _try_play_collision_sound():
	# Only the last-dropped ball plays collision sounds
	var manager = get_parent()
	if not manager or not manager.has_meta("last_dropped_clown"):
		return
	if manager.get_meta("last_dropped_clown") != self:
		return

	# Skip if on cooldown
	if collision_cooldown > 0.0:
		return

	# Skip if velocity is too low (gentle resting contact)
	if linear_velocity.length() < COLLISION_VELOCITY_THRESHOLD:
		return

	# Pick sound based on clown size group
	var sound: AudioStreamPlayer = null
	if clown_type <= 3:
		sound = manager.collision_sound_small
	elif clown_type <= 6:
		sound = manager.collision_sound_medium
	else:
		sound = manager.collision_sound_large

	if sound and not sound.playing:
		sound.play()
		collision_cooldown = COLLISION_COOLDOWN_DURATION

func attempt_merge(other: ClownBall):
	# Re-check under the wire. body_entered, the safety-net scan and the
	# pending-contact resolver can all route here, and two calls could land in
	# the same frame, so this guard is what actually prevents a double-merge
	# (which would spawn two clowns from one pair, or free an already-freed
	# node).
	if not is_instance_valid(other):
		return
	if is_merging or other.is_merging:
		return
	if not can_merge or not other.can_merge:
		return
	
	is_merging = true
	other.is_merging = true
	can_merge = false
	other.can_merge = false
	
	pending_contacts.clear()
	other.pending_contacts.clear()
	
	var merge_pos = (global_position + other.global_position) / 2.0
	
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("merge_clowns"):
		game_manager.merge_clowns(self, other, merge_pos, clown_type + 1)
	else:
		print("ERROR: Could not find game_manager!")
