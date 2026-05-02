extends Node2D

const MINUTES_PER_REAL_SECOND := 10.0
const START_HOUR := 6
const START_MINUTE := 0
const TIME_NAMES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
const WEATHER_TABLE := ["晴", "灵雨", "雾瘴", "晴", "晴", "血月"]
const REALMS := ["炼气", "筑基", "金丹", "元婴"]
const SKELETON_NAME := "碎嘴骷髅"

var day: int = 1
var season_index: int = 0
var total_minutes: float = float(START_HOUR * 60 + START_MINUTE)
var current_weather: String = "晴"
var spirit: float = 80.0
var max_spirit: float = 100.0
var spirit_stones: int = 36
var realm_index := 0
var cultivation := 0
var tutorial_stage := 0
var tutorial_intro_seen := false
var inventory := {
	"青灵草籽": 6,
	"赤火芝籽": 4,
	"青灵草": 0,
	"赤火芝": 0
}
var crop_defs := {
	"青灵草籽": {
		"crop_name": "青灵草",
		"hours": 18,
		"yield_min": 1,
		"yield_max": 2,
		"price": 8,
		"bonus_weather": "灵雨"
	},
	"赤火芝籽": {
		"crop_name": "赤火芝",
		"hours": 28,
		"yield_min": 1,
		"yield_max": 1,
		"price": 18,
		"bonus_weather": "晴"
	}
}

@onready var player := $Player
@onready var ui := $UI
@onready var environment_fx := $EnvironmentFX
@onready var feedback_layer := $FeedbackLayer

var _hour_cursor: int = START_HOUR
var _farm_tiles: Array = []
var _daily_reset_nodes: Array = []
var _interactables: Array = []
var _has_loaded_save := false

func _ready() -> void:
	randomize()
	_setup_input_map()
	player.game = self
	_farm_tiles = get_tree().get_nodes_in_group("farm_tile")
	_daily_reset_nodes = get_tree().get_nodes_in_group("daily_reset")
	_interactables = get_tree().get_nodes_in_group("interactable")
	for tile in _farm_tiles:
		tile.game = self
	current_weather = _roll_weather()
	_has_loaded_save = load_game()
	for node in _daily_reset_nodes:
		if node.has_method("on_day_started"):
			node.on_day_started(day)
	_hour_cursor = get_hour_of_day()
	if not _has_loaded_save and not tutorial_intro_seen:
		start_skeleton_intro()
	queue_redraw()

