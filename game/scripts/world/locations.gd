class_name Locations
extends Node3D
## Interactive places: gas stations, gun shops, 24/7 stores (robbable), hospitals, police stations,
## paint & spray, clothes shop and safehouses. Each has a marker, a trigger and a minimap blip.

const DEFS := [
	{"kind": "gas", "name": "Gasolinera Leonida", "lot": [-660, 30, -580, 120]},
	{"kind": "gas", "name": "Gasolinera Stockyard", "lot": [50, -440, 150, -330]},
	{"kind": "gas", "name": "Gasolinera Vice Beach", "lot": [870, -600, 950, -510]},
	{"kind": "gas", "name": "Gasolinera de los Cayos", "pos": [-540, 1760]},
	{"kind": "gun", "name": "Armería Downtown", "lot": [-150, -60, -50, 30]},
	{"kind": "gun", "name": "Armería Little Cuba", "lot": [-420, 210, -340, 300]},
	{"kind": "gun", "name": "Armería Ocean Beach", "lot": [870, 660, 950, 740]},
	{"kind": "store", "name": "Tienda 24h Ocean", "lot": [950, 500, 1030, 580]},
	{"kind": "store", "name": "Bodega La Cubana", "lot": [-500, -60, -420, 30]},
	{"kind": "store", "name": "Tienda 24h Downtown", "lot": [150, 300, 250, 432]},
	{"kind": "store", "name": "Tienda 24h Brickell", "lot": [-340, 740, -250, 850]},
	{"kind": "hospital", "name": "Hospital Vice Beach", "lot": [870, -330, 950, -240]},
	{"kind": "hospital", "name": "Hospital General", "lot": [-250, 300, -150, 432]},
	{"kind": "police", "name": "Comisaría VCPD Beach", "lot": [870, 30, 950, 120]},
	{"kind": "police", "name": "Comisaría VCPD Little Cuba", "lot": [-580, 120, -500, 210]},
	{"kind": "spray", "name": "Pinta Rápido", "lot": [-150, -660, -50, -550]},
	{"kind": "spray", "name": "Pinta Rápido Cuba", "lot": [-820, 300, -740, 432]},
	{"kind": "clothes", "name": "Ropa Vice", "lot": [870, 420, 950, 500]},
	{"kind": "safe", "name": "Piso franco Ocean Beach", "lot": [950, 740, 1030, 820]},
	{"kind": "safe", "name": "Motel Leonida", "pos": [-612, 1830]},
]

const BLIP := {
	"gas": ["⛽", Color(1, 0.8, 0.2)], "gun": ["🔫", Color(1, 0.3, 0.3)], "store": ["$", Color(0.3, 1, 0.4)],
	"hospital": ["✚", Color(1, 0.4, 0.4)], "police": ["★", Color(0.4, 0.6, 1)], "spray": ["🎨", Color(0.9, 0.5, 1)],
	"clothes": ["👕", Color(0.4, 0.9, 1)], "safe": ["⌂", Color(1, 1, 1)],
}

var places: Array = []        # {kind, name, pos, area, ...}
var wb: WorldBuilder
var _mat_cache := {}


static func reserved_rects() -> Array:
	var out := []
	for d in DEFS:
		if d.has("lot"):
			var l: Array = d.lot
			out.append(Rect2(l[0], l[1], l[2] - l[0], l[3] - l[1]).grow(-12.0))
	return out


func build(p_wb: WorldBuilder) -> void:
	wb = p_wb
	for d in DEFS:
		var pos: Vector3
		var face := Vector3.ZERO   # direction of the street the entrance faces
		if d.has("lot"):
			var l: Array = d.lot
			var r := Rect2(l[0], l[1], l[2] - l[0], l[3] - l[1])
			pos = Vector3(r.get_center().x, CityMap.LAND + 0.14, r.get_center().y)
			# face the nearest long street (towards smaller x for beach lots, else -z)
			face = Vector3(0, 0, 1) if r.size.x >= r.size.y else Vector3(1, 0, 0)
		else:
			pos = Vector3(d.pos[0], 0, d.pos[1])
			pos.y = maxf(wb.height_grid(pos.x, pos.z), CityMap.LAND) + 0.05
			face = Vector3(0, 0, 1)
		var p := {"kind": d.kind, "name": d.name, "pos": pos, "face": face}
		match d.kind:
			"gas":
				_gas(p)
			"gun", "store", "clothes":
				_shop(p)
			"hospital":
				_big(p, Color(0.95, 0.95, 0.97), "HOSPITAL", Color(1, 0.2, 0.2))
			"police":
				_big(p, Color(0.85, 0.87, 0.92), "VCPD", Color(0.3, 0.5, 1.0))
			"spray":
				_spray(p)
			"safe":
				_safe(p)
		places.append(p)
	Game.set_meta("locations", self)


