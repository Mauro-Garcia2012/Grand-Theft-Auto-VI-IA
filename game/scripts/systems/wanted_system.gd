class_name WantedSystem
extends Node
## Wanted level (1-6 stars), police dispatch, search area & evasion, BUSTED / WASTED.
## 1-2: patrols, 3: helicopter and roadblocks, 4: SWAT, 5: the army, 6: the air force (fighter jet).

var stars := 0
var heat := 0.0
var last_seen := Vector3.ZERO
var seen := false
var evade_t := 0.0
var dispatch_t := 0.0
var units: Array = []           # police vehicles dispatched
var heli: Node = null           # first police helicopter (3+ stars)
var helis: Array = []           # one at 3-4 stars, two at 5
var foot_cops: Array = []
var roadblocks: Array = []      # police cars parked across the road + their cops (3+ stars)
var _roadblock_t := 15.0
var jets: Array = []            # air force fighters (6 stars)
var _search: Node3D             # where units go when they have lost sight of the player
var _search_t := 0.0
var bust_t := 0.0
var respawning := false
var _crime_cd := {}


func _ready() -> void:
	Game.wanted = self
	_search = Node3D.new()
	_search.name = "SearchPoint"
	add_child(_search)


## Chance that someone reports each kind of crime the first time (it grows with every repeat).
const REPORT_CHANCE := {"shots": 0.2, "hit_ped": 0.25, "assault": 0.15, "carjack": 0.3, "explosive": 0.35,
	"murder": 0.55, "explosion": 0.6, "robbery": 0.9, "cop_killed": 1.0}
## Minimum wanted level of each crime once reported.
const MIN_STARS := {"shots": 1, "hit_ped": 1, "assault": 1, "carjack": 1, "explosive": 2, "murder": 2,
	"explosion": 2, "robbery": 2, "cop_killed": 3}

var pending: Array = []         # reports on their way: {due, kind, pos, witness, police}
var _recent: Array = []         # [time, kind] of the player's recent crimes (repeats raise the odds)


## A crime happened. It is not reported straight away: somebody has to see it (a cop or a
## civilian), and whether they report it depends on the crime and on how many times the player
## has done it lately. A cop reacts in 1-2.5 s; a civilian takes a few seconds to phone the police
## (kill them before they finish and there is no call). Crimes seen by cops while already wanted
## raise the level the same way.
func report_crime(pos: Vector3, severity: float, kind := "", witness: Node = null) -> void:
	if respawning or Game.player == null or Game.player.dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if kind == "call":
		# a victim/witness decided to phone (from the ped brains)
		if heat > 0.0 and witness != null and not _has_pending_from(witness):
			_queue(witness.global_position, "call", witness, false, randf_range(5.0, 9.0))
		return
	if _crime_cd.get(kind, 0.0) > now and kind in ["shots", "assault", "hit_ped"]:
		return
	_crime_cd[kind] = now + 2.0
	heat += severity
	_recent.append([now, kind])
	while not _recent.is_empty() and now - float(_recent[0][0]) > 150.0:
		_recent.pop_front()
	var repeats := 0
	for r in _recent:
		repeats += 1 if r[1] == kind else 0
	# who saw it?
	var cop: Node = null
	var civ: Node = null
	var best_cop := 55.0 if stars == 0 else 80.0
	var best_civ := 35.0
	for h in Game.humanoids():
		if h.dead or h == Game.player or h.team == "player" or str(h.team).begins_with("gang"):
			continue
		var d: float = h.global_position.distance_to(pos)
		if h.team == "police" and d < best_cop:
			var eye: Vector3 = h.global_position + Vector3.UP * 1.6
			if Combat.raycast(eye, pos + Vector3.UP * 1.2, [h, Game.player, h.vehicle, Game.player.vehicle], Game.LAYER_WORLD).is_empty():
				best_cop = d
				cop = h
		elif h.team != "police" and d < best_civ and h.vehicle == null:
			best_civ = d
			civ = h
	if cop != null:
		_queue(pos, kind, cop, true, randf_range(1.0, 2.5))
		return
	if civ == null:
		return
	var chance: float = REPORT_CHANCE.get(kind, 0.3) + 0.22 * (repeats - 1)
	chance *= Game.by_difficulty([0.7, 1.0, 1.25, 1.5])
	if stars > 0:
		chance += 0.25          # people are already on the lookout
	if randf() > chance or _has_pending_from(civ):
		return
	_queue(pos, kind, civ, false, randf_range(4.0, 8.0) * Game.by_difficulty([1.3, 1.0, 0.8, 0.7]))


