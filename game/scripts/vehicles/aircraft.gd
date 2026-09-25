class_name Aircraft
extends RigidBody3D
## Arcade flight model for the light aircraft, business jet and airliner.
## - power lever (W/S), lift from angle of attack with a stall, drag, side-slip damping
## - "mouse aim": the plane banks and pitches towards the direction the camera looks
##   (A/D roll directly, and steer the nose wheel on the ground)
## - tricycle landing gear with raycast suspension, wheel brakes, crash damage, explosion
## Shares the seat/occupant/damage interface of Vehicle and Boat.

const G := 9.8

var def_id := "cessna"
var def: Dictionary
var paint := Color(-1, 0, 0)
var throttle := 0.0          # -1..1 input, moves the power lever
var steer_input := 0.0       # +1 = left (roll in the air, nose wheel on the ground)
var brake := 0.0
var handbrake := false
var horn := false
var aim_dir := Vector3.ZERO  # world direction to fly towards (zero = hold attitude)
var occupants: Array = [null, null]
var health := 1400.0
var destroyed := false
var body_size := Vector3(9, 2.5, 8)
var model_root: Node3D
var speed_kmh := 0.0
var forward_speed := 0.0
var fuel := 1.0
var engine_on := false
var ai_owned := false
var persistent := true
var siren_on := false
var lights_on := false
var power := 0.0
var airborne := false
var altitude := 0.0
var stalled := false

var _gear: Array = []        # local gear points (nose, left, right)
var _gear_h := 1.0
var _k_lift := 1.0
var _k_drag := 1.0
var _thrust := 1.0
var _v_stall := 25.0
var _prop: Node3D
var _engine_snd: AudioStreamPlayer3D
var _prev_v := Vector3.ZERO
var _seat_offsets: Array = []
var _smoke: GPUParticles3D
var _alt_t := 0.0
var _age := 0.0
var _fire: GPUParticles3D          # engine fire when badly damaged
var _wreck_boom := false            # the burning wreck already exploded against the ground
var _idle_t := 0.0


func _ready() -> void:
	def = VehicleDB.get_def(def_id)
	add_to_group("vehicles")
	add_to_group("aircraft")
	collision_layer = Game.LAYER_VEHICLE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	mass = float(def.mass)
	# the project's default damping would act as a huge extra drag at flying speeds
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.6
	continuous_cd = true
	can_sleep = true
	health = float(def.get("health", 1400.0))
	# model: nose towards -Z, wheels on y = 0
	var m := ModelUtil.make(def.src, float(def.length), def.get("recolor", {}))
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	m.rotation.y = {"+z": PI, "+x": PI * 0.5, "-x": -PI * 0.5}.get(def.get("front", "-z"), 0.0)
	model_root.add_child(m)
	var a := ModelUtil.mesh_aabb(m)
	body_size = a.size
	var span := body_size.x
	var length := body_size.z
	var h := body_size.y
	if def.has("prop"):
		_prop = m.find_child(def.prop, true, false)
	# flight constants from the def (SI units; tuned for fun rather than realism)
	var v_cruise: float = float(def.cruise)
	_k_lift = mass * G / (0.3 * v_cruise * v_cruise)
	_thrust = mass * float(def.accel)
	_k_drag = _thrust / pow(float(def.top), 2.0)
	_v_stall = sqrt(mass * G / (_k_lift * 1.45))
	# collision: fuselage + wings, lifted so the gear carries the weight
	_gear_h = clampf(h * 0.3, 0.8, 2.6)
	var fw := clampf(span * 0.13, 1.2, 5.5)
	# the fuselage box reaches the cabin roof (so shots through the windscreen can hit the pilot)
	_add_box(Vector3(fw, h * 0.55, length * 0.94), Vector3(0, _gear_h + h * 0.275, 0))
	_add_box(Vector3(span * 0.94, clampf(h * 0.1, 0.25, 1.2), length * 0.16), Vector3(0, _gear_h + h * float(def.get("wing_y", 0.3)), float(def.get("wing_z", 0.0)) * length))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, _gear_h + h * 0.2, 0)
	var gx := clampf(span * 0.16, 1.1, 5.0)
	_gear = [Vector3(0, _gear_h, -length * 0.36), Vector3(-gx, _gear_h, length * 0.06), Vector3(gx, _gear_h, length * 0.06)]
	_seat_offsets = [Transform3D(Basis(), Vector3(-0.3, _gear_h + h * 0.15, -length * 0.3)), Transform3D(Basis(), Vector3(0.3, _gear_h + h * 0.15, -length * 0.3))]
	_engine_snd = AudioStreamPlayer3D.new()
	_engine_snd.stream = Sfx.get_stream("engine")
	_engine_snd.unit_size = 18.0 if def.get("jet", false) else 12.0
	_engine_snd.max_distance = 600.0
	_engine_snd.volume_db = -4.0
	add_child(_engine_snd)


