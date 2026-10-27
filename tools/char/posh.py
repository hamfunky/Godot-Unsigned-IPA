"""Posh cash managers (19 Oct, Hamza): SKINNY, scrawny, posh, everyone in suits. Very different from the
chunky detailers; only the cartoon theme is shared (ink outlines, cel shading, palette).
Rank = age, read mostly from the hair colour: Junior young (natural colour), Senior middle-aged (greying),
Executive old (white / silver). Few wrinkles on the old ones (Hamza: looks ugly).
Front view. Poses = today's idle loops: 0 arm pump, 1 arms crossed, 2 hands on hips, 3 clipboard.
"""
import math, random, sys
sys.path.insert(0, "/root/char")
import detailer as D
from detailer import f, P, limb, shaded, ellipse_d, INK, GROUND

OUT = 5.5
HEAD_SCALE = 1.38   # compact look: bigger head
SKINS = [("#f4cfa6", "#d9a97c"), ("#e8b48a", "#c98e63"), ("#c58a5c", "#9e6539"),
         ("#8d5a3a", "#6b4026"), ("#fbe0c8", "#e6b996")]


def lighten(hexc, k):
    c = [int(hexc[i:i + 2], 16) for i in (1, 3, 5)]
    c = [int(v + (255 - v) * k) if k > 0 else int(v * (1 + k)) for v in c]
    return "#%02x%02x%02x" % tuple(c)


def blobs(pts, fill, shade=None, ink=True, sw=OUT):
    """Fluffy hair mass from circles (ink ring first, then fill), like the detailer's wash mitt."""
    s = ""
    if ink:
        s += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r + sw * 0.55)}" fill="{INK}"/>' for x, y, r in pts)
    if shade:
        s += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{shade}"/>' for x, y, r in pts)
        s += "".join(f'<circle cx="{f(x - r*0.18)}" cy="{f(y - r*0.22)}" r="{f(r*0.78)}" fill="{fill}"/>' for x, y, r in pts)
    else:
        s += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"/>' for x, y, r in pts)
    return s


# ------------------------------------------------------------------ layout
def layout(p):
    fem = p.get("fem", False)
    ank = GROUND - 12
    hip = ank - (62 if not fem else 60)      # compact (Hamza 19 Oct): short legs, big head
    sy = hip - 70
    chin = sy - 12           # long neck (the collar hides the bottom of it)
    hh, hw = 80.0, 28.0
    S = (38 if not fem else 34) + (3 if p.get("tier", 2) == 0 else 0)   # Junior: jacket a size too big
    return dict(ank=ank, hip=hip, sy=sy, chin=chin, top=chin - hh, hh=hh, hw=hw,
                S=S, W=24 if not fem else 22)


# ------------------------------------------------------------------ head
def young_eye(p, cx, ey, sd, SK, tier):
    """Junior: big round open eyes with two sparkles. Senior: a light lid over the top third (calm, not snooty)."""
    fem = p.get("fem", False)
    rx, ry = (7.2, 7.4) if tier == 0 else (7.0, 6.0)
    cy = ey - (1.2 if tier == 0 else 0.0)
    cid = D.uid("ye")
    e = ellipse_d(cx, cy, rx, ry)
    iris = p.get("iris", "#5a3a22")
    ir = 4.6 if tier == 0 else 3.9
    iy = cy + (0.6 if tier == 0 else 1.6)
    ix = cx + 1.8 * float(p.get("turn", 0))      # irises look towards the workers
    s = f'<clipPath id="{cid}"><path d="{e}"/></clipPath><path d="{e}" fill="#fbf8f3"/>'
    s += (f'<g clip-path="url(#{cid})"><circle cx="{f(ix)}" cy="{f(iy)}" r="{ir}" fill="{iris}"/>'
          f'<circle cx="{f(ix)}" cy="{f(iy)}" r="{ir*0.55}" fill="{INK}"/>'
          f'<circle cx="{f(ix - 1.6)}" cy="{f(iy - 1.6)}" r="{1.6 if tier == 0 else 1.1}" fill="#fff"/>')
    if tier == 0:
        s += f'<circle cx="{f(ix + 1.8)}" cy="{f(iy + 1.8)}" r="0.8" fill="#fff"/>'
    else:
        s += (f'<rect x="{f(cx - rx - 1)}" y="{f(cy - ry - 1)}" width="{f(rx*2 + 2)}" height="{f(ry*0.62)}" fill="{SK[0]}"/>')
    s += '</g>'
    s += f'<path d="{e}" fill="none" stroke="{INK}" stroke-width="1.8"/>'
    if tier == 0:   # lash line on top
        s += f'<path d="M {f(cx - rx)} {f(cy - 0.5)} C {f(cx - rx)} {f(cy - ry*1.25)} {f(cx + rx)} {f(cy - ry*1.25)} {f(cx + rx)} {f(cy - 0.5)}" stroke="{INK}" stroke-width="2.8" fill="none" stroke-linecap="round"/>'
    else:
        ly = cy - ry + ry * 0.62 - 0.5
        s += f'<path d="M {f(cx - rx - 0.5)} {f(ly + 1.4)} Q {f(cx)} {f(ly - 1.6)} {f(cx + rx + 0.5)} {f(ly + 1.4)}" stroke="{INK}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    if fem:
        s += f'<path d="M {f(cx + sd*rx*0.9)} {f(cy - ry*0.5)} l {f(sd*4)} {f(-3)} M {f(cx + sd*rx*0.55)} {f(cy - ry*0.85)} l {f(sd*2.5)} {f(-3.5)}" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>'
    return s


