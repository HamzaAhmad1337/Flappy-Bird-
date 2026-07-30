#!/usr/bin/env python3
"""
gen_models.py — bakes the game's 3D art.

Each game object is described as a signed-distance-field *model* and rendered
offline by tools/render3d.py with PBR shading, soft shadows and ambient
occlusion. The results are written to assets/models/ as sprite sheets and
tiling textures that the Flutter game draws at runtime.

Run:  python3 tools/gen_models.py            # everything
      python3 tools/gen_models.py bird coin  # only some targets
"""
from __future__ import annotations

import os
import sys
import time

import numpy as np
from PIL import Image

from render3d import (  # noqa: E402
    Light, Scene, fbm, length, norm, op_union, render, rot_x, rot_y, rot_z,
    sd_cone_round, sd_cyl_capped, sd_ellipsoid, sd_round_box, sd_sphere,
    sd_torus, smin, smin_mat, to_srgb8, v3, dot,
)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'models')
os.makedirs(OUT, exist_ok=True)

# Bird skins — must stay in sync with lib/game/skins.dart.
SKINS = {
    'classic': dict(body=(1.00, 0.79, 0.20), belly=(1.00, 0.90, 0.62), wing=(0.93, 0.63, 0.18), beak=(0.94, 0.38, 0.10)),
    'robin':   dict(body=(0.87, 0.29, 0.15), belly=(1.00, 0.79, 0.65), wing=(0.60, 0.13, 0.07), beak=(1.00, 0.74, 0.24)),
    'bluejay': dict(body=(0.20, 0.51, 0.90), belly=(0.85, 0.92, 1.00), wing=(0.09, 0.22, 0.52), beak=(0.94, 0.65, 0.20)),
    'mint':    dict(body=(0.20, 0.79, 0.62), belly=(0.85, 1.00, 0.94), wing=(0.09, 0.47, 0.36), beak=(1.00, 0.74, 0.24)),
    'shadow':  dict(body=(0.27, 0.23, 0.46), belly=(0.70, 0.66, 0.86), wing=(0.09, 0.06, 0.17), beak=(0.72, 0.60, 1.00)),
    'ghost':   dict(body=(0.89, 0.94, 1.00), belly=(1.00, 1.00, 1.00), wing=(0.76, 0.82, 0.90), beak=(0.65, 0.70, 0.77)),
    'phoenix': dict(body=(1.00, 0.44, 0.06), belly=(1.00, 0.74, 0.24), wing=(0.68, 0.06, 0.03), beak=(1.00, 0.93, 0.66)),
    'gold':    dict(body=(1.00, 0.76, 0.20), belly=(1.00, 0.92, 0.68), wing=(0.60, 0.40, 0.00), beak=(1.00, 0.96, 0.82)),
}

BIRD_FRAMES = 8
COIN_FRAMES = 8


# ===========================================================================
# Bird
# ===========================================================================

