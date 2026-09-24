class_name VehicleDB
extends RefCounted
## Vehicle catalogue: realistic models only. Sketchfab "Generic Passenger Car Pack" and "Generic
## Civil Service Vehicles Pack" and the boat set (as prepared by the Motorpool project), detailed real
## cars from fan collections (see assets/licenses), aircraft.

const B := "res://assets/vehicles/brand/"
const P := "res://assets/vehicles/pack/"
const R := "res://assets/vehicles/boats_real/"
const A := "res://assets/aircraft/"

# front: "-z" means the model's nose points to -Z (Godot forward); "+z" needs a 180° turn.
const CARS := {
	# ---- Sketchfab "Generic Passenger Car Pack" (nose -Z, wheels fitted by tools: see credits)
	"p_compact": {"name": "Compacto Brio", "src": P + "compact.glb", "front": "-z", "length": 3.67, "mass": 1100, "accel": 7.0, "top": 44, "grip": 1.0, "paint": false, "kind": "civil"},
	"p_coupe": {"name": "Coupé Sentinel", "src": P + "coupe.glb", "front": "-z", "length": 4.77, "mass": 1400, "accel": 8.5, "top": 52, "grip": 1.05, "paint": false, "kind": "civil"},
	"p_hatchback": {"name": "Hatch Blista", "src": P + "hatchback.glb", "front": "-z", "length": 4.45, "mass": 1250, "accel": 8.0, "top": 50, "grip": 1.05, "paint": false, "kind": "civil"},
	"p_minivan": {"name": "Minivan Moonbeam", "src": P + "minivan.glb", "front": "-z", "length": 5.19, "mass": 1900, "accel": 6.0, "top": 42, "grip": 0.95, "paint": false, "kind": "civil"},
	"p_offroad": {"name": "Todoterreno Mesa", "src": P + "offroad.glb", "front": "-z", "length": 4.44, "mass": 1900, "accel": 7.0, "top": 44, "grip": 1.0, "paint": false, "kind": "civil"},
	"p_pickup": {"name": "Pickup Bobcat", "src": P + "pickup.glb", "front": "-z", "length": 5.83, "mass": 2100, "accel": 7.0, "top": 46, "grip": 0.95, "paint": false, "kind": "civil"},
	"p_sedan": {"name": "Sedán Primo", "src": P + "sedan.glb", "front": "-z", "length": 4.9, "mass": 1450, "accel": 7.5, "top": 48, "grip": 1.0, "paint": false, "kind": "civil"},
	"p_sport": {"name": "Deportivo Turismo", "src": P + "sport.glb", "front": "-z", "length": 4.4, "mass": 1250, "accel": 12.5, "top": 72, "grip": 1.3, "paint": false, "kind": "super"},
	"p_suv": {"name": "SUV Granger", "src": P + "suv.glb", "front": "-z", "length": 5.19, "mass": 2300, "accel": 7.0, "top": 46, "grip": 0.95, "paint": false, "kind": "civil"},
	"p_wagon": {"name": "Familiar Regina", "src": P + "wagon.glb", "front": "-z", "length": 4.93, "mass": 1500, "accel": 7.0, "top": 46, "grip": 1.0, "paint": false, "kind": "civil"},
	# ---- Sketchfab "Generic Civil Service Vehicles Pack"
	"p_police": {"name": "Patrulla VCPD", "src": P + "police_sedan.glb", "front": "-z", "length": 5.4, "mass": 1700, "accel": 10.5, "top": 60, "grip": 1.15, "paint": false, "kind": "police", "siren": true},
	"p_taxi": {"name": "Taxi Vice City", "src": P + "taxi.glb", "front": "-z", "length": 5.32, "mass": 1600, "accel": 7.5, "top": 48, "grip": 1.0, "paint": false, "kind": "taxi"},
	"p_ambulance": {"name": "Ambulancia", "src": P + "ambulance.glb", "front": "-z", "length": 7.2, "mass": 3400, "accel": 6.5, "top": 44, "grip": 0.95, "paint": false, "kind": "emergency", "siren": true},
	"p_firetruck": {"name": "Camión de bomberos", "src": P + "fire_truck.glb", "front": "-z", "length": 8.73, "mass": 9000, "accel": 4.2, "top": 36, "grip": 0.85, "paint": false, "kind": "emergency", "siren": true},
	"p_bus": {"name": "Autobús VC Transit", "src": P + "citybus.glb", "front": "-z", "length": 10.4, "mass": 11000, "accel": 3.8, "top": 30, "grip": 0.85, "paint": false, "kind": "work"},
	"p_schoolbus": {"name": "Autobús escolar", "src": P + "school_bus.glb", "front": "-z", "length": 8.28, "mass": 9500, "accel": 3.8, "top": 30, "grip": 0.85, "paint": false, "kind": "work"},
	"p_garbage": {"name": "Camión de basura", "src": P + "garbage_truck.glb", "front": "-z", "length": 8.0, "mass": 9000, "accel": 3.5, "top": 28, "grip": 0.85, "paint": false, "kind": "work"},
	"p_towtruck": {"name": "Grúa", "src": P + "towtruck.glb", "front": "-z", "length": 7.26, "mass": 6000, "accel": 4.0, "top": 34, "grip": 0.9, "paint": false, "kind": "work"},
	"p_postvan": {"name": "Furgoneta de correos", "src": P + "postvan.glb", "front": "-z", "length": 5.59, "mass": 2600, "accel": 5.5, "top": 40, "grip": 0.9, "paint": false, "kind": "work"},
	"p_roadservice": {"name": "Asistencia en carretera", "src": P + "rdservtruck.glb", "front": "-z", "length": 5.57, "mass": 2800, "accel": 6.0, "top": 42, "grip": 0.9, "paint": false, "kind": "work", "siren": true},
	# ---- detailed real cars (fan uploads; see assets/licenses)
	"b_m5": {"name": "BMW M5 CS", "src": B + "bmw_m5.glb", "front": "+z", "length": 4.98, "mass": 1800, "accel": 12.5, "top": 74, "grip": 1.3, "paint": true, "paint_mats": ["bm_carpaint_max1"], "kind": "sport"},
	"b_m8": {"name": "BMW M8 Competition", "src": B + "bmw_m8.glb", "front": "+z", "length": 4.87, "mass": 1850, "accel": 13.0, "top": 76, "grip": 1.3, "paint": true, "paint_mats": ["bbmw_m8rewardrecycled_2020paint_material1"], "kind": "sport"},
	"b_challenger": {"name": "Dodge Challenger R/T", "src": B + "challenger.glb", "front": "+z", "length": 5.02, "mass": 1900, "accel": 12.0, "top": 68, "grip": 1.1, "paint": true, "paint_mats": ["ddodge_challengerrtshakerf7_2015paint_material1"], "kind": "sport"},
	"b_roadster": {"name": "Tesla Roadster", "src": B + "roadster.glb", "front": "+z", "length": 4.6, "mass": 1700, "accel": 15.0, "top": 80, "grip": 1.4, "paint": true, "paint_mats": ["car_main_paint"], "kind": "super"},
	"b_m3gtr": {"name": "BMW M3 GTR", "src": B + "bmw.glb", "front": "-z", "length": 4.5, "mass": 1350, "accel": 14.0, "top": 78, "grip": 1.4, "paint": false, "kind": "super"},
	"b_camaro": {"name": "Chevrolet Camaro 1969", "src": B + "camaro.glb", "front": "-z", "length": 4.7, "mass": 1550, "accel": 11.5, "top": 66, "grip": 1.05, "paint": false, "kind": "sport"},
	"b_canyon": {"name": "GMC Canyon", "src": B + "canyon.glb", "front": "-z", "length": 5.4, "mass": 2100, "accel": 8.0, "top": 52, "grip": 1.0, "paint": false, "kind": "civil"},
	"b_hotrod": {"name": "Dodge Pickup 1947", "src": B + "dodge.glb", "front": "-z", "length": 4.9, "mass": 1800, "accel": 7.0, "top": 46, "grip": 0.95, "paint": false, "kind": "civil"},
	"b_porsche": {"name": "Porsche 911 GT3 R", "src": B + "porsche.glb", "front": "-z", "length": 4.6, "mass": 1250, "accel": 15.0, "top": 82, "grip": 1.5, "paint": false, "kind": "super"},
	"b_mclaren": {"name": "McLaren F1", "src": B + "mclaren.glb", "front": "-z", "length": 4.29, "mass": 1140, "accel": 16.0, "top": 86, "grip": 1.45, "paint": false, "kind": "super"},
	"b_ferrari": {"name": "Ferrari 599 GTB", "src": B + "ferrari599.glb", "front": "+z", "length": 4.66, "mass": 1600, "accel": 15.0, "top": 84, "grip": 1.4, "paint": false, "kind": "super"},
	"b_monster": {"name": "Monster Truck", "src": B + "monster.glb", "front": "-z", "length": 5.2, "mass": 3200, "accel": 9.5, "top": 50, "grip": 1.15, "paint": false, "kind": "civil"},
	"b_f1": {"name": "Mercedes-AMG F1 W14", "src": B + "w14.glb", "front": "-z", "length": 5.63, "mass": 800, "accel": 21.0, "top": 95, "grip": 1.9, "paint": false, "kind": "super"},
}

