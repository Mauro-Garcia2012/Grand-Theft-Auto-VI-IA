class_name WorldBuilder
extends Node3D
## Generates Vice City at startup from CityMap: terrain, water, roads & bridges, city blocks,
## instanced buildings with procedural facades, CC0 props (palms, lights, benches...), special areas.

const CELL := 8.0
const CHUNK := 256.0

var city: CityMap
var rng := RandomNumberGenerator.new()
var heights := PackedFloat32Array()
var hx := 0
var hz := 0
var static_body: StaticBody3D
var building_mat: ShaderMaterial
var road_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var sidewalk_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var unit_cube: ArrayMesh
var roof_prism: ArrayMesh

# chunk key -> {"b": Array[[Transform3D, Color, Color]], "p": {prop_key: Array[Transform3D]}}
var chunks := {}
var prop_meshes := {}      # key -> Mesh
var streetlights: Array[Vector3] = []
var building_boxes: Array = []   # AABBs for spawning checks
var neon_signs: Array = []
var locations: Node
var palms_sites: Array = []


var _bodies := {}


## Adds a collision shape to the static body of its chunk (bodies enter the tree at the end:
## adding thousands of shapes to one live body is quadratic with Jolt).
func add_shape(cs: CollisionShape3D, hint := Vector3.INF) -> void:
	var k := _chunk_key(cs.transform.origin if hint == Vector3.INF else hint)
	var b: StaticBody3D = _bodies.get(k)
	if b == null:
		b = StaticBody3D.new()
		b.collision_layer = Game.LAYER_WORLD
		b.collision_mask = 0
		_bodies[k] = b
	b.add_child(cs)


func _attach_bodies() -> void:
	for k in _bodies:
		add_child(_bodies[k])


## Godot treats clockwise triangles as front faces: cross(b - a, c - a) must point against the normal.
static func quad_order(q: Array, n: Vector3) -> Array:
	var cr: Vector3 = (q[1] - q[0]).cross(q[2] - q[0])
	if cr.dot(n) < 0.0:
		return [0, 1, 2, 0, 2, 3]
	return [0, 2, 1, 0, 3, 2]


func _chunk_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


func _chunk(p: Vector3) -> Dictionary:
	var k := _chunk_key(p)
	if not chunks.has(k):
		chunks[k] = {"b": [], "p": {}, "r": []}
	return chunks[k]


