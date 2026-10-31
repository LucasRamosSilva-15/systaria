class_name HUDController
extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/TopBar/StatsVBox/HealthContainer/HealthBar
@onready var health_label: Label = $MarginContainer/TopBar/StatsVBox/HealthContainer/HealthLabel
@onready var oxygen_bar: ProgressBar = $MarginContainer/TopBar/StatsVBox/OxygenContainer/OxygenBar
@onready var oxygen_label: Label = $MarginContainer/TopBar/StatsVBox/OxygenContainer/OxygenLabel
@onready var depth_label: Label = $MarginContainer/TopBar/DepthContainer/DepthLabel
@onready var stratum_label: Label = $MarginContainer/TopBar/DepthContainer/StratumLabel
@onready var selected_block_label: Label = $BottomBar/HotbarContainer/SelectedBlockLabel
@onready var hotbar_slots: HBoxContainer = $BottomBar/HotbarContainer/SlotsHBox

var _slot_panels: Array[Panel] = []

func _ready() -> void:
	# Cache hotbar slot panels
	if hotbar_slots:
		for child in hotbar_slots.get_children():
			if child is Panel:
				_slot_panels.append(child)

func update_stats(health: float, max_health: float, oxygen: float, max_oxygen: float, depth: int, selected_block_id: int) -> void:
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

	# Selected block info
	var block_data := BlockManager.get_block(selected_block_id)
	if selected_block_label:
		selected_block_label.text = "[ %s ]" % block_data.name

	# Update quickbar highlights
	var block_ids = [
		BlockManager.BlockID.DIRT,
		BlockManager.BlockID.STONE,
		BlockManager.BlockID.DEEP_STONE,
		BlockManager.BlockID.METALLIC_ORE,
		BlockManager.BlockID.CYAN_CRYSTAL,
		BlockManager.BlockID.GRASS
	]

	for i in range(_slot_panels.size()):
		var slot := _slot_panels[i]
		if i < block_ids.size() and block_ids[i] == selected_block_id:
			slot.modulate = Color(1.4, 1.4, 1.0, 1.0) # Highlight active slot
		else:
			slot.modulate = Color(0.7, 0.7, 0.7, 0.85)

