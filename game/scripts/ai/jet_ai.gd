class_name JetAI
extends Node
## Air force fighter at 6 stars: it lines up on the player from a distance, dives in a strafing run
## firing its 30 mm cannon (small explosive shells walking towards the target), pulls up and comes
## round again. When the chase ends it climbs away and disappears.

const SPEED := 150.0             # m/s (540 km/h)
const CRUISE_ALT := 330.0        # above the tallest towers downtown (~260 m)

var leaving := false
var _dir := Vector3.ZERO           # flight direction held by the autopilot
var _phase := "approach"
var _t := 0.0
var _fire_t := 0.0
var _leave_t := 0.0
var _shot := 0


func _physics_process(delta: float) -> void:
	var ac: Aircraft = get_parent()
	if ac == null or ac.destroyed or ac.active_driver() == null:
		if ac:
			ac.gravity_scale = 1.0     # shot down: real physics from here on
		return
	ac.gravity_scale = 0.0
	var pos := ac.global_position
	var pp := Game.player_pos()
	var fwd := -ac.global_basis.z
	var flat := Vector3(pp.x - pos.x, 0.0, pp.z - pos.z)
	var dist := flat.length()
	var ground := maxf(pp.y, 0.0)
	var target: Vector3
	_t += delta
	if leaving:
		_leave_t += delta
		target = pos + Vector3(fwd.x, 0, fwd.z).normalized() * 800.0
		target.y = ground + 400.0
		if _leave_t > 25.0:
			for o in ac.occupants.duplicate():
				if o != null and is_instance_valid(o):
					o.queue_free()
			ac.queue_free()
			return
	else:
		match _phase:
			"approach":
				# get lined up from far away, high enough to dive
				target = pp + Vector3.UP * CRUISE_ALT
				if dist > 900.0 and dist < 1700.0 and fwd.dot(flat.normalized()) > 0.95:
					_phase = "attack"
					_t = 0.0
				elif dist < 900.0:
					# too close to dive: fly away first
					target = pos - flat.normalized() * 600.0
					target.y = ground + CRUISE_ALT
			"attack":
				target = pp + Vector3.UP * 2.0
				var to := (pp + Vector3.UP - (pos + fwd * 12.0)).normalized()
				if fwd.dot(to) > 0.975 and dist < 950.0:
					_fire_t -= delta
					if _fire_t <= 0.0:
						_fire_t = 0.09
						_cannon(ac, pos + fwd * 12.0, to)
				if dist < 320.0 or ac.altitude < 110.0 or _t > 14.0:
					_phase = "pullup"
					_t = 0.0
			"pullup":
				target = pos + Vector3(fwd.x, 0, fwd.z).normalized() * 600.0
				target.y = ground + CRUISE_ALT + 40.0
				if _t > 8.0:
					_phase = "approach"
					_t = 0.0
	# fly there: the autopilot turns the velocity towards the target at a limited rate (the flight
	# model only takes over again if the jet is shot down or loses its pilot)
	var to_t := target - pos
	var hd := Vector2(to_t.x, to_t.z).length()
	var max_dive := 0.6 if _phase == "attack" else 0.2
	var want := Vector3(to_t.x, 0, to_t.z).normalized() if hd > 1.0 else Vector3(fwd.x, 0, fwd.z).normalized()
	want.y = clampf(to_t.y / maxf(hd, 150.0), -max_dive, 0.4)
	# never fly into the ground or a tower: look ahead along the flight path and climb
	if not leaving:
		# rays from the nose and both wing tips (6 s ahead, 2.5 s in a strafing dive, when the ground
		# ahead is the whole point) and one aimed below the flight path
		var attacking := _phase == "attack"
		var ahead := ac.linear_velocity * (2.5 if attacking else 6.0)
		var right := ac.global_basis.x * 9.0
		var obstacle := false
		for o in [Vector3.ZERO, right, -right, Vector3.DOWN * 25.0]:
			if not Combat.raycast(pos + o, pos + o + ahead, [ac], Game.LAYER_WORLD).is_empty():
				obstacle = true
				break
		if not attacking:
			obstacle = obstacle or not Combat.raycast(pos, pos + ahead * 0.6 + Vector3.DOWN * 140.0, [ac], Game.LAYER_WORLD).is_empty()
		if obstacle or ac.altitude < 110.0:
			want = Vector3(fwd.x, 0, fwd.z).normalized()
			want.y = 0.5
			if _phase == "attack":
				_phase = "pullup"
				_t = 0.0
	want = want.normalized()
	if _dir == Vector3.ZERO:
		_dir = ac.linear_velocity.normalized() if ac.linear_velocity.length() > 10.0 else fwd
	# turn level (yaw) and climb/dive (pitch) separately: interpolating the whole direction would
	# loop over the top or bottom when turning round
	var yaw := atan2(-_dir.x, -_dir.z)
	var pitch := asin(clampf(_dir.y, -1.0, 1.0))
	var want_yaw := atan2(-want.x, -want.z)
	var want_pitch := asin(clampf(want.y, -1.0, 1.0))
	var dyaw := wrapf(want_yaw - yaw, -PI, PI)
	var yaw_step := clampf(dyaw, -deg_to_rad(28.0) * delta, deg_to_rad(28.0) * delta)
	yaw += yaw_step
	pitch = move_toward(pitch, want_pitch, deg_to_rad(22.0) * delta)
	_dir = Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	var nd := _dir
	ac.linear_velocity = nd * SPEED
	# attitude: nose along the flight path, banked into the turn
	var turn := clampf(dyaw * 1.5, -1.1, 1.1)
	var target_b := Basis.looking_at(nd, Vector3.UP).rotated(nd, -turn)
	var q := (target_b * ac.global_basis.orthonormalized().inverse()).get_rotation_quaternion()
	var a := q.get_angle()
	if a > PI:
		a -= TAU
	ac.angular_velocity = q.get_axis() * a * 5.0 if absf(a) > 0.0001 else Vector3.ZERO
	ac.power = 1.0


func _cannon(ac: Aircraft, from: Vector3, dir: Vector3) -> void:
	var pilot: Node = ac.driver()
	dir = Combat.apply_spread(dir, 1.6 * Game.by_difficulty([1.6, 1.0, 0.8, 0.6]))
	Sfx.play_at("rifle", from, 6.0, 0.6)
	var hit := Combat.raycast(from, from + dir * 900.0, [ac, pilot])
	if hit.is_empty():
		return
	var col = hit.collider
	if col is Humanoid:
		col.take_damage(45.0, pilot, hit.position, dir, "bullet")
	_shot += 1
	if _shot % 2 == 0:
		Combat.explosion(hit.position, 3.5, 60.0, pilot)
	else:
		Game.effects.impact(hit.position, hit.normal, "concrete")
	Game.effects.tracer(from, hit.position)
