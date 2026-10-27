"""v3 (Hamza 19 Oct): natural, younger face (neutral canthal tilt, light lash line, soft unlined lips, less blush,
darker brows), dark brunette hair, brown eyes, slim black reading glasses ON. At most 2 cashiers in the game.
Front desk cashier (v0.19e prototype v2, Hamza 19 Oct): NOT the chunky crew build after all (v1 kept in
cashier_crew_v1.py). Skinny "secretary" build, a silky wrap dress (modest V neckline), a pretty cartoon face
(almond eyes with a winged lash line, slim arched brows, small nose, full rosy lips, blush), BLONDE hair like his
reference photo: a messy high bun, curtain bangs parted in the middle, loose wispy strands framing the face.
Optional glasses (GLASSES). Same ink outlines + cel shading as the rest of the cast (detailer.py helpers).
Front view (she faces the customer across the counter). Poses: stand, count (hands on the counter with notes),
cheer (fist up, big smile).
Coordinates as detailer.py: x = 0 body centre, y down, feet on GROUND.
"""
import math
import detailer as D
from detailer import f, P, shaded, limb, ellipse_d, INK, OUT, GROUND, bez

SKIN = ("#ecbf98", "#cf966f")   # v4b (Hamza): a light tan (was #f6d2b8 / #dfa98a, too pale)
HAIR = ("#3b2b25", "#22171a", "#6e5249")       # v3: dark brunette: base, shade, shine
BROW = "#2a1c18"
LIPS = ("#e7958f", "#cf7a78")                  # v3: natural, soft (lower, upper)
IRIS = ("#7a4a2a", "#4a2a16")                  # v3: brown
DRESS = ("#c2185b", "#8e1145", "#ff8fc0")       # silky raspberry: base, shade, sheen
GLASS = "#141218"

V = dict(head=1.0, S=46, W=30, torso=88, legs=68, neck=13)
GLASSES = True       # v3: Hamza wants the glasses (slim black reading glasses)


def layout():
    return D.layout(V)


# ---------- head ----------
def head(L, mood="smile"):
    hs, top, chin, hh = L["hs"], L["top"], L["chin"], L["hh"]
    hw = L["hw"] * 0.86
    y = lambda k: top + hh * k
    out = [bun(L, hw)]
    for s in (-1, 1):
        out.append(shaded(ellipse_d(s * (hw + 1), y(0.60), 7 * hs, 10 * hs), SKIN[0], SKIN[1], dx=-3, dy=-3))
    # heart-shaped face: soft cheeks, slim jaw, small pointed chin
    d = (f"M 0 {f(top)} C {f(hw*0.62)} {f(top)} {f(hw*0.95)} {f(y(0.14))} {f(hw*0.97)} {f(y(0.38))} "
         f"C {f(hw)} {f(y(0.52))} {f(hw)} {f(y(0.62))} {f(hw*0.90)} {f(y(0.74))} "
         f"C {f(hw*0.72)} {f(y(0.88))} {f(hw*0.36)} {f(chin - 2)} 0 {f(chin)} "
         f"C {f(-hw*0.36)} {f(chin - 2)} {f(-hw*0.72)} {f(y(0.88))} {f(-hw*0.90)} {f(y(0.74))} "
         f"C {f(-hw)} {f(y(0.62))} {f(-hw)} {f(y(0.52))} {f(-hw*0.97)} {f(y(0.38))} "
         f"C {f(-hw*0.95)} {f(y(0.14))} {f(-hw*0.62)} {f(top)} 0 {f(top)} Z")
    blush = "".join(f'<ellipse cx="{f(s*hw*0.56)}" cy="{f(y(0.71))}" rx="{f(8*hs)}" ry="{f(4*hs)}" fill="#ff8f8f" opacity="0.16"/>' for s in (-1, 1))
    out.append(shaded(d, SKIN[0], SKIN[1], dx=-8, dy=-6, extra=blush))
    out.append(face(L, hw, mood))
    out.append(hair_front(L, hw))
    if GLASSES:
        out.append(glasses(L, hw))
    return "".join(out)


