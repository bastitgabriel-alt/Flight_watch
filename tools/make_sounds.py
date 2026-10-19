"""Synthèse des sons du jeu (aucun fichier externe)."""
import os, subprocess, sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env_ad(n, a, d_curve):
    e = np.ones(n)
    na = max(1, int(SR * a))
    e[:na] = np.linspace(0, 1, na)
    e[na:] = np.exp(-np.arange(n - na) / SR * d_curve)
    return e


def lp(x, f, order=4):
    b, a = signal.butter(order, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def reverb(x, seconds=2.0, mix=0.3, damp=3.0):
    n = int(SR * seconds)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * damp)
    ir = lp(ir, 6000)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return (1 - mix) * dry + mix * wet


def saw(freq, tt):
    return 2 * ((freq * tt) % 1) - 1


def norm(x, peak=0.89):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def fade(x, fin=0.005, fout=0.05):
    n = len(x)
    a, b = int(SR * fin), int(SR * fout)
    x = x.copy()
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim(x, threshold=0.004):
    x = norm(x)
    loud = np.nonzero(np.abs(x) > threshold)[0]
    end = min(len(x), loud[-1] + int(SR * 0.1)) if len(loud) else len(x)
    return x[:end]


def save(name, x, stereo_width=0.0):
    assert np.all(np.isfinite(x)), name
    x = norm(fade(trim(x), fout=0.15))
    rms = np.sqrt(np.mean(x ** 2))
    print(f"  {name}: rms {20 * np.log10(rms):.1f} dBFS")
    left = x
    right = x
    if stereo_width:
        d = int(SR * 0.012)
        right = np.concatenate([np.zeros(d), x[:-d]])
        left, right = x * (1 - stereo_width * 0.3) + right * stereo_width * 0.3, right
    data = np.stack([left, right], axis=1)
    wav = os.path.join(OUT, name + ".wav")
    wavfile.write(wav, SR, (data * 32767).astype(np.int16))
    mp3 = os.path.join(OUT, name + ".mp3")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-b:a", "192k", mp3], check=True)
    os.remove(wav)
    print(name, f"{len(x) / SR:.1f}s")


def bell(freq, d, decay=2.5, ratios=(1, 2.0, 2.76, 4.07, 5.4), amps=(1, 0.5, 0.6, 0.25, 0.3)):
    tt = t(d)
    out = np.zeros_like(tt)
    for r, a in zip(ratios, amps):
        out += a * np.sin(2 * np.pi * freq * r * tt) * np.exp(-tt * decay * (0.6 + r * 0.4))
    return out * env_ad(len(tt), 0.002, 0)


# 1. Sonnette de la réception
def reception_bell():
    x = bell(1320, 2.2, decay=1.6)
    x += 0.15 * bp(rng.standard_normal(len(x)), 3000, 8000) * np.exp(-t(2.2) * 60)
    save("Bell", reverb(x, 1.5, 0.25))


# 2. Capture : souffle aspiré + éclair + clac métallique
def capture():
    d = 1.4
    tt = t(d)
    noise = rng.standard_normal(len(tt))
    whoosh = lp(noise, 2500) * np.sin(np.pi * np.clip(tt / 0.8, 0, 1)) ** 2
    tone = np.sin(2 * np.pi * (900 * np.exp(-tt * 4) + 120) * tt) * np.exp(-tt * 3) * 0.6
    click_t = t(0.4)
    click = bell(2400, 0.4, decay=10, ratios=(1, 1.5, 2.3), amps=(1, 0.7, 0.4))
    x = whoosh * 0.8 + tone
    start = int(SR * 0.8)
    x[start : start + len(click)] += click * 0.9
    thump = np.sin(2 * np.pi * 70 * click_t) * np.exp(-click_t * 18)
    x[start : start + len(thump)] += thump
    save("Capture", reverb(x, 1.2, 0.2), 0.5)


# 3. Pièces + tiroir-caisse
def cash():
    d = 1.0
    x = np.zeros(int(SR * d))
    for i, (when, f) in enumerate([(0.0, 3200), (0.07, 3900), (0.13, 3500), (0.2, 4300), (0.26, 3700)]):
        c = bell(f, 0.35, decay=9, ratios=(1, 1.47, 2.09), amps=(1, 0.5, 0.3))
        s = int(SR * when)
        x[s : s + len(c)] += c * (0.8 - i * 0.08)
    ding = bell(1760, 0.7, decay=3)
    s = int(SR * 0.32)
    x[s : s + len(ding)] += ding[: len(x) - s] * 0.7
    save("Cash", reverb(x, 0.8, 0.15), 0.4)


