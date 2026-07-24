#version 460 core
// sky.frag — volumetric storm sky.
//
// Raymarches a layer of FBM cloud density lit by the sun, over an
// atmospheric-scattering gradient, with god rays, stars and a horizon haze.
// Driven entirely by uniforms so the CPU side stays trivial.

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;      // canvas size in px
uniform float uTime;      // seconds
uniform float uPhase;     // 0..1 time of day (0 dawn, .25 noon, .5 dusk, .75 night)
uniform float uScroll;    // world scroll (parallax)
uniform float uStorm;     // 0..1 storm intensity (cloud density / darkness)
uniform float uFlash;     // 0..1 lightning flash amount

out vec4 fragColor;

const float PI = 3.14159265;

// ---- hash / noise ---------------------------------------------------------
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.80, 0.60, -0.60, 0.80);
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p = rot * p * 2.02;
        a *= 0.5;
    }
    return v;
}

// ---- palette --------------------------------------------------------------
// Sky keyframes matching the game's day/night cycle.
//
// Blended with tent weights rather than array lookups: dynamically indexing a
// local array is not allowed on all GLSL ES targets and silently fails to
// compile on some devices.
void skyColors(float ph, out vec3 top, out vec3 mid, out vec3 bot) {
    const vec3 tDawn  = vec3(0.22, 0.27, 0.42);
    const vec3 mDawn  = vec3(0.49, 0.43, 0.59);
    const vec3 bDawn  = vec3(0.85, 0.55, 0.42);
    const vec3 tDay   = vec3(0.07, 0.16, 0.24);
    const vec3 mDay   = vec3(0.11, 0.29, 0.40);
    const vec3 bDay   = vec3(0.17, 0.43, 0.56);
    const vec3 tDusk  = vec3(0.17, 0.11, 0.23);
    const vec3 mDusk  = vec3(0.48, 0.23, 0.37);
    const vec3 bDusk  = vec3(0.83, 0.42, 0.29);
    const vec3 tNight = vec3(0.03, 0.05, 0.11);
    const vec3 mNight = vec3(0.05, 0.11, 0.20);
    const vec3 bNight = vec3(0.09, 0.20, 0.29);

    float s = fract(ph) * 4.0;
    // Tent weights; the (s-4) term closes the loop from night back to dawn.
    float w0 = clamp(1.0 - abs(s - 0.0), 0.0, 1.0) + clamp(1.0 - abs(s - 4.0), 0.0, 1.0);
    float w1 = clamp(1.0 - abs(s - 1.0), 0.0, 1.0);
    float w2 = clamp(1.0 - abs(s - 2.0), 0.0, 1.0);
    float w3 = clamp(1.0 - abs(s - 3.0), 0.0, 1.0);

    top = tDawn * w0 + tDay * w1 + tDusk * w2 + tNight * w3;
    mid = mDawn * w0 + mDay * w1 + mDusk * w2 + mNight * w3;
    bot = bDawn * w0 + bDay * w1 + bDusk * w2 + bNight * w3;
}

