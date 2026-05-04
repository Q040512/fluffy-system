extends Node2D

const PlaceholderSpriteFactory = preload("res://scripts/placeholder_sprite_factory.gd")

@export var speed := 150.0

var game
var facing := Vector2.DOWN
var anim_time := 0.0
var direction_name := "down"

var _sprite: AnimatedSprite2D
var _animation_player: AnimationPlayer
var _aura_scale := 1.0
var _is_meditating_visual := false

func _ready() -> void:
	z_index = 2
	_build_visual_nodes()
	_play_state_animation("idle_down")

func _process(delta: float) -> void:
	anim_time += delta
	if game != null and Input.is_action_just_pressed("interact") and game.ui.is_dialogue_open():
		game.advance_modal_dialogue()
		queue_redraw()
		return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if game != null and game.has_method("modify_move_input"):
		input_vector = game.modify_move_input(input_vector)
	_is_meditating_visual = Input.is_action_pressed("meditate")
	if input_vector != Vector2.ZERO:
		facing = input_vector.normalized()
		direction_name = _get_direction_name(facing)
		var speed_mul := 1.0
		if game != null and game.has_method("get_player_speed_multiplier"):
			speed_mul = game.get_player_speed_multiplier()
		position += facing * speed * speed_mul * delta
		position.x = clamp(position.x, 48.0, 1180.0)
		position.y = clamp(position.y, 120.0, 650.0)
		_play_state_animation("walk_%s" % direction_name)
	else:
		var idle_anim := "meditate" if _is_meditating_visual else "idle_%s" % direction_name
		_play_state_animation(idle_anim)
	if Input.is_action_just_pressed("interact"):
		game.try_interact(global_position + facing * 28.0)
	if Input.is_action_just_pressed("meditate"):
		game.meditate()
	queue_redraw()

func _draw() -> void:
	var aura_alpha := 0.12 + 0.05 * sin(anim_time * 2.0)
	var aura_radius := 13.0 * _aura_scale + sin(anim_time * 4.0) * 0.8
	draw_circle(Vector2(0, 26), aura_radius, Color(0.4, 0.9, 1.0, aura_alpha))
	if game != null and game.traversal_mode == "sword_flight":
		draw_arc(Vector2(0, 30), 18.0, 0.0, TAU, 24, Color("9ad8ff"), 2.0)
	elif game != null and game.traversal_mode == "spirit_mount":
		draw_rect(Rect2(Vector2(-12, 30), Vector2(24, 8)), Color("7c6a50"))
	if _is_meditating_visual:
		for i in 3:
			var radius := 12.0 + i * 7.0 + fmod(anim_time * 22.0, 8.0)
			draw_arc(Vector2(0, 8), radius, 0.0, TAU, 24, Color(0.55, 0.95, 1.0, 0.18), 1.5)
	draw_line(Vector2.ZERO, facing * 18.0, Color("d9f7ff"), 2.0)

func _build_visual_nodes() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = PlaceholderSpriteFactory.build_player_frames()
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	add_child(_sprite)

	_animation_player = AnimationPlayer.new()
	add_child(_animation_player)

	var idle := Animation.new()
	idle.length = 1.2
	idle.loop_mode = Animation.LOOP_LINEAR
	var idle_track := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(idle_track, NodePath("%s:position" % _sprite.name))
	idle.track_insert_key(idle_track, 0.0, Vector2(0, 0))
	idle.track_insert_key(idle_track, 0.6, Vector2(0, -2))
	idle.track_insert_key(idle_track, 1.2, Vector2(0, 0))
	_animation_player.add_animation_library("", AnimationLibrary.new())
	_animation_player.get_animation_library("").add_animation("idle_motion", idle)

	var meditate := Animation.new()
	meditate.length = 1.0
	meditate.loop_mode = Animation.LOOP_LINEAR
	var meditate_track := meditate.add_track(Animation.TYPE_VALUE)
	meditate.track_set_path(meditate_track, NodePath("%s:position" % _sprite.name))
	meditate.track_insert_key(meditate_track, 0.0, Vector2(0, 0))
	meditate.track_insert_key(meditate_track, 0.5, Vector2(0, -4))
	meditate.track_insert_key(meditate_track, 1.0, Vector2(0, 0))
	_animation_player.get_animation_library("").add_animation("meditate_motion", meditate)

func _play_state_animation(animation_name: String) -> void:
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)
	if animation_name == "meditate":
		if _animation_player.current_animation != "meditate_motion":
			_animation_player.play("meditate_motion")
		_aura_scale = 1.25
	else:
		if _animation_player.current_animation != "idle_motion":
			_animation_player.play("idle_motion")
		_aura_scale = 1.0

func _get_direction_name(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"
