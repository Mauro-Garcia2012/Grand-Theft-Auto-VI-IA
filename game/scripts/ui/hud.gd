class_name HUD
extends Control
## In-game HUD: minimap, health/armor, money, wanted stars, weapon/ammo, vehicle info, zone names,
## notifications, big messages, crosshair / scope, interaction prompts, radio name, fade.

var font_black: Font
var font_bold: Font
var minimap: Minimap
var _money_label: Label
var _clock_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _stars: Array[Label] = []
var _zone_label: Label
var _zone_t := 0.0
var _last_zone := ""
var _veh_label: Label
var _veh_t := 0.0
var _speed_label: Label
var _fuel_bar: ProgressBar
var _notify_box: PanelContainer
var _notify_label: Label
var _notify_queue: Array = []
var _notify_t := 0.0
var _big_title: Label
var _big_sub: Label
var _big_t := 0.0
var _prompt: Label
var _prompt_t := 0.0
var _fade: ColorRect
var _vignette: ColorRect
var _scope: Control
var _crosshair: Control
var _fps: Label
var _radio_label: Label
var _radio_t := 0.0
var _hp_bar: ProgressBar
var _ar_bar: ProgressBar
var _char_label: Label
var _shown_money := 0.0
var _last_vehicle: Node = null
var _hit_t := 0.0
var _last_health := 0.0
var _hurt := 0.0
var _star_flash := 0.0
var _star_cols: Array = [null, null, null, null, null]
var _mm_t := 0.0


func _ready() -> void:
	Game.hud = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font_black = load("res://assets/fonts/inter_black.woff")
	font_bold = load("res://assets/fonts/inter_bold.woff")
	_build()
	Game.notify.connect(_on_notify)
	Game.big_message.connect(_on_big)
	Game.wanted_changed.connect(func(_s): _star_flash = 3.0)
	_shown_money = Game.money