func _marker(pos: Vector3, color: Color, radius := 1.2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 1.2
	c.cap_top = false
	c.cap_bottom = false
	m.mesh = c
	var key := color.to_html()
	if not _mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_cache[key] = mat
	m.material_override = _mat_cache[key]
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3.UP * 0.6
	return m


func _area(p: Dictionary, pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Game.LAYER_TRIGGER
	a.collision_mask = Game.LAYER_CHAR | Game.LAYER_VEHICLE
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	a.add_child(cs)
	add_child(a)
	a.global_position = pos + Vector3.UP * size.y * 0.5
	p["area"] = a
	p["area_pos"] = pos
	p["area_size"] = size
	return a


func _sign(text: String, pos: Vector3, face: Vector3, color: Color, size := 0.02) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = size
	l.outline_size = 16
	l.modulate = color * 1.5
	l.outline_modulate = color.darkened(0.6)
	l.shaded = false
	add_child(l)
	l.global_position = pos
	l.look_at(pos - face, Vector3.UP)
	l.visibility_range_end = 400.0


func _gas(p: Dictionary) -> void:
	var pos: Vector3 = p.pos
	# canopy on pillars
	for sx in [-8.0, 8.0]:
		for sz in [-5.0, 5.0]:
			wb.add_box(Transform3D(Basis().scaled(Vector3(0.6, 5.0, 0.6)), pos + Vector3(sx, 0, sz)), Color(0.9, 0.9, 0.9), 6)
	wb.add_box(Transform3D(Basis().scaled(Vector3(22, 1.0, 14)), pos + Vector3(0, 5.0, 0)), Color(0.95, 0.35, 0.2), 1, 0.05, false)
	for sx in [-4.0, 4.0]:
		wb.add_box(Transform3D(Basis().scaled(Vector3(1.0, 1.6, 0.6)), pos + Vector3(sx, 0, 0)), Color(0.2, 0.5, 0.8), 6)
	# kiosk store
	wb.add_building(pos + Vector3(0, 0, -16), Vector3(16, 4.5, 8), Color(0.95, 0.93, 0.88), 2, 0.05)
	_sign("GAS", pos + Vector3(0, 7.2, 7.1), Vector3(0, 0, 1), Color(1, 0.6, 0.2), 0.03)
	_marker(pos, Color(1, 0.8, 0.2), 6.0)
	_area(p, pos, Vector3(20, 4, 12))


func _shop(p: Dictionary) -> void:
	var pos: Vector3 = p.pos
	var f: Vector3 = p.face
	var right := Vector3(f.z, 0, -f.x)
	var w := 14.0
	var d := 10.0
	var h := 4.2
	var wall = {"gun": Color(0.35, 0.33, 0.3), "store": Color(0.95, 0.95, 0.9), "clothes": Color(0.95, 0.8, 0.9)}[p.kind]
	var accent = {"gun": 0.0, "store": 0.33, "clothes": 0.85}[p.kind]
	# three walls + roof, open front facing f
	var back_c := pos - f * d * 0.5
	_wall(back_c, right, w, h, wall, accent)
	_wall(pos + right * w * 0.5, f, d, h, wall, accent)
	_wall(pos - right * w * 0.5, f, d, h, wall, accent)
	# front wall pieces leaving a door gap of 5m
	_wall(pos + f * d * 0.5 + right * (w * 0.5 - 2.25), right, 4.5, h, wall, accent)
	_wall(pos + f * d * 0.5 - right * (w * 0.5 - 2.25), right, 4.5, h, wall, accent)
	wb.add_box(Transform3D(Basis().scaled(Vector3(w + 1, 0.4, d + 1)), pos + Vector3.UP * h), wall.darkened(0.2), 6)
	# counter
	var counter_pos := pos - f * (d * 0.5 - 2.2)
	var cb := Basis.looking_at(f, Vector3.UP).scaled(Vector3(6, 1.1, 0.8))
	wb.add_box(Transform3D(cb, counter_pos), Color(0.45, 0.3, 0.2), 6)
	var title = {"gun": "ARMERÍA", "store": "24/7", "clothes": "ROPA VICE"}[p.kind]
	_sign(title, pos + f * (d * 0.5 + 0.3) + Vector3.UP * (h + 1.2), f, Color.from_hsv(accent, 0.7, 1.0), 0.025)
	# interior light
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.95, 0.85)
	l.light_energy = 1.4
	l.omni_range = 9.0
	add_child(l)
	l.global_position = pos + Vector3.UP * (h - 0.6)
	p["clerk_pos"] = pos - f * (d * 0.5 - 1.0)
	p["clerk_face"] = f
	var marker_pos := pos - f * 0.5
	_marker(marker_pos, Color(1, 0.85, 0.2) if p.kind != "store" else Color(0.3, 1, 0.4), 0.8)
	_area(p, pos, Vector3(w - 1.0, 3.0, d - 1.0))
	p["robbed_until"] = 0.0


func _wall(center: Vector3, along: Vector3, length: float, h: float, col: Color, accent: float) -> void:
	var b := Basis.looking_at(along.cross(Vector3.UP), Vector3.UP).scaled(Vector3(length, h, 0.35))
	wb.add_box(Transform3D(b, center), col, 2, accent)


func _big(p: Dictionary, col: Color, title: String, sign_col: Color) -> void:
	var pos: Vector3 = p.pos
	wb.add_building(pos - p.face * 12.0, Vector3(40, 16, 24), col, 4, 0.55)
	_sign(title, pos - p.face * 12.0 + p.face * 12.2 + Vector3.UP * 13.0, p.face, sign_col, 0.04)
	p["spawn"] = pos + p.face * 10.0


func _spray(p: Dictionary) -> void:
	var pos: Vector3 = p.pos
	var f: Vector3 = p.face
	var right := Vector3(f.z, 0, -f.x)
	_wall(pos - f * 6.0, right, 12.0, 6.0, Color(0.5, 0.5, 0.55), 0.8)
	_wall(pos + right * 6.0, f, 12.0, 6.0, Color(0.5, 0.5, 0.55), 0.8)
	_wall(pos - right * 6.0, f, 12.0, 6.0, Color(0.5, 0.5, 0.55), 0.8)
	wb.add_box(Transform3D(Basis().scaled(Vector3(13, 0.5, 13)), pos + Vector3.UP * 6.0), Color(0.4, 0.4, 0.45), 6)
	_sign("PINTA RÁPIDO", pos + f * 6.3 + Vector3.UP * 7.2, f, Color(0.9, 0.4, 1.0), 0.02)
	_marker(pos, Color(0.9, 0.5, 1), 3.5)
	_area(p, pos, Vector3(9, 4, 9))


func _safe(p: Dictionary) -> void:
	var pos: Vector3 = p.pos
	_marker(pos, Color(1, 1, 1), 0.9)
	_area(p, pos, Vector3(2.5, 3, 2.5))
	_sign("GUARDAR", pos + Vector3.UP * 2.6, p.face, Color(1, 1, 1), 0.01)


func place_at(pos: Vector3, kinds: Array = []) -> Dictionary:
	for p in places:
		if not kinds.is_empty() and not p.kind in kinds:
			continue
		var ap: Vector3 = p.get("area_pos", p.pos)
		var s: Vector3 = p.get("area_size", Vector3(4, 4, 4))
		if absf(pos.x - ap.x) < s.x * 0.5 + 0.5 and absf(pos.z - ap.z) < s.z * 0.5 + 0.5 and absf(pos.y - ap.y) < 4.0:
			return p
	return {}


func nearest(kind: String, pos: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for p in places:
		if p.kind != kind:
			continue
		var d: float = (p.pos as Vector3).distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best