class BirdModel(Scene):
    """An organic bird built from smoothly-blended primitives.

    Materials: 0 back/body, 1 belly, 2 wing, 3 beak, 4 sclera, 5 pupil.
    """

    materials = [
        dict(albedo=(1, 1, 1), rough=0.55, metal=0.0),  # body
        dict(albedo=(1, 1, 1), rough=0.66, metal=0.0),  # belly
        dict(albedo=(1, 1, 1), rough=0.44, metal=0.0),  # wing
        dict(albedo=(1, 1, 1), rough=0.26, metal=0.0),  # beak
        dict(albedo=(1, 1, 1), rough=0.10, metal=0.0),  # sclera
        dict(albedo=(1, 1, 1), rough=0.06, metal=0.0),  # pupil
    ]
    rim_color = (0.13, 0.17, 0.26)

    def __init__(self, wing_angle: float):
        self.wing = wing_angle

    def sdf(self, p):
        # Torso + head blended into one egg-shaped silhouette.
        body = sd_ellipsoid(p - v3(-0.06, 0.0, 0.0), v3(1.10, 0.86, 0.80))
        head = sd_sphere(p - v3(0.56, 0.34, 0.0), 0.56)
        d = smin(body, head, 0.30)

        # Belly: pale chest/chin sweeping down and back under the tail, with a
        # feather-ragged boundary rather than a flat waterline.
        edge = -0.10 + 0.26 * p[..., 0]
        ragged = (fbm(p * 7.0, octaves=3) - 0.5) * 0.16
        m = (p[..., 1] < (edge + ragged)).astype(np.float32)

        # Tail feathers sweeping back and up, kept distinct from the torso.
        pt = rot_z(p - v3(-1.18, 0.10, 0.0), -0.95)
        tail = sd_cone_round(rot_z(pt, np.pi / 2), 0.78, 0.32, 0.03)
        d, m = smin_mat(d, m, tail, np.float32(0.0), 0.10)

        # Wing — sits proud of the torso on the near side so it reads as its
        # own shape rather than sinking into the body silhouette.
        pw = rot_z(p - v3(-0.04, 0.16, 0.90), self.wing)
        wing = sd_ellipsoid(pw - v3(-0.30, 0.0, 0.0), v3(0.80, 0.40, 0.17))
        d, m = smin_mat(d, m, wing, np.float32(2.0), 0.05)

        # Beak: a cone rotated to point along +X.
        pb = rot_z(p - v3(0.96, 0.08, 0.0), np.pi / 2)
        beak = sd_cone_round(pb, 0.66, 0.22, 0.02)
        d, m = op_union(d, m, beak, np.float32(3.0))

        # Eye.
        eye = sd_sphere(p - v3(0.74, 0.46, 0.38), 0.235)
        d, m = op_union(d, m, eye, np.float32(4.0))
        pupil = sd_sphere(p - v3(0.815, 0.455, 0.505), 0.135)
        d, m = op_union(d, m, pupil, np.float32(5.0))
        return d, m

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        # Fine feather relief. Bump-mapping the normal (rather than tinting
        # albedo) keeps the sprite fully re-colorable per skin while still
        # showing real texture through the lighting.
        mid = np.rint(mat).astype(np.int32)
        feathered = (mid == 0) | (mid == 1) | (mid == 2)

        def height(q):
            # Overlapping feather clumps, with only a hint of directional
            # banding so it doesn't read as corduroy.
            clump = fbm(q * 5.0, octaves=4)
            fine = fbm(q * 13.0, octaves=2)
            band = np.sin(q[..., 0] * 15.0 + clump * 7.0) * 0.5 + 0.5
            return clump * 0.62 + fine * 0.26 + band * 0.12

        n2 = self.bump(p, n, height, scale=0.042, eps=0.013)
        n = np.where(feathered[..., None], n2, n)
        return n, albedo, rough, metal, emissive


