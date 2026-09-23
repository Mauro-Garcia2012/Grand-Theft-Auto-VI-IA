class_name Vehicle
extends RigidBody3D
## Arcade raycast-suspension car (GTA-style handling): springs, tire grip with friction circle,
## handbrake drifts, speed-sensitive steering, damage -> smoke -> fire -> explosion, fuel, sirens.

signal destroyed_sig(v)

var def_id := "sedan"
var def: Dictionary
var paint := Color(-1, 0, 0)

# input
var throttle := 0.0      # -1..1 (negative = reverse)
var steer_input := 0.0   # -1..1 (positive = left)
var brake := 0.0
var handbrake := false
var horn := false

# state
var occupants: Array = [null, null, null, null]
var health := 1000.0
var destroyed := false
var on_fire := false
var fire_timer := 0.0
var fuel := 1.0
var siren_on := false
var lights_on := false
var engine_on := false
var locked := false
var is_bike := false
var ai_owned := false           # traffic spawned
var persistent := false         # player's last car etc.
var speed_kmh := 0.0
var forward_speed := 0.0
var steer_angle := 0.0
var wheels: Array = []          # dicts
var body_size := Vector3(1.8, 1.4, 4.5)
var model_root: Node3D
var _paint_mats: Array = []
var _smoke: GPUParticles3D
var _fire: GPUParticles3D
var _engine_snd: AudioStreamPlayer3D
var _siren_snd: AudioStreamPlayer3D
var _horn_snd: AudioStreamPlayer3D
var _skid_snd: AudioStreamPlayer3D
var _siren_lights: Array = []
var _headlights: Array = []
var _brake_mat: StandardMaterial3D
var _last_vel := Vector3.ZERO
var _crash_cd := 0.0
var _flip_timer := 0.0
var _siren_t := 0.0
var _tire_smoke: Array = []
var _seat_offsets: Array = []
var _exit_offsets: Array = []
var _stuck_t := 0.0
var last_driver: Humanoid = null
var rest := 0.42
static var _protos := {}


func _ready() -> void:
	def = VehicleDB.get_def(def_id)
	is_bike = def.get("bike", false)
	add_to_group("vehicles")
	collision_layer = Game.LAYER_VEHICLE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	mass = float(def.mass)
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.05
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.05
	physics_material_override = pm
	_build_model()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, body_size.y * (0.18 if not is_bike else 0.25), 0)
	_build_audio()
	_build_lights()


