"""Detailer character prototype — parametric SVG parts.

Every body part is its own <g> with an id, so the same parts can later be cut out and rigged.
Coordinates: x = 0 is the body centre, y grows down, feet on GROUND.
"""
import math, random

INK = "#1d1b2b"
OUT = 6.0          # outline width at 300px tall
GROUND = 300.0
BLINK = False      # draw closed eyes (for the blink frame)


def f(v):
    return f"{v:.1f}"


def P(*pts):
    return " ".join(f"{f(x)} {f(y)}" for x, y in pts)


# ---------- helpers ----------
_uid = [0]


def uid(prefix="c"):
    _uid[0] += 1
    return f"{prefix}{_uid[0]}"


def shaded(d, base, shade, dx=-7, dy=-6, light=None, ldx=-4, ldy=-4, lw=None, stroke=True, sw=OUT, extra=""):
    """Cel-shaded shape: dark base, the lit area is the shape shifted towards the light (top-left),
    clipped to the shape -> a shadow rim on the bottom-right. Optional highlight stripe."""
    cid = uid()
    s = f'<clipPath id="{cid}"><path d="{d}"/></clipPath>'
    s += f'<path d="{d}" fill="{shade}"/>'
    s += f'<g clip-path="url(#{cid})"><path d="{d}" fill="{base}" transform="translate({dx},{dy})"/>'
    if light:
        s += f'<path d="{d}" fill="none" stroke="{light}" stroke-width="{lw or 4}" stroke-linecap="round" transform="translate({ldx},{ldy})" opacity="0.55" stroke-dasharray="0" />'
    s += extra
    s += '</g>'
    if stroke:
        s += f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>'
    return s


def limb(a, b, wa, wb, bulge=0.0, bulge_in=None, cap_a=True):
    """Closed path for a limb segment from a to b, widths wa/wb, outer side bulges by `bulge`."""
    if bulge_in is None:
        bulge_in = bulge * 0.4
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay) or 1
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux
    ha, hb = wa / 2, wb / 2
    p1 = (ax + nx * ha, ay + ny * ha)
    p2 = (bx + nx * hb, by + ny * hb)
    p3 = (bx - nx * hb, by - ny * hb)
    p4 = (ax - nx * ha, ay - ny * ha)
    c1 = (ax + ux * L * 0.3 + nx * (ha + bulge), ay + uy * L * 0.3 + ny * (ha + bulge))
    c2 = (ax + ux * L * 0.7 + nx * (hb + bulge * 0.8), ay + uy * L * 0.7 + ny * (hb + bulge * 0.8))
    c3 = (ax + ux * L * 0.7 - nx * (hb + bulge_in * 0.8), ay + uy * L * 0.7 - ny * (hb + bulge_in * 0.8))
    c4 = (ax + ux * L * 0.3 - nx * (ha + bulge_in), ay + uy * L * 0.3 - ny * (ha + bulge_in))
    d = f"M {P(p1)} C {P(c1, c2, p2)} A {f(hb)} {f(hb)} 0 0 0 {P(p3)} C {P(c3, c4, p4)}"
    d += f" A {f(ha)} {f(ha)} 0 0 0 {P(p1)} Z" if cap_a else " Z"
    return d


def ellipse_d(cx, cy, rx, ry):
    return f"M {f(cx - rx)} {f(cy)} A {f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)} A {f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)} Z"


def mirror_x(pts):
    return [(-x, y) for x, y in pts]


# ---------- variants ----------
SKIN = ("#d9a174", "#b97c52")          # base, shade
HAIR = ("#2b1d14", "#1a110b")

VARIANTS = {
    "A": dict(name="A · The Bulldog", head=1.0, S=84, W=50, torso=82, legs=50, neck=26,
              hair="quiff", shirt=("#f07a2e", "#c45a1a"), logo="#ffffff", sleeve=True,
              pants=("#4b505c", "#363a44"), boots=("#9c6a3e", "#734b29"), gloves=("#2b2e36", "#1c1e24", "#5a6070")),
    "B": dict(name="B · The Tradie", head=0.86, S=74, W=44, torso=92, legs=66, neck=24,
              hair="buzz", shirt=("#f07a2e", "#c45a1a"), logo="#ffffff", sleeve=True,
              pants=("#2f3e5c", "#212c43"), boots=("#3a3533", "#24201f"), gloves=("#2b2e36", "#1c1e24", "#5a6070")),
    "C": dict(name="C · The Brick", head=1.08, S=86, W=58, torso=78, legs=44, neck=30,
              hair="flat", shirt=("#3c424c", "#2a2f37"), logo="#ffc93c", sleeve=False,
              pants=("#a38a5f", "#7f6a45"), boots=("#6b4426", "#4b2f19"), gloves=("#2f7fe0", "#1f5fb0", "#8cc0ff")),
}


def layout(v):
    hs = v["head"]
    boot_h = 22
    ank = GROUND - boot_h + 4
    hip = ank - v["legs"]
    sy = hip - v["torso"]          # shoulder line
    head_h = 112 * hs
    head_w = 50 * hs               # half width at the cheeks
    chin = sy + 10
    top = chin - head_h
    return dict(hs=hs, ank=ank, hip=hip, sy=sy, chin=chin, top=top, hh=head_h, hw=head_w, boot_h=boot_h)


