"""Bake the SOAP-BUBBLE ability buttons (v0.19d, Hamza 19 Oct: "the little ability buttons were a rough sketch").

One translucent soap bubble per ability colour with the ability's picture floating inside it:
  income   = money bag with a "$"          (green bubble)
  speed    = stopwatch with speed lines    (blue bubble)
  discount = price tag with a "%"          (orange bubble)
  signature (Dazza's Tip Jar) = tip jar with coins (gold bubble)
Layers (all centred, drawn by scripts/ability_icon.gd):
  body_<kind>   the bubble film: tinted, darker towards the rim, an iridescent rim (rotated slowly in game)
  body_grey     recharging bubble
  shine         white glints, drawn OVER the icon so the icon looks inside the bubble
  glow_<kind>   soft glow behind the bubble while the ability runs
  icon_<kind>, icon_<kind>_grey
  mini_<kind>   tiny bubble (active fizz + the pop burst)
Run: python3 tools/char/ability_bubble.py <project> [sig]   (sig = only the v0.19q signature pictures) (Playwright + Chromium render the SVGs, Pillow for grey copies)
Writes <project>/assets/game/sprites/ability/*.png. Open Godot afterwards (the .import files turn mipmaps on).
"""
import os, sys
from playwright.sync_api import sync_playwright
from PIL import Image, ImageOps

PROJ = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(PROJ, "assets/game/sprites/ability")
FONT = os.path.abspath(os.path.join(PROJ, "assets/game/fonts/fredoka_700.ttf"))
INK = "#1d1b2b"
SCALE = 2
BUB_VB = 80        # bubble viewbox; bubble radius R_B units -> R_B * SCALE px in the texture
R_B = 34
ICON_VB = 100

KINDS = {   # light, mid, deep (same family as the suds aura colours)
    "income": ("#d6ffe3", "#6ee89a", "#2fae5e"),
    "speed": ("#dff3ff", "#6cc6ff", "#2a82e8"),
    "discount": ("#fff0d6", "#ffbe5c", "#f07a12"),
    "signature": ("#fff6cf", "#ffd54f", "#c99a12"),
}
GREY = ("#eef1f5", "#b4bcc8", "#6b7484")


def bubble_body(c, irid=True):
    c0, c1, c2 = c
    cx = cy = BUB_VB / 2
    irid_arcs = ""
    if irid:
        # iridescent film: soft pink / cyan / yellow bands round the rim
        for col, a0, a1 in (("#ff8ad8", 200, 290), ("#7fe3ff", 300, 400), ("#fff27a", 60, 150), ("#b9a3ff", 150, 200)):
            irid_arcs += arc(cx, cy, R_B - 3.2, a0, a1, col, 3.4, 0.55)
    return f'''<defs>
<radialGradient id="f" cx="46%" cy="44%" r="56%">
 <stop offset="0" stop-color="{c0}" stop-opacity="0.80"/><stop offset="0.55" stop-color="{c1}" stop-opacity="0.78"/>
 <stop offset="0.86" stop-color="{c1}" stop-opacity="0.92"/><stop offset="1" stop-color="{c2}" stop-opacity="1"/></radialGradient>
<radialGradient id="h" cx="35%" cy="30%" r="45%">
 <stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>
</defs>
<circle cx="{cx}" cy="{cy}" r="{R_B + 1.4}" fill="{INK}" opacity="0.85"/>
<circle cx="{cx}" cy="{cy}" r="{R_B}" fill="url(#f)"/>
<circle cx="{cx}" cy="{cy}" r="{R_B}" fill="url(#h)"/>
{irid_arcs}
<circle cx="{cx}" cy="{cy}" r="{R_B - 0.8}" fill="none" stroke="{c2}" stroke-width="1.6" opacity="0.9"/>'''


def arc(cx, cy, r, a0, a1, col, w, op):
    import math
    p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
    p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return (f'<path d="M{p0[0]:.2f},{p0[1]:.2f} A{r},{r} 0 {large} 1 {p1[0]:.2f},{p1[1]:.2f}" fill="none" '
            f'stroke="{col}" stroke-width="{w}" stroke-linecap="round" opacity="{op}"/>')


def shine():
    cx = cy = BUB_VB / 2
    return (arc(cx, cy, R_B * 0.76, 198, 262, "#ffffff", 4.6, 0.95)
            + f'<circle cx="{cx + R_B * 0.76 * -0.20:.2f}" cy="{cy - R_B * 0.76 * 0.98:.2f}" r="2.4" fill="#ffffff" opacity="0.95"/>'
            + arc(cx, cy, R_B * 0.80, 25, 70, "#ffffff", 2.2, 0.5))


