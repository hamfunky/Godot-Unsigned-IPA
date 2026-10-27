"""Bake the locked posh cash managers (compact v2, 19 Oct) into part textures for the Godot rig.

Per look (a fixed pool of people per tier):
  body        legs + shoes + neck + jacket (crew items drawn in a neutral grey)
  body_crew   only the crew-colour items (tie / waistcoat / bow tie / pocket square / socks...) in greyscale;
              the game draws it over the body with modulate = crew colour
  head, head_talk, head_blink   (head already at the compact 1.38 scale; pivot = chin)
  body_glow, head_glow          white, dilated + blurred silhouettes for the active-ability rim light
Shared: folio (clipboard), and the suds-aura layers per ability kind.
Arms + hands are drawn in code by scripts/manager_rig.gd (so they bend smoothly).
Writes <proj>/assets/game/sprites/managers/*.png and <proj>/scripts/manager_parts.gd.
"""
import sys, os, io, math, random
sys.path.insert(0, "/root/char")
import posh as M, detailer as D, aura as A
from PIL import Image, ImageFilter, ImageChops
from playwright.sync_api import sync_playwright

PROJ = sys.argv[1] if len(sys.argv) > 1 else "/root/p"
OUT = os.path.join(PROJ, "assets/game/sprites/managers")
RES = 1.5
GLOW_RES = 0.75
VB = (-140, -70, 280, 390)
KEY = "#ff00ff"
NEUTRAL = "#8a8f99"

WHITE = ("#f4f2ee", "#c9c5bd", "#ffffff"); SILVER = ("#d7dbe2", "#a9b0bb", "#ffffff")
PEP = ("#4a3a30", "#2f241d", "#7a6352"); GREYT = "#b9bdc4"
BROWN = ("#6b4226", "#4a2c18", "#9a6a46"); BLACK = ("#1f1a17", "#0f0c0a", "#4a403a")
GINGER = ("#c0602e", "#93441c", "#e8935e"); BLOND = ("#e0b452", "#b88a2c", "#f6dc94")
TAN = ("#b07a45", "#87582c"); BRN = ("#8a5530", "#5e3619"); BLK = ("#454a58", "#262a33")

