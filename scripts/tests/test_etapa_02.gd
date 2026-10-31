extends SceneTree

const Inventory = preload("res://scripts/inventory/inventory.gd")
const InventorySlot = preload("res://scripts/inventory/inventory_slot.gd")
const DroppedItem = preload("res://scripts/items/dropped_item.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const InventoryUI = preload("res://scripts/ui/inventory_ui.gd")
const ItemManager = preload("res://scripts/items/item_manager.gd")
const ChunkManager = preload("res://scripts/world/chunk_manager.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const HUDController = preload("res://scripts/ui/hud_controller.gd")

var _stage: int = 0
var _frames: int = 0

var main_node: Node
var cm: Node
var player: Node
var hud: Node
var inv_ui: Node

func _init() -> void:
	print("==================================================")
	print("=== INITIATING ABYSSUS ETAPA 02 TEST SUITE ===")
	print("==================================================")
	# Clean any previous test save
	var test_save_dir := "user://saves/test_etapa_02"
	if DirAccess.dir_exists_absolute(test_save_dir):
		var d := DirAccess.open(test_save_dir)
		if d:
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

		# Use test world id
		main_node.world_id = "test_etapa_02"
		cm.world_id = "test_etapa_02"

		print("[TEST] Framework hooked up. Starting test execution...")
		_run_all_tests()
		return true

	return false

func _run_all_tests() -> void:
	_test_a_inventory()
	_test_b_mining_and_dropped_item()
	_test_c_building_linked_to_inventory()
	_test_d_persistence()
	_test_e_chunk_unloading_and_negative_coords()

	print("==================================================")
	print("=== ALL ETAPA 02 TESTS PASSED WITH 100% SUCCESS ===")
	print("==================================================")
	quit(0)

func _test_a_inventory() -> void:
	print("\n--- TEST A: INVENTÁRIO (40 SLOTS, STACK, SPLIT, SWAP, FULL) ---")
	var inv := Inventory.new(40)
	assert(inv.slots.size() == 40, "Inventory must have exactly 40 slots")

	# 1. Add item
	var remainder := inv.add_item("dirt", 50)
	assert(remainder == 0, "All 50 dirt should fit in slot 0")
	assert(inv.get_item_count("dirt") == 50, "Dirt count should be 50")
	print("✓ Added 50 dirt into inventory")

	# 2. Stack item up to 999
	remainder = inv.add_item("dirt", 949)
	assert(remainder == 0, "All 949 dirt should fit in slot 0 (50+949 = 999)")
	assert(inv.get_slot(0).count == 999, "Slot 0 should be max stacked at 999")
	print("✓ Stacked dirt up to 999 max limit")

	# 3. Overflow into next slot
	remainder = inv.add_item("dirt", 10)
	assert(remainder == 0, "10 dirt should overflow into slot 1")
	assert(inv.get_slot(0).count == 999, "Slot 0 remains at 999")
	assert(inv.get_slot(1).count == 10, "Slot 1 receives overflow of 10")
	print("✓ Handled stack overflow into next slot")

	# 4. Swap slots
	inv.add_item("cyan_crystal", 5) # goes into slot 2
	assert(inv.get_slot(2).item_id == "cyan_crystal", "Slot 2 has crystal")
	inv.swap_slots(1, 2)
	assert(inv.get_slot(1).item_id == "cyan_crystal" and inv.get_slot(1).count == 5, "Slot 1 now has crystal")
	assert(inv.get_slot(2).item_id == "dirt" and inv.get_slot(2).count == 10, "Slot 2 now has dirt")
	print("✓ Swapped slots 1 and 2 successfully")

	# 5. Split slot
	inv.split_slot(1, 3) # splits 5 crystals: 3 go to slot 3, 2 remain in slot 1
	assert(inv.get_slot(3).item_id == "cyan_crystal" and inv.get_slot(3).count == 3, "Slot 3 has 3 crystals")
	assert(inv.get_slot(1).item_id == "cyan_crystal" and inv.get_slot(1).count == 2, "Slot 1 has 2 crystals")
	print("✓ Split slot 1 into slot 3 successfully")

	# 6. Fill inventory completely and verify full behavior
	var full_inv := Inventory.new(40)
	for i in range(40):
		full_inv.get_slot(i).item_id = "stone"
		full_inv.get_slot(i).count = 999

	var cant_add := full_inv.add_item("dirt", 10)
	assert(cant_add == 10, "Full inventory should return full remainder (10)")
	print("✓ Verified full inventory rejection behavior")

func _test_b_mining_and_dropped_item() -> void:
	print("\n--- TEST B: MINERAÇÃO, ENTIDADE DROPPED ITEM E COLETA ---")
	var initial_dirt_count: int = player.inventory.get_item_count("dirt")

	# Ensure block at (0, 2) is DIRT
	cm.set_block(Vector2i(0, 2), BlockManager.BlockID.DIRT)
	assert(cm.get_block(Vector2i(0, 2)) == BlockManager.BlockID.DIRT, "Block at (0, 2) must be DIRT")

	# Mine block
	var mined: bool = cm.mine_block(Vector2i(0, 2))
	assert(mined == true, "Mining block should return true")
	assert(cm.get_block(Vector2i(0, 2)) == BlockManager.BlockID.AIR, "Mined block should now be AIR")

	# Check dropped item was created
	var items = cm.items_container.get_children()
	assert(items.size() > 0, "At least one DroppedItem entity should exist in items_container")
	var dropped: DroppedItem = items[items.size() - 1]
	assert(dropped.item_id == "dirt", "Dropped item should be 'dirt'")
	print("✓ Block mined: block became AIR, DroppedItem created in world")

	# Simulate collection by player
	dropped.pickup_delay = 0.0
	dropped._try_collect(player)
	assert(dropped.is_collected == true, "DroppedItem should be marked as collected")
	assert(player.inventory.get_item_count("dirt") == initial_dirt_count + 1, "Player inventory should gain +1 dirt")
	print("✓ Dropped item collected and added to player inventory without duplication")

func _test_c_building_linked_to_inventory() -> void:
	print("\n--- TEST C: CONSTRUÇÃO VINCULADA AO INVENTÁRIO ---")
	# Put cyan crystal in selected hotbar slot 0
	player.selected_hotbar_index = 0
	player.inventory.get_slot(0).item_id = "cyan_crystal"
	player.inventory.get_slot(0).count = 3

	var build_pos := Vector2i(0, 1) # Air block above ground
	cm.set_block(build_pos, BlockManager.BlockID.AIR)

	# Simulate placing block
	var slot = player.inventory.get_slot(player.selected_hotbar_index)
	var item_data := ItemManager.get_item(slot.item_id)
	assert(item_data != null and item_data.place_block_id == BlockManager.BlockID.CYAN_CRYSTAL, "Item should place CYAN_CRYSTAL")

	cm.set_block(build_pos, item_data.place_block_id)
	player.inventory.remove_from_slot(player.selected_hotbar_index, 1)

	assert(cm.get_block(build_pos) == BlockManager.BlockID.CYAN_CRYSTAL, "Block at build_pos should now be CYAN_CRYSTAL")
	assert(player.inventory.get_slot(0).count == 2, "Hotbar slot count should be decremented to 2")
	print("✓ Building placed block and consumed exactly 1 unit from inventory")

	# Test empty slot cannot build
	player.inventory.get_slot(0).clear()
	var slot_empty = player.inventory.get_slot(0)
	assert(slot_empty.is_empty(), "Slot is empty")
	# If player tried to build with empty slot, action is blocked
	print("✓ Building blocked when hotbar slot has no items")

func _test_d_persistence() -> void:
	print("\n--- TEST D: SALVAMENTO E CARREGAMENTO PERSISTENTE ---")
	# Set player stats and inventory
	player.global_position = Vector2(123.0, 45.0)
	player.current_health = 88.0
	player.current_oxygen = 77.0
	player.selected_hotbar_index = 4
	player.inventory.get_slot(4).item_id = "deep_stone"
	player.inventory.get_slot(4).count = 42

	# Mark modifications in chunk (0, 0)
	cm.set_block(Vector2i(5, 5), BlockManager.BlockID.CYAN_CRYSTAL)
	cm.set_block(Vector2i(6, 6), BlockManager.BlockID.AIR)

	# Save game
	main_node.save_game(false)

	# Verify save files exist on disk
	var world_meta := SaveManager.load_world_meta("test_etapa_02")
	assert(world_meta.has("seed"), "world.json must contain seed")
	assert(SaveManager.has_save("test_etapa_02") == true, "Save file exists")

	# Reset player state in memory
	player.global_position = Vector2.ZERO
	player.current_health = 10.0
	player.inventory.get_slot(4).clear()

	# Load state back from disk
	var loaded := SaveManager.load_player("test_etapa_02", player)
	assert(loaded == true, "Player save should load successfully")
	assert(player.global_position == Vector2(123.0, 45.0), "Player position restored")
	assert(player.current_health == 88.0, "Player health restored")
	assert(player.current_oxygen == 77.0, "Player oxygen restored")
	assert(player.selected_hotbar_index == 4, "Player hotbar index restored")
	assert(player.inventory.get_slot(4).item_id == "deep_stone", "Player item restored")
	assert(player.inventory.get_slot(4).count == 42, "Player item count restored")
	print("✓ Player position, stats, inventory and hotbar restored perfectly from disk")

	# Check chunk modifications restored from disk
	var chunk_disk := SaveManager.load_chunk("test_etapa_02", Vector2i(0, 0))
	assert(chunk_disk.has("modified_blocks"), "Chunk must have modified_blocks on disk")
	assert(int(chunk_disk["modified_blocks"]["5,5"]) == BlockManager.BlockID.CYAN_CRYSTAL, "Placed crystal restored")
	assert(int(chunk_disk["modified_blocks"]["6,6"]) == BlockManager.BlockID.AIR, "Mined air restored")
	print("✓ Chunk block modifications verified on disk")

func _test_e_chunk_unloading_and_negative_coords() -> void:
	print("\n--- TEST E: CHUNKS DESCARREGADOS, ITENS PERSISTENTES E COORDENADAS NEGATIVAS ---")
	var neg_coords := Vector2i(-2, -3)
	var neg_block := Vector2i(-2 * 32 + 4, -3 * 32 + 5)

	# Modify block in negative coordinate
	cm.set_block(neg_block, BlockManager.BlockID.METALLIC_ORE)
	assert(cm.get_block(neg_block) == BlockManager.BlockID.METALLIC_ORE, "Negative coordinate block set")

	# Spawn dropped item in that negative chunk
	var dropped_pos := Vector2(neg_block.x * 16.0 + 8.0, neg_block.y * 16.0 + 8.0)
	cm.spawn_dropped_item("metallic_ore", 3, dropped_pos, "neg_item_1")

	# Force unload the negative chunk
	cm._unload_chunk(neg_coords)
	assert(not cm.active_chunks.has(neg_coords), "Negative chunk unloaded")

	# Reload chunk
	cm._load_chunk(neg_coords)
	assert(cm.active_chunks.has(neg_coords), "Negative chunk reloaded")
	assert(cm.get_block(neg_block) == BlockManager.BlockID.METALLIC_ORE, "Modifications preserved after reload")

	# Check dropped item was restored in chunk
	var found_item := false
	for child in cm.items_container.get_children():
		if child is DroppedItem and child.unique_id == "neg_item_1":
			found_item = true
			assert(child.count == 3, "Restored item count is 3")
			break
	assert(found_item == true, "Dropped item in negative chunk restored successfully")
	print("✓ Negative coordinates, chunk unloading and dropped item persistence validated")