def glow(c):
    c0, c1, c2 = c
    cx = cy = BUB_VB / 2
    return f'''<defs><filter id="b" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="5"/></filter></defs>
<circle cx="{cx}" cy="{cy}" r="{R_B + 3}" fill="{c1}" filter="url(#b)" opacity="0.95"/>
<circle cx="{cx}" cy="{cy}" r="{R_B - 2}" fill="{c0}" filter="url(#b)" opacity="0.7"/>'''


def mini(c):
    c0, c1, c2 = c
    return f'''<circle cx="10" cy="10" r="8.6" fill="{INK}" opacity="0.5"/>
<circle cx="10" cy="10" r="7.8" fill="{c1}" opacity="0.75"/><circle cx="10" cy="10" r="5.5" fill="{c0}" opacity="0.5"/>
<path d="M5.6,8.4 A5,5 0 0 1 9,5.1" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/>'''


def txt(x, y, s, size, fill, stroke=6):
    return (f'<text x="{x}" y="{y}" text-anchor="middle" font-family="F" font-size="{size}" fill="{fill}" '
            f'stroke="{INK}" stroke-width="{stroke}" stroke-linejoin="round" paint-order="stroke">{s}</text>')


ICONS = {
    # money bag: burlap sack, rope tie, a big green "$"
    "income": f'''
<path d="M36,40 L27,17 Q38,22 42,25 L50,12 L58,25 Q62,22 73,17 L64,40 Z" fill="#d9a35a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<path d="M33,42 C12,58 12,92 50,92 C88,92 88,58 67,42 Z" fill="#d9a35a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<path d="M72,56 C82,70 78,86 58,89" fill="none" stroke="#b07a3a" stroke-width="6" stroke-linecap="round"/>
<ellipse cx="34" cy="58" rx="6" ry="9" fill="#f3cf8e" transform="rotate(25 34 58)"/>
<rect x="31" y="35" width="38" height="11" rx="5.5" fill="#8a5530" stroke="{INK}" stroke-width="5"/>
{txt(50, 85, "$", 40, "#3fcf72", 7)}''',
    # stopwatch: white face, blue bezel, hand, three speed lines
    "speed": f'''
<rect x="49" y="7" width="16" height="10" rx="3" fill="#cfd8e3" stroke="{INK}" stroke-width="5"/>
<rect x="53" y="15" width="8" height="9" fill="#cfd8e3" stroke="{INK}" stroke-width="5"/>
<rect x="78" y="20" width="12" height="9" rx="3" fill="#cfd8e3" stroke="{INK}" stroke-width="5" transform="rotate(45 84 24.5)"/>
<circle cx="57" cy="57" r="31" fill="#ffffff" stroke="{INK}" stroke-width="6"/>
<circle cx="57" cy="57" r="24" fill="none" stroke="#2a82e8" stroke-width="5"/>
<path d="M57,57 L57,39" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
<path d="M57,57 L69,48" stroke="#e53935" stroke-width="5" stroke-linecap="round"/>
<circle cx="57" cy="57" r="5" fill="{INK}"/>
<path d="M4,46 L20,46 M2,60 L18,60 M6,74 L20,74" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>
<path d="M4,46 L20,46 M2,60 L18,60 M6,74 L20,74" stroke="#ffffff" stroke-width="5" stroke-linecap="round"/>''',
    # price tag: cream tag on a string, an orange "%"
    "discount": f'''
<g transform="rotate(-22 52 54)">
<path d="M8,54 L30,28 L88,28 Q95,28 95,35 L95,73 Q95,80 88,80 L30,80 Z" fill="#fff3dc" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<circle cx="27" cy="54" r="6" fill="#ffbe5c" stroke="{INK}" stroke-width="4.5"/>
{txt(64, 71, "%", 46, "#f07a12", 7)}
</g>''',
    # Dazza's tip jar: glass jar, wooden lid, gold coins, one going in
    "signature": f'''
<rect x="24" y="30" width="52" height="62" rx="13" fill="#e3f6ff" stroke="{INK}" stroke-width="6"/>
<rect x="30" y="58" width="40" height="28" rx="8" fill="#6fd16a"/>
<circle cx="40" cy="68" r="7" fill="#ffd23f" stroke="{INK}" stroke-width="3.5"/><circle cx="58" cy="74" r="7" fill="#ffd23f" stroke="{INK}" stroke-width="3.5"/>
<rect x="31" y="38" width="7" height="40" rx="3.5" fill="#ffffff" opacity="0.8"/>
<rect x="28" y="20" width="44" height="13" rx="4" fill="#8d6e63" stroke="{INK}" stroke-width="5"/>
<circle cx="50" cy="9" r="8" fill="#ffd23f" stroke="{INK}" stroke-width="4"/>''',
}