# 4. Frayeur (anomalie infiltrée)
def scare():
    d = 1.8
    tt = t(d)
    cluster = np.zeros_like(tt)
    for f in [1480, 1568, 1661, 2217, 2349]:
        vib = 1 + 0.01 * np.sin(2 * np.pi * 7 * tt)
        cluster += saw(f * vib, tt)
    cluster = bp(cluster, 1200, 7000) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * tt))
    cluster *= env_ad(len(tt), 0.01, 2.2)
    boom = np.sin(2 * np.pi * (60 * np.exp(-tt * 2) + 35) * tt) * np.exp(-tt * 2.5)
    hit = lp(rng.standard_normal(len(tt)), 900) * np.exp(-tt * 12)
    save("Scare", reverb(cluster * 0.6 + boom * 1.0 + hit * 0.8, 2.0, 0.3), 0.8)


# 5. Alarme de vol
def alarm():
    d = 2.4
    tt = t(d)
    f = np.where((tt * 4) % 1 < 0.5, 880, 660)
    phase = 2 * np.cumsum(np.pi * f) / SR
    tone = np.sign(np.sin(phase)) * 0.4 + np.sin(phase) * 0.6
    tone = lp(tone, 4000)
    ring = 0.6 + 0.4 * np.sin(2 * np.pi * 22 * tt)
    save("Alarm", reverb(tone * ring, 0.8, 0.2), 0.3)


# 6. Renaissance : arpège qui monte + chœur scintillant
def rebirth():
    d = 3.5
    tt = t(d)
    x = np.zeros_like(tt)
    notes = [261.6, 329.6, 392.0, 523.3, 659.3, 784.0, 1046.5]
    for i, f in enumerate(notes):
        s = int(SR * i * 0.12)
        c = bell(f * 2, d - i * 0.12, decay=1.5)
        x[s : s + len(c)] += c[: len(x) - s] * 0.5
    choir = np.zeros_like(tt)
    for f in [261.6, 329.6, 392.0, 523.3]:
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5 * tt + f)
        for h, a in [(1, 1), (2, 0.5), (3, 0.3), (4, 0.15)]:
            choir += a * np.sin(2 * np.pi * f * h * vib * tt)
    choir = bp(choir, 200, 3000) * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 1.5
    sparkle = hp(rng.standard_normal(len(tt)), 7000) * (rng.random(len(tt)) > 0.997) * 3
    sparkle = lp(sparkle, 12000) * np.clip(tt, 0, 1)
    save("Rebirth", reverb(x + choir * 0.25 + sparkle * 0.3, 2.5, 0.35), 0.8)


# 7. Hurlement de loup (Lune de Sang)
def howl():
    d = 4.5
    tt = t(d)
    # hauteur : monte, tient, retombe
    pitch = np.interp(tt, [0, 0.6, 2.8, 4.0, 4.5], [330, 520, 560, 380, 300])
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt)
    phase = 2 * np.pi * np.cumsum(pitch * vib) / SR
    voice = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)
    voice *= np.interp(tt, [0, 0.3, 3.5, 4.5], [0, 1, 0.8, 0])
    breath = bp(rng.standard_normal(len(tt)), 800, 3000) * 0.08 * voice
    wind = lp(rng.standard_normal(len(tt)), 500) * 0.25 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.3 * tt))
    save("Howl", reverb(voice * 0.7 + breath + wind, 3.0, 0.45, damp=1.5), 0.9)


# 8. Coupure de courant
def power_down():
    d = 2.6
    tt = t(d)
    drop = np.interp(tt, [0, 1.2, 1.8, 2.6], [1, 1, 0.35, 0.3])
    hum = np.zeros_like(tt)
    phase = 2 * np.pi * np.cumsum(50 * drop) / SR
    for h, a in [(1, 1), (2, 0.6), (3, 0.5), (5, 0.3), (7, 0.2)]:
        hum += a * np.sin(h * phase)
    buzz = np.sign(np.sin(phase * 2)) * 0.15
    level = np.interp(tt, [0, 0.1, 1.6, 1.9, 2.6], [0, 1, 1, 0, 0])
    clunk_t = t(0.6)
    clunk = (lp(rng.standard_normal(len(clunk_t)), 600) + np.sin(2 * np.pi * 80 * clunk_t)) * np.exp(-clunk_t * 9)
    x = (hum + buzz) * level * 0.5
    s = int(SR * 1.85)
    x[s : s + len(clunk)] += clunk * 0.9
    save("PowerDown", reverb(x, 1.5, 0.3), 0.3)


