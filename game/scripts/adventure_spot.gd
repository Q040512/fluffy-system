extends Node2D

@export var spot_name := "听雨潭"
@export var mode := "spring" # spring / arena / ruins / cliff / secret_realm / logging / digging / carving / underground / divine_bones

var available := true
var last_day := -1
var anim_time := 0.0
var _redraw_accum := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("daily_reset")

func _process(delta: float) -> void:
	anim_time += delta
	_redraw_accum += delta
	if _redraw_accum >= 0.05:
		_redraw_accum = 0.0
		queue_redraw()

func interact(game) -> void:
	if last_day == game.day and not available:
		game.ui.push_message("%s今日机缘已尽。" % spot_name)
		return
	match mode:
		"spring":
			if not game.spend_spirit(1.0):
				return
			game.restore_spirit(18.0)
			game.add_cultivation(6, global_position)
			game.ui.push_message("你在%s吐纳灵息，灵力大幅恢复。" % spot_name)
			game.feedback_layer.show_world_popup(global_position, "灵息回涌", Color("9de8ff"))
		"arena":
			if not game.spend_spirit(5.0):
				return
			game.add_cultivation(14, global_position)
			game.add_spirit_stones(10)
			game.ui.push_message("你在%s与各派弟子切磋，心法更加稳固。" % spot_name)
			game.feedback_layer.show_world_popup(global_position, "切磋精进", Color("ffd77a"))
			game.notify_tutorial_event("arena_trial")
		"ruins":
			if not game.spend_spirit(3.0):
				return
			game.add_item("赤火芝", 1)
			game.add_spirit_stones(6)
			game.ui.push_message("你在%s寻得一株赤火芝。" % spot_name)
			game.feedback_layer.fly_item_to_panel(global_position, "赤火芝", Color("ff9b7a"))
			if randf() < 0.18:
				game.collect_spirit_pearl("土灵珠", spot_name)
			if randf() < 0.22:
				_trigger_cave_fortune(game)
		"cliff":
			if not game.spend_spirit(2.0):
				return
			if randf() < 0.35:
				_trigger_cave_fortune(game)
				if randf() < 0.3:
					game.collect_spirit_pearl("风灵珠", spot_name)
			else:
				game.add_cultivation(8, global_position)
				game.ui.push_message("你在峭壁失足却稳住身形，心境更沉。")
				game.feedback_layer.show_world_popup(global_position, "险境悟道", Color("b7d9ff"))
		"secret_realm":
			if not game.spend_spirit(6.0):
				return
			_trigger_secret_realm(game)
		"logging":
			if not game.spend_spirit(3.0):
				return
			game.add_item("灵木", 1 + randi() % 2)
			game.add_cultivation(6, global_position)
			game.ui.push_message("你砍下一段灵木，可用于建房。")
			_trigger_region_beast(game, "林地")
		"digging":
			if not game.spend_spirit(4.0):
				return
			game.add_item("灵石块", 1 + randi() % 2)
			game.add_cultivation(7, global_position)
			game.ui.push_message("你向下挖出一截洞道，洞府雏形渐成。")
			_trigger_region_beast(game, "地脉")
		"carving":
			if not game.spend_spirit(2.0):
				return
			game.add_cultivation(5, global_position)
			game.ui.show_dialogue("石刻留名", [
				"你在石壁刻下今日所悟，字迹粗粝却有锋芒。",
				"若干年后，也许会有人在这里读到你的名字。"
			])
		"underground":
			if not game.spend_spirit(5.0):
				return
			game.restore_spirit(10.0)
			game.add_cultivation(8, global_position)
			game.ui.push_message("你在地下洞窟暂居一夜，心神更稳。")
			_trigger_region_beast(game, "幽穴")
		"divine_bones":
			if not game.spend_spirit(7.0):
				return
			game.add_cultivation(16, global_position)
			game.add_spirit_stones(20)
			game.ui.show_dialogue("神兽骸骨", [
				"你在古坑中发现一截神兽骸骨，骨纹仍有灵辉流转。",
				"仅是凝视片刻，你的经脉便像被远古雷鸣震过一遍。"
			])
			if randf() < 0.45:
				game.add_item("神骨碎片", 1)
				game.feedback_layer.fly_item_to_panel(global_position, "神骨碎片", Color("ffe6a3"))
			_trigger_region_beast(game, "古坑")
	available = false
	last_day = game.day
	game.advance_minutes(30)

