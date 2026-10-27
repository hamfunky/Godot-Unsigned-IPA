import sys, base64
sys.path.insert(0, '/root/char')
import posh as M, detailer as D, aura as A
from PIL import Image
from playwright.sync_api import sync_playwright
exec(open('/root/char/sheet_exec.py').read().split('os.makedirs')[0].split('from playwright.sync_api import sync_playwright')[1])
exec(open('/root/char/people_ladder.py').read().split('cols=')[0].split('from playwright.sync_api import sync_playwright')[1])
SEN = ppl[:3]; JUN = ppl[3:]
TC = ["#8bc34a", "#42a5f5", "#ffb300"]
VB = (-160, -90, 320, 400); SC = 4
TOP = 30.0

def active(p, pose, t, kind, uid):
    fig = M.figure(p, pose)
    return (A.defs(kind, uid) + A.aura_back(kind, uid, TOP) + M.shadow(TC[t], 0.35) + A.wrap_rim(fig, uid) + fig + A.aura_front(kind, uid, TOP))

def png(svgbody, path, pw):
    html = f'<html><body style="margin:0;background:transparent">{D.svg(svgbody, VB[2], VB[3], VB)}</body></html>'
    pg = pw.new_page(device_scale_factor=SC, viewport={"width": VB[2], "height": VB[3]})
    pg.set_content(html); pg.locator("svg").screenshot(path=path, omit_background=True); pg.close()
    return Image.open(path).convert("RGBA")

clean = Image.open('/root/shots_clean/09_late_scrolled.png').convert('RGBA')
line = [(JUN[0], 2, 0, "income"), (SEN[0], 1, 1, None), (E["prof"], 2, 2, "speed"), (JUN[2], 1, 0, "discount")]
with sync_playwright() as pw:
    br = pw.chromium.launch()
    out = clean.copy()
    for i, (p, pose, t, kind) in enumerate(line):
        plain = png(M.shadow(TC[t]) + M.figure(p, pose), f'/root/char/out/au_p{i}.png', br)
        bb = plain.split()[3].point(lambda v: 255 if v > 20 else 0).getbbox()
        gpx = (A.GROUND - VB[1]) * SC
        k = 94 / (gpx - bb[1])
        img = png(active(p, pose, t, kind, f"u{i}") if kind else M.shadow(TC[t]) + M.figure(p, pose), f'/root/char/out/au_a{i}.png', br)
        sm = img.resize((int(img.width * k), int(img.height * k)), Image.LANCZOS)
        ax, ay = -VB[0] * SC * k, gpx * k
        fy = 236 + 150 * i + 135
        out.alpha_composite(sm, (int(243 - ax), int(fy - ay)))
    out.crop((90, 236, 600, 836)).save('/root/char/out/au_game.png')
    b64 = lambda q: base64.b64encode(open(q, 'rb').read()).decode()
    big = ""
    for (p, pose, t, kind, lab) in ((JUN[0], 2, 0, "income", "INCOME"), (SEN[0], 2, 1, "speed", "SPEED"), (E["prof"], 2, 2, "discount", "DISCOUNT")):
        big += f'<div class="cell" style="background:#bfe0f5">{D.svg(active(p, pose, t, kind, "B"+lab), 340, 425, VB)}<b>{lab}</b></div>'
    font = b64('/root/p/assets/game/fonts/fredoka_700.ttf')
    html = f'''<html><head><style>@font-face{{font-family:FB;src:url(data:font/ttf;base64,{font})}}
body{{margin:0;background:#f4f7fb;font-family:FB,sans-serif;color:#1d1b2b;width:1120px;padding-bottom:14px}}
h1{{margin:16px 20px 2px;font-size:32px}} p{{margin:0 20px 8px;font-size:17px;color:#4a5568;font-family:sans-serif}}
.row{{display:flex;gap:12px;margin:8px 14px;align-items:flex-start}}
.cell{{display:flex;flex-direction:column;align-items:center;border-radius:14px;padding:6px;border:3px solid #1d1b2b;box-shadow:0 4px 0 #1d1b2b}}
.cell b{{font-size:20px}} img{{border:3px solid #1d1b2b;border-radius:12px}}</style></head><body>
<h1>Manager active effect · "suds aura" (still, before animating)</h1>
<p>Soft rounded glow + rising tongues, glowing suds ring at the feet, soap bubbles, twinkles, coloured rim around the manager. Colour = ability.</p>
<div class="row">{big}</div>
<h1 style="font-size:24px">In the bays (real size x1.2): income · idle · speed · discount</h1>
<div class="row"><img src="data:image/png;base64,{b64('/root/char/out/au_game.png')}" width="612"></div>
</body></html>'''
    pg = br.new_page(viewport={'width': 1120, 'height': 900}); pg.set_content(html); pg.wait_for_timeout(400)
    pg.screenshot(path='/root/char/out/manager_aura_v1.png', full_page=True); br.close()
print("ok")
