extends SceneTree
## Offline converter for the detailed "brand" car models (Sketchfab-style GLBs with thousands of nodes).
## Usage: godot --headless --path . --script tools/brand_cars.gd -- <src.glb> <out.glb> <target_tris> [...]
## - merges every mesh into a body + four wheel meshes (grouped by material)
## - decimates with Godot's mesh simplifier (ImporterMesh LODs) down to ~target_tris
## - downsizes textures to 1024 px
## - writes a compact GLB with a "body" mesh and four wheel meshes named wheel_<a/b>_<l/r>
##   (a = the -Z/-X end of the long axis); the game works out front/back from the def

const WHEEL_RE := "(wheel|tire|tyre|(?<![a-z])rims?(?![a-z])|brake|caliper|disk|disc)"
const MAX_TEX := 1024

var _re := RegEx.new()


func _init() -> void:
	_re.compile("(?i)" + WHEEL_RE)
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size(), 3):
		_convert(a[i], a[i + 1], int(a[i + 2]))
	quit()


func _is_wheel_part(n: Node) -> bool:
	var p := n
	while p != null:
		var nm := String(p.name)
		if nm.to_lower().contains("steer"):
			return false
		if _re.search(nm) != null:
			return true
		p = p.get_parent()
	return false


func _global(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _convert(src: String, out: String, target: int) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(src, state) != OK:
		push_error("cannot read " + src)
		return
	var root: Node = doc.generate_scene(state)
	var parts: Array = []   # [MeshInstance3D, Transform3D, is_wheel]
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		parts.append([mi, _global(mi), _is_wheel_part(mi)])
	# body bounds (without wheels) to split wheels into quadrants
	var body_aabb := AABB()
	var first := true
	for p in parts:
		if p[2]:
			continue
		var a: AABB = p[1] * (p[0] as MeshInstance3D).get_aabb()
		body_aabb = a if first else body_aabb.merge(a)
		first = false
	var long_z := body_aabb.size.z >= body_aabb.size.x
	var c := body_aabb.get_center()
	var groups := {"body": {}, "wheel_a_l": {}, "wheel_a_r": {}, "wheel_b_l": {}, "wheel_b_r": {}}
	var total_tris := 0
	for p in parts:
		var mi: MeshInstance3D = p[0]
		var t: Transform3D = p[1]
		var key := "body"
		if p[2]:
			var wc: Vector3 = (t * mi.get_aabb()).get_center()
			if wc.y > c.y + body_aabb.size.y * 0.15:
				key = "body"      # e.g. a spare wheel or badge: keep with the body
			else:
				var along: float = (wc.z - c.z) if long_z else (wc.x - c.x)
				var side: float = (wc.x - c.x) if long_z else (wc.z - c.z)
				key = "wheel_%s_%s" % ["a" if along < 0.0 else "b", "l" if side < 0.0 else "r"]
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null:
				mat = StandardMaterial3D.new()
			if not groups[key].has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key][mat] = st
			(groups[key][mat] as SurfaceTool).append_from(mi.mesh, s, t)
			var arr := mi.mesh.surface_get_arrays(s)
			total_tris += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	var ratio := clampf(float(target) / maxf(float(total_tris), 1.0), 0.02, 1.0)
	print("== %s: %d parts, %d tris, ratio %.3f, long axis %s, size %s" % [src.get_file(), parts.size(), total_tris, ratio, "z" if long_z else "x", body_aabb.size])
	var out_root := Node3D.new()
	out_root.name = src.get_file().get_basename()
	var tex_done := {}
	var final_tris := 0
	for key in groups:
		if groups[key].is_empty():
			if key != "body":
				push_warning("%s: no parts for %s" % [src.get_file(), key])
			continue
		var am := ArrayMesh.new()
		for mat in groups[key]:
			var st: SurfaceTool = groups[key][mat]
			st.index()
			var arrays := st.commit_to_arrays()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var sub := ratio if idx.size() > 600 else 1.0
			for it in 3:
				var before: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
				arrays = _simplify(arrays, sub)
				var after: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
				if sub >= 0.95 or after == before:
					break
				sub = clampf(sub * float(before) / float(after), 0.02, 1.0)
				if sub >= 0.9:
					break
			final_tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(am.get_surface_count() - 1, _shrink_textures(mat, tex_done))
		var node := MeshInstance3D.new()
		node.mesh = am
		# name wheels by position; "a" is the -Z (or -X) end. The game works out front/back itself.
		node.name = key
		out_root.add_child(node)
		node.owner = out_root
	var mats := []
	for mat in groups.body:
		mats.append(String(mat.resource_name))
	print("   -> %d tris; body materials: %s" % [final_tris, ", ".join(mats)])
	var od := GLTFDocument.new()
	var ostate := GLTFState.new()
	if od.append_from_scene(out_root, ostate) != OK:
		push_error("export failed")
		return
	od.write_to_filesystem(ostate, out)
	print("   wrote ", out)
	root.free()
	out_root.free()


## Returns clean arrays (standard channels only), decimated towards `ratio` of the triangles.
func _simplify(arrays: Array, ratio: float) -> Array:
	var base: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if ratio < 0.95:
		var clean := []
		clean.resize(Mesh.ARRAY_MAX)
		for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			clean[a] = arrays[a]
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, clean)
		im.generate_lods(60.0, 25.0, [])
		var target := float(base) * ratio
		var best_err := INF
		for l in im.get_surface_lod_count(0):
			var li: PackedInt32Array = im.get_surface_lod_indices(0, l)
			if li.size() < 36:
				continue
			var err := absf(log(float(li.size()) / target))
			if err < best_err:
				best_err = err
				best = li
	# compact: keep only referenced vertices
	var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var remap := PackedInt32Array()
	remap.resize(vcount)
	remap.fill(-1)
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(best.size())
	for i in best.size():
		var v := best[i]
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
		new_idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var src = arrays[a]
		if src == null:
			continue
		var comps := 1
		if a == Mesh.ARRAY_TANGENT:
			comps = 4
		var dst = src.duplicate()
		dst.resize(order.size() * comps)
		for i in order.size():
			for k in comps:
				dst[i * comps + k] = src[order[i] * comps + k]
		out[a] = dst
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


func _shrink_textures(mat: Material, done: Dictionary) -> Material:
	if not (mat is BaseMaterial3D):
		return mat
	var m: BaseMaterial3D = mat
	for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ROUGHNESS,
			BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
		var tex := m.get_texture(slot)
		if tex == null or done.has(tex):
			continue
		done[tex] = true
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		if maxi(img.get_width(), img.get_height()) > MAX_TEX:
			var k := float(MAX_TEX) / maxi(img.get_width(), img.get_height())
			img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			if tex is ImageTexture:
				(tex as ImageTexture).set_image(img)
			else:
				m.set_texture(slot, ImageTexture.create_from_image(img))
	return m
