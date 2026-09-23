class_name MapImage
extends RefCounted
## Renders the city map (land, water, beaches, blocks, roads) into a texture for the minimap / map screen.

const MPP := 2.5    # meters per pixel

static var texture: ImageTexture
static var width := 0
static var height := 0


static func world_to_px(p: Vector3) -> Vector2:
	return Vector2((p.x - CityMap.MIN_X) / MPP, (p.z - CityMap.MIN_Z) / MPP)


static func px_to_world(v: Vector2) -> Vector3:
	return Vector3(v.x * MPP + CityMap.MIN_X, 0, v.y * MPP + CityMap.MIN_Z)


static func build(wb: WorldBuilder) -> ImageTexture:
	var city := wb.city
	var small := Image.create(wb.hx, wb.hz, false, Image.FORMAT_RGBA8)
	var water := Color(0.29, 0.52, 0.68)
	var deep := Color(0.2, 0.4, 0.58)
	var land := Color(0.24, 0.26, 0.29)
	var sand := Color(0.78, 0.72, 0.55)
	var swamp := Color(0.26, 0.34, 0.24)
	for iz in wb.hz:
		for ix in wb.hx:
			var h := wb.heights[iz * wb.hx + ix]
			var c: Color
			if h < 0.02:
				c = water.lerp(deep, clampf(-h / 8.0, 0.0, 1.0))
			elif h < CityMap.LAND - 0.05:
				c = sand if h > 0.1 else water
				var x := CityMap.MIN_X + ix * WorldBuilder.CELL
				var z := CityMap.MIN_Z + iz * WorldBuilder.CELL
				if city.district_at(x, z) == "grassrivers":
					c = swamp
			else:
				c = land
			small.set_pixel(ix, iz, c)
	width = int((CityMap.MAX_X - CityMap.MIN_X) / MPP)
	height = int((CityMap.MAX_Z - CityMap.MIN_Z) / MPP)
	small.resize(width, height, Image.INTERPOLATE_BILINEAR)
	var img := small
	# blocks
	var block_col := Color(0.31, 0.33, 0.37)
	var park_col := Color(0.25, 0.4, 0.25)
	for lot in city.lots:
		var r: Rect2 = lot.rect
		var ins: Array = lot.inset
		var b := Rect2(r.position.x + ins[0], r.position.y + ins[1], r.size.x - ins[0] - ins[2], r.size.y - ins[1] - ins[3])
		var c := b.get_center()
		if city.land_sdf(c.x, c.y) < 10.0:
			continue
		var is_park := false
		for pk in city.parks:
			if (pk as Rect2).intersects(b.grow(-5.0)):
				is_park = true
		var p0 := world_to_px(Vector3(b.position.x, 0, b.position.y))
		var s := b.size / MPP
		img.fill_rect(Rect2i(Vector2i(p0), Vector2i(s)), park_col if is_park else block_col)
	# airport runways
	for rw in [[Vector3(-1780, 0, -1100), Vector3(-1020, 0, -1100), 60.0], [Vector3(-1780, 0, -300), Vector3(-1020, 0, -300), 60.0], [Vector3(-1100, 0, -1450), Vector3(-1100, 0, -350), 25.0]]:
		_line(img, rw[0], rw[1], rw[2] / MPP, Color(0.4, 0.4, 0.42))
	# roads
	for e in city.edges:
		var a: Vector3 = city.nodes[e.a]
		var bb: Vector3 = city.nodes[e.b]
		var col := Color(0.82, 0.82, 0.8)
		if e.kind in ["avenue", "causeway", "highway"]:
			col = Color(0.95, 0.85, 0.55)
		_line(img, a, bb, maxf(e.width / MPP * 0.75, 3.0), col)
	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	return texture


static func _line(img: Image, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var pa := world_to_px(a)
	var pb := world_to_px(b)
	var L := pa.distance_to(pb)
	var steps := int(L) + 1
	var hw := int(ceil(w * 0.5))
	for i in steps + 1:
		var p := pa.lerp(pb, float(i) / maxf(steps, 1))
		var r := Rect2i(int(p.x) - hw, int(p.y) - hw, hw * 2, hw * 2).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, col)
