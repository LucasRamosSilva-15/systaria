class_name Workbench
extends StaticBody2D

@export var unique_id: String = ""

var chunk_coords: Vector2i = Vector2i.ZERO
var is_destroyed: bool = false

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("workbenches")
	if unique_id == "":
		unique_id = "wb_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func setup(p_id: String = "") -> void:
	if p_id != "":
		unique_id = p_id

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and "current_crafting_station" in body:
		body.current_crafting_station = "workbench"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and "current_crafting_station" in body:
		if body.current_crafting_station == "workbench":
			body.current_crafting_station = ""

func mine_and_destroy(chunk_manager_ref: Node2D) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	# Notify player if within area
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "current_crafting_station" in p and p.current_crafting_station == "workbench":
			p.current_crafting_station = ""

	# Spawn dropped item
	if chunk_manager_ref and chunk_manager_ref.has_method("spawn_dropped_item"):
		chunk_manager_ref.spawn_dropped_item("workbench", 1, global_position)

	queue_free()

func to_dict() -> Dictionary:
	return {
		"id": unique_id,
		"x": global_position.x,
		"y": global_position.y
	}

