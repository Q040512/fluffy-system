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
var legend_intro_seen := false
var main_quest_stage := 0
var life_origin := "山野遗孤"
var life_traits := {}
var reincarnation_count := 0
var _is_dead := false
var story_route := "正道守山"
var joined_faction := "无门无派"
var story_phase := 0
var side_story_stage := 0
var spirit_pearls := {"风灵珠": false, "雷灵珠": false, "水灵珠": false, "火灵珠": false, "土灵珠": false}
var drunk_timer := 0.0
var drunk_strength := 0.0
var unlocked_story_count := 0
var daily_tasks: Array[Dictionary] = []
var daily_task_day := 0
var traversal_mode := "walk" # walk / sword_flight / spirit_mount
var spirit_npc_attitude := "善待"
var spirit_npc_relation := 0
var morality_alignment := "中立" # 好人 / 中立 / 坏人
var morality_score := 0
var known_languages := {"中州雅言": true}
var language_exp := {"中州雅言": 100}
var human_path := "未定" # 未定 / 学子 / 武夫 / 小贩 / 医师 / 猎户 / 匠人
var exam_rank := 0
var spiritual_root := "杂灵根"
var cultivation_focus := "法修" # 丹修 / 符修 / 体修 / 法修
var cultivation_paths := {"丹修": 0, "符修": 0, "体修": 0, "法修": 0}
var martial_art := "太极剑意"
var immortal_art := "青岚吐纳经"
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
var _skeleton_check_hour := -1

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
	if not _has_loaded_save:
		_roll_life_origin()
	if not _has_loaded_save and not legend_intro_seen:
		_show_legend_opening()
	if not _has_loaded_save and not tutorial_intro_seen:
		start_skeleton_intro()
	_refresh_daily_tasks()
	queue_redraw()

func _process(delta: float) -> void:
	if drunk_timer > 0.0:
		drunk_timer = max(drunk_timer - delta, 0.0)
		if drunk_timer == 0.0:
			drunk_strength = 0.0
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
	if spirit <= 0.0 and not _is_dead:
		_trigger_death("灵力枯竭，气海崩散。")
		return
	if Input.is_action_just_pressed("breakthrough"):
		attempt_breakthrough()
	if Input.is_action_just_pressed("free_action"):
		do_free_action()
	if Input.is_action_just_pressed("toggle_sword_flight"):
		toggle_traversal_mode("sword_flight")
	if Input.is_action_just_pressed("toggle_spirit_mount"):
		toggle_traversal_mode("spirit_mount")
	if Input.is_action_just_pressed("toggle_spirit_attitude"):
		cycle_spirit_attitude()
	if Input.is_action_just_pressed("toggle_alignment"):
		cycle_alignment()
	if Input.is_action_just_pressed("career_action"):
		try_human_career_action()
	if Input.is_action_just_pressed("switch_cultivation_focus"):
		cycle_cultivation_focus()
	if Input.is_action_just_pressed("practice_path"):
		practice_cultivation_path()
	if Input.is_action_just_pressed("switch_martial_art"):
		cycle_martial_art()
	if Input.is_action_just_pressed("switch_immortal_art"):
		cycle_immortal_art()

