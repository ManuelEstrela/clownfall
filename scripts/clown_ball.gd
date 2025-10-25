extends RigidBody2D
class_name ClownBall

# Clown data
var clown_type: int = 0
var clown_size: float = 35.0
var clown_score: int = 1
var can_merge: bool = true
var is_merging: bool = false

# References
@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

# Clown config with individual hitbox scales AND vertical offsets
# hitbox_scale: 1.0 = perfect circle, 0.95 = 5% smaller, 1.05 = 5% larger
# hitbox_offset_y: positive = move hitbox DOWN, negative = move hitbox UP
const CLOWNS = [
	{"name": "Tessa", "size": 35, "score": 1, "hitbox_scale": 0.95, "hitbox_offset_y": 0, "image": "res://assets/images/tessa.png"},
	{"name": "Twinkles", "size": 42, "score": 3, "hitbox_scale": 0.94, "hitbox_offset_y": 0, "image": "res://assets/images/twinkles.png"},
	{"name": "Reina", "size": 48, "score": 6, "hitbox_scale": 0.90, "hitbox_offset_y": -2, "image": "res://assets/images/reina.png"},
	{"name": "Osvaldo", "size": 58, "score": 10, "hitbox_scale": 0.92, "hitbox_offset_y": 0, "image": "res://assets/images/osvaldo.png"},
	{"name": "Hazel", "size": 72, "score": 15, "hitbox_scale": 0.92, "hitbox_offset_y": 0, "image": "res://assets/images/hazel.png"},
	{"name": "Mumbles", "size": 80, "score": 21, "hitbox_scale": 0.90, "hitbox_offset_y": 4, "image": "res://assets/images/mumbles.png"},
	{"name": "Sneaky", "size": 92, "score": 28, "hitbox_scale": 0.90, "hitbox_offset_y": 2, "image": "res://assets/images/sneaky.png"},
	{"name": "Wendy", "size": 100, "score": 36, "hitbox_scale": 0.94, "hitbox_offset_y": -1, "image": "res://assets/images/wendy.png"},
	{"name": "Chatty", "size": 130, "score": 45, "hitbox_scale": 0.82, "hitbox_offset_y": 5, "image": "res://assets/images/chatty.png"},
	{"name": "Cups", "size": 150, "score": 55, "hitbox_scale": 0.92, "hitbox_offset_y": -1, "image": "res://assets/images/cups.png"},
	{"name": "Kirk", "size": 192, "score": 66, "hitbox_scale": 0.82, "hitbox_offset_y": 1, "image": "res://assets/images/kirk.png"},
]

func setup(type: int):
	clown_type = type
	var data = CLOWNS[type]
	
	clown_size = data.size
	clown_score = data.score
	var hitbox_scale = data.get("hitbox_scale", 1.0)
	var hitbox_offset_y = data.get("hitbox_offset_y", 0.0)  # Get vertical offset
	
	# Wait for node to be ready if needed
	if not sprite:
		await ready
	
	# Set sprite (centered at RigidBody2D origin)
	sprite.texture = load(data.image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.scale = Vector2.ONE * (clown_size / sprite.texture.get_width())
	
	# ACCURATE HITBOX with per-clown adjustment AND vertical offset
	var radius = (clown_size / 2.0) * hitbox_scale
	collision.shape = CircleShape2D.new()
	collision.shape.radius = radius
	
	# Apply vertical offset to collision shape position
	collision.position = Vector2(0, hitbox_offset_y)
	
	# Debug output
	print("🎪 ", data.name, " - Size: ", clown_size, 
		  " | Hitbox Scale: ", hitbox_scale, 
		  " | Radius: ", radius,
		  " | Y Offset: ", hitbox_offset_y)
	
	# Physics properties
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.35
	linear_damp = 0.1
	angular_damp = 1.0
	
	# Set collision layer and mask
	collision_layer = 1
	collision_mask = 1
	
	# Set z-index based on size - smaller clowns appear in front
	# Invert the type so smaller = higher z-index
	z_index = 100 - (clown_type * 10)

func _ready():
	body_entered.connect(_on_body_entered)
	contact_monitor = true
	max_contacts_reported = 4

func _on_body_entered(body):
	if not body is ClownBall:
		return
	
	if is_merging or not can_merge:
		return
	
	if not body.can_merge or body.is_merging:
		return
	
	if body.clown_type == clown_type and clown_type < CLOWNS.size() - 1:
		if get_instance_id() < body.get_instance_id():
			attempt_merge(body)

func attempt_merge(other: ClownBall):
	is_merging = true
	other.is_merging = true
	can_merge = false
	other.can_merge = false
	
	var merge_pos = (global_position + other.global_position) / 2.0
	
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("merge_clowns"):
		game_manager.merge_clowns(self, other, merge_pos, clown_type + 1)
	else:
		print("ERROR: Could not find game_manager!")