def eye(ex, ey, hs, side, closed=False):
    """v3: natural almond eye, NEUTRAL canthal tilt (inner + outer corners level), a light lash line."""
    rx, ry = 11 * hs, 8.8 * hs
    if closed or D.BLINK:
        return (f'<path d="M {f(ex - rx)} {f(ey)} Q {f(ex)} {f(ey + 6*hs)} {f(ex + rx)} {f(ey)}" fill="none" '
                f'stroke="{INK}" stroke-width="{f(2.8*hs)}" stroke-linecap="round"/>') + brow(ex, ey, hs, side)
    I = (ex - side * rx, ey + 0.5 * hs)
    O = (ex + side * rx, ey + 0.5 * hs)
    e = (f"M {P(I)} C {f(ex - side*rx*0.45)} {f(ey - ry*1.2)} {f(ex + side*rx*0.45)} {f(ey - ry*1.2)} {P(O)} "
         f"C {f(ex + side*rx*0.45)} {f(ey + ry*1.05)} {f(ex - side*rx*0.45)} {f(ey + ry*1.05)} {P(I)} Z")
    cid = D.uid("e")
    ix, iy = ex, ey + 0.4 * hs
    s = f'<clipPath id="{cid}"><path d="{e}"/></clipPath><path d="{e}" fill="#fbf8f4"/>'
    s += (f'<g clip-path="url(#{cid})">'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(7.2*hs)}" fill="{IRIS[0]}"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy + 1*hs)}" r="{f(4.8*hs)}" fill="{IRIS[1]}"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(3*hs)}" fill="{INK}"/>'
          f'<circle cx="{f(ix - 2.6*hs)}" cy="{f(iy - 2.6*hs)}" r="{f(2.3*hs)}" fill="#ffffff"/>'
          f'<circle cx="{f(ix + 2.4*hs)}" cy="{f(iy + 2.6*hs)}" r="{f(1*hs)}" fill="#ffffff" opacity="0.8"/>'
          f'<path d="{e}" fill="none" stroke="#000" stroke-width="{f(3.4*hs)}" opacity="0.08" transform="translate(0,{f(-2.2*hs)})"/>'
          f'</g>')
    s += f'<path d="{e}" fill="none" stroke="{INK}" stroke-width="{f(1.5*hs)}" stroke-linejoin="round"/>'
    # light upper lash line, just a touch thicker at the outer end
    s += (f'<path d="M {P(I)} C {f(ex - side*rx*0.45)} {f(ey - ry*1.2)} {f(ex + side*rx*0.45)} {f(ey - ry*1.2)} {P(O)}" '
          f'fill="none" stroke="{INK}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>')
    s += f'<path d="M {f(O[0] - side*1.5*hs)} {f(O[1] - 1.5*hs)} l {f(side*2.2*hs)} {f(-1.6*hs)}" stroke="{INK}" stroke-width="{f(1.8*hs)}" stroke-linecap="round"/>'
    return s + brow(ex, ey, hs, side)


def brow(ex, ey, hs, side):
    # v4 (Hamza): a touch thicker and the SAME thickness all the way along (no fading ends), rounded ends,
    # a soft natural arch
    d = (f"M {f(ex - side*11*hs)} {f(ey - 12.5*hs)} C {f(ex - side*5*hs)} {f(ey - 16.5*hs)} "
         f"{f(ex + side*4*hs)} {f(ey - 18*hs)} {f(ex + side*12.5*hs)} {f(ey - 14.5*hs)}")
    return f'<path d="{d}" fill="none" stroke="{BROW}" stroke-width="{f(4.6*hs)}" stroke-linecap="round"/>'


