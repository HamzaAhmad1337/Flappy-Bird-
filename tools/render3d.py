#!/usr/bin/env python3
"""
render3d.py — a small offline 3D renderer used to bake the game's art.

This is a real raymarcher: scenes are signed-distance fields (SDFs), surfaces
are shaded with a Cook-Torrance GGX PBR model, and the result is tonemapped
with ACES and written to PNG. Because it runs offline we can afford soft
shadows, ambient occlusion and supersampling — which is what gives the sprites
their "rendered in a 3D package" look.

Everything is vectorized with numpy: one ray per pixel, all marched together.

Key idea for skinning: instead of baking final colors we output *lighting
buffers* (diffuse irradiance, specular) plus a material id per pixel. A sprite
can then be recolored for any bird skin with a cheap multiply:

    color = albedo(material) * diffuse + specular

so the expensive raymarching happens once, not once per skin.
"""
from __future__ import annotations

import numpy as np

# ---------------------------------------------------------------------------
# Small vector helpers (arrays are (...,3) float32)
# ---------------------------------------------------------------------------

def v3(x, y, z):
    return np.array([x, y, z], dtype=np.float32)


def norm(a):
    return a / (np.linalg.norm(a, axis=-1, keepdims=True) + 1e-9)


def dot(a, b):
    return np.sum(a * b, axis=-1)


def length(a):
    return np.sqrt(np.sum(a * a, axis=-1))


def rot_x(p, a):
    c, s = np.cos(a), np.sin(a)
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    return np.stack([x, c * y - s * z, s * y + c * z], axis=-1)


def rot_y(p, a):
    c, s = np.cos(a), np.sin(a)
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    return np.stack([c * x + s * z, y, -s * x + c * z], axis=-1)


def rot_z(p, a):
    c, s = np.cos(a), np.sin(a)
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    return np.stack([c * x - s * y, s * x + c * y, z], axis=-1)


# ---------------------------------------------------------------------------
# SDF primitives
# ---------------------------------------------------------------------------

def sd_sphere(p, r):
    return length(p) - r


def sd_ellipsoid(p, r):
    """Approximate (bounded) ellipsoid distance."""
    k0 = length(p / r)
    k1 = length(p / (r * r))
    return k0 * (k0 - 1.0) / (k1 + 1e-9)


def sd_round_box(p, b, r):
    q = np.abs(p) - b
    outside = length(np.maximum(q, 0.0))
    inside = np.minimum(np.max(q, axis=-1), 0.0)
    return outside + inside - r


def sd_capsule(p, a, b, r):
    pa = p - a
    ba = b - a
    h = np.clip(np.sum(pa * ba, axis=-1) / (np.dot(ba, ba) + 1e-9), 0.0, 1.0)
    return length(pa - ba * h[..., None]) - r


def sd_cone_round(p, h, r1, r2):
    """Vertical rounded cone from radius r1 (at y=0) to r2 (at y=h)."""
    q = np.stack([length(p[..., [0, 2]]), p[..., 1]], axis=-1)
    b = (r1 - r2) / (h + 1e-9)
    a = np.sqrt(max(1.0 - b * b, 1e-6))
    k = q[..., 0] * (-b) + q[..., 1] * a
    d_low = length(q) - r1
    d_high = length(q - np.array([0.0, h], dtype=np.float32)) - r2
    d_mid = q[..., 0] * a + q[..., 1] * b - r1
    return np.where(k < 0.0, d_low, np.where(k > a * h, d_high, d_mid))


def sd_torus(p, R, r):
    q = np.stack([length(p[..., [0, 2]]) - R, p[..., 1]], axis=-1)
    return length(q) - r


def sd_cyl_capped(p, h, r):
    """Cylinder along Y, half-height h, radius r."""
    d_xz = length(p[..., [0, 2]]) - r
    d_y = np.abs(p[..., 1]) - h
    inside = np.minimum(np.maximum(d_xz, d_y), 0.0)
    outside = np.sqrt(np.maximum(d_xz, 0.0) ** 2 + np.maximum(d_y, 0.0) ** 2)
    return inside + outside


def smin(a, b, k):
    """Polynomial smooth minimum — blends shapes into one organic surface."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1.0 - h)


def smin_mat(a, ma, b, mb, k):
    """Smooth min that also blends material ids by the same factor."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    d = b * (1 - h) + a * h - k * h * (1.0 - h)
    return d, np.where(h > 0.5, ma, mb)


def op_union(da, ma, db, mb):
    take_a = da < db
    return np.where(take_a, da, db), np.where(take_a, ma, mb)


# ---------------------------------------------------------------------------
# Value noise / fbm (used for surface grunge, moss, rust)
# ---------------------------------------------------------------------------

