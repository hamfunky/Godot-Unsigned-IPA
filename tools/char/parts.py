"""Bake the locked detailer design (v4) into rigid part textures for the Godot rig.

Each part is drawn in the design's own coordinates (feet at y=300), rendered at RES px per unit,
cropped, and its joint (pivot) recorded. Writes:
  <proj>/assets/game/sprites/detailer/*.png
  <proj>/scripts/detailer_parts.gd   (pivots, sizes, skeleton numbers in design units)
"""
import sys, os, json
sys.path.insert(0, "/root/char")
import detailer as D
from detailer import f, P, limb, shaded, ellipse_d, SKIN, HAIR, INK, GROUND
from playwright.sync_api import sync_playwright
from PIL import Image

PROJ = sys.argv[1] if len(sys.argv) > 1 else "/root/p"
OUTDIR = os.path.join(PROJ, "assets/game/sprites/detailer")
RES = 2.0
V = D.VARIANTS["A"]
L = D.layout(V)
S, W, N = V["S"], V["W"], V["neck"]
sy, hip, ank, chin = L["sy"], L["hip"], L["ank"], L["chin"]

# skeleton (design units)
UPPER_ARM = 46.0
FOREARM = 40.0
HAND_R = 17.0
THIGH = 21.0
SHIN = 21.0
HIP_Y = hip + 6.0          # leg joints
ANKLE_Y = ank - 2.0


TORSO_D = {}


def sample_path(d, step=4.0):
    """Sample an SVG path made of M/L/C/Z commands into points."""
    import math
    toks = d.replace(",", " ").split()
    pts, i, cur, cmd = [], 0, (0.0, 0.0), None
    while i < len(toks):
        t = toks[i]
        if t in ("M", "L", "C", "Z"):
            cmd = t
            i += 1
            if t == "Z":
                continue
        if cmd == "M" or cmd == "L":
            cur = (float(toks[i]), float(toks[i + 1])); i += 2
            pts.append(cur)
        elif cmd == "C":
            c1 = (float(toks[i]), float(toks[i + 1])); c2 = (float(toks[i + 2]), float(toks[i + 3])); e = (float(toks[i + 4]), float(toks[i + 5])); i += 6
            n = max(4, int(math.dist(cur, e) / step))
            for k in range(1, n + 1):
                pts.append(D.bez(cur, c1, c2, e, k / n))
            cur = e
        else:
            i += 1
    return pts


def torso_34():
    s = ""
    nk = f"M {f(-N + 6)} {f(chin - 30)} L {f(N + 4)} {f(chin - 30)} L {f(N + 10)} {f(sy + 4)} L {f(-N - 2)} {f(sy + 4)} Z"
    s += shaded(nk, SKIN[0], SKIN[1], dx=-4, dy=6)
    Sn, Sf = S * 0.98, S * 0.70
    td = (f"M {f(-N + 2)} {f(sy - 8)} C {f(-N - 16)} {f(sy - 6)} {f(-Sn + 14)} {f(sy - 4)} {f(-Sn)} {f(sy + 14)} "
          f"C {f(-Sn - 4)} {f(sy + 44)} {f(-W - 6)} {f(hip - 30)} {f(-W + 2)} {f(hip + 6)} "
          f"L {f(W * 0.9)} {f(hip + 6)} C {f(W + 6)} {f(hip - 26)} {f(Sf + 18)} {f(sy + 56)} {f(Sf + 16)} {f(sy + 30)} "
          f"C {f(Sf + 14)} {f(sy + 10)} {f(N + 22)} {f(sy - 6)} {f(N + 8)} {f(sy - 8)} Z")
    TORSO_D["34"] = td
    detail = f'<path d="M {f(-N + 3)} {f(sy - 8)} C {f(-N + 8)} {f(sy + 10)} {f(N + 2)} {f(sy + 10)} {f(N + 8)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    detail += f'<path d="M {f(Sf - 4)} {f(sy + 40)} C {f(Sf - 18)} {f(sy + 52)} {f(4)} {f(sy + 50)} {f(-6)} {f(sy + 38)}" fill="none" stroke="{V["shirt"][1]}" stroke-width="3.5" stroke-linecap="round"/>'
    lx, ly = Sf * 0.35, sy + 26
    detail += f'<path d="M {f(lx)} {f(ly - 9)} C {f(lx + 5)} {f(ly - 1)} {f(lx + 6)} {f(ly + 4)} {f(lx)} {f(ly + 6)} C {f(lx - 6)} {f(ly + 4)} {f(lx - 5)} {f(ly - 1)} {f(lx)} {f(ly - 9)} Z" fill="{V["logo"]}" stroke="{INK}" stroke-width="2"/>'
    s += shaded(td, V["shirt"][0], V["shirt"][1], dx=-12, dy=-4, extra=detail)
    bd = f"M {f(-W + 1)} {f(hip - 2)} L {f(W * 0.92)} {f(hip - 2)} L {f(W * 0.9)} {f(hip + 9)} L {f(-W + 2)} {f(hip + 9)} Z"
    s += (f'<path d="{bd}" fill="#2b2522" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
          f'<rect x="{f(W*0.3 - 7)}" y="{f(hip - 1)}" width="14" height="9" rx="2" fill="#c9b27a" stroke="{INK}" stroke-width="2.5"/>')
    return s


