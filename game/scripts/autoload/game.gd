extends Node
## Global game state: player, money, wanted level, time, helpers.

signal money_changed(value: int)
signal wanted_changed(stars: int)
signal notify(text: String, seconds: float)
signal big_message(title: String, subtitle: String, color: Color)
signal player_changed(p)

const LAYER_WORLD := 1
const LAYER_VEHICLE := 2
const LAYER_CHAR := 4
const LAYER_PROJECTILE := 8
const LAYER_TRIGGER := 16
const MASK_BULLET := LAYER_WORLD | LAYER_VEHICLE | LAYER_CHAR

var player: Humanoid
var protagonists: Array = []   # [Jason, Lucia]
var active_protagonist := 0
var world: Node3D
var city: Node          # CityMap
var hud: Control
var camera_rig: Node3D
var population: Node
var wanted: Node
var sky: Node
var effects: Node3D
var rng := RandomNumberGenerator.new()

var money := 5000:
	set(v):
		money = max(0, v)
		money_changed.emit(money)

var paused := false
var cheats_used := 0
var god_mode := false
var infinite_ammo := false
var stats := {"kills": 0, "cops_killed": 0, "cars_stolen": 0, "distance": 0.0, "busted": 0, "wasted": 0, "robberies": 0}
var settings := {"mouse_sens": 0.25, "invert_y": false, "fov": 70.0, "volume": 0.8, "shadows": 2, "view_distance": 1.0, "show_fps": false}


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func msg(text: String, seconds := 3.0) -> void:
	notify.emit(text, seconds)


func add_money(v: int) -> void:
	money += v


func is_player(n) -> bool:
	return n != null and n == player


func player_pos() -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.ZERO
	if player.vehicle:
		return player.vehicle.global_position
	return player.global_position


func report_crime(pos: Vector3, severity: float, kind := "") -> void:
	if wanted:
		wanted.report_crime(pos, severity, kind)


func get_wanted() -> int:
	return wanted.stars if wanted else 0


func camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var f := FileAccess.open("user://settings.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				settings[k] = d[k]
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(settings.volume, 0.0, 1.0)))


func save_game() -> bool:
	if player == null:
		return false
	var p = player
	var data := {
		"money": money,
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z],
		"protagonist": active_protagonist,
		"weapons": p.weapons,
		"health": p.health,
		"armor": p.armor,
		"time": sky.time_of_day if sky else 12.0,
		"stats": stats,
	}
	var f := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	msg("Partida guardada")
	return true


func has_save() -> bool:
	return FileAccess.file_exists("user://savegame.json")


func load_game() -> bool:
	if not has_save() or player == null:
		return false
	var f := FileAccess.open("user://savegame.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	money = int(d.get("money", 5000))
	var pos: Array = d.get("pos", [0, 2, 0])
	if player.vehicle:
		player.exit_vehicle(true)
	player.global_position = Vector3(pos[0], pos[1] + 0.5, pos[2])
	player.velocity = Vector3.ZERO
	player.weapons = d.get("weapons", player.weapons)
	for w in player.weapons:
		for k in ["clip", "ammo"]:
			w[k] = int(w.get(k, 0))
	player.select_weapon(0)
	player.health = float(d.get("health", 100))
	player.armor = float(d.get("armor", 0))
	if sky:
		sky.time_of_day = float(d.get("time", 12.0))
	var st = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	if wanted:
		wanted.clear()
	msg("Partida cargada")
	return true