LOOKS = [
    # ---- Juniors (20s): natural hair, big eyes, beaming
    dict(tier=0, skin=4, hair=GINGER, style="swoop", freckles=True, suit=("#8fa3b8", "#6d8197"), iris="#3f6f9a", shoe=TAN),
    dict(tier=0, skin=2, hair=BLACK, style="curlytop", suit=("#7d8a5e", "#5e6a44"), iris="#3b2a1a", shoe=TAN),
    dict(tier=0, skin=1, hair=BLOND, style="highpony", fem=True, suit=("#c08aa0", "#9a6a80"), iris="#3f6f9a", shoe=BRN, accent="#e53935"),
    dict(tier=0, skin=3, hair=BLACK, style="bob", fem=True, suit=("#9a8a74", "#7a6b58"), iris="#3b2a1a", shoe=BLK, accent="#43a047"),
    dict(tier=0, skin=0, hair=BROWN, style="swoop", suit=("#6f86b0", "#556b93"), iris="#4a6a3a", shoe=TAN),
    dict(tier=0, skin=0, hair=BROWN, style="bob", fem=True, suit=("#a7adb5", "#858c96"), iris="#5a3a22", shoe=BRN, accent="#1e88e5"),
    # ---- Seniors (40s-50s): greying temples, calm
    dict(tier=1, skin=1, hair=PEP, style="sidepart", temples=GREYT, readers="#7a4a2a", suit=("#5a6270", "#3f4652"), iris="#3b2a1a", shoe=BRN),
    dict(tier=1, skin=3, hair=BLACK, style="receding", temples=GREYT, mo="handlebar", mo_col=BLACK, suit=("#6b5a48", "#4c3f32"), iris="#3b2a1a", shoe=BRN),
    dict(tier=1, skin=0, hair=BROWN, style="lowbun", temples=GREYT, fem=True, suit=("#4d5d7a", "#364358"), iris="#4a6a3a", shoe=BRN),
    dict(tier=1, skin=4, hair=GINGER, style="sidepart", temples=GREYT, suit=("#4f5a6e", "#384152"), iris="#3f6f9a", shoe=BRN),
    dict(tier=1, skin=2, hair=BLACK, style="lowbun", temples=GREYT, fem=True, readers="#2a2d34", suit=("#6a4a5e", "#4c3343"), iris="#3b2a1a", shoe=BLK),
    dict(tier=1, skin=0, hair=BROWN, style="receding", temples=GREYT, mo="walrus", mo_col=BROWN, suit=("#5f6648", "#454a33"), iris="#4a6a8a", shoe=BRN),
    # ---- Executives (60s+): white / silver, snooty (locked 19 Oct)
    dict(tier=2, skin=4, hair=WHITE, style="tufts", bushy=True, brow=WHITE, mo="handlebar", suit=("#3a3550", "#28243a"), pinstripe=True),
    dict(tier=2, skin=2, hair=SILVER, style="bouffant", fem=True, suit=("#5b2a4a", "#3f1c33"), glasses="#c62828", iris="#3b2a1a"),
    dict(tier=2, skin=1, hair=WHITE, style="slick", bushy=True, brow=WHITE, mo="walrus", monocle=True, suit=("#2f4a3e", "#1f342b"), spats=True, iris="#3b2a1a"),
    dict(tier=2, skin=3, hair=SILVER, style="slick", bushy=True, brow=SILVER, mo="handlebar", suit=("#2c3f66", "#1e2c4a"), pinstripe=True, iris="#3b2a1a"),
    dict(tier=2, skin=0, hair=SILVER, style="bob", fem=True, pearls_ear=True, suit=("#2f5458", "#1f3a3d"), iris="#4a6a8a", accent="#e7b93c"),
]
IDLE_MOOD = ["beam", "smile", "smug"]
TURN = 0.75        # Hamza 19 Oct: they face their workers, not us
KINDS = ["income", "speed", "discount"]


def svg(body):
    return D.svg(body, int(VB[2]), int(VB[3]), VB)


class Baker:
    def __init__(self, pw):
        self.b = pw.chromium.launch()
        self.pg = self.b.new_page(device_scale_factor=RES, viewport={"width": int(VB[2]), "height": int(VB[3])})

    def render(self, body):
        self.pg.set_content(f'<html><body style="margin:0;background:transparent">{svg(body)}</body></html>')
        png = self.pg.locator("svg").screenshot(omit_background=True)
        return Image.open(io.BytesIO(png)).convert("RGBA")


def to_px(x, y, res=RES):
    return ((x - VB[0]) * res, (y - VB[1]) * res)


def crop_save(img, name, pivot_units, res=RES, pad=2):
    bb = img.split()[3].getbbox()
    l, t, r, b = bb
    l, t = max(0, l - pad), max(0, t - pad)
    r, b = min(img.width, r + pad), min(img.height, b + pad)
    img.crop((l, t, r, b)).save(os.path.join(OUT, name + ".png"), optimize=True)
    px, py = to_px(*pivot_units, res)
    return {"pivot": (round(px - l, 2), round(py - t, 2)), "size": (r - l, b - t), "res": res}


def glow_of(img):
    """White silhouette, dilated + blurred, at GLOW_RES."""
    a = img.split()[3]
    k = GLOW_RES / RES
    a = a.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
    a = a.point(lambda v: 255 if v > 40 else 0)
    a = a.filter(ImageFilter.MaxFilter(5))            # ~3.5 design units at 0.75 px/unit
    a = a.filter(ImageFilter.GaussianBlur(2.2))
    w = Image.new("RGBA", a.size, (255, 255, 255, 0))
    w.putalpha(a)
    return w