# ---------- head ----------
def head_front(v, L, cx=0.0, mood="mean"):
    hs, top, chin, hw = L["hs"], L["top"], L["chin"], L["hw"]
    hh = L["hh"]
    y = lambda k: top + hh * k
    jw = hw * 1.06                  # jaw half width (thick jaw)
    tw = hw * 0.90                  # temple
    out = []
    # ears
    for s in (-1, 1):
        ed = ellipse_d(cx + s * (hw + 2), y(0.58), 9 * hs, 13 * hs)
        out.append(shaded(ed, SKIN[0], SKIN[1], dx=-3, dy=-3))
        out.append(f'<path d="M {f(cx + s*(hw+1))} {f(y(0.52))} q {f(s*4*hs)} {f(6*hs)} 0 {f(14*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="3" stroke-linecap="round"/>')
    d = (f"M {f(cx)} {f(top)} C {f(cx + hw*0.62)} {f(top)} {f(cx + tw)} {f(y(0.12))} {f(cx + tw)} {f(y(0.32))} "
         f"C {f(cx + tw + 2)} {f(y(0.45))} {f(cx + hw)} {f(y(0.52))} {f(cx + hw)} {f(y(0.62))} "
         f"C {f(cx + hw)} {f(y(0.78))} {f(cx + jw)} {f(y(0.86))} {f(cx + jw*0.80)} {f(y(0.93))} "
         f"C {f(cx + jw*0.62)} {f(y(1.0))} {f(cx + hw*0.42)} {f(chin)} {f(cx)} {f(chin)} "
         f"C {f(cx - hw*0.42)} {f(chin)} {f(cx - jw*0.62)} {f(y(1.0))} {f(cx - jw*0.80)} {f(y(0.93))} "
         f"C {f(cx - jw)} {f(y(0.86))} {f(cx - hw)} {f(y(0.78))} {f(cx - hw)} {f(y(0.62))} "
         f"C {f(cx - hw)} {f(y(0.52))} {f(cx - tw - 2)} {f(y(0.45))} {f(cx - tw)} {f(y(0.32))} "
         f"C {f(cx - tw)} {f(y(0.12))} {f(cx - hw*0.62)} {f(top)} {f(cx)} {f(top)} Z")
    # stubble: shaded jaw area + dots
    stub = (f"M {f(cx - hw + 1)} {f(y(0.66))} C {f(cx - hw + 4)} {f(y(0.90))} {f(cx - hw*0.4)} {f(chin - 1)} {f(cx)} {f(chin - 1)} "
            f"C {f(cx + hw*0.4)} {f(chin - 1)} {f(cx + hw - 4)} {f(y(0.90))} {f(cx + hw - 1)} {f(y(0.66))} "
            f"C {f(cx + hw*0.62)} {f(y(0.74))} {f(cx + hw*0.35)} {f(y(0.70))} {f(cx)} {f(y(0.71))} "
            f"C {f(cx - hw*0.35)} {f(y(0.70))} {f(cx - hw*0.62)} {f(y(0.74))} {f(cx - hw + 1)} {f(y(0.66))} Z")
    rng = random.Random(7)
    dots = ""
    for _ in range(int(70 * hs)):
        px = rng.uniform(-hw * 0.9, hw * 0.9)
        py = rng.uniform(y(0.70), chin - 4)
        # keep inside the jaw roughly and out of the mouth
        if abs(px) > hw * (0.95 - 0.5 * max(0, (py - y(0.85)) / (chin - y(0.85)))):
            continue
        if abs(px) < 14 * hs and abs(py - y(0.84)) < 5 * hs:
            continue
        dots += f'<circle cx="{f(cx + px)}" cy="{f(py)}" r="{f(1.3*hs)}" fill="#6b4a33" opacity="0.55"/>'
    extra = f'<path d="{stub}" fill="#8a6247" opacity="0.28"/>' + dots
    out.append(shaded(d, SKIN[0], SKIN[1], dx=-9, dy=-6, extra=extra))
    out.append(face_front(v, L, cx, mood))
    out.append(hair_front(v, L, cx))
    return "".join(out)


def hunter_eye(ex, ey, hs, sc, side, iris_dx=0.0):
    """Hunter eye (Hamza's sketch, 19 Oct): a straight, level brow sits low across the eye and hides its
    top half, so you only see the lower half of the eye + iris. side -1 = image-left eye.
    sc squashes it sideways for the far eye in 3/4 view."""
    rx = 11.5 * hs * sc
    yu = ey - 6.0 * hs            # (hidden) top of the eye
    yl = ey + 8.2 * hs            # lowest point of the lower lid
    I = (ex - side * rx, ey + 0.4 * hs)     # inner corner
    O = (ex + side * rx, ey - 0.2 * hs)     # outer corner
    eye = (f"M {P(I)} C {f(I[0] + side*rx*0.45)} {f(yu)} {f(O[0] - side*rx*0.55)} {f(yu)} {P(O)} "
           f"C {f(O[0] - side*rx*0.15)} {f(yl + 3.0*hs)} {f(I[0] + side*rx*0.45)} {f(yl + 3.4*hs)} {P(I)} Z")
    cid = uid("e")
    if BLINK:
        s = (f'<path d="M {P(I)} Q {f(ex)} {f(ey + 5.5*hs)} {P(O)}" fill="none" stroke="{INK}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>')
        return s + _brow(ex, ey, hs, rx, side)
    s = f'<clipPath id="{cid}"><path d="{eye}"/></clipPath>'
    s += f'<path d="{eye}" fill="#f6f2ec"/>'
    ix = ex + iris_dx * hs
    iy = ey + 1.6 * hs
    s += (f'<g clip-path="url(#{cid})">'
          f'<ellipse cx="{f(ix)}" cy="{f(iy)}" rx="{f(6.8*hs*min(1.0, sc + 0.2))}" ry="{f(6.8*hs)}" fill="#6b4a2c"/>'
          f'<ellipse cx="{f(ix)}" cy="{f(iy)}" rx="{f(4.2*hs*min(1.0, sc + 0.2))}" ry="{f(4.2*hs)}" fill="#4a3220"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(3.0*hs)}" fill="{INK}"/>'
          f'<circle cx="{f(ix - 2.6*hs)}" cy="{f(iy + 1.4*hs)}" r="{f(1.4*hs)}" fill="#ffffff"/>'
          # shadow the brow casts on the eye
          f'<rect x="{f(ex - rx*1.3)}" y="{f(ey)}" width="{f(rx*2.6)}" height="{f(1.4*hs)}" fill="#000000" opacity="0.16"/>'
          f'</g>')
    s += f'<path d="{eye}" fill="none" stroke="{INK}" stroke-width="{f(2.0*hs)}" stroke-linejoin="round"/>'
    return s + _brow(ex, ey, hs, rx, side)


