class_name FireZone
extends Node3D
## Burning petrol from a Molotov cocktail: flames for a few seconds that hurt people standing in them
## and set vehicles on fire.

const RADIUS := 3.2

var shooter: Node
var life := 9.0
var _t := 0.0
var _light: OmniLight3D
var _flames: Array = []


static func spawn(pos: Vector3, p_shooter: Node) -> FireZone:
	var z := FireZone.new()
	z.shooter = p_shooter
	Game.world.add_child(z)
	# settle on the ground
	var hit := Combat.raycast(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 4.0, [], Game.LAYER_WORLD)
	z.global_position = hit.position if not hit.is_empty() else pos
	return z


func _ready() -> void:
	for i in 7:
		var f: GPUParticles3D = Game.effects.make_fire(0.9 if i == 0 else 0.55)
		add_child(f)
		var a := TAU * i / 6.0
		f.position = Vector3.ZERO if i == 0 else Vector3(cos(a), 0, sin(a)) * RADIUS * randf_range(0.45, 0.8)
		f.emitting = true
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 3.0
	_light.omni_range = 9.0
	add_child(_light)
	_light.position = Vector3.UP * 1.0
	Sfx.play_at("explosion", global_position, -6.0, 1.7)
	if shooter == Game.player:
		Game.report_crime(global_position, 1.5, "explosive")


func _physics_process(delta: float) -> void:
	life -= delta
	_light.light_energy = 2.5 + sin(Time.get_ticks_msec() * 0.03) * 0.8
	if life <= 1.5:
		for f in _flames:
			f.emitting = false
		_light.light_energy *= life / 1.5
	if life <= 0.0:
		queue_free()
		return
	_t -= delta
	if _t > 0.0 or life < 1.5:
		return
	_t = 0.25
	var p := global_position
	for h in get_tree().get_nodes_in_group("humanoids"):
		if h.dead or h.vehicle:
			continue
		if Vector2(h.global_position.x - p.x, h.global_position.z - p.z).length() < RADIUS and absf(h.global_position.y - p.y) < 2.0:
			h.take_damage(6.0, shooter, h.global_position + Vector3.UP, Vector3.UP, "fire")
			if h.brain and h.brain.has_method("on_gunshot") and not h.dead:
				h.brain.on_gunshot(p, shooter)
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(p) < RADIUS + 1.5 and not v.destroyed:
			v.take_damage(35.0, shooter)
