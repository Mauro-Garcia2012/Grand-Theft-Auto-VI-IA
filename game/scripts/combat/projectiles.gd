class_name Rocket
extends Node3D
## RPG rocket: flies straight, explodes on contact.

var velocity := Vector3.ZERO
var shooter: Node
var life := 6.0
var _trail: GPUParticles3D


func _ready() -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.04
	c.bottom_radius = 0.06
	c.height = 0.5
	m.mesh = c
	m.rotation.x = PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.2)
	m.material_override = mat
	add_child(m)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.2)
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position.z = 0.4
	add_child(light)
	_trail = Game.effects.make_smoke_trail()
	add_child(_trail)
	_trail.position.z = 0.35


func _physics_process(delta: float) -> void:
	life -= delta
	velocity.y -= 1.5 * delta
	var from := global_position
	var to := from + velocity * delta
	var hit := Combat.raycast(from, to, [shooter, shooter.vehicle if shooter is Humanoid and shooter.vehicle else null])
	if not hit.is_empty() or life <= 0.0:
		var p: Vector3 = hit.position if not hit.is_empty() else to
		Combat.explosion(p, 8.0, 220.0, shooter)
		queue_free()
		return
	global_position = to
	if velocity.length() > 0.1:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.FORWARD)