def _brow(ex, ey, hs, rx, side):
    # brow: straight and level; its bottom edge runs across the middle of the eye (hides the top half)
    s = ""
    bb = ey + 0.5 * hs            # brow bottom = the visible top of the eye
    th = 5.6 * hs   # v4: trimmed (was 7.6)
    bi = ex - side * rx * 1.18    # inner end
    bo = ex + side * rx * 1.28    # outer end
    brow = (f"M {f(bi)} {f(bb)} L {f(bi)} {f(bb - th + 1.4*hs)} Q {f(bi)} {f(bb - th)} {f(bi + side*2*hs)} {f(bb - th)} "
            f"L {f(bo - side*3*hs)} {f(bb - th + 0.4*hs)} Q {f(bo + side*0.6*hs)} {f(bb - th + 1.2*hs)} {f(bo)} {f(bb)} Z")
    s += f'<path d="{brow}" fill="{HAIR[0]}" stroke="{INK}" stroke-width="{f(2.2*hs)}" stroke-linejoin="round"/>'
    return s


def face_front(v, L, cx, mood):
    hs, top, hh, hw = L["hs"], L["top"], L["hh"], L["hw"]
    y = lambda k: top + hh * k
    s = ""
    ey = y(0.50)
    for side in (-1, 1):
        s += hunter_eye(cx + side * hw * 0.40, ey, hs, 1.0, side)
    # nose bridge: a defined straight bridge between the brows (shade on the lit side's opposite)
    s += f'<path d="M {f(cx + 3*hs)} {f(ey - 2*hs)} C {f(cx + 4*hs)} {f(ey + 8*hs)} {f(cx + 6*hs)} {f(y(0.64))} {f(cx + 8*hs)} {f(y(0.68))}" fill="none" stroke="{SKIN[1]}" stroke-width="{f(3*hs)}" stroke-linecap="round" opacity="0.8"/>'
    # nose: straight bridge (shade line added above) + rounded tip with nostril wings
    ny = y(0.69)
    s += f'<ellipse cx="{f(cx + 1*hs)}" cy="{f(ny + 5.5*hs)}" rx="{f(9*hs)}" ry="{f(3*hs)}" fill="{SKIN[1]}" opacity="0.6"/>'
    s += f'<ellipse cx="{f(cx - 1.5*hs)}" cy="{f(ny - 1*hs)}" rx="{f(3.5*hs)}" ry="{f(2.5*hs)}" fill="#ffffff" opacity="0.25"/>'
    for sd in (-1, 1):
        s += f'<path d="M {f(cx + sd*6*hs)} {f(ny - 3*hs)} C {f(cx + sd*11*hs)} {f(ny - 1*hs)} {f(cx + sd*11*hs)} {f(ny + 5*hs)} {f(cx + sd*5*hs)} {f(ny + 5*hs)}" fill="none" stroke="{INK}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
        s += f'<ellipse cx="{f(cx + sd*3.3*hs)}" cy="{f(ny + 4.6*hs)}" rx="{f(2.1*hs)}" ry="{f(1.2*hs)}" fill="#5a3a28"/>'
    s += f'<path d="M {f(cx - 3*hs)} {f(ny + 6*hs)} Q {f(cx)} {f(ny + 7*hs)} {f(cx + 3*hs)} {f(ny + 6*hs)}" fill="none" stroke="{INK}" stroke-width="{f(2*hs)}" stroke-linecap="round"/>'
    # mouth
    my = y(0.835)
    if mood == "grin":
        m = f"M {f(cx - 15*hs)} {f(my - 3*hs)} C {f(cx - 8*hs)} {f(my + 12*hs)} {f(cx + 8*hs)} {f(my + 12*hs)} {f(cx + 15*hs)} {f(my - 3*hs)} Z"
        s += f'<path d="{m}" fill="#5a1f1f" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        s += f'<path d="M {f(cx - 13*hs)} {f(my - 1.5*hs)} L {f(cx + 13*hs)} {f(my - 1.5*hs)} L {f(cx + 10*hs)} {f(my + 3*hs)} L {f(cx - 10*hs)} {f(my + 3*hs)} Z" fill="#ffffff"/>'
    else:
        s += f'<path d="M {f(cx - 12*hs)} {f(my + 0.5*hs)} C {f(cx - 5*hs)} {f(my - 0.5*hs)} {f(cx + 5*hs)} {f(my - 0.5*hs)} {f(cx + 12*hs)} {f(my + 1.5*hs)}" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>'
        s += f'<path d="M {f(cx - 6*hs)} {f(my + 6*hs)} C {f(cx - 2*hs)} {f(my + 8*hs)} {f(cx + 2*hs)} {f(my + 8*hs)} {f(cx + 6*hs)} {f(my + 6*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="2.5" stroke-linecap="round"/>'
    return s