# ------------------------------------------------------------------ head (all tiers)
def head(p, L, mood="smug"):
    top, chin, hh, hw = L["top"], L["chin"], L["hh"], L["hw"]
    y = lambda k: top + hh * k
    SK = SKINS[p["skin"]]
    hair = p["hair"]           # (base, shade, light)
    fem = p.get("fem", False)
    out = []
    style = p["style"]
    # ---- hair behind the head
    if style == "tufts":       # bald dome, big white tufts out over the ears (the professor)
        rng = random.Random(3)
        for sd in (-1, 1):
            pts = []
            for i in range(9):
                a = rng.uniform(-0.9, 0.9)
                pts.append((sd * (hw + 6 + rng.uniform(0, 13)), y(0.36) + a * 14, rng.uniform(6.5, 9.5)))
            out.append(blobs(pts, hair[0], hair[1]))
    elif style == "bouffant":  # tall silver bouffant (the dame)
        rng = random.Random(9)
        pts = [(math.cos(a) * hw * 1.15, y(0.22) + math.sin(a) * hh * 0.33, rng.uniform(10, 13))
               for a in [math.pi * (0.92 + 1.16 * i / 13) for i in range(14)]]
        pts += [(rng.uniform(-hw * 0.7, hw * 0.7), y(0.02) + rng.uniform(-8, 6), rng.uniform(11, 14)) for _ in range(6)]
        pts += [(sd * (hw + 4), y(0.48) + k * 9, 9.5 - k) for sd in (-1, 1) for k in range(3)]
        out.append(blobs(pts, hair[0], hair[1]))
    elif style == "bob":       # chin-length bob (behind the face)
        d = (f"M {f(-hw - 7)} {f(y(0.84))} C {f(-hw - 12)} {f(y(0.30))} {f(-hw*0.7)} {f(top - 9)} 0 {f(top - 9)} "
             f"C {f(hw*0.7)} {f(top - 9)} {f(hw + 12)} {f(y(0.30))} {f(hw + 7)} {f(y(0.84))} "
             f"Q {f(hw*0.6)} {f(y(0.90))} {f(hw*0.4)} {f(y(0.80))} L {f(-hw*0.4)} {f(y(0.80))} Q {f(-hw*0.6)} {f(y(0.90))} {f(-hw - 7)} {f(y(0.84))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
    elif style == "highpony":  # bouncy high ponytail
        d = (f"M {f(hw*0.2)} {f(top + 4)} C {f(hw*0.9)} {f(top - 26)} {f(hw*2.1)} {f(top - 10)} {f(hw*1.9)} {f(y(0.40))} "
             f"C {f(hw*1.8)} {f(y(0.55))} {f(hw*1.4)} {f(y(0.62))} {f(hw*1.2)} {f(y(0.58))} "
             f"C {f(hw*1.5)} {f(y(0.40))} {f(hw*1.4)} {f(top + 2)} {f(hw*0.5)} {f(top + 12)} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
        out.append(f'<circle cx="{f(hw*0.62)}" cy="{f(top + 2)}" r="5" fill="{p["crew"]}" stroke="{INK}" stroke-width="2.4"/>')
    elif style == "lowbun":    # neat low bun (the senior lady)
        out.append(shaded(ellipse_d(hw * 0.95, y(0.30), 13, 12), hair[0], hair[1], dx=-3, dy=-3, sw=OUT))
    # ---- ears
    turn = float(p.get("turn", 0.0))       # 0 = facing you, 0.75 = turned towards their workers (+x)
    for sd in (-1, 1):
        if sd > 0 and turn > 0:
            out.append(shaded(ellipse_d(hw - 1 - 2 * turn, y(0.50), 6.5 * (1 - 0.55 * turn), 10), SK[0], SK[1], dx=-2, dy=-2, sw=OUT * 0.8))
        else:
            out.append(shaded(ellipse_d(sd * (hw + 1), y(0.50), 6.5, 10), SK[0], SK[1], dx=-2, dy=-2, sw=OUT * 0.8))
    # ---- face: long, narrow, pointed chin
    jw = hw * (0.62 if fem else 0.70)
    d = (f"M 0 {f(top)} C {f(hw*0.62)} {f(top)} {f(hw*0.98)} {f(y(0.14))} {f(hw)} {f(y(0.36))} "
         f"C {f(hw + 1)} {f(y(0.58))} {f(hw*0.92)} {f(y(0.70))} {f(jw)} {f(y(0.86))} "
         f"C {f(jw*0.62)} {f(y(0.97))} {f(hw*0.22)} {f(chin)} 0 {f(chin)} "
         f"C {f(-hw*0.22)} {f(chin)} {f(-jw*0.62)} {f(y(0.97))} {f(-jw)} {f(y(0.86))} "
         f"C {f(-hw*0.92)} {f(y(0.70))} {f(-hw - 1)} {f(y(0.58))} {f(-hw)} {f(y(0.36))} "
         f"C {f(-hw*0.98)} {f(y(0.14))} {f(-hw*0.62)} {f(top)} 0 {f(top)} Z")
    extra = ""
    if style == "tufts":   # shiny dome
        extra += f'<ellipse cx="{f(-hw*0.32)}" cy="{f(y(0.10))}" rx="9" ry="4" fill="#fff" opacity="0.55" transform="rotate(-25 {f(-hw*0.32)} {f(y(0.10))})"/>'
    out.append(shaded(d, SK[0], SK[1], dx=-7, dy=-5, extra=extra, sw=OUT))
    # ---- hair on top of the face
    if style == "slick":
        d = (f"M {f(-hw - 3)} {f(y(0.50))} C {f(-hw - 5)} {f(y(0.10))} {f(-hw*0.45)} {f(top - 8)} 0 {f(top - 8)} "
             f"C {f(hw*0.45)} {f(top - 8)} {f(hw + 5)} {f(y(0.10))} {f(hw + 3)} {f(y(0.50))} "
             f"L {f(hw - 2)} {f(y(0.40))} C {f(hw - 3)} {f(y(0.22))} {f(hw*0.55)} {f(y(0.08))} {f(hw*0.2)} {f(y(0.10))} "
             f"L 0 {f(y(0.22))} L {f(-hw*0.2)} {f(y(0.10))} "
             f"C {f(-hw*0.55)} {f(y(0.08))} {f(-hw + 3)} {f(y(0.22))} {f(-hw + 2)} {f(y(0.40))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
    elif style == "bouffant":
        rng = random.Random(4)
        fr = [(-hw * 0.75 + i * hw * 0.3, y(0.18) + rng.uniform(-3, 2) + abs(i - 2.5) * 2.5, 9.5) for i in range(6)]
        out.append(blobs(fr, hair[0], hair[1]))
    elif style == "swoop":     # big shiny swoop of a quiff (young and keen)
        d = (f"M {f(-hw - 2)} {f(y(0.46))} C {f(-hw - 5)} {f(y(0.08))} {f(-hw*0.6)} {f(top - 8)} {f(-hw*0.1)} {f(top - 12)} "
             f"C {f(hw*0.3)} {f(top - 19)} {f(hw*1.1)} {f(top - 18)} {f(hw + 10)} {f(top - 6)} "
             f"C {f(hw + 4)} {f(top - 4)} {f(hw + 5)} {f(y(0.12))} {f(hw + 2)} {f(y(0.46))} "
             f"L {f(hw - 2)} {f(y(0.34))} C {f(hw - 3)} {f(y(0.20))} {f(hw*0.5)} {f(y(0.12))} {f(hw*0.1)} {f(y(0.16))} "
             f"C {f(-hw*0.3)} {f(y(0.20))} {f(-hw*0.7)} {f(y(0.18))} {f(-hw + 2)} {f(y(0.34))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
        out.append(f'<path d="M {f(-hw*0.3)} {f(top - 7)} C {f(hw*0.1)} {f(top - 15)} {f(hw*0.6)} {f(top - 15)} {f(hw*0.95)} {f(top - 8)}" stroke="{hair[2]}" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
    elif style == "curlytop":  # curls on top, short sides
        rng = random.Random(12)
        pts = [(math.cos(a) * hw * 0.92, y(0.24) + math.sin(a) * hh * 0.30, rng.uniform(7.5, 9.5))
               for a in [math.pi * (1.05 + 0.9 * i / 11) for i in range(12)]]
        pts += [(rng.uniform(-hw * 0.6, hw * 0.6), top - 2 + rng.uniform(-6, 6), rng.uniform(8, 10)) for _ in range(6)]
        cap = (f"M {f(-hw)} {f(y(0.40))} C {f(-hw - 2)} {f(y(0.12))} {f(-hw*0.5)} {f(top - 4)} 0 {f(top - 4)} "
               f"C {f(hw*0.5)} {f(top - 4)} {f(hw + 2)} {f(y(0.12))} {f(hw)} {f(y(0.40))} "
               f"L {f(hw - 3)} {f(y(0.30))} Q 0 {f(y(0.16))} {f(-hw + 3)} {f(y(0.30))} Z")
        out.append(f'<path d="{cap}" fill="{hair[0]}" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>')
        out.append(blobs(pts, hair[0], hair[1]))
    elif style == "bob":       # straight fringe
        d = (f"M {f(-hw - 2)} {f(y(0.40))} C {f(-hw - 4)} {f(y(0.06))} {f(-hw*0.6)} {f(top - 7)} 0 {f(top - 7)} "
             f"C {f(hw*0.6)} {f(top - 7)} {f(hw + 4)} {f(y(0.06))} {f(hw + 2)} {f(y(0.40))} "
             f"L {f(hw - 2)} {f(y(0.30))} C {f(hw*0.4)} {f(y(0.32))} {f(-hw*0.4)} {f(y(0.32))} {f(-hw + 2)} {f(y(0.30))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
        out.append(f'<rect x="{f(hw*0.30)}" y="{f(y(0.20))}" width="14" height="6" rx="3" fill="{p["crew"]}" stroke="{INK}" stroke-width="2.2" transform="rotate(-20 {f(hw*0.30)} {f(y(0.20))})"/>')
    elif style in ("highpony", "lowbun", "sidepart"):   # neat cap with a side part
        d = (f"M {f(-hw - 2)} {f(y(0.48))} C {f(-hw - 6)} {f(y(0.06))} {f(-hw*0.5)} {f(top - 8)} {f(hw*0.05)} {f(top - 9)} "
             f"C {f(hw*0.7)} {f(top - 10)} {f(hw + 6)} {f(y(0.04))} {f(hw + 2)} {f(y(0.48))} "
             f"L {f(hw - 2)} {f(y(0.32))} C {f(hw - 5)} {f(y(0.16))} {f(hw*0.2)} {f(y(0.20))} {f(-hw*0.32)} {f(y(0.12))} "
             f"C {f(-hw*0.6)} {f(y(0.18))} {f(-hw + 2)} {f(y(0.24))} {f(-hw + 2)} {f(y(0.32))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-4, dy=-4, sw=OUT))
        out.append(f'<path d="M {f(-hw*0.32)} {f(y(0.12))} C {f(-hw*0.36)} {f(top + 2)} {f(-hw*0.4)} {f(top - 3)} {f(-hw*0.42)} {f(top - 6)}" stroke="{hair[1]}" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
        out.append(f'<path d="M {f(-hw*0.1)} {f(top - 4)} q {f(hw*0.4)} -4 {f(hw*0.75)} 3" stroke="{hair[2]}" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.8"/>')
    elif style == "receding":  # high forehead, a little tuft at the front
        d = (f"M {f(-hw - 2)} {f(y(0.48))} C {f(-hw - 5)} {f(y(0.10))} {f(-hw*0.7)} {f(top - 3)} {f(-hw*0.4)} {f(top - 4)} "
             f"L {f(-hw*0.55)} {f(y(0.18))} C {f(-hw*0.8)} {f(y(0.20))} {f(-hw + 2)} {f(y(0.28))} {f(-hw + 2)} {f(y(0.34))} Z")
        out.append(shaded(d, hair[0], hair[1], dx=-3, dy=-3, sw=OUT))
        d2 = (f"M {f(hw + 2)} {f(y(0.48))} C {f(hw + 5)} {f(y(0.10))} {f(hw*0.7)} {f(top - 3)} {f(hw*0.4)} {f(top - 4)} "
              f"L {f(hw*0.55)} {f(y(0.18))} C {f(hw*0.8)} {f(y(0.20))} {f(hw - 2)} {f(y(0.28))} {f(hw - 2)} {f(y(0.34))} Z")
        out.append(shaded(d2, hair[0], hair[1], dx=-3, dy=-3, sw=OUT))
        tuft = [(-4, top, 4.5), (1, top - 1.5, 5), (5, top + 0.5, 4)]
        out.append(blobs(tuft, hair[0], hair[1], sw=4))
    if p.get("temples"):       # greying temples (Senior)
        g = p["temples"]
        for sd in (-1, 1):
            td_ = f"M {f(sd*(hw + 2))} {f(y(0.30))} L {f(sd*(hw + 2))} {f(y(0.48))} L {f(sd*(hw - 3))} {f(y(0.46))} L {f(sd*(hw - 3))} {f(y(0.32))} Z"
            out.append(f'<path d="{td_}" fill="{g}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    tier = p.get("tier", 2)
    feat_at = len(out)          # everything from here to the moustache is the face: shifted for the turn
    fs = turn * hw * 0.36       # face shift towards the workers
    fsc = 1 - 0.12 * turn       # and a little narrower
    # ---- brows (bushy for the old ones, arched up at the outer end = posh)
    ey = y(0.47)
    ex = hw * 0.37
    bcol = p.get("brow", hair)
    for sd in (-1, 1):
        if p.get("bushy"):
            pts = [(sd * (ex - 7 + i * 4.2), ey - 13 - i * 1.6, 4.6 + (i % 2) * 0.8) for i in range(5)]
            out.append(blobs(pts, bcol[0], bcol[1], sw=3.5))
        elif tier == 0:   # high, round, friendly
            bd = (f"M {f(sd*(ex - 7))} {f(ey - 17)} Q {f(sd*(ex))} {f(ey - 23)} {f(sd*(ex + 8))} {f(ey - 17)} "
                  f"L {f(sd*(ex + 7.5))} {f(ey - 15)} Q {f(sd*(ex))} {f(ey - 20)} {f(sd*(ex - 6.5))} {f(ey - 14.8)} Z")
            out.append(f'<path d="{bd}" fill="{bcol[0]}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>')
        elif tier == 1:
            bd = (f"M {f(sd*(ex - 8))} {f(ey - 13)} Q {f(sd*(ex + 1))} {f(ey - 17)} {f(sd*(ex + 10))} {f(ey - 13.5)} "
                  f"L {f(sd*(ex + 9.5))} {f(ey - 11)} Q {f(sd*(ex + 1))} {f(ey - 14)} {f(sd*(ex - 7.5))} {f(ey - 10.5)} Z")
            out.append(f'<path d="{bd}" fill="{bcol[0]}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>')
        else:
            bd = (f"M {f(sd*(ex - 9))} {f(ey - 10)} Q {f(sd*(ex + 2))} {f(ey - 17)} {f(sd*(ex + 11))} {f(ey - 15)} "
                  f"L {f(sd*(ex + 10))} {f(ey - 12)} Q {f(sd*(ex + 1))} {f(ey - 13)} {f(sd*(ex - 8))} {f(ey - 7)} Z")
            out.append(f'<path d="{bd}" fill="{bcol[0]}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>')
    # ---- eyes: heavy lids half shut, looking down the nose
    for sd in (-1, 1):
        if tier < 2:
            out.append(young_eye(p, sd * ex, ey, sd, SK, tier))
            continue
        cx, rx, ry = sd * ex, 7.0, 5.6
        cid = D.uid("pe")
        e = ellipse_d(cx, ey, rx, ry)
        s = f'<clipPath id="{cid}"><path d="{e}"/></clipPath><path d="{e}" fill="#f7f3ee"/>'
        s += (f'<g clip-path="url(#{cid})"><circle cx="{f(cx + 0.6 + 2.0 * float(p.get("turn", 0)))}" cy="{f(ey + 2.4)}" r="3.6" fill="{p.get("iris", "#4a6a8a")}"/>'
              f'<circle cx="{f(cx + 0.6 + 2.0 * float(p.get("turn", 0)))}" cy="{f(ey + 2.4)}" r="2" fill="{INK}"/>'
              f'<circle cx="{f(cx - 0.6)}" cy="{f(ey + 1.4)}" r="0.9" fill="#fff"/>'
              f'<rect x="{f(cx - rx - 1)}" y="{f(ey - ry - 1)}" width="{f(rx*2 + 2)}" height="{f(ry + 0.8)}" fill="{SK[0]}"/>'
              f'<rect x="{f(cx - rx - 1)}" y="{f(ey - 0.6)}" width="{f(rx*2 + 2)}" height="1.6" fill="{SK[1]}"/></g>')
        s += f'<path d="{e}" fill="none" stroke="{INK}" stroke-width="1.8"/>'
        s += f'<path d="M {f(cx - rx - 1)} {f(ey + 0.2)} Q {f(cx)} {f(ey - 1.6)} {f(cx + rx + 1)} {f(ey + 0.2)}" stroke="{INK}" stroke-width="3" fill="none" stroke-linecap="round"/>'
        if fem:
            s += f'<path d="M {f(cx + sd*rx)} {f(ey)} l {f(sd*4)} {f(-3.5)}" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'
        out.append(s)
    if p.get("monocle"):
        mx = -ex
        out.append(f'<circle cx="{f(mx)}" cy="{f(ey + 0.5)}" r="10.5" fill="#cfe8ff" opacity="0.35" stroke="{INK}" stroke-width="4.5"/>'
                   f'<circle cx="{f(mx)}" cy="{f(ey + 0.5)}" r="10.5" fill="none" stroke="#e7b93c" stroke-width="2.2"/>'
                   f'<path d="M {f(mx - 7)} {f(ey + 8)} C {f(mx - 18)} {f(ey + 30)} {f(-hw - 2)} {f(L["sy"] + 4)} {f(-hw*0.9)} {f(L["sy"] + 26)}" stroke="#e7b93c" stroke-width="1.8" fill="none"/>'
                   f'<path d="M {f(mx - 5)} {f(ey - 6)} l 4 3" stroke="#fff" stroke-width="2" stroke-linecap="round"/>')
    if p.get("glasses"):     # cat-eye glasses
        gc = p["glasses"]
        for sd in (-1, 1):
            cx = sd * ex
            gd = (f"M {f(cx - sd*10)} {f(ey - 4)} Q {f(cx)} {f(ey - 8)} {f(cx + sd*12)} {f(ey - 10)} "
                  f"Q {f(cx + sd*12)} {f(ey + 7)} {f(cx)} {f(ey + 7)} Q {f(cx - sd*10)} {f(ey + 6)} {f(cx - sd*10)} {f(ey - 4)} Z")
            out.append(f'<path d="{gd}" fill="#cfe8ff" fill-opacity="0.25" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
                       f'<path d="{gd}" fill="none" stroke="{gc}" stroke-width="2.3" stroke-linejoin="round"/>')
        out.append(f'<path d="M -3 {f(ey - 4)} Q 0 {f(ey - 6)} 3 {f(ey - 4)}" stroke="{INK}" stroke-width="2.5" fill="none"/>')
    # ---- nose: long and pointed, a little upturned at the tip (looking down it)
    ny = y([0.64, 0.70, 0.74][tier] - (0.06 if fem and tier == 2 else 0.0))
    # bridge = soft shade only; ink just on the pointy tip
    if (tier == 2 or ny - ey > 14) and not p.get("readers"):
        out.append(f'<path d="M 2 {f(ey + 2)} C 4 {f(ey + 10)} 6 {f(ny - 12)} 7 {f(ny - 6)}" stroke="{SK[1]}" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
    tip = (f"M 7 {f(ny - 9)} C 10 {f(ny - 2)} 9 {f(ny + 4)} 2 {f(ny + 5)} C -2 {f(ny + 5)} -5 {f(ny + 3)} -6 {f(ny)}") if tier > 0 else \
          (f"M 4 {f(ny - 4)} C 6.5 {f(ny - 1)} 5.5 {f(ny + 3)} 1 {f(ny + 3)} C -2 {f(ny + 3)} -4 {f(ny + 2)} -4.5 {f(ny)}")
    out.append(f'<path d="{tip}" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>')
    out.append(f'<ellipse cx="0" cy="{f(ny + 1.5)}" rx="1.6" ry="1" fill="{INK}" opacity="0.7"/>')
    out.append(f'<ellipse cx="3" cy="{f(ny - 2)}" rx="2.2" ry="1.6" fill="#fff" opacity="0.5"/>')
    if p.get("blink"):       # closed eyes (lids down)
        for sd in (-1, 1):
            cx = sd * ex
            ry_ = 7.4 if tier == 0 else 6.0
            out.append(f'<ellipse cx="{f(cx)}" cy="{f(ey - (1.2 if tier == 0 else 0))}" rx="8.2" ry="{f(ry_ + 1)}" fill="{SK[0]}"/>'
                       f'<path d="M {f(cx - 7.5)} {f(ey + 1)} Q {f(cx)} {f(ey + 4.5)} {f(cx + 7.5)} {f(ey + 1)}" stroke="{INK}" stroke-width="2.8" fill="none" stroke-linecap="round"/>')
    if p.get("readers"):     # Senior glasses: drawn over the nose, lenses centred on the eyes
        gc = p["readers"]
        for sd in (-1, 1):
            cx = sd * ex
            gd = ellipse_d(cx, ey + 1, 10.5, 8.5)
            out.append(f'<path d="{gd}" fill="#cfe8ff" fill-opacity="0.22" stroke="{INK}" stroke-width="4.2"/>'
                       f'<path d="{gd}" fill="none" stroke="{gc}" stroke-width="2"/>'
                       f'<path d="M {f(cx + sd*10.5)} {f(ey - 1)} L {f(((sd*(hw + 0.5)) - fs) / fsc if sd < 0 else (hw - 1.5 - fs) / fsc)} {f(ey - 3)}" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'
                       f'<path d="M {f(cx - 5)} {f(ey - 4)} l 3 -2" stroke="#fff" stroke-width="1.8" stroke-linecap="round" opacity="0.8"/>')
        out.append(f'<path d="M {f(-ex + 10.5)} {f(ey - 1)} Q 0 {f(ey - 5)} {f(ex - 10.5)} {f(ey - 1)}" stroke="{INK}" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
    # cheeks (rosy, no wrinkles)
    for sd in (-1, 1):
        out.append(f'<ellipse cx="{f(sd*hw*0.58)}" cy="{f(y(0.66))}" rx="6" ry="3.4" fill="#e9776b" opacity="{0.42 if tier == 0 else 0.30}"/>')
        if p.get("freckles"):
            for fx, fy in ((0.45, 0.60), (0.58, 0.63), (0.70, 0.60), (0.52, 0.68), (0.66, 0.68)):
                out.append(f'<circle cx="{f(sd*hw*fx)}" cy="{f(y(fy))}" r="1.1" fill="{SK[1]}"/>')
    # ---- mouth
    my = y([0.80, 0.86, 0.88][tier] if not fem else [0.78, 0.83, 0.84][tier])
    lip = "#b8404d" if fem else INK
    if mood == "grin":
        m = f"M -9 {f(my - 2)} C -5 {f(my + 7)} 6 {f(my + 7)} 10 {f(my - 3)} Z"
        out.append(f'<path d="{m}" fill="#5a1f1f" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
                   f'<path d="M -8 {f(my - 1)} L 9 {f(my - 2)} L 7 {f(my + 1.5)} L -6 {f(my + 1.5)} Z" fill="#fff"/>')
    elif mood == "beam":   # big open happy smile
        m = f"M -11 {f(my - 4)} C -9 {f(my + 9)} 9 {f(my + 9)} 11 {f(my - 4)} Q 0 {f(my - 1)} -11 {f(my - 4)} Z"
        cid = D.uid("mb")
        out.append(f'<clipPath id="{cid}"><path d="{m}"/></clipPath><path d="{m}" fill="#6b2226"/>'
                   f'<g clip-path="url(#{cid})"><rect x="-12" y="{f(my - 6)}" width="24" height="5.2" fill="#fff"/>'
                   f'<ellipse cx="1" cy="{f(my + 7)}" rx="6" ry="3.6" fill="#e2747a"/></g>'
                   f'<path d="{m}" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>')
        for sd in (-1, 1):
            out.append(f'<path d="M {f(sd*12)} {f(my - 6)} q {f(sd*2.5)} 2 {f(sd*1)} 5" stroke="{SK[1]}" stroke-width="2" fill="none" stroke-linecap="round"/>')
    elif mood == "talk":   # open mouth for talking (rig swaps it in and out)
        tier_ = p.get("tier", 2)
        mw, mh = [(8.5, 7.5), (6.5, 5.5), (5.0, 4.2)][tier_]
        cid = D.uid("mt")
        m = f"M {f(-mw)} {f(my - 1)} C {f(-mw)} {f(my + mh*1.3)} {f(mw)} {f(my + mh*1.3)} {f(mw)} {f(my - 1)} C {f(mw*0.6)} {f(my - 2.5)} {f(-mw*0.6)} {f(my - 2.5)} {f(-mw)} {f(my - 1)} Z"
        out.append(f'<clipPath id="{cid}"><path d="{m}"/></clipPath><path d="{m}" fill="#6b2226"/>'
                   f'<g clip-path="url(#{cid})"><rect x="{f(-mw)}" y="{f(my - 3)}" width="{f(mw*2)}" height="{f(2.8 + tier_ * -0.4 + 1.2)}" fill="#fff"/>'
                   f'<ellipse cx="0.5" cy="{f(my + mh*1.05)}" rx="{f(mw*0.6)}" ry="{f(mh*0.45)}" fill="#e2747a"/></g>'
                   f'<path d="{m}" fill="none" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>')
    elif mood == "smile":  # polite closed smile
        out.append(f'<path d="M -8 {f(my - 1)} C -4 {f(my + 4)} 4 {f(my + 4)} 8 {f(my - 1)}" stroke="{lip}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    elif mood == "flat":
        out.append(f'<path d="M -6 {f(my + 0.5)} Q 0 {f(my + 1.5)} 6 {f(my + 0.5)}" stroke="{lip}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    elif mood == "pout":
        out.append(f'<path d="M -6 {f(my)} Q 0 {f(my - 2.5)} 6 {f(my)}" stroke="{lip}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    else:   # smug: small one-sided smile
        out.append(f'<path d="M -7 {f(my + 0.5)} C -2 {f(my + 2)} 4 {f(my + 1.5)} 9 {f(my - 3)}" stroke="{lip}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    # ---- moustaches
    mo = p.get("mo")
    mc = p.get("mo_col", hair)
    if mo == "handlebar":
        for sd in (-1, 1):
            md = (f"M 0 {f(ny + 7)} C {f(sd*5)} {f(ny + 4)} {f(sd*13)} {f(ny + 6)} {f(sd*17)} {f(ny + 9)} "
                  f"C {f(sd*22)} {f(ny + 11)} {f(sd*25)} {f(ny + 5)} {f(sd*22)} {f(ny + 1)} "
                  f"C {f(sd*25)} {f(ny + 2)} {f(sd*27)} {f(ny + 9)} {f(sd*22)} {f(ny + 14)} "
                  f"C {f(sd*15)} {f(ny + 17)} {f(sd*6)} {f(ny + 13)} 0 {f(ny + 11)} Z")
            out.append(shaded(md, mc[0], mc[1], dx=-2, dy=-2, sw=3.2))
    elif mo == "walrus":
        pts = [(i * 4.4 - 15.4, ny + 9 + abs(i - 3.5) * 0.9, 5.6) for i in range(8)]
        out.append(blobs(pts, mc[0], mc[1], sw=3.4))
    if turn > 0:
        face = "".join(out[feat_at:])
        del out[feat_at:]
        out.append(f'<g transform="translate({f(fs)} 0) scale({fsc:.3f} 1)">{face}</g>')
    if p.get("pearls_ear"):
        for sd in (-1, 1):
            out.append(f'<circle cx="{f(sd*(hw + 2))}" cy="{f(y(0.62))}" r="3.4" fill="#fbf6ea" stroke="{INK}" stroke-width="1.8"/>')
    return "".join(out)


# ------------------------------------------------------------------ body
def torso_d(L, flare=18):
    S, W, sy, hip = L["S"], L["W"], L["sy"], L["hip"]
    return (f"M -9 {f(sy - 6)} L {f(-S + 6)} {f(sy - 3)} C {f(-S - 1)} {f(sy - 2)} {f(-S - 3)} {f(sy + 2)} {f(-S - 3)} {f(sy + 8)} "
            f"C {f(-S - 1)} {f(sy + 30)} {f(-W - 1)} {f(hip - 30)} {f(-W + 1)} {f(hip - 14)} "
            f"C {f(-W - 1)} {f(hip)} {f(-W - 4)} {f(hip + flare - 6)} {f(-W - 5)} {f(hip + flare)} "
            f"L -3 {f(hip + flare)} L 0 {f(hip + flare - 10)} L 3 {f(hip + flare)} L {f(W + 5)} {f(hip + flare)} "
            f"C {f(W + 4)} {f(hip + flare - 6)} {f(W + 1)} {f(hip)} {f(W - 1)} {f(hip - 14)} "
            f"C {f(W + 1)} {f(hip - 30)} {f(S + 1)} {f(sy + 30)} {f(S + 3)} {f(sy + 8)} "
            f"C {f(S + 3)} {f(sy + 2)} {f(S + 1)} {f(sy - 2)} {f(S - 6)} {f(sy - 3)} L 9 {f(sy - 6)} Z")


def bowtie(x, y_, col):
    sh = lighten(col, -0.25)
    s = ""
    for sd in (-1, 1):
        d = f"M {f(x)} {f(y_)} L {f(x + sd*11)} {f(y_ - 6)} Q {f(x + sd*13)} {f(y_)} {f(x + sd*11)} {f(y_ + 6)} Z"
        s += f'<path d="{d}" fill="{col}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
        s += f'<path d="M {f(x + sd*4)} {f(y_ - 1)} L {f(x + sd*9)} {f(y_ - 3)}" stroke="{sh}" stroke-width="1.6"/>'
    s += f'<rect x="{f(x - 3)}" y="{f(y_ - 3.5)}" width="6" height="7" rx="2" fill="{col}" stroke="{INK}" stroke-width="2.2"/>'
    return s


def body(p, L):
    S, W, sy, hip, ank = L["S"], L["W"], L["sy"], L["hip"], L["ank"]
    SK = SKINS[p["skin"]]
    suit = p["suit"]
    crew = p["crew"]
    fem = p.get("fem", False)
    parts = {}
    # legs: skinny trousers (or a pencil skirt + thin legs)
    if fem:
        knee = hip + 32
        legs = ""
        for sd in (-1, 1):
            legs += shaded(limb((sd * 8, knee - 4), (sd * 7, ank - 2), 11, 8, bulge=1.5), SK[0], SK[1], dx=-2, dy=-2, sw=OUT * 0.8)
        sk = (f"M {f(-W - 4)} {f(hip)} C {f(-W - 6)} {f(hip + 20)} {f(-W + 1)} {f(knee - 6)} {f(-W + 3)} {f(knee)} "
              f"L {f(W - 3)} {f(knee)} C {f(W - 1)} {f(knee - 6)} {f(W + 6)} {f(hip + 20)} {f(W + 4)} {f(hip)} Z")
        legs += shaded(sk, suit[0], suit[1], dx=-5, dy=-2, sw=OUT,
                       extra=f'<path d="M 0 {f(knee)} L 0 {f(knee - 10)}" stroke="{INK}" stroke-width="2.5"/>')
        parts["legs"] = legs
    else:
        legs = ""
        short = p.get("tier", 2) == 0
        for sd in (-1, 1):
            if short:
                legs += shaded(limb((sd * 9, ank - 14), (sd * 9, ank + 2), 11, 10), crew, lighten(crew, -0.25), dx=-2, dy=-2, sw=OUT * 0.8,
                               extra=f'<path d="M {f(sd*9 - 4)} {f(ank - 6)} L {f(sd*9 + 4)} {f(ank - 6)}" stroke="#fff" stroke-width="2"/>')
        for sd in (-1, 1):
            legs += shaded(limb((sd * 10, hip + 6), (sd * 10, ank - (10 if short else 0)), 19, 14, bulge=1), suit[0], suit[1], dx=-4, dy=-2, sw=OUT,
                           extra=f'<path d="M {f(sd*10)} {f(hip + 30)} L {f(sd*10)} {f(ank - 4)}" stroke="{suit[1]}" stroke-width="2"/>')
        parts["legs"] = legs
    # shoes: long pointy toes splayed outwards (duck stance)
    sh = ""
    for sd in (-1, 1):
        x0 = sd * (4 if not fem else 3)
        tip = sd * (38 if not fem else 28)
        turn_ = float(p.get("turn", 0.0))
        tip = tip * (1 - 0.36 * turn_) if sd < 0 else tip * (1 + 0.08 * turn_)   # feet point towards the workers
        d = (f"M {f(x0)} {f(GROUND)} L {f(x0)} {f(ank - 4)} C {f(x0 + sd*3)} {f(ank - 9)} {f(sd*15)} {f(ank - 8)} {f(sd*19)} {f(ank - 4)} "
             f"C {f(sd*24)} {f(ank)} {f(tip - sd*6)} {f(GROUND - 6)} {f(tip)} {f(GROUND - 8)} "
             f"C {f(tip + sd*3)} {f(GROUND - 7)} {f(tip + sd*2)} {f(GROUND - 1)} {f(tip - sd*4)} {f(GROUND)} Z")
        if p.get("spats"):
            sh += shaded(d, "#454a58", "#262a33", dx=-3, dy=-2, sw=3.6)
            sp = f"M {f(x0)} {f(ank + 6)} L {f(x0)} {f(ank - 9)} L {f(sd*16)} {f(ank - 9)} C {f(sd*20)} {f(ank - 4)} {f(sd*21)} {f(ank + 2)} {f(sd*19)} {f(ank + 6)} Z"
            sh += shaded(sp, "#e9e4d8", "#c7bfae", dx=-2, dy=-2, sw=3.2,
                         extra="".join(f'<circle cx="{f(sd*(8 + k*4))}" cy="{f(ank - 2)}" r="1.3" fill="{INK}"/>' for k in range(3)))
        else:
            col = p.get("shoe", ("#454a58", "#262a33"))
            sh += shaded(d, col[0], col[1], dx=-3, dy=-2, sw=3.6,
                         extra=f'<ellipse cx="{f(sd*19)}" cy="{f(ank - 2)}" rx="5" ry="1.8" fill="#fff" opacity="0.55"/>')
            if fem:   # little heel
                sh += f'<rect x="{f(x0 - (5 if sd > 0 else 0))}" y="{f(GROUND - 9)}" width="5" height="9" fill="{col[0]}" stroke="{INK}" stroke-width="2.2"/>'
    parts["shoes"] = sh
    # neck: long and thin
    nk = f"M -6 {f(L['chin'] - 14)} L 6 {f(L['chin'] - 14)} L 7 {f(sy + 2)} L -7 {f(sy + 2)} Z"
    ds = float(p.get("turn", 0.0)) * S * 0.20      # chest details shift towards the turn
    nk = f'M {f(-6 + ds * 0.4)} {f(L["chin"] - 14)} L {f(6 + ds * 0.4)} {f(L["chin"] - 14)} L {f(7 + ds * 0.4)} {f(sy + 2)} L {f(-7 + ds * 0.4)} {f(sy + 2)} Z'
    parts["neck"] = shaded(nk, SK[0], SK[1], dx=-3, dy=4, sw=OUT * 0.8,
                           extra=f'<path d="M 0 {f(L["chin"] + 2)} q 3 3 0 6" stroke="{SK[1]}" stroke-width="2" fill="none"/>' if not fem else "")
    # jacket
    if p.get("tier", 2) < 2:
        parts["torso"] = young_jacket(p, L)
        return parts
    td = torso_d(L, 18 if not fem else 8)
    det = ""
    vb = sy + (36 if not fem else 30)
    stripe = lighten(suit[0], 0.22)
    if p.get("pinstripe"):
        det += "".join(f'<path d="M {f(x)} {f(sy - 10)} L {f(x)} {f(hip + 20)}" stroke="{stripe}" stroke-width="1.1" opacity="0.6"/>' for x in range(-int(S) - 4, int(S) + 6, 6))
    shirt = "#f7f4ec"
    det += f'<path d="M -10 {f(sy - 8)} L 10 {f(sy - 8)} L 0 {f(vb)} Z" fill="{shirt}"/>'
    for sd in (-1, 1):   # peak lapels
        lp = (f"M {f(sd*10)} {f(sy - 8)} L {f(sd*1)} {f(vb + 2)} L {f(sd*7)} {f(vb + 3)} "
              f"L {f(sd*(S*0.62))} {f(sy + 14)} L {f(sd*(S*0.78))} {f(sy + 1)} L {f(sd*(S*0.55))} {f(sy + 6)} L {f(sd*(S*0.45))} {f(sy - 4)} Z")
        det += f'<path d="{lp}" fill="{lighten(suit[0], 0.10)}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    if fem:
        det += "".join(f'<circle cx="{f(math.sin(t) * 9)}" cy="{f(sy - 4 + (1 - math.cos(t)) * 9)}" r="2.6" fill="#fbf6ea" stroke="{INK}" stroke-width="1.4"/>' for t in [(-1.3 + 2.6 * i / 8) for i in range(9)])
    # double-breasted buttons
    for k in range(3 if not fem else 2):
        for sd in (-1, 1):
            det += f'<circle cx="{f(sd*7)}" cy="{f(vb + 9 + k*11)}" r="2.4" fill="{p.get("button", lighten(suit[0], 0.3))}" stroke="{INK}" stroke-width="1.3"/>'
    # pocket square (crew colour) + hip pocket flaps
    psx = -S * 0.62
    det += f'<path d="M {f(psx)} {f(sy + 24)} L {f(psx + 6)} {f(sy + 15)} L {f(psx + 9)} {f(sy + 20)} L {f(psx + 13)} {f(sy + 14)} L {f(psx + 15)} {f(sy + 24)} Z" fill="{crew}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>'
    det += f'<path d="M {f(psx - 2)} {f(sy + 24)} L {f(psx + 17)} {f(sy + 24)}" stroke="{INK}" stroke-width="2.2"/>'
    for sd in (-1, 1):
        det += f'<path d="M {f(sd*(W - 1))} {f(hip - 4)} L {f(sd*(W*0.25))} {f(hip - 4)}" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>'
    over = ""
    if not fem:
        for sd in (-1, 1):   # wing collar points
            over += f'<path d="M {f(sd*1)} {f(sy - 7)} L {f(sd*9)} {f(sy - 12)} L {f(sd*10)} {f(sy - 3)} Z" fill="{shirt}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>'
        over += bowtie(0, sy - 5, crew)
    parts["torso"] = shaded(td, suit[0], suit[1], dx=-8, dy=-3, extra=f'<g transform="translate({f(ds)} 0)">{det}</g>', sw=OUT) + f'<g transform="translate({f(ds)} 0)">{over}</g>'
    return parts


def skinny_tie(y0, y1, col, w=3.6):
    sh = lighten(col, -0.25)
    blade = f"M {f(-w*0.7)} {f(y0 + 5)} L {f(w*0.7)} {f(y0 + 5)} L {f(w)} {f(y1 - 4)} L 0 {f(y1)} L {f(-w)} {f(y1 - 4)} Z"
    return (f'<path d="{blade}" fill="{col}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>'
            f'<path d="M {f(w*0.3)} {f(y0 + 8)} L {f(w*0.6)} {f(y1 - 5)}" stroke="{sh}" stroke-width="1.6"/>'
            f'<path d="M {f(-w)} {f(y0 - 1)} L {f(w)} {f(y0 - 1)} L {f(w*0.7)} {f(y0 + 6)} L {f(-w*0.7)} {f(y0 + 6)} Z" fill="{col}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>')


def neck_bow(y0, col):   # soft blouse bow with two tails (the ladies)
    sh = lighten(col, -0.25)
    s = ""
    for sd in (-1, 1):
        s += f'<path d="M 0 {f(y0)} L {f(sd*3)} {f(y0 + 16)} L {f(sd*8)} {f(y0 + 14)} Z" fill="{col}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
    for sd in (-1, 1):
        s += f'<path d="M 0 {f(y0)} C {f(sd*6)} {f(y0 - 7)} {f(sd*11)} {f(y0 - 3)} {f(sd*9)} {f(y0 + 3)} C {f(sd*6)} {f(y0 + 5)} {f(sd*3)} {f(y0 + 2)} 0 {f(y0)} Z" fill="{col}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
    s += f'<circle cx="0" cy="{f(y0)}" r="2.6" fill="{sh}" stroke="{INK}" stroke-width="1.6"/>'
    return s


def young_jacket(p, L):
    """Senior: open jacket over a crew-colour waistcoat, proper tie, pocket square.
    Junior: slim single-button suit a size too big, skinny crew tie, name badge."""
    S, W, sy, hip = L["S"], L["W"], L["sy"], L["hip"]
    suit, crew, fem, tier = p["suit"], p["crew"], p.get("fem", False), p.get("tier", 2)
    shirt = p.get("shirt", "#f7f4ec")
    td = torso_d(L, 16 if not fem else 8)
    det, over = "", ""
    lap = lighten(suit[0], 0.10)
    if tier == 1:
        det += f'<path d="M -11 {f(sy - 8)} L 11 {f(sy - 8)} L 15 {f(sy + 10)} L 0 {f(sy + 34)} L -15 {f(sy + 10)} Z" fill="{shirt}"/>'
        if not fem:
            det += skinny_tie(sy - 4, sy + 34, p.get("tie", lighten(crew, -0.35)), w=5.5)
        wc = (f"M -15 {f(sy + 4)} L 0 {f(sy + 30)} L 15 {f(sy + 4)} L {f(W*0.62)} {f(hip + 10)} "
              f"L 0 {f(hip + 16)} L {f(-W*0.62)} {f(hip + 10)} Z")
        det += shaded(wc, crew, lighten(crew, -0.22), dx=-3, dy=-2, sw=2.6)
        det += "".join(f'<circle cx="0" cy="{f(sy + 38 + k*9)}" r="1.9" fill="{lighten(crew, 0.5)}" stroke="{INK}" stroke-width="1.2"/>' for k in range(4))
        for sd in (-1, 1):   # notch lapels rolling to the open front edge
            lp = (f"M {f(sd*11)} {f(sy - 8)} L {f(sd*15)} {f(sy + 40)} L {f(sd*(S*0.50))} {f(sy + 16)} "
                  f"L {f(sd*(S*0.66))} {f(sy + 4)} L {f(sd*(S*0.48))} {f(sy + 5)} L {f(sd*(S*0.42))} {f(sy - 4)} Z")
            det += f'<path d="{lp}" fill="{lap}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
            det += f'<path d="M {f(sd*15)} {f(sy + 40)} L {f(sd*W*0.62)} {f(hip + 18)}" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'
        if fem:
            det += f'<circle cx="{f(S*0.40)}" cy="{f(sy + 20)}" r="3.4" fill="#e7b93c" stroke="{INK}" stroke-width="1.6"/>'   # brooch
        psx = -S * 0.66
        det += f'<path d="M {f(psx)} {f(sy + 26)} L {f(psx + 5)} {f(sy + 18)} L {f(psx + 9)} {f(sy + 22)} L {f(psx + 13)} {f(sy + 17)} L {f(psx + 14)} {f(sy + 26)} Z" fill="{lighten(crew, 0.35)}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>'
        det += f'<path d="M {f(psx - 2)} {f(sy + 26)} L {f(psx + 16)} {f(sy + 26)}" stroke="{INK}" stroke-width="2.2"/>'
    else:
        vb = sy + 44
        det += f'<path d="M -10 {f(sy - 8)} L 10 {f(sy - 8)} L 0 {f(vb)} Z" fill="{shirt}"/>'
        if not fem:
            det += skinny_tie(sy - 4, vb + 4, crew)
        for sd in (-1, 1):
            lp = (f"M {f(sd*10)} {f(sy - 8)} L {f(sd*1)} {f(vb + 1)} L {f(sd*(S*0.42))} {f(sy + 14)} "
                  f"L {f(sd*(S*0.58))} {f(sy + 3)} L {f(sd*(S*0.42))} {f(sy + 4)} L {f(sd*(S*0.38))} {f(sy - 4)} Z")
            det += f'<path d="{lp}" fill="{lap}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
        det += f'<path d="M 1 {f(vb + 1)} L 0 {f(hip + 10)}" stroke="{INK}" stroke-width="2.4"/>'
        det += f'<circle cx="4" cy="{f(vb + 7)}" r="2.6" fill="{lighten(suit[0], 0.35)}" stroke="{INK}" stroke-width="1.4"/>'
        bx, by = S * 0.32, sy + 20   # name badge
        det += (f'<rect x="{f(bx - 7)}" y="{f(by)}" width="15" height="10" rx="2" fill="#fff" stroke="{INK}" stroke-width="1.8"/>'
                f'<rect x="{f(bx - 7)}" y="{f(by)}" width="15" height="3.4" rx="1.5" fill="{crew}"/>'
                f'<rect x="{f(bx - 4)}" y="{f(by + 5.5)}" width="9" height="1.8" rx="0.9" fill="#9fb0c0"/>')
    for sd in (-1, 1):
        det += f'<path d="M {f(sd*(W - 1))} {f(hip - 4)} L {f(sd*(W*0.45))} {f(hip - 4)}" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>'
    for sd in (-1, 1):   # shirt collar points
        over += f'<path d="M {f(sd*1)} {f(sy - 6)} L {f(sd*10)} {f(sy - 11)} L {f(sd*11)} {f(sy - 1)} Z" fill="{shirt}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>'
    if fem:
        over += neck_bow(sy - 4, crew)
    ds = float(p.get("turn", 0.0)) * S * 0.20
    return shaded(td, suit[0], suit[1], dx=-8, dy=-3, extra=f'<g transform="translate({f(ds)} 0)">{det}</g>', sw=OUT) + f'<g transform="translate({f(ds)} 0)">{over}</g>'


def hand(p, at, d, r=7.5):
    SK = SKINS[p["skin"]]
    hx, hy = at[0] + d[0] * r * 0.55, at[1] + d[1] * r * 0.55
    return shaded(ellipse_d(hx, hy, r, r * 0.9), SK[0], SK[1], dx=-2, dy=-2, sw=OUT * 0.75)


def upper(p, a, b):
    s = p["suit"]
    return shaded(limb(a, b, 17, 13, bulge=1.5), s[0], s[1], dx=-3, dy=-2, sw=OUT)


def fore(p, a, b, cufflink=True):
    if p.get("tier", 2) == 0:
        s = p["suit"]
        L_ = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
        d = ((b[0] - a[0]) / L_, (b[1] - a[1]) / L_)
        b2 = (b[0] + d[0] * 3, b[1] + d[1] * 3)   # sleeve runs over the wrist
        return shaded(limb(a, b2, 14, 13, bulge=1), s[0], s[1], dx=-3, dy=-2, sw=OUT), d
    s = p["suit"]
    L_ = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
    d = ((b[0] - a[0]) / L_, (b[1] - a[1]) / L_)
    nx, ny = -d[1], d[0]
    out = shaded(limb(a, b, 13, 11, bulge=1), s[0], s[1], dx=-3, dy=-2, sw=OUT)
    cx, cy = b[0] - d[0] * 1, b[1] - d[1] * 1
    out += f'<path d="M {f(cx + nx*6)} {f(cy + ny*6)} L {f(cx - nx*6)} {f(cy - ny*6)}" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
    out += f'<path d="M {f(cx + nx*5.5)} {f(cy + ny*5.5)} L {f(cx - nx*5.5)} {f(cy - ny*5.5)}" stroke="#f7f4ec" stroke-width="3.4" stroke-linecap="round"/>'
    if cufflink:
        out += f'<circle cx="{f(cx)}" cy="{f(cy)}" r="1.6" fill="#e7b93c"/>'
    return out, d


def clipboard(x, y_, ang=-10, k=0.85):
    s = f'<g transform="translate({f(x)} {f(y_)}) rotate({ang}) scale({k})">'
    s += '<rect x="-22" y="-30" width="44" height="58" rx="5" fill="#6d3f24" stroke="#1d1b2b" stroke-width="5"/>'   # leather folio
    s += '<rect x="-17" y="-23" width="34" height="46" rx="2" fill="#fbf8ee"/>'
    for i in range(4):
        s += f'<rect x="-12" y="{-15 + i*9}" width="{24 if i % 2 == 0 else 17}" height="3" rx="1.5" fill="#a9b4bf"/>'
    s += '<rect x="-9" y="-35" width="18" height="9" rx="3" fill="#e7b93c" stroke="#1d1b2b" stroke-width="2.5"/>'
    return s + "</g>"


def figure(p, pose=2, mood=None, phase=1.0):
    L = layout(p)
    S, W, sy, hip = L["S"], L["W"], L["sy"], L["hip"]
    if mood is None:
        mood = [{0: "beam", 1: "beam", 2: "beam", 3: "smile"},
                {0: "grin", 1: "smile", 2: "smile", 3: "flat"},
                {0: "grin", 1: "pout", 2: "smug", 3: "smug"}][p.get("tier", 2)][pose]
    parts = body(p, L)
    shl, shr = (-(S - 4), sy + 8), (S - 4, sy + 8)
    back, front, top = [], [], []

    def hip_arm(sd, sh_):
        el = (sd * (S + 20), sy + 44)
        wr = (sd * (W + 3), hip - 16)
        back.append(upper(p, sh_, el))
        fs, d = fore(p, el, wr)
        front.append(fs + hand(p, wr, d))

    if pose == 2:
        hip_arm(-1, shl); hip_arm(1, shr)
    elif pose == 1:
        el_l, el_r = (-(S + 6), sy + 50), (S + 6, sy + 48)
        back.append(upper(p, shl, el_l)); back.append(upper(p, shr, el_r))
        fs, d = fore(p, el_r, (-S + 8, sy + 30))
        front.append(fs + hand(p, (-S + 8, sy + 30), d))
        fs, d = fore(p, el_l, (S - 4, sy + 40))
        front.append(fs)
        front.append(upper(p, shr, el_r))
    elif pose == 0:
        hip_arm(-1, shl)
        k = phase
        el = ((S + 14) + 6 * k, sy + 46 - 44 * k)
        wr = ((S + 8) + 2 * k, sy + 86 - 132 * k)
        back.append(upper(p, shr, el))
        fs, d = fore(p, el, wr)
        top.append(fs + hand(p, wr, d, r=8.5))
        if k > 0.6:
            top.append(f'<path d="M {f(S + 26)} {f(sy - 62)} q 9 3 11 14 M {f(S - 12)} {f(sy - 63)} q -8 5 -8 14" stroke="{INK}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    else:
        el_l, el_r = (-(S + 6), sy + 50), (S + 6, sy + 50)
        back.append(upper(p, shl, el_l)); back.append(upper(p, shr, el_r))
        hold = (-S * 0.40, sy + 66)
        fs, d = fore(p, el_l, hold)
        front.append(fs)
        front.append(clipboard(-S * 0.10, sy + 40, -10))
        front.append(hand(p, hold, d))
        pen = (S * 0.36, sy + 30)
        fs, d = fore(p, el_r, pen)
        front.append(fs)
        hx, hy = pen[0] + d[0] * 4, pen[1] + d[1] * 4
        front.append(f'<path d="M {f(hx + 3)} {f(hy - 4)} L {f(hx - 14)} {f(hy + 5)}" stroke="{INK}" stroke-width="6.5" stroke-linecap="round"/>'
                     f'<path d="M {f(hx + 3)} {f(hy - 4)} L {f(hx - 14)} {f(hy + 5)}" stroke="#1d1b2b" stroke-width="3" stroke-linecap="round"/>'
                     f'<path d="M {f(hx - 6)} {f(hy)} L {f(hx - 2)} {f(hy - 2)}" stroke="#e7b93c" stroke-width="3"/>')   # fountain pen
        front.append(hand(p, pen, d))
    k, cy = HEAD_SCALE, L["chin"]
    hd = f'<g transform="translate(0 {f(cy)}) scale({k}) translate(0 {f(-cy)})">{head(p, L, mood)}</g>'
    return "".join([parts["legs"], parts["shoes"]] + back + [parts["neck"], parts["torso"]] + front + [hd] + top)


def shadow(col, op=0.55):
    return f'<ellipse cx="0" cy="{f(GROUND)}" rx="62" ry="13" fill="{col}" opacity="{op}"/>'