def render_bird():
    print('bird: raymarching %d wing frames…' % BIRD_FRAMES)
    W, H = 168, 148
    frames = []
    for i in range(BIRD_FRAMES):
        # A full flap cycle: up-stroke is faster than the glide back down.
        t = i / BIRD_FRAMES
        angle = -0.95 * np.sin(t * 2 * np.pi) ** 3 + 0.15
        t0 = time.time()
        buf = render(
            BirdModel(float(angle)), W, H,
            cam_pos=(0.75, 0.45, 5.6), cam_target=(0.02, 0.02, 0.0),
            fov=30.0, ss=3,
            lights=[
                Light((-0.45, 0.80, 0.70), (1.00, 0.95, 0.86), 1.30),
                Light((0.85, 0.10, 0.40), (0.42, 0.60, 0.92), 0.30, shadow=False),
                Light((0.30, 0.55, -0.85), (0.85, 0.93, 1.00), 0.55, shadow=False),
            ],
            ambient=(0.14, 0.17, 0.24),
        )
        frames.append(buf)
        print('   frame %d/%d  (%.1fs)' % (i + 1, BIRD_FRAMES, time.time() - t0))

    # Re-tint the shared lighting buffers into one sheet per skin.
    for skin_id, cols in SKINS.items():
        sheet = np.zeros((H, W * BIRD_FRAMES, 4), dtype=np.uint8)
        palette = [
            cols['body'], cols['belly'], cols['wing'], cols['beak'],
            (0.97, 0.98, 1.00),   # sclera
            (0.06, 0.09, 0.12),   # pupil
        ]
        for i, buf in enumerate(frames):
            albedo = np.zeros((H, W, 3), dtype=np.float32)
            for mi, c in enumerate(palette):
                albedo += buf['mat'][..., mi][..., None] * np.array(c, dtype=np.float32)
            rgb = albedo * buf['diffuse'] + buf['specular']
            sheet[:, i * W:(i + 1) * W, :3] = to_srgb8(rgb, saturation=1.35, contrast=1.08)
            sheet[:, i * W:(i + 1) * W, 3] = np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)
        path = os.path.join(OUT, f'bird_{skin_id}.png')
        Image.fromarray(sheet, 'RGBA').save(path)
        print('   wrote', os.path.relpath(path, HERE))


# ===========================================================================
# Coin
# ===========================================================================

class CoinModel(Scene):
    materials = [dict(albedo=(1.00, 0.76, 0.30), rough=0.22, metal=1.0)]

    def __init__(self, spin: float):
        self.spin = spin

    def sdf(self, p):
        q = rot_y(p, self.spin)
        # A disc lying in the XY plane (thin along Z) with a rounded rim.
        disc = sd_cyl_capped(rot_x(q, np.pi / 2), 0.13, 0.92) - 0.06
        rim = sd_torus(rot_x(q, np.pi / 2), 0.88, 0.10)
        d = smin(disc, rim, 0.06)
        return d, np.zeros(p.shape[:-1], dtype=np.float32)

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        q = rot_y(p, self.spin)

        def height(w):
            wq = rot_y(w, self.spin)
            r = length(wq[..., [0, 1]])
            # Embossed 5-point star + milled edge ridges.
            ang = np.arctan2(wq[..., 1], wq[..., 0])
            star = np.cos(ang * 5.0) * 0.5 + 0.5
            star_mask = np.clip(1.0 - r / (0.30 + 0.24 * star), 0.0, 1.0)
            ridges = (np.sin(ang * 46.0) * 0.5 + 0.5) * np.clip((r - 0.80) * 7.0, 0.0, 1.0)
            return star_mask * 0.8 + ridges * 0.35

        n = self.bump(p, n, height, scale=0.10, eps=0.010)
        # Slight polish variation so the gold isn't a perfect mirror.
        rough = rough + fbm(q * 9.0, octaves=2) * 0.10
        return n, albedo, rough, metal, emissive


def render_coin():
    print('coin: raymarching %d spin frames…' % COIN_FRAMES)
    W, H = 96, 96
    sheet = np.zeros((H, W * COIN_FRAMES, 4), dtype=np.uint8)
    for i in range(COIN_FRAMES):
        spin = (i / COIN_FRAMES) * np.pi  # half turn reads as a full spin
        buf = render(
            CoinModel(float(spin)), W, H,
            cam_pos=(0.0, 0.35, 4.6), cam_target=(0, 0, 0), fov=30.0, ss=3,
            lights=[
                Light((-0.5, 0.8, 0.7), (1.0, 0.96, 0.88), 3.6),
                Light((0.9, 0.1, 0.5), (0.5, 0.65, 0.95), 1.4, shadow=False),
                Light((0.2, 0.5, -0.9), (1.0, 0.98, 0.9), 2.6, shadow=False),
            ],
            ambient=(0.24, 0.24, 0.30),
        )
        sheet[:, i * W:(i + 1) * W, :3] = to_srgb8(buf['rgb'], saturation=1.25, contrast=1.06)
        sheet[:, i * W:(i + 1) * W, 3] = np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)
    path = os.path.join(OUT, 'coin.png')
    Image.fromarray(sheet, 'RGBA').save(path)
    print('   wrote', os.path.relpath(path, HERE))