func _add_box(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)


# --------------------------------------------------------------- occupants (Vehicle interface)
func add_occupant(hm: Node, s: int) -> void:
	occupants[s] = hm
	if s == 0:
		engine_on = true
		sleeping = false
		_engine_snd.play()
		if hm is Humanoid and hm.is_player:
			if Game.touch:
				Game.msg("Joystick arriba/abajo potencia · el avión vuela hacia donde mira la cámara · izquierda/derecha alabeo · F saltar", 7.0)
			else:
				Game.msg("W/S potencia · el avión vuela hacia donde mira la cámara · A/D alabeo · Espacio frenos · F saltar en paracaídas", 7.0)


func remove_occupant(hm: Node) -> void:
	for i in occupants.size():
		if occupants[i] == hm:
			occupants[i] = null
			if i == 0:
				throttle = 0.0
				steer_input = 0.0
				aim_dir = Vector3.ZERO


func get_occupant(s: int) -> Node:
	if s < 0 or s >= occupants.size():
		return null
	var o = occupants[s]
	if o != null and not is_instance_valid(o):
		occupants[s] = null
		return null
	return o


func driver() -> Humanoid:
	return get_occupant(0)


## The driver if alive: someone shot dead stays slumped in the seat but no longer drives.
func active_driver() -> Humanoid:
	var d := driver()
	return d if d != null and not d.dead else null


func seat_count() -> int:
	return occupants.size()


func free_seat_for(hm: Node) -> int:
	if destroyed:
		return -1
	if hm is Humanoid and hm.is_player:
		return 0
	for i in occupants.size():
		if get_occupant(i) == null:
			return i
	return -1


func is_enclosed() -> bool:
	return true


func get_seat_transform(s: int) -> Transform3D:
	return global_transform * _seat_offsets[clampi(s, 0, _seat_offsets.size() - 1)]


func get_exit_position(s: int) -> Vector3:
	var side := -1.0 if s % 2 == 0 else 1.0
	if airborne:
		# jump clear of the wing
		return global_position + global_basis.x * side * (body_size.x * 0.5 + 2.0) - global_basis.y * 1.0
	return global_transform * Vector3(side * (clampf(body_size.x * 0.13, 1.2, 5.5) * 0.5 + 1.2), 0.3, -body_size.z * 0.25)


func take_damage(amount: float, attacker: Node = null, _hit := Vector3.ZERO) -> void:
	if destroyed:
		return
	if Game.god_mode and driver() != null and driver().is_player:
		amount *= 0.1
	health -= amount
	sleeping = false
	if health < float(def.get("health", 1400.0)) * 0.4 and _smoke == null:
		_smoke = Game.effects.make_smoke(0.4, 1.2)
		add_child(_smoke)
		_smoke.position = Vector3(0, _gear_h + body_size.y * 0.4, -body_size.z * 0.2)
		_smoke.emitting = true
	if health < float(def.get("health", 1400.0)) * 0.2 and _fire == null:
		# engine on fire: it loses power and the plane comes down
		_fire = Game.effects.make_fire(1.0 + body_size.x * 0.02)
		add_child(_fire)
		_fire.position = Vector3(body_size.x * 0.18, _gear_h + body_size.y * 0.35, -body_size.z * 0.05)
		_fire.emitting = true
	if health <= 0.0:
		explode(attacker)


