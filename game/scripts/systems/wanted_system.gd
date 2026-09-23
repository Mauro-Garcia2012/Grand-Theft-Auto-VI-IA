class_name WantedSystem
extends Node
## Wanted level (1-5 stars), police dispatch, search area & evasion, BUSTED / WASTED.

var stars := 0
var heat := 0.0
var last_seen := Vector3.ZERO
var seen := false
var evade_t := 0.0
var dispatch_t := 0.0
var units: Array = []           # police vehicles dispatched
var foot_cops: Array = []
var bust_t := 0.0
var respawning := false
var _crime_cd := {}


func _ready() -> void:
	Game.wanted = self


func report_crime(pos: Vector3, severity: float, kind := "") -> void:
	if respawning or Game.player == null or Game.player.dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if kind == "call":
		# a witness called the police
		if stars == 0 and heat > 0.0:
			_set_stars(1)
		return
	if _crime_cd.get(kind, 0.0) > now and kind in ["shots", "assault"]:
		return
	_crime_cd[kind] = now + 2.0
	# witnesses?
	var witnessed := false
	for h in get_tree().get_nodes_in_group("humanoids"):
		if h.dead or h == Game.player or h.team == "player":
			continue
		var d: float = h.global_position.distance_to(pos)
		if d < (70.0 if h.team == "police" else 35.0):
			witnessed = true
			break
	heat += severity
	if not witnessed and stars == 0:
		return
	var min_stars := 0
	match kind:
		"shots": min_stars = 1
		"assault": min_stars = 1 if heat > 1.5 else 0
		"carjack": min_stars = 1
		"hit_ped": min_stars = 1 if heat > 2.0 else 0
		"murder": min_stars = 2
		"cop_killed": min_stars = 3
		"explosion": min_stars = 2
		"robbery": min_stars = 2
	var from_heat := 0
	if heat >= 3: from_heat = 1
	if heat >= 8: from_heat = 2
	if heat >= 18: from_heat = 3
	if heat >= 32: from_heat = 4
	if heat >= 50: from_heat = 5
	var ns := clampi(maxi(maxi(stars, min_stars), from_heat), 0, 5)
	if kind in ["cop_killed", "murder"] and stars >= min_stars:
		heat += 4.0
	last_seen = pos
	if ns > stars:
		_set_stars(ns)


func set_level(n: int) -> void:
	heat = [0.0, 3.0, 8.0, 18.0, 32.0, 50.0][clampi(n, 0, 5)]
	_set_stars(n)


func _set_stars(n: int) -> void:
	var old := stars
	stars = clampi(n, 0, 5)
	if stars > old:
		Sfx.play("wanted", -4.0)
		evade_t = 0.0
		dispatch_t = 0.5
	Game.wanted_changed.emit(stars)
	if stars == 0:
		_stand_down()


func clear() -> void:
	heat = 0.0
	_set_stars(0)


func search_radius() -> float:
	return 70.0 + stars * 45.0


func _stand_down() -> void:
	for v in units:
		if is_instance_valid(v):
			var d = v.driver()
			if d and d.brain and d.brain.driver_ai:
				d.brain.driver_ai.mode = DriverAI.M.CRUISE
				d.brain.driver_ai.from_node = -1
				v.siren_on = false
	units.clear()
	for c in foot_cops:
		if is_instance_valid(c) and c.brain:
			c.brain.threat = null
			c.brain.start_wander()
	foot_cops.clear()


