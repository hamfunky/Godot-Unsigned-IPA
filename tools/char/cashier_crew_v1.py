"""Front desk cashier (v0.19e prototype, sheet first): crew family like the detailers (tools/char/detailer.py:
same ink outlines, cel shading, chunky build, crew-orange tee + white droplet logo, charcoal trousers) but she's
the friendly face of the shop: a FRONT view (she faces the customer across the counter), big warm eyes, an easy
smile, a high ponytail with a crew-blue scrunchie, a headset with a little mic, a name badge.
Poses: stand (neutral), count (hands down on the counter with a stack of notes), cheer (fist up, grin).
Coordinates as detailer.py: x = 0 body centre, y down, feet on GROUND.
"""
import math
import detailer as D
from detailer import f, P, shaded, limb, ellipse_d, INK, OUT, GROUND, bez

SKIN = ("#e8b48a", "#c98e63")
HAIR = ("#7a3b1f", "#57260f", "#a8603a")      # auburn: base, shade, shine
SCRUNCHIE = ("#2f9bff", "#1f6fc4")

V = dict(head=1.04, S=72, W=44, torso=84, legs=56, neck=21,
         shirt=("#f07a2e", "#c45a1a"), logo="#ffffff", sleeve=True,
         pants=("#4b505c", "#363a44"), shoes=("#f4f4f4", "#c9ced6", "#2f9bff"))


def layout():
    return D.layout(V)


# ---------- head ----------
def head(L, mood="smile"):
    hs, top, chin, hw, hh = L["hs"], L["top"], L["chin"], L["hw"] * 0.98, L["hh"]
    y = lambda k: top + hh * k
    out = []
    out.append(ponytail(L))
    for s in (-1, 1):   # ears (mostly under the hair)
        ed = ellipse_d(s * (hw + 1), y(0.60), 8 * hs, 11.5 * hs)
        out.append(shaded(ed, SKIN[0], SKIN[1], dx=-3, dy=-3))
    jw = hw * 0.90
    d = (f"M 0 {f(top)} C {f(hw*0.62)} {f(top)} {f(hw*0.92)} {f(y(0.12))} {f(hw*0.94)} {f(y(0.34))} "
         f"C {f(hw*0.98)} {f(y(0.48))} {f(hw)} {f(y(0.56))} {f(hw)} {f(y(0.64))} "
         f"C {f(hw)} {f(y(0.80))} {f(jw)} {f(y(0.90))} {f(jw*0.62)} {f(y(0.96))} "
         f"C {f(jw*0.40)} {f(chin)} {f(hw*0.20)} {f(chin + 1)} 0 {f(chin + 1)} "
         f"C {f(-hw*0.20)} {f(chin + 1)} {f(-jw*0.40)} {f(chin)} {f(-jw*0.62)} {f(y(0.96))} "
         f"C {f(-jw)} {f(y(0.90))} {f(-hw)} {f(y(0.80))} {f(-hw)} {f(y(0.64))} "
         f"C {f(-hw)} {f(y(0.56))} {f(-hw*0.98)} {f(y(0.48))} {f(-hw*0.94)} {f(y(0.34))} "
         f"C {f(-hw*0.92)} {f(y(0.12))} {f(-hw*0.62)} {f(top)} 0 {f(top)} Z")
    blush = "".join(f'<ellipse cx="{f(s*hw*0.58)}" cy="{f(y(0.72))}" rx="{f(9*hs)}" ry="{f(5*hs)}" fill="#ff7a7a" opacity="0.30"/>' for s in (-1, 1))
    out.append(shaded(d, SKIN[0], SKIN[1], dx=-9, dy=-6, extra=blush))
    out.append(face(L, hw, mood))
    out.append(hair_front(L, hw))
    out.append(headset(L, hw))
    return "".join(out)


