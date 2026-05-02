extends Node2D

const PARTICLE_COUNT := 36

var particles: Array[Dictionary] = []
var haze_offset := 0.0
var sky_flash := 0.0
var _last_weather := ""
var breakthrough_ring := 0.0
var breakthrough_alpha := 0.0
var breakthrough_position := Vector2.ZERO
var breakthrough_success := false
var harvest_bursts: Array[Dictionary] = []
var thunder_position := Vector2(-1000, -1000)
var thunder_alpha := 0.0

func _ready() -> void:
	z_index = 10
	for i in PARTICLE_COUNT:
		particles.append(_make_particle(i))

func _process(delta: float) -> void:
	var game = get_parent()
	if game == null:
		return
	haze_offset += delta * 18.0
	if game.current_weather != _last_weather:
		_last_weather = game.current_weather
		if _last_weather == "血月":
			sky_flash = 0.7
	for particle in particles:
		particle["position"] += particle["velocity"] * delta
		if particle["position"].y > 760.0 or particle["position"].x < -30.0 or particle["position"].x > 1310.0:
			_reset_particle(particle)
	if sky_flash > 0.0:
		sky_flash = max(sky_flash - delta * 0.45, 0.0)
	if breakthrough_alpha > 0.0:
		breakthrough_ring += delta * 140.0
		breakthrough_alpha = max(breakthrough_alpha - delta * 0.55, 0.0)
	var active_bursts: Array[Dictionary] = []
	for burst in harvest_bursts:
		burst["time"] += delta
		burst["alpha"] = max(float(burst["alpha"]) - delta * 1.2, 0.0)
		if burst["alpha"] > 0.0:
			active_bursts.append(burst)
	harvest_bursts = active_bursts
	if thunder_alpha > 0.0:
		thunder_alpha = max(thunder_alpha - delta * 1.4, 0.0)
	queue_redraw()

func _draw() -> void:
	var game = get_parent()
	if game == null:
		return
	var time_ratio := float(game.get_hour_of_day() * 60 + game.get_minute_of_hour()) / (24.0 * 60.0)
	var daylight := clamp(sin(time_ratio * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)
	var orb_position := Vector2(160.0 + time_ratio * 920.0, 100.0 + sin(time_ratio * TAU) * 48.0)
	var orb_color := Color("ffe9a8") if daylight > 0.35 else Color("c9d7ff")
	draw_circle(orb_position, 30.0, orb_color)
	draw_circle(orb_position, 46.0, Color(orb_color.r, orb_color.g, orb_color.b, 0.18))
	_draw_haze(game, daylight)
	_draw_weather(game)
	var night_alpha := lerp(0.58, 0.04, daylight)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.03, 0.05, 0.1, night_alpha))
	if sky_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.8, 0.2, 0.25, sky_flash * 0.35))
	_draw_harvest_bursts()
	_draw_thunder()
	_draw_breakthrough()

func _draw_haze(game, daylight: float) -> void:
	var haze_strength := 0.06 if game.current_weather != "雾瘴" else 0.18
	for i in 4:
		var y := 120.0 + i * 105.0 + sin((haze_offset * 0.03) + i * 0.7) * 8.0
		var alpha := haze_strength + (1.0 - daylight) * 0.05
		draw_rect(Rect2(Vector2(-20.0 + i * 18.0, y), Vector2(1340.0, 42.0)), Color(0.75, 0.9, 1.0, alpha))

func _draw_weather(game) -> void:
	match game.current_weather:
		"灵雨":
			for particle in particles:
				draw_line(particle["position"], particle["position"] + Vector2(-4, 12), Color(0.6, 0.9, 1.0, 0.7), 1.5)
		"雾瘴":
			for particle in particles:
				draw_circle(particle["position"], particle["radius"] + 4.0, Color(0.55, 0.8, 0.65, 0.16))
		"血月":
			for particle in particles:
				draw_circle(particle["position"], particle["radius"], Color(0.96, 0.3, 0.42, 0.55))
		_:
			for index in range(0, particles.size(), 2):
				var particle: Dictionary = particles[index]
				draw_circle(particle["position"], particle["radius"], Color(0.75, 0.96, 1.0, 0.32))

func _make_particle(seed_offset: int) -> Dictionary:
	var particle := {
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"radius": 0.0
	}
	particle["position"] = Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0))
	particle["velocity"] = Vector2(randf_range(-10.0, 10.0), randf_range(12.0, 28.0))
	particle["radius"] = randf_range(1.5, 3.0)
	particle["position"].x += seed_offset * 7.0
	return particle

func _reset_particle(particle: Dictionary) -> void:
	particle["position"] = Vector2(randf_range(0.0, 1280.0), randf_range(-120.0, -10.0))
	particle["velocity"] = Vector2(randf_range(-10.0, 10.0), randf_range(12.0, 28.0))
	particle["radius"] = randf_range(1.5, 3.0)

func trigger_breakthrough(world_position: Vector2, success: bool) -> void:
	breakthrough_position = world_position
	breakthrough_success = success
	breakthrough_ring = 24.0
	breakthrough_alpha = 0.95
	trigger_thunder_strike(world_position + Vector2(0, -120), success)

func trigger_harvest_burst(world_position: Vector2, color: Color) -> void:
	harvest_bursts.append({
		"position": world_position,
		"color": color,
		"time": 0.0,
		"alpha": 0.9
	})

func trigger_thunder_strike(world_position: Vector2, success: bool) -> void:
	thunder_position = world_position
	thunder_alpha = 0.95 if success else 0.7
	if success:
		sky_flash = max(sky_flash, 0.6)

func _draw_breakthrough() -> void:
	if breakthrough_alpha <= 0.0:
		return
	var ring_color := Color("ffe08b") if breakthrough_success else Color("ff8a8a")
	draw_circle(breakthrough_position, breakthrough_ring, Color(ring_color.r, ring_color.g, ring_color.b, breakthrough_alpha * 0.16))
	draw_arc(breakthrough_position, breakthrough_ring + 12.0, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, breakthrough_alpha), 3.0)

func _draw_harvest_bursts() -> void:
	for burst in harvest_bursts:
		var pos: Vector2 = burst["position"]
		var tint: Color = burst["color"]
		var time: float = burst["time"]
		var alpha: float = burst["alpha"]
		for i in 6:
			var angle := (TAU / 6.0) * i + time * 3.0
			var offset := Vector2(cos(angle), sin(angle)) * (16.0 + time * 30.0)
			draw_circle(pos + offset, 3.0, Color(tint.r, tint.g, tint.b, alpha))

func _draw_thunder() -> void:
	if thunder_alpha <= 0.0:
		return
	var start := thunder_position + Vector2(0, -160)
	var mid_a := thunder_position + Vector2(-16, -90)
	var mid_b := thunder_position + Vector2(14, -42)
	var end := thunder_position
	draw_line(start, mid_a, Color(0.85, 0.96, 1.0, thunder_alpha), 3.0)
	draw_line(mid_a, mid_b, Color(0.85, 0.96, 1.0, thunder_alpha), 3.0)
	draw_line(mid_b, end, Color(0.85, 0.96, 1.0, thunder_alpha), 3.0)
