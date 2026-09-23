extends SceneTree
var frame := 0
func _init():
	var root := Node3D.new()
	get_root().add_child(root)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 20, 0); root.add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.2); env.environment = e; root.add_child(env)
	# triangle A: CW seen from above (a -> +x -> +z), red, cull back
	for i in 2:
		var verts := PackedVector3Array()
		if i == 0:
			verts = PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(0,0,1)])
		else:
			verts = PackedVector3Array([Vector3(0,0,0), Vector3(0,0,1), Vector3(1,0,0)])
		var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new(); mi.mesh = am
		var m := StandardMaterial3D.new(); m.albedo_color = Color.RED if i == 0 else Color.GREEN
		mi.material_override = m
		mi.position = Vector3(i * 1.5 - 1.2, 0, -0.5)
		root.add_child(mi)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4, 0.01), Vector3(0,0,0), Vector3(0,0,-1))
	get_root().size = Vector2i(400, 300)
func _process(_d):
	frame += 1
	if frame == 5:
		var img = get_root().get_texture().get_image()
		print("left(red CW-from-above) center pixel: ", img.get_pixel(120, 150), "  right(green CCW) pixel: ", img.get_pixel(260, 150))
		img.save_png("/home/user/scratch/winding.png")
		quit()
	return false