def face(L, hw, mood):
    hs, top, hh = L["hs"], L["top"], L["hh"]
    y = lambda k: top + hh * k
    ey = y(0.54)
    s = "".join(eye(side * hw * 0.44, ey, hs, side, closed=(mood == "cheer")) for side in (-1, 1))
    # small nose: a soft tip line + highlight
    ny = y(0.68)
    s += f'<path d="M {f(-3*hs)} {f(ny + 1.5*hs)} Q {f(1*hs)} {f(ny + 4.5*hs)} {f(4*hs)} {f(ny + 0.5*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
    s += f'<ellipse cx="{f(-0.5*hs)}" cy="{f(ny - 3*hs)}" rx="{f(2.4*hs)}" ry="{f(1.8*hs)}" fill="#ffffff" opacity="0.45"/>'
    my = y(0.795)
    if mood in ("grin", "cheer"):
        m = f"M {f(-12*hs)} {f(my - 2*hs)} C {f(-7*hs)} {f(my + 12*hs)} {f(7*hs)} {f(my + 12*hs)} {f(12*hs)} {f(my - 2*hs)} C {f(5*hs)} {f(my)} {f(-5*hs)} {f(my)} {f(-12*hs)} {f(my - 2*hs)} Z"
        s += f'<path d="{m}" fill="#8a3a3f" stroke="{LIPS[1]}" stroke-width="{f(2.4*hs)}" stroke-linejoin="round"/>'
        s += f'<path d="M {f(-9*hs)} {f(my - 0.2*hs)} Q 0 {f(my + 1.6*hs)} {f(9*hs)} {f(my - 0.2*hs)} L {f(7*hs)} {f(my + 3.6*hs)} Q 0 {f(my + 4.6*hs)} {f(-7*hs)} {f(my + 3.6*hs)} Z" fill="#ffffff"/>'
    else:
        # v3: soft natural lips, no outline, a gentle closed smile
        up = (f"M {f(-9*hs)} {f(my + 1*hs)} C {f(-6*hs)} {f(my - 2.6*hs)} {f(-2.5*hs)} {f(my - 3*hs)} 0 {f(my - 1.6*hs)} "
              f"C {f(2.5*hs)} {f(my - 3*hs)} {f(6*hs)} {f(my - 2.6*hs)} {f(9*hs)} {f(my + 1*hs)} "
              f"C {f(4*hs)} {f(my + 1.4*hs)} {f(-4*hs)} {f(my + 1.4*hs)} {f(-9*hs)} {f(my + 1*hs)} Z")
        lo = (f"M {f(-8*hs)} {f(my + 1.2*hs)} C {f(-5*hs)} {f(my + 6.5*hs)} {f(5*hs)} {f(my + 6.5*hs)} {f(8*hs)} {f(my + 1.2*hs)} "
              f"C {f(4*hs)} {f(my + 2*hs)} {f(-4*hs)} {f(my + 2*hs)} {f(-8*hs)} {f(my + 1.2*hs)} Z")
        s += f'<path d="{lo}" fill="{LIPS[0]}"/>'
        s += f'<path d="{up}" fill="{LIPS[1]}"/>'
        s += f'<path d="M {f(-9*hs)} {f(my + 1*hs)} C {f(-4*hs)} {f(my + 2.2*hs)} {f(4*hs)} {f(my + 2.2*hs)} {f(9*hs)} {f(my + 1*hs)}" fill="none" stroke="#9a4e50" stroke-width="{f(1.6*hs)}" stroke-linecap="round"/>'
        s += f'<ellipse cx="{f(-2*hs)}" cy="{f(my + 3.8*hs)}" rx="{f(2.4*hs)}" ry="{f(0.9*hs)}" fill="#ffffff" opacity="0.4"/>'
        for sd in (-1, 1):
            s += f'<path d="M {f(sd*9*hs)} {f(my + 1*hs)} q {f(sd*1.6*hs)} {f(-0.6*hs)} {f(sd*2.2*hs)} {f(-2.2*hs)}" fill="none" stroke="#9a4e50" stroke-width="{f(1.4*hs)}" stroke-linecap="round"/>'
    return s


