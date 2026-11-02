class_name PlayerController
extends CharacterBody2D

const Inventory = preload("res://scripts/inventory/inventory.gd")

signal stats_changed(health: float, max_health: float, oxygen: float, max_oxygen: float, depth: int, selected_hotbar_idx: int)
signal inventory_toggle_requested
signal crafting_toggle_requested
signal chest_interact_requested(chest_node)
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

@export_group("Stats")
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var health_recovery_rate: float = 2.0
@export var max_oxygen: float = 100.0
@export var current_oxygen: float = 100.0
@export var oxygen_depletion_rate: float = 1.5
@export var meters_per_block: float = 1.0

@export_group("Lighting & Vision")
@export var lantern_energy: float = 1.15
@export var lantern_scale: float = 1.35
@export var lantern_color: Color = Color(0.92, 0.96, 1.0, 1.0)
@export var camera_zoom: Vector2 = Vector2(1.5, 1.5)

var inventory: Inventory
var selected_hotbar_index: int = 0
var chunk_manager: Node2D
var is_inventory_open: bool = false
var is_crafting_open: bool = false
var is_chest_open: bool = false

var current_crafting_station: String = ""
var current_mining_target: Vector2i = Vector2i(-999999, -999999)
var current_mining_damage: float = 0.0
var is_mining: bool = false
var mining_anim_time: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selector: Sprite2D = $SelectorReticle
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tool_pivot: Node2D = $ToolPivot
@onready var tool_sprite: Sprite2D = $ToolPivot/ToolSprite
@onready var cracks_sprite: Sprite2D = $CracksSprite

var sprite: CanvasItem:
	get:
		return anim_sprite

static func pixel_to_block(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pixel_pos.x / 16.0)),
		int(floor(pixel_pos.y / 16.0))
	)

func _init() -> void:
	inventory = Inventory.new(40)

func _ready() -> void:
	add_to_group("player")
	if selector:
		selector.top_level = true
	if cracks_sprite:
		cracks_sprite.top_level = true
	if anim_sprite:
		anim_sprite.play("idle")
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = camera_zoom
	var lamp: PointLight2D = get_node_or_null("Headlamp") as PointLight2D
	if lamp:
		lamp.energy = lantern_energy
		lamp.texture_scale = lantern_scale
		lamp.color = lantern_color
		lamp.shadow_enabled = true
		lamp.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
		lamp.shadow_filter_smooth = 3.0
		lamp.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		lamp.range_layer_min = -10
		lamp.range_layer_max = 0
		lamp.position = Vector2(3.0, -4.0)
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
		"toggle_crafting": [KEY_C],
		"interact": [KEY_F],
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

func has_ui_open() -> bool:
	return is_inventory_open or is_crafting_open or is_chest_open

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	if not has_ui_open() and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction := 0.0
	if not has_ui_open():
		direction = Input.get_axis("move_left", "move_right")

	var accel := acceleration if is_on_floor() else air_acceleration
	var frict := friction if is_on_floor() else air_friction

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, accel * delta)
		if not is_mining and anim_sprite:
			anim_sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, frict * delta)

	move_and_slide()
	_update_animation()

	_process_survival(delta)

	if chunk_manager and chunk_manager.has_method("update_chunks_around"):
		chunk_manager.update_chunks_around(global_position)

	_emit_hud_stats()

func _process(delta: float) -> void:
	if not has_ui_open():
		_update_selector()
		_handle_interaction(delta)
	else:
		if selector:
			selector.visible = false
		if cracks_sprite:
			cracks_sprite.visible = false
		if tool_sprite:
			tool_sprite.visible = false
		is_mining = false
		current_mining_damage = 0.0

	_update_tool_animation(delta)

func _input(event: InputEvent) -> void:
	# Toggle Inventory
	if event.is_action_pressed("toggle_inventory"):
		inventory_toggle_requested.emit()
	# Toggle Crafting
	elif event.is_action_pressed("toggle_crafting"):
		crafting_toggle_requested.emit()
	# Interact (Chest open)
	elif event.is_action_pressed("interact"):
		var nearest = _get_nearest_chest()
		if nearest:
			chest_interact_requested.emit(nearest)
	# Menu / ESC
	elif event.is_action_pressed("menu"):
		if has_ui_open():
			if is_chest_open:
				chest_interact_requested.emit(null) # close chest
			elif is_crafting_open:
				crafting_toggle_requested.emit()
			elif is_inventory_open:
				inventory_toggle_requested.emit()

	# Quick Save
	if event.is_action_pressed("quick_save"):
		quick_save_requested.emit()

	# Hotbar selection via keys
	if not has_ui_open():
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

