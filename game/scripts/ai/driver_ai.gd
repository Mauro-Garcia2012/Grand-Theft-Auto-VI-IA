class_name DriverAI
extends RefCounted
## Lane-following traffic driver + police pursuit (A* over the road graph, then direct chase).

enum M { CRUISE, PANIC, PURSUIT, PARKED }

var h: Humanoid
var v: Vehicle
var mode := M.CRUISE
var from_node := -1
var to_node := -1
var next_node := -1
var speed_limit := 13.0
var reverse_t := 0.0
var stuck_t := 0.0
var panic_t := 0.0
var path: PackedVector3Array
var path_i := 0
var repath_t := 0.0
var target: Node3D = null
var honk_t := 0.0
var _blocked_t := 0.0


func _init(p_h: Humanoid, p_v: Vehicle) -> void:
	h = p_h
	v = p_v


func setup_on_edge(a: int, b: int) -> void:
	from_node = a
	to_node = b
	next_node = _pick_next(a, b)


func _pick_next(a: int, b: int) -> int:
	var c := Game.city
	var nb: Array = c.adj[b]
	var choices: Array = []
	for n in nb:
		if n != a:
			choices.append(n)
	if choices.is_empty():
		return a
	# prefer going straight
	var dir = (c.nodes[b] - c.nodes[a])
	dir.y = 0
	dir = dir.normalized()
	var best: int = choices[randi() % choices.size()]
	if randf() < 0.55:
		var bd := -2.0
		for n in choices:
			var d2: Vector3 = c.nodes[n] - c.nodes[b]
			d2.y = 0
			var dt = dir.dot(d2.normalized())
			if dt > bd:
				bd = dt
				best = n
	return best


func panic(from: Node) -> void:
	if mode == M.PURSUIT:
		return
	mode = M.PANIC
	panic_t = randf_range(10.0, 18.0)
	if from != null and v.horn == false:
		honk_t = 1.0


func start_pursuit(t: Node3D) -> void:
	mode = M.PURSUIT
	target = t
	repath_t = 0.0
	v.siren_on = v.def.get("siren", false)


func _lane_point(a: Vector3, b: Vector3, width: float) -> Array:
	var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var right := Vector3(-d.z, 0, d.x) * -1.0   # right-hand traffic
	right = Vector3(-d.z, 0, d.x)
	# Godot: forward d, right = d x up
	right = d.cross(Vector3.UP).normalized()
	var off := width * 0.25
	return [a + right * off, b + right * off, d]


func update(delta: float) -> void:
	if v == null or not is_instance_valid(v) or v.destroyed:
		return
	honk_t = maxf(0.0, honk_t - delta)
	v.horn = honk_t > 0.0 and honk_t < 0.6
	match mode:
		M.CRUISE, M.PANIC:
			_cruise(delta)
		M.PURSUIT:
			_pursue(delta)
		M.PARKED:
			v.throttle = 0.0
			v.brake = 1.0


func _drive_to(p: Vector3, want_speed: float, delta: float) -> void:
	var gt := v.global_transform
	var local := gt.affine_inverse() * p
	var ang := atan2(-local.x, -local.z)      # positive = target to the left
	var spd := v.forward_speed
	if reverse_t > 0.0:
		reverse_t -= delta
		v.throttle = -0.7
		v.steer_input = -signf(ang)
		v.brake = 0.0
		v.handbrake = false
		return
	v.steer_input = clampf(ang * 2.0, -1.0, 1.0)
	# slow for sharp turns
	var turn_factor := clampf(1.0 - absf(ang) / 1.2, 0.25, 1.0)
	var target_speed := want_speed * turn_factor
	# obstacle check ahead
	var obstacle := _obstacle_distance(spd)
	if obstacle < INF:
		target_speed = minf(target_speed, maxf(0.0, (obstacle - 5.0) * 0.8))
	if spd < target_speed - 0.5:
		v.throttle = clampf((target_speed - spd) * 0.4, 0.2, 1.0)
		v.brake = 0.0
	elif spd > target_speed + 1.0:
		v.throttle = 0.0
		v.brake = clampf((spd - target_speed) * 0.25, 0.1, 1.0)
	else:
		v.throttle = 0.15
		v.brake = 0.0
	v.handbrake = false
	# stuck handling
	if v.throttle > 0.3 and absf(spd) < 0.6 and obstacle == INF:
		stuck_t += delta
		if stuck_t > 2.5:
			stuck_t = 0.0
			reverse_t = 1.4
	else:
		stuck_t = maxf(0.0, stuck_t - delta)
	if obstacle < 8.0 and absf(spd) < 0.5:
		_blocked_t += delta
		if _blocked_t > 3.0 and honk_t <= 0.0:
			honk_t = 0.8
			_blocked_t = 0.0
		if _blocked_t > 6.0 and mode == M.PANIC:
			reverse_t = 1.0
	else:
		_blocked_t = 0.0


