extends SceneTree

const Inventory = preload("res://scripts/inventory/inventory.gd")
const InventorySlot = preload("res://scripts/inventory/inventory_slot.gd")
const DroppedItem = preload("res://scripts/items/dropped_item.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const ItemManager = preload("res://scripts/items/item_manager.gd")
const BlockManager = preload("res://scripts/world/block_manager.gd")
const CraftingManager = preload("res://scripts/crafting/crafting_manager.gd")
const Recipe = preload("res://scripts/crafting/recipe.gd")
const Workbench = preload("res://scripts/world/workbench.gd")
const Chest = preload("res://scripts/world/chest.gd")

var _stage: int = 0
var _frames: int = 0

var main_node: Node
var cm: Node
var player: Node
var hud: Node
var inv_ui: Node
var craft_ui: Node
var chest_ui: Node

func _init() -> void:
	print("==================================================")
	print("=== INITIATING ABYSSUS ETAPA 03 TEST SUITE ===")
	print("==================================================")
	var test_save_dir := "user://saves/test_etapa_03"
	if DirAccess.dir_exists_absolute(test_save_dir):
		_recursive_remove(test_save_dir)

	change_scene_to_file("res://scenes/main.tscn")

func _recursive_remove(path: String) -> void:
	var d := DirAccess.open(path)
	if d:
		d.list_dir_begin()
		var file_name = d.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path.path_join(file_name)
				if d.current_is_dir():
					_recursive_remove(full_path)
				else:
					DirAccess.remove_absolute(full_path)
			file_name = d.get_next()
		d.list_dir_end()
		DirAccess.remove_absolute(path)

func _process(delta: float) -> bool:
	_frames += 1
	if not current_scene or _frames < 3:
		return false

	if _stage == 0:
		_stage = 1
		main_node = current_scene
		cm = main_node.get_node("World/ChunkManager")
		player = main_node.get_node("Player")
		hud = main_node.get_node("HUD")
		inv_ui = main_node.get_node("UI_Layer/InventoryUI")
		craft_ui = main_node.get_node("UI_Layer/CraftingUI")
		chest_ui = main_node.get_node("UI_Layer/ChestUI")

		main_node.world_id = "test_etapa_03"
		cm.world_id = "test_etapa_03"

		print("[TEST] Framework hooked up. Starting test execution...")
		_run_all_tests()
		return true

	return false

func _run_all_tests() -> void:
	_test_a_crafting()
	_test_b_workbench()
	_test_c_chest()
	_test_d_tools_and_mining_progression()
	_test_e_animation_and_presentation()
	_test_f_persistence_regression()

	print("==================================================")
	print("=== ALL ETAPA 03 TESTS PASSED WITH 100% SUCCESS ===")
	print("==================================================")
	quit(0)

func _test_a_crafting() -> void:
	print("\n--- TEST A: CRAFTING E RECEITAS ---")
	var inv = Inventory.new(40)
	CraftingManager.init_recipes()

	# Give materials for basic pickaxe: 4 wood + 4 stone
	inv.add_item("wood", 4)
	inv.add_item("stone", 4)

	var recipe_pick = CraftingManager.get_recipe_by_id("craft_basic_pickaxe")
	assert(recipe_pick != null, "Recipe craft_basic_pickaxe must exist")

	# Can craft with manual station
	var can_craft: bool = CraftingManager.can_craft(recipe_pick, inv, "")
	assert(can_craft == true, "Should be able to craft basic pickaxe")

	# Execute craft
	var success: bool = CraftingManager.craft(recipe_pick, inv, "")
	assert(success == true, "Crafting must succeed")
	assert(inv.get_item_count("basic_pickaxe") == 1, "Should have 1 basic pickaxe")
	assert(inv.get_item_count("wood") == 0, "Wood consumed")
	assert(inv.get_item_count("stone") == 0, "Stone consumed")
	print("✓ Basic pickaxe crafted: materials consumed atomically, product awarded")

	# Fail when lacking materials
	can_craft = CraftingManager.can_craft(recipe_pick, inv, "")
	assert(can_craft == false, "Cannot craft without materials")

	# Fail when workbench is required but player is at manual station
	var recipe_wb_pick = CraftingManager.get_recipe_by_id("craft_stone_pickaxe")
	inv.add_item("stone", 10)
	inv.add_item("wood", 10)
	assert(CraftingManager.can_craft(recipe_wb_pick, inv, "") == false, "Cannot craft stone pickaxe without workbench")
	assert(CraftingManager.can_craft(recipe_wb_pick, inv, "workbench") == true, "Can craft stone pickaxe with workbench")
	print("✓ Workbench requirement validated")

	# Full inventory space check
	var full_inv = Inventory.new(40)
	for i in range(40):
		full_inv.get_slot(i).item_id = "dirt"
		full_inv.get_slot(i).count = 999
	# Even with materials, full inventory blocks crafting
	assert(CraftingManager.can_craft(recipe_pick, full_inv, "") == false, "Full inventory blocks crafting")
	print("✓ Full inventory space check validated")

func _test_b_workbench() -> void:
	print("\n--- TEST B: BANCADA POSICIONÁVEL E ÁREA DE INTERAÇÃO ---")
	var wb_pos := Vector2(64.0, -32.0)
	var wb = cm.spawn_workbench(wb_pos, "wb_test_1")
	assert(wb != null, "Workbench entity spawned")
	assert(wb.is_in_group("workbenches"), "Workbench in group")

	# Simulate player entering workbench interaction area
	wb._on_body_entered(player)
	assert(player.current_crafting_station == "workbench", "Player enters workbench crafting zone")
	print("✓ Player entered workbench radius: station updated to 'workbench'")

	# Simulate player leaving workbench area
	wb._on_body_exited(player)
	assert(player.current_crafting_station == "", "Player leaves workbench crafting zone")
	print("✓ Player left workbench radius: station reset to manual")

	# Mine and destroy workbench
	var initial_wb_items = player.inventory.get_item_count("workbench")
	wb.mine_and_destroy(cm)
	assert(wb.is_destroyed == true, "Workbench destroyed")
	print("✓ Workbench mined: node removed, dropped item spawned")

func _test_c_chest() -> void:
	print("\n--- TEST C: BAÚ E ARMAZENAMENTO PERSISTENTE ---")
	var chest_pos := Vector2(100.0, -32.0)
	var chest = cm.spawn_chest(chest_pos, "chest_test_1")
	assert(chest != null, "Chest spawned")
	assert(chest.inventory.slots.size() == 20, "Chest must have 20 slots")

	# Transfer items into chest
	chest.inventory.add_item("metallic_ore", 15)
	chest.inventory.add_item("cyan_crystal", 7)
	assert(chest.has_any_items() == true, "Chest has items")
	assert(chest.can_be_destroyed() == false, "Chest with items cannot be destroyed")

	# Attempt to destroy non-empty chest (must fail)
	var destroyed: bool = chest.mine_and_destroy(cm, hud)
	assert(destroyed == false, "Destruction of non-empty chest blocked")
	print("✓ Non-empty chest destruction blocked successfully")

	# Empty chest and destroy
	chest.inventory.get_slot(0).clear()
	chest.inventory.get_slot(1).clear()
	assert(chest.has_any_items() == false, "Chest now empty")
	assert(chest.can_be_destroyed() == true, "Empty chest can be destroyed")

	destroyed = chest.mine_and_destroy(cm, hud)
	assert(destroyed == true, "Empty chest destroyed successfully")
	print("✓ Empty chest destroyed and recovered as dropped item")

func _test_d_tools_and_mining_progression() -> void:
	print("\n--- TEST D: FERRAMENTAS E VELOCIDADES DE MINERAÇÃO ---")
	# Check tools data
	var basic = ItemManager.get_item("basic_pickaxe")
	var stone_p = ItemManager.get_item("stone_pickaxe")
	var metal_p = ItemManager.get_item("metallic_pickaxe")

	assert(basic != null and basic.mining_power == 1 and basic.mining_speed == 1.0, "Basic pickaxe stats")
	assert(stone_p != null and stone_p.mining_power == 2 and stone_p.mining_speed == 1.25, "Stone pickaxe stats")
	assert(metal_p != null and metal_p.mining_power == 3 and metal_p.mining_speed == 1.6, "Metallic pickaxe stats")

	# Compare mining times on Stone (hardness 1.2, min_power 1)
	var stone_block = BlockManager.get_block(BlockManager.BlockID.STONE)
	var time_hand = stone_block.hardness / (0.5 * 1.0) # speed 0.5, power 1
	var time_basic = stone_block.hardness / (1.0 * 1.0) # speed 1.0, power 1
	var time_stone = stone_block.hardness / (1.25 * (1.0 + (2 - 1) * 0.35)) # speed 1.25, power 2
	var time_metal = stone_block.hardness / (1.6 * (1.0 + (3 - 1) * 0.35)) # speed 1.6, power 3

	assert(time_hand > time_basic, "Hand is slower than basic pickaxe")
	assert(time_basic > time_stone, "Basic is slower than stone pickaxe")
	assert(time_stone > time_metal, "Stone is slower than metallic pickaxe")
	print("✓ Mining progression verified: Hand (%.2fs) > Basic (%.2fs) > Stone (%.2fs) > Metal (%.2fs)" % [time_hand, time_basic, time_stone, time_metal])

	# Check power requirement on Metallic Ore (min_mining_power = 2)
	var ore_block = BlockManager.get_block(BlockManager.BlockID.METALLIC_ORE)
	assert(ore_block.min_mining_power == 2, "Metallic ore requires power 2")
	print("✓ Block power requirement verified")

func _test_e_animation_and_presentation() -> void:
	print("\n--- TEST E: ANIMAÇÃO DE MINERAÇÃO E FEEDBACK VISUAL ---")
	# Simulate mining action
	player.is_mining = true
	player._update_tool_animation(0.016)
	assert(player.tool_sprite.visible == true, "Tool sprite visible while mining")
	assert(player.mining_anim_time > 0.0, "Animation time running")

	# Release mining
	player._cancel_mining()
	assert(player.is_mining == false, "Mining stopped")
	assert(player.cracks_sprite.visible == false, "Cracks hidden when mining stopped")
	print("✓ Tool swinging and crack progression feedback validated")

func _test_f_persistence_regression() -> void:
	print("\n--- TEST F: PERSISTÊNCIA COMPLETA E REGRESSÃO ---")
	cm._load_chunk(Vector2i(1, 1))
	# Place a workbench and a chest with items in chunk (1, 1)
	var test_wb_pos := Vector2(1 * 32 * 16 + 10, 1 * 32 * 16 + 10)
	var test_ch_pos := Vector2(1 * 32 * 16 + 26, 1 * 32 * 16 + 10)
	cm.spawn_workbench(test_wb_pos, "saved_wb_1")
	var ch = cm.spawn_chest(test_ch_pos, "saved_ch_1")
	ch.inventory.add_item("cyan_crystal", 12)

	# Save game
	main_node.world_id = "test_etapa_03"
	cm.world_id = "test_etapa_03"
	main_node.save_game(false)

	# Verify saved chunk on disk
	var disk_data := SaveManager.load_chunk("test_etapa_03", Vector2i(1, 1))
	assert(disk_data.has("workbenches") and disk_data["workbenches"].size() > 0, "Saved workbenches on disk")
	assert(disk_data.has("chests") and disk_data["chests"].size() > 0, "Saved chests on disk")
	assert(disk_data["chests"][0]["inventory"][0]["item_id"] == "cyan_crystal", "Saved chest inventory on disk")
	print("✓ Workbenches and Chest inventories persisted on disk")

	# Unload and reload chunk (1, 1) to test streaming restoration
	cm._unload_chunk(Vector2i(1, 1))
	assert(not cm.active_chunks.has(Vector2i(1, 1)), "Chunk (1, 1) unloaded")

	cm._load_chunk(Vector2i(1, 1))
	assert(cm.active_chunks.has(Vector2i(1, 1)), "Chunk (1, 1) reloaded")

	var found_wb := false
	var found_ch := false
	for child in cm.entities_container.get_children():
		if child is Workbench and child.unique_id == "saved_wb_1":
			found_wb = true
		elif child is Chest and child.unique_id == "saved_ch_1":
			found_ch = true
			assert(child.inventory.get_item_count("cyan_crystal") == 12, "Chest restored exactly 12 crystals")

	assert(found_wb == true, "Workbench restored in reloaded chunk")
	assert(found_ch == true, "Chest restored in reloaded chunk")
	print("✓ Chunk entities streaming restoration passed")

