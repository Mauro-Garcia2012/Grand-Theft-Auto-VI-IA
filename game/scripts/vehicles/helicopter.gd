class_name Helicopter
extends Aircraft
## Arcade helicopter (FlightGear Bell 407 / EC135 models with the main rotor split out in Blender).
## - the rotor spools up after boarding; lift needs it at speed
## - auto-hover: with no input it holds position and height
## - W/S forward/back, A/D strafe, Space climb, C/Ctrl descend, heading follows the camera
## - tilts into the direction of acceleration, skids on the ground, crash damage, autorotation fall
## Reuses Aircraft's occupants, damage, explosion, water/bounds checks and HUD fields.

var lift_input := 0.0        # +1 climb, -1 descend
var rotor_rpm := 0.0         # 0..1
var _rotor: Node3D
var _fuselage_h := 2.0


func _ready() -> void:
	def = VehicleDB.get_def(def_id)
	add_to_group("vehicles")
	add_to_group("aircraft")
	collision_layer = Game.LAYER_VEHICLE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	mass = float(def.mass)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.05
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 2.0
	continuous_cd = true
	can_sleep = true
	health = float(def.get("health", 1300.0))
	# model: nose towards -Z, skids on y = 0
	var m := ModelUtil.make(def.src, float(def.length), def.get("recolor", {}))
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	m.rotation.y = {"+z": PI, "+x": PI * 0.5, "-x": -PI * 0.5}.get(def.get("front", "-z"), 0.0)
	model_root.add_child(m)
	_rotor = m.find_child("rotor", true, false)
	var a := ModelUtil.mesh_aabb(m)
	body_size = a.size
	var L := body_size.z
	_fuselage_h = body_size.y
	# collision: cabin, tail boom and a flat skid pad
	_add_box(Vector3(1.9, _fuselage_h * 0.5, L * 0.36), Vector3(0, _fuselage_h * 0.42, -L * 0.1))
	_add_box(Vector3(0.6, 0.7, L * 0.42), Vector3(0, _fuselage_h * 0.5, L * 0.28))
	_add_box(Vector3(2.1, 0.2, 2.8), Vector3(0, 0.1, -L * 0.08))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, _fuselage_h * 0.35, -L * 0.08)
	_seat_offsets = [Transform3D(Basis(), Vector3(-0.45, _fuselage_h * 0.28, -L * 0.2)), Transform3D(Basis(), Vector3(0.45, _fuselage_h * 0.28, -L * 0.2))]
	_engine_snd = AudioStreamPlayer3D.new()
	_engine_snd.stream = Sfx.get_stream("engine")
	_engine_snd.unit_size = 16.0
	_engine_snd.max_distance = 500.0
	_engine_snd.volume_db = -4.0
	add_child(_engine_snd)


func add_occupant(hm: Node, s: int) -> void:
	occupants[s] = hm
	if s == 0:
		engine_on = true
		sleeping = false
		_engine_snd.play()
		if hm is Humanoid and hm.is_player:
			Game.msg("Helicóptero: Espacio subir · C bajar · W/S adelante/atrás · A/D lateral · la cámara marca el rumbo · F saltar", 7.0)


func get_exit_position(s: int) -> Vector3:
	var side := -1.0 if s % 2 == 0 else 1.0
	if airborne:
		return global_position + global_basis.x * side * 2.5 - global_basis.y * 1.0
	return global_transform * Vector3(side * 2.0, 0.3, -body_size.z * 0.15)