func _build_model() -> void:
	var inst: Node3D
	if def.has("node"):
		# multi-car source file: extract the sub-tree once and duplicate it afterwards
		if not _protos.has(def_id):
			var whole: Node3D = VehicleDB.load_src(def.src).instantiate()
			for other_id in VehicleDB.CARS:
				var od: Dictionary = VehicleDB.CARS[other_id]
				if od.src == def.src and od.has("node") and not _protos.has(other_id):
					var src: Node3D = whole.find_child(od.node, true, false)
					if src:
						src.get_parent().remove_child(src)
						src.transform = Transform3D.IDENTITY
						_protos[other_id] = src
			whole.free()
		inst = (_protos[def_id] as Node3D).duplicate()
	else:
		inst = VehicleDB.load_src(def.src).instantiate()
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	var holder := Node3D.new()
	model_root.add_child(holder)
	holder.add_child(inst)
	if def.front == "+z":
		holder.rotation.y = PI
	# collect wheels & compute bounds (in model_root space, unscaled)
	var wheel_nodes: Array = []
	for n in inst.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if nm.begins_with("wheel") and n is MeshInstance3D:
			wheel_nodes.append(n)
	var body_aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false) + ([inst] if inst is MeshInstance3D else []):
		if mi in wheel_nodes:
			continue
		var nm := String(mi.name).to_lower()
		if nm.begins_with("lights") or nm.begins_with("axle"):
			continue
		var a: AABB = _rel(mi, model_root) * (mi as MeshInstance3D).get_aabb()
		if first:
			body_aabb = a
			first = false
		else:
			body_aabb = body_aabb.merge(a)
	var length_raw := body_aabb.size.z
	var k: float = float(def.length) / maxf(length_raw, 0.01)
	model_root.scale = Vector3.ONE * k
	body_size = body_aabb.size * k
	var body_center := body_aabb.get_center() * k
	# Paint
	var col := paint
	if col.r < 0.0 and def.get("paint", false):
		col = VehicleDB.PAINTS.pick_random()
	for mi in inst.find_children("*", "MeshInstance3D", true, false) + ([inst] if inst is MeshInstance3D else []):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat == null:
				continue
			var mname := String(mat.resource_name).to_lower()
			if def.get("paint", false) and col.r >= 0.0 and (mname.begins_with("paint") or mname.contains("paint") or mname == "lospec material"):
				if mname == "lospec material":
					continue
				var pm2: StandardMaterial3D = mat.duplicate()
				pm2.albedo_color = col
				pm2.metallic = 0.35
				pm2.roughness = 0.25
				m.set_surface_override_material(s, pm2)
				_paint_mats.append(pm2)
			elif mname.contains("window"):
				var wm: StandardMaterial3D = mat.duplicate()
				wm.albedo_color = Color(0.12, 0.16, 0.2)
				wm.metallic = 0.8
				wm.roughness = 0.08
				m.set_surface_override_material(s, wm)
			elif mname.contains("lightback") or mname.contains("brake"):
				if _brake_mat == null:
					_brake_mat = (mat as StandardMaterial3D).duplicate()
					_brake_mat.emission_enabled = true
					_brake_mat.emission = Color(1, 0.05, 0.05)
					_brake_mat.emission_energy_multiplier = 0.3
				m.set_surface_override_material(s, _brake_mat)
			elif mname.contains("lightfront"):
				var hm: StandardMaterial3D = mat.duplicate()
				hm.emission_enabled = true
				hm.emission = Color(1, 0.95, 0.8)
				hm.emission_energy_multiplier = 0.5
				m.set_surface_override_material(s, hm)
	# Wheels: wrap in pivots for steer/spin
	for wn in wheel_nodes:
		var w: MeshInstance3D = wn
		var waabb: AABB = _rel(w, model_root) * w.get_aabb()
		var center := waabb.get_center()
		var radius := maxf(waabb.size.y, waabb.size.z) * 0.5 * k
		var pivot := Node3D.new()
		model_root.add_child(pivot)
		pivot.position = center
		var spin := Node3D.new()
		pivot.add_child(spin)
		var gt := _rel(w, model_root)
		w.get_parent().remove_child(w)
		spin.add_child(w)
		w.transform = Transform3D(Basis(), -center) * gt
		var local := center * k   # vehicle space
		var front := local.z < body_center.z
		wheels.append({
			"pivot": pivot, "spin": spin, "pos": local, "radius": radius, "front": front,
			"left": local.x < 0.0, "compression": 0.0, "contact": false, "rot": 0.0, "slip": 0.0,
			"normal": Vector3.UP, "hit": Vector3.ZERO,
		})
	# Shift so that the lowest wheel touches y=0 at rest (origin = ground level)
	var min_y := 0.0
	for w in wheels:
		min_y = minf(min_y, w.pos.y - w.radius)
	# collision box (body only, lifted a bit so wheels do the ground work)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bottom := body_center.y - body_size.y * 0.5
	var lift := 0.25 if not is_bike else 0.2
	var h := maxf(body_size.y - maxf(0.0, lift - bottom), 0.5)
	box.size = Vector3(body_size.x * (0.92 if not is_bike else 0.5), h, body_size.z * 0.96)
	cs.shape = box
	cs.position = Vector3(body_center.x, maxf(bottom, lift) + h * 0.5, body_center.z)
	add_child(cs)
	body_size = Vector3(body_size.x, body_size.y, body_size.z)
	if wheels.is_empty():
		# fallback 4 virtual wheels
		for p in [Vector3(-0.8, 0.35, -1.4), Vector3(0.8, 0.35, -1.4), Vector3(-0.8, 0.35, 1.4), Vector3(0.8, 0.35, 1.4)]:
			wheels.append({"pivot": null, "spin": null, "pos": p, "radius": 0.35, "front": p.z < 0, "left": p.x < 0,
				"compression": 0.0, "contact": false, "rot": 0.0, "slip": 0.0, "normal": Vector3.UP, "hit": Vector3.ZERO})
	# seats
	var sx := body_size.x * 0.22
	var sy := maxf(0.25, (body_center.y - body_size.y * 0.5) + 0.15)
	var sz := body_center.z + (0.1 if not is_bike else 0.05) * body_size.z
	if is_bike:
		_seat_offsets = [Transform3D(Basis(), Vector3(0, 0.35 * k, sz - 0.05)), Transform3D(Basis(), Vector3(0, 0.4 * k, sz + 0.45))]
		_exit_offsets = [Vector3(-1.1, 0.2, 0.0), Vector3(1.1, 0.2, 0.4)]
	else:
		_seat_offsets = [
			Transform3D(Basis(), Vector3(-sx, sy, sz - 0.3)),
			Transform3D(Basis(), Vector3(sx, sy, sz - 0.3)),
			Transform3D(Basis(), Vector3(-sx, sy, sz + 0.7)),
			Transform3D(Basis(), Vector3(sx, sy, sz + 0.7)),
		]
		var ex := body_size.x * 0.5 + 0.6
		_exit_offsets = [Vector3(-ex, 0.2, sz - 0.3), Vector3(ex, 0.2, sz - 0.3), Vector3(-ex, 0.2, sz + 0.7), Vector3(ex, 0.2, sz + 0.7)]


