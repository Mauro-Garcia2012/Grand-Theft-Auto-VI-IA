class_name AirTraffic
extends Node
## Planes crossing the sky over Leonida, GTA style: light aircraft, business jets and airliners on
## long straight legs that pass near the player. They are real Aircraft with an AI pilot, so they can
## be shot down: kill the pilot and the plane glides into the ground, damage it and it catches fire,
## loses power and explodes when it crashes.

const TYPES := [["cessna", 110.0, 170.0], ["jet", 170.0, 260.0], ["airliner", 200.0, 320.0], ["cessna", 90.0, 140.0]]

var planes: Array = []
var max_planes := 2
var _t := 12.0


func _ready() -> void:
	if Game.mobile:
		max_planes = 1


func _physics_process(delta: float) -> void:
	var pp := Game.player_pos()
	for i in range(planes.size() - 1, -1, -1):
		var ac = planes[i]
		if ac == null or not is_instance_valid(ac):
			planes.remove_at(i)
			continue
		var d: float = ac.global_position.distance_to(pp)
		var player_in: bool = ac.driver() != null and ac.driver().is_player
		if not player_in and (d > 2600.0 or (ac.destroyed and d > 400.0 and ac.linear_velocity.length() < 1.0)):
			for o in ac.occupants.duplicate():
				if o != null and is_instance_valid(o) and not o.is_player:
					o.queue_free()
			ac.queue_free()
			planes.remove_at(i)
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(25.0, 50.0)
	if planes.size() < max_planes and Game.player and not Game.player.dead:
		spawn_plane()


## A plane on a straight leg that passes within ~250 m of the player.
func spawn_plane(type_id := "") -> Aircraft:
	var pp := Game.player_pos()
	var ty: Array = TYPES.pick_random()
	if type_id != "":
		for t in TYPES:
			if t[0] == type_id:
				ty = t
	var a := randf() * TAU
	var start := pp + Vector3(cos(a), 0.0, sin(a)) * 1500.0
	var through := pp + Vector3(randf_range(-250.0, 250.0), 0.0, randf_range(-250.0, 250.0))
	var dir := through - start
	dir.y = 0.0
	dir = dir.normalized()
	var alt: float = maxf(pp.y, 0.0) + randf_range(ty[1], ty[2])
	start.y = alt
	var ac: Aircraft = VehicleDB.spawn(ty[0], start, atan2(-dir.x, -dir.z))
	ac.persistent = false
	ac.ai_owned = true
	ac.power = 0.85
	ac.engine_on = true
	ac.linear_velocity = dir * float(ac.def.get("cruise", 60.0))
	var pilot: Humanoid = Game.population.spawn_ped(start + Vector3.UP * 3.0, "male", "")
	Game.population.peds.erase(pilot)
	pilot.enter_vehicle(ac, 0)
	pilot.brain.set_physics_process(false)
	var ai := PlaneAI.new()
	ai.name = "PlaneAI"
	ai.dest = start + dir * 3200.0
	ai.alt = alt
	ac.add_child(ai)
	planes.append(ac)
	return ac


class PlaneAI extends Node:
	var dest := Vector3.ZERO
	var alt := 200.0

	func _physics_process(_delta: float) -> void:
		var ac: Aircraft = get_parent()
		if ac.destroyed or ac.active_driver() == null:
			return
		var p := ac.global_position
		var to := dest - p
		to.y = 0.0
		var d := to.normalized() if to.length() > 1.0 else -ac.global_basis.z
		d.y = clampf((alt - p.y) / 300.0, -0.2, 0.2)
		ac.aim_dir = d.normalized()
		ac.throttle = 1.0 if ac.power < 0.85 else 0.0
