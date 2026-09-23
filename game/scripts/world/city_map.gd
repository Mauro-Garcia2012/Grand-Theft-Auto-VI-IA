class_name CityMap
extends Node
## Layout of "Vice City, Leonida" (inspired by public GTA VI trailer info + real Miami geography).
## X = east, Z = south (north is -Z). Units: meters. Water surface at y = 0, land at y = 1.
## Provides terrain height, districts, the road graph (for traffic, GPS, minimap) and lots for buildings.

const WATER := 0.0
const LAND := 1.0
var water_level := WATER

const MIN_X := -2000.0
const MAX_X := 1700.0
const MIN_Z := -1700.0
const MAX_Z := 2500.0

# --- Land masses: [type, params...]  rect: [x0,z0,x1,z1], circle: [cx,cz,r]
# beach=true: gentle sloped sandy shore; otherwise seawall.
var lands: Array = [
	{"name": "mainland", "rect": Rect2(-1850, -1550, 1850 + 360, 1550 + 1150), "beach": false},
	{"name": "vice_beach", "rect": Rect2(820, -1500, 340, 2500), "beach": true},
	{"name": "starfish", "rect": Rect2(530, 140, 150, 170), "beach": false, "round": 30.0},
	{"name": "port", "rect": Rect2(420, 540, 300, 320), "beach": false},
	{"name": "fisher_island", "rect": Rect2(880, 1060, 180, 140), "beach": true, "round": 50.0},
	{"name": "key_1", "circle": Vector3(80, 1380, 150), "beach": true},
	{"name": "key_2", "circle": Vector3(-260, 1600, 130), "beach": true},
	{"name": "key_3", "circle": Vector3(-620, 1800, 170), "beach": true},
	{"name": "key_4", "circle": Vector3(-1010, 1990, 140), "beach": true},
	{"name": "key_5", "circle": Vector3(-1380, 2200, 190), "beach": true},
]

# --- Districts (for building style, population, radio, names on HUD)
var districts: Array = [
	{"id": "ocean_beach", "name": "Ocean Beach", "rect": Rect2(820, 150, 340, 900), "style": "deco", "block": 90.0, "ped": 1.4, "gang": ""},
	{"id": "vice_beach_n", "name": "Vice Beach Norte", "rect": Rect2(820, -1500, 340, 1650), "style": "condo", "block": 110.0, "ped": 1.0, "gang": ""},
	{"id": "downtown", "name": "Downtown Vice City", "rect": Rect2(-250, -160, 610, 700), "style": "tower", "block": 100.0, "ped": 1.3, "gang": ""},
	{"id": "stockyard", "name": "Stockyard", "rect": Rect2(-250, -1100, 610, 940), "style": "warehouse", "block": 110.0, "ped": 0.8, "gang": "gang_purple"},
	{"id": "little_cuba", "name": "Little Cuba", "rect": Rect2(-900, -160, 650, 860), "style": "lowrise", "block": 85.0, "ped": 1.2, "gang": "gang_green"},
	{"id": "west_vice", "name": "West Vice", "rect": Rect2(-900, -1100, 650, 940), "style": "suburb", "block": 110.0, "ped": 0.7, "gang": ""},
	{"id": "brickell", "name": "Brickell Bay", "rect": Rect2(-900, 540, 1260, 560), "style": "midrise", "block": 100.0, "ped": 1.0, "gang": ""},
	{"id": "north_vice", "name": "North Vice", "rect": Rect2(-900, -1550, 1260, 450), "style": "suburb", "block": 120.0, "ped": 0.6, "gang": ""},
	{"id": "airport", "name": "Aeropuerto Int. de Vice City", "rect": Rect2(-1850, -1550, 950, 1650), "style": "airport", "block": 0.0, "ped": 0.2, "gang": ""},
	{"id": "grassrivers", "name": "Grassrivers", "rect": Rect2(-1850, 100, 950, 1050), "style": "swamp", "block": 0.0, "ped": 0.1, "gang": ""},
	{"id": "starfish", "name": "Starfish Island", "rect": Rect2(530, 140, 150, 170), "style": "mansion", "block": 0.0, "ped": 0.4, "gang": ""},
	{"id": "port", "name": "Puerto de Vice City", "rect": Rect2(420, 540, 300, 320), "style": "port", "block": 0.0, "ped": 0.3, "gang": ""},
	{"id": "fisher", "name": "Fisher Island", "rect": Rect2(880, 1060, 180, 140), "style": "mansion", "block": 0.0, "ped": 0.3, "gang": ""},
	{"id": "keys", "name": "Cayos de Leonida", "rect": Rect2(-1600, 1200, 1900, 1250), "style": "keys", "block": 0.0, "ped": 0.4, "gang": ""},
]