def hair_front(L, hw):
    hs, top, hh = L["hs"], L["top"], L["hh"]
    y = lambda k: top + hh * k
    tw = hw * 1.04
    # pulled up, with soft volume at the sides (not a helmet): a lighter ink line, messy texture strands
    cap = (f"M {f(-tw - 2)} {f(y(0.48))} C {f(-tw - 12)} {f(y(0.24))} {f(-tw - 4)} {f(y(0.02))} {f(-hw*0.5)} {f(top - 8*hs)} "
           f"C {f(-hw*0.2)} {f(top - 12*hs)} {f(hw*0.2)} {f(top - 12*hs)} {f(hw*0.5)} {f(top - 8*hs)} "
           f"C {f(tw + 4)} {f(y(0.02))} {f(tw + 12)} {f(y(0.24))} {f(tw + 2)} {f(y(0.48))} "
           f"C {f(tw - 4)} {f(y(0.32))} {f(hw*0.5)} {f(y(0.22))} 0 {f(y(0.24))} "
           f"C {f(-hw*0.5)} {f(y(0.22))} {f(-tw + 4)} {f(y(0.32))} {f(-tw - 2)} {f(y(0.48))} Z")
    s = shaded(cap, HAIR[0], HAIR[1], dx=-5, dy=-6, sw=3.6)
    for k in (-0.7, -0.35, 0.35, 0.7):
        s += f'<path d="M {f(k*hw*1.25)} {f(y(0.26))} Q {f(k*hw*1.1)} {f(top + 4*hs)} {f(k*hw*0.35)} {f(top - 8*hs)}" stroke="{HAIR[1]}" stroke-width="{f(1.8*hs)}" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M {f(-hw*0.55)} {f(top + 2*hs)} Q {f(-hw*0.1)} {f(top - 8*hs)} {f(hw*0.35)} {f(top - 3*hs)}" stroke="{HAIR[2]}" stroke-width="{f(3*hs)}" fill="none" stroke-linecap="round"/>'
    for sd in (-1, 1):
        # curtain bang: from the middle part, sweeping out over the brow, flicking out at the cheekbone
        bang = (f"M {f(sd*1*hs)} {f(y(0.20))} C {f(sd*hw*0.35)} {f(y(0.19))} {f(sd*hw*0.85)} {f(y(0.30))} {f(sd*hw*1.05)} {f(y(0.56))} "
                f"Q {f(sd*hw*1.12)} {f(y(0.62))} {f(sd*hw*1.16)} {f(y(0.60))} "
                f"C {f(sd*hw*1.0)} {f(y(0.46))} {f(sd*hw*0.86)} {f(y(0.33))} {f(sd*hw*0.62)} {f(y(0.30))} "
                f"C {f(sd*hw*0.40)} {f(y(0.27))} {f(sd*hw*0.20)} {f(y(0.25))} {f(sd*1*hs)} {f(y(0.26))} Z")   # v3: shorter so the brows show
        s += shaded(bang, HAIR[0], HAIR[1], dx=-2 * sd, dy=-3, sw=2.6)
        s += f'<path d="M {f(sd*hw*0.22)} {f(y(0.23))} C {f(sd*hw*0.55)} {f(y(0.26))} {f(sd*hw*0.82)} {f(y(0.35))} {f(sd*hw*0.96)} {f(y(0.50))}" stroke="{HAIR[2]}" stroke-width="{f(2.2*hs)}" fill="none" stroke-linecap="round"/>'
        # loose face-framing strand: a wavy lock from the temple to below the jaw
        w0 = sd * hw * 1.0
        lock = (f"M {f(w0)} {f(y(0.40))} C {f(w0 + sd*12*hs)} {f(y(0.56))} {f(w0 - sd*2*hs)} {f(y(0.70))} {f(w0 + sd*6*hs)} {f(y(0.86))} "
                f"C {f(w0 + sd*12*hs)} {f(y(0.96))} {f(w0 + sd*4*hs)} {f(y(1.04))} {f(w0 + sd*9*hs)} {f(y(1.10))} "
                f"C {f(w0 - sd*2*hs)} {f(y(1.02))} {f(w0 + sd*2*hs)} {f(y(0.94))} {f(w0 - sd*2*hs)} {f(y(0.84))} "
                f"C {f(w0 - sd*8*hs)} {f(y(0.70))} {f(w0 + sd*2*hs)} {f(y(0.56))} {f(w0 - sd*5*hs)} {f(y(0.44))} Z")
        s += shaded(lock, HAIR[0], HAIR[1], dx=-2 * sd, dy=-2, sw=2.4)
        s += f'<path d="M {f(w0 + sd*3*hs)} {f(y(0.48))} C {f(w0 + sd*8*hs)} {f(y(0.60))} {f(w0)} {f(y(0.72))} {f(w0 + sd*4*hs)} {f(y(0.86))}" stroke="{HAIR[2]}" stroke-width="{f(1.8*hs)}" fill="none" stroke-linecap="round"/>'
    return s


