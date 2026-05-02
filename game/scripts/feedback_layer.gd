extends CanvasLayer

func show_world_popup(world_position: Vector2, text: String, color: Color = Color("f3f7ff"), scale_boost: float = 1.0) -> void:
	var label := Label.new()
	label.text = text
	label.position = world_position + Vector2(-20, -30)
	label.modulate = color
	label.scale = Vector2.ONE * scale_boost
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(randf_range(-18.0, 18.0), -42.0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_property(label, "scale", Vector2.ONE * (scale_boost + 0.2), 0.7)
	tween.finished.connect(func() -> void: label.queue_free())

func fly_item_to_panel(world_position: Vector2, text: String, color: Color = Color("9de8ff")) -> void:
	var label := Label.new()
	label.text = text
	label.position = world_position
	label.modulate = color
	add_child(label)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", Vector2(1040, 140), 0.8)
	tween.parallel().tween_property(label, "scale", Vector2(0.55, 0.55), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.1, 0.8)
	tween.finished.connect(func() -> void: label.queue_free())