def hair_front(v, L, cx):
    hs, top, hh, hw = L["hs"], L["top"], L["hh"], L["hw"]
    y = lambda k: top + hh * k
    st = v["hair"]
    tw = hw * 0.92
    if st == "quiff":
        d = (f"M {f(cx - tw - 2)} {f(y(0.40))} C {f(cx - tw - 6)} {f(y(0.10))} {f(cx - hw*0.5)} {f(top - 12*hs)} {f(cx + 2)} {f(top - 14*hs)} "
             f"C {f(cx + hw*0.55)} {f(top - 18*hs)} {f(cx + tw + 6)} {f(top - 4*hs)} {f(cx + tw + 2)} {f(y(0.40))} "
             f"L {f(cx + tw - 3)} {f(y(0.30))} C {f(cx + tw - 8)} {f(y(0.20))} {f(cx + hw*0.5)} {f(y(0.17))} {f(cx + hw*0.2)} {f(y(0.22))} "
             f"C {f(cx)} {f(y(0.16))} {f(cx - hw*0.4)} {f(y(0.24))} {f(cx - hw*0.65)} {f(y(0.21))} "
             f"C {f(cx - tw + 4)} {f(y(0.22))} {f(cx - tw + 2)} {f(y(0.30))} {f(cx - tw - 2)} {f(y(0.40))} Z")
    elif st == "buzz":
        d = (f"M {f(cx - tw - 1)} {f(y(0.40))} C {f(cx - tw - 3)} {f(y(0.08))} {f(cx - hw*0.55)} {f(top - 4*hs)} {f(cx)} {f(top - 4*hs)} "
             f"C {f(cx + hw*0.55)} {f(top - 4*hs)} {f(cx + tw + 3)} {f(y(0.08))} {f(cx + tw + 1)} {f(y(0.40))} "
             f"L {f(cx + tw - 4)} {f(y(0.30))} C {f(cx + hw*0.6)} {f(y(0.20))} {f(cx + hw*0.3)} {f(y(0.19))} {f(cx)} {f(y(0.20))} "
             f"C {f(cx - hw*0.3)} {f(y(0.19))} {f(cx - hw*0.6)} {f(y(0.20))} {f(cx - tw + 4)} {f(y(0.30))} Z")
    else:  # flat-top
        d = (f"M {f(cx - tw - 2)} {f(y(0.40))} L {f(cx - tw - 3)} {f(top + 2*hs)} C {f(cx - tw)} {f(top - 9*hs)} {f(cx + tw)} {f(top - 9*hs)} {f(cx + tw + 3)} {f(top + 2*hs)} "
             f"L {f(cx + tw + 2)} {f(y(0.40))} L {f(cx + tw - 3)} {f(y(0.30))} C {f(cx + hw*0.6)} {f(y(0.19))} {f(cx - hw*0.6)} {f(y(0.19))} {f(cx - tw + 3)} {f(y(0.30))} Z")
    s = shaded(d, HAIR[0], HAIR[1], dx=-5, dy=-5, light="#5a4332", ldx=0, ldy=0, lw=0.01)
    # a few strand lines / shine
    s += f'<path d="M {f(cx - hw*0.4)} {f(top - 2*hs)} q {f(hw*0.3)} {f(-6*hs)} {f(hw*0.6)} {f(-2*hs)}" stroke="#6a5240" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>'
    # sideburns
    for side in (-1, 1):
        sb = f"M {f(cx + side*(tw+1))} {f(y(0.36))} L {f(cx + side*(hw-1))} {f(y(0.58))} L {f(cx + side*(hw-7*hs))} {f(y(0.58))} L {f(cx + side*(tw-6*hs))} {f(y(0.34))} Z"
        s += f'<path d="{sb}" fill="{HAIR[0]}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
    return s


# ---------- body (front) ----------
def body_front(v, L, pose="stand"):
    S, W, N = v["S"], v["W"], v["neck"]
    sy, hip, ank = L["sy"], L["hip"], L["ank"]
    out = {}
    # legs + boots
    leg = (f"M {f(-W + 2)} {f(hip - 2)} C {f(-W - 4)} {f(hip + 20)} {f(-W + 2)} {f(ank - 14)} {f(-W + 6)} {f(ank)} "
           f"L {f(-5)} {f(ank)} L {f(-3)} {f(hip + 14)} L {f(3)} {f(hip + 14)} L {f(5)} {f(ank)} "
           f"L {f(W - 6)} {f(ank)} C {f(W - 2)} {f(ank - 14)} {f(W + 4)} {f(hip + 20)} {f(W - 2)} {f(hip - 2)} Z")
    pk = ""
    for side in (-1, 1):  # cargo pockets
        px = side * (W - 4) - (14 if side > 0 else 0)
        pk += f'<rect x="{f(side*(W-2) - (16 if side>0 else 0))}" y="{f(hip + 16)}" width="16" height="{f(max(14, (ank-hip)*0.42))}" rx="3" fill="none" stroke="{v["pants"][1]}" stroke-width="3"/>'
    out["legs"] = shaded(leg, v["pants"][0], v["pants"][1], dx=-8, dy=-2, extra=pk)
    boots = ""
    for side in (-1, 1):
        x0 = side * 4 if side > 0 else -W - 6
        bw = W + 2
        bd = (f"M {f(x0)} {f(GROUND)} L {f(x0)} {f(ank - 8)} C {f(x0)} {f(ank - 14)} {f(x0 + bw)} {f(ank - 14)} {f(x0 + bw)} {f(ank - 8)} "
              f"L {f(x0 + bw + 2)} {f(GROUND)} Z")
        boots += shaded(bd, v["boots"][0], v["boots"][1], dx=-5, dy=-3,
                        extra=f'<rect x="{f(x0 - 4)}" y="{f(GROUND - 7)}" width="{f(bw + 10)}" height="8" fill="#2a2420"/>')
    out["boots"] = boots
    # neck
    nd = f"M {f(-N + 2)} {f(L['chin'] - 30)} L {f(N - 2)} {f(L['chin'] - 30)} L {f(N + 4)} {f(sy + 4)} L {f(-N - 4)} {f(sy + 4)} Z"
    out["neck"] = shaded(nd, SKIN[0], SKIN[1], dx=-4, dy=6)
    # torso (tee / singlet)
    td = (f"M {f(-N - 2)} {f(sy - 8)} C {f(-N - 18)} {f(sy - 6)} {f(-S + 14)} {f(sy - 4)} {f(-S)} {f(sy + 14)} "
          f"C {f(-S - 6)} {f(sy + 40)} {f(-W - 10)} {f(hip - 30)} {f(-W - 2)} {f(hip + 6)} "
          f"L {f(W + 2)} {f(hip + 6)} C {f(W + 10)} {f(hip - 30)} {f(S + 6)} {f(sy + 40)} {f(S)} {f(sy + 14)} "
          f"C {f(S - 14)} {f(sy - 4)} {f(N + 18)} {f(sy - 6)} {f(N + 2)} {f(sy - 8)} Z")
    detail = ""
    # collar
    if v["sleeve"]:
        detail += f'<path d="M {f(-N - 1)} {f(sy - 8)} C {f(-N + 4)} {f(sy + 12)} {f(N - 4)} {f(sy + 12)} {f(N + 1)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    else:  # singlet: deep scoop + skin shoulders handled by arms
        detail += f'<path d="M {f(-N - 4)} {f(sy - 8)} C {f(-N + 2)} {f(sy + 22)} {f(N - 2)} {f(sy + 22)} {f(N + 4)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    # pec lines + ab hint
    for side in (-1, 1):
        detail += f'<path d="M {f(side*(S-24))} {f(sy + 36)} C {f(side*(S-36))} {f(sy + 50)} {f(side*10)} {f(sy + 50)} {f(side*3)} {f(sy + 38)}" fill="none" stroke="{v["shirt"][1]}" stroke-width="3.5" stroke-linecap="round"/>'
    # logo: a droplet with a shine
    lx, ly = -S * 0.42, sy + 24
    detail += f'<path d="M {f(lx)} {f(ly - 9)} C {f(lx + 6)} {f(ly - 1)} {f(lx + 7)} {f(ly + 4)} {f(lx)} {f(ly + 6)} C {f(lx - 7)} {f(ly + 4)} {f(lx - 6)} {f(ly - 1)} {f(lx)} {f(ly - 9)} Z" fill="{v["logo"]}" stroke="{INK}" stroke-width="2"/>'
    out["torso"] = shaded(td, v["shirt"][0], v["shirt"][1], dx=-12, dy=-4, extra=detail)
    # belt
    bd = f"M {f(-W - 3)} {f(hip - 2)} L {f(W + 3)} {f(hip - 2)} L {f(W + 2)} {f(hip + 9)} L {f(-W - 2)} {f(hip + 9)} Z"
    out["belt"] = (f'<path d="{bd}" fill="#2b2522" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
                   f'<rect x="-8" y="{f(hip - 1)}" width="16" height="9" rx="2" fill="#c9b27a" stroke="{INK}" stroke-width="2.5"/>')
    return out