# --- Road network
var nodes: Array[Vector3] = []          # road graph nodes (x, y, z)
var adj: Array = []                      # Array[Array[int]]
var edges: Array = []                    # {a, b, width, lanes, kind, bridge}
var _node_index := {}                    # grid-key -> node id (merging)
var lots: Array = []                     # {rect: Rect2, district, height_hint}
var parks: Array = []                    # Rect2
var bridges: Array = []                  # edge ids that are bridges
var landmarks: Array = []                # {name, pos, kind}
var spawn_points := {}                   # name -> Vector3


func _init() -> void:
	_build_roads()


# ------------------------------------------------------------------ geometry
func land_sdf(x: float, z: float) -> float:
	## Signed distance to land (positive inside land).
	var best := -99999.0
	for l in lands:
		var d: float
		if l.has("circle"):
			var c: Vector3 = l.circle
			d = c.z - Vector2(x - c.x, z - c.y).length()
			# irregular coast
			d += sin(x * 0.03) * 8.0 + cos(z * 0.027) * 8.0
		else:
			var r: Rect2 = l.rect
			var rr: float = l.get("round", 12.0)
			var cx := r.position.x + r.size.x * 0.5
			var cz := r.position.y + r.size.y * 0.5
			var qx := absf(x - cx) - (r.size.x * 0.5 - rr)
			var qz := absf(z - cz) - (r.size.y * 0.5 - rr)
			var outside := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()
			d = -(outside + minf(maxf(qx, qz), 0.0) - rr)
			if l.name == "vice_beach":
				d += sin(z * 0.011) * 6.0
		if d > best:
			best = d
	return best


func is_beach(x: float, z: float) -> bool:
	# east coast of Vice Beach + keys + fisher island
	if x > 1040.0 and z > -1500.0 and z < 1000.0:
		return true
	for l in lands:
		if l.get("beach", false) and l.has("circle"):
			var c: Vector3 = l.circle
			if Vector2(x - c.x, z - c.y).length() < c.z + 40.0:
				return true
	if x > 860.0 and z > 1040.0 and z < 1220.0:
		return true
	return false


func height_at(x: float, z: float) -> float:
	var sd := land_sdf(x, z)
	var d := district_at(x, z)
	if d == "grassrivers" and sd > 0.0:
		# swamp: mostly just above water with channels
		var n := sin(x * 0.021) * cos(z * 0.018) + sin(x * 0.047 + z * 0.031) * 0.5
		return 0.25 + n * 0.55 + clampf(sd / 200.0, 0.0, 0.3)
	if sd >= 0.0:
		if is_beach(x, z):
			# sandy slope up to land level over ~70m
			return lerpf(0.2, LAND, clampf(sd / 70.0, 0.0, 1.0))
		return LAND
	# under water
	if is_beach(x, z):
		return lerpf(0.2, -6.0, clampf(-sd / 90.0, 0.0, 1.0))
	return lerpf(-3.5, -9.0, clampf(-sd / 60.0, 0.0, 1.0))


func surface_at(x: float, z: float) -> int:
	## 0 grass, 1 sand, 2 concrete/urban, 3 swamp, 4 tarmac(airport)
	var d := district_at(x, z)
	var h := height_at(x, z)
	if is_beach(x, z) and h < LAND - 0.02:
		return 1
	if d == "grassrivers":
		return 3
	if d == "airport":
		return 4
	if d in ["downtown", "stockyard", "port", "ocean_beach", "little_cuba", "brickell"]:
		return 2
	return 0


func district_at(x: float, z: float) -> String:
	# small islands first (they overlap bigger rects)
	for dd in districts:
		if dd.id in ["starfish", "port", "fisher"] and (dd.rect as Rect2).has_point(Vector2(x, z)):
			return dd.id
	for dd in districts:
		if (dd.rect as Rect2).has_point(Vector2(x, z)):
			return dd.id
	return "ocean"


func district_info(id: String) -> Dictionary:
	for dd in districts:
		if dd.id == id:
			return dd
	return {"id": "ocean", "name": "Océano Atlántico", "style": "", "ped": 0.0, "gang": ""}


