extends SceneTree
func _init():
	for p in ["res://assets/characters/anim_ual1.glb", "res://assets/characters/anim_ual2.glb"]:
		var s = load(p).instantiate()
		var ap: AnimationPlayer = s.get_node("AnimationPlayer")
		var out := []
		for n in ap.get_animation_list():
			var a = ap.get_animation(n)
			out.append("%s(%.2f%s)" % [n, a.length, "L" if a.loop_mode != Animation.LOOP_NONE else ""])
		print(p, ": ", ", ".join(out))
		print(ap.get_animation_library_list())
		s.free()
	var h = load("res://assets/characters/hair_long.glb").instantiate()
	var mi: MeshInstance3D = h.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skin = mi.skin
	print("hair binds ", sk.get_bind_count(), " name0=", sk.get_bind_name(0), " bone0=", sk.get_bind_bone(0))
	var m = load("res://assets/characters/male.glb").instantiate()
	var bm: MeshInstance3D = m.get_node("Armature/Skeleton3D/SuperHero_Male")
	print("male binds ", bm.skin.get_bind_count(), " name0=", bm.skin.get_bind_name(0), " bone0=", bm.skin.get_bind_bone(0))
	var mat = bm.get_active_material(0)
	print("male mat ", mat, " ", mat.resource_name)
	var hm = mi.get_active_material(0)
	print("hair mat ", hm.albedo_color, " transp=", hm.transparency, " cull=", hm.cull_mode)
	quit()
