class_name Interactions
extends Node
## Context actions at locations: refuel, gun shop, store robbery (GTA VI style), clothes, paint & spray,
## hospital, safehouse save. Also spawns shop clerks when the player is near.

var loc: Locations
var _t := 0.0
var current: Dictionary = {}
var shop_ui: ShopMenu
var rob_progress := 0.0
var clerks := {}          # place name -> Humanoid
var _refuel_hold := 0.0
var _distance_last := Vector3.ZERO
var _clerk_seq := {}      # place name -> [[anim, seconds], ...] played by the clerk in order
var _last_place := ""


func _ready() -> void:
	loc = Game.get_meta("locations")
	shop_ui = ShopMenu.new()
	shop_ui.name = "ShopMenu"
	Game.hud.get_parent().add_child(shop_ui)
	shop_ui.closed.connect(_on_shop_closed)


func _physics_process(delta: float) -> void:
	var p := Game.player
	if p == null or p.dead or Game.paused:
		return
	# distance stat
	var pp := Game.player_pos()
	if _distance_last != Vector3.ZERO:
		var d := pp.distance_to(_distance_last)
		if d < 50.0:
			Game.stats.distance += d
	_distance_last = pp
	_t -= delta
	if _t <= 0.0:
		_t = 0.15
		current = loc.place_at(pp)
		_manage_clerks(pp)
		var name_now: String = current.get("name", "")
		if name_now != _last_place:
			if current.get("kind", "") == "gun" and p.vehicle == null:
				_clerk_play(name_now, [["Point", 1.5], ["Idle_Talking", -1.0]])
				Game.msg("Dependiente: Bienvenido. Mira lo que quieras, aquí no preguntamos.", 3.0)
			if _last_place != "" and clerks.has(_last_place):
				_clerk_play(_last_place, [["Idle", -1.0]])
			_last_place = name_now
	_update_clerks(delta)
	if current.is_empty():
		rob_progress = 0.0
		return
	match current.kind:
		"gas":
			if p.vehicle and "fuel" in p.vehicle:
				var v = p.vehicle
				if v.fuel >= 0.999:
					Game.hud.prompt("Depósito lleno")
				else:
					var cost := int((1.0 - v.fuel) * 80.0) + 5
					Game.hud.prompt("Mantén E para repostar ($%d)" % cost)
					if Input.is_action_pressed("interact"):
						_refuel_hold += delta
						if _refuel_hold > 0.6:
							if Game.money >= cost:
								Game.money -= cost
								v.fuel = 1.0
								Game.msg("Depósito lleno (-$%d)" % cost, 2.0)
								Sfx.play("money")
							else:
								Game.msg("No tienes suficiente dinero")
							_refuel_hold = 0.0
					else:
						_refuel_hold = 0.0
			else:
				Game.hud.prompt(current.name)
		"gun":
			if p.vehicle == null:
				Game.hud.prompt("Pulsa E para comprar armas")
				if Input.is_action_just_pressed("interact"):
					shop_ui.open_guns(p)
		"clothes":
			if p.vehicle == null:
				Game.hud.prompt("Pulsa E para cambiarte de ropa ($150)")
				if Input.is_action_just_pressed("interact"):
					_change_clothes(p)
		"store":
			_store(p, delta)
		"spray":
			if p.vehicle and p.vehicle is Vehicle:
				var v: Vehicle = p.vehicle
				Game.hud.prompt("Pulsa E: reparar, pintar y perder a la policía ($250)")
				if Input.is_action_just_pressed("interact"):
					if Game.money < 250:
						Game.msg("No tienes suficiente dinero")
					elif Game.wanted.seen and Game.get_wanted() > 0:
						Game.msg("¡La policía te está viendo!")
					else:
						Game.money -= 250
						v.repair()
						v.set_paint(VehicleDB.PAINTS.pick_random())
						Game.wanted.clear()
						Game.hud.fade(0.4)
						Game.msg("Coche como nuevo. Nadie te reconocerá.", 3.0)
		"hospital":
			if p.vehicle == null and p.health < p.max_health:
				Game.hud.prompt("Pulsa E para curarte ($200)")
				if Input.is_action_just_pressed("interact") and Game.money >= 200:
					Game.money -= 200
					p.health = p.max_health
					Sfx.play("pickup")
		"safe":
			if p.vehicle == null:
				Game.hud.prompt("Pulsa E para guardar la partida y descansar")
				if Input.is_action_just_pressed("interact"):
					if Game.get_wanted() > 0:
						Game.msg("No puedes guardar mientras te busca la policía")
					else:
						Game.save_game()
						p.health = p.max_health
						Game.sky.time_of_day = fmod(Game.sky.time_of_day + 6.0, 24.0)
						Game.hud.fade(0.6)
		"police":
			pass