def eye(ex, ey, hs, side, closed=False):
    rx, ry = 10.5 * hs, 12.5 * hs
    if closed or D.BLINK:
        return (f'<path d="M {f(ex - rx)} {f(ey + 1*hs)} Q {f(ex)} {f(ey + 7*hs)} {f(ex + rx)} {f(ey + 1*hs)}" fill="none" '
                f'stroke="{INK}" stroke-width="{f(3*hs)}" stroke-linecap="round"/>') + brow(ex, ey, hs, side)
    cid = D.uid("e")
    e = ellipse_d(ex, ey, rx, ry)
    s = f'<clipPath id="{cid}"><path d="{e}"/></clipPath><path d="{e}" fill="#fbf8f3"/>'
    s += (f'<g clip-path="url(#{cid})">'
          f'<circle cx="{f(ex + side*0.8*hs)}" cy="{f(ey + 2*hs)}" r="{f(8.2*hs)}" fill="#6b4226"/>'
          f'<circle cx="{f(ex + side*0.8*hs)}" cy="{f(ey + 2*hs)}" r="{f(5.4*hs)}" fill="#3e2414"/>'
          f'<circle cx="{f(ex + side*0.8*hs - 2.8*hs)}" cy="{f(ey - 1.6*hs)}" r="{f(2.8*hs)}" fill="#ffffff"/>'
          f'<circle cx="{f(ex + side*0.8*hs + 2.6*hs)}" cy="{f(ey + 4.6*hs)}" r="{f(1.3*hs)}" fill="#ffffff" opacity="0.85"/>'
          f'<path d="{e}" fill="none" stroke="#000" stroke-width="{f(5*hs)}" opacity="0.10" transform="translate(0,{f(-3*hs)})"/>'
          f'</g>')
    s += f'<path d="{e}" fill="none" stroke="{INK}" stroke-width="{f(2.2*hs)}"/>'
    # upper lash line, thicker, with a flick at the outer corner
    s += (f'<path d="M {f(ex - side*rx*1.02)} {f(ey - 1*hs)} C {f(ex - side*rx*0.8)} {f(ey - ry*1.15)} {f(ex + side*rx*0.7)} {f(ey - ry*1.15)} '
          f'{f(ex + side*rx*1.05)} {f(ey - 3*hs)} L {f(ex + side*rx*1.45)} {f(ey - 7*hs)}" fill="none" stroke="{INK}" '
          f'stroke-width="{f(4*hs)}" stroke-linecap="round" stroke-linejoin="round"/>')
    return s + brow(ex, ey, hs, side)


def brow(ex, ey, hs, side):
    # soft, friendly arch (no frown: she's the welcome)
    return (f'<path d="M {f(ex - side*11*hs)} {f(ey - 15*hs)} Q {f(ex)} {f(ey - 24*hs)} {f(ex + side*12*hs)} {f(ey - 18*hs)}" '
            f'fill="none" stroke="{HAIR[1]}" stroke-width="{f(4.4*hs)}" stroke-linecap="round"/>')


