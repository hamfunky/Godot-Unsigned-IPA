import sys; sys.path.insert(0,'/root/char')
import posh as M, detailer as D
from playwright.sync_api import sync_playwright
PEP=("#4a3a30","#2f241d","#7a6352"); GREYT="#b9bdc4"
BROWN=("#6b4226","#4a2c18","#9a6a46"); BLACK=("#1f1a17","#0f0c0a","#4a403a"); GINGER=("#c0602e","#93441c","#e8935e"); BLOND=("#e0b452","#b88a2c","#f6dc94")
ppl=[
 dict(tier=1,skin=1,hair=PEP,style="sidepart",temples=GREYT,suit=("#5a6270","#3f4652"),crew="#1e88e5",readers="#7a4a2a",iris="#3b2a1a",shoe=("#8a5530","#5e3619")),
 dict(tier=1,skin=3,hair=BLACK,style="receding",temples=GREYT,mo="handlebar",mo_col=BLACK,suit=("#6b5a48","#4c3f32"),crew="#e53935",iris="#3b2a1a",shoe=("#8a5530","#5e3619")),
 dict(tier=1,skin=0,hair=BROWN,style="lowbun",temples=GREYT,fem=True,suit=("#4d5d7a","#364358"),crew="#43a047",iris="#4a6a3a",shoe=("#8a5530","#5e3619")),
 dict(tier=0,skin=4,hair=GINGER,style="swoop",freckles=True,suit=("#8fa3b8","#6d8197"),crew="#fb8c00",iris="#3f6f9a",shoe=("#b07a45","#87582c")),
 dict(tier=0,skin=2,hair=BLACK,style="curlytop",suit=("#7d8a5e","#5e6a44"),crew="#1e88e5",iris="#3b2a1a",shoe=("#b07a45","#87582c")),
 dict(tier=0,skin=1,hair=BLOND,style="highpony",fem=True,suit=("#c08aa0","#9a6a80"),crew="#e53935",iris="#3f6f9a",shoe=("#5e3619","#3e220f")),
 dict(tier=0,skin=3,hair=BLACK,style="bob",fem=True,suit=("#9a8a74","#7a6b58"),crew="#43a047",iris="#3b2a1a",shoe=("#2a2d34","#15171c")),
]
cols=["#42a5f5"]*3+["#8bc34a"]*4
cells=""
for pose in (2,0,1,3):
  for p,c in zip(ppl,cols):
    cells+=f'<div style="display:inline-block;background:#cfe3f2;margin:3px;border:3px solid #1d1b2b;border-radius:12px">{D.svg(M.shadow(c)+M.figure(p,pose),180,262,(-110,-30,220,340))}</div>'
html=f'<html><body style="margin:0;background:#f4f7fb;width:1380px">{cells}</body></html>'
with sync_playwright() as pw:
  b=pw.chromium.launch(); pg=b.new_page(viewport={'width':1380,'height':800}); pg.set_content(html); pg.screenshot(path='/root/char/test5.png',full_page=True); b.close()
