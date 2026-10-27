"""Cash manager concepts (19 Oct) in the detailer's art language (tools/char/detailer.py):
same ink, outline weight, cel shading (lit shape shifted to the top-left, shadow rim bottom-right),
hunter eyes, chunky proportions. Front view only (managers stand facing you at their station).

Tiers keep today's logic: Junior = crew-colour polo, Senior = shirt + crew tie, Executive = suit + crew tie.
Poses keep today's four idle loops: 0 arm pump, 1 arms crossed, 2 hands on hips, 3 clipboard + pen.
"""
import math, random, sys
sys.path.insert(0, "/root/char")
import detailer as D
from detailer import f, P, limb, shaded, ellipse_d, INK, OUT, GROUND, bez

SKINS = [("#f2c79b", "#d49b6c"), ("#d9a174", "#b97c52"), ("#b9784a", "#93582f"),
         ("#8a5634", "#6a3e22"), ("#f6d6b8", "#dcae88")]
HAIRS = {"black": ("#1c1714", "#0e0b09", "#4a3d36"), "brown": ("#5b3b22", "#3e2716", "#8a6448"),
         "dark": ("#2b1d14", "#1a110b", "#5a4332"), "blond": ("#d8a94e", "#b07f2c", "#f3d58e"),
         "ginger": ("#b5562a", "#8a3d1a", "#e08a5a"), "grey": ("#9aa0a8", "#747a83", "#d0d4da")}

BUILDS = {
    "stocky": dict(head=0.96, S=80, W=48, torso=82, legs=52, neck=25),
    "lean":   dict(head=0.92, S=70, W=42, torso=86, legs=58, neck=22),
}


def layout(b):
    hs = b["head"]
    ank = GROUND - 14
    hip = ank - b["legs"]
    sy = hip - b["torso"]
    hh, hw = 112 * hs, 50 * hs
    chin = sy + 10
    return dict(hs=hs, ank=ank, hip=hip, sy=sy, chin=chin, top=chin - hh, hh=hh, hw=hw)


# ------------------------------------------------------------------ head
def eye(ex, ey, hs, side, hair, lift=0.0, lash=False, iris_dx=0.0, brow_th=5.6, brow_tilt=0.0):
    """Hunter eye from the detailer (level brow low across the eye). lift > 0 raises the brow so more
    of the eye shows (friendlier); brow_tilt lifts the inner end (keen / surprised)."""
    rx = 11.5 * hs
    yu, yl = ey - 6.0 * hs, ey + 8.2 * hs
    I = (ex - side * rx, ey + 0.4 * hs)
    O = (ex + side * rx, ey - 0.2 * hs)
    d = (f"M {P(I)} C {f(I[0] + side*rx*0.45)} {f(yu)} {f(O[0] - side*rx*0.55)} {f(yu)} {P(O)} "
         f"C {f(O[0] - side*rx*0.15)} {f(yl + 3.0*hs)} {f(I[0] + side*rx*0.45)} {f(yl + 3.4*hs)} {P(I)} Z")
    cid = D.uid("e")
    ix, iy = ex + iris_dx * hs, ey + 1.6 * hs - lift * 0.25
    s = f'<clipPath id="{cid}"><path d="{d}"/></clipPath><path d="{d}" fill="#f6f2ec"/>'
    s += (f'<g clip-path="url(#{cid})">'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(6.8*hs)}" fill="#5e4128"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(4.2*hs)}" fill="#3f2a18"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{f(3.0*hs)}" fill="{INK}"/>'
          f'<circle cx="{f(ix - 2.6*hs)}" cy="{f(iy + 1.4*hs)}" r="{f(1.4*hs)}" fill="#fff"/>'
          f'<rect x="{f(ex - rx*1.3)}" y="{f(ey - lift)}" width="{f(rx*2.6)}" height="{f(1.4*hs)}" fill="#000" opacity="0.16"/></g>')
    s += f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{f(2.0*hs)}" stroke-linejoin="round"/>'
    if lash:
        s += f'<path d="M {P(O)} l {f(side*4.5*hs)} {f(-2.5*hs)}" stroke="{INK}" stroke-width="{f(2.4*hs)}" stroke-linecap="round"/>'
    # brow
    bb = ey + 0.5 * hs - lift
    th = brow_th * hs
    bi, bo = ex - side * rx * 1.18, ex + side * rx * 1.28
    ti = brow_tilt * hs
    brow = (f"M {f(bi)} {f(bb - ti)} L {f(bi)} {f(bb - th + 1.4*hs - ti)} Q {f(bi)} {f(bb - th - ti)} {f(bi + side*2*hs)} {f(bb - th - ti)} "
            f"L {f(bo - side*3*hs)} {f(bb - th + 0.4*hs)} Q {f(bo + side*0.6*hs)} {f(bb - th + 1.2*hs)} {f(bo)} {f(bb)} Z")
    s += f'<path d="{brow}" fill="{hair[0]}" stroke="{INK}" stroke-width="{f(2.2*hs)}" stroke-linejoin="round"/>'
    return s


