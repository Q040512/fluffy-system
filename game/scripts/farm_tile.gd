extends Node2D

const PlaceholderSpriteFactory = preload("res://scripts/placeholder_sprite_factory.gd")

enum PlotState { UNTILLED, TILLED, GROWING, READY }

@export var tile_x := 0
@export var tile_y := 0

var game
var state: int = PlotState.UNTILLED
var seed_name := ""
var crop_name := ""
var hours_remaining := 0
var aura_level := 0
var corrupted := false
var anim_time := 0.0
var _crop_sprite: Sprite2D
var _visual_signature := ""

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("farm_tile")
	_crop_sprite = Sprite2D.new()
	_crop_sprite.centered = true
	_crop_sprite.position = Vector2(0, -4)
	add_child(_crop_sprite)

func _process(delta: float) -> void:
	anim_time += delta
	if state != PlotState.UNTILLED:
		_update_crop_visual(false)
		queue_redraw()

func interact(main) -> void:
	game = main
	match state:
		PlotState.UNTILLED:
			if not game.spend_spirit(4.0):
				return
			state = PlotState.TILLED
			game.advance_minutes(20)
			game.notify_tutorial_event("tilled")
			game.feedback_layer.show_world_popup(global_position, "开垦", Color("c9a97a"))
			game.ui.push_message("你以灵锄开垦了一块灵田。")
		PlotState.TILLED:
			var chosen_seed := game.choose_available_seed()
			if chosen_seed == "":
				game.ui.push_message("背包里没有灵种。")
				return
			if not game.spend_spirit(3.0):
				return
			if not game.remove_item(chosen_seed, 1):
				return
			var crop := game.get_crop_data(chosen_seed)
			seed_name = chosen_seed
			crop_name = crop.get("crop_name", "")
			hours_remaining = int(crop.get("hours", 18))
			aura_level = 1
			corrupted = false
			state = PlotState.GROWING
			game.advance_minutes(25)
			game.notify_tutorial_event("planted")
			game.feedback_layer.show_world_popup(global_position, "播种", Color("b8f0a5"))
			game.ui.push_message("你播下了%s。再引灵几次会长得更快。" % crop_name)
		PlotState.GROWING:
			if not game.spend_spirit(2.0):
				return
			aura_level = min(aura_level + 1, 3)
			if corrupted:
				corrupted = false
				game.ui.push_message("魔障被驱散，灵植重新稳定。")
			else:
				game.ui.push_message("灵气汇入田垄，%s气色更盛。" % crop_name)
			game.notify_tutorial_event("channeled")
			game.feedback_layer.show_world_popup(global_position, "引灵", Color("9de8ff"), 0.9)
			game.advance_minutes(15)
		PlotState.READY:
			var crop := game.get_crop_data(seed_name)
			var amount := randi_range(crop.get("yield_min", 1), crop.get("yield_max", 1))
			var harvested_name := crop_name
			var is_rare := aura_level >= 3 and (randf() < 0.35 or game.current_weather == "血月")
			if aura_level >= 3:
				amount += 1
			if is_rare:
				amount += 1
				game.feedback_layer.show_world_popup(global_position, "极品收成", Color("ffd77a"), 1.2)
				game.environment_fx.trigger_harvest_burst(global_position, Color("ffd77a"))
				game.add_cultivation(18, global_position)
			game.add_item(harvested_name, amount)
			game.add_spirit_stones(amount * int(crop.get("price", 6)))
			game.feedback_layer.fly_item_to_panel(global_position, harvested_name, Color("9de8ff"))
			state = PlotState.TILLED
			seed_name = ""
			crop_name = ""
			hours_remaining = 0
			aura_level = 0
			corrupted = false
			game.advance_minutes(20)
			game.notify_tutorial_event("harvested")
			game.ui.push_message("你收获了 %d 份%s。" % [amount, harvested_name])
	_update_crop_visual(true)
	queue_redraw()