func _handle_interaction(delta: float) -> void:
	if not chunk_manager or has_ui_open():
		return

	var mouse_pos := get_global_mouse_position()
	var dist := global_position.distance_to(mouse_pos)
	if dist > reach_distance:
		if is_mining:
			_cancel_mining()
		return

	var target_block := pixel_to_block(mouse_pos)

	# 1. MINING (Hold LMB)
	if Input.is_action_pressed("mine"):
		_process_mining_block(target_block, mouse_pos, delta)
	else:
		if is_mining:
			_cancel_mining()

	# 2. BUILDING & PLACING (RMB Click)
	if Input.is_action_just_pressed("build"):
		_process_building(target_block)

func _process_mining_block(target_block: Vector2i, mouse_pos: Vector2, delta: float) -> void:
	# Check if clicking on in-world entity first (Workbench or Chest)
	var clicked_wb = _get_entity_at_position("workbenches", mouse_pos)
	if clicked_wb:
		clicked_wb.mine_and_destroy(chunk_manager)
		_cancel_mining()
		return

	var clicked_chest = _get_entity_at_position("chests", mouse_pos)
	if clicked_chest:
		var hud_node = get_parent().get_node_or_null("HUD") if get_parent() else null
		clicked_chest.mine_and_destroy(chunk_manager, hud_node)
		_cancel_mining()
		return

	# Mine terrain block
	var current_id: int = int(chunk_manager.get_block(target_block))
	if current_id == BlockManager.BlockID.AIR:
		_cancel_mining()
		return

	if target_block != current_mining_target:
		current_mining_target = target_block
		current_mining_damage = 0.0

	var block_data := BlockManager.get_block(current_id)

	# Calculate mining speed and power from equipped hotbar tool
	var tool_power: int = 1
	var tool_speed: float = 0.5 # Hand digging speed
	var slot := inventory.get_slot(selected_hotbar_index)
	if slot and not slot.is_empty():
		var it_data := ItemManager.get_item(slot.item_id)
		if it_data and it_data.tool_type == "pickaxe":
			tool_power = it_data.mining_power
			tool_speed = it_data.mining_speed

	# Tool power restriction / penalty
	if tool_power < block_data.min_mining_power:
		tool_speed *= 0.15

	var effective_time: float = max(0.08, block_data.hardness / (tool_speed * (1.0 + (tool_power - 1) * 0.35)))
	current_mining_damage += (1.0 / effective_time) * delta
	is_mining = true

	# Cracks visual progress
	if cracks_sprite:
		cracks_sprite.visible = true
		cracks_sprite.global_position = Vector2(target_block.x * 16 + 8, target_block.y * 16 + 8)
		var stage: int = clamp(int(current_mining_damage * 4.0), 0, 3)
		cracks_sprite.region_rect = Rect2(stage * 16, 0, 16, 16)

	if current_mining_damage >= 1.0:
		chunk_manager.mine_block(target_block)
		_cancel_mining()

func _cancel_mining() -> void:
	is_mining = false
	current_mining_damage = 0.0
	current_mining_target = Vector2i(-999999, -999999)
	if cracks_sprite:
		cracks_sprite.visible = false

func _process_building(target_block: Vector2i) -> void:
	var slot := inventory.get_slot(selected_hotbar_index)
	if not slot or slot.is_empty():
		return

	var item_data := ItemManager.get_item(slot.item_id)
	if not item_data:
		return

	var place_pixel_pos := Vector2(target_block.x * 16 + 8, target_block.y * 16 + 8)

	# Place Workbench
	if item_data.place_entity_type == "workbench":
		if chunk_manager and chunk_manager.has_method("spawn_workbench"):
			chunk_manager.spawn_workbench(place_pixel_pos)
			inventory.remove_from_slot(selected_hotbar_index, 1)
		return

	# Place Chest
	if item_data.place_entity_type == "chest":
		if chunk_manager and chunk_manager.has_method("spawn_chest"):
			chunk_manager.spawn_chest(place_pixel_pos)
			inventory.remove_from_slot(selected_hotbar_index, 1)
		return

	# Place Solid Block
	if item_data.place_block_id > 0:
		var current_id: int = int(chunk_manager.get_block(target_block))
		if current_id == BlockManager.BlockID.AIR:
			var player_rect := Rect2(global_position.x - 12, global_position.y - 42, 24, 86)
			var block_rect := Rect2(target_block.x * 16, target_block.y * 16, 16, 16)
			if not player_rect.intersects(block_rect):
				chunk_manager.set_block(target_block, item_data.place_block_id)
				inventory.remove_from_slot(selected_hotbar_index, 1)

