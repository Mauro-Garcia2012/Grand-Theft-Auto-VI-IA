"""Generates clothing variants painted over the CC0 Quaternius Universal Base Character textures.
UV islands are classified per-triangle using bone weights + bind-pose position, then painted."""
import os, sys, random, numpy as np
from PIL import Image, ImageDraw, ImageFilter
from glbmesh import skinned_mesh, load_glb

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
CH = os.path.join(ROOT, "assets", "characters")
OUT = os.path.join(CH, "outfits")
os.makedirs(OUT, exist_ok=True)
S = 1024

REG = dict(SKIN=0, TORSO=1, UPPERARM_IN=2, UPPERARM_OUT=3, LOWERARM=4, HIPS=5, THIGH_UP=6, THIGH_LOW=7, CALF=8, FEET=9, NECK=10)

def classify(bone, x, y, h):
    ax = abs(x)
    s = h / 1.81
    if bone.startswith(("Head",)): return REG["SKIN"]
    if bone.startswith("neck"): return REG["NECK"]
    if bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")): return REG["SKIN"]
    if bone.startswith(("foot", "ball")): return REG["FEET"]
    if bone.startswith("calf"): return REG["FEET"] if y < 0.11 * s else REG["CALF"]
    if bone.startswith("thigh"): return REG["THIGH_UP"] if y > 0.70 * s else REG["THIGH_LOW"]
    if bone.startswith("lowerarm"): return REG["LOWERARM"]
    if bone.startswith("upperarm"): return REG["UPPERARM_IN"] if ax < 0.31 * s else REG["UPPERARM_OUT"]
    if bone.startswith("pelvis"): return REG["HIPS"] if y < 0.99 * s else REG["TORSO"]
    return REG["TORSO"]

def label_map(glb, mesh_name):
    prims, jn, _ = skinned_mesh(glb, mesh_name)
    lab = Image.new("L", (S, S), 255)
    d = ImageDraw.Draw(lab)
    h = max(p["pos"][:, 1].max() for p in prims)
    for p in prims:
        pos, uv, jo, we, idx = p["pos"], p["uv"], p["joints"], p["weights"], p["idx"]
        dom = jo[np.arange(len(pos)), we.argmax(1)]
        for t in idx:
            c = pos[t].mean(0)
            # majority bone of the triangle's vertices
            bones = [jn[dom[v]] for v in t]
            bone = max(set(bones), key=bones.count)
            r = classify(bone, c[0], c[1], h)
            pts = [(float(uv[v][0] * S), float(uv[v][1] * S)) for v in t]
            d.polygon(pts, fill=r)
    arr = np.array(lab)
    # dilate labels into unassigned (255) pixels to cover seams
    for _ in range(6):
        un = arr == 255
        if not un.any(): break
        sh = [np.roll(arr, 1, 0), np.roll(arr, -1, 0), np.roll(arr, 1, 1), np.roll(arr, -1, 1)]
        for s2 in sh:
            fill = un & (s2 != 255)
            arr[fill] = s2[fill]
            un = arr == 255
    arr[arr == 255] = REG["SKIN"]
    return arr

