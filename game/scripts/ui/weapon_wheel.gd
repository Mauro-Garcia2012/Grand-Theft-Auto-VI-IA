class_name WeaponWheel
extends Control
## GTA V weapon wheel: hold TAB, time slows down, move the mouse towards a category and let go.
## The mouse wheel (or a second press of the category key) cycles inside a category.

const R_IN := 120.0
const R_OUT := 290.0

var _sel := Vector2.ZERO
var _hover := -1
var _pick := {}           # category -> weapon index chosen while the wheel is open
var _font: Font
var _slowed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	var p: Humanoid = Game.player
	var want: bool = p != null and not p.dead and not Game.paused and Input.is_action_pressed("weapon_wheel")
	if want and not visible:
		_open()
	elif not want and visible:
		_close(p != null and not p.dead)
	if visible:
		queue_redraw()


func _open() -> void:
	visible = true
	Game.wheel_open = true
	_sel = Vector2.ZERO
	_hover = -1
	_pick.clear()
	if Engine.time_scale > 0.99:
		Engine.time_scale = 0.3
		_slowed = true


func _close(apply: bool) -> void:
	visible = false
	Game.wheel_open = false
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false
	if apply and _hover >= 0:
		var p: Humanoid = Game.player
		var owned := _owned(p, _hover)
		if not owned.is_empty():
			p.select_weapon(_pick.get(_hover, owned[0] if not p.weapon_index in owned else p.weapon_index))


func _owned(p: Humanoid, cat: int) -> Array:
	var out: Array = []
	for j in p.weapons.size():
		if int(WeaponDB.get_def(p.weapons[j].id).get("slot", 0)) == cat:
			out.append(j)
	return out


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventMouseMotion:
		_sel = (_sel + e.relative).limit_length(160.0)
		if _sel.length() > 40.0:
			var a := fposmod(_sel.angle() + PI * 0.5 + PI / 8.0, TAU)
			_hover = int(a / (TAU / 8.0)) % 8
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and _hover >= 0 and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var owned := _owned(Game.player, _hover)
		if owned.size() > 1:
			var cur: int = _pick.get(_hover, Game.player.weapon_index if Game.player.weapon_index in owned else owned[0])
			var k := owned.find(cur)
			_pick[_hover] = owned[(k + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1) + owned.size()) % owned.size()]
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var p: Humanoid = Game.player
	if p == null:
		return
	var c := size * 0.5
	draw_circle(c, R_OUT + 12.0, Color(0, 0, 0, 0.35))
	for i in 8:
		var a0 := -PI * 0.5 - PI / 8.0 + i * TAU / 8.0
		var a1 := a0 + TAU / 8.0
		var owned := _owned(p, i)
		var has := not owned.is_empty()
		var col := Color(0.08, 0.08, 0.1, 0.78)
		if i == _hover:
			col = Color(0.95, 0.3, 0.6, 0.85) if has else Color(0.4, 0.4, 0.45, 0.8)
		var pts := PackedVector2Array()
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * R_OUT)
		for k in 13:
			var a := lerpf(a1, a0, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * R_IN)
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.35), 2.0, true)
		var mid := (a0 + a1) * 0.5
		var tp := c + Vector2(cos(mid), sin(mid)) * (R_IN + R_OUT) * 0.5
		var name := "—"
		var sub: String = WeaponDB.CATEGORIES[i]
		var icon := ""
		if has:
			var j: int = _pick.get(i, p.weapon_index if p.weapon_index in owned else owned[0])
			var w: Dictionary = p.weapons[j]
			var d := WeaponDB.get_def(w.id)
			name = str(d.name)
			icon = str(d.get("icon", ""))
			if d.get("type", "") in ["gun", "launcher", "throw"]:
				sub = "%d / %d" % [int(w.clip), int(w.ammo)] if d.type != "throw" else "x%d" % (int(w.clip) + int(w.ammo))
			if owned.size() > 1:
				sub += "   (%d/%d)" % [owned.find(j) + 1, owned.size()]
		_text(tp + Vector2(0, -22), icon, 28, Color(1, 1, 1, 0.95 if has else 0.3))
		_text(tp + Vector2(0, 10), name, 17, Color(1, 1, 1, 1.0 if has else 0.35))
		_text(tp + Vector2(0, 32), sub, 13, Color(0.85, 0.85, 0.9, 0.9 if has else 0.3))
	var cur := WeaponDB.get_def(p.current_weapon_id())
	_text(c + Vector2(0, -8), str(cur.name), 20, Color(1, 0.6, 0.8))
	_text(c + Vector2(0, 18), "Rueda: cambiar", 13, Color(1, 1, 1, 0.6))


func _text(pos: Vector2, s: String, fs: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, pos - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, pos - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
