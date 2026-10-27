import sys, base64, os
sys.path.insert(0, '/root/char')
import manager as M, detailer as D, composite as C
from PIL import Image
from playwright.sync_api import sync_playwright

TIER_COL = ["#8bc34a", "#42a5f5", "#ffb300"]
JDM, EURO, MUSCLE, OFF = "#e53935", "#1e88e5", "#fb8c00", "#43a047"

P = {
    "tony":  dict(tier=0, crew=JDM, skin=1, hair="dark", style="quiff", facial="stubble", build="stocky"),
    "mia":   dict(tier=0, crew=OFF, skin=0, hair="brown", style="bun", fem=True, build="lean", eyes=dict(lift=3.5)),
    "liam":  dict(tier=1, crew=EURO, skin=4, hair="ginger", style="sidepart", build="lean", eyes=dict(lift=3)),
    "dre":   dict(tier=0, crew=EURO, skin=3, hair="black", style="curly", facial="", build="stocky", eyes=dict(lift=2)),
    "frank": dict(tier=2, crew=MUSCLE, skin=2, hair="grey", style="sidepart", facial="mo", build="stocky", eyes=dict(lift=1.5)),
    "kenji": dict(tier=1, crew=JDM, skin=0, hair="black", style="buzz", facial="", build="stocky", eyes=dict(lift=0.5)),
    "rosa":  dict(tier=2, crew=OFF, skin=2, hair="black", style="pony", fem=True, build="lean", eyes=dict(lift=3)),
    "big":   dict(tier=1, crew=MUSCLE, skin=1, hair="dark", style="bald", facial="beard", build="stocky", eyes=dict(lift=0)),
}


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def fig_png(p, pose, name, phase=1.0):
    body = M.shadow(TIER_COL[p["tier"]], 0.55) + M.figure(p, pose, phase=phase)
    return C.figure_png(body, f'/root/char/out/{name}.png')


os.makedirs('/root/char/out', exist_ok=True)

# ---- in-game composite: 09_late_scrolled with the managers hidden, concept managers pasted in
clean = Image.open('/root/shots_clean/09_late_scrolled.png').convert('RGBA')
before = Image.open('/root/shots/09_late_scrolled.png').convert('RGBA')
lineup = [("tony", 0), ("liam", 1), ("frank", 2), ("mia", 3), ("dre", 2), ("rosa", 1)]
after = clean.copy()
for i, (who, pose) in enumerate(lineup):
    top = 236 + 150 * i   # bay 4 card top
    img = fig_png(P[who], pose, f'game_{i}')
    sm, ax, ay = C.placed(img, 92)
    C.paste(after, sm, ax, ay, (243, top + 135))
after.save('/root/char/out/after_full.png')
crop = (90, 236, 600, 836)
before.crop(crop).save('/root/char/out/before_crop.png')
after.crop(crop).save('/root/char/out/after_crop.png')

# ---- big figures
tiers = [("tony", "JUNIOR", "Crew-colour polo, droplet logo + name badge, chinos, sneakers"),
         ("liam", "SENIOR", "Pale shirt, rolled sleeves, crew tie, pen in the pocket, brown shoes"),
         ("frank", "EXECUTIVE", "Navy suit, crew tie + pocket square, gold watch, shiny shoes")]
poses = [("ARM PUMP", 0, "big"), ("ARMS CROSSED", 1, "kenji"), ("HANDS ON HIPS", 2, "rosa"), ("CLIPBOARD", 3, "mia")]


def cell(svgc, label, sub="", cls=""):
    return f'<div class="cell {cls}">{svgc}<b>{label}</b>{f"<span>{sub}</span>" if sub else ""}</div>'


