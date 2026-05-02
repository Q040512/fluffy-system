extends Node2D

@export var npc_name := "青岚师姐"
@export var title := "内门"
@export var faction := "青岚宗"
@export var archetype := "mentor"
@export var personality := "严谨"
@export var hobby := "种药"
@export var morning_offset := Vector2(-10, -6)
@export var noon_offset := Vector2(12, 0)
@export var night_offset := Vector2(-6, 10)

var favor := 0
var last_talk_day := -1
var anim_time := 0.0
var _home_position := Vector2.ZERO
var _tragic_revealed := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc_state")
	_home_position = position

func _process(delta: float) -> void:
	anim_time += delta
	_update_routine(delta)
	queue_redraw()

func interact(game) -> void:
	if game.day != last_talk_day:
		last_talk_day = game.day
		favor += 1
		var gift := _daily_gift()
		if gift.size() > 0:
			game.add_item(gift.get("item", "青灵草籽"), int(gift.get("amount", 1)))
		game.notify_tutorial_event("met_npc")
		game.feedback_layer.show_world_popup(global_position, "好感 +1", Color("ffbfd5"))
			game.ui.push_message("%s赠你%s x%d。好感 +1。" % [npc_name, gift.get("item", "青灵草籽"), int(gift.get("amount", 1))])
			game.ui.show_dialogue(npc_name, _daily_lines(game) + _personality_lines(game) + _villain_tragic_lines(game))
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
			game.ui.show_dialogue(npc_name, _exchange_lines() + _personality_lines(game) + _villain_tragic_lines(game))
		if favor >= 3 and faction != "" and game.joined_faction == "无门无派":
			game.offer_join_faction(faction, npc_name)
		else:
			game.ui.show_dialogue(npc_name, _hint_lines(game) + _personality_lines(game) + _villain_tragic_lines(game))

func _update_routine(delta: float) -> void:
	var game = get_parent()
	if game == null:
		return
	var hour := game.get_hour_of_day()
	var target := _home_position
	if hour >= 6 and hour < 11:
		target = _home_position + morning_offset
	elif hour >= 11 and hour < 18:
		target = _home_position + noon_offset
	else:
		target = _home_position + night_offset
	position = position.lerp(target, clamp(delta * 1.8, 0.0, 1.0))

func _daily_gift() -> Dictionary:
	match archetype:
		"junior":
			return {"item": "青灵草籽", "amount": 1}
		"elder":
			return {"item": "赤火芝籽", "amount": 1}
		"demon_lord":
			return {"item": "赤火芝", "amount": 1}
		_:
			return {"item": "青灵草籽", "amount": 1}

func _daily_lines(game) -> Array[String]:
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
		"faction_guest":
			return ["我是%s来使，奉命观摩青岚宗新弟子。" % faction, "礼尚往来，这份薄礼收下。"]
		_:
			return ["今日勤修，来日自有回响。"]

func _exchange_lines() -> Array[String]:
	return ["你以灵草换心得，这笔买卖不亏。", "招式可以借，心法要自己悟。"]

func _hint_lines(game) -> Array[String]:
	return ["先去种点青灵草再来，我再与你细讲。", "当前天象是%s，顺势而修更省力。" % game.current_weather]

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
	var bob := sin(anim_time * 1.8) * 3.0
	var aura := 0.12 + 0.03 * sin(anim_time * 2.6)
	draw_circle(Vector2(0, 24), 13.0, Color(0.75, 0.65, 1.0, aura))
	draw_circle(Vector2(0, -12 + bob), 10, Color("ead8c0"))
	draw_rect(Rect2(Vector2(-10, -2 + bob), Vector2(20, 28)), Color("a592d7"))
	draw_line(Vector2(-12, 14 + bob), Vector2(12, 14 + bob), Color("e8dcff"), 1.5)
	if favor > 0:
		draw_circle(Vector2(0, -34 + sin(anim_time * 3.4) * 2.0), 4.0, Color(1.0, 0.78, 0.88, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-40, -36), "%s·%s" % [faction, title], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9e8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -20), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2f7ff"))

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