func _process(delta: float) -> void:
	total_minutes += delta * MINUTES_PER_REAL_SECOND
	var new_day := int(total_minutes / (24.0 * 60.0)) + 1
	if new_day != day:
		_on_new_day(new_day)
	var hour_now := get_hour_of_day()
	while _hour_cursor != hour_now:
		_hour_cursor = (_hour_cursor + 1) % 24
		_on_hour_changed(_hour_cursor)
	if is_input_blocked():
		return
	if Input.is_action_just_pressed("breakthrough"):
		attempt_breakthrough()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("15232f"))
	draw_rect(Rect2(Vector2(0, 120), Vector2(1280, 600)), Color("2b4838"))
	draw_rect(Rect2(Vector2(160, 140), Vector2(270, 250)), Color("4f3f2c"))
	draw_rect(Rect2(Vector2(470, 120), Vector2(130, 120)), Color("3b5369"))
	draw_rect(Rect2(Vector2(470, 240), Vector2(160, 140)), Color("314233"))
	draw_string(ThemeDB.fallback_font, Vector2(180, 405), "灵田", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(485, 110), "青岚阁", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(92, 290), "山壁灵草", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(388, 392), "骨祠", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7d8ca"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _setup_input_map() -> void:
	_add_key_if_missing("interact", KEY_E)
	_add_key_if_missing("interact", KEY_SPACE)
	_add_key_if_missing("meditate", KEY_R)
	_add_key_if_missing("breakthrough", KEY_F)

func _add_key_if_missing(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	InputMap.action_add_event(action, event)

func is_input_blocked() -> bool:
	return ui.is_dialogue_open()

func advance_modal_dialogue() -> void:
	ui.advance_dialogue()

func get_hour_of_day() -> int:
	return int(total_minutes / 60.0) % 24

func get_minute_of_hour() -> int:
	return int(total_minutes) % 60

func get_time_label() -> String:
	var hour := get_hour_of_day()
	var shichen := TIME_NAMES[int(hour / 2)]
	return "第%d日 %s时 %02d:%02d" % [day, shichen, hour, get_minute_of_hour()]

func get_season_name() -> String:
	return ["春", "夏", "秋", "冬"][season_index]

func get_realm_name() -> String:
	return REALMS[realm_index]

func get_breakthrough_cost() -> int:
	return 80 + realm_index * 50

func get_current_objective_text() -> String:
	match tutorial_stage:
		0:
			return "按 E 推完骷髅废话"
		1:
			return "去开垦一块灵田，证明你不是来散步的"
		2:
			return "往田里播一颗灵种"
		3:
			return "再对着灵田引灵一次，别让草比你还懒"
		4:
			return "等成熟后收获，骷髅已经准备好嘲笑你了"
		5:
			return "找青岚师姐说话，看看活人是不是也这么难带"
		_:
			return "自由修仙。骷髅还在旁边看你笑话。"

func start_skeleton_intro() -> void:
	tutorial_intro_seen = true
	tutorial_stage = 0
	ui.show_dialogue(SKELETON_NAME, [
		"醒了？很好，说明你还没彻底死透。虽然从你这眼神看，也差不了多少。",
		"欢迎来到青岚山。别紧张，这里不收废物。最多把废物埋在后山，种成灵草。",
		"你左手边那几块地，看见没？先去开一块。连泥都不会翻，就别妄想翻身成仙。",
		"按 E 跟东西互动。是的，我知道这种常识还要我教，你已经开始让我头疼了。"
	])

func show_skeleton_hint() -> void:
	var lines: Array[String] = []
	match tutorial_stage:
		0, 1:
			lines = ["你还站着？去开垦灵田。地不会自己翻，就像你不会自己开窍。"]
		2:
			lines = ["地翻好了就播种。别对着空地发呆，发呆长不出灵草，只长得出失败。"]
		3:
			lines = ["灵种下去了，再引灵一次。你要是连催个芽都嫌累，建议直接回棺材。"]
		4:
			lines = ["等它成熟再收。提前薅秃只能证明你对植物和人生都没有耐心。"]
		5:
			lines = ["去找青岚师姐。活人至少还会给你点种子，我只会给你建议，而且很刻薄。"]
		_:
			lines = ["不错，你至少学会了最基础的事。离成仙还远，但离被我骂废物稍微远了一点。"]
	ui.show_dialogue(SKELETON_NAME, lines)

func notify_tutorial_event(event_name: String) -> void:
	match event_name:
		"tilled":
			if tutorial_stage <= 1:
				tutorial_stage = 2
				ui.show_dialogue(SKELETON_NAME, [
					"哦？你居然真翻出来了。看来你不是纯摆设。",
					"现在把灵种播进去。随便挑一颗，反正第一轮你大概率也种不出什么传世奇株。"
				])
		"planted":
			if tutorial_stage <= 2:
				tutorial_stage = 3
				ui.show_dialogue(SKELETON_NAME, [
					"总算播下去了。看到没，你离农业废物只差半步了。",
					"接下来对着灵田再引一次灵。灵气懂事，你最好也懂事。"
				])
		"channeled":
			if tutorial_stage <= 3:
				tutorial_stage = 4
				ui.show_dialogue(SKELETON_NAME, [
					"这才像点样子。现在等成熟，再收获。",
					"耐心一点。别像某些人修仙三天就想飞升，最后只会飞出去摔死。"
				])
		"harvested":
			if tutorial_stage <= 4:
				tutorial_stage = 5
				ui.show_dialogue(SKELETON_NAME, [
					"居然真收上来了。很好，至少饿不死，或者说，暂时饿不死。",
					"去找青岚师姐说话。她脾气比我好，但眼光未必比我差。"
				])
		"met_npc":
			if tutorial_stage <= 5:
				tutorial_stage = 6
				ui.show_dialogue(SKELETON_NAME, [
					"行，活人关系也搭上了。你现在算半个能喘气的修士了。",
					"剩下的路自己滚着走吧。我会继续看着你，主要是为了在你犯蠢时及时嘲笑。"
				])

func _on_hour_changed(hour: int) -> void:
	for tile in _farm_tiles:
		tile.pass_hour(current_weather)
	if hour == 6:
		spirit = min(max_spirit, spirit + 8.0)

func _on_new_day(new_day: int) -> void:
	day = new_day
	current_weather = _roll_weather()
	spirit = min(max_spirit, spirit + 12.0)
	if day > 1 and (day - 1) % 30 == 0:
		season_index = (season_index + 1) % 4
	for node in _daily_reset_nodes:
		if node.has_method("on_day_started"):
			node.on_day_started(day)
	if current_weather == "血月":
		environment_fx.trigger_thunder_strike(Vector2(320, 210), false)
	save_game()

func _roll_weather() -> String:
	return WEATHER_TABLE[randi() % WEATHER_TABLE.size()]

func spend_spirit(amount: float) -> bool:
	if spirit < amount:
		ui.push_message("灵力不足，先打坐恢复。")
		return false
	spirit -= amount
	return true

func restore_spirit(amount: float) -> void:
	spirit = min(max_spirit, spirit + amount)

func meditate() -> void:
	restore_spirit(18.0)
	advance_minutes(90)
	feedback_layer.show_world_popup(player.global_position, "吐纳 +18", Color("9de8ff"))
	ui.push_message("你在静息吐纳，灵力恢复了。")

func advance_minutes(minutes: int) -> void:
	total_minutes += minutes

func add_item(item_name: String, amount: int) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + amount
	ui.queue_redraw()

func remove_item(item_name: String, amount: int) -> bool:
	if inventory.get(item_name, 0) < amount:
		return false
	inventory[item_name] -= amount
	ui.queue_redraw()
	return true

func add_spirit_stones(amount: int) -> void:
	spirit_stones += amount
	feedback_layer.show_world_popup(player.global_position + Vector2(0, -20), "+%d 灵石" % amount, Color("ffe394"))
	ui.push_message("获得 %d 灵石。" % amount)

func add_cultivation(amount: int, source_position: Vector2) -> void:
	cultivation += amount
	feedback_layer.show_world_popup(source_position, "+%d 修为" % amount, Color("c7b3ff"))

func try_interact(target_position: Vector2) -> void:
	var nearest = null
	var best_distance := 999999.0
	for node in _interactables:
		var distance := node.global_position.distance_to(target_position)
		if distance < 42.0 and distance < best_distance:
			best_distance = distance
			nearest = node
	if nearest and nearest.has_method("interact"):
		feedback_layer.show_world_popup(nearest.global_position, "交互", Color("ffffff"), 0.8)
		nearest.interact(self)
	else:
		ui.push_message("附近没有可交互的目标。")

func attempt_breakthrough() -> void:
	if realm_index >= REALMS.size() - 1:
		ui.push_message("你已达到当前原型的最高境界。")
		return
	if spirit < max_spirit:
		ui.push_message("突破前需要灵力圆满。")
		return
	var cost := get_breakthrough_cost()
	if spirit_stones < cost:
		ui.push_message("灵石不足，无法布置突破法阵。")
		return
	spirit_stones -= cost
	advance_minutes(180)
	var success_rate := 0.65 + min(float(cultivation) / 240.0, 0.25)
	if current_weather == "血月":
		success_rate -= 0.1
	elif current_weather == "灵雨":
		success_rate += 0.08
	var success := randf() < success_rate
	environment_fx.trigger_breakthrough(player.global_position, success)
	if success:
		realm_index += 1
		cultivation = 0
		max_spirit += 25.0
		spirit = max_spirit
		feedback_layer.show_world_popup(player.global_position, "%s成" % get_realm_name(), Color("ffd77a"), 1.4)
		ui.push_message("你成功突破至%s，气海大开。" % get_realm_name())
	else:
		spirit = max(spirit - 28.0, 12.0)
		feedback_layer.show_world_popup(player.global_position, "突破受阻", Color("ff8d8d"), 1.2)
		ui.push_message("突破失败，气息翻涌，所幸未伤根基。")

func get_crop_data(seed_name: String) -> Dictionary:
	return crop_defs.get(seed_name, {})

func choose_available_seed() -> String:
	if inventory.get("青灵草籽", 0) > 0:
		return "青灵草籽"
	if inventory.get("赤火芝籽", 0) > 0:
		return "赤火芝籽"
	return ""

func save_game() -> void:
	var farm_state: Array = []
	for tile in _farm_tiles:
		farm_state.append(tile.to_save_data())
	var npc_state: Array = []
	for npc in get_tree().get_nodes_in_group("npc_state"):
		npc_state.append(npc.to_save_data())
	var world_state := {
		"day": day,
		"season_index": season_index,
		"total_minutes": total_minutes,
		"weather": current_weather,
		"spirit": spirit,
		"spirit_stones": spirit_stones,
		"realm_index": realm_index,
		"cultivation": cultivation,
		"tutorial_stage": tutorial_stage,
		"tutorial_intro_seen": tutorial_intro_seen,
		"inventory": inventory,
		"player_position": {
			"x": player.position.x,
			"y": player.position.y
		},
		"farm": farm_state,
		"npcs": npc_state
	}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(world_state))

func load_game() -> bool:
	if not FileAccess.file_exists("user://savegame.json"):
		return false
	var file := FileAccess.open("user://savegame.json", FileAccess.READ)
	if file == null:
		return false
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	day = parsed.get("day", day)
	season_index = parsed.get("season_index", season_index)
	total_minutes = float(parsed.get("total_minutes", total_minutes))
	current_weather = parsed.get("weather", current_weather)
	spirit = float(parsed.get("spirit", spirit))
	spirit_stones = int(parsed.get("spirit_stones", spirit_stones))
	realm_index = int(parsed.get("realm_index", realm_index))
	cultivation = int(parsed.get("cultivation", cultivation))
	tutorial_stage = int(parsed.get("tutorial_stage", tutorial_stage))
	tutorial_intro_seen = bool(parsed.get("tutorial_intro_seen", tutorial_intro_seen))
	inventory = parsed.get("inventory", inventory)
	var player_position: Dictionary = parsed.get("player_position", {})
	if not player_position.is_empty():
		player.position = Vector2(
			float(player_position.get("x", player.position.x)),
			float(player_position.get("y", player.position.y))
		)
	for tile_data in parsed.get("farm", []):
		for tile in _farm_tiles:
			if tile.tile_x == tile_data.get("tile_x", -1) and tile.tile_y == tile_data.get("tile_y", -1):
				tile.load_from_data(tile_data)
	for npc_data in parsed.get("npcs", []):
		for npc in get_tree().get_nodes_in_group("npc_state"):
			if npc.npc_name == npc_data.get("npc_name", ""):
				npc.load_from_data(npc_data)
	return true
