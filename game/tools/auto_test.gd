extends Node
## Automated test driver: `godot --path . -- --test=<mode>`
## modes: smoke (headless run), shots (screenshots from viewpoints), drive, combat

var mode := "smoke"
var t := 0.0
var step := 0
var out_dir := "/home/user/scratch/shots"
var _shot_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("[test] mode=", mode)
	Game.settings.show_fps = true
	var pc = Game.player.get_node_or_null("PlayerController")
	if pc:
		pc.set_physics_process(false)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "%s/%02d_%s.png" % [out_dir, _shot_i, name]
	_shot_i += 1
	img.save_png(p)
	print("[test] shot ", p, " fps=", Engine.get_frames_per_second())


func _place_cam(pos: Vector3, look: Vector3) -> void:
	var rig: CameraRig = Game.camera_rig
	rig.set_physics_process(false)
	rig.global_position = pos
	rig.arm.spring_length = 0.0
	rig.arm.position = Vector3.ZERO
	rig.look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	t += delta
	match mode:
		"smoke":
			_smoke()
		"shots":
			_shots()
		"drive":
			_drive()
		"combat":
			_combat()
		"perf":
			_perf()
		"gallery":
			_gallery()
		"vgallery":
			_vgallery()
		"vview":
			_vview()
		"pview":
			_pview()
		"shots2":
			_shots2()
		"spawnperf":
			_spawnperf()
		"readme":
			_readme()
		"fly":
			_fly()
		"flyshots":
			_flyshots()
		"bshot":
			_bshot()
		"heli":
			_heli()
		"copheli":
			_copheli()
		"traffic":
			_traffic()
		"chase":
			_chase()


