"""Front desk art (v0.19g): counter, the register at each desk stage, cash, and the back wall
(a showroom window, or a plain shop wall). Same ink + cel-shade look as the characters.
Units = screen px at the game's 720 wide layout; baked at RES x for crisp mipmapped textures.
  counter          wooden front desk with a marble top (FRONT DESK is written on its brass plate in Godot)
  reg_tin          Lv 1   cash tin (body)      reg_tin_lid  its lid (lifts when it takes the cash)
  reg_terminal     Lv 10  card terminal in a dock (stands next to the tin)
  reg_retro        Lv 50  mint retro cash register     reg_drawer  its cash drawer (slides out on payout)
  reg_pos          Lv 200 touchscreen POS: tablet on a stand, card tap pad, receipt printer, slim drawer
  cash_stack       a banded stack of notes      coin_stack  three coins
  show_back        showroom interior behind the glass (hexagon LED ceiling + its reflection in the floor, plinths)
  show_glass       window frame + glass tint + reflections (drawn over the cars)
(Hamza picked the showroom over a plain shop wall, 19 Oct; the cars are drawn in Godot between the two layers.)
Writes <proj>/assets/game/sprites/desk/*.png and <proj>/scripts/desk_parts.gd (pivots).
Run: python3 tools/char/desk_art.py <project> [sheet.png]
"""
import sys, os, io, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detailer as D
from PIL import Image
from playwright.sync_api import sync_playwright

INK = D.INK
RES = 2.0
OUTW = 2.5          # outline width (screen px)
WIN = (318.0, 60.0, 286.0, 82.0)    # the window in the desk row (x, y, w, h)
PANE_W, FRAME, MULL = 88.0, 6.0, 5.0


