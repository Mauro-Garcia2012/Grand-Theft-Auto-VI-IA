class_name SpecialAreas
extends Node
## Beach, port, airport, swamp, keys, mansions, marinas and neon signs.

var wb: WorldBuilder
var rng := RandomNumberGenerator.new()
var docks: Array = []            # boat spawn transforms
var parking_spots: Array = []    # car spawn transforms (parked)
const UMB_COLORS := [Color(0.95, 0.3, 0.4), Color(0.2, 0.7, 0.8), Color(1.0, 0.8, 0.2), Color(0.95, 0.95, 0.95), Color(0.5, 0.3, 0.8)]


func build() -> void:
	rng.seed = 777
	_make_umbrella_meshes()
	_beach()
	_port()
	_airport()
	_swamp()
	_keys()
	_mansions(Rect2(535, 150, 140, 150), 5)
	_mansions(Rect2(885, 1070, 170, 120), 4)
	_marinas()
	_neon()
	Game.world.set_meta("docks", docks)


func _y() -> float:
	return CityMap.LAND + 0.02




var _plane_spots: Array = []


func _spawn_planes() -> void:
	for sp in _plane_spots:
		VehicleDB.spawn(sp[0], sp[1], sp[2])
	_rooftop_helipads()


## Helicopters on the roofs of a few downtown towers (GTA-style helipads).
func _rooftop_helipads() -> void:
	var n := 0
	for b: AABB in wb.building_boxes:
		if n >= 3:
			break
		var c := b.get_center()
		var d = wb.city.district_at(c.x, c.z)
		if d not in ["downtown", "brickell"] or b.size.y < 60.0 or b.size.y > 140.0 or b.size.x < 24.0 or b.size.z < 24.0:
			continue
		var top := Vector3(c.x, b.position.y + b.size.y + 0.4, c.z)
		# the roof has to be free (no crown/setback built on top of it)
		var q := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 30.0, top - Vector3.UP * 2.0, Game.LAYER_WORLD)
		var hit := Game.world.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - (top.y - 0.4)) > 0.3:
			continue
		VehicleDB.spawn("police_heli" if n == 0 else "heli", Vector3(top.x, hit.position.y + 0.4, top.z), rng.randf() * TAU)
		wb.city.landmarks.append({"name": "Helipuerto", "pos": top, "kind": "helipad"})
		n += 1
	print("Helipads: %d" % n)


## Static decoration model (ModelUtil.make) placed at `pos` (base) with a yaw.
func _model(path: String, pos: Vector3, yaw: float, length: float, overrides := {}) -> Node3D:
	var m := ModelUtil.make(path, length, overrides)
	if m == null:
		return null
	wb.add_child(m)
	m.position = pos
	m.rotation.y = yaw
	return m


## Box collider standing on `pos` (bottom centre).
func _collider(pos: Vector3, yaw: float, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * size.y * 0.5)
	wb.add_shape(cs)


func _make_umbrella_meshes() -> void:
	for i in UMB_COLORS.size():
		var am := ArrayMesh.new()
		var pole := CylinderMesh.new()
		pole.top_radius = 0.022
		pole.bottom_radius = 0.028
		pole.height = 2.3
		pole.radial_segments = 8
		var canopy := CylinderMesh.new()
		canopy.top_radius = 0.03
		canopy.bottom_radius = 1.35
		canopy.height = 0.42
		canopy.radial_segments = 24
		canopy.rings = 2
		var m1 := StandardMaterial3D.new()
		m1.albedo_color = Color(0.72, 0.72, 0.74)
		m1.metallic = 0.8
		m1.roughness = 0.35
		var m2 := StandardMaterial3D.new()
		# striped canvas: 8 panels alternating colour / off-white
		var img := Image.create(64, 4, false, Image.FORMAT_RGB8)
		for x in 64:
			var c: Color = UMB_COLORS[i] if (x / 8) % 2 == 0 else Color(0.93, 0.92, 0.88)
			for y in 4:
				img.set_pixel(x, y, c)
		m2.albedo_texture = ImageTexture.create_from_image(img)
		m2.roughness = 0.85
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
		_append(am, pole, Transform3D(Basis(), Vector3(0, 1.15, 0)), m1)
		_append(am, canopy, Transform3D(Basis(), Vector3(0, 2.28, 0)), m2)
		wb.prop_meshes["umbrella%d" % i] = am
		# towel with a couple of stripes
		var towel := ArrayMesh.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.9, 0.012, 1.8)
		var m3 := StandardMaterial3D.new()
		var ti := Image.create(4, 32, false, Image.FORMAT_RGB8)
		var tc: Color = UMB_COLORS[(i + 2) % UMB_COLORS.size()]
		for y in 32:
			for x in 4:
				ti.set_pixel(x, y, Color(0.95, 0.95, 0.92) if y % 8 < 2 else tc)
		m3.albedo_texture = ImageTexture.create_from_image(ti)
		m3.roughness = 1.0
		_append(towel, bx, Transform3D(Basis(), Vector3(0, 0.006, 0)), m3)
		wb.prop_meshes["towel%d" % i] = towel
	# lounger
	var lounger := ArrayMesh.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.7, 0.08, 1.9)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.95, 0.95, 0.92)
	_append(lounger, lb, Transform3D(Basis(), Vector3(0, 0.35, 0)), lm)
	var back := BoxMesh.new()
	back.size = Vector3(0.7, 0.08, 0.7)
	_append(lounger, back, Transform3D(Basis(Vector3.RIGHT, 0.8), Vector3(0, 0.55, -0.9)), lm)
	wb.prop_meshes["lounger"] = lounger


