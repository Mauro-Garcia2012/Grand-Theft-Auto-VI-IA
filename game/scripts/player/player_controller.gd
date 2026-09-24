class_name PlayerController
extends Node
## Reads keyboard/mouse/gamepad input and drives the player's Humanoid (or its vehicle).

var h: Humanoid
var rig: CameraRig
var _fire_was := false
var _interact_cd := 0.0
var _flip_hold := 0.0


static func setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "walk": [KEY_ALT], "jump": [KEY_SPACE], "crouch": [KEY_C, KEY_CTRL],
		"enter_vehicle": [KEY_F, KEY_ENTER], "reload": [KEY_R], "interact": [KEY_E],
		"horn": [KEY_H], "siren": [KEY_Q], "lights": [KEY_L], "handbrake": [KEY_SPACE],
		"camera_view": [KEY_V], "map": [KEY_M], "pause": [KEY_ESCAPE, KEY_P], "switch_char": [KEY_Z], "cheat": [KEY_T],
		"weapon_next": [], "weapon_prev": [], "quick_save": [KEY_F5], "quick_load": [KEY_F9], "grenade": [KEY_G],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6], "slot_7": [KEY_7], "slot_8": [KEY_8],
		"radio": [KEY_N], "phone": [KEY_TAB], "look_behind": [KEY_B],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	# on phones the screen buttons fire and aim (a tap in a menu must not shoot)
	if not Game.touch:
		_mouse("fire", MOUSE_BUTTON_LEFT)
		_mouse("aim", MOUSE_BUTTON_RIGHT)
		_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
		_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	# gamepad
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_btn("jump", JOY_BUTTON_A)
	_joy_btn("handbrake", JOY_BUTTON_A)
	_joy_btn("sprint", JOY_BUTTON_B)
	_joy_btn("enter_vehicle", JOY_BUTTON_Y)
	_joy_btn("reload", JOY_BUTTON_X)
	_joy_btn("crouch", JOY_BUTTON_LEFT_STICK)
	_joy_btn("weapon_next", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_btn("weapon_prev", JOY_BUTTON_LEFT_SHOULDER)
	_joy_btn("pause", JOY_BUTTON_START)
	_joy_btn("map", JOY_BUTTON_BACK)
	_joy_btn("horn", JOY_BUTTON_RIGHT_STICK)
	_joy_btn("switch_char", JOY_BUTTON_DPAD_DOWN)
	_joy_btn("interact", JOY_BUTTON_DPAD_RIGHT)
	_joy_btn("camera_view", JOY_BUTTON_DPAD_UP)
	for a in ["fire", "aim"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)


static func _mouse(a: String, b: MouseButton) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)


static func _joy_axis(a: String, axis: JoyAxis, v: float) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.2)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	InputMap.action_add_event(a, e)


static func _joy_btn(a: String, b: JoyButton) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)


func _ready() -> void:
	h = get_parent()
	process_physics_priority = -10


func _unhandled_input(event: InputEvent) -> void:
	if Game.paused or h == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rig.mouse_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if h.dead:
		return
	if event.is_action_pressed("weapon_next"):
		h.cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		h.cycle_weapon(-1)
	for i in 8:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			var id: String = WeaponDB.ORDER[i]
			for j in h.weapons.size():
				if h.weapons[j].id == id:
					h.select_weapon(j)
	if event.is_action_pressed("reload"):
		h.start_reload()
	if event.is_action_pressed("camera_view"):
		if h.vehicle:
			rig.vehicle_view = (rig.vehicle_view + 1) % 3
		else:
			rig.foot_view = (rig.foot_view + 1) % 2
	if h.vehicle:
		var v = h.vehicle
		if event.is_action_pressed("siren") and "siren_on" in v and v.def.get("siren", false):
			v.siren_on = not v.siren_on
		if event.is_action_pressed("lights") and "lights_on" in v:
			v.lights_on = not v.lights_on


func _physics_process(delta: float) -> void:
	if h == null or Game.paused:
		return
	_interact_cd = maxf(0.0, _interact_cd - delta)
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	rig.stick_look(rs, delta)
	if h.dead:
		h.move_dir = Vector3.ZERO
		h.trigger = false
		h.aiming = false
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if h.vehicle:
		_drive(delta, input)
	else:
		_on_foot(delta, input)
	if Input.is_action_just_pressed("enter_vehicle") and _interact_cd <= 0.0:
		_interact_cd = 0.6
		_toggle_vehicle()
	if Input.is_action_just_pressed("grenade") and h.has_weapon("grenade") and not h.vehicle:
		var prev := h.weapon_index
		for j in h.weapons.size():
			if h.weapons[j].id == "grenade":
				h.select_weapon(j)
				h.fire_cd = 0.0
				h.aim_point = rig.aim_point
				h.try_fire()
				if h.weapons.size() > prev:
					h.select_weapon(prev)
				break


