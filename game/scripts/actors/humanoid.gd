class_name Humanoid
extends CharacterBody3D
## Shared body for the player, pedestrians, cops and gang members.
## Controllers (player input or AI brains) write the "intent" variables; this class does the rest.

signal died(h: Humanoid, killer: Node)
signal damaged(h: Humanoid, amount: float, attacker: Node)

const GRAVITY := 18.0
const WALK_SPEED := 1.7
const JOG_SPEED := 4.4
const SPRINT_SPEED := 7.2
const CROUCH_SPEED := 1.5
const AIM_SPEED := 2.3
const SWIM_SPEED := 2.6
const JUMP_VELOCITY := 5.4

# --- intent (written by controllers) ---
var move_dir := Vector3.ZERO
var want_sprint := false
var want_walk := false
var want_jump := false
var want_crouch := false
var aiming := false
var aim_point := Vector3.ZERO
var trigger := false
var face_target := Vector3.ZERO   # optional: face this point when idle (NPC conversations)

# --- identity ---
var is_player := false
var team := "civilian"        # player, civilian, police, gang_purple, gang_green
var gender := "male"
var display_name := ""
var model: CharacterModel
var brain: Node = null        # AI brain (NPCs)

# --- stats ---
var max_health := 100.0
var health := 100.0
var armor := 0.0
var dead := false
var money_carried := 0

# --- state ---
var vehicle: Node = null      # Vehicle or Boat
var seat := 0
var swimming := false
var crouching := false
var down_timer := 0.0         # knocked down
var hit_react := 0.0
var busy_anim := 0.0          # full-body one-shot playing (punch, throw, etc)
var entering := 0.0
var _enter_target: Node = null
var _enter_seat := 0
var air_time := 0.0
var fall_start_y := 0.0
var parachute_in := 0.0          # >0: seconds until the parachute opens (after bailing out of a plane)
var _chute: Node3D
var last_attacker: Node = null
var death_time := 0.0
var stamina := 100.0

# --- weapons ---
var weapons: Array = [{"id": "fists", "clip": 0, "ammo": 0}]
var weapon_index := 0
var fire_cd := 0.0
var reload_left := 0.0
var melee_combo := 0
var _weapon_attach: BoneAttachment3D
var _weapon_pivot: Node3D
var _weapon_model: Node3D
var _weapon_model_id := ""
var recoil := 0.0
var spread_bloom := 0.0
var last_hurt_time := -100.0      # player: health regenerates a while after the last hit

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _footstep_t := 0.0


func setup(p_gender: String, outfit := "", hair := "", beard := false, hair_color := Color(-1, 0, 0)) -> void:
	gender = p_gender
	add_to_group("humanoids")
	collision_layer = Game.LAYER_CHAR
	collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE | Game.LAYER_CHAR
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.32
	_capsule.height = 1.8
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = 0.9
	add_child(_shape)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52)
	safe_margin = 0.02
	model = CharacterModel.new()
	model.name = "Model"
	add_child(model)
	model.build(gender, outfit, hair, hair_color, beard)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponPivot"
	_weapon_attach = model.attach_to_bone(_weapon_pivot, "RightHand")
	_update_weapon_model()


func _ready() -> void:
	fall_start_y = global_position.y


# ------------------------------------------------------------------ weapons
func current_weapon() -> Dictionary:
	return weapons[clampi(weapon_index, 0, weapons.size() - 1)]


func current_weapon_id() -> String:
	return current_weapon().id


func current_def() -> Dictionary:
	return WeaponDB.get_def(current_weapon_id())


func has_weapon(id: String) -> bool:
	for w in weapons:
		if w.id == id:
			return true
	return false


func give_weapon(id: String, ammo := -1, select := false) -> void:
	var d := WeaponDB.get_def(id)
	if ammo < 0:
		ammo = int(d.get("clip", 1)) * 4
	for i in weapons.size():
		if weapons[i].id == id:
			weapons[i].ammo += ammo
			if select:
				select_weapon(i)
			return
	var clip: int = mini(int(d.get("clip", 0)), ammo)
	weapons.append({"id": id, "clip": clip, "ammo": ammo - clip})
	weapons.sort_custom(func(a, b): return WeaponDB.ORDER.find(a.id) < WeaponDB.ORDER.find(b.id))
	if select:
		for i in weapons.size():
			if weapons[i].id == id:
				select_weapon(i)


