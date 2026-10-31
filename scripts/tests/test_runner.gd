extends SceneTree

var _frames: int = 0

func _init() -> void:
	print("=== INITIATING ABYSSUS VERIFICATION TEST ===")
	change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> bool:
	_frames += 1
	if not current_scene or _frames < 3:
		return false

	var main_node := current_scene
	var cm: ChunkManager = main_node.get_node("World/ChunkManager")
	var player: PlayerController = main_node.get_node("Player")
	var hud: HUDController = main_node.get_node("HUD")

	print("--- VERIFICATION METRICS ---")
	print("Current Scene: ", main_node.name)
	print("Active Chunks: ", cm.active_chunks.size())
	print("Player Position: ", player.global_position)
	print("Player Health: ", player.current_health)
	print("Player Oxygen: ", player.current_oxygen)

	# Test mining on a guaranteed surface dirt block
	var test_block := Vector2i(0, 2)
	var initial_id: int = cm.get_block(test_block)
	print("Block at (0, 2): ", initial_id, " (", BlockManager.get_block(initial_id).name, ")")
	if initial_id == BlockManager.BlockID.AIR:
		push_error("Assertion failed: block at (0, 2) should be solid dirt!")
		quit(1)
		return true

	# Set to AIR (Mine)
	cm.set_block(test_block, BlockManager.BlockID.AIR)
	var after_mine: int = cm.get_block(test_block)
	print("Block after mining at (0, 2): ", after_mine)
	if after_mine != BlockManager.BlockID.AIR:
		push_error("Assertion failed: block should be AIR")
		quit(1)
		return true

	# Place CYAN_CRYSTAL
	cm.set_block(test_block, BlockManager.BlockID.CYAN_CRYSTAL)
	var after_place: int = cm.get_block(test_block)
	print("Block after placing at (0, 2): ", after_place)
	if after_place != BlockManager.BlockID.CYAN_CRYSTAL:
		push_error("Assertion failed: block should be CYAN_CRYSTAL")
		quit(1)
		return true

	print("=== ALL ABYSSUS VERIFICATION TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
	return true
