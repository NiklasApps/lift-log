# Renders the Lift Log icon PNGs from the same geometry as brand/icon.svg.
# Usage: python make_icon.py <out_dir>
from PIL import Image, ImageDraw
import sys, os

out = sys.argv[1]
NAVY, LIME, WHITE = "#0D1B2B", "#C7F431", "#FFFFFF"
K = 4                      # supersampling factor
S = 1024 * K
STROKE = 66
PULSE = [(180, 619), (362, 619), (431, 495), (545, 704)]
ARROW = [[(545, 704), (814, 434)], [(680, 434), (814, 434), (814, 570)]]

def stroke(d, pts, color):
    pts = [(x * K, y * K) for x, y in pts]
    r = STROKE * K / 2
    d.line(pts, fill=color, width=STROKE * K, joint="curve")
    for x, y in pts:  # round caps and joins
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)

def render(radius):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=radius * K, fill=NAVY)
    stroke(d, PULSE, WHITE)
    for seg in ARROW:
        stroke(d, seg, LIME)
    return img

full = render(0)        # iOS + Android maskable: the OS rounds the corners
rounded = render(230)   # "any" purpose icons and favicons

def save(img, size, name, rgb=False):
    im = img.resize((size, size), Image.LANCZOS)
    if rgb:
        im = im.convert("RGB")
    im.save(os.path.join(out, name), optimize=True)

save(full, 180, "liftlog-icon-180.png", rgb=True)
save(full, 512, "liftlog-maskable-512.png", rgb=True)
save(rounded, 512, "liftlog-icon-512.png")
save(rounded, 1024, "liftlog-icon-1024.png")
save(rounded, 32, "favicon-32.png")
print("ok")