# ===========================================================================
# Power-up orb (rendered white, tinted per type in-game)
# ===========================================================================

class OrbModel(Scene):
    materials = [dict(albedo=(1, 1, 1), rough=0.10, metal=0.15)]

    def sdf(self, p):
        d = sd_sphere(p, 0.95)
        return d, np.zeros(p.shape[:-1], dtype=np.float32)

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        def height(q):
            return fbm(q * 6.0, octaves=3)
        n = self.bump(p, n, height, scale=0.03, eps=0.012)
        return n, albedo, rough, metal, emissive


def render_orb():
    print('orb: rendering…')
    W, H = 112, 112
    buf = render(
        OrbModel(), W, H, cam_pos=(0.0, 0.25, 4.6), cam_target=(0, 0, 0),
        fov=30.0, ss=3,
        lights=[
            Light((-0.5, 0.8, 0.7), (1.0, 0.97, 0.92), 3.0),
            Light((0.9, 0.0, 0.4), (0.55, 0.7, 1.0), 1.5, shadow=False),
            Light((0.2, 0.4, -0.9), (1.0, 1.0, 1.0), 2.4, shadow=False),
        ],
        ambient=(0.30, 0.32, 0.38),
    )
    path = os.path.join(OUT, 'orb.png')
    Image.fromarray(np.dstack([to_srgb8(buf['rgb']),
                              np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)]),
                    'RGBA').save(path)
    print('   wrote', os.path.relpath(path, HERE))


# ===========================================================================
# Pipes — a weathered metal tube
# ===========================================================================

def _periodic_y(p, period):
    """Map y onto a circle so noise sampled from it tiles seamlessly."""
    a = p[..., 1] * (2 * np.pi / period)
    return np.stack([p[..., 0], np.cos(a) * (period / (2 * np.pi)),
                     np.sin(a) * (period / (2 * np.pi))], axis=-1)


class PipeBodyModel(Scene):
    """An infinite vertical cylinder; the render tiles along Y.

    TILE is both the ortho window size and the noise period, so the rendered
    strip is exactly as wide as the tube and repeats seamlessly end-to-end.
    """

    TILE = 2.0  # = cylinder diameter, and the vertical repeat period

    materials = [dict(albedo=(0.17, 0.42, 0.22), rough=0.40, metal=0.32)]
    rim_color = (0.12, 0.16, 0.24)

    def sdf(self, p):
        d = length(p[..., [0, 2]]) - 1.0
        return d, np.zeros(p.shape[:-1], dtype=np.float32)

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        def height(q):
            qq = _periodic_y(q, self.TILE)
            # Mostly irregular denting. A strong periodic term along the axis
            # reads as a screw thread once the texture repeats, so keep it faint.
            dents = fbm(qq * 2.6, octaves=4)
            fine = fbm(qq * 8.0, octaves=3)
            return dents * 0.72 + fine * 0.28

        n = self.bump(p, n, height, scale=0.05, eps=0.012)

        qq = _periodic_y(p, self.TILE)
        grunge = fbm(qq * 3.2, octaves=4)
        rust = np.clip((fbm(qq * 1.7, octaves=3) - 0.52) * 5.0, 0.0, 1.0)
        moss = np.clip((fbm(qq * 2.2 + 11.0, octaves=3) - 0.55) * 4.5, 0.0, 1.0)

        base = np.array((0.17, 0.42, 0.22), dtype=np.float32)
        dark = np.array((0.10, 0.28, 0.13), dtype=np.float32)
        rust_c = np.array((0.42, 0.20, 0.08), dtype=np.float32)
        moss_c = np.array((0.13, 0.30, 0.10), dtype=np.float32)

        a = base[None, None, :] * (0.72 + 0.55 * grunge)[..., None]
        a = a * (1 - rust[..., None]) + rust_c[None, None, :] * rust[..., None]
        a = a * (1 - moss[..., None]) + moss_c[None, None, :] * moss[..., None]
        a = a * (1 - 0.25 * (1 - grunge))[..., None] + dark[None, None, :] * 0.0

        rough = np.clip(0.30 + rust * 0.5 + moss * 0.35 - grunge * 0.10, 0.05, 1.0)
        metal = np.clip(0.55 * (1 - rust) * (1 - moss), 0.0, 1.0)
        return n, a.astype(np.float32), rough, metal, emissive


