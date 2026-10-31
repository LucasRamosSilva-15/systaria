class_name InventoryUI
extends Control

const Inventory = preload("res://scripts/inventory/inventory.gd")
const InventorySlot = preload("res://scripts/inventory/inventory_slot.gd")

signal visibility_changed_to(is_open: bool)

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var slots_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SlotsGrid
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_title: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipTitle
@onready var tooltip_count: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipCount
@onready var tooltip_desc: Label = $TooltipPanel/MarginContainer/VBoxContainer/TooltipDesc
@onready var held_cursor: Control = $HeldCursor
@onready var held_icon: TextureRect = $HeldCursor/HeldIcon
@onready var held_count_label: Label = $HeldCursor/HeldCount

var inventory: Inventory
var slot_ui_nodes: Array[Panel] = []
var held_slot: InventorySlot = InventorySlot.new()
var hovered_slot_idx: int = -1

func _ready() -> void:
	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	if held_cursor:
		held_cursor.visible = false
	_build_slot_grid()

func set_inventory(inv: Inventory) -> void:
	if inventory:
		inventory.inventory_changed.disconnect(_on_inventory_changed)
	inventory = inv
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)
		_refresh_all_slots()

func _build_slot_grid() -> void:
	if not slots_grid:
		return

	# Clear existing children if any
	for child in slots_grid.get_children():
		child.queue_free()
	slot_ui_nodes.clear()

	# Create 40 slot panels (10 columns x 4 rows)
	for i in range(Inventory.TOTAL_SLOTS):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(28, 28)
		slot_panel.name = "Slot_%d" % i

		# Custom style
		var style := StyleBoxFlat.new()
		if i < Inventory.HOTBAR_SLOTS:
			style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
			style.border_color = Color(0.15, 0.65, 0.85, 0.8) # Cyan highlight for hotbar
		else:
			style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
			style.border_color = Color(0.25, 0.32, 0.42, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		slot_panel.add_theme_stylebox_override("panel", style)

		# Icon
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

		# Count Label
		var label := Label.new()
		label.name = "CountLabel"
		label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		label.offset_left = -26
		label.offset_top = -12
		label.offset_right = -2
		label.offset_bottom = -1
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(label)

		# Connect slot mouse events
		var idx := i
		slot_panel.gui_input.connect(func(event: InputEvent): _on_slot_gui_input(event, idx))
		slot_panel.mouse_entered.connect(func(): _on_slot_mouse_entered(idx))
		slot_panel.mouse_exited.connect(func(): _on_slot_mouse_exited(idx))

		slots_grid.add_child(slot_panel)
		slot_ui_nodes.append(slot_panel)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_refresh_all_slots()
	visibility_changed_to.emit(true)

func close() -> void:
	# If holding items when closing, return them to inventory
	if not held_slot.is_empty() and inventory:
		var remainder := inventory.add_item(held_slot.item_id, held_slot.count)
		if remainder > 0:
			# If full, spawn dropped item near player
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0 and players[0].chunk_manager:
				players[0].chunk_manager.spawn_dropped_item(held_slot.item_id, remainder, players[0].global_position)
		held_slot.clear()
		_update_held_cursor()

	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	visibility_changed_to.emit(false)

func _process(_delta: float) -> void:
	if not visible:
		return

	var mouse_pos := get_global_mouse_position()

	# Move held stack cursor
	if held_cursor and held_cursor.visible:
		held_cursor.global_position = mouse_pos + Vector2(10, 10)

	# Position tooltip
	if tooltip_panel and tooltip_panel.visible:
		tooltip_panel.global_position = mouse_pos + Vector2(16, 16)

func _refresh_all_slots() -> void:
	if not inventory:
		return
	for i in range(mini(Inventory.TOTAL_SLOTS, slot_ui_nodes.size())):
		_refresh_slot(i)

func _refresh_slot(idx: int) -> void:
	if not inventory or idx >= slot_ui_nodes.size():
		return
	var slot_panel := slot_ui_nodes[idx]
	var icon: TextureRect = slot_panel.get_node("Icon")
	var label: Label = slot_panel.get_node("CountLabel")
	var slot_data := inventory.get_slot(idx)

	if not slot_data or slot_data.is_empty():
		icon.texture = null
		label.text = ""
	else:
		var item_data := ItemManager.get_item(slot_data.item_id)
		icon.texture = item_data.icon if item_data else null
		label.text = str(slot_data.count) if slot_data.count > 1 else ""

func _on_inventory_changed() -> void:
	_refresh_all_slots()
	if hovered_slot_idx >= 0:
		_show_tooltip(hovered_slot_idx)

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not inventory or not (event is InputEventMouseButton) or not event.is_pressed():
		return

	var mb: InputEventMouseButton = event
	var slot := inventory.get_slot(idx)

	# LEFT CLICK: Pick up, place, or swap
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if held_slot.is_empty():
			if not slot.is_empty():
				# Pick up whole slot
				held_slot.item_id = slot.item_id
				held_slot.count = slot.count
				slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()
		else:
			if slot.is_empty():
				# Place whole held item into empty slot
				slot.item_id = held_slot.item_id
				slot.count = held_slot.count
				held_slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()
			elif slot.item_id == held_slot.item_id:
				# Merge stacks up to max
				var max_stack := slot.get_max_stack()
				var space: int = max_stack - slot.count
				var to_add: int = mini(held_slot.count, space)
				slot.count += to_add
				held_slot.count -= to_add
				if held_slot.count <= 0:
					held_slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()
			else:
				# Swap held item and slot
				var temp_id := slot.item_id
				var temp_count := slot.count
				slot.item_id = held_slot.item_id
				slot.count = held_slot.count
				held_slot.item_id = temp_id
				held_slot.count = temp_count
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()

	# RIGHT CLICK: Split or drop 1 item
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if held_slot.is_empty():
			if not slot.is_empty():
				# Pick up half of slot
				var half := int(ceil(float(slot.count) / 2.0))
				held_slot.item_id = slot.item_id
				held_slot.count = half
				slot.count -= half
				if slot.count <= 0:
					slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()
		else:
			# Drop 1 item into slot
			if slot.is_empty():
				slot.item_id = held_slot.item_id
				slot.count = 1
				held_slot.count -= 1
				if held_slot.count <= 0:
					held_slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()
			elif slot.item_id == held_slot.item_id and slot.count < slot.get_max_stack():
				slot.count += 1
				held_slot.count -= 1
				if held_slot.count <= 0:
					held_slot.clear()
				inventory.slot_changed.emit(idx)
				inventory.inventory_changed.emit()

	_update_held_cursor()
	if hovered_slot_idx == idx:
		_show_tooltip(idx)

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

func _on_slot_mouse_entered(idx: int) -> void:
	hovered_slot_idx = idx
	_show_tooltip(idx)

func _on_slot_mouse_exited(idx: int) -> void:
	if hovered_slot_idx == idx:
		hovered_slot_idx = -1
		if tooltip_panel:
			tooltip_panel.visible = false

func _show_tooltip(idx: int) -> void:
	if not inventory or not tooltip_panel:
		return
	var slot := inventory.get_slot(idx)
	if not slot or slot.is_empty():
		tooltip_panel.visible = false
		return

	var item_data := ItemManager.get_item(slot.item_id)
	if not item_data:
		tooltip_panel.visible = false
		return

	tooltip_title.text = item_data.name
	tooltip_count.text = "Qtd: %d (Máx: %d)" % [slot.count, item_data.max_stack]
	tooltip_desc.text = item_data.description
	tooltip_panel.visible = true
