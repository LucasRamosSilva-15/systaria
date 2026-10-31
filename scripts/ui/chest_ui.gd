class_name ChestUI
extends Control

signal visibility_changed_to(is_open: bool)

const Inventory = preload("res://scripts/inventory/inventory.gd")
const InventorySlot = preload("res://scripts/inventory/inventory_slot.gd")

@onready var chest_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChestSection/ChestGrid
@onready var player_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayerSection/PlayerGrid
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_title: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipTitle
@onready var tooltip_count: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipCount
@onready var tooltip_desc: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipDesc
@onready var held_cursor: Control = $HeldCursor
@onready var held_icon: TextureRect = $HeldCursor/HeldIcon
@onready var held_count_label: Label = $HeldCursor/HeldCount

var player_inventory: Inventory
var current_chest: StaticBody2D = null

var chest_slot_nodes: Array[Panel] = []
var player_slot_nodes: Array[Panel] = []
var held_slot: InventorySlot = InventorySlot.new()
var hovered_info: Dictionary = {} # { "is_chest": bool, "idx": int }

func _ready() -> void:
	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	if held_cursor:
		held_cursor.visible = false
	_build_ui_grids()

func open_chest(chest_node: StaticBody2D, player_inv: Inventory) -> void:
	current_chest = chest_node
	player_inventory = player_inv

	if current_chest and current_chest.inventory:
		current_chest.inventory.inventory_changed.connect(_on_inventories_changed)
	if player_inventory:
		player_inventory.inventory_changed.connect(_on_inventories_changed)

	visible = true
	_refresh_all()
	visibility_changed_to.emit(true)

func close() -> void:
	if not visible:
		return

	# Return held items to player inventory
	if not held_slot.is_empty() and player_inventory:
		var rem := player_inventory.add_item(held_slot.item_id, held_slot.count)
		if rem > 0 and current_chest:
			current_chest.inventory.add_item(held_slot.item_id, rem)
		held_slot.clear()
		_update_held_cursor()

	if current_chest and current_chest.inventory:
		current_chest.inventory.inventory_changed.disconnect(_on_inventories_changed)
	if player_inventory:
		player_inventory.inventory_changed.disconnect(_on_inventories_changed)

	current_chest = null
	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	visibility_changed_to.emit(false)

func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos := get_global_mouse_position()
	if held_cursor and held_cursor.visible:
		held_cursor.global_position = mouse_pos + Vector2(10, 10)
	if tooltip_panel and tooltip_panel.visible:
		tooltip_panel.global_position = mouse_pos + Vector2(16, 16)

func _build_ui_grids() -> void:
	# 1. Build Chest Grid (20 slots: 10x2)
	if chest_grid:
		for child in chest_grid.get_children():
			child.queue_free()
		chest_slot_nodes.clear()
		for i in range(20):
			var slot_panel := _create_slot_panel(i, true)
			chest_grid.add_child(slot_panel)
			chest_slot_nodes.append(slot_panel)

	# 2. Build Player Grid (40 slots: 10x4)
	if player_grid:
		for child in player_grid.get_children():
			child.queue_free()
		player_slot_nodes.clear()
		for i in range(40):
			var slot_panel := _create_slot_panel(i, false)
			player_grid.add_child(slot_panel)
			player_slot_nodes.append(slot_panel)

