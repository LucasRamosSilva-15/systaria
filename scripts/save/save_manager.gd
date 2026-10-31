class_name SaveManager
extends RefCounted

const SAVE_VERSION: int = 1
const BASE_SAVES_DIR: String = "user://saves"

static func get_world_dir(world_id: String = "world_001") -> String:
	return BASE_SAVES_DIR.path_join(world_id)

static func get_chunks_dir(world_id: String = "world_001") -> String:
	return get_world_dir(world_id).path_join("chunks")

static func ensure_dirs(world_id: String = "world_001") -> void:
	var c_dir := get_chunks_dir(world_id)
	if not DirAccess.dir_exists_absolute(c_dir):
		DirAccess.make_dir_recursive_absolute(c_dir)

static func safe_write_json(path: String, data: Variant) -> bool:
	var json_str := JSON.stringify(data, "\t")
	var tmp_path := path + ".tmp"

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not f:
		push_error("SaveManager: Failed to open tmp file for write: %s" % tmp_path)
		return false
	f.store_string(json_str)
	f.close()

	# Atomically replace destination file
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		# Fallback if rename fails
		var src := FileAccess.open(tmp_path, FileAccess.READ)
		var dst := FileAccess.open(path, FileAccess.WRITE)
		if src and dst:
			dst.store_string(src.get_as_text())
			src.close()
			dst.close()
			DirAccess.remove_absolute(tmp_path)
			return true
		push_error("SaveManager: Failed to rename tmp to destination: %s" % path)
		return false
	return true

static func safe_read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var text := f.get_as_text()
	f.close()

	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(text)
	if error != OK:
		push_error("SaveManager: JSON parse error in %s: %s" % [path, test_json_conv.get_error_message()])
		return null
	return test_json_conv.data

static func save_world_meta(world_id: String, world_seed: int) -> bool:
	ensure_dirs(world_id)
	var meta := {
		"version": SAVE_VERSION,
		"world_id": world_id,
		"seed": world_seed,
		"timestamp": Time.get_unix_time_from_system()
	}
	return safe_write_json(get_world_dir(world_id).path_join("world.json"), meta)

static func load_world_meta(world_id: String) -> Dictionary:
	var path := get_world_dir(world_id).path_join("world.json")
	var data = safe_read_json(path)
	if data is Dictionary:
		return data
	return {}

static func save_player(world_id: String, player: PlayerController) -> bool:
	if not player:
		return false
	ensure_dirs(world_id)
	var p_data := {
		"version": SAVE_VERSION,
		"world_id": world_id,
		"x": player.global_position.x,
		"y": player.global_position.y,
		"health": player.current_health,
		"oxygen": player.current_oxygen,
		"selected_hotbar_index": player.selected_hotbar_index,
		"inventory": player.inventory.serialize()
	}
	return safe_write_json(get_world_dir(world_id).path_join("player.json"), p_data)

static func load_player(world_id: String, player: PlayerController) -> bool:
	if not player:
		return false
	var path := get_world_dir(world_id).path_join("player.json")
	var p_data = safe_read_json(path)
	if not (p_data is Dictionary):
		return false

	if p_data.has("x") and p_data.has("y"):
		player.global_position = Vector2(float(p_data["x"]), float(p_data["y"]))
	if p_data.has("health"):
		player.current_health = float(p_data["health"])
	if p_data.has("oxygen"):
		player.current_oxygen = float(p_data["oxygen"])
	if p_data.has("selected_hotbar_index"):
		player.selected_hotbar_index = int(p_data["selected_hotbar_index"])
	if p_data.has("inventory") and (p_data["inventory"] is Array):
		player.inventory.deserialize(p_data["inventory"])
	return true

static func get_chunk_file_path(world_id: String, coords: Vector2i) -> String:
	return get_chunks_dir(world_id).path_join("chunk_%d_%d.json" % [coords.x, coords.y])

static func save_chunk(world_id: String, coords: Vector2i, modified_blocks: Dictionary, dropped_items: Array = []) -> bool:
	# Only create file if there are actual modifications or dropped items
	var path := get_chunk_file_path(world_id, coords)
	if modified_blocks.is_empty() and dropped_items.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return true

	ensure_dirs(world_id)
	var chunk_data := {
		"version": SAVE_VERSION,
		"coords": [coords.x, coords.y],
		"modified_blocks": modified_blocks,
		"dropped_items": dropped_items
	}
	return safe_write_json(path, chunk_data)

static func load_chunk(world_id: String, coords: Vector2i) -> Dictionary:
	var path := get_chunk_file_path(world_id, coords)
	var data = safe_read_json(path)
	if data is Dictionary:
		return data
	return {}

static func has_save(world_id: String = "world_001") -> bool:
	return FileAccess.file_exists(get_world_dir(world_id).path_join("world.json"))