## Store alarms and such: the police are told after `delay` seconds, no matter what.
func alarm(min_stars: int, delay: float, pos: Vector3) -> void:
	pending.append({"due": Time.get_ticks_msec() / 1000.0 + delay, "kind": "alarm", "pos": pos, "witness": null,
		"police": true, "min": min_stars})


func _has_pending_from(w: Node) -> bool:
	for r in pending:
		if r.witness == w:
			return true
	return false


func _queue(pos: Vector3, kind: String, witness: Node, police: bool, delay: float) -> void:
	pending.append({"due": Time.get_ticks_msec() / 1000.0 + delay, "kind": kind, "pos": pos, "witness": witness,
		"police": police, "min": MIN_STARS.get(kind, 1)})
	if not police and witness is Humanoid:
		# the witness gets the phone out (GTA IV/V style)
		var w: Humanoid = witness
		if w.brain and "state" in w.brain and w.brain.state in [PedBrain.S.WANDER, PedBrain.S.IDLE, PedBrain.S.BEACH]:
			w.move_dir = Vector3.ZERO
			w.brain.state = PedBrain.S.IDLE
			w.brain.t = delay + 1.0
			w.brain.idle_anim = "Idle_TalkingPhone"
		if w.global_position.distance_to(Game.player_pos()) < 60.0:
			Game.msg("📱 Un testigo está llamando a la policía...", 2.5)


func _process_pending() -> void:
	if pending.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(pending.size() - 1, -1, -1):
		var r: Dictionary = pending[i]
		if now < float(r.due):
			continue
		pending.remove_at(i)
		var w = r.witness
		if r.kind != "alarm" and (w == null or not is_instance_valid(w) or w.dead):
			if not r.police:
				Game.msg("El testigo no llegó a llamar", 2.0)
			continue
		if respawning or Game.player == null or Game.player.dead:
			continue
		var from_heat := 0
		for th in [[3.0, 1], [8.0, 2], [18.0, 3], [32.0, 4], [50.0, 5], [75.0, 6]]:
			if heat >= th[0]:
				from_heat = th[1]
		var ns := clampi(maxi(maxi(stars, int(r.min)), mini(from_heat, stars + 1)), 0, 6)
		if r.kind in ["cop_killed", "murder"] and stars >= int(r.min):
			heat += 4.0
			ns = clampi(maxi(ns, mini(from_heat, 6)), 0, 6)
		last_seen = r.pos
		if ns > stars:
			_set_stars(ns)
		elif stars > 0:
			# already wanted: the report refreshes where they look for you
			evade_t = 0.0


func set_level(n: int) -> void:
	heat = [0.0, 3.0, 8.0, 18.0, 32.0, 50.0, 75.0][clampi(n, 0, 6)]
	_set_stars(n)


func _set_stars(n: int) -> void:
	var old := stars
	stars = clampi(n, 0, 6)
	if stars > old:
		Sfx.play("wanted", -4.0)
		evade_t = 0.0
		# the first units need a few seconds to be sent
		dispatch_t = randf_range(2.0, 4.0) if old == 0 else 1.0
	Game.wanted_changed.emit(stars)
	if stars == 0:
		_stand_down()


func clear() -> void:
	heat = 0.0
	_set_stars(0)


func search_radius() -> float:
	return 80.0 + stars * 55.0


func _stand_down() -> void:
	for hh in helis:
		if hh != null and is_instance_valid(hh):
			var ai = hh.get_node_or_null("HeliAI")
			if ai:
				ai.leaving = true
	helis.clear()
	heli = null
	for j in jets:
		if j != null and is_instance_valid(j):
			var ja = j.get_node_or_null("JetAI")
			if ja:
				ja.leaving = true
	jets.clear()
	_clear_roadblocks(0.0)
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
	_process_pending()
	if stars == 0:
		heat = maxf(0.0, heat - delta * 0.15)
		return
	# can any cop see the player?
	seen = false
	var pp := Game.player_pos()
	for h in Game.humanoids():
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
		if evade_t > (10.0 + stars * 5.0) * Game.by_difficulty([0.6, 1.0, 1.3, 1.6]):
			Game.msg("Has despistado a la policía", 3.0)
			clear()
			return
	# where the units drive: the player while seen, else a search point around the last sighting
	_search_t -= delta
	if seen:
		_search.global_position = pp
	elif _search_t <= 0.0:
		_search_t = 7.0
		var a := randf() * TAU
		_search.global_position = last_seen + Vector3(cos(a), 0, sin(a)) * randf() * search_radius() * 0.6
	# dispatch units
	dispatch_t -= delta
	if dispatch_t <= 0.0:
		dispatch_t = 6.0
		_dispatch()
	_roadblock_t -= delta
	if stars >= 3 and _roadblock_t <= 0.0:
		_roadblock_t = 8.0
		if _try_roadblock():
			_roadblock_t = Game.by_difficulty([60.0, 40.0, 30.0, 25.0])
	_clear_roadblocks(260.0)
	_update_units()
	_check_bust(delta)


