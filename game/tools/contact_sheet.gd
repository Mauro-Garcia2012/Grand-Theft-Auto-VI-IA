extends SceneTree
# Usage: godot --path . --script tools/contact_sheet.gd -- <dir> <out.png> [cols] [cell]
var files: Array = []
var out := ""
var frame := 0
func _init():
	var args = OS.get_cmdline_user_args()
	var dir: String = args[0]
	out = args[1]
	var cols := int(args[2]) if args.size() > 2 else 10
	var cell := float(args[3]) if args.size() > 3 else 3.0
	var filt: String = args[4] if args.size() > 4 else ""
	var d = DirAccess.open(dir)
	for f in d.get_files():
		if (f.ends_with(".glb") or f.ends_with(".gltf") or f.ends_with(".fbx")) and (filt == "" or f.contains(filt)):
			files.append(dir.path_join(f))
	files.sort()
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.45, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var rows := int(ceil(files.size() / float(cols)))
	for i in files.size():
		var s = load(files[i])
		if s == null: continue
		var inst: Node3D = s.instantiate()
		# normalize size
		var aabb := _aabb(inst)
		var sz = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		var k = (cell * 0.8) / max(sz, 0.001)
		var holder := Node3D.new()
		holder.position = Vector3((i % cols) * cell, 0, (i / cols) * cell)
		root.add_child(holder)
		inst.scale = Vector3.ONE * k
		inst.position = -aabb.get_center() * k + Vector3(0, aabb.size.y * k * 0.5, 0)
		holder.add_child(inst)
		var l := Label3D.new()
		l.text = "%d:%s" % [i, files[i].get_file().get_basename().replace("modularBuildings_", "").replace("watercraftPack_", "")]
		l.font_size = 48
		l.pixel_size = 0.004 * cell / 3.0
		l.position = Vector3(0, 0.05, cell * 0.42)
		l.rotation_degrees = Vector3(-60, 0, 0)
		l.modulate = Color.YELLOW
		l.outline_size = 8
		holder.add_child(l)
	var cam := Camera3D.new()
	var w = cols * cell
	var h = rows * cell
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = max(w, h * 1.0) * 1.05
	cam.far = 500
	root.add_child(cam)
	cam.look_at_from_position(Vector3(w * 0.5 - cell * 0.5, max(w, h) * 0.9, h * 0.5 - cell * 0.5 + max(w, h) * 0.9), Vector3(w * 0.5 - cell * 0.5, 0, h * 0.5 - cell * 0.5))
	get_root().size = Vector2i(1800, int(1800 * max(0.4, h / w)))
func _aabb(n: Node) -> AABB:
	var res := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = m.get_aabb()
		var t: Transform3D = Transform3D.IDENTITY
		var p: Node = m
		while p != n and p != null:
			if p is Node3D: t = p.transform * t
			p = p.get_parent()
		a = t * a
		if first: res = a; first = false
		else: res = res.merge(a)
	return res
func _process(_d):
	frame += 1
	if frame == 8:
		var img = get_root().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		quit()
	return false
