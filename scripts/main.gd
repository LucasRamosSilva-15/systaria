class_name Main
extends Node2D

@onready var world: Node2D = $World
@onready var chunk_manager: ChunkManager = $World/ChunkManager
@onready var player: PlayerController = $Player
@onready var hud: HUDController = $HUD

func _ready() -> void:
	print("[Main] Initializing ABYSSUS...")
	# 1. Connect player to world systems
	player.chunk_manager = chunk_manager
	player.stats_changed.connect(hud.update_stats)

	# 2. Spawn player safely on surface
	_spawn_player_safely()
	print("[Main] Initialization complete. Active chunks: %d | Player spawn: %s" % [chunk_manager.active_chunks.size(), player.global_position])

func _spawn_player_safely() -> void:
	var surface_y: int = chunk_manager.generator.get_surface_height(0)
	# Spawn 4 blocks above surface at x = 0
	player.global_position = Vector2(8.0, (surface_y - 4) * 16.0)

	# Preload initial chunks immediately
	chunk_manager.update_chunks_around(player.global_position)