def face(L, hw, mood):
    hs, top, hh = L["hs"], L["top"], L["hh"]
    y = lambda k: top + hh * k
    ey = y(0.53)
    s = "".join(eye(side * hw * 0.42, ey, hs, side, closed=(mood == "cheer")) for side in (-1, 1))
    # little button nose
    ny = y(0.69)
    s += f'<path d="M {f(-4*hs)} {f(ny + 2*hs)} Q {f(0)} {f(ny + 6*hs)} {f(5*hs)} {f(ny + 1*hs)}" fill="none" stroke="{INK}" stroke-width="{f(2.6*hs)}" stroke-linecap="round"/>'
    s += f'<ellipse cx="{f(-1.5*hs)}" cy="{f(ny - 3*hs)}" rx="{f(3.2*hs)}" ry="{f(2.2*hs)}" fill="#ffffff" opacity="0.35"/>'
    # freckles
    for fx, fy in ((-0.30, 0.66), (-0.24, 0.69), (-0.35, 0.70), (0.30, 0.66), (0.24, 0.69), (0.35, 0.70)):
        s += f'<circle cx="{f(fx*hw*1.6)}" cy="{f(y(fy))}" r="{f(1.2*hs)}" fill="#b5683e" opacity="0.6"/>'
    my = y(0.80)
    if mood in ("grin", "cheer"):
        m = f"M {f(-14*hs)} {f(my - 1*hs)} C {f(-8*hs)} {f(my + 15*hs)} {f(8*hs)} {f(my + 15*hs)} {f(14*hs)} {f(my - 1*hs)} Z"
        s += f'<path d="{m}" fill="#7a2230" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        s += f'<path d="M {f(-12*hs)} {f(my + 0.5*hs)} L {f(12*hs)} {f(my + 0.5*hs)} L {f(9*hs)} {f(my + 5*hs)} L {f(-9*hs)} {f(my + 5*hs)} Z" fill="#ffffff"/>'
        s += f'<ellipse cx="0" cy="{f(my + 9.5*hs)}" rx="{f(6*hs)}" ry="{f(2.6*hs)}" fill="#ff8a8a"/>'
    else:
        # easy closed smile with little dimples
        s += f'<path d="M {f(-12*hs)} {f(my)} C {f(-6*hs)} {f(my + 8*hs)} {f(6*hs)} {f(my + 8*hs)} {f(12*hs)} {f(my)}" fill="none" stroke="{INK}" stroke-width="3.4" stroke-linecap="round"/>'
        for sd in (-1, 1):
            s += f'<path d="M {f(sd*12*hs)} {f(my - 2.5*hs)} q {f(sd*2.5*hs)} {f(2*hs)} 0 {f(4.5*hs)}" fill="none" stroke="{SKIN[1]}" stroke-width="2.4" stroke-linecap="round"/>'
    return s


def hair_front(L, hw):
    hs, top, hh = L["hs"], L["top"], L["hh"]
    y = lambda k: top + hh * k
    tw = hw * 0.97
    # pulled-back hair with a soft side-swept fringe (a wave off to the right)
    d = (f"M {f(-tw - 3)} {f(y(0.50))} C {f(-tw - 8)} {f(y(0.12))} {f(-hw*0.55)} {f(top - 10*hs)} {f(4)} {f(top - 10*hs)} "
         f"C {f(hw*0.62)} {f(top - 10*hs)} {f(tw + 9)} {f(y(0.12))} {f(tw + 3)} {f(y(0.50))} "
         f"L {f(tw - 3)} {f(y(0.40))} C {f(tw - 6)} {f(y(0.28))} {f(hw*0.62)} {f(y(0.24))} {f(hw*0.40)} {f(y(0.27))} "
         f"C {f(hw*0.15)} {f(y(0.31))} {f(-hw*0.15)} {f(y(0.36))} {f(-hw*0.45)} {f(y(0.30))} "
         f"C {f(-hw*0.62)} {f(y(0.26))} {f(-tw + 3)} {f(y(0.30))} {f(-tw + 1)} {f(y(0.42))} Z")
    s = shaded(d, HAIR[0], HAIR[1], dx=-5, dy=-6)
    # strands + shine
    s += f'<path d="M {f(-hw*0.55)} {f(top + 4*hs)} Q {f(-hw*0.1)} {f(top - 4*hs)} {f(hw*0.45)} {f(top + 2*hs)}" stroke="{HAIR[2]}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.9"/>'
    s += f'<path d="M {f(-hw*0.2)} {f(y(0.30))} Q {f(hw*0.1)} {f(y(0.18))} {f(hw*0.55)} {f(y(0.20))}" stroke="{HAIR[1]}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    return s