def bun(L, hw):
    """Messy high bun: one loose knot with loops showing, a few flyaway strands (drawn behind the head)."""
    hs, top = L["hs"], L["top"]
    cx, cy = 3 * hs, top - 20 * hs
    s = ""
    for a0, r in ((-160, 36), (-118, 33), (-64, 35), (-22, 31)):
        a = math.radians(a0)
        px, py = cx + math.cos(a) * r * hs, cy + math.sin(a) * r * hs * 0.85
        q = f'M {f(cx + math.cos(a)*16*hs)} {f(cy + math.sin(a)*12*hs)} Q {f(px + 10*hs)} {f(py - 8*hs)} {f(px)} {f(py)}'
        s += (f'<path d="{q}" fill="none" stroke="{INK}" stroke-width="{f(4*hs)}" stroke-linecap="round"/>'
              f'<path d="{q}" fill="none" stroke="{HAIR[0]}" stroke-width="{f(1.8*hs)}" stroke-linecap="round"/>')
    knot = (f"M {f(cx - 28*hs)} {f(cy + 8*hs)} C {f(cx - 34*hs)} {f(cy - 14*hs)} {f(cx - 14*hs)} {f(cy - 26*hs)} {f(cx + 2*hs)} {f(cy - 24*hs)} "
            f"C {f(cx + 22*hs)} {f(cy - 26*hs)} {f(cx + 34*hs)} {f(cy - 10*hs)} {f(cx + 28*hs)} {f(cy + 8*hs)} "
            f"C {f(cx + 22*hs)} {f(cy + 18*hs)} {f(cx - 20*hs)} {f(cy + 18*hs)} {f(cx - 28*hs)} {f(cy + 8*hs)} Z")
    s += shaded(knot, HAIR[0], HAIR[1], dx=-5, dy=-5, sw=3.6)
    # the twist: loop strands inside the knot
    s += f'<path d="M {f(cx - 20*hs)} {f(cy + 6*hs)} C {f(cx - 22*hs)} {f(cy - 14*hs)} {f(cx + 12*hs)} {f(cy - 18*hs)} {f(cx + 14*hs)} {f(cy - 2*hs)}" stroke="{HAIR[1]}" stroke-width="{f(2.4*hs)}" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M {f(cx - 8*hs)} {f(cy + 10*hs)} C {f(cx - 10*hs)} {f(cy - 4*hs)} {f(cx + 14*hs)} {f(cy - 6*hs)} {f(cx + 20*hs)} {f(cy + 6*hs)}" stroke="{HAIR[1]}" stroke-width="{f(2.2*hs)}" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M {f(cx - 16*hs)} {f(cy - 14*hs)} Q {f(cx)} {f(cy - 24*hs)} {f(cx + 16*hs)} {f(cy - 16*hs)}" stroke="{HAIR[2]}" stroke-width="{f(3*hs)}" fill="none" stroke-linecap="round"/>'
    return s


