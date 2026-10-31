# Redraws the app icon (art/AppIcon.swift) with Pillow for docs/assets/app-icon.png, so the README icon can be updated
# without a Mac: python3 art/readme-icon.py docs/assets/app-icon.png. Coordinates are on a 1024 canvas from the top left,
# drawn at 2x and scaled down. Keep it in step with AppIcon.swift.
import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]; pixels = int(sys.argv[2]) if len(sys.argv) > 2 else 512
SS = 2048; k = SS / 1024
yy, xx = np.mgrid[0:SS, 0:SS].astype(np.float32) / k

def rgba(rgb, a):
    arr = np.zeros((SS, SS, 4), np.float32); arr[..., :3] = rgb; arr[..., 3] = a; return arr
def over(dst, src):  # premultiplied-free "over" on float RGBA in 0..1
    sa = src[..., 3:4]; da = dst[..., 3:4]
    oa = sa + da * (1 - sa)
    oc = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    return np.concatenate([oc, oa], -1)
def mask(fn):
    m = Image.new("L", (SS, SS), 0); fn(ImageDraw.Draw(m)); return np.array(m, np.float32) / 255
def blur(a, r):
    return np.array(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r * k)), np.float32) / 255
def blur_rgba(arr, r):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(r * k))
    return np.array(img, np.float32) / 255
def turn(p): x, y = p; return (1024 - y, x)
def hem(offset=0.0, amplitude=26.0, phase=0.0):
    sx, sy, ex, ey = 820, 60, 140, 1000; dx, dy = ex - sx, ey - sy; L = math.hypot(dx, dy)
    nx, ny = dy / L, -dx / L
    return [(sx + dx * t + nx * (offset + amplitude * math.sin((t * 2.5 + phase) * 2 * math.pi)),
             sy + dy * t + ny * (offset + amplitude * math.sin((t * 2.5 + phase) * 2 * math.pi))) for t in [i / 120 for i in range(121)]]
S = lambda pts: [(x * k, y * k) for x, y in pts]

body = mask(lambda d: d.rounded_rectangle([100 * k, 100 * k, 924 * k, 924 * k], radius=185 * k, fill=255))
canvas = np.zeros((SS, SS, 4), np.float32)
canvas = over(canvas, rgba((0, 0, 0), np.roll(blur(body, 14), int(12 * k), 0) * 0.28))

# Desktop: navy at the top to sky blue at the bottom.
t = np.clip((yy - 100) / 824, 0, 1)
t = t[..., None]
navy, sky = np.array((0.07, 0.17, 0.40)), np.array((0.40, 0.76, 0.98))
layer = rgba(0, 1); layer[..., :3] = navy * (1 - t) + sky * t
# A soft glow behind the icons, so the glass has light to bend.
glow = np.clip(1 - np.hypot(xx - 690, yy - 300) / 360, 0, 1)
layer = over(layer, rgba((0.55, 0.80, 1.0), glow * 0.30))

def edge_light(x0, y0, size, peak, low, end):  # 45°, top left to bottom right, stops 0 / 0.4 / 0.6 / 1
    u = np.clip(((xx - x0) + (yy - y0)) / (2 * size), 0, 1)
    return np.interp(u, [0, 0.4, 0.6, 1], [peak, low, low, end])
# Icons: glass tiles.
tiles = mask(lambda d: [d.rounded_rectangle([(906 - (190 + r * 178)) * k, (190 + c * 178) * k, (1024 - (190 + r * 178)) * k, (308 + c * 178) * k], radius=32 * k, fill=255) for r in range(3) for c in range(3)])
rings = mask(lambda d: [d.rounded_rectangle([(906 - (190 + r * 178)) * k, (190 + c * 178) * k, (1024 - (190 + r * 178)) * k, (308 + c * 178) * k], radius=32 * k, outline=255, width=int(3 * k)) for r in range(3) for c in range(3)])
layer = over(layer, rgba((0, 0, 0), np.roll(blur(tiles, 10), int(6 * k), 0) * 0.18))
# tile light: per-tile local coordinates for the specular rim
spec = np.zeros((SS, SS), np.float32)
for r in range(3):
    for c in range(3):
        x0, y0 = 906 - (190 + r * 178), 190 + c * 178
        cx, cy = x0 + 59, y0 + 59
        sel = (xx >= x0 - 2) & (xx <= x0 + 120) & (yy >= y0 - 2) & (yy <= y0 + 120)
        s = edge_light(x0, y0, 118, 1, 0.25, 0.7)
        spec[sel] = s[sel]
face_a = tiles * (0.84 - 0.16 * np.clip((yy % 178 - 12) / 118, 0, 1))
layer = over(layer, rgba((1, 1, 1), face_a))
layer = over(layer, rgba((1, 1, 1), blur(rings, 0.6) * spec))

# Cloth: a sheet of frosted glass. What's under it shows through, blurred and whitened.
cloth_pts = [turn(p) for p in hem() + [(60, 1000), (1000, 1000), (1000, 60)]]
cloth = mask(lambda d: d.polygon(S(cloth_pts), fill=255))
layer = over(layer, rgba((0.02, 0.06, 0.18), blur(cloth, 22) * 0.30 * (1 - cloth)))  # shadow beside the hem
frost = blur_rgba(layer, 26)
tint = np.clip(((xx - 140) * 0.6 + (yy - 520) * 0.8) / 700, 0, 1)[..., None]
white = rgba(0, 1); white[..., :3] = np.array((1, 1, 1)) * (1 - tint) + np.array((0.80, 0.89, 0.99)) * tint
frosted = over(frost, rgba(white[..., :3], 0.86))
frosted[..., 3] = cloth
layer = over(layer, frosted)
# Hem: a bright specular line along the cloth's edge, and a faint one along the folds.
hem_line = mask(lambda d: d.line(S([turn(p) for p in hem(4)]), fill=255, width=int(4 * k), joint="curve"))
layer = over(layer, rgba((1, 1, 1), blur(hem_line, 0.8) * cloth * 0.95))
for off, ph in [(170, 0.12), (330, 0.3)]:  # folds
    fs = mask(lambda d: d.line(S([turn(p) for p in hem(off + 9, 22, ph)]), fill=255, width=int(5 * k), joint="curve"))
    layer = over(layer, rgba((1, 1, 1), blur(fs, 2) * cloth * 0.55))

# Body rim: thin light, strongest top left and bottom right.
rim = mask(lambda d: d.rounded_rectangle([100 * k, 100 * k, 924 * k, 924 * k], radius=185 * k, outline=255, width=int(4 * k)))
rl = edge_light(100, 100, 824, 0.98, 0.18, 0.68)
layer = over(layer, rgba((1, 1, 1), blur(rim, 0.8) * rl))

layer[..., 3] *= body
canvas = over(canvas, layer)
img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA")
img.resize((pixels, pixels), Image.LANCZOS).save(out)
