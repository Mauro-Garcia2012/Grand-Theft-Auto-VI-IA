class_name GunShop
extends Node3D
## Enterable gun shop (Blender model with trimesh collision, see assets/buildings/gunshop.glb).
## Automatic sliding glass doors, weapons on the pegboards and in the glass counter, ceiling fans,
## fluorescent lights, an interior reflection probe and a shooting range at the back whose paper
## targets swing and score when shot. Shooting inside the range is not reported as a crime.
## Local layout: street front at z = 0 facing +Z, 20 m wide, 26 m deep, counter at z = -10,
## range partition at z = -14 (door at x 6.5..8.5), targets at z = -23.

const MODEL := "res://assets/buildings/gunshop.glb"
const TARGET_TEX := "res://assets/buildings/range_target.jpg"
const CLERK_LOCAL := Vector3(0, 0.05, -11.8)
const COUNTER_LOCAL := Vector3(0, 0.0, -8.7)
const LANES := [-6.0, -2.0, 2.0, 6.0]

static var shops: Array = []

var face := Vector3(0, 0, 1)
var _doors: Array = []        # [body, closed_x, open_x]
var _door_area: Area3D
var _door_open := 0.0
var _door_was_open := false
var _fans: Array = []
var _targets: Array = []      # RangeTarget
var _stock: Node3D
var _t := 0.0
var _score := 0
var _player_inside := false
static var _mats := {}


## `front`: centre of the street facade (ground level), `p_face`: direction the entrance faces.
func setup(front: Vector3, p_face: Vector3) -> void:
	face = p_face
	global_position = front
	rotation.y = atan2(face.x, face.z)
	var m: Node3D = load(MODEL).instantiate()
	add_child(m)
	for b in m.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = Game.LAYER_WORLD
		(b as StaticBody3D).collision_mask = 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "decor":
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# foundation so the floor never floats over lower ground
	var base := _box(self, Vector3(0, -0.8, -13.0), Vector3(20.4, 1.6, 26.4), "dark_metal")
	base.material_override = _mat("concrete")
	_build_doors()
	_build_lights()
	_build_fans()
	_build_targets()
	_neon("ARMAS", Vector3(-4.0, 2.7, -0.3), Color(1.0, 0.25, 0.2))
	_neon("ABIERTO 24H", Vector3(4.0, 2.7, -0.3), Color(0.3, 1.0, 0.5))
	shops.append(self)


func _exit_tree() -> void:
	shops.erase(self)


func clerk_position() -> Vector3:
	return to_global(CLERK_LOCAL)


func counter_position() -> Vector3:
	return to_global(COUNTER_LOCAL)


## True when `pos` is inside the shooting range of any gun shop (no crime for shooting there).
static func in_range(pos: Vector3) -> bool:
	for s in shops:
		if not is_instance_valid(s):
			continue
		var l: Vector3 = (s as Node3D).to_local(pos)
		if l.z < -14.0 and l.z > -26.0 and absf(l.x) < 10.0 and l.y > -1.0 and l.y < 5.5:
			return true
	return false


## True when `pos` is anywhere inside the building.
func contains(pos: Vector3) -> bool:
	var l := to_local(pos)
	return l.z < -0.2 and l.z > -26.0 and absf(l.x) < 10.0 and l.y > -1.0 and l.y < 5.5


# ------------------------------------------------------------------ materials
static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.72, 0.82, 0.86, 0.22)
			m.metallic = 0.3
			m.roughness = 0.04
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"alu":
			m.albedo_color = Color(0.62, 0.63, 0.65)
			m.metallic = 0.9
			m.roughness = 0.35
		"dark_metal":
			m.albedo_color = Color(0.12, 0.12, 0.13)
			m.metallic = 0.8
			m.roughness = 0.45
		"fan_blade":
			m.albedo_color = Color(0.36, 0.24, 0.15)
			m.roughness = 0.6
		"wire":
			m.albedo_color = Color(0.2, 0.2, 0.2)
			m.metallic = 1.0
			m.roughness = 0.3
		"target":
			m.albedo_texture = load(TARGET_TEX)
			m.roughness = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"concrete":
			m.albedo_color = Color(0.55, 0.54, 0.52)
			m.roughness = 0.9
		"tag":
			m.albedo_color = Color(0.95, 0.93, 0.85)
			m.roughness = 0.8
	_mats[key] = m
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(mat)
	parent.add_child(mi)
	mi.position = pos
	return mi