func select_weapon(i: int) -> void:
	weapon_index = clampi(i, 0, weapons.size() - 1)
	reload_left = 0.0
	fire_cd = maxf(fire_cd, 0.25)
	_update_weapon_model()


func cycle_weapon(dir: int) -> void:
	if weapons.size() <= 1:
		return
	select_weapon(wrapi(weapon_index + dir, 0, weapons.size()))


func total_ammo() -> int:
	var w := current_weapon()
	return int(w.clip) + int(w.ammo)


func _update_weapon_model() -> void:
	var id := current_weapon_id()
	if id == _weapon_model_id:
		return
	_weapon_model_id = id
	if _weapon_model:
		_weapon_model.queue_free()
		_weapon_model = null
	if id == "fists" or vehicle != null:
		return
	_weapon_model = WeaponDB.make_model(id)
	if _weapon_model:
		_weapon_pivot.add_child(_weapon_model)


func muzzle_position() -> Vector3:
	if _weapon_model:
		var m := _weapon_model.get_node_or_null("Muzzle")
		if m:
			return m.global_position
	return global_position + Vector3.UP * 1.45 - global_basis.z * 0.5


func eye_position() -> Vector3:
	return global_position + Vector3.UP * (1.1 if crouching else 1.62)


func start_reload() -> void:
	var w := current_weapon()
	var d := current_def()
	if d.get("type", "") in ["melee", "throw"] or reload_left > 0.0:
		return
	if int(w.clip) >= int(d.get("clip", 0)) or int(w.ammo) <= 0:
		return
	reload_left = float(d.get("reload", 1.5))
	if model:
		model.upper("Pistol_Reload")
	Sfx.play_at("reload", global_position, -6.0)


func _finish_reload() -> void:
	var w := current_weapon()
	var d := current_def()
	var need: int = int(d.get("clip", 0)) - int(w.clip)
	var take: int = mini(need, int(w.ammo))
	if Game.infinite_ammo and is_player:
		take = need
	else:
		w.ammo = int(w.ammo) - take
	w.clip = int(w.clip) + take


## Called every frame while the trigger is held. Returns true if a shot happened.
func try_fire() -> bool:
	if dead or fire_cd > 0.0 or reload_left > 0.0 or down_timer > 0.0 or swimming:
		return false
	var d := current_def()
	var w := current_weapon()
	match d.get("type", "melee"):
		"melee":
			_melee_attack(d)
			return true
		"throw":
			if int(w.clip) + int(w.ammo) <= 0:
				return false
			_throw_grenade()
			return true
	if int(w.clip) <= 0:
		if int(w.ammo) > 0:
			start_reload()
		else:
			Sfx.play_at("dry", global_position, -8.0)
			fire_cd = 0.3
		return false
	if not (Game.infinite_ammo and is_player):
		w.clip = int(w.clip) - 1
	fire_cd = float(d.rate)
	var npc := not is_player and team != "player"
	if npc:
		# NPCs fire in slower bursts
		fire_cd *= randf_range(1.8, 3.0)
	var from := muzzle_position()
	var aim := aim_point
	if aim == Vector3.ZERO:
		aim = from - global_basis.z * 50.0
	if npc and randf() < Game.by_difficulty([0.72, 0.55, 0.4, 0.25]):
		# deliberate miss (GTA-style forgiving NPC accuracy)
		aim += Vector3(randf_range(-1.6, 1.6), randf_range(-0.6, 1.4), randf_range(-1.6, 1.6))
	if d.type == "launcher" and d.get("projectile", "") == "shell":
		Combat.fire_shell(from, Combat.apply_spread((aim - from).normalized(), float(d.spread)), self)
	elif d.type == "launcher":
		Combat.fire_rocket(from, (aim - from).normalized(), self)
	else:
		var pellets: int = int(d.get("pellets", 1))
		var spread: float = float(d.spread) + spread_bloom * (0.5 if crouching else 1.0)
		if not is_player:
			spread *= Game.by_difficulty([2.8, 2.2, 1.7, 1.3])
		for i in pellets:
			var dir := (aim - from).normalized()
			dir = Combat.apply_spread(dir, spread)
			Combat.fire_bullet(from, dir, float(d.range), float(d.damage), self)
		spread_bloom = minf(spread_bloom + float(d.recoil) * 0.6, 6.0)
	recoil += float(d.get("recoil", 1.0))
	Game.effects.muzzle_flash(from, (aim - from).normalized(), d.type == "launcher")
	Sfx.play_at(d.get("sound", "pistol"), from, 0.0 if is_player else -3.0)
	if model:
		model.upper("Rifle_Fire" if d.get("hold", "") == "rifle" and d.type == "gun" else "Aim")
	# shooting in public is a crime (police are allowed, and so is a gun shop's shooting range)
	if team != "police" and not GunShop.in_range(global_position):
		Game.report_crime(global_position, 1.0 if is_player else 0.0, "shots")
		if Game.population:
			Game.population.panic_at(global_position, 35.0, self)
	if int(w.clip) <= 0 and int(w.ammo) > 0:
		start_reload()
	return true