func explode(attacker: Node = null) -> void:
	if destroyed:
		return
	destroyed = true
	power = 0.0
	for o in occupants.duplicate():
		if o != null and is_instance_valid(o):
			o.exit_vehicle(true)
			o.take_damage(400.0, attacker, o.global_position, Vector3.UP, "explosion")
	Combat.explosion(global_position + Vector3.UP * _gear_h, 10.0 + body_size.x * 0.3, 220.0, attacker)
	if attacker == Game.player:
		SocialFeed.event("shootdown_heli" if self is Helicopter and def_id == "police_heli" else "plane")
	if airborne or altitude > 5.0:
		# blown apart in the air: burning debris and the wreck spinning down
		_debris(attacker)
		apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * mass * 6.0)
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.06, 0.05, 0.05)
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = burnt
	_engine_snd.stop()
	var fire: GPUParticles3D = Game.effects.make_fire(1.4)
	add_child(fire)
	fire.position = Vector3(0, _gear_h + body_size.y * 0.3, 0)
	fire.emitting = true
	get_tree().create_timer(14.0).timeout.connect(func(): if is_instance_valid(fire): fire.emitting = false)


func _debris(attacker: Node) -> void:
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.08, 0.07, 0.06)
	burnt.roughness = 0.9
	for i in 5:
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = Game.LAYER_WORLD
		b.mass = 50.0
		var s := Vector3(randf_range(0.5, 1.4), randf_range(0.1, 0.4), randf_range(0.6, 2.0)) * clampf(body_size.x / 12.0, 0.6, 2.5)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm
		mi.material_override = burnt
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s
		cs.shape = sh
		b.add_child(cs)
		if i < 2:
			var f: GPUParticles3D = Game.effects.make_fire(0.5)
			b.add_child(f)
			f.emitting = true
		Game.world.add_child(b)
		b.global_position = global_position + Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
		b.linear_velocity = linear_velocity * 0.6 + Vector3(randf_range(-14, 14), randf_range(4, 14), randf_range(-14, 14))
		b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		get_tree().create_timer(25.0).timeout.connect(b.queue_free)