func build(p_city: CityMap, progress: Callable) -> void:
	city = p_city
	rng.seed = 20261119
	_make_materials()
	static_body = StaticBody3D.new()
	static_body.name = "WorldCollision"
	static_body.collision_layer = Game.LAYER_WORLD
	static_body.collision_mask = 0
	add_child(static_body)
	var t0 := Time.get_ticks_msec()
	progress.call(0.05, "Generando terreno de Leonida...")
	await get_tree().process_frame
	_build_terrain()
	print("  terrain %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	progress.call(0.2, "Llenando la bahía de Vice City...")
	await get_tree().process_frame
	_build_water()
	progress.call(0.25, "Asfaltando calles y puentes...")
	await get_tree().process_frame
	_build_roads()
	print("  roads %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	progress.call(0.4, "Levantando edificios...")
	await get_tree().process_frame
	_load_props()
	print("  props load %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	_build_blocks()
	print("  blocks %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	progress.call(0.6, "Plantando palmeras...")
	await get_tree().process_frame
	_build_street_props()
	print("  street props %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	progress.call(0.68, "Construyendo el puerto, el aeropuerto y los Cayos...")
	await get_tree().process_frame
	var sa := SpecialAreas.new()
	sa.wb = self
	add_child(sa)
	sa.build()
	print("  special %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	locations = Locations.new()
	locations.name = "Locations"
	Game.world.add_child(locations)
	locations.build(self)
	progress.call(0.8, "Instanciando la ciudad...")
	await get_tree().process_frame
	_flush_chunks()
	_flush_platforms()
	_attach_bodies()
	print("  flush %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()


# ------------------------------------------------------------------ materials & meshes
func _make_materials() -> void:
	building_mat = ShaderMaterial.new()
	building_mat.shader = load("res://shaders/building.gdshader")
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader")
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.72, 0.7, 0.66)
	sidewalk_mat.roughness = 0.9
	sidewalk_mat.albedo_texture = _paver_texture()
	sidewalk_mat.uv1_triplanar = true
	sidewalk_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	sidewalk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.32, 0.52, 0.2)
	grass_mat.roughness = 1.0
	grass_mat.albedo_texture = _noise_texture(Color(0.25, 0.45, 0.15), Color(0.4, 0.58, 0.22))
	grass_mat.uv1_triplanar = true
	grass_mat.uv1_scale = Vector3(0.1, 0.1, 0.1)
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	unit_cube = _make_unit_cube()
	roof_prism = _make_prism()


func _paver_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var edge := (x % 32 < 1) or (y % 32 < 1)
			var v := 0.92 + randf() * 0.08
			if edge:
				v = 0.7
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.94))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _noise_texture(a: Color, b: Color) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	nt.noise = n
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	nt.color_ramp = g
	return nt


func _make_unit_cube() -> ArrayMesh:
	# unit cube with origin at bottom center, normals per face
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 1, 0.5), Vector3(-0.5, 1, 0.5)]],
		[Vector3(0, 0, -1), [Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5), Vector3(-0.5, 1, -0.5), Vector3(0.5, 1, -0.5)]],
		[Vector3(1, 0, 0), [Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 1, -0.5), Vector3(0.5, 1, 0.5)]],
		[Vector3(-1, 0, 0), [Vector3(-0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(-0.5, 1, 0.5), Vector3(-0.5, 1, -0.5)]],
		[Vector3(0, 1, 0), [Vector3(-0.5, 1, 0.5), Vector3(0.5, 1, 0.5), Vector3(0.5, 1, -0.5), Vector3(-0.5, 1, -0.5)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var v: Array = f[1]
		for idx in quad_order(v, n):
			st.set_normal(n)
			st.set_uv(Vector2(v[idx].x, v[idx].y))
			st.add_vertex(v[idx])
	return st.commit()


func _make_prism() -> ArrayMesh:
	# gable roof prism, origin at bottom center, ridge along Z, height 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5)
	var b := Vector3(0.5, 0, -0.5)
	var c := Vector3(0.5, 0, 0.5)
	var d := Vector3(-0.5, 0, 0.5)
	var r1 := Vector3(0, 1, -0.5)
	var r2 := Vector3(0, 1, 0.5)
	var tris := [[a, r1, r2], [a, r2, d], [b, c, r2], [b, r2, r1], [a, b, r1], [d, r2, c]]
	var center := Vector3(0, 0.3, 0)
	for t in tris:
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
		var out_dir: Vector3 = (t[0] + t[1] + t[2]) / 3.0 - center
		if n.dot(out_dir) < 0.0:
			n = -n
		# clockwise front face: cross must point inwards
		if (t[1] - t[0]).cross(t[2] - t[0]).dot(n) > 0.0:
			t = [t[0], t[2], t[1]]
		for v in t:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


# ------------------------------------------------------------------ terrain
func height_grid(x: float, z: float) -> float:
	var fx := (x - CityMap.MIN_X) / CELL
	var fz := (z - CityMap.MIN_Z) / CELL
	var ix := clampi(int(fx), 0, hx - 2)
	var iz := clampi(int(fz), 0, hz - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var h00 := heights[iz * hx + ix]
	var h10 := heights[iz * hx + ix + 1]
	var h01 := heights[(iz + 1) * hx + ix]
	var h11 := heights[(iz + 1) * hx + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


const TERRAIN_CACHE := "res://data/terrain_cache.bin"
const TERRAIN_VERSION := 4
var surf := PackedByteArray()


func _compute_grid() -> void:
	hx = int((CityMap.MAX_X - CityMap.MIN_X) / CELL) + 1
	hz = int((CityMap.MAX_Z - CityMap.MIN_Z) / CELL) + 1
	if FileAccess.file_exists(TERRAIN_CACHE):
		var f := FileAccess.open(TERRAIN_CACHE, FileAccess.READ)
		var d = f.get_var()
		if d is Dictionary and d.get("version", 0) == TERRAIN_VERSION and d.hx == hx and d.hz == hz:
			heights = d.heights
			surf = d.surf
			return
	heights.resize(hx * hz)
	surf.resize(hx * hz)
	for iz in hz:
		var z := CityMap.MIN_Z + iz * CELL
		for ix in hx:
			var x := CityMap.MIN_X + ix * CELL
			var h := city.height_at(x, z)
			heights[iz * hx + ix] = h
			var s := city.surface_at(x, z)
			if h < 0.5 and s != 3:
				s = 1
			surf[iz * hx + ix] = s
	var f2 := FileAccess.open(TERRAIN_CACHE, FileAccess.WRITE)
	if f2:
		f2.store_var({"version": TERRAIN_VERSION, "hx": hx, "hz": hz, "heights": heights, "surf": surf})
		print("  terrain cache written")


func _build_terrain() -> void:
	_compute_grid()
	# splat texture (r sand, g grass, b concrete, a swamp; zero = tarmac)
	var img := Image.create(hx, hz, false, Image.FORMAT_RGBA8)
	var cols := [Color(0, 1, 0, 0), Color(1, 0, 0, 0), Color(0, 0.25, 0.75, 0), Color(0, 0.3, 0, 0.7), Color(0, 0.35, 0, 0)]
	for i in hx * hz:
		img.set_pixel(i % hx, i / hx, cols[surf[i]])
	var splat := ImageTexture.create_from_image(img)
	terrain_mat.set_shader_parameter("splat", splat)
	terrain_mat.set_shader_parameter("map_min", Vector2(CityMap.MIN_X, CityMap.MIN_Z))
	terrain_mat.set_shader_parameter("map_size", Vector2((hx - 1) * CELL, (hz - 1) * CELL))
	var cpc := int(CHUNK / CELL)
	var ncx := int(ceil(float(hx - 1) / cpc))
	var ncz := int(ceil(float(hz - 1) / cpc))
	for cz in ncz:
		for cx in ncx:
			var x0 := cx * cpc
			var z0 := cz * cpc
			var x1 := mini(x0 + cpc, hx - 1)
			var z1 := mini(z0 + cpc, hz - 1)
			var all_flat := true
			var all_deep := true
			for iz in range(z0, z1 + 1):
				for ix in range(x0, x1 + 1):
					var h := heights[iz * hx + ix]
					if absf(h - CityMap.LAND) > 0.001:
						all_flat = false
					if h > -8.5:
						all_deep = false
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var idx := PackedInt32Array()
			if all_flat:
				var ax := CityMap.MIN_X + x0 * CELL
				var az := CityMap.MIN_Z + z0 * CELL
				var bx := CityMap.MIN_X + x1 * CELL
				var bz := CityMap.MIN_Z + z1 * CELL
				verts = PackedVector3Array([Vector3(ax, CityMap.LAND, az), Vector3(bx, CityMap.LAND, az), Vector3(bx, CityMap.LAND, bz), Vector3(ax, CityMap.LAND, bz)])
				norms = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
				idx = PackedInt32Array([0, 1, 2, 0, 2, 3])
			else:
				var w := x1 - x0 + 1
				for iz in range(z0, z1 + 1):
					for ix in range(x0, x1 + 1):
						var h := heights[iz * hx + ix]
						verts.append(Vector3(CityMap.MIN_X + ix * CELL, h, CityMap.MIN_Z + iz * CELL))
						var hl := heights[iz * hx + maxi(ix - 1, 0)]
						var hr := heights[iz * hx + mini(ix + 1, hx - 1)]
						var hd := heights[maxi(iz - 1, 0) * hx + ix]
						var hu := heights[mini(iz + 1, hz - 1) * hx + ix]
						norms.append(Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized())
				for iz in range(z1 - z0):
					for ix in range(x1 - x0):
						var a := iz * w + ix
						idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = terrain_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			if all_deep:
				continue
			var shape := CollisionShape3D.new()
			if all_flat:
				var box := BoxShape3D.new()
				var sx := (x1 - x0) * CELL
				var sz := (z1 - z0) * CELL
				box.size = Vector3(sx, 2.0, sz)
				shape.shape = box
				shape.position = Vector3(CityMap.MIN_X + x0 * CELL + sx * 0.5, CityMap.LAND - 1.0, CityMap.MIN_Z + z0 * CELL + sz * 0.5)
			else:
				var cp := am.create_trimesh_shape()
				cp.backface_collision = true
				shape.shape = cp
			add_shape(shape, Vector3(CityMap.MIN_X + (x0 + x1) * 0.5 * CELL, 0, CityMap.MIN_Z + (z0 + z1) * 0.5 * CELL))


func _build_water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	pm.subdivide_width = 180
	pm.subdivide_depth = 180
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	mi.material_override = m
	mi.position = Vector3((CityMap.MIN_X + CityMap.MAX_X) * 0.5, city.water_level, (CityMap.MIN_Z + CityMap.MAX_Z) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Water"
	add_child(mi)
	# invisible ocean floor far away so objects don't fall forever
	var floor_shape := CollisionShape3D.new()
	var wb := WorldBoundaryShape3D.new()
	floor_shape.shape = wb
	floor_shape.position.y = -12.0
	add_shape(floor_shape)


# ------------------------------------------------------------------ roads
func _build_roads() -> void:
	var st_by_chunk := {}
	var node_w := {}
	for e in city.edges:
		node_w[e.a] = maxf(node_w.get(e.a, 0.0), e.width)
		node_w[e.b] = maxf(node_w.get(e.b, 0.0), e.width)
	# intersections
	for i in city.nodes.size():
		if city.adj[i].size() < 3:
			continue
		var p: Vector3 = city.nodes[i]
		var w: float = node_w.get(i, 14.0)
		var st := _road_st(st_by_chunk, p)
		var y := p.y + 0.06
		var hw := w * 0.5
		var c := [Vector3(p.x - hw, y, p.z - hw), Vector3(p.x + hw, y, p.z - hw), Vector3(p.x + hw, y, p.z + hw), Vector3(p.x - hw, y, p.z + hw)]
		for idx in quad_order(c, Vector3.UP):
			st.set_color(Color(1, 0, 0))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2.ZERO)
			st.add_vertex(c[idx])
	for e in city.edges:
		var a: Vector3 = city.nodes[e.a]
		var b: Vector3 = city.nodes[e.b]
		var dir := b - a
		var flat := Vector3(dir.x, 0, dir.z)
		var L := flat.length()
		if L < 0.5:
			continue
		var fd := flat / L
		var side := Vector3(-fd.z, 0, fd.x)
		var cut_a: float = node_w.get(e.a, 0.0) * 0.5 if city.adj[e.a].size() >= 3 else 0.0
		var cut_b: float = node_w.get(e.b, 0.0) * 0.5 if city.adj[e.b].size() >= 3 else 0.0
		var ta := cut_a / L
		var tb := 1.0 - cut_b / L
		if tb <= ta:
			continue
		var pa := a.lerp(b, ta) + Vector3.UP * 0.06
		var pb := a.lerp(b, tb) + Vector3.UP * 0.06
		var hw: float = e.width * 0.5
		var seg_len := pa.distance_to(pb)
		var st := _road_st(st_by_chunk, (pa + pb) * 0.5)
		var q := [pa - side * hw, pa + side * hw, pb + side * hw, pb - side * hw]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, seg_len), Vector2(0, seg_len)]
		var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		if n.y < 0:
			n = -n
		for idx in quad_order(q, n):
			st.set_color(Color(0, 0, 0))
			st.set_normal(n)
			st.set_uv(uvs[idx])
			st.set_uv2(Vector2(seg_len, e.lanes))
			st.add_vertex(q[idx])
		if e.bridge:
			_bridge_segment(a, b, e.width)
	for k in st_by_chunk:
		var mi := MeshInstance3D.new()
		mi.mesh = st_by_chunk[k].commit()
		mi.material_override = road_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _road_st(d: Dictionary, p: Vector3) -> SurfaceTool:
	var k := _chunk_key(p)
	if not d.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		d[k] = st
	return d[k]


func _bridge_segment(a: Vector3, b: Vector3, width: float) -> void:
	# deck collision + visual deck body, rails and pillars
	var mid := (a + b) * 0.5
	var L := a.distance_to(b)
	var t := Transform3D()
	var fwd := (b - a).normalized()
	var up := Vector3.UP
	var right := fwd.cross(up).normalized()
	up = right.cross(fwd).normalized()
	t.basis = Basis(right, up, -fwd)
	t.origin = mid
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, L + 0.5)
	cs.shape = box
	cs.transform = t.translated_local(Vector3(0, -0.45, 0))
	add_shape(cs)
	# visual: concrete body under deck
	var c := _chunk(mid)
	var body_t := Transform3D(t.basis.scaled_local(Vector3(width + 1.0, 1.2, L + 0.3)), t.origin - up * 1.2)
	c.b.append([body_t, Color(0.7, 0.7, 0.68), Color(0.6, 0.5, 0.2, 0.1)])
	# rails
	for sgn in [-1.0, 1.0]:
		var rt := Transform3D(t.basis.scaled_local(Vector3(0.4, 0.9, L + 0.3)), t.origin + right * sgn * (width * 0.5 + 0.2))
		c.b.append([rt, Color(0.85, 0.85, 0.82), Color(0.6, 0.5, 0.3, 0.1)])
		var rcs := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.4, 1.2, L)
		rcs.shape = rb
		rcs.transform = Transform3D(t.basis, t.origin + right * sgn * (width * 0.5 + 0.2) + up * 0.5)
		add_shape(rcs)
	# pillars down to the water
	if mid.y > 2.5:
		var pillar_h := mid.y + 8.0
		var pt := Transform3D(Basis().scaled(Vector3(width * 0.6, pillar_h, 2.0)), Vector3(mid.x, mid.y - 1.2 - pillar_h, mid.z))
		c.b.append([pt, Color(0.75, 0.74, 0.7), Color(0.6, 0.5, 0.3, 0.1)])
		# street lights on bridge
		streetlights.append(mid + right * (width * 0.5 - 0.3))


# ------------------------------------------------------------------ props
func _load_props() -> void:
	var defs := {
		"palm_tall": ["res://assets/props/tree_palmTall.glb", 11.0],
		"palm_detail": ["res://assets/props/tree_palmDetailedTall.glb", 12.0],
		"palm_bend": ["res://assets/props/tree_palmBend.glb", 9.0],
		"palm_short": ["res://assets/props/tree_palmDetailedShort.glb", 6.0],
		"palm_pm": ["res://assets/props/pm_PalmTree_Art.glb", 10.0],
		"tree_oak": ["res://assets/props/tree_oak.glb", 8.0],
		"tree_default": ["res://assets/props/tree_default.glb", 7.0],
		"bush": ["res://assets/props/plant_bushLarge.glb", 1.4],
		"bush2": ["res://assets/props/plant_bushDetailed.glb", 1.2],
		"streetlight": ["res://assets/props/pm_Light_Streetlight_01.glb", 7.5],
		"bench": ["res://assets/props/pm_Bench_02.glb", 0.9],
		"bin": ["res://assets/props/pm_Bin_01.glb", 1.0],
		"rock": ["res://assets/props/rock_largeA.glb", 1.5],
		"grass": ["res://assets/props/grass_large.glb", 0.6],
		"flower": ["res://assets/props/flower_redA.glb", 0.5],
		"pole": ["res://assets/props/pm_ElectricPost01_Art.glb", 8.0],
	}
	for k in defs:
		var m := _extract_mesh(defs[k][0], defs[k][1])
		if m:
			prop_meshes[k] = m


func _extract_mesh(path: String, target_h: float) -> Mesh:
	var sc: PackedScene = load(path)
	if sc == null:
		return null
	var inst: Node3D = sc.instantiate()
	# merge all meshes into one ArrayMesh normalized to target height, base at y=0
	var parts: Array = []
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false) + ([inst] if inst is MeshInstance3D else []):
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != inst:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		parts.append([mi, t])
		var a: AABB = t * (mi as MeshInstance3D).get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	if parts.is_empty():
		inst.free()
		return null
	var k := target_h / maxf(aabb.size.y, 0.001)
	var center := aabb.get_center()
	var base := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-center.x * k, -aabb.position.y * k, -center.z * k))
	var out := ArrayMesh.new()
	for part in parts:
		var mi: MeshInstance3D = part[0]
		var t: Transform3D = base * part[1]
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(mi.mesh, s)
			var arr := st.commit_to_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = t * verts[i]
				if norms.size() > i:
					norms[i] = (t.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			if norms.size() > 0:
				arr[Mesh.ARRAY_NORMAL] = norms
			# drop skinning data if any
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mat := mi.get_active_material(s)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	inst.free()
	return out


func add_prop(key: String, pos: Vector3, yaw := 0.0, scale := 1.0, collide := 0.0) -> void:
	if not prop_meshes.has(key):
		return
	var c := _chunk(pos)
	if not c.p.has(key):
		c.p[key] = []
	c.p[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos))
	if collide > 0.0:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collide
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = pos + Vector3.UP * 2.0
		add_shape(cs)