func _melee_attack(d: Dictionary) -> void:
	fire_cd = float(d.rate)
	melee_combo = (melee_combo + 1) % 3
	var anim: String = ["Punch_Jab", "Punch_Cross", "Melee_Hook"][melee_combo]
	if model:
		if move_dir.length() < 0.1:
			busy_anim = 0.35
			model.play(anim)
		else:
			model.upper("Punch_Jab" if melee_combo != 1 else "Punch_Cross")
	# find target in front
	var fwd := -global_basis.z
	var best: Node = null
	var best_d := 99.0
	for n in get_tree().get_nodes_in_group("humanoids"):
		if n == self or n.dead:
			continue
		var to: Vector3 = n.global_position - global_position
		var dist := to.length()
		if dist < float(d.range) + 0.4 and fwd.dot(to.normalized()) > 0.3 and dist < best_d:
			best = n
			best_d = dist
	if best:
		var dmg := float(d.damage) * (1.6 if melee_combo == 2 else 1.0)
		best.take_damage(dmg, self, best.global_position + Vector3.UP * 1.4, fwd, "melee")
		Sfx.play_at("thud" if current_weapon_id() == "bat" else "punch", best.global_position, 0.0)
		if (melee_combo == 2 or d.get("knockdown", false)) and best.health > 0:
			best.knockdown(fwd * 4.0 + Vector3.UP * 2.0)
	else:
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v.global_position.distance_to(global_position) < 2.6 and fwd.dot((v.global_position - global_position).normalized()) > 0.3:
				v.take_damage(3.0, self)
				Sfx.play_at("punch", global_position + fwd, -4.0)
				break
		Sfx.play_at("swing", global_position, -10.0)
	if team != "police" and best != null:
		Game.report_crime(global_position, 0.5 if is_player else 0.0, "assault")


func _throw_grenade() -> void:
	var w := current_weapon()
	fire_cd = 1.1
	if not (Game.infinite_ammo and is_player):
		if int(w.clip) > 0:
			w.clip = int(w.clip) - 1
		else:
			w.ammo = int(w.ammo) - 1
		if int(w.clip) <= 0 and int(w.ammo) > 0:
			w.clip = 1
			w.ammo = int(w.ammo) - 1
	if model:
		model.upper("OverhandThrow")
	var from := global_position + Vector3.UP * 1.7 - global_basis.z * 0.3
	var target := aim_point if aim_point != Vector3.ZERO else global_position - global_basis.z * 15.0
	var id := current_weapon_id()
	await get_tree().create_timer(0.35).timeout
	if dead or not is_inside_tree():
		return
	Combat.throw_grenade(from, target, self, "molotov" if WeaponDB.get_def(id).get("fire", false) else "frag")
	Game.report_crime(global_position, 1.5 if is_player else 0.0, "explosive")
	if total_ammo() <= 0 and current_weapon_id() == id:
		weapons.remove_at(weapon_index)
		select_weapon(0)


