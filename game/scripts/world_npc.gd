extends Node2D

@export var npc_name := "青岚师姐"

var favor := 0
var last_talk_day := -1
var anim_time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc_state")

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func interact(game) -> void:
	if game.day != last_talk_day:
		last_talk_day = game.day
		favor += 1
		game.add_item("青灵草籽", 1)
		game.notify_tutorial_event("met_npc")
		game.feedback_layer.show_world_popup(global_position, "好感 +1", Color("ffbfd5"))
		game.ui.push_message("%s赠你一包青灵草籽。好感 +1。" % npc_name)
		return
	if game.inventory.get("青灵草", 0) > 0:
		game.remove_item("青灵草", 1)
		favor += 2
		game.add_spirit_stones(12)
		game.add_cultivation(10, global_position)
		game.feedback_layer.show_world_popup(global_position, "论道 +2", Color("ffbfd5"))
		game.ui.push_message("%s收下了青灵草，与你论道片刻。好感 +2。" % npc_name)
	else:
		game.ui.push_message("%s：灵田若得灵雨相助，药性会更足。" % npc_name)

func _draw() -> void:
	var bob := sin(anim_time * 1.8) * 3.0
	var aura := 0.12 + 0.03 * sin(anim_time * 2.6)
	draw_circle(Vector2(0, 24), 13.0, Color(0.75, 0.65, 1.0, aura))
	draw_circle(Vector2(0, -12 + bob), 10, Color("ead8c0"))
	draw_rect(Rect2(Vector2(-10, -2 + bob), Vector2(20, 28)), Color("a592d7"))
	draw_line(Vector2(-12, 14 + bob), Vector2(12, 14 + bob), Color("e8dcff"), 1.5)
	if favor > 0:
		draw_circle(Vector2(0, -34 + sin(anim_time * 3.4) * 2.0), 4.0, Color(1.0, 0.78, 0.88, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-28, -24), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2f7ff"))

func to_save_data() -> Dictionary:
	return {
		"npc_name": npc_name,
		"favor": favor,
		"last_talk_day": last_talk_day
	}

func load_from_data(data: Dictionary) -> void:
	favor = int(data.get("favor", 0))
	last_talk_day = int(data.get("last_talk_day", -1))