def noise(seed, scale=1.0):
    rng = np.random.default_rng(seed)
    n = rng.random((S // 8, S // 8)).astype(np.float32)
    img = Image.fromarray((n * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
    fine = rng.random((S, S)).astype(np.float32)
    return (np.array(img).astype(np.float32) / 255.0) * 0.6 + fine * 0.4

def floral(rng, base, colors):
    img = Image.new("RGB", (S, S), tuple(int(c * 255) for c in base))
    d = ImageDraw.Draw(img)
    for _ in range(420):
        x, y = rng.integers(0, S, 2)
        r = int(rng.integers(8, 22))
        col = tuple(int(c * 255) for c in colors[rng.integers(0, len(colors))])
        for k in range(5):
            a = k * 2 * np.pi / 5 + rng.random()
            px, py = x + np.cos(a) * r * 0.8, y + np.sin(a) * r * 0.8
            d.ellipse([px - r * 0.55, py - r * 0.55, px + r * 0.55, py + r * 0.55], fill=col)
        d.ellipse([x - r * 0.3, y - r * 0.3, x + r * 0.3, y + r * 0.3], fill=(250, 230, 120))
    for _ in range(160):
        x, y = rng.integers(0, S, 2)
        d.ellipse([x - 14, y - 5, x + 14, y + 5], fill=(40, 120, 60))
    return np.array(img).astype(np.float32) / 255.0

def stripes(base, other, width=18, vertical=False):
    yy, xx = np.mgrid[0:S, 0:S]
    m = ((xx if vertical else yy) // width) % 2 == 0
    out = np.empty((S, S, 3), np.float32)
    out[:] = base
    out[m] = other
    return out

def solid(c):
    out = np.empty((S, S, 3), np.float32); out[:] = c; return out

def camo(rng, cols):
    out = solid(cols[0])
    for i, c in enumerate(cols[1:]):
        n = noise(int(rng.integers(0, 99999)))
        blur = np.array(Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))) / 255.0
        out[blur > 0.52 + 0.03 * i] = c
    return out

TOPS = dict(
    tshirt=["TORSO", "UPPERARM_IN"],
    tank=["TORSO"],
    longsleeve=["TORSO", "UPPERARM_IN", "UPPERARM_OUT", "LOWERARM"],
    jacket=["TORSO", "UPPERARM_IN", "UPPERARM_OUT", "LOWERARM", "NECK_LOW"],
    none=[],
)
BOTTOMS = dict(
    pants=["HIPS", "THIGH_UP", "THIGH_LOW", "CALF"],
    shorts=["HIPS", "THIGH_UP"],
    swim=[],
)

def make(base_img, labels, outfit, seed):
    rng = np.random.default_rng(seed)
    img = np.array(base_img.convert("RGB")).astype(np.float32) / 255.0
    lum = img.mean(2)
    sat = img.max(2) - img.min(2)
    underwear = (lum < 0.33) & (sat < 0.08) & np.isin(labels, [REG["HIPS"], REG["TORSO"], REG["THIGH_UP"]])
    skin = ~underwear
    # skin tone
    tone = np.array(outfit.get("skin", (1, 1, 1)), np.float32)
    img[skin & np.isin(labels, list(REG.values()))] *= tone
    n = noise(seed)[..., None] * 0.14 + 0.93
    def paint(regions, tex):
        m = np.isin(labels, [REG[r] for r in regions if r in REG])
        img[m] = (tex * n)[m]
    top_tex = outfit["top_tex"](rng)
    bot_tex = outfit["bottom_tex"](rng)
    if outfit.get("swim_color") is not None:
        c = np.array(outfit["swim_color"], np.float32)
        img[underwear] = c * (0.85 + 0.15 * n[..., 0][underwear][:, None])
    paint(BOTTOMS[outfit["bottom"]], bot_tex)
    paint(TOPS[outfit["top"]], top_tex)
    if outfit.get("shoes") is not None:
        paint(["FEET"], solid(outfit["shoes"]))
    return Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8))

SKINS = [(1.22, 1.12, 1.05), (1.08, 1.02, 0.98), (1.0, 1.0, 1.0), (0.78, 0.70, 0.64), (0.58, 0.47, 0.40)]

def P(c): return lambda rng: solid(c)

def outfits_for(gender):
    denim = lambda rng: solid((0.20, 0.30, 0.52)) * (0.9 + 0.2 * noise(int(rng.integers(0, 9999)))[..., None])
    khaki = P((0.62, 0.55, 0.40))
    black = P((0.08, 0.08, 0.09))
    white = P((0.93, 0.93, 0.92))
    L = []
    hawaii = [((0.1, 0.55, 0.75), [(0.95, 0.35, 0.45), (1, 0.6, 0.2), (1, 1, 1)]),
              ((0.9, 0.25, 0.35), [(1, 0.85, 0.3), (1, 1, 1), (0.3, 0.8, 0.6)]),
              ((0.15, 0.2, 0.3), [(0.95, 0.4, 0.7), (0.3, 0.85, 0.9), (1, 0.8, 0.2)])]
    for i, (b, cols) in enumerate(hawaii):
        L.append(dict(name=f"hawaiian{i}", top="tshirt", top_tex=(lambda b=b, cols=cols: lambda rng: floral(rng, b, cols))(),
                      bottom="shorts" if i != 2 else "pants", bottom_tex=khaki if i == 0 else (denim if i == 1 else white), shoes=(0.9, 0.9, 0.9)))
    L.append(dict(name="business", top="jacket", top_tex=P((0.12, 0.13, 0.18)), bottom="pants", bottom_tex=P((0.12, 0.13, 0.18)), shoes=(0.05, 0.04, 0.04)))
    L.append(dict(name="suit_white", top="jacket", top_tex=P((0.92, 0.9, 0.86)), bottom="pants", bottom_tex=P((0.92, 0.9, 0.86)), shoes=(0.55, 0.4, 0.3)))
    L.append(dict(name="tank_jeans", top="tank", top_tex=white, bottom="pants", bottom_tex=denim, shoes=(0.15, 0.15, 0.15)))
    L.append(dict(name="tee_red", top="tshirt", top_tex=P((0.75, 0.12, 0.15)), bottom="pants", bottom_tex=black, shoes=(0.9, 0.9, 0.9)))
    L.append(dict(name="tee_stripes", top="tshirt", top_tex=lambda rng: stripes((0.95, 0.95, 0.95), (0.1, 0.35, 0.7), 14), bottom="shorts", bottom_tex=denim, shoes=(0.3, 0.2, 0.15)))
    L.append(dict(name="jogger", top="tank", top_tex=P((0.1, 0.8, 0.9)), bottom="shorts", bottom_tex=black, shoes=(0.95, 0.4, 0.2)))
    L.append(dict(name="camo", top="longsleeve", top_tex=lambda rng: camo(rng, [(0.3, 0.35, 0.2), (0.45, 0.42, 0.28), (0.18, 0.2, 0.12)]), bottom="pants", bottom_tex=khaki, shoes=(0.2, 0.15, 0.1)))
    L.append(dict(name="gang_purple", top="longsleeve", top_tex=P((0.4, 0.12, 0.55)), bottom="pants", bottom_tex=black, shoes=(0.95, 0.95, 0.95)))
    L.append(dict(name="gang_green", top="tank", top_tex=P((0.15, 0.55, 0.2)), bottom="shorts", bottom_tex=khaki, shoes=(0.95, 0.95, 0.95)))
    L.append(dict(name="police", top="tshirt", top_tex=P((0.10, 0.14, 0.28)), bottom="pants", bottom_tex=P((0.08, 0.1, 0.18)), shoes=(0.03, 0.03, 0.03)))
    L.append(dict(name="swat", top="longsleeve", top_tex=P((0.08, 0.08, 0.09)), bottom="pants", bottom_tex=P((0.08, 0.08, 0.09)), shoes=(0.03, 0.03, 0.03)))
    L.append(dict(name="medic", top="tshirt", top_tex=P((0.85, 0.87, 0.9)), bottom="pants", bottom_tex=P((0.1, 0.25, 0.5)), shoes=(0.03, 0.03, 0.03)))
    if gender == "male":
        L.append(dict(name="beach_trunks", top="none", top_tex=white, bottom="swim", bottom_tex=white, shoes=None, swim_color=(0.95, 0.45, 0.1)))
        L.append(dict(name="beach_trunks2", top="none", top_tex=white, bottom="shorts", bottom_tex=lambda rng: floral(rng, (0.1, 0.3, 0.8), [(1, 1, 1), (1, 0.8, 0.2)]), shoes=None))
        L.append(dict(name="jason", top="tank", top_tex=P((0.28, 0.30, 0.26)), bottom="pants", bottom_tex=denim, shoes=(0.35, 0.25, 0.15)))
    else:
        L.append(dict(name="bikini_pink", top="none", top_tex=white, bottom="swim", bottom_tex=white, shoes=None, swim_color=(0.95, 0.25, 0.55)))
        L.append(dict(name="bikini_teal", top="none", top_tex=white, bottom="swim", bottom_tex=white, shoes=None, swim_color=(0.1, 0.75, 0.75)))
        L.append(dict(name="lucia", top="tank", top_tex=P((0.12, 0.12, 0.13)), bottom="shorts", bottom_tex=denim, shoes=(0.95, 0.95, 0.95)))
    return L

def main():
    import json
    manifest = {}
    for gender, mesh, tex in [("male", "Retopology", "male_T_Superhero_Male_Dark.jpg"),
                              ("female", "Superhero_Female", "female_T_Superhero_Female_Dark_BaseColor.jpg")]:
        labels = label_map(os.path.join(CH, gender + ".glb"), mesh)
        Image.fromarray((labels * 20).astype(np.uint8)).save(os.path.join(os.path.dirname(__file__), f"labels_{gender}.png"))
        base = Image.open(os.path.join(CH, tex))
        if base.size != (S, S): base = base.resize((S, S))
        manifest[gender] = []
        for i, o in enumerate(outfits_for(gender)):
            for si, sk in enumerate(SKINS):
                if o["name"] in ("jason", "lucia") and si != 2: continue
                if o["name"] not in ("jason", "lucia") and (i + si) % 2 == 1 and si != 2: continue
                o2 = dict(o); o2["skin"] = sk
                im = make(base, labels, o2, seed=i * 17 + si)
                fn = f"{gender}_{o['name']}_s{si}.jpg"
                if o["name"] not in ("jason", "lucia"):
                    im = im.resize((512, 512), Image.LANCZOS)
                im.save(os.path.join(OUT, fn), quality=90)
                manifest[gender].append(dict(file=fn, outfit=o["name"], skin=si))
        print(gender, len(manifest[gender]))
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
