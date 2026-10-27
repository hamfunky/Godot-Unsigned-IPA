"""Manager 'active' effect, cash version = SUDS AURA (prototype still, 19 Oct).
Its own layer, separate from the manager rig: aura_back() goes behind the manager, aura_front() in front,
rim() is a coloured glow around the manager's silhouette. Colour by ability (matches the ability icon).
Premium managers can swap in their own effect later (effect id), the manager animation never changes.
"""
import math, random

KINDS = {   # core (bright), mid, deep, rim
    "income":   ("#d6ffe3", "#6ee89a", "#2fae5e", "#7dffb0"),
    "speed":    ("#dff3ff", "#6cc6ff", "#2a82e8", "#8fd8ff"),
    "discount": ("#fff0d6", "#ffbe5c", "#f07a12", "#ffcf7a"),
}
GROUND = 300.0


def f(v):
    return f"{v:.1f}"


def defs(kind, uid):
    c0, c1, c2, rimc = KINDS[kind]
    return f'''<defs>
<linearGradient id="g{uid}" x1="0" y1="1" x2="0" y2="0">
  <stop offset="0" stop-color="{c2}" stop-opacity="0.85"/><stop offset="0.45" stop-color="{c1}" stop-opacity="0.7"/>
  <stop offset="0.8" stop-color="{c1}" stop-opacity="0.35"/><stop offset="1" stop-color="{c1}" stop-opacity="0"/></linearGradient>
<linearGradient id="t{uid}" x1="0" y1="1" x2="0" y2="0">
  <stop offset="0" stop-color="{c0}" stop-opacity="0.95"/><stop offset="0.55" stop-color="{c0}" stop-opacity="0.55"/>
  <stop offset="1" stop-color="{c0}" stop-opacity="0"/></linearGradient>
<radialGradient id="p{uid}" cx="50%" cy="50%" r="50%">
  <stop offset="0" stop-color="{c0}" stop-opacity="0.9"/><stop offset="0.55" stop-color="{c1}" stop-opacity="0.55"/>
  <stop offset="1" stop-color="{c2}" stop-opacity="0"/></radialGradient>
<radialGradient id="b{uid}" cx="38%" cy="34%" r="70%">
  <stop offset="0" stop-color="#ffffff" stop-opacity="0.55"/><stop offset="0.5" stop-color="{c0}" stop-opacity="0.18"/>
  <stop offset="0.85" stop-color="{c1}" stop-opacity="0.32"/><stop offset="1" stop-color="{c2}" stop-opacity="0.75"/></radialGradient>
<filter id="s{uid}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>
<filter id="m{uid}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3"/></filter>
<filter id="r{uid}" x="-30%" y="-30%" width="160%" height="160%">
  <feMorphology in="SourceAlpha" operator="dilate" radius="3.5" result="d"/>
  <feFlood flood-color="{rimc}"/><feComposite in2="d" operator="in"/><feGaussianBlur stdDeviation="2.6"/></filter>
</defs>'''


def flame_blob(cx, base, w, h, lobes, rng, wob=0.0):
    """Soft rounded 'flame': an egg shape (widest low, rounded crown, no sharp tips) with gentle lobes."""
    pts = []
    n = 28
    for i in range(n):
        a = math.pi * 2 * i / n
        u = (1 - math.cos(a)) / 2                     # 0 bottom .. 1 top
        x = cx + math.sin(a) * w * (1 - 0.32 * u * u) * (1 + 0.07 * math.sin(a * lobes + wob))
        y = base - u * h * (1 + 0.04 * math.sin(a * (lobes + 1) - wob))
        pts.append((x, y))
    d = f"M {f(pts[0][0])} {f(pts[0][1])} "
    for i in range(n):   # Catmull-Rom -> cubic, closed
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C {f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])} "
    return d + "Z"


def bubble(x, y, r, uid, op=1.0):
    return (f'<g opacity="{op}"><circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="url(#b{uid})"/>'
            f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="none" stroke="#ffffff" stroke-width="{f(max(1.0, r*0.12))}" stroke-opacity="0.85"/>'
            f'<path d="M {f(x - r*0.62)} {f(y - r*0.05)} A {f(r*0.65)} {f(r*0.65)} 0 0 1 {f(x - r*0.05)} {f(y - r*0.62)}" stroke="#ffffff" stroke-width="{f(max(1.2, r*0.2))}" fill="none" stroke-linecap="round"/>'
            f'<circle cx="{f(x + r*0.38)}" cy="{f(y + r*0.36)}" r="{f(r*0.12)}" fill="#ffffff" opacity="0.9"/></g>')