class PipeCapModel(Scene):
    """The flared lip at the mouth of a pipe."""

    materials = [dict(albedo=(0.19, 0.45, 0.24), rough=0.36, metal=0.42)]
    rim_color = (0.12, 0.16, 0.24)

    def sdf(self, p):
        d = sd_cyl_capped(p, 0.42, 1.18) - 0.07
        return d, np.zeros(p.shape[:-1], dtype=np.float32)

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        def height(q):
            return fbm(q * 4.0, octaves=4)
        n = self.bump(p, n, height, scale=0.06, eps=0.012)
        grunge = fbm(p * 4.5, octaves=4)
        rust = np.clip((fbm(p * 2.2 + 4.0, octaves=3) - 0.53) * 5.0, 0.0, 1.0)
        base = np.array((0.20, 0.47, 0.25), dtype=np.float32)
        rust_c = np.array((0.44, 0.21, 0.09), dtype=np.float32)
        a = base[None, None, :] * (0.75 + 0.5 * grunge)[..., None]
        a = a * (1 - rust[..., None]) + rust_c[None, None, :] * rust[..., None]
        rough = np.clip(0.28 + rust * 0.5, 0.05, 1.0)
        metal = np.clip(0.6 * (1 - rust), 0.0, 1.0)
        return n, a.astype(np.float32), rough, metal, emissive


def render_pipes():
    print('pipe: rendering body + cap…')
    lights = [
        Light((-0.62, 0.55, 0.60), (1.00, 0.96, 0.90), 1.35),
        Light((0.85, 0.10, 0.45), (0.40, 0.58, 0.92), 0.32, shadow=False),
        Light((0.15, 0.35, -0.92), (0.88, 0.95, 1.00), 0.55, shadow=False),
    ]
    # Body: orthographic slice, tiles vertically.
    Wb, Hb = 128, 128
    buf = render(PipeBodyModel(), Wb, Hb, cam_pos=(0, 0, 4.0), cam_target=(0, 0, 0),
                 ortho=PipeBodyModel.TILE, ss=3, lights=lights,
                 ambient=(0.13, 0.16, 0.23), shadows=False)
    # Square ortho window == tube diameter == vertical repeat period.
    img = np.dstack([to_srgb8(buf['rgb'], saturation=1.02, contrast=1.04),
                     np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)])
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, 'pipe_body.png'))
    print('   wrote assets/models/pipe_body.png')

    # Cap.
    Wc, Hc = 160, 72
    buf = render(PipeCapModel(), Wc, Hc, cam_pos=(0, 0.0, 4.0), cam_target=(0, 0, 0),
                 ortho=1.15, ss=3, lights=lights, ambient=(0.13, 0.16, 0.23))
    img = np.dstack([to_srgb8(buf['rgb'], saturation=1.02, contrast=1.04),
                     np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)])
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, 'pipe_cap.png'))
    print('   wrote assets/models/pipe_cap.png')


# ===========================================================================
# Ground — a wet rocky embankment with a grassy lip
# ===========================================================================

