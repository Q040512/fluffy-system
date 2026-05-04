extends Node2D

@export var npc_name := "青岚师姐"
@export var title := "内门"
@export var faction := "青岚宗"
@export var archetype := "mentor"
@export var personality := "严谨"
@export var hobby := "种药"
@export var profession := "修士"
@export var nation := "中州"
@export var required_language := "中州雅言"
@export var morning_offset := Vector2(-10, -6)
@export var noon_offset := Vector2(12, 0)
@export var night_offset := Vector2(-6, 10)

var favor := 0
var last_talk_day := -1
var anim_time := 0.0
var _home_position := Vector2.ZERO
var _tragic_revealed := false
var _routine_points: Array[Vector2] = []
var _routine_index := 0
var _facing := Vector2.DOWN
var _last_routine_hour := -1
var _redraw_accum := 0.0
var _step_phase := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc_state")
	if archetype == "ghost" and required_language == "中州雅言":
		required_language = "冥语"
	if archetype == "monster" and required_language == "中州雅言":
		required_language = "兽灵语"
	_home_position = position
	_routine_points = [
		_home_position + Vector2(0, 0),
		_home_position + Vector2(0, -28),
		_home_position + Vector2(24, -28),
		_home_position + Vector2(24, 0),
		_home_position + Vector2(24, 28),
		_home_position + Vector2(0, 28),
		_home_position + Vector2(-24, 28),
		_home_position + Vector2(-24, 0),
		_home_position + Vector2(-24, -28)
	]

func _process(delta: float) -> void:
	anim_time += delta
	_update_routine(delta)
	_redraw_accum += delta
	if _redraw_accum >= 0.05:
		_redraw_accum = 0.0
		queue_redraw()

func interact(game) -> void:
	if required_language != "" and not game.knows_language(required_language):
		_handle_language_barrier(game)
		return
	if archetype == "ghost" or archetype == "monster":
		_interact_spirit_npc(game)
		return
	if game.day != last_talk_day:
		last_talk_day = game.day
		favor += 1
		var gift := _daily_gift()
		if gift.size() > 0:
			game.add_item(gift.get("item", "青灵草籽"), int(gift.get("amount", 1)))
		game.notify_tutorial_event("met_npc")
		game.feedback_layer.show_world_popup(global_position, "好感 +1", Color("ffbfd5"))
		game.ui.push_message("%s赠你%s x%d。好感 +1。" % [npc_name, gift.get("item", "青灵草籽"), int(gift.get("amount", 1))])
		game.ui.show_dialogue(npc_name, _daily_lines(game) + _personality_lines(game) + _bond_story_lines() + _villain_tragic_lines(game))
		game.apply_morality(2, "%s的感谢" % npc_name)
		if favor >= 1 and faction != "" and game.joined_faction == "无门无派":
			game.offer_join_faction(faction, npc_name)
		return

	if game.inventory.get("青灵草", 0) > 0:
		game.remove_item("青灵草", 1)
		favor += 2
		game.add_spirit_stones(8 + mini(favor, 10))
		game.add_cultivation(8 + mini(favor, 12), global_position)
		game.feedback_layer.show_world_popup(global_position, "论道 +2", Color("ffbfd5"))
		game.ui.push_message("%s与你切磋心法，点拨了你的行气节奏。" % npc_name)
		game.ui.show_dialogue(npc_name, _exchange_lines() + _personality_lines(game) + _bond_story_lines() + _villain_tragic_lines(game))
		game.apply_morality(1, "%s的论道" % npc_name)
		if hobby == "酿酒" and randf() < 0.45:
			game.apply_drunkenness(45.0, 0.22)
			game.ui.push_message("%s递来一碗烈酒，你豪饮后有些踉跄。" % npc_name)
		if favor >= 3 and faction != "" and game.joined_faction == "无门无派":
			game.offer_join_faction(faction, npc_name)
		return

	game.ui.show_dialogue(npc_name, _hint_lines(game) + _personality_lines(game) + _bond_story_lines() + _villain_tragic_lines(game))

func _handle_language_barrier(game) -> void:
	game.add_language_exp(required_language, 18)
	var broken_lines := [
		"%s用%s说了一长串，你只听懂了零星词汇。" % [npc_name, required_language],
		"你猜到对方并非敌意，但交流仍像隔着雾墙。"
	]
	if archetype == "faction_guest":
		broken_lines.append("你决定先学语言，再谈结盟与交易。")
	game.ui.show_dialogue("%s（%s）" % [npc_name, nation], broken_lines)