def glasses(L, hw):
    """v3: slim, sleek black reading glasses (shape from Hamza's sunglasses reference): narrow lenses, a straight
    top edge rising a touch to a crisp outer corner, a softly rounded bottom; clear lenses with a glint."""
    hs, top, hh = L["hs"], L["top"], L["hh"]
    ey = top + hh * 0.54
    s = ""
    for sd in (-1, 1):
        ex = sd * hw * 0.44
        ix, ox = ex - sd * 13.5 * hs, ex + sd * 15 * hs        # inner / outer x
        r = (f"M {f(ix)} {f(ey - 6.5*hs)} L {f(ox - sd*2*hs)} {f(ey - 9*hs)} Q {f(ox + sd*1*hs)} {f(ey - 9.4*hs)} {f(ox)} {f(ey - 6*hs)} "
             f"C {f(ox - sd*1*hs)} {f(ey + 3*hs)} {f(ex + sd*8*hs)} {f(ey + 8*hs)} {f(ex)} {f(ey + 8*hs)} "
             f"C {f(ex - sd*8*hs)} {f(ey + 8*hs)} {f(ix - sd*0.5*hs)} {f(ey + 3*hs)} {f(ix)} {f(ey - 6.5*hs)} Z")
        s += f'<path d="{r}" fill="#ffffff" fill-opacity="0.10" stroke="{GLASS}" stroke-width="{f(3.4*hs)}" stroke-linejoin="round"/>'
        s += f'<path d="M {f(ex - sd*6*hs)} {f(ey - 4.5*hs)} l {f(sd*5*hs)} {f(-0.8*hs)}" stroke="#ffffff" stroke-width="{f(1.8*hs)}" stroke-linecap="round" opacity="0.65"/>'
        # arm going back to the ear
        s += f'<path d="M {f(ox)} {f(ey - 7*hs)} L {f(sd*(hw + 2))} {f(ey - 5*hs)}" stroke="{GLASS}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
    br = f'M {f(-hw*0.44 + 13.5*hs)} {f(ey - 5*hs)} Q 0 {f(ey - 8*hs)} {f(hw*0.44 - 13.5*hs)} {f(ey - 5*hs)}'
    s += f'<path d="{br}" fill="none" stroke="{GLASS}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
    return s


