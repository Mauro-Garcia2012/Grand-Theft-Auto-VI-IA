class_name Grenade
extends RigidBody3D
## Thrown or launched explosives:
## - frag grenade: 2.8 s fuse
## - "shell" (grenade launcher): explodes when it hits something
## - "molotov": the bottle breaks on impact and leaves a pool of burning petrol (FireZone)

var shooter: Node
var fuse := 2.8
var kind := "frag"          # frag, shell, molotov
var _done := false


func _ready() -> void:
	mass = 0.4
	collision_layer = Game.LAYER_PROJECTILE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE
	if kind != "frag":
		collision_mask |= Game.LAYER_CHAR
		contact_monitor = true
		max_contacts_reported = 2
		body_entered.connect(_on_hit)
		fuse = 8.0
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.07
	cs.shape = s
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	var model_id: String = "molotov" if kind == "molotov" else "grenade"
	var m := WeaponDB.make_model(model_id)
	if m:
		add_child(m)
		if kind == "shell":
			m.scale = Vector3.ONE * 0.7
	if kind == "molotov":
		# the rag is burning
		var f: GPUParticles3D = Game.effects.make_fire(0.12)
		f.amount = 12
		add_child(f)
		f.emitting = true
	continuous_cd = true


func _on_hit(body: Node) -> void:
	if body == shooter:
		return
	_detonate()


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		_detonate()


func _detonate() -> void:
	if _done:
		return
	_done = true
	if kind == "molotov":
		Sfx.play_at("glass", global_position, 2.0)
		FireZone.spawn(global_position, shooter)
	else:
		Combat.explosion(global_position, 9.0 if kind == "frag" else 7.5, 200.0 if kind == "frag" else 230.0, shooter)
	queue_free()
