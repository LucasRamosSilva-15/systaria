class_name Main
extends Node2D

const SaveManager = preload("res://scripts/save/save_manager.gd")

@export var world_id: String = "world_001"
@export var auto_save_interval: float = 60.0
@export var ambient_cave_color: Color = Color(0.26, 0.30, 0.38, 1.0)

@onready var world = $World
@onready var chunk_manager = $World/ChunkManager
@onready var player = $Player
@onready var hud = $HUD
@onready var inventory_ui = $UI_Layer/InventoryUI
@onready var crafting_ui = $UI_Layer/CraftingUI
@onready var chest_ui = $UI_Layer/ChestUI
@onready var atmosphere_modulate = $AtmosphereModulate

var _auto_save_timer: float = 0.0

func _ready() -> void:
	print("[Main] Initializing ABYSSUS Stage 3...")

	if atmosphere_modulate:
		atmosphere_modulate.color = ambient_cave_color

	# 1. Connect world and inventory systems
	player.chunk_manager = chunk_manager
	chunk_manager.world_id = world_id

	# 2. Connect HUD, Inventory UI, Crafting UI, Chest UI
	player.stats_changed.connect(hud.update_stats)
	hud.connect_inventory(player.inventory)

	if inventory_ui:
		inventory_ui.set_inventory(player.inventory)
		player.inventory_toggle_requested.connect(inventory_ui.toggle)
		inventory_ui.visibility_changed_to.connect(_on_inventory_visibility_changed)

	if crafting_ui:
		crafting_ui.set_inventory(player.inventory)
		player.crafting_toggle_requested.connect(crafting_ui.toggle)
		crafting_ui.visibility_changed_to.connect(_on_crafting_visibility_changed)

	if chest_ui:
		player.chest_interact_requested.connect(_on_chest_interact_requested)
		chest_ui.visibility_changed_to.connect(_on_chest_visibility_changed)

	player.quick_save_requested.connect(save_game)

	# 3. Load or create player/world
	_setup_session()

	print("[Main] Ready. Active chunks: %d | Player pos: %s" % [chunk_manager.active_chunks.size(), player.global_position])

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= auto_save_interval:
		_auto_save_timer = 0.0
		save_game(true)

	# Keep crafting station updated on crafting UI
	if crafting_ui and crafting_ui.visible:
		crafting_ui.set_crafting_station(player.current_crafting_station)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[Main] Exit requested: Performing safe autosave...")
		save_game(false)

func _setup_session() -> void:
	if SaveManager.has_save(world_id):
		print("[Main] Save file found for '%s'. Loading persistent state..." % world_id)
		SaveManager.load_player(world_id, player)

		_ensure_player_position_valid()
		chunk_manager.update_chunks_around(player.global_position)
	else:
		print("[Main] Creating fresh world '%s'..." % world_id)
		_spawn_player_safely()

		# Initial starting explorer supplies
		player.inventory.add_item("basic_pickaxe", 1)
		player.inventory.add_item("wood", 16)
		player.inventory.add_item("dirt", 10)
		player.inventory.add_item("stone", 10)

		save_game(false)

func _spawn_player_safely() -> void:
	var surface_y: int = int(chunk_manager.generator.get_surface_height(0))
	player.global_position = Vector2(8.0, (surface_y - 4) * 16.0)
	chunk_manager.update_chunks_around(player.global_position)

func _ensure_player_position_valid() -> void:
	var block_pos := Vector2i(int(floor(player.global_position.x / 16.0)), int(floor(player.global_position.y / 16.0)))
	var current_block: int = int(chunk_manager.get_block(block_pos))
	if current_block != BlockManager.BlockID.AIR:
		var safe_y: int = block_pos.y
		while safe_y > -50 and chunk_manager.get_block(Vector2i(block_pos.x, safe_y)) != BlockManager.BlockID.AIR:
			safe_y -= 1
		player.global_position.y = (safe_y - 2) * 16.0

func _on_inventory_visibility_changed(is_open: bool) -> void:
	player.is_inventory_open = is_open
	if is_open:
		if crafting_ui:
			crafting_ui.close()
		if chest_ui:
			chest_ui.close()

func _on_crafting_visibility_changed(is_open: bool) -> void:
	player.is_crafting_open = is_open
	if is_open:
		if inventory_ui:
			inventory_ui.close()
		if chest_ui:
			chest_ui.close()

func _on_chest_visibility_changed(is_open: bool) -> void:
	player.is_chest_open = is_open
	if is_open:
		if inventory_ui:
			inventory_ui.close()
		if crafting_ui:
			crafting_ui.close()

func _on_chest_interact_requested(chest_node: Variant) -> void:
	if not chest_ui:
		return
	if chest_node:
		chest_ui.open_chest(chest_node, player.inventory)
	else:
		chest_ui.close()

func save_game(is_auto: bool = false) -> void:
	chunk_manager.save_all_active_chunks()
	SaveManager.save_player(world_id, player)
	SaveManager.save_world_meta(world_id, chunk_manager.world_seed)

	var msg := "Salvamento Automático..." if is_auto else "Jogo Salvo com Sucesso!"
	if hud:
		hud.show_notification(msg)
	print("[SaveManager] %s at %s" % [msg, Time.get_time_string_from_system()])