func _physics_process(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	if p.dead and not respawning:
		_wasted()
		return
	if stars == 0:
		heat = maxf(0.0, heat - delta * 0.15)
		return
	# can any cop see the player?
	seen = false
	var pp := Game.player_pos()
	for h in get_tree().get_nodes_in_group("humanoids"):
		if h.team != "police" or h.dead:
			continue
		var d: float = h.global_position.distance_to(pp)
		if d < 90.0:
			var eye: Vector3 = h.global_position + Vector3.UP * 1.6
			if h.vehicle:
				eye = h.vehicle.global_position + Vector3.UP * 1.8
			var hit := Combat.raycast(eye, pp + Vector3.UP * 1.2, [h, p, h.vehicle, p.vehicle], Game.LAYER_WORLD)
			if hit.is_empty():
				seen = true
				break
	if seen:
		last_seen = pp
		evade_t = 0.0
	else:
		if pp.distance_to(last_seen) > search_radius():
			evade_t += delta
		else:
			evade_t += delta * 0.25
		if evade_t > 8.0 + stars * 4.0:
			Game.msg("Has despistado a la policía", 3.0)
			clear()
			return
	# dispatch units
	dispatch_t -= delta
	if dispatch_t <= 0.0:
		dispatch_t = 6.0
		_dispatch()
	_update_units()
	_check_bust(delta)


func _dispatch() -> void:
	var want_cars = [0, 1, 2, 3, 4, 5][stars]
	var alive := 0
	for i in range(units.size() - 1, -1, -1):
		if not is_instance_valid(units[i]) or units[i].destroyed:
			units.remove_at(i)
		else:
			alive += 1
	if alive >= want_cars:
		return
	var pop: Population = Game.population
	var sp := pop._random_lane_point(90.0, 180.0)
	if sp.is_empty():
		return
	var swat := stars >= 4 and randf() < 0.5
	var id: String = "van" if swat else ["q_cop", "q_cop", "q_cop_suv", "police", "nb_police"].pick_random()
	var v := pop.spawn_traffic_car(id, sp.pos, sp.yaw, sp.a, sp.b, "police")
	var drv: Humanoid = v.get_meta("driver")
	drv.team = "police"
	drv.give_weapon("smg" if stars >= 3 else "pistol", 200)
	drv.select_weapon(1)
	drv.brain.driver_ai.start_pursuit(Game.player)
	v.siren_on = true
	# partner
	var partner := pop.spawn_cop(sp.pos + Vector3.UP * 2.0, swat)
	partner.enter_vehicle(v, 1)
	partner.brain.state = PedBrain.S.DRIVE
	units.append(v)


func _update_units() -> void:
	var pp := Game.player_pos()
	var p := Game.player
	for v in units:
		if not is_instance_valid(v) or v.destroyed:
			continue
		var d = v.global_position.distance_to(pp)
		var drv = v.driver()
		if drv and drv.brain and drv.brain.driver_ai:
			drv.brain.driver_ai.target = p
		# get out and fight when close and the player is on foot (or stopped)
		var player_slow = p.vehicle == null or p.vehicle.linear_velocity.length() < 3.0
		if d < 28.0 and player_slow and v.linear_velocity.length() < 4.0:
			for o in v.occupants.duplicate():
				if o != null and is_instance_valid(o) and not o.dead and o.team == "police":
					o.exit_vehicle()
					o.brain.threat = p
					o.brain.state = PedBrain.S.FIGHT
					o.brain.t = 60.0
					foot_cops.append(o)
		# drive-by shooting from cop cars at 3+ stars
		if stars >= 3 and d < 35.0:
			for o in v.occupants:
				if o != null and is_instance_valid(o) and o.seat == 1 and randf() < 0.08:
					o.aim_point = pp + Vector3.UP
					o.aiming = true
					o.try_fire()
	# foot cops always know where the player is while wanted
	for c in foot_cops:
		if is_instance_valid(c) and not c.dead and c.brain and c.vehicle == null:
			if stars == 1:
				# try to arrest instead of shooting
				c.brain.threat = p
				c.brain.state = PedBrain.S.FIGHT
				c.aiming = false
				var to: Vector3 = p.global_position - c.global_position
				c.move_dir = Vector3(to.x, 0, to.z).normalized() if to.length() > 1.2 else Vector3.ZERO
				c.want_sprint = to.length() > 5.0
			else:
				c.brain.threat = p
				c.brain.state = PedBrain.S.FIGHT


func _check_bust(delta: float) -> void:
	var p := Game.player
	if stars > 2 or p.vehicle != null or p.dead:
		bust_t = 0.0
		return
	var near := false
	for c in foot_cops:
		if is_instance_valid(c) and not c.dead and c.global_position.distance_to(p.global_position) < 1.8:
			near = true
	if near and Vector2(p.velocity.x, p.velocity.z).length() < 2.5 and not p.aiming:
		bust_t += delta
		if bust_t > 1.6:
			_busted()
	else:
		bust_t = maxf(0.0, bust_t - delta)


func _busted() -> void:
	respawning = true
	var p := Game.player
	Game.big_message.emit("BUSTED", "Has sido arrestado", Color(0.3, 0.55, 1.0))
	Game.stats.busted += 1
	p.move_dir = Vector3.ZERO
	await get_tree().create_timer(3.0).timeout
	var loss := mini(Game.money, 500 + stars * 250)
	Game.money -= loss
	p.weapons = [{"id": "fists", "clip": 0, "ammo": 0}]
	p.select_weapon(0)
	var loc: Locations = Game.get_meta("locations")
	var st := loc.nearest("police", p.global_position)
	_respawn(st.get("spawn", st.get("pos", p.global_position)))
	Game.msg("Multa: -$%d. Te han requisado las armas." % loss, 5.0)


func _wasted() -> void:
	respawning = true
	var p := Game.player
	Game.stats.wasted += 1
	Game.big_message.emit("WASTED", "", Color(0.9, 0.15, 0.15))
	Engine.time_scale = 0.35
	await get_tree().create_timer(1.6).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.5).timeout
	var loss := mini(Game.money, 1000)
	Game.money -= loss
	var loc: Locations = Game.get_meta("locations")
	var hos := loc.nearest("hospital", p.global_position)
	_respawn(hos.get("spawn", hos.get("pos", p.global_position)))
	Game.msg("Factura del hospital: -$%d" % loss, 5.0)


func _respawn(pos: Vector3) -> void:
	var p := Game.player
	if Game.hud:
		Game.hud.fade(0.5)
	await get_tree().create_timer(0.5).timeout
	if p.vehicle:
		p.exit_vehicle()
	p.dead = false
	p.health = p.max_health
	p.armor = 0.0
	p.collision_layer = Game.LAYER_CHAR
	p.collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE | Game.LAYER_CHAR
	p.global_position = pos + Vector3.UP * 0.5
	p.velocity = Vector3.ZERO
	p.down_timer = 0.0
	if p.model:
		p.model.restart("Idle")
	p.select_weapon(p.weapon_index)
	p._weapon_model_id = ""
	p._update_weapon_model()
	clear()
	Game.population.clear_all()
	# companion joins
	for o in Game.protagonists:
		if o != p:
			if o.dead:
				o.dead = false
				o.health = o.max_health
				o.collision_layer = Game.LAYER_CHAR
				o.collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE | Game.LAYER_CHAR
				if o.model:
					o.model.restart("Idle")
			if o.vehicle:
				o.exit_vehicle()
			o.global_position = pos + Vector3(1.5, 0.5, 1.0)
	respawning = false