func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _build_audio() -> void:
	_engine_snd = AudioStreamPlayer3D.new()
	_engine_snd.stream = Sfx.get_stream("engine")
	_engine_snd.unit_size = 6.0
	_engine_snd.max_distance = 90.0
	_engine_snd.volume_db = -10.0
	add_child(_engine_snd)
	_skid_snd = AudioStreamPlayer3D.new()
	_skid_snd.stream = Sfx.get_stream("skid")
	_skid_snd.unit_size = 6.0
	_skid_snd.max_distance = 80.0
	_skid_snd.volume_db = -14.0
	add_child(_skid_snd)
	_horn_snd = AudioStreamPlayer3D.new()
	_horn_snd.stream = Sfx.get_stream("horn")
	_horn_snd.unit_size = 10.0
	_horn_snd.volume_db = -6.0
	add_child(_horn_snd)
	if def.get("siren", false):
		_siren_snd = AudioStreamPlayer3D.new()
		_siren_snd.stream = Sfx.get_stream("siren")
		_siren_snd.unit_size = 25.0
		_siren_snd.max_distance = 260.0
		_siren_snd.volume_db = -4.0
		add_child(_siren_snd)


func _build_lights() -> void:
	var fz := -body_size.z * 0.5
	for sx in [-1, 1]:
		var sl := SpotLight3D.new()
		sl.light_color = Color(1, 0.95, 0.85)
		sl.light_energy = 4.0
		sl.spot_range = 35.0
		sl.spot_angle = 32.0
		sl.shadow_enabled = false
		sl.position = Vector3(sx * body_size.x * 0.32, 0.8, fz - 0.1)
		sl.rotation.x = deg_to_rad(-6)
		sl.visible = false
		add_child(sl)
		_headlights.append(sl)
	if def.get("siren", false):
		for i in 2:
			var ol := OmniLight3D.new()
			ol.light_color = Color(1, 0.1, 0.1) if i == 0 else Color(0.15, 0.3, 1)
			ol.light_energy = 0.0
			ol.omni_range = 14.0
			ol.position = Vector3((i * 2 - 1) * 0.4, body_size.y + 0.25, -0.2)
			add_child(ol)
			_siren_lights.append(ol)


# --------------------------------------------------------------- occupants
func add_occupant(h: Node, s: int) -> void:
	occupants[s] = h
	if s == 0:
		engine_on = true
		last_driver = h
		if not _engine_snd.playing:
			_engine_snd.play()
	sleeping = false


func remove_occupant(h: Node) -> void:
	for i in occupants.size():
		if occupants[i] == h:
			occupants[i] = null
			if i == 0:
				throttle = 0.0
				brake = 0.0
				steer_input = 0.0
				handbrake = true
				horn = false


func get_occupant(s: int) -> Node:
	var o = occupants[s] if s < occupants.size() else null
	if o != null and not is_instance_valid(o):
		occupants[s] = null
		return null
	return o