# ------------------------------------------------------------------ doors
func _build_doors() -> void:
	for side in [-1.0, 1.0]:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = Game.LAYER_WORLD
		body.collision_mask = 0
		add_child(body)
		body.position = Vector3(side * 0.875, 0.05, -0.47)
		# frame + glass pane (1.75 x 3.2)
		_box(body, Vector3(0, 1.6, 0), Vector3(1.66, 3.1, 0.02), "glass")
		_box(body, Vector3(0, 3.17, 0), Vector3(1.75, 0.07, 0.06), "alu")
		_box(body, Vector3(0, 0.05, 0), Vector3(1.75, 0.1, 0.06), "alu")
		_box(body, Vector3(-0.85, 1.6, 0), Vector3(0.05, 3.2, 0.06), "alu")
		_box(body, Vector3(0.85, 1.6, 0), Vector3(0.05, 3.2, 0.06), "alu")
		_box(body, Vector3(-side * 0.72, 1.05, 0.05), Vector3(0.03, 0.9, 0.03), "alu")   # handle
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.75, 3.2, 0.08)
		cs.shape = sh
		cs.position = Vector3(0, 1.6, 0)
		body.add_child(cs)
		_doors.append([body, side * 0.875, side * 2.6])
	# door header track
	_box(self, Vector3(0, 3.33, -0.47), Vector3(7.0, 0.12, 0.14), "alu")
	# motion sensor: characters on either side open the doors
	_door_area = Area3D.new()
	_door_area.collision_layer = 0
	_door_area.collision_mask = Game.LAYER_CHAR
	_door_area.monitorable = false
	var cs2 := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.5, 3.0, 9.0)
	cs2.shape = bs
	_door_area.add_child(cs2)
	add_child(_door_area)
	_door_area.position = Vector3(0, 1.5, -0.4)


# ------------------------------------------------------------------ lights
func _build_lights() -> void:
	for z in [-3.0, -7.5, -11.5]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.96, 0.98, 1.0)
		l.light_energy = 1.3
		l.omni_range = 9.5
		l.omni_attenuation = 1.3
		l.shadow_enabled = z == -7.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 20.0
		add_child(l)
		l.position = Vector3(0, 4.85, z)
	var rl := OmniLight3D.new()
	rl.light_color = Color(1.0, 0.95, 0.85)
	rl.light_energy = 1.1
	rl.omni_range = 10.0
	rl.distance_fade_enabled = true
	rl.distance_fade_begin = 60.0
	rl.distance_fade_length = 20.0
	add_child(rl)
	rl.position = Vector3(0, 4.8, -19.0)
	# targets lit from the front
	var tl := SpotLight3D.new()
	tl.light_energy = 3.0
	tl.spot_range = 14.0
	tl.spot_angle = 45.0
	tl.distance_fade_enabled = true
	tl.distance_fade_begin = 50.0
	tl.distance_fade_length = 15.0
	add_child(tl)
	tl.position = Vector3(0, 5.0, -17.5)
	tl.look_at(to_global(Vector3(0, 1.5, -23.5)), Vector3.UP)
	# the inside uses its own ambient light and reflections instead of the sky
	var rp := ReflectionProbe.new()
	rp.size = Vector3(19.3, 5.3, 25.4)
	rp.origin_offset = Vector3.ZERO
	rp.box_projection = true
	rp.interior = true
	rp.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	rp.ambient_color = Color(0.72, 0.7, 0.66)
	rp.ambient_color_energy = 0.55
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.max_distance = 40.0
	rp.blend_distance = 0.4
	add_child(rp)
	rp.position = Vector3(0, 2.65, -13.0)