# v0.19q: pictures for individual premium signatures (ability_icon.gd uses icon_<ability id> when it exists,
# on the gold signature bubble). Bake just these with:  python3 tools/char/ability_bubble.py <project> sig
def _ute(x, y, s=1.0):
    return (f'<g transform="translate({x} {y}) scale({s})">'
            f'<rect x="0" y="8" width="44" height="16" rx="5" fill="#ffd23f" stroke="{INK}" stroke-width="4.5"/>'
            f'<path d="M24,9 L28,0 L40,0 L44,9 Z" fill="#9fe0ff" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
            f'<rect x="3" y="11" width="18" height="9" rx="2" fill="#8d6e63"/>'
            f'<circle cx="11" cy="25" r="5.5" fill="{INK}"/><circle cx="35" cy="25" r="5.5" fill="{INK}"/></g>')


SIG_ICONS = {
    # Kev's Shortcut: a key with a big green arrow leaping up and over (straight to the pickup lot)
    "shortcut": f'''
<circle cx="26" cy="74" r="13" fill="#ffd23f" stroke="{INK}" stroke-width="5"/>
<circle cx="26" cy="74" r="5" fill="#fff6cf" stroke="{INK}" stroke-width="3"/>
<path d="M36,80 L58,80 M50,80 L50,88 M56,80 L56,86" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>
<path d="M36,80 L58,80 M50,80 L50,88 M56,80 L56,86" stroke="#cfd8dc" stroke-width="4.5" stroke-linecap="round"/>
<path d="M30,52 C30,24 56,14 76,24" fill="none" stroke="{INK}" stroke-width="15" stroke-linecap="round"/>
<path d="M30,52 C30,24 56,14 76,24" fill="none" stroke="#3ccf5a" stroke-width="8" stroke-linecap="round"/>
<path d="M64,8 L92,28 L62,40 Z" fill="#3ccf5a" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round"/>''',
    # Priya's Finish Line: a chequered flag on a pole
    "finish_line": f'''
<rect x="18" y="10" width="8" height="84" rx="4" fill="#8d6e63" stroke="{INK}" stroke-width="5"/>
<path d="M26,14 C44,6 58,22 82,14 L82,54 C58,62 44,46 26,54 Z" fill="#ffffff" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<g fill="{INK}">
<rect x="27" y="15" width="11" height="10"/><rect x="49" y="15" width="11" height="10"/><rect x="71" y="15" width="10" height="10"/>
<rect x="38" y="25" width="11" height="10"/><rect x="60" y="25" width="11" height="10"/>
<rect x="27" y="35" width="11" height="10"/><rect x="49" y="35" width="11" height="10"/><rect x="71" y="35" width="10" height="10"/>
<rect x="38" y="45" width="11" height="8"/><rect x="60" y="45" width="11" height="8"/></g>
<circle cx="22" cy="10" r="7" fill="#ffd23f" stroke="{INK}" stroke-width="4"/>''',
    # Marco's Convoy: three utes in a row, loaded up
    "convoy": f'''{_ute(4, 6, 0.9)}{_ute(28, 36, 0.9)}{_ute(52, 66, 0.9)}''',
    # v0.19r Shazza's Clear the Lot: a cash register drawer bursting with notes
    "clear_lot": f'''
<rect x="14" y="44" width="72" height="44" rx="8" fill="#ff8a3d" stroke="{INK}" stroke-width="6"/>
<rect x="24" y="54" width="52" height="12" rx="4" fill="#fff3dc" stroke="{INK}" stroke-width="4"/>
<rect x="8" y="76" width="84" height="18" rx="5" fill="#d0611a" stroke="{INK}" stroke-width="5"/>
<g transform="rotate(-18 34 30)"><rect x="18" y="20" width="34" height="18" rx="3" fill="#6fd36a" stroke="{INK}" stroke-width="4.5"/><circle cx="35" cy="29" r="4" fill="#2e7d32"/></g>
<g transform="rotate(14 66 26)"><rect x="50" y="16" width="34" height="18" rx="3" fill="#6fd36a" stroke="{INK}" stroke-width="4.5"/><circle cx="67" cy="25" r="4" fill="#2e7d32"/></g>
<rect x="38" y="4" width="26" height="15" rx="3" fill="#8be08a" stroke="{INK}" stroke-width="4"/>''',
    # Tash's Showstopper: a gold star over a shiny car
    "showstopper": f'''
<path d="M50,6 L58,24 L78,25 L62,37 L68,56 L50,45 L32,56 L38,37 L22,25 L42,24 Z" fill="#ffd23f" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
<path d="M10,82 Q14,66 30,64 L40,56 L64,56 L76,66 Q90,68 92,82 Z" fill="#e8553d" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round"/>
<path d="M44,60 L62,60 L70,66 L42,66 Z" fill="#bfe9ff"/>
<circle cx="28" cy="84" r="9" fill="{INK}"/><circle cx="74" cy="84" r="9" fill="{INK}"/>
<circle cx="28" cy="84" r="4" fill="#cfd8dc"/><circle cx="74" cy="84" r="4" fill="#cfd8dc"/>
<path d="M84,44 L88,52 M92,48 L84,50" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>''',
    # Jono's Mate's Rates: a price tag with FREE on it
    "mates_rates": f'''
<g transform="rotate(-18 52 54)">
<path d="M8,54 L30,26 L90,26 Q96,26 96,32 L96,76 Q96,82 90,82 L30,82 Z" fill="#6fd36a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<circle cx="27" cy="54" r="6" fill="#fff6cf" stroke="{INK}" stroke-width="4.5"/>
{txt(64, 64, "FREE", 22, "#ffffff", 6)}
</g>''',
    # Bec's Loyalty Card: a membership card with a heart
    "loyalty_card": f'''
<rect x="8" y="24" width="84" height="56" rx="9" fill="#b07cff" stroke="{INK}" stroke-width="6"/>
<rect x="8" y="34" width="84" height="10" fill="#7a4ad6"/>
<rect x="16" y="58" width="32" height="7" rx="3" fill="#ffffff" opacity="0.8"/>
<path d="M70,72 C56,62 54,54 60,50 C64,47 69,49 70,53 C71,49 76,47 80,50 C86,54 84,62 70,72 Z" fill="#ff6fa5" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>''',
    # v0.19t Gazza's Foam Cannon: a foam cannon blasting a big cloud of suds
    "foam_cannon": f'''
<path d="M8,70 L40,56 L46,70 L14,84 Z" fill="#ff7043" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round"/>
<rect x="18" y="78" width="10" height="16" rx="3" fill="#5d4037" stroke="{INK}" stroke-width="4.5"/>
<path d="M40,58 L54,52 L58,62 L46,68 Z" fill="#cfd8dc" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>
<circle cx="70" cy="40" r="16" fill="#ffffff" stroke="{INK}" stroke-width="5"/>
<circle cx="86" cy="22" r="10" fill="#ffffff" stroke="{INK}" stroke-width="4.5"/>
<circle cx="88" cy="56" r="9" fill="#ffffff" stroke="{INK}" stroke-width="4.5"/>
<circle cx="58" cy="18" r="8" fill="#e3f4ff" stroke="{INK}" stroke-width="4"/>
<circle cx="66" cy="34" r="5" fill="#bfe9ff"/>''',
    # Yuki's Flash Polish: a polisher pad with a lightning bolt and sparkles
    "flash_polish": f'''
<ellipse cx="44" cy="70" rx="34" ry="14" fill="#f06292" stroke="{INK}" stroke-width="5.5"/>
<rect x="30" y="44" width="28" height="22" rx="6" fill="#eceff1" stroke="{INK}" stroke-width="5"/>
<rect x="22" y="30" width="44" height="16" rx="7" fill="#455a64" stroke="{INK}" stroke-width="5"/>
<path d="M72,6 L56,40 L70,40 L60,70 L90,30 L74,30 L84,6 Z" fill="#ffd23f" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
<path d="M14,16 L18,26 L28,30 L18,34 L14,44 L10,34 L0,30 L10,26 Z" fill="#ffffff" stroke="{INK}" stroke-width="3"/>''',
    # Lukas's Training Day: a coach's whistle with an up arrow
    "training_day": f'''
<path d="M58,28 L84,10" stroke="{INK}" stroke-width="7" stroke-linecap="round"/><path d="M58,28 L84,10" stroke="#ff7043" stroke-width="3" stroke-linecap="round"/>
<circle cx="40" cy="62" r="26" fill="#1e88e5" stroke="{INK}" stroke-width="6"/>
<rect x="44" y="30" width="34" height="18" rx="5" fill="#1e88e5" stroke="{INK}" stroke-width="5.5"/>
<circle cx="40" cy="62" r="9" fill="#bbdefb" stroke="{INK}" stroke-width="4"/>
<path d="M82,92 L82,60" stroke="{INK}" stroke-width="13" stroke-linecap="round"/><path d="M82,92 L82,60" stroke="#3ccf5a" stroke-width="6" stroke-linecap="round"/>
<path d="M68,64 L82,46 L96,64 Z" fill="#3ccf5a" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>''',
    # Rosa's Referral: a speech bubble with a gold star (a happy customer sends a friend)
    "referral": f'''
<path d="M10,20 Q10,8 22,8 L80,8 Q92,8 92,20 L92,58 Q92,70 80,70 L42,70 L22,90 L26,70 L22,70 Q10,70 10,58 Z" fill="#ffffff" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<path d="M51,16 L58,31 L74,32 L61,42 L66,58 L51,49 L36,58 L41,42 L28,32 L44,31 Z" fill="#ffd23f" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M78,74 C70,68 68,62 72,59 C75,57 78,58 79,61 C80,58 84,57 86,59 C90,62 88,68 78,74 Z" fill="#ff6fa5" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''',
    # Mick's Tow Truck: a tow truck with its hook
    "tow_truck": f'''
<path d="M10,72 L10,48 L44,48 L44,72 Z" fill="#ff8a3d" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
<path d="M14,48 L20,32 L40,32 L44,48 Z" fill="#bfe9ff" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
<rect x="44" y="60" width="46" height="12" rx="3" fill="#8a94ab" stroke="{INK}" stroke-width="5"/>
<path d="M52,60 L80,22" stroke="{INK}" stroke-width="9" stroke-linecap="round"/><path d="M52,60 L80,22" stroke="#ffd23f" stroke-width="4" stroke-linecap="round"/>
<path d="M80,22 L80,40" stroke="{INK}" stroke-width="3"/>
<path d="M80,40 Q80,50 72,48" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
<circle cx="24" cy="76" r="10" fill="{INK}"/><circle cx="72" cy="76" r="10" fill="{INK}"/>
<circle cx="24" cy="76" r="4" fill="#cfd8dc"/><circle cx="72" cy="76" r="4" fill="#cfd8dc"/>''',
}