func _append(am: ArrayMesh, prim: PrimitiveMesh, t: Transform3D, mat: Material) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in v.size():
		v[i] = t * v[i]
		n[i] = (t.basis * n[i]).normalized()
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TANGENT] = null
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(am.get_surface_count() - 1, mat)


func _beach() -> void:
	var city := wb.city
	var z := -1420.0
	var next_tower := -1380.0
	while z < 980.0:
		# sand x range: from the promenade to the water
		var x_water := 1150.0
		while city.height_at(x_water, z) < 0.25 and x_water > 1045.0:
			x_water -= 4.0
		# umbrella clusters
		if rng.randf() < 0.75:
			for k in rng.randi_range(1, 4):
				var x := rng.randf_range(1062.0, x_water - 12.0)
				var zz := z + rng.randf_range(-6.0, 6.0)
				var y := wb.height_grid(x, zz)
				var ci := rng.randi() % UMB_COLORS.size()
				wb.add_prop("umbrella%d" % ci, Vector3(x, y, zz), rng.randf() * TAU, 1.0)
				wb.add_prop("towel%d" % ci, Vector3(x + 1.2, y, zz + 0.5), rng.randf_range(-0.3, 0.3), 1.0)
				if rng.randf() < 0.5:
					wb.add_prop("lounger", Vector3(x - 1.3, y, zz), PI * 0.5 + rng.randf_range(-0.2, 0.2), 1.0)
		# lifeguard tower every ~160m (pastel huts on stilts, Miami style)
		if z >= next_tower:
			next_tower += 160.0
			var tx := x_water - 25.0
			var ty := wb.height_grid(tx, z)
			# pastel lifeguard stand facing the sea (+X); the prop is re-centred on its bounds,
			# so the hut sits ~2.5 m towards the sea from the ramp end
			wb.add_prop("lifeguard_%d" % (rng.randi() % 5), Vector3(tx, ty, z), PI * 0.5, 1.0)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(4.4, 5.2, 3.6)
			cs.shape = box
			cs.position = Vector3(tx + 2.4, ty + 2.6, z)
			wb.add_shape(cs)
		z += rng.randf_range(12.0, 22.0)
	# promenade / boardwalk along Ocean Drive beach side
	wb.add_box(Transform3D(Basis().scaled(Vector3(6.0, 0.3, 800.0)), Vector3(1047.0, CityMap.LAND - 0.12, 590.0)), Color(0.75, 0.62, 0.45), 6, 0.0, true)


