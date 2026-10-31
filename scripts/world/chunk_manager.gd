class_name ChunkManager
extends Node2D

const CHUNK_SIZE: int = 32
const BLOCK_SIZE: int = 16

@export var tileset: TileSet
@export var world_seed: int = 1337
@export var load_radius: int = 2
@export var unload_radius: int = 4

var generator: WorldGenerator
var active_chunks: Dictionary = {} # Vector2i -> Chunk
var modified_chunks: Dictionary = {} # Vector2i -> Array[int]

signal block_changed(global_block_pos: Vector2i, new_block_id: int)

func _ready() -> void:
	if not tileset:
		tileset = load("res://resources/tileset.tres")
	generator = WorldGenerator.new(world_seed)

static func block_to_chunk(block_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(block_pos.x) / CHUNK_SIZE)),
		int(floor(float(block_pos.y) / CHUNK_SIZE))
	)

static func block_to_local(block_pos: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(block_pos.x, CHUNK_SIZE),
		posmod(block_pos.y, CHUNK_SIZE)
	)

static func global_pixel_to_block(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pixel_pos.x / BLOCK_SIZE)),
		int(floor(pixel_pos.y / BLOCK_SIZE))
	)

static func block_to_global_pixel(block_pos: Vector2i) -> Vector2:
	return Vector2(block_pos.x * BLOCK_SIZE, block_pos.y * BLOCK_SIZE)

func update_chunks_around(target_pos: Vector2) -> void:
	var center_block: Vector2i = global_pixel_to_block(target_pos)
	var center_chunk: Vector2i = block_to_chunk(center_block)

	# 1. Load missing chunks within load_radius
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var c_coords := Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			if not active_chunks.has(c_coords):
				_load_chunk(c_coords)

	# 2. Unload chunks farther than unload_radius
	var chunks_to_remove: Array[Vector2i] = []
	for c_coords in active_chunks.keys():
		var dist_x: int = abs(c_coords.x - center_chunk.x)
		var dist_y: int = abs(c_coords.y - center_chunk.y)
		if dist_x > unload_radius or dist_y > unload_radius:
			chunks_to_remove.append(c_coords)

	for c_coords in chunks_to_remove:
		_unload_chunk(c_coords)

func _load_chunk(coords: Vector2i) -> void:
	var chunk := Chunk.new(coords)
	chunk.setup_tilemap(tileset)

	if modified_chunks.has(coords):
		# Restore previously modified chunk
		var saved_data: Array[int] = modified_chunks[coords]
		chunk.raw_blocks = saved_data.duplicate()
	else:
		# Procedurally generate chunk content
		for ly in range(CHUNK_SIZE):
			for lx in range(CHUNK_SIZE):
				var gx: int = coords.x * CHUNK_SIZE + lx
				var gy: int = coords.y * CHUNK_SIZE + ly
				var block_id: int = generator.generate_block(gx, gy)
				chunk.raw_blocks[ly * CHUNK_SIZE + lx] = block_id

	chunk.build_mesh()
	add_child(chunk)
	active_chunks[coords] = chunk

func _unload_chunk(coords: Vector2i) -> void:
	if active_chunks.has(coords):
		var chunk: Chunk = active_chunks[coords]
		if chunk.is_modified:
			modified_chunks[coords] = chunk.raw_blocks.duplicate()
		active_chunks.erase(coords)
		chunk.queue_free()

func get_block(global_block_pos: Vector2i) -> int:
	var c_coords: Vector2i = block_to_chunk(global_block_pos)
	var l_coords: Vector2i = block_to_local(global_block_pos)

	if active_chunks.has(c_coords):
		return active_chunks[c_coords].get_block_local(l_coords.x, l_coords.y)
	elif modified_chunks.has(c_coords):
		var index: int = l_coords.y * CHUNK_SIZE + l_coords.x
		return modified_chunks[c_coords][index]
	else:
		return generator.generate_block(global_block_pos.x, global_block_pos.y)

func set_block(global_block_pos: Vector2i, block_id: int) -> bool:
	var c_coords: Vector2i = block_to_chunk(global_block_pos)
	var l_coords: Vector2i = block_to_local(global_block_pos)

	if not active_chunks.has(c_coords):
		_load_chunk(c_coords)

	var chunk: Chunk = active_chunks[c_coords]
	chunk.set_block_local(l_coords.x, l_coords.y, block_id)
	modified_chunks[c_coords] = chunk.raw_blocks.duplicate()

	block_changed.emit(global_block_pos, block_id)
	return true

