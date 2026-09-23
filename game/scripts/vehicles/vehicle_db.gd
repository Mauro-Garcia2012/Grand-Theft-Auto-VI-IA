class_name VehicleDB
extends RefCounted
## Vehicle catalogue. Models: Kenney "Car Kit" (CC0), Kenney "Racing Kit" motorcycle (CC0),
## Neill Bogie low-poly cars set (CC-BY 4.0), Kenney "Watercraft Pack" (CC0),
## Quaternius "Realistic Car Pack" / "Ultimate Vehicles" / "Tanks" (CC0).

const NB := "res://assets/vehicles/lowpoly_cars_set.glb"
const Q := "res://assets/q/"
const B := "res://assets/vehicles/brand/"

# front: "-z" means the model's nose points to -Z (Godot forward); "+z" needs a 180° turn.
const CARS := {
	# ---- Kenney Car Kit
	"sedan": {"name": "Leonida Sedan", "src": "res://assets/vehicles/sedan.glb", "front": "-z", "length": 4.7, "mass": 1400, "accel": 7.5, "top": 46, "grip": 1.0, "paint": true, "kind": "civil"},
	"sedanSports": {"name": "Vice GT", "src": "res://assets/vehicles/sedanSports.glb", "front": "-z", "length": 4.6, "mass": 1350, "accel": 10.0, "top": 60, "grip": 1.15, "paint": true, "kind": "sport"},
	"hatchbackSports": {"name": "Hatch RS", "src": "res://assets/vehicles/hatchbackSports.glb", "front": "-z", "length": 4.2, "mass": 1200, "accel": 9.0, "top": 52, "grip": 1.1, "paint": true, "kind": "sport"},
	"suv": {"name": "Everglade SUV", "src": "res://assets/vehicles/suv.glb", "front": "-z", "length": 4.9, "mass": 2000, "accel": 6.5, "top": 44, "grip": 0.95, "paint": true, "kind": "civil"},
	"suvLuxury": {"name": "Starfish Luxe", "src": "res://assets/vehicles/suvLuxury.glb", "front": "-z", "length": 5.0, "mass": 2200, "accel": 7.5, "top": 48, "grip": 1.0, "paint": true, "kind": "civil"},
	"taxi": {"name": "Taxi Vice City", "src": "res://assets/vehicles/taxi.glb", "front": "-z", "length": 4.7, "mass": 1450, "accel": 7.0, "top": 45, "grip": 1.0, "paint": false, "kind": "taxi"},
	"police": {"name": "Patrulla VCPD", "src": "res://assets/vehicles/police.glb", "front": "-z", "length": 4.8, "mass": 1600, "accel": 10.0, "top": 58, "grip": 1.15, "paint": false, "kind": "police", "siren": true},
	"van": {"name": "Furgoneta", "src": "res://assets/vehicles/van.glb", "front": "-z", "length": 5.2, "mass": 2400, "accel": 5.5, "top": 38, "grip": 0.9, "paint": true, "kind": "work"},
	"delivery": {"name": "Reparto", "src": "res://assets/vehicles/delivery.glb", "front": "-z", "length": 6.0, "mass": 3500, "accel": 4.5, "top": 34, "grip": 0.85, "paint": false, "kind": "work"},
	"deliveryFlat": {"name": "Plataforma", "src": "res://assets/vehicles/deliveryFlat.glb", "front": "-z", "length": 6.0, "mass": 3300, "accel": 4.5, "top": 34, "grip": 0.85, "paint": false, "kind": "work"},
	"truck": {"name": "Camión", "src": "res://assets/vehicles/truck.glb", "front": "-z", "length": 7.5, "mass": 6000, "accel": 3.8, "top": 32, "grip": 0.85, "paint": false, "kind": "work"},
	"truckFlat": {"name": "Camión plataforma", "src": "res://assets/vehicles/truckFlat.glb", "front": "-z", "length": 7.5, "mass": 5500, "accel": 3.8, "top": 32, "grip": 0.85, "paint": false, "kind": "work"},
	"garbageTruck": {"name": "Basurero", "src": "res://assets/vehicles/garbageTruck.glb", "front": "-z", "length": 7.2, "mass": 8000, "accel": 3.5, "top": 28, "grip": 0.85, "paint": false, "kind": "work"},
	"ambulance": {"name": "Ambulancia", "src": "res://assets/vehicles/ambulance.glb", "front": "-z", "length": 6.2, "mass": 3200, "accel": 6.5, "top": 44, "grip": 0.95, "paint": false, "kind": "emergency", "siren": true},
	"firetruck": {"name": "Bomberos", "src": "res://assets/vehicles/firetruck.glb", "front": "-z", "length": 8.5, "mass": 9000, "accel": 4.0, "top": 34, "grip": 0.85, "paint": false, "kind": "emergency", "siren": true},
	"race": {"name": "Speedster", "src": "res://assets/vehicles/race.glb", "front": "-z", "length": 4.6, "mass": 1100, "accel": 13.0, "top": 72, "grip": 1.35, "paint": true, "kind": "super"},
	"raceFuture": {"name": "Prototipo X", "src": "res://assets/vehicles/raceFuture.glb", "front": "-z", "length": 4.6, "mass": 1050, "accel": 14.0, "top": 78, "grip": 1.4, "paint": true, "kind": "super"},
	"tractor": {"name": "Tractor", "src": "res://assets/vehicles/tractor.glb", "front": "-z", "length": 4.0, "mass": 3000, "accel": 3.5, "top": 18, "grip": 1.1, "paint": false, "kind": "work"},
	"tractorShovel": {"name": "Excavadora", "src": "res://assets/vehicles/tractorShovel.glb", "front": "-z", "length": 5.0, "mass": 5000, "accel": 3.0, "top": 15, "grip": 1.1, "paint": false, "kind": "work"},
	# ---- Neill Bogie low poly set (CC-BY 4.0)
	"nb_pickup": {"name": "Gator Pickup", "src": NB, "node": "car_pickup", "front": "+z", "length": 5.2, "mass": 1900, "accel": 7.0, "top": 44, "grip": 0.95, "paint": true, "kind": "civil"},
	"nb_sports": {"name": "Stinger Stripe", "src": NB, "node": "car_sports_striped", "front": "+z", "length": 4.5, "mass": 1250, "accel": 11.0, "top": 64, "grip": 1.2, "paint": false, "kind": "sport"},
	"nb_limo": {"name": "Limusina", "src": NB, "node": "car_limo", "front": "+z", "length": 7.0, "mass": 2600, "accel": 6.0, "top": 44, "grip": 0.95, "paint": false, "kind": "civil"},
	"nb_breadvan": {"name": "Panadería Van", "src": NB, "node": "car_breadvan", "front": "+z", "length": 5.0, "mass": 2200, "accel": 5.5, "top": 38, "grip": 0.9, "paint": false, "kind": "work"},
	"nb_daily": {"name": "Compacto", "src": NB, "node": "car_daily", "front": "+z", "length": 4.3, "mass": 1200, "accel": 7.0, "top": 44, "grip": 1.0, "paint": true, "kind": "civil"},
	"nb_charger": {"name": "Dominator 69", "src": NB, "node": "car_charger", "front": "+z", "length": 5.0, "mass": 1600, "accel": 11.0, "top": 62, "grip": 1.0, "paint": true, "kind": "sport"},
	"nb_police": {"name": "Interceptor VCPD", "src": NB, "node": "car_police", "front": "+z", "length": 4.9, "mass": 1650, "accel": 10.5, "top": 60, "grip": 1.15, "paint": false, "kind": "police", "siren": true},
	"nb_minivan": {"name": "Minivan", "src": NB, "node": "car_minivan", "front": "+z", "length": 4.9, "mass": 1900, "accel": 6.0, "top": 42, "grip": 0.95, "paint": true, "kind": "civil"},
	"nb_convertible": {"name": "Cabrio Ocean", "src": NB, "node": "car_convertible", "front": "+z", "length": 4.6, "mass": 1300, "accel": 9.0, "top": 56, "grip": 1.1, "paint": true, "kind": "sport", "open": true},
	"nb_beemer": {"name": "Übermacht", "src": NB, "node": "car_beemer", "front": "+z", "length": 4.8, "mass": 1500, "accel": 9.5, "top": 58, "grip": 1.1, "paint": true, "kind": "sport"},
	"nb_removals": {"name": "Mudanzas", "src": NB, "node": "car_removals", "front": "+z", "length": 6.0, "mass": 3500, "accel": 4.5, "top": 34, "grip": 0.85, "paint": false, "kind": "work"},
	"nb_minipickup": {"name": "Mini Pickup", "src": NB, "node": "car_mini-pickup", "front": "+z", "length": 4.4, "mass": 1500, "accel": 6.5, "top": 42, "grip": 0.95, "paint": true, "kind": "civil"},
	"nb_skis": {"name": "Rally Ski", "src": NB, "node": "car_sports_skiis", "front": "+z", "length": 4.4, "mass": 1200, "accel": 10.5, "top": 60, "grip": 1.2, "paint": false, "kind": "sport"},
	"nb_dragster": {"name": "Dragster", "src": NB, "node": "car_dragster", "front": "+z", "length": 6.5, "mass": 1000, "accel": 16.0, "top": 85, "grip": 1.2, "paint": false, "kind": "super"},
	# ---- Quaternius "Realistic Car Pack" (CC0)
	"q_primo": {"name": "Primo", "src": Q + "cars/NormalCar1.fbx", "front": "+z", "length": 4.6, "mass": 1400, "accel": 7.5, "top": 48, "grip": 1.05, "paint": true, "paint_mats": ["blue"], "kind": "civil"},
	"q_asterope": {"name": "Asterope", "src": Q + "cars/NormalCar2.fbx", "front": "+z", "length": 4.7, "mass": 1450, "accel": 7.5, "top": 48, "grip": 1.05, "paint": true, "paint_mats": ["lightblue"], "kind": "civil"},
	"q_cavalcade": {"name": "Cavalcade", "src": Q + "cars/SUV.fbx", "front": "+z", "length": 5.0, "mass": 2100, "accel": 7.0, "top": 46, "grip": 1.0, "paint": true, "paint_mats": ["white"], "kind": "civil"},
	"q_infernus": {"name": "Infernus Vice", "src": Q + "cars/SportsCar.fbx", "front": "+z", "length": 4.6, "mass": 1250, "accel": 13.0, "top": 76, "grip": 1.35, "paint": true, "paint_mats": ["orange", "darkorange"], "kind": "super"},
	"q_comet": {"name": "Comet Leonida", "src": Q + "cars/SportsCar2.fbx", "front": "+z", "length": 4.5, "mass": 1300, "accel": 11.5, "top": 68, "grip": 1.25, "paint": true, "paint_mats": ["white"], "kind": "sport"},
	"q_taxi": {"name": "Taxi Downtown Cab Co.", "src": Q + "cars/Taxi.fbx", "front": "+z", "length": 4.7, "mass": 1450, "accel": 7.5, "top": 46, "grip": 1.0, "paint": false, "kind": "taxi"},
	"q_cop": {"name": "Police Cruiser VCPD", "src": Q + "cars/Cop.fbx", "front": "+z", "length": 4.8, "mass": 1600, "accel": 10.5, "top": 60, "grip": 1.15, "paint": false, "kind": "police", "siren": true},
	"q_cop_suv": {"name": "Police Ranger VCPD", "src": Q + "cars/Cop_SUV.fbx", "front": "+z", "length": 5.0, "mass": 2200, "accel": 9.0, "top": 55, "grip": 1.1, "paint": false, "kind": "police", "siren": true},
	# ---- Quaternius "Ultimate Vehicles" (CC0, untextured: recolored by material name)
	"q_bus": {"name": "Autobús VC Transit", "src": Q + "transport/Bus.fbx", "front": "-x", "length": 10.5, "width": 2.8, "mass": 11000, "accel": 3.8, "top": 30, "grip": 0.85, "paint": false, "kind": "work", "white": true,
		"recolor": {"material": Color(0.08, 0.08, 0.08), "top": Color(0.95, 0.95, 0.95), "bottom": Color(0.1, 0.62, 0.66)}},
	"q_schoolbus": {"name": "Autobús escolar", "src": Q + "transport/SchoolBus.fbx", "front": "-x", "length": 9.5, "width": 2.7, "mass": 9500, "accel": 3.8, "top": 30, "grip": 0.85, "paint": false, "kind": "work", "white": true},
	"q_ambulance": {"name": "Ambulancia Leonida", "src": Q + "transport/Ambulance.fbx", "front": "+z", "length": 6.2, "width": 2.4, "mass": 3200, "accel": 6.5, "top": 44, "grip": 0.95, "paint": false, "kind": "emergency", "siren": true, "white": true,
		"recolor": {"material": Color(0.08, 0.08, 0.08), "grey": Color(0.4, 0.4, 0.42)}},
	"q_tank": {"name": "Rhino", "src": Q + "tanks/Tank.fbx", "front": "-x", "length": 9.0, "width": 4.6, "mass": 40000, "accel": 4.0, "top": 22, "grip": 1.6, "paint": false, "kind": "military",
		"turret": "Tank_Turret", "gun": "Tank_Gun", "armored": true},
	# ---- detailed licensed-look cars (fan uploads, converted with tools/brand_cars.gd)
	"b_m5": {"name": "BMW M5 CS", "src": B + "bmw_m5.glb", "front": "+z", "length": 4.98, "mass": 1800, "accel": 12.5, "top": 74, "grip": 1.3, "paint": true, "paint_mats": ["bm_carpaint_max1"], "kind": "sport"},
	"b_m8": {"name": "BMW M8 Competition", "src": B + "bmw_m8.glb", "front": "+z", "length": 4.87, "mass": 1850, "accel": 13.0, "top": 76, "grip": 1.3, "paint": true, "paint_mats": ["bbmw_m8rewardrecycled_2020paint_material1"], "kind": "sport"},
	"b_challenger": {"name": "Dodge Challenger R/T", "src": B + "challenger.glb", "front": "+z", "length": 5.02, "mass": 1900, "accel": 12.0, "top": 68, "grip": 1.1, "paint": true, "paint_mats": ["ddodge_challengerrtshakerf7_2015paint_material1"], "kind": "sport"},
	"b_roadster": {"name": "Tesla Roadster", "src": B + "roadster.glb", "front": "+z", "length": 4.6, "mass": 1700, "accel": 15.0, "top": 80, "grip": 1.4, "paint": true, "paint_mats": ["car_main_paint"], "kind": "super"},
	# ---- two wheels
	"motorcycle": {"name": "Moto Sanchez", "src": "res://assets/vehicles/motorcycle.glb", "front": "+z", "length": 2.3, "mass": 260, "accel": 11.0, "top": 60, "grip": 1.2, "paint": false, "kind": "bike", "bike": true, "open": true},
}