func pass_hour(weather: String) -> void:
	if state != PlotState.GROWING:
		return
	var crop := game.get_crop_data(seed_name)
	var growth := 1
	if aura_level > 0:
		growth += 1
	if aura_level >= 3:
		growth += 1
	if weather == crop.get("bonus_weather", ""):
		growth += 1
	if weather == "血月" and randf() < 0.22:
		corrupted = true
	if weather == "雾瘴" and randf() < 0.1:
		corrupted = true
	if corrupted:
		growth = max(growth - 1, 0)
	if growth > 0:
		hours_remaining = max(hours_remaining - growth, 0)
	if hours_remaining == 0:
		state = PlotState.READY
	_update_crop_visual(true)
	queue_redraw()

func _draw() -> void:
	var base_color := Color("5d4834")
	var inner_color := Color("6e573d")
	var pulse := 0.0
	match state:
		PlotState.UNTILLED:
			base_color = Color("45403a")
			inner_color = Color("4f4941")
		PlotState.TILLED:
			base_color = Color("6f5337")
			inner_color = Color("876545")
		PlotState.GROWING:
			base_color = Color("6f5337")
			inner_color = Color("876545")
		PlotState.READY:
			base_color = Color("7e643b")
			inner_color = Color("937842")
	if state == PlotState.GROWING or state == PlotState.READY:
		pulse = sin(anim_time * 3.2 + float(tile_x + tile_y)) * 0.5 + 0.5
		base_color = base_color.lerp(Color("728b57"), 0.05 * pulse)
	draw_rect(Rect2(Vector2(-26, -26), Vector2(52, 52)), base_color)
	draw_rect(Rect2(Vector2(-22, -22), Vector2(44, 44)), inner_color)
	if state == PlotState.GROWING or state == PlotState.READY:
		draw_rect(Rect2(Vector2(-16, 12), Vector2(32, 6)), Color("20353a"))
		var progress := 1.0 - (float(hours_remaining) / max(float(game.get_crop_data(seed_name).get("hours", 1)), 1.0))
		if state == PlotState.READY:
			progress = 1.0
		draw_rect(Rect2(Vector2(-16, 12), Vector2(32 * progress, 6)), Color("86e0c2"))
	if aura_level > 0 and state in [PlotState.GROWING, PlotState.READY]:
		for index in aura_level:
			var offset_y := sin(anim_time * 4.5 + index) * 2.0
			draw_circle(Vector2(-15 + index * 12, -18 + offset_y), 2.5 + pulse * 0.6, Color("9de8ff"))

func _update_crop_visual(force: bool) -> void:
	if _crop_sprite == null:
		return
	if state != PlotState.GROWING and state != PlotState.READY:
		_crop_sprite.visible = false
		_visual_signature = ""
		return
	_crop_sprite.visible = true
	var total_hours := max(int(game.get_crop_data(seed_name).get("hours", 1)), 1)
	var ratio := 1.0 - (float(hours_remaining) / float(total_hours))
	var stage := mini(int(floor(ratio * 3.0)), 2)
	var pulse := sin(anim_time * 3.2 + float(tile_x + tile_y)) * 0.5 + 0.5
	var pulse_bucket := mini(int(floor(pulse * 3.0)), 2)
	var visual_signature := "%s|%d|%s|%s|%d" % [crop_name, stage, str(state == PlotState.READY), str(corrupted), pulse_bucket]
	if force or visual_signature != _visual_signature:
		_crop_sprite.texture = PlaceholderSpriteFactory.build_crop_texture(crop_name, stage, state == PlotState.READY, corrupted, pulse_bucket)
		_visual_signature = visual_signature
	_crop_sprite.position = Vector2(sin(anim_time * 4.0 + tile_x) * (1.0 + aura_level * 0.2), -2)
	_crop_sprite.scale = Vector2.ONE * (1.0 + pulse * 0.06)

func to_save_data() -> Dictionary:
	return {
		"tile_x": tile_x,
		"tile_y": tile_y,
		"state": state,
		"seed_name": seed_name,
		"crop_name": crop_name,
		"hours_remaining": hours_remaining,
		"aura_level": aura_level,
		"corrupted": corrupted
	}

func load_from_data(data: Dictionary) -> void:
	state = int(data.get("state", PlotState.UNTILLED))
	seed_name = data.get("seed_name", "")
	crop_name = data.get("crop_name", "")
	hours_remaining = int(data.get("hours_remaining", 0))
	aura_level = int(data.get("aura_level", 0))
	corrupted = bool(data.get("corrupted", false))
	_update_crop_visual(true)
	queue_redraw()