class GroundModel(Scene):
    # Must equal the rendered frame's world width (ortho * W/H = 3.0 * 256/96)
    # or the horizontal wrap won't line up and tiling shows a seam.
    TILE = 8.0
    materials = [dict(albedo=(0.30, 0.21, 0.13), rough=0.72, metal=0.0)]
    rim_color = (0.11, 0.14, 0.20)

    def sdf(self, p):
        d = sd_round_box(p - v3(0, -1.4, 0), v3(12.0, 1.5, 1.0), 0.18)
        return d, np.zeros(p.shape[:-1], dtype=np.float32)

    def _px(self, p):
        """Wrap x so noise tiles horizontally."""
        a = p[..., 0] * (2 * np.pi / self.TILE)
        r = self.TILE / (2 * np.pi)
        return np.stack([np.cos(a) * r, p[..., 1], np.sin(a) * r], axis=-1)

    def decorate(self, p, n, albedo, rough, metal, emissive, mat):
        def height(q):
            qq = self._px(q)
            rocks = fbm(qq * 2.2, octaves=4)
            pebbles = fbm(qq * 7.0, octaves=3)
            return rocks * 0.7 + pebbles * 0.3

        n = self.bump(p, n, height, scale=0.10, eps=0.014)

        qq = self._px(p)
        grunge = fbm(qq * 3.0, octaves=4)
        y = p[..., 1]
        # Grass occupies the top band, dirt below, with a ragged transition.
        edge = -0.30 + (fbm(qq * 6.0, octaves=3) - 0.5) * 0.26
        grass = np.clip((y - edge) * 7.0, 0.0, 1.0)

        dirt_c = np.array((0.20, 0.14, 0.09), dtype=np.float32)
        dirt_hi = np.array((0.33, 0.24, 0.15), dtype=np.float32)
        grass_c = np.array((0.15, 0.31, 0.12), dtype=np.float32)
        grass_hi = np.array((0.29, 0.47, 0.19), dtype=np.float32)

        dirt = dirt_c[None, None, :] * (1 - grunge)[..., None] + dirt_hi[None, None, :] * grunge[..., None]
        gr = grass_c[None, None, :] * (1 - grunge)[..., None] + grass_hi[None, None, :] * grunge[..., None]
        a = dirt * (1 - grass[..., None]) + gr * grass[..., None]

        # Wet sheen: smoother and shinier where it's rained on (upper faces).
        wet = np.clip(n[..., 1], 0.0, 1.0) * 0.6
        rough = np.clip(0.85 - wet * 0.55 - grunge * 0.10, 0.05, 1.0)
        return n, a.astype(np.float32), rough, metal, emissive


def render_ground():
    print('ground: rendering…')
    W, H = 256, 96
    buf = render(
        GroundModel(), W, H, cam_pos=(0, -1.25, 5.0), cam_target=(0, -1.25, 0),
        # 3.0 world units tall; the slab spans the frame edge to edge.
        ortho=3.0, ss=3,
        lights=[
            Light((-0.5, 0.75, 0.65), (1.00, 0.95, 0.88), 1.30),
            Light((0.8, 0.15, 0.45), (0.42, 0.58, 0.90), 0.30, shadow=False),
            Light((0.2, 0.4, -0.9), (0.9, 0.95, 1.0), 0.45, shadow=False),
        ],
        ambient=(0.13, 0.16, 0.22), shadows=False,
    )
    img = np.dstack([to_srgb8(buf['rgb'], saturation=1.00, contrast=1.03),
                     np.clip(buf['alpha'] * 255 + 0.5, 0, 255).astype(np.uint8)])
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, 'ground.png'))
    print('   wrote assets/models/ground.png')


TARGETS = {
    'bird': render_bird,
    'coin': render_coin,
    'orb': render_orb,
    'pipes': render_pipes,
    'ground': render_ground,
}