# ------------------------------------------------------------------ damage
func take_damage(amount: float, attacker: Node = null, hit_pos := Vector3.ZERO, dir := Vector3.ZERO, kind := "bullet") -> void:
	if dead:
		return
	if is_player and Game.god_mode:
		return
	if team == "player" and attacker is Humanoid and attacker.team != "player":
		amount *= (0.45 if is_player else 0.3) * Game.by_difficulty([0.6, 1.0, 1.4, 2.0])
	if is_player:
		last_hurt_time = Time.get_ticks_msec() / 1000.0
	if vehicle and kind == "bullet" and vehicle.has_method("is_enclosed") and vehicle.is_enclosed():
		amount *= 0.8    # the window glass takes a little of the bullet
	# headshots
	if kind == "bullet" and hit_pos != Vector3.ZERO and hit_pos.y > global_position.y + 1.52 and not crouching:
		amount *= 3.0 if not is_player else 1.6
	if armor > 0.0 and kind != "fall":
		var absorbed := minf(armor, amount * 0.7)
		armor -= absorbed
		amount -= absorbed
	health -= amount
	last_attacker = attacker
	damaged.emit(self, amount, attacker)
	if kind in ["bullet", "melee", "explosion", "vehicle"] and hit_pos != Vector3.ZERO:
		Game.effects.blood(hit_pos, dir)
	if health <= 0.0:
		die(attacker, kind, dir)
	elif kind in ["bullet", "melee"] and vehicle == null and hit_react <= 0.0 and busy_anim <= 0.0:
		hit_react = 0.3
		if model:
			model.restart("Hit_Chest")
	if brain and brain.has_method("on_damaged"):
		brain.on_damaged(attacker, amount)


func heal(v: float) -> void:
	health = minf(max_health, health + v)


func die(killer: Node = null, kind := "", dir := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	death_time = Time.get_ticks_msec() / 1000.0
	if vehicle:
		var v = vehicle
		if is_player or kind in ["explosion", "fall", "drown"] or v.destroyed or ("is_bike" in v and v.is_bike):
			exit_vehicle(true)
		else:
			_die_in_seat(v, killer)
	collision_layer = 0
	collision_mask = Game.LAYER_WORLD
	aiming = false
	trigger = false
	if model and vehicle == null:
		model.upper("")
		model.play("Death01")
	if kind == "explosion" or kind == "vehicle":
		velocity = dir * 6.0 + Vector3.UP * 5.0
	# drop some cash / weapon (not from inside a car)
	if not is_player:
		if vehicle == null and (money_carried > 0 or Game.rng.randf() < 0.5):
			Pickups.spawn_money(global_position + Vector3(0, 0.3, 0), money_carried if money_carried > 0 else Game.rng.randi_range(5, 60))
		if current_weapon_id() != "fists" and vehicle == null:
			Pickups.spawn_weapon(global_position + Vector3(0.5, 0.3, 0), current_weapon_id(), maxi(8, total_ammo()))
		if killer != null and killer == Game.player:
			Game.stats.kills += 1
			if Game.has_meta("social_feed"):
				Game.get_meta("social_feed").on_player_kill()
			if team == "police":
				Game.stats.cops_killed += 1
				Game.report_crime(global_position, 3.0, "cop_killed")
			else:
				Game.report_crime(global_position, 1.5, "murder")
	died.emit(self, killer)
	_update_weapon_model_hidden()


## Shot inside a vehicle: the body stays slumped in the seat. A dead driver lets go of the wheel
## (the car coasts on, often with the horn stuck) and the passengers still alive get out and run.
func _die_in_seat(v: Node, killer: Node) -> void:
	aiming = false
	if model:
		model.upper("")
		model.visible = true
		model.play("Sitting_Idle")
		# slumped towards the middle of the car
		model.rotation = Vector3(-0.4, model.rotation.y, -0.32 if seat % 2 == 0 else 0.32)
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(model) and model.anim_tree and vehicle != null:
				model.anim_tree.active = false)
	if seat == 0 and "throttle" in v:
		v.throttle = 0.0
		v.steer_input = randf_range(-0.25, 0.25)
		if "brake" in v:
			v.brake = 0.0
		if "handbrake" in v:
			v.handbrake = false
		if "horn" in v:
			v.horn = randf() < 0.6
		if "siren_on" in v and v.siren_on and randf() < 0.5:
			v.siren_on = false
	if Sfx:
		Sfx.play_at("glass", global_position + Vector3.UP, -2.0)
	for o in v.occupants.duplicate():
		if o != null and is_instance_valid(o) and o != self and not o.dead and not o.is_player and o.brain:
			var ov = o.vehicle
			o.exit_vehicle()
			if o.team == "police" or o.brain.aggressive:
				o.brain.threat = killer
				o.brain.state = PedBrain.S.FIGHT
				o.brain.t = 40.0
			elif ov:
				o.brain.on_gunshot(ov.global_position, killer)