const BOATS := {
	"speedboat": {"name": "Lancha Squalo", "src": "res://assets/vehicles/boats/watercraftPack_017.gltf", "length": 7.0, "mass": 1500, "accel": 9.0, "top": 30},
	"speedboat2": {"name": "Lancha Jetmax", "src": "res://assets/vehicles/boats/watercraftPack_016.gltf", "length": 7.5, "mass": 1600, "accel": 9.5, "top": 32},
	"dinghy": {"name": "Neumática", "src": "res://assets/vehicles/boats/watercraftPack_001.gltf", "length": 5.0, "mass": 700, "accel": 7.0, "top": 24},
	"fishing": {"name": "Pesquero", "src": "res://assets/vehicles/boats/watercraftPack_010.gltf", "length": 9.0, "mass": 3000, "accel": 5.0, "top": 18},
	"yacht": {"name": "Yate", "src": "res://assets/vehicles/boats/watercraftPack_008.gltf", "length": 14.0, "mass": 9000, "accel": 4.0, "top": 20},
	"tug": {"name": "Remolcador", "src": "res://assets/vehicles/boats/watercraftPack_023.gltf", "length": 12.0, "mass": 12000, "accel": 3.0, "top": 14},
}

const PAINTS := [
	Color(0.95, 0.95, 0.95), Color(0.08, 0.08, 0.09), Color(0.6, 0.62, 0.65), Color(0.75, 0.1, 0.12),
	Color(0.1, 0.55, 0.6), Color(0.95, 0.4, 0.65), Color(0.95, 0.75, 0.1), Color(0.12, 0.25, 0.6),
	Color(0.3, 0.3, 0.32), Color(0.15, 0.45, 0.2), Color(0.95, 0.5, 0.15), Color(0.55, 0.2, 0.6),
	Color(0.2, 0.8, 0.85), Color(0.85, 0.85, 0.7),
]

