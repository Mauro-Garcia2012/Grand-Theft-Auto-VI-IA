class_name CharacterModel
extends Node3D
## Realistic humanoid built from Mixamo characters, driven by the CC0 "Universal Animation
## Library" 1 & 2 (Quaternius). Both skeletons are retargeted on import to Godot's humanoid
## profile (bone maps in assets/people and assets/characters), so every clip plays on every body.

## Character bodies: id -> source scene, gender, hair material (tinted for variety).
const MODELS := {
	"ch12": {"src": "res://assets/people/Ch12.glb", "gender": "male", "hair": "ch12_hair"},
	"ch16": {"src": "res://assets/people/Ch16.glb", "gender": "male", "hair": ""},
	"ch17": {"src": "res://assets/people/Ch17.glb", "gender": "male", "hair": "ch17_hair"},
	"ch28": {"src": "res://assets/people/Ch28.glb", "gender": "male", "hair": "ch28_hair"},
	"soldier": {"src": "res://assets/people/Soldier.glb", "gender": "male", "hair": "", "scale": 1.52},
	"ch07": {"src": "res://assets/people/Ch07.glb", "gender": "female", "hair": "ch07_hair"},
}
## Who wears what: role -> model ids
const ROLES := {
	"jason": ["ch12"], "lucia": ["ch07"],
	"civil_male": ["ch16", "ch17", "ch28", "ch17"], "civil_female": ["ch07"],
	"police": ["ch28"], "swat": ["soldier"], "medic": ["ch16"],
	"gang_purple": ["ch28", "ch17"], "gang_green": ["ch17", "ch28"], "tee": ["ch17", "ch28"],
}
const HAIR_COLORS := [
	Color(1, 1, 1), Color(0.8, 0.75, 0.7), Color(1.2, 1.0, 0.8), Color(0.6, 0.55, 0.5), Color(1.3, 1.1, 0.75),
]

const UPPER_BODY_BONES := [
	"Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftThumbMetacarpal", "LeftThumbProximal", "LeftThumbDistal", "LeftIndexProximal", "LeftIndexIntermediate", "LeftIndexDistal",
	"LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal", "LeftRingProximal", "LeftRingIntermediate", "LeftRingDistal",
	"LeftLittleProximal", "LeftLittleIntermediate", "LeftLittleDistal",
	"RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal", "RightIndexProximal", "RightIndexIntermediate", "RightIndexDistal",
	"RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal", "RightRingProximal", "RightRingIntermediate", "RightRingDistal",
	"RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal",
]
const SKELETON_PATH := "%GeneralSkeleton"

## Full body locomotion / action states.
const LOCO_STATES := [
	"Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd",
	"Jump_Start", "Jump", "Jump_Land", "Roll", "Swim_Idle", "Swim_Fwd",
	"Driving", "Sitting_Idle", "Death01", "Hit_Chest", "Hit_Knockback", "LayToIdle",
	"Idle_Talking", "Idle_TalkingPhone", "Idle_FoldArms", "Dance", "Walk_Formal",
	"Punch_Jab", "Punch_Cross", "Melee_Hook", "OverhandThrow", "Interact", "PickUp_Table",
	"Fixing_Kneeling", "Zombie_Walk_Fwd", "Idle_No", "Yes", "ClimbUp_1m", "Push",
]
## Upper body overlay states (aiming, reloading, punching while moving).
const UPPER_STATES := ["Pistol_Idle", "Pistol_Reload", "Pistol_Shoot", "Punch_Jab", "Punch_Cross", "OverhandThrow", "Idle_TalkingPhone"]

static var _anim_lib: AnimationLibrary
static var _mat_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}
static var _tree_root: AnimationNodeBlendTree

var gender := "male"
var outfit_file := ""
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var body: MeshInstance3D
var _loco_pb: AnimationNodeStateMachinePlayback
var _upper_pb: AnimationNodeStateMachinePlayback
var _aim_blend := 0.0
var _aim_target := 0.0
var current_loco := "Idle"
var current_upper := ""


static func load_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