def head(p, L, mood="flat", cx=0.0):
    """p: person dict (skin, hair colour, hair style, facial, fem, eyes)."""
    hs, top, chin, hw, hh = L["hs"], L["top"], L["chin"], L["hw"], L["hh"]
    y = lambda k: top + hh * k
    SK = SKINS[p["skin"]]
    HR = HAIRS[p["hair"]]
    fem = p.get("fem", False)
    jw = hw * (0.94 if fem else 1.06)
    tw = hw * 0.90
    out = []
    style = p["style"]
    if style == "bun":    # bun behind the head
        out.append(shaded(ellipse_d(cx + 4 * hs, top - 4 * hs, 21 * hs, 18 * hs), HR[0], HR[1], dx=-4, dy=-4))
    if style == "pony":
        pd = f"M {f(cx + hw*0.5)} {f(y(0.18))} C {f(cx + hw*1.5)} {f(y(0.10))} {f(cx + hw*1.55)} {f(y(0.62))} {f(cx + hw*1.18)} {f(y(0.86))} C {f(cx + hw*1.1)} {f(y(0.6))} {f(cx + hw*0.95)} {f(y(0.4))} {f(cx + hw*0.6)} {f(y(0.32))} Z"
        out.append(shaded(pd, HR[0], HR[1], dx=-4, dy=-4))
    for s_ in (-1, 1):
        out.append(shaded(ellipse_d(cx + s_ * (hw + 2), y(0.58), 9 * hs, 13 * hs), SK[0], SK[1], dx=-3, dy=-3))
        out.append(f'<path d="M {f(cx + s_*(hw+1))} {f(y(0.52))} q {f(s_*4*hs)} {f(6*hs)} 0 {f(14*hs)}" fill="none" stroke="{SK[1]}" stroke-width="3" stroke-linecap="round"/>')
    d = (f"M {f(cx)} {f(top)} C {f(cx + hw*0.62)} {f(top)} {f(cx + tw)} {f(y(0.12))} {f(cx + tw)} {f(y(0.32))} "
         f"C {f(cx + tw + 2)} {f(y(0.45))} {f(cx + hw)} {f(y(0.52))} {f(cx + hw)} {f(y(0.62))} "
         f"C {f(cx + hw)} {f(y(0.78))} {f(cx + jw)} {f(y(0.86))} {f(cx + jw*0.80)} {f(y(0.93))} "
         f"C {f(cx + jw*0.62)} {f(y(1.0))} {f(cx + hw*0.42)} {f(chin)} {f(cx)} {f(chin)} "
         f"C {f(cx - hw*0.42)} {f(chin)} {f(cx - jw*0.62)} {f(y(1.0))} {f(cx - jw*0.80)} {f(y(0.93))} "
         f"C {f(cx - jw)} {f(y(0.86))} {f(cx - hw)} {f(y(0.78))} {f(cx - hw)} {f(y(0.62))} "
         f"C {f(cx - hw)} {f(y(0.52))} {f(cx - tw - 2)} {f(y(0.45))} {f(cx - tw)} {f(y(0.32))} "
         f"C {f(cx - tw)} {f(y(0.12))} {f(cx - hw*0.62)} {f(top)} {f(cx)} {f(top)} Z")
    extra = ""
    fac = p.get("facial", "")
    if fac in ("stubble", "beard"):
        stub = (f"M {f(cx - hw + 1)} {f(y(0.66))} C {f(cx - hw + 4)} {f(y(0.90))} {f(cx - hw*0.4)} {f(chin - 1)} {f(cx)} {f(chin - 1)} "
                f"C {f(cx + hw*0.4)} {f(chin - 1)} {f(cx + hw - 4)} {f(y(0.90))} {f(cx + hw - 1)} {f(y(0.66))} "
                f"C {f(cx + hw*0.62)} {f(y(0.74))} {f(cx + hw*0.35)} {f(y(0.70))} {f(cx)} {f(y(0.71))} "
                f"C {f(cx - hw*0.35)} {f(y(0.70))} {f(cx - hw*0.62)} {f(y(0.74))} {f(cx - hw + 1)} {f(y(0.66))} Z")
        if fac == "stubble":
            extra += f'<path d="{stub}" fill="{HR[1]}" opacity="0.22"/>'
            rng = random.Random(p.get("seed", 7))
            for _ in range(int(60 * hs)):
                px, py = rng.uniform(-hw * 0.9, hw * 0.9), rng.uniform(y(0.70), chin - 4)
                if abs(px) > hw * (0.95 - 0.5 * max(0, (py - y(0.85)) / (chin - y(0.85)))) or (abs(px) < 14 * hs and abs(py - y(0.84)) < 5 * hs):
                    continue
                extra += f'<circle cx="{f(cx + px)}" cy="{f(py)}" r="{f(1.3*hs)}" fill="{HR[1]}" opacity="0.5"/>'
    out.append(shaded(d, SK[0], SK[1], dx=-9, dy=-6, extra=extra))
    if fac == "beard":   # short boxed beard: a hair shape hugging the jaw, mouth cut-out
        bd = (f"M {f(cx - hw)} {f(y(0.56))} C {f(cx - hw - 1)} {f(y(0.86))} {f(cx - hw*0.5)} {f(chin + 6*hs)} {f(cx)} {f(chin + 6*hs)} "
              f"C {f(cx + hw*0.5)} {f(chin + 6*hs)} {f(cx + hw + 1)} {f(y(0.86))} {f(cx + hw)} {f(y(0.56))} "
              f"L {f(cx + hw - 7*hs)} {f(y(0.58))} C {f(cx + hw*0.7)} {f(y(0.74))} {f(cx + hw*0.35)} {f(y(0.74))} {f(cx)} {f(y(0.75))} "
              f"C {f(cx - hw*0.35)} {f(y(0.74))} {f(cx - hw*0.7)} {f(y(0.74))} {f(cx - hw + 7*hs)} {f(y(0.58))} Z")
        out.append(shaded(bd, HR[0], HR[1], dx=-4, dy=-4))
    # face
    ey = y(0.50)
    e = p.get("eyes", {})
    for side in (-1, 1):
        out.append(eye(cx + side * hw * 0.40, ey, hs, side, HR, lift=e.get("lift", 0.0) * hs, lash=fem,
                       iris_dx=e.get("look", 0.0), brow_th=4.2 if fem else 5.6, brow_tilt=e.get("tilt", 0.0)))
    s = f'<path d="M {f(cx + 3*hs)} {f(ey - 2*hs)} C {f(cx + 4*hs)} {f(ey + 8*hs)} {f(cx + 6*hs)} {f(y(0.64))} {f(cx + 8*hs)} {f(y(0.68))}" fill="none" stroke="{SK[1]}" stroke-width="{f(3*hs)}" stroke-linecap="round" opacity="0.8"/>'
    ny = y(0.69)
    nk = 0.85 if fem else 1.0
    s += f'<ellipse cx="{f(cx + 1*hs)}" cy="{f(ny + 5.5*hs)}" rx="{f(9*hs*nk)}" ry="{f(3*hs)}" fill="{SK[1]}" opacity="0.6"/>'
    for sd in (-1, 1):
        s += f'<path d="M {f(cx + sd*6*hs*nk)} {f(ny - 3*hs)} C {f(cx + sd*11*hs*nk)} {f(ny - 1*hs)} {f(cx + sd*11*hs*nk)} {f(ny + 5*hs)} {f(cx + sd*5*hs*nk)} {f(ny + 5*hs)}" fill="none" stroke="{INK}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
        s += f'<ellipse cx="{f(cx + sd*3.3*hs*nk)}" cy="{f(ny + 4.6*hs)}" rx="{f(2.1*hs)}" ry="{f(1.2*hs)}" fill="#4a2c1c"/>'
    if fac == "mo":
        md = f"M {f(cx - 15*hs)} {f(ny + 13*hs)} C {f(cx - 12*hs)} {f(ny + 5*hs)} {f(cx - 3*hs)} {f(ny + 6*hs)} {f(cx)} {f(ny + 8*hs)} C {f(cx + 3*hs)} {f(ny + 6*hs)} {f(cx + 12*hs)} {f(ny + 5*hs)} {f(cx + 15*hs)} {f(ny + 13*hs)} C {f(cx + 8*hs)} {f(ny + 11*hs)} {f(cx - 8*hs)} {f(ny + 11*hs)} {f(cx - 15*hs)} {f(ny + 13*hs)} Z"
        s += f'<path d="{md}" fill="{HR[0]}" stroke="{INK}" stroke-width="{f(2.2*hs)}" stroke-linejoin="round"/>'
    my = y(0.835)
    lipc = "#b5535a" if fem else None
    if mood == "grin":
        m = f"M {f(cx - 15*hs)} {f(my - 3*hs)} C {f(cx - 8*hs)} {f(my + 12*hs)} {f(cx + 8*hs)} {f(my + 12*hs)} {f(cx + 15*hs)} {f(my - 3*hs)} Z"
        s += f'<path d="{m}" fill="#5a1f1f" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        s += f'<path d="M {f(cx - 13*hs)} {f(my - 1.5*hs)} L {f(cx + 13*hs)} {f(my - 1.5*hs)} L {f(cx + 10*hs)} {f(my + 3*hs)} L {f(cx - 10*hs)} {f(my + 3*hs)} Z" fill="#fff"/>'
        s += f'<path d="M {f(cx - 6*hs)} {f(my + 7.5*hs)} Q {f(cx)} {f(my + 10*hs)} {f(cx + 6*hs)} {f(my + 7.5*hs)}" stroke="#d0605a" stroke-width="{f(3*hs)}" fill="none" stroke-linecap="round"/>'
    elif mood == "smile":
        s += f'<path d="M {f(cx - 12*hs)} {f(my - 1.5*hs)} C {f(cx - 5*hs)} {f(my + 5*hs)} {f(cx + 5*hs)} {f(my + 5*hs)} {f(cx + 12*hs)} {f(my - 1.5*hs)}" fill="none" stroke="{lipc or INK}" stroke-width="{f(3.5*hs)}" stroke-linecap="round"/>'
        for sd in (-1, 1):
            s += f'<path d="M {f(cx + sd*12*hs)} {f(my - 4*hs)} q {f(sd*2*hs)} {f(2.5*hs)} 0 {f(4.5*hs)}" fill="none" stroke="{SK[1]}" stroke-width="2.4" stroke-linecap="round"/>'
    elif mood == "smirk":
        s += f'<path d="M {f(cx - 11*hs)} {f(my + 1.5*hs)} C {f(cx - 4*hs)} {f(my + 2.5*hs)} {f(cx + 5*hs)} {f(my + 1*hs)} {f(cx + 12*hs)} {f(my - 3.5*hs)}" fill="none" stroke="{lipc or INK}" stroke-width="{f(3.5*hs)}" stroke-linecap="round"/>'
        s += f'<path d="M {f(cx + 12*hs)} {f(my - 6*hs)} q {f(2*hs)} {f(2.5*hs)} 0 {f(4.5*hs)}" fill="none" stroke="{SK[1]}" stroke-width="2.4" stroke-linecap="round"/>'
    else:
        s += f'<path d="M {f(cx - 11*hs)} {f(my + 0.5*hs)} C {f(cx - 5*hs)} {f(my - 0.5*hs)} {f(cx + 5*hs)} {f(my - 0.5*hs)} {f(cx + 11*hs)} {f(my + 1.5*hs)}" fill="none" stroke="{lipc or INK}" stroke-width="{f(3.5*hs)}" stroke-linecap="round"/>'
    if mood != "grin" and fac != "beard":
        s += f'<path d="M {f(cx - 5*hs)} {f(my + 6*hs)} C {f(cx - 2*hs)} {f(my + 8*hs)} {f(cx + 2*hs)} {f(my + 8*hs)} {f(cx + 5*hs)} {f(my + 6*hs)}" fill="none" stroke="{SK[1]}" stroke-width="2.5" stroke-linecap="round"/>'
    if fem or p.get("blush"):
        for sd in (-1, 1):
            s += f'<ellipse cx="{f(cx + sd*hw*0.58)}" cy="{f(y(0.68))}" rx="{f(7*hs)}" ry="{f(3.5*hs)}" fill="#e2766b" opacity="0.28"/>'
    out.append(s)
    out.append(hair(p, L, cx, HR))
    return "".join(out)


