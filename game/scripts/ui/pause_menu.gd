class_name PauseMenu
extends Control
## Pause menu (map with waypoint, stats, settings, controls, save/load) + full-screen map + cheat console.

var _root: PanelContainer
var _tabs: TabContainer
var _map: MapView
var _cheat: LineEdit
var _open := false
var _map_only := false
var _stats_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = true
	_root.visible = false
	_cheat.visible = false


func _build() -> void:
	var font_black: Font = load("res://assets/fonts/inter_black.woff")
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.93)
	_root.add_theme_stylebox_override("panel", sb)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var vb := VBoxContainer.new()
	_root.add_child(vb)
	var title := Label.new()
	title.text = "  VICE CITY  ·  LEONIDA"
	title.add_theme_font_override("font", font_black)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1, 0.45, 0.75))
	vb.add_child(title)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_tabs)
	# MAP
	_map = MapView.new()
	_map.name = "Mapa"
	_tabs.add_child(_map)
	# BRIEF / STATS
	var stats := VBoxContainer.new()
	stats.name = "Estadísticas"
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 22)
	stats.add_child(_stats_label)
	_tabs.add_child(stats)
	# SETTINGS
	var sett := GridContainer.new()
	sett.name = "Ajustes"
	sett.columns = 2
	_tabs.add_child(sett)
	_slider(sett, "Sensibilidad de la cámara" if Game.touch else "Sensibilidad del ratón", 0.05, 1.0, Game.settings.mouse_sens, func(v): Game.settings.mouse_sens = v)
	_slider(sett, "Campo de visión (FOV)", 55.0, 100.0, Game.settings.fov, func(v): Game.settings.fov = v)
	_slider(sett, "Volumen", 0.0, 1.0, Game.settings.volume, _set_volume)
	_slider(sett, "Densidad de tráfico y peatones", 0.2, 1.5, 1.0, _set_density)
	_option(sett, "Dificultad", Game.DIFFICULTIES, Game.difficulty(), func(v): Game.settings.difficulty = v)
	_check(sett, "Invertir eje Y", Game.settings.invert_y, func(v): Game.settings.invert_y = v)
	_check(sett, "Mostrar FPS", Game.settings.show_fps, func(v): Game.settings.show_fps = v)
	_check(sett, "Sombras", Game.sky.sun.shadow_enabled if Game.sky else true, _set_shadows)
	if not Game.mobile:
		_check(sett, "Pantalla completa", false, _set_fullscreen)
	_check(sett, "SSAO (oclusión ambiental)", Game.sky.env.ssao_enabled if Game.sky else true, _set_ssao)
	_check(sett, "Reflejos en pantalla (SSR)", Game.sky.env.ssr_enabled if Game.sky else true, func(v): if Game.sky: Game.sky.env.ssr_enabled = v)
	if Game.mobile:
		_slider(sett, "Resolución 3D", 0.4, 1.0, get_tree().root.scaling_3d_scale, func(v): get_tree().root.scaling_3d_scale = v)
	# CONTROLS
	var help := Label.new()
	help.name = "Controles"
	help.add_theme_font_size_override("font_size", 19)
	help.text = """A PIE
  WASD / Stick izq.  Moverse          Shift  Correr        Alt  Caminar       Espacio  Saltar
  C / Ctrl  Agacharse                 Ratón  Cámara        Clic der.  Apuntar  Clic izq.  Disparar / Golpear
  R  Recargar     TAB (mantener)  Rueda de armas     1-8  Categorías de armas     G  Granada / molotov     E  Interactuar
  F / Enter  Entrar / robar vehículo (con conductor = carjacking)             Z  Cambiar entre Jason y Lucía

EN VEHÍCULO
  W / S  Acelerar / Frenar-marcha atrás     A / D  Girar     Espacio  Freno de mano (derrapes)
  H  Claxon     Q  Sirena (policía/ambulancia)     L  Luces     N  Emisora de radio     V  Cámara
  Clic der. + izq.  Disparar desde el coche (pistola / subfusil)      F  Salir (en marcha: saltar)

EN AVIÓN
  W / S  Potencia     Ratón  El avión vuela hacia donde mira la cámara     A / D  Alabeo
  Espacio  Frenos en tierra     F  Saltar en paracaídas (WASD para planear)
HELICÓPTERO
  Espacio / C  Subir / bajar     W/S  Adelante / atrás     A/D  Lateral     Ratón  Rumbo (vuelo estacionario automático)

GENERAL
  M  Mapa (clic para marcar destino GPS)     ESC / P  Pausa     F5  Guardar     F9  Cargar     T  Trucos
TRUCOS: DINERO, ARMAS, VIDA, DIOS, MUNICION, SINPOLICIA, POLICIA5, POLICIA6, SUPERCOCHE, INFERNUS, DEPORTIVO, DRAGSTER, MONSTRUO, F1,
        PATRULLA, TAXI, AMBULANCIA, BOMBEROS, CAMION, AUTOBUS, AVIONETA, JET, CAZA, JUMBO, HELICOPTERO, HELIPOLICIA, LANCHA,
        TORMENTA, SOL, NOCHE, MEDIODIA, RAPIDO, CAOS, TELEPORT"""
	if Game.touch:
		help.text = """PANTALLA TÁCTIL
  Mitad izquierda: joystick para moverte (llévalo al borde para correr; en vehículos acelera, frena y gira)
  Mitad derecha: arrastra el dedo para mover la cámara (también mientras mantienes DISPARAR o APUNTAR)
  DISPARAR (mantener)   APUNTAR (tocar para activar/desactivar)   SALTAR   AGACHAR   R Recargar   ARMA ▸ Cambiar arma
  F  Entrar / salir del vehículo (mantener para darle la vuelta)   E  Usar (tiendas, gasolineras, guardar)   G  Granada
  En coche: FRENO MANO, CLAXON, SIRENA, RADIO y VISTA     En helicóptero: SUBIR / BAJAR     En avión: FRENOS
  Arriba: II pausa, MAPA (toca para marcar destino), Z cambiar Jason/Lucía, T trucos, VISTA cámara
  Botón «atrás» de Android: pausa / cerrar menús

TRUCOS: DINERO, ARMAS, VIDA, DIOS, MUNICION, SINPOLICIA, POLICIA5, POLICIA6, SUPERCOCHE, INFERNUS, DEPORTIVO, DRAGSTER, MONSTRUO, F1,
        PATRULLA, TAXI, AMBULANCIA, BOMBEROS, CAMION, AUTOBUS, AVIONETA, JET, CAZA, JUMBO, HELICOPTERO, HELIPOLICIA, LANCHA,
        TORMENTA, SOL, NOCHE, MEDIODIA, RAPIDO, CAOS, TELEPORT"""
	_tabs.add_child(help)
	# GAME
	var game := VBoxContainer.new()
	game.name = "Partida"
	_tabs.add_child(game)
	for pair in [["Continuar", toggle.bind(false)], ["Guardar partida", _do_save], ["Cargar partida", _do_load], ["Salir del juego" if Game.mobile else "Salir al escritorio", _do_quit]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(360, 54)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(pair[1])
		game.add_child(b)
	# cheat console
	_cheat = LineEdit.new()
	_cheat.placeholder_text = "Escribe un truco y pulsa Enter (ESC para cancelar)"
	UI.place(_cheat, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -220), Vector2(600, 44))
	_cheat.add_theme_font_size_override("font_size", 22)
	_cheat.text_submitted.connect(_on_cheat)
	add_child(_cheat)


