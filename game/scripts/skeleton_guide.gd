extends Node2D

var anim_time := 0.0
var ask_count := 0

func _ready() -> void:
	add_to_group("interactable")

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func interact(game) -> void:
	ask_count += 1
	game.show_skeleton_qa(ask_count)

func _draw() -> void:
	var bob := sin(anim_time * 1.7) * 2.0
	draw_rect(Rect2(Vector2(-18, 8), Vector2(36, 14)), Color("5f4335"))
	draw_rect(Rect2(Vector2(-12, -2 + bob), Vector2(24, 16)), Color("7f5a44"))
	draw_circle(Vector2(0, -12 + bob), 10.0, Color("ddd0c8"))
	draw_circle(Vector2(-3, -13 + bob), 2.0, Color("2a2530"))
	draw_circle(Vector2(3, -13 + bob), 2.0, Color("2a2530"))
	draw_line(Vector2(-3, -7 + bob), Vector2(3, -7 + bob), Color("8c5048"), 2.0)
	draw_line(Vector2(-10, 3 + bob), Vector2(-18, 10 + bob), Color("d0c2b5"), 2.0)
	draw_line(Vector2(10, 3 + bob), Vector2(18, 10 + bob), Color("d0c2b5"), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-30, -26),
		"碎嘴骷髅",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("f1e4d2")
	)