def hair(p, L, cx, HR):
    hs, top, hh, hw = L["hs"], L["top"], L["hh"], L["hw"]
    y = lambda k: top + hh * k
    st = p["style"]
    tw = hw * 0.92
    if st in ("quiff", "buzz", "flat"):
        old = D.HAIR
        D.HAIR = HR[:2]
        v = {"hair": st}
        s = D.hair_front(v, L, cx)
        D.HAIR = old
        return s.replace("#5a4332", HR[2]).replace("#6a5240", HR[2])
    if st == "bald":
        return (f'<ellipse cx="{f(cx - hw*0.3)}" cy="{f(top + 12*hs)}" rx="{f(12*hs)}" ry="{f(5*hs)}" fill="#fff" opacity="0.35" transform="rotate(-18 {f(cx - hw*0.3)} {f(top + 12*hs)})"/>'
                + "".join(f'<path d="M {f(cx + sd*(hw+1))} {f(y(0.30))} L {f(cx + sd*(hw-1))} {f(y(0.56))} L {f(cx + sd*(hw-8*hs))} {f(y(0.56))} L {f(cx + sd*(hw-7*hs))} {f(y(0.30))} Z" fill="{HR[0]}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>' for sd in (-1, 1)))
    if st == "sidepart":
        d = (f"M {f(cx - tw - 2)} {f(y(0.42))} C {f(cx - tw - 6)} {f(y(0.08))} {f(cx - hw*0.5)} {f(top - 9*hs)} {f(cx + hw*0.05)} {f(top - 10*hs)} "
             f"C {f(cx + hw*0.7)} {f(top - 11*hs)} {f(cx + tw + 6)} {f(y(0.02))} {f(cx + tw + 2)} {f(y(0.42))} "
             f"L {f(cx + tw - 3)} {f(y(0.30))} C {f(cx + tw - 6)} {f(y(0.16))} {f(cx + hw*0.2)} {f(y(0.20))} {f(cx - hw*0.32)} {f(y(0.13))} "
             f"C {f(cx - hw*0.6)} {f(y(0.18))} {f(cx - tw + 2)} {f(y(0.24))} {f(cx - tw - 2)} {f(y(0.42))} Z")
        s = shaded(d, HR[0], HR[1], dx=-5, dy=-5)
        s += f'<path d="M {f(cx - hw*0.32)} {f(y(0.13))} C {f(cx - hw*0.36)} {f(top + 2*hs)} {f(cx - hw*0.4)} {f(top - 4*hs)} {f(cx - hw*0.42)} {f(top - 6*hs)}" stroke="{HR[1]}" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
        s += f'<path d="M {f(cx - hw*0.1)} {f(top - 4*hs)} q {f(hw*0.4)} {f(-4*hs)} {f(hw*0.75)} {f(4*hs)}" stroke="{HR[2]}" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>'
    elif st == "curly":
        d = (f"M {f(cx - tw - 1)} {f(y(0.40))} C {f(cx - tw - 4)} {f(y(0.06))} {f(cx - hw*0.55)} {f(top - 6*hs)} {f(cx)} {f(top - 6*hs)} "
             f"C {f(cx + hw*0.55)} {f(top - 6*hs)} {f(cx + tw + 4)} {f(y(0.06))} {f(cx + tw + 1)} {f(y(0.40))} "
             f"L {f(cx + tw - 4)} {f(y(0.30))} C {f(cx + hw*0.6)} {f(y(0.22))} {f(cx - hw*0.6)} {f(y(0.22))} {f(cx - tw + 4)} {f(y(0.30))} Z")
        rng = random.Random(5)
        blobs = []
        for i in range(15):
            a = math.pi * (1.08 + 0.84 * i / 14)
            r = rng.uniform(9.5, 12.5) * hs
            bx = cx + math.cos(a) * (hw * 0.86)
            by = y(0.30) + math.sin(a) * (hh * 0.36)
            blobs.append((bx, by, r))
        for i in range(6):
            blobs.append((cx + rng.uniform(-hw * 0.55, hw * 0.55), top + rng.uniform(-2, 10) * hs, rng.uniform(10, 13) * hs))
        s = f'<path d="{d}" fill="{HR[0]}" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>'
        s += "".join(f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(r + 3)}" fill="{INK}"/>' for bx, by, r in blobs)
        s += "".join(f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(r)}" fill="{HR[0]}"/>' for bx, by, r in blobs)
        s += "".join(f'<path d="M {f(bx - r*0.5)} {f(by - r*0.1)} a {f(r*0.5)} {f(r*0.5)} 0 0 1 {f(r*0.8)} {f(-r*0.3)}" stroke="{HR[2]}" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.8"/>' for bx, by, r in blobs[::2])
        s += f'<path d="{d}" fill="{HR[0]}"/>'   # cover the inner outlines so curls read as one mass
        s += "".join(f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(r)}" fill="{HR[0]}"/>' for bx, by, r in blobs[15:])
        s += "".join(f'<path d="M {f(bx - r*0.5)} {f(by - r*0.1)} a {f(r*0.5)} {f(r*0.5)} 0 0 1 {f(r*0.8)} {f(-r*0.3)}" stroke="{HR[2]}" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.8"/>' for bx, by, r in blobs[15:])
    else:   # bun / pony: swept fringe + side locks
        d = (f"M {f(cx - tw - 3)} {f(y(0.62))} C {f(cx - tw - 8)} {f(y(0.10))} {f(cx - hw*0.5)} {f(top - 8*hs)} {f(cx + hw*0.05)} {f(top - 8*hs)} "
             f"C {f(cx + hw*0.65)} {f(top - 8*hs)} {f(cx + tw + 8)} {f(y(0.10))} {f(cx + tw + 3)} {f(y(0.62))} "
             f"L {f(cx + tw - 4)} {f(y(0.56))} C {f(cx + tw - 2)} {f(y(0.30))} {f(cx + hw*0.5)} {f(y(0.22))} {f(cx + hw*0.05)} {f(y(0.24))} "
             f"C {f(cx - hw*0.35)} {f(y(0.30))} {f(cx - hw*0.55)} {f(y(0.24))} {f(cx - hw*0.7)} {f(y(0.30))} "
             f"C {f(cx - tw + 1)} {f(y(0.36))} {f(cx - tw + 2)} {f(y(0.48))} {f(cx - tw + 4)} {f(y(0.56))} Z")
        s = shaded(d, HR[0], HR[1], dx=-5, dy=-5)
        s += f'<path d="M {f(cx - hw*0.45)} {f(top - 1*hs)} q {f(hw*0.35)} {f(-6*hs)} {f(hw*0.75)} {f(-1*hs)}" stroke="{HR[2]}" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.85"/>'
        if st == "bun":
            s += f'<path d="M {f(cx - 8*hs)} {f(top - 7*hs)} q {f(8*hs)} {f(4*hs)} {f(18*hs)} 0" stroke="{INK}" stroke-width="3" fill="none" stroke-linecap="round"/>'
    return s