def ponytail(L):
    hs, top, hh, hw = L["hs"], L["top"], L["hh"], L["hw"]
    # high ponytail swinging out behind the head, to the image right
    bx, by = hw * 0.40, top + 4 * hs
    # gathered high at the back of the crown, swings out to the right and falls to the shoulder
    d = (f"M {f(bx - 6)} {f(by - 2)} C {f(bx + 34*hs)} {f(by - 22*hs)} {f(bx + 70*hs)} {f(by - 6*hs)} {f(bx + 74*hs)} {f(by + 30*hs)} "
         f"C {f(bx + 78*hs)} {f(by + 64*hs)} {f(bx + 62*hs)} {f(by + 96*hs)} {f(bx + 46*hs)} {f(by + 118*hs)} "
         f"C {f(bx + 50*hs)} {f(by + 92*hs)} {f(bx + 50*hs)} {f(by + 56*hs)} {f(bx + 34*hs)} {f(by + 30*hs)} "
         f"C {f(bx + 26*hs)} {f(by + 18*hs)} {f(bx + 12)} {f(by + 12*hs)} {f(bx + 4)} {f(by + 14*hs)} Z")
    s = shaded(d, HAIR[0], HAIR[1], dx=-6, dy=-5)
    s += f'<path d="M {f(bx + 34*hs)} {f(by - 8*hs)} Q {f(bx + 66*hs)} {f(by + 2*hs)} {f(bx + 64*hs)} {f(by + 52*hs)}" stroke="{HAIR[2]}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/>'
    s += f'<path d="M {f(bx + 52*hs)} {f(by + 40*hs)} Q {f(bx + 58*hs)} {f(by + 74*hs)} {f(bx + 50*hs)} {f(by + 100*hs)}" stroke="{HAIR[1]}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    # scrunchie
    s += shaded(ellipse_d(bx + 14 * hs, by - 2 * hs, 11 * hs, 9 * hs), SCRUNCHIE[0], SCRUNCHIE[1], dx=-3, dy=-3)
    return s


def headset(L, hw):
    hs, top, hh = L["hs"], L["top"], L["hh"]
    y = lambda k: top + hh * k
    s = ""
    # band over the top
    s += f'<path d="M {f(-hw - 2)} {f(y(0.55))} C {f(-hw - 6)} {f(top - 18*hs)} {f(hw + 6)} {f(top - 18*hs)} {f(hw + 2)} {f(y(0.55))}" fill="none" stroke="{INK}" stroke-width="{f(7*hs)}" stroke-linecap="round"/>'
    s += f'<path d="M {f(-hw - 2)} {f(y(0.55))} C {f(-hw - 6)} {f(top - 18*hs)} {f(hw + 6)} {f(top - 18*hs)} {f(hw + 2)} {f(y(0.55))}" fill="none" stroke="#5a6070" stroke-width="{f(3*hs)}" stroke-linecap="round"/>'
    # ear cups
    for sd in (-1, 1):
        s += shaded(ellipse_d(sd * (hw + 3), y(0.60), 9.5 * hs, 12.5 * hs), "#3a3f4b", "#262a33", dx=-3, dy=-3)
        s += f'<ellipse cx="{f(sd*(hw + 3) - 2*hs)}" cy="{f(y(0.56))}" rx="{f(3*hs)}" ry="{f(4*hs)}" fill="#7a8396"/>'
    # mic boom from the left cup to the corner of the mouth
    mx, my = -hw * 0.30, y(0.80)
    s += f'<path d="M {f(-hw - 3)} {f(y(0.66))} C {f(-hw - 4)} {f(y(0.84))} {f(-hw*0.75)} {f(my + 4*hs)} {f(mx - 4*hs)} {f(my + 1*hs)}" fill="none" stroke="{INK}" stroke-width="{f(5*hs)}" stroke-linecap="round"/>'
    s += f'<path d="M {f(-hw - 3)} {f(y(0.66))} C {f(-hw - 4)} {f(y(0.84))} {f(-hw*0.75)} {f(my + 4*hs)} {f(mx - 4*hs)} {f(my + 1*hs)}" fill="none" stroke="#5a6070" stroke-width="{f(2*hs)}" stroke-linecap="round"/>'
    s += f'<ellipse cx="{f(mx - 3*hs)}" cy="{f(my + 1*hs)}" rx="{f(5*hs)}" ry="{f(4*hs)}" fill="#2a2d34" stroke="{INK}" stroke-width="2"/>'
    return s


