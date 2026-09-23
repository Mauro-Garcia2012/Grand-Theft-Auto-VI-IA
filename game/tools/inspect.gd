extends SceneTree
func _dump(n: Node, depth := 0):
	var extra := ""
	if n is MeshInstance3D:
		extra = " mesh=%s skin=%s skel=%s aabb=%s" % [n.mesh.resource_name if n.mesh else "-", n.skin != null, n.skeleton, n.get_aabb()]
	if n is Skeleton3D:
		extra = " bones=%d" % n.get_bone_count()
	if n is Node3D:
		extra += " pos=%s scale=%s" % [n.position, n.scale]
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	if depth < 6:
		for c in n.get_children():
			_dump(c, depth + 1)
func _init():
	var paths = OS.get_cmdline_user_args()
	for p in paths:
		print("==== ", p)
		var s = load(p).instantiate()
		_dump(s)
		for ap in s.find_children("*", "AnimationPlayer", true, false):
			var names = ap.get_animation_list()
			print("anims: ", names.size())
			if names.size() > 0:
				var a: Animation = ap.get_animation(names[min(5, names.size()-1)])
				print("anim ", names[min(5, names.size()-1)], " len=", a.length, " tracks=", a.get_track_count())
				for i in range(min(6, a.get_track_count())):
					print("   track ", i, " ", a.track_get_path(i), " type=", a.track_get_type(i))
				var pos_tracks := 0
				for i in a.get_track_count():
					if a.track_get_type(i) == Animation.TYPE_POSITION_3D: pos_tracks += 1
				print("   position tracks: ", pos_tracks)
		s.free()
	quit()