def _hash3(ix, iy, iz):
    n = ix * 374761393 + iy * 668265263 + iz * 1442695040888963407
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return (n & 0xFFFF).astype(np.float32) / 65535.0


def value_noise(p):
    """3D value noise in [0,1]."""
    pi = np.floor(p).astype(np.int64)
    pf = p - np.floor(p)
    w = pf * pf * (3.0 - 2.0 * pf)
    ix, iy, iz = pi[..., 0], pi[..., 1], pi[..., 2]
    c = {}
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                c[(dx, dy, dz)] = _hash3(ix + dx, iy + dy, iz + dz)
    wx, wy, wz = w[..., 0], w[..., 1], w[..., 2]
    x00 = c[(0, 0, 0)] * (1 - wx) + c[(1, 0, 0)] * wx
    x10 = c[(0, 1, 0)] * (1 - wx) + c[(1, 1, 0)] * wx
    x01 = c[(0, 0, 1)] * (1 - wx) + c[(1, 0, 1)] * wx
    x11 = c[(0, 1, 1)] * (1 - wx) + c[(1, 1, 1)] * wx
    y0 = x00 * (1 - wy) + x10 * wy
    y1 = x01 * (1 - wy) + x11 * wy
    return y0 * (1 - wz) + y1 * wz


def fbm(p, octaves=4, lac=2.0, gain=0.5):
    total = np.zeros(p.shape[:-1], dtype=np.float32)
    amp = 1.0
    freq = 1.0
    norm_f = 0.0
    for _ in range(octaves):
        total += amp * value_noise(p * freq)
        norm_f += amp
        amp *= gain
        freq *= lac
    return total / norm_f


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

class Scene:
    """Override `sdf` (and optionally `material`) to describe a model."""

    # Material table: id -> dict(albedo, roughness, metallic, emissive)
    materials: list[dict] = [
        dict(albedo=(1.0, 1.0, 1.0), rough=0.6, metal=0.0),
    ]
    background = (0.0, 0.0, 0.0)
    # Strength/tint of the Fresnel edge sheen. Keep this low or surfaces wash
    # out to white at grazing angles.
    rim_color = (0.16, 0.21, 0.30)

    def sdf(self, p):
        """Return (distance, material_id_float)."""
        raise NotImplementedError

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        """Optional hook: add procedural surface detail at shading time.

        Bump-mapping the normal here (rather than displacing the SDF) keeps
        marching fast while still producing rich, textured surfaces. Return the
        (possibly modified) tuple.
        """
        return n, albedo, rough, metal, emissive

    def bump(self, p, n, height_fn, scale=0.06, eps=0.01):
        """Perturb `n` by the gradient of a scalar height field."""
        h0 = height_fn(p)
        dx = height_fn(p + v3(eps, 0, 0)) - h0
        dy = height_fn(p + v3(0, eps, 0)) - h0
        dz = height_fn(p + v3(0, 0, eps)) - h0
        grad = np.stack([dx, dy, dz], axis=-1) / eps
        # Project the gradient onto the surface plane, then tilt the normal.
        grad = grad - n * dot(grad, n)[..., None]
        return norm(n - grad * scale)


def raymarch(scene, ro, rd, max_steps=96, max_dist=24.0, eps=8e-4):
    """March all rays together. Returns (t, hit_mask, material_id)."""
    t = np.zeros(rd.shape[:-1], dtype=np.float32)
    hit = np.zeros(rd.shape[:-1], dtype=bool)
    mat = np.zeros(rd.shape[:-1], dtype=np.float32)
    active = np.ones(rd.shape[:-1], dtype=bool)

    for _ in range(max_steps):
        if not active.any():
            break
        p = ro + rd * t[..., None]
        d, m = scene.sdf(p)
        d = np.where(active, d, 1e9)
        newly_hit = active & (d < eps)
        hit |= newly_hit
        mat = np.where(newly_hit, m, mat)
        active = active & ~newly_hit & (t < max_dist)
        t = t + np.where(active, np.maximum(d, eps * 0.5), 0.0)
    return t, hit, mat


def get_normal(scene, p, h=1.2e-3):
    """Gradient of the SDF via the tetrahedron trick."""
    k = np.array([[1, -1, -1], [-1, -1, 1], [-1, 1, -1], [1, 1, 1]], dtype=np.float32)
    n = np.zeros(p.shape, dtype=np.float32)
    for ki in k:
        d, _ = scene.sdf(p + ki * h)
        n += ki * d[..., None]
    return norm(n)