var _perf_next := 2.0
func _perf() -> void:
	if t < _perf_next:
		return
	_perf_next += 2.0
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var peds := 0
	for h in get_tree().get_nodes_in_group("humanoids"):
		peds += 1
	print("[perf] t=%.0f fps=%d process=%.1fms physics=%.1fms humanoids=%d vehicles=%d nodes=%d" % [t, Engine.get_frames_per_second(), proc, phys, peds, get_tree().get_nodes_in_group("vehicles").size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	match int(t):
		10:
			print("[perf] -> disabling AnimationTrees")
			for h in get_tree().get_nodes_in_group("humanoids"):
				if h.model and h.model.anim_tree:
					h.model.anim_tree.active = false
		16:
			print("[perf] -> disabling humanoid physics")
			for h in get_tree().get_nodes_in_group("humanoids"):
				if not h.is_player:
					h.set_physics_process(false)
					if h.brain:
						h.brain.set_physics_process(false)
			Game.population.set_physics_process(false)
		22:
			print("[perf] -> disabling vehicles")
			for v in get_tree().get_nodes_in_group("vehicles"):
				v.set_physics_process(false)
				v.set_process(false)
		28:
			print("[perf] -> disabling HUD/minimap")
			Game.hud.set_process(false)
			Game.hud.minimap.set_process(false)
		34:
			get_tree().quit()


func _smoke() -> void:
	var p := Game.player
	if step == 0 and t > 1.0:
		step = 1
		p.move_dir = Vector3(0, 0, -1)
		print("[test] player at ", p.global_position, " on_floor=", p.is_on_floor())
	elif step == 1 and t > 4.0:
		step = 2
		print("[test] player at ", p.global_position, " on_floor=", p.is_on_floor(), " anim=", p.model.current_loco)
		print("[test] peds=", Game.population.peds.size(), " traffic=", Game.population.traffic.size(), " parked=", Game.population.parked.size())
		p.aiming = true
		p.aim_point = p.global_position + Vector3(0, 1, -20)
		for i in 3:
			p.fire_cd = 0.0
			p.try_fire()
		Game.wanted.set_level(2)
	elif step == 2 and t > 10.0:
		step = 3
		print("[test] wanted=", Game.get_wanted(), " units=", Game.wanted.units.size(), " peds=", Game.population.peds.size(), " traffic=", Game.population.traffic.size())
		# enter nearest car
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v.global_position.distance_to(p.global_position) < 30.0 and v is Vehicle:
				p.enter_vehicle(v, 0)
				break
		print("[test] in vehicle: ", p.vehicle)
	elif step == 3 and t > 11.0:
		if p.vehicle:
			p.vehicle.throttle = 1.0
			p.vehicle.steer_input = 0.2
	if step == 3 and t > 16.0:
		step = 4
		if p.vehicle:
			print("[test] vehicle speed km/h=", p.vehicle.speed_kmh, " pos=", p.vehicle.global_position, " fuel=", p.vehicle.fuel, " health=", p.vehicle.health)
		print("[test] fps=", Engine.get_frames_per_second(), " objects=", Performance.get_monitor(Performance.OBJECT_COUNT), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		Cheats.apply("ARMAS")
		Cheats.apply("SUPERCOCHE")
		Game.sky.set_weather("storm")
	elif step == 4 and t > 22.0:
		step = 5
		print("[test] wanted=", Game.get_wanted(), " player health=", p.health, " dead=", p.dead)
		print("[test] OK smoke test finished")
		get_tree().quit()


func _shots() -> void:
	var p := Game.player
	match step:
		0:
			if t > 2.0:
				step = 1
				Game.sky.time_of_day = 17.6
				_place_cam(p.global_position + Vector3(-6, 3, 8), p.global_position + Vector3(0, 1.4, 0))
				await _wait(1.0)
				await _shot("player_closeup")
				_place_cam(Vector3(1150, 60, 700), Vector3(980, 5, 450))
				await _wait(1.5)
				await _shot("ocean_drive_aerial")
				_place_cam(Vector3(1045, 3.2, 820), Vector3(1030, 4, 600))
				await _wait(1.5)
				await _shot("ocean_drive_street")
				_place_cam(Vector3(600, 160, 700), Vector3(80, 60, 150))
				await _wait(1.5)
				await _shot("downtown_skyline")
				_place_cam(Vector3(40, 4, 380), Vector3(80, 40, 120))
				await _wait(1.5)
				await _shot("downtown_street")
				_place_cam(Vector3(-380, 30, 150), Vector3(-560, 3, 0))
				await _wait(1.5)
				await _shot("little_cuba")
				_place_cam(Vector3(50, 30, -700), Vector3(-100, 5, -900))
				await _wait(1.5)
				await _shot("stockyard")
				_place_cam(Vector3(300, 60, 850), Vector3(600, 10, 650))
				await _wait(1.5)
				await _shot("port")
				_place_cam(Vector3(700, 400, 2200), Vector3(200, 0, 0))
				await _wait(2.0)
				await _shot("overview")
				Game.sky.time_of_day = 22.5
				await _wait(1.5)
				_place_cam(Vector3(1045, 3.2, 820), Vector3(1030, 6, 600))
				await _wait(1.5)
				await _shot("ocean_drive_night")
				_place_cam(Vector3(600, 160, 700), Vector3(80, 60, 150))
				await _wait(1.0)
				await _shot("downtown_night")
				Game.sky.time_of_day = 12.5
				_place_cam(Vector3(1180, 8, 300), Vector3(1080, 1, 450))
				await _wait(1.5)
				await _shot("beach_noon")
				print("[test] OK shots finished")
				get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _drive() -> void:
	var p := Game.player
	if step == 0 and t > 1.5:
		step = 1
		var v: Vehicle = VehicleDB.spawn(OS.get_environment("DRIVE_ID") if OS.get_environment("DRIVE_ID") != "" else "p_sport", p.global_position + Vector3(0, 1, -6), 0.0)
		await _wait(0.2)
		p.enter_vehicle(v, 0)
	elif step == 1 and t > 2.5:
		var v = p.vehicle
		if v:
			v.throttle = 1.0
			v.steer_input = 0.0 if t < 7.0 else 0.4
			v.handbrake = t > 9.0 and t < 10.0
		if int(t * 2) % 2 == 0:
			print("[test] t=%.1f speed=%.1f pos=%s up=%.2f wheels_contact=%d" % [t, v.speed_kmh, v.global_position, v.global_basis.y.y, v.wheels.filter(func(w): return w.contact).size()])
		if t > 11.0:
			step = 2
			await _shot("driving")
			print("[test] OK drive finished")
			get_tree().quit()


func _combat() -> void:
	var p := Game.player
	if step == 0 and t > 2.0:
		step = 1
		Cheats.apply("ARMAS")
		Game.sky.time_of_day = 16.0
		for i in 4:
			var h: Humanoid = Game.population.spawn_ped(p.global_position + Vector3(i * 2 - 3, 0.5, -10), "male", "gang_purple", "gang_purple")
			h.give_weapon("pistol", 50)
			h.select_weapon(1)
			h.brain.aggressive = true
			h.brain.threat = p
			h.brain.state = PedBrain.S.FIGHT
			h.brain.t = 60.0
		p.select_weapon(3)
	elif step == 1 and t > 3.0:
		p.aiming = true
		var target: Humanoid = null
		for h in get_tree().get_nodes_in_group("humanoids"):
			if h.team.begins_with("gang") and not h.dead:
				target = h
				break
		if target:
			p.aim_point = target.global_position + Vector3.UP * 1.3
			p.rotation.y = atan2(-(target.global_position - p.global_position).x, -(target.global_position - p.global_position).z)
			p.try_fire()
		if int(t * 10) % 10 == 0:
			var alive := 0
			for h in get_tree().get_nodes_in_group("humanoids"):
				if h.team.begins_with("gang") and not h.dead:
					alive += 1
			print("[test] t=%.1f player hp=%.0f armor=%.0f clip=%d gang_alive=%d" % [t, p.health, p.armor, int(p.current_weapon().clip), alive])
		if t > 5.0 and _shot_i == 0 and DisplayServer.get_name() != "headless":
			_place_cam(p.global_position + Vector3(2.5, 2.2, 3.5), p.global_position + Vector3(0, 1.2, -8))
			await _shot("combat")
		if t > 12.0:
			step = 2
			var dead := 0
			for h in get_tree().get_nodes_in_group("humanoids"):
				if h.team.begins_with("gang") and h.dead:
					dead += 1
			print("[test] gang dead=", dead, " player health=", p.health, " wanted=", Game.get_wanted())
			print("[test] OK combat finished")
			get_tree().quit()


func _gallery() -> void:
	if step != 0 or t < 2.0:
		return
	step = 1
	var p := Game.player
	Game.sky.time_of_day = 16.5
	Game.population.set_physics_process(false)
	Game.population.clear_all()
	var base := Vector3(1060, 1.2, 400)
	# every body model, idle / walking, close up
	var c0 := base + Vector3(-20, 0, 14)
	var ids := CharacterModel.MODELS.keys()
	for i in ids.size():
		var h = Game.population.spawn_ped(c0 + Vector3(i * 1.3, 0.3, 0), CharacterModel.MODELS[ids[i]].gender, "")
		h.model.set_outfit(ids[i], Color(1, 1, 1), true)
		h.brain.set_physics_process(false)
		h.set_physics_process(false)
		h.rotation.y = PI + (0.4 if i % 2 else -0.3)
		h.model.play(["Idle", "Walk", "Idle_Talking", "Idle_FoldArms"][i % 4])
	await _wait(1.5)
	_place_cam(c0 + Vector3(3.2, 1.5, 4.2), c0 + Vector3(3.2, 1.0, 0))
	await _wait(0.5)
	await _shot("gallery_people")
	# characters with weapons
	var c := base + Vector3(-20, 0, 0)
	var weaps := ["pistol", "smg", "rifle", "shotgun", "sniper", "rpg"]
	for i in weaps.size():
		var h = Game.population.spawn_ped(c + Vector3(i * 1.6, 0.3, 0), "male" if i % 2 == 0 else "female", "")
		h.brain.set_physics_process(false)
		h.give_weapon(weaps[i], 30, true)
		h.rotation.y = PI
		h.aiming = i % 2 == 0
		h.aim_point = h.global_position + Vector3(0, 1.4, 20)
	await _wait(1.5)
	_place_cam(c + Vector3(4, 1.8, 6), c + Vector3(4, 1.1, 0))
	await _wait(0.5)
	await _shot("gallery_weapons")
	# cars
	var cars := ["p_sedan", "p_sport", "p_police", "p_taxi", "b_m5", "b_challenger", "p_suv", "b_mclaren", "p_pickup", "p_ambulance", "p_garbage", "b_porsche"]
	for i in cars.size():
		var v = VehicleDB.spawn(cars[i], base + Vector3((i % 4) * 7.0, 0.5, (i / 4) * 9.0), PI * 0.25)
		v.freeze = false
	await _wait(2.5)
	_place_cam(base + Vector3(10, 7, 30), base + Vector3(10, 0, 8))
	await _wait(1.0)
	await _shot("gallery_cars")
	# player driving
	var car = VehicleDB.spawn("b_m8", base + Vector3(0, 0.6, -30), 0.0)
	await _wait(0.5)
	p.enter_vehicle(car, 0)
	for o in Game.protagonists:
		if o != p:
			o.enter_vehicle(car, 1)
	await _wait(1.0)
	_place_cam(car.global_position + Vector3(4, 2.5, 7), car.global_position + Vector3(0, 1.0, 0))
	await _wait(0.5)
	await _shot("gallery_driving")
	# boats
	var b = VehicleDB.spawn("cruiser", Vector3(1250, 0.5, 400), 0.0)
	VehicleDB.spawn("yacht", Vector3(1275, 0.5, 440), 0.5)
	VehicleDB.spawn("sailboat", Vector3(1230, 0.5, 425), 1.0)
	await _wait(3.0)
	_place_cam(b.global_position + Vector3(-22, 9, 26), b.global_position)
	await _wait(0.5)
	await _shot("gallery_boats")
	print("[test] OK gallery finished")
	get_tree().quit()


var _sim_next := 0.0
func _traffic() -> void:
	# observe traffic & pedestrians health: moving / stuck ratios
	if t < 3.0:
		return
	if t >= _sim_next:
		_sim_next = t + 3.0
		var moving := 0
		var stuck := 0
		var total := 0
		var at_signal := 0
		for v in Game.population.traffic:
			if not is_instance_valid(v) or v.destroyed:
				continue
			total += 1
			if v.linear_velocity.length() > 2.0:
				moving += 1
			else:
				stuck += 1
				var nn: int = Game.city.nearest_node(v.global_position, 26.0)
				if nn >= 0 and TrafficSignals.signals.has(nn):
					at_signal += 1
		var pm := 0
		var pt := 0
		for h in Game.population.peds:
			if is_instance_valid(h) and not h.dead and h.vehicle == null:
				pt += 1
				if Vector2(h.velocity.x, h.velocity.z).length() > 0.5:
					pm += 1
		var flipped := 0
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v is Vehicle and v.global_basis.y.y < 0.5:
				flipped += 1
		print("[traffic] t=%.0f cars=%d moving=%d stopped=%d (at lights %d) flipped=%d | peds=%d walking=%d | fps=%d" % [t, total, moving, stuck, at_signal, flipped, pt, pm, Engine.get_frames_per_second()])
	if t > 70.0:
		print("[test] OK traffic finished")
		get_tree().quit()


var _chase_started := false
func _chase() -> void:
	var p := Game.player
	if not _chase_started and t > 2.0:
		_chase_started = true
		var v: Vehicle = VehicleDB.spawn("p_sport", Vector3(950, 1.8, 300), PI)
		await _wait(0.3)
		p.enter_vehicle(v, 0)
		Game.wanted.set_level(3)
	if _chase_started and p.vehicle:
		var v = p.vehicle
		# drive south along Collins Ave at moderate speed
		v.throttle = 0.6 if v.speed_kmh < 70 else 0.0
		var target := Vector3(950, 1, 1100)
		var local = v.global_transform.affine_inverse() * target
		v.steer_input = clampf(atan2(-local.x, -local.z) * 2.0, -1, 1)
		if t >= _sim_next:
			_sim_next = t + 2.0
			var near := INF
			var sirens := 0
			for u in Game.wanted.units:
				if is_instance_valid(u):
					near = minf(near, u.global_position.distance_to(v.global_position))
					if u.siren_on:
						sirens += 1
			print("[chase] t=%.0f stars=%d units=%d sirens=%d nearest=%.0f seen=%s player_speed=%.0f pos=%s" % [t, Game.get_wanted(), Game.wanted.units.size(), sirens, near, Game.wanted.seen, v.speed_kmh, v.global_position])
	if t > 45.0:
		print("[test] OK chase finished")
		get_tree().quit()


func _vgallery() -> void:
	if step != 0 or t < 2.0:
		return
	step = 1
	Game.sky.time_of_day = 15.0
	Game.population.set_physics_process(false)
	Game.population.clear_all()
	var base := Vector3(1060, 1.2, 380)
	var ids := ["q_primo", "q_asterope", "q_cavalcade", "q_infernus", "q_comet", "q_taxi", "q_cop", "q_cop_suv", "q_ambulance", "q_bus", "q_schoolbus", "q_tank"]
	for i in ids.size():
		var v = VehicleDB.spawn(ids[i], base + Vector3((i % 4) * 9.0, 0.5, (i / 4) * 13.0), PI * 0.2)
		if ids[i] in ["q_cop", "q_cop_suv", "q_ambulance"]:
			v.siren_on = true
	await _wait(3.0)
	_place_cam(base + Vector3(14, 9, 42), base + Vector3(14, 0, 12))
	await _wait(1.0)
	await _shot("vgallery_a")
	_place_cam(base + Vector3(-12, 5, 6), base + Vector3(10, 0, 14))
	await _wait(0.5)
	await _shot("vgallery_b")
	get_tree().quit()


## Close-up turntable of the vehicles listed in the VIEW_IDS environment variable (comma separated).
func _vview() -> void:
	if step != 0 or t < 2.0:
		return
	step = 1
	Game.sky.time_of_day = 13.0
	Game.population.set_physics_process(false)
	Game.population.clear_all()
	var base := Vector3(1080, 1.2, 380)
	for id in OS.get_environment("VIEW_IDS").split(","):
		var v = VehicleDB.spawn(id, base, 0.0)
		await _wait(2.0)
		print("[vview] ", id, " body=", v.body_size, " y=", v.global_position.y, " mscale=", v.model_root.scale)
		for w in v.wheels:
			print("   wheel pos=", w.pos, " r=", w.radius, " front=", w.front, " axle=", w.get("axle", false), " contact=", w.contact)
		var L: float = maxf(v.body_size.z, 4.0)
		var c: Vector3 = v.global_position + Vector3(0, v.body_size.y * 0.4, 0)
		if v.turret:
			var tgt: Vector3 = v.global_position + Vector3(30, 2, 10)
			for i in 90:
				v.aim_turret(tgt, 0.05)
			print("[vview] muzzle=", v.muzzle_position() - v.global_position)
			v.fire_cannon(tgt, Game.player)
			await _wait(0.12)
		for a in [0.6, 2.4, 4.2]:
			_place_cam(c + Vector3(sin(a), 0.35, cos(a)) * L * 1.3, c)
			await _wait(0.3)
			await _shot("vview_%s_%d" % [id, int(a * 10)])
		v.queue_free()
	get_tree().quit()


## Line up the models listed in PVIEW (comma separated res:// paths, optional "@length") with a red
## marker on their +Z side and a blue one on +X, to check scale and orientation.
func _pview() -> void:
	if step != 0 or t < 7.0:
		return
	step = 1
	Game.sky.time_of_day = 13.0
	Game.population.set_physics_process(false)
	Game.population.clear_all()
	var base := Vector3(1080, 0.9, 380)
	var items := OS.get_environment("PVIEW").split(",")
	var ms: Array = []
	for it in items:
		var parts := it.split("@")
		var spec := parts[1] if parts.size() > 1 else "0"
		var ov := {"*debug": true} if parts.size() > 2 and parts[2] == "dbg" else {}
		var m := ModelUtil.make(parts[0], 0.0 if spec.begins_with("h") else float(spec), ov, float(spec.substr(1)) if spec.begins_with("h") else 0.0)
		Game.world.add_child(m)
		m.global_position = base
		m.visible = false
		var a := ModelUtil.mesh_aabb(m.get_child(0))
		print("[pview] ", parts[0].get_file(), " size=", a.size)
		for mk in [[Vector3(0, 0.3, a.size.z * 0.5 + 0.6), Color.RED], [Vector3(a.size.x * 0.5 + 0.6, 0.3, 0), Color.BLUE]]:
			var b := MeshInstance3D.new()
			b.mesh = BoxMesh.new()
			b.scale = Vector3.ONE * maxf(0.2, a.get_longest_axis_size() * 0.04)
			var mt := StandardMaterial3D.new()
			mt.albedo_color = mk[1]
			b.material_override = mt
			m.add_child(b)
			b.position = mk[0]
		ms.append([m, a, parts[0].get_file().get_basename()])
	for e in ms:
		var m: Node3D = e[0]
		var a: AABB = e[1]
		m.visible = true
		var r := a.get_longest_axis_size()
		var c := base + Vector3(0, a.size.y * 0.4, 0)
		_place_cam(c + Vector3(0.8, 0.55, 1.0).normalized() * r * 1.4, c)
		await _wait(0.3)
		await _shot("pview_" + e[2])
		m.visible = false
	get_tree().quit()


var _heli_v: Node = null
var _heli_log := 0.0
## Helicopter: spool up, climb, fly north, turn east, hover, descend and land.
func _heli() -> void:
	var p := Game.player
	if _heli_v == null:
		if t < 2.0:
			return
		Game.population.set_physics_process(false)
		Game.population.clear_all()
		var id := OS.get_environment("FLY_ID") if OS.get_environment("FLY_ID") != "" else "heli"
		_heli_v = VehicleDB.spawn(id, Vector3(-1500, CityMap.LAND + 0.4, -470), 0.0)
		p.global_position = Vector3(-1497, CityMap.LAND + 1.0, -470)
		await get_tree().physics_frame
		p.enter_vehicle(_heli_v, 0)
		return
	var v: Helicopter = _heli_v
	var ft := t - 2.0
	v.throttle = 0.0
	v.steer_input = 0.0
	v.lift_input = 0.0
	v.aim_dir = Vector3(0, 0, -1)
	if ft < 5.0:
		pass
	elif ft < 11.0:
		v.lift_input = 1.0
	elif ft < 21.0:
		v.throttle = 1.0
	elif ft < 27.0:
		v.aim_dir = Vector3(1, 0, 0)
		v.throttle = 0.6
	elif ft < 33.0:
		v.aim_dir = Vector3(1, 0, 0)
	elif ft < 48.0:
		v.aim_dir = Vector3(1, 0, 0)
		v.lift_input = -1.0
	else:
		print("[heli] done hp=%.0f destroyed=%s" % [v.health, v.destroyed])
		if OS.get_environment("HELI_SHOTS") != "":
			return
		get_tree().quit()
		return
	if OS.get_environment("HELI_SHOTS") != "" and (int(ft) == 15 or int(ft) == 24) and step != int(ft):
		step = int(ft)
		Game.hud.visible = false
		var c: Vector3 = v.global_position + Vector3(0, 2, 0)
		_place_cam(c + v.global_basis * Vector3(9, 3, 12), c)
		await _shot("heli_%d" % int(ft))
		Game.camera_rig.set_physics_process(true)
		if ft > 23:
			get_tree().quit()
	if t - _heli_log >= 1.0:
		_heli_log = t
		var gb := v.global_basis
		print("[heli] t=%.0f rpm=%.2f spd=%.0f km/h alt=%.1f y=%.1f pitch=%.0f bank=%.0f hdg=%.0f air=%s hp=%.0f" % [ft, v.rotor_rpm, v.speed_kmh, v.altitude, v.global_position.y,
			rad_to_deg(asin(clampf(-gb.z.y, -1, 1))), rad_to_deg(asin(clampf(gb.x.y, -1, 1))), rad_to_deg(atan2(-gb.z.x, -gb.z.z)), v.airborne, v.health])


var _ch_log := 0.0
func _copheli() -> void:
	if t < 3.0:
		return
	if step == 0:
		step = 1
		Game.wanted.set_level(3)
		Game.god_mode = true
	if t - _ch_log >= 2.0:
		_ch_log = t
		var h = Game.wanted.heli
		if h and is_instance_valid(h):
			print("[copheli] t=%.0f dist=%.0f alt=%.0f spd=%.0f rpm=%.2f seen=%s stars=%d hp=%.0f" % [t, h.global_position.distance_to(Game.player.global_position), h.altitude, h.speed_kmh, h.rotor_rpm, Game.wanted.seen, Game.wanted.stars, Game.player.health])
		else:
			print("[copheli] t=%.0f no heli stars=%d" % [t, Game.wanted.stars])
	if t > 50.0 and step == 1:
		step = 2
		Game.wanted.clear()
		print("[copheli] cleared")
	if t > 62.0:
		var h = Game.wanted.heli
		print("[copheli] end heli_ref=%s" % [h])
		get_tree().quit()


## Quick close-ups of facades (shader checks). Optional env BSHOT_T = hour.
func _bshot() -> void:
	if step != 0 or t < 3.0:
		return
	step = 1
	Game.sky.time_of_day = float(OS.get_environment("BSHOT_T")) if OS.get_environment("BSHOT_T") != "" else 11.0
	Game.hud.visible = false
	if OS.get_environment("BSHOT_BEACH") != "":
		_place_cam(Vector3(1092, 7.0, 640), Vector3(1118, 2.0, 480))
		await _wait(1.0)
		await _shot("beach_towers")
		get_tree().quit()
		return
	_place_cam(Vector3(1045, 2.0, 700), Vector3(1010, 6, 690))
	await _wait(1.0)
	await _shot("facade_deco")
	_place_cam(Vector3(-470, 2.0, 60), Vector3(-500, 5, 20))
	await _wait(1.0)
	await _shot("facade_cuba")
	_place_cam(Vector3(40, 4, 380), Vector3(80, 40, 120))
	await _wait(1.0)
	await _shot("facade_towers")
	_place_cam(Vector3(600, 160, 700), Vector3(80, 60, 150))
	await _wait(1.0)
	await _shot("skyline")
	_place_cam(Vector3(50, 30, -700), Vector3(-100, 5, -900))
	await _wait(1.0)
	await _shot("stockyard")
	get_tree().quit()


## Views of the newer content: traffic lights, airport gates, cruise ships, sailboats.
func _shots2() -> void:
	if step != 0 or t < 7.0:
		return
	step = 1
	Game.sky.time_of_day = 16.0
	var city := Game.city
	# nearest signalised intersection to a downtown spot
	var best := -1
	var bd := INF
	for n in TrafficSignals.signals:
		var d: float = city.nodes[n].distance_to(Vector3(60, 0, 150))
		if d < bd:
			bd = d
			best = n
	var c: Vector3 = city.nodes[best]
	Game.player.global_position = c + Vector3(12, 0.5, 12)
	await _wait(8.0)
	_place_cam(c + Vector3(-9, 4.5, 28), c + Vector3(0, 3, 0))
	await _wait(0.5)
	await _shot("signals_day")
	var cnt_stopped := 0
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v is Vehicle and v.ai_owned and v.global_position.distance_to(c) < 60.0 and absf(v.forward_speed) < 0.5:
			cnt_stopped += 1
	print("[shots2] vehicles stopped near intersection: ", cnt_stopped)
	Game.sky.time_of_day = 21.5
	await _wait(1.0)
	await _shot("signals_night")
	Game.sky.time_of_day = 16.0
	Game.player.global_position = Vector3(-1350, 1.5, -560)
	await _wait(2.0)
	_place_cam(Vector3(-1300, 25, -560), Vector3(-1380, 3, -650))
	await _wait(0.5)
	await _shot("airport_gates")
	_place_cam(Vector3(-1560, 12, -420), Vector3(-1600, 2, -480))
	await _wait(0.5)
	await _shot("airport_hangars")
	Game.player.global_position = Vector3(640, 1.5, 700)
	await _wait(2.0)
	_place_cam(Vector3(660, 40, 470), Vector3(750, 10, 650))
	await _wait(0.5)
	await _shot("port_cruise")
	_place_cam(Vector3(560, 30, -200), Vector3(650, 0, 100))
	await _wait(0.5)
	await _shot("bay_sailboats")
	get_tree().quit()


func _spawnperf() -> void:
	if step != 0 or t < 1.0:
		return
	step = 1
	for round in 2:
		for id in VehicleDB.CARS:
			var t0 := Time.get_ticks_usec()
			var v = VehicleDB.spawn(id, Vector3(1100, 5, 300), 0.0)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			if dt > 8.0:
				print("[spawnperf] round %d %s %.1f ms" % [round, id, dt])
			v.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## Promotional views for the README: brand cars on Ocean Drive, a vehicle line-up, airport, port.
func _readme() -> void:
	if step != 0 or t < 7.0:
		return
	step = 1
	Game.sky.time_of_day = 17.6
	Game.population.set_physics_process(false)
	Game.population.clear_all()
	Game.hud.visible = false
	# brand cars parked along Ocean Drive (road at x=1030, heading north = -Z)
	var ids := ["b_m8", "b_m5", "b_challenger", "b_roadster"]
	var paints := [Color(0.05, 0.05, 0.06), Color(0.75, 0.08, 0.1), Color(0.9, 0.9, 0.92), Color(0.1, 0.55, 0.7)]
	for i in ids.size():
		VehicleDB.spawn(ids[i], Vector3(1024.0 + (i % 2) * 3.4, 1.4, 520.0 - i * 7.5), 0.0, paints[i])
	Game.player.global_position = Vector3(1040, 1.2, 470)
	await _wait(3.0)
	_place_cam(Vector3(1036, 2.6, 500), Vector3(1025.5, 0.9, 506))
	await _wait(0.5)
	await _shot("brand_cars")
	# line-up of the other vehicles on the beach
	var base := Vector3(1075, 1.2, 600)
	var line := ["p_police", "b_ferrari", "p_taxi", "p_suv", "p_bus", "p_ambulance", "b_mclaren", "b_camaro"]
	for i in line.size():
		var v = VehicleDB.spawn(line[i], base + Vector3((i % 4) * 9.0, 0.5, (i / 4) * 14.0), PI * 0.15)
		if line[i] in ["p_police", "p_ambulance"]:
			v.siren_on = true
	await _wait(3.0)
	_place_cam(base + Vector3(14, 8, 34), base + Vector3(14, 0, 8))
	await _wait(0.5)
	await _shot("vehicles")
	Game.sky.time_of_day = 16.5
	Game.player.global_position = Vector3(-1350, 1.5, -560)
	await _wait(2.0)
	_place_cam(Vector3(-1290, 30, -560), Vector3(-1380, 3, -650))
	await _wait(0.5)
	await _shot("airport")
	Game.player.global_position = Vector3(640, 1.5, 700)
	await _wait(2.0)
	_place_cam(Vector3(660, 45, 450), Vector3(750, 8, 660))
	await _wait(0.5)
	await _shot("port")
	get_tree().quit()


## Flight test (headless): take off from runway 09, climb, turn left, level off, bail out.
## FLY_ID selects the aircraft (cessna, jet, airliner).
var _plane: Node
var _fly_log := 0.0
func _fly() -> void:
	var p := Game.player
	if _plane == null:
		if t < 2.0:
			return
		Game.population.set_physics_process(false)
		Game.population.clear_all()
		var id := OS.get_environment("FLY_ID")
		if id == "":
			id = "cessna"
		_plane = VehicleDB.spawn(id, Vector3(-1760, CityMap.LAND + 0.3, -300), -PI * 0.5)
		p.global_position = Vector3(-1760, CityMap.LAND + 1.0, -290)
		await get_tree().physics_frame
		p.enter_vehicle(_plane, 0)
		_fly_log = t
		return
	var v: Aircraft = _plane
	var ft := t - 2.0
	var east := Vector3(1, 0, 0)
	var north := Vector3(0, 0, -1)
	if p.vehicle == v:
		v.throttle = 1.0
		if v.forward_speed < v._v_stall * 1.05 and not v.airborne:
			v.aim_dir = east
		elif ft < 30.0:
			v.aim_dir = (east + Vector3.UP * 0.3).normalized()
		elif ft < 45.0:
			v.aim_dir = (north + Vector3.UP * 0.05).normalized()
		else:
			v.aim_dir = north
			v.throttle = 0.0
		if ft > 55.0 and v.airborne:
			p.exit_vehicle(true)
			p.parachute_in = 1.0
			print("[fly] bail out at alt %.0f" % v.altitude)
	if t - _fly_log >= 1.0:
		_fly_log = t
		var gb := v.global_basis
		var pitch := rad_to_deg(asin(clampf(-gb.z.y, -1, 1)))
		var bank := rad_to_deg(asin(clampf(gb.x.y, -1, 1)))
		var hdg := rad_to_deg(atan2(-gb.z.x, gb.z.z))
		print("[fly] t=%.0f spd=%.0f km/h alt=%.0f pow=%.2f pitch=%.0f bank=%.0f hdg=%.0f air=%s stall=%s hp=%.0f | player y=%.1f vy=%.1f chute=%s" % [
			ft, v.speed_kmh, v.altitude, v.power, pitch, bank, hdg, v.airborne, v.stalled, v.health,
			p.global_position.y, p.velocity.y, p._chute != null])
	if ft > 55.0 and p.vehicle == null and p.is_on_floor() and ft > 58.0:
		print("[fly] landed by parachute, player hp=%.0f dead=%s" % [p.health, p.dead])
		get_tree().quit()
	if ft > 140.0:
		print("[fly] timeout")
		get_tree().quit()


func _flyshots() -> void:
	if step != 0 or t < 7.0:
		return
	step = 1
	var p := Game.player
	Game.sky.time_of_day = 17.8
	Game.hud.visible = true
	# parked aircraft at the hangars
	p.global_position = Vector3(-1560, 1.5, -430)
	await _wait(2.0)
	_place_cam(Vector3(-1530, 9, -415), Vector3(-1600, 2, -470))
	await _wait(0.5)
	await _shot("hangars")
	# in flight over Ocean Beach, chase camera
	var v: Aircraft = VehicleDB.spawn("cessna", Vector3(1000, 160, 900), 0.0)
	await get_tree().physics_frame
	v.linear_velocity = Vector3(0, 0, -50)
	p.enter_vehicle(v, 0)
	v.power = 0.8
	var rig: CameraRig = Game.camera_rig
	rig.set_physics_process(true)
	rig.target = p
	rig.yaw = 0.0
	rig.pitch = -0.25
	await _wait(3.0)
	await _shot("flying_cessna")
	# bail out: parachute over the beach
	p.exit_vehicle(true)
	p.parachute_in = 0.3
	await _wait(2.5)
	rig.yaw = 0.8
	await _wait(0.5)
	await _shot("parachute")
	get_tree().quit()
