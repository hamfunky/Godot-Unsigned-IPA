import sys, base64; sys.path.insert(0,'/root/char')
import detailer as D, composite as C
from PIL import Image
from playwright.sync_api import sync_playwright
ver, title, sub = sys.argv[1], sys.argv[2], sys.argv[3]
v=D.VARIANTS["A"]
img=C.figure_png(D.figure_34(v),f'/root/char/fig34_A{ver}.png')
sm,ax,ay=C.placed(img,86)
out=Image.open('/root/shots_clean/09_late_scrolled.png').convert('RGBA')
for rt in (236,386):
    fy=rt+140; C.paste(out,sm,ax,ay,(344,fy)); C.paste(out,sm,ax,ay,(552,fy),flip=True)
out.crop((262,236,622,536)).save(f'/root/char/crop_A{ver}.png')
def b64(p): return base64.b64encode(open(p,'rb').read()).decode()
font=b64('/root/p/assets/game/fonts/fredoka_600.ttf')
w34=D.svg(D.figure_34(v),300,320,(-150,-40,320,345))
flex=D.svg(D.front_figure(v,"grin","cheer"),300,320,(-160,-40,320,345))
neu=D.svg(D.front_figure(v),300,320,(-160,-40,320,345))
face=D.svg(D.front_figure(v),320,320,(-80,45,160,160))
face34=D.svg(D.figure_34(v),320,320,(-70,45,160,160))
html=f'''<html><head><style>
@font-face{{font-family:F;src:url(data:font/ttf;base64,{font})}}
body{{margin:0;background:#f4f7fb;font-family:F,sans-serif;color:#1d1b2b;width:1340px;padding-bottom:16px}}
h1{{margin:18px 24px 4px;font-size:34px}} .sub{{margin:0 24px 10px;font-size:18px;color:#4a5568}}
.row{{display:flex;gap:10px;margin:10px 16px;align-items:flex-start}}
.cell{{display:flex;flex-direction:column;align-items:center;background:#cfe3f2;border-radius:14px;padding:6px;border:3px solid #1d1b2b;box-shadow:0 4px 0 #1d1b2b;overflow:hidden}}
.cell span{{font-size:16px;color:#2b3a4a;margin:2px 0 4px}}
.cell.game{{background:#e8eef5}}
</style></head><body>
<h1>{title}</h1><p class="sub">{sub}</p>
<div class="row"><div class="cell">{face}<span>Face, front</span></div><div class="cell">{face34}<span>Face, working angle</span></div>
<div class="cell game"><img src="data:image/png;base64,{b64(f'/root/char/crop_A{ver}.png')}" width="540"><span>Two real bays, shown at 1.5x</span></div></div>
<div class="row"><div class="cell">{w34}<span>Working (faces the car)</span></div><div class="cell">{flex}<span>Celebrate (faces you)</span></div><div class="cell">{neu}<span>Front, neutral</span></div></div>
</body></html>'''
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={'width':1340,'height':900}); pg.set_content(html); pg.wait_for_timeout(300); pg.screenshot(path=f'/root/char/detailer_prototype_v{ver}.png',full_page=True); b.close()