func _interact_spirit_npc(game) -> void:
	var attitude := game.get_spirit_attitude()
	var alignment := game.get_morality_alignment()
	if alignment == "好人":
		game.ui.push_message("%s看你眼神柔和了几分。"% npc_name)
	elif alignment == "坏人":
		game.ui.push_message("%s对你保持明显戒备。"% npc_name)
	match attitude:
		"善待":
			favor += 1
			game.add_cultivation(6, global_position)
			game.restore_spirit(6.0)
			game.apply_spirit_relation_delta(+6, npc_name)
			game.apply_morality(4, "善待妖鬼")
			game.ui.show_dialogue(npc_name, [
				"你放低兵刃，与我平声说话……这在修士里很少见。",
				"我记你一份善意，今夜林路若起雾，我会替你引路。"
			])
		"交易":
			if game.spirit_stones >= 6:
				game.spirit_stones -= 6
				game.add_item("赤火芝", 1)
				game.add_cultivation(4, global_position)
				game.apply_spirit_relation_delta(+2, npc_name)
				game.apply_morality(0, "与妖鬼交易")
				game.ui.show_dialogue(npc_name, [
					"你用灵石换走了我藏着的药材，账算得清楚。",
					"下次再来，带点更有意思的东西。"
				])
			else:
				game.ui.push_message("灵石不够，妖鬼摊主只是冷笑。")
		"驱逐":
			favor = max(favor - 1, 0)
			game.spend_spirit(4.0)
			game.add_cultivation(3, global_position)
			game.apply_spirit_relation_delta(-8, npc_name)
			game.apply_morality(-6, "驱逐妖鬼")
			game.ui.show_dialogue(npc_name, [
				"你以剑势逼退了我。今晚你赢了，但山里会记住你的味道。",
				"若再相逢，我们未必还能这样说话。"
			])

func _update_routine(delta: float) -> void:
	var game = get_parent()
	if game == null:
		return
	var hour := game.get_hour_of_day()
	if hour != _last_routine_hour:
		_last_routine_hour = hour
		if hour % 3 == 0:
			_routine_index = (_routine_index + 1) % _routine_points.size()
	var target := _routine_points[_routine_index]
	# 不同时段整体偏移，保留“日程感”
	if hour >= 6 and hour < 11:
		target += morning_offset
	elif hour >= 11 and hour < 18:
		target += noon_offset
	else:
		target += night_offset
	var delta_vec := target - position
	if delta_vec.length() > 1.0:
		_facing = _cardinalize(delta_vec.normalized())
		_step_phase += delta * 8.0
	position = position.move_toward(target, 28.0 * delta)

