extends SceneTree
func _init():
	for p in OS.get_cmdline_user_args():
		var s = load(p).instantiate()
		var out := []
		var tris := 0
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m = mi.get_active_material(i)
				tris += mi.mesh.surface_get_array_len(i) / 3 if mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_INDEX == 0 else mi.mesh.surface_get_array_index_len(i) / 3
				if m is StandardMaterial3D:
					out.append("%s:%s%s" % [m.resource_name, m.albedo_color.to_html(false), "+tex" if m.albedo_texture else ""])
				else:
					out.append(str(m))
		print(p.get_file(), " tris=", tris, " mats=", out.slice(0, 14))
		s.free()
	quit()