def torso_front():
    S_, W_ = S, W
    TORSO_D["F"] = (f"M {f(-N - 2)} {f(sy - 8)} C {f(-N - 18)} {f(sy - 6)} {f(-S_ + 14)} {f(sy - 4)} {f(-S_)} {f(sy + 14)} "
          f"C {f(-S_ - 6)} {f(sy + 40)} {f(-W_ - 10)} {f(hip - 30)} {f(-W_ - 2)} {f(hip + 6)} "
          f"L {f(W_ + 2)} {f(hip + 6)} C {f(W_ + 10)} {f(hip - 30)} {f(S_ + 6)} {f(sy + 40)} {f(S_)} {f(sy + 14)} "
          f"C {f(S_ - 14)} {f(sy - 4)} {f(N + 18)} {f(sy - 6)} {f(N + 2)} {f(sy - 8)} Z")
    b = D.body_front(V, L)
    return b["neck"] + b["torso"] + b["belt"]


def head34(mood="mean", blink=False):
    D.BLINK = blink
    s = D.head_34(V, L, 6.0, mood)
    D.BLINK = False
    return s


def headF(mood="mean", blink=False):
    D.BLINK = blink
    s = D.head_front(V, L, 0.0, mood)
    D.BLINK = False
    return s


def upper_arm():
    return shaded(limb((0, 0), (0, UPPER_ARM), 42, 30, bulge=9), SKIN[0], SKIN[1], dx=-6, dy=-4)


def forearm():
    v = V
    el, wr = (0, 0), (0, FOREARM)
    s = shaded(limb(el, wr, 31, 24, bulge=6), SKIN[0], SKIN[1], dx=-5, dy=-4)
    gy = FOREARM * 0.68
    s += shaded(limb((0, gy), wr, 27, 23, bulge=2, cap_a=False), v["gloves"][0], v["gloves"][1], dx=-4, dy=-4)
    s += f'<path d="M 15 {f(gy)} L -15 {f(gy)}" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
    s += f'<path d="M 13 {f(gy + 3)} L -13 {f(gy + 3)}" stroke="{v["gloves"][2]}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>'
    return s


def fist():
    v = V
    hx, hy = 0.0, HAND_R * 0.55
    fd = ellipse_d(hx, hy, HAND_R, HAND_R * 0.92)
    kn = ""
    for k in (-1, 0, 1):
        kx, ky = hx - k * 6.5, hy + 6
        kn += f'<path d="M {f(kx)} {f(ky - 4)} L {f(kx)} {f(ky)}" stroke="{v["gloves"][1]}" stroke-width="2.5" stroke-linecap="round"/>'
    return shaded(fd, v["gloves"][0], v["gloves"][1], dx=-4, dy=-4,
                  extra=kn + f'<circle cx="{f(hx - 5)}" cy="{f(hy - 6)}" r="3.2" fill="{v["gloves"][2]}" opacity="0.8"/>')


def mitt():
    return D.mitt(0.0, 0.0)


def thigh(pocket=True):
    s_extra = f'<rect x="-21" y="10" width="15" height="17" rx="3" fill="none" stroke="{V["pants"][1]}" stroke-width="3"/>' if pocket else ""
    return shaded(limb((0, 0), (0, THIGH), 50, 46, bulge=3), V["pants"][0], V["pants"][1], dx=-7, dy=-2, extra=s_extra)