func on_day_started(_day: int) -> void:
	available = true

func _trigger_cave_fortune(game) -> void:
	game.add_spirit_stones(18)
	game.add_item("赤火芝", 1)
	game.add_cultivation(16, global_position)
	game.ui.show_dialogue("山洞奇遇", [
		"你坠入山壁暗缝，竟在洞中见到残缺剑碑与古修坐化遗蜕。",
		"你拾得一株赤火芝与一袋灵石，且从碑纹中悟到一缕行气诀窍。"
	])
	game.feedback_layer.show_world_popup(global_position, "山洞机缘", Color("9dd6ff"), 1.2)

func _trigger_secret_realm(game) -> void:
	var success := randf() < 0.48
	if success:
		game.add_spirit_stones(30)
		game.add_item("赤火芝", 2)
		game.add_cultivation(24, global_position)
		game.ui.show_dialogue("秘境回响", [
			"你踏入裂隙秘境，穿过镜湖幻阵，最终在石殿中取得灵材。",
			"虽仅片刻，却足抵外界数日苦修。"
		])
		game.feedback_layer.show_world_popup(global_position, "秘境得宝", Color("cdb7ff"), 1.3)
		var pool := ["雷灵珠", "水灵珠", "火灵珠"]
		game.collect_spirit_pearl(pool[randi() % pool.size()], spot_name)
	else:
		game.spirit = max(game.spirit - 12.0, 0.0)
		game.add_cultivation(10, global_position)
		game.ui.show_dialogue("秘境反噬", [
			"秘境灵压骤变，你被迫撤出，灵息受创。",
			"但险死还生之间，你也抓住了一丝突破感悟。"
		])
		game.feedback_layer.show_world_popup(global_position, "负伤脱离", Color("ff9fa6"), 1.2)

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(anim_time * 2.2)
	var ring := 0.5 + 0.5 * sin(anim_time * 3.6)
	var base := Color("4f6678")
	if mode == "arena":
		base = Color("7a5f4f")
	elif mode == "ruins":
		base = Color("5d4f69")
	elif mode == "cliff":
		base = Color("51657a")
	elif mode == "secret_realm":
		base = Color("6b4f85")
	elif mode == "logging":
		base = Color("6f5a3d")
	elif mode == "digging":
		base = Color("5b4f3f")
	elif mode == "carving":
		base = Color("66606c")
	elif mode == "underground":
		base = Color("3f4b5f")
	elif mode == "divine_bones":
		base = Color("6c6050")
	draw_circle(Vector2.ZERO, 16.0, base)
	draw_circle(Vector2.ZERO, 8.0 + pulse * 2.0, Color(0.8, 0.95, 1.0, 0.35 if available else 0.12))
	draw_arc(Vector2.ZERO, 20.0 + ring * 2.0, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 0.28 if available else 0.1), 1.5)
	if mode == "secret_realm" or mode == "divine_bones":
		draw_circle(Vector2(0, -2), 4.0 + pulse, Color(0.95, 0.82, 1.0, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(-36, -22), spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8f1ff"))

func _trigger_region_beast(game, region: String) -> void:
	if randf() > 0.35:
		return
	var beast_pool := {
		"林地": ["青背狼妖", "赤尾灵狐"],
		"地脉": ["岩甲蜥兽", "伏地石魈"],
		"幽穴": ["玄蝠妖", "地听灵鼬", "幽灯骨蛛"],
		"古坑": ["夔纹残魄", "烛龙遗蜕", "玄麒断角灵"]
	}
	var candidates: Array = beast_pool.get(region, ["游荡小妖"])
	var beast := candidates[randi() % candidates.size()]
	game.add_cultivation(6, global_position)
	game.ui.show_dialogue("遭遇灵兽", [
		"你在%s遇见%s，一番周旋后成功脱身。" % [region, beast],
		"不同地域孕育不同妖兽灵兽，越深处越危险。"
	])
