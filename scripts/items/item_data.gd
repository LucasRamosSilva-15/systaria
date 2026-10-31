class_name ItemData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 999
@export var place_block_id: int = 0 # If > 0, places block in TileMapLayer
@export var place_entity_type: String = "" # "workbench", "chest"
@export var tool_type: String = "" # "pickaxe"
@export var mining_power: int = 0 # 1, 2, 3
@export var mining_speed: float = 1.0 # 1.0, 1.25, 1.6
