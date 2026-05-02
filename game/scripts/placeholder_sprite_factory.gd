extends RefCounted

static var _player_frames_cache: SpriteFrames
static var _crop_texture_cache := {}

static func build_player_frames() -> SpriteFrames:
	if _player_frames_cache != null:
		return _player_frames_cache
	var frames := SpriteFrames.new()
	var directions := ["down", "up", "left", "right"]
	for direction in directions:
		frames.add_animation("idle_%s" % direction)
		frames.set_animation_speed("idle_%s" % direction, 4.0)
		frames.add_frame("idle_%s" % direction, _make_player_texture(direction, 0, false))
		frames.add_animation("walk_%s" % direction)
		frames.set_animation_speed("walk_%s" % direction, 7.0)
		for frame in 4:
			frames.add_frame("walk_%s" % direction, _make_player_texture(direction, frame, true))
	frames.add_animation("meditate")
	frames.set_animation_speed("meditate", 5.0)
	for frame in 4:
		frames.add_frame("meditate", _make_meditate_texture(frame))
	_player_frames_cache = frames
	return _player_frames_cache

static func build_crop_texture(crop_name: String, stage: int, ready: bool, corrupted: bool, pulse_bucket: int) -> Texture2D:
	var cache_key := "%s|%d|%s|%s|%d" % [crop_name, stage, str(ready), str(corrupted), pulse_bucket]
	if _crop_texture_cache.has(cache_key):
		return _crop_texture_cache[cache_key]
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var crop_color := Color("68ba74") if crop_name == "青灵草" else Color("ca7440")
	if corrupted:
		crop_color = Color("7e4d8d")
	var stem_height := 8 + stage * 4
	var bloom_size := 3 + pulse_bucket + (1 if ready else 0)
	_fill_rect(image, Rect2i(10, 20 - stem_height, 4, stem_height), crop_color)
	_fill_circle(image, Vector2i(12, 20 - stem_height), bloom_size, Color(crop_color.r, crop_color.g, crop_color.b, 0.95))
	if ready:
		_fill_circle(image, Vector2i(12, 20 - stem_height), bloom_size + 3, Color(crop_color.r, crop_color.g, crop_color.b, 0.2))
	var texture := ImageTexture.create_from_image(image)
	_crop_texture_cache[cache_key] = texture
	return texture

static func _make_player_texture(direction: String, frame: int, moving: bool) -> Texture2D:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var skin := Color("f2d5b5")
	var robe := Color("6ba3d6")
	var dark := Color("24384c")
	var hair := Color("201b1b")
	var bob := frame % 2 if moving else 0
	var leg_shift := 1 if frame in [1, 3] else -1
	_fill_rect(image, Rect2i(11, 8 + bob, 10, 10), skin)
	if direction == "up":
		_fill_rect(image, Rect2i(11, 7 + bob, 10, 4), hair)
	_fill_rect(image, Rect2i(9, 18 + bob, 14, 16), robe)
	if direction == "left":
		_fill_rect(image, Rect2i(7, 20 + bob, 5, 10), robe.darkened(0.08))
	elif direction == "right":
		_fill_rect(image, Rect2i(20, 20 + bob, 5, 10), robe.darkened(0.08))
	_fill_rect(image, Rect2i(11 + leg_shift, 34 + bob, 4, 10), dark)
	_fill_rect(image, Rect2i(17 - leg_shift, 34 + bob, 4, 10), dark)
	_fill_rect(image, Rect2i(6, 23 + bob, 4, 3), skin.darkened(0.1))
	_fill_rect(image, Rect2i(22, 23 + bob, 4, 3), skin.darkened(0.1))
	if direction == "up":
		_fill_rect(image, Rect2i(12, 12 + bob, 8, 2), hair)
	return ImageTexture.create_from_image(image)

static func _make_meditate_texture(frame: int) -> Texture2D:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var robe := Color("84c8eb")
	var skin := Color("f2d5b5")
	var dark := Color("24384c")
	var halo_alpha := 0.12 + frame * 0.05
	_fill_circle(image, Vector2i(16, 36), 11, Color(0.4, 0.9, 1.0, halo_alpha))
	_fill_rect(image, Rect2i(11, 10, 10, 10), skin)
	_fill_rect(image, Rect2i(8, 20, 16, 12), robe)
	_fill_rect(image, Rect2i(10, 31, 5, 8), dark)
	_fill_rect(image, Rect2i(17, 31, 5, 8), dark)
	return ImageTexture.create_from_image(image)

static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, color)

static func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius * radius:
				if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
					image.set_pixel(x, y, color)