func _obstacle_distance(spd: float) -> float:
	var gt := v.global_transform
	var fwd := -gt.basis.z
	var from := gt.origin + Vector3.UP * 0.8 + fwd * (v.body_size.z * 0.5 + 0.3)
	var look := clampf(4.0 + spd * 1.3, 5.0, 38.0)
	var ex: Array = [v]
	var hit := Combat.raycast(from, from + fwd * look, ex, Game.LAYER_VEHICLE | Game.LAYER_CHAR | Game.LAYER_WORLD)
	if hit.is_empty():
		# second ray slightly towards the steering direction
		var sdir := fwd.rotated(Vector3.UP, v.steer_angle)
		hit = Combat.raycast(from, from + sdir * look * 0.7, ex, Game.LAYER_VEHICLE | Game.LAYER_CHAR)
	if hit.is_empty():
		return INF
	var col = hit.collider
	if mode == M.PURSUIT and target != null and (col == target or (target is Humanoid and col == target.vehicle)):
		return INF
	if mode == M.PANIC and col is Humanoid:
		return INF   # panicking drivers run people over
	return from.distance_to(hit.position)


func _cruise(delta: float) -> void:
	var c := Game.city
	if from_node < 0 or to_node < 0:
		var n = c.nearest_node(v.global_position, 300.0)
		if n < 0:
			return
		var nb: Array = c.adj[n]
		if nb.is_empty():
			return
		setup_on_edge(n, nb[randi() % nb.size()])
	var a: Vector3 = c.nodes[from_node]
	var b: Vector3 = c.nodes[to_node]
	var e = c.edge_between(from_node, to_node)
	var w: float = e.get("width", 14.0)
	var lane := _lane_point(a, b, w)
	var la: Vector3 = lane[0]
	var lb: Vector3 = lane[1]
	var pos := v.global_position
	# progress along segment
	var ab := lb - la
	var t := clampf((pos - la).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
	var seg_len := ab.length()
	var look := 7.0 + absf(v.forward_speed) * 0.6
	var target_p: Vector3
	var remaining := (1.0 - t) * seg_len
	if remaining < look and next_node >= 0:
		# blend into next segment
		var nx: Vector3 = c.nodes[next_node]
		var e2 = c.edge_between(to_node, next_node)
		var lane2 := _lane_point(b, nx, e2.get("width", 14.0))
		target_p = (lane2[0] as Vector3).lerp(lane2[1], clampf((look - remaining) / maxf((lane2[1] - lane2[0]).length(), 1.0), 0.0, 1.0))
	else:
		target_p = la.lerp(lb, clampf(t + look / maxf(seg_len, 1.0), 0.0, 1.0))
	if remaining < 4.0 or t >= 0.999:
		from_node = to_node
		to_node = next_node
		next_node = _pick_next(from_node, to_node)
	var limit := 11.0 if e.get("kind", "street") == "street" else 17.0
	if e.get("kind", "") in ["highway", "causeway"]:
		limit = 22.0
	if mode == M.PANIC:
		limit *= 1.7
		panic_t -= delta
		if panic_t <= 0.0:
			mode = M.CRUISE
	# slow down before a sharp turn at the next node
	if next_node >= 0 and remaining < 25.0:
		var d1 := (b - a)
		d1.y = 0
		var d2: Vector3 = c.nodes[next_node] - b
		d2.y = 0
		if d1.normalized().dot(d2.normalized()) < 0.5:
			limit = minf(limit, 7.0 + remaining * 0.3)
	_drive_to(target_p, limit, delta)


func _pursue(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		mode = M.CRUISE
		v.siren_on = false
		return
	var tp: Vector3 = target.global_position
	if target is Humanoid and target.vehicle:
		tp = target.vehicle.global_position
	var dist := v.global_position.distance_to(tp)
	var los := Combat.raycast(v.global_position + Vector3.UP * 1.5, tp + Vector3.UP * 1.0, [v, target, target.vehicle if target is Humanoid else null], Game.LAYER_WORLD).is_empty()
	if dist < 45.0 and los:
		# direct chase / ram
		var lead := tp
		if target is Humanoid and target.vehicle:
			lead = tp + target.vehicle.linear_velocity * 0.5
		var spd := 28.0 if dist > 15.0 else maxf(4.0, dist)
		if not (target is Humanoid and target.vehicle) and dist < 12.0:
			spd = 0.0
		_drive_to(lead, spd, delta)
		return
	repath_t -= delta
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 2.0
		path = Game.city.find_path(v.global_position, tp)
		path_i = 0
	if path.size() < 2:
		_drive_to(tp, 25.0, delta)
		return
	while path_i < path.size() - 1 and v.global_position.distance_to(path[path_i]) < 12.0:
		path_i += 1
	var p := path[path_i]
	# lane offset
	if path_i > 0:
		var d := (path[path_i] - path[path_i - 1])
		d.y = 0
		p += d.normalized().cross(Vector3.UP) * 3.0
	_drive_to(p, 26.0, delta)
