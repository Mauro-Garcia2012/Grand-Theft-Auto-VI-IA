extends Node3D
## Entry point: loading screen -> world generation -> protagonists (Jason & Lucia) -> systems.

var city: CityMap
var builder: WorldBuilder
var loading: CanvasLayer
var _bar: ProgressBar
var _label: Label
var controller: PlayerController
var rig: CameraRig
var ready_done := false
var _test_mode := ""


func _ready() -> void:
	Game.world = self
	PlayerController.setup_input()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			_test_mode = a.substr(7)
	_make_loading()
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	city = CityMap.new()
	city.name = "CityMap"
	add_child(city)
	Game.city = city
	var fx := Effects.new()
	fx.name = "Effects"
	add_child(fx)
	var sky := SkyCycle.new()
	sky.name = "Sky"
	add_child(sky)
	builder = WorldBuilder.new()
	builder.name = "World"
	add_child(builder)
	await builder.build(city, _progress)
	sky.streetlights = builder.streetlights
	_progress.call(0.87, "Calentando motores...")
	await get_tree().process_frame
	_warm_up()
	_progress.call(0.9, "Despertando a Jason y Lucía...")
	await get_tree().process_frame
	_spawn_protagonists()
	var wanted := WantedSystem.new()
	wanted.name = "Wanted"
	add_child(wanted)
	var pop := Population.new()
	pop.name = "Population"
	add_child(pop)
	MapImage.build(builder)
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)
	var hud := HUD.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	var menu := PauseMenu.new()
	menu.name = "PauseMenu"
	hud_layer.add_child(menu)
	var inter := Interactions.new()
	inter.name = "Interactions"
	add_child(inter)
	var radio := Radio.new()
	radio.name = "Radio"
	add_child(radio)
	print("World ready in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_progress.call(1.0, "¡Bienvenido a Leonida!")
	await get_tree().create_timer(0.3).timeout
	loading.queue_free()
	ready_done = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.big_message.emit("VICE CITY", "Leonida · Mundo libre", Color(1, 0.4, 0.7))
	Game.msg("WASD mover · Ratón apuntar · F coche · M mapa · Z cambiar Jason/Lucía · ESC menú", 8.0)
	if _test_mode != "":
		var tester = load("res://tools/hud_debug.gd" if _test_mode == "hud" else "res://tools/auto_test.gd").new()
		tester.mode = _test_mode
		add_child(tester)


func _make_loading() -> void:
	loading = CanvasLayer.new()
	loading.layer = 100
	add_child(loading)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.03, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.98, 0.45, 0.35))
	g.set_color(1, Color(0.45, 0.1, 0.55))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.modulate = Color(1, 1, 1, 0.85)
	loading.add_child(grad)
	var title := Label.new()
	title.text = "VICE CITY"
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.9, 0.2, 0.55))
	title.add_theme_constant_override("outline_size", 18)
	var f := load("res://assets/fonts/inter_black_italic.woff")
	if f:
		title.add_theme_font_override("font", f)
	UI.place(title, Control.PRESET_CENTER_TOP, Vector2(-380, 180), Vector2(760, 150))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_child(title)
	var sub := Label.new()
	sub.text = "LEONIDA  ·  FREE ROAM  ·  FAN PROJECT"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	UI.place(sub, Control.PRESET_CENTER_TOP, Vector2(-380, 330), Vector2(760, 40))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_child(sub)
	_bar = ProgressBar.new()
	UI.place(_bar, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -140), Vector2(600, 18))
	_bar.show_percentage = false
	loading.add_child(_bar)
	_label = Label.new()
	UI.place(_label, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -110), Vector2(600, 30))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	loading.add_child(_label)


func _warm_up() -> void:
	## Preload heavy resources so spawning traffic/pedestrians later doesn't hitch.
	for id in VehicleDB.CARS:
		VehicleDB.load_src(VehicleDB.CARS[id].src)
	for id in VehicleDB.BOATS:
		VehicleDB.load_src(VehicleDB.BOATS[id].src)
	CharacterModel.get_anim_library()
	for p in CharacterModel.BODY_SCENES.values() + CharacterModel.HAIR_SCENES.values():
		CharacterModel.load_scene(p)
	# instantiate one car of the multi-car set to cache its prototypes
	var tmp := VehicleDB.spawn("nb_daily", Vector3(0, -500, 0), 0.0)
	tmp.queue_free()
	var o := CharacterModel.get_outfits("male") + CharacterModel.get_outfits("female")
	for e in o:
		ResourceLoader.load_threaded_request("res://assets/characters/outfits/" + e.file)


