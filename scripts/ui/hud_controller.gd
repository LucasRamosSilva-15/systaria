class_name HUDController
extends CanvasLayer

const Inventory = preload("res://scripts/inventory/inventory.gd")

@onready var health_bar: ProgressBar = $MarginContainer/TopBar/StatsVBox/HealthContainer/HealthBar
@onready var health_label: Label = $MarginContainer/TopBar/StatsVBox/HealthContainer/HealthLabel
@onready var oxygen_bar: ProgressBar = $MarginContainer/TopBar/StatsVBox/OxygenContainer/OxygenBar
@onready var oxygen_label: Label = $MarginContainer/TopBar/StatsVBox/OxygenContainer/OxygenLabel
@onready var depth_label: Label = $MarginContainer/TopBar/DepthContainer/DepthLabel
@onready var stratum_label: Label = $MarginContainer/TopBar/DepthContainer/StratumLabel
@onready var selected_block_label: Label = $BottomBar/HotbarContainer/SelectedBlockLabel
@onready var hotbar_slots: HBoxContainer = $BottomBar/HotbarContainer/SlotsHBox
@onready var notification_label: Label = $NotificationContainer/NotificationLabel
@onready var notification_anim: AnimationPlayer = $NotificationContainer/AnimationPlayer

var _slot_panels: Array[Panel] = []
var _current_inventory: Inventory = null
var _selected_slot_idx: int = 0

func _ready() -> void:
	if hotbar_slots:
		for child in hotbar_slots.get_children():
			if child is Panel:
				_slot_panels.append(child)

func connect_inventory(inv: Inventory) -> void:
	if _current_inventory:
		_current_inventory.inventory_changed.disconnect(_refresh_hotbar)
	_current_inventory = inv
	if _current_inventory:
		_current_inventory.inventory_changed.connect(_refresh_hotbar)
		_refresh_hotbar()

func update_stats(health: float, max_health: float, oxygen: float, max_oxygen: float, depth: int, selected_hotbar_idx: int) -> void:
	_selected_slot_idx = selected_hotbar_idx

	# Health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if health_label:
		health_label.text = "%d/%d" % [int(health), int(max_health)]

	# Oxygen
	if oxygen_bar:
		oxygen_bar.max_value = max_oxygen
		oxygen_bar.value = oxygen
	if oxygen_label:
		oxygen_label.text = "%d%%" % [int(oxygen)]

	# Depth & Stratum naming
	if depth_label:
		depth_label.text = "%d m" % depth

	if stratum_label:
		if depth <= 0:
			stratum_label.text = "SUPERFÍCIE"
		elif depth < 30:
			stratum_label.text = "ESTRATO 1: CAMADA ROCHOSA"
		elif depth < 100:
			stratum_label.text = "ESTRATO 2: ROCHA PROFUNDA"
		elif depth < 300:
			stratum_label.text = "ESTRATO 3: CAVERNAS CRISTALINAS"
		else:
			stratum_label.text = "ESTRATO 20: O ABISSO"

	_refresh_hotbar()

func _refresh_hotbar() -> void:
	if not _current_inventory:
		return

	# Update selected slot label
	var active_slot := _current_inventory.get_slot(_selected_slot_idx)
	if selected_block_label:
		if active_slot and not active_slot.is_empty():
			var item_data := ItemManager.get_item(active_slot.item_id)
			var item_name := item_data.name if item_data else active_slot.item_id
			selected_block_label.text = "[ %s  x%d ]" % [item_name, active_slot.count]
		else:
			selected_block_label.text = "[ Vazio ]"

	# Update each of the 10 slots
	for i in range(mini(10, _slot_panels.size())):
		var panel_node := _slot_panels[i]
		var icon: TextureRect = panel_node.get_node_or_null("Icon")
		var count_lbl: Label = panel_node.get_node_or_null("Count")
		var slot_data := _current_inventory.get_slot(i)

		if slot_data and not slot_data.is_empty():
			var data := ItemManager.get_item(slot_data.item_id)
			if icon:
				icon.texture = data.icon if data else null
			if count_lbl:
				count_lbl.text = str(slot_data.count) if slot_data.count > 1 else ""
		else:
			if icon:
				icon.texture = null
			if count_lbl:
				count_lbl.text = ""

		# Highlight active hotbar slot
		if i == _selected_slot_idx:
			panel_node.modulate = Color(1.4, 1.4, 1.1, 1.0)
		else:
			panel_node.modulate = Color(0.75, 0.75, 0.8, 0.85)

func show_notification(message: String) -> void:
	if not notification_label:
		return
	notification_label.text = message
	if notification_anim:
		notification_anim.stop()
		notification_anim.play("fade")
