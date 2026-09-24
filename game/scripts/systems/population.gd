class_name Population
extends Node
## Spawns/despawns pedestrians, gang members, beach-goers, traffic, parked cars and boats around the player.

const PED_RADIUS := 110.0
const PED_DESPAWN := 160.0
const CAR_RADIUS := 230.0
const CAR_DESPAWN := 300.0

var max_peds := 34
var max_traffic := 20
var max_parked := 10
var max_boats := 5
var peds: Array = []
var traffic: Array = []
var parked: Array = []
var boats: Array = []
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _t_car := 0.0
var density := 1.0


func _ready() -> void:
	if Game.mobile:
		max_peds = 18
		max_traffic = 12
		max_parked = 6
		max_boats = 3
	Game.population = self
	rng.randomize()


func _physics_process(delta: float) -> void:
	if Game.player == null:
		return
	_t -= delta
	_t_car -= delta
	if _t <= 0.0:
		_t = 0.35
		var t0 := Time.get_ticks_usec()
		_cleanup()
		_spawn_peds()
		_prof("peds", t0)
	if _t_car <= 0.0:
		_t_car = 0.5
		var t1 := Time.get_ticks_usec()
		_spawn_traffic()
		_prof("traffic", t1)
		t1 = Time.get_ticks_usec()
		_spawn_parked()
		_prof("parked", t1)
		t1 = Time.get_ticks_usec()
		_spawn_boats()
		_prof("boats", t1)


var _prof_log := ""
func _prof(what: String, t0: int) -> void:
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_prof_log += "%s=%.0f " % [what, ms]
	if what == "traffic" and ms > 300.0:
		print("[population] breakdown: ", _prof_log)
	if what in ["traffic", "peds"]:
		_prof_log = ""
	if ms > 25.0 and OS.is_debug_build():
		print("[population] slow %s: %.1f ms" % [what, ms])


func _cam_forward() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return -cam.global_basis.z if cam else Vector3.FORWARD