# ------------------------------------------------------------------ body
OUTFITS = {
    # tier 0: crew-colour polo, chinos, sneakers
    0: dict(sleeve="short", pants=("#c8b48a", "#a08b62"), shoes="sneaker", belt="#5a3a22"),
    # tier 1: pale shirt, rolled sleeves, crew tie, navy trousers, brown shoes
    1: dict(sleeve="rolled", top=("#f3f6fa", "#c3cedb"), pants=("#34405a", "#252e42"), shoes="brown", belt="#3a2416"),
    # tier 2: dark suit, crew tie + pocket square, black shoes, gold watch
    2: dict(sleeve="long", top=("#34405e", "#232c42"), pants=("#34405e", "#232c42"), shoes="black", belt=None),
}


def lighten(hexc, k):
    c = [int(hexc[i:i + 2], 16) for i in (1, 3, 5)]
    c = [int(v + (255 - v) * k) if k > 0 else int(v * (1 + k)) for v in c]
    return "#%02x%02x%02x" % tuple(c)


def torso_path(b, L, hem=6):
    S, W, N = b["S"], b["W"], b["neck"]
    sy, hip = L["sy"], L["hip"]
    return (f"M {f(-N - 2)} {f(sy - 8)} C {f(-N - 18)} {f(sy - 6)} {f(-S + 14)} {f(sy - 4)} {f(-S)} {f(sy + 14)} "
            f"C {f(-S - 6)} {f(sy + 40)} {f(-W - 10)} {f(hip - 30)} {f(-W - 2)} {f(hip + hem)} "
            f"L {f(W + 2)} {f(hip + hem)} C {f(W + 10)} {f(hip - 30)} {f(S + 6)} {f(sy + 40)} {f(S)} {f(sy + 14)} "
            f"C {f(S - 14)} {f(sy - 4)} {f(N + 18)} {f(sy - 6)} {f(N + 2)} {f(sy - 8)} Z")