# ------------------------------------------------------------------ road graph
func _key(p: Vector3) -> String:
	return "%d_%d" % [roundi(p.x / 4.0), roundi(p.z / 4.0)]


func add_node(p: Vector3) -> int:
	var k := _key(p)
	if _node_index.has(k):
		return _node_index[k]
	nodes.append(p)
	adj.append([])
	_node_index[k] = nodes.size() - 1
	return nodes.size() - 1


func add_edge(a: int, b: int, width: float, lanes: int, kind := "street", bridge := false) -> void:
	if a == b or b in adj[a]:
		return
	adj[a].append(b)
	adj[b].append(a)
	edges.append({"a": a, "b": b, "width": width, "lanes": lanes, "kind": kind, "bridge": bridge})
	if bridge:
		bridges.append(edges.size() - 1)


func add_road(points: Array, width: float, lanes: int, kind := "street", bridge := false, subdivide := 0.0) -> void:
	## polyline road; long segments optionally subdivided (for ramps / curves)
	var ids: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		if i > 0 and subdivide > 0.0:
			var prev: Vector3 = points[i - 1]
			var n := int(prev.distance_to(p) / subdivide)
			for s in range(1, n):
				ids.append(add_node(prev.lerp(p, float(s) / n)))
		ids.append(add_node(p))
	for i in range(1, ids.size()):
		add_edge(ids[i - 1], ids[i], width, lanes, kind, bridge)


func _grid_lines(xs: Array, zs: Array, wide_x: Array, wide_z: Array, W: float, A: float) -> void:
	## Street grid from explicit line coordinates (keeps districts connected).
	for x in xs:
		var pts: Array = []
		for z in zs:
			pts.append(Vector3(x, LAND, z))
		var wide: bool = x in wide_x
		add_road(pts, A if wide else W, 4 if wide else 2, "avenue" if wide else "street")
	for z in zs:
		var pts: Array = []
		for x in xs:
			pts.append(Vector3(x, LAND, z))
		var wide: bool = z in wide_z
		add_road(pts, A if wide else W, 4 if wide else 2, "avenue" if wide else "street")
	for xi in range(xs.size() - 1):
		for zi in range(zs.size() - 1):
			var r := Rect2(xs[xi], zs[zi], xs[xi + 1] - xs[xi], zs[zi + 1] - zs[zi])
			var wx0: float = (A if xs[xi] in wide_x else W)
			var wx1: float = (A if xs[xi + 1] in wide_x else W)
			var wz0: float = (A if zs[zi] in wide_z else W)
			var wz1: float = (A if zs[zi + 1] in wide_z else W)
			lots.append({"rect": r, "inset": [wx0 * 0.5, wz0 * 0.5, wx1 * 0.5, wz1 * 0.5]})