func _lbl(text: String, size: int, color := Color.WHITE, font: Font = null, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, bg := Color(0, 0, 0, 0.55)) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = bg
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build() -> void:
	# vignette (damage)
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = """shader_type canvas_item;
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(0.8, 0.0, 0.0, 1.0);
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d) * 1.2);
	COLOR = vec4(tint.rgb, v * amount);
}"""
	var vm := ShaderMaterial.new()
	vm.shader = vs
	_vignette.material = vm
	add_child(_vignette)
	# scope overlay
	_scope = ScopeOverlay.new()
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.visible = false
	add_child(_scope)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crosshair)
	# minimap
	minimap = Minimap.new()
	UI.place(minimap, Control.PRESET_BOTTOM_LEFT, Vector2(28, -300), Vector2(250, 250))
	add_child(minimap)
	_hp_bar = _bar(Color(0.3, 0.8, 0.35))
	UI.place(_hp_bar, Control.PRESET_BOTTOM_LEFT, Vector2(28, -42), Vector2(123, 10))
	add_child(_hp_bar)
	_ar_bar = _bar(Color(0.3, 0.6, 1.0))
	UI.place(_ar_bar, Control.PRESET_BOTTOM_LEFT, Vector2(155, -42), Vector2(123, 10))
	add_child(_ar_bar)
	_char_label = _lbl("JASON", 16, Color(1, 1, 1, 0.9), font_black, 5)
	UI.place(_char_label, Control.PRESET_BOTTOM_LEFT, Vector2(30, -30), Vector2(250, 24))
	add_child(_char_label)
	# top-right cluster
	var tr := VBoxContainer.new()
	UI.place(tr, Control.PRESET_TOP_RIGHT, Vector2(-420, 20), Vector2(400, 200))
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_END
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(stars_row)
	for i in 5:
		var s := _lbl("★", 34, Color(1, 1, 1, 0.18), font_black, 6)
		stars_row.add_child(s)
		_stars.append(s)
	_clock_label = _lbl("18:00", 26, Color(1, 1, 1), font_bold, 6)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_clock_label)
	_money_label = _lbl("$0", 40, Color(0.45, 0.95, 0.5), font_black, 8)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_money_label)
	_weapon_label = _lbl("", 22, Color(1, 1, 1), font_bold, 6)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_weapon_label)
	_ammo_label = _lbl("", 26, Color(1, 0.9, 0.6), font_black, 6)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_ammo_label)
	# zone & vehicle names (bottom right)
	_zone_label = _lbl("", 44, Color(1, 0.95, 0.85), font_black, 10)
	UI.place(_zone_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-820, -130), Vector2(790, 60))
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_zone_label)
	_veh_label = _lbl("", 34, Color(0.4, 0.95, 1.0), font_black, 8)
	UI.place(_veh_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-820, -180), Vector2(790, 50))
	_veh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_veh_label)
	_speed_label = _lbl("", 30, Color(1, 1, 1), font_black, 6)
	UI.place(_speed_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-470, -70), Vector2(440, 40))
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_speed_label)
	_fuel_bar = _bar(Color(1, 0.7, 0.2))
	UI.place(_fuel_bar, Control.PRESET_BOTTOM_RIGHT, Vector2(-190, -28), Vector2(160, 8))
	add_child(_fuel_bar)
	_radio_label = _lbl("", 28, Color(1, 0.5, 0.85), font_black, 8)
	UI.place(_radio_label, Control.PRESET_CENTER_TOP, Vector2(-300, 30), Vector2(600, 40))
	_radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_radio_label)
	# notifications
	_notify_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_notify_box.add_theme_stylebox_override("panel", sb)
	_notify_box.position = Vector2(24, 24)
	_notify_box.custom_minimum_size = Vector2(380, 0)
	_notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notify_label = _lbl("", 18, Color.WHITE, font_bold, 0)
	_notify_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notify_label.custom_minimum_size = Vector2(380, 0)
	_notify_box.add_child(_notify_label)
	_notify_box.visible = false
	add_child(_notify_box)
	# big message
	_big_title = _lbl("", 110, Color(1, 0.2, 0.2), font_black, 16)
	UI.place(_big_title, Control.PRESET_CENTER, Vector2(-600, -110), Vector2(1200, 140))
	_big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_big_title)
	_big_sub = _lbl("", 28, Color(1, 1, 1), font_bold, 6)
	UI.place(_big_sub, Control.PRESET_CENTER, Vector2(-600, 30), Vector2(1200, 40))
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_big_sub)
	# prompt
	_prompt = _lbl("", 22, Color(1, 1, 1), font_bold, 7)
	UI.place(_prompt, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -150), Vector2(1000, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_fps = _lbl("", 14, Color(1, 1, 0.6), null, 4)
	_fps.position = Vector2(8, 4)
	add_child(_fps)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func fade(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	tw.tween_interval(0.25)
	tw.tween_property(_fade, "color:a", 0.0, t)


func prompt(text: String) -> void:
	_prompt.text = text
	_prompt_t = 0.25


func radio_name(text: String) -> void:
	_radio_label.text = text
	_radio_t = 3.0


func hit_marker() -> void:
	_hit_t = 0.15


func _on_notify(text: String, seconds: float) -> void:
	_notify_queue.append([text, seconds])


func _on_big(title: String, sub: String, color: Color) -> void:
	_big_title.text = title
	_big_sub.text = sub
	_big_title.add_theme_color_override("font_color", color)
	_big_t = 4.0


func _process(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	# money counter animation
	_shown_money = move_toward(_shown_money, Game.money, maxf(absf(Game.money - _shown_money) * delta * 4.0, 1.0))
	_money_label.text = "$%s" % _fmt(int(_shown_money))
	_clock_label.text = Game.sky.clock_string() if Game.sky else ""
	# stars
	var st := Game.get_wanted()
	_star_flash = maxf(0.0, _star_flash - delta)
	var searching: bool = Game.wanted and not Game.wanted.seen and st > 0
	for i in 5:
		var on := i < st
		var c := Color(1, 1, 1, 0.18)
		if on:
			c = Color(1, 0.85, 0.2)
			if searching and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0:
				c = Color(0.6, 0.6, 0.6)
			if _star_flash > 0.0 and fmod(_star_flash * 6.0, 2.0) < 1.0:
				c = Color(1, 1, 1)
		if _star_cols[i] != c:
			_star_cols[i] = c
			_stars[i].add_theme_color_override("font_color", c)
	# weapon
	var d := p.current_def()
	_weapon_label.text = d.get("name", "")
	if d.get("type", "melee") == "melee":
		_ammo_label.text = ""
	else:
		var w := p.current_weapon()
		if p.reload_left > 0.0:
			_ammo_label.text = "RECARGANDO..."
		elif Game.infinite_ammo:
			_ammo_label.text = "%d / ∞" % int(w.clip)
		else:
			_ammo_label.text = "%d / %d" % [int(w.clip), int(w.ammo)]
	# health
	_hp_bar.max_value = p.max_health
	_hp_bar.value = p.health
	_ar_bar.max_value = 100.0
	_ar_bar.value = p.armor
	_char_label.text = p.display_name.to_upper()
	if p.health < _last_health - 0.5:
		_hurt = clampf(_hurt + (_last_health - p.health) / 40.0, 0.0, 1.0)
	_last_health = p.health
	_hurt = maxf(0.0, _hurt - delta * 0.8)
	var low := clampf(1.0 - p.health / (p.max_health * 0.3), 0.0, 1.0) * (0.5 + 0.2 * sin(Time.get_ticks_msec() / 200.0))
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", maxf(_hurt, low))
	# zone
	var pp := Game.player_pos()
	var zone = Game.city.district_at(pp.x, pp.z)
	if zone != _last_zone:
		_last_zone = zone
		_zone_label.text = Game.city.district_info(zone).get("name", "")
		_zone_t = 4.0
	_zone_t -= delta
	_zone_label.modulate.a = clampf(_zone_t, 0.0, 1.0)
	# vehicle
	var v = p.vehicle
	if v != _last_vehicle:
		_last_vehicle = v
		if v:
			_veh_label.text = v.def.get("name", "")
			_veh_t = 3.5
	_veh_t -= delta
	_veh_label.modulate.a = clampf(_veh_t, 0.0, 1.0)
	if v and is_instance_valid(v):
		_speed_label.visible = true
		_fuel_bar.visible = true
		_speed_label.text = "%d km/h" % int(v.speed_kmh)
		if v is Aircraft:
			_speed_label.text = "%d km/h · %d m · %d%%" % [int(v.speed_kmh), int(v.altitude), int(v.power * 100.0)]
			if v.stalled:
				_speed_label.text = "¡PÉRDIDA! " + _speed_label.text
		_fuel_bar.value = v.fuel * 100.0
		if v.fuel < 0.15:
			_fuel_bar.modulate = Color(1, 0.3, 0.3) if fmod(Time.get_ticks_msec() / 300.0, 2.0) < 1.0 else Color.WHITE
		else:
			_fuel_bar.modulate = Color.WHITE
	else:
		_speed_label.visible = false
		_fuel_bar.visible = false
	# notifications
	if _notify_t > 0.0:
		_notify_t -= delta
		if _notify_t <= 0.0:
			_notify_box.visible = false
	elif not _notify_queue.is_empty():
		var n = _notify_queue.pop_front()
		_notify_label.text = n[0]
		_notify_t = n[1]
		_notify_box.visible = true
	# big message
	_big_t -= delta
	var a := clampf(_big_t, 0.0, 1.0)
	_big_title.modulate.a = a
	_big_sub.modulate.a = a
	# prompt
	_prompt_t -= delta
	_prompt.visible = _prompt_t > 0.0
	_radio_t -= delta
	_radio_label.modulate.a = clampf(_radio_t, 0.0, 1.0)
	# crosshair / scope
	var rig: CameraRig = Game.camera_rig
	_scope.visible = rig != null and rig.scoped
	_crosshair.visible = (p.aiming or (p.vehicle == null and p.current_def().get("type", "") != "melee")) and not _scope.visible and not p.dead
	(_crosshair as Crosshair).spread = p.spread_bloom + float(p.current_def().get("spread", 1.0))
	(_crosshair as Crosshair).aiming = p.aiming
	_hit_t -= delta
	(_crosshair as Crosshair).hit = _hit_t > 0.0
	_crosshair.queue_redraw()
	_fps.visible = Game.settings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


class Crosshair extends Control:
	var spread := 1.0
	var aiming := false
	var hit := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		# The camera aims through the screen center
		var gap := 4.0 + spread * 3.0
		var col := Color(1, 1, 1, 0.9) if aiming else Color(1, 1, 1, 0.45)
		if hit:
			col = Color(1, 0.3, 0.3)
		draw_circle(c, 2.0, col)
		if aiming:
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * gap, c + d * (gap + 8.0), col, 2.0)


class ScopeOverlay extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		# black outside the circle
		var pts := PackedVector2Array()
		for i in 65:
			var a := TAU * i / 64.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_rect(Rect2(0, 0, c.x - r, size.y), Color.BLACK)
		draw_rect(Rect2(c.x + r, 0, size.x - c.x - r, size.y), Color.BLACK)
		for i in 64:
			var a0 := TAU * i / 64.0
			var p0 := c + Vector2(cos(a0), sin(a0)) * r
			var edge := Vector2(p0.x, 0.0 if p0.y < c.y else size.y)
			var a1 := TAU * (i + 1) / 64.0
			var p1 := c + Vector2(cos(a1), sin(a1)) * r
			var edge1 := Vector2(p1.x, 0.0 if p1.y < c.y else size.y)
			draw_colored_polygon(PackedVector2Array([p0, p1, edge1, edge]), Color.BLACK)
		draw_polyline(pts, Color(0, 0, 0), 6.0)
		draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, 0.9), 2.0)
		draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color(0, 0, 0, 0.9), 2.0)
		draw_circle(c, 3.0, Color(1, 0.1, 0.1))