def tie(x, y0, y1, col, w=7.0):
    sh = lighten(col, -0.25)
    knot = f"M {f(x - w)} {f(y0 - 2)} L {f(x + w)} {f(y0 - 2)} L {f(x + w*0.6)} {f(y0 + 9)} L {f(x - w*0.6)} {f(y0 + 9)} Z"
    blade = f"M {f(x - w*0.55)} {f(y0 + 8)} L {f(x + w*0.55)} {f(y0 + 8)} L {f(x + w*1.15)} {f(y1 - 9)} L {f(x)} {f(y1)} L {f(x - w*1.15)} {f(y1 - 9)} Z"
    s = f'<path d="{blade}" fill="{col}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    s += f'<path d="M {f(x + w*0.3)} {f(y0 + 14)} L {f(x + w*0.75)} {f(y1 - 10)}" stroke="{sh}" stroke-width="3" stroke-linecap="round"/>'
    for k in range(3):   # a few diagonal stripes
        yy = y0 + 18 + k * 12
        s += f'<path d="M {f(x - w*0.8)} {f(yy + 4)} L {f(x + w*0.8)} {f(yy - 2)}" stroke="{lighten(col, 0.35)}" stroke-width="2" opacity="0.7"/>'
    s += f'<path d="{knot}" fill="{col}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    return s


