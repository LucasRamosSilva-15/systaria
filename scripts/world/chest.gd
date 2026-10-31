class_name Chest
extends StaticBody2D

const Inventory = preload("res://scripts/inventory/inventory.gd")

@export var unique_id: String = ""

var inventory: Inventory
var is_destroyed: bool = false

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D

func _init() -> void:
	inventory = Inventory.new(20) # 20 slots of storage

func _ready() -> void:
	add_to_group("chests")
	if unique_id == "":
		unique_id = "chest_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

func setup(p_id: String = "", p_items_data: Array = []) -> void:
	if p_id != "":
		unique_id = p_id
	if not p_items_data.is_empty():
		inventory.deserialize(p_items_data)

func has_any_items() -> bool:
	for slot in inventory.slots:
		if not slot.is_empty():
			return true
	return false

func can_be_destroyed() -> bool:
	return not has_any_items()

func mine_and_destroy(chunk_manager_ref: Node2D, hud_ref: Node = null) -> bool:
	if has_any_items():
		if hud_ref and hud_ref.has_method("show_notification"):
			hud_ref.show_notification("Esvazie o baú antes de removê-lo.")
		return false

	if is_destroyed:
		return true
	is_destroyed = true

	# Spawn dropped chest item
	if chunk_manager_ref and chunk_manager_ref.has_method("spawn_dropped_item"):
		chunk_manager_ref.spawn_dropped_item("chest", 1, global_position)

	queue_free()
	return true

func to_dict() -> Dictionary:
	return {
		"id": unique_id,
		"x": global_position.x,
		"y": global_position.y,
		"inventory": inventory.serialize()
	}

