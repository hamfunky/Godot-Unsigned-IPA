import sys, base64, os
sys.path.insert(0, '/root/char')
import posh as M, detailer as D, composite as C
from PIL import Image
from playwright.sync_api import sync_playwright

GOLD = "#ffb300"
WHITE = ("#f4f2ee", "#c9c5bd", "#ffffff"); SILVER = ("#d7dbe2", "#a9b0bb", "#ffffff")
E = {
    "prof":  dict(skin=4, hair=WHITE, style="tufts", bushy=True, brow=WHITE, mo="handlebar", suit=("#3a3550", "#28243a"), pinstripe=True, crew="#e53935"),
    "dame":  dict(skin=2, hair=SILVER, style="bouffant", fem=True, suit=("#5b2a4a", "#3f1c33"), crew="#43a047", glasses="#c62828", iris="#3b2a1a"),
    "count": dict(skin=1, hair=WHITE, style="slick", bushy=True, brow=WHITE, mo="walrus", monocle=True, suit=("#2f4a3e", "#1f342b"), crew="#fb8c00", spats=True, iris="#3b2a1a"),
    "baron": dict(skin=3, hair=SILVER, style="slick", bushy=True, brow=SILVER, mo="handlebar", suit=("#2c3f66", "#1e2c4a"), pinstripe=True, crew="#1e88e5", iris="#3b2a1a"),
}
os.makedirs('/root/char/out', exist_ok=True)
b64 = lambda p: base64.b64encode(open(p, 'rb').read()).decode()

clean = Image.open('/root/shots_clean/09_late_scrolled.png').convert('RGBA')
before = Image.open('/root/shots/09_late_scrolled.png').convert('RGBA')
after = clean.copy()
for i, (who, pose) in enumerate([("prof", 2), ("dame", 1), ("count", 3), ("baron", 0)]):
    img = C.figure_png(M.shadow(GOLD) + M.figure(E[who], pose), f'/root/char/out/ex_{i}.png')
    sm, ax, ay = C.placed(img, 94)
    C.paste(after, sm, ax, ay, (243, 236 + 150 * i + 135))
crop = (90, 236, 600, 836)
before.crop(crop).save('/root/char/out/ex_before.png')
after.crop(crop).save('/root/char/out/ex_after.png')

VB = (-110, -10, 220, 320)
def cell(svgc, label, sub=""):
    return f'<div class="cell">{svgc}<b>{label}</b>{f"<span>{sub}</span>" if sub else ""}</div>'
big = [("prof", "THE PROFESSOR", "Bald dome, wild white tufts, handlebar moustache, pinstripe double-breasted, crew bow tie"),
       ("dame", "THE DAME", "Silver bouffant, red cat-eye glasses, pearls, skirt suit, crew pocket square, little heels"),
       ("count", "THE COUNT", "Slicked white hair, monocle on a gold chain, walrus moustache, spats")]
row_big = "".join(cell(D.svg(M.shadow(GOLD) + M.figure(E[w], 2), 300, 436, VB), t, s) for w, t, s in big)
loops = [(0, 0.0, "ARM PUMP", "rest"), (0, 1.0, "ARM PUMP", "pump"), (1, 1, "ARMS CROSSED", ""), (2, 1, "HANDS ON HIPS", ""), (3, 1, "CLIPBOARD", "leather folio + fountain pen")]
row_l = "".join(cell(D.svg(M.shadow(GOLD) + M.figure(E["prof"], pz, phase=ph), 190, 276, VB), t, s) for pz, ph, t, s in loops)

font = b64('/root/p/assets/game/fonts/fredoka_600.ttf'); fontb = b64('/root/p/assets/game/fonts/fredoka_700.ttf')
html = f'''<html><head><style>
@font-face{{font-family:F;src:url(data:font/ttf;base64,{font})}} @font-face{{font-family:FB;src:url(data:font/ttf;base64,{fontb})}}
body{{margin:0;background:#f4f7fb;font-family:F,sans-serif;color:#1d1b2b;width:1300px;padding-bottom:18px}}
h1{{margin:18px 24px 2px;font-family:FB;font-size:36px}} .sub{{margin:0 24px 6px;font-size:18px;color:#4a5568}}
h2{{margin:14px 24px 4px;font-family:FB;font-size:22px;display:inline-block;background:#ffb300;color:#1d1b2b;padding:3px 16px;border-radius:20px;border:3px solid #1d1b2b}}
.row{{display:flex;gap:12px;margin:8px 16px;align-items:flex-start;flex-wrap:wrap}}
.cell{{display:flex;flex-direction:column;align-items:center;background:#cfe3f2;border-radius:14px;padding:6px 6px 10px;border:3px solid #1d1b2b;box-shadow:0 4px 0 #1d1b2b}}
.cell b{{font-family:FB;font-size:19px;margin-top:2px}} .cell span{{font-size:15px;color:#2b3a4a;max-width:290px;text-align:center}}
.shot{{display:flex;flex-direction:column;align-items:center;gap:4px}} .shot img{{border:3px solid #1d1b2b;border-radius:12px}} .shot b{{font-family:FB;font-size:20px}}
</style></head><body>
<h1>Executive managers · prototype v1</h1>
<p class="sub">Skinny, posh, old (white / silver hair = Executive). Cartoon theme shared with the detailers, nothing else. Crew colour on the bow tie + pocket square, gold rarity glow under their feet.</p>
<h2>In the bays (real size x1.2)</h2>
<div class="row"><div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/ex_before.png')}" width="612"><b>Now</b></div>
<div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/ex_after.png')}" width="612"><b>Prototype</b></div></div>
<h2>Three Executives (they'd be dealt from a pool of looks like this)</h2>
<div class="row">{row_big}</div>
<h2>The idle loops they already have</h2>
<div class="row">{row_l}</div>
</body></html>'''
with sync_playwright() as pw:
    b = pw.chromium.launch(); pg = b.new_page(viewport={'width': 1300, 'height': 900})
    pg.set_content(html); pg.wait_for_timeout(400)
    pg.screenshot(path='/root/char/out/executive_prototype_v1.png', full_page=True); b.close()
print("ok")
