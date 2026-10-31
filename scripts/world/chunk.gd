class_name Chunk
extends Node2D

const CHUNK_SIZE: int = 32
const BLOCK_SIZE: int = 16

var chunk_coords: Vector2i = Vector2i.ZERO
var raw_blocks: Array[int] = []
var modified_blocks: Dictionary = {} # "lx,ly" -> block_id
var is_modified: bool = false

var tile_map_layer: TileMapLayer
var crystal_lights: Dictionary = {} # Vector2i -> PointLight2D
var lights_container: Node2D
var light_texture: Texture2D

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
	
	lights_container = Node2D.new()
	lights_container.name = "ChunkLights"
	add_child(lights_container)
	light_texture = load("res://assets/characters/light.png")

func build_mesh() -> void:
	if not tile_map_layer:
		return
	_clear_crystal_lights()
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var block_id: int = raw_blocks[ly * CHUNK_SIZE + lx]
			if block_id != BlockManager.BlockID.AIR:
				var coords: Vector2i = BlockManager.get_atlas_coords(block_id)
				tile_map_layer.set_cell(Vector2i(lx, ly), 0, coords)
				if block_id == BlockManager.BlockID.CYAN_CRYSTAL:
					_add_crystal_light(lx, ly)
			else:
				tile_map_layer.set_cell(Vector2i(lx, ly), -1, Vector2i(-1, -1))

func set_block_local(lx: int, ly: int, block_id: int) -> void:
	if lx < 0 or lx >= CHUNK_SIZE or ly < 0 or ly >= CHUNK_SIZE:
		return
	var index: int = ly * CHUNK_SIZE + lx
	var old_id: int = raw_blocks[index]
	raw_blocks[index] = block_id
	modified_blocks["%d,%d" % [lx, ly]] = block_id
	is_modified = true

	if old_id == BlockManager.BlockID.CYAN_CRYSTAL and block_id != BlockManager.BlockID.CYAN_CRYSTAL:
		_remove_crystal_light(lx, ly)
	elif block_id == BlockManager.BlockID.CYAN_CRYSTAL and old_id != BlockManager.BlockID.CYAN_CRYSTAL:
		_add_crystal_light(lx, ly)

	if tile_map_layer:
		if block_id != BlockManager.BlockID.AIR:
			var coords: Vector2i = BlockManager.get_atlas_coords(block_id)
			tile_map_layer.set_cell(Vector2i(lx, ly), 0, coords)
		else:
			tile_map_layer.set_cell(Vector2i(lx, ly), -1, Vector2i(-1, -1))

func _clear_crystal_lights() -> void:
	for light in crystal_lights.values():
		if is_instance_valid(light):
			light.queue_free()
	crystal_lights.clear()

func _add_crystal_light(lx: int, ly: int) -> void:
	var pos_key := Vector2i(lx, ly)
	if crystal_lights.has(pos_key):
		return
	if not lights_container:
		lights_container = Node2D.new()
		lights_container.name = "ChunkLights"
		add_child(lights_container)
	if not light_texture:
		light_texture = load("res://assets/characters/light.png")

	var light := PointLight2D.new()
	light.texture = light_texture
	light.texture_scale = 0.55
	light.color = Color(0.2, 0.9, 1.0, 1.0)
	light.energy = 0.85
	light.shadow_enabled = false
	light.position = Vector2(lx * BLOCK_SIZE + 8, ly * BLOCK_SIZE + 8)
	lights_container.add_child(light)
	crystal_lights[pos_key] = light

func _remove_crystal_light(lx: int, ly: int) -> void:
	var pos_key := Vector2i(lx, ly)
	if crystal_lights.has(pos_key):
		var light: PointLight2D = crystal_lights[pos_key]
		if is_instance_valid(light):
			light.queue_free()
		crystal_lights.erase(pos_key)

func get_block_local(lx: int, ly: int) -> int:
	if lx < 0 or lx >= CHUNK_SIZE or ly < 0 or ly >= CHUNK_SIZE:
		return BlockManager.BlockID.AIR
	return raw_blocks[ly * CHUNK_SIZE + lx]

func apply_modifications(mods: Dictionary) -> void:
	for key in mods.keys():
		var parts = str(key).split(",")
		if parts.size() == 2:
			var lx: int = int(parts[0])
			var ly: int = int(parts[1])
			var b_id: int = int(mods[key])
			if lx >= 0 and lx < CHUNK_SIZE and ly >= 0 and ly < CHUNK_SIZE:
				raw_blocks[ly * CHUNK_SIZE + lx] = b_id
				modified_blocks[key] = b_id
	is_modified = true

func get_bounds_rect() -> Rect2:
	return Rect2(position.x, position.y, CHUNK_SIZE * BLOCK_SIZE, CHUNK_SIZE * BLOCK_SIZE)
