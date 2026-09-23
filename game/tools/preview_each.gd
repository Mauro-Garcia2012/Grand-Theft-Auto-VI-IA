extends SceneTree
## Renders every model in a folder on its own from a 3/4 view (for asset review).
## Usage: tools/render.sh --path . --script tools/preview_each.gd -- <res dir> <out dir> [yaw_deg]
var files: Array = []
var i := -1
var frame := 0
var stage: Node3D
var cam: Camera3D
var cur: Node3D
var out_dir := ""
var yaw := 35.0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	out_dir = a[1]
	if a.size() > 2:
		yaw = float(a[2])
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["glb", "gltf", "fbx"]:
			files.append(dir.path_join(f))
	stage = Node3D.new()
	get_root().add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.66, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.45, 0.45)
	ground.material_override = gm
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40
	stage.add_child(cam)
	get_root().size = Vector2i(900, 600)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 4 != 0:
		return false
	if cur and frame % 4 == 0 and i >= 0 and cur.has_meta("shot") == false:
		cur.set_meta("shot", true)
		var img := get_root().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, files[i].get_file().get_basename()])
		cur.queue_free()
		cur = null
		return false
	i += 1
	if i >= files.size():
		quit()
		return true
	var ps: PackedScene = load(files[i])
	cur = ps.instantiate()
	stage.add_child(cur)
	var aabb := _aabb(cur)
	cur.position = Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	var r := aabb.size.length() * 0.5
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.45, cos(deg_to_rad(yaw))).normalized()
	cam.look_at_from_position(dir * r * 2.6 + Vector3(0, aabb.size.y * 0.4, 0), Vector3(0, aabb.size.y * 0.4, 0))
	return false


func _aabb(n: Node) -> AABB:
	var res := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = m.get_aabb()
		var t := Transform3D.IDENTITY
		var p: Node = m
		while p != n and p != null:
			if p is Node3D:
				t = p.transform * t
			p = p.get_parent()
		a = t * a
		if first:
			res = a
			first = false
		else:
			res = res.merge(a)
	return res