def soft_shadow(scene, ro, rd, k=16.0, max_steps=40, tmin=0.02, tmax=8.0):
    res = np.ones(ro.shape[:-1], dtype=np.float32)
    t = np.full(ro.shape[:-1], tmin, dtype=np.float32)
    active = np.ones(ro.shape[:-1], dtype=bool)
    for _ in range(max_steps):
        if not active.any():
            break
        p = ro + rd * t[..., None]
        d, _ = scene.sdf(p)
        d = np.maximum(d, 0.0)
        res = np.where(active, np.minimum(res, k * d / np.maximum(t, 1e-4)), res)
        t = t + np.where(active, np.clip(d, 0.01, 0.4), 0.0)
        active = active & (res > 0.005) & (t < tmax)
    return np.clip(res, 0.0, 1.0)


def ambient_occlusion(scene, p, n, samples=5, step=0.055):
    occ = np.zeros(p.shape[:-1], dtype=np.float32)
    weight = 1.0
    for i in range(1, samples + 1):
        h = step * i
        d, _ = scene.sdf(p + n * h)
        occ += (h - d) * weight
        weight *= 0.72
    return np.clip(1.0 - 1.6 * occ, 0.0, 1.0)


# ---- PBR ------------------------------------------------------------------

def ggx_specular(n, v, l, rough, f0):
    """Cook-Torrance GGX. Returns RGB specular response."""
    h = norm(v + l)
    ndl = np.clip(dot(n, l), 0.0, 1.0)
    ndv = np.clip(dot(n, v), 0.0, 1.0)
    ndh = np.clip(dot(n, h), 0.0, 1.0)
    vdh = np.clip(dot(v, h), 0.0, 1.0)

    a = np.maximum(rough * rough, 1e-3)
    a2 = a * a
    denom = ndh * ndh * (a2 - 1.0) + 1.0
    D = a2 / (np.pi * denom * denom + 1e-9)

    k = a / 2.0
    Gv = ndv / (ndv * (1 - k) + k + 1e-9)
    Gl = ndl / (ndl * (1 - k) + k + 1e-9)
    G = Gv * Gl

    F = f0 + (1.0 - f0) * np.power(1.0 - vdh, 5.0)[..., None]
    spec = (D * G / (4.0 * ndv * ndl + 1e-4))[..., None] * F
    return spec * ndl[..., None]


ACES_A, ACES_B, ACES_C, ACES_D, ACES_E = 2.51, 0.03, 2.43, 0.59, 0.14


def aces(x):
    return np.clip((x * (ACES_A * x + ACES_B)) / (x * (ACES_C * x + ACES_D) + ACES_E), 0.0, 1.0)


class Light:
    def __init__(self, direction, color, intensity, shadow=True):
        self.dir = norm(np.array(direction, dtype=np.float32))
        self.color = np.array(color, dtype=np.float32)
        self.intensity = float(intensity)
        self.shadow = shadow