func _update_weapon_model_hidden() -> void:
	if _weapon_model:
		_weapon_model.visible = false


func knockdown(impulse: Vector3) -> void:
	if dead or vehicle:
		return
	down_timer = 2.6
	velocity = impulse
	busy_anim = 0.0
	if model:
		model.upper("")
		model.restart("Hit_Knockback")


# ------------------------------------------------------------------ vehicles
func enter_vehicle(v: Node, p_seat := 0) -> void:
	vehicle = v
	seat = p_seat
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	swimming = false
	crouching = false
	aiming = false
	v.add_occupant(self, p_seat)
	if model:
		model.upper("")
		model.play("Driving" if p_seat == 0 else "Sitting_Idle")
		# visible through the windows (hidden in closed cars on phones to save GPU time)
		model.visible = not (Game.mobile and v.has_method("is_enclosed") and v.is_enclosed())
	if _weapon_model:
		_weapon_model.visible = false


func exit_vehicle(force := false) -> void:
	if vehicle == null:
		return
	var v = vehicle
	var pos: Vector3 = v.get_exit_position(seat)
	v.remove_occupant(self)
	vehicle = null
	if not dead:
		collision_layer = Game.LAYER_CHAR
		collision_mask = Game.LAYER_WORLD | Game.LAYER_VEHICLE | Game.LAYER_CHAR
	global_position = pos
	rotation = Vector3(0, v.global_rotation.y, 0)
	velocity = v.linear_velocity * (0.6 if force else 0.0) if v is RigidBody3D else Vector3.ZERO
	if model:
		model.visible = true
		if dead:
			# a body pulled out of a car
			model.rotation = Vector3(0, model.rotation.y, 0)
			if model.anim_tree:
				model.anim_tree.active = true
			model.restart("Death01")
		else:
			model.play("Idle")
	if _weapon_model:
		_weapon_model.visible = not dead
	fall_start_y = global_position.y


## Starts entering (with small delay/animation). Carjacks if occupied.
func begin_enter(v: Node) -> void:
	if entering > 0.0 or vehicle != null:
		return
	var s: int = v.free_seat_for(self)
	if s < 0:
		return
	_enter_target = v
	_enter_seat = s
	entering = 0.45
	if model:
		model.play("Interact")
	var occ = v.get_occupant(s)
	if occ != null and occ != self:
		# carjack!
		occ.exit_vehicle(true)
		if occ.dead:
			# just pull the body out
			Sfx.play_at("thud", occ.global_position, -4.0)
			return
		if occ.brain and occ.brain.has_method("on_carjacked"):
			occ.brain.on_carjacked(self)
		occ.knockdown((occ.global_position - global_position).normalized() * 2.0 + Vector3.UP)
		if is_player:
			Game.stats.cars_stolen += 1
			Game.report_crime(global_position, 1.0 if occ.team != "police" else 2.5, "carjack")
		Sfx.play_at("punch", global_position, -3.0)


# ------------------------------------------------------------------ physics
var _lod_skip := 0
var _lod_acc := 0.0
var _rest := false


