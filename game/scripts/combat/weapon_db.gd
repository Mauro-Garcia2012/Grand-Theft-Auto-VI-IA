class_name WeaponDB
extends RefCounted
## Weapon definitions (GTA-like arsenal). Models: amaraha "Free Low Poly Weapons Pack"
## (via Jeh3no's Godot FPS weapon system, MIT) + "Low Poly RPG-7" by Polyte (CC-BY 4.0).

const MODELS_SCENE := "res://assets/weapons/weapons_models.tscn"

const WEAPONS := {
	"fists": {"name": "Puños", "slot": 0, "type": "melee", "damage": 14.0, "rate": 0.45, "range": 1.6, "icon": "✊"},
	"pistol": {"name": "Pistola", "slot": 1, "type": "gun", "model": "Pistol", "length": 0.24, "damage": 26.0, "rate": 0.22,
		"auto": false, "clip": 12, "reload": 1.3, "spread": 1.0, "range": 130.0, "pellets": 1, "price": 400, "ammo_price": 60, "flip": false,
		"sound": "pistol", "recoil": 0.9, "icon": "🔫", "hold": "pistol"},
	"smg": {"name": "Micro SMG", "slot": 2, "type": "gun", "model": "Pistol", "length": 0.34, "damage": 17.0, "rate": 0.07,
		"auto": true, "clip": 32, "reload": 1.5, "spread": 3.2, "range": 90.0, "pellets": 1, "price": 1200, "ammo_price": 120, "flip": false,
		"sound": "smg", "recoil": 0.6, "icon": "🔫", "hold": "pistol", "tint": Color(0.45, 0.45, 0.5)},
	"rifle": {"name": "Rifle de asalto", "slot": 3, "type": "gun", "model": "AssaultRifle", "scene": "res://assets/weapons/real/ak74.glb", "length": 0.94, "damage": 30.0, "rate": 0.1,
		"auto": true, "clip": 30, "reload": 1.8, "spread": 1.6, "range": 180.0, "pellets": 1, "price": 3000, "ammo_price": 200, "flip": false,
		"sound": "rifle", "recoil": 1.1, "icon": "🔫", "hold": "rifle"},
	"shotgun": {"name": "Escopeta", "slot": 4, "type": "gun", "model": "Shotgun", "length": 1.0, "damage": 13.0, "rate": 0.85,
		"auto": false, "clip": 8, "reload": 2.2, "spread": 5.5, "range": 45.0, "pellets": 9, "price": 1800, "ammo_price": 150, "flip": false,
		"sound": "shotgun", "recoil": 2.4, "icon": "🔫", "hold": "rifle"},
	"sniper": {"name": "Rifle francotirador", "slot": 5, "type": "gun", "model": "Sniper", "length": 1.25, "damage": 160.0, "rate": 1.3,
		"auto": false, "clip": 5, "reload": 2.5, "spread": 0.05, "range": 600.0, "pellets": 1, "price": 5000, "ammo_price": 300, "flip": false,
		"sound": "sniper", "recoil": 3.0, "icon": "🎯", "hold": "rifle", "scope": true},
	"rpg": {"name": "Lanzacohetes", "slot": 6, "type": "launcher", "model": "RocketLauncher", "length": 1.1, "damage": 250.0, "rate": 1.6,
		"auto": false, "clip": 1, "reload": 2.4, "spread": 0.3, "range": 400.0, "pellets": 1, "price": 9000, "ammo_price": 600, "flip": false,
		"sound": "rpg", "recoil": 3.0, "icon": "🚀", "hold": "rifle", "shoulder": true},
	"grenade": {"name": "Granadas", "slot": 7, "type": "throw", "damage": 200.0, "rate": 1.1, "clip": 1, "reload": 0.0,
		"range": 30.0, "price": 250, "ammo_price": 250, "icon": "💣"},
}

const ORDER := ["fists", "pistol", "smg", "rifle", "shotgun", "sniper", "rpg", "grenade"]

static var _models_root: Node3D
static var _model_cache: Dictionary = {}


static func get_def(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["fists"])


static func _root() -> Node3D:
	if _models_root == null:
		_models_root = load(MODELS_SCENE).instantiate()
	return _models_root


## Returns a Node3D whose origin is the grip, barrel pointing to -Z, scaled to real size.
static func make_model(id: String) -> Node3D:
	var d := get_def(id)
	if not d.has("model"):
		if id == "grenade":
			return _grenade_model()
		return null
	var src: Node3D
	if d.has("scene"):
		if not _model_cache.has(d.scene):
			_model_cache[d.scene] = load(d.scene).instantiate()
		src = _model_cache[d.scene]
	else:
		src = _root().get_node(d.model)
	var holder := Node3D.new()
	holder.name = "WeaponModel"
	var inst: Node3D = src.duplicate()
	inst.transform = src.transform
	var pivot := Node3D.new()
	pivot.add_child(inst)
	holder.add_child(pivot)
	# measure
	var aabb := _aabb_of(inst, pivot)
	# longest horizontal axis -> -Z
	var axis := 0 if aabb.size.x >= aabb.size.z else 2
	var length := aabb.size.x if axis == 0 else aabb.size.z
	var s: float = d.length / max(length, 0.0001)
	pivot.scale = Vector3.ONE * s
	# source models have their barrel towards +Z (or -X); rotate so it points to -Z
	if axis == 0:
		pivot.rotation.y = PI / 2.0 if not d.get("flip", false) else -PI / 2.0
	elif not d.get("flip", false):
		pivot.rotation.y = PI
	# recenter: grip roughly 70% towards the back, at bottom third
	var aabb2 := _aabb_of(inst, holder)
	var c := aabb2.get_center()
	var grip := Vector3(c.x, aabb2.position.y + aabb2.size.y * 0.35, aabb2.position.z + aabb2.size.z * 0.72)
	if d.get("shoulder", false):
		grip = Vector3(c.x, c.y - aabb2.size.y * 0.25, c.z + aabb2.size.z * 0.1)
	pivot.position -= grip
	if d.has("tint"):
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = d.tint
			mat.metallic = 0.6
			mat.roughness = 0.4
			m.material_override = mat
	for m in holder.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers = 1
	# muzzle marker at the front
	var aabb3 := _aabb_of(inst, holder)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(aabb3.get_center().x, aabb3.position.y + aabb3.size.y * 0.75, aabb3.position.z)
	holder.add_child(muzzle)
	return holder


static func _grenade_model() -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.11
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.28, 0.15)
	mat.roughness = 0.7
	m.material_override = mat
	n.add_child(m)
	var mz := Marker3D.new()
	mz.name = "Muzzle"
	n.add_child(mz)
	return n


static func _aabb_of(n: Node3D, relative_to: Node3D) -> AABB:
	var res := AABB()
	var first := true
	for vi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var t := _rel_transform(vi, relative_to)
		var a: AABB = t * (vi as MeshInstance3D).get_aabb()
		if first:
			res = a
			first = false
		else:
			res = res.merge(a)
	return res


static func _rel_transform(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