func _slider(parent: Control, text: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = (mx - mn) / 100.0
	s.value = val
	s.custom_minimum_size = Vector2(400, 30)
	s.value_changed.connect(_on_setting.bind(cb))
	parent.add_child(s)


func _option(parent: Control, text: String, items: Array, val: int, cb: Callable) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = val
	o.add_theme_font_size_override("font_size", 20)
	o.item_selected.connect(_on_setting.bind(cb))
	parent.add_child(o)


func _check(parent: Control, text: String, val: bool, cb: Callable) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	var c := CheckBox.new()
	c.button_pressed = val
	c.toggled.connect(_on_setting.bind(cb))
	parent.add_child(c)


func _on_setting(v, cb: Callable) -> void:
	cb.call(v)
	Game.save_settings()


func _set_volume(v: float) -> void:
	Game.settings.volume = v
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func _set_density(v: float) -> void:
	if Game.population:
		Game.population.density = v


func _set_shadows(v: bool) -> void:
	if Game.sky:
		Game.sky.sun.shadow_enabled = v


func _set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_ssao(v: bool) -> void:
	if Game.sky:
		Game.sky.env.ssao_enabled = v


func _do_save() -> void:
	Game.save_game()


func _do_load() -> void:
	Game.load_game()
	toggle()


func _do_quit() -> void:
	get_tree().quit()


func toggle(map_only := false) -> void:
	_open = not _open
	_root.visible = _open
	Game.paused = _open
	get_tree().paused = _open
	if _open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_tabs.current_tab = 0 if map_only else _tabs.current_tab
		_map.center_on_player()
		_update_stats()
		Sfx.play("ui")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_stats() -> void:
	var s := Game.stats
	_stats_label.text = """
  Dinero: $%d
  Asesinatos: %d        Policías abatidos: %d
  Vehículos robados: %d
  Atracos: %d
  Arrestado (BUSTED): %d        Muerto (WASTED): %d
  Distancia recorrida: %.1f km
  Hora en Vice City: %s   ·   Clima: %s
  Trucos usados: %d""" % [Game.money, s.kills, s.cops_killed, s.cars_stolen, s.robberies, s.busted, s.wasted,
		s.distance / 1000.0, Game.sky.clock_string() if Game.sky else "", Game.sky.weather if Game.sky else "", Game.cheats_used]


func _unhandled_input(event: InputEvent) -> void:
	if _cheat.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_cheat()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if _open and _tabs.current_tab == 0:
			toggle()
		elif not _open:
			toggle(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cheat") and not _open:
		_cheat.visible = true
		_cheat.text = ""
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.paused = true
		get_tree().paused = true
		_cheat.grab_focus()
		get_viewport().set_input_as_handled()


func _close_cheat() -> void:
	_cheat.visible = false
	_cheat.release_focus()
	Game.paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_cheat(text: String) -> void:
	_close_cheat()
	Cheats.apply(text.strip_edges().to_upper())


class MapView extends Control:
	## Regions of the state of Leonida covered by the map (GTA VI).
	const REGIONS := [["VICE CITY", Vector3(-250, 0, -420)], ["GRASSRIVERS", Vector3(-1380, 0, 640)],
		["CAYOS DE LEONIDA", Vector3(-650, 0, 2050)], ["VICE BEACH", Vector3(990, 0, -900)], ["AEROPUERTO", Vector3(-1380, 0, -1000)]]
	var zoom := 0.45
	var offset := Vector2.ZERO
	var _drag := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func center_on_player() -> void:
		offset = MapImage.world_to_px(Game.player_pos())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				zoom = clampf(zoom * 1.15, 0.2, 3.0)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				zoom = clampf(zoom / 1.15, 0.2, 3.0)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				_drag = e.pressed
			elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				var px = offset + (e.position - size * 0.5) / zoom
				var w := MapImage.px_to_world(px)
				if Game.has_meta("waypoint") and (Game.get_meta("waypoint") as Vector3).distance_to(w) < 30.0 / zoom:
					Game.remove_meta("waypoint")
				else:
					w.y = CityMap.LAND
					Game.set_meta("waypoint", w)
					Sfx.play("ui_move")
			queue_redraw()
		elif e is InputEventMouseMotion and (_drag or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)):
			offset -= e.relative / zoom
			queue_redraw()

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.38, 0.52))
		if MapImage.texture == null:
			return
		var c := size * 0.5
		draw_set_transform(c - offset * zoom, 0, Vector2(zoom, zoom))
		draw_texture(MapImage.texture, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var font := get_theme_default_font()
		# the big regions of Leonida (GTA VI) when zoomed out, district names when zoomed in
		if zoom < 0.6:
			for reg in REGIONS:
				var p := c + (MapImage.world_to_px(reg[1]) - offset) * zoom
				_label(font, p, reg[0], 26, Color(1, 1, 1, 0.85))
		else:
			for d in Game.city.districts:
				var r: Rect2 = d.rect
				var p := c + (MapImage.world_to_px(Vector3(r.get_center().x, 0, r.get_center().y)) - offset) * zoom
				_label(font, p, d.name.to_upper(), 16, Color(1, 1, 1, 0.75))
		# locations
		var loc = Game.get_meta("locations") if Game.has_meta("locations") else null
		if loc:
			for pl in loc.places:
				var p := c + (MapImage.world_to_px(pl.pos) - offset) * zoom
				var b: Array = Locations.BLIP.get(pl.kind, ["•", Color.WHITE])
				draw_circle(p, 11, Color(0, 0, 0, 0.8))
				draw_string(font, p + Vector2(-7, 7), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, b[1])
		# waypoint
		if Game.has_meta("waypoint"):
			var p := c + (MapImage.world_to_px(Game.get_meta("waypoint")) - offset) * zoom
			draw_circle(p, 9, Color(0.8, 0.4, 1))
		# player
		var pp := c + (MapImage.world_to_px(Game.player_pos()) - offset) * zoom
		var fwd := Vector2(0, -1).rotated(-Game.player.global_rotation.y)
		var right := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pp + fwd * 14, pp - fwd * 9 + right * 9, pp - fwd * 9 - right * 9]), Color.WHITE)
		# police and army units while wanted
		if Game.wanted and Game.get_wanted() > 0:
			for u in Game.wanted.units + Game.wanted.helis:
				if u != null and is_instance_valid(u) and not u.destroyed:
					var up := c + (MapImage.world_to_px(u.global_position) - offset) * zoom
					draw_circle(up, 7, Color(0, 0, 0, 0.8))
					draw_circle(up, 5, Color(1, 0.25, 0.25))
		_legend(font)
		draw_string(font, Vector2(16, size.y - 20), "Rueda: zoom · Clic der. arrastrar: mover · Clic izq.: marcar destino GPS · M: cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))

	## GTA V style legend on the right.
	func _legend(font: Font) -> void:
		var items := [["gun", "Armería"], ["store", "Tienda 24h (se puede atracar)"], ["gas", "Gasolinera"], ["clothes", "Tienda de ropa"],
			["spray", "Pinta Rápido"], ["hospital", "Hospital"], ["police", "Comisaría"], ["safe", "Casa segura (guardar)"]]
		var w := 290.0
		var h := 40.0 + items.size() * 30.0 + 60.0
		var x0 := size.x - w - 16.0
		var y0 := 16.0
		draw_rect(Rect2(x0, y0, w, h), Color(0, 0, 0, 0.72))
		draw_string(font, Vector2(x0 + 14, y0 + 28), "LEYENDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.55, 0.8))
		var y := y0 + 58.0
		for it in items:
			var b: Array = Locations.BLIP.get(it[0], ["•", Color.WHITE])
			draw_circle(Vector2(x0 + 26, y - 6), 11, Color(0.12, 0.12, 0.14))
			draw_string(font, Vector2(x0 + 19, y + 1), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, b[1])
			draw_string(font, Vector2(x0 + 46, y), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
			y += 30.0
		draw_circle(Vector2(x0 + 26, y - 6), 7, Color(0.8, 0.4, 1))
		draw_string(font, Vector2(x0 + 46, y), "Destino GPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
		y += 30.0
		draw_circle(Vector2(x0 + 26, y - 6), 5, Color(1, 0.25, 0.25))
		draw_string(font, Vector2(x0 + 46, y), "Policía / ejército", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

	func _label(font: Font, p: Vector2, text: String, fs: int, col: Color) -> void:
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, p - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.6))
		draw_string(font, p - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
