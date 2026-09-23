class_name CompanionBrain
extends Node
## The protagonist you are not controlling: follows the player, rides along, shoots at attackers.

var h: Humanoid
var enemy: Node = null
var _think := 0.0
var _enter_cd := 0.0


func _ready() -> void:
	h = get_parent()


func _physics_process(delta: float) -> void:
	if h == null or h.dead or Game.player == null:
		return
	var p := Game.player
	_think -= delta
	_enter_cd -= delta
	if _think <= 0.0:
		_think = 0.5
		_find_enemy()
	# ride along
	if p.vehicle != null:
		if h.vehicle == p.vehicle:
			h.move_dir = Vector3.ZERO
			if enemy and h.current_def().get("hold", "") == "pistol":
				h.aiming = true
				h.aim_point = enemy.global_position + Vector3.UP * 1.2
				if randf() < 0.3:
					h.try_fire()
			else:
				h.aiming = false
			return
		elif h.vehicle == null and h.global_position.distance_to(p.vehicle.global_position) < 35.0 and _enter_cd <= 0.0:
			var s: int = -1
			for i in range(1, p.vehicle.seat_count() if p.vehicle.has_method("seat_count") else 4):
				if p.vehicle.get_occupant(i) == null:
					s = i
					break
			if s > 0:
				var d := h.global_position.distance_to(p.vehicle.global_position)
				if d < 4.5:
					h.enter_vehicle(p.vehicle, s)
					_enter_cd = 2.0
					return
				_run_to(p.vehicle.global_position, true)
				return
	elif h.vehicle != null:
		var bail: bool = h.vehicle is Aircraft and h.vehicle.airborne
		h.exit_vehicle(bail)
		if bail:
			h.parachute_in = 1.3     # follow the player out of the plane
		_enter_cd = 1.0
		return
	if h.vehicle != null:
		return
	# fight
	if enemy and is_instance_valid(enemy) and not enemy.dead:
		var to: Vector3 = enemy.global_position - h.global_position
		if h.current_def().get("type", "melee") == "melee":
			for i in h.weapons.size():
				if h.weapons[i].id != "fists" and h.weapons[i].id != "grenade":
					h.select_weapon(i)
					break
		h.aiming = true
		h.aim_point = enemy.global_position + Vector3.UP * 1.25
		h.move_dir = Vector3.ZERO if to.length() < 25.0 else Vector3(to.x, 0, to.z).normalized()
		if randf() < 0.5:
			h.try_fire()
		return
	h.aiming = false
	# follow
	var dist := h.global_position.distance_to(p.global_position)
	if dist > 80.0:
		# teleport behind the player if too far (keeps the duo together), never into the air
		var player_in_air: bool = (p.vehicle == null and not p.is_on_floor()) or (p.vehicle is Aircraft and p.vehicle.airborne)
		if player_in_air:
			h.move_dir = Vector3.ZERO
			return
		var behind := p.global_position + p.global_basis.z * 3.0
		h.global_position = behind + Vector3.UP * 0.5
		h.velocity = Vector3.ZERO
		return
	if dist > 4.0:
		_run_to(p.global_position + p.global_basis.x * 1.5, dist > 9.0)
	else:
		h.move_dir = Vector3.ZERO
		h.want_sprint = false


func _run_to(target: Vector3, sprint: bool) -> void:
	var to := target - h.global_position
	to.y = 0
	h.move_dir = to.normalized() if to.length() > 1.0 else Vector3.ZERO
	h.want_sprint = sprint
	h.want_walk = false
	if h.is_on_wall() and h.is_on_floor():
		h.want_jump = true


func _find_enemy() -> void:
	enemy = null
	var best := 45.0
	for o in get_tree().get_nodes_in_group("humanoids"):
		if o.dead or o == h or o.team == "player":
			continue
		var hostile := false
		if o.brain and "threat" in o.brain and o.brain.threat != null and (o.brain.threat == Game.player or o.brain.threat == h) and o.brain.state == PedBrain.S.FIGHT:
			hostile = true
		if o.team == "police" and Game.get_wanted() >= 2:
			hostile = true
		if hostile:
			var d: float = o.global_position.distance_to(h.global_position)
			if d < best:
				best = d
				enemy = o
