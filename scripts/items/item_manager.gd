class_name ItemManager
extends RefCounted

static var _items: Dictionary = {}
static var _block_to_item: Dictionary = {}
static var _initialized: bool = false

static func init_items() -> void:
	if _initialized:
		return
	_initialized = true

	# Ensure blocks are initialized
	BlockManager.init_blocks()

	_register_item("dirt", "Terra", "Solo comum encontrado logo abaixo da vegetação.", "res://assets/ui/icon_dirt.png", 999, BlockManager.BlockID.DIRT)
	_register_item("stone", "Pedra", "Rocha sólida que forma a crosta média do terreno.", "res://assets/ui/icon_stone.png", 999, BlockManager.BlockID.STONE)
	_register_item("deep_stone", "Pedra Profunda", "Basalto denso e resistente das profundezas.", "res://assets/ui/icon_deep_stone.png", 999, BlockManager.BlockID.DEEP_STONE)
	_register_item("metallic_ore", "Minério Metálico", "Nódulos metálicos brutos incorporados na rocha.", "res://assets/ui/icon_metallic_ore.png", 999, BlockManager.BlockID.METALLIC_ORE)
	_register_item("cyan_crystal", "Cristal Ciano", "Cristais luminescentes com ressonância energética.", "res://assets/ui/icon_cyan_crystal.png", 999, BlockManager.BlockID.CYAN_CRYSTAL)
	_register_item("grass", "Terra com Vegetação", "Bloco superficial coberto por musgo biológico.", "res://assets/ui/icon_grass.png", 999, BlockManager.BlockID.GRASS)

static func _register_item(id: String, name: String, desc: String, icon_path: String, max_stack: int, place_block_id: int) -> void:
	var item := ItemData.new()
	item.id = id
	item.name = name
	item.description = desc
	item.max_stack = max_stack
	item.place_block_id = place_block_id
	if ResourceLoader.exists(icon_path):
		item.icon = load(icon_path)
	_items[id] = item

	if place_block_id > 0:
		_block_to_item[place_block_id] = id

static func get_item(id: String) -> ItemData:
	if not _initialized:
		init_items()
	return _items.get(id, null)

static func get_item_by_block_id(block_id: int) -> ItemData:
	if not _initialized:
		init_items()
	var item_id: String = _block_to_item.get(block_id, "")
	if item_id != "":
		return get_item(item_id)
	return null

static func get_all_items() -> Array:
	if not _initialized:
		init_items()
	return _items.values()