def shin():
    return shaded(limb((0, 0), (0, SHIN), 46, 42, bulge=2), V["pants"][0], V["pants"][1], dx=-7, dy=-2)


def boot34():
    bx, a = 0.0, ANKLE_Y + 2      # design ank
    bd = (f"M {f(bx - 22)} {f(GROUND)} L {f(bx - 22)} {f(a - 10)} C {f(bx - 22)} {f(a - 16)} {f(bx + 12)} {f(a - 16)} {f(bx + 16)} {f(a - 6)} "
          f"C {f(bx + 32)} {f(a - 2)} {f(bx + 36)} {f(GROUND - 6)} {f(bx + 34)} {f(GROUND)} Z")
    return shaded(bd, V["boots"][0], V["boots"][1], dx=-5, dy=-3) + f'<rect x="{f(bx - 25)}" y="{f(GROUND - 7)}" width="62" height="8" rx="2" fill="#2a2420"/>'


def bootF():
    a = ANKLE_Y + 2
    bw = W + 2
    x0 = -bw / 2
    bd = (f"M {f(x0)} {f(GROUND)} L {f(x0)} {f(a - 8)} C {f(x0)} {f(a - 14)} {f(x0 + bw)} {f(a - 14)} {f(x0 + bw)} {f(a - 8)} "
          f"L {f(x0 + bw + 2)} {f(GROUND)} Z")
    return shaded(bd, V["boots"][0], V["boots"][1], dx=-5, dy=-3,
                  extra=f'<rect x="{f(x0 - 4)}" y="{f(GROUND - 7)}" width="{f(bw + 10)}" height="8" fill="#2a2420"/>')


def cannon():
    """Pressure-washer gun with a foam cannon on the end, pointing +x. Pivot (0,0) = where the fist grips it."""
    ink = f'stroke="{INK}" stroke-width="4" stroke-linejoin="round"'
    s = ""
    # lance
    s += f'<rect x="18" y="-14" width="60" height="8" rx="3" fill="#b8c2cc" {ink}/>'
    s += f'<rect x="20" y="-13" width="56" height="2.5" fill="#eef3f7"/>'
    # gun body + pistol grip (black with a yellow trigger guard)
    s += f'<path d="M -16 -20 L 22 -20 Q 28 -20 28 -14 L 28 -4 Q 28 2 22 2 L 6 2 L 10 26 Q 11 32 4 32 L -4 32 Q -10 32 -10 26 L -12 2 Q -18 0 -18 -6 L -18 -14 Q -18 -20 -16 -20 Z" fill="#2b2e36" {ink}/>'
    s += f'<path d="M -12 -17 L 20 -17" stroke="#5a6070" stroke-width="3" stroke-linecap="round"/>'
    s += f'<path d="M 10 2 Q 20 4 18 16" fill="none" stroke="#ffc93c" stroke-width="4.5" stroke-linecap="round"/>'
    s += f'<path d="M 10 2 Q 20 4 18 16" fill="none" stroke="{INK}" stroke-width="1.5" stroke-linecap="round" opacity="0.6"/>'
    # foam cannon: brass body, bottle hanging underneath, fan nozzle
    s += f'<rect x="70" y="-19" width="20" height="18" rx="4" fill="#d9a441" {ink}/>'
    s += f'<rect x="73" y="-16" width="13" height="4" rx="2" fill="#f3d58a"/>'
    s += f'<path d="M 66 0 L 94 0 L 92 40 Q 92 46 86 46 L 74 46 Q 68 46 68 40 Z" fill="#e6f6ff" {ink}/>'
    s += f'<path d="M 69.5 22 L 92.5 22 L 92 40 Q 92 44 86 44 L 74 44 Q 69.5 44 69.5 40 Z" fill="#8fd3ff"/>'
    s += f'<path d="M 69.5 22 Q 75 18 81 22 Q 87 26 92.5 22" fill="#ffffff" stroke="#bfe6ff" stroke-width="1.5"/>'
    s += f'<rect x="72" y="4" width="4" height="34" rx="2" fill="#ffffff" opacity="0.7"/>'
    s += f'<rect x="64" y="-4" width="32" height="8" rx="3" fill="#d9a441" {ink}/>'
    s += f'<path d="M 90 -15 L 104 -21 L 104 -1 L 90 -7 Z" fill="#d9a441" {ink}/>'
    s += f'<rect x="100" y="-20" width="5" height="18" rx="2" fill="#2b2e36"/>'
    return s