const TRAFFIC_WEIGHTS := {
	"q_primo": 9, "q_asterope": 9, "q_cavalcade": 7, "q_taxi": 6, "q_comet": 3, "q_infernus": 2,
	"sedan": 4, "nb_daily": 5, "suv": 3, "taxi": 2, "nb_minivan": 3, "hatchbackSports": 2, "nb_pickup": 4,
	"sedanSports": 2, "suvLuxury": 2, "van": 3, "delivery": 2, "nb_breadvan": 1, "nb_minipickup": 2,
	"nb_convertible": 3, "nb_beemer": 3, "nb_charger": 2, "truck": 1, "garbageTruck": 1, "nb_removals": 1,
	"nb_sports": 1, "nb_limo": 1, "motorcycle": 2, "deliveryFlat": 1, "q_ambulance": 1, "q_bus": 2, "q_schoolbus": 1,
	"b_m5": 1, "b_m8": 1, "b_challenger": 1, "b_roadster": 1,
}

static var _scene_cache := {}
static var _weights_total := 0


static func get_def(id: String) -> Dictionary:
	if CARS.has(id):
		return CARS[id]
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
	return "sedan"


static func load_src(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


static func spawn(id: String, pos: Vector3, yaw := 0.0, paint := Color(-1, 0, 0)) -> Node3D:
	var v: Node3D
	if BOATS.has(id):
		v = Boat.new()
	else:
		v = Vehicle.new()
	v.def_id = id
	v.paint = paint
	Game.world.add_child(v)
	v.global_position = pos
	v.rotation.y = yaw
	return v
