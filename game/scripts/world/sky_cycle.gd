class_name SkyCycle
extends Node3D
## Day/night cycle (Vice City sunsets), weather (clear, cloudy, rain, storm), street light pool.

signal hour_changed(h: int)

var time_of_day := 18.0        # hours
var minutes_per_second := 1.0  # 24 real minutes per game day
var weather := "clear"
var _weather_target := 0.0     # 0 clear .. 1 storm
var _weather_v := 0.0
var _weather_timer := 240.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var world_env: WorldEnvironment
var _rain: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _lights: Array[OmniLight3D] = []
var _light_t := 0.0
var _last_hour := -1
var _lightning_t := 5.0
var streetlights: Array[Vector3] = []


func _ready() -> void:
	Game.sky = self
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: filmic, photographic highlight roll-off (less "cartoon" saturation than ACES)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.tonemap_white = 12.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 350.0
	env.fog_depth_end = 3200.0
	env.fog_density = 1.0
	env.fog_light_color = Color(0.75, 0.82, 0.92)
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.08
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_bias = 0.04
	sun.light_angular_distance = 0.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)
	# rain
	_rain = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1, 30)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -10, 0)
	_rain.process_material = pm
	_rain.amount = 4000
	_rain.lifetime = 1.0
	_rain.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.7)
	_rain.draw_pass_1 = q
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_rain.material_override = rm
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-40, -60, -40), Vector3(80, 80, 80))
	add_child(_rain)
	_rain_snd = AudioStreamPlayer.new()
	var noise_stream := Sfx.get_stream("skid")
	_rain_snd.stream = noise_stream
	_rain_snd.volume_db = -80.0
	_rain_snd.pitch_scale = 0.35
	add_child(_rain_snd)
	for i in 14:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 0.0
		l.omni_range = 16.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
	_apply(0.0)


func is_night() -> bool:
	return time_of_day < 6.3 or time_of_day > 19.7


func clock_string() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func set_weather(w: String) -> void:
	weather = w
	_weather_target = {"clear": 0.0, "cloudy": 0.35, "rain": 0.75, "storm": 1.0}.get(w, 0.0)
	_weather_timer = randf_range(180.0, 420.0)


func _process(delta: float) -> void:
	if Game.paused:
		return
	time_of_day = fmod(time_of_day + delta * minutes_per_second / 60.0, 24.0)
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		var r := randf()
		set_weather("clear" if r < 0.5 else ("cloudy" if r < 0.72 else ("rain" if r < 0.9 else "storm")))
	_weather_v = move_toward(_weather_v, _weather_target, delta * 0.03)
	_apply(delta)
	var h := int(time_of_day)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)


func _apply(delta: float) -> void:
	var t := time_of_day
	# sun elevation: rises 6:00, sets 20:00, peaks at 13:00
	var day_frac := (t - 6.0) / 14.0
	var elev := sin(clampf(day_frac, 0.0, 1.0) * PI) * 72.0
	if t < 6.0 or t > 20.0:
		elev = -10.0
	var az := lerpf(-100.0, 100.0, clampf(day_frac, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-maxf(elev, 2.0), az + 180.0, 0)
	var day := clampf((elev + 2.0) / 14.0, 0.0, 1.0)      # 0 night .. 1 day
	var golden := clampf(1.0 - absf(elev - 6.0) / 12.0, 0.0, 1.0) * day
	var night := 1.0 - day
	var storm := _weather_v
	sun.light_energy = lerpf(0.0, 1.35, day) * (1.0 - storm * 0.7)
	sun.light_color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.55, 0.35), golden)
	sun.visible = day > 0.01
	sun.shadow_enabled = day > 0.05
	moon.light_energy = night * 0.3
	moon.rotation_degrees = Vector3(-45, 30, 0)
	# sky colors: vice city pink/orange sunsets, deep purple nights
	var top_day := Color(0.18, 0.42, 0.78)
	var hor_day := Color(0.62, 0.78, 0.92)
	var top_sunset := Color(0.28, 0.25, 0.55)
	var hor_sunset := Color(1.0, 0.5, 0.45)
	var top_night := Color(0.03, 0.03, 0.11)
	var hor_night := Color(0.16, 0.09, 0.26)
	var top := top_night.lerp(top_day, day).lerp(top_sunset, golden * 0.8)
	var hor := hor_night.lerp(hor_day, day).lerp(hor_sunset, golden)
	var grey := Color(0.45, 0.48, 0.52) * (0.3 + day * 0.7)
	top = top.lerp(grey * 0.8, storm * 0.8)
	hor = hor.lerp(grey, storm * 0.8)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.5))
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("cloud_cover", lerpf(0.3, 0.85, storm))
	sky_mat.set_shader_parameter("cloud_dark", storm)
	# sky light mixed with a warm bounce colour: shadows stay neutral instead of deep blue
	env.ambient_light_color = Color(0.62, 0.58, 0.52).lerp(Color(0.25, 0.22, 0.35), night)
	env.ambient_light_energy = lerpf(0.5, 0.8, day)
	env.ambient_light_sky_contribution = lerpf(0.6, 0.55, day)
	env.fog_light_color = hor.lerp(Color(0.6, 0.62, 0.66), storm * 0.6)
	env.fog_depth_begin = lerpf(350.0, 80.0, storm)
	env.fog_depth_end = lerpf(3200.0, 900.0, storm)
	env.glow_intensity = lerpf(0.5, 1.1, night)
	RenderingServer.global_shader_parameter_set("night_factor", clampf(night * 1.2 + storm * 0.3, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("wetness", clampf((storm - 0.5) * 2.0, 0.0, 1.0))
	# rain follows the camera
	var cam := get_viewport().get_camera_3d()
	var raining := storm > 0.55
	_rain.emitting = raining
	if cam:
		_rain.global_position = cam.global_position + Vector3.UP * 18.0
		_rain.amount_ratio = clampf((storm - 0.5) * 2.0, 0.1, 1.0)
	_rain_snd.volume_db = linear_to_db(clampf((storm - 0.5) * 2.0, 0.0, 1.0) * 0.25 + 0.0001)
	if raining and not _rain_snd.playing:
		_rain_snd.play()
	elif not raining and _rain_snd.playing:
		_rain_snd.stop()
	# lightning
	if storm > 0.9:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(4.0, 14.0)
			_flash()
	# street lights
	_light_t -= delta
	if _light_t <= 0.0 and cam:
		_light_t = 0.4
		_update_street_lights(cam.global_position, night)


func _flash() -> void:
	var e0 := env.ambient_light_energy
	env.ambient_light_energy = 4.0
	await get_tree().create_timer(0.08).timeout
	env.ambient_light_energy = e0
	await get_tree().create_timer(randf_range(0.6, 2.0)).timeout
	Sfx.play("explosion", -14.0, 0.45)


func _update_street_lights(p: Vector3, night: float) -> void:
	if night < 0.3 or streetlights.is_empty():
		for l in _lights:
			l.light_energy = 0.0
		return
	# find nearest N street lights (simple partial scan)
	var best: Array = []
	for s in streetlights:
		var d := s.distance_squared_to(p)
		if d < 120.0 * 120.0:
			best.append([d, s])
	best.sort_custom(func(a, b): return a[0] < b[0])
	for i in _lights.size():
		if i < best.size():
			_lights[i].global_position = best[i][1]
			_lights[i].light_energy = 2.2 * clampf((night - 0.3) * 2.0, 0.0, 1.0)
		else:
			_lights[i].light_energy = 0.0