def bez(p0, p1, p2, p3, t):
    m = 1 - t
    return (m**3*p0[0] + 3*m*m*t*p1[0] + 3*m*t*t*p2[0] + t**3*p3[0],
            m**3*p0[1] + 3*m*m*t*p1[1] + 3*m*t*t*p2[1] + t**3*p3[1])


def attached_sleeve(v, sh, el, side, anchor, skin=False, hem_t=0.42):
    """Sleeve that grows out of the torso: its top edge starts ON the torso's shoulder line (anchor) and
    swells over the deltoid; only the outer edge, hem and inner fold are inked, so there is no seam ball."""
    L = math.hypot(el[0] - sh[0], el[1] - sh[1]) or 1
    ux, uy = (el[0] - sh[0]) / L, (el[1] - sh[1]) / L
    no = (uy, -ux) if side > 0 else (-uy, ux)          # outward normal
    H = (sh[0] + ux * L * hem_t, sh[1] + uy * L * hem_t)
    H1 = (H[0] + no[0] * 24, H[1] + no[1] * 24)
    H2 = (H[0] - no[0] * 22, H[1] - no[1] * 22)
    A = (sh[0] + ux * L * 0.06 - no[0] * 19, sh[1] + uy * L * 0.06 - no[1] * 19)
    Pin = (sh[0] - no[0] * 10 - ux * 16, sh[1] - no[1] * 10 - uy * 16)
    c1 = (sh[0] + no[0] * 38 - ux * 4, sh[1] + no[1] * 38 - uy * 4)
    c2 = (H1[0] - ux * L * 0.14 + no[0] * 3, H1[1] - uy * L * 0.14 + no[1] * 3)
    hem_mid = ((H1[0] + H2[0]) / 2 + ux * 2.5, (H1[1] + H2[1]) / 2 + uy * 2.5)
    fill_d = f"M {P(anchor)} C {P(c1, c2, H1)} Q {P(hem_mid, H2)} L {P(A)} L {P(Pin)} Z"
    line_d = f"M {P(anchor)} C {P(c1, c2, H1)} Q {P(hem_mid, H2)} L {P(A)}"
    base, shade = (SKIN if skin else v["shirt"])
    cid = uid()
    tx, ty = -no[0] * 5, -no[1] * 5 - 3
    out = f'<clipPath id="{cid}"><path d="{fill_d}"/></clipPath>'
    out += f'<path d="{fill_d}" fill="{shade}"/>'
    out += f'<g clip-path="url(#{cid})"><path d="{fill_d}" fill="{base}" transform="translate({f(tx)},{f(ty)})"/></g>'
    if not skin:
        # hem band
        hb1 = (H1[0] - ux * 5, H1[1] - uy * 5); hb2 = (H2[0] - ux * 5, H2[1] - uy * 5)
        out += f'<path d="M {P(hb1)} L {P(hb2)}" stroke="{shade}" stroke-width="2.5" stroke-linecap="round"/>'
    out += f'<path d="{line_d}" fill="none" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round" stroke-linecap="round"/>'
    return out


def arm(v, sh, el, wr, side=1, sleeve=True, fist=True, hand_r=17.0, glove_cut=0.68, hold=None, anchor=None):
    """Upper arm sh->el, forearm el->wr, gloved fist at the wrist."""
    s = ""
    ua = limb(sh, el, 34, 28, bulge=7 * side * 0, bulge_in=0)
    ua = limb(sh, el, 42, 30, bulge=9)
    fa = limb(el, wr, 31, 24, bulge=6)
    # forearm skin then glove over the end
    s += shaded(fa, SKIN[0], SKIN[1], dx=-5, dy=-4)
    gx = el[0] + (wr[0] - el[0]) * glove_cut
    gy = el[1] + (wr[1] - el[1]) * glove_cut
    gd = limb((gx, gy), wr, 27, 23, bulge=2, cap_a=False)
    s += shaded(gd, v["gloves"][0], v["gloves"][1], dx=-4, dy=-4)
    # cuff ring
    L_ = math.hypot(wr[0] - el[0], wr[1] - el[1])
    ux, uy = (wr[0] - el[0]) / L_, (wr[1] - el[1]) / L_
    nx, ny = -uy, ux
    s += f'<path d="M {f(gx + nx*15)} {f(gy + ny*15)} L {f(gx - nx*15)} {f(gy - ny*15)}" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
    s += f'<path d="M {f(gx + nx*13 + ux*3)} {f(gy + ny*13 + uy*3)} L {f(gx - nx*13 + ux*3)} {f(gy - ny*13 + uy*3)}" stroke="{v["gloves"][2]}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>'
    # upper arm
    s += shaded(ua, SKIN[0], SKIN[1], dx=-6, dy=-4)
    if sleeve:
        s += attached_sleeve(v, sh, el, side, anchor or (sh[0] - side * 4, sh[1] - 14))
    elif anchor:
        # singlet: a skin-coloured deltoid that grows out of the trap line
        s += attached_sleeve(v, sh, el, side, anchor, skin=True)
    # fist
    hx, hy = wr[0] + ux * hand_r * 0.55, wr[1] + uy * hand_r * 0.55
    fd = ellipse_d(hx, hy, hand_r, hand_r * 0.92)
    knuckles = ""
    for k in (-1, 0, 1):
        kx, ky = hx + nx * k * 6.5 + ux * 6, hy + ny * k * 6.5 + uy * 6
        knuckles += f'<path d="M {f(kx - ux*4)} {f(ky - uy*4)} L {f(kx)} {f(ky)}" stroke="{v["gloves"][1]}" stroke-width="2.5" stroke-linecap="round"/>'
    s += shaded(fd, v["gloves"][0], v["gloves"][1], dx=-4, dy=-4,
                extra=knuckles + f'<circle cx="{f(hx - 5)}" cy="{f(hy - 6)}" r="3.2" fill="{v["gloves"][2]}" opacity="0.8"/>')
    if hold:
        s += hold(hx, hy)
    return s


