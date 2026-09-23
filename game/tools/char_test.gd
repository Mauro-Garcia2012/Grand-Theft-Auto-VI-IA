extends SceneTree
var frame := 0
var out := "/home/user/scratch/chars.png"
var models := []
func _init():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.5, 0.5, 0.48)
	g.material_override = gm
	root.add_child(g)
	var specs = [
		["male", "male_jason_s2.jpg", "buzzed", true, "Idle"],
		["female", "female_lucia_s2.jpg", "long", false, "Walk"],
		["male", "male_hawaiian0_s2.jpg", "parted", false, "Jog_Fwd"],
		["female", "female_bikini_pink_s1.jpg", "buns", false, "Idle"],
		["male", "male_police_s4.jpg", "buzzed", false, "Idle"],
		["female", "female_business_s3.jpg", "buzzed_f", false, "Walk"],
		["male", "male_beach_trunks_s1.jpg", "parted", false, "Sprint"],
		["male", "male_gang_purple_s0.jpg", "buzzed", true, "AIM"],
	]
	for i in specs.size():
		var s = specs[i]
		var m := CharacterModel.new()
		root.add_child(m)
		m.build(s[0], s[1], s[2], Color(-1,0,0), s[3])
		m.position = Vector3((i % 4) * 1.6 - 2.4, 0, (i / 4) * -2.5)
		m.rotation.y = PI  # face camera (+Z)
		if s[4] == "AIM":
			m.play("Idle"); m.upper("Aim")
		else:
			m.play(s[4])
		models.append(m)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 6.5), Vector3(0, 1.0, -1.2))
	cam.fov = 55
	get_root().size = Vector2i(1600, 900)
func _process(_d):
	frame += 1
	if frame == 40:
		get_root().get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
	return false
