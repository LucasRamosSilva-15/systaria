class_name WorldGenerator
extends RefCounted

@export var world_seed: int = 1337

var _surface_noise: FastNoiseLite
var _cave_noise: FastNoiseLite
var _ore_noise: FastNoiseLite
var _crystal_noise: FastNoiseLite

func _init(seed_val: int = 1337) -> void:
	world_seed = seed_val
	_setup_noises()

func _setup_noises() -> void:
	# Surface altitude noise
	_surface_noise = FastNoiseLite.new()
	_surface_noise.seed = world_seed
	_surface_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_surface_noise.frequency = 0.02

	# Cave chambers and tunnels
	_cave_noise = FastNoiseLite.new()
	_cave_noise.seed = world_seed + 101
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_noise.frequency = 0.04
	_cave_noise.fractal_octaves = 2

	# Metallic ore veins
	_ore_noise = FastNoiseLite.new()
	_ore_noise.seed = world_seed + 202
	_ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ore_noise.frequency = 0.08

	# Cyan crystal pockets
	_crystal_noise = FastNoiseLite.new()
	_crystal_noise.seed = world_seed + 303
	_crystal_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_crystal_noise.frequency = 0.09

func get_surface_height(global_x: int) -> int:
	return int(round(_surface_noise.get_noise_1d(global_x) * 8.0))

func generate_block(global_x: int, global_y: int) -> int:
	var surface_y: int = get_surface_height(global_x)

	# Above surface: Air
	if global_y < surface_y:
		return BlockManager.BlockID.AIR

	# Surface top layer: Grass
	if global_y == surface_y:
		return BlockManager.BlockID.GRASS

	# Underground caves check (leave top 3 blocks solid to avoid exposed floating grass)
	if global_y > surface_y + 3:
		var cave_val: float = _cave_noise.get_noise_2d(global_x, global_y)
		if cave_val > 0.32:
			return BlockManager.BlockID.AIR

	# Veins and crystals
	# Cyan Crystal (deep only)
	if global_y > surface_y + 32:
		var crystal_val: float = _crystal_noise.get_noise_2d(global_x, global_y)
		if crystal_val > 0.48:
			return BlockManager.BlockID.CYAN_CRYSTAL

	# Metallic Ore (stone & deep stone layers)
	if global_y > surface_y + 6:
		var ore_val: float = _ore_noise.get_noise_2d(global_x, global_y)
		if ore_val > 0.46:
			return BlockManager.BlockID.METALLIC_ORE

	# Base layer stratification
	if global_y <= surface_y + 6:
		return BlockManager.BlockID.DIRT
	elif global_y <= surface_y + 35:
		return BlockManager.BlockID.STONE
	else:
		return BlockManager.BlockID.DEEP_STONE
