#version 460 core
// lens.frag — full-screen "camera lens" pass drawn over the scene.
//
// Rain beading and running down the glass, a cinematic vignette, subtle
// chromatic fringing at the edges, film grain and a lightning bloom. This is
// an additive/soft overlay so it needs no copy of the framebuffer, which keeps
// it cheap enough for 60fps on a phone.

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uTime;
uniform float uIntensity;  // 0..1 master wetness
uniform float uFlash;      // lightning
uniform float uSpeed;      // world speed -> streak length

out vec4 fragColor;

float hash21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float n = hash21(p);
    return vec2(n, hash21(p + n));
}

// A layer of droplets on a jittered grid.
// Returns (mask, height, surfaceDir.xy). The direction from the droplet centre
// doubles as the surface gradient, so we avoid dFdx/dFdy (not available in
// Flutter's fragment-shader subset).
vec4 droplets(vec2 uv, float scale, float seed, float t) {
    vec2 g = uv * scale + vec2(seed * 13.7, seed * 7.1);
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;

    float best = 1e9;
    float bestR = 1.0;
    vec2 bestDir = vec2(0.0, -1.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y));
            vec2 rnd = hash22(id + o + seed);
            // Only some cells hold a droplet; they drift slowly downward.
            if (rnd.x < 0.55) continue;
            float slip = fract(rnd.y + t * (0.05 + rnd.x * 0.12));
            vec2 pos = o + vec2(rnd.x - 0.5, slip - 0.5) * 0.8;
            vec2 rel = f - pos;
            float rad = 0.055 + rnd.y * 0.10;
            float d = length(rel) - rad;
            if (d < best) {
                best = d;
                bestR = rad;
                bestDir = rel / (length(rel) + 1e-5);
            }
        }
    }
    float mask = smoothstep(0.02, -0.02, best);
    float height = clamp(-best / max(bestR, 1e-3), 0.0, 1.0);
    return vec4(mask, height, bestDir);
}

void main() {
    vec2 fc = FlutterFragCoord().xy;
    vec2 uv = fc / uSize;
    float aspect = uSize.x / uSize.y;
    vec2 auv = vec2(uv.x * aspect, uv.y);

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // ---- rain on the lens -------------------------------------------------
    vec4 dA = droplets(auv, 26.0, 1.0, uTime);
    vec4 dB = droplets(auv, 41.0, 2.0, uTime * 1.3);
    // Keep whichever layer's droplet is in front at this pixel.
    vec4 drops = (dA.x >= dB.x) ? dA : dB;
    float mask = drops.x;
    float h = drops.y;

    if (mask > 0.001) {
        // Fake refraction: bright crescent on the lit side, dark on the other.
        float lit = clamp(dot(drops.zw, normalize(vec2(-0.6, -0.8))), -1.0, 1.0);
        float rim = smoothstep(0.35, 1.0, h);
        vec3 drop = vec3(0.70, 0.82, 0.95) * (0.20 + 0.60 * max(lit, 0.0));
        drop += vec3(1.0) * pow(rim, 6.0) * 0.45;             // specular pop
        col += drop * mask;
        alpha = max(alpha, mask * (0.10 + 0.16 * rim) * uIntensity);
    }

    // ---- vertical streaks (water running with the wind) -------------------
    float streak = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 sp = auv * vec2(38.0 + fi * 20.0, 2.2 + fi * 1.1);
        sp.y += uTime * (0.55 + fi * 0.35) * (0.6 + uSpeed * 0.0018);
        float n = hash21(floor(sp));
        streak += smoothstep(0.986, 1.0, n) * 0.5;
    }
    col += vec3(0.62, 0.76, 0.92) * streak;
    alpha = max(alpha, streak * 0.18 * uIntensity);

    // ---- chromatic fringe at the frame edges ------------------------------
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    float fringe = smoothstep(0.42, 0.85, r);
    col += vec3(0.10, 0.0, -0.06) * fringe * 0.55;
    alpha = max(alpha, fringe * 0.10);

    // ---- lightning bloom --------------------------------------------------
    if (uFlash > 0.001) {
        col += vec3(0.78, 0.86, 1.00) * uFlash;
        alpha = max(alpha, uFlash * 0.55);
    }

    // ---- film grain -------------------------------------------------------
    float grain = hash21(fc + fract(uTime) * 431.0) - 0.5;
    col += grain * 0.05;
    alpha = max(alpha, abs(grain) * 0.06);

    // ---- vignette (darkens corners; drawn as a dark overlay) --------------
    float vig = smoothstep(0.35, 1.05, r);
    // Composite: the vignette needs to *darken*, so bias the color down and
    // raise alpha where it bites.
    col = mix(col, col * 0.10, vig);
    alpha = max(alpha, vig * 0.38);

    fragColor = vec4(col * alpha, alpha);
}