func _visible_spot(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var to := p - cam.global_position
	var d := to.length()
	if d < 25.0:
		return true
	return _cam_forward().dot(to / d) > 0.55 and d < 90.0


func _cleanup() -> void:
	var pp := Game.player_pos()
	for list in [peds]:
		for i in range(list.size() - 1, -1, -1):
			var h = list[i]
			if not is_instance_valid(h):
				list.remove_at(i)
				continue
			var d: float = h.global_position.distance_to(pp)
			var dead_long: bool = h.dead and Time.get_ticks_msec() / 1000.0 - h.death_time > 25.0
			if (d > PED_DESPAWN and h.vehicle == null) or dead_long or h.global_position.y < -20.0:
				if h in Game.protagonists:
					list.remove_at(i)
					continue
				list.remove_at(i)
				h.queue_free()
	for i in range(traffic.size() - 1, -1, -1):
		var v = traffic[i]
		if not is_instance_valid(v):
			traffic.remove_at(i)
			continue
		var d: float = v.global_position.distance_to(pp)
		var player_used: bool = v.last_driver != null and v.last_driver.is_player
		if player_used:
			traffic.remove_at(i)
			continue
		if d > CAR_DESPAWN or v.global_position.y < -15.0 or (v.destroyed and d > 120.0):
			_free_vehicle(v)
			traffic.remove_at(i)
	for list in [parked, boats]:
		for i in range(list.size() - 1, -1, -1):
			var v = list[i]
			if not is_instance_valid(v):
				list.remove_at(i)
				continue
			if v.driver() != null and v.driver().is_player:
				list.remove_at(i)
				continue
			if v.global_position.distance_to(pp) > CAR_DESPAWN + 50.0:
				_free_vehicle(v)
				list.remove_at(i)


func _free_vehicle(v: Node) -> void:
	for o in v.occupants:
		if o != null and is_instance_valid(o) and not o.is_player and not o in Game.protagonists:
			peds.erase(o)
			o.queue_free()
		elif o != null and is_instance_valid(o):
			o.exit_vehicle()
	v.queue_free()


func _random_sidewalk_point(min_d: float, max_d: float) -> Dictionary:
	var c := Game.city
	var pp := Game.player_pos()
	for attempt in 12:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(min_d, max_d)
		var p := pp + Vector3(cos(ang), 0, sin(ang)) * dist
		var n = c.nearest_node(p, 120.0)
		if n < 0:
			continue
		var nb: Array = c.adj[n]
		if nb.is_empty():
			continue
		var m: int = nb[rng.randi() % nb.size()]
		var e = c.edge_between(n, m)
		if e.get("bridge", false) or e.get("kind", "") in ["highway", "rural"]:
			continue
		var a: Vector3 = c.nodes[n]
		var b: Vector3 = c.nodes[m]
		var t := rng.randf_range(0.25, 0.75)
		var q := a.lerp(b, t)
		var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		q += Vector3(-d.z, 0, d.x) * side * (e.width * 0.5 + 1.8)
		q.y = CityMap.LAND + 0.3
		if q.distance_to(pp) < min_d * 0.8:
			continue
		if _visible_spot(q) and q.distance_to(pp) < 70.0:
			continue
		if c.land_sdf(q.x, q.z) < 2.0:
			continue
		return {"pos": q, "a": n, "b": m}
	return {}


func _spawn_peds() -> void:
	var pp := Game.player_pos()
	var dist_id = Game.city.district_at(pp.x, pp.z)
	var info = Game.city.district_info(dist_id)
	var dens: float = float(info.get("ped", 0.5)) * density
	var night: bool = Game.sky and Game.sky.is_night()
	var target := int(max_peds * clampf(dens, 0.1, 1.4) * (0.6 if night else 1.0))
	var alive := 0
	for h in peds:
		if is_instance_valid(h) and not h.dead:
			alive += 1
	if alive >= target:
		return
	var sp := _random_sidewalk_point(35.0, PED_RADIUS)
	if sp.is_empty():
		return
	var pos: Vector3 = sp.pos
	var d = Game.city.district_at(pos.x, pos.z)
	var dinfo = Game.city.district_info(d)
	var gang: String = dinfo.get("gang", "")
	if gang != "" and rng.randf() < 0.35:
		_spawn_gang_group(pos, gang)
		return
	var gender := "male" if rng.randf() < 0.5 else "female"
	var kind := ""
	var beach = d in ["ocean_beach", "vice_beach_n"] and rng.randf() < 0.3
	if beach:
		kind = "bikini" if gender == "female" else "beach"
	elif d in ["downtown", "brickell"] and rng.randf() < 0.35:
		kind = "business" if rng.randf() < 0.7 else "suit_white"
	elif d == "ocean_beach" and rng.randf() < 0.4:
		kind = "hawaiian"
	var h := spawn_ped(pos, gender, kind)
	h.brain.start_wander()
	if beach:
		# some sunbathe on the sand
		var bp := Vector3(rng.randf_range(1065, 1120), 0, pos.z)
		bp.y = Game.world.builder.height_grid(bp.x, bp.z) + 0.2
		if bp.y > 0.35 and not _visible_spot(bp):
			h.global_position = bp
			h.brain.state = PedBrain.S.BEACH
			h.brain.idle_anim = ["Sitting_Idle", "Idle_FoldArms", "Dance", "Idle_TalkingPhone"][rng.randi() % 4]
	if rng.randf() < 0.06 and not night:
		h.give_weapon("pistol", 24)


func spawn_ped(pos: Vector3, gender: String, kind := "", team := "civilian") -> Humanoid:
	var h := Humanoid.new()
	h.team = team
	Game.world.add_child(h)
	var outfit := CharacterModel.pick_outfit(gender, kind, rng)
	h.setup(gender, outfit, "", gender == "male" and rng.randf() < 0.3)
	h.global_position = pos
	h.rotation.y = rng.randf() * TAU
	h.money_carried = rng.randi_range(0, 80)
	var b := PedBrain.new()
	b.name = "Brain"
	h.add_child(b)
	h.brain = b
	peds.append(h)
	return h


func _spawn_gang_group(pos: Vector3, gang: String) -> void:
	var outfit_kind := "gang_purple" if gang == "gang_purple" else "gang_green"
	var n := rng.randi_range(2, 4)
	var anims := ["Idle_FoldArms", "Idle_Talking", "Dance", "Idle_TalkingPhone", "Idle"]
	for i in n:
		var g := "male" if rng.randf() < 0.75 else "female"
		var h := spawn_ped(pos + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), g, outfit_kind, gang)
		h.max_health = 120.0
		h.health = 120.0
		h.give_weapon(["pistol", "smg", "pistol", "shotgun", "revolver", "knife", "bat", "assault_shotgun"][rng.randi() % 8], 60)
		h.select_weapon(1)
		h.brain.start_idle(anims[rng.randi() % anims.size()])
		h.brain.t = 999.0
		h.face_target = pos
		h.brain.aggressive = true


