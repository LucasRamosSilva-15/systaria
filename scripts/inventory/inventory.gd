class_name Inventory
extends RefCounted

signal inventory_changed
signal slot_changed(slot_idx: int)

const TOTAL_SLOTS: int = 40
const HOTBAR_SLOTS: int = 10

var slots: Array[InventorySlot] = []

func _init(p_total_slots: int = TOTAL_SLOTS) -> void:
	slots.resize(p_total_slots)
	for i in range(p_total_slots):
		slots[i] = InventorySlot.new()

func get_slot(idx: int) -> InventorySlot:
	if idx < 0 or idx >= slots.size():
		return null
	return slots[idx]

## Adds an item to the inventory. Returns the remaining count that could not fit (0 if all added).
func add_item(item_id: String, count: int) -> int:
	if item_id == "" or count <= 0:
		return 0

	var item_data := ItemManager.get_item(item_id)
	var max_stack := item_data.max_stack if item_data else 999
	var remaining: int = count

	# 1. Fill existing stacks of this item
	for i in range(slots.size()):
		var slot := slots[i]
		if not slot.is_empty() and slot.item_id == item_id and slot.count < max_stack:
			var space: int = max_stack - slot.count
			var to_add: int = mini(remaining, space)
			slot.count += to_add
			remaining -= to_add
			slot_changed.emit(i)
			if remaining <= 0:
				inventory_changed.emit()
				return 0

	# 2. Fill empty slots
	for i in range(slots.size()):
		var slot := slots[i]
		if slot.is_empty():
			var to_add: int = mini(remaining, max_stack)
			slot.item_id = item_id
			slot.count = to_add
			remaining -= to_add
			slot_changed.emit(i)
			if remaining <= 0:
				inventory_changed.emit()
				return 0

	inventory_changed.emit()
	return remaining

## Removes a specific quantity of an item from anywhere in the inventory.
func remove_item(item_id: String, count: int) -> bool:
	if get_item_count(item_id) < count:
		return false

	var needed: int = count
	for i in range(slots.size() - 1, -1, -1):
		var slot := slots[i]
		if slot.item_id == item_id:
			if slot.count <= needed:
				needed -= slot.count
				slot.clear()
				slot_changed.emit(i)
			else:
				slot.count -= needed
				needed = 0
				slot_changed.emit(i)
				break

	inventory_changed.emit()
	return true

## Removes items specifically from a given slot index.
func remove_from_slot(slot_idx: int, count: int = 1) -> bool:
	var slot := get_slot(slot_idx)
	if not slot or slot.is_empty() or slot.count < count:
		return false

	slot.count -= count
	if slot.count <= 0:
		slot.clear()
	slot_changed.emit(slot_idx)
	inventory_changed.emit()
	return true

## Returns true if the inventory contains at least `count` units of `item_id`.
func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

## Total count of a specific item across all 40 slots.
func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if slot.item_id == item_id:
			total += slot.count
	return total

## Swaps or stacks two slots together.
func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a == idx_b:
		return
	var slot_a := get_slot(idx_a)
	var slot_b := get_slot(idx_b)
	if not slot_a or not slot_b:
		return

	# If both slots have the same item type, merge them up to max stack
	if not slot_a.is_empty() and not slot_b.is_empty() and slot_a.item_id == slot_b.item_id:
		var max_stack := slot_b.get_max_stack()
		var space: int = max_stack - slot_b.count
		if space > 0:
			var to_move: int = mini(slot_a.count, space)
			slot_b.count += to_move
			slot_a.count -= to_move
			if slot_a.count <= 0:
				slot_a.clear()
			slot_changed.emit(idx_a)
			slot_changed.emit(idx_b)
			inventory_changed.emit()
			return

	# Otherwise normal swap
	var temp_id: String = slot_a.item_id
	var temp_count: int = slot_a.count
	slot_a.item_id = slot_b.item_id
	slot_a.count = slot_b.count
	slot_b.item_id = temp_id
	slot_b.count = temp_count

	slot_changed.emit(idx_a)
	slot_changed.emit(idx_b)
	inventory_changed.emit()

## Splits half of slot_a into slot_b (if empty or same type).
func split_slot(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	var slot_from := get_slot(from_idx)
	var slot_to := get_slot(to_idx)
	if not slot_from or not slot_to or slot_from.is_empty():
		return

	var take_count: int = int(ceil(float(slot_from.count) / 2.0))

	if slot_to.is_empty():
		slot_to.item_id = slot_from.item_id
		slot_to.count = take_count
		slot_from.count -= take_count
		if slot_from.count <= 0:
			slot_from.clear()
		slot_changed.emit(from_idx)
		slot_changed.emit(to_idx)
		inventory_changed.emit()
	elif slot_to.item_id == slot_from.item_id:
		var max_stack := slot_to.get_max_stack()
		var space: int = max_stack - slot_to.count
		var actual_move: int = mini(take_count, space)
		if actual_move > 0:
			slot_to.count += actual_move
			slot_from.count -= actual_move
			if slot_from.count <= 0:
				slot_from.clear()
			slot_changed.emit(from_idx)
			slot_changed.emit(to_idx)
			inventory_changed.emit()

func serialize() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in slots:
		result.append(slot.to_dict())
	return result

func deserialize(data: Array) -> void:
	for i in range(mini(TOTAL_SLOTS, data.size())):
		var entry = data[i]
		if entry is Dictionary:
			slots[i] = InventorySlot.from_dict(entry)
		else:
			slots[i] = InventorySlot.new()
	inventory_changed.emit()
