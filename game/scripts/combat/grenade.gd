class_name Grenade
extends RigidBody3D
## Frag grenade with a 2.8 s fuse.

var shooter: Node
var fuse := 2.8


func _ready() -> void:
	mass = 0.4
	collision_layer = Game.LAYER_PROJECTILE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.07
	cs.shape = s
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	add_child(WeaponDB.make_model("grenade"))
	continuous_cd = true


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		Combat.explosion(global_position, 9.0, 200.0, shooter)
		queue_free()
