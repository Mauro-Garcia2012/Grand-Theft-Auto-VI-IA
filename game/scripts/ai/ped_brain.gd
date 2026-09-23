class_name PedBrain
extends Node
## Pedestrian / gang / cop on-foot AI. Writes intents into the parent Humanoid.

enum S { WANDER, IDLE, FLEE, COWER, FIGHT, PURSUE, DRIVE, BEACH }

var h: Humanoid
var state := S.WANDER
var t := 0.0
var threat: Node = null
var threat_pos := Vector3.ZERO
var node_from := -1
var node_to := -1
var side := 1.0
var target := Vector3.ZERO
var stuck_t := 0.0
var aggressive := false        # fights back when attacked
var hostile_to_player := false
var idle_anim := ""
var home := Vector3.ZERO
var driver_ai: DriverAI
var think_t := 0.0
var _last_pos := Vector3.ZERO
var called_police := false


func _ready() -> void:
	h = get_parent()
	home = h.global_position
	think_t = randf() * 0.3
	if h.team.begins_with("gang"):
		aggressive = true
	if h.team == "police":
		aggressive = true
	elif randf() < 0.18:
		aggressive = true


func start_wander() -> void:
	state = S.WANDER
	var c := Game.city
	node_from = c.nearest_node(h.global_position, 200.0)
	if node_from < 0:
		state = S.IDLE
		return
	var nb: Array = c.adj[node_from]
	node_to = nb[randi() % nb.size()] if nb.size() > 0 else node_from
	side = 1.0 if randf() < 0.5 else -1.0
	_update_target()


func start_idle(anim := "") -> void:
	state = S.IDLE
	t = randf_range(8.0, 30.0)
	idle_anim = anim


func _update_target() -> void:
	var c := Game.city
	var a: Vector3 = c.nodes[node_from]
	var b: Vector3 = c.nodes[node_to]
	var e = c.edge_between(node_from, node_to)
	var w: float = e.get("width", 14.0)
	var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var perp := Vector3(-d.z, 0, d.x)
	target = b + perp * side * (w * 0.5 + 1.8) - d * (w * 0.5 + 1.8)


func _physics_process(delta: float) -> void:
	if h == null or h.dead:
		return
	if h.vehicle and driver_ai:
		driver_ai.update(delta)
		return
	if h.down_timer > 0.0:
		h.move_dir = Vector3.ZERO
		return
	think_t -= delta
	t -= delta
	match state:
		S.WANDER:
			_wander(delta)
		S.IDLE:
			h.move_dir = Vector3.ZERO
			h.want_sprint = false
			if h.model and idle_anim != "" and h.model.current_loco != idle_anim and Vector2(h.velocity.x, h.velocity.z).length() < 0.2:
				h.model.play(idle_anim)
			if t <= 0.0:
				idle_anim = ""
				start_wander()
		S.BEACH:
			h.move_dir = Vector3.ZERO
			if h.model and idle_anim != "" and h.model.current_loco != idle_anim:
				h.model.play(idle_anim)
		S.FLEE:
			_flee(delta)
		S.COWER:
			h.move_dir = Vector3.ZERO
			h.want_crouch = true
			if t <= 0.0:
				h.want_crouch = false
				state = S.FLEE
				t = randf_range(6.0, 10.0)
		S.FIGHT:
			_fight(delta)
	# periodic awareness
	if think_t <= 0.0:
		think_t = 0.4
		_perceive()


func _wander(delta: float) -> void:
	h.want_sprint = false
	h.want_walk = true
	h.aiming = false
	var to := target - h.global_position
	to.y = 0
	if to.length() < 1.6:
		var c := Game.city
		var nb: Array = c.adj[node_to]
		var choices: Array = []
		for n in nb:
			if n != node_from:
				choices.append(n)
		if choices.is_empty():
			choices = nb
		var nxt: int = choices[randi() % choices.size()]
		node_from = node_to
		node_to = nxt
		if randf() < 0.3:
			side = -side
		_update_target()
		if randf() < 0.08:
			start_idle(["Idle_TalkingPhone", "Idle_FoldArms", "Idle", "Idle_Talking"][randi() % 4])
		return
	h.move_dir = to.normalized()
	# stuck detection
	var moved := h.global_position.distance_to(_last_pos)
	_last_pos = h.global_position
	if moved < 0.01:
		stuck_t += delta
		if stuck_t > 1.5:
			stuck_t = 0.0
			side = -side
			_update_target()
			if randf() < 0.5:
				var tmp := node_from
				node_from = node_to
				node_to = tmp
				_update_target()
	else:
		stuck_t = 0.0


