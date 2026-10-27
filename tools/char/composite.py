import sys
sys.path.insert(0, "/root/char")
import importlib
import detailer as D
from playwright.sync_api import sync_playwright
from PIL import Image

SCALE = 4


def figure_png(svg_body, path):
    html = f'<html><body style="margin:0;background:transparent">{D.svg(svg_body, 320, 340, (-160, -30, 320, 340))}</body></html>'
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=SCALE, viewport={"width": 320, "height": 340})
        pg.set_content(html)
        pg.locator("svg").screenshot(path=path, omit_background=True)
        b.close()
    return Image.open(path).convert("RGBA")


def placed(img, height):
    """Scale so the figure (alpha bbox top .. ground) is `height` px. Returns (image, anchor_x, anchor_y) = body centre + feet."""
    a = img.split()[3].point(lambda v: 255 if v > 20 else 0)
    bb = a.getbbox()
    ground_px = (D.GROUND + 30) * SCALE
    fig_h = ground_px - bb[1]
    k = height / fig_h
    sm = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
    ax = 160 * SCALE * k
    ay = ground_px * k
    return sm, ax, ay


def paste(base, sm, ax, ay, at, flip=False):
    if flip:
        sm = sm.transpose(Image.FLIP_LEFT_RIGHT)
        ax = sm.width - ax
    base.alpha_composite(sm, (int(round(at[0] - ax)), int(round(at[1] - ay))))


if __name__ == "__main__":
    clean = Image.open("/root/shots_clean/09_late_scrolled.png").convert("RGBA")
    for k, v in D.VARIANTS.items():
        img = figure_png(D.figure_34(v), f"/root/char/fig34_{k}.png")
        sm, ax, ay = placed(img, 86)
        out = clean.copy()
        # bay 4 row: car spans ~348..548, floor ~ y 372 (FLOOR_Y + 4 = 376)
        for row_top in (236, 386, 536, 686, 836, 986):
            fy = row_top + 136 + 4
            paste(out, sm, ax, ay, (344, fy))
            paste(out, sm, ax, ay, (552, fy), flip=True)
        out.save(f"/root/char/ingame_{k}.png")