def page_html(body, vb):
    return f'''<html><head><style>@font-face{{font-family:F;src:url("file://{FONT}")}}
body{{margin:0;background:transparent}}</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="{vb}" height="{vb}" viewBox="0 0 {vb} {vb}">{body}</svg></body></html>'''


def render(pg, body, vb, path):
    tmp = os.path.abspath(path + ".html")
    with open(tmp, "w") as fh:
        fh.write(page_html(body, vb))
    pg.set_viewport_size({"width": vb, "height": vb})
    pg.goto("file://" + tmp)
    pg.evaluate("document.fonts.ready")
    pg.wait_for_timeout(60)
    pg.locator("svg").screenshot(path=path, omit_background=True)
    os.remove(tmp)


def grey_copy(src, dst, fade=0.85):
    im = Image.open(src).convert("RGBA")
    r, g, b, a = im.split()
    gr = ImageOps.grayscale(Image.merge("RGB", (r, g, b)))
    gr = gr.point(lambda v: int(70 + v * 0.62))
    out = Image.merge("RGBA", (gr, gr, gr, a.point(lambda v: int(v * fade))))
    out.save(dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 2 and sys.argv[2] == "sig":
        with sync_playwright() as p:
            b = p.chromium.launch()
            pg = b.new_page(device_scale_factor=SCALE)
            for k, body in SIG_ICONS.items():
                render(pg, body, ICON_VB, f"{OUT}/icon_{k}.png")
                grey_copy(f"{OUT}/icon_{k}.png", f"{OUT}/icon_{k}_grey.png")
            b.close()
        print("wrote", [f"icon_{k}" for k in SIG_ICONS])
        return
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=SCALE)
        for k, c in KINDS.items():
            render(pg, bubble_body(c), BUB_VB, f"{OUT}/body_{k}.png")
            render(pg, glow(c), BUB_VB, f"{OUT}/glow_{k}.png")
            render(pg, mini(c), 20, f"{OUT}/mini_{k}.png")
            render(pg, ICONS[k], ICON_VB, f"{OUT}/icon_{k}.png")
            grey_copy(f"{OUT}/icon_{k}.png", f"{OUT}/icon_{k}_grey.png")
        render(pg, bubble_body(GREY, irid=False), BUB_VB, f"{OUT}/body_grey.png")
        render(pg, shine(), BUB_VB, f"{OUT}/shine.png")
        b.close()
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