func _cardinalize(v: Vector2) -> Vector2:
	if abs(v.x) > abs(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP

func _daily_gift() -> Dictionary:
	if profession == "仙人":
		return {"item": "神骨碎片", "amount": 1}
	if profession == "医师":
		return {"item": "赤火芝", "amount": 1}
	if profession == "猎户":
		return {"item": "兽骨", "amount": 1}
	if profession == "匠人":
		return {"item": "灵木", "amount": 1}
	if profession == "小贩":
		return {"item": "青灵草籽", "amount": 2}
	match archetype:
		"junior":
			return {"item": "青灵草籽", "amount": 1}
		"elder":
			return {"item": "赤火芝籽", "amount": 1}
		"demon_lord":
			return {"item": "赤火芝", "amount": 1}
		"immortal":
			return {"item": "赤火芝", "amount": 2}
		"ghost":
			return {"item": "幽磷粉", "amount": 1}
		"monster":
			return {"item": "兽骨", "amount": 1}
		_:
			return {"item": "青灵草籽", "amount": 1}

func _daily_lines(game) -> Array[String]:
	if profession == "医师":
		return ["我在药庐值夜，见过太多硬撑到倒下的人。", "先保命，再谈破境。今天%s，脉象要稳。" % game.current_weather]
	if profession == "猎户":
		return ["山风一变，兽踪就乱。你走山路时记得看风口。", "这副兽骨你收着，做柄短刀也好。"]
	if profession == "匠人":
		return ["铁要百炼，心也要百炼。", "你若有灵石块，改日我给你打个顺手家伙。"]
	if profession == "小贩":
		return ["今天集市价高，手快有手慢无。", "行商靠眼力，也靠口风。你多听少说。"]
	if profession == "仙人":
		return ["我自云外来，见你命火未熄，便停一步与你说话。", "莫急着追快，天地大道从不与人赛跑。"]
	match archetype:
		"mentor":
			return ["今日%s，先稳住灵息，再谈境界。" % game.current_weather, "田里有收成就别空着，修行也讲积累。"]
		"junior":
			return ["师兄/师姐，我把种子给你留好了！", "等你收成了，也教我两招吧。"]
		"elder":
			return ["心急是大忌。先把根基打牢，三月后再谈突破。", "外门弟子都在看你，莫要松懈。"]
		"uncle_master":
			return ["江湖路远，宗门只是起点。", "行走诸派，先学会听风辨势。"]
		"demon_lord":
			return ["正邪不过立场，能护住自己道心才算本事。", "他们叫我魔尊，只因我替死人说过话。"]
		"immortal":
			return ["凡尘百态，我都见过。你要守住本心，才有资格谈飞升。", "若有一日你登天门，别忘了曾经的泥路。"]
		"ghost":
			return ["我从雾里来，也会从雾里走。你若愿听，我就讲一段旧城往事。", "别急着拔剑，很多鬼只是放不下。"]
		"monster":
			return ["我识得你的气息，修士。你想狩我，还是与我交易？", "山里规矩很简单：谁守约，谁就能活得久。"]
		"faction_guest":
			return ["我是%s来使，奉命观摩青岚宗新弟子。" % faction, "礼尚往来，这份薄礼收下。"]
		_:
			return ["今日勤修，来日自有回响。"]

func _exchange_lines() -> Array[String]:
	return [
		"你以灵草换心得，这笔买卖不亏。",
		"招式可以借，心法要自己悟。",
		"今日我讲三句：守气、守心、守口。",
		"你若下次还来，我再给你一段更狠的实战心得。"
	]

func _hint_lines(game) -> Array[String]:
	var lines := ["先去种点青灵草再来，我再与你细讲。", "当前天象是%s，顺势而修更省力。" % game.current_weather]
	var hour := game.get_hour_of_day()
	if hour < 10:
		lines.append("晨气最净，适合先练基础吐纳。")
	elif hour < 18:
		lines.append("午后人多耳杂，说话留三分。")
	else:
		lines.append("夜里风声重，若要远行先备好灵石。")
	if favor >= 5:
		lines.append("你我已熟，我直说：别把所有秘密都告诉同一个人。")
	return lines

func _personality_lines(game) -> Array[String]:
	var lines: Array[String] = []
	match personality:
		"豪迈":
			lines.append("我这人直来直去，不服就去演武坪走两招。")
		"寡言":
			lines.append("……少说，多做。")
		"狡黠":
			lines.append("江湖话只听一半，另一半藏在价码里。")
		_:
			lines.append("修行要稳，今日风向是%s，别逆势硬来。" % game.current_weather)
	lines.append("我平日爱%s。要是你也懂这个，我们更聊得来。" % hobby)
	return lines


func _bond_story_lines() -> Array[String]:
	if favor >= 9:
		return ["你沉默了很久，终于把最不愿提起的旧伤讲给我听。", "从今往后，若你要走险路，我会替你留一盏灯。"]
	if favor >= 6:
		return ["你我之间已不只是交易，算是能托付后背的人了。", "下次若你夜行未归，我会亲自去山口接应。"]
	if favor >= 3:
		return ["最近你常来，我都记得。", "江湖人嘴硬，但心里会把重要的人排在前面。"]
	return []

func _villain_tragic_lines(game) -> Array[String]:
	if archetype != "demon_lord":
		return []
	var lines: Array[String] = []
	if not _tragic_revealed and favor >= 2:
		_tragic_revealed = true
		lines.append("你想听真相？三十年前，我本是青岚外门弟子。")
		lines.append("血月夜里，师门拿我族人祭阵，我活下来，就成了他们口中的魔。")
	elif _tragic_revealed:
		if game.current_weather == "血月":
			lines.append("每逢血月，我都记得那夜的火光和哭声。")
		else:
			lines.append("我不求洗白，只求后来者别再拿无辜之人填阵。")
	return lines

func _draw() -> void:
	var walk_bob := sin(_step_phase) * 2.4
	var breathe_bob := sin(anim_time * 1.8) * 1.2
	var bob := walk_bob + breathe_bob
	var aura := 0.12 + 0.03 * sin(anim_time * 2.6)
	var game = get_parent()
	var robe_color := _get_robe_color(game)
	var trim_color := _get_trim_color(game)
	draw_circle(Vector2(0, 24), 13.0, Color(0.75, 0.65, 1.0, aura))
	draw_circle(Vector2(0, -12 + bob), 10, Color("ead8c0"))
	draw_rect(Rect2(Vector2(-10, -2 + bob), Vector2(20, 28)), robe_color)
	draw_line(Vector2(-9, 3 + bob), Vector2(9, 3 + bob), trim_color, 2.0)
	draw_line(Vector2(-6, 17 + bob), Vector2(6, 17 + bob), trim_color.darkened(0.1), 1.8)
	draw_line(Vector2(-7, 24 + walk_bob), Vector2(-7, 30 - walk_bob), Color("dbc8b1"), 1.2)
	draw_line(Vector2(7, 24 - walk_bob), Vector2(7, 30 + walk_bob), Color("dbc8b1"), 1.2)
	draw_line(Vector2(0, 10 + bob), Vector2(0, 10 + bob) + _facing * 8.0, Color("e7f4ff"), 1.6)
	draw_line(Vector2(-12, 14 + bob), Vector2(12, 14 + bob), Color("e8dcff"), 1.5)
	if game != null:
		_draw_season_accessory(game, bob)
	_draw_role_marker(bob)
	if favor > 0:
		draw_circle(Vector2(0, -34 + sin(anim_time * 3.4) * 2.0), 4.0, Color(1.0, 0.78, 0.88, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-40, -36), "%s·%s" % [faction, title], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9e8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -20), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2f7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(-26, -8), profession, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe9be"))

func _get_robe_color(game) -> Color:
	var base: Color
	match personality:
		"豪迈":
			base = Color("b07a55")
		"寡言":
			base = Color("6e7a8f")
		"狡黠":
			base = Color("7f6aa8")
		_:
			base = Color("7ea07f") if archetype == "mentor" else Color("a592d7")
	if game == null:
		return base
	match int(game.season_index):
		0: # 春
			return base.lightened(0.06)
		1: # 夏
			return base.lightened(0.15)
		2: # 秋
			return base.darkened(0.04)
		_: # 冬
			return base.darkened(0.13)

func _get_trim_color(game) -> Color:
	if game == null:
		return Color("f0e8dc")
	match int(game.season_index):
		0:
			return Color("e7f7cf")
		1:
			return Color("d4f4ff")
		2:
			return Color("f6dfb0")
		_:
			return Color("dce4ff")

func _draw_season_accessory(game, bob: float) -> void:
	match int(game.season_index):
		0: # 春：草叶簪
			draw_line(Vector2(8, -16 + bob), Vector2(12, -22 + bob), Color("b5e08f"), 1.8)
		1: # 夏：轻薄披肩
			draw_arc(Vector2(0, 8 + bob), 13.0, PI * 0.12, PI * 0.88, 20, Color(0.835, 0.969, 1.0, 0.5), 1.6)
		2: # 秋：束带
			draw_line(Vector2(-10, 12 + bob), Vector2(10, 12 + bob), Color("d9a86a"), 2.2)
		_: # 冬：围巾
			draw_line(Vector2(-8, -1 + bob), Vector2(8, -1 + bob), Color("c7d4f7"), 2.6)

func _draw_role_marker(bob: float) -> void:
	match archetype:
		"mentor", "elder":
			draw_circle(Vector2(0, -30 + bob), 3.5, Color("ffd77a"))
		"immortal":
			draw_arc(Vector2(0, -28 + bob), 7.0, 0.0, TAU, 24, Color("ffe6a6"), 1.7)
			draw_circle(Vector2(0, -28 + bob), 2.4, Color("fff3c4"))
		"demon_lord":
			draw_line(Vector2(-6, -28 + bob), Vector2(6, -20 + bob), Color("ff8fa1"), 2.0)
			draw_line(Vector2(6, -28 + bob), Vector2(-6, -20 + bob), Color("ff8fa1"), 2.0)
		"ghost":
			draw_arc(Vector2(0, -24 + bob), 7.0, 0.0, TAU, 24, Color("b9d5ff"), 1.6)
		"monster":
			draw_line(Vector2(-6, -26 + bob), Vector2(-2, -20 + bob), Color("d8c59b"), 2.0)
			draw_line(Vector2(6, -26 + bob), Vector2(2, -20 + bob), Color("d8c59b"), 2.0)
		"faction_guest":
			draw_rect(Rect2(Vector2(-4, -29 + bob), Vector2(8, 8)), Color("9de8ff"))
		_:
			draw_circle(Vector2(0, -26 + bob), 2.5, Color("c7f0d8"))

func to_save_data() -> Dictionary:
	return {
		"npc_name": npc_name,
		"favor": favor,
		"last_talk_day": last_talk_day,
		"tragic_revealed": _tragic_revealed
	}

func load_from_data(data: Dictionary) -> void:
	favor = int(data.get("favor", 0))
	last_talk_day = int(data.get("last_talk_day", -1))
	_tragic_revealed = bool(data.get("tragic_revealed", false))