# 9. Tonnerre
def thunder():
    d = 5.0
    tt = t(d)
    crack = hp(rng.standard_normal(len(tt)), 1500) * np.exp(-tt * 9)
    rumble = lp(rng.standard_normal(len(tt)), 180, 4)
    rumble *= np.interp(tt, [0, 0.15, 1.5, 5], [0, 1, 0.6, 0])
    rumble *= 0.6 + 0.4 * np.interp(tt, np.linspace(0, d, 14), rng.random(14))
    mid = lp(rng.standard_normal(len(tt)), 700) * np.exp(-tt * 1.2) * 0.6
    save("Thunder", reverb(crack * 0.5 + rumble * 2.5 + mid, 3.0, 0.4, damp=1.2), 1.0)


# 10. Musique d'ambiance (boucle de 64 s) : nappe grave + boîte à musique
def ambience():
    d = 64.0
    tt = t(d)
    drone = np.zeros_like(tt)
    for f, a in [(55.0, 1), (55.4, 0.8), (82.4, 0.5), (110.2, 0.35), (164.8, 0.15)]:
        drone += a * saw(f, tt)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * tt / 16)
    drone = lp(drone, 400) * (0.6 + 0.4 * lfo)
    pad = np.zeros_like(tt)
    for f in [220.0, 261.6, 329.6]:
        pad += np.sin(2 * np.pi * f * tt * (1 + 0.003 * np.sin(2 * np.pi * 0.2 * tt + f)))
    pad *= 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 32 - 1))
    # Boîte à musique : mélodie mineure, lente, un peu désaccordée
    melody = [(0, 880), (1.5, 1046.5), (3, 987.8), (4.5, 659.3), (8, 880), (9.5, 784), (11, 698.5), (12.5, 659.3),
              (16, 587.3), (17.5, 698.5), (19, 880), (20.5, 830.6), (24, 880), (25.5, 1046.5), (27, 1318.5), (28.5, 1174.7),
              (32, 1046.5), (33.5, 987.8), (35, 880), (36.5, 830.6), (40, 880), (44, 659.3), (45.5, 698.5), (47, 587.3),
              (52, 880), (53.5, 1046.5), (55, 987.8), (56.5, 659.3), (58, 622.3)]
    box = np.zeros_like(tt)
    for when, f in melody:
        c = bell(f * 0.998, 3.0, decay=1.8, ratios=(1, 3.0, 4.1), amps=(1, 0.25, 0.1))
        s = int(SR * when)
        e = min(len(box), s + len(c))
        box[s:e] += c[: e - s] * 0.35
    creaks = np.zeros_like(tt)
    for when in [13.0, 37.5, 50.0]:
        ct = t(1.2)
        pitch = 180 + 60 * np.sin(2 * np.pi * 1.3 * ct)
        c = saw(pitch, ct) * np.sin(np.pi * ct / 1.2) * 0.08
        c = bp(c, 300, 2500)
        s = int(SR * when)
        creaks[s : s + len(c)] += c
    x = drone * 0.5 + pad + box + creaks
    x = reverb(x, 3.5, 0.45, damp=1.2)
    # Boucle sans couture : la queue de réverbération revient au début
    tail = x[len(tt) :]
    x = x[: len(tt)]
    x[: len(tail)] += tail
    n = len(x)
    save_loop("Ambience", x)


def save_loop(name, x):
    x = norm(x, 0.8)
    data = np.stack([x, np.roll(x, int(SR * 0.015))], axis=1)
    wav = os.path.join(OUT, name + ".wav")
    wavfile.write(wav, SR, (data * 32767).astype(np.int16))
    mp3 = os.path.join(OUT, name + ".mp3")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-b:a", "160k", mp3], check=True)
    os.remove(wav)
    print(name, f"{len(x) / SR:.1f}s")


for fn in [reception_bell, capture, cash, scare, alarm, rebirth, howl, power_down, thunder, ambience]:
    fn()
