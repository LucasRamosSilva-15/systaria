class_name CraftingManager
extends RefCounted

const Recipe = preload("res://scripts/crafting/recipe.gd")
const Inventory = preload("res://scripts/inventory/inventory.gd")

static var _recipes: Array = []
static var _initialized: bool = false

static func init_recipes() -> void:
	if _initialized:
		return
	_initialized = true

	# 1. Processar Madeira Fóssil (Manual / à mão)
	_recipes.append(Recipe.new(
		"wood_process",
		"Processar Madeira Fóssil",
		{ "dirt": 2 },
		"wood",
		2,
		"",
		"Extrai fibras orgânicas e madeira compactada do solo subterrâneo."
	))

	# 2. Bancada de Trabalho (Manual / à mão)
	_recipes.append(Recipe.new(
		"craft_workbench",
		"Bancada de Trabalho",
		{ "wood": 10 },
		"workbench",
		1,
		"",
		"Mesa com ferramentas que desbloqueia receitas de fabricação avançadas."
	))

	# 3. Picareta Básica (Manual / à mão)
	_recipes.append(Recipe.new(
		"craft_basic_pickaxe",
		"Picareta Básica",
		{ "wood": 4, "stone": 4 },
		"basic_pickaxe",
		1,
		"",
		"Ferramenta de mineração inicial. Poder: 1, Velocidade: 1.0x."
	))

	# 4. Baú Reforçado (Exige Bancada)
	_recipes.append(Recipe.new(
		"craft_chest",
		"Baú Reforçado",
		{ "wood": 8, "metallic_ore": 2 },
		"chest",
		1,
		"workbench",
		"Contêiner seguro com 20 slots de armazenamento persistente."
	))

	# 5. Picareta de Pedra (Exige Bancada)
	_recipes.append(Recipe.new(
		"craft_stone_pickaxe",
		"Picareta de Pedra",
		{ "stone": 8, "wood": 4 },
		"stone_pickaxe",
		1,
		"workbench",
		"Ferramenta afiada de rocha densa. Poder: 2, Velocidade: 1.25x."
	))

	# 6. Picareta Metálica (Exige Bancada)
	_recipes.append(Recipe.new(
		"craft_metallic_pickaxe",
		"Picareta Metálica",
		{ "metallic_ore": 10, "wood": 4 },
		"metallic_pickaxe",
		1,
		"workbench",
		"Ferramenta reforçada com liga mineral. Poder: 3, Velocidade: 1.6x."
	))

static func get_all_recipes() -> Array:
	if not _initialized:
		init_recipes()
	return _recipes

static func get_recipe_by_id(recipe_id: String) -> Variant:
	if not _initialized:
		init_recipes()
	for r in _recipes:
		if r.id == recipe_id:
			return r
	return null

## Checks whether the player can craft this recipe given their inventory and station proximity
static func can_craft(recipe: Variant, inv: Variant, current_station: String = "") -> bool:
	if not recipe or not inv:
		return false

	# 1. Check crafting station requirement
	if recipe.required_station != "" and current_station != recipe.required_station:
		return false

	# 2. Check if player has required materials
	for mat_id in recipe.materials.keys():
		var required_qty: int = int(recipe.materials[mat_id])
		if inv.get_item_count(mat_id) < required_qty:
			return false

	# 3. Check if inventory has room for the result
	var max_stack: int = 999
	var item_data := ItemManager.get_item(recipe.result_item_id)
	if item_data:
		max_stack = item_data.max_stack

	var space_available: int = 0
	for slot in inv.slots:
		if slot.is_empty():
			space_available += max_stack
		elif slot.item_id == recipe.result_item_id and slot.count < max_stack:
			space_available += (max_stack - slot.count)

	if space_available < recipe.result_count:
		return false

	return true

## Atomically crafts an item: consumes ingredients and awards the product.
static func craft(recipe: Variant, inv: Variant, current_station: String = "") -> bool:
	if not can_craft(recipe, inv, current_station):
		return false

	# Consume materials
	for mat_id in recipe.materials.keys():
		var count_to_remove: int = int(recipe.materials[mat_id])
		inv.remove_item(mat_id, count_to_remove)

	# Award crafted item
	var remainder: int = inv.add_item(recipe.result_item_id, recipe.result_count)
	if remainder > 0:
		push_error("CraftingManager: Unexpected overflow when adding crafted item")
	return true
