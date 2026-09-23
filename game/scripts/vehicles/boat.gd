class_name Boat
extends RigidBody3D
## Buoyant boat: multi-point buoyancy, stern propulsion, rudder, wake spray.

var def_id := "speedboat"
var def: Dictionary
var paint := Color(-1, 0, 0)
var throttle := 0.0
var steer_input := 0.0
var brake := 0.0
var handbrake := false
var horn := false
var occupants: Array = [null, null, null, null]
var health := 800.0
var destroyed := false
var body_size := Vector3(2.5, 1.5, 7.0)
var model_root: Node3D
var speed_kmh := 0.0
var forward_speed := 0.0
var fuel := 1.0
var engine_on := false
var ai_owned := false
var persistent := false
var siren_on := false
var lights_on := false
var _floats: Array = []
var _engine_snd: AudioStreamPlayer3D
var _spray: GPUParticles3D
var _seat_offsets: Array = []


func _ready() -> void:
	def = VehicleDB.get_def(def_id)
	add_to_group("boats")
	add_to_group("vehicles")
	collision_layer = Game.LAYER_VEHICLE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	mass = float(def.mass)
	linear_damp = 0.0
	angular_damp = 1.5
	can_sleep = false
	var inst: Node3D = VehicleDB.load_src(def.src).instantiate()
	model_root = Node3D.new()
	add_child(model_root)
	model_root.add_child(inst)
	var aabb := _measure(inst)
	# orient longest axis along Z
	if aabb.size.x > aabb.size.z:
		inst.rotation.y = PI / 2
		aabb = _measure(inst)
	var k: float = float(def.length) / maxf(aabb.size.z, 0.01)
	model_root.scale = Vector3.ONE * k
	var c := aabb.get_center() * k
	model_root.position = -Vector3(c.x, aabb.position.y * k + aabb.size.y * k * 0.15, c.z)
	body_size = aabb.size * k
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(body_size.x * 0.9, body_size.y * 0.5, body_size.z * 0.95)
	cs.shape = box
	cs.position = Vector3(0, body_size.y * 0.1, 0)
	add_child(cs)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -body_size.y * 0.2, 0)
	var hx := body_size.x * 0.4
	var hz := body_size.z * 0.42
	_floats = [Vector3(-hx, -body_size.y * 0.1, -hz), Vector3(hx, -body_size.y * 0.1, -hz), Vector3(-hx, -body_size.y * 0.1, hz),
		Vector3(hx, -body_size.y * 0.1, hz), Vector3(0, -body_size.y * 0.1, 0)]
	_seat_offsets = [Transform3D(Basis(), Vector3(-0.3, body_size.y * 0.15, body_size.z * 0.1)), Transform3D(Basis(), Vector3(0.4, body_size.y * 0.15, body_size.z * 0.1)),
		Transform3D(Basis(), Vector3(-0.4, body_size.y * 0.15, body_size.z * 0.3)), Transform3D(Basis(), Vector3(0.4, body_size.y * 0.15, body_size.z * 0.3))]
	_engine_snd = AudioStreamPlayer3D.new()
	_engine_snd.stream = Sfx.get_stream("engine")
	_engine_snd.unit_size = 8.0
	_engine_snd.volume_db = -8.0
	add_child(_engine_snd)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 1)
	pm.spread = 30.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.color = Color(1, 1, 1, 0.7)
	_spray = GPUParticles3D.new()
	_spray.process_material = pm
	_spray.amount = 50
	_spray.lifetime = 0.8
	_spray.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	_spray.draw_pass_1 = q
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.6)
	sm.vertex_color_use_as_albedo = true
	_spray.material_override = sm
	_spray.position = Vector3(0, 0, body_size.z * 0.5)
	_spray.emitting = false
	add_child(_spray)