def twinkle(x, y, r, col="#ffffff"):
    d = (f"M {f(x)} {f(y - r)} Q {f(x + r*0.16)} {f(y - r*0.16)} {f(x + r)} {f(y)} Q {f(x + r*0.16)} {f(y + r*0.16)} {f(x)} {f(y + r)} "
         f"Q {f(x - r*0.16)} {f(y + r*0.16)} {f(x - r)} {f(y)} Q {f(x - r*0.16)} {f(y - r*0.16)} {f(x)} {f(y - r)} Z")
    return f'<path d="{d}" fill="{col}"/><circle cx="{f(x)}" cy="{f(y)}" r="{f(r*0.22)}" fill="#fff"/>'


def aura_back(kind, uid, top=96.0, seed=1):
    """Everything behind the manager. `top` = top of the manager's head (design units)."""
    c0, c1, c2, _ = KINDS[kind]
    rng = random.Random(seed)
    h = GROUND - top
    s = defs(kind, uid)
    # 1 big soft glow (blurred teardrop) + a brighter core
    s += f'<path d="{flame_blob(0, GROUND + 14, 96, h + 70, 3, rng, 0.4)}" fill="url(#g{uid})" filter="url(#m{uid})"/>'
    s += f'<path d="{flame_blob(0, GROUND + 6, 72, h + 26, 4, rng, 1.3)}" fill="url(#t{uid})" filter="url(#m{uid})" opacity="0.85"/>'
    # 2 three soft rising tongues (rounded, offset, fading to the top)
    for dx, ww, hh, wob, op in ((-64, 24, h * 0.70, 2.0, 0.7), (66, 22, h * 0.80, 0.6, 0.65), (-6, 30, h + 58, 3.1, 0.55)):
        s += f'<path d="{flame_blob(dx, GROUND - 10, ww, hh, 2, rng, wob)}" fill="url(#t{uid})" filter="url(#m{uid})" opacity="{op}"/>'
    # 3 glowing pool on the floor + a ring of suds round the feet
    s += f'<ellipse cx="0" cy="{f(GROUND)}" rx="78" ry="17" fill="url(#p{uid})"/>'
    foam = []
    for i in range(15):
        a = math.pi * (0.0 + i / 14.0)
        foam.append((math.cos(a) * 62 + rng.uniform(-3, 3), GROUND - 2 - math.sin(a) * 7 + rng.uniform(-1.5, 1.5), rng.uniform(7, 11)))
    s += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r + 1.6)}" fill="{c2}" opacity="0.55"/>' for x, y, r in foam)
    s += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#ffffff"/>' for x, y, r in foam)
    s += "".join(f'<circle cx="{f(x - r*0.15)}" cy="{f(y + r*0.3)}" r="{f(r*0.75)}" fill="{c0}" opacity="0.8"/>' for x, y, r in foam)
    s += "".join(f'<circle cx="{f(x - r*0.3)}" cy="{f(y - r*0.35)}" r="{f(r*0.28)}" fill="#ffffff"/>' for x, y, r in foam[::2])
    # 4 bubbles behind, rising up the sides (bigger low, smaller high)
    for i in range(9):
        side = -1 if i % 2 == 0 else 1
        k = i / 8.0
        x = side * rng.uniform(40, 62) * (1 - 0.35 * k)
        y = GROUND - 30 - k * (h + 10)
        s += bubble(x, y, 11 - 6 * k + rng.uniform(-1.5, 1.5), uid, 0.95 - 0.35 * k)
    return s


def aura_front(kind, uid, top=96.0, seed=2):
    """A few small bubbles + twinkles in front (kept off the face)."""
    rng = random.Random(seed)
    h = GROUND - top
    s = ""
    for x, y, r in ((-52, GROUND - 46, 6.5), (56, GROUND - 88, 5.5), (-46, top + 18, 4.5), (44, top - 6, 7), (-14, top - 34, 5), (20, top - 58, 3.6)):
        s += bubble(x, y, r, uid, 0.9)
    s += twinkle(58, top + 30, 7) + twinkle(-62, GROUND - 120, 5.5) + twinkle(30, top - 30, 4.5)
    return s


def wrap_rim(figure_svg, uid):
    """Coloured glow hugging the manager's silhouette, drawn behind the figure."""
    return f'<g filter="url(#r{uid})">{figure_svg}</g>'
