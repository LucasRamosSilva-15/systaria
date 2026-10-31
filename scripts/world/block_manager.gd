class_name BlockManager
extends RefCounted

enum BlockID {
	AIR = 0,
	DIRT = 1,
	STONE = 2,
	DEEP_STONE = 3,
	METALLIC_ORE = 4,
	CYAN_CRYSTAL = 5,
	GRASS = 6
}

static var _blocks: Dictionary = {}
static var _initialized: bool = false

static func init_blocks() -> void:
	if _initialized:
		return
	_initialized = true

	# 0: AIR
	var air := BlockData.new()
	air.id = BlockID.AIR
	air.name = "Vazio"
	air.material_type = BlockData.MaterialType.AIR
	air.is_solid = false
	air.hardness = 0.0
	air.min_mining_power = 0
	air.atlas_coords = Vector2i(-1, -1)
	_blocks[BlockID.AIR] = air

	# 1: DIRT
	var dirt := BlockData.new()
	dirt.id = BlockID.DIRT
	dirt.name = "Terra"
	dirt.material_type = BlockData.MaterialType.SOIL
	dirt.is_solid = true
	dirt.hardness = 0.6
	dirt.min_mining_power = 1
	dirt.atlas_coords = Vector2i(0, 0)
	dirt.drop_item_id = "dirt"
	_blocks[BlockID.DIRT] = dirt

	# 2: STONE
	var stone := BlockData.new()
	stone.id = BlockID.STONE
	stone.name = "Pedra"
	stone.material_type = BlockData.MaterialType.STONE
	stone.is_solid = true
	stone.hardness = 1.2
	stone.min_mining_power = 1
	stone.atlas_coords = Vector2i(1, 0)
	stone.drop_item_id = "stone"
	_blocks[BlockID.STONE] = stone

	# 3: DEEP STONE
	var deep_stone := BlockData.new()
	deep_stone.id = BlockID.DEEP_STONE
	deep_stone.name = "Pedra Profunda"
	deep_stone.material_type = BlockData.MaterialType.DEEP_STONE
	deep_stone.is_solid = true
	deep_stone.hardness = 2.6
	deep_stone.min_mining_power = 2
	deep_stone.atlas_coords = Vector2i(2, 0)
	deep_stone.drop_item_id = "deep_stone"
	_blocks[BlockID.DEEP_STONE] = deep_stone

	# 4: METALLIC ORE
	var metallic_ore := BlockData.new()
	metallic_ore.id = BlockID.METALLIC_ORE
	metallic_ore.name = "Minério Metálico"
	metallic_ore.material_type = BlockData.MaterialType.ORE
	metallic_ore.is_solid = true
	metallic_ore.hardness = 2.0
	metallic_ore.min_mining_power = 2
	metallic_ore.atlas_coords = Vector2i(3, 0)
	metallic_ore.drop_item_id = "metallic_ore"
	_blocks[BlockID.METALLIC_ORE] = metallic_ore

	# 5: CYAN CRYSTAL
	var crystal := BlockData.new()
	crystal.id = BlockID.CYAN_CRYSTAL
	crystal.name = "Cristal Ciano"
	crystal.material_type = BlockData.MaterialType.CRYSTAL
	crystal.is_solid = true
	crystal.hardness = 3.2
	crystal.min_mining_power = 2
	crystal.atlas_coords = Vector2i(4, 0)
	crystal.drop_item_id = "cyan_crystal"
	_blocks[BlockID.CYAN_CRYSTAL] = crystal

	# 6: GRASS
	var grass := BlockData.new()
	grass.id = BlockID.GRASS
	grass.name = "Terra com Vegetação"
	grass.material_type = BlockData.MaterialType.ORGANIC
	grass.is_solid = true
	grass.hardness = 0.6
	grass.min_mining_power = 1
	grass.atlas_coords = Vector2i(5, 0)
	grass.drop_item_id = "dirt"
	_blocks[BlockID.GRASS] = grass

static func get_block(id: int) -> BlockData:
	if not _initialized:
		init_blocks()
	return _blocks.get(id, _blocks[BlockID.AIR])

static func is_solid(id: int) -> bool:
	return get_block(id).is_solid

static func get_atlas_coords(id: int) -> Vector2i:
	return get_block(id).atlas_coords

static func get_all_blocks() -> Array:
	if not _initialized:
		init_blocks()
	var list: Array = []
	for id in _blocks.keys():
		if id != BlockID.AIR:
			list.append(_blocks[id])
	return list
