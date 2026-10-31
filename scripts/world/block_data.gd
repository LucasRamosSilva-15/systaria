class_name BlockData
extends Resource

enum MaterialType {
	AIR = 0,
	SOIL = 1,
	STONE = 2,
	DEEP_STONE = 3,
	ORE = 4,
	CRYSTAL = 5,
	ORGANIC = 6
}

@export var id: int = 0
@export var name: String = "Vazio"
@export var material_type: MaterialType = MaterialType.AIR
@export var hardness: float = 1.0
@export var is_solid: bool = false
@export var atlas_coords: Vector2i = Vector2i(-1, -1)
@export var drop_item_id: String = ""
