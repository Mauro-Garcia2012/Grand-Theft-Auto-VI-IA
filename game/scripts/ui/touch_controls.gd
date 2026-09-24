class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (GTA mobile style):
## - floating joystick on the left half (push it to the edge to run)
## - drag anywhere on the right half to move the camera (also while holding FIRE or AIM)
## - buttons on the right that change on foot / in a car / in a helicopter or plane
## Buttons feed the same input actions as the keyboard (InputEventAction), so the game code is shared.
## Layout is in the 1600x900 HUD space (the window scales it, see Game.mobile).

const JOY_RADIUS := 105.0
const LOOK_SENS := 1.25

## Button: [action, label, radius, offset from the bottom-right corner (or top centre when "top")]
const FOOT := [
	["fire", "DISPARAR", 80.0, Vector2(-150, -165)],
	["aim", "APUNTAR", 54.0, Vector2(-335, -95)],
	["jump", "SALTAR", 50.0, Vector2(-320, -260)],
	["crouch", "AGACHAR", 40.0, Vector2(-120, -355)],
	["enter_vehicle", "F\nCOCHE", 46.0, Vector2(-240, -400)],
	["interact", "E\nUSAR", 42.0, Vector2(-420, -385)],
	["reload", "R\nRECARGAR", 40.0, Vector2(-480, -215)],
	["weapon_next", "ARMA ▸", 42.0, Vector2(-510, -85)],
	["grenade", "G\nGRANADA", 38.0, Vector2(-80, -500)],
]
const CAR := [
	["fire", "DISPARAR", 64.0, Vector2(-140, -300)],
	["aim", "APUNTAR", 46.0, Vector2(-300, -350)],
	["handbrake", "FRENO\nMANO", 62.0, Vector2(-150, -120)],
	["horn", "CLAXON", 42.0, Vector2(-330, -110)],
	["enter_vehicle", "F\nSALIR", 44.0, Vector2(-80, -450)],
	["siren", "SIRENA", 40.0, Vector2(-470, -110)],
	["radio", "RADIO", 38.0, Vector2(-450, -250)],
	["camera_view", "VISTA", 36.0, Vector2(-240, -470)],
]
const HELI := [
	["jump", "▲\nSUBIR", 62.0, Vector2(-150, -300)],
	["crouch", "▼\nBAJAR", 62.0, Vector2(-150, -140)],
	["enter_vehicle", "F\nSALTAR", 44.0, Vector2(-330, -120)],
	["camera_view", "VISTA", 36.0, Vector2(-330, -270)],
]
const PLANE := [
	["handbrake", "FRENOS", 56.0, Vector2(-150, -130)],
	["enter_vehicle", "F\nSALTAR", 46.0, Vector2(-330, -120)],
	["camera_view", "VISTA", 36.0, Vector2(-310, -270)],
]
const TOP := [
	["pause", "II", 30.0, Vector2(-190, 48)],
	["map", "MAPA", 30.0, Vector2(-120, 48)],
	["switch_char", "Z\nCAMBIAR", 30.0, Vector2(-50, 48)],
	["cheat", "T\nTRUCOS", 30.0, Vector2(20, 48)],
	["camera_view", "VISTA", 30.0, Vector2(90, 48)],
]
## Buttons whose finger can also be dragged to look around.
const DRAG_LOOK := ["fire", "aim"]
## Toggle buttons (tap on / tap off).
const TOGGLES := ["aim"]

var active := true
var _pad: Control
var _font: Font
var _buttons: Array = []        # [action, label, radius, centre]
var _held := {}                 # finger index -> action
var _joy_finger := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
var _toggled := {}              # action -> bool
var _mode := ""
var _hud_moved := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_pad = Control.new()
	_pad.name = "Pad"
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	get_tree().quit_on_go_back = false
	get_viewport().size_changed.connect(func(): _mode = "")
	if not Game.mobile:
		# trying the touch layout on a PC: the mouse acts as a finger
		Input.emulate_touch_from_mouse = true


func _playing() -> bool:
	return not Game.paused and not get_tree().paused and Game.player != null and is_instance_valid(Game.player)


func _process(_delta: float) -> void:
	var playing := _playing()
	visible = playing and active
	# menus (pause, shop, map) are used with the finger as a mouse; in game the touch is ours
	Input.emulate_mouse_from_touch = not playing
	if not playing:
		if not _held.is_empty() or _joy_finger >= 0 or _look_finger >= 0:
			_release_all()
		return
	if not _hud_moved:
		_move_hud()
	var mode := _current_mode()
	if mode != _mode:
		_mode = mode
		_release_all()
		_layout()
	_update_joystick()
	_pad.queue_redraw()


func _current_mode() -> String:
	var p: Humanoid = Game.player
	if p.vehicle == null:
		return "foot"
	if p.vehicle is Helicopter:
		return "heli"
	if p.vehicle is Aircraft:
		return "plane"
	return "car"


func _layout() -> void:
	var size := _pad.size
	var br := size
	_buttons.clear()
	var set: Array = {"foot": FOOT, "car": CAR, "heli": HELI, "plane": PLANE}[_mode]
	for b in set:
		_buttons.append([b[0], b[1], b[2], br + b[3]])
	for b in TOP:
		if b[0] == "camera_view" and _mode != "foot":
			continue
		_buttons.append([b[0], b[1], b[2], Vector2(size.x * 0.5, 0) + b[3]])


func _visible_button(b: Array) -> bool:
	var p: Humanoid = Game.player
	match b[0]:
		"grenade":
			return p.has_weapon("grenade")
		"siren":
			return p.vehicle != null and "siren_on" in p.vehicle and p.vehicle.def.get("siren", false)
		"fire", "aim":
			if p.vehicle:
				var d := p.current_def()
				return d.get("hold", "") == "pistol" or (p.vehicle is Vehicle and p.vehicle.turret != null)
	return true


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()