func spawn_cop(pos: Vector3, swat := false) -> Humanoid:
	var g := "male" if rng.randf() < 0.75 else "female"
	var h := spawn_ped(pos, g, "swat" if swat else "police", "police")
	h.max_health = 150.0 if swat else 110.0
	h.health = h.max_health
	h.armor = 50.0 if swat else 0.0
	h.give_weapon("carbine" if swat else ("shotgun" if rng.randf() < 0.2 else "pistol"), 200)
	h.select_weapon(1)
	h.brain.aggressive = true
	return h


# ------------------------------------------------------------------ traffic
func _spawn_traffic() -> void:
	var alive := 0
	for v in traffic:
		if is_instance_valid(v) and not v.destroyed:
			alive += 1
	var pp := Game.player_pos()
	var d = Game.city.district_at(pp.x, pp.z)
	var dens := 0.5 if d in ["airport", "grassrivers", "keys", "port"] else 1.0
	if Game.sky and Game.sky.is_night():
		dens *= 0.7
	if alive >= int(max_traffic * dens * density):
		return
	var t0 := Time.get_ticks_usec()
	var sp := _random_lane_point(70.0, CAR_RADIUS)
	_prof("lane point", t0)
	if sp.is_empty():
		return
	var id := VehicleDB.random_traffic(rng)
	if rng.randf() < 0.06:
		id = "p_police"
	var v := spawn_traffic_car(id, sp.pos, sp.yaw, sp.a, sp.b)
	if v and v.def.get("kind", "") == "police":
		v.get_meta("driver").team = "police"


func spawn_traffic_car(id: String, pos: Vector3, yaw: float, a: int, b: int, team := "civilian") -> Vehicle:
	var t0 := Time.get_ticks_usec()
	var v: Vehicle = VehicleDB.spawn(id, pos, yaw)
	_prof("vehicle " + id, t0)
	v.ai_owned = true
	var g := "male" if rng.randf() < 0.6 else "female"
	var kind := ""
	if v.def.get("kind", "") == "police":
		kind = "police"
		team = "police"
	elif v.def.get("kind", "") == "taxi":
		kind = "tee"
	t0 = Time.get_ticks_usec()
	var drv := spawn_ped(pos + Vector3.UP * 2.0, g, kind, team)
	_prof("driver", t0)
	if team == "police":
		drv.give_weapon("pistol", 100)
		drv.select_weapon(1)
	t0 = Time.get_ticks_usec()
	drv.enter_vehicle(v, 0)
	_prof("enter", t0)
	t0 = Time.get_ticks_usec()
	var ai := DriverAI.new(drv, v)
	ai.setup_on_edge(a, b)
	_prof("ai", t0)
	drv.brain.driver_ai = ai
	drv.brain.state = PedBrain.S.DRIVE
	v.set_meta("driver", drv)
	v.linear_velocity = -v.global_basis.z * 8.0
	traffic.append(v)
	return v