func _dispatch() -> void:
	for i in range(helis.size() - 1, -1, -1):
		var hh = helis[i]
		if hh == null or not is_instance_valid(hh) or hh.destroyed or hh.active_driver() == null:
			helis.remove_at(i)
	var want_helis: int = 0 if stars < 3 else [1, 1, 2, 3][stars - 3]
	if helis.size() < want_helis:
		_spawn_heli()
	heli = helis[0] if not helis.is_empty() else null
	# 6 stars: the air force sends a fighter jet
	for i in range(jets.size() - 1, -1, -1):
		if jets[i] == null or not is_instance_valid(jets[i]) or jets[i].destroyed:
			jets.remove_at(i)
	if stars >= 6 and jets.is_empty():
		_spawn_jet()
	var want_cars := clampi(stars + 1 + int(Game.by_difficulty([-1, 0, 1, 2])), 2, 8)
	var alive := 0
	for i in range(units.size() - 1, -1, -1):
		var u = units[i]
		# a car whose crew is dead no longer counts
		if not is_instance_valid(u) or u.destroyed or u.active_driver() == null:
			units.remove_at(i)
		else:
			alive += 1
	if alive >= want_cars:
		return
	var pop: Population = Game.population
	var sp := pop._random_lane_point(90.0, 180.0)
	if sp.is_empty():
		return
	# 4 stars: SWAT; 5 stars: the army joins in (soldiers in military pickups)
	var army := stars >= 6 or (stars >= 5 and randf() < 0.55)
	var swat := army or (stars >= 4 and randf() < 0.5)
	var id: String = "b_canyon" if army else ("p_suv" if swat else "p_police")
	var v := pop.spawn_traffic_car(id, sp.pos, sp.yaw, sp.a, sp.b, "police")
	var drv: Humanoid = v.get_meta("driver")
	drv.team = "police"
	if army and drv.model:
		drv.model.set_outfit("soldier", Color(1, 1, 1), true)
	drv.give_weapon("rifle" if army else ("smg" if stars >= 3 else "pistol"), 200)
	drv.select_weapon(1)
	drv.brain.driver_ai.start_pursuit(Game.player)
	if "siren_on" in v and v.def.get("siren", false):
		v.siren_on = true
	# partners (the army and SWAT come in fours)
	for s in (range(1, 4) if swat else [1]):
		var partner := pop.spawn_cop(sp.pos + Vector3.UP * (2.0 + s), swat)
		if army:
			partner.give_weapon("mg" if s == 1 else "rifle", 300, true)
		partner.enter_vehicle(v, s)
		partner.brain.state = PedBrain.S.DRIVE
	if army and randf() < 0.5:
		Game.msg("¡El ejército se une a la persecución!", 2.5)
	units.append(v)


## Air force fighter (Rafale) that makes strafing runs with its cannon (6 stars).
func _spawn_jet() -> void:
	var pp := Game.player_pos()
	var a := randf() * TAU
	var pos := pp + Vector3(cos(a), 0, sin(a)) * 1400.0
	pos.y = maxf(pp.y, 0.0) + 220.0
	var dir := (pp - pos)
	dir.y = 0.0
	dir = dir.normalized()
	var jet: Aircraft = VehicleDB.spawn("fighter", pos, atan2(-dir.x, -dir.z))
	jet.persistent = false
	jet.ai_owned = true
	jet.power = 1.0
	jet.engine_on = true
	jet.linear_velocity = dir * float(jet.def.get("cruise", 120.0))
	var pilot: Humanoid = Game.population.spawn_cop(pos + Vector3.UP * 3.0, true)
	Game.population.peds.erase(pilot)
	pilot.enter_vehicle(jet, 0)
	pilot.brain.set_physics_process(false)
	var ai := JetAI.new()
	ai.name = "JetAI"
	jet.add_child(ai)
	jets.append(jet)
	Game.msg("¡Las fuerzas aéreas han enviado un caza!", 3.0)


