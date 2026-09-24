class_name Effects
extends Node3D
## Visual effects: muzzle flashes, tracers, impacts, blood, explosions, fire, smoke, splashes.

var _mats := {}
var _meshes := {}
var _flash_tex: Texture2D
var _tracers: Array = []


func _ready() -> void:
	Game.effects = self
	_flash_tex = load("res://assets/weapons/muzzle_flash.png")


func _billboard_mat(key: String, color: Color, additive := false, tex: Texture2D = null) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex:
		m.albedo_texture = tex
	else:
		m.albedo_texture = _soft_circle()
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


var _circle: ImageTexture
func _soft_circle() -> ImageTexture:
	if _circle:
		return _circle
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_circle = ImageTexture.create_from_image(img)
	return _circle


func _quad(size: float) -> QuadMesh:
	var key := "q%.2f" % size
	if not _meshes.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		_meshes[key] = q
	return _meshes[key]


func _burst(pos: Vector3, amount: int, lifetime: float, mat: Material, size: float, pm: ParticleProcessMaterial, one_shot := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.process_material = pm
	var q := _quad(size)
	p.draw_pass_1 = q
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	add_child(p)
	p.global_position = pos
	p.emitting = true
	if one_shot:
		get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p


func _pm(dir: Vector3, spread: float, vmin: float, vmax: float, grav: float, color: Color, scale_curve := true) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -grav, 0)
	pm.color = color
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	if scale_curve:
		var c := CurveTexture.new()
		var cv := Curve.new()
		cv.add_point(Vector2(0, 1))
		cv.add_point(Vector2(1, 0.2))
		c.curve = cv
		pm.scale_curve = c
	var g := GradientTexture1D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	pm.color_ramp = g
	return pm


func muzzle_flash(pos: Vector3, dir: Vector3, big := false) -> void:
	var s := Sprite3D.new()
	s.texture = _flash_tex
	s.pixel_size = 0.0012 if not big else 0.003
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.modulate = Color(1, 0.85, 0.5)
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	s.global_position = pos + dir * 0.08
	s.rotation.z = randf() * TAU
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.75, 0.4)
	l.light_energy = 2.5
	l.omni_range = 5.0
	add_child(l)
	l.global_position = pos
	get_tree().create_timer(0.05).timeout.connect(s.queue_free)
	get_tree().create_timer(0.06).timeout.connect(l.queue_free)


func tracer(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 1.0:
		return
	var m := MeshInstance3D.new()
	var bm: BoxMesh = _meshes.get("tracer")
	if bm == null:
		bm = BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, 1.0)
		_meshes["tracer"] = bm
	m.mesh = bm
	var mat: StandardMaterial3D = _mats.get("tracer")
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 0.9, 0.6, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1, 0.8, 0.4)
		_mats["tracer"] = mat
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var seg := minf(len, 6.0)
	var start := from.lerp(to, randf_range(0.0, 0.3))
	m.global_position = start
	m.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	m.scale = Vector3(1, 1, seg)
	var tw := m.create_tween()
	var end_pos := to - (to - from).normalized() * seg * 0.5
	tw.tween_property(m, "global_position", end_pos, clampf(len / 400.0, 0.02, 0.15))
	tw.tween_callback(m.queue_free)


func impact(pos: Vector3, normal: Vector3, kind := "concrete") -> void:
	var col := Color(0.75, 0.7, 0.6) if kind == "concrete" else (Color(0.85, 0.93, 1.0) if kind == "glass" else Color(1, 0.8, 0.4))
	var pm := _pm(normal, 35.0, 2.0, 5.0, 9.8, col)
	_burst(pos, 8, 0.4, _billboard_mat("impact_" + kind, Color.WHITE, kind == "metal"), 0.06 if kind == "metal" else 0.12, pm)
	if Game.player and pos.distance_squared_to(Game.player.global_position) < 3600.0:
		Sfx.play_at("ricochet" if kind == "metal" else "impact", pos, -12.0, randf_range(0.8, 1.2))


func blood(pos: Vector3, dir: Vector3) -> void:
	var pm := _pm(dir.normalized() + Vector3.UP * 0.3, 30.0, 1.0, 3.5, 9.8, Color(0.6, 0.02, 0.02))
	_burst(pos, 12, 0.5, _billboard_mat("blood", Color.WHITE), 0.1, pm)


func splash(pos: Vector3) -> void:
	var pm := _pm(Vector3.UP, 25.0, 3.0, 6.0, 9.8, Color(0.9, 0.95, 1.0, 0.8))
	_burst(pos, 30, 0.9, _billboard_mat("splash", Color.WHITE), 0.35, pm)
	Sfx.play_at("splash", pos, -4.0)


func explosion(pos: Vector3, radius: float) -> void:
	# fireball
	var pm := _pm(Vector3.UP, 180.0, radius * 0.4, radius * 1.1, -2.0, Color(1, 0.55, 0.15))
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	_burst(pos, 40, 0.9, _billboard_mat("fire_add", Color.WHITE, true), radius * 0.35, pm)
	# smoke
	var pm2 := _pm(Vector3.UP, 60.0, 1.0, 4.0, -1.5, Color(0.12, 0.11, 0.1, 0.8), false)
	pm2.scale_min = 1.0
	pm2.scale_max = 2.2
	_burst(pos + Vector3.UP, 30, 3.5, _billboard_mat("smoke", Color.WHITE), radius * 0.5, pm2)
	# debris sparks
	var pm3 := _pm(Vector3.UP, 70.0, 8.0, 18.0, 12.0, Color(1, 0.8, 0.3))
	_burst(pos, 30, 1.2, _billboard_mat("spark", Color.WHITE, true), 0.12, pm3)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.6, 0.25)
	l.light_energy = 12.0
	l.omni_range = radius * 4.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos + Vector3.UP * 1.5
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	scorch(pos)


func scorch(pos: Vector3) -> void:
	var d := Decal.new()
	d.size = Vector3(6, 3, 6)
	d.texture_albedo = _soft_circle()
	d.modulate = Color(0.05, 0.04, 0.03, 0.85)
	add_child(d)
	d.global_position = pos
	get_tree().create_timer(60.0).timeout.connect(d.queue_free)


func make_fire(size := 1.0) -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 15.0, 1.0, 2.5, -2.0, Color(1, 0.5, 0.12))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 * size
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.8
	p.process_material = pm
	p.draw_pass_1 = _quad(0.9 * size)
	p.material_override = _billboard_mat("fire_add", Color.WHITE, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 8.0
	p.add_child(l)
	return p


func make_smoke(dark := 0.5, size := 1.0) -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 20.0, 0.8, 2.0, -1.0, Color(dark * 0.3, dark * 0.3, dark * 0.3, 0.6), false)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.5
	p.process_material = pm
	p.draw_pass_1 = _quad(1.2 * size)
	p.material_override = _billboard_mat("smoke", Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func make_smoke_trail() -> GPUParticles3D:
	var pm := _pm(Vector3.BACK, 10.0, 0.5, 1.5, -0.5, Color(0.7, 0.7, 0.7, 0.7), false)
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.5
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = _quad(0.6)
	p.material_override = _billboard_mat("smoke", Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func make_tire_smoke() -> GPUParticles3D:
	var p := make_smoke(2.5, 0.8)
	p.local_coords = false
	p.amount = 30
	p.lifetime = 1.4
	return p
