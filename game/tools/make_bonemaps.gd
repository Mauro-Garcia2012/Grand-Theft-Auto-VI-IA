extends SceneTree
## Writes a humanoid BoneMap for each given glb: args are triples <glb> <out.tres> <mixamo|ual>.
const MIXAMO := {
	"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
	"LeftThumbMetacarpal": "LeftHandThumb1", "LeftThumbProximal": "LeftHandThumb2", "LeftThumbDistal": "LeftHandThumb3",
	"LeftIndexProximal": "LeftHandIndex1", "LeftIndexIntermediate": "LeftHandIndex2", "LeftIndexDistal": "LeftHandIndex3",
	"LeftMiddleProximal": "LeftHandMiddle1", "LeftMiddleIntermediate": "LeftHandMiddle2", "LeftMiddleDistal": "LeftHandMiddle3",
	"LeftRingProximal": "LeftHandRing1", "LeftRingIntermediate": "LeftHandRing2", "LeftRingDistal": "LeftHandRing3",
	"LeftLittleProximal": "LeftHandPinky1", "LeftLittleIntermediate": "LeftHandPinky2", "LeftLittleDistal": "LeftHandPinky3",
	"LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
}
const UAL := {
	"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03", "Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftUpperArm": "upperarm_l", "LeftLowerArm": "lowerarm_l", "LeftHand": "hand_l",
	"LeftThumbMetacarpal": "thumb_01_l", "LeftThumbProximal": "thumb_02_l", "LeftThumbDistal": "thumb_03_l",
	"LeftIndexProximal": "index_01_l", "LeftIndexIntermediate": "index_02_l", "LeftIndexDistal": "index_03_l",
	"LeftMiddleProximal": "middle_01_l", "LeftMiddleIntermediate": "middle_02_l", "LeftMiddleDistal": "middle_03_l",
	"LeftRingProximal": "ring_01_l", "LeftRingIntermediate": "ring_02_l", "LeftRingDistal": "ring_03_l",
	"LeftLittleProximal": "pinky_01_l", "LeftLittleIntermediate": "pinky_02_l", "LeftLittleDistal": "pinky_03_l",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "calf_l", "LeftFoot": "foot_l", "LeftToes": "ball_l",
}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size(), 3):
		var s: Node = load(a[i]).instantiate()
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		var prefix := ""
		for b in sk.get_bone_count():
			var n := sk.get_bone_name(b)
			if n.ends_with("Hips") and a[i + 2] == "mixamo":
				prefix = n.substr(0, n.length() - 4)
		var table: Dictionary = MIXAMO if a[i + 2] == "mixamo" else UAL
		var bm := BoneMap.new()
		bm.profile = SkeletonProfileHumanoid.new()
		var missing := []
		for side in ["Left", "Right"]:
			for k in table:
				var pk: String = k
				var sb: String = table[k]
				if pk.begins_with("Left"):
					pk = side + pk.substr(4)
					if a[i + 2] == "mixamo":
						sb = side + sb.substr(4) if sb.begins_with("Left") else sb
					else:
						sb = sb.substr(0, sb.length() - 2) + ("_l" if side == "Left" else "_r") if sb.ends_with("_l") else sb
				elif side == "Right":
					continue
				var full := prefix + sb
				if sk.find_bone(full) < 0:
					missing.append(full)
					continue
				bm.set_skeleton_bone_name(StringName(pk), StringName(full))
		ResourceSaver.save(bm, a[i + 1])
		print("BONEMAP ", a[i + 1], " prefix=", prefix, " missing=", missing)
		s.free()
	quit()