def crew_overlay(key_img):
    """Greyscale crew items from a render with crew = pure magenta."""
    px = key_img.load()
    w, h = key_img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            m = max(r, b)
            if m > 30 and abs(r - b) < 14 + 0.05 * m and g < 0.42 * m and m - g > 50:
                v = m
                po[x, y] = (v, v, v, a)
    return out


def head_svg(p, L, mood):
    k, cy = M.HEAD_SCALE, L["chin"]
    return f'<g transform="translate(0 {M.f(cy)}) scale({k}) translate(0 {M.f(-cy)})">{M.head(p, L, mood)}</g>'


def body_svg(p, L):
    parts = M.body(p, L)
    return parts["legs"] + parts["shoes"] + parts["neck"] + parts["torso"]


def gd_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:.2f}" if isinstance(v, float) else str(v)
    if isinstance(v, tuple) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v):
        return f"Vector2({v[0]:.2f}, {v[1]:.2f})"
    if isinstance(v, str):
        return f'"{v}"'
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd_val(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join(f'"{k}": {gd_val(x)}' for k, x in v.items()) + "}"
    raise TypeError(v)


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = {}
    looks_gd = []
    with sync_playwright() as pw:
        bk = Baker(pw)
        for i, base in enumerate(LOOKS):
            p = dict(base)
            p["crew"] = p.get("accent", "#e53935")        # hair accessories keep a fixed colour
            p["turn"] = TURN                               # turned towards their workers (the game mirrors for the valet)
            L = M.layout(p)
            n = f"m{i:02d}"
            # body: neutral crew colour for the base, magenta for the overlay
            pb = dict(p, crew=NEUTRAL)
            body = bk.render(body_svg(pb, L))
            parts[n + "_body"] = crop_save(body, n + "_body", (0, A.GROUND))
            keyimg = bk.render(body_svg(dict(p, crew=KEY), L))
            ov = crew_overlay(keyimg)
            # keep the overlay on the same crop as the body
            bb = body.split()[3].getbbox()
            l, t = max(0, bb[0] - 2), max(0, bb[1] - 2)
            r, b = min(body.width, bb[2] + 2), min(body.height, bb[3] + 2)
            ov.crop((l, t, r, b)).save(os.path.join(OUT, n + "_body_crew.png"), optimize=True)
            parts[n + "_body_crew"] = dict(parts[n + "_body"])
            g = glow_of(body)
            parts[n + "_body_glow"] = crop_save(g, n + "_body_glow", (0, A.GROUND), GLOW_RES)
            # heads
            mood = IDLE_MOOD[p["tier"]]
            hd = bk.render(head_svg(p, L, mood))
            parts[n + "_head"] = crop_save(hd, n + "_head", (0, L["chin"]))
            parts[n + "_head_talk"] = crop_save(bk.render(head_svg(p, L, "talk")), n + "_head_talk", (0, L["chin"]))
            parts[n + "_head_blink"] = crop_save(bk.render(head_svg(dict(p, blink=True), L, mood)), n + "_head_blink", (0, L["chin"]))
            parts[n + "_head_glow"] = crop_save(glow_of(hd), n + "_head_glow", (0, L["chin"]), GLOW_RES)
            SK = M.SKINS[p["skin"]]
            looks_gd.append({
                "id": n, "tier": p["tier"], "fem": bool(p.get("fem", False)),
                "skin": SK[0], "skin_shade": SK[1], "suit": p["suit"][0], "suit_shade": p["suit"][1],
                "S": float(L["S"]), "W": float(L["W"]), "sy": float(L["sy"]), "hip": float(L["hip"]), "chin": float(L["chin"]),
                "top": float(L["chin"] - L["hh"] * M.HEAD_SCALE - 12),
            })
            print(n, "ok", flush=True)
        # folio (clipboard), centred
        parts["folio"] = crop_save(bk.render(M.clipboard(0, 100, 0, 0.85)), "folio", (0, 100))
        # aura layers per kind (back): glow, core, tongue, puddle, bubble; shared: foam puff, twinkle
        h = A.GROUND - 30.0
        rng = random.Random(1)
        for kind in KINDS:
            uid = "k" + kind
            dfs = A.defs(kind, uid)
            glow = f'<path d="{A.flame_blob(0, A.GROUND + 14, 96, h + 70, 3, rng, 0.4)}" fill="url(#g{uid})" filter="url(#m{uid})"/>'
            parts[f"aura_glow_{kind}"] = crop_save(bk.render(dfs + glow), f"aura_glow_{kind}", (0, A.GROUND))
            core = f'<path d="{A.flame_blob(0, A.GROUND + 6, 72, h + 26, 4, rng, 1.3)}" fill="url(#t{uid})" filter="url(#m{uid})" opacity="0.85"/>'
            parts[f"aura_core_{kind}"] = crop_save(bk.render(dfs + core), f"aura_core_{kind}", (0, A.GROUND))
            tongue = f'<path d="{A.flame_blob(0, A.GROUND - 10, 24, h * 0.8, 2, rng, 2.0)}" fill="url(#t{uid})" filter="url(#m{uid})"/>'
            parts[f"aura_tongue_{kind}"] = crop_save(bk.render(dfs + tongue), f"aura_tongue_{kind}", (0, A.GROUND - 10))
            pud = f'<ellipse cx="0" cy="{A.GROUND}" rx="78" ry="17" fill="url(#p{uid})"/>'
            parts[f"aura_puddle_{kind}"] = crop_save(bk.render(dfs + pud), f"aura_puddle_{kind}", (0, A.GROUND))
            bub = A.bubble(0, 100, 12, uid, 1.0)
            parts[f"aura_bubble_{kind}"] = crop_save(bk.render(dfs + bub), f"aura_bubble_{kind}", (0, 100))
        puff = ('<circle cx="0" cy="100" r="10" fill="#ffffff"/><circle cx="-1.5" cy="103" r="7.5" fill="#000" opacity="0.10"/>'
                '<circle cx="-3" cy="96.5" r="2.8" fill="#ffffff"/>')
        parts["aura_puff"] = crop_save(bk.render(puff), "aura_puff", (0, 100))
        parts["aura_twinkle"] = crop_save(bk.render(A.twinkle(0, 100, 8)), "aura_twinkle", (0, 100))
        bk.b.close()
    # ---- GDScript data
    lines = ["## GENERATED by tools/char/manager_parts.py from the locked posh managers (compact v2, 19 Oct). Don't edit.",
             "## Textures: res://assets/game/sprites/managers/<name>.png. Units = design units (feet at y = GROUND).",
             "", f"const GROUND := {A.GROUND:.1f}", f"const HEAD_SCALE := {M.HEAD_SCALE}", ""]
    lines.append("const KIND_COLORS := {")
    for kind in KINDS:
        c0, c1, c2, rimc = A.KINDS[kind]
        lines.append(f'\t"{kind}": [Color("{c0}"), Color("{c1}"), Color("{c2}"), Color("{rimc}")],')
    lines.append("}\n")
    lines.append("const PARTS := {")
    for k, v in parts.items():
        lines.append(f'\t"{k}": {{"pivot": Vector2({v["pivot"][0]:.2f}, {v["pivot"][1]:.2f}), "res": {v["res"]:.2f}}},')
    lines.append("}\n")
    lines.append("## Pool of looks: tier 0 Junior, 1 Senior, 2 Executive. Skeleton numbers in design units.")
    lines.append("const LOOKS := [")
    for lk in looks_gd:
        lines.append("\t" + gd_val(lk) + ",")
    lines.append("]")
    open(os.path.join(PROJ, "scripts/manager_parts.gd"), "w").write("\n".join(lines) + "\n")
    print("done", len(parts), "parts")


if __name__ == "__main__":
    main()
