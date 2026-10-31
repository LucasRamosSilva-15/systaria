class_name InventorySlot
extends RefCounted

var item_id: String = ""
var count: int = 0

func is_empty() -> bool:
	return item_id == "" or count <= 0

func clear() -> void:
	item_id = ""
	count = 0

func can_stack_with(id: String) -> bool:
	if is_empty():
		return true
	if item_id != id:
		return false
	var data := ItemManager.get_item(item_id)
	var max_stack := data.max_stack if data else 999
	return count < max_stack

func get_max_stack() -> int:
	var data := ItemManager.get_item(item_id)
	return data.max_stack if data else 999

func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"count": count
	}

static func from_dict(data: Dictionary) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.item_id = str(data.get("item_id", ""))
	slot.count = int(data.get("count", 0))
	if slot.count <= 0:
		slot.clear()
	return slot