# Boats (Motorpool boat set, waterline at the model's y = 0, bow towards -Z)
const BOATS := {
	"yacht": {"name": "Yate Flybridge", "src": R + "yacht.glb", "length": 16.6, "mass": 12000, "accel": 4.5, "top": 22, "waterline": true},
	"cruiser": {"name": "Lancha Cabinada", "src": R + "cruiser.glb", "length": 8.6, "mass": 3000, "accel": 7.5, "top": 26, "waterline": true},
	"rescue": {"name": "Lancha de rescate", "src": R + "tug.glb", "length": 11.2, "mass": 4500, "accel": 9.0, "top": 32, "waterline": true},
	"sailboat": {"name": "Velero", "src": R + "sail.glb", "length": 10.2, "mass": 3500, "accel": 4.0, "top": 14, "waterline": true},
}

# Flyable aircraft (FlightGear-derived models via FlightAirMap-3dmodels, GPL; Cessna 172 "Plane" by
# osmosikum, CC BY 4.0; Rafale M via the FlightSim project). length = longest horizontal side
# (usually the wingspan); cruise/top in m/s; accel = full-power thrust per kg.
const PLANES := {
	"cessna": {"name": "Cessna 172", "src": A + "c172.glb", "front": "+z", "length": 11.0, "mass": 1100,
		"cruise": 52.0, "top": 68.0, "accel": 3.6, "pitch_rate": 1.0, "prop": "propelting", "wing_y": 0.55, "health": 1200.0},
	"jet": {"name": "Cessna Citation II", "src": A + "c550.glb", "front": "+z", "length": 15.9, "mass": 6500,
		"cruise": 88.0, "top": 125.0, "accel": 4.6, "pitch_rate": 0.8, "jet": true, "wing_y": 0.2, "health": 1800.0},
	"airliner": {"name": "Airbus A320", "src": A + "a320.glb", "front": "+x", "length": 37.6, "mass": 60000,
		"cruise": 92.0, "top": 145.0, "accel": 3.1, "pitch_rate": 0.55, "jet": true, "wing_y": 0.12, "health": 5000.0, "max_bank": 0.6},
	"fighter": {"name": "Dassault Rafale M", "src": A + "rafale-m.glb", "front": "+x", "length": 15.3, "mass": 12000,
		"cruise": 140.0, "top": 260.0, "accel": 9.0, "pitch_rate": 1.4, "jet": true, "wing_y": 0.2, "health": 2500.0, "max_bank": 1.3},
}

