class_name ModelUtil
extends RefCounted
## Helpers for third-party models. Many of the Quaternius FBX packs import with plain white
## materials whose *names* describe the part ("Yellow", "Windows", "Bumper", "Wood"...), so we
## recolor them by name. Override materials are cached and shared between instances.

const WHITE_EPS := 0.06
const NAMED := {
	"yellow": Color(0.93, 0.7, 0.1), "red": Color(0.75, 0.1, 0.1), "white": Color(0.92, 0.92, 0.92),
	"grey": Color(0.5, 0.5, 0.52), "gray": Color(0.5, 0.5, 0.52), "black": Color(0.07, 0.07, 0.08),
	"bumper": Color(0.32, 0.32, 0.34), "details": Color(0.13, 0.13, 0.14), "bottom": Color(0.22, 0.23, 0.25),
	"top": Color(0.94, 0.94, 0.94), "wheel": Color(0.08, 0.08, 0.08), "wheels": Color(0.08, 0.08, 0.08),
	"metal": Color(0.3, 0.31, 0.33), "darkermetal": Color(0.12, 0.12, 0.13), "wood": Color(0.4, 0.24, 0.12),
	"magazine": Color(0.1, 0.1, 0.11), "muzzle": Color(0.06, 0.06, 0.06), "body": Color(0.95, 0.95, 0.96),
	"orange": Color(0.95, 0.42, 0.08), "handle": Color(0.08, 0.08, 0.08), "bike": Color(0.75, 0.12, 0.18),
	"blue": Color(0.1, 0.3, 0.75), "green": Color(0.15, 0.45, 0.2),
}
const GLASS := Color(0.1, 0.14, 0.18)

static var _mats := {}
static var _dbg_i := -1


static func base_name(mat: Material) -> String:
	var n := String(mat.resource_name).to_lower()
	var dot := n.find(".")
	if dot > 0:
		n = n.substr(0, dot)
	return n.strip_edges()


static func is_default_white(mat: Material) -> bool:
	if not (mat is StandardMaterial3D):
		return false
	var s: StandardMaterial3D = mat
	if s.albedo_texture != null:
		return false
	var c := s.albedo_color
	return absf(c.r - 0.906) < WHITE_EPS and absf(c.g - 0.906) < WHITE_EPS and absf(c.b - 0.906) < WHITE_EPS


## Recolor every surface of `root`. `overrides` maps lower-case material base names to a Color,
## "glass", "light" or "skip". Unnamed white materials use NAMED; non-white materials are kept.
static func recolor(root: Node, overrides := {}) -> void:
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	for mi: MeshInstance3D in list:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null:
				continue
			var n := base_name(mat)
			var full := String(mat.resource_name).to_lower()
			var spec: Variant = null
			if overrides.has(full):
				spec = overrides[full]
			elif overrides.has(n):
				spec = overrides[n]
			elif overrides.has("*debug"):
				_dbg_i += 1
				spec = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE][_dbg_i % 7]
				print("[recolor] ", mi.name, " ", full, " -> ", spec)
			elif is_default_white(mat):
				if n.contains("window") or n.contains("glass"):
					spec = "glass"
				elif n.contains("light") or n == "lamp":
					spec = "light"
				elif NAMED.has(n):
					spec = NAMED[n]
			if spec == null or (spec is String and spec == "skip"):
				continue
			mi.set_surface_override_material(s, material_for(spec))


static func material_for(spec: Variant) -> StandardMaterial3D:
	var key := str(spec)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if spec is Color:
		m.albedo_color = spec
		m.roughness = 0.6
		m.metallic = 0.15
	elif spec == "glass":
		m.albedo_color = GLASS
		m.metallic = 0.8
		m.roughness = 0.08
	elif spec == "light":
		m.albedo_color = Color(1, 0.96, 0.85)
		m.emission_enabled = true
		m.emission = Color(1, 0.92, 0.75)
		m.emission_energy_multiplier = 0.6
	_mats[key] = m
	return m


## World-space AABB of all meshes under `root`, expressed in `root`'s parent space.
static func mesh_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	for mi: MeshInstance3D in list:
		var t := root.transform
		var rel := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != root:
			if p is Node3D:
				rel = (p as Node3D).transform * rel
			p = p.get_parent()
		var a: AABB = (t * rel) * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


## Instance a model, recolor it and scale it so its longest horizontal side equals `length`
## (or its height equals `height` when given). The result sits on y=0 (or keeps the model's own
## y = 0, e.g. a ship's waterline, with keep_y), centred on x/z.
static func make(path: String, length := 0.0, overrides := {}, height := 0.0, keep_y := false) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	for n in inst.find_children("*", "Light3D", true, false) + inst.find_children("*", "Camera3D", true, false):
		n.free()
	recolor(inst, overrides)
	var holder := Node3D.new()
	holder.add_child(inst)
	var a := mesh_aabb(inst)
	var k := 1.0
	if height > 0.0:
		k = height / maxf(a.size.y, 0.001)
	elif length > 0.0:
		k = length / maxf(maxf(a.size.x, a.size.z), 0.001)
	inst.scale *= k
	var c := a.get_center() * k
	inst.position = inst.position * k + Vector3(-c.x, 0.0 if keep_y else -a.position.y * k, -c.z)
	return holder