func _store(p: Humanoid, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < current.get("robbed_until", 0.0):
		Game.hud.prompt("La caja está vacía. Vuelve más tarde.")
		return
	var clerk: Humanoid = clerks.get(current.name)
	if p.vehicle:
		return
	var armed = p.current_def().get("type", "melee") in ["gun", "launcher"]
	if not armed:
		Game.hud.prompt("%s · Apunta al dependiente con un arma para atracar" % current.name)
		rob_progress = 0.0
		return
	var aiming_at_clerk := false
	if clerk and is_instance_valid(clerk) and not clerk.dead and p.aiming:
		var dir := (p.aim_point - p.eye_position()).normalized()
		var to := (clerk.global_position + Vector3.UP * 1.3 - p.eye_position()).normalized()
		aiming_at_clerk = dir.dot(to) > 0.9
	if aiming_at_clerk:
		rob_progress += delta
		clerk.want_crouch = false
		if clerk.model:
			clerk.model.play("Idle_No")
		Game.hud.prompt("¡ATRACO!  Vaciando la caja... %d%%" % int(clampf(rob_progress / 4.0, 0, 1) * 100))
		if rob_progress > 0.3 and rob_progress - delta <= 0.3:
			Game.report_crime(p.global_position, 3.0, "robbery")
		if rob_progress >= 4.0:
			rob_progress = 0.0
			current["robbed_until"] = now + 300.0
			var amount := randi_range(600, 2800)
			Pickups.spawn_money(clerk.global_position + current.clerk_face * 1.5 + Vector3.UP * 0.2, amount)
			Game.stats.robberies += 1
			SocialFeed.event("robbery")
			Game.msg("¡Atraco completado! Coge el dinero y huye antes de que salte la alarma.", 3.0)
			# the silent alarm reaches the police a few seconds later
			Game.wanted.alarm(2, randf_range(3.0, 6.0), p.global_position)
			if clerk.brain:
				clerk.brain.state = PedBrain.S.COWER
				clerk.brain.t = 20.0
	else:
		rob_progress = maxf(0.0, rob_progress - delta * 0.5)
		Game.hud.prompt("%s · Apunta al dependiente para atracar" % current.name)


## Queues full-body animations for a shop clerk (seconds < 0: hold until the next request).
func _clerk_play(place: String, seq: Array) -> void:
	_clerk_seq[place] = seq.duplicate(true)
	_apply_clerk_anim(place)


func _apply_clerk_anim(place: String) -> void:
	var c = clerks.get(place)
	var seq: Array = _clerk_seq.get(place, [])
	if c == null or not is_instance_valid(c) or c.dead or c.brain == null or seq.is_empty():
		return
	if c.brain.state == PedBrain.S.BEACH:
		c.brain.idle_anim = seq[0][0]
		if c.model:
			if c.model.current_loco == seq[0][0]:
				c.model.restart(seq[0][0])
			else:
				c.model.play(seq[0][0])


func _update_clerks(delta: float) -> void:
	for place in _clerk_seq.keys():
		var seq: Array = _clerk_seq[place]
		if seq.is_empty() or float(seq[0][1]) < 0.0:
			continue
		seq[0][1] = float(seq[0][1]) - delta
		if seq[0][1] <= 0.0:
			seq.pop_front()
			_apply_clerk_anim(place)
		# the gun shop clerk only draws the shotgun when there is trouble
	for place in clerks:
		var c = clerks[place]
		if c != null and is_instance_valid(c) and not c.dead and c.brain and c.brain.state == PedBrain.S.FIGHT \
				and c.current_weapon_id() == "fists" and c.has_weapon("shotgun"):
			c.give_weapon("shotgun", 0, true)


func _on_shop_closed(bought: int) -> void:
	if bought > 0 and current.get("kind", "") == "gun":
		_clerk_play(current.name, [["Interact", 1.4], ["Yes", 1.6], ["Idle_Talking", -1.0]])
		Game.msg("Dependiente: Buena elección. Úsala con cabeza.", 2.5)


func _manage_clerks(pp: Vector3) -> void:
	for pl in loc.places:
		if not pl.has("clerk_pos"):
			continue
		var d: float = (pl.clerk_pos as Vector3).distance_to(pp)
		var c = clerks.get(pl.name)
		if d < 70.0 and (c == null or not is_instance_valid(c)):
			var g := "male" if randf() < 0.5 else "female"
			var h = Game.population.spawn_ped(pl.clerk_pos + Vector3.UP * 0.2, "male" if pl.kind == "gun" else g,
					"clerk" if pl.kind == "gun" else "tee")
			Game.population.peds.erase(h)
			h.brain.state = PedBrain.S.BEACH
			h.brain.idle_anim = "Idle"
			h.face_target = pl.clerk_pos + pl.clerk_face * 5.0
			h.rotation.y = atan2(-pl.clerk_face.x, -pl.clerk_face.z)
			if pl.kind == "gun":
				h.give_weapon("shotgun", 40)
				h.select_weapon(0)
				h.brain.aggressive = true
			clerks[pl.name] = h
		elif d > 120.0 and c != null and is_instance_valid(c):
			c.queue_free()
			clerks.erase(pl.name)


func _change_clothes(p: Humanoid) -> void:
	if Game.money < 150:
		Game.msg("No tienes suficiente dinero")
		return
	Game.money -= 150
	# new hairstyle colour (the protagonists keep their own clothes)
	p.model.set_outfit(p.model.outfit_file, CharacterModel.HAIR_COLORS.pick_random(), true)
	Game.msg("Nuevo look. ¡Estás increíble!", 2.0)
	Sfx.play("pickup")
	if Game.get_wanted() > 0 and not Game.wanted.seen:
		Game.wanted.set_level(maxi(0, Game.get_wanted() - 1))


class ShopMenu extends PanelContainer:
	signal closed(bought: int)
	var _list: VBoxContainer
	var _p: Humanoid
	var _bought := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false
		custom_minimum_size = Vector2(720, 680)
		UI.place(self, Control.PRESET_CENTER, Vector2(-360, -340), Vector2(720, 680))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.04, 0.1, 0.95)
		sb.border_color = Color(1, 0.4, 0.7)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		add_child(vb)
		var t := Label.new()
		t.text = "  ARMERÍA DE LEONIDA"
		t.add_theme_font_size_override("font_size", 34)
		t.add_theme_color_override("font_color", Color(1, 0.5, 0.75))
		vb.add_child(t)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(sc)
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_list)
		var close := Button.new()
		close.text = "Salir (ESC)"
		close.pressed.connect(close_menu)
		vb.add_child(close)

	func open_guns(p: Humanoid) -> void:
		if not visible:
			_bought = 0
		_p = p
		for c in _list.get_children():
			c.queue_free()
		for id in WeaponDB.SHOP:
			var d := WeaponDB.get_def(id)
			var hb := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s" % d.name
			l.custom_minimum_size = Vector2(320, 0)
			l.add_theme_font_size_override("font_size", 21)
			hb.add_child(l)
			var b := Button.new()
			b.text = "Arma $%d" % d.price if not p.has_weapon(id) else "Ya la tienes"
			b.disabled = p.has_weapon(id)
			b.custom_minimum_size = Vector2(170, 44)
			b.pressed.connect(_buy.bind(id, false))
			hb.add_child(b)
			if d.get("type", "") != "melee":
				var b2 := Button.new()
				b2.text = "Munición $%d" % d.ammo_price
				b2.custom_minimum_size = Vector2(170, 44)
				b2.pressed.connect(_buy.bind(id, true))
				hb.add_child(b2)
			_list.add_child(hb)
		var hb2 := HBoxContainer.new()
		var la := Label.new()
		la.text = "Chaleco antibalas"
		la.custom_minimum_size = Vector2(250, 0)
		la.add_theme_font_size_override("font_size", 22)
		hb2.add_child(la)
		var ba := Button.new()
		ba.text = "$500"
		ba.custom_minimum_size = Vector2(170, 44)
		ba.pressed.connect(_buy.bind("armor", false))
		hb2.add_child(ba)
		_list.add_child(hb2)
		visible = true
		Game.paused = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	func _buy(id: String, ammo: bool) -> void:
		if id == "armor":
			if Game.money >= 500:
				Game.money -= 500
				_p.armor = 100.0
				_bought += 1
				Sfx.play("money")
			return
		var d := WeaponDB.get_def(id)
		var cost: int = d.ammo_price if ammo else d.price
		if Game.money < cost:
			Game.msg("No tienes suficiente dinero")
			return
		Game.money -= cost
		var amount: int = int(d.get("clip", 1)) * (2 if ammo else 3)
		if d.get("type", "") == "throw":
			amount = 3 if ammo else 5
		elif d.get("type", "") == "melee":
			amount = 0
		elif id == "minigun":
			amount = 500 if ammo else 1000
		_p.give_weapon(id, amount, not ammo)
		_bought += 1
		Sfx.play("money")
		open_guns(_p)

	func close_menu() -> void:
		visible = false
		Game.paused = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit(_bought)

	func _unhandled_input(e: InputEvent) -> void:
		if visible and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause")):
			close_menu()
			get_viewport().set_input_as_handled()
