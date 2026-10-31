class_name ChunkManager
extends Node2D

const Chunk = preload("res://scripts/world/chunk.gd")
const DroppedItem = preload("res://scripts/items/dropped_item.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")

const CHUNK_SIZE: int = 32
const BLOCK_SIZE: int = 16

@export var tileset: TileSet
@export var world_seed: int = 1337
@export var load_radius: int = 2
@export var unload_radius: int = 4
@export var world_id: String = "world_001"

var generator: WorldGenerator
var active_chunks: Dictionary = {} # Vector2i -> Chunk
var modified_chunks_cache: Dictionary = {} # Vector2i -> Dictionary ("lx,ly" -> block_id)
var dropped_items_cache: Dictionary = {} # Vector2i -> Array[Dictionary]

var dropped_item_scene: PackedScene
var items_container: Node2D

signal block_changed(global_block_pos: Vector2i, new_block_id: int)

func _ready() -> void:
	if not tileset:
		tileset = load("res://resources/tileset.tres")
	dropped_item_scene = load("res://scenes/items/dropped_item.tscn")

	items_container = Node2D.new()
	items_container.name = "DroppedItems"
	add_child(items_container)

	# Check for world metadata save
	var meta := SaveManager.load_world_meta(world_id)
	if meta.has("seed"):
		world_seed = int(meta["seed"])
	else:
		SaveManager.save_world_meta(world_id, world_seed)

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

	# 1. Base procedural generation
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var gx: int = coords.x * CHUNK_SIZE + lx
			var gy: int = coords.y * CHUNK_SIZE + ly
			var block_id: int = generator.generate_block(gx, gy)
			chunk.raw_blocks[ly * CHUNK_SIZE + lx] = block_id

	# 2. Check and apply saved modifications
	var mods: Dictionary = {}
	var saved_items: Array = []

	if modified_chunks_cache.has(coords):
		mods = modified_chunks_cache[coords]
		if dropped_items_cache.has(coords):
			saved_items = dropped_items_cache[coords]
	else:
		# Query disk
		var disk_data := SaveManager.load_chunk(world_id, coords)
		if disk_data.has("modified_blocks") and (disk_data["modified_blocks"] is Dictionary):
			mods = disk_data["modified_blocks"]
			modified_chunks_cache[coords] = mods
		if disk_data.has("dropped_items") and (disk_data["dropped_items"] is Array):
			saved_items = disk_data["dropped_items"]
			dropped_items_cache[coords] = saved_items

	if not mods.is_empty():
		chunk.apply_modifications(mods)

	chunk.build_mesh()
	add_child(chunk)
	active_chunks[coords] = chunk

	# 3. Restore dropped items in this chunk
	for item_dict in saved_items:
		if item_dict is Dictionary:
			var item_id: String = str(item_dict.get("item_id", ""))
			var count: int = int(item_dict.get("count", 1))
			var pos := Vector2(float(item_dict.get("x", 0.0)), float(item_dict.get("y", 0.0)))
			var uid: String = str(item_dict.get("id", ""))
			spawn_dropped_item(item_id, count, pos, uid)

func _unload_chunk(coords: Vector2i) -> void:
	if not active_chunks.has(coords):
		return

	var chunk: Chunk = active_chunks[coords]
	var bounds: Rect2 = chunk.get_bounds_rect()

	# Collect and remove dropped items currently inside this chunk
	var chunk_items: Array = []
	if items_container:
		for child in items_container.get_children():
			if child is DroppedItem and not child.is_collected:
				if bounds.has_point(child.global_position):
					chunk_items.append({
						"id": child.unique_id,
						"item_id": child.item_id,
						"count": child.count,
						"x": child.global_position.x,
						"y": child.global_position.y
					})
					child.queue_free()

	dropped_items_cache[coords] = chunk_items

	if chunk.is_modified or not chunk_items.is_empty():
		modified_chunks_cache[coords] = chunk.modified_blocks.duplicate()
		SaveManager.save_chunk(world_id, coords, chunk.modified_blocks, chunk_items)

	active_chunks.erase(coords)
	chunk.queue_free()

func get_block(global_block_pos: Vector2i) -> int:
	var c_coords: Vector2i = block_to_chunk(global_block_pos)
	var l_coords: Vector2i = block_to_local(global_block_pos)

	if active_chunks.has(c_coords):
		return active_chunks[c_coords].get_block_local(l_coords.x, l_coords.y)
	elif modified_chunks_cache.has(c_coords):
		var key := "%d,%d" % [l_coords.x, l_coords.y]
		if modified_chunks_cache[c_coords].has(key):
			return int(modified_chunks_cache[c_coords][key])
		return generator.generate_block(global_block_pos.x, global_block_pos.y)
	else:
		return generator.generate_block(global_block_pos.x, global_block_pos.y)

func set_block(global_block_pos: Vector2i, block_id: int) -> bool:
	var c_coords: Vector2i = block_to_chunk(global_block_pos)
	var l_coords: Vector2i = block_to_local(global_block_pos)

	if not active_chunks.has(c_coords):
		_load_chunk(c_coords)

	var chunk: Chunk = active_chunks[c_coords]
	chunk.set_block_local(l_coords.x, l_coords.y, block_id)
	modified_chunks_cache[c_coords] = chunk.modified_blocks.duplicate()

	block_changed.emit(global_block_pos, block_id)
	return true

## Mines a block, removes it from terrain, and spawns the corresponding dropped item resource
func mine_block(global_block_pos: Vector2i) -> bool:
	var current_id := get_block(global_block_pos)
	if current_id == BlockManager.BlockID.AIR:
		return false

	var block_data := BlockManager.get_block(current_id)
	var drop_id := block_data.drop_item_id
	if drop_id != "":
		var spawn_pos := Vector2(global_block_pos.x * BLOCK_SIZE + 8, global_block_pos.y * BLOCK_SIZE + 8)
		spawn_dropped_item(drop_id, 1, spawn_pos)

	set_block(global_block_pos, BlockManager.BlockID.AIR)
	return true

func spawn_dropped_item(item_id: String, count: int, spawn_pos: Vector2, uid: String = "") -> Node2D:
	if not dropped_item_scene:
		dropped_item_scene = load("res://scenes/items/dropped_item.tscn")
	var item_node = dropped_item_scene.instantiate()
	item_node.setup(item_id, count, uid)
	item_node.global_position = spawn_pos
	# Initial small pop velocity
	item_node.velocity = Vector2(randf_range(-35.0, 35.0), randf_range(-110.0, -60.0))

	if items_container:
		items_container.add_child(item_node)
	else:
		add_child(item_node)
	return item_node

func save_all_active_chunks() -> void:
	for coords in active_chunks.keys():
		var chunk: Chunk = active_chunks[coords]
		var bounds: Rect2 = chunk.get_bounds_rect()

		var chunk_items: Array = []
		if items_container:
			for child in items_container.get_children():
				if child is DroppedItem and not child.is_collected:
					if bounds.has_point(child.global_position):
						chunk_items.append({
							"id": child.unique_id,
							"item_id": child.item_id,
							"count": child.count,
							"x": child.global_position.x,
							"y": child.global_position.y
						})

		if chunk.is_modified or not chunk_items.is_empty():
			modified_chunks_cache[coords] = chunk.modified_blocks.duplicate()
			dropped_items_cache[coords] = chunk_items
			SaveManager.save_chunk(world_id, coords, chunk.modified_blocks, chunk_items)