# ---------- body ----------
def body(L):
    S, W, N = V["S"], V["W"], V["neck"]
    sy, hip, ank = L["sy"], L["hip"], L["ank"]
    out = []
    # trousers (slimmer than the cargos) + white crew sneakers with a blue stripe
    leg = (f"M {f(-W + 2)} {f(hip - 2)} C {f(-W - 2)} {f(hip + 20)} {f(-W + 4)} {f(ank - 14)} {f(-W + 7)} {f(ank)} "
           f"L {f(-5)} {f(ank)} L {f(-3)} {f(hip + 14)} L {f(3)} {f(hip + 14)} L {f(5)} {f(ank)} "
           f"L {f(W - 7)} {f(ank)} C {f(W - 4)} {f(ank - 14)} {f(W + 2)} {f(hip + 20)} {f(W - 2)} {f(hip - 2)} Z")
    out.append(shaded(leg, V["pants"][0], V["pants"][1], dx=-8, dy=-2))
    for side in (-1, 1):
        x0 = 3 if side > 0 else -W - 3
        bw = W
        sd = (f"M {f(x0)} {f(GROUND)} L {f(x0)} {f(ank - 6)} C {f(x0)} {f(ank - 12)} {f(x0 + bw)} {f(ank - 12)} {f(x0 + bw + 4)} {f(ank - 2)} "
              f"L {f(x0 + bw + 6)} {f(GROUND)} Z")
        out.append(shaded(sd, V["shoes"][0], V["shoes"][1], dx=-4, dy=-3,
                          extra=f'<rect x="{f(x0 - 4)}" y="{f(GROUND - 7)}" width="{f(bw + 12)}" height="8" fill="{V["shoes"][2]}"/>'
                                f'<path d="M {f(x0 + 8)} {f(ank - 4)} l {f(bw*0.6)} 6" stroke="{V["shoes"][2]}" stroke-width="3"/>'))
    nd = f"M {f(-N + 2)} {f(L['chin'] - 30)} L {f(N - 2)} {f(L['chin'] - 30)} L {f(N + 3)} {f(sy + 4)} L {f(-N - 3)} {f(sy + 4)} Z"
    out.append(shaded(nd, SKIN[0], SKIN[1], dx=-4, dy=6))
    # crew tee: chunky shoulders, a softer waist
    td = (f"M {f(-N - 2)} {f(sy - 8)} C {f(-N - 16)} {f(sy - 6)} {f(-S + 12)} {f(sy - 4)} {f(-S)} {f(sy + 14)} "
          f"C {f(-S - 4)} {f(sy + 40)} {f(-W - 4)} {f(hip - 36)} {f(-W - 2)} {f(hip + 6)} "
          f"L {f(W + 2)} {f(hip + 6)} C {f(W + 4)} {f(hip - 36)} {f(S + 4)} {f(sy + 40)} {f(S)} {f(sy + 14)} "
          f"C {f(S - 12)} {f(sy - 4)} {f(N + 16)} {f(sy - 6)} {f(N + 2)} {f(sy - 8)} Z")
    det = f'<path d="M {f(-N - 1)} {f(sy - 8)} C {f(-N + 4)} {f(sy + 12)} {f(N - 4)} {f(sy + 12)} {f(N + 1)} {f(sy - 8)}" fill="{SKIN[0]}" stroke="{INK}" stroke-width="3.5"/>'
    lx, ly = -S * 0.42, sy + 24       # droplet logo (same as the detailers)
    det += f'<path d="M {f(lx)} {f(ly - 9)} C {f(lx + 6)} {f(ly - 1)} {f(lx + 7)} {f(ly + 4)} {f(lx)} {f(ly + 6)} C {f(lx - 7)} {f(ly + 4)} {f(lx - 6)} {f(ly - 1)} {f(lx)} {f(ly - 9)} Z" fill="{V["logo"]}" stroke="{INK}" stroke-width="2"/>'
    # name badge on the other side
    bx, by = S * 0.20, sy + 18
    det += f'<rect x="{f(bx)}" y="{f(by)}" width="30" height="15" rx="4" fill="#ffffff" stroke="{INK}" stroke-width="2.5"/>'
    det += f'<rect x="{f(bx + 5)}" y="{f(by + 5.5)}" width="20" height="4" rx="2" fill="{SCRUNCHIE[0]}"/>'
    det += f'<path d="M {f(-W)} {f(hip - 20)} Q 0 {f(hip - 12)} {f(W)} {f(hip - 20)}" fill="none" stroke="{V["shirt"][1]}" stroke-width="3" stroke-linecap="round"/>'
    out.append(shaded(td, V["shirt"][0], V["shirt"][1], dx=-12, dy=-4, extra=det))
    bd = f"M {f(-W - 3)} {f(hip - 2)} L {f(W + 3)} {f(hip - 2)} L {f(W + 2)} {f(hip + 8)} L {f(-W - 2)} {f(hip + 8)} Z"
    out.append(f'<path d="{bd}" fill="#2b2522" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>')
    return "".join(out)