func _physics_process(delta: float) -> void:
	# --- LOD: far NPCs simulate at a lower rate
	if team != "player" and vehicle == null:
		if dead and _rest:
			return
		var d2 := global_position.distance_squared_to(Game.player_pos())
		var step := 1
		if d2 > 4900.0:
			step = 4
		elif d2 > 1225.0:
			step = 2
		if step > 1 and down_timer <= 0.0 and entering <= 0.0:
			_lod_acc += delta
			_lod_skip += 1
			if _lod_skip < step:
				return
			_lod_skip = 0
			delta = _lod_acc
			_lod_acc = 0.0
	fire_cd = maxf(0.0, fire_cd - delta)
	spread_bloom = move_toward(spread_bloom, 0.0, delta * 5.0)
	recoil = move_toward(recoil, 0.0, delta * 8.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()
	if vehicle:
		_physics_in_vehicle(delta)
		return
	if dead:
		_physics_dead(delta)
		return
	if entering > 0.0:
		entering -= delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
		if _enter_target and is_instance_valid(_enter_target):
			var look: Vector3 = _enter_target.global_position - global_position
			look.y = 0
			if look.length() > 0.1:
				rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), delta * 10.0)
		if entering <= 0.0 and _enter_target and is_instance_valid(_enter_target) and not _enter_target.destroyed:
			if _enter_target.get_occupant(_enter_seat) == null:
				enter_vehicle(_enter_target, _enter_seat)
			_enter_target = null
			return
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	hit_react = maxf(0.0, hit_react - delta)
	busy_anim = maxf(0.0, busy_anim - delta)
	# water
	var water_y: float = Game.city.water_level if Game.city else -100.0
	var submerged := global_position.y < water_y - 1.05
	if submerged and not swimming:
		swimming = true
		Game.effects.splash(Vector3(global_position.x, water_y, global_position.z))
		velocity.y *= 0.2
	elif swimming and global_position.y > water_y - 0.6 and is_on_floor():
		swimming = false
	if down_timer > 0.0:
		down_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, delta * (4.0 if is_on_floor() else 0.5))
		velocity.z = move_toward(velocity.z, 0.0, delta * (4.0 if is_on_floor() else 0.5))
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if model:
			if down_timer < 1.5 and model.current_loco != "LayToIdle":
				model.play("LayToIdle")
		return
	if swimming:
		_physics_swim(delta, water_y)
	else:
		_physics_ground(delta)
	_update_anim(delta)
	_update_weapon_pivot()


func _physics_ground(delta: float) -> void:
	crouching = want_crouch and is_on_floor()
	var speed := JOG_SPEED
	var sprinting := false
	if crouching:
		speed = CROUCH_SPEED
	elif aiming:
		speed = AIM_SPEED
	elif want_walk:
		speed = WALK_SPEED
	elif want_sprint and stamina > 1.0:
		speed = SPRINT_SPEED
		sprinting = true
	if busy_anim > 0.0 or hit_react > 0.0:
		speed *= 0.2
	stamina = clampf(stamina + (-12.0 if sprinting and move_dir.length() > 0.2 else 18.0) * delta, 0.0, 100.0)
	var target := move_dir.limit_length(1.0) * speed
	var accel := 14.0 if is_on_floor() else 2.5
	velocity.x = move_toward(velocity.x, target.x, accel * delta * maxf(speed, 3.0))
	velocity.z = move_toward(velocity.z, target.z, accel * delta * maxf(speed, 3.0))
	if is_on_floor():
		if air_time > 0.5:
			var fall := fall_start_y - global_position.y
			if fall > 6.0:
				take_damage((fall - 6.0) * 9.0, null, Vector3.ZERO, Vector3.ZERO, "fall")
			if model and not dead:
				model.restart("Jump_Land", 1.6)
				busy_anim = 0.25
		air_time = 0.0
		fall_start_y = global_position.y
		if want_jump and busy_anim <= 0.0:
			velocity.y = JUMP_VELOCITY
			want_jump = false
			if model:
				model.restart("Jump_Start", 1.8)
	else:
		air_time += delta
		velocity.y -= GRAVITY * delta
		if velocity.y > 0.0:
			fall_start_y = maxf(fall_start_y, global_position.y)
		if parachute_in > 0.0:
			parachute_in -= delta
			if parachute_in <= 0.0:
				_open_chute()
		if _chute:
			# gliding under the canopy: slow descent, WASD steers
			velocity.y = maxf(velocity.y, -4.5)
			var glide := move_dir.limit_length(1.0) * 7.0
			velocity.x = move_toward(velocity.x, glide.x, delta * 6.0)
			velocity.z = move_toward(velocity.z, glide.z, delta * 6.0)
			fall_start_y = global_position.y
	if _chute and (is_on_floor() or swimming or dead):
		_close_chute()
	want_jump = false
	move_and_slide()
	# push rigid bodies / get hit by cars handled by vehicle
	# facing
	var face := Vector3.ZERO
	if aiming and aim_point != Vector3.ZERO:
		face = aim_point - global_position
	elif Vector2(velocity.x, velocity.z).length() > 0.4 and move_dir.length() > 0.1:
		face = Vector3(velocity.x, 0, velocity.z)
	elif face_target != Vector3.ZERO:
		face = face_target - global_position
	face.y = 0.0
	if face.length() > 0.05:
		var target_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * (18.0 if aiming else 9.0), 0.0, 1.0))
	# footsteps
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 1.0:
		_footstep_t -= delta * hs
		if _footstep_t <= 0.0:
			_footstep_t = 1.6
			if is_player or global_position.distance_squared_to(Game.player_pos()) < 400.0:
				Sfx.play_at("step", global_position, -18.0 if not is_player else -12.0, randf_range(0.85, 1.15))


