#!/usr/bin/env python3
"""Procedurally synthesize the game's sound effects as 16-bit mono WAV files.
Pure standard library (wave, struct, math, random). Warm, arcade-y tones."""
import wave, struct, math, random, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)

def env_exp(n, i, decay=5.0):
    return math.exp(-decay * (i / n))

def adsr(n, i, a=0.01, d=0.1, s=0.6, r=0.2):
    t = i / n
    at, dt, rt = a, d, r
    if t < at:
        return t / at
    if t < at + dt:
        return 1 - (1 - s) * ((t - at) / dt)
    if t < 1 - rt:
        return s
    return s * (1 - (t - (1 - rt)) / rt)

def write(name, samples, amp=0.9):
    # normalize
    peak = max(1e-6, max(abs(x) for x in samples))
    scale = amp / peak
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in samples:
            v = int(max(-1, min(1, x * scale)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path, f"{len(samples)/SR*1000:.0f}ms")

def tone(freq, dur, wave_fn=math.sin, vibrato=0.0, vfreq=6.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1 + vibrato * math.sin(2 * math.pi * vfreq * t))
        out.append(wave_fn(2 * math.pi * f * t))
    return out

def sweep(f0, f1, dur, wave_fn=math.sin):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        out.append(wave_fn(phase))
    return out

def square(x):
    return 1.0 if math.sin(x) >= 0 else -1.0

def tri(x):
    return 2 / math.pi * math.asin(math.sin(x))

def noise(dur):
    n = int(SR * dur)
    return [random.uniform(-1, 1) for _ in range(n)]

def mix(*sigs):
    m = max(len(s) for s in sigs)
    out = [0.0] * m
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out

def apply_env(sig, env_fn):
    n = len(sig)
    return [v * env_fn(n, i) for i, v in enumerate(sig)]

# ---- flap: quick airy blip sweep up -------------------------------------
def make_flap():
    body = sweep(420, 900, 0.11, tri)
    body = [v * env_exp(len(body), i, 6) for i, v in enumerate(body)]
    air = apply_env(noise(0.09), lambda n, i: env_exp(n, i, 9) * 0.3)
    sig = mix(body, air)
    write("flap.wav", sig, 0.75)

# ---- score: bright two-note ding ----------------------------------------
def make_score():
    a = tone(880, 0.09, tri)
    a = [v * env_exp(len(a), i, 5) for i, v in enumerate(a)]
    b = tone(1318, 0.16, tri)  # E6
    b = [v * env_exp(len(b), i, 4) for i, v in enumerate(b)]
    sig = a + b
    write("score.wav", sig, 0.7)

# ---- coin: sparkly arpeggio ---------------------------------------------
def make_coin():
    notes = [1046, 1318, 1568, 2093]  # C6 E6 G6 C7
    sig = []
    for f in notes:
        seg = tone(f, 0.05, tri)
        seg = [v * env_exp(len(seg), i, 6) for i, v in enumerate(seg)]
        sig += seg
    write("coin.wav", sig, 0.6)

# ---- hit: low thud + noise crunch ---------------------------------------
def make_hit():
    low = sweep(220, 60, 0.28, math.sin)
    low = [v * env_exp(len(low), i, 4) for i, v in enumerate(low)]
    crunch = apply_env(noise(0.22), lambda n, i: env_exp(n, i, 7))
    sig = mix(low, [c * 0.5 for c in crunch])
    write("hit.wav", sig, 0.9)

# ---- powerup: rising shimmer --------------------------------------------
def make_powerup():
    up = sweep(400, 1600, 0.35, tri)
    up = [v * adsr(len(up), i, 0.02, 0.1, 0.7, 0.3) for i, v in enumerate(up)]
    shimmer = tone(2200, 0.35, math.sin, vibrato=0.02, vfreq=18)
    shimmer = [v * env_exp(len(shimmer), i, 3) * 0.3 for i, v in enumerate(shimmer)]
    sig = mix(up, shimmer)
    write("powerup.wav", sig, 0.7)

# ---- shield break ---------------------------------------------------------
def make_shield():
    dn = sweep(1200, 300, 0.25, square)
    dn = [v * env_exp(len(dn), i, 5) * 0.5 for i, v in enumerate(dn)]
    glass = apply_env(noise(0.2), lambda n, i: env_exp(n, i, 8) * 0.5)
    write("shield.wav", mix(dn, glass), 0.7)

# ---- button click ---------------------------------------------------------
def make_button():
    s = tone(600, 0.04, tri)
    s = [v * env_exp(len(s), i, 8) for i, v in enumerate(s)]
    write("button.wav", s, 0.5)

# ---- swoosh (transitions) -------------------------------------------------
def make_swoosh():
    s = apply_env(noise(0.25), lambda n, i: math.sin(math.pi * i / n) )
    # bandpass-ish by smoothing
    out = []
    prev = 0
    for v in s:
        prev = prev * 0.85 + v * 0.15
        out.append(prev)
    write("swoosh.wav", out, 0.4)

make_flap(); make_score(); make_coin(); make_hit(); make_powerup()
make_shield(); make_button(); make_swoosh()
print("done")