func driver() -> Humanoid:
	return get_occupant(0)


func seat_count() -> int:
	return 2 if is_bike else 4


func free_seat_for(h: Node) -> int:
	# driver seat preferred, carjack allowed
	if destroyed:
		return -1
	if h is Humanoid and h.is_player:
		return 0
	for i in seat_count():
		if get_occupant(i) == null:
			return i
	return -1


func is_enclosed() -> bool:
	return not def.get("open", false) and not is_bike


func get_seat_transform(s: int) -> Transform3D:
	var t: Transform3D = _seat_offsets[clampi(s, 0, _seat_offsets.size() - 1)]
	return global_transform * t


func get_exit_position(s: int) -> Vector3:
	var o: Vector3 = _exit_offsets[clampi(s, 0, _exit_offsets.size() - 1)]
	var p := global_transform * o
	# make sure not inside something
	var hit := Combat.raycast(global_position + Vector3.UP * 1.0, p + Vector3.UP * 1.0, [self], Game.LAYER_WORLD | Game.LAYER_VEHICLE)
	if not hit.is_empty():
		o.x = -o.x
		p = global_transform * o
	return Vector3(p.x, maxf(p.y, global_position.y + 0.1), p.z)


# --------------------------------------------------------------- damage
func take_damage(amount: float, attacker: Node = null, _hit_pos := Vector3.ZERO) -> void:
	if destroyed:
		return
	if Game.god_mode and driver() != null and driver().is_player:
		amount *= 0.1
	health -= amount
	if attacker == Game.player and driver() != null and driver() != Game.player:
		if driver().brain and driver().brain.has_method("on_damaged"):
			driver().brain.on_damaged(attacker, amount)
	if health < 400.0 and _smoke == null:
		_smoke = Game.effects.make_smoke(0.5 if health > 200 else 0.15, 0.8)
		add_child(_smoke)
		_smoke.position = Vector3(0, body_size.y * 0.7, -body_size.z * 0.35)
		_smoke.emitting = true
	if health <= 150.0 and not on_fire:
		on_fire = true
		fire_timer = 5.0 + randf() * 2.0
		_fire = Game.effects.make_fire(1.0)
		add_child(_fire)
		_fire.position = Vector3(0, body_size.y * 0.6, -body_size.z * 0.35)
		_fire.emitting = true
	if health <= -300.0:
		explode(attacker)


func explode(attacker: Node = null) -> void:
	if destroyed:
		return
	destroyed = true
	on_fire = false
	engine_on = false
	siren_on = false
	if _fire:
		_fire.amount = 16
	for o in occupants.duplicate():
		if o != null and is_instance_valid(o):
			o.exit_vehicle(true)
			o.take_damage(500.0, attacker, o.global_position, Vector3.UP, "explosion")
	Combat.explosion(global_position + Vector3.UP * 0.8, 9.0, 160.0, attacker)
	apply_central_impulse(Vector3.UP * mass * 7.0)
	apply_torque_impulse(Vector3(randf() - 0.5, 0, randf() - 0.5) * mass * 4.0)
	# burnt look
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.06, 0.055, 0.05)
	burnt.roughness = 1.0
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = burnt
	for l in _headlights:
		l.visible = false
	if _engine_snd:
		_engine_snd.stop()
	if _siren_snd:
		_siren_snd.stop()
	destroyed_sig.emit(self)
	if attacker == Game.player:
		Game.report_crime(global_position, 1.5, "explosion")


func repair() -> void:
	health = 1000.0
	on_fire = false
	if _smoke:
		_smoke.queue_free()
		_smoke = null
	if _fire:
		_fire.queue_free()
		_fire = null


func set_paint(c: Color) -> void:
	for m in _paint_mats:
		m.albedo_color = c