func _physics_swim(delta: float, water_y: float) -> void:
	var target := move_dir.limit_length(1.0) * SWIM_SPEED * (1.5 if want_sprint else 1.0)
	velocity.x = move_toward(velocity.x, target.x, 6.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 6.0 * delta)
	var target_y := water_y - 1.35
	velocity.y = (target_y - global_position.y) * 3.0
	move_and_slide()
	if move_dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), delta * 5.0)
	aiming = false


func _physics_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -30.0:
		velocity = Vector3.ZERO
	if is_on_floor() and velocity.length() < 0.2 and Time.get_ticks_msec() / 1000.0 - death_time > 3.0:
		_rest = not is_player


func _physics_in_vehicle(_delta: float) -> void:
	if not is_instance_valid(vehicle):
		vehicle = null
		return
	global_transform = vehicle.get_seat_transform(seat)


func _update_anim(_delta: float) -> void:
	if model == null:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if swimming:
		model.play("Swim_Fwd" if hs > 0.5 else "Swim_Idle")
		model.upper("")
		return
	if busy_anim > 0.0 or hit_react > 0.0:
		return
	if not is_on_floor() and air_time > 0.15:
		if model.current_loco != "Jump_Start" or model.loco_time_left() < 0.1:
			model.play("Jump")
	elif crouching:
		model.play("Crouch_Fwd" if hs > 0.3 else "Crouch_Idle", maxf(hs / 1.4, 0.6) if hs > 0.3 else 1.0)
	elif hs > 1.2 and aiming and Vector2(velocity.x, velocity.z).dot(Vector2(-global_basis.z.x, -global_basis.z.z)) < -0.5 * hs:
		# backing away while aiming
		model.play("Run_Back", clampf(hs / 3.0, 0.6, 1.4))
	elif hs > 5.6:
		model.play("Sprint", hs / 6.8)
	elif hs > 2.6:
		if current_def().get("hold", "") == "rifle":
			model.play("Rifle_Run", hs / 2.9)
		else:
			model.play("Jog_Fwd", hs / 3.4)
	elif hs > 0.35:
		model.play("Walk", hs / 1.4)
	else:
		if model.current_loco in ["Jump_Land", "LayToIdle"] and model.loco_time_left() > 0.1:
			pass
		elif model.current_loco in ["Idle_Talking", "Idle_TalkingPhone", "Idle_FoldArms", "Dance", "Sitting_Idle", "Push", "Fixing_Kneeling",
				"Point", "Kneel", "CPR", "CPR_Recv", "Stand_Up", "Idle_No", "Yes"]:
			pass
		else:
			model.play("Idle")
	# upper body
	var d := current_def()
	var t: String = d.get("type", "melee")
	if reload_left > 0.0:
		model.upper("Pistol_Reload")
	elif aiming and t == "gun" and d.get("hold", "") == "rifle":
		# two-handed shouldered rifle (mocap)
		model.upper("Rifle_Fire")
	elif aiming and t in ["gun", "launcher", "throw"]:
		model.upper("Aim")
		var to := aim_point - eye_position()
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		model.set_aim_pitch(pitch / (PI * 0.35))
	elif t in ["gun", "launcher"] and not model.current_upper in ["Pistol_Reload"]:
		if model.current_upper in ["Punch_Jab", "Punch_Cross", "OverhandThrow"] and model.upper_time_left() > 0.05:
			pass
		elif fire_cd > 0.0:
			pass
		else:
			model.upper("Pistol_Idle")
	elif model.current_upper in ["Punch_Jab", "Punch_Cross", "OverhandThrow", "Pistol_Reload"]:
		if model.upper_time_left() <= 0.05:
			model.upper("")
	elif model.current_upper != "":
		model.upper("")