func _neon(text: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0055
	l.modulate = col * 2.2
	l.outline_size = 10
	l.outline_modulate = Color(col.r, col.g, col.b, 0.35)
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = 150.0
	add_child(l)
	l.position = pos


# ------------------------------------------------------------------ fans
func _build_fans() -> void:
	for fp in [Vector3(-4.5, 0, -5.0), Vector3(4.5, 0, -5.0)]:
		var root := Node3D.new()
		add_child(root)
		root.position = Vector3(fp.x, 5.18, fp.z)
		var rod := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.02
		cm.height = 0.45
		cm.radial_segments = 8
		rod.mesh = cm
		rod.material_override = _mat("dark_metal")
		root.add_child(rod)
		rod.position = Vector3(0, -0.22, 0)
		var spin := Node3D.new()
		root.add_child(spin)
		spin.position = Vector3(0, -0.5, 0)
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.1
		hm.bottom_radius = 0.13
		hm.height = 0.16
		hm.radial_segments = 16
		hub.mesh = hm
		hub.material_override = _mat("dark_metal")
		spin.add_child(hub)
		for i in 5:
			var arm := Node3D.new()
			spin.add_child(arm)
			arm.rotation.y = TAU * i / 5.0
			var bl := _box(arm, Vector3(0.48, -0.02, 0), Vector3(0.66, 0.012, 0.13), "fan_blade")
			bl.rotation.x = 0.12
			bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fans.append(spin)


# ------------------------------------------------------------------ range targets
func _build_targets() -> void:
	for x in LANES:
		# carrier on a ceiling rail, wire, clip and the paper target
		_box(self, Vector3(x, 5.12, -19.5), Vector3(0.06, 0.06, 11.0), "dark_metal")
		_box(self, Vector3(x, 5.0, -23.0), Vector3(0.18, 0.12, 0.22), "dark_metal")
		var wire := _box(self, Vector3(x, 3.5, -23.0), Vector3(0.012, 2.9, 0.012), "wire")
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(x, 2.05, -23.0)
		_box(pivot, Vector3(0, 0, 0), Vector3(0.64, 0.04, 0.03), "dark_metal")
		var t := RangeTarget.new()
		t.shop = self
		pivot.add_child(t)
		t.position = Vector3(0, -0.47, 0)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.6, 0.9)
		q.mesh = qm
		q.material_override = _mat("target")
		t.add_child(q)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 0.9, 0.03)
		cs.shape = bs
		t.add_child(cs)
		t.pivot = pivot
		_targets.append(t)


func target_hit(t: RangeTarget, local_hit: Vector3, shooter: Node) -> void:
	# texture: rings centred 0.585 m below the top edge, head 0.164 m below it (0.6 x 0.9 sheet)
	var top := 0.45
	var p := Vector2(local_hit.x, top - local_hit.y)
	var pts := 1
	var what := ""
	var r := p.distance_to(Vector2(0, 0.585))
	if p.distance_to(Vector2(0, 0.164)) < 0.117:
		pts = 10
		what = "¡A la cabeza! "
	elif r < 0.04:
		pts = 10
		what = "¡Diana! "
	elif r < 0.08:
		pts = 8
	elif r < 0.165:
		pts = 5
	elif absf(p.x) < 0.2 and p.y > 0.28:
		pts = 2
	if shooter == Game.player:
		_score += pts
		Game.msg("%s+%d  ·  Puntuación: %d" % [what, pts, _score], 1.4)


# ------------------------------------------------------------------ stock (weapons on display)
func _build_stock() -> void:
	_stock = Node3D.new()
	_stock.name = "Stock"
	add_child(_stock)
	# left wall (x = -9.5, facing +X): long guns on top, handguns lower
	var rows := [
		[3.0, ["rifle", "sniper", "rifle"]],
		[2.35, ["shotgun", "rifle", "shotgun"]],
		[1.65, ["smg", "smg", "smg", "smg"]],
		[1.15, ["pistol", "pistol", "pistol", "pistol", "pistol"]],
	]
	for side in [-1.0, 1.0]:
		for row in rows:
			var ids: Array = row[1]
			for i in ids.size():
				var z := -2.3 - (i + 0.5) * 6.8 / ids.size()
				var b := Basis(Vector3.UP, 0.0 if side < 0.0 else PI)
				_hang(ids[i], Vector3(side * 9.52, row[0], z), b, Vector3(side * 9.578, row[0], z), Vector3(side * -1.0, 0, 0))
	# back wall behind the counter (z = -13.8, facing +Z): barrels towards +X
	var bb := Basis(Vector3.UP, -PI * 0.5)
	for g in [["rpg", 0.0, 3.0], ["sniper", -1.8, 2.4], ["rifle", 1.8, 2.4], ["shotgun", -1.8, 1.75], ["shotgun", 1.8, 1.75]]:
		_hang(g[0], Vector3(g[1], g[2], -13.78), bb, Vector3(g[1], g[2], -13.83), Vector3(0, 0, 1))
	# glass counter: handguns lying on the velvet, barrels towards -X, price tags in front
	# lying on their side, tilted towards the customers
	var flat := Basis(Vector3.RIGHT, 0.5) * Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	var i2 := 0
	for x in [-5.0, -3.6, -2.2, -0.8, 0.8, 2.2, 3.6, 5.0]:
		var id: String = "pistol" if i2 % 2 == 0 else "smg"
		var g := WeaponDB.make_model(id)
		if g:
			_stock.add_child(g)
			g.position = Vector3(x + 0.2, 0.92, -10.05)
			g.basis = flat
		_tag(id, Vector3(x, 0.882, -9.72), Basis(Vector3.RIGHT, -PI * 0.5))
		i2 += 1
	# ammo and grenades on the counter return
	for k in 4:
		var gr := WeaponDB.make_model("grenade")
		if gr:
			_stock.add_child(gr)
			gr.position = Vector3(6.25 + (k % 2) * 0.25, 1.06, -11.2 - floorf(k / 2.0) * 0.25)