def body(p, b, L, pose):
    tier = p["tier"]
    o = OUTFITS[tier]
    crew = p["crew"]
    S, W, N = b["S"], b["W"], b["neck"]
    sy, hip, ank, chin = L["sy"], L["hip"], L["ank"], L["chin"]
    SK = SKINS[p["skin"]]
    top_c = (crew, lighten(crew, -0.22)) if tier == 0 else o["top"]
    parts = {}
    # legs
    leg = (f"M {f(-W + 2)} {f(hip - 2)} C {f(-W - 4)} {f(hip + 20)} {f(-W + 3)} {f(ank - 14)} {f(-W + 6)} {f(ank)} "
           f"L {f(-4)} {f(ank)} L {f(-3)} {f(hip + 12)} L {f(3)} {f(hip + 12)} L {f(4)} {f(ank)} "
           f"L {f(W - 6)} {f(ank)} C {f(W - 3)} {f(ank - 14)} {f(W + 4)} {f(hip + 20)} {f(W - 2)} {f(hip - 2)} Z")
    crease = ""
    if tier > 0:
        for sd in (-1, 1):
            crease += f'<path d="M {f(sd*W*0.5)} {f(hip + 16)} L {f(sd*W*0.52)} {f(ank - 2)}" stroke="{o["pants"][1]}" stroke-width="2.5" stroke-linecap="round"/>'
    else:
        for sd in (-1, 1):   # chino side pocket slant
            crease += f'<path d="M {f(sd*(W - 4))} {f(hip + 4)} L {f(sd*(W - 14))} {f(hip + 18)}" stroke="{o["pants"][1]}" stroke-width="3" stroke-linecap="round"/>'
    parts["legs"] = shaded(leg, o["pants"][0], o["pants"][1], dx=-8, dy=-2, extra=crease)
    # shoes
    sh = ""
    for sd in (-1, 1):
        x0, x1 = (-W - 4, -1) if sd < 0 else (1, W + 4)
        if sd < 0:
            x0 -= 4
        else:
            x1 += 4
        d = (f"M {f(x0)} {f(GROUND)} L {f(x0)} {f(ank)} C {f(x0)} {f(ank - 9)} {f(x1)} {f(ank - 9)} {f(x1)} {f(ank)} L {f(x1 + 1)} {f(GROUND)} Z")
        if o["shoes"] == "sneaker":
            ex = (f'<rect x="{f(x0 - 3)}" y="{f(GROUND - 6)}" width="{f(x1 - x0 + 7)}" height="7" fill="#e8ecf1"/>'
                  f'<path d="M {f(x0 + 6)} {f(ank - 1)} q {f((x1 - x0)*0.35)} {f(6)} {f((x1 - x0)*0.7)} {f(-1)}" stroke="{crew}" stroke-width="4" fill="none" stroke-linecap="round"/>')
            sh += shaded(d, "#ffffff", "#c9d1db", dx=-4, dy=-3, extra=ex)
        elif o["shoes"] == "brown":
            sh += shaded(d, "#7a4a2a", "#57321b", dx=-4, dy=-3, light="#c08a5e", ldx=0, ldy=0, lw=0.01,
                         extra=f'<rect x="{f(x0 - 3)}" y="{f(GROUND - 5)}" width="{f(x1 - x0 + 7)}" height="6" fill="#2a1a10"/><ellipse cx="{f((x0 + x1)/2 - 4)}" cy="{f(ank - 3)}" rx="6" ry="2.5" fill="#fff" opacity="0.35"/>')
        else:
            sh += shaded(d, "#2a2d34", "#15171c", dx=-4, dy=-3,
                         extra=f'<rect x="{f(x0 - 3)}" y="{f(GROUND - 5)}" width="{f(x1 - x0 + 7)}" height="6" fill="#0c0d10"/><ellipse cx="{f((x0 + x1)/2 - 4)}" cy="{f(ank - 3)}" rx="7" ry="2.6" fill="#fff" opacity="0.55"/>')
    parts["shoes"] = sh
    # neck
    nd = f"M {f(-N + 2)} {f(chin - 30)} L {f(N - 2)} {f(chin - 30)} L {f(N + 4)} {f(sy + 4)} L {f(-N - 4)} {f(sy + 4)} Z"
    parts["neck"] = shaded(nd, SK[0], SK[1], dx=-4, dy=6)
    # torso + outfit detail (clipped) + overlay (on top, unclipped)
    hem = 14 if tier == 2 else 6
    td = torso_path(b, L, hem)
    det, over = "", ""
    lx, ly = -S * 0.42, sy + 30
    if tier == 0:
        det += f'<path d="M {f(-N + 1)} {f(sy - 8)} C {f(-N + 6)} {f(sy + 8)} {f(N - 6)} {f(sy + 8)} {f(N - 1)} {f(sy - 8)}" fill="{SK[0]}"/>'
        det += f'<path d="M {f(-6)} {f(sy + 4)} L {f(-6)} {f(sy + 32)} L {f(6)} {f(sy + 32)} L {f(6)} {f(sy + 4)}" fill="none" stroke="{top_c[1]}" stroke-width="3"/>'
        det += "".join(f'<circle cx="0" cy="{f(sy + 12 + k*11)}" r="2.6" fill="#fff" stroke="{INK}" stroke-width="1.5"/>' for k in range(2))
        det += f'<path d="M {f(lx)} {f(ly - 9)} C {f(lx + 6)} {f(ly - 1)} {f(lx + 7)} {f(ly + 4)} {f(lx)} {f(ly + 6)} C {f(lx - 7)} {f(ly + 4)} {f(lx - 6)} {f(ly - 1)} {f(lx)} {f(ly - 9)} Z" fill="#fff" stroke="{INK}" stroke-width="2"/>'
        bx_, by_ = S * 0.22, sy + 24   # name badge
        det += f'<rect x="{f(bx_)}" y="{f(by_)}" width="24" height="13" rx="3" fill="#fff" stroke="{INK}" stroke-width="2.2"/><rect x="{f(bx_ + 5)}" y="{f(by_ + 5)}" width="14" height="3" rx="1.5" fill="{crew}"/>'
        det += f'<path d="M {f(-S + 6)} {f(sy + 30)} C {f(-S*0.5)} {f(sy + 52)} {f(-10)} {f(sy + 52)} {f(-3)} {f(sy + 42)}" fill="none" stroke="{top_c[1]}" stroke-width="3" stroke-linecap="round" opacity="0.6"/>'
        for sd in (-1, 1):   # polo collar flaps
            cd = f"M {f(sd*(N + 3))} {f(sy - 10)} L {f(sd*2)} {f(sy + 6)} L {f(sd*(N - 2))} {f(sy + 14)} L {f(sd*(N + 10))} {f(sy + 2)} Z"
            over += f'<path d="{cd}" fill="{lighten(crew, 0.12)}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    elif tier == 1:
        det += f'<path d="M 0 {f(sy + 4)} L 0 {f(hip + 6)}" stroke="{top_c[1]}" stroke-width="2.5"/>'
        det += "".join(f'<circle cx="4" cy="{f(sy + 30 + k*16)}" r="2.2" fill="{top_c[1]}"/>' for k in range(4))
        px, py = -S * 0.62, sy + 26     # chest pocket + pen
        det += f'<path d="M {f(px)} {f(py)} L {f(px + 22)} {f(py)} L {f(px + 22)} {f(py + 18)} Q {f(px + 11)} {f(py + 22)} {f(px)} {f(py + 18)} Z" fill="none" stroke="{top_c[1]}" stroke-width="2.5"/>'
        det += f'<rect x="{f(px + 14)}" y="{f(py - 9)}" width="4" height="14" rx="1.5" fill="#1e63c8" stroke="{INK}" stroke-width="1.5"/>'
        det += f'<path d="M {f(S - 6)} {f(sy + 30)} C {f(S*0.5)} {f(sy + 50)} {f(18)} {f(sy + 54)} {f(10)} {f(sy + 46)}" fill="none" stroke="{top_c[1]}" stroke-width="3" stroke-linecap="round" opacity="0.7"/>'
        over += tie(0, sy - 2, sy + 62, crew)
        for sd in (-1, 1):
            cd = f"M {f(sd*(N + 4))} {f(sy - 11)} L {f(sd*3)} {f(sy - 2)} L {f(sd*(N - 6))} {f(sy + 12)} L {f(sd*(N + 10))} {f(sy)} Z"
            over += f'<path d="{cd}" fill="#ffffff" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    else:
        vb = sy + 50
        shirt_v = f"M {f(-N - 4)} {f(sy - 10)} L {f(N + 4)} {f(sy - 10)} L {f(N - 2)} {f(sy + 20)} L 0 {f(vb)} L {f(-N + 2)} {f(sy + 20)} Z"
        det += f'<path d="{shirt_v}" fill="#f3f6fa"/>'
        det += tie(0, sy - 2, vb + 4, crew, w=6.5)
        for sd in (-1, 1):   # lapels: notch near the collarbone, down to the button point
            lp = (f"M {f(sd*(N + 2))} {f(sy - 9)} L {f(sd*2)} {f(vb + 4)} L {f(sd*10)} {f(vb + 6)} "
                  f"L {f(sd*(S*0.55))} {f(sy + 22)} L {f(sd*(N + 14))} {f(sy + 12)} L {f(sd*(N + 20))} {f(sy + 2)} L {f(sd*(N + 14))} {f(sy - 6)} Z")
            det += f'<path d="{lp}" fill="{lighten(top_c[0], 0.12)}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        det += f'<path d="M {f(-S*0.62)} {f(sy + 38)} L {f(-S*0.28)} {f(sy + 38)} L {f(-S*0.30)} {f(sy + 32)} L {f(-S*0.40)} {f(sy + 28)} L {f(-S*0.48)} {f(sy + 33)} L {f(-S*0.56)} {f(sy + 29)} Z" fill="{crew}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
        det += f'<path d="M {f(-S*0.66)} {f(sy + 38)} L {f(-S*0.24)} {f(sy + 38)}" stroke="{INK}" stroke-width="2.5"/>'
        det += f'<path d="M 2 {f(vb + 6)} L 2 {f(hip + 14)}" stroke="{INK}" stroke-width="2.5"/>'
        det += "".join(f'<circle cx="7" cy="{f(vb + 14 + k*16)}" r="3" fill="{lighten(top_c[0], 0.25)}" stroke="{INK}" stroke-width="1.5"/>' for k in range(2))
        for sd in (-1, 1):   # hip pocket flaps
            det += f'<path d="M {f(sd*(W - 2))} {f(hip - 8)} L {f(sd*(W*0.35))} {f(hip - 8)}" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>'
        for sd in (-1, 1):
            cd = f"M {f(sd*(N + 2))} {f(sy - 11)} L {f(sd*3)} {f(sy - 2)} L {f(sd*(N - 6))} {f(sy + 10)} L {f(sd*(N + 8))} {f(sy - 1)} Z"
            over += f'<path d="{cd}" fill="#ffffff" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    parts["torso"] = shaded(td, top_c[0], top_c[1], dx=-12, dy=-4, extra=det) + over
    if o["belt"]:
        bd = f"M {f(-W - 3)} {f(hip - 2)} L {f(W + 3)} {f(hip - 2)} L {f(W + 2)} {f(hip + 8)} L {f(-W - 2)} {f(hip + 8)} Z"
        parts["belt"] = (f'<path d="{bd}" fill="{o["belt"]}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
                         f'<rect x="-7" y="{f(hip - 1)}" width="14" height="8" rx="2" fill="#d6c08a" stroke="{INK}" stroke-width="2.5"/>')
        # polo / shirt tucked in: the belt sits over the torso hem
    else:
        parts["belt"] = ""
    return parts, top_c