func _random_lane_point(min_d: float, max_d: float) -> Dictionary:
	var c := Game.city
	var pp := Game.player_pos()
	for attempt in 10:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(min_d, max_d)
		var p := pp + Vector3(cos(ang), 0, sin(ang)) * dist
		var n = c.nearest_node(p, 150.0)
		if n < 0:
			continue
		var nb: Array = c.adj[n]
		if nb.is_empty():
			continue
		var m: int = nb[rng.randi() % nb.size()]
		var e = c.edge_between(n, m)
		var a: Vector3 = c.nodes[n]
		var b: Vector3 = c.nodes[m]
		if a.distance_to(b) < 30.0:
			continue
		var t := rng.randf_range(0.3, 0.6)
		var q := a.lerp(b, t)
		var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var right := d.cross(Vector3.UP).normalized()
		q += right * e.width * 0.25
		q.y += 0.9
		if q.distance_to(pp) < min_d:
			continue
		if _visible_spot(q) and q.distance_to(pp) < 110.0:
			continue
		var clear := true
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v.global_position.distance_to(q) < 12.0:
				clear = false
				break
		if not clear:
			continue
		return {"pos": q, "yaw": atan2(-d.x, -d.z), "a": n, "b": m}
	return {}


func _spawn_parked() -> void:
	var alive := 0
	for v in parked:
		if is_instance_valid(v):
			alive += 1
	if alive >= max_parked:
		return
	var sp := _random_lane_point(60.0, 170.0)
	if sp.is_empty():
		return
	var c := Game.city
	var e = c.edge_between(sp.a, sp.b)
	if e.get("kind", "") != "street":
		return
	var a: Vector3 = c.nodes[sp.a]
	var b: Vector3 = c.nodes[sp.b]
	var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var right := d.cross(Vector3.UP).normalized()
	var pos: Vector3 = sp.pos + right * (e.width * 0.5 - 1.8 - e.width * 0.25)
	var id := VehicleDB.random_traffic(rng)
	if VehicleDB.get_def(id).get("length", 5.0) > 6.5:
		id = "p_sedan"    # no buses or trucks parked on the kerb
	var v = VehicleDB.spawn(id, pos, sp.yaw)
	parked.append(v)


func _spawn_boats() -> void:
	var docks: Array = Game.world.get_meta("docks", [])
	var alive := 0
	for b in boats:
		if is_instance_valid(b):
			alive += 1
	if alive >= max_boats or docks.is_empty():
		return
	var pp := Game.player_pos()
	for tr in docks:
		var t: Transform3D = tr
		var dist := t.origin.distance_to(pp)
		if dist < 60.0 or dist > 280.0:
			continue
		var taken := false
		for b in boats:
			if is_instance_valid(b) and b.global_position.distance_to(t.origin) < 8.0:
				taken = true
		if taken:
			continue
		var id: String = ["cruiser", "rescue", "cruiser", "sailboat", "yacht"][rng.randi() % 5]
		var boat = VehicleDB.spawn(id, t.origin + Vector3.UP * 0.5, t.basis.get_euler().y)
		boats.append(boat)
		return


# ------------------------------------------------------------------ reactions
func panic_at(pos: Vector3, radius: float, source: Node) -> void:
	for h in peds:
		if not is_instance_valid(h) or h.dead or h.brain == null:
			continue
		if h.team == "police" and source == Game.player:
			h.brain.threat = source
			h.brain.state = PedBrain.S.FIGHT
			h.brain.t = 30.0
			continue
		if h.global_position.distance_to(pos) < radius:
			h.brain.on_gunshot(pos, source)


func bullet_whiz(from: Vector3, to: Vector3, shooter: Node) -> void:
	# people near the bullet line panic
	var seg := to - from
	var L := seg.length()
	if L < 0.1:
		return
	var dir := seg / L
	for h in peds:
		if not is_instance_valid(h) or h.dead or h == shooter or h.brain == null:
			continue
		var rel: Vector3 = h.global_position + Vector3.UP - from
		var t := clampf(rel.dot(dir), 0.0, L)
		if (rel - dir * t).length() < 4.0:
			h.brain.on_gunshot(from, shooter)


func clear_all() -> void:
	for h in peds:
		if is_instance_valid(h):
			h.queue_free()
	peds.clear()
	for v in traffic + parked + boats:
		if is_instance_valid(v):
			_free_vehicle(v)
	traffic.clear()
	parked.clear()
	boats.clear()