func _update_tool_animation(delta: float) -> void:
	if not tool_pivot or not tool_sprite:
		return

	if is_mining:
		tool_sprite.visible = true
		mining_anim_time += delta
		var mouse_pos := get_global_mouse_position()
		var base_angle := (mouse_pos - tool_pivot.global_position).angle()
		var swing := sin(mining_anim_time * 16.0) * 0.75
		tool_pivot.rotation = base_angle + swing

		# Flip tool head based on mouse direction
		var facing_left: bool = mouse_pos.x < global_position.x
		tool_pivot.scale.y = -1.0 if facing_left else 1.0
		if anim_sprite:
			anim_sprite.flip_h = facing_left
	else:
		tool_sprite.visible = false
		mining_anim_time = 0.0

func _update_animation() -> void:
	if not anim_sprite:
		return

	var target_anim: String = "idle"
	if is_mining:
		target_anim = "mine"
	elif not is_on_floor():
		if velocity.y < -10.0:
			target_anim = "jump"
		else:
			target_anim = "fall"
	elif abs(velocity.x) > 5.0:
		target_anim = "walk"
	else:
		target_anim = "idle"

	if anim_sprite.animation != target_anim:
		anim_sprite.play(target_anim)

	_update_lamp_position()

func _update_lamp_position() -> void:
	var lamp: PointLight2D = get_node_or_null("Headlamp") as PointLight2D
	if lamp and anim_sprite:
		var bias_x: float = -3.0 if anim_sprite.flip_h else 3.0
		lamp.position = Vector2(bias_x, -4.0)

func update_lantern_depth(depth_factor: float) -> void:
	var lamp: PointLight2D = get_node_or_null("Headlamp") as PointLight2D
	if lamp:
		# Smoothly scale from 0.85 on surface to lantern_energy (1.15) in cave
		lamp.energy = lerpf(0.85, lantern_energy, depth_factor)

func _get_nearest_chest() -> Variant:
	var chests = get_tree().get_nodes_in_group("chests")
	var nearest = null
	var min_dist := 54.0 # Reach limit
	for ch in chests:
		var d: float = global_position.distance_to(ch.global_position)
		if d < min_dist:
			min_dist = d
			nearest = ch
	return nearest

func _get_entity_at_position(group_name: String, click_pos: Vector2) -> Variant:
	var entities = get_tree().get_nodes_in_group(group_name)
	for ent in entities:
		if ent.global_position.distance_to(click_pos) <= 16.0:
			return ent
	return null

func _process_survival(delta: float) -> void:
	if global_position.y > 32.0:
		current_oxygen = max(0.0, current_oxygen - oxygen_depletion_rate * delta)
		if current_oxygen <= 0.0:
			current_health = max(0.0, current_health - 4.0 * delta)
	else:
		current_oxygen = min(max_oxygen, current_oxygen + 25.0 * delta)
		# Natural health recovery when safe on the surface with full oxygen
		if current_oxygen >= max_oxygen and current_health < max_health:
			current_health = min(max_health, current_health + health_recovery_rate * delta)

	# Handle death and respawn if health is completely depleted
	if current_health <= 0.0:
		_respawn_player()

func _respawn_player() -> void:
	current_health = max_health
	current_oxygen = max_oxygen
	global_position.y = -10.0
	velocity = Vector2.ZERO

func _emit_hud_stats() -> void:
	var current_depth: int = max(0, int(floor(global_position.y / 16.0) * meters_per_block))
	stats_changed.emit(current_health, max_health, current_oxygen, max_oxygen, current_depth, selected_hotbar_index)