def hand(p, at, d, r=15.0, open_=False):
    """Bare fist at `at`, pointing along unit vector d."""
    SK = SKINS[p["skin"]]
    hx, hy = at[0] + d[0] * r * 0.5, at[1] + d[1] * r * 0.5
    nx, ny = -d[1], d[0]
    kn = "".join(f'<path d="M {f(hx + nx*k*5.5 + d[0]*3)} {f(hy + ny*k*5.5 + d[1]*3)} L {f(hx + nx*k*5.5 + d[0]*8)} {f(hy + ny*k*5.5 + d[1]*8)}" stroke="{SK[1]}" stroke-width="2.4" stroke-linecap="round"/>' for k in (-1, 0, 1))
    return shaded(ellipse_d(hx, hy, r, r * 0.92), SK[0], SK[1], dx=-4, dy=-4, extra=kn)


def upper_arm(p, b, L, top_c, sh, el, side, anchor):
    o = OUTFITS[p["tier"]]
    SK = SKINS[p["skin"]]
    ua = limb(sh, el, 38, 28, bulge=7)
    v = {"shirt": top_c}
    if o["sleeve"] == "short":
        s = shaded(ua, SK[0], SK[1], dx=-6, dy=-4)
        s += D.attached_sleeve(v, sh, el, side, anchor, hem_t=0.52)
    else:
        s = shaded(ua, top_c[0], top_c[1], dx=-6, dy=-4)
        s += D.attached_sleeve(v, sh, el, side, anchor, hem_t=0.5).replace(f'stroke="{top_c[1]}" stroke-width="2.5"', 'stroke="none"')
    return s


def forearm(p, top_c, el, wr, watch=False):
    o = OUTFITS[p["tier"]]
    SK = SKINS[p["skin"]]
    L_ = math.hypot(wr[0] - el[0], wr[1] - el[1]) or 1
    d = ((wr[0] - el[0]) / L_, (wr[1] - el[1]) / L_)
    nx, ny = -d[1], d[0]
    fa = limb(el, wr, 28, 21, bulge=5)
    s = ""
    if o["sleeve"] == "long":
        s += shaded(fa, top_c[0], top_c[1], dx=-5, dy=-4)
        cx_, cy_ = wr[0] - d[0] * 3, wr[1] - d[1] * 3
        s += f'<path d="M {f(cx_ + nx*11)} {f(cy_ + ny*11)} L {f(cx_ - nx*11)} {f(cy_ - ny*11)}" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
        s += f'<path d="M {f(cx_ + nx*10)} {f(cy_ + ny*10)} L {f(cx_ - nx*10)} {f(cy_ - ny*10)}" stroke="#f3f6fa" stroke-width="5.5" stroke-linecap="round"/>'
    else:
        s += shaded(fa, SK[0], SK[1], dx=-5, dy=-4)
        if o["sleeve"] == "rolled":
            rx_, ry_ = el[0] + d[0] * 13, el[1] + d[1] * 13
            s += f'<path d="M {f(rx_ + nx*17)} {f(ry_ + ny*17)} L {f(rx_ - nx*17)} {f(ry_ - ny*17)}" stroke="{INK}" stroke-width="15" stroke-linecap="round"/>'
            s += f'<path d="M {f(rx_ + nx*16)} {f(ry_ + ny*16)} L {f(rx_ - nx*16)} {f(ry_ - ny*16)}" stroke="{top_c[0]}" stroke-width="10" stroke-linecap="round"/>'
            s += f'<path d="M {f(rx_ + nx*14 + d[0]*2)} {f(ry_ + ny*14 + d[1]*2)} L {f(rx_ - nx*14 + d[0]*2)} {f(ry_ - ny*14 + d[1]*2)}" stroke="{top_c[1]}" stroke-width="2.5" stroke-linecap="round"/>'
    if watch:
        wx, wy = wr[0] - d[0] * 7, wr[1] - d[1] * 7
        s += f'<path d="M {f(wx + nx*11)} {f(wy + ny*11)} L {f(wx - nx*11)} {f(wy - ny*11)}" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
        s += f'<path d="M {f(wx + nx*10)} {f(wy + ny*10)} L {f(wx - nx*10)} {f(wy - ny*10)}" stroke="#e7b93c" stroke-width="4.5" stroke-linecap="round"/>'
        s += f'<circle cx="{f(wx)}" cy="{f(wy)}" r="5" fill="#fff4cc" stroke="{INK}" stroke-width="2"/>'
    return s, d


