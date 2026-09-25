class_name TrafficSignals
extends Node3D
## Traffic lights at the busiest intersections: galvanized mast-arm pole with a Rostock 3DModels
## signal head (CC0), assembled in Blender (assets/props/city/traffic_signal.glb).
## Each signalised node alternates between its N-S and E-W approaches; AI drivers stop on red.
## The pole meshes are chunked MultiMeshes owned by the WorldBuilder; the lamps are small emissive
## spheres in per-area MultiMeshes whose colours are refreshed a few times per second near the camera.

const MODEL := "res://assets/props/city/traffic_signal.glb"
const HEIGHT := 6.8
const CYCLE := 18.0           # seconds for a full N-S + E-W cycle
const AMBER := 2.0
const URBAN := ["downtown", "ocean_beach", "brickell", "little_cuba", "vice_beach_n", "stockyard"]
const AREA := 300.0

static var signals := {}      # node id -> phase offset (s)
static var clock := 0.0

var wb: WorldBuilder
var _areas := {}              # Vector2i -> {mm, lamps: Array[[node, dir(Vector3), slot(0 red,1 amber,2 green)]]}
var _t := 0.0
var _lamp_local: Array = []   # red, amber, green centres (model space, pole base at origin)
var _facing := Vector3.FORWARD
var _pole_local := Vector3.ZERO


static func state(node: int, travel_dir: Vector3) -> int:
	## 0 green, 1 amber, 2 red for a vehicle travelling along travel_dir into `node`; -1 = no signal
	if not signals.has(node):
		return -1
	var ph := fmod(clock + float(signals[node]), CYCLE)
	var ns := absf(travel_dir.z) >= absf(travel_dir.x)
	var half := CYCLE * 0.5
	var t := ph if ns else fmod(ph + half, CYCLE)
	if t < half - AMBER:
		return 0
	if t < half:
		return 1
	return 2


func _process(delta: float) -> void:
	clock += delta
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	for key in _areas:
		var a: Dictionary = _areas[key]
		var c := Vector3((key.x + 0.5) * AREA, 0, (key.y + 0.5) * AREA)
		if Vector2(c.x - cp.x, c.z - cp.z).length() > AREA * 1.6:
			continue
		var mm: MultiMesh = a.mm
		var lamps: Array = a.lamps
		for i in lamps.size():
			var l: Array = lamps[i]
			var s := state(l[0], l[1])
			var slot: int = l[2]
			var on := (slot == 0 and s == 2) or (slot == 1 and s == 1) or (slot == 2 and s == 0)
			mm.set_instance_color(i, _lamp_color(slot, on))


func _lamp_color(slot: int, on: bool) -> Color:
	var c: Color = [Color(1.0, 0.08, 0.05), Color(1.0, 0.65, 0.05), Color(0.1, 1.0, 0.35)][slot]
	return c * 4.0 if on else c * 0.08


func build(p_wb: WorldBuilder) -> void:
	wb = p_wb
	var city := wb.city
	if not _load_model():
		return
	var n_sig := 0
	for n in city.nodes.size():
		var nb: Array = city.adj[n]
		if nb.size() < 3:
			continue
		var p: Vector3 = city.nodes[n]
		if not city.district_at(p.x, p.z) in URBAN:
			continue
		var ok := true
		var width := 0.0
		for m in nb:
			var e: Dictionary = city.edge_between(n, m)
			if e.get("bridge", false) or not e.get("kind", "") in ["street", "avenue"]:
				ok = false
				break
			width = maxf(width, e.get("width", 14.0))
		if not ok:
			continue
		signals[n] = fmod(float(n) * 7.31, CYCLE)
		n_sig += 1
		for m in nb:
			var e: Dictionary = city.edge_between(n, m)
			var d: Vector3 = p - city.nodes[m]
			d.y = 0.0
			d = d.normalized()                          # direction of travel into the intersection
			_place_pole(n, p, d, float(e.get("width", 14.0)), width)
	# lamp multimeshes
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	sphere.material = mat
	for key in _areas:
		var a: Dictionary = _areas[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = sphere
		mm.instance_count = a.xf.size()
		for i in a.xf.size():
			mm.set_instance_transform(i, a.xf[i])
			mm.set_instance_color(i, _lamp_color(a.lamps[i][2], false))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 450.0
		add_child(mmi)
		a.mm = mm
		a.erase("xf")
	print("Traffic signals: %d intersections" % n_sig)


func _place_pole(n: int, center: Vector3, d: Vector3, approach_w: float, cross_w: float) -> void:
	# pole on the near-right corner of the approach, lamps facing the oncoming drivers
	var right := d.cross(Vector3.UP).normalized()
	var pos := center - d * (cross_w * 0.5 + 2.0) + right * (approach_w * 0.5 + 1.3)
	pos.y = CityMap.LAND + 0.1
	# yaw so that the model's lamp facing points against the travel direction
	var want := -d
	var yaw := atan2(want.x, want.z) - atan2(_facing.x, _facing.z)
	var basis := Basis(Vector3.UP, yaw)
	wb.add_prop("traffic_light", pos - basis * _pole_local, yaw, 1.0, 0.25)
	var key := Vector2i(floori(pos.x / AREA), floori(pos.z / AREA))
	if not _areas.has(key):
		_areas[key] = {"xf": [], "lamps": [], "mm": null}
	var a: Dictionary = _areas[key]
	for slot in 3:
		var lp: Vector3 = pos + basis * (_lamp_local[slot] - _pole_local) + want * 0.12
		a.xf.append(Transform3D(Basis(), lp))
		a.lamps.append([n, d, slot])


func _load_model() -> bool:
	var ps: PackedScene = load(MODEL)
	if ps == null:
		return false
	var inst: Node3D = ps.instantiate()
	var parts: Array = []
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != inst:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		parts.append([mi, t])
		var a: AABB = t * mi.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var k := HEIGHT / maxf(aabb.size.y, 0.001)
	var base := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(0, -aabb.position.y * k, 0))
	var out := ArrayMesh.new()
	var lamp_boxes := [AABB(), AABB(), AABB()]
	var lamp_norm := Vector3.ZERO
	var low_pts := PackedVector3Array()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.08)
	for part in parts:
		var mi: MeshInstance3D = part[0]
		var t: Transform3D = base * part[1]
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = t * verts[i]
				if norms.size() > i:
					norms[i] = (t.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ModelUtil.surface_lods(mi.mesh, s, t.basis.get_scale().x))
			var mat := mi.get_active_material(s)
			var mn := ModelUtil.base_name(mat) if mat else ""
			var slot: int = {"red": 0, "yellow": 1, "green": 2, "ampel_rot": 0, "ampel_gelb": 1, "ampel_gruen": 2}.get(mn, -1)
			if slot >= 0:
				var bb := AABB(verts[0], Vector3.ZERO)
				for v in verts:
					bb = bb.expand(v)
				lamp_boxes[slot] = bb
				for nn in norms:
					lamp_norm += nn
				mat = dark
			else:
				for v in verts:
					if v.y < 0.6:
						low_pts.append(v)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	inst.free()
	if low_pts.is_empty():
		return false
	var c := Vector3.ZERO
	for v in low_pts:
		c += v
	_pole_local = c / low_pts.size()
	_pole_local.y = 0.0
	for i in 3:
		_lamp_local.append(lamp_boxes[i].get_center())
	lamp_norm.y = 0.0
	_facing = lamp_norm.normalized() if lamp_norm.length() > 0.01 else Vector3.FORWARD
	wb.prop_meshes["traffic_light"] = out
	return true
