from PIL import Image, ImageDraw
import sys, os

out = sys.argv[1]
S = 2048  # supersampled canvas
img = Image.new("RGB", (S, S), "#1f56c8")
d = ImageDraw.Draw(img)

# subtle lighter top half for depth
d = ImageDraw.Draw(img)

W = "#ffffff"
cy = S // 2
def rr(x0, y0, x1, y1, r, fill=W):
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill)

# bar
rr(300, cy - 55, S - 300, cy + 55, 55)
# inner collars
rr(560, cy - 150, 640, cy + 150, 30)
rr(S - 640, cy - 150, S - 560, cy + 150, 30)
# big plates
rr(400, cy - 470, 540, cy + 470, 60)
rr(S - 540, cy - 470, S - 400, cy + 470, 60)
# small outer plates
rr(270, cy - 330, 380, cy + 330, 50)
rr(S - 380, cy - 330, S - 270, cy + 330, 50)

for size in (1024, 512, 180):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, f"liftlog-icon-{size}.png"), optimize=True)
print("ok")
