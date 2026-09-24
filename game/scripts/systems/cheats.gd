class_name Cheats
extends RefCounted
## Classic GTA-style cheat codes (typed in the T console).


static func apply(code: String) -> void:
	var p := Game.player
	if p == null:
		return
	var ok := true
	match code:
		"DINERO", "MONEY":
			Game.add_money(250000)
		"ARMAS", "GUNS":
			for id in ["pistol", "smg", "rifle", "shotgun", "sniper", "rpg"]:
				p.give_weapon(id, int(WeaponDB.get_def(id).clip) * 8)
			p.give_weapon("grenade", 10)
		"VIDA", "HEALTH":
			p.health = p.max_health
			p.armor = 100.0
			if p.vehicle and p.vehicle.has_method("repair"):
				p.vehicle.repair()
		"DIOS", "GOD":
			Game.god_mode = not Game.god_mode
			Game.msg("Modo dios: %s" % ("ON" if Game.god_mode else "OFF"))
		"MUNICION", "AMMO":
			Game.infinite_ammo = not Game.infinite_ammo
			Game.msg("Munición infinita: %s" % ("ON" if Game.infinite_ammo else "OFF"))
		"SINPOLICIA", "NOPOLICE":
			Game.wanted.clear()
		"POLICIA5", "WANTED":
			Game.wanted.set_level(5)
		"SUPERCOCHE", "SUPERCAR":
			_spawn("b_mclaren")
		"DEPORTIVO":
			_spawn("b_m5")
		"TAXI":
			_spawn("p_taxi")
		"AMBULANCIA":
			_spawn("p_ambulance")
		"BOMBEROS":
			_spawn("p_firetruck")
		"MCLAREN":
			_spawn("b_mclaren")
		"MONSTRUO", "MONSTER":
			_spawn("b_monster")
		"FORMULA1", "F1":
			_spawn("b_f1")
		"CAMION":
			_spawn("p_garbage")
		"AUTOBUS", "BUS":
			_spawn("p_bus")
		"AVIONETA", "PLANE":
			_spawn("cessna")
		"JET":
			_spawn("jet")
		"CAZA", "RAFALE":
			_spawn("fighter")
		"JUMBO", "AVION":
			# airliners need a runway: go to the threshold of the southern runway
			if p.vehicle:
				p.exit_vehicle()
			var a: Node3D = VehicleDB.spawn("airliner", Vector3(-1740, CityMap.LAND + 0.3, -300), -PI * 0.5)
			p.global_position = Vector3(-1740, CityMap.LAND + 1.0, -280)
			p.enter_vehicle(a, 0)
		"INFERNUS", "FERRARI":
			_spawn("b_ferrari")
		"PATRULLA", "COPCAR":
			_spawn("p_police")
		"DRAGSTER", "PORSCHE":
			_spawn("b_porsche")
		"LANCHA", "BOAT":
			var pos := p.global_position
			# find water nearby
			var best := Vector3.ZERO
			for r in [20.0, 40.0, 80.0, 150.0, 300.0]:
				for i in 16:
					var a := TAU * i / 16.0
					var q = pos + Vector3(cos(a), 0, sin(a)) * r
					if Game.city.height_at(q.x, q.z) < -2.0:
						best = q
						break
				if best != Vector3.ZERO:
					break
			if best == Vector3.ZERO:
				ok = false
			else:
				VehicleDB.spawn("cruiser", Vector3(best.x, 0.5, best.z), 0.0)
				Game.msg("Lancha disponible en el agua cercana")
		"TORMENTA", "STORM":
			Game.sky.set_weather("storm")
		"LLUVIA", "RAIN":
			Game.sky.set_weather("rain")
		"SOL", "SUNNY":
			Game.sky.set_weather("clear")
		"NOCHE", "NIGHT":
			Game.sky.time_of_day = 23.0
		"MEDIODIA", "NOON":
			Game.sky.time_of_day = 12.0
		"ATARDECER", "SUNSET":
			Game.sky.time_of_day = 18.8
		"RAPIDO", "FASTTIME":
			Game.sky.minutes_per_second = 10.0 if Game.sky.minutes_per_second < 5.0 else 1.0
		"CAOS", "RIOT":
			for h in Game.population.peds:
				if is_instance_valid(h) and not h.dead and h.brain:
					h.give_weapon(["pistol", "smg", "shotgun"][randi() % 3], 60)
					h.select_weapon(1)
					h.brain.aggressive = true
					h.brain.hostile_to_player = randf() < 0.5
		"TELEPORT":
			if Game.has_meta("waypoint"):
				var w: Vector3 = Game.get_meta("waypoint")
				var target := Vector3(w.x, maxf(Game.city.height_at(w.x, w.z), 0.0) + 2.0, w.z)
				if p.vehicle:
					p.vehicle.global_position = target
					p.vehicle.linear_velocity = Vector3.ZERO
				else:
					p.global_position = target
			else:
				ok = false
				Game.msg("Marca un destino en el mapa (M) primero")
		_:
			ok = false
	if ok:
		Game.cheats_used += 1
		Game.msg("Truco activado: " + code, 2.5)
		Sfx.play("pickup")
	else:
		Game.msg("Truco desconocido", 1.5)


static func _spawn(id: String) -> void:
	var p := Game.player
	var fwd := -p.global_basis.z
	if VehicleDB.PLANES.has(id):
		# planes appear in front of the player, facing the same way (clear of the wings)
		var d: float = float(VehicleDB.PLANES[id].length) * 0.8 + 4.0
		VehicleDB.spawn(id, p.global_position + fwd * d + Vector3.UP * 0.5, p.global_rotation.y)
		return
	var pos := p.global_position + fwd * 6.0 + Vector3.UP * 1.0
	VehicleDB.spawn(id, pos, p.global_rotation.y + PI * 0.5)