## VCPD Bell 407 arriving from a distance, already in the air.
func _spawn_heli() -> void:
	var pp := Game.player_pos()
	var a := randf() * TAU
	var pos := pp + Vector3(cos(a), 0, sin(a)) * 260.0
	pos.y = maxf(pp.y, 0.0) + 60.0
	var h: Helicopter = VehicleDB.spawn("police_heli", pos, a)
	h.rotor_rpm = 1.0
	h.persistent = false
	var pilot: Humanoid = Game.population.spawn_cop(pos + Vector3.UP * 3.0, false)
	pilot.enter_vehicle(h, 0)
	pilot.brain.set_physics_process(false)
	var shooter: Humanoid = Game.population.spawn_cop(pos + Vector3.UP * 3.0, true)
	shooter.enter_vehicle(h, 1)
	shooter.brain.set_physics_process(false)
	var ai := HeliAI.new()
	ai.name = "HeliAI"
	h.add_child(ai)
	helis.append(h)
	heli = helis[0]
	Game.msg("¡Helicóptero de la policía!" if helis.size() == 1 else "¡Otro helicóptero en camino!", 2.5)


func _update_units() -> void:
	var pp := Game.player_pos()
	var p := Game.player
	for v in units:
		if not is_instance_valid(v) or v.destroyed:
			continue
		var d = v.global_position.distance_to(pp)
		var drv = v.active_driver()
		if drv and drv.brain and drv.brain.driver_ai:
			# they only know where you are while someone sees you
			drv.brain.driver_ai.target = p if seen else _search
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
		# drive-by shooting from cop cars from 2 stars
		if stars >= 2 and d < 40.0 and seen:
			for o in v.occupants:
				if o != null and is_instance_valid(o) and o.seat >= 1 and not o.dead and randf() < 0.14:
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


## Two police cars parked across the road ahead of a player who is driving away, with armed cops
## behind them. Returns true when one was placed.
func _try_roadblock() -> bool:
	var p := Game.player
	var pv = p.vehicle
	if pv == null or not pv is Vehicle or pv.linear_velocity.length() < 8.0 or roadblocks.size() > 6:
		return false
	var c: CityMap = Game.city
	var dir: Vector3 = pv.linear_velocity
	dir.y = 0.0
	dir = dir.normalized()
	var pp := Game.player_pos()
	var n := c.nearest_node(pp + dir * 170.0, 70.0)
	if n < 0:
		return false
	var np: Vector3 = c.nodes[n]
	var to := np - pp
	to.y = 0.0
	if to.length() < 110.0 or to.normalized().dot(dir) < 0.7:
		return false
	# the road through that node that is most in line with the player's direction
	var rd := dir
	var best := -1.0
	for m in c.adj[n]:
		var e: Vector3 = c.nodes[m] - np
		e.y = 0.0
		if e.length() < 1.0:
			continue
		var al := absf(e.normalized().dot(dir))
		if al > best:
			best = al
			rd = e.normalized()
	var side := rd.cross(Vector3.UP).normalized()
	for k in [-1.0, 1.0]:
		var pos: Vector3 = np + side * k * 2.9 + Vector3.UP * 0.6
		var fwd := side.rotated(Vector3.UP, 0.3 * k)
		var car: Vehicle = VehicleDB.spawn("p_police", pos, atan2(-fwd.x, -fwd.z))
		car.siren_on = true
		roadblocks.append(car)
		var cop: Humanoid = Game.population.spawn_cop(pos - rd * 3.5 + Vector3.UP, stars >= 4)
		cop.brain.threat = p
		cop.brain.state = PedBrain.S.FIGHT
		cop.brain.t = 60.0
		foot_cops.append(cop)
		roadblocks.append(cop)
	Game.msg("¡Control policial más adelante!", 2.5)
	return true


## Removes roadblock cars and cops farther than `dist` from the player (all of them with 0).
func _clear_roadblocks(dist: float) -> void:
	var pp := Game.player_pos()
	for i in range(roadblocks.size() - 1, -1, -1):
		var r = roadblocks[i]
		if r == null or not is_instance_valid(r):
			roadblocks.remove_at(i)
			continue
		if dist > 0.0 and r.global_position.distance_to(pp) < dist:
			continue
		if r is Vehicle and r.driver() != null and r.driver().is_player:
			roadblocks.remove_at(i)
			continue
		if r is Vehicle:
			for o in r.occupants:
				if o != null and is_instance_valid(o) and not o.is_player:
					o.queue_free()
		r.queue_free()
		roadblocks.remove_at(i)


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