func _physics_process(delta: float) -> void:
	var drv := driver()
	if sleeping and drv == null and rotor_rpm <= 0.0:
		return
	var gb := global_basis
	var v := linear_velocity
	speed_kmh = v.length() * 3.6
	forward_speed = v.dot(-gb.z)
	_age += delta
	# crash detection (hitting buildings or the ground hard)
	var dv := (v - _prev_v).length()
	if dv > 9.0 and not destroyed and _age > 0.5:
		take_damage((dv - 9.0) * 120.0, null)
		Sfx.play_at("crash", global_position, 2.0, 0.7)
		if Game.camera_rig and drv != null and drv.is_player:
			Game.camera_rig.shake(0.8)
	_prev_v = v
	# rotor spool: up with a pilot aboard, slowly down without one
	var want_rpm := 1.0 if drv != null and not destroyed and fuel > 0.0 else 0.0
	rotor_rpm = move_toward(rotor_rpm, want_rpm, delta * (0.3 if want_rpm > rotor_rpm else 0.12))
	power = rotor_rpm
	if drv != null:
		fuel = maxf(0.0, fuel - rotor_rpm * delta * 0.0005)
	var alt := _update_altitude(delta)
	_check_water_and_bounds(drv, v.length())
	airborne = alt > 1.3
	stalled = false
	var eff := clampf((rotor_rpm - 0.55) / 0.45, 0.0, 1.0)
	if destroyed or eff <= 0.0:
		_update_heli_fx(delta)
		return
	# desired velocity in the heading frame
	var fwd := Vector3(-gb.z.x, 0.0, -gb.z.z).normalized()
	var right := Vector3(gb.x.x, 0.0, gb.x.z).normalized()
	var top: float = float(def.get("top", 60.0))
	var target := fwd * throttle * (top if throttle > 0.0 else top * 0.3) + right * (-steer_input) * 14.0
	target.y = lift_input * (9.0 if lift_input > 0.0 else 7.0)
	if drv == null:
		target = Vector3(0, -4.0, 0)      # pilotless: settle down
	var acc := (target - v) * Vector3(0.9, 2.2, 0.9)
	var h_acc := Vector2(acc.x, acc.z).limit_length(7.5)
	acc = Vector3(h_acc.x, clampf(acc.y, -6.0, 8.0), h_acc.y)
	# sitting on the ground without asking to climb: don't fight gravity
	if not airborne and lift_input <= 0.0 and target.y <= 0.0:
		acc.y = minf(acc.y, 0.0)
		acc.x *= 0.1
		acc.z *= 0.1
	apply_central_force((Vector3.UP * G + acc) * mass * eff)
	# attitude: lean into the acceleration, nose to the camera heading
	var pitch_t := clampf(-acc.dot(fwd) * 0.055, -0.38, 0.3)
	var roll_t := clampf(-acc.dot(right) * 0.06, -0.45, 0.45)
	var yaw_t := atan2(-fwd.x, -fwd.z)
	if drv != null and aim_dir != Vector3.ZERO and (airborne or target.length() > 0.5 or lift_input > 0.0):
		yaw_t = atan2(-aim_dir.x, -aim_dir.z)
	var tb := Basis.from_euler(Vector3(pitch_t, yaw_t, roll_t))
	var q := (tb * gb.orthonormalized().inverse()).get_rotation_quaternion()
	var ang := q.get_angle()
	if ang > PI:
		ang -= TAU
	var w := q.get_axis() * ang * 2.4 if absf(ang) > 0.0001 else Vector3.ZERO
	w.y = clampf(w.y, -1.1, 1.1)
	if airborne or lift_input > 0.0:
		angular_velocity = angular_velocity.lerp(w, clampf(delta * 4.0 * eff, 0.0, 1.0))
	_update_heli_fx(delta)


func _update_heli_fx(delta: float) -> void:
	if _rotor:
		_rotor.rotate_object_local(Vector3.UP, rotor_rpm * 32.0 * delta)
	if _engine_snd.playing:
		_engine_snd.pitch_scale = 0.4 + rotor_rpm * 0.7
		_engine_snd.volume_db = lerpf(-14.0, 0.0, rotor_rpm)
		if driver() == null and rotor_rpm <= 0.02:
			_engine_snd.stop()
			engine_on = false