def arm(sh, el, wr, side, anchor, hand="open", hold=None):
    """Bare forearm + hand (no gloves at the desk), sleeve grows out of the tee like the detailers'."""
    s = ""
    fa = limb(el, wr, 26, 21, bulge=4)
    s += shaded(fa, SKIN[0], SKIN[1], dx=-5, dy=-4)
    ua = limb(sh, el, 34, 26, bulge=6)
    s += shaded(ua, SKIN[0], SKIN[1], dx=-6, dy=-4)
    s += D.attached_sleeve(V, sh, el, side, anchor)
    L_ = math.hypot(wr[0] - el[0], wr[1] - el[1]) or 1
    ux, uy = (wr[0] - el[0]) / L_, (wr[1] - el[1]) / L_
    hx, hy = wr[0] + ux * 9, wr[1] + uy * 9
    if hold:
        s += hold(hx, hy)
    if hand == "fist":
        s += shaded(ellipse_d(hx, hy, 14, 13), SKIN[0], SKIN[1], dx=-4, dy=-4)
        for k in (-1, 0, 1):
            s += f'<path d="M {f(hx + k*5 + ux*2)} {f(hy - 4)} l 0 6" stroke="{SKIN[1]}" stroke-width="2.2" stroke-linecap="round"/>'
    else:
        # open hand: palm + a mitten of fingers + thumb
        s += shaded(ellipse_d(hx, hy, 13, 12), SKIN[0], SKIN[1], dx=-4, dy=-4)
        tx = hx - side * 10
        s += shaded(ellipse_d(tx, hy - 3, 6, 8), SKIN[0], SKIN[1], dx=-2, dy=-2)
    return s


def notes(hx, hy):
    """A little stack of green notes held flat."""
    s = ""
    for k in range(3):
        s += f'<rect x="{f(hx - 22)}" y="{f(hy - 10 - k*4)}" width="44" height="14" rx="2.5" fill="#43a047" stroke="{INK}" stroke-width="2.5"/>'
    s += f'<rect x="{f(hx - 18)}" y="{f(hy - 16)}" width="36" height="3" fill="#e8f5e9"/>'
    s += f'<circle cx="{f(hx)}" cy="{f(hy - 12)}" r="3.2" fill="#e8f5e9"/>'
    return s


def figure(pose="stand", mood=None):
    L = layout()
    S, sy, N = V["S"], L["sy"], V["neck"]
    parts = [body(L)]
    mood = mood or {"stand": "smile", "count": "smile", "cheer": "cheer"}[pose]
    for side in (-1, 1):
        sh = (side * (S - 12), sy + 18)
        if pose == "cheer" and side < 0:   # the arm away from the ponytail
            el, wr, hand, hold = (side * (S + 40), sy - 6), (side * (S + 30), sy - 64), "fist", None
        elif pose == "count":
            # elbows out, forearms forward: hands resting on the counter top, counting a stack of notes
            el, wr, hand, hold = (side * (S + 8), sy + 50), (side * 30, sy + 58), "open", (notes if side < 0 else None)
        else:
            el, wr, hand, hold = (side * (S + 4), sy + 58), (side * (S - 2), sy + 94), "open", None
        anc = bez((S, sy + 14), (S - 12, sy - 4), (N + 16, sy - 6), (N + 2, sy - 8), 0.30)
        parts.append(arm(sh, el, wr, side, (side * anc[0], anc[1]), hand, hold))
    parts.append(head(L, mood))
    return "".join(parts)


def svg(body_, w=320, h=360, vb=(-160, -60, 320, 365)):
    return D.svg(body_, w, h, vb)
