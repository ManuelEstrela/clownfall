extends RigidBody2D
class_name ClownBall

# Clown data
var clown_type: int = 0
var clown_size: float = 35.0
var clown_score: int = 1
var can_merge: bool = true
var danger_timer: float = 0.0

# References
@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

# Clown config (matches your JS)
const CLOWNS = [
	{"name": "Tessa", "size": 35, "score": 1, "image": "res://assets/images/tessa.png"},
	{"name": "Twinkles", "size": 42, "score": 3, "image": "res://assets/images/twinkles.png"},
	{"name": "Reina", "size": 48, "score": 6, "image": "res://assets/images/reina.png"},
	{"name": "Osvaldo", "size": 54, "score": 10, "image": "res://assets/images/osvaldo.png"},
	{"name": "Hazel", "size": 60, "score": 15, "image": "res://assets/images/hazel.png"},
	{"name": "Mumbles", "size": 66, "score": 21, "image": "res://assets/images/mumbles.png"},
	{"name": "Sneaky", "size": 72, "score": 28, "image": "res://assets/images/sneaky.png"},
	{"name": "Wendy", "size": 78, "score": 36, "image": "res://assets/images/wendy.png"},
	{"name": "Chatty", "size": 84, "score": 45, "image": "res://assets/images/chatty.png"},
	{"name": "Cups", "size": 90, "score": 55, "image": "res://assets/images/cups.png"},
	{"name": "Kirk", "size": 96, "score": 66, "image": "res://assets/images/kirk.png"},
]

func setup(type: int):
	clown_type = type
	var data = CLOWNS[type]
	
	clown_size = data.size
	clown_score = data.score
	
	# Wait for node to be ready if needed
	if not sprite:
		await ready
	
	# Set sprite
	sprite.texture = load(data.image)
	sprite.scale = Vector2.ONE * (clown_size / sprite.texture.get_width())
	
	# Set collision
	var radius = (clown_size / 2.0) * 0.95  # hitbox scale
	collision.shape = CircleShape2D.new()
	collision.shape.radius = radius
	
	# Physics properties
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.4
	linear_damp = 0.1
	angular_damp = 1.0

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is ClownBall and can_merge and body.can_merge:
		if body.clown_type == clown_type and clown_type < CLOWNS.size() - 1:
			attempt_merge(body)

func attempt_merge(other: ClownBall):
	# Prevent double merging
	can_merge = false
	other.can_merge = false
	
	# Calculate merge position
	var merge_pos = (global_position + other.global_position) / 2.0
	
	# Notify game manager to create merged clown
	get_parent().merge_clowns(self, other, merge_pos, clown_type + 1)