func add_box(t: Transform3D, color: Color, style: int, accent := 0.0, collide := true, seed := -1.0) -> void:
	## t: basis includes size; origin = bottom center
	var c := _chunk(t.origin)
	var sd := seed if seed >= 0.0 else rng.randf()
	c.b.append([t, color, Color(style / 10.0 + 0.001, sd, accent, 0.0)])
	if collide:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var sx := t.basis.x.length()
		var sy := t.basis.y.length()
		var sz := t.basis.z.length()
		box.size = Vector3(sx, sy, sz)
		cs.shape = box
		cs.transform = Transform3D(t.basis.orthonormalized(), t.origin + t.basis.y * 0.5)
		add_shape(cs)
		building_boxes.append(AABB(t.origin - Vector3(sx, 0, sz) * 0.5, Vector3(sx, sy, sz)))


func add_roof(t: Transform3D, color := Color(0.55, 0.3, 0.22)) -> void:
	var c := _chunk(t.origin)
	c.r.append([t, color, Color(0.501, rng.randf(), 0, 0)])


func add_building(center: Vector3, size: Vector3, color: Color, style: int, accent := 0.0, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw).scaled(size)
	add_box(Transform3D(b, center), color, style, accent)


func _flush_chunks() -> void:
	var n_build := 0
	for k in chunks:
		var c: Dictionary = chunks[k]
		if c.b.size() > 0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = unit_cube
			mm.instance_count = c.b.size()
			for i in c.b.size():
				mm.set_instance_transform(i, c.b[i][0])
				mm.set_instance_color(i, c.b[i][1])
				mm.set_instance_custom_data(i, c.b[i][2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = building_mat
			mmi.visibility_range_end = 3000.0
			add_child(mmi)
			n_build += c.b.size()
		if c.r.size() > 0:
			var rm := MultiMesh.new()
			rm.transform_format = MultiMesh.TRANSFORM_3D
			rm.use_colors = true
			rm.use_custom_data = true
			rm.mesh = roof_prism
			rm.instance_count = c.r.size()
			for i in c.r.size():
				rm.set_instance_transform(i, c.r[i][0])
				rm.set_instance_color(i, c.r[i][1])
				rm.set_instance_custom_data(i, c.r[i][2])
			var rmi := MultiMeshInstance3D.new()
			rmi.multimesh = rm
			rmi.material_override = building_mat
			rmi.visibility_range_end = 1500.0
			add_child(rmi)
		for pk in c.p:
			var list: Array = c.p[pk]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = prop_meshes[pk]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 700.0 if not pk.begins_with("palm") else 1200.0
			if pk in ["grass", "flower", "bin", "bench", "rock", "bush2"]:
				mmi.visibility_range_end = 250.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
	print("World: %d building boxes, %d chunks, %d road nodes" % [n_build, chunks.size(), city.nodes.size()])


# ------------------------------------------------------------------ city blocks
const PASTELS := [Color(0.98, 0.72, 0.78), Color(0.72, 0.93, 0.85), Color(0.99, 0.93, 0.62), Color(0.78, 0.8, 0.98),
	Color(0.99, 0.82, 0.66), Color(0.96, 0.96, 0.93), Color(0.75, 0.93, 0.97), Color(0.92, 0.78, 0.96)]
const CUBA := [Color(0.95, 0.55, 0.35), Color(0.35, 0.7, 0.75), Color(0.95, 0.85, 0.45), Color(0.85, 0.4, 0.5),
	Color(0.55, 0.8, 0.5), Color(0.95, 0.9, 0.8), Color(0.6, 0.55, 0.85), Color(0.98, 0.7, 0.4)]
const HOTEL_NAMES := ["THE VICE", "FLAMINGO", "STARLITE", "PINK PALMS", "OCEANIA", "LEONIDA", "CORAL", "SUNSET", "NEON BAY",
	"MIRAMAR", "PARADISE", "EL DORADO", "SAN MARCO", "COLONY", "TROPICANA", "AVALON", "CAVALIER", "BREAKWATER"]


func _in_park(r: Rect2) -> bool:
	for p in city.parks:
		if (p as Rect2).intersects(r.grow(-5.0)):
			return true
	return false


func _build_blocks() -> void:
	var hotel_i := 0
	var reserved := Locations.reserved_rects()
	for lot in city.lots:
		var r: Rect2 = lot.rect
		var ins: Array = lot.inset
		var block := Rect2(r.position.x + ins[0], r.position.y + ins[1], r.size.x - ins[0] - ins[2], r.size.y - ins[1] - ins[3])
		if block.size.x < 8 or block.size.y < 8:
			continue
		var c := block.get_center()
		if city.land_sdf(c.x, c.y) < 10.0:
			continue
		var district := city.district_at(c.x, c.y)
		var info := city.district_info(district)
		var style: String = info.get("style", "")
		var park := _in_park(block)
		_block_platform(block, park or style == "suburb")
		var inner := block.grow(-3.5)
		var skip := false
		for rr in reserved:
			if (rr as Rect2).intersects(block):
				skip = true
		if skip:
			continue
		if park:
			_park(inner)
			continue
		match style:
			"tower":
				_towers(inner, c)
			"deco":
				hotel_i = _deco(inner, hotel_i)
			"condo":
				_condos(inner)
			"lowrise":
				_lowrise(inner)
			"warehouse":
				_warehouses(inner)
			"suburb":
				_suburb(inner)
			"midrise":
				_midrise(inner)
			_:
				_lowrise(inner)


var _plat := {}   # chunk -> {"v": PackedVector3Array, "n": PackedVector3Array, "uv": PackedVector2Array}
var _grass := {}


func _plat_arrays(d: Dictionary, p: Vector3) -> Dictionary:
	var k := _chunk_key(p)
	if not d.has(k):
		d[k] = {"v": PackedVector3Array(), "n": PackedVector3Array()}
	return d[k]


func _block_platform(block: Rect2, grassy: bool) -> void:
	var y0 := CityMap.LAND - 0.2
	var h := 0.34
	var ch := 0.25   # chamfer
	var x0 := block.position.x
	var z0 := block.position.y
	var x1 := block.end.x
	var z1 := block.end.y
	var top := [Vector3(x0 + ch, y0 + h, z0 + ch), Vector3(x1 - ch, y0 + h, z0 + ch), Vector3(x1 - ch, y0 + h, z1 - ch), Vector3(x0 + ch, y0 + h, z1 - ch)]
	var bot := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)]
	var a := _plat_arrays(_plat, Vector3(block.get_center().x, 0, block.get_center().y))
	for idx in quad_order(top, Vector3.UP):
		a.v.append(top[idx])
		a.n.append(Vector3.UP)
	for i in 4:
		var j := (i + 1) % 4
		var quad := [bot[i], bot[j], top[j], top[i]]
		var mid: Vector3 = (quad[0] + quad[1]) * 0.5
		var n := Vector3(mid.x - block.get_center().x, 0.0, mid.z - block.get_center().y).normalized()
		n = (n + Vector3.UP * 0.6).normalized()
		for idx in quad_order(quad, n):
			a.v.append(quad[idx])
			a.n.append(n)
	if grassy:
		var g := _plat_arrays(_grass, Vector3(block.get_center().x, 0, block.get_center().y))
		var gy := y0 + h + 0.02
		var q := [Vector3(x0 + 3.5, gy, z0 + 3.5), Vector3(x1 - 3.5, gy, z0 + 3.5), Vector3(x1 - 3.5, gy, z1 - 3.5), Vector3(x0 + 3.5, gy, z1 - 3.5)]
		for idx in quad_order(q, Vector3.UP):
			g.v.append(q[idx])
			g.n.append(Vector3.UP)
	var cs := CollisionShape3D.new()
	var cp := ConvexPolygonShape3D.new()
	cp.points = PackedVector3Array(top + bot)
	cs.shape = cp
	add_shape(cs, Vector3(block.get_center().x, 0, block.get_center().y))