def main():
    want = sys.argv[1:] or list(TARGETS)
    t0 = time.time()
    for name in want:
        if name not in TARGETS:
            print('unknown target:', name)
            continue
        TARGETS[name]()
    print('all done in %.1fs' % (time.time() - t0))




# ===========================================================================
# Parallax scenery — mountain range and city skyline
# ===========================================================================
#
# These replace the flat vector silhouettes the background used to draw.
#
# They are rasterised directly from a heightfield rather than raymarched: they
# are viewed head-on and orthographically, so every pixel's surface is a pure
# function of x. Marching an SDF for that meant ~27 cone evaluations per step
# across a million rays for a shape we can evaluate once per column. Lighting,
# snow, haze and texture are still computed per pixel, so they read as rendered
# rather than flat.
#
# Both tile horizontally: the generating functions are periodic in x, so the
# left and right edges line up exactly.

SCENERY_W = 6.0  # world units across one tile


def _periodic_ridge(x, peaks, width=SCENERY_W):
    """Height of the ridge at x, summing peaks wrapped over the tile."""
    h = np.zeros_like(x)
    for cx, ph, pw in peaks:
        # Distance to the peak on a circle, so the profile wraps seamlessly.
        d = np.abs(((x - cx + width / 2) % width) - width / 2)
        # Smooth bump: cosine falloff inside the peak's radius.
        t = np.clip(1.0 - d / pw, 0.0, 1.0)
        h = np.maximum(h, ph * (t * t * (3 - 2 * t)))
    return h


def _shade_layer(mask, height, x, y, base_col, *, snow_line=None,
                 light=(-0.55, 0.72), ambient=(0.16, 0.20, 0.28)):
    """Light a heightfield silhouette. Returns (rgb, alpha) float buffers."""
    H, W = mask.shape
    # Surface normal from the slope of the ridge, with a little z curvature so
    # faces turn away toward the silhouette edge.
    dhdx = np.gradient(height, axis=1)
    nx = -dhdx
    ny = np.ones_like(nx)
    nz = np.full_like(nx, 0.55)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx * inv, ny * inv, nz * inv

    lx, ly = light
    ln = 1.0 / np.hypot(lx, ly)
    ndl = np.clip(nx * lx * ln + ny * ly * ln, 0.0, 1.0)

    # Depth into the body of the mountain -> ambient occlusion downward.
    depth = np.clip((height - y) / np.maximum(height, 1e-3), 0.0, 1.0)
    ao = 0.35 + 0.65 * (1.0 - depth) ** 0.6

    rock = np.asarray(base_col, dtype=np.float32)
    grain = fbm(np.stack([x * 3.0, y * 3.0, np.zeros_like(x)], axis=-1), octaves=4)
    col = rock[None, None, :] * (0.72 + 0.55 * grain)[..., None]

    if snow_line is not None:
        # Snow settles on upward faces above the line, with a ragged edge.
        edge = snow_line + (grain - 0.5) * 0.10
        snowy = np.clip((y - edge) * 7.0, 0.0, 1.0) * np.clip(ny, 0.0, 1.0) ** 1.5
        snow = np.asarray((0.93, 0.96, 1.00), dtype=np.float32)
        col = col * (1 - snowy[..., None]) + snow[None, None, :] * snowy[..., None]

    amb = np.asarray(ambient, dtype=np.float32)
    lit = col * (0.35 + 0.9 * ndl)[..., None] * ao[..., None] + col * amb[None, None, :]

    # Aerial perspective: wash the base out toward the sky colour.
    haze = np.clip(1.0 - depth * 1.4, 0.0, 1.0)[..., None]
    lit = lit * (1 - haze * 0.16) + amb[None, None, :] * haze * 0.28

    return lit.astype(np.float32), mask.astype(np.float32)


