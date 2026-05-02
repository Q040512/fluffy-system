extends Node2D

var available := true
var anim_time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("daily_reset")

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func interact(game) -> void:
	if not available:
		game.ui.push_message("这株野生灵草今天已经被采尽了。")
		return
	if not game.spend_spirit(2.0):
		return
	available = false
	game.add_item("青灵草", 1)
	game.add_cultivation(6, global_position)
	game.feedback_layer.fly_item_to_panel(global_position, "青灵草", Color("88f0a0"))
	game.advance_minutes(20)
	game.ui.push_message("你从山壁间采到一株青灵草。")
	queue_redraw()

func on_day_started(_day: int) -> void:
	available = true
	queue_redraw()

func _draw() -> void:
	var stem_color := Color("76cf7d") if available else Color("556557")
	var sway := sin(anim_time * 2.7) * 3.0 if available else 0.0
	draw_rect(Rect2(Vector2(-4 + sway * 0.2, -12), Vector2(8, 24)), stem_color)
	draw_circle(Vector2(-6 + sway, -6), 5, stem_color)
	draw_circle(Vector2(6 + sway * 0.8, -4), 5, stem_color)
	if available:
		draw_circle(Vector2(0, -18 + sin(anim_time * 5.0) * 2.0), 2.5, Color(0.8, 1.0, 0.86, 0.8))
