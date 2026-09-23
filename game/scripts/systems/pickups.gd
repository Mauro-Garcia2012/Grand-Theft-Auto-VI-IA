class_name Pickups
extends Area3D
## Collectible item (money, weapon, health, armor). Static helpers spawn them.

var kind := "money"
var amount := 0
var weapon_id := ""
var respawn := 0.0         # >0: permanent pickup that respawns
var life := 60.0
var _visual: Node3D
var _t := 0.0
var _hidden_until := 0.0
var _base_y := 0.0


static func spawn_money(pos: Vector3, value: int) -> Pickups:
	var p := Pickups.new()
	p.kind = "money"
	p.amount = value
	Game.world.add_child(p)
	p.global_position = pos
	return p


static func spawn_weapon(pos: Vector3, id: String, ammo: int, permanent := false) -> Pickups:
	var p := Pickups.new()
	p.kind = "weapon"
	p.weapon_id = id
	p.amount = ammo
	if permanent:
		p.respawn = 60.0
	Game.world.add_child(p)
	p.global_position = pos
	return p


static func spawn_item(pos: Vector3, kind: String, value: int, permanent := true) -> Pickups:
	var p := Pickups.new()
	p.kind = kind
	p.amount = value
	if permanent:
		p.respawn = 45.0
	Game.world.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	collision_layer = Game.LAYER_TRIGGER
	collision_mask = Game.LAYER_CHAR
	monitoring = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	cs.shape = s
	add_child(cs)
	add_to_group("pickups")
	_base_y = position.y
	_build_visual()
	body_entered.connect(_on_body)


func _build_visual() -> void:
	match kind:
		"weapon":
			_visual = WeaponDB.make_model(weapon_id)
			if _visual == null:
				_visual = Node3D.new()
			_visual.scale = Vector3.ONE * 1.3
		"money":
			_visual = _box(Vector3(0.3, 0.12, 0.16), Color(0.25, 0.7, 0.3), Color(0.1, 0.5, 0.15))
		"health":
			_visual = Node3D.new()
			_visual.add_child(_box(Vector3(0.5, 0.16, 0.16), Color(0.95, 0.95, 0.95), Color(1, 0.2, 0.2)))
			var b2 := _box(Vector3(0.16, 0.5, 0.16), Color(0.95, 0.95, 0.95), Color(1, 0.2, 0.2))
			_visual.add_child(b2)
		"armor":
			_visual = _box(Vector3(0.45, 0.55, 0.14), Color(0.2, 0.3, 0.6), Color(0.2, 0.5, 1.0))
	add_child(_visual)
	_visual.position.y = 0.6
	var l := OmniLight3D.new()
	l.light_color = {"money": Color(0.3, 1, 0.4), "weapon": Color(1, 0.8, 0.3), "health": Color(1, 0.3, 0.3), "armor": Color(0.3, 0.5, 1)}.get(kind, Color.WHITE)
	l.light_energy = 1.2
	l.omni_range = 2.5
	l.position.y = 0.7
	add_child(l)


func _box(size: Vector3, col: Color, emit: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = emit
	mat.emission_energy_multiplier = 0.6
	m.material_override = mat
	return m


func _process(delta: float) -> void:
	_t += delta
	if _visual:
		_visual.rotation.y = _t * 2.0
		_visual.position.y = 0.6 + sin(_t * 3.0) * 0.08
	if respawn <= 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
	elif not visible and Time.get_ticks_msec() / 1000.0 > _hidden_until:
		visible = true
		set_deferred("monitoring", true)


func _on_body(b: Node) -> void:
	if not visible or not (b is Humanoid) or b.dead:
		return
	var h: Humanoid = b
	if not h.is_player:
		return
	match kind:
		"money":
			Game.add_money(amount)
			Game.msg("+$%d" % amount, 1.5)
			Sfx.play("money", -4.0)
		"weapon":
			h.give_weapon(weapon_id, amount, not h.has_weapon(weapon_id))
			Game.msg("%s (+%d)" % [WeaponDB.get_def(weapon_id).name, amount], 2.0)
			Sfx.play("pickup", -6.0)
		"health":
			if h.health >= h.max_health:
				return
			h.heal(amount)
			Sfx.play("pickup", -6.0)
		"armor":
			if h.armor >= 100.0:
				return
			h.armor = minf(100.0, h.armor + amount)
			Sfx.play("pickup", -6.0)
	if respawn > 0.0:
		visible = false
		set_deferred("monitoring", false)
		_hidden_until = Time.get_ticks_msec() / 1000.0 + respawn
	else:
		queue_free()
