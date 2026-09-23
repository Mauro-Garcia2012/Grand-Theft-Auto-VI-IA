class_name VehicleDB
extends RefCounted
## Vehicle catalogue. Models: Kenney "Car Kit" (CC0), Kenney "Racing Kit" motorcycle (CC0),
## Neill Bogie low-poly cars set (CC-BY 4.0), Kenney "Watercraft Pack" (CC0).

const NB := "res://assets/vehicles/lowpoly_cars_set.glb"

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
	"sedan": 10, "nb_daily": 8, "suv": 6, "taxi": 6, "nb_minivan": 4, "hatchbackSports": 4, "nb_pickup": 5,
	"sedanSports": 3, "suvLuxury": 3, "van": 3, "delivery": 2, "nb_breadvan": 1, "nb_minipickup": 3,
	"nb_convertible": 3, "nb_beemer": 3, "nb_charger": 2, "truck": 1, "garbageTruck": 1, "nb_removals": 1,
	"nb_sports": 1, "nb_limo": 1, "motorcycle": 2, "deliveryFlat": 1, "ambulance": 1,
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