func _on_foot(_delta: float, input: Vector2) -> void:
	var basis := rig.get_look_basis()
	var dir := basis * Vector3(input.x, 0, input.y)
	h.move_dir = dir.limit_length(1.0)
	h.want_sprint = Input.is_action_pressed("sprint")
	h.want_walk = Input.is_action_pressed("walk")
	if Input.is_action_just_pressed("jump"):
		h.want_jump = true
	if Input.is_action_just_pressed("crouch"):
		h.want_crouch = not h.want_crouch
	if h.want_sprint:
		h.want_crouch = false
	var d := h.current_def()
	var t: String = d.get("type", "melee")
	h.aiming = Input.is_action_pressed("aim") and t != "melee" and not h.swimming
	h.aim_point = rig.aim_point
	var fire := Input.is_action_pressed("fire")
	if fire and not h.swimming:
		var auto: bool = d.get("auto", false) or t == "melee"
		if auto or not _fire_was:
			if t != "melee" and t != "throw":
				# hip fire: turn to aim direction
				if not h.aiming:
					var to := rig.aim_point - h.global_position
					h.rotation.y = atan2(-to.x, -to.z)
			h.try_fire()
	_fire_was = fire


func _drive(delta: float, input: Vector2) -> void:
	var v = h.vehicle
	if h.seat != 0:
		h.move_dir = Vector3.ZERO
		return
	if v is Helicopter:
		# W/S forward/back, A/D strafe, Space/C climb/descend; the nose follows the camera
		v.throttle = -input.y
		v.steer_input = -input.x
		v.lift_input = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
		v.aim_dir = Basis(Vector3.UP, rig.yaw) * Vector3.FORWARD
		h.aiming = false
		return
	if v is Aircraft:
		# W/S power, A/D roll (nose wheel on the ground); the plane flies towards where the camera looks
		v.throttle = -input.y
		v.steer_input = -input.x
		v.handbrake = Input.is_action_pressed("handbrake")
		v.aim_dir = Basis.from_euler(Vector3(rig.pitch + 0.2, rig.yaw, 0.0)) * Vector3.FORWARD
		h.aiming = false
		return
	if v is Vehicle or v is Boat:
		v.throttle = -input.y
		v.steer_input = -input.x
		v.brake = 0.0
		v.handbrake = Input.is_action_pressed("handbrake")
		v.horn = Input.is_action_pressed("horn")
		if Input.is_action_pressed("enter_vehicle") and v is Vehicle:
			_flip_hold += delta
		else:
			_flip_hold = 0.0
	# tanks: the turret follows the camera, LMB fires the cannon
	if v is Vehicle and v.turret != null:
		v.aim_turret(rig.aim_point, delta)
		if Input.is_action_pressed("fire"):
			v.fire_cannon(rig.aim_point, h)
		h.aiming = false
		_fire_was = Input.is_action_pressed("fire")
		return
	# drive-by: aim with RMB and shoot sideways with pistol/smg
	var d := h.current_def()
	var can_driveby: bool = d.get("hold", "") == "pistol" or d.get("type", "") == "gun" and v is Boat
	h.aiming = Input.is_action_pressed("aim") and can_driveby
	h.aim_point = rig.aim_point
	if h.aiming and Input.is_action_pressed("fire"):
		var auto: bool = d.get("auto", false)
		if auto or not _fire_was:
			h.try_fire()
	_fire_was = Input.is_action_pressed("fire")


func _toggle_vehicle() -> void:
	if h.vehicle:
		var v = h.vehicle
		if v is Vehicle and v.global_basis.y.y < 0.3:
			v.flip_if_needed()
			return
		if v is Aircraft and v.airborne:
			# jump out: the parachute opens after a moment
			h.exit_vehicle(true)
			h.parachute_in = 1.0
			Game.msg("¡Paracaídas! Se abrirá enseguida · %s para planear" % ("joystick" if Game.touch else "WASD"), 3.0)
			return
		if v.linear_velocity.length() > 12.0:
			# bail out at speed
			h.exit_vehicle(true)
			h.knockdown(v.linear_velocity * 0.5 + Vector3.UP * 3.0)
			h.take_damage(10.0, null, Vector3.ZERO, Vector3.ZERO, "fall")
		else:
			h.exit_vehicle()
		return
	# find closest vehicle
	var best: Node = null
	var best_d := 6.0
	for v in get_tree().get_nodes_in_group("vehicles") + get_tree().get_nodes_in_group("boats"):
		if v.destroyed:
			continue
		var reach: float = v.body_size.z * 0.5 + 2.2 if "body_size" in v else 4.0
		var d: float = v.global_position.distance_to(h.global_position)
		if d < reach and d < best_d + reach:
			if best == null or d < best_d:
				best = v
				best_d = d
	if best:
		h.begin_enter(best)