func _build_roads() -> void:
	var W := 14.0   # standard street width (2 lanes + parking)
	var A := 22.0   # avenue / boulevard
	# --- Mainland grid (Downtown, Stockyard, Little Cuba, West Vice, Brickell, North Vice)
	var mxs := [-900, -820, -740, -660, -580, -500, -420, -340, -250, -150, -50, 50, 150, 250, 340]
	var mzs := [-1500, -1400, -1300, -1200, -1100, -990, -880, -776, -660, -550, -440, -330, -240, -150, -60, 30, 120, 210, 300, 432, 530, 632, 740, 850, 950, 1050]
	_grid_lines(mxs, mzs, [-900, -250, 340], [-776, -150, 432, 632], W, A)
	# --- Vice Beach island: Washington (870), Collins (950), Ocean Drive (1030)
	var bxs := [870, 950, 1030]
	var bzs := [-1440, -1340, -1240, -1140, -1040, -940, -860, -776, -690, -600, -510, -420, -330, -240, -150, -60, 30, 120, 210, 300, 420, 500, 580, 660, 740, 820, 900, 990]
	_grid_lines(bxs, bzs, [950], [-776, -150, 420], W, A)
	# --- Arterials / highways
	# Airport road (E-W at z=-600)
	add_road([Vector3(-900, LAND, -550), Vector3(-1250, LAND, -550), Vector3(-1250, LAND, -300)], A, 4, "avenue", false, 60.0)
	# Swamp road towards Grassrivers (south-west)
	add_road([Vector3(-900, LAND, 850), Vector3(-1150, LAND, 800), Vector3(-1400, LAND, 700), Vector3(-1700, LAND, 900)], W, 2, "rural", false, 50.0)
	# --- Causeways (bridges over the bay) at 6m, with ramps
	var H := 7.0
	# North causeway z=-760 from x=340 -> 870
	add_road([Vector3(340, LAND, -776), Vector3(400, H, -776), Vector3(810, H, -776), Vector3(870, LAND, -776)], A, 4, "causeway", true, 30.0)
	# Central causeway z=-150 from Downtown -> Vice Beach
	add_road([Vector3(340, LAND, -150), Vector3(400, H, -150), Vector3(810, H, -150), Vector3(870, LAND, -150)], A, 4, "causeway", true, 30.0)
	# MacArthur-like causeway via Starfish Island
	add_road([Vector3(340, LAND, 432), Vector3(400, H, 432), Vector3(500, H, 425), Vector3(560, LAND, 400)], A, 4, "causeway", true, 25.0)
	add_road([Vector3(560, LAND, 400), Vector3(650, LAND, 400)], A, 4, "avenue")
	add_road([Vector3(650, LAND, 400), Vector3(700, H, 420), Vector3(810, H, 420), Vector3(870, LAND, 420)], A, 4, "causeway", true, 25.0)
	# Starfish island loop
	add_road([Vector3(560, LAND, 400), Vector3(560, LAND, 170), Vector3(650, LAND, 170), Vector3(650, LAND, 400)], 10.0, 2, "street")
	# Port bridge z=620 from x=340 -> 420
	add_road([Vector3(340, LAND, 632), Vector3(360, 4.0, 632), Vector3(410, 4.0, 632), Vector3(430, LAND, 632)], A, 4, "causeway", true, 12.0)
	add_road([Vector3(430, LAND, 632), Vector3(700, LAND, 632)], A, 4, "avenue", false, 60.0)
	add_road([Vector3(560, LAND, 632), Vector3(560, LAND, 840)], W, 2, "street", false, 60.0)
	# Fisher island ferry road (bridge from south beach)
	add_road([Vector3(950, LAND, 990), Vector3(950, 3.0, 1020), Vector3(950, 3.0, 1060), Vector3(950, LAND, 1090), Vector3(950, LAND, 1170)], W, 2, "causeway", true, 12.0)
	# --- Overseas highway to the Keys (from Brickell south edge)
	var keys_pts := [Vector3(-50, LAND, 1050), Vector3(-60, LAND, 1140), Vector3(-40, 5.0, 1200), Vector3(40, 5.0, 1260),
		Vector3(80, LAND, 1330), Vector3(40, LAND, 1440), Vector3(-80, 5.0, 1500), Vector3(-200, 5.0, 1540),
		Vector3(-260, LAND, 1580), Vector3(-350, LAND, 1650), Vector3(-430, 5.0, 1690), Vector3(-520, 5.0, 1740),
		Vector3(-620, LAND, 1790), Vector3(-760, LAND, 1850), Vector3(-840, 5.0, 1900), Vector3(-930, 5.0, 1950),
		Vector3(-1010, LAND, 1990), Vector3(-1120, LAND, 2050), Vector3(-1200, 5.0, 2100), Vector3(-1290, 5.0, 2150),
		Vector3(-1380, LAND, 2200), Vector3(-1450, LAND, 2260)]
	var prev_land := true
	for i in range(1, keys_pts.size()):
		var a: Vector3 = keys_pts[i - 1]
		var b: Vector3 = keys_pts[i]
		var over_water := land_sdf((a.x + b.x) * 0.5, (a.z + b.z) * 0.5) < 0.0 or a.y > LAND + 0.5 or b.y > LAND + 0.5
		add_road([a, b], A * 0.8, 2, "highway", over_water, 25.0)
	# Airport runway & taxiway (not drivable graph but lots)
	landmarks.append({"name": "Pista 09/27", "pos": Vector3(-1450, LAND, -900), "kind": "runway"})
	# --- landmarks / spawn points
	spawn_points["ocean_drive"] = Vector3(1042, LAND + 0.2, 560)
	spawn_points["hospital_beach"] = Vector3(990, LAND + 0.2, -300)
	spawn_points["hospital_downtown"] = Vector3(-120, LAND + 0.2, 380)
	spawn_points["police_beach"] = Vector3(990, LAND + 0.2, 100)
	spawn_points["police_cuba"] = Vector3(-520, LAND + 0.2, 200)
	spawn_points["keys_motel"] = Vector3(-620, LAND + 0.2, 1810)
	# parks (lots converted to green)
	parks = [Rect2(-240, 239, 97, 97), Rect2(-560, 90, 80, 80), Rect2(870, -600, 160, 120), Rect2(-880, 631, 101, 101)]