func _port() -> void:
	var y := _y()
	var cols := [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.2, 0.55, 0.3), Color(0.85, 0.6, 0.1), Color(0.5, 0.5, 0.55), Color(0.9, 0.9, 0.9)]
	# container yard
	var x := 440.0
	while x < 545.0:
		var z := 660.0
		while z < 850.0:
			var stack := rng.randi_range(1, 4)
			for s in stack:
				wb.add_box(Transform3D(Basis().scaled(Vector3(2.5, 2.6, 12.0)), Vector3(x, y + s * 2.6, z)), cols[rng.randi() % cols.size()], 8, rng.randf(), s == 0)
			z += 13.0
		x += 3.0 if rng.randf() < 0.8 else 8.0
	# ship-to-shore container cranes at the east quay (boom over the water, towards +X)
	for i in 4:
		var cz := 580.0 + i * 70.0
		var cx := 695.0
		# the prop mesh is re-centred on its bounds; the boom overhangs 10 m more to the water side
		wb.add_prop("port_crane", Vector3(cx + 10.0, y, cz), 0.0, 1.0)
		for lz in [-6.0, 6.0]:
			for lx in [-8.0, 8.0]:
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(1.4, 30.0, 1.4)
				cs.shape = box
				cs.position = Vector3(cx + lx, y + 15.0, cz + lz)
				wb.add_shape(cs)
		var boom := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(68.0, 3.0, 7.0)
		boom.shape = bb
		boom.position = Vector3(cx + 10.0, y + 33.0, cz)
		wb.add_shape(boom)
	# warehouses
	for i in 3:
		wb.add_building(Vector3(610.0, y, 690.0 + i * 55.0), Vector3(50.0, 12.0, 40.0), Color(0.55, 0.57, 0.6), 7, rng.randf())
	# a cruise ferry and a bulk carrier moored along the east quay (waterline at the models' y = 0)
	for ship in [["ferry.glb", Vector3(752.0, 0.0, 640.0), 203.0], ["cargo.glb", Vector3(748.0, 0.0, 835.0), 140.0]]:
		var m := ModelUtil.make("res://assets/vehicles/boats_real/" + ship[0], ship[2], {}, 0.0, true)
		if m:
			wb.add_child(m)
			m.position = ship[1]
			var a := ModelUtil.mesh_aabb(m.get_child(0))
			_collider(Vector3(ship[1].x, -8.0, ship[1].z), 0.0, Vector3(a.size.x * 0.9, a.size.y * 0.6, a.size.z * 0.95))
	wb.city.landmarks.append({"name": "Puerto de Vice City", "pos": Vector3(560, 1, 700), "kind": "port"})


func _airport() -> void:
	var y := CityMap.LAND + 0.05
	# runways (dark strips with markings via road shader surface)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rw in [[Vector3(-1780, y, -1100), Vector3(-1020, y, -1100), 60.0], [Vector3(-1780, y, -300), Vector3(-1020, y, -300), 60.0], [Vector3(-1100, y, -1450), Vector3(-1100, y, -350), 25.0]]:
		var a: Vector3 = rw[0]
		var b: Vector3 = rw[1]
		var w: float = rw[2]
		var fd := (b - a).normalized()
		var side := Vector3(-fd.z, 0, fd.x)
		var L := a.distance_to(b)
		var q := [a - side * w * 0.5, a + side * w * 0.5, b + side * w * 0.5, b - side * w * 0.5]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, L), Vector2(0, L)]
		for idx in WorldBuilder.quad_order(q, Vector3.UP):
			st.set_color(Color(0, 0, 0))
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.set_uv2(Vector2(L, 4.0))
			st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wb.road_mat
	wb.add_child(mi)
	# terminal (long glass building), control tower, hangars
	wb.add_building(Vector3(-1350, _y(), -700), Vector3(260, 18, 60), Color(0.8, 0.82, 0.85), 0, 0.5)
	wb.add_building(Vector3(-1350, _y() + 18, -700), Vector3(240, 6, 40), Color(0.9, 0.9, 0.92), 4, 0.5)
	wb.add_building(Vector3(-1200, _y(), -520), Vector3(10, 45, 10), Color(0.85, 0.85, 0.85), 4, 0.5)
	wb.add_building(Vector3(-1200, _y() + 45, -520), Vector3(16, 7, 16), Color(0.2, 0.3, 0.35), 0, 0.5)
	for i in 5:
		wb.add_building(Vector3(-1700 + i * 90, _y(), -520), Vector3(70, 20, 50), Color(0.6, 0.62, 0.64), 7, rng.randf())
	# concrete apron in front of the terminal and hangars, with taxiways to both runways
	var apron := WorldBuilder.pbr_material("cwall", 0.08, Color(0.72, 0.72, 0.7))
	for r in [Rect2(-1760, -675, 580, 225), Rect2(-1395, -450, 30, 125), Rect2(-1395, -1075, 30, 345)]:
		var am := PlaneMesh.new()
		am.size = r.size
		am.material = apron
		var ami := MeshInstance3D.new()
		ami.mesh = am
		ami.position = Vector3(r.get_center().x, CityMap.LAND + 0.035, r.get_center().y)
		ami.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wb.add_child(ami)
	# airliners at the terminal gates (nose = -X in the model), one waiting on runway 09
	for i in 5:
		var gp := Vector3(-1460.0 + i * 55.0, _y(), -648.0)
		# nose towards the terminal (-Z): the A320 model's nose is +X, the E190's +Z
		var a320 := i % 2 == 0
		if _model("res://assets/aircraft/" + ("a320.glb" if a320 else "e190.glb"), gp, PI * 0.5 if a320 else PI, 37.6 if a320 else 36.2):
			_collider(gp, 0.0, Vector3(4.5, 5.0, 36.0))
	# flyable aircraft: an airliner waiting on runway 09, jets and light aircraft at the hangars.
	# They are spawned once the world's collision is in place.
	_plane_spots = [["airliner", Vector3(-1720, _y() + 0.3, -1100), -PI * 0.5]]
	for i in 5:
		var hp := Vector3(-1700.0 + i * 90.0, _y() + 0.3, -462.0)
		if i % 2 == 0:
			_plane_spots.append(["jet", hp, PI])
		else:
			_plane_spots.append(["cessna", hp + Vector3(-12, 0, 0), PI])
			_plane_spots.append(["cessna", hp + Vector3(12, 0, 4), PI + 0.3])
	# helicopters on the apron next to the hangars
	_plane_spots.append(["heli", Vector3(-1250.0, _y() + 0.4, -470.0), PI])
	_plane_spots.append(["police_heli", Vector3(-1225.0, _y() + 0.4, -470.0), PI])
	Game.world.get_tree().create_timer(1.0).timeout.connect(_spawn_planes)
	wb.city.landmarks.append({"name": "Aeropuerto", "pos": Vector3(-1350, 1, -700), "kind": "airport"})


