@tool
extends RefCounted

const TYPE_ORDER := ["npc", "battle_trigger", "exit", "shop", "pickup", "notice", "object"]
const TYPE_LABELS := {
	"npc": "NPC",
	"battle_trigger": "战斗",
	"exit": "出口",
	"shop": "商店",
	"pickup": "拾取",
	"notice": "提示",
	"object": "对象",
}
const TYPE_COLORS := {
	"npc": "#8d3b7a",
	"battle_trigger": "#8f3b2f",
	"exit": "#2f6fdd",
	"notice": "#c49a2c",
	"shop": "#3d7f5c",
	"pickup": "#7c6f3a",
	"object": "#666666",
}

static func normalize_type(object_type: String) -> String:
	var key = str(object_type).strip_edges()
	if TYPE_LABELS.has(key):
		return key
	return "object"

static func type_label(object_type: String) -> String:
	return str(TYPE_LABELS.get(normalize_type(object_type), "对象"))

static func type_color(object_type: String) -> Color:
	var color_text = str(TYPE_COLORS.get(normalize_type(object_type), "#666666"))
	return Color(color_text)

static func color_html(object_type: String) -> String:
	return type_color(object_type).to_html(false)

static func object_display_name(object_record: Dictionary) -> String:
	var display = str(object_record.get("name", "")).strip_edges()
	if not display.is_empty():
		return display
	return str(object_record.get("id", "")).strip_edges()

static func object_label(object_record: Dictionary) -> String:
	return "%s / %s" % [
		object_display_name(object_record),
		type_label(str(object_record.get("type", ""))),
	]

static func spawn_label(spawn_id: String) -> String:
	return "出生点 / %s" % str(spawn_id)

static func obstacle_label(obstacle_id: String) -> String:
	return "障碍 / %s" % str(obstacle_id)

static func build_object_summary(objects: Array) -> Dictionary:
	var counts := {}
	var rows := []
	for object_record in objects:
		if typeof(object_record) != TYPE_DICTIONARY:
			continue
		var object_id = str(object_record.get("id", "")).strip_edges()
		if object_id.is_empty():
			continue
		var type_key = normalize_type(str(object_record.get("type", "")))
		counts[type_key] = int(counts.get(type_key, 0)) + 1
		rows.append({
			"id": object_id,
			"name": object_display_name(object_record),
			"type": type_key,
			"type_label": type_label(type_key),
			"label": object_label(object_record),
			"color": color_html(type_key),
		})
	return {
		"counts": counts,
		"rows": rows,
	}
