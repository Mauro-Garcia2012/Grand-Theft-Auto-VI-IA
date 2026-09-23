extends SceneTree
var frame := 0
func _init():
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3,0.35,0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6)
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 30, 0); root.add_child(sun)
	var ids = ["pistol","smg","rifle","shotgun","sniper","rpg","grenade"]
	for i in ids.size():
		var m = WeaponDB.make_model(ids[i])
		m.position = Vector3(0, 0, i * 0.6 - 1.8)
		m.rotation.y = -PI/2  # -Z -> +X (to the right)
		root.add_child(m)
		var mark := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.03,0.03,0.03); mark.mesh = bm
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color.RED; mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mark.material_override = mm
		m.add_child(mark)
		var mz = m.get_node_or_null("Muzzle")
		if mz:
			var mk2 = mark.duplicate(); mk2.material_override = mm.duplicate(); mk2.material_override.albedo_color = Color.YELLOW
			mz.add_child(mk2)
		var l := Label3D.new(); l.text = ids[i]; l.pixel_size = 0.002; l.position = Vector3(-0.9, 0, i*0.6-1.8); l.rotation_degrees = Vector3(-90,0,0); root.add_child(l)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.look_at_from_position(Vector3(0.2, 3.5, 0.01), Vector3(0.2, 0, 0))
	cam.fov = 60
	get_root().size = Vector2i(1200, 900)
func _process(_d):
	frame += 1
	if frame == 6:
		get_root().get_texture().get_image().save_png("/home/user/scratch/weapons.png"); quit()
	return false
