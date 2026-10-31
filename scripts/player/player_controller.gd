class_name PlayerController
extends CharacterBody2D

signal stats_changed(health: float, max_health: float, oxygen: float, max_oxygen: float, depth: int, selected_block: int)

@export_group("Movement")
@export var move_speed: float = 160.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
@export var air_acceleration: float = 600.0
@export var air_friction: float = 300.0

@export_group("Jump & Gravity")
@export var jump_velocity: float = -370.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 550.0

@export_group("Building & Mining")
@export var reach_distance: float = 110.0
@export var mine_cooldown: float = 0.15

@export_group("Stats")
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var max_oxygen: float = 100.0
@export var current_oxygen: float = 100.0
@export var oxygen_depletion_rate: float = 1.5 # % per second when underground
@export var meters_per_block: float = 1.0 # 1 block = 1 meter

var selected_block_id: int = BlockManager.BlockID.DIRT
var chunk_manager: ChunkManager
var _mine_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var selector: Sprite2D = $SelectorReticle
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Ensure selector top-level or detached from player rotation
	if selector:
		selector.top_level = true
	_ensure_default_inputs()

func _ensure_default_inputs() -> void:
	# Fallback input registration in case project.godot wasn't reloaded
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"hotbar_1": [KEY_1],
		"hotbar_2": [KEY_2],
		"hotbar_3": [KEY_3],
		"hotbar_4": [KEY_4],
		"hotbar_5": [KEY_5],
		"hotbar_6": [KEY_6],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

	if not InputMap.has_action("mine"):
		InputMap.add_action("mine")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("mine", mb)

	if not InputMap.has_action("build"):
		InputMap.add_action("build")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("build", mb)

func _physics_process(delta: float) -> void:
	# 1. Gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# 2. Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 3. Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	var accel := acceleration if is_on_floor() else air_acceleration
	var frict := friction if is_on_floor() else air_friction

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, accel * delta)
		if sprite:
			sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, frict * delta)

	move_and_slide()

	# 4. Survival & Oxygen
	_process_survival(delta)

	# 5. Mining & Building cooldown
	if _mine_timer > 0.0:
		_mine_timer -= delta

	# 6. Stream chunks around player
	if chunk_manager:
		chunk_manager.update_chunks_around(global_position)

	# 7. Update HUD
	_emit_hud_stats()

func _process(delta: float) -> void:
	_update_selector()
	_handle_interaction()

func _input(event: InputEvent) -> void:
	# Hotbar selection via numeric keys
	if event.is_action_pressed("hotbar_1"):
		selected_block_id = BlockManager.BlockID.DIRT
	elif event.is_action_pressed("hotbar_2"):
		selected_block_id = BlockManager.BlockID.STONE
	elif event.is_action_pressed("hotbar_3"):
		selected_block_id = BlockManager.BlockID.DEEP_STONE
	elif event.is_action_pressed("hotbar_4"):
		selected_block_id = BlockManager.BlockID.METALLIC_ORE
	elif event.is_action_pressed("hotbar_5"):
		selected_block_id = BlockManager.BlockID.CYAN_CRYSTAL
	elif event.is_action_pressed("hotbar_6"):
		selected_block_id = BlockManager.BlockID.GRASS

	# Mouse wheel hotbar cycle
	if event is InputEventMouseButton and event.is_pressed():
		var blocks = [
			BlockManager.BlockID.DIRT,
			BlockManager.BlockID.STONE,
			BlockManager.BlockID.DEEP_STONE,
			BlockManager.BlockID.METALLIC_ORE,
			BlockManager.BlockID.CYAN_CRYSTAL,
			BlockManager.BlockID.GRASS
		]
		var current_idx: int = blocks.find(selected_block_id)
		if current_idx == -1:
			current_idx = 0

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_idx = (current_idx - 1 + blocks.size()) % blocks.size()
			selected_block_id = blocks[current_idx]
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_idx = (current_idx + 1) % blocks.size()
			selected_block_id = blocks[current_idx]

func _update_selector() -> void:
	if not selector:
		return
	var mouse_pos := get_global_mouse_position()
	var block_coords := ChunkManager.global_pixel_to_block(mouse_pos)
	selector.global_position = Vector2(block_coords.x * 16 + 8, block_coords.y * 16 + 8)

	var dist := global_position.distance_to(mouse_pos)
	if dist <= reach_distance:
		selector.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		selector.modulate = Color(1.0, 0.2, 0.2, 0.35)

func _handle_interaction() -> void:
	if not chunk_manager:
		return

	var mouse_pos := get_global_mouse_position()
	var dist := global_position.distance_to(mouse_pos)
	if dist > reach_distance:
		return

	var target_block := ChunkManager.global_pixel_to_block(mouse_pos)

	# Mine block (LMB)
	if Input.is_action_pressed("mine") and _mine_timer <= 0.0:
		var current_id := chunk_manager.get_block(target_block)
		if current_id != BlockManager.BlockID.AIR:
			chunk_manager.set_block(target_block, BlockManager.BlockID.AIR)
			_mine_timer = mine_cooldown

	# Place block (RMB)
	elif Input.is_action_just_pressed("build"):
		var current_id := chunk_manager.get_block(target_block)
		if current_id == BlockManager.BlockID.AIR:
			# Check intersection with player body
			var player_rect := Rect2(global_position.x - 12, global_position.y - 42, 24, 86)
			var block_rect := Rect2(target_block.x * 16, target_block.y * 16, 16, 16)
			if not player_rect.intersects(block_rect):
				chunk_manager.set_block(target_block, selected_block_id)

func _process_survival(delta: float) -> void:
	# Depth is considered underground when y > 0
	if global_position.y > 32.0:
		current_oxygen = max(0.0, current_oxygen - oxygen_depletion_rate * delta)
		if current_oxygen <= 0.0:
			# Suffocation damage
			current_health = max(0.0, current_health - 4.0 * delta)
	else:
		# Surface replenishes oxygen quickly
		current_oxygen = min(max_oxygen, current_oxygen + 25.0 * delta)

func _emit_hud_stats() -> void:
	# Depth in meters relative to surface (y = 0)
	var current_depth: int = max(0, int(floor(global_position.y / 16.0) * meters_per_block))
	stats_changed.emit(current_health, max_health, current_oxygen, max_oxygen, current_depth, selected_block_id)