func _create_slot_panel(idx: int, is_chest: bool) -> Panel:
	var slot_panel := Panel.new()
	slot_panel.custom_minimum_size = Vector2(26, 26)

	var style := StyleBoxFlat.new()
	if is_chest:
		style.bg_color = Color(0.14, 0.11, 0.08, 0.95)
		style.border_color = Color(0.85, 0.65, 0.25, 0.75) # Warm brass for chest
	else:
		if idx < 10:
			style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
			style.border_color = Color(0.15, 0.75, 0.9, 0.8)
		else:
			style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
			style.border_color = Color(0.25, 0.32, 0.42, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	slot_panel.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(icon)

	var label := Label.new()
	label.name = "CountLabel"
	label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	label.offset_left = -24
	label.offset_top = -12
	label.offset_right = -2
	label.offset_bottom = -1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(label)

	slot_panel.gui_input.connect(func(event: InputEvent): _on_slot_gui_input(event, idx, is_chest))
	slot_panel.mouse_entered.connect(func(): _on_slot_mouse_entered(idx, is_chest))
	slot_panel.mouse_exited.connect(func(): _on_slot_mouse_exited(idx, is_chest))

	return slot_panel

func _on_slot_gui_input(event: InputEvent, idx: int, is_chest: bool) -> void:
	if not (event is InputEventMouseButton) or not event.is_pressed():
		return
	var mb: InputEventMouseButton = event
	var target_inv: Inventory = current_chest.inventory if is_chest else player_inventory
	if not target_inv:
		return

	var slot: InventorySlot = target_inv.get_slot(idx)
	if not slot:
		return

	# LEFT CLICK: Pick, Place, Swap, Merge
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if held_slot.is_empty():
			if not slot.is_empty():
				held_slot.item_id = slot.item_id
				held_slot.count = slot.count
				slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()
		else:
			if slot.is_empty():
				slot.item_id = held_slot.item_id
				slot.count = held_slot.count
				held_slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()
			elif slot.item_id == held_slot.item_id:
				var max_stk := slot.get_max_stack()
				var space: int = max_stk - slot.count
				var to_add: int = mini(held_slot.count, space)
				slot.count += to_add
				held_slot.count -= to_add
				if held_slot.count <= 0:
					held_slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()
			else:
				var temp_id := slot.item_id
				var temp_cnt := slot.count
				slot.item_id = held_slot.item_id
				slot.count = held_slot.count
				held_slot.item_id = temp_id
				held_slot.count = temp_cnt
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()

	# RIGHT CLICK: Split or Drop 1
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if held_slot.is_empty():
			if not slot.is_empty():
				var half := int(ceil(float(slot.count) / 2.0))
				held_slot.item_id = slot.item_id
				held_slot.count = half
				slot.count -= half
				if slot.count <= 0:
					slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()
		else:
			if slot.is_empty():
				slot.item_id = held_slot.item_id
				slot.count = 1
				held_slot.count -= 1
				if held_slot.count <= 0:
					held_slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()
			elif slot.item_id == held_slot.item_id and slot.count < slot.get_max_stack():
				slot.count += 1
				held_slot.count -= 1
				if held_slot.count <= 0:
					held_slot.clear()
				target_inv.slot_changed.emit(idx)
				target_inv.inventory_changed.emit()

	_update_held_cursor()
	if hovered_info.get("idx", -1) == idx and hovered_info.get("is_chest", false) == is_chest:
		_show_tooltip(idx, is_chest)

func _on_inventories_changed() -> void:
	_refresh_all()

func _refresh_all() -> void:
	# Refresh chest slots
	if current_chest and current_chest.inventory:
		for i in range(mini(20, chest_slot_nodes.size())):
			_refresh_single_slot(chest_slot_nodes[i], current_chest.inventory.get_slot(i))
	# Refresh player slots
	if player_inventory:
		for i in range(mini(40, player_slot_nodes.size())):
			_refresh_single_slot(player_slot_nodes[i], player_inventory.get_slot(i))

func _refresh_single_slot(panel_node: Panel, slot: InventorySlot) -> void:
	var icon: TextureRect = panel_node.get_node("Icon")
	var label: Label = panel_node.get_node("CountLabel")
	if not slot or slot.is_empty():
		icon.texture = null
		label.text = ""
	else:
		var item_data := ItemManager.get_item(slot.item_id)
		icon.texture = item_data.icon if item_data else null
		label.text = str(slot.count) if slot.count > 1 else ""

func _update_held_cursor() -> void:
	if not held_cursor:
		return
	if held_slot.is_empty():
		held_cursor.visible = false
	else:
		held_cursor.visible = true
		var item_data := ItemManager.get_item(held_slot.item_id)
		held_icon.texture = item_data.icon if item_data else null
		held_count_label.text = str(held_slot.count) if held_slot.count > 1 else ""

func _on_slot_mouse_entered(idx: int, is_chest: bool) -> void:
	hovered_info = { "idx": idx, "is_chest": is_chest }
	_show_tooltip(idx, is_chest)

func _on_slot_mouse_exited(idx: int, is_chest: bool) -> void:
	if hovered_info.get("idx", -1) == idx and hovered_info.get("is_chest", false) == is_chest:
		hovered_info.clear()
		if tooltip_panel:
			tooltip_panel.visible = false

func _show_tooltip(idx: int, is_chest: bool) -> void:
	var target_inv: Inventory = current_chest.inventory if is_chest else player_inventory
	if not target_inv or not tooltip_panel:
		return
	var slot: InventorySlot = target_inv.get_slot(idx)
	if not slot or slot.is_empty():
		tooltip_panel.visible = false
		return

	var item_data := ItemManager.get_item(slot.item_id)
	if not item_data:
		tooltip_panel.visible = false
		return

	tooltip_title.text = item_data.name
	tooltip_count.text = "Qtd: %d" % slot.count
	tooltip_desc.text = item_data.description
	tooltip_panel.visible = true
