#!/usr/bin/env python3
"""
gen_loops.py — synthesizes the game's looping audio beds.

Two long clips that play continuously under the game:

  ambience_rain.wav  steady rainfall, so the storm you can see is also audible
  music_loop.wav     a slow pad in A minor that sits under the rain

Both are written at a lower sample rate (plenty for noise and pads) and are
crossfaded end-over-start, so the loop point is inaudible.

Run:  python3 tools/gen_loops.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)

random.seed(7)


def _write_loop(name, samples, amp=0.9, fade=0.8):
    """Write a seamless loop: the tail is crossfaded back over the head."""
    n = len(samples)
    f = int(SR * fade)
    out = list(samples)
    for i in range(f):
        w = i / f
        out[i] = out[i] * w + samples[n - f + i] * (1 - w)
    out = out[: n - f]

    peak = max(1e-6, max(abs(x) for x in out))
    scale = amp / peak
    path = os.path.join(OUT, name)
    with wave.open(path, 'w') as w_:
        w_.setnchannels(1)
        w_.setsampwidth(2)
        w_.setframerate(SR)
        frames = bytearray()
        for x in out:
            frames += struct.pack('<h', int(max(-1, min(1, x * scale)) * 32767))
        w_.writeframes(frames)
    print(f'wrote {path}  {len(out) / SR:.1f}s  {os.path.getsize(path) // 1024} KB')


def _lowpass(sig, cutoff):
    """One-pole lowpass; cutoff is a 0..1 fraction of Nyquist."""
    out = []
    prev = 0.0
    for v in sig:
        prev += cutoff * (v - prev)
        out.append(prev)
    return out


def _highpass(sig, cutoff):
    return [s - l for s, l in zip(sig, _lowpass(sig, cutoff))]


def make_ambience(seconds=10.0):
    """Rainfall: filtered noise with slow gusts and a few closer droplets."""
    n = int(SR * seconds)
    base = [random.uniform(-1, 1) for _ in range(n)]
    hiss = _highpass(base, 0.35)   # the fine spray
    body = _lowpass(base, 0.05)    # the duller roar underneath
    sig = [h * 0.55 + b * 0.45 for h, b in zip(hiss, body)]

    # Slow gusts so the bed breathes instead of sitting flat.
    for i in range(n):
        t = i / SR
        sig[i] *= (1.0
                   + 0.18 * math.sin(2 * math.pi * t / seconds * 2)
                   + 0.10 * math.sin(2 * math.pi * t / seconds * 3))

    # A handful of nearer drips for detail.
    for _ in range(int(seconds * 6)):
        pos = random.randrange(0, n - 2000)
        freq = random.uniform(900, 2400)
        for i in range(1500):
            sig[pos + i] += 0.25 * math.sin(2 * math.pi * freq * i / SR) * math.exp(-6.0 * i / 1500)

    _write_loop('ambience_rain.wav', sig, amp=0.55)


def make_music(seconds=24.0):
    """A slow, wistful pad loop in A minor, with a sparse bell motif over it."""
    n = int(SR * seconds)
    sig = [0.0] * n

    a = 220.0  # A3
    # Am - F - G - C, one bar each, using just intervals for a clean blend.
    chords = [
        [a, a * 6 / 5, a * 3 / 2],
        [a * 4 / 3, a * 5 / 3, a * 2],
        [a * 3 / 2, a * 15 / 8, a * 9 / 4],
        [a * 5 / 4, a * 3 / 2, a * 2],
    ]
    bar = n // len(chords)

    for ci, chord in enumerate(chords):
        start = ci * bar
        for f in chord:
            for octave, amp in ((1.0, 0.20), (2.0, 0.09)):
                phase = random.uniform(0, 2 * math.pi)
                for i in range(bar):
                    t = i / SR
                    # Swell in and out so chords breathe into each other.
                    env = math.sin(math.pi * i / bar) ** 0.7
                    vib = 1.0 + 0.0015 * math.sin(2 * math.pi * 0.7 * t)
                    sig[start + i] += amp * env * math.sin(
                        2 * math.pi * f * octave * vib * t + phase)

    # Sparse bells drifting over the top.
    for k in range(int(seconds / 2.2)):
        pos = int(k * 2.2 * SR) % n
        semi = random.choice([0, 3, 5, 7, 10, 12])
        f = a * 2 * (2 ** (semi / 12))
        dur = int(SR * 1.6)
        for i in range(dur):
            if pos + i >= n:
                break
            sig[pos + i] += 0.10 * math.sin(2 * math.pi * f * i / SR) * math.exp(-3.2 * i / dur)

    sig = _lowpass(sig, 0.28)  # take the edge off; it sits *under* the rain
    _write_loop('music_loop.wav', sig, amp=0.42, fade=1.2)


if __name__ == '__main__':
    make_ambience()
    make_music()
    print('loops done')
