#!/usr/bin/env python3
"""Generate a 1024x1024 app icon PNG (pure stdlib: zlib+struct). Storm sky,
rain streaks, and a cute bird — matching the in-game art."""
import zlib, struct, math, os

S = 1024
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
os.makedirs(OUT_DIR, exist_ok=True)

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_col(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))

# Palette (matches lib/game/config.dart)
SKY_TOP = (0x13, 0x29, 0x3D)
SKY_MID = (0x1B, 0x49, 0x65)
SKY_BOT = (0x2C, 0x6E, 0x8F)
BIRD = (0xFF, 0xD4, 0x47)
BIRD_HI = (0xFF, 0xE4, 0x77)
BIRD_LO = (0xF0, 0xB2, 0x1F)
WING = (0xF2, 0xA9, 0x3B)
BEAK = (0xF2, 0x6A, 0x21)

cx, cy, R = S * 0.52, S * 0.54, S * 0.26

# Precompute rain streaks
import random
random.seed(7)
streaks = []
for _ in range(90):
    x = random.uniform(-100, S)
    y = random.uniform(-100, S)
    ln = random.uniform(40, 90)
    streaks.append((x, y, ln))

def sky_color(y):
    t = y / S
    if t < 0.55:
        return lerp_col(SKY_TOP, SKY_MID, t / 0.55)
    return lerp_col(SKY_MID, SKY_BOT, (t - 0.55) / 0.45)

def near_streak(x, y):
    for (sx, sy, ln) in streaks:
        # line direction (dx=-0.3, dy=1) normalized
        dx, dy = -0.28, 0.96
        # project point onto segment
        px, py = x - sx, y - sy
        proj = px * dx + py * dy
        if proj < 0 or proj > ln:
            continue
        cxp, cyp = sx + dx * proj, sy + dy * proj
        d = math.hypot(x - cxp, y - cyp)
        if d < 1.6:
            return max(0.0, 1 - d / 1.6)
    return 0.0

def bird_pixel(x, y):
    """Return (color, alpha) for bird at pixel or (None,0)."""
    dx, dy = x - cx, y - cy
    # body ellipse
    ex, ey = dx / (R * 1.12), dy / (R * 1.0)
    r2 = ex * ex + ey * ey
    if r2 <= 1.0:
        # top-lit gradient
        t = (y - (cy - R)) / (2 * R)
        t = max(0, min(1, t))
        if t < 0.5:
            col = lerp_col(BIRD_HI, BIRD, t / 0.5)
        else:
            col = lerp_col(BIRD, BIRD_LO, (t - 0.5) / 0.5)
        # belly highlight
        bdx, bdy = x - (cx - R * 0.05), y - (cy + R * 0.28)
        if (bdx / (R * 0.62)) ** 2 + (bdy / (R * 0.5)) ** 2 <= 1:
            col = lerp_col(col, (255, 233, 168), 0.5)
        return col, 1.0
    return None, 0.0

def wing_pixel(x, y):
    wx, wy = cx - R * 0.28, cy + R * 0.05
    dx, dy = x - wx, y - wy
    # rotate slightly
    ang = -0.5
    rx = dx * math.cos(ang) - dy * math.sin(ang)
    ry = dx * math.sin(ang) + dy * math.cos(ang)
    if (rx / (R * 0.7)) ** 2 + (ry / (R * 0.46)) ** 2 <= 1:
        t = (ry + R * 0.46) / (R * 0.92)
        return lerp_col(BIRD_HI, WING, max(0, min(1, t)))
    return None

def beak_pixel(x, y):
    # triangle pointing right
    x0, y0 = cx + R * 0.85, cy - R * 0.12
    x1, y1 = cx + R * 1.5, cy + R * 0.02
    x2, y2 = cx + R * 0.85, cy + R * 0.28
    def sign(ax, ay, bx, by, px, py):
        return (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d1 = sign(x0, y0, x1, y1, x, y)
    d2 = sign(x1, y1, x2, y2, x, y)
    d3 = sign(x2, y2, x0, y0, x, y)
    neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (neg and pos)

def eye_pixel(x, y):
    ex, ey = cx + R * 0.34, cy - R * 0.34
    d = math.hypot(x - ex, y - ey)
    if d <= R * 0.2:
        # iris
        ix, iy = cx + R * 0.42, cy - R * 0.34
        if math.hypot(x - ix, y - iy) <= R * 0.09:
            # shine
            if math.hypot(x - (ix + R*0.03), y - (iy - R*0.04)) <= R * 0.03:
                return (255, 255, 255)
            return (0x20, 0x30, 0x3A)
        return (255, 255, 255)
    return None

print("rendering...")
raw = bytearray()
for y in range(S):
    raw.append(0)  # filter byte per scanline
    base_sky = sky_color(y)
    for x in range(S):
        r, g, b = base_sky
        # vignette
        vig = 1 - 0.25 * (math.hypot(x - S/2, y - S/2) / (S/1.4))
        r, g, b = int(r*vig), int(g*vig), int(b*vig)

        # rain
        rn = near_streak(x, y)
        if rn > 0:
            r = int(lerp(r, 190, rn * 0.5))
            g = int(lerp(g, 220, rn * 0.5))
            b = int(lerp(b, 240, rn * 0.6))

        # bird layers (order: wing behind body edge, then body, beak, eye)
        w = wing_pixel(x, y)
        if w is not None:
            r, g, b = w
        col, a = bird_pixel(x, y)
        if a > 0:
            r, g, b = col
        if beak_pixel(x, y):
            r, g, b = BEAK
        e = eye_pixel(x, y)
        if e is not None:
            r, g, b = e

        raw.append(r & 255); raw.append(g & 255); raw.append(b & 255)
    if y % 200 == 0:
        print(f"  row {y}")

def chunk(typ, data):
    c = struct.pack(">I", len(data)) + typ + data
    crc = zlib.crc32(typ + data) & 0xffffffff
    return c + struct.pack(">I", crc)

png = b"\x89PNG\r\n\x1a\n"
ihdr = struct.pack(">IIBBBBB", S, S, 8, 2, 0, 0, 0)  # 8-bit truecolor
png += chunk(b"IHDR", ihdr)
png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
png += chunk(b"IEND", b"")

path = os.path.join(OUT_DIR, "icon.png")
with open(path, "wb") as f:
    f.write(png)
print("wrote", path, f"{len(png)/1024:.0f} KB")