def render(
    scene,
    width,
    height,
    cam_pos,
    cam_target,
    fov=28.0,
    ss=3,
    lights=None,
    ambient=(0.16, 0.20, 0.28),
    ortho=None,
    ao=True,
    shadows=True,
):
    """Render `scene`. Returns dict of float buffers at (height, width).

    Buffers: diffuse (H,W,3), specular (H,W,3), alpha (H,W), mat (H,W),
    and `rgb` — a ready-to-view composite using each material's own albedo.
    """
    W, H = width * ss, height * ss

    # --- camera ---
    cam_pos = np.array(cam_pos, dtype=np.float32)
    cam_target = np.array(cam_target, dtype=np.float32)
    fwd = norm(cam_target - cam_pos)
    right = norm(np.cross(fwd, v3(0, 1, 0)))
    up = np.cross(right, fwd)

    px = (np.arange(W, dtype=np.float32) + 0.5) / W * 2.0 - 1.0
    py = 1.0 - (np.arange(H, dtype=np.float32) + 0.5) / H * 2.0
    gx, gy = np.meshgrid(px, py)
    aspect = W / H
    gx = gx * aspect

    if ortho is not None:
        half = float(ortho) * 0.5
        ro = (cam_pos[None, None, :]
              + right[None, None, :] * (gx[..., None] * half)
              + up[None, None, :] * (gy[..., None] * half))
        rd = np.broadcast_to(fwd[None, None, :], ro.shape).copy()
    else:
        f = 1.0 / np.tan(np.radians(fov) * 0.5)
        rd = norm(fwd[None, None, :] * f
                  + right[None, None, :] * gx[..., None]
                  + up[None, None, :] * gy[..., None])
        ro = np.broadcast_to(cam_pos[None, None, :], rd.shape).copy()

    if lights is None:
        lights = [
            Light((-0.55, 0.75, 0.65), (1.0, 0.94, 0.85), 3.1),   # key (warm)
            Light((0.8, 0.15, 0.45), (0.45, 0.62, 0.9), 1.0, shadow=False),  # fill (sky)
            Light((0.25, 0.45, -0.9), (0.9, 0.95, 1.0), 1.9, shadow=False),  # rim
        ]

    t, hit, mat = raymarch(scene, ro, rd)
    p = ro + rd * t[..., None]
    n = get_normal(scene, p)
    v = -rd

    diffuse = np.zeros((H, W, 3), dtype=np.float32)
    specular = np.zeros((H, W, 3), dtype=np.float32)

    # Per-pixel material properties.
    rough = np.zeros((H, W), dtype=np.float32)
    metal = np.zeros((H, W), dtype=np.float32)
    albedo = np.zeros((H, W, 3), dtype=np.float32)
    emissive = np.zeros((H, W, 3), dtype=np.float32)
    for i, m in enumerate(scene.materials):
        sel = (np.rint(mat).astype(np.int32) == i)
        if not sel.any():
            continue
        rough[sel] = m.get('rough', 0.6)
        metal[sel] = m.get('metal', 0.0)
        albedo[sel] = np.array(m.get('albedo', (1, 1, 1)), dtype=np.float32)
        emissive[sel] = np.array(m.get('emissive', (0, 0, 0)), dtype=np.float32)

    # Procedural surface detail (bump mapping, rust/moss variation, …).
    n, albedo, rough, metal, emissive = scene.decorate(
        p, n, albedo, rough, metal, emissive, mat)

    occ = ambient_occlusion(scene, p, n) if ao else np.ones((H, W), dtype=np.float32)

    f0 = 0.04 * (1.0 - metal)[..., None] + albedo * metal[..., None]

    for lt in lights:
        ldir = np.broadcast_to(lt.dir[None, None, :], p.shape)
        ndl = np.clip(dot(n, ldir), 0.0, 1.0)
        sh = np.ones_like(ndl)
        if shadows and lt.shadow:
            sh = soft_shadow(scene, p + n * 0.02, ldir)
        radiance = lt.color * lt.intensity
        contrib = (ndl * sh)[..., None] * radiance
        diffuse += contrib * (1.0 - metal)[..., None]
        specular += ggx_specular(n, v, ldir, rough, f0) * radiance * sh[..., None]

    # Hemispheric ambient (sky above, ground bounce below) modulated by AO.
    sky = np.array(ambient, dtype=np.float32)
    ground_bounce = np.array((0.14, 0.11, 0.09), dtype=np.float32)
    hemi = 0.5 + 0.5 * n[..., 1]
    amb = sky[None, None, :] * hemi[..., None] + ground_bounce[None, None, :] * (1 - hemi)[..., None]
    diffuse += amb * occ[..., None]

    # Fresnel rim boost — the subtle edge glow that reads as "cinematic".
    fres = np.power(1.0 - np.clip(dot(n, v), 0.0, 1.0), 5.0)
    specular += (fres * occ)[..., None] * np.array(scene.rim_color, dtype=np.float32)

    diffuse *= occ[..., None]
    specular *= occ[..., None]

    rgb = albedo * diffuse + specular + emissive
    alpha = hit.astype(np.float32)

    def down(buf):
        if ss == 1:
            return buf
        if buf.ndim == 2:
            return buf.reshape(height, ss, width, ss).mean(axis=(1, 3))
        return buf.reshape(height, ss, width, ss, buf.shape[-1]).mean(axis=(1, 3))

    return dict(
        diffuse=down(diffuse),
        specular=down(specular),
        rgb=down(rgb),
        alpha=down(alpha),
        mat=down(np.stack([(np.rint(mat) == i).astype(np.float32)
                           for i in range(len(scene.materials))], axis=-1)),
    )


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def to_srgb8(lin, exposure=1.0, saturation=1.0, contrast=1.0):
    """ACES tonemap + optional grade + gamma encode -> uint8.

    ACES intentionally desaturates bright values; for stylised game sprites a
    little saturation back is usually wanted, hence the grade controls.
    """
    x = aces(np.maximum(lin, 0.0) * exposure)
    if saturation != 1.0:
        lum = np.sum(x * LUMA, axis=-1, keepdims=True)
        x = np.clip(lum + (x - lum) * saturation, 0.0, 1.0)
    if contrast != 1.0:
        x = np.clip((x - 0.5) * contrast + 0.5, 0.0, 1.0)
    x = np.power(np.clip(x, 0.0, 1.0), 1.0 / 2.2)
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def save_rgba(path, rgb_lin, alpha):
    from PIL import Image
    rgb = to_srgb8(rgb_lin)
    a = np.clip(alpha * 255.0 + 0.5, 0, 255).astype(np.uint8)
    img = np.dstack([rgb, a])
    Image.fromarray(img, 'RGBA').save(path)
    return path
