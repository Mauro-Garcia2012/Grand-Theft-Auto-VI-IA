"""Minimal glTF/GLB mesh reader (positions, uvs, joints, weights, indices) using numpy."""
import json, struct, numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def load_glb(path):
    data = open(path, "rb").read()
    l = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + l])
    off = 20 + l
    bl = struct.unpack("<I", data[off:off + 4])[0]
    return j, data[off + 8: off + 8 + bl]

def accessor(j, b, idx):
    a = j["accessors"][idx]
    bv = j["bufferViews"][a["bufferView"]]
    dt = CT[a["componentType"]]
    n = NC[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    itemsize = np.dtype(dt).itemsize * n
    if stride and stride != itemsize:
        raw = np.frombuffer(b, dtype=np.uint8, count=stride * a["count"], offset=start)
        raw = raw.reshape(a["count"], stride)[:, :itemsize].copy()
        arr = raw.view(dt).reshape(a["count"], n)
    else:
        arr = np.frombuffer(b, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
    return arr

def skinned_mesh(path, mesh_name_contains=None):
    j, b = load_glb(path)
    skin = j["skins"][0]
    joint_names = [j["nodes"][i]["name"] for i in skin["joints"]]
    for m in j["meshes"]:
        if mesh_name_contains and mesh_name_contains not in m["name"]:
            continue
        out = []
        for p in m["primitives"]:
            at = p["attributes"]
            out.append(dict(
                pos=accessor(j, b, at["POSITION"]).astype(np.float32),
                uv=accessor(j, b, at["TEXCOORD_0"]).astype(np.float32),
                joints=accessor(j, b, at["JOINTS_0"]).astype(np.int32),
                weights=accessor(j, b, at["WEIGHTS_0"]).astype(np.float32),
                idx=accessor(j, b, p["indices"]).reshape(-1, 3).astype(np.int64),
            ))
        return out, joint_names, j
    raise RuntimeError("mesh not found")
