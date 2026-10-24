"""Vista previa de las animaciones de ejercicios.

Uso: python3 tools/motion/preview.py apps/zerack_fit/assets/exercise_motion.json salida.png

Dibuja frames[0], el punto medio y frames[1] de cada ejercicio con la misma
cinemática que usa la app (lib/src/ui/train/exercise_motion.dart).
"""
import json, math, sys
from PIL import Image, ImageDraw

L = dict(shin=22, thigh=22, torso=30, neck=3, head=6, upper=16, fore=15)

def d(a):
    r = math.radians(a)
    return math.sin(r), -math.cos(r)

def add(p, a, l):
    x, y = d(a)
    return (p[0] + x * l, p[1] + y * l)

def solve(ex, f):
    if ex["root"] == "ankle":
        ankle = tuple(ex["at"]); knee = add(ankle, f["shin"], L["shin"]); hip = add(knee, f["thigh"], L["thigh"])
    else:
        hip = tuple(ex["at"]); knee = add(hip, f["thigh"], L["thigh"]); ankle = add(knee, f["shin"], L["shin"])
    sh = add(hip, f["torso"], L["torso"]); head = add(sh, f["torso"], L["neck"] + L["head"])
    el = add(sh, f["upper"], L["upper"]); wr = add(el, f["fore"], L["fore"])
    return dict(ankle=ankle, knee=knee, hip=hip, sh=sh, head=head, el=el, wr=wr)

def lerp(a, b, t):
    # Ángulos por el arco más corto, igual que la app.
    def one(x, y):
        delta = (y - x + 180) % 360 - 180
        return x + delta * t
    return {k: one(a[k], b[k]) for k in a}

def draw(ex, f, img, ox, oy, s):
    g = ImageDraw.Draw(img); P = lambda p: (ox + p[0] * s, oy + p[1] * s)
    j = solve(ex, f)
    g.line([P((0, 95)), P((100, 95))], fill=(80, 80, 80), width=2)
    if "bench" in ex:
        x1, y1, x2, y2 = ex["bench"]; g.rectangle([P((x1, y1)), P((x2, y2))], outline=(120, 120, 120), width=2)
    if "anchor" in ex:
        g.line([P(j["wr"]), P(tuple(ex["anchor"]))], fill=(120, 120, 120), width=1)
    w = int(3 * s)
    for a, b in [("ankle", "knee"), ("knee", "hip"), ("hip", "sh"), ("sh", "el"), ("el", "wr")]:
        g.line([P(j[a]), P(j[b])], fill=(34, 211, 238), width=w)
    hx, hy = P(j["head"]); r = L["head"] * s
    g.ellipse([hx - r, hy - r, hx + r, hy + r], outline=(34, 211, 238), width=w)
    if "barbell" in ex["props"]:
        x, y = P(j["wr"]); g.ellipse([x - 5 * s, y - 5 * s, x + 5 * s, y + 5 * s], outline=(245, 245, 245), width=w)
    if "dumbbell" in ex["props"]:
        x, y = P(j["wr"]); g.rectangle([x - 4 * s, y - 2 * s, x + 4 * s, y + 2 * s], outline=(245, 245, 245), width=w)

def main():
    data = json.load(open(sys.argv[1])); names = [k for k in data if not k.startswith("_")]
    s = 2.2; cell = int(104 * s); img = Image.new("RGB", (cell * 3, cell * len(names)), (0, 0, 0))
    for i, n in enumerate(names):
        ex = data[n]; a, b = ex["frames"]
        for c, t in enumerate([0, 0.5, 1]):
            draw(ex, lerp(a, b, t), img, c * cell, i * cell, s)
        ImageDraw.Draw(img).text((4, i * cell + 4), n, fill=(255, 255, 255))
    img.save(sys.argv[2]); print(len(names), "ejercicios")

main()