static func get_anim_library() -> AnimationLibrary:
	if _anim_lib:
		return _anim_lib
	_anim_lib = AnimationLibrary.new()
	for p in ["res://assets/characters/anim_ual1.glb", "res://assets/characters/anim_ual2.glb"]:
		var s: Node = load_scene(p).instantiate()
		var ap: AnimationPlayer = s.get_node("AnimationPlayer")
		var lib: AnimationLibrary = ap.get_animation_library("")
		for n in lib.get_animation_list():
			if not _anim_lib.has_animation(n):
				_anim_lib.add_animation(n, lib.get_animation(n))
		s.free()
	# Loop fixes for locomotion clips that must cycle
	for n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump", "Swim_Idle", "Swim_Fwd",
			"Driving", "Sitting_Idle", "Idle_Talking", "Idle_TalkingPhone", "Idle_FoldArms", "Dance", "Walk_Formal",
			"Pistol_Idle", "Zombie_Walk_Fwd", "Push", "Idle_No"]:
		if _anim_lib.has_animation(n):
			_anim_lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return _anim_lib


## Model ids a character of this gender can wear (civilian clothes).
static func get_outfits(p_gender: String) -> Array:
	return ROLES["civil_male" if p_gender == "male" else "civil_female"]


static func pick_outfit(p_gender: String, kind := "", rng: RandomNumberGenerator = null) -> String:
	var key := kind
	if key == "" or not ROLES.has(key):
		key = "civil_male" if p_gender == "male" else "civil_female"
	var pool: Array = ROLES[key]
	if rng:
		return pool[rng.randi() % pool.size()]
	return pool.pick_random()