def clipboard(x, y, ang=-6, k=1.0):
    s = f'<g transform="rotate({ang} {f(x)} {f(y)}) translate({f(x)} {f(y)}) scale({k}) translate({f(-x)} {f(-y)})">'
    s += f'<rect x="{f(x - 22)}" y="{f(y - 30)}" width="44" height="58" rx="5" fill="#a87a4f" stroke="{INK}" stroke-width="4"/>'
    s += f'<rect x="{f(x - 17)}" y="{f(y - 22)}" width="34" height="46" rx="2" fill="#fbfbf7"/>'
    for k in range(4):
        s += f'<rect x="{f(x - 12)}" y="{f(y - 14 + k*9)}" width="{24 if k % 2 == 0 else 18}" height="3" rx="1.5" fill="#9fb0c0"/>'
    s += f'<path d="M {f(x - 11)} {f(y - 15)} l 3 3 l 5 -6" stroke="#2fa84f" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    s += f'<rect x="{f(x - 10)}" y="{f(y - 35)}" width="20" height="9" rx="3" fill="#b8c2cc" stroke="{INK}" stroke-width="2.5"/>'
    return s + "</g>"


def figure(p, pose=2, mood=None, phase=1.0):
    """Front-facing manager. pose 0 arm pump (phase 0 = arm down, 1 = up), 1 arms crossed,
    2 hands on hips, 3 clipboard + pen."""
    b = BUILDS[p.get("build", "stocky")]
    L = layout(b)
    S, N, W = b["S"], b["neck"], b["W"]
    sy, hip = L["sy"], L["hip"]
    parts, top_c = body(p, b, L, pose)
    if mood is None:
        mood = {0: "grin", 1: "smirk", 2: "smile", 3: "flat"}[pose]
    out = [parts["legs"], parts["shoes"], parts["neck"], parts["torso"], parts["belt"]]
    anc = bez((S, sy + 14), (S - 14, sy - 4), (N + 18, sy - 6), (N + 2, sy - 8), 0.30)
    sh = {s: (s * (S - 12), sy + 18) for s in (-1, 1)}
    an = {s: (s * anc[0], anc[1]) for s in (-1, 1)}
    watch = p["tier"] == 2
    front = []

    def full(side, el, wr, wt=False, hold=None):
        fs, d = forearm(p, top_c, el, wr, wt)
        s = fs + upper_arm(p, b, L, top_c, sh[side], el, side, an[side]) + hand(p, wr, d)
        return s

    if pose == 2:      # hands on hips
        for side in (-1, 1):
            el = (side * (S + 26), sy + 50)
            wr = (side * (W + 6), hip - 10)
            out.append(full(side, el, wr, watch and side < 0))
    elif pose == 1:    # arms crossed: forearms make a shallow X; one fist on the biceps, the other tucked away
        el_l, el_r = (-(S + 2), sy + 70), (S + 2, sy + 66)
        out.append(upper_arm(p, b, L, top_c, sh[-1], el_l, -1, an[-1]))
        # back forearm (image-right arm) rises to the left: its fist sits on the left biceps
        fs, d = forearm(p, top_c, el_r, (-S + 18, sy + 38))
        out.append(fs + hand(p, (-S + 18, sy + 38), d, r=14))
        # front forearm (image-left arm) rises to the right, hand tucked under the right upper arm
        fs, d = forearm(p, top_c, el_l, (S - 6, sy + 50), watch)
        out.append(fs)
        out.append(upper_arm(p, b, L, top_c, sh[1], el_r, 1, an[1]))
    elif pose == 0:    # arm pump: image-right arm punches up, the other on the hip
        out.append(full(-1, (-(S + 26), sy + 50), (-(W + 6), hip - 10), watch))
        k = phase
        el = ((S + 10) + 18 * k, sy + 56 - 52 * k)
        wr = ((S + 4) + 4 * k, sy + 96 - 140 * k)
        if k > 0.6:   # little motion arcs
            out.append(f'<path d="M {f(S + 38)} {f(sy - 56)} q 12 4 14 18 M {f(S - 22)} {f(sy - 58)} q -10 6 -10 18" stroke="{INK}" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
        front.append(full(1, el, wr))
    else:              # clipboard in the image-left hand, pen in the other
        el_l, el_r = (-(S + 6), sy + 62), (S + 6, sy + 62)
        hold_wr = (-S * 0.45, sy + 84)
        out.append(upper_arm(p, b, L, top_c, sh[-1], el_l, -1, an[-1]))
        out.append(upper_arm(p, b, L, top_c, sh[1], el_r, 1, an[1]))
        fs, d = forearm(p, top_c, el_l, hold_wr, watch)
        out.append(fs)
        out.append(clipboard(-S * 0.12, sy + 50, -12, k=1.25))
        out.append(hand(p, hold_wr, d, r=14))
        pen_wr = (S * 0.36, sy + 40)
        fs, d = forearm(p, top_c, el_r, pen_wr)
        out.append(fs)
        hx, hy = pen_wr[0] + d[0] * 6, pen_wr[1] + d[1] * 6
        out.append(f'<path d="M {f(hx + 4)} {f(hy - 6)} L {f(hx - 18)} {f(hy + 6)}" stroke="{INK}" stroke-width="8" stroke-linecap="round"/><path d="M {f(hx + 4)} {f(hy - 6)} L {f(hx - 18)} {f(hy + 6)}" stroke="#1e63c8" stroke-width="4" stroke-linecap="round"/>')
        out.append(hand(p, pen_wr, d, r=13))
    out.append(head(p, L, mood))
    out.extend(front)
    return "".join(out)


def shadow(col, op=0.5):
    return f'<ellipse cx="0" cy="{f(GROUND)}" rx="92" ry="17" fill="{col}" opacity="{op}"/>'
