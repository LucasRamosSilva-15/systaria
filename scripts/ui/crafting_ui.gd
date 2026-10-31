class_name CraftingUI
extends Control

signal visibility_changed_to(is_open: bool)

const CraftingManager = preload("res://scripts/crafting/crafting_manager.gd")
const Inventory = preload("res://scripts/inventory/inventory.gd")
const Recipe = preload("res://scripts/crafting/recipe.gd")

@onready var recipes_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/RecipesVBox
@onready var station_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StationLabel

var player_inventory: Inventory
var current_station: String = ""

func _ready() -> void:
	visible = false
	CraftingManager.init_recipes()

func set_inventory(inv: Inventory) -> void:
	if player_inventory:
		player_inventory.inventory_changed.disconnect(_on_inventory_changed)
	player_inventory = inv
	if player_inventory:
		player_inventory.inventory_changed.connect(_on_inventory_changed)
		_refresh_recipes()

func set_crafting_station(station: String) -> void:
	current_station = station
	if visible:
		_refresh_recipes()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_refresh_recipes()
	visibility_changed_to.emit(true)

func close() -> void:
	visible = false
	visibility_changed_to.emit(false)

func _on_inventory_changed() -> void:
	if visible:
		_refresh_recipes()

func _refresh_recipes() -> void:
	if not recipes_container:
		return

	# Update station indicator
	if station_label:
		if current_station == "workbench":
			station_label.text = "[ Estação: Bancada de Trabalho ]"
			station_label.modulate = Color(0.2, 0.95, 0.5)
		else:
			station_label.text = "[ Estação: Fabricação Manual ]"
			station_label.modulate = Color(0.6, 0.7, 0.8)

	for child in recipes_container.get_children():
		child.queue_free()

	var all_recipes := CraftingManager.get_all_recipes()
	for r in all_recipes:
		var can_make: bool = CraftingManager.can_craft(r, player_inventory, current_station)
		var card := _create_recipe_card(r, can_make)
		recipes_container.add_child(card)

func _create_recipe_card(recipe: Variant, can_make: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if can_make:
		style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
		style.border_color = Color(0.15, 0.85, 0.95, 0.8) # Glowing cyan border for craftable
	else:
		style.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		style.border_color = Color(0.2, 0.25, 0.32, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# 1. Product Icon & Count
	var result_data := ItemManager.get_item(recipe.result_item_id)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = result_data.icon if result_data else null
	hbox.add_child(icon)

	# 2. Recipe Info (Title & Materials list)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s (x%d)" % [recipe.name, recipe.result_count]
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.modulate = Color(0.95, 0.95, 1.0) if can_make else Color(0.6, 0.65, 0.7)
	info_vbox.add_child(title_lbl)

	# Materials list
	var mats_hbox := HBoxContainer.new()
	mats_hbox.add_theme_constant_override("separation", 6)
	info_vbox.add_child(mats_hbox)

	for mat_id in recipe.materials.keys():
		var req_count: int = int(recipe.materials[mat_id])
		var current_count: int = player_inventory.get_item_count(mat_id) if player_inventory else 0
		var mat_data := ItemManager.get_item(mat_id)
		var mat_name: String = mat_data.name if mat_data else str(mat_id)

		var mat_lbl := Label.new()
		mat_lbl.text = "%s: %d/%d" % [mat_name, current_count, req_count]
		mat_lbl.add_theme_font_size_override("font_size", 8)
		if current_count >= req_count:
			mat_lbl.modulate = Color(0.3, 0.9, 0.4) # Green if enough
		else:
			mat_lbl.modulate = Color(0.95, 0.35, 0.35) # Red if missing
		mats_hbox.add_child(mat_lbl)

	# Required station indicator if missing
	if recipe.required_station != "" and current_station != recipe.required_station:
		var req_station_lbl := Label.new()
		req_station_lbl.text = "[ Exige Bancada ]"
		req_station_lbl.add_theme_font_size_override("font_size", 7)
		req_station_lbl.modulate = Color(0.9, 0.6, 0.2)
		info_vbox.add_child(req_station_lbl)

	# 3. Craft Button
	var btn := Button.new()
	btn.text = "Fabricar"
	btn.add_theme_font_size_override("font_size", 8)
	btn.custom_minimum_size = Vector2(54, 20)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = not can_make
	btn.pressed.connect(func(): _on_craft_pressed(recipe))
	hbox.add_child(btn)

	return card

func _on_craft_pressed(recipe: Variant) -> void:
	if not player_inventory:
		return
	var success := CraftingManager.craft(recipe, player_inventory, current_station)
	if success:
		_refresh_recipes()