func _swamp() -> void:
	var city := wb.city
	for i in 1400:
		var x := rng.randf_range(-1840, -910)
		var z := rng.randf_range(110, 1140)
		var h := wb.height_grid(x, z)
		if h < 0.15:
			continue
		var k: String = ["tree_oak", "tree_default", "bush", "bush2", "bush", "palm_short", "tree_default"][rng.randi() % 7]
		wb.add_prop(k, Vector3(x, h, z), rng.randf() * TAU, rng.randf_range(0.7, 1.3), 0.3 if k.begins_with("tree") else 0.0)
	# stilt shacks
	for i in 6:
		var p := Vector3(rng.randf_range(-1700, -1000), 0.0, rng.randf_range(300, 1000))
		p.y = maxf(wb.height_grid(p.x, p.z), 0.0)
		wb.add_building(p + Vector3.UP * 1.5, Vector3(8, 4, 6), Color(0.55, 0.42, 0.3), 5, 0.1)
		wb.add_roof(Transform3D(Basis().scaled(Vector3(9, 2, 7)), p + Vector3.UP * 5.5), Color(0.35, 0.3, 0.25))
		docks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(8, 0.3, 0)))
	city.landmarks.append({"name": "Grassrivers", "pos": Vector3(-1400, 1, 700), "kind": "swamp"})


func _keys() -> void:
	var city := wb.city
	for l in city.lands:
		if not l.has("circle"):
			continue
		var c: Vector3 = l.circle
		var n := int(c.z / 12.0)
		for i in n:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.1, 0.75) * c.z
			var p := Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r)
			p.y = wb.height_grid(p.x, p.z)
			if p.y < 0.6:
				continue
			if city.road_height_at(p.x, p.z) > -INF:
				continue
			if rng.randf() < 0.35:
				var col: Color = WorldBuilder.PASTELS[rng.randi() % WorldBuilder.PASTELS.size()]
				wb.add_building(p, Vector3(10, 4.5, 9), col, 5, rng.randf())
				wb.add_roof(Transform3D(Basis().scaled(Vector3(11, 2, 10)), p + Vector3.UP * 4.5), Color(0.9, 0.9, 0.9))
			else:
				wb.add_prop(["palm_tall", "palm_bend", "palm_detail", "palm_short"][rng.randi() % 4], p, rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.35)
		# beach docks
		docks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x + c.z * 0.95, 0.3, c.y)))
	# motel on key 3 (Jason & Lucia's hideout)
	var mp: Vector3 = city.spawn_points["keys_motel"]
	wb.add_building(mp + Vector3(20, 0, 0), Vector3(12, 7, 40), Color(0.55, 0.85, 0.8), 1, 0.9)
	wb.add_building(mp + Vector3(0, 0, 26), Vector3(30, 7, 12), Color(0.55, 0.85, 0.8), 1, 0.9)
	wb.neon_signs.append({"pos": mp + Vector3(13.8, 5.5, 0), "face": Vector3(-1, 0, 0), "text": "MOTEL LEONIDA", "hue": 0.9})