func _progress(v: float, text: String) -> void:
	if _bar:
		_bar.value = v * 100.0
	if _label:
		_label.text = text
	print("[loading] %d%% %s" % [int(v * 100), text])


func _spawn_protagonists() -> void:
	var start: Vector3 = city.spawn_points["ocean_drive"]
	var jason := Humanoid.new()
	jason.name = "Jason"
	jason.display_name = "Jason"
	jason.is_player = true
	jason.team = "player"
	add_child(jason)
	jason.setup("male", "male_jason_s2.jpg", "buzzed", true, Color(0.2, 0.16, 0.13))
	jason.add_to_group("humanoids")
	jason.global_position = start
	jason.max_health = 200.0
	jason.health = 200.0
	jason.armor = 50.0
	jason.give_weapon("pistol", 60)
	jason.give_weapon("smg", 90)
	jason.give_weapon("grenade", 3)
	jason.select_weapon(0)
	var lucia := Humanoid.new()
	lucia.name = "Lucia"
	lucia.display_name = "Lucía"
	lucia.team = "player"
	add_child(lucia)
	lucia.setup("female", "female_lucia_s2.jpg", "long", false, Color(0.12, 0.09, 0.08))
	lucia.add_to_group("humanoids")
	lucia.global_position = start + Vector3(1.5, 0, 1.0)
	lucia.max_health = 200.0
	lucia.health = 200.0
	lucia.armor = 50.0
	lucia.give_weapon("pistol", 60)
	lucia.give_weapon("shotgun", 24)
	lucia.select_weapon(0)
	Game.protagonists = [jason, lucia]
	jason.model.always_full_rate = true
	lucia.model.always_full_rate = true
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	controller = PlayerController.new()
	controller.name = "PlayerController"
	controller.rig = rig
	_set_active(0, true)
	var buddy := CompanionBrain.new()
	buddy.name = "Brain"
	lucia.add_child(buddy)
	lucia.brain = buddy
	# a car waiting for them on Ocean Drive
	VehicleDB.spawn("nb_convertible", start + Vector3(-7.5, 0.8, 6), 0.0, Color(0.95, 0.35, 0.6))
	VehicleDB.spawn("motorcycle", start + Vector3(-7.5, 0.8, -4), 0.0)


func _set_active(i: int, instant := false) -> void:
	var prev: Humanoid = Game.player
	var h: Humanoid = Game.protagonists[i]
	if prev and prev != h:
		prev.is_player = false
		if controller.get_parent():
			controller.get_parent().remove_child(controller)
		var buddy := CompanionBrain.new()
		buddy.name = "Brain"
		prev.add_child(buddy)
		prev.brain = buddy
	if h.brain:
		h.brain.queue_free()
		h.brain = null
	h.is_player = true
	h.add_child(controller)
	controller.h = h
	Game.player = h
	Game.active_protagonist = i
	rig.target = h
	if instant:
		rig.global_position = h.global_position + Vector3.UP * 1.6
		rig.yaw = h.rotation.y
	Game.player_changed.emit(h)


func switch_protagonist() -> void:
	if Game.protagonists.size() < 2 or Game.player.dead:
		return
	var n := (Game.active_protagonist + 1) % 2
	var other: Humanoid = Game.protagonists[n]
	if other.dead:
		return
	var far := other.global_position.distance_to(Game.player.global_position) > 60.0
	if far:
		Game.hud.fade(0.35)
		await get_tree().create_timer(0.35).timeout
	_set_active(n, far)
	Game.msg("Ahora juegas como %s" % other.display_name, 2.5)
	Sfx.play("ui_move")


func _unhandled_input(event: InputEvent) -> void:
	if not ready_done:
		return
	if event.is_action_pressed("switch_char") and not Game.paused:
		switch_protagonist()
	if event.is_action_pressed("quick_save") and not Game.paused:
		Game.save_game()
	if event.is_action_pressed("quick_load") and not Game.paused:
		Game.load_game()