def front_figure(v, mood="mean", arms_pose="stand"):
    L = layout(v)
    S, sy = v["S"], L["sy"]
    b = body_front(v, L)
    parts = []
    parts.append(b["legs"]); parts.append(b["boots"])
    parts.append(b["neck"])
    parts.append(b["torso"])
    parts.append(b["belt"])
    for side in (-1, 1):
        sh = (side * (S - 12), sy + 18)
        if arms_pose == "cheer":
            el = (side * (S + 30), sy + 4)
            wr = (side * (S + 4), sy - 40)
        else:
            el = (side * (S + 6), sy + 58)
            wr = (side * (S + 2), sy + 96)
        N = v["neck"]
        anc = bez((S, sy + 14), (S - 14, sy - 4), (N + 18, sy - 6), (N + 2, sy - 8), 0.30)
        parts.append(arm(v, sh, el, wr, side, sleeve=v["sleeve"], anchor=(side * anc[0], anc[1])))
    parts.append(head_front(v, L, 0.0, mood))
    return "".join(parts)


# ---------- 3/4 view facing right ----------
def head_34(v, L, cx=0.0, mood="mean"):
    hs, top, chin, hw, hh = L["hs"], L["top"], L["chin"], L["hw"], L["hh"]
    y = lambda k: top + hh * k
    fc = cx + hw * 0.28          # face centre line (turned towards +x)
    out = []
    # near ear (left side)
    ed = ellipse_d(cx - hw * 0.62, y(0.58), 9 * hs, 13 * hs)
    back = cx - hw * 1.02
    front = cx + hw * 0.98
    d = (f"M {f(cx - hw*0.05)} {f(top)} C {f(cx + hw*0.6)} {f(top)} {f(front - 2)} {f(y(0.12))} {f(front - 3)} {f(y(0.34))} "
         f"C {f(front - 2)} {f(y(0.40))} {f(front + 3)} {f(y(0.43))} {f(front + 2)} {f(y(0.49))} "       # brow ridge
         f"C {f(front)} {f(y(0.56))} {f(front - 3)} {f(y(0.60))} {f(front - 1)} {f(y(0.66))} "            # cheek
         f"C {f(front + 1)} {f(y(0.80))} {f(front)} {f(y(0.92))} {f(fc + hw*0.45)} {f(chin)} "                # jaw to chin
         f"C {f(fc)} {f(chin + 2)} {f(cx - hw*0.35)} {f(chin - 2)} {f(cx - hw*0.62)} {f(y(0.86))} "           # under jaw
         f"C {f(cx - hw*0.80)} {f(y(0.80))} {f(back)} {f(y(0.70))} {f(back)} {f(y(0.48))} "
         f"C {f(back)} {f(y(0.16))} {f(cx - hw*0.65)} {f(top)} {f(cx - hw*0.05)} {f(top)} Z")
    stub = (f"M {f(cx - hw*0.55)} {f(y(0.66))} C {f(cx - hw*0.5)} {f(y(0.92))} {f(fc - 4)} {f(chin)} {f(fc + hw*0.45)} {f(chin - 1)} "
            f"C {f(front - 2)} {f(y(0.92))} {f(front)} {f(y(0.78))} {f(front - 2)} {f(y(0.67))} "
            f"C {f(fc + hw*0.4)} {f(y(0.73))} {f(fc - hw*0.1)} {f(y(0.71))} {f(cx - hw*0.55)} {f(y(0.66))} Z")
    rng = random.Random(11)
    dots = ""
    for _ in range(int(64 * hs)):
        px = rng.uniform(cx - hw * 0.55, front - 3)
        py = rng.uniform(y(0.70), chin - 4)
        if px < cx - hw * 0.5 + (py - y(0.70)) * 0.4:
            continue
        if px > front - 4 - max(0, (py - y(0.88))) * 1.6:
            continue
        if abs(px - (fc + 4)) < 11 * hs and abs(py - y(0.84)) < 5 * hs:
            continue
        dots += f'<circle cx="{f(px)}" cy="{f(py)}" r="{f(1.3*hs)}" fill="#6b4a33" opacity="0.55"/>'
    extra = f'<path d="{stub}" fill="#8a6247" opacity="0.28"/>' + dots
    out.append(shaded(d, SKIN[0], SKIN[1], dx=-9, dy=-6, extra=extra))
    out.append(shaded(ed, SKIN[0], SKIN[1], dx=-3, dy=-3))
    out.append(f'<path d="M {f(cx - hw*0.62 - 2)} {f(y(0.52))} q {f(-4*hs)} {f(6*hs)} 0 {f(14*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="3" stroke-linecap="round"/>')
    # face
    ey = y(0.50)
    s = ""
    s += hunter_eye(fc - hw * 0.30, ey, hs, 1.0, -1, iris_dx=2.2)
    s += hunter_eye(fc + hw * 0.52, ey, hs, 0.66, 1, iris_dx=2.0)
    # nose: points to the right, sits on the face line
    nx_ = fc + hw * 0.18
    ny = y(0.69)
    nose = (f"M {f(nx_ + 1)} {f(ey + 6*hs)} C {f(nx_ + 3*hs)} {f(ny - 9*hs)} {f(nx_ + 11*hs)} {f(ny - 4*hs)} {f(nx_ + 10*hs)} {f(ny + 2*hs)} "
            f"C {f(nx_ + 9*hs)} {f(ny + 7*hs)} {f(nx_ + 1*hs)} {f(ny + 7*hs)} {f(nx_ - 5*hs)} {f(ny + 4*hs)}")
    s += f'<path d="{nose} Z" fill="{SKIN[1]}" opacity="0.45"/>'
    s += f'<path d="{nose}" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
    my = y(0.835)
    mx = fc + hw * 0.12
    if mood == "grin":
        m = f"M {f(mx - 13*hs)} {f(my - 3*hs)} C {f(mx - 6*hs)} {f(my + 12*hs)} {f(mx + 8*hs)} {f(my + 12*hs)} {f(mx + 13*hs)} {f(my - 3*hs)} Z"
        s += f'<path d="{m}" fill="#5a1f1f" stroke="{INK}" stroke-width="3"/>'
        s += f'<path d="M {f(mx - 11*hs)} {f(my - 1.5*hs)} L {f(mx + 11*hs)} {f(my - 1.5*hs)} L {f(mx + 8.5*hs)} {f(my + 3*hs)} L {f(mx - 8.5*hs)} {f(my + 3*hs)} Z" fill="#ffffff"/>'
    else:
        s += f'<path d="M {f(mx - 11*hs)} {f(my + 0.5*hs)} C {f(mx - 4*hs)} {f(my - 0.5*hs)} {f(mx + 5*hs)} {f(my - 0.5*hs)} {f(mx + 11*hs)} {f(my + 1.5*hs)}" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>'
        s += f'<path d="M {f(mx - 4*hs)} {f(my + 6*hs)} C {f(mx)} {f(my + 8*hs)} {f(mx + 4*hs)} {f(my + 8*hs)} {f(mx + 8*hs)} {f(my + 6*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="2.5" stroke-linecap="round"/>'
    out.append(s)
    # hair (3/4): covers the back of the head down to the ear
    tw = hw
    st = v["hair"]
    lift = {"quiff": 14, "buzz": 4, "flat": 9}[st] * hs
    if st == "flat":
        d = (f"M {f(back - 1)} {f(y(0.52))} L {f(back - 2)} {f(top + 2*hs)} C {f(back)} {f(top - lift)} {f(front - 6)} {f(top - lift)} {f(front - 1)} {f(top + 2*hs)} "
             f"L {f(front - 3)} {f(y(0.30))} C {f(fc + hw*0.3)} {f(y(0.18))} {f(cx - hw*0.2)} {f(y(0.22))} {f(cx - hw*0.42)} {f(y(0.40))} "
             f"L {f(cx - hw*0.52)} {f(y(0.52))} Z")
    else:
        q = lift
        d = (f"M {f(back - 1)} {f(y(0.52))} C {f(back - 5)} {f(y(0.12))} {f(cx - hw*0.5)} {f(top - q*0.6)} {f(cx + hw*0.1)} {f(top - q*0.8)} "
             f"C {f(cx + hw*0.7)} {f(top - q*1.15)} {f(front + 4)} {f(top - q*0.2)} {f(front - 2)} {f(y(0.28))} "
             f"C {f(fc + hw*0.45)} {f(y(0.18))} {f(fc)} {f(y(0.20))} {f(cx - hw*0.05)} {f(y(0.22))} "
             f"C {f(cx - hw*0.3)} {f(y(0.24))} {f(cx - hw*0.40)} {f(y(0.34))} {f(cx - hw*0.44)} {f(y(0.52))} Z")
    out.append(shaded(d, HAIR[0], HAIR[1], dx=-5, dy=-5))
    out.append(f'<path d="M {f(cx - hw*0.3)} {f(top - 2*hs)} q {f(hw*0.3)} {f(-7*hs)} {f(hw*0.65)} {f(-3*hs)}" stroke="#6a5240" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
    sb = f"M {f(cx - hw*0.42)} {f(y(0.38))} L {f(cx - hw*0.36)} {f(y(0.60))} L {f(cx - hw*0.48)} {f(y(0.60))} L {f(cx - hw*0.52)} {f(y(0.40))} Z"
    out.append(f'<path d="{sb}" fill="{HAIR[0]}" stroke="{INK}" stroke-width="2"/>')
    return "".join(out)


def mitt(hx, hy):
    """Fluffy blue wash mitt around the hand."""
    s = ""
    rng = random.Random(3)
    blobs = [(hx + rng.uniform(-14, 14), hy + rng.uniform(-14, 14), rng.uniform(8, 11)) for _ in range(11)]
    for bx, by, r in blobs:
        s += f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(r + 3)}" fill="{INK}"/>'
    for bx, by, r in blobs:
        s += f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(r)}" fill="#7fd3ff"/>'
    for bx, by, r in blobs[:6]:
        s += f'<circle cx="{f(bx - 2)}" cy="{f(by - 3)}" r="{f(r*0.45)}" fill="#c9f0ff"/>'
    return s