# --------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	var drv := driver()
	if sleeping and drv == null and not on_fire:
		return
	var gb := global_basis
	var fwd := -gb.z
	var up := gb.y
	var right := gb.x
	forward_speed = linear_velocity.dot(fwd)
	speed_kmh = linear_velocity.length() * 3.6
	_crash_cd = maxf(0.0, _crash_cd - delta)
	if on_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			explode(null)
	if destroyed or drv == null or fuel <= 0.0:
		if drv == null:
			throttle = 0.0
			if not ai_owned or destroyed:
				handbrake = true
		if destroyed or fuel <= 0.0:
			throttle = 0.0
	var top: float = float(def.top)
	var speed_factor := clampf(absf(forward_speed) / top, 0.0, 1.0)
	# steering
	var max_steer := deg_to_rad(lerpf(36.0, 9.0, pow(speed_factor, 0.7)))
	if is_bike:
		max_steer *= 0.8
	var target_steer := steer_input * max_steer
	steer_angle = move_toward(steer_angle, target_steer, delta * (2.6 if absf(target_steer) > absf(steer_angle) else 4.0))
	# engine force
	var drive_force := 0.0
	var accel: float = float(def.accel)
	if throttle > 0.01:
		if forward_speed < -1.0:
			drive_force = 0.0
		else:
			var curve := clampf(1.0 - pow(maxf(forward_speed, 0.0) / top, 2.0), 0.0, 1.0)
			drive_force = throttle * mass * accel * (0.35 + 0.65 * curve)
			if forward_speed > top:
				drive_force = 0.0
	elif throttle < -0.01:
		if forward_speed > 1.0:
			drive_force = 0.0
		elif forward_speed > -top * 0.3:
			drive_force = throttle * mass * accel * 0.6
	var braking := brake
	if throttle < -0.01 and forward_speed > 1.0:
		braking = maxf(braking, -throttle)
	if throttle > 0.01 and forward_speed < -1.0:
		braking = maxf(braking, throttle)
	# fuel
	if engine_on and drv != null:
		fuel = maxf(0.0, fuel - absf(throttle) * delta * 0.0009)
	# wheels
	var space := get_world_3d().direct_space_state
	var grounded := 0
	var n_drive := 0
	for w in wheels:
		if not w.front or is_bike or def.accel > 10.0:
			n_drive += 1
	var comp_l := 0.0
	var comp_r := 0.0
	var skid_amount := 0.0
	rest = 0.42 if not is_bike else 0.35
	var k_spring := mass * 9.8 / float(wheels.size()) / (rest * 0.35)
	var c_damp := 2.0 * sqrt(k_spring * mass / float(wheels.size())) * 0.45
	for w in wheels:
		var mount_local: Vector3 = w.pos + Vector3.UP * (rest * 0.5)
		var mount := global_transform * mount_local
		var ray_len: float = rest + w.radius
		var q := PhysicsRayQueryParameters3D.create(mount, mount - up * ray_len, Game.LAYER_WORLD | Game.LAYER_VEHICLE)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			w.contact = false
			w.compression = move_toward(w.compression, 0.0, delta * 4.0)
			continue
		grounded += 1
		w.contact = true
		var dist: float = mount.distance_to(hit.position) - w.radius
		var compression: float = clampf(rest - dist, 0.0, rest)
		w.compression = compression
		w.normal = hit.normal
		w.hit = hit.position
		var contact: Vector3 = hit.position
		var rel := contact - global_position
		var pv := linear_velocity + angular_velocity.cross(rel)
		var spring := k_spring * compression
		var damper := c_damp * pv.dot(up)
		var fn := maxf(0.0, spring - damper)
		if compression >= rest * 0.98:
			fn += mass * 3.0
		apply_force(up * fn, rel)
		if w.left:
			comp_l += compression
		else:
			comp_r += compression
		# tire frame
		var wf := fwd
		if w.front:
			wf = fwd.rotated(up, steer_angle)
		var n: Vector3 = hit.normal
		wf = (wf - n * wf.dot(n)).normalized()
		var ws := n.cross(wf).normalized()   # points left
		var v_long := pv.dot(wf)
		var v_lat := pv.dot(ws)
		var mu: float = 1.25 * float(def.grip)
		if handbrake and not w.front:
			mu *= 0.38
		var grip := mu * fn
		var lat_stiff := mass / float(wheels.size()) / maxf(delta, 0.001) * 0.55
		var f_lat := clampf(-v_lat * lat_stiff, -grip, grip)
		var f_long := 0.0
		var is_drive = (not w.front) or is_bike or def.accel > 10.0
		if is_drive and n_drive > 0:
			f_long += drive_force / float(n_drive)
		if braking > 0.01:
			f_long += -signf(v_long) * minf(absf(v_long) * mass * 4.0, mass * 11.0 * braking / float(wheels.size()))
		if handbrake and not w.front:
			f_long += -signf(v_long) * minf(absf(v_long) * mass * 3.0, mass * 6.0 / float(wheels.size()))
		# rolling resistance
		f_long += -v_long * mass * 0.015
		# friction circle
		var total := Vector2(f_lat, f_long)
		if total.length() > grip:
			total = total.normalized() * grip
			skid_amount = maxf(skid_amount, absf(v_lat) * 0.2 + (1.0 if handbrake and absf(v_long) > 5.0 else 0.0))
		w.slip = absf(v_lat)
		apply_force(ws * total.x + wf * total.y, rel)
	# anti-roll
	if not is_bike and grounded >= 3:
		var roll := (comp_l - comp_r) * mass * 12.0
		apply_torque(fwd * roll)
	# downforce
	if grounded > 0:
		apply_central_force(-up * linear_velocity.length_squared() * mass * 0.0025)
	# bike stabilizer: keep upright with lean
	if is_bike and not destroyed:
		var lean := -steer_angle * clampf(absf(forward_speed) / 15.0, 0.0, 1.0) * 1.2
		var target_up := Vector3.UP.rotated(fwd, lean)
		var err := up.cross(target_up)
		apply_torque(err * mass * 60.0 - angular_velocity.project(fwd) * mass * 8.0)
		if grounded > 0:
			# yaw control from steering (two virtual contacts are weak)
			var yaw_rate := forward_speed * tan(steer_angle) / 1.4
			var yaw_err := yaw_rate - angular_velocity.dot(Vector3.UP)
			apply_torque(Vector3.UP * yaw_err * mass * 2.5)
	# air control & upright assist
	if grounded == 0 and drv != null:
		apply_torque(right * -throttle * mass * 0.8 + fwd * steer_input * mass * 0.6)
	# flipped?
	if up.y < 0.2 and linear_velocity.length() < 3.0:
		_flip_timer += delta
		if _flip_timer > 3.0 and (drv == null or not drv.is_player):
			_unflip()
	else:
		_flip_timer = 0.0
	# crash detection
	var dv := (linear_velocity - _last_vel).length()
	if dv > 7.0 and _crash_cd <= 0.0:
		_crash_cd = 0.4
		take_damage((dv - 6.0) * 22.0 * (0.4 if is_bike else 1.0), null)
		Sfx.play_at("crash", global_position, clampf(dv - 12.0, -12.0, 4.0))
		if Game.camera_rig and drv != null and drv.is_player:
			Game.camera_rig.shake(clampf(dv / 25.0, 0.1, 0.8))
		if is_bike and dv > 11.0 and drv != null:
			var d := drv
			d.exit_vehicle(true)
			d.knockdown(linear_velocity * 0.6 + Vector3.UP * 4.0)
			d.take_damage(dv * 1.5, null, Vector3.ZERO, Vector3.ZERO, "fall")
	_last_vel = linear_velocity
	# pedestrians hit
	if linear_velocity.length() > 3.0:
		_check_ped_hits()
	_update_audio_fx(delta, skid_amount, grounded)