def polisher():
    """Dual-action polisher, pad pointing +x. Pivot (0,0) = centre of the pad's face.
    Rear grip at (-89, 1) (near hand), top knob at (-22, -24) (far hand)."""
    ink = f'stroke="{INK}" stroke-width="4" stroke-linejoin="round"'
    s = ""
    # rear grip (rubber) + cord boot
    s += f'<rect x="-104" y="-6" width="10" height="16" rx="4" fill="#2b2e36" {ink}/>'
    s += f'<rect x="-100" y="-12" width="24" height="26" rx="9" fill="#2b2e36" {ink}/>'
    for k in range(3):
        s += f'<path d="M {-94 + k * 6} -7 L {-94 + k * 6} 9" stroke="#4a4f5c" stroke-width="2.5" stroke-linecap="round"/>'
    # motor body
    s += f'<rect x="-80" y="-18" width="52" height="36" rx="13" fill="#1e88e5" {ink}/>'
    s += f'<rect x="-74" y="-13" width="40" height="6" rx="3" fill="#6ab7ff"/>'
    for k in range(3):
        s += f'<path d="M {-70 + k * 9} 4 L {-66 + k * 9} 11" stroke="#0d47a1" stroke-width="3" stroke-linecap="round"/>'
    # top knob (side handle)
    s += f'<rect x="-31" y="-34" width="17" height="24" rx="7" fill="#2b2e36" {ink}/>'
    # gear head
    s += f'<rect x="-36" y="-14" width="26" height="28" rx="5" fill="#6b7280" {ink}/>'
    s += f'<rect x="-32" y="-10" width="18" height="5" rx="2" fill="#9aa1ad"/>'
    # backing plate + foam pad (pad spin is drawn on top in code)
    s += f'<rect x="-12" y="-20" width="7" height="40" rx="2" fill="#2b2e36" {ink}/>'
    s += f'<rect x="-6" y="-25" width="12" height="50" rx="5" fill="#ff8a3d" {ink}/>'
    s += f'<rect x="-3" y="-21" width="3" height="42" rx="1.5" fill="#ffc08f"/>'
    return s


# name -> (svg, pivot in design units)
PARTS = {
    "torso34": (torso_34(), (0.0, hip)),
    "torsoF": (torso_front(), (0.0, hip)),
    "head34": (head34(), (6.0, chin - 16)),
    "head34_blink": (head34(blink=True), (6.0, chin - 16)),
    "head34_grin": (head34("grin"), (6.0, chin - 16)),
    "headF": (headF(), (0.0, chin - 16)),
    "headF_blink": (headF(blink=True), (0.0, chin - 16)),
    "headF_grin": (headF("grin"), (0.0, chin - 16)),
    "upper_arm": (upper_arm(), (0.0, 0.0)),
    "forearm": (forearm(), (0.0, 0.0)),
    "fist": (fist(), (0.0, 0.0)),
    "mitt": (mitt(), (0.0, 0.0)),
    "thigh": (thigh(), (0.0, 0.0)),
    "shin": (shin(), (0.0, 0.0)),
    "boot34": (boot34(), (0.0, ANKLE_Y)),
    "bootF": (bootF(), (0.0, ANKLE_Y)),
    "cannon": (cannon(), (0.0, 0.0)),
    "polisher": (polisher(), (0.0, 0.0)),
}