VB = (-150, -50, 300, 360)
row_t = "".join(cell(D.svg(M.shadow(TIER_COL[P[w]["tier"]], 0.55) + M.figure(P[w], 2), 280, 336, VB), t, s) for w, t, s in tiers)
row_p = cell(D.svg(M.shadow(TIER_COL[1], 0.55) + M.figure(P["big"], 0, phase=0.0), 210, 252, VB), "ARM PUMP", "rest")
row_p += "".join(cell(D.svg(M.shadow(TIER_COL[P[w]["tier"]], 0.55) + M.figure(P[w], pz), 210, 252, VB), t, "pump" if pz == 0 else "") for t, pz, w in poses)
faces = ["tony", "mia", "liam", "dre", "frank", "kenji", "rosa", "big"]
row_f = ""
for w in faces:
    p = P[w]
    bg = M.lighten(p["crew"], 0.35)
    s = D.svg(f'<rect x="-120" y="0" width="240" height="400" fill="{bg}"/>' + M.figure(p, 2), 132, 132, (-82, 30, 164, 164))
    row_f += f'<div class="face" style="border-color:{TIER_COL[p["tier"]]}">{s}</div>'

font = b64('/root/p/assets/game/fonts/fredoka_600.ttf')
fontb = b64('/root/p/assets/game/fonts/fredoka_700.ttf')
html = f'''<html><head><style>
@font-face{{font-family:F;src:url(data:font/ttf;base64,{font})}}
@font-face{{font-family:FB;src:url(data:font/ttf;base64,{fontb})}}
body{{margin:0;background:#f4f7fb;font-family:F,sans-serif;color:#1d1b2b;width:1340px;padding-bottom:18px}}
h1{{margin:18px 24px 2px;font-family:FB;font-size:36px}} .sub{{margin:0 24px 6px;font-size:18px;color:#4a5568}}
h2{{margin:14px 24px 4px;font-family:FB;font-size:22px;display:inline-block;background:#1e88e5;color:#fff;padding:3px 16px;border-radius:20px;border:3px solid #1d1b2b}}
.row{{display:flex;gap:12px;margin:8px 16px;align-items:flex-start;flex-wrap:wrap}}
.cell{{display:flex;flex-direction:column;align-items:center;background:#cfe3f2;border-radius:14px;padding:6px 6px 10px;border:3px solid #1d1b2b;box-shadow:0 4px 0 #1d1b2b}}
.cell b{{font-family:FB;font-size:19px;margin-top:2px}} .cell span{{font-size:15px;color:#2b3a4a;max-width:270px;text-align:center}}
.shot{{display:flex;flex-direction:column;align-items:center;gap:4px}} .shot img{{border:3px solid #1d1b2b;border-radius:12px}}
.shot b{{font-family:FB;font-size:20px}}
.face{{width:132px;height:132px;border-radius:16px;overflow:hidden;border:5px solid;box-shadow:0 4px 0 #1d1b2b}}
</style></head><body>
<h1>Cash managers · concept v1</h1>
<p class="sub">Same look as the locked detailer (ink, outline weight, cel shading, hunter eyes, chunky build). Same 4 idle loops and the same 3 tier outfits as now, just redrawn.</p>
<h2>In the bays (real size x1.2)</h2>
<div class="row">
<div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/before_crop.png')}" width="612"><b>Now (v0.18c)</b></div>
<div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/after_crop.png')}" width="612"><b>Concept</b></div>
</div>
<h2>Tier outfits (rarity colour under their feet, as now)</h2>
<div class="row">{row_t}</div>
<h2>The 4 idle loops they already have</h2>
<div class="row">{row_p}</div>
<h2>Faces for the manager lists (mixed skin, hair, facial hair)</h2>
<div class="row">{row_f}</div>
</body></html>'''
with sync_playwright() as pw:
    b = pw.chromium.launch()
    pg = b.new_page(viewport={'width': 1340, 'height': 900})
    pg.set_content(html)
    pg.wait_for_timeout(400)
    pg.screenshot(path='/root/char/out/managers_concept_v1.png', full_page=True)
    b.close()
print("ok")
