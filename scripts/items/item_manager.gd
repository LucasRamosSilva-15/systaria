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

	# Blocks
	_register_item("dirt", "Terra", "Solo comum encontrado logo abaixo da vegetação.", "res://assets/ui/icon_dirt.png", 999, BlockManager.BlockID.DIRT)
	_register_item("stone", "Pedra", "Rocha sólida que forma a crosta média do terreno.", "res://assets/ui/icon_stone.png", 999, BlockManager.BlockID.STONE)
	_register_item("deep_stone", "Pedra Profunda", "Basalto denso e resistente das profundezas.", "res://assets/ui/icon_deep_stone.png", 999, BlockManager.BlockID.DEEP_STONE)
	_register_item("metallic_ore", "Minério Metálico", "Nódulos metálicos brutos incorporados na rocha.", "res://assets/ui/icon_metallic_ore.png", 999, BlockManager.BlockID.METALLIC_ORE)
	_register_item("cyan_crystal", "Cristal Ciano", "Cristais luminescentes com ressonância energética.", "res://assets/ui/icon_cyan_crystal.png", 999, BlockManager.BlockID.CYAN_CRYSTAL)
	_register_item("grass", "Terra com Vegetação", "Bloco superficial coberto por musgo biológico.", "res://assets/ui/icon_grass.png", 999, BlockManager.BlockID.GRASS)

	# Raw Materials
	_register_item("wood", "Madeira Fóssil", "Tronco orgânico e fibroso compactado pelo abisso.", "res://assets/ui/icon_wood.png", 999, 0)

	# Placeable Objects
	var wb := _register_item("workbench", "Bancada de Trabalho", "Estação de trabalho que desbloqueia receitas avançadas.", "res://assets/ui/icon_workbench.png", 99, 0)
	wb.place_entity_type = "workbench"

	var ch := _register_item("chest", "Baú Reforçado", "Compartimento com 20 slots de armazenamento seguro.", "res://assets/ui/icon_chest.png", 99, 0)
	ch.place_entity_type = "chest"

	# Tools
	var p_basic := _register_item("basic_pickaxe", "Picareta Básica", "Ferramenta rudimentar de escavação (Poder: 1, Vel: 1.0x).", "res://assets/ui/icon_basic_pickaxe.png", 1, 0)
	p_basic.tool_type = "pickaxe"
	p_basic.mining_power = 1
	p_basic.mining_speed = 1.0

	var p_stone := _register_item("stone_pickaxe", "Picareta de Pedra", "Picareta esculpida com pedra afiada (Poder: 2, Vel: 1.25x).", "res://assets/ui/icon_stone_pickaxe.png", 1, 0)
	p_stone.tool_type = "pickaxe"
	p_stone.mining_power = 2
	p_stone.mining_speed = 1.25

	var p_metal := _register_item("metallic_pickaxe", "Picareta Metálica", "Picareta reforçada com liga metálica (Poder: 3, Vel: 1.6x).", "res://assets/ui/icon_metallic_pickaxe.png", 1, 0)
	p_metal.tool_type = "pickaxe"
	p_metal.mining_power = 3
	p_metal.mining_speed = 1.6

static func _register_item(id: String, name: String, desc: String, icon_path: String, max_stack: int, place_block_id: int) -> ItemData:
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
	return item

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