# --------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	var drv := active_driver()
	if sleeping and drv == null:
		return
	var gb := global_basis
	var v := linear_velocity
	var speed := v.length()
	var fwd := -gb.z
	forward_speed = v.dot(fwd)
	speed_kmh = speed * 3.6
	# crash detection: a sudden change of velocity means we hit something (ignored for a moment
	# after spawning, when the velocity may be set directly)
	_age += delta
	var dv := (v - _prev_v).length()
	if destroyed and not _wreck_boom and dv > 8.0 and _age > 0.5:
		# the burning wreck hits the ground
		_wreck_boom = true
		Combat.explosion(global_position, 14.0 + body_size.x * 0.3, 260.0, null)
	if dv > 11.0 and not destroyed and _age > 0.5:
		take_damage((dv - 11.0) * 90.0, null)
		Sfx.play_at("crash", global_position, 2.0, 0.7)
		if Game.camera_rig and drv != null and drv.is_player:
			Game.camera_rig.shake(0.8)
	_prev_v = v
	# power lever (an engine on fire gives half power at most)
	if drv != null and not destroyed and fuel > 0.0:
		power = clampf(power + throttle * delta * 0.55, 0.0, 0.5 if _fire else 1.0)
		fuel = maxf(0.0, fuel - power * delta * 0.0006)
	else:
		power = move_toward(power, 0.0, delta * 0.4)
	# --- landing gear
	var contacts := 0
	var k: float = mass * G / 3.0 / 0.35
	var c: float = 2.0 * sqrt(k * mass / 3.0) * 0.55
	var space := get_world_3d().direct_space_state
	var wheel_brake := handbrake or (throttle < -0.1 and power < 0.02)
	for i in _gear.size():
		var gp: Vector3 = global_transform * _gear[i]
		var reach := _gear_h + 0.35
		var q := PhysicsRayQueryParameters3D.create(gp, gp - gb.y * reach, Game.LAYER_WORLD | Game.LAYER_VEHICLE, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		contacts += 1
		var dist: float = gp.distance_to(hit.position)
		var comp := reach - dist
		var r: Vector3 = hit.position - global_position
		var pv := v + angular_velocity.cross(r)
		var n: Vector3 = hit.normal
		var fn := maxf(0.0, k * comp - c * pv.dot(n))
		apply_force(n * fn, r)
		# tyre friction: kill side slip, roll freely forwards, brakes
		var side_v := pv.dot(gb.x)
		var lat := clampf(-side_v * mass / 3.0 * 8.0, -fn * 1.1, fn * 1.1)
		apply_force(gb.x * lat, r)
		var fwd_v := pv.dot(fwd)
		var roll := -fwd_v * mass / 3.0 * (0.015 if not wheel_brake else 2.5)
		roll = clampf(roll, -fn * (0.05 if not wheel_brake else 0.7), fn * (0.05 if not wheel_brake else 0.7))
		apply_force(fwd * roll, r)
	# parked with nobody aboard: let the body sleep (the gear springs would keep it awake forever)
	if drv == null and not destroyed and contacts >= 2 and v.length() < 0.15 and angular_velocity.length() < 0.05:
		_idle_t += delta
		if _idle_t > 2.0:
			_idle_t = 0.0
			sleeping = true
			return
	else:
		_idle_t = 0.0
	var altitude_ok := _update_altitude(delta)
	_check_water_and_bounds(drv, speed)
	airborne = contacts == 0 and altitude_ok > 1.5
	# --- aerodynamics
	var lv := gb.inverse() * v
	var aoa := atan2(-lv.y, maxf(-lv.z, 1.0)) if -lv.z > 2.0 else 0.0
	var cl := clampf(0.3 + 4.5 * aoa, -0.6, 1.5)
	stalled = aoa > 0.3 and speed > 5.0
	if stalled:
		cl = lerpf(cl, 0.45, clampf((aoa - 0.3) * 5.0, 0.0, 1.0))
	var q_dyn := maxf(forward_speed, 0.0) * maxf(forward_speed, 0.0)
	var lift := _k_lift * cl * q_dyn
	var lift_dir := gb.x.cross(v.normalized()).normalized() if speed > 2.0 else gb.y
	var force := fwd * power * _thrust * (1.0 if not destroyed else 0.0)
	force += -v * speed * _k_drag
	force += lift_dir * lift
	force += -v.normalized() * absf(lift) * 0.03 * absf(cl) if speed > 1.0 else Vector3.ZERO
	force += -gb.x * lv.x * mass * 0.9
	apply_central_force(force)
	# --- control
	var authority := clampf((forward_speed - 4.0) / maxf(_v_stall, 1.0), 0.0, 1.25)
	var want := Vector3.ZERO           # local angular velocity (x pitch up, y yaw left, z roll left)
	var bank := asin(clampf(gb.x.y, -1.0, 1.0))
	if drv != null and not destroyed:
		var desired_bank := 0.0
		var pitch_cmd := 0.0
		if aim_dir != Vector3.ZERO:
			var lt := gb.inverse() * aim_dir.normalized()
			var pitch_err := atan2(lt.y, maxf(-lt.z, 0.05))
			var yaw_err := atan2(-lt.x, maxf(-lt.z, 0.05))
			var max_bank: float = float(def.get("max_bank", 0.95))
			desired_bank = clampf(yaw_err * 2.0, -max_bank, max_bank)
			# in a bank, pitching "up" also turns: keep pulling while the target is off to the side
			pitch_cmd = clampf(pitch_err * 2.4 + absf(sin(bank)) * clampf(absf(yaw_err) * 1.5, 0.0, 0.6), -1.0, 1.0)
			want.y = clampf(yaw_err * 0.5, -0.15, 0.15)
		if absf(steer_input) > 0.1:
			desired_bank = steer_input * 1.1
		want.z = clampf((desired_bank - bank) * 2.2, -1.8, 1.8)
		# stall protection: never pull harder once the wing is near its critical angle
		if aoa > 0.2:
			pitch_cmd = minf(pitch_cmd, 0.0)
		want.x = pitch_cmd * float(def.get("pitch_rate", 0.9))
	else:
		# pilotless: wings level, gentle glide
		want.z = clampf(-bank * 1.5, -1.0, 1.0)
		want.x = -0.05
	# coordinated turn and weathervane: the nose follows the airflow (also in pitch, which
	# recovers a stall by dropping the nose)
	want.y += bank * 0.25 + atan2(-lv.x, maxf(-lv.z, 1.0)) * 0.6
	want.x -= clampf(aoa - 0.12, 0.0, 1.5) * 3.0
	if airborne:
		var target := gb * (want * authority)
		angular_velocity = angular_velocity.lerp(target, clampf(delta * 3.5, 0.0, 1.0))
	elif contacts > 0:
		var la := gb.inverse() * angular_velocity
		# rotation for take-off
		if forward_speed > _v_stall * 0.7 and want.x > 0.0:
			la.x = lerpf(la.x, want.x * authority, clampf(delta * 3.0, 0.0, 1.0))
		# nose-wheel steering
		if drv != null:
			var steer_rate := steer_input * clampf(1.4 - absf(forward_speed) / 30.0, 0.15, 1.0) * 0.7
			la.y = lerpf(la.y, steer_rate, clampf(delta * 4.0, 0.0, 1.0))
		angular_velocity = gb * la
	_update_fx(delta)


var _bounds_msg_t := 0.0
func _check_water_and_bounds(drv: Humanoid, speed: float) -> void:
	var p := global_position
	if Game.city == null:
		return
	# ditching: fast contact with the sea destroys the plane, slow contact sinks it
	var water: float = Game.city.water_level
	if not destroyed and p.y < water + 0.3 and Game.city.height_at(p.x, p.z) < water - 0.5:
		Game.effects.splash(Vector3(p.x, water, p.z))
		if speed > 12.0:
			explode(null)
		else:
			take_damage(health + 1.0, null)
	if p.y < water - 60.0:
		for o in occupants.duplicate():
			if o != null and is_instance_valid(o):
				o.exit_vehicle(true)
		queue_free()
		return
	# leaving the map: the autopilot turns the plane back towards the city
	var margin := 150.0
	var out := p.x < CityMap.MIN_X - margin or p.x > CityMap.MAX_X + margin or p.z < CityMap.MIN_Z - margin or p.z > CityMap.MAX_Z + margin
	if out and drv != null:
		var center := Vector3((CityMap.MIN_X + CityMap.MAX_X) * 0.5, p.y, (CityMap.MIN_Z + CityMap.MAX_Z) * 0.5)
		aim_dir = (center - p).normalized()
		_bounds_msg_t -= get_physics_process_delta_time()
		if _bounds_msg_t <= 0.0 and drv.is_player:
			_bounds_msg_t = 4.0
			Game.msg("Espacio aéreo restringido: volviendo a Leonida", 3.0)


func _update_altitude(delta: float) -> float:
	_alt_t -= delta
	if _alt_t <= 0.0:
		_alt_t = 0.15
		var p := global_position
		var ground: float = Game.city.height_at(p.x, p.z) if Game.city else 0.0
		var water: float = Game.city.water_level if Game.city else 0.0
		altitude = p.y - maxf(ground, water)
	return altitude


func _update_fx(delta: float) -> void:
	if _prop:
		_prop.rotate_object_local(Vector3.UP, (power * 55.0 + (4.0 if engine_on else 0.0)) * delta)
	if _engine_snd.playing:
		var jet: bool = def.get("jet", false)
		_engine_snd.pitch_scale = (0.55 if not jet else 0.9) + power * (0.9 if not jet else 0.6)
		_engine_snd.volume_db = lerpf(-10.0, 0.0, power)
		if driver() == null and power <= 0.01:
			_engine_snd.stop()
			engine_on = false
