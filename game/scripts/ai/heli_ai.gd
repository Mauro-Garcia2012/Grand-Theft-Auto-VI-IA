class_name HeliAI
extends Node
## Police helicopter pilot: circles above the player, keeps them in sight (so the wanted level
## doesn't drop), a marksman fires from the cabin and a searchlight follows them at night.
## When the chase ends it flies away and is removed.

var heli: Helicopter
var leaving := false
var _orbit := 0.0
var _fire_t := 2.0
var _leave_t := 0.0
var _light: SpotLight3D


func _ready() -> void:
	heli = get_parent()
	_orbit = randf() * TAU
	_light = SpotLight3D.new()
	_light.spot_range = 90.0
	_light.spot_angle = 11.0
	_light.light_energy = 0.0
	_light.light_color = Color(1.0, 0.97, 0.9)
	_light.shadow_enabled = false
	heli.add_child(_light)
	_light.position = Vector3(0, 0.3, -2.0)


func _physics_process(delta: float) -> void:
	if heli == null or not is_instance_valid(heli) or heli.destroyed or heli.driver() == null:
		if _light:
			_light.light_energy = 0.0
		return
	var p := Game.player_pos()
	var hp := heli.global_position
	var target: Vector3
	if leaving:
		_leave_t += delta
		target = hp + Vector3(hp.x - p.x, 0, hp.z - p.z).normalized() * 200.0
		target.y = p.y + 90.0
		if _leave_t > 25.0:
			for o in heli.occupants.duplicate():
				if o != null and is_instance_valid(o):
					o.queue_free()
			heli.queue_free()
			return
	else:
		_orbit += delta * 0.18
		target = p + Vector3(cos(_orbit), 0, sin(_orbit)) * 28.0
		target.y = maxf(p.y, Game.city.water_level if Game.city else 0.0) + 32.0
	# heading: look at the player (or away when leaving)
	var look := (p - hp) if not leaving else (target - hp)
	look.y = 0.0
	if look.length() > 1.0:
		heli.aim_dir = look.normalized()
	var gb := heli.global_basis
	var fwd := Vector3(-gb.z.x, 0, -gb.z.z).normalized()
	var right := Vector3(gb.x.x, 0, gb.x.z).normalized()
	var to := target - hp
	var th := Vector3(to.x, 0, to.z)
	# proportional speed towards the orbit point (the helicopter holds the commanded speed)
	var want := (th * 0.45).limit_length(40.0 if not leaving else 60.0)
	var top: float = float(heli.def.get("top", 60.0))
	heli.throttle = clampf(want.dot(fwd) / top, -1.0, 1.0)
	heli.steer_input = -clampf(want.dot(right) / 14.0, -1.0, 1.0)
	heli.lift_input = clampf(to.y / 8.0, -1.0, 1.0)
	# searchlight at night
	var night: bool = Game.sky != null and Game.sky.is_night()
	_light.light_energy = 14.0 if night and not leaving else 0.0
	if night:
		_light.look_at(p, Vector3.UP)
	# marksman
	if leaving:
		return
	_fire_t -= delta
	var d := hp.distance_to(p)
	if _fire_t <= 0.0 and d < 80.0 and not Game.player.dead:
		_fire_t = randf_range(0.9, 1.6)
		var from := hp + Vector3.DOWN * 1.2 + gb.x * 1.2
		var hit := Combat.raycast(from, p + Vector3.UP * 1.0, [heli, Game.player, Game.player.vehicle], Game.LAYER_WORLD)
		if hit.is_empty():
			var dir := Combat.apply_spread((p + Vector3.UP * 1.0 - from).normalized(), 2.5)
			Combat.fire_bullet(from, dir, 120.0, 11.0, heli.get_occupant(1) if heli.get_occupant(1) else heli.driver())
			Sfx.play_at("rifle", from, 0.0, 1.0)