void main() {
    vec2 fc = FlutterFragCoord().xy;
    vec2 uv = fc / uSize;
    float aspect = uSize.x / uSize.y;

    vec3 top, mid, bot;
    skyColors(uPhase, top, mid, bot);

    // Base atmosphere: three-stop vertical gradient.
    vec3 col = uv.y < 0.55
        ? mix(top, mid, uv.y / 0.55)
        : mix(mid, bot, (uv.y - 0.55) / 0.45);

    // Sun / moon position rides an arc across the sky.
    float dayness = clamp(0.5 + 0.5 * cos((uPhase - 0.25) * 2.0 * PI), 0.0, 1.0);
    vec2 sunUV = vec2(0.72, 0.16 + 0.05 * sin(uPhase * 2.0 * PI));
    vec2 d = (uv - sunUV) * vec2(aspect, 1.0);
    float sunDist = length(d);

    // Stars (night only), twinkling. Each occupied cell gets a small round
    // point — shading the whole cell would show up as square blocks.
    float night = 1.0 - dayness;
    if (night > 0.01) {
        vec2 sp = uv * vec2(aspect, 1.0) * 90.0;
        vec2 cell = floor(sp);
        vec2 f = fract(sp) - 0.5;
        float rnd = hash(cell);
        if (rnd > 0.972) {
            // Jitter the star inside its cell so the grid never reads.
            vec2 jitter = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
            float d = length(f - jitter * 0.7);
            float size = 0.06 + fract(rnd * 91.7) * 0.10;
            float tw = 0.45 + 0.55 * sin(uTime * 3.0 + rnd * 240.0);
            float pt = smoothstep(size, 0.0, d) * tw;
            col += vec3(0.85, 0.90, 1.00) * pt * night
                 * (1.0 - smoothstep(0.35, 0.8, uv.y));
        }
    }

    // Aurora — slow ribbons of light on clear-ish nights. Purely decorative,
    // but it makes the night half of the cycle something to look forward to.
    if (night > 0.25) {
        float aur = 0.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float band = 0.20 + fi * 0.075;
            // A wavering horizontal ribbon that drifts sideways over time.
            float wave = sin(uv.x * (5.0 + fi * 2.5) + uTime * (0.25 + fi * 0.12)
                             + fbm(vec2(uv.x * 3.0, uTime * 0.06)) * 3.0) * 0.045;
            float d = abs(uv.y - (band + wave));
            aur += smoothstep(0.055, 0.0, d) * (0.55 - fi * 0.13);
        }
        vec3 auroraCol = mix(vec3(0.25, 0.95, 0.65), vec3(0.45, 0.55, 1.00),
                             0.5 + 0.5 * sin(uTime * 0.2));
        col += auroraCol * aur * night * 0.45;
    }

    // Shooting stars: a rare streak that crosses the upper sky.
    if (night > 0.35) {
        float cycle = 6.0;               // one candidate every few seconds
        float idx = floor(uTime / cycle);
        float local = fract(uTime / cycle);
        float seed = hash(vec2(idx, 3.0));
        if (seed > 0.55) {               // …and only some of them appear
            vec2 start = vec2(0.15 + hash(vec2(idx, 7.0)) * 0.7, 0.06 + hash(vec2(idx, 11.0)) * 0.18);
            vec2 dir = normalize(vec2(-0.85, 0.42));
            float travel = local * 1.6;
            vec2 head = start + dir * travel;
            vec2 rel = (uv - head) * vec2(aspect, 1.0);
            // Distance to the trail behind the head.
            float along = clamp(dot(rel, -dir), 0.0, 0.14);
            float perp = length(rel + dir * along);
            float streak = smoothstep(0.006, 0.0, perp) * (1.0 - along / 0.14);
            float fade = smoothstep(0.0, 0.1, local) * smoothstep(1.0, 0.7, local);
            col += vec3(0.9, 0.95, 1.0) * streak * fade * night * 1.3;
        }
    }

    // Sun / moon disc + bloom halo.
    vec3 sunCol = mix(vec3(0.85, 0.90, 1.00), vec3(1.00, 0.93, 0.72), dayness);
    float disc = smoothstep(0.055, 0.040, sunDist);
    float halo = exp(-sunDist * 7.0) * 0.55 + exp(-sunDist * 2.2) * 0.22;
    col += sunCol * (disc * 1.4 + halo * (0.35 + 0.65 * dayness));

    // ---- volumetric clouds ------------------------------------------------
    // March a slab of FBM density; each step is lit by a cheap directional
    // transmittance estimate toward the sun.
    vec2 wind = vec2(uScroll * 0.00035 + uTime * 0.010, uTime * 0.004);
    float density = 0.0;
    float light = 0.0;
    float t = 0.0;
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        // Layers get larger and slower with depth -> parallax.
        float depth = 1.0 + fi * 0.22;
        vec2 q = vec2(uv.x * aspect, uv.y) * (1.6 * depth) + wind * (1.0 / depth) * (1.0 + fi * 0.35);
        q.y -= fi * 0.06;
        float n = fbm(q + fbm(q * 0.6 + wind * 0.5) * 0.9);
        // Confine clouds to the upper sky, fading toward the horizon.
        float band = smoothstep(0.95, 0.30, uv.y) * smoothstep(-0.05, 0.25, uv.y);
        float dsty = smoothstep(0.52 - uStorm * 0.16, 0.86, n) * band;
        density += dsty * 0.16;
        // Sun-facing edges catch light (cheap single-scatter approximation).
        float toSun = 1.0 - clamp(sunDist * 1.4, 0.0, 1.0);
        light += dsty * (0.14 + 0.5 * toSun) * (1.0 - t);
        t += dsty * 0.12;
    }
    density = clamp(density, 0.0, 1.0);

    vec3 cloudDark = mix(vec3(0.10, 0.12, 0.17), vec3(0.03, 0.04, 0.07), night);
    vec3 cloudLit = mix(vec3(0.75, 0.78, 0.86), sunCol, 0.45);
    vec3 cloud = mix(cloudDark, cloudLit, clamp(light * 1.6, 0.0, 1.0));
    col = mix(col, cloud, density * (0.55 + 0.35 * uStorm));

    // ---- god rays ---------------------------------------------------------
    // Radial blur of cloud gaps toward the sun.
    float rays = 0.0;
    vec2 dir = (sunUV - uv) * vec2(aspect, 1.0);
    for (int i = 0; i < 8; i++) {
        float s = float(i) / 8.0;
        vec2 sp = uv + dir * s * 0.85;
        vec2 q = vec2(sp.x * aspect, sp.y) * 2.6 + wind;
        float n = fbm(q);
        rays += smoothstep(0.55, 0.85, n) * (1.0 - s);
    }
    rays /= 8.0;
    float rayMask = exp(-sunDist * 2.0) * dayness;
    col += sunCol * rays * rayMask * 0.55;

    // Horizon haze grounds the scene.
    float haze = smoothstep(0.45, 1.0, uv.y);
    col = mix(col, bot * 1.05, haze * 0.35);

    // Lightning flash lifts the whole sky.
    col += vec3(0.70, 0.80, 1.00) * uFlash * 0.5;

    // Storm darkening + subtle vignette.
    col *= mix(1.0, 0.80, uStorm);

    fragColor = vec4(col, 1.0);
}