# skeleton, relative to the hip pivot (0, hip) for torso-attached joints, design units
anc34 = D.bez((-N + 2, sy - 8), (-N - 16, sy - 6), (-S * 0.98 + 14, sy - 4), (-S * 0.98, sy + 14), 0.70)
ancF = D.bez((S, sy + 14), (S - 14, sy - 4), (N + 18, sy - 6), (N + 2, sy - 8), 0.30)
SKEL = {
    "res": RES,
    "ground": GROUND,
    "hip_y": hip,                      # torso pivot height (design y)
    "upper_arm": UPPER_ARM, "forearm": FOREARM, "hand_r": HAND_R,
    "thigh": THIGH, "shin": SHIN,
    "leg_hip_y": HIP_Y - hip,          # leg joints below the torso pivot
    "ankle_y": ANKLE_Y,
    # 3/4 view (facing +x)
    "sh_near34": (-S * 0.82, sy + 18 - hip), "sh_far34": (S * 0.55, sy + 14 - hip),
    "anc_near34": (anc34[0], anc34[1] - hip), "anc_far34": (S * 0.55 - 4, sy + 2 - hip),
    "hip_near34": (-W * 0.45, HIP_Y - hip), "hip_far34": (W * 0.45, HIP_Y - hip),
    "foot_near34": (-W * 0.45 - 4, ANKLE_Y), "foot_far34": (W * 0.62 + 10, ANKLE_Y),
    "neck34": (6.0, chin - 16 - hip),
    # front view
    "sh_F": (S - 12, sy + 18 - hip), "anc_F": (ancF[0], ancF[1] - hip),
    "hip_F": (W * 0.5, HIP_Y - hip), "foot_F": (W * 0.56, ANKLE_Y),
    "neckF": (0.0, chin - 16 - hip),
    "nozzle": (106.0, -11.0), "hose": (-1.0, 32.0),
    "pol_grip": (-89.0, 1.0), "pol_knob": (-22.0, -24.0), "pol_cord": (-104.0, 2.0),
    "shirt": V["shirt"], "skin": SKIN, "ink": INK,
}


def render_all():
    os.makedirs(OUTDIR, exist_ok=True)
    vb = (-200, -60, 400, 420)
    scale = RES
    out = {}
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=scale, viewport={"width": vb[2], "height": vb[3]})
        for name, (svg_body, piv) in PARTS.items():
            html = (f'<html><body style="margin:0;background:transparent">'
                    f'<svg xmlns="http://www.w3.org/2000/svg" width="{vb[2]}" height="{vb[3]}" viewBox="{vb[0]} {vb[1]} {vb[2]} {vb[3]}">{svg_body}</svg></body></html>')
            pg.set_content(html)
            tmp = f"/tmp/claude-0/part_{name}.png"
            pg.locator("svg").screenshot(path=tmp, omit_background=True)
            im = Image.open(tmp).convert("RGBA")
            bb = im.split()[3].getbbox()
            pad = 3
            bb = (max(0, bb[0] - pad), max(0, bb[1] - pad), min(im.width, bb[2] + pad), min(im.height, bb[3] + pad))
            crop = im.crop(bb)
            crop.save(os.path.join(OUTDIR, f"{name}.png"))
            # pivot in pixels inside the cropped texture
            px = (piv[0] - vb[0]) * scale - bb[0]
            py = (piv[1] - vb[1]) * scale - bb[1]
            out[name] = (round(px, 2), round(py, 2), crop.width, crop.height)
        b.close()
    return out


def gd_value(v):
    if isinstance(v, (tuple, list)) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v):
        return f"Vector2({v[0]:.2f}, {v[1]:.2f})"
    if isinstance(v, (tuple, list)):
        return "[" + ", ".join(gd_value(x) for x in v) + "]"
    if isinstance(v, str):
        return f'"{v}"'
    return f"{float(v):.3f}"


if __name__ == "__main__":
    info = render_all()
    lines = ["## GENERATED by tools/char/parts.py from the locked detailer design (v4, 19 Oct). Don't edit by hand.",
             "## Part textures live in res://assets/game/sprites/detailer/. Units = design units (figure ~266 tall).", "",
             "const PARTS := {"]
    for k, (px, py, w, h) in info.items():
        lines.append(f'\t"{k}": {{"pivot": Vector2({px:.2f}, {py:.2f}), "size": Vector2({w}, {h})}},')
    lines.append("}")
    lines.append("")
    lines.append("const SKEL := {")
    for k, v in SKEL.items():
        lines.append(f'\t"{k}": {gd_value(v)},')
    lines.append("}")
    lines.append("")
    lines.append("## torso silhouettes (torso-local, around the hip pivot), used to hide the sleeve's ink where the")
    lines.append("## shoulder blends into the body")
    for key in ("34", "F"):
        pts = sample_path(TORSO_D[key])
        if pts and pts[0] == pts[-1]:
            pts = pts[:-1]
        lines.append(f"const TORSO_{key} := [" + ", ".join(f"Vector2({x:.1f}, {y - hip:.1f})" for x, y in pts) + "]")
    open(os.path.join(PROJ, "scripts/detailer_parts.gd"), "w").write("\n".join(lines) + "\n")
    print(json.dumps(info, indent=0))