func _touch_down(i: int, pos: Vector2) -> void:
	for b in _buttons:
		if not _visible_button(b):
			continue
		if pos.distance_to(b[3]) <= b[2] * 1.15:
			var a: String = b[0]
			_held[i] = a
			if a in TOGGLES:
				_toggled[a] = not _toggled.get(a, false)
				_send(a, _toggled[a])
			else:
				_send(a, true)
			if a in DRAG_LOOK:
				_look_last = pos
			return
	var size := _pad.size
	if pos.x < size.x * 0.45 and pos.y > size.y * 0.22 and _joy_finger < 0:
		_joy_finger = i
		_joy_origin = pos
		_joy_pos = pos
	elif _look_finger < 0:
		_look_finger = i
		_look_last = pos


func _touch_up(i: int) -> void:
	if _held.has(i):
		var a: String = _held[i]
		_held.erase(i)
		if not a in TOGGLES:
			_send(a, false)
	if i == _joy_finger:
		_joy_finger = -1
		_joy_pos = _joy_origin
	if i == _look_finger:
		_look_finger = -1


func _touch_drag(i: int, pos: Vector2, rel: Vector2) -> void:
	if i == _joy_finger:
		_joy_pos = pos
	elif i == _look_finger or (_held.has(i) and _held[i] in DRAG_LOOK):
		_look(rel)


func _look(rel: Vector2) -> void:
	if Game.camera_rig:
		Game.camera_rig.mouse_look(rel * LOOK_SENS)


func _update_joystick() -> void:
	var v := Vector2.ZERO
	if _joy_finger >= 0:
		v = (_joy_pos - _joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			# drag the base along so the stick never gets "stuck" at the rim
			_joy_origin = _joy_pos - v.normalized() * JOY_RADIUS
			v = v.normalized()
	_axis("move_left", maxf(-v.x, 0.0))
	_axis("move_right", maxf(v.x, 0.0))
	_axis("move_forward", maxf(-v.y, 0.0))
	_axis("move_back", maxf(v.y, 0.0))
	# pushing the stick to the rim runs (on foot)
	var run := _mode == "foot" and v.length() > 0.92
	if run != Input.is_action_pressed("sprint"):
		if run:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")


func _axis(a: String, s: float) -> void:
	if s > 0.05:
		Input.action_press(a, s)
	elif Input.is_action_pressed(a):
		Input.action_release(a)


## Presses/releases an action like a key would: updates Input and sends the event to the scene.
func _send(a: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for i in _held:
		if not _held[i] in TOGGLES:
			_send(_held[i], false)
	_held.clear()
	for a in _toggled:
		if _toggled[a]:
			_send(a, false)
	_toggled.clear()
	_joy_finger = -1
	_look_finger = -1
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


## Moves the HUD texts that sit where the buttons are (bottom right) to the top centre.
func _move_hud() -> void:
	var hud = Game.hud
	if hud == null:
		return
	_hud_moved = true
	var moves := {"_zone_label": [Vector2(-395, 100), Vector2(790, 60)], "_veh_label": [Vector2(-395, 150), Vector2(790, 50)],
		"_speed_label": [Vector2(-220, 196), Vector2(440, 40)], "_fuel_bar": [Vector2(-80, 238), Vector2(160, 8)]}
	for k in moves:
		var c = hud.get(k)
		if c is Control:
			UI.place(c, Control.PRESET_CENTER_TOP, moves[k][0], moves[k][1])
			if c is Label:
				(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pr = hud.get("_prompt")
	if pr is Control:
		UI.place(pr, Control.PRESET_CENTER_BOTTOM, Vector2(-600, -110), Vector2(1000, 40))


# ------------------------------------------------------------------ drawing
func _draw_pad() -> void:
	if not _playing():
		return
	# joystick
	var base := _joy_origin if _joy_finger >= 0 else Vector2(420, _pad.size.y - 190)
	var knob := _joy_pos if _joy_finger >= 0 else base
	_pad.draw_circle(base, JOY_RADIUS, Color(0, 0, 0, 0.22))
	_pad.draw_arc(base, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	_pad.draw_circle(knob, 44.0, Color(1, 1, 1, 0.35 if _joy_finger >= 0 else 0.18))
	# buttons
	var held_actions := _held.values()
	for b in _buttons:
		if not _visible_button(b):
			continue
		var a: String = b[0]
		var on: bool = a in held_actions or _toggled.get(a, false)
		var c: Vector2 = b[3]
		var r: float = b[2]
		var fill := Color(1.0, 0.35, 0.6, 0.55) if on else Color(0.05, 0.05, 0.08, 0.38)
		if a == "fire" and not on:
			fill = Color(0.55, 0.05, 0.08, 0.42)
		_pad.draw_circle(c, r, fill)
		_pad.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.7), 2.5, true)
		var lines: PackedStringArray = (b[1] as String).split("\n")
		var fs := int(clampf(r * 0.36, 13.0, 24.0))
		var lh := fs + 2.0
		var y0 := c.y - (lines.size() - 1) * lh * 0.5 + fs * 0.35
		for li in lines.size():
			var s: String = lines[li]
			var sz := fs if li == 0 or lines.size() == 1 else int(fs * 0.75)
			var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			_pad.draw_string_outline(_font, Vector2(c.x - w * 0.5, y0 + li * lh), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.6))
			_pad.draw_string(_font, Vector2(c.x - w * 0.5, y0 + li * lh), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, 0.95))


func _notification(what: int) -> void:
	# Android back button: pause menu / close menus instead of quitting the game
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_send("pause", true)
		_send("pause", false)
