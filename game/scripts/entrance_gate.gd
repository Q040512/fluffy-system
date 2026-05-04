extends Node2D

@export var gate_name := "山门入口"
@export var target_position := Vector2(320, 380)

var anim_time := 0.0

func _ready() -> void:
	add_to_group("interactable")

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func interact(game) -> void:
	game.player.position = target_position
	game.ui.push_message("你从%s踏入青岚山地界。" % gate_name)
	game.feedback_layer.show_world_popup(global_position, "进入", Color("9de8ff"), 1.0)

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(anim_time * 2.3)
	draw_rect(Rect2(Vector2(-20, -10), Vector2(40, 52)), Color("6a5742"))
	draw_rect(Rect2(Vector2(-26, -16), Vector2(52, 10)), Color("7f6a52"))
	draw_circle(Vector2(0, 18), 7.0 + pulse * 1.2, Color(0.6, 0.9, 1.0, 0.24))
	draw_string(ThemeDB.fallback_font, Vector2(-34, -24), gate_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e6f2ff"))
