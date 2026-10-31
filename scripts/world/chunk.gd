class_name Chunk
extends Node2D

const CHUNK_SIZE: int = 32
const BLOCK_SIZE: int = 16

var chunk_coords: Vector2i = Vector2i.ZERO
var raw_blocks: Array[int] = []
var is_modified: bool = false

var tile_map_layer: TileMapLayer

func _init(coords: Vector2i = Vector2i.ZERO) -> void:
	chunk_coords = coords
	position = Vector2(coords.x * CHUNK_SIZE * BLOCK_SIZE, coords.y * CHUNK_SIZE * BLOCK_SIZE)
	name = "Chunk_%d_%d" % [coords.x, coords.y]
	raw_blocks.resize(CHUNK_SIZE * CHUNK_SIZE)
	raw_blocks.fill(BlockManager.BlockID.AIR)

func setup_tilemap(tileset: TileSet) -> void:
	tile_map_layer = TileMapLayer.new()
	tile_map_layer.name = "TileMapLayer"
	tile_map_layer.tile_set = tileset
	add_child(tile_map_layer)

func build_mesh() -> void:
	if not tile_map_layer:
		return
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var block_id: int = raw_blocks[ly * CHUNK_SIZE + lx]
			if block_id != BlockManager.BlockID.AIR:
				var coords: Vector2i = BlockManager.get_atlas_coords(block_id)
				tile_map_layer.set_cell(Vector2i(lx, ly), 0, coords)
			else:
				tile_map_layer.set_cell(Vector2i(lx, ly), -1, Vector2i(-1, -1))

func set_block_local(lx: int, ly: int, block_id: int) -> void:
	if lx < 0 or lx >= CHUNK_SIZE or ly < 0 or ly >= CHUNK_SIZE:
		return
	var index: int = ly * CHUNK_SIZE + lx
	raw_blocks[index] = block_id
	is_modified = true

	if tile_map_layer:
		if block_id != BlockManager.BlockID.AIR:
			var coords: Vector2i = BlockManager.get_atlas_coords(block_id)
			tile_map_layer.set_cell(Vector2i(lx, ly), 0, coords)
		else:
			tile_map_layer.set_cell(Vector2i(lx, ly), -1, Vector2i(-1, -1))

func get_block_local(lx: int, ly: int) -> int:
	if lx < 0 or lx >= CHUNK_SIZE or ly < 0 or ly >= CHUNK_SIZE:
		return BlockManager.BlockID.AIR
	return raw_blocks[ly * CHUNK_SIZE + lx]