static func _build_tree_root() -> AnimationNodeBlendTree:
	if _tree_root:
		return _tree_root
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeStateMachine.new()
	for s in LOCO_STATES:
		var n := AnimationNodeAnimation.new()
		n.animation = s
		loco.add_node(s, n)
	_connect_all(loco, LOCO_STATES, 0.18)
	var upper := AnimationNodeStateMachine.new()
	var aim := AnimationNodeBlendSpace1D.new()
	for pair in [["Pistol_Aim_Down", -1.0], ["Pistol_Aim_Neutral", 0.0], ["Pistol_Aim_Up", 1.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = pair[0]
		aim.add_blend_point(a, pair[1], -1, StringName(pair[0]))
	aim.min_space = -1.0
	aim.max_space = 1.0
	upper.add_node("Aim", aim)
	var ustates: Array = ["Aim"]
	for s in UPPER_STATES:
		var n := AnimationNodeAnimation.new()
		n.animation = s
		upper.add_node(s, n)
		ustates.append(s)
	_connect_all(upper, ustates, 0.1)
	bt.add_node("loco", loco)
	bt.add_node("upper", upper)
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("loco_speed", ts)
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	for b in UPPER_BODY_BONES:
		blend.set_filter_path(NodePath(SKELETON_PATH + ":" + b), true)
	bt.add_node("upper_blend", blend)
	bt.connect_node("loco_speed", 0, "loco")
	bt.connect_node("upper_blend", 0, "loco_speed")
	bt.connect_node("upper_blend", 1, "upper")
	bt.connect_node("output", 0, "upper_blend")
	_tree_root = bt
	return bt


static func _connect_all(sm: AnimationNodeStateMachine, states: Array, xfade: float) -> void:
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", states[0], start)
	for a in states:
		for b in states:
			if a == b:
				continue
			var t := AnimationNodeStateMachineTransition.new()
			t.xfade_time = xfade
			t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			sm.add_transition(a, b, t)


func build(p_gender: String, p_outfit := "", _hair := "", hair_color := Color(-1, 0, 0), _beard := false) -> void:
	gender = p_gender
	outfit_file = p_outfit if MODELS.has(p_outfit) else pick_outfit(gender)
	var def: Dictionary = MODELS[outfit_file]
	gender = def.gender
	var body_scene: Node3D = load_scene(def.src).instantiate()
	body_scene.name = "Body"
	add_child(body_scene)
	# Mixamo models face +Z; our characters face -Z (Godot forward)
	body_scene.rotation.y = PI
	body_scene.scale = Vector3.ONE * float(def.get("scale", 1.0))
	skeleton = body_scene.get_node(SKELETON_PATH)
	# hair tint for a bit of variety between people wearing the same body
	var tint: Color = hair_color if hair_color.r >= 0.0 else HAIR_COLORS.pick_random()
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if body == null:
			body = m
		if def.hair != "" and tint != Color(1, 1, 1):
			for si in m.mesh.get_surface_count():
				var mat := m.get_active_material(si)
				if mat is StandardMaterial3D and String(mat.resource_name).to_lower() == def.hair:
					var key := str(mat.get_instance_id()) + str(tint)
					if not _mat_cache.has(key):
						var m2: StandardMaterial3D = mat.duplicate()
						m2.albedo_color = tint
						_mat_cache[key] = m2
					m.set_surface_override_material(si, _mat_cache[key])
	# Animation
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	body_scene.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	anim_player.add_animation_library("", get_anim_library())
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	body_scene.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.root_node = NodePath("..")
	anim_tree.tree_root = _build_tree_root()
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim_tree.active = true
	_loco_pb = anim_tree.get("parameters/loco/playback")
	_upper_pb = anim_tree.get("parameters/upper/playback")
	anim_tree.set("parameters/upper_blend/blend_amount", 0.0)
	anim_tree.set("parameters/loco_speed/scale", 1.0)


## Rebuilds the character with another body (clothes shop).
func set_outfit(id: String, hair_tint := Color(1, 1, 1), force := false) -> void:
	if not MODELS.has(id) or (id == outfit_file and not force):
		return
	var attachments: Array = []
	for ba in skeleton.find_children("*", "BoneAttachment3D", false, false):
		attachments.append([ba, ba.bone_name])
		skeleton.remove_child(ba)
	var old := get_node_or_null("Body")
	if old:
		old.name = "OldBody"
		old.queue_free()
	body = null
	anim_tree = null
	build(gender, id, "", hair_tint)
	for a in attachments:
		skeleton.add_child(a[0])
		(a[0] as BoneAttachment3D).bone_name = a[1]


## Locomotion / full body state (cross-faded).
func play(state: String, speed := 1.0) -> void:
	if not _loco_pb:
		return
	anim_tree.set("parameters/loco_speed/scale", speed)
	if state == current_loco:
		return
	current_loco = state
	_loco_pb.travel(state)


func restart(state: String, speed := 1.0) -> void:
	if not _loco_pb:
		return
	anim_tree.set("parameters/loco_speed/scale", speed)
	current_loco = state
	_loco_pb.start(state, true)


## Upper body overlay. Pass "" to fade it out.
func upper(state: String) -> void:
	if not _upper_pb:
		return
	if state == "":
		_aim_target = 0.0
		return
	_aim_target = 1.0
	if state != current_upper or state in ["Pistol_Shoot", "Punch_Jab", "Punch_Cross", "OverhandThrow", "Pistol_Reload"]:
		if state in ["Pistol_Shoot", "Punch_Jab", "Punch_Cross", "OverhandThrow", "Pistol_Reload"]:
			_upper_pb.start(state, true)
		else:
			_upper_pb.travel(state)
	current_upper = state


func set_aim_pitch(v: float) -> void:
	if anim_tree:
		anim_tree.set("parameters/upper/Aim/blend_position", clampf(v, -1.0, 1.0))


func loco_time_left() -> float:
	if not _loco_pb:
		return 0.0
	return _loco_pb.get_current_length() - _loco_pb.get_current_play_position()


func upper_time_left() -> float:
	if not _upper_pb:
		return 0.0
	return _upper_pb.get_current_length() - _upper_pb.get_current_play_position()


var _anim_acc := 0.0
var _anim_skip := 0
var always_full_rate := false


func _process(delta: float) -> void:
	if anim_tree == null:
		return
	_aim_blend = move_toward(_aim_blend, _aim_target, delta * 6.0)
	anim_tree.set("parameters/upper_blend/blend_amount", _aim_blend)
	# animation LOD: far / off-screen characters update less often
	_anim_acc += delta
	var step := 1
	if not always_full_rate:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var to := global_position - cam.global_position
			var d2 := to.length_squared()
			if d2 > 6400.0:
				step = 6
			elif d2 > 1600.0:
				step = 3
			elif d2 > 400.0:
				step = 2
			if d2 > 100.0 and to.dot(-cam.global_basis.z) < 0.0:
				step = maxi(step, 6)
	_anim_skip += 1
	if _anim_skip >= step:
		_anim_skip = 0
		anim_tree.advance(_anim_acc)
		_anim_acc = 0.0


func bone_global(bone: String) -> Vector3:
	var i := skeleton.find_bone(bone)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


func attach_to_bone(node: Node3D, bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	ba.add_child(node)
	return ba