def towel(hx, hy):
    d = f"M {f(hx - 10)} {f(hy + 2)} L {f(hx + 10)} {f(hy + 2)} L {f(hx + 13)} {f(hy + 34)} L {f(hx - 6)} {f(hy + 36)} Z"
    return (f'<path d="{d}" fill="#ffcc33" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
            f'<path d="M {f(hx - 4)} {f(hy + 12)} L {f(hx + 8)} {f(hy + 12)} M {f(hx - 3)} {f(hy + 22)} L {f(hx + 9)} {f(hy + 22)}" stroke="#e0a800" stroke-width="2.5"/>')


def figure_34(v, mood="mean"):
    """Working stance, turned towards the car on the right: far arm reaches with the wash mitt."""
    L = layout(v)
    S, W, N = v["S"], v["W"], v["neck"]
    sy, hip, ank = L["sy"], L["hip"], L["ank"]
    sh_far = (S * 0.55, sy + 14)
    sh_near = (-S * 0.82, sy + 18)
    parts = []
    # far arm (behind the torso), reaching forward-up with the mitt
    parts.append(arm(v, sh_far, (S * 0.55 + 38, sy + 30), (S * 0.55 + 70, sy + 4), 1, sleeve=v["sleeve"], hold=mitt))
    # far leg + boot (slightly behind, a step forward)
    fl = limb((W * 0.45, hip + 6), (W * 0.62 + 10, ank - 2), W * 0.95, W * 0.80, bulge=3)
    parts.append(shaded(fl, v["pants"][1], "#262a32", dx=-6, dy=-2))
    bx = W * 0.62 + 10
    bd = f"M {f(bx - 18)} {f(GROUND)} L {f(bx - 18)} {f(ank - 10)} C {f(bx - 18)} {f(ank - 16)} {f(bx + 10)} {f(ank - 16)} {f(bx + 14)} {f(ank - 6)} C {f(bx + 30)} {f(ank - 2)} {f(bx + 34)} {f(GROUND - 6)} {f(bx + 32)} {f(GROUND)} Z"
    parts.append(shaded(bd, v["boots"][1], "#2a1d12", dx=-4, dy=-3) + f'<rect x="{f(bx - 21)}" y="{f(GROUND - 7)}" width="56" height="8" rx="2" fill="#2a2420"/>')
    # near leg + boot
    nlx = -W * 0.45
    nl = limb((nlx, hip + 6), (nlx - 4, ank - 2), W * 1.0, W * 0.84, bulge=4)
    parts.append(shaded(nl, v["pants"][0], v["pants"][1], dx=-7, dy=-2,
                        extra=f'<rect x="{f(nlx - 18)}" y="{f(hip + 18)}" width="16" height="{f(max(14, (ank-hip)*0.42))}" rx="3" fill="none" stroke="{v["pants"][1]}" stroke-width="3"/>'))
    bx = nlx - 4
    bd = f"M {f(bx - 22)} {f(GROUND)} L {f(bx - 22)} {f(ank - 10)} C {f(bx - 22)} {f(ank - 16)} {f(bx + 12)} {f(ank - 16)} {f(bx + 16)} {f(ank - 6)} C {f(bx + 32)} {f(ank - 2)} {f(bx + 36)} {f(GROUND - 6)} {f(bx + 34)} {f(GROUND)} Z"
    parts.append(shaded(bd, v["boots"][0], v["boots"][1], dx=-5, dy=-3) + f'<rect x="{f(bx - 25)}" y="{f(GROUND - 7)}" width="62" height="8" rx="2" fill="#2a2420"/>')
    # neck
    nk = f"M {f(-N + 6)} {f(L['chin'] - 30)} L {f(N + 4)} {f(L['chin'] - 30)} L {f(N + 10)} {f(sy + 4)} L {f(-N - 2)} {f(sy + 4)} Z"
    parts.append(shaded(nk, SKIN[0], SKIN[1], dx=-4, dy=6))
    # torso turned: broad back on the left, chest pushing out to the right
    Sn, Sf = S * 0.98, S * 0.70
    td = (f"M {f(-N + 2)} {f(sy - 8)} C {f(-N - 16)} {f(sy - 6)} {f(-Sn + 14)} {f(sy - 4)} {f(-Sn)} {f(sy + 14)} "
          f"C {f(-Sn - 4)} {f(sy + 44)} {f(-W - 6)} {f(hip - 30)} {f(-W + 2)} {f(hip + 6)} "
          f"L {f(W * 0.9)} {f(hip + 6)} C {f(W + 6)} {f(hip - 26)} {f(Sf + 18)} {f(sy + 56)} {f(Sf + 16)} {f(sy + 30)} "
          f"C {f(Sf + 14)} {f(sy + 10)} {f(N + 22)} {f(sy - 6)} {f(N + 8)} {f(sy - 8)} Z")
    detail = ""
    if v["sleeve"]:
        detail += f'<path d="M {f(-N + 3)} {f(sy - 8)} C {f(-N + 8)} {f(sy + 10)} {f(N + 2)} {f(sy + 10)} {f(N + 8)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    else:
        detail += f'<path d="M {f(-N)} {f(sy - 8)} C {f(-N + 6)} {f(sy + 20)} {f(N + 4)} {f(sy + 20)} {f(N + 10)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    detail += f'<path d="M {f(Sf - 4)} {f(sy + 40)} C {f(Sf - 18)} {f(sy + 52)} {f(4)} {f(sy + 50)} {f(-6)} {f(sy + 38)}" fill="none" stroke="{v["shirt"][1]}" stroke-width="3.5" stroke-linecap="round"/>'
    lx, ly = Sf * 0.35, sy + 26
    detail += f'<path d="M {f(lx)} {f(ly - 9)} C {f(lx + 5)} {f(ly - 1)} {f(lx + 6)} {f(ly + 4)} {f(lx)} {f(ly + 6)} C {f(lx - 6)} {f(ly + 4)} {f(lx - 5)} {f(ly - 1)} {f(lx)} {f(ly - 9)} Z" fill="{v["logo"]}" stroke="{INK}" stroke-width="2"/>'
    parts.append(shaded(td, v["shirt"][0], v["shirt"][1], dx=-12, dy=-4, extra=detail))
    bd = f"M {f(-W + 1)} {f(hip - 2)} L {f(W * 0.92)} {f(hip - 2)} L {f(W * 0.9)} {f(hip + 9)} L {f(-W + 2)} {f(hip + 9)} Z"
    parts.append(f'<path d="{bd}" fill="#2b2522" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
                 f'<rect x="{f(W*0.3 - 7)}" y="{f(hip - 1)}" width="14" height="9" rx="2" fill="#c9b27a" stroke="{INK}" stroke-width="2.5"/>')
    # head
    parts.append(head_34(v, L, 6.0, mood))
    # near arm in front: bent, towel hanging from the fist
    Sn_ = S * 0.98
    anc = bez((-N + 2, sy - 8), (-N - 16, sy - 6), (-Sn_ + 14, sy - 4), (-Sn_, sy + 14), 0.70)
    parts.append(arm(v, sh_near, (-S * 0.82 + 22, sy + 62), (-S * 0.82 + 70, sy + 56), -1, sleeve=v["sleeve"], anchor=anc))
    return "".join(parts)


def svg(content, w=320, h=320, vb=(-160, -30, 320, 340)):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb[0]} {vb[1]} {vb[2]} {vb[3]}">{content}</svg>'