func _measure(inst: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = _rel(mi, model_root) * (mi as MeshInstance3D).get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	return aabb


func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func add_occupant(h: Node, s: int) -> void:
	occupants[s] = h
	if s == 0:
		engine_on = true
		_engine_snd.play()


func remove_occupant(h: Node) -> void:
	for i in occupants.size():
		if occupants[i] == h:
			occupants[i] = null
			if i == 0:
				throttle = 0.0
				steer_input = 0.0
				engine_on = false
				_engine_snd.stop()


func get_occupant(s: int) -> Node:
	var o = occupants[s]
	if o != null and not is_instance_valid(o):
		occupants[s] = null
		return null
	return o


func driver() -> Humanoid:
	return get_occupant(0)


func free_seat_for(h: Node) -> int:
	if destroyed:
		return -1
	if h is Humanoid and h.is_player:
		return 0
	for i in 4:
		if get_occupant(i) == null:
			return i
	return -1


func is_enclosed() -> bool:
	return false


func get_seat_transform(s: int) -> Transform3D:
	return global_transform * _seat_offsets[clampi(s, 0, 3)]


func get_exit_position(s: int) -> Vector3:
	var side := -1.0 if s % 2 == 0 else 1.0
	return global_transform * Vector3(side * (body_size.x * 0.5 + 0.8), 0.5, 0)


func take_damage(amount: float, attacker: Node = null, _hit := Vector3.ZERO) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0:
		destroyed = true
		for o in occupants.duplicate():
			if o != null and is_instance_valid(o):
				o.exit_vehicle(true)
		Combat.explosion(global_position, 8.0, 150.0, attacker)
		var burnt := StandardMaterial3D.new()
		burnt.albedo_color = Color(0.06, 0.05, 0.05)
		for mi in model_root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = burnt


func _physics_process(delta: float) -> void:
	var water: float = Game.city.water_level if Game.city else 0.0
	var gb := global_basis
	var fwd := -gb.z
	forward_speed = linear_velocity.dot(fwd)
	speed_kmh = linear_velocity.length() * 3.6
	var submerged := 0
	var t := Time.get_ticks_msec() / 1000.0
	for fp in _floats:
		var p: Vector3 = global_transform * fp
		var wave := sin(p.x * 0.08 + t * 1.3) * 0.12 + cos(p.z * 0.07 + t * 1.1) * 0.12
		var depth: float = (water + wave) - p.y
		if depth > 0.0:
			submerged += 1
			var rel := p - global_position
			var pv := linear_velocity + angular_velocity.cross(rel)
			var f := mass * 9.8 / float(_floats.size()) * clampf(depth / 0.45, 0.0, 2.5)
			apply_force(Vector3.UP * (f - pv.y * mass * 0.35 / float(_floats.size())), rel)
	if submerged > 0:
		# water drag
		var lat := linear_velocity.dot(gb.x)
		apply_central_force(-gb.x * lat * mass * 1.2)
		apply_central_force(-fwd * forward_speed * mass * 0.08)
		if driver() != null and not destroyed:
			var top: float = float(def.top)
			if throttle > 0.0 and forward_speed < top:
				apply_force(fwd * throttle * mass * float(def.accel), gb.z * body_size.z * 0.4)
			elif throttle < 0.0 and forward_speed > -top * 0.3:
				apply_force(fwd * throttle * mass * float(def.accel) * 0.5, gb.z * body_size.z * 0.4)
			var rudder := steer_input * clampf(absf(forward_speed) / 6.0, 0.15, 1.0) * signf(forward_speed if absf(forward_speed) > 0.5 else 1.0)
			apply_torque(Vector3.UP * rudder * mass * 2.2)
			# lean into turns
			apply_torque(fwd * -steer_input * forward_speed * mass * 0.05)
	_spray.emitting = submerged > 0 and absf(forward_speed) > 6.0
	if _engine_snd.playing:
		_engine_snd.pitch_scale = 0.7 + clampf(absf(forward_speed) / float(def.top), 0.0, 1.0) * 1.2 + absf(throttle) * 0.2