var _grid_index := {}
const GRID_CELL := 200.0


func _build_grid_index() -> void:
	_grid_index.clear()
	for i in nodes.size():
		var k := Vector2i(floori(nodes[i].x / GRID_CELL), floori(nodes[i].z / GRID_CELL))
		if not _grid_index.has(k):
			_grid_index[k] = PackedInt32Array()
		_grid_index[k].append(i)


func nearest_node(p: Vector3, max_d := 1e9) -> int:
	if _grid_index.is_empty():
		_build_grid_index()
	var best := -1
	var bd := max_d * max_d
	var c := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
	for r in 4:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var arr = _grid_index.get(c + Vector2i(dx, dz))
				if arr == null:
					continue
				for i in arr:
					var d := Vector2(nodes[i].x - p.x, nodes[i].z - p.z).length_squared()
					if d < bd:
						bd = d
						best = i
		if best >= 0 and sqrt(bd) < r * GRID_CELL:
			return best
	if best < 0 and max_d > 800.0:
		for i in nodes.size():
			var d := Vector2(nodes[i].x - p.x, nodes[i].z - p.z).length_squared()
			if d < bd:
				bd = d
				best = i
	return best


var _edge_index := {}


func edge_between(a: int, b: int) -> Dictionary:
	if _edge_index.is_empty():
		for e in edges:
			_edge_index[Vector2i(mini(e.a, e.b), maxi(e.a, e.b))] = e
	return _edge_index.get(Vector2i(mini(a, b), maxi(a, b)), {})


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	## A* over the road graph (GPS / police) with a binary heap.
	var s := nearest_node(from)
	var g := nearest_node(to)
	var out := PackedVector3Array()
	if s < 0 or g < 0:
		return out
	var n := nodes.size()
	var gs := PackedFloat32Array()
	gs.resize(n)
	gs.fill(INF)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	gs[s] = 0.0
	var heap_f := PackedFloat32Array([nodes[s].distance_to(nodes[g])])
	var heap_n := PackedInt32Array([s])
	var goal := nodes[g]
	while heap_n.size() > 0:
		# pop min
		var cur := heap_n[0]
		var last := heap_n.size() - 1
		heap_n[0] = heap_n[last]
		heap_f[0] = heap_f[last]
		heap_n.resize(last)
		heap_f.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			if l >= last:
				break
			var r := l + 1
			var m := l if r >= last or heap_f[l] <= heap_f[r] else r
			if heap_f[m] >= heap_f[i]:
				break
			var tf := heap_f[i]
			heap_f[i] = heap_f[m]
			heap_f[m] = tf
			var tn := heap_n[i]
			heap_n[i] = heap_n[m]
			heap_n[m] = tn
			i = m
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		if cur == g:
			var k := g
			while k >= 0:
				out.append(nodes[k])
				k = came[k]
			out.reverse()
			return out
		var pc := nodes[cur]
		for nb in adj[cur]:
			if closed[nb] == 1:
				continue
			var t := gs[cur] + pc.distance_to(nodes[nb])
			if t < gs[nb]:
				gs[nb] = t
				came[nb] = cur
				# push
				heap_n.append(nb)
				heap_f.append(t + nodes[nb].distance_to(goal))
				var j := heap_n.size() - 1
				while j > 0:
					var pj := (j - 1) / 2
					if heap_f[pj] <= heap_f[j]:
						break
					var tf2 := heap_f[pj]
					heap_f[pj] = heap_f[j]
					heap_f[j] = tf2
					var tn2 := heap_n[pj]
					heap_n[pj] = heap_n[j]
					heap_n[j] = tn2
					j = pj
	return out


func road_height_at(x: float, z: float) -> float:
	## Height of a bridge deck near x,z if any (else -INF)
	var best := -INF
	for ei in bridges:
		var e: Dictionary = edges[ei]
		var a: Vector3 = nodes[e.a]
		var b: Vector3 = nodes[e.b]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(x - a.x, z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := (ap - ab * t).length()
		if d < e.width * 0.5 + 1.0:
			best = maxf(best, lerpf(a.y, b.y, t))
	return best