def rr(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (f"M {x + r:.1f} {y:.1f} H {x + w - r:.1f} A {r} {r} 0 0 1 {x + w:.1f} {y + r:.1f} V {y + h - r:.1f} "
            f"A {r} {r} 0 0 1 {x + w - r:.1f} {y + h:.1f} H {x + r:.1f} A {r} {r} 0 0 1 {x:.1f} {y + h - r:.1f} "
            f"V {y + r:.1f} A {r} {r} 0 0 1 {x + r:.1f} {y:.1f} Z")


def sh(d, base, shade, dx=-3.0, dy=-2.5, light=None, lw=1.6, sw=OUTW, stroke=True, extra=""):
    return D.shaded(d, base, shade, dx=dx, dy=dy, light=light, ldx=-1.2, ldy=-1.2, lw=lw, stroke=stroke, sw=sw, extra=extra)


def path(d, fill="none", stroke=None, sw=OUTW, op=1.0, cap="round"):
    s = f'<path d="{d}" fill="{fill}" opacity="{op}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="round"'
    return s + "/>"


def ell(cx, cy, rx, ry):
    return D.ellipse_d(cx, cy, rx, ry)


# ------------------------------------------------------------------ counter
def counter():
    W = 308.0
    s = ""
    body = rr(8, 5, W - 16, 45, 7)
    kick = f'<rect x="0" y="42" width="{W}" height="12" fill="#6e3d1d"/>'
    grain = "".join(path(f"M {x} 16 V 40", stroke="#9d6234", sw=1.2, op=0.6) for x in (14, 20, 232, 246, 260, 274))
    s += sh(body, "#bd7a42", "#8f5630", dx=-4, dy=-3, extra=kick + grain)
    # side panel under the register (its drawer slides out over it, not over the name)
    s += sh(rr(214, 14, 76, 25, 5), "#ad6c37", "#83491f", dx=2, dy=2, sw=1.6)
    # brass name plate (FRONT DESK is drawn on it in Godot: PLATE)
    s += path(rr(28, 12, 176, 29, 8), fill=INK)
    s += sh(rr(30, 14, 172, 25, 7), "#e9bf5f", "#b98a2c", dx=-2, dy=-2, stroke=False)
    s += sh(rr(34, 17, 164, 19, 5), "#5b3219", "#472612", dx=2, dy=2, sw=1.4)
    for x in (38, 194):
        s += f'<circle cx="{x}" cy="26.5" r="1.6" fill="#ffe7a3"/>'
    # marble top
    veins = (path("M 40 3 C 60 9, 80 2, 110 8", stroke="#cdb38a", sw=1.0, op=0.55)
             + path("M 180 9 C 205 3, 225 10, 262 4", stroke="#cdb38a", sw=1.0, op=0.55))
    s += sh(rr(0, -1, W, 14, 6), "#f8eedb", "#d9c19a", dx=-2, dy=-3, light="#ffffff", lw=1.6, extra=veins)
    return s


# ------------------------------------------------------------------ registers (origin = bottom centre, on the counter)
def tin_body():
    s = sh(rr(-28, -24, 56, 24, 5), "#a7bac6", "#71889a", dx=-3, dy=-2)
    s += path(rr(-22, -18, 44, 12, 3), stroke="#8aa0ae", sw=1.4)
    s += f'<circle cx="0" cy="-12" r="2.6" fill="{INK}"/>' + path("M 0 -12 V -8", stroke=INK, sw=1.8)
    return s


def tin_lid():   # origin = where it sits on the body
    s = path("M -9 -6 C -9 -14, 9 -14, 9 -6", stroke=INK, sw=4.6) + path("M -9 -6 C -9 -14, 9 -14, 9 -6", stroke="#cfd8dc", sw=2.0)
    s += sh(rr(-30, -7, 60, 8, 4), "#c3d1da", "#8ea4b2", dx=-2, dy=-1.5, light="#ffffff", lw=1.2)
    return s


def terminal():
    s = sh(rr(-13, -8, 26, 8, 3), "#3c4152", "#262a36", dx=-2, dy=-1.5)                 # dock
    s += sh(rr(-10, -38, 20, 33, 5), "#3c4152", "#262a36", dx=-2, dy=-2)                # handset
    s += path(rr(-7, -35, 14, 9, 2), fill="#a5d6a7") + path("M -5 -31 H 3", stroke="#3e8e41", sw=1.2)
    for r_ in range(3):
        for c in range(3):
            s += f'<circle cx="{-4.5 + c * 4.5}" cy="{-21 + r_ * 4.2}" r="1.35" fill="#b8bfd0"/>'
    s += path("M -6 -39.5 H 6", stroke="#1d1b2b", sw=2.0)   # card slot
    return s


def retro():
    s = sh(rr(-40, -20, 80, 20, 5), "#62c7b8", "#3d9a8c", dx=-3, dy=-2)                # drawer body
    s += path("M -36 -9 H 36", stroke="#3d9a8c", sw=1.4) + sh(rr(-9, -15, 18, 4.5, 2), "#e0e6e4", "#a8b3b0", sw=1.4)
    deck = "M -37 -20 L 37 -20 L 31 -42 L -31 -42 Z"
    keys = ""
    for r_ in range(3):
        for c in range(5):
            y = -38 + r_ * 6
            x = -22 + c * 11 - (2 - r_) * 0.0
            keys += path(rr(x - 3.6 + (r_ - 1) * 0.0, y, 7.2 + r_ * 0.6, 4.6, 1.5), fill="#fff4dd" if (r_, c) != (2, 4) else "#ff8a80",
                         stroke=INK, sw=1.1)
    s += sh(deck, "#71d3c4", "#46a798", dx=-3, dy=-2, extra="") + keys
    s += sh(rr(-4, -48, 8, 7, 2), "#3b3f50", "#262a36", sw=1.6)                         # neck
    s += sh(rr(-18, -62, 36, 16, 5), "#3b3f50", "#262a36", dx=-2, dy=-2)                # display pod
    s += path(rr(-14, -59, 28, 10, 2.5), fill="#a5d6a7") + path("M -10 -54 H 8", stroke="#3e8e41", sw=1.4)
    s += sh(ell(43, -16, 3.2, 3.2), "#ffcf4a", "#d39b1d", sw=1.4) + path("M 40 -16 H 34", stroke=INK, sw=2.2)   # crank
    return s


def drawer():    # origin = top centre (just under the register's front)
    s = sh(rr(-36, 0, 72, 13, 3), "#2f3341", "#1f222d", dx=-2, dy=-1.5)
    s += path(rr(-33, 2, 66, 6, 2), fill="#ece0c8")
    for i, x in enumerate((-30, -17, -4)):
        s += path(rr(x, 2.5, 11, 5, 1), fill="#6cc070", stroke="#3f8f45", sw=0.8)
    for x in (12, 19, 26):
        s += f'<circle cx="{x}" cy="5" r="2.3" fill="#ffcf4a" stroke="#b07a10" stroke-width="0.8"/>'
    s += sh(rr(-8, 9, 16, 3, 1.5), "#cfd8dc", "#90a4ae", sw=1.0)
    return s


def pos():
    s = sh(rr(-38, -12, 76, 12, 4), "#3b3f50", "#262a36", dx=-2, dy=-1.5)                 # slim drawer
    s += path("M -32 -6 H 32", stroke="#5b6176", sw=1.2)
    s += sh(rr(-10, -15, 20, 4, 2), "#cfd8dc", "#90a4ae", sw=1.6)                        # stand foot
    s += sh(rr(-3, -30, 6, 16, 2), "#cfd8dc", "#90a4ae", sw=1.6)                          # stand neck
    s += sh(rr(-27, -58, 54, 34, 6), "#f5f7fa", "#c8d0da", dx=-2, dy=-2)                  # tablet
    scr = (f'<defs><linearGradient id="pg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5ab4f5"/>'
           f'<stop offset="1" stop-color="#1e7fd6"/></linearGradient></defs>')
    s += scr + path(rr(-23, -54, 46, 26, 3), fill="url(#pg)")
    s += f'<circle cx="-11" cy="-41" r="7" fill="#ffffff" opacity="0.95"/>' + path("M -14.5 -41 L -11.8 -38 L -7 -44", stroke="#2e9b4f", sw=2.2)
    s += path("M 0 -46 H 17", stroke="#ffffff", sw=2.2, op=0.9) + path("M 0 -40 H 13", stroke="#ffffff", sw=2.2, op=0.6) + path("M 0 -34 H 15", stroke="#ffffff", sw=2.2, op=0.6)
    # card tap pad (left) + receipt printer (right)
    s += sh(rr(-52, -20, 14, 20, 3), "#3b3f50", "#262a36", dx=-1.5, dy=-1.5)
    for r_ in (2.5, 4.5, 6.5):
        s += path(f"M {-46 + r_ * 0.2:.1f} {-13 - r_:.1f} A {r_} {r_} 0 0 1 {-46 + r_ * 0.2:.1f} {-13 + r_:.1f}", stroke="#c5cbe0", sw=1.1)
    s += path("M 40 -24 C 40 -34, 50 -34, 47 -42", stroke=INK, sw=6.0) + path("M 40 -24 C 40 -34, 50 -34, 47 -42", stroke="#ffffff", sw=3.4)
    s += sh(rr(32, -24, 22, 24, 4), "#f5f7fa", "#c8d0da", dx=-1.5, dy=-1.5)
    s += path("M 36 -21 H 50", stroke=INK, sw=1.6)
    return s


def cash_stack():   # origin = bottom centre
    s = ""
    for i in range(5):
        y = -3.2 * (i + 1)
        x = (-1.2, 0.8, -0.4, 1.1, 0.0)[i]
        top = i == 4
        s += path(rr(-17 + x, y, 34, 3.6, 1.2), fill="#8fd694" if top else "#6cc070", stroke=INK, sw=1.2)
    s += path("M -12 -14.5 H 12", stroke="#3f8f45", sw=0.8, op=0.7)
    s += path(rr(-4, -17.5, 8, 18, 1.5), fill="#f3e3b5", stroke=INK, sw=1.2)          # paper band
    s += path("M -2 -13 H 2 M -2 -9 H 2", stroke="#c9a64d", sw=0.9)
    return s


def coin_stack():
    s = ""
    for i in range(3):
        y = -3.0 * i - 2.4
        s += sh(ell(0, y, 7, 2.6), "#ffd65a", "#d39b1d", dx=-1, dy=-0.6, sw=1.3)
    s += f'<text x="0" y="-7" font-size="4" text-anchor="middle" fill="#b07a10" font-family="sans-serif" font-weight="700">$</text>'
    return s


# ------------------------------------------------------------------ back wall: showroom window
def panes():
    return [(FRAME + k * (PANE_W + MULL), FRAME, PANE_W, WIN[3] - 2 * FRAME) for k in range(3)]


def honeycomb(x0, y0, w, h, r, sy, stroke, sw, op, glow=False):
    """A flattened honeycomb of hexagon outlines (detailing-studio LED lights seen at an angle),
    clipped to the box. sy squashes it vertically (perspective)."""
    cid = D.uid("hx")
    s = f'<clipPath id="{cid}"><rect x="{x0}" y="{y0}" width="{w}" height="{h}"/></clipPath><g clip-path="url(#{cid})">'
    dx, dy = r * 1.5, r * math.sqrt(3) * sy
    d = ""
    cols = int(w / dx) + 3
    rows = int(h / dy) + 3
    for c in range(-1, cols):
        for rw in range(-1, rows):
            cx = x0 + c * dx
            cy = y0 + rw * dy + (dy / 2 if c % 2 else 0)
            pts = [(cx + r * math.cos(a), cy + r * math.sin(a) * sy) for a in (k * math.pi / 3 for k in range(6))]
            d += "M " + " L ".join(f"{px:.1f} {py:.1f}" for px, py in pts) + " Z "
    if glow:
        s += f'<path d="{d}" fill="none" stroke="#bfe9ff" stroke-width="{sw * 3}" opacity="{op * 0.35}" stroke-linejoin="round"/>'
    s += f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" stroke-linejoin="round"/>'
    return s + "</g>"


CEIL = 18.0     # the showroom ceiling band (hex LEDs) in the window
FLOOR = 50.0    # where the polished showroom floor starts


def show_back():
    w, h = WIN[2], WIN[3]
    s = ('<defs><linearGradient id="sw" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3f6fa"/>'
         '<stop offset="1" stop-color="#d5dde7"/></linearGradient>'
         '<linearGradient id="sf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#aeb9c6"/>'
         '<stop offset="1" stop-color="#e3e8ef"/></linearGradient>'
         '<linearGradient id="sl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.7"/>'
         '<stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient></defs>')
    s += f'<rect x="0" y="0" width="{w}" height="{h}" fill="url(#sw)"/>'
    for (x, y, pw, ph) in panes():   # back wall panels
        s += f'<rect x="{x + 5}" y="{CEIL + 4}" width="{pw - 10}" height="{FLOOR - CEIL - 8}" rx="2" fill="#e9eef5" opacity="0.9"/>'
    s += f'<rect x="0" y="{CEIL}" width="{w}" height="22" fill="url(#sl)"/>'                    # light falling from the LEDs
    # v0.19g (Hamza): the hexagon LED ceiling you see in detailing studios
    s += f'<rect x="0" y="0" width="{w}" height="{CEIL}" fill="#232733"/>'
    s += honeycomb(0, 1, w, CEIL - 1, 6.5, 0.42, "#f4fbff", 1.5, 0.95, glow=True)
    s += f'<rect x="0" y="{CEIL - 1}" width="{w}" height="1.5" fill="#11131a"/>'
    # polished floor + the LED honeycomb reflected in it
    s += f'<rect x="0" y="{FLOOR}" width="{w}" height="{h - FLOOR}" fill="url(#sf)"/>'
    s += honeycomb(0, FLOOR + 2, w, h - FLOOR - 2, 7.0, 0.36, "#ffffff", 1.2, 0.35)
    s += f'<rect x="0" y="{FLOOR}" width="{w}" height="1.5" fill="#8f9aa8"/>'
    for (x, y, pw, ph) in panes():
        cx = x + pw / 2
        s += sh(ell(cx, 64, 39, 5.5), "#474d5e", "#2e3240", dx=0, dy=1.5, sw=1.8)        # plinth
        s += path(ell(cx, 62.6, 36, 3.6), fill="#6b7287")
    return s


def show_glass():
    w, h = WIN[2], WIN[3]
    s = ""
    for (x, y, pw, ph) in panes():
        s += f'<rect x="{x}" y="{y}" width="{pw}" height="{ph}" fill="#bfe6ff" opacity="0.16"/>'
        s += path(f"M {x + 10} {y + ph} L {x + 30} {y} L {x + 40} {y} L {x + 20} {y + ph} Z", fill="#ffffff", op=0.22)
        s += path(f"M {x + 46} {y + ph} L {x + 60} {y} L {x + 64} {y} L {x + 50} {y + ph} Z", fill="#ffffff", op=0.16)
    frame = rr(0, 0, w, h, 4)
    holes = "".join(f" M {x} {y} h {pw} v {ph} h {-pw} Z" for (x, y, pw, ph) in panes())
    s += f'<path d="{frame}{holes}" fill="#cfd8e2" fill-rule="evenodd"/>'
    s += f'<path d="{frame}{holes}" fill="none" stroke="{INK}" stroke-width="{OUTW}" stroke-linejoin="round"/>'
    s += path(f"M 2 2.5 H {w - 2}", stroke="#ffffff", sw=1.2, op=0.7)
    s += sh(rr(-6, h - 3, w + 12, 8, 3), "#eef1f5", "#b9c3cf", dx=-1, dy=-1.5)             # sill
    return s


PIECES = {
    # name: (fn, viewBox, pivot in piece coords)
    "counter": (counter, (-4, -4, 316, 62), (0.0, 0.0)),
    "reg_tin": (tin_body, (-34, -30, 68, 34), (0.0, 0.0)),
    "reg_tin_lid": (tin_lid, (-34, -18, 68, 22), (0.0, 0.0)),
    "reg_terminal": (terminal, (-16, -44, 32, 48), (0.0, 0.0)),
    "reg_retro": (retro, (-46, -68, 96, 72), (0.0, 0.0)),
    "reg_drawer": (drawer, (-40, -4, 80, 22), (0.0, 0.0)),
    "reg_pos": (pos, (-58, -64, 118, 68), (0.0, 0.0)),
    "cash_stack": (cash_stack, (-22, -24, 44, 28), (0.0, 0.0)),
    "coin_stack": (coin_stack, (-10, -14, 20, 16), (0.0, 0.0)),
    "show_back": (show_back, (-2, -2, WIN[2] + 4, WIN[3] + 4), (0.0, 0.0)),
    "show_glass": (show_glass, (-10, -4, WIN[2] + 20, WIN[3] + 12), (0.0, 0.0)),
}


def render(pg, body, vb):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{vb[2]}" height="{vb[3]}" viewBox="{vb[0]} {vb[1]} {vb[2]} {vb[3]}">{body}</svg>'
    pg.set_viewport_size({"width": int(math.ceil(vb[2])) + 4, "height": int(math.ceil(vb[3])) + 4})
    pg.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
    return Image.open(io.BytesIO(pg.locator("svg").screenshot(omit_background=True))).convert("RGBA")


def main():
    proj = sys.argv[1] if len(sys.argv) > 1 else "."
    out = os.path.join(proj, "assets/game/sprites/desk")
    os.makedirs(out, exist_ok=True)
    piv = {}
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=RES)
        for name, (fn, vb, pv) in PIECES.items():
            img = render(pg, fn(), vb)
            img.save(os.path.join(out, name + ".png"), optimize=True)
            piv[name] = ((pv[0] - vb[0]) * RES, (pv[1] - vb[1]) * RES)
        b.close()
    gd = ['extends RefCounted',
          '## GENERATED by tools/char/desk_art.py (front desk art). Don\'t edit.',
          '## Textures: res://assets/game/sprites/desk/<name>.png, baked at RES x; PARTS = pivot in texture px.',
          '',
          'const RES := %.1f' % RES,
          'const WIN := Rect2(%.1f, %.1f, %.1f, %.1f)   # the window in the desk row' % WIN,
          'const PLATE := Rect2(34.0, 17.0, 164.0, 19.0)   # the name plate\'s dark inset, in counter coords',
          'const CEIL := %.1f       # showroom ceiling band height (window coords)' % CEIL,
          'const FLOOR := %.1f      # showroom floor line (window coords)' % FLOOR,
          'const PLINTH_Y := 63.5   # front cars stand here (window coords)',
          'const PANES := [']
    for (x, y, pw, ph) in panes():
        gd.append('\tRect2(%.1f, %.1f, %.1f, %.1f),' % (x, y, pw, ph))
    gd += [']', 'const PARTS := {']
    for k, v in piv.items():
        gd.append('\t"%s": Vector2(%.1f, %.1f),' % (k, v[0], v[1]))
    gd.append('}')
    with open(os.path.join(proj, "scripts/desk_parts.gd"), "w") as fh:
        fh.write("\n".join(gd) + "\n")
    print("baked", list(piv))


if __name__ == "__main__":
    main()
