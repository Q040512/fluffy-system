extends CanvasLayer

var message_log: Array[String] = ["踏入青岚山门，从一块灵田开始修行。"]
var _panel: Panel
var _stats: Label
var _inventory: Label
var _message: RichTextLabel
var _hint: Label
var _dialogue_layer: ColorRect
var _dialogue_panel: Panel
var _dialogue_name: Label
var _dialogue_text: RichTextLabel
var _dialogue_prompt: Label
var _time := 0.0
var _refresh_accumulator := 0.0
var _last_stats_text := ""
var _last_inventory_text := ""
var _last_message_text := ""
var _last_hint_text := ""
var _dialogue_lines: Array[String] = []
var _dialogue_index := 0
var _dialogue_title := ""

func _ready() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(920, 20)
	_panel.size = Vector2(330, 680)
	add_child(_panel)

	_stats = Label.new()
	_stats.position = Vector2(16, 16)
	_stats.size = Vector2(298, 170)
	_panel.add_child(_stats)

	_inventory = Label.new()
	_inventory.position = Vector2(16, 180)
	_inventory.size = Vector2(298, 180)
	_panel.add_child(_inventory)

	_message = RichTextLabel.new()
	_message.position = Vector2(16, 350)
	_message.size = Vector2(298, 220)
	_message.bbcode_enabled = false
	_message.scroll_active = true
	_panel.add_child(_message)

	_hint = Label.new()
	_hint.position = Vector2(16, 580)
	_hint.size = Vector2(298, 90)
	_panel.add_child(_hint)

	_dialogue_layer = ColorRect.new()
	_dialogue_layer.color = Color(0.02, 0.02, 0.05, 0.64)
	_dialogue_layer.size = Vector2(1280, 720)
	_dialogue_layer.visible = false
	add_child(_dialogue_layer)

	_dialogue_panel = Panel.new()
	_dialogue_panel.position = Vector2(90, 500)
	_dialogue_panel.size = Vector2(780, 170)
	_dialogue_layer.add_child(_dialogue_panel)

	_dialogue_name = Label.new()
	_dialogue_name.position = Vector2(18, 12)
	_dialogue_name.size = Vector2(240, 26)
	_dialogue_panel.add_child(_dialogue_name)

	_dialogue_text = RichTextLabel.new()
	_dialogue_text.position = Vector2(18, 42)
	_dialogue_text.size = Vector2(742, 88)
	_dialogue_text.bbcode_enabled = false
	_dialogue_text.scroll_active = false
	_dialogue_panel.add_child(_dialogue_text)

	_dialogue_prompt = Label.new()
	_dialogue_prompt.position = Vector2(18, 136)
	_dialogue_prompt.size = Vector2(742, 24)
	_dialogue_panel.add_child(_dialogue_prompt)

func _process(delta: float) -> void:
	_time += delta
	var game = get_parent()
	if game == null:
		return
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.92 + sin(_time * 1.6) * 0.03)
	_dialogue_panel.modulate = Color(1.0, 1.0, 1.0, 0.95 + sin(_time * 2.0) * 0.03)
	_refresh_accumulator += delta
	if _refresh_accumulator < 0.12:
		return
	_refresh_accumulator = 0.0
	var stats_text := "【洞府】\n%s\n季节：%s  天象：%s\n灵力：%d / %d\n灵石：%d\n境界：%s  修为：%d" % [
		game.get_time_label(),
		game.get_season_name(),
		game.current_weather,
		int(game.spirit),
		int(game.max_spirit),
		game.spirit_stones,
		game.get_realm_name(),
		game.cultivation
	]
	if stats_text != _last_stats_text:
		_last_stats_text = stats_text
		_stats.text = stats_text

	var inventory_text := "【背包】\n青灵草籽 x %d\n赤火芝籽 x %d\n青灵草 x %d\n赤火芝 x %d" % [
		game.inventory.get("青灵草籽", 0),
		game.inventory.get("赤火芝籽", 0),
		game.inventory.get("青灵草", 0),
		game.inventory.get("赤火芝", 0)
	]
	if inventory_text != _last_inventory_text:
		_last_inventory_text = inventory_text
		_inventory.text = inventory_text

	var spirit_bar_count := int(round((game.spirit / max(game.max_spirit, 1.0)) * 10.0))
	var spirit_bar := "●".repeat(spirit_bar_count) + "○".repeat(10 - spirit_bar_count)
	var message_text := "【消息】\n" + "\n".join(message_log)
	if message_text != _last_message_text:
		_last_message_text = message_text
		_message.text = message_text

	var objective := game.get_current_objective_text()
	var hint_text := "【操作】\n移动：WASD / 方向键\n交互：E / 空格\n打坐：R\n突破：F（%d 灵石）\n灵力潮汐：%s\n当前目标：%s" % [
		game.get_breakthrough_cost(),
		spirit_bar,
		objective
	]
	if hint_text != _last_hint_text:
		_last_hint_text = hint_text
		_hint.text = hint_text

func push_message(text: String) -> void:
	message_log.append(text)
	if message_log.size() > 9:
		message_log.pop_front()

func show_dialogue(title: String, lines: Array[String]) -> void:
	_dialogue_title = title
	_dialogue_lines = lines.duplicate()
	_dialogue_index = 0
	_dialogue_layer.visible = true
	_refresh_dialogue()

func advance_dialogue() -> void:
	if _dialogue_lines.is_empty():
		return
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		hide_dialogue()
		return
	_refresh_dialogue()

func hide_dialogue() -> void:
	_dialogue_layer.visible = false
	_dialogue_lines.clear()
	_dialogue_index = 0

func is_dialogue_open() -> bool:
	return _dialogue_layer.visible

func _refresh_dialogue() -> void:
	_dialogue_name.text = "【%s】" % _dialogue_title
	_dialogue_text.text = _dialogue_lines[_dialogue_index]
	_dialogue_prompt.text = "按 E / 空格继续"