func _draw() -> void:
	# 顶部天空
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 140)), Color("15232f"))
	# 主地表
	draw_rect(Rect2(Vector2(0, 140), Vector2(1280, 580)), Color("2f5a43"))
	# 以“地块 + 小路 + 功能区”的方式组织，靠近星露谷式分区结构
	_draw_tiled_ground(Rect2(Vector2(0, 140), Vector2(1280, 580)), 32, Color("315f47"), Color("2c5842"))
	# 中央十字小路
	draw_rect(Rect2(Vector2(610, 140), Vector2(52, 580)), Color("8a7a58"))
	draw_rect(Rect2(Vector2(0, 402), Vector2(1280, 52)), Color("8a7a58"))
	# 农田区
	draw_rect(Rect2(Vector2(150, 170), Vector2(320, 250)), Color("4f3f2c"))
	_draw_tiled_ground(Rect2(Vector2(160, 180), Vector2(300, 230)), 32, Color("6e573d"), Color("624f36"))
	_draw_building_block(Rect2(Vector2(170, 186), Vector2(86, 70)), Color("7d5b3f"), "谷仓")
	# 宗门庭院
	draw_rect(Rect2(Vector2(470, 160), Vector2(220, 220)), Color("4a5f71"))
	_draw_tiled_ground(Rect2(Vector2(482, 172), Vector2(196, 196)), 28, Color("566d82"), Color("4c6174"))
	_draw_building_block(Rect2(Vector2(520, 186), Vector2(120, 96)), Color("5f7b96"), "青岚堂")
	# 集市/社交区
	draw_rect(Rect2(Vector2(730, 170), Vector2(280, 200)), Color("4e624f"))
	_draw_tiled_ground(Rect2(Vector2(742, 182), Vector2(256, 176)), 32, Color("5b715d"), Color("506452"))
	_draw_building_block(Rect2(Vector2(760, 196), Vector2(96, 74)), Color("7a6a52"), "茶棚")
	_draw_building_block(Rect2(Vector2(875, 206), Vector2(110, 88)), Color("6b5f49"), "杂货摊")
	# 水潭
	draw_rect(Rect2(Vector2(1010, 110), Vector2(180, 130)), Color("2f5877"))
	_draw_tiled_ground(Rect2(Vector2(1020, 120), Vector2(160, 110)), 20, Color("3d6d90"), Color("376482"))
	# 遗墟与山道
	draw_rect(Rect2(Vector2(90, 500), Vector2(220, 140)), Color("4d4658"))
	draw_rect(Rect2(Vector2(0, 460), Vector2(160, 220)), Color("3a4452"))
	_draw_building_block(Rect2(Vector2(118, 526), Vector2(120, 88)), Color("5b5266"), "残碑台")
	# 幽谷与林缘区（风格区分）
	draw_rect(Rect2(Vector2(1030, 470), Vector2(220, 180)), Color("3f4a34"))
	_draw_tiled_ground(Rect2(Vector2(1040, 480), Vector2(200, 160)), 26, Color("4d5d40"), Color("445338"))
	_draw_building_block(Rect2(Vector2(1080, 520), Vector2(120, 90)), Color("4f5b46"), "猎人营地")
	draw_string(ThemeDB.fallback_font, Vector2(180, 405), "灵田", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(485, 110), "青岚阁", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(92, 290), "山壁灵草", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dce9f3"))
	draw_string(ThemeDB.fallback_font, Vector2(388, 392), "骨祠", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7d8ca"))
	draw_string(ThemeDB.fallback_font, Vector2(1000, 96), "听雨潭", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7efff"))
	draw_string(ThemeDB.fallback_font, Vector2(1035, 468), "演武坪", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f5dec8"))
	draw_string(ThemeDB.fallback_font, Vector2(146, 556), "残碑遗墟", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dfd5f4"))
	draw_string(ThemeDB.fallback_font, Vector2(52, 456), "断云崖", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6e5f7"))
	draw_string(ThemeDB.fallback_font, Vector2(1132, 196), "裂隙秘境", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e2d7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(1085, 596), "伐木地", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2e1c4"))
	draw_string(ThemeDB.fallback_font, Vector2(232, 656), "掘洞口", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e6d9c6"))
	draw_string(ThemeDB.fallback_font, Vector2(322, 536), "刻字石", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7d3e8"))
	draw_string(ThemeDB.fallback_font, Vector2(1200, 656), "幽穴入口", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c9d8ef"))
	draw_string(ThemeDB.fallback_font, Vector2(980, 694), "神骸古坑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f5e4b8"))
	draw_string(ThemeDB.fallback_font, Vector2(600, 706), "山门入口", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9dec8"))

func _draw_tiled_ground(area: Rect2, tile: int, c1: Color, c2: Color) -> void:
	var rows := int(area.size.y / tile)
	var cols := int(area.size.x / tile)
	for y in rows:
		for x in cols:
			var color := c1 if (x + y) % 2 == 0 else c2
			draw_rect(Rect2(area.position + Vector2(x * tile, y * tile), Vector2(tile, tile)), color)

func _draw_building_block(area: Rect2, wall: Color, label: String) -> void:
	var roof := wall.darkened(0.25)
	draw_rect(Rect2(area.position + Vector2(0, -12), Vector2(area.size.x, 18)), roof)
	draw_rect(area, wall)
	draw_rect(Rect2(area.position + Vector2(area.size.x * 0.42, area.size.y - 24), Vector2(16, 24)), Color("3a2b1f"))
	draw_string(ThemeDB.fallback_font, area.position + Vector2(6, area.size.y + 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0e8dc"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _setup_input_map() -> void:
	_add_key_if_missing("interact", KEY_E)
	_add_key_if_missing("interact", KEY_SPACE)
	_add_key_if_missing("meditate", KEY_R)
	_add_key_if_missing("breakthrough", KEY_F)
	_add_key_if_missing("free_action", KEY_T)
	_add_key_if_missing("toggle_sword_flight", KEY_Y)
	_add_key_if_missing("toggle_spirit_mount", KEY_U)
	_add_key_if_missing("toggle_spirit_attitude", KEY_O)
	_add_key_if_missing("toggle_alignment", KEY_P)
	_add_key_if_missing("career_action", KEY_L)
	_add_key_if_missing("switch_cultivation_focus", KEY_I)
	_add_key_if_missing("practice_path", KEY_J)
	_add_key_if_missing("switch_martial_art", KEY_V)
	_add_key_if_missing("switch_immortal_art", KEY_B)

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
	# 允许玩家在对话期间继续移动，保持自由操控
	return false

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
	return 160 + realm_index * 120

func get_breakthrough_cultivation_req() -> int:
	return 140 + realm_index * 120

func get_current_objective_text() -> String:
	return "天地自宽，随心而行。你和谁交谈、去哪里，都会留下回响。"

func get_main_quest_objective() -> String:
	if joined_faction == "无门无派":
		return "四处走走，多和各派人物聊聊，也许会有新的去处。"
	match main_quest_stage:
		0:
			return "先把日子过稳：种田、采药、修炼都能打开新门路。"
		1:
			return "听说演武坪近日很热闹，去见识见识也无妨。"
		2:
			return "山中遗墟常出稀罕灵材，或许值得冒险一趟。"
		3:
			return "若你觉得火候到了，不妨试着冲击更高境界。"
		4:
			return "风声越来越紧，先稳住资源与人脉，再决定下一步。"
		5:
			return "最近几夜不太平，去听听各派口风再作判断。"
		6:
			return "你已卷入更深的局，修为和立场都需要再表态。"
		7:
			return "归墟将启前夜，所有旧账都在逼近。"
		_:
			return "江湖路远，继续为%s行事，风声自会变化。" % joined_faction

func _show_legend_opening() -> void:
	legend_intro_seen = true
	ui.show_dialogue("山海旧谣", [
		"相传百年前，天裂三夜，灵潮倒灌九州，诸派自此并立。",
		"青岚宗镇守东岭灵脉，幽冥殿潜行夜渊，正邪纷争从未止息。",
		"你只是山门最不起眼的弟子，却在血月之夜梦见一枚碎裂古印。",
		"骷髅说那是‘归墟印’——若其重现，天下宗门都将改写座次。"
	])
	ui.push_message("你的家世：%s｜天命：%s" % [life_origin, life_traits.get("tag", "平常")])
	ui.push_message("当前故事线：%s｜所属门派：%s" % [story_route, joined_faction])
	ui.push_message("阶段：序章（旁观者）")

func _roll_life_origin() -> void:
	var origins := [
		{"name": "山野遗孤", "spirit": 90.0, "stones": 30, "cultivation": 8, "tag": "根骨平稳"},
		{"name": "宗门旁支", "spirit": 80.0, "stones": 56, "cultivation": 12, "tag": "家传吐纳"},
		{"name": "商贾之后", "spirit": 74.0, "stones": 96, "cultivation": 5, "tag": "囊中丰足"},
		{"name": "流亡剑裔", "spirit": 102.0, "stones": 24, "cultivation": 16, "tag": "杀伐余烬"},
		{"name": "夺舍残魂", "spirit": 112.0, "stones": 18, "cultivation": 20, "tag": "魂火不稳"}
	]
	var pick: Dictionary = origins[randi() % origins.size()]
	life_origin = pick["name"]
	life_traits = pick
	spirit = min(float(pick["spirit"]), max_spirit)
	spirit_stones = int(pick["stones"])
	cultivation = int(pick["cultivation"])
	var routes := ["正道守山", "魔门逆命", "游侠问道", "王朝诏命"]
	story_route = routes[randi() % routes.size()]
	var roots := ["金灵根", "木灵根", "水灵根", "火灵根", "土灵根", "风灵根", "雷灵根", "杂灵根", "天灵根", "变异冰灵根", "变异毒灵根", "变异空灵根"]
	spiritual_root = roots[randi() % roots.size()]
	if spiritual_root == "天灵根":
		cultivation += 10
		spirit = min(spirit + 12.0, max_spirit)
	elif spiritual_root == "杂灵根":
		spirit_stones += 8
	joined_faction = "无门无派"
	story_phase = 0
	if life_origin == "夺舍残魂" and randf() < 0.35:
		_trigger_death("夺舍失败，识海反噬。少侠请重新来过。")
	if randf() < 0.05:
		_trigger_death("你一出生便卷入仇杀，未及修行已身死道消。")

func _trigger_death(reason: String) -> void:
	if _is_dead:
		return
	_is_dead = true
	ui.show_dialogue("命数已尽", [
		reason,
		"少侠请重新来过。"
	])
	ui.push_message("第%d次命轮终结。正在重开…" % (reincarnation_count + 1))
	_restart_reincarnation()

func _restart_reincarnation() -> void:
	reincarnation_count += 1
	_reset_world_state()
	_roll_life_origin()
	_is_dead = false
	_show_legend_opening()
	start_skeleton_intro()

func _reset_world_state() -> void:
	day = 1
	season_index = 0
	total_minutes = float(START_HOUR * 60 + START_MINUTE)
	current_weather = _roll_weather()
	max_spirit = 100.0
	spirit = 80.0
	spirit_stones = 36
	realm_index = 0
	cultivation = 0
	tutorial_stage = 0
	tutorial_intro_seen = false
	legend_intro_seen = false
	main_quest_stage = 0
	story_route = "正道守山"
	joined_faction = "无门无派"
	story_phase = 0
	side_story_stage = 0
	spirit_pearls = {"风灵珠": false, "雷灵珠": false, "水灵珠": false, "火灵珠": false, "土灵珠": false}
	unlocked_story_count = 0
	inventory = {"青灵草籽": 6, "赤火芝籽": 4, "青灵草": 0, "赤火芝": 0}
	player.position = Vector2(320, 380)

func start_skeleton_intro() -> void:
	tutorial_intro_seen = true
	tutorial_stage = 0
	ui.show_dialogue(SKELETON_NAME, [
		"醒了就去走走。山门里的人、山外的风，都能做你的老师。",
		"别急着问路，也别急着求成。先听，再看，再动手。"
	])

func show_skeleton_hint() -> void:
	show_skeleton_qa(1)

func show_skeleton_qa(ask_count: int) -> void:
	var topic := ask_count % 5
	var lines: Array[String] = []
	match topic:
		0:
			lines = [
				"你问修炼？先活下来再谈飞升。白天稳灵息，夜里别硬冲境界。",
				"我已经说第三遍了：急功近利的人，通常埋得也比较快。"
			]
		1:
			lines = [
				"你问门派？青岚宗讲规矩，幽冥殿讲结果，江湖散修讲命硬。",
				"别再让我做你的百科全书，我死了都没这么闲。"
			]
		2:
			lines = [
				"你问机缘？断云崖和裂隙秘境都有好东西，也都有棺材位。",
				"你要是再问‘稳不稳’，我建议你回屋种地。"
			]
		3:
			lines = [
				"你问突破？灵力满、修为够、灵石足，再挑个好天象。",
				"问完就去练，别把我当说书先生。"
			]
		_:
			lines = [
				"又来问？行吧：多和人说话，多跑地图，线索自己会露头。",
				"最后一次提醒——我很有耐心，但不是对你。"
			]
	ui.show_dialogue(SKELETON_NAME, lines)

func notify_tutorial_event(event_name: String) -> void:
	if event_name == "met_npc":
		tutorial_stage = max(tutorial_stage, 1)
	_update_main_quest(event_name)

func offer_join_faction(faction_name: String, npc_name: String) -> void:
	if joined_faction != "无门无派":
		return
	joined_faction = faction_name
	main_quest_stage = max(main_quest_stage, 1)
	story_phase = max(story_phase, 1)
	ui.show_dialogue(npc_name, [
		"从今日起，你便算%s记名弟子。" % faction_name,
		"记住：门派给你庇护，也要你拿结果回报。"
	])
	ui.push_message("你已加入%s。" % faction_name)
	ui.push_message("阶段：第一幕（入局）")

func _update_main_quest(event_name: String) -> void:
	match main_quest_stage:
		0:
			if inventory.get("青灵草", 0) >= 3:
				main_quest_stage = 1
				ui.show_dialogue("青岚师姐", [
					"三株青灵草齐了，不错。下一步去演武坪切磋，别只会种地。",
					"去不去随你，但见过刀剑的人，心境会不一样。"
				])
		1:
			if event_name == "arena_trial":
				main_quest_stage = 2
				ui.show_dialogue("松鹤师叔", [
					"拳脚还算沉稳。去残碑遗墟寻一株赤火芝，准备夜试药引。",
					"路在你脚下，敢走才有机缘。"
				])
		2:
			if inventory.get("赤火芝", 0) >= 1:
				main_quest_stage = 3
				ui.show_dialogue("玄尘师父", [
					"药引已备，接下来只差境界。",
					"急与不急都由你，但境界不会等人。"
				])
		3:
			if realm_index >= 1:
				main_quest_stage = 4
				ui.show_dialogue("碎嘴骷髅", [
					"行啊，你真筑基了。归墟印的事，看来得让你掺和一脚。",
					"你以为这就完了？这才刚开始。"
				])

func _on_hour_changed(hour: int) -> void:
	for tile in _farm_tiles:
		tile.pass_hour(current_weather)
	if hour == 6:
		spirit = min(max_spirit, spirit + 8.0)
	if hour % 6 == 0 and hour != _skeleton_check_hour:
		_skeleton_check_hour = hour
		ui.push_message("碎嘴骷髅在远处盯着你：\"别偷懒，江湖各派都在看你表现。\"")

func _on_new_day(new_day: int) -> void:
	day = new_day
	current_weather = _roll_weather()
	spirit = min(max_spirit, spirit + 12.0)
	if day > 1 and (day - 1) % 30 == 0:
		season_index = (season_index + 1) % 4
	for node in _daily_reset_nodes:
		if node.has_method("on_day_started"):
			node.on_day_started(day)
	_refresh_daily_tasks()
	_trigger_daily_event_pack()
	if current_weather == "血月":
		environment_fx.trigger_thunder_strike(Vector2(320, 210), false)
	_update_story_phase_by_day()
	_advance_long_arc_by_day()
	_trigger_post_mainline_story()
	save_game()

func _trigger_post_mainline_story() -> void:
	if main_quest_stage < 8:
		return
	if side_story_stage == 0 and day >= 30:
		side_story_stage = 1
		ui.show_dialogue("异闻录", [
			"【后续故事·药王失踪】药庐主事失联，只留下一张残图。",
			"线索指向听雨潭与残碑遗墟之间的旧路。"
		])
	elif side_story_stage == 1 and day >= 34:
		side_story_stage = 2
		ui.show_dialogue("江湖耳报", [
			"【后续故事·剑帖再现】昆仑旧剑帖重现黑市，几派同时派人争夺。",
			"你若介入，可能换来新盟友，也可能添旧仇。"
		])
	elif side_story_stage == 2 and day >= 38:
		side_story_stage = 3
		ui.show_dialogue("碎嘴骷髅", [
			"【后续故事·故城夜雨】城外废城在雨夜亮灯，像在等谁回去。",
			"去不去随你，但这种门不会一直开着。"
		])
	elif side_story_stage == 3 and _count_collected_pearls() >= 3:
		side_story_stage = 4
		ui.show_dialogue("古卷残页", [
			"【后续故事·灵珠旧约】你已凑齐三枚灵珠，古卷开始显现缺失地图。",
			"传说五珠归位，可开归墟内层。"
		])
	elif side_story_stage == 4 and _count_collected_pearls() >= 5:
		side_story_stage = 5
		ui.show_dialogue("碎嘴骷髅", [
			"【后续故事·五珠齐鸣】五灵珠已齐，天地灵脉共振。",
			"你可以选择开启归墟内层，或者把钥匙留给后来者。"
		])

func collect_spirit_pearl(pearl_name: String, source_name: String) -> void:
	if not spirit_pearls.has(pearl_name):
		return
	if bool(spirit_pearls[pearl_name]):
		return
	spirit_pearls[pearl_name] = true
	ui.show_dialogue("灵珠异象", [
		"你在%s获得了%s。珠光映照出一段失落旧闻。" % [source_name, pearl_name],
		"当前灵珠进度：%d / 5。" % _count_collected_pearls()
	])
	feedback_layer.show_world_popup(player.global_position + Vector2(0, -40), pearl_name, Color("9de8ff"), 1.4)

func _count_collected_pearls() -> int:
	var count := 0
	for key in spirit_pearls.keys():
		if bool(spirit_pearls[key]):
			count += 1
	return count

func apply_drunkenness(duration_seconds: float, strength: float) -> void:
	drunk_timer = max(drunk_timer, duration_seconds)
	drunk_strength = max(drunk_strength, clamp(strength, 0.05, 0.45))
	ui.push_message("你有点上头了，脚下开始发飘。")


func toggle_traversal_mode(mode_name: String) -> void:
	if traversal_mode == mode_name:
		traversal_mode = "walk"
		ui.push_message("你收起%s，回到步行。" % ("飞剑" if mode_name == "sword_flight" else "灵兽"))
		return
	traversal_mode = mode_name
	if mode_name == "sword_flight":
		ui.show_dialogue("御剑起行", ["你踏上飞剑，风声掠耳，山河在脚下后退。", "御剑时更耗灵，但赶路更快。"])
	else:
		ui.show_dialogue("灵兽同行", ["灵兽伏低身形让你骑上，步伐沉稳如鼓点。", "骑乘时更耐久，适合长线探索。"])

func cycle_spirit_attitude() -> void:
	var attitudes := ["善待", "交易", "驱逐"]
	var idx := attitudes.find(spirit_npc_attitude)
	idx = (idx + 1) % attitudes.size()
	spirit_npc_attitude = attitudes[idx]
	ui.push_message("你对妖鬼的处置倾向切换为：%s（按 O 可继续切换）。" % spirit_npc_attitude)

func get_spirit_attitude() -> String:
	return spirit_npc_attitude

func cycle_alignment() -> void:
	var alignments := ["好人", "中立", "坏人"]
	var idx := alignments.find(morality_alignment)
	idx = (idx + 1) % alignments.size()
	morality_alignment = alignments[idx]
	ui.push_message("你的江湖立场切换为：%s（按 P 切换）。" % morality_alignment)

func apply_morality(delta: int, source: String) -> void:
	morality_score = clamp(morality_score + delta, -100, 100)
	if morality_score >= 25:
		morality_alignment = "好人"
	elif morality_score <= -25:
		morality_alignment = "坏人"
	else:
		morality_alignment = "中立"
	feedback_layer.show_world_popup(player.global_position + Vector2(20, -30), "善恶 %+d" % delta, Color("ffd0a3"))
	ui.push_message("%s影响了你的名声：%s（善恶值 %d）。" % [source, morality_alignment, morality_score])

func get_morality_alignment() -> String:
	return morality_alignment

func knows_language(lang: String) -> bool:
	return bool(known_languages.get(lang, false))

func add_language_exp(lang: String, amount: int) -> void:
	var old_exp := int(language_exp.get(lang, 0))
	var new_exp := min(old_exp + amount, 100)
	language_exp[lang] = new_exp
	if new_exp >= 100 and not knows_language(lang):
		known_languages[lang] = true
		ui.show_dialogue("语言通晓", [
			"你终于听懂了%s。" % lang,
			"从现在起，你可以与对应国度的人流畅交流。"
		])
	elif new_exp > old_exp:
		ui.push_message("你对%s的理解提升到 %d/100。" % [lang, new_exp])

func choose_human_path(path_name: String) -> void:
	if human_path == path_name:
		return
	human_path = path_name
	match human_path:
		"学子":
			ui.show_dialogue("人间考学", ["你报考书院，开始走学子之路。", "读书明理，也能为修行开眼界。"])
			add_cultivation(5, player.global_position)
		"武夫":
			ui.show_dialogue("投身武途", ["你拜入武馆，走上武夫路子。", "拳脚虽粗，胜在直取要害。"])
			add_cultivation(8, player.global_position)
			restore_spirit(6.0)
		"小贩":
			ui.show_dialogue("开市行商", ["你在集市支起小摊，开始做小贩。", "讲价也是江湖功夫。"])
			add_spirit_stones(12)
		"医师":
			ui.show_dialogue("悬壶济世", ["你到药庐学起医理，准备行医济人。", "识草木、辨寒热，也是一条修行路。"])
			restore_spirit(10.0)
		"猎户":
			ui.show_dialogue("山野猎行", ["你背弓入山，做起猎户营生。", "看风辨迹，胆气与耐性缺一不可。"])
			add_cultivation(6, player.global_position)
		"匠人":
			ui.show_dialogue("百工入道", ["你走进作坊，学锻打与机关。", "器成于火，心成于磨。"])
			add_item("灵木", 1)
		_:
			pass

func try_human_career_action() -> void:
	if human_path == "未定":
		var options := ["学子", "武夫", "小贩", "医师", "猎户", "匠人"]
		var pick := options[randi() % options.size()]
		choose_human_path(pick)
		return
	match human_path:
		"学子":
			if cultivation >= 30 + exam_rank * 20:
				exam_rank += 1
				add_cultivation(10 + exam_rank * 2, player.global_position)
				apply_morality(2, "书院乡试")
				ui.push_message("你通过了第%d场科考，名望渐起。" % exam_rank)
			else:
				ui.push_message("学识火候未够，先多读书修身。")
		"武夫":
			add_cultivation(12, player.global_position)
			spirit = max(spirit - 4.0, 0.0)
			apply_morality(0, "武馆擂台")
			ui.push_message("你在擂台连战三场，筋骨更硬。")
		"小贩":
			var income := 6 + randi() % 10
			add_spirit_stones(income)
			apply_morality(1 if randf() < 0.5 else -1, "街市买卖")
			ui.push_message("你今天摆摊盈利 %d 灵石。" % income)
		"医师":
			restore_spirit(12.0)
			add_cultivation(7, player.global_position)
			apply_morality(3, "药庐义诊")
			ui.push_message("你在药庐义诊，救治了几名伤者。")
		"猎户":
			var loot := 1 + randi() % 2
			add_item("兽骨", loot)
			add_spirit_stones(4 + randi() % 6)
			add_cultivation(9, player.global_position)
			apply_morality(0, "山林狩猎")
			ui.push_message("你入山狩猎，带回兽骨 x%d。" % loot)
		"匠人":
			add_item("灵木", 1)
			add_item("灵石块", 1)
			add_cultivation(8, player.global_position)
			apply_morality(1, "作坊铸造")
			ui.push_message("你在作坊打磨器具，手艺更精了。")

func cycle_cultivation_focus() -> void:
	var paths := ["丹修", "符修", "体修", "法修"]
	var idx := paths.find(cultivation_focus)
	idx = (idx + 1) % paths.size()
	cultivation_focus = paths[idx]
	ui.push_message("当前主修切换为：%s（可兼修，按 J 修行）。" % cultivation_focus)

func _get_root_bonus_scale(path_name: String) -> float:
	if spiritual_root == "天灵根":
		return 1.18
	if spiritual_root == "杂灵根":
		return 0.92
	if spiritual_root == "火灵根" and path_name == "丹修":
		return 1.12
	if spiritual_root == "木灵根" and path_name == "丹修":
		return 1.08
	if spiritual_root == "雷灵根" and path_name == "法修":
		return 1.12
	if spiritual_root == "金灵根" and path_name == "体修":
		return 1.08
	if spiritual_root == "土灵根" and path_name == "体修":
		return 1.06
	if spiritual_root == "水灵根" and path_name == "符修":
		return 1.08
	if spiritual_root == "变异冰灵根" and (path_name == "符修" or path_name == "法修"):
		return 1.16
	if spiritual_root == "变异毒灵根" and path_name == "丹修":
		return 1.15
	if spiritual_root == "变异空灵根":
		return 1.14
	return 1.0

func cycle_martial_art() -> void:
	var arts := ["太极剑意", "降龙掌势", "独孤九剑", "黯然销魂掌", "凌波微步", "七伤拳"]
	var idx := arts.find(martial_art)
	idx = (idx + 1) % arts.size()
	martial_art = arts[idx]
	ui.push_message("武学切换为：%s。" % martial_art)

func cycle_immortal_art() -> void:
	var arts := ["青岚吐纳经", "太虚御雷诀", "玄冰真诀", "九转丹火经", "万象符箓录", "不灭金身法"]
	var idx := arts.find(immortal_art)
	idx = (idx + 1) % arts.size()
	immortal_art = arts[idx]
	ui.push_message("仙法切换为：%s。" % immortal_art)

func _get_martial_bonus() -> float:
	var bonus := 1.0
	if martial_art == "降龙掌势" and spiritual_root == "火灵根":
		bonus += 0.08
	if martial_art == "独孤九剑" and spiritual_root == "金灵根":
		bonus += 0.1
	if martial_art == "凌波微步" and (spiritual_root == "风灵根" or spiritual_root == "变异空灵根"):
		bonus += 0.1
	if martial_art == "七伤拳" and spiritual_root == "土灵根":
		bonus += 0.08
	return bonus

func _get_immortal_art_bonus(path_name: String) -> float:
	var bonus := 1.0
	if immortal_art == "太虚御雷诀" and path_name == "法修" and spiritual_root == "雷灵根":
		bonus += 0.12
	if immortal_art == "玄冰真诀" and path_name == "符修" and spiritual_root == "变异冰灵根":
		bonus += 0.14
	if immortal_art == "九转丹火经" and path_name == "丹修" and spiritual_root == "火灵根":
		bonus += 0.12
	if immortal_art == "万象符箓录" and path_name == "符修":
		bonus += 0.08
	if immortal_art == "不灭金身法" and path_name == "体修":
		bonus += 0.1
	return bonus

func practice_cultivation_path() -> void:
	var path_name := cultivation_focus
	var current := int(cultivation_paths.get(path_name, 0))
	var scale := _get_root_bonus_scale(path_name) * _get_martial_bonus() * _get_immortal_art_bonus(path_name)
	var gain := int(round((4 + current * 0.4) * scale))
	cultivation_paths[path_name] = current + gain
	match path_name:
		"丹修":
			restore_spirit(8.0)
			add_item("赤火芝", 1)
			add_cultivation(6 + gain, player.global_position)
		"符修":
			add_spirit_stones(6 + current / 6)
			add_cultivation(7 + gain, player.global_position)
		"体修":
			max_spirit = min(max_spirit + 1.0, 220.0)
			spirit = min(spirit + 4.0, max_spirit)
			add_cultivation(8 + gain, player.global_position)
		"法修":
			add_cultivation(11 + gain, player.global_position)
			spirit = max(spirit - 3.0, 0.0)
	ui.push_message("你进行了一次%s修行（武学：%s｜仙法：%s），分支造诣达到 %d。灵根：%s。" % [path_name, martial_art, immortal_art, cultivation_paths[path_name], spiritual_root])
	advance_minutes(45)

func apply_spirit_relation_delta(delta: int, speaker: String) -> void:
	spirit_npc_relation = clamp(spirit_npc_relation + delta, -100, 100)
	feedback_layer.show_world_popup(player.global_position + Vector2(0, -26), "妖鬼缘 %+d" % delta, Color("cba8ff"))
	ui.push_message("%s对你的态度发生变化，当前妖鬼缘：%d。" % [speaker, spirit_npc_relation])

func get_player_speed_multiplier() -> float:
	match traversal_mode:
		"sword_flight":
			return 1.65
		"spirit_mount":
			return 1.35
		_:
			return 1.0

func modify_move_input(input_vector: Vector2) -> Vector2:
	if drunk_timer <= 0.0:
		return input_vector
	var wobble_x := sin(total_minutes * 0.17) * drunk_strength
	var wobble_y := cos(total_minutes * 0.19) * drunk_strength
	var drifted := input_vector + Vector2(wobble_x, wobble_y)
	if drifted.length() > 1.0:
		drifted = drifted.normalized()
	return drifted


func _refresh_daily_tasks() -> void:
	if daily_task_day == day and not daily_tasks.is_empty():
		return
	daily_task_day = day
	daily_tasks = [
		{"id": "talk", "title": "拜访同门", "target": 2, "progress": 0, "claimed": false, "reward": {"stones": 10, "cultivation": 8}},
		{"id": "free", "title": "行脚江湖", "target": 2, "progress": 0, "claimed": false, "reward": {"stones": 6, "spirit": 8.0}},
		{"id": "meditate", "title": "静息吐纳", "target": 1, "progress": 0, "claimed": false, "reward": {"cultivation": 10}}
	]
	ui.push_message("【日常任务】已刷新：拜访同门 / 行脚江湖 / 静息吐纳。")

func _progress_daily_task(task_id: String, amount: int) -> void:
	for i in range(daily_tasks.size()):
		var task: Dictionary = daily_tasks[i]
		if task.get("id", "") != task_id:
			continue
		var target := int(task.get("target", 1))
		var progress := min(int(task.get("progress", 0)) + amount, target)
		var claimed := bool(task.get("claimed", false))
		task["progress"] = progress
		daily_tasks[i] = task
		ui.push_message("【日常任务】%s %d/%d" % [task.get("title", "任务"), progress, target])
		if progress >= target and not claimed:
			task["claimed"] = true
			daily_tasks[i] = task
			_claim_daily_task_reward(task)
		break

func _claim_daily_task_reward(task: Dictionary) -> void:
	var reward: Dictionary = task.get("reward", {})
	var stones := int(reward.get("stones", 0))
	var spirit_bonus := float(reward.get("spirit", 0.0))
	var cultivation_bonus := int(reward.get("cultivation", 0))
	if stones > 0:
		add_spirit_stones(stones)
	if spirit_bonus > 0.0:
		restore_spirit(spirit_bonus)
		feedback_layer.show_world_popup(player.global_position + Vector2(-10, -26), "+%d 灵力" % int(spirit_bonus), Color("9de8ff"))
	if cultivation_bonus > 0:
		add_cultivation(cultivation_bonus, player.global_position + Vector2(0, -18))
	ui.show_dialogue("日常任务完成", [
		"你完成了【%s】。" % task.get("title", "任务"),
		"今日的江湖仍在继续，去和更多人聊聊吧。"
	])

func _trigger_daily_event_pack() -> void:
	var routine_events := [
		{"title": "药圃除草", "desc": "你帮药庐清理杂草，顺便温习辨药。", "cultivation": 5, "stones": 0, "spirit": -2.0},
		{"title": "外门晨课", "desc": "晨课点名，你被拉去演示吐纳。", "cultivation": 4, "stones": 2, "spirit": -1.0},
		{"title": "山道巡查", "desc": "你与巡山弟子走了一圈，路上捡到散落灵石。", "cultivation": 3, "stones": 4, "spirit": -2.0},
		{"title": "灶房帮工", "desc": "灶房缺人，你劈柴半日，换来一顿热饭。", "cultivation": 2, "stones": 3, "spirit": 4.0}
	]
	var routine: Dictionary = routine_events[randi() % routine_events.size()]
	_apply_daily_event(routine, "日常")
	if randf() < 0.38:
		var incident_events := [
			{"title": "夜半失火", "desc": "仓房起火，你抢出一批种子却被浓烟呛伤。", "cultivation": 6, "stones": -4, "spirit": -12.0},
			{"title": "灵兽闯田", "desc": "灵鹿闯入田埂后又留下一枚奇异晶核。", "cultivation": 8, "stones": 10, "spirit": -3.0},
			{"title": "黑市来客", "desc": "神秘商人低价甩货，你赌了一把，赚到灵石。", "cultivation": 0, "stones": 14, "spirit": 0.0},
			{"title": "旧敌尾随", "desc": "山门外有人试探你底细，短暂交手后各退一步。", "cultivation": 10, "stones": 0, "spirit": -8.0}
		]
		var incident: Dictionary = incident_events[randi() % incident_events.size()]
		_apply_daily_event(incident, "突发")
	if randf() < 0.42:
		_trigger_random_character_event()
	if randf() < 0.45:
		_trigger_story_snippet()

func _trigger_story_snippet() -> void:
	var snippets := [
		"你在旧井旁听见童谣，词里藏着失传阵图的方位。",
		"茶棚说书人提到‘北岭白衣’，据说只在血月前后现身。",
		"外门弟子争论谁是叛徒，最后谁也不敢说出那个名字。",
		"山门石狮夜里落泪，执事说那是潮气，老人说那是预兆。",
		"你在摊贩残册里翻到一页：‘归墟不收无悔之人’。",
		"有散修在墙上留字：‘若见青灯三盏，切莫回头。’",
		"雨夜里有人唱古调，曲终时脚印只剩进山的一行。",
		"药庐老账里有一笔空白，日期恰是血月初现那年。",
		"断云崖下捡到半截玉佩，背面刻着陌生门徽。",
		"巡山弟子说，昨夜林中有兽影朝你洞府方向跪伏。"
	]
	unlocked_story_count += 1
	var line := snippets[randi() % snippets.size()]
	ui.show_dialogue("江湖小传·第%d则" % unlocked_story_count, [line, "你把这则见闻记在册中，或许日后能串起更大的真相。"])

func _trigger_random_character_event() -> void:
	var surnames := ["沈", "苏", "顾", "萧", "陆", "林", "白", "秦"]
	var names := ["行舟", "无咎", "听澜", "照影", "归尘", "怀玉", "千城", "逐月"]
	var roles := ["散修", "游商", "流亡剑客", "符师", "药师", "说书人"]
	var temp_name := "%s%s" % [surnames[randi() % surnames.size()], names[randi() % names.size()]]
	var role := roles[randi() % roles.size()]
	var flavor := [
		"留下一句忠告后匆匆离去。",
		"与你交换了一段江湖传闻。",
		"看了看你的气机，点头不语。",
		"在茶棚坐了半刻，便消失在人群里。"
	]
	var reward_roll := randi() % 3
	if reward_roll == 0:
		add_spirit_stones(6 + randi() % 8)
	elif reward_roll == 1:
		add_cultivation(5 + randi() % 6, player.global_position + Vector2(0, -16))
	else:
		restore_spirit(8.0)
	ui.show_dialogue("偶遇角色", [
		"你遇见了%s（%s），%s" % [temp_name, role, flavor[randi() % flavor.size()]],
		"这种人不会长期停留，但每次出现都可能改写你当天的节奏。"
	])

func _apply_daily_event(event_data: Dictionary, event_type: String) -> void:
	var spirit_delta := float(event_data.get("spirit", 0.0))
	var stones_delta := int(event_data.get("stones", 0))
	var cultivation_delta := int(event_data.get("cultivation", 0))
	spirit = clamp(spirit + spirit_delta, 0.0, max_spirit)
	spirit_stones = max(spirit_stones + stones_delta, 0)
	if cultivation_delta != 0:
		add_cultivation(cultivation_delta, player.global_position + Vector2(0, -18))
	ui.push_message("【%s】%s：%s" % [event_type, event_data.get("title", "无名事件"), event_data.get("desc", "")])
	if stones_delta != 0:
		feedback_layer.show_world_popup(player.global_position + Vector2(24, -24), "%+d 灵石" % stones_delta, Color("ffe394"))
	if spirit_delta != 0.0:
		feedback_layer.show_world_popup(player.global_position + Vector2(-20, -22), "%+d 灵力" % int(spirit_delta), Color("9de8ff"))

func _advance_long_arc_by_day() -> void:
	if joined_faction == "无门无派":
		return
	if main_quest_stage == 4 and day >= 8:
		main_quest_stage = 5
		ui.show_dialogue("驿站密信", [
			"边地传来消息：多处灵田被夜袭，疑似有人试阵。",
			"你若继续追下去，就没有回头路了。"
		])
	elif main_quest_stage == 5 and day >= 14:
		main_quest_stage = 6
		ui.show_dialogue("门中长议", [
			"各派都想把你拉到自己那一边，因为你看过太多真相。",
			"从这一刻起，你做的每件事都会被记账。"
		])
	elif main_quest_stage == 6 and day >= 21 and realm_index >= 1:
		main_quest_stage = 7
		ui.show_dialogue("夜半来客", [
			"来人只留下一句话：归墟门开前，先决定你要救谁。",
			"你终于明白，这不是修炼题，而是生死题。"
		])
	elif main_quest_stage == 7 and day >= 28:
		main_quest_stage = 8
		ui.show_dialogue("章节结语", [
			"第一卷至此收束，诸派棋盘已布成。",
			"下一卷，你将亲自落子。"
		])

func _update_story_phase_by_day() -> void:
	if joined_faction == "无门无派":
		return
	var target_phase := mini(40, 1 + int(day / 2))
	while story_phase < target_phase:
		story_phase += 1
		var beat := _build_story_phase_lines(story_phase)
		ui.show_dialogue(beat.get("speaker", "江湖风闻"), beat.get("lines", []))

func _build_story_phase_lines(phase: int) -> Dictionary:
	var tag := "第%d幕" % phase
	var tone := "风声更紧，盟友与敌人的边界继续模糊。"
	if phase % 5 == 0:
		tone = "旧账被翻出，新的代价也被摆上桌面。"
	elif phase % 7 == 0:
		tone = "有人失踪，有人倒戈，你的名字开始出现在密卷里。"
	elif phase % 9 == 0:
		tone = "边境起火，宗门议事彻夜未停。"
	var route_hint := "你在%s线上的每次表态，都在改变后续局势。" % story_route
	return {
		"speaker": "幕间纪要",
		"lines": ["【%s】%s" % [tag, tone], route_hint]
	}

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
	_progress_daily_task("meditate", 1)

func advance_minutes(minutes: int) -> void:
	total_minutes += minutes

func add_item(item_name: String, amount: int) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + amount
	ui.queue_redraw()
	_update_main_quest("item_added")

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
	var realm_damp := 1.0 / (1.0 + float(realm_index) * 0.55)
	var daily_damp := 1.0 if get_hour_of_day() < 18 else 0.82
	var adjusted := max(int(round(float(amount) * realm_damp * daily_damp)), 1)
	cultivation += adjusted
	feedback_layer.show_world_popup(source_position, "+%d 修为" % adjusted, Color("c7b3ff"))

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
		_progress_daily_task("talk", 1)
	else:
		pass

func do_free_action() -> void:
	var acts := [
		{"name": "读旧书", "cultivation": 6, "spirit": -2.0, "stones": 0, "desc": "你翻阅旧书，悟到一段行气细节。"},
		{"name": "河边垂钓", "cultivation": 2, "spirit": -1.0, "stones": 5, "desc": "你在河边发呆垂钓，顺手卖了几尾灵鱼。"},
		{"name": "街市闲逛", "cultivation": 0, "spirit": 2.0, "stones": -3, "desc": "你逛了集市，花了点灵石换心情。"},
		{"name": "独自练剑", "cultivation": 10, "spirit": -6.0, "stones": 0, "desc": "你在空地练剑，汗流浃背却更沉稳。"},
		{"name": "帮人跑腿", "cultivation": 3, "spirit": -2.0, "stones": 8, "desc": "你替人送信跑腿，赚到点碎灵石。"}
	]
	var act: Dictionary = acts[randi() % acts.size()]
	var spirit_delta := float(act.get("spirit", 0.0))
	var stone_delta := int(act.get("stones", 0))
	var cult_delta := int(act.get("cultivation", 0))
	spirit = clamp(spirit + spirit_delta, 0.0, max_spirit)
	spirit_stones = max(spirit_stones + stone_delta, 0)
	if cult_delta > 0:
		add_cultivation(cult_delta, player.global_position)
	advance_minutes(20 + randi() % 40)
	ui.push_message("【自由行动】%s：%s" % [act.get("name", "随性而为"), act.get("desc", "")])
	_progress_daily_task("free", 1)

func attempt_breakthrough() -> void:
	if realm_index >= REALMS.size() - 1:
		ui.push_message("你已达到当前原型的最高境界。")
		return
	if spirit < max_spirit:
		ui.push_message("突破前需要灵力圆满。")
		return
	var required_cultivation := get_breakthrough_cultivation_req()
	if cultivation < required_cultivation:
		ui.push_message("修为火候不足（%d / %d），强行突破只会走火入魔。" % [cultivation, required_cultivation])
		return
	var cost := get_breakthrough_cost()
	if spirit_stones < cost:
		ui.push_message("灵石不足，无法布置突破法阵。")
		return
	spirit_stones -= cost
	advance_minutes(180)
	var extra_cultivation := max(cultivation - required_cultivation, 0)
	var success_rate := 0.32 + min(float(extra_cultivation) / 420.0, 0.26)
	if current_weather == "血月":
		success_rate -= 0.18
	elif current_weather == "灵雨":
		success_rate += 0.05
	if spirit_stones >= cost * 2:
		success_rate += 0.05
	success_rate = clamp(success_rate, 0.12, 0.78)
	var success := randf() < success_rate
	environment_fx.trigger_breakthrough(player.global_position, success)
	if success:
		realm_index += 1
		cultivation = 0
		max_spirit += 25.0
		spirit = max_spirit
		feedback_layer.show_world_popup(player.global_position, "%s成" % get_realm_name(), Color("ffd77a"), 1.4)
		ui.push_message("你成功突破至%s，气海大开。" % get_realm_name())
		_update_main_quest("breakthrough")
	else:
		spirit = max(spirit - 42.0, 8.0)
		cultivation = max(cultivation - 18, 0)
		spirit_stones = max(spirit_stones - int(cost * 0.2), 0)
		feedback_layer.show_world_popup(player.global_position, "突破受阻", Color("ff8d8d"), 1.2)
		ui.push_message("突破失败，气息逆冲，修为与灵石皆有损耗。")

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
		"legend_intro_seen": legend_intro_seen,
		"main_quest_stage": main_quest_stage,
		"life_origin": life_origin,
		"life_traits": life_traits,
		"story_route": story_route,
		"joined_faction": joined_faction,
		"story_phase": story_phase,
		"side_story_stage": side_story_stage,
		"spirit_pearls": spirit_pearls,
		"reincarnation_count": reincarnation_count,
		"unlocked_story_count": unlocked_story_count,
		"daily_tasks": daily_tasks,
		"daily_task_day": daily_task_day,
		"traversal_mode": traversal_mode,
		"spirit_npc_attitude": spirit_npc_attitude,
		"spirit_npc_relation": spirit_npc_relation,
		"morality_alignment": morality_alignment,
		"morality_score": morality_score,
		"known_languages": known_languages,
		"language_exp": language_exp,
		"human_path": human_path,
		"exam_rank": exam_rank,
		"spiritual_root": spiritual_root,
		"cultivation_focus": cultivation_focus,
		"cultivation_paths": cultivation_paths,
		"martial_art": martial_art,
		"immortal_art": immortal_art,
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
	legend_intro_seen = bool(parsed.get("legend_intro_seen", legend_intro_seen))
	main_quest_stage = int(parsed.get("main_quest_stage", main_quest_stage))
	life_origin = str(parsed.get("life_origin", life_origin))
	life_traits = parsed.get("life_traits", life_traits)
	story_route = str(parsed.get("story_route", story_route))
	joined_faction = str(parsed.get("joined_faction", joined_faction))
	story_phase = int(parsed.get("story_phase", story_phase))
	side_story_stage = int(parsed.get("side_story_stage", side_story_stage))
	spirit_pearls = parsed.get("spirit_pearls", spirit_pearls)
	reincarnation_count = int(parsed.get("reincarnation_count", reincarnation_count))
	unlocked_story_count = int(parsed.get("unlocked_story_count", unlocked_story_count))
	daily_tasks = parsed.get("daily_tasks", daily_tasks)
	daily_task_day = int(parsed.get("daily_task_day", daily_task_day))
	traversal_mode = str(parsed.get("traversal_mode", traversal_mode))
	spirit_npc_attitude = str(parsed.get("spirit_npc_attitude", spirit_npc_attitude))
	spirit_npc_relation = int(parsed.get("spirit_npc_relation", spirit_npc_relation))
	morality_alignment = str(parsed.get("morality_alignment", morality_alignment))
	morality_score = int(parsed.get("morality_score", morality_score))
	known_languages = parsed.get("known_languages", known_languages)
	language_exp = parsed.get("language_exp", language_exp)
	human_path = str(parsed.get("human_path", human_path))
	exam_rank = int(parsed.get("exam_rank", exam_rank))
	spiritual_root = str(parsed.get("spiritual_root", spiritual_root))
	cultivation_focus = str(parsed.get("cultivation_focus", cultivation_focus))
	cultivation_paths = parsed.get("cultivation_paths", cultivation_paths)
	martial_art = str(parsed.get("martial_art", martial_art))
	immortal_art = str(parsed.get("immortal_art", immortal_art))
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