def render_scenery():
    print('scenery: mountains + skyline…')
    W, H = 512, 256
    ss = 3
    SW, SH = W * ss, H * ss

    # World-space grid for one tile.
    xs = np.linspace(0, SCENERY_W, SW, endpoint=False)
    ys = np.linspace(1.0, 0.0, SH)  # top of image = high
    x, y = np.meshgrid(xs, ys)

    def down(buf):
        if buf.ndim == 2:
            return buf.reshape(H, ss, W, ss).mean(axis=(1, 3))
        return buf.reshape(H, ss, W, ss, buf.shape[-1]).mean(axis=(1, 3))

    # ---- mountains ----
    # A few dominant summits with smaller shoulders between them, rather than a
    # row of same-sized scallops.
    rng = np.random.RandomState(5)
    peaks = []
    for i in range(7):
        cx = (i + rng.uniform(-0.35, 0.35)) * (SCENERY_W / 7)
        tall = rng.random() < 0.45
        # Broad bases: narrow bumps read as stalagmites, not summits.
        ph = rng.uniform(0.40, 0.60) if tall else rng.uniform(0.16, 0.32)
        pw = rng.uniform(0.70, 1.15) if tall else rng.uniform(0.55, 0.90)
        peaks.append((cx, ph, pw))

    # Peaks rise out of a continuous massif rather than off the flat.
    ring = np.stack([
        np.cos(x * (2 * np.pi / SCENERY_W)) * 1.6,
        np.sin(x * (2 * np.pi / SCENERY_W)) * 1.6,
        np.zeros_like(x),
    ], axis=-1)
    massif = 0.20 + 0.16 * fbm(ring * 1.5, octaves=3)
    height = massif + _periodic_ridge(x, peaks)
    # Break up the ridge line so edges read as rock, not a drawn curve.
    height = height * (0.92 + 0.16 * fbm(ring * 3.0, octaves=4))
    mask = y < height
    rgb, alpha = _shade_layer(mask, height, x, y, (0.20, 0.25, 0.36),
                              snow_line=0.60)
    img = np.dstack([to_srgb8(down(rgb), saturation=1.12, contrast=1.05),
                     np.clip(down(alpha) * 255 + 0.5, 0, 255).astype(np.uint8)])
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, 'mountains.png'))
    print('   wrote assets/models/mountains.png')

    # ---- skyline ----
    rng = np.random.RandomState(17)
    towers = []
    cx = 0.0
    while cx < SCENERY_W:
        w = rng.uniform(0.10, 0.26)
        h = rng.uniform(0.28, 0.85)
        towers.append((cx + w, h, w))
        cx += w * 2 + rng.uniform(0.01, 0.10)
    sky_h = np.zeros_like(x)
    for tcx, th, tw in towers:
        d = np.abs(((x - tcx + SCENERY_W / 2) % SCENERY_W) - SCENERY_W / 2)
        sky_h = np.maximum(sky_h, np.where(d < tw, th, 0.0))
    mask = y < sky_h
    rgb, alpha = _shade_layer(mask, sky_h, x, y, (0.10, 0.14, 0.21))

    # Warm windows on a grid, only on the towers themselves.
    gx = (np.sin(x * 150.0) > 0.45)
    gy = (np.sin(y * 130.0) > 0.30)
    cellrand = fbm(np.stack([np.floor(x * 24), np.floor(y * 21),
                             np.zeros_like(x)], axis=-1) * 0.9, octaves=2)
    lit = gx & gy & (cellrand > 0.47) & mask
    warm = np.asarray((1.00, 0.80, 0.45), dtype=np.float32)
    rgb = rgb + warm[None, None, :] * lit[..., None] * 0.55

    img = np.dstack([to_srgb8(down(rgb), saturation=1.10, contrast=1.06),
                     np.clip(down(alpha) * 255 + 0.5, 0, 255).astype(np.uint8)])
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, 'skyline.png'))
    print('   wrote assets/models/skyline.png')


TARGETS['scenery'] = render_scenery


if __name__ == '__main__':
    main()