func _unflip() -> void:
	var yaw := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.5)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_flip_timer = 0.0


func flip_if_needed() -> void:
	if global_basis.y.y < 0.3 and linear_velocity.length() < 4.0:
		_unflip()


func _check_ped_hits() -> void:
	var inv := global_transform.affine_inverse()
	var hx := body_size.x * 0.5 + 0.35
	var hz := body_size.z * 0.5 + 0.35
	for h in get_tree().get_nodes_in_group("humanoids"):
		if h.vehicle != null or h.down_timer > 0.5:
			continue
		var d2: float = h.global_position.distance_squared_to(global_position)
		if d2 > (hz + 2.0) * (hz + 2.0):
			continue
		var lp: Vector3 = inv * h.global_position
		if absf(lp.x) < hx and absf(lp.z) < hz and lp.y > -1.0 and lp.y < 2.5:
			var rel_v: Vector3 = linear_velocity - h.velocity
			var spd := rel_v.length()
			if spd < 3.0:
				continue
			var dmg := spd * spd * 0.9
			var drv := driver()
			if not h.dead:
				h.take_damage(dmg, drv, h.global_position + Vector3.UP, rel_v.normalized(), "vehicle")
				if not h.dead:
					h.knockdown(rel_v * 0.7 + Vector3.UP * (2.0 + spd * 0.25))
				else:
					h.velocity = rel_v * 0.8 + Vector3.UP * (2.0 + spd * 0.2)
				Sfx.play_at("thud", h.global_position, 0.0)
				if drv != null and drv.is_player:
					Game.report_crime(global_position, 1.0, "hit_ped")
			# car loses a bit of speed
			linear_velocity *= 0.97