func _update_weapon_pivot() -> void:
	if _weapon_model == null or _weapon_pivot == null:
		return
	var hand := _weapon_attach.global_position
	var d := current_def()
	var dir: Vector3
	if d.get("type", "") == "melee":
		if d.get("hold", "") == "bat":
			# resting on the shoulder, swung flat
			dir = (-global_basis.z if fire_cd > 0.15 else Vector3.UP * 0.85 + global_basis.z * 0.45).normalized()
		else:
			dir = (-global_basis.z * 0.7 + Vector3.DOWN * (0.15 if fire_cd > 0.0 else 0.7)).normalized()
	elif (aiming or fire_cd > 0.0) and aim_point != Vector3.ZERO:
		dir = (aim_point - hand).normalized()
	else:
		dir = (-global_basis.z * 0.5 + Vector3.DOWN * 0.85).normalized()
		if d.get("hold", "pistol") == "rifle":
			dir = (-global_basis.z * 0.8 + Vector3.DOWN * 0.5 + global_basis.x * -0.3).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else global_basis.z
	var b := Basis.looking_at(dir, up)
	if recoil > 0.0:
		b = b.rotated(b.x, recoil * 0.05)
	_weapon_pivot.global_basis = b
	if d.get("shoulder", false) and (aiming or fire_cd > 0.0):
		_weapon_pivot.global_position = hand + Vector3.UP * 0.18
	else:
		_weapon_pivot.position = Vector3.ZERO




# --------------------------------------------------------------- parachute
func _open_chute() -> void:
	if _chute or dead or is_on_floor():
		return
	_chute = Node3D.new()
	_chute.name = "Parachute"
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.2
	sm.height = 1.8
	sm.is_hemisphere = true
	sm.radial_segments = 16
	sm.rings = 4
	canopy.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color(0.95, 0.35, 0.6), Color(0.1, 0.65, 0.75), Color(0.98, 0.7, 0.15)][Game.rng.randi() % 3]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = mat
	canopy.position = Vector3(0, 5.2, 0)
	canopy.scale = Vector3(1.0, 0.6, 0.75)
	_chute.add_child(canopy)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.9, 0.9, 0.9)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cord := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.015
			cm.height = 4.0
			cord.mesh = cm
			cord.material_override = cord_mat
			var top := Vector3(sx * 2.4, 5.2, sz * 1.7)
			var bottom := Vector3(sx * 0.2, 1.5, sz * 0.1)
			cord.position = (top + bottom) * 0.5
			var dirv := (top - bottom).normalized()
			cord.basis = Basis(Quaternion(Vector3.UP, dirv))
			_chute.add_child(cord)
	add_child(_chute)
	velocity.y = maxf(velocity.y, -8.0)
	Sfx.play_at("swing", global_position, 0.0, 0.5)


func _close_chute() -> void:
	if _chute:
		_chute.queue_free()
		_chute = null
	parachute_in = 0.0
