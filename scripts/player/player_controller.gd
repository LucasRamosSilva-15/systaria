class_name PlayerController
extends CharacterBody2D

const Inventory = preload("res://scripts/inventory/inventory.gd")

signal stats_changed(health: float, max_health: float, oxygen: float, max_oxygen: float, depth: int, selected_hotbar_idx: int)
signal inventory_toggle_requested
signal quick_save_requested

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
@export var oxygen_depletion_rate: float = 1.5
@export var meters_per_block: float = 1.0

var inventory: Inventory
var selected_hotbar_index: int = 0
var chunk_manager: Node2D
var is_inventory_open: bool = false
var _mine_timer: float = 0.0

static func pixel_to_block(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pixel_pos.x / 16.0)),
		int(floor(pixel_pos.y / 16.0))
	)

@onready var sprite: Sprite2D = $Sprite2D
@onready var selector: Sprite2D = $SelectorReticle
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _init() -> void:
	inventory = Inventory.new(40)

func _ready() -> void:
	add_to_group("player")
	if selector:
		selector.top_level = true
	_ensure_default_inputs()

func _ensure_default_inputs() -> void:
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
		"hotbar_7": [KEY_7],
		"hotbar_8": [KEY_8],
		"hotbar_9": [KEY_9],
		"hotbar_0": [KEY_0],
		"toggle_inventory": [KEY_E],
		"quick_save": [KEY_F5],
		"menu": [KEY_ESCAPE],
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

	# 2. Jump (only when inventory is closed)
	if not is_inventory_open and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 3. Horizontal movement
	var direction := 0.0
	if not is_inventory_open:
		direction = Input.get_axis("move_left", "move_right")

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
	if not is_inventory_open:
		_update_selector()
		_handle_interaction()
	else:
		if selector:
			selector.visible = false

func _input(event: InputEvent) -> void:
	# Toggle Inventory
	if event.is_action_pressed("toggle_inventory"):
		inventory_toggle_requested.emit()
	elif event.is_action_pressed("menu"):
		if is_inventory_open:
			inventory_toggle_requested.emit()

	# Quick Save
	if event.is_action_pressed("quick_save"):
		quick_save_requested.emit()

	# Hotbar selection via numeric keys (only if inventory closed)
	if not is_inventory_open:
		var hotbar_actions = [
			"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
			"hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_0"
		]
		for i in range(hotbar_actions.size()):
			if event.is_action_pressed(hotbar_actions[i]):
				selected_hotbar_index = i
				_emit_hud_stats()
				break

		# Mouse wheel hotbar cycle
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				selected_hotbar_index = (selected_hotbar_index - 1 + 10) % 10
				_emit_hud_stats()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				selected_hotbar_index = (selected_hotbar_index + 1) % 10
				_emit_hud_stats()

func _update_selector() -> void:
	if not selector:
		return
	selector.visible = true
	var mouse_pos := get_global_mouse_position()
	var block_coords := pixel_to_block(mouse_pos)
	selector.global_position = Vector2(block_coords.x * 16 + 8, block_coords.y * 16 + 8)

	var dist := global_position.distance_to(mouse_pos)
	if dist <= reach_distance:
		selector.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		selector.modulate = Color(1.0, 0.2, 0.2, 0.35)

func _handle_interaction() -> void:
	if not chunk_manager or is_inventory_open:
		return

	var mouse_pos := get_global_mouse_position()
	var dist := global_position.distance_to(mouse_pos)
	if dist > reach_distance:
		return

	var target_block := pixel_to_block(mouse_pos)

	# Mine block (LMB)
	if Input.is_action_pressed("mine") and _mine_timer <= 0.0:
		var current_id: int = int(chunk_manager.get_block(target_block))
		if current_id != BlockManager.BlockID.AIR:
			chunk_manager.mine_block(target_block)
			_mine_timer = mine_cooldown

	# Place block (RMB) - Linked strictly to Inventory!
	elif Input.is_action_just_pressed("build"):
		var slot := inventory.get_slot(selected_hotbar_index)
		if not slot or slot.is_empty():
			return

		var item_data := ItemManager.get_item(slot.item_id)
		if not item_data or item_data.place_block_id <= 0:
			return

		var current_id: int = int(chunk_manager.get_block(target_block))
		if current_id == BlockManager.BlockID.AIR:
			# Check intersection with player body
			var player_rect := Rect2(global_position.x - 12, global_position.y - 42, 24, 86)
			var block_rect := Rect2(target_block.x * 16, target_block.y * 16, 16, 16)
			if not player_rect.intersects(block_rect):
				# Place block in world
				chunk_manager.set_block(target_block, item_data.place_block_id)
				# Consume 1 unit from inventory
				inventory.remove_from_slot(selected_hotbar_index, 1)

func _process_survival(delta: float) -> void:
	if global_position.y > 32.0:
		current_oxygen = max(0.0, current_oxygen - oxygen_depletion_rate * delta)
		if current_oxygen <= 0.0:
			current_health = max(0.0, current_health - 4.0 * delta)
	else:
		current_oxygen = min(max_oxygen, current_oxygen + 25.0 * delta)

func _emit_hud_stats() -> void:
	var current_depth: int = max(0, int(floor(global_position.y / 16.0) * meters_per_block))
	stats_changed.emit(current_health, max_health, current_oxygen, max_oxygen, current_depth, selected_hotbar_index)
