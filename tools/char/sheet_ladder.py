import sys, base64, os
sys.path.insert(0, '/root/char')
import posh as M, detailer as D, composite as C
from PIL import Image
from playwright.sync_api import sync_playwright
exec(open('/root/char/sheet_exec.py').read().split('os.makedirs')[0].split('from playwright.sync_api import sync_playwright')[1])
exec(open('/root/char/people_ladder.py').read().split('cols=')[0].split('from playwright.sync_api import sync_playwright')[1])
SEN = ppl[:3]; JUN = ppl[3:]
TC = ["#8bc34a", "#42a5f5", "#ffb300"]
os.makedirs('/root/char/out', exist_ok=True)
b64 = lambda p: base64.b64encode(open(p, 'rb').read()).decode()

clean = Image.open('/root/shots_clean/09_late_scrolled.png').convert('RGBA')
before = Image.open('/root/shots/09_late_scrolled.png').convert('RGBA')
after = clean.copy()
line = [(JUN[0], 0, 0), (SEN[0], 3, 1), (E["prof"], 2, 2), (JUN[2], 2, 0), (SEN[1], 1, 1), (JUN[1], 3, 0)]
for i, (p, pose, t) in enumerate(line):
    img = C.figure_png(M.shadow(TC[t]) + M.figure(p, pose), f'/root/char/out/lad_{i}.png')
    sm, ax, ay = C.placed(img, 94)
    C.paste(after, sm, ax, ay, (243, 236 + 150 * i + 135))
crop = (90, 236, 600, 836)
before.crop(crop).save('/root/char/out/lad_before.png')
after.crop(crop).save('/root/char/out/lad_after.png')

VB = (-110, -30, 220, 340)
def cell(svgc, label, sub="", bg="#cfe3f2"):
    return f'<div class="cell" style="background:{bg}">{svgc}<b>{label}</b>{f"<span>{sub}</span>" if sub else ""}</div>'
ladder = (cell(D.svg(M.shadow(TC[0]) + M.figure(JUN[0], 0), 270, 417, VB), "JUNIOR · 20s", "Natural hair colour. Big round eyes, huge smile, keen as. Slim suit a size too big, skinny crew tie, name badge, crew socks")
          + cell(D.svg(M.shadow(TC[1]) + M.figure(SEN[0], 2), 270, 417, VB), "SENIOR · 40s-50s", "Greying temples. Calm eyes, polite smile. Open jacket over a crew-colour waistcoat, proper tie, pocket square, brown shoes")
          + cell(D.svg(M.shadow(TC[2]) + M.figure(E["prof"], 2), 270, 417, VB), "EXECUTIVE · 60s+", "White / silver hair. Half-shut eyes, nose in the air (locked). Double-breasted, crew bow tie + pocket square"))
jr = "".join(cell(D.svg(M.shadow(TC[0]) + M.figure(p, pz), 190, 293, VB), lab) for p, pz, lab in
             [(JUN[0], 2, "HANDS ON HIPS"), (JUN[1], 0, "ARM PUMP"), (JUN[2], 1, "ARMS CROSSED"), (JUN[3], 3, "CLIPBOARD")])
sr = "".join(cell(D.svg(M.shadow(TC[1]) + M.figure(p, pz), 190, 293, VB), lab) for p, pz, lab in
             [(SEN[0], 0, "ARM PUMP"), (SEN[1], 2, "HANDS ON HIPS"), (SEN[2], 1, "ARMS CROSSED"), (SEN[0], 3, "CLIPBOARD")])
font = b64('/root/p/assets/game/fonts/fredoka_600.ttf'); fontb = b64('/root/p/assets/game/fonts/fredoka_700.ttf')
html = f'''<html><head><style>
@font-face{{font-family:F;src:url(data:font/ttf;base64,{font})}} @font-face{{font-family:FB;src:url(data:font/ttf;base64,{fontb})}}
body{{margin:0;background:#f4f7fb;font-family:F,sans-serif;color:#1d1b2b;width:1300px;padding-bottom:18px}}
h1{{margin:18px 24px 2px;font-family:FB;font-size:36px}} .sub{{margin:0 24px 6px;font-size:18px;color:#4a5568}}
h2{{margin:14px 24px 4px;font-family:FB;font-size:22px;display:inline-block;color:#1d1b2b;padding:3px 16px;border-radius:20px;border:3px solid #1d1b2b}}
.row{{display:flex;gap:12px;margin:8px 16px;align-items:flex-start;flex-wrap:wrap}}
.cell{{display:flex;flex-direction:column;align-items:center;border-radius:14px;padding:6px 6px 10px;border:3px solid #1d1b2b;box-shadow:0 4px 0 #1d1b2b}}
.cell b{{font-family:FB;font-size:19px;margin-top:2px}} .cell span{{font-size:15px;color:#2b3a4a;max-width:270px;text-align:center}}
.shot{{display:flex;flex-direction:column;align-items:center;gap:4px}} .shot img{{border:3px solid #1d1b2b;border-radius:12px}} .shot b{{font-family:FB;font-size:20px}}
</style></head><body>
<h1>Cash managers · compact v2</h1>
<p class="sub">All skinny and posh, all in suits. The rank shows in their age (hair colour first), and the snobbery climbs with it: keen Juniors, steady Seniors, snooty Executives.</p>
<h2 style="background:#ffb300">Junior → Senior → Executive</h2>
<div class="row">{ladder}</div>
<h2 style="background:#ffb300">In the bays (real size x1.2), all three mixed</h2>
<div class="row"><div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/lad_before.png')}" width="612"><b>Now</b></div>
<div class="shot"><img src="data:image/png;base64,{b64('/root/char/out/lad_after.png')}" width="612"><b>Junior · Senior · Executive · Junior</b></div></div>
<h2 style="background:#8bc34a">Juniors (full of life)</h2>
<div class="row">{jr}</div>
<h2 style="background:#42a5f5">Seniors (the middle ground)</h2>
<div class="row">{sr}</div>
</body></html>'''
with sync_playwright() as pw:
    b = pw.chromium.launch(); pg = b.new_page(viewport={'width': 1300, 'height': 900})
    pg.set_content(html); pg.wait_for_timeout(400)
    pg.screenshot(path='/root/char/out/managers_compact_v2.png', full_page=True); b.close()
print("ok")