func _mansions(r: Rect2, n: int) -> void:
	for i in n:
		var p := Vector3(rng.randf_range(r.position.x + 20, r.end.x - 20), CityMap.LAND, rng.randf_range(r.position.y + 20, r.end.y - 20))
		if wb.city.road_height_at(p.x, p.z) > -INF:
			p.x += 25.0
		var col = Color(0.97, 0.96, 0.92) if rng.randf() < 0.7 else WorldBuilder.PASTELS[rng.randi() % WorldBuilder.PASTELS.size()]
		wb.add_building(p, Vector3(22, 7, 16), col, 4, 0.55)
		wb.add_building(p + Vector3(4, 7, 0), Vector3(14, 5, 12), col, 4, 0.55)
		# pool
		var pool := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(10, 0.1, 5)
		pool.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.75, 0.9)
		mat.roughness = 0.05
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.5, 0.7)
		mat.emission_energy_multiplier = 0.4
		pool.material_override = mat
		pool.position = p + Vector3(0, 0.1, 13)
		wb.add_child(pool)
		for k in 3:
			wb.add_prop(["palm_tall", "palm_detail", "palm_bend"][k], p + Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(9, 18)), rng.randf() * TAU, 1.0, 0.35)


func _sailboats() -> void:
	## Anchored sailboats in Biscayne-like bay between the mainland and Vice Beach
	var city := wb.city
	var n := 0
	var tries := 0
	while n < 14 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(420, 800), 0.0, rng.randf_range(-1300, 1000))
		if city.land_sdf(p.x, p.z) > -14.0:
			continue
		var big := rng.randf() < 0.15
		var m := ModelUtil.make("res://assets/vehicles/boats_real/" + ("yacht.glb" if big else "sail.glb"), 16.6 if big else 10.2, {}, 0.0, true)
		if m:
			wb.add_child(m)
			m.position = Vector3(p.x, 0.0, p.z)
			m.rotation.y = rng.randf() * TAU
		n += 1


func _marinas() -> void:
	_sailboats()
	# wooden piers on the bay side of the mainland (x=360) and of Vice Beach (x=820)
	var pier_col := Color(0.55, 0.42, 0.3)
	for z in [700.0, 800.0, 900.0, -450.0, -1000.0]:
		wb.add_box(Transform3D(Basis().scaled(Vector3(40.0, 0.4, 4.0)), Vector3(380.0, 0.8, z)), pier_col, 6, 0.0, true)
		for k in 3:
			docks.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(372.0 + k * 11.0, 0.3, z + 7.0)))
	for z in [-300.0, 250.0, -1100.0]:
		wb.add_box(Transform3D(Basis().scaled(Vector3(40.0, 0.4, 4.0)), Vector3(800.0, 0.8, z)), pier_col, 6, 0.0, true)
		for k in 2:
			docks.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(790.0 - k * 11.0, 0.3, z + 7.0)))


func _neon() -> void:
	for s in wb.neon_signs:
		var l := Label3D.new()
		l.text = s.text
		l.font_size = 96
		l.pixel_size = 0.018
		l.outline_size = 18
		var hue: float = fposmod(s.hue, 1.0)
		l.modulate = Color.from_hsv(hue, 0.6, 1.0) * 1.6
		l.outline_modulate = Color.from_hsv(hue, 0.9, 0.6)
		l.shaded = false
		l.double_sided = false
		l.no_depth_test = false
		l.render_priority = 1
		wb.add_child(l)
		l.global_position = s.pos
		var f: Vector3 = s.face
		l.look_at(s.pos - f, Vector3.UP)
		l.visibility_range_end = 450.0
		l.add_to_group("neon")
