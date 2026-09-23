extends SceneTree
func _init():
	for p in OS.get_cmdline_user_args():
		var s = load(p).instantiate()
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		var names := []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		print("BONES ", p.get_file(), " ", names)
		s.free()
	var prof := SkeletonProfileHumanoid.new()
	var pn := []
	for i in prof.bone_size:
		pn.append(prof.get_bone_name(i))
	print("PROFILE ", pn)
	quit()