const PAINTS := [
	Color(0.95, 0.95, 0.95), Color(0.08, 0.08, 0.09), Color(0.6, 0.62, 0.65), Color(0.75, 0.1, 0.12),
	Color(0.1, 0.55, 0.6), Color(0.95, 0.4, 0.65), Color(0.95, 0.75, 0.1), Color(0.12, 0.25, 0.6),
	Color(0.3, 0.3, 0.32), Color(0.15, 0.45, 0.2), Color(0.95, 0.5, 0.15), Color(0.55, 0.2, 0.6),
	Color(0.2, 0.8, 0.85), Color(0.85, 0.85, 0.7),
]

const TRAFFIC_WEIGHTS := {
	"p_sedan": 9, "p_compact": 7, "p_hatchback": 7, "p_coupe": 6, "p_wagon": 5, "p_suv": 6, "p_minivan": 5,
	"p_offroad": 4, "p_pickup": 5, "p_taxi": 7, "p_sport": 2, "p_bus": 2, "p_schoolbus": 1, "p_garbage": 1,
	"p_postvan": 2, "p_towtruck": 1, "p_ambulance": 1, "p_roadservice": 1,
	"b_canyon": 2, "b_hotrod": 1, "b_camaro": 1, "b_m5": 1, "b_m8": 1, "b_challenger": 1, "b_roadster": 1,
	"b_m3gtr": 1, "b_porsche": 1, "b_mclaren": 1, "b_ferrari": 1,
}

static var _scene_cache := {}
static var _weights_total := 0


static func get_def(id: String) -> Dictionary:
	if CARS.has(id):
		return CARS[id]
	if PLANES.has(id):
		return PLANES[id]
	return BOATS.get(id, {})


static func random_traffic(rng: RandomNumberGenerator) -> String:
	if _weights_total == 0:
		for k in TRAFFIC_WEIGHTS:
			_weights_total += TRAFFIC_WEIGHTS[k]
	var r := rng.randi() % _weights_total
	for k in TRAFFIC_WEIGHTS:
		r -= TRAFFIC_WEIGHTS[k]
		if r < 0:
			return k
	return "p_sedan"


static func load_src(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


static func spawn(id: String, pos: Vector3, yaw := 0.0, paint := Color(-1, 0, 0)) -> Node3D:
	var v: Node3D
	if BOATS.has(id):
		v = Boat.new()
	elif PLANES.has(id):
		v = Aircraft.new()
	else:
		v = Vehicle.new()
	v.def_id = id
	v.paint = paint
	Game.world.add_child(v)
	v.global_position = pos
	v.rotation.y = yaw
	return v