func _flee(_delta: float) -> void:
	h.want_walk = false
	h.want_sprint = true
	h.want_crouch = false
	var away := h.global_position - threat_pos
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	h.move_dir = away.normalized()
	if t <= 0.0:
		h.want_sprint = false
		start_wander()
	if not called_police and threat == Game.player and randf() < 0.01:
		called_police = true
		Game.report_crime(h.global_position, 0.0, "call")


func _fight(delta: float) -> void:
	if threat == null or not is_instance_valid(threat) or threat.dead:
		threat = null
		h.aiming = false
		start_wander()
		return
	var tp: Vector3 = threat.global_position
	if threat is Humanoid and threat.vehicle:
		tp = threat.vehicle.global_position
	var to := tp - h.global_position
	var dist := to.length()
	var armed = h.current_def().get("type", "melee") != "melee"
	h.want_walk = false
	if armed:
		h.aim_point = tp + Vector3.UP * 1.2
		if dist > 22.0:
			h.aiming = false
			h.want_sprint = dist > 40.0
			h.move_dir = Vector3(to.x, 0, to.z).normalized()
		else:
			h.aiming = true
			h.want_sprint = false
			# strafe a bit
			var perp := Vector3(-to.z, 0, to.x).normalized()
			h.move_dir = perp * sin(Time.get_ticks_msec() / 900.0 + home.x) * 0.6 if dist > 6.0 else Vector3.ZERO
			if _has_los(tp):
				if randf() < 0.55:
					h.try_fire()
			else:
				h.move_dir = Vector3(to.x, 0, to.z).normalized()
	else:
		h.aiming = false
		h.face_target = tp
		if dist > 1.5:
			h.want_sprint = dist > 6.0
			h.move_dir = Vector3(to.x, 0, to.z).normalized()
		else:
			h.move_dir = Vector3.ZERO
			h.try_fire()
	if t <= 0.0 and dist > 80.0:
		threat = null
		h.aiming = false
		start_wander()


func _has_los(p: Vector3) -> bool:
	var hit := Combat.raycast(h.eye_position(), p, [h], Game.LAYER_WORLD)
	return hit.is_empty()


func _perceive() -> void:
	var p := Game.player
	if p == null or p.dead:
		return
	if state in [S.FLEE, S.COWER, S.FIGHT]:
		return
	var d := h.global_position.distance_to(p.global_position)
	# player aiming a gun at me
	if d < 25.0 and p.aiming and p.current_def().get("type", "") in ["gun", "launcher"]:
		var dir := (p.aim_point - p.eye_position()).normalized()
		var to_me := (h.global_position + Vector3.UP * 1.2 - p.eye_position()).normalized()
		if dir.dot(to_me) > 0.97:
			react_to_threat(p, p.global_position)
			return
	if hostile_to_player and d < 18.0:
		threat = p
		state = S.FIGHT
		t = 20.0


func react_to_threat(source: Node, pos: Vector3) -> void:
	if h.dead:
		return
	threat = source
	threat_pos = pos
	if aggressive and source != null and (h.team.begins_with("gang") or h.team == "police" or randf() < 0.4):
		state = S.FIGHT
		t = 25.0
		if h.team.begins_with("gang") and source == Game.player:
			hostile_to_player = true
		return
	if randf() < 0.25 and state != S.FLEE:
		state = S.COWER
		t = randf_range(2.0, 5.0)
	else:
		state = S.FLEE
		t = randf_range(8.0, 14.0)
	h.aiming = false


func on_damaged(attacker: Node, _amount: float) -> void:
	if attacker == null or attacker == h:
		return
	if h.vehicle and driver_ai:
		driver_ai.panic(attacker)
		return
	react_to_threat(attacker, attacker.global_position if attacker is Node3D else h.global_position)
	if aggressive:
		threat = attacker
		state = S.FIGHT
		t = 30.0
	# gang members call their friends
	if h.team.begins_with("gang"):
		for o in get_tree().get_nodes_in_group("humanoids"):
			if o != h and o.team == h.team and not o.dead and o.global_position.distance_to(h.global_position) < 40.0 and o.brain:
				o.brain.threat = attacker
				o.brain.state = S.FIGHT
				o.brain.t = 30.0
				if attacker == Game.player:
					o.brain.hostile_to_player = true


func on_carjacked(by: Node) -> void:
	if aggressive and randf() < 0.6:
		threat = by
		state = S.FIGHT
		t = 15.0
	else:
		threat_pos = by.global_position
		state = S.FLEE
		t = 10.0
	Game.report_crime(h.global_position, 0.0, "call")


func on_gunshot(pos: Vector3, shooter: Node) -> void:
	if state in [S.FLEE, S.FIGHT, S.COWER] or h.vehicle:
		if h.vehicle and driver_ai:
			driver_ai.panic(shooter)
		return
	react_to_threat(shooter, pos)