# ---------- body: silky wrap dress ----------
def body(L):
    S, W, N = V["S"], V["W"], V["neck"]
    sy, hip, ank = L["sy"], L["hip"], L["ank"]
    out = []
    knee = hip + (ank - hip) * 0.45
    for sd in (-1, 1):
        lg = limb((sd * 12, hip), (sd * 10, ank - 4), 20, 13, bulge=2)
        out.append(shaded(lg, SKIN[0], SKIN[1], dx=-4, dy=-2))
        x0 = sd * 10
        pump = (f"M {f(x0 - 9)} {f(ank - 6)} C {f(x0 - 10)} {f(GROUND)} {f(x0 + sd*14)} {f(GROUND + 1)} {f(x0 + sd*16)} {f(GROUND - 4)} "
                f"C {f(x0 + sd*14)} {f(ank - 2)} {f(x0 + 8)} {f(ank - 8)} {f(x0 - 9)} {f(ank - 6)} Z")
        out.append(shaded(pump, DRESS[1], "#5e0b2e", dx=-2, dy=-2))
    nd = f"M {f(-N)} {f(L['chin'] - 26)} L {f(N)} {f(L['chin'] - 26)} L {f(N + 2)} {f(sy + 4)} L {f(-N - 2)} {f(sy + 4)} Z"
    out.append(shaded(nd, SKIN[0], SKIN[1], dx=-3, dy=6))
    waist = sy + 52
    hem = knee + 16
    # v4: shoulders slope down from the neck (they sat high, like a shrug)
    dd = (f"M {f(-N - 6)} {f(sy - 5)} C {f(-N - 16)} {f(sy - 1)} {f(-S + 6)} {f(sy + 6)} {f(-S)} {f(sy + 20)} "
          f"C {f(-S + 2)} {f(sy + 36)} {f(-W + 2)} {f(waist - 10)} {f(-W + 4)} {f(waist)} "
          f"C {f(-W - 4)} {f(hip)} {f(-W - 12)} {f(hem - 18)} {f(-W - 16)} {f(hem)} "
          f"Q 0 {f(hem + 8)} {f(W + 16)} {f(hem)} "
          f"C {f(W + 12)} {f(hem - 18)} {f(W + 4)} {f(hip)} {f(W - 4)} {f(waist)} "
          f"C {f(W - 2)} {f(waist - 10)} {f(S - 2)} {f(sy + 36)} {f(S)} {f(sy + 20)} "
          f"C {f(S - 6)} {f(sy + 6)} {f(N + 16)} {f(sy - 1)} {f(N + 6)} {f(sy - 5)} Z")
    det = ""
    # modest wrap V neckline with a hint of a cleavage line at the bottom
    vb = sy + 26
    det += f'<path d="M {f(-N - 5)} {f(sy - 5)} L 2 {f(vb)} L {f(N + 5)} {f(sy - 5)} Z" fill="{SKIN[0]}"/>'
    det += f'<path d="M 0 {f(vb - 7)} q 0.6 4 1.4 6.5" stroke="{SKIN[1]}" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    det += f'<path d="M {f(-N - 5)} {f(sy - 5)} L 2 {f(vb)} L {f(N + 5)} {f(sy - 5)}" fill="none" stroke="{INK}" stroke-width="3.2" stroke-linejoin="round"/>'
    det += f'<path d="M 2 {f(vb)} C 8 {f(vb + 10)} 12 {f(waist - 10)} 16 {f(waist)}" stroke="{DRESS[1]}" stroke-width="3" fill="none" stroke-linecap="round"/>'
    # satin sheen: soft light streaks
    for (x0, y0, x1, y1, w_) in ((-S + 10, sy + 10, -W + 6, waist - 6, 5), (-W - 4, hip, -W - 10, hem - 8, 6), (6, hip + 6, 10, hem - 6, 4)):
        det += f'<path d="M {f(x0)} {f(y0)} Q {f((x0 + x1) / 2 - 4)} {f((y0 + y1) / 2)} {f(x1)} {f(y1)}" stroke="{DRESS[2]}" stroke-width="{w_}" fill="none" stroke-linecap="round" opacity="0.55"/>'
    for x in (-14, 12):
        det += f'<path d="M {f(x * 0.6)} {f(hip + 4)} Q {f(x)} {f((hip + hem) / 2)} {f(x * 1.3)} {f(hem + 2)}" stroke="{DRESS[1]}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    bx, by = S * 0.26, sy + 20
    det += f'<rect x="{f(bx - 2)}" y="{f(by)}" width="22" height="11" rx="3" fill="#ffffff" stroke="{INK}" stroke-width="2"/>'
    det += f'<rect x="{f(bx + 2)}" y="{f(by + 4)}" width="14" height="3" rx="1.5" fill="#2f9bff"/>'
    out.append(shaded(dd, DRESS[0], DRESS[1], dx=-8, dy=-4, extra=det))
    out.append(f'<path d="M {f(-W + 3)} {f(waist - 3)} L {f(W - 3)} {f(waist - 3)} L {f(W - 3)} {f(waist + 4)} L {f(-W + 3)} {f(waist + 4)} Z" fill="{DRESS[1]}" stroke="{INK}" stroke-width="2.5"/>')
    out.append(shaded(ellipse_d(16, waist, 5.5, 5), DRESS[0], DRESS[1], dx=-2, dy=-2))
    for (ex, ey) in ((22, waist + 22), (12, waist + 26)):
        t = f'M 16 {f(waist + 3)} Q {f(ex + 4)} {f((waist + ey) / 2)} {f(ex)} {f(ey)}'
        out.append(f'<path d="{t}" stroke="{INK}" stroke-width="6.5" fill="none" stroke-linecap="round"/>')
        out.append(f'<path d="{t}" stroke="{DRESS[0]}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    return out


def arm(sh, el, wr, side, hand="open", hold=None):
    """Slim bare arm, a short silky cap sleeve over the shoulder."""
    s = ""
    s += shaded(limb(el, wr, 15, 12, bulge=2), SKIN[0], SKIN[1], dx=-3, dy=-3)
    s += shaded(limb(sh, el, 18, 15, bulge=2), SKIN[0], SKIN[1], dx=-3, dy=-3)
    L_ = math.hypot(el[0] - sh[0], el[1] - sh[1]) or 1
    ux, uy = (el[0] - sh[0]) / L_, (el[1] - sh[1]) / L_
    cap_end = (sh[0] + ux * L_ * 0.38, sh[1] + uy * L_ * 0.38)
    s += shaded(limb((sh[0] - side * 3, sh[1] - 2), cap_end, 21, 18, bulge=2), DRESS[0], DRESS[1], dx=-3, dy=-3)
    L2 = math.hypot(wr[0] - el[0], wr[1] - el[1]) or 1
    vx, vy = (wr[0] - el[0]) / L2, (wr[1] - el[1]) / L2
    hx, hy = wr[0] + vx * 6, wr[1] + vy * 6
    if hold:
        s += hold(hx, hy)
    if hand == "fist":
        s += shaded(ellipse_d(hx, hy, 9.5, 9), SKIN[0], SKIN[1], dx=-3, dy=-3)
    else:
        s += shaded(ellipse_d(hx, hy, 8.5, 9.5), SKIN[0], SKIN[1], dx=-3, dy=-3)
        s += shaded(ellipse_d(hx - side * 7, hy - 3, 3.6, 5.5), SKIN[0], SKIN[1], dx=-1, dy=-1)
        s += f'<path d="M {f(hx - 4)} {f(hy + 8)} l 0 2.5 M {f(hx)} {f(hy + 8.5)} l 0 2.5 M {f(hx + 4)} {f(hy + 8)} l 0 2.5" stroke="{LIPS[0]}" stroke-width="2.4" stroke-linecap="round"/>'
    return s


def notes(hx, hy):
    s = ""
    for k in range(3):
        s += f'<rect x="{f(hx - 18)}" y="{f(hy - 8 - k*3.5)}" width="36" height="11" rx="2" fill="#43a047" stroke="{INK}" stroke-width="2.2"/>'
    s += f'<rect x="{f(hx - 14)}" y="{f(hy - 13)}" width="28" height="2.5" fill="#e8f5e9"/>'
    return s


def figure(pose="stand", mood=None):
    L = layout()
    S, sy = V["S"], L["sy"]
    parts = body(L)
    mood = mood or {"stand": "smile", "count": "smile", "cheer": "cheer"}[pose]
    arms = []
    for side in (-1, 1):
        sh = (side * (S - 7), sy + 20)        # v4: lower shoulders
        if pose == "cheer" and side < 0:
            el, wr, hand, hold = (side * (S + 26), sy + 4), (side * (S + 16), sy - 40), "fist", None
        elif pose == "count":
            el, wr, hand, hold = (side * (S + 4), sy + 54), (side * 18, sy + 62), "open", (notes if side < 0 else None)
        else:
            el, wr, hand, hold = (side * (S + 3), sy + 56), (side * (S + 1), sy + 92), "open", None
        arms.append(arm(sh, el, wr, side, hand, hold))
    return "".join(parts) + "".join(arms) + head(L, mood)


def svg(body_, w=320, h=360, vb=(-160, -70, 320, 375)):
    return D.svg(body_, w, h, vb)
