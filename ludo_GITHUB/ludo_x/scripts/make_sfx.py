#!/usr/bin/env python3
"""Synthesizes the LUDO X sound effects (stdlib only) into assets/sfx/*.wav"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * 0.85)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

def env(i, n, a=0.01, r=0.6):
    t = i / n
    return min(1, t / a) * (1 - t) ** (1 / max(r, 0.01)) if t < 1 else 0

def tone(freq, dur, kind='sine', vol=1.0, slide=0.0):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = freq + slide * (i / n)
        ph += 2 * math.pi * f / SR
        s = math.sin(ph) if kind == 'sine' else (1 if math.sin(ph) > 0 else -1) * 0.5
        out.append(s * env(i, n, 0.02, 0.5) * vol)
    return out

def noise_burst(dur, vol=1.0, decay=3.0):
    n = int(SR * dur)
    return [(random.random() * 2 - 1) * vol * math.exp(-decay * i / n) for i in range(n)]

def silence(d): return [0.0] * int(SR * d)

# dice: rapid clacks
dice = []
for k in range(7):
    dice += noise_burst(0.045, 0.9 - k * 0.07, 6) + silence(0.035 + k * 0.012)
dice += tone(180, 0.07, 'sine', 0.8)
write('dice', dice)

# move: soft wooden tick
write('move', [a * 0.9 + b * 0.5 for a, b in zip(tone(520, 0.07, 'sine'), noise_burst(0.07, 0.4, 14))])

# capture: descending sweep + thud
cap = tone(700, 0.28, 'square', 0.5, slide=-520)
thud = tone(110, 0.2, 'sine', 1.0)
cap = [(cap[i] if i < len(cap) else 0) + (thud[i - 2000] if 2000 <= i < 2000 + len(thud) else 0) for i in range(len(cap) + 3000)]
write('capture', cap)

# home: rising arpeggio
home = []
for f in (523.25, 659.25, 783.99, 1046.5):
    home += tone(f, 0.11, 'sine', 0.9)
write('home', home)

# win: fanfare
win = []
for f, d in ((523.25, 0.14), (523.25, 0.14), (659.25, 0.14), (783.99, 0.3), (659.25, 0.12), (783.99, 0.14), (1046.5, 0.5)):
    win += tone(f, d, 'sine', 0.9)
write('win', win)

# tick: timer warning
write('tick', tone(1200, 0.05, 'sine', 0.7))

# six: bright double ping
write('six', tone(880, 0.09, 'sine') + tone(1318.5, 0.16, 'sine'))
print('sfx written')
