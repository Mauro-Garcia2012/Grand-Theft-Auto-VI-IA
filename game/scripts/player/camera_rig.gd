class_name CameraRig
extends Node3D
## Third-person orbit camera: over-the-shoulder aiming, sniper scope, vehicle chase cam, shake.

var target: Humanoid
var yaw := 0.0
var pitch := -0.15
var camera: Camera3D
var arm: SpringArm3D
var aim_point := Vector3.ZERO
var aim_hit: Dictionary = {}
var scoped := false
var cinematic := false
var _dist := 3.8
var _shoulder := 0.45
var _height := 1.55
var _fov := 70.0
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _idle_mouse := 0.0
var vehicle_view := 1   # 0 near, 1 far, 2 very far
var foot_view := 0      # 0 normal, 1 far


func _ready() -> void:
	Game.camera_rig = self
	top_level = true
	arm = SpringArm3D.new()
	arm.collision_mask = Game.LAYER_WORLD
	arm.margin = 0.25
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.08
	camera.far = 1600.0 if Game.mobile else 4000.0
	arm.add_child(camera)
	_noise.frequency = 2.0


func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func mouse_look(rel: Vector2) -> void:
	var sens: float = Game.settings.mouse_sens * 0.01 * (0.25 if scoped else 1.0) * (0.6 if target and target.aiming else 1.0)
	yaw -= rel.x * sens
	var inv := -1.0 if Game.settings.invert_y else 1.0
	pitch = clampf(pitch - rel.y * sens * inv, -1.35, 1.0)
	_idle_mouse = 0.0


func stick_look(v: Vector2, delta: float) -> void:
	if v.length() < 0.15:
		return
	yaw -= v.x * delta * 2.6
	pitch = clampf(pitch - v.y * delta * 1.8, -1.35, 1.0)
	_idle_mouse = 0.0


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_t += delta
	_idle_mouse += delta
	var v = target.vehicle
	var focus: Vector3
	var want_dist: float
	var want_shoulder := 0.0
	var want_fov: float = Game.settings.fov
	if v != null and is_instance_valid(v):
		var vlen: float = v.body_size.z if "body_size" in v else 5.0
		want_dist = [vlen * 0.9 + 2.5, vlen * 1.15 + 3.5, vlen * 1.6 + 6.0][vehicle_view]
		focus = v.global_position + Vector3.UP * (1.3 + vlen * 0.12)
		# auto align behind the car when driving and the mouse is idle
		var spd: float = v.linear_velocity.length()
		var flying: bool = v is Aircraft and v.airborne
		if _idle_mouse > 1.2 and spd > 4.0 and not target.aiming and not flying:
			var vy: float = v.global_rotation.y
			var fwd_s: float = v.linear_velocity.dot(-v.global_basis.z)
			if fwd_s < -2.0:
				vy += PI
			yaw = lerp_angle(yaw, vy, delta * 2.2)
			pitch = lerpf(pitch, -0.18, delta * 1.5)
		want_fov += clampf(spd * 0.25, 0.0, 14.0)
		if target.aiming:
			want_dist *= 0.75
			want_shoulder = 0.6
		scoped = false
	else:
		var crouch_off := -0.45 if target.crouching else 0.0
		focus = target.global_position + Vector3.UP * (_height + crouch_off)
		want_dist = 3.6 if foot_view == 0 else 6.0
		want_shoulder = 0.45
		scoped = target.aiming and target.current_def().get("scope", false)
		if target.aiming:
			want_dist = 1.7
			want_shoulder = 0.62
			want_fov = Game.settings.fov - 18.0
			if scoped:
				want_fov = 11.0
				want_dist = 0.0
				want_shoulder = 0.0
				focus = target.eye_position()
		if target.dead:
			want_dist = 6.0
			want_shoulder = 0.0
		if target.swimming:
			focus.y = maxf(focus.y, Game.city.water_level + 0.8)
		if target._chute != null:
			# under the parachute: pull back so the canopy is in view
			want_dist = 9.0
			want_shoulder = 0.0
			focus.y += 2.2
	_dist = lerpf(_dist, want_dist, clampf(delta * 8.0, 0.0, 1.0))
	_shoulder = lerpf(_shoulder, want_shoulder, clampf(delta * 8.0, 0.0, 1.0))
	_fov = lerpf(_fov, want_fov, clampf(delta * 10.0, 0.0, 1.0))
	global_position = global_position.lerp(focus, clampf(delta * 25.0, 0.0, 1.0)) if global_position.distance_to(focus) < 20.0 else focus
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = _dist
	arm.position = Vector3(_shoulder, 0, 0)
	var ex: Array[RID] = [target.get_rid()]
	if v != null and is_instance_valid(v):
		ex.append(v.get_rid())
	arm.clear_excluded_objects()
	for r in ex:
		arm.add_excluded_object(r)
	camera.fov = _fov
	# shake
	_trauma = maxf(0.0, _trauma - delta * 1.2)
	var sh := _trauma * _trauma
	camera.h_offset = _noise.get_noise_2d(_t * 30.0, 0.0) * sh * 0.6
	camera.v_offset = _noise.get_noise_2d(0.0, _t * 30.0) * sh * 0.6
	camera.rotation.z = _noise.get_noise_2d(_t * 20.0, 50.0) * sh * 0.1
	# weapon recoil kick
	if target.recoil > 0.0 and target.aiming:
		pitch = minf(pitch + target.recoil * 0.004, 1.0)
	_update_aim(ex)


func _update_aim(ex: Array[RID]) -> void:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 800.0, Game.MASK_BULLET)
	q.exclude = ex
	aim_hit = space.intersect_ray(q)
	var p: Vector3 = aim_hit.position if not aim_hit.is_empty() else from + dir * 800.0
	# don't aim at points behind the character (camera between wall and player)
	aim_point = p
	# mild aim assist toward humanoids near the crosshair (wider with touch controls, also for hip fire)
	if (target.aiming or (Game.touch and Input.is_action_pressed("fire"))) and not scoped:
		var best := 0.985 if Game.touch else 0.9965
		var best_p := Vector3.ZERO
		for h in Game.humanoids():
			if h == target or h.dead or h.team == target.team:
				continue
			var chest: Vector3 = h.global_position + Vector3.UP * 1.25
			var to: Vector3 = chest - from
			var d := to.length()
			if d > 70.0 or d < 1.0:
				continue
			var dt := dir.dot(to / d)
			if dt > best:
				best = dt
				best_p = chest
		if best_p != Vector3.ZERO:
			var d_hit := from.distance_to(aim_hit.position) if not aim_hit.is_empty() else INF
			if from.distance_to(best_p) < d_hit + 1.0:
				aim_point = best_p


func get_look_basis() -> Basis:
	return Basis(Vector3.UP, yaw)