## Hangs a gun centred on `pos` (flat against a wall) with its price tag below it on the wall.
func _hang(id: String, pos: Vector3, b: Basis, wall: Vector3, normal: Vector3) -> void:
	var g := WeaponDB.make_model(id)
	if g == null:
		return
	_stock.add_child(g)
	g.basis = b
	g.position = pos
	# the grip sits ~72% of the way back from the muzzle: shift it so the gun is centred on the slot
	var along := b * Vector3(0, 0, -1)
	var L: float = float(WeaponDB.get_def(id).get("length", 0.5))
	g.position -= along * L * 0.22
	var tb := Basis.looking_at(-normal, Vector3.UP)
	_tag(id, wall + Vector3.DOWN * 0.22, tb)


func _tag(id: String, pos: Vector3, b: Basis) -> void:
	var d := WeaponDB.get_def(id)
	var l := Label3D.new()
	l.text = "$%d" % int(d.get("price", 0))
	l.font_size = 40
	l.pixel_size = 0.0016
	l.modulate = Color(0.1, 0.1, 0.1)
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	l.visibility_range_end = 25.0
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.06)
	bg.mesh = qm
	bg.material_override = _mat("tag")
	bg.visibility_range_end = 25.0
	_stock.add_child(bg)
	bg.basis = b
	bg.position = pos
	_stock.add_child(l)
	l.basis = b
	l.position = pos + b * Vector3(0, 0, 0.003)


# ------------------------------------------------------------------ update
func _physics_process(delta: float) -> void:
	var pp := Game.player_pos()
	var d := global_position.distance_to(pp)
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		if d < 90.0 and _stock == null:
			_build_stock()
		elif d > 160.0 and _stock != null:
			_stock.queue_free()
			_stock = null
		var inside := d < 40.0 and contains(pp)
		if inside and not _player_inside and Game.player and Game.player.vehicle == null:
			Game.msg("Armería de Leonida · Mostrador al fondo · Galería de tiro detrás del cristal", 3.5)
		_player_inside = inside
	if d > 150.0:
		return
	# doors
	var want := 1.0 if _door_area.has_overlapping_bodies() else 0.0
	_door_open = move_toward(_door_open, want, delta * (2.2 if want > 0.5 else 1.1))
	var s := smoothstep(0.0, 1.0, _door_open)
	for dd in _doors:
		var body: AnimatableBody3D = dd[0]
		body.position.x = lerpf(dd[1], dd[2], s)
	if (want > 0.5) != _door_was_open:
		_door_was_open = want > 0.5
		Sfx.play_at("swing", to_global(Vector3(0, 2.0, -0.4)), -14.0, 0.45)
	# fans
	for f in _fans:
		(f as Node3D).rotate_y(delta * 5.5)
	# targets swing back to rest
	for t in _targets:
		(t as RangeTarget).swing(delta)


class RangeTarget extends StaticBody3D:
	var shop: GunShop
	var pivot: Node3D
	var ang := 0.0
	var vel := 0.0
	var yaw_vel := 0.0

	func _ready() -> void:
		collision_layer = Game.LAYER_WORLD
		collision_mask = 0

	func on_bullet_hit(pos: Vector3, dir: Vector3, shooter: Node) -> void:
		var l := to_local(pos)
		vel += 3.5 * signf(-dir.dot(global_basis.z) + 0.001)
		yaw_vel += l.x * 6.0
		Sfx.play_at("thud", pos, -8.0, 1.4)
		if shop:
			shop.target_hit(self, l, shooter)

	func swing(delta: float) -> void:
		if absf(ang) < 0.0005 and absf(vel) < 0.001 and absf(pivot.rotation.y) < 0.0005 and absf(yaw_vel) < 0.001:
			return
		# damped pendulum around the clip (x) and a little twist (y)
		vel += (-ang * 22.0 - vel * 2.2) * delta
		ang += vel * delta
		yaw_vel += (-pivot.rotation.y * 14.0 - yaw_vel * 2.5) * delta
		pivot.rotation = Vector3(ang, pivot.rotation.y + yaw_vel * delta, 0)
