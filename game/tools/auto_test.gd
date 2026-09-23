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
		var v: Vehicle = VehicleDB.spawn("sedanSports", p.global_position + Vector3(0, 1, -6), 0.0)
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
		if t > 5.0 and _shot_i == 0:
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
	var base := Vector3(1060, 1.2, 400)
	var ids := ["sedan", "sedanSports", "police", "taxi", "nb_convertible", "nb_charger", "suvLuxury", "raceFuture", "nb_pickup", "ambulance", "garbageTruck", "motorcycle"]
	for i in ids.size():
		var v = VehicleDB.spawn(ids[i], base + Vector3((i % 4) * 7.0, 0.5, (i / 4) * 9.0), PI * 0.25)
		v.freeze = false
	await _wait(2.5)
	_place_cam(base + Vector3(10, 7, 30), base + Vector3(10, 0, 8))
	await _wait(1.0)
	await _shot("gallery_cars")
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
	# player driving the convertible
	var car = VehicleDB.spawn("nb_convertible", base + Vector3(0, 0.6, -30), 0.0, Color(0.95, 0.35, 0.6))
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
	var b = VehicleDB.spawn("speedboat", Vector3(1250, 0.5, 400), 0.0)
	VehicleDB.spawn("yacht", Vector3(1270, 0.5, 430), 0.5)
	VehicleDB.spawn("dinghy", Vector3(1235, 0.5, 420), 1.0)
	await _wait(3.0)
	_place_cam(b.global_position + Vector3(-18, 8, 20), b.global_position)
	await _wait(0.5)
	await _shot("gallery_boats")
	print("[test] OK gallery finished")
	get_tree().quit()