func _flush_platforms() -> void:
	for pair in [[_plat, sidewalk_mat], [_grass, grass_mat]]:
		for k in pair[0]:
			var d: Dictionary = pair[0][k]
			if d.v.is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = d.v
			arr[Mesh.ARRAY_NORMAL] = d.n
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = pair[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


func _y() -> float:
	return CityMap.LAND + 0.14


func _towers(inner: Rect2, c: Vector2) -> void:
	# distance to downtown core boosts height
	var core := Vector2(80, 180)
	var f := clampf(1.0 - c.distance_to(core) / 450.0, 0.1, 1.0)
	var podium_h := rng.randf_range(8.0, 16.0)
	var col := Color(0.55, 0.57, 0.6).lerp(Color(0.85, 0.83, 0.8), rng.randf())
	add_building(Vector3(inner.get_center().x, _y(), inner.get_center().y), Vector3(inner.size.x, podium_h, inner.size.y), col, 2 if rng.randf() < 0.5 else 4, rng.randf())
	var n := 1 if inner.size.x < 60 else rng.randi_range(1, 2)
	for i in n:
		var w := rng.randf_range(22.0, minf(inner.size.x / n, 45.0))
		var d := rng.randf_range(22.0, minf(inner.size.y, 45.0))
		var cx := inner.position.x + (i + 0.5) * inner.size.x / n + rng.randf_range(-3, 3)
		var cz := inner.get_center().y + rng.randf_range(-(inner.size.y - d) * 0.4, (inner.size.y - d) * 0.4)
		var h := rng.randf_range(40.0, 90.0) + f * f * rng.randf_range(40.0, 170.0)
		var glass := Color(0.2, 0.25, 0.3).lerp(Color(0.6, 0.62, 0.66), rng.randf())
		var acc := rng.randf_range(0.45, 0.6) if rng.randf() < 0.6 else rng.randf()
		add_building(Vector3(cx, _y() + podium_h, cz), Vector3(w, h, d), glass, 0, acc)
		# setback crown
		if rng.randf() < 0.6:
			add_building(Vector3(cx, _y() + podium_h + h, cz), Vector3(w * 0.7, h * rng.randf_range(0.1, 0.25), d * 0.7), glass, 0, acc)
		if rng.randf() < 0.5:
			add_building(Vector3(cx, _y() + podium_h + h, cz), Vector3(3, 1.2, 3), Color(0.5, 0.5, 0.5), 6)


func _deco(inner: Rect2, hotel_i: int) -> int:
	# row of art deco hotels facing the long edges of the block
	var along_z := inner.size.y > inner.size.x
	var length := inner.size.y if along_z else inner.size.x
	var depth := inner.size.x if along_z else inner.size.y
	var pos := 0.0
	while pos < length - 10.0:
		var w := minf(rng.randf_range(16.0, 30.0), length - pos)
		for side in [0, 1]:
			var dd := depth * 0.5 - 1.0
			var h := rng.randf_range(9.0, 18.0)
			var col: Color = PASTELS[rng.randi() % PASTELS.size()]
			var acc = [0.9, 0.5, 0.83, 0.12, 0.55][rng.randi() % 5] + rng.randf_range(-0.03, 0.03)
			var cx: float
			var cz: float
			if along_z:
				cx = inner.position.x + (dd * 0.5 if side == 0 else depth - dd * 0.5)
				cz = inner.position.y + pos + w * 0.5
				add_building(Vector3(cx, _y(), cz), Vector3(dd, h, w - 1.0), col, 1, acc)
			else:
				cx = inner.position.x + pos + w * 0.5
				cz = inner.position.y + (dd * 0.5 if side == 0 else depth - dd * 0.5)
				add_building(Vector3(cx, _y(), cz), Vector3(w - 1.0, h, dd), col, 1, acc)
			# decorative tower element
			if rng.randf() < 0.4:
				add_building(Vector3(cx, _y() + h, cz), Vector3(4.0, rng.randf_range(3.0, 7.0), 4.0), col, 1, acc)
			# neon hotel sign on the street side
			if rng.randf() < 0.55:
				var face := Vector3.ZERO
				if along_z:
					face = Vector3(-1 if side == 0 else 1, 0, 0)
				else:
					face = Vector3(0, 0, -1 if side == 0 else 1)
				var sign_pos := Vector3(cx, _y() + h - 2.2, cz) + face * ((dd if along_z else dd) * 0.5 + 0.15)
				neon_signs.append({"pos": sign_pos, "face": face, "text": HOTEL_NAMES[hotel_i % HOTEL_NAMES.size()], "hue": acc})
				hotel_i += 1
		pos += w
	return hotel_i


func _condos(inner: Rect2) -> void:
	var beachside := inner.get_center().x > 990.0
	var n := 2 if inner.size.y > 70 else 1
	for i in n:
		var d := inner.size.y / n
		var cz := inner.position.y + (i + 0.5) * d
		var h := rng.randf_range(35.0, 110.0) if beachside else rng.randf_range(12.0, 35.0)
		var col: Color = [Color(0.95, 0.95, 0.93), Color(0.9, 0.88, 0.82), Color(0.85, 0.93, 0.95)][rng.randi() % 3]
		add_building(Vector3(inner.get_center().x, _y(), cz), Vector3(inner.size.x * rng.randf_range(0.6, 0.9), h, d * 0.75), col, 4, rng.randf_range(0.45, 0.58))


func _lowrise(inner: Rect2) -> void:
	_row_parcels(inner, 10.0, 18.0, 5.0, 12.0, CUBA, 2)


func _midrise(inner: Rect2) -> void:
	if rng.randf() < 0.45:
		var h := rng.randf_range(25.0, 70.0)
		add_building(Vector3(inner.get_center().x, _y(), inner.get_center().y), Vector3(inner.size.x * 0.8, h, inner.size.y * 0.7),
			Color(0.9, 0.9, 0.88), 4 if rng.randf() < 0.6 else 0, rng.randf_range(0.4, 0.6))
	else:
		_row_parcels(inner, 18.0, 30.0, 10.0, 26.0, PASTELS, 2)


func _warehouses(inner: Rect2) -> void:
	var n := rng.randi_range(1, 3)
	for i in n:
		var w := inner.size.x / n
		var cx := inner.position.x + (i + 0.5) * w
		var h := rng.randf_range(7.0, 14.0)
		var col: Color = [Color(0.6, 0.35, 0.3), Color(0.55, 0.55, 0.55), Color(0.7, 0.68, 0.6), Color(0.4, 0.45, 0.5)][rng.randi() % 4]
		add_building(Vector3(cx, _y(), inner.get_center().y), Vector3(w - 3.0, h, inner.size.y * rng.randf_range(0.7, 0.95)), col, 3, rng.randf())


func _suburb(inner: Rect2) -> void:
	# houses around the perimeter with lawns
	var houses_x := int(inner.size.x / 26.0)
	var houses_z := int(inner.size.y / 26.0)
	for i in houses_x:
		for side in [0, 1]:
			var cx := inner.position.x + (i + 0.5) * inner.size.x / houses_x
			var cz := inner.position.y + (9.0 if side == 0 else inner.size.y - 9.0)
			_house(Vector3(cx, _y(), cz))
	for j in range(1, houses_z - 1):
		for side in [0, 1]:
			var cz := inner.position.y + (j + 0.5) * inner.size.y / houses_z
			var cx := inner.position.x + (9.0 if side == 0 else inner.size.x - 9.0)
			_house(Vector3(cx, _y(), cz))
	# a palm or two in the middle
	add_prop(["palm_short", "palm_bend", "tree_default"][rng.randi() % 3], Vector3(inner.get_center().x, _y(), inner.get_center().y), rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.4)


func _house(p: Vector3) -> void:
	var w := rng.randf_range(10.0, 14.0)
	var d := rng.randf_range(9.0, 12.0)
	var h := rng.randf_range(3.2, 6.5)
	var col: Color = [Color(0.95, 0.93, 0.85), Color(0.98, 0.85, 0.75), Color(0.8, 0.9, 0.85), Color(0.95, 0.9, 0.7), Color(0.85, 0.85, 0.95)][rng.randi() % 5]
	add_building(p, Vector3(w, h, d), col, 5, rng.randf())
	# roof
	add_roof(Transform3D(Basis().scaled(Vector3(w + 0.8, rng.randf_range(1.5, 2.5), d + 0.8)), p + Vector3.UP * h))
	if rng.randf() < 0.5:
		add_prop("bush", p + Vector3(w * 0.5 + 1.5, 0, 0), rng.randf() * TAU, 1.0)


func _park(inner: Rect2) -> void:
	var n := int(inner.size.x * inner.size.y / 250.0)
	for i in n:
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), _y(), rng.randf_range(inner.position.y, inner.end.y))
		var k: String = ["palm_tall", "palm_detail", "tree_oak", "palm_short", "bush", "tree_default"][rng.randi() % 6]
		add_prop(k, p, rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.4 if not k.begins_with("bush") else 0.0)
	for i in n / 3:
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), _y(), rng.randf_range(inner.position.y, inner.end.y))
		add_prop("bench", p, rng.randf() * TAU, 1.0)


