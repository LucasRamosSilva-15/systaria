class_name Recipe
extends RefCounted

var id: String = ""
var name: String = ""
var materials: Dictionary = {} # item_id (String) -> required_count (int)
var result_item_id: String = ""
var result_count: int = 1
var required_station: String = "" # "" = Manual / À mão, "workbench" = Bancada
var description: String = ""

func _init(p_id: String, p_name: String, p_materials: Dictionary, p_result_id: String, p_result_count: int = 1, p_station: String = "", p_desc: String = "") -> void:
	id = p_id
	name = p_name
	materials = p_materials
	result_item_id = p_result_id
	result_count = p_result_count
	required_station = p_station
	description = p_desc