func _update_audio_fx(delta: float, skid: float, grounded: int) -> void:
	var drv := driver()
	var near := global_position.distance_squared_to(Game.player_pos()) < 90.0 * 90.0 if Game.player else false
	if engine_on and not destroyed and near:
		if not _engine_snd.playing:
			_engine_snd.play()
		var rpm := 0.55 + clampf(absf(forward_speed) / float(def.top), 0.0, 1.0) * 1.6 + absf(throttle) * 0.25
		# fake gears
		var g := fmod(absf(forward_speed) / float(def.top) * 4.0, 1.0)
		rpm += g * 0.25
		_engine_snd.pitch_scale = lerpf(_engine_snd.pitch_scale, rpm * (1.4 if is_bike else 1.0), delta * 6.0)
		_engine_snd.volume_db = (-8.0 if drv != null and drv.is_player else -14.0) + absf(throttle) * 3.0
	elif _engine_snd.playing:
		_engine_snd.stop()
	if drv == null and not ai_owned:
		engine_on = false
	# skid
	if skid > 0.8 and grounded > 0 and near:
		if not _skid_snd.playing:
			_skid_snd.play()
		_skid_snd.volume_db = clampf(-20.0 + skid * 2.0, -20.0, -4.0)
		if _tire_smoke.is_empty() and linear_velocity.length() > 6.0:
			for w in wheels:
				if not w.front:
					var ts = Game.effects.make_tire_smoke()
					add_child(ts)
					ts.position = w.pos + Vector3.DOWN * w.radius * 0.8
					ts.emitting = true
					_tire_smoke.append(ts)
	else:
		if _skid_snd.playing:
			_skid_snd.stop()
		if not _tire_smoke.is_empty():
			for ts in _tire_smoke:
				ts.emitting = false
				get_tree().create_timer(2.0).timeout.connect(ts.queue_free)
			_tire_smoke.clear()
	# horn
	if horn and not _horn_snd.playing:
		_horn_snd.play()
	elif not horn and _horn_snd.playing:
		_horn_snd.stop()
	# siren
	if _siren_snd:
		if siren_on and not destroyed:
			if not _siren_snd.playing:
				_siren_snd.play()
			_siren_t += delta
			var ph := fmod(_siren_t * 3.0, 1.0)
			_siren_lights[0].light_energy = 6.0 if ph < 0.5 else 0.0
			_siren_lights[1].light_energy = 6.0 if ph >= 0.5 else 0.0
		else:
			if _siren_snd.playing:
				_siren_snd.stop()
			for l in _siren_lights:
				l.light_energy = 0.0
	# lights
	var night: bool = Game.sky != null and Game.sky.is_night()
	var want_lights := (engine_on or ai_owned) and not destroyed and (night or lights_on)
	for l in _headlights:
		l.visible = want_lights and near
	if _brake_mat:
		_brake_mat.emission_energy_multiplier = 3.0 if brake > 0.1 or (throttle < -0.1 and forward_speed > 1.0) else (1.0 if want_lights else 0.2)


func _process(delta: float) -> void:
	# wheel visuals
	for w in wheels:
		if w.pivot == null:
			continue
		var target_y: float = w.pos.y + w.compression - rest * 0.5
		w.pivot.position.y = lerpf(w.pivot.position.y, target_y / model_root.scale.y, 0.5)
		if w.front:
			w.pivot.rotation.y = steer_angle
		w.rot += forward_speed / maxf(w.radius, 0.1) * delta
		w.spin.rotation.x = -w.rot