func _row_parcels(inner: Rect2, wmin: float, wmax: float, hmin: float, hmax: float, palette: Array, style: int) -> void:
	var along_z := inner.size.y > inner.size.x
	var length := inner.size.y if along_z else inner.size.x
	var depth := inner.size.x if along_z else inner.size.y
	var pos := 0.0
	while pos < length - 6.0:
		var w := minf(rng.randf_range(wmin, wmax), length - pos)
		for side in [0, 1]:
			var dd := minf(depth * 0.5 - 1.0, rng.randf_range(12.0, 24.0))
			var h := rng.randf_range(hmin, hmax)
			var col: Color = palette[rng.randi() % palette.size()]
			var acc := rng.randf()
			if along_z:
				var cx := inner.position.x + (dd * 0.5 if side == 0 else depth - dd * 0.5)
				add_building(Vector3(cx, _y(), inner.position.y + pos + w * 0.5), Vector3(dd, h, w - 0.6), col, style, acc)
			else:
				var cz := inner.position.y + (dd * 0.5 if side == 0 else depth - dd * 0.5)
				add_building(Vector3(inner.position.x + pos + w * 0.5, _y(), cz), Vector3(w - 0.6, h, dd), col, style, acc)
		pos += w


# ------------------------------------------------------------------ street props
func _build_street_props() -> void:
	for e in city.edges:
		var a: Vector3 = city.nodes[e.a]
		var b: Vector3 = city.nodes[e.b]
		if e.bridge or e.kind in ["highway", "rural"]:
			continue
		var d := Vector3(b.x - a.x, 0, b.z - a.z)
		var L := d.length()
		if L < 20.0:
			continue
		var fd := d / L
		var side := Vector3(-fd.z, 0, fd.x)
		var off: float = e.width * 0.5 + 1.2
		var district := city.district_at((a.x + b.x) * 0.5, (a.z + b.z) * 0.5)
		var t := 15.0
		var k := 0
		while t < L - 15.0:
			var p := a + fd * t
			for sgn in [-1.0, 1.0]:
				var sp = p + side * off * sgn
				sp.y = _y()
				if city.land_sdf(sp.x, sp.z) < 3.0:
					continue
				if k % 2 == 0:
					add_prop("streetlight", sp, atan2(side.x * sgn, side.z * sgn), 1.0, 0.25)
					streetlights.append(sp + Vector3.UP * 7.0)
				elif district in ["ocean_beach", "downtown", "brickell", "vice_beach_n"] or (e.kind == "avenue" and rng.randf() < 0.7):
					add_prop(["palm_tall", "palm_detail", "palm_pm"][rng.randi() % 3], sp, rng.randf() * TAU, rng.randf_range(0.85, 1.15), 0.35)
				elif district in ["little_cuba", "west_vice", "north_vice"] and rng.randf() < 0.4:
					add_prop(["tree_default", "palm_short", "tree_oak"][rng.randi() % 3], sp, rng.randf() * TAU, rng.randf_range(0.7, 1.0), 0.35)
				if district in ["ocean_beach", "downtown", "little_cuba"] and rng.randf() < 0.12:
					add_prop("bench", sp + fd * 4.0, atan2(side.x * sgn, side.z * sgn) + PI, 1.0)
				elif rng.randf() < 0.06:
					add_prop("bin", sp + fd * 3.0, rng.randf() * TAU, 1.0)
			t += 22.0
			k += 1
	# Ocean Drive beach promenade palms (east of x=1030 road)
	var z := 190.0
	while z < 990.0:
		var p := Vector3(1030.0 + 7.0 + 3.0, _y(), z)
		add_prop(["palm_tall", "palm_detail", "palm_bend", "palm_pm"][rng.randi() % 4], p, rng.randf() * TAU, rng.randf_range(0.9, 1.3), 0.35)
		palms_sites.append(p)
		z += rng.randf_range(9.0, 14.0)
