class_name DroppedItem
extends CharacterBody2D

const Inventory = preload("res://scripts/inventory/inventory.gd")

@export var item_id: String = ""
@export var count: int = 1
@export var magnet_range: float = 64.0
@export var magnet_speed: float = 240.0
@export var pickup_distance: float = 16.0

var unique_id: String = ""
var target_player: CharacterBody2D = null
var is_collected: bool = false
var pickup_delay: float = 0.3 # Brief delay after block break before magnet kicks in

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow_sprite: Sprite2D = $Shadow

func _ready() -> void:
	if unique_id == "":
		unique_id = "%s_%d_%d" % [item_id, Time.get_ticks_msec(), randi() % 10000]
	_update_appearance()

func setup(p_item_id: String, p_count: int = 1, p_id: String = "") -> void:
	item_id = p_item_id
	count = p_count
	if p_id != "":
		unique_id = p_id
	if is_inside_tree():
		_update_appearance()

func _update_appearance() -> void:
	if not sprite:
		return
	var data := ItemManager.get_item(item_id)
	if data and data.icon:
		sprite.texture = data.icon
		sprite.scale = Vector2(0.8, 0.8) # Crisp scaled icon

func _physics_process(delta: float) -> void:
	if is_collected:
		return

	if pickup_delay > 0.0:
		pickup_delay -= delta

	# Check for player proximity
	if not target_player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]

	if target_player and pickup_delay <= 0.0:
		var dist := global_position.distance_to(target_player.global_position)
		if dist <= pickup_distance:
			_try_collect(target_player)
			return
		elif dist <= magnet_range:
			# Magnetic attraction towards player center
			var dir := (target_player.global_position - global_position).normalized()
			velocity = velocity.move_toward(dir * magnet_speed, 600.0 * delta)
			move_and_slide()
			return

	# Standard gravity physics
	if not is_on_floor():
		velocity.y = min(velocity.y + 600.0 * delta, 400.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	move_and_slide()

func _try_collect(player_node: CharacterBody2D) -> void:
	if is_collected or not ("inventory" in player_node):
		return

	var inv: Inventory = player_node.inventory
	if not inv:
		return

	var remainder: int = inv.add_item(item_id, count)
	if remainder == 0:
		is_collected = true
		queue_free()
	elif remainder < count:
		count = remainder
