"""Temporary audio made in code (v0.17g): no copyright worries, good enough for playtests.

  python3 tools/audio_synth.py music   -> assets/game/music/*.ogg  (3 chill loops)
  python3 tools/audio_synth.py sfx     -> assets/game/sfx/pop_*.ogg (mid-low "pop" sounds)
  python3 tools/audio_synth.py all

Needs numpy + ffmpeg (libvorbis). Hamza's taste: mid-low, light, poppy; nothing shrill.
Swap any of these for real tracks later: the game plays whatever .ogg files are in assets/game/music.
"""
import os, sys, subprocess, tempfile
import numpy as np
import scipy.io.wavfile as wavfile
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RNG = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env_adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    e = np.full(n, s, dtype=float)
    a = max(1, min(a, n)); e[:a] = np.linspace(0, 1, a)
    dd = max(1, min(d, n - a)); e[a:a + dd] = np.linspace(1, s, dd)
    if r > 0 and n > r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lp(x, hz, order=2):
    return sosfilt(butter(order, hz, 'low', fs=SR, output='sos'), x)


def hp(x, hz, order=2):
    return sosfilt(butter(order, hz, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


# ------------------------------------------------------------------ instruments

def epiano(freq, dur):
    """soft FM electric piano (Rhodes-ish)"""
    n = int(dur * SR); t = np.arange(n) / SR
    idx = 1.6 * np.exp(-t * 3.0) + 0.25
    mod = np.sin(2 * np.pi * freq * t) * idx
    car = np.sin(2 * np.pi * freq * t + mod)
    bell = 0.12 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t * 9.0)
    trem = 1.0 + 0.08 * np.sin(2 * np.pi * 4.5 * t)
    return (car + bell) * env_adsr(n, 0.008, 0.6, 0.35, min(0.25, dur * 0.4)) * trem


def marimba(freq, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 3.98 * t) * np.exp(-t * 18)
    return x * np.exp(-t * 5.5) * env_adsr(n, 0.003, 0.05, 1.0, 0.02)


def pluck(freq, dur):
    """ukulele-ish Karplus-Strong"""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = RNG.uniform(-1, 1, p)
    buf = lp(np.tile(buf, 3), 3000)[-p:]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
    return out * env_adsr(n, 0.002, 0.1, 1.0, 0.03)


def bass(freq, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    x = np.tanh(x * 1.6)
    return x * env_adsr(n, 0.006, 0.15, 0.7, 0.05)


def kick():
    n = int(0.35 * SR); t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9)


def snare():
    n = int(0.22 * SR); t = np.arange(n) / SR
    noise = bp(RNG.uniform(-1, 1, n), 900, 4000) * np.exp(-t * 22)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28)
    return (noise * 0.7 + body * 0.6)


def shaker():
    n = int(0.06 * SR); t = np.arange(n) / SR
    return bp(RNG.uniform(-1, 1, n), 3000, 7000) * np.exp(-t * 60)


def add(buf, x, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= buf.shape[0]:
        return
    x = x[:buf.shape[0] - i] * gain
    l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
    buf[i:i + len(x), 0] += x * l * 1.41
    buf[i:i + len(x), 1] += x * r * 1.41


# ------------------------------------------------------------------ songs

def song(bpm, chords, bars, lead_fn, lead_notes, swing=0.0, feel="lofi"):
    beat = 60.0 / bpm
    total = bars * 4 * beat + 2.0
    buf = np.zeros((int(total * SR), 2))
    for bar in range(bars):
        ch = chords[bar % len(chords)]
        t0 = bar * 4 * beat
        # keys: chord stabs on 1 and the "and" of 2 (soft), voiced mid register
        for k, at in enumerate([0.0, 1.5, 2.5] if feel != "lofi" else [0.0, 2.0]):
            dur = beat * (1.8 if feel == "lofi" else 0.9)
            for j, nnote in enumerate(ch[1:]):
                add(buf, epiano(midi(nnote), dur), t0 + at * beat + j * 0.012, 0.11, pan=-0.3 + 0.2 * j)
        # bass: root on 1, fifth/root pattern
        root = ch[0]
        pat = [(0.0, root, 1.4), (1.5, root, 0.4), (2.0, root + 7, 0.9), (3.5, root + 12 if bar % 2 else root, 0.4)]
        for at, nn, d in pat:
            add(buf, bass(midi(nn), d * beat), t0 + at * beat, 0.32)
        # drums (laid back)
        for b in range(4):
            sw = swing * beat if b % 2 else 0.0
            if b in (0, 2) or (feel == "funk" and b == 2):
                add(buf, kick(), t0 + b * beat, 0.55)
            if b in (1, 3):
                add(buf, snare(), t0 + b * beat + sw * 0.3, 0.16, pan=0.1)
            for e in range(2):
                add(buf, shaker(), t0 + (b + e * 0.5) * beat + (swing * beat * 0.5 if e else 0.0), 0.05 if e else 0.035, pan=0.35)
        if feel == "funk" and bar % 2:
            add(buf, kick(), t0 + 2.75 * beat, 0.35)
    # lead: sparse motif, comes in after the intro bars, rests on every 4th phrase
    step = beat / 2
    for bar in range(2, bars):
        if (bar // 4) % 4 == 3:
            continue
        motif = lead_notes[bar % len(lead_notes)]
        for k, nn in enumerate(motif):
            if nn is None:
                continue
            add(buf, lead_fn(midi(nn), step * 1.8), bar * 4 * beat + k * step + (swing * step if k % 2 else 0), 0.16, pan=0.25)
    # warm it up: gentle low-pass, little stereo room
    for c in range(2):
        buf[:, c] = lp(buf[:, c], 5200)
    d = int(0.023 * SR)
    room = np.zeros_like(buf)
    room[d:, 0] = buf[:-d, 1] * 0.18
    room[d:, 1] = buf[:-d, 0] * 0.18
    buf += room
    # loop-friendly: fade the tail, trim to whole bars
    n = int(bars * 4 * beat * SR)
    tail = buf[n:].copy()
    buf = buf[:n]
    buf[:len(tail)] += tail[:n]      # wrap the ring-out into the start so it loops smoothly
    rms = np.sqrt(np.mean(buf ** 2))
    buf *= 0.12 / max(rms, 1e-9)
    buf = np.tanh(buf * 1.1) / 1.1
    peak = np.abs(buf).max()
    if peak > 0.89:
        buf *= 0.89 / peak
    return buf


def write_ogg(buf, path, q=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    wavfile.write(tmp, SR, (np.clip(buf, -1, 1) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def make_music():
    out = os.path.join(ROOT, "assets", "game", "music")
    # 1: "Saturday Suds" - lofi keys, F major, 88 BPM
    F = [[41, 57, 60, 64, 69], [38, 57, 60, 62, 65], [43, 58, 62, 65, 69], [36, 58, 60, 64, 67]]  # Fmaj7 Dm9 Gm7 C9
    lead1 = [[72, None, 69, None, 67, 69, None, None], [None, 65, None, 67, 69, None, 72, None],
             [74, None, 72, 70, None, 69, None, None], [67, None, None, 69, 67, 65, None, None]]
    write_ogg(song(88, F, 32, marimba, lead1, swing=0.12, feel="lofi"), os.path.join(out, "01_saturday_suds.ogg"))
    # 2: "Wax On" - ukulele pluck, C major, 100 BPM
    C = [[36, 55, 60, 64, 67], [33, 57, 60, 64, 69], [41, 57, 60, 65, 69], [43, 55, 59, 62, 67]]   # C Am F G
    lead2 = [[67, 69, 72, None, 69, None, 67, None], [64, None, 67, 69, None, 67, 64, None],
             [65, 67, 69, None, 72, None, 69, None], [67, None, 62, None, 64, 65, 67, None]]
    write_ogg(song(100, C, 32, pluck, lead2, swing=0.08, feel="pop"), os.path.join(out, "02_wax_on.ogg"))
    # 3: "Detail Drive" - light funk, G mixolydian, 96 BPM
    G = [[43, 59, 62, 65, 69], [41, 57, 60, 64, 69], [36, 55, 59, 64, 67], [41, 57, 60, 65, 69]]   # G9 F69 Cmaj7 F
    lead3 = [[74, None, 72, 74, None, 77, None, 74], [None, 72, None, 69, 67, None, 65, None],
             [67, 69, None, 72, None, 74, None, None], [72, None, 69, None, 67, None, None, None]]
    write_ogg(song(96, G, 32, epiano, lead3, swing=0.1, feel="funk"), os.path.join(out, "03_detail_drive.ogg"))
    print("music ->", out)


# ------------------------------------------------------------------ sound effects

def tone_sweep(f0, f1, dur, shape=4.0):
    n = int(dur * SR); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * shape / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def pop(f0, f1, dur, body=0.0, noise=0.0, lpf=3000):
    n = int(dur * SR); t = np.arange(n) / SR
    x = tone_sweep(f0, f1, dur, 5.0)
    x += 0.3 * tone_sweep(f0 * 2, f1 * 2, dur, 5.0) * np.exp(-t * 40)
    if body:
        x += body * np.sin(2 * np.pi * 110 * t) * np.exp(-t * 35)
    if noise:
        x += noise * lp(RNG.uniform(-1, 1, n), 1800) * np.exp(-t * 60)
    e = env_adsr(n, 0.004, dur * 0.3, 0.35, dur * 0.5)
    return lp(x * e, lpf)


def chime(notes, gap, dur=0.5):
    total = gap * (len(notes) - 1) + dur
    out = np.zeros(int(total * SR) + 1)
    for k, f in enumerate(notes):
        m = marimba(f, dur)
        i = int(k * gap * SR)
        out[i:i + len(m)] += m
    return lp(out, 3500)


def norm(x, peak=0.7):
    return x * (peak / max(np.abs(x).max(), 1e-9))


def make_sfx():
    out = os.path.join(ROOT, "assets", "game", "sfx")
    s = {
        "pop_click": pop(520, 360, 0.07, noise=0.15, lpf=2600),        # any button
        "pop_tap": pop(300, 470, 0.11, body=0.3, lpf=2400),            # tap a station to start it (bloop up)
        "pop_open": pop(250, 380, 0.13, lpf=2000),                     # a panel slides up
        "pop_close": pop(380, 230, 0.12, lpf=2000),                    # ... and closes
        "pop_toggle": np.concatenate([pop(420, 340, 0.06), pop(480, 380, 0.07)]),
        "pop_cash": norm(lp(pop(660, 560, 0.12, body=0.5) + 0.5 * np.concatenate([np.zeros(int(0.04 * SR)), pop(990, 880, 0.12)])[:int(0.12 * SR)], 2800)),
        "pop_level": pop(392, 523, 0.12, body=0.2, lpf=2600),          # one level bought
        "pop_hire": chime([midi(60), midi(64), midi(67)], 0.07, 0.5),  # warm C-E-G marimba
        "pop_error": np.concatenate([pop(240, 200, 0.08), pop(200, 160, 0.1)]),
    }
    for k, x in s.items():
        x = norm(x)
        f = int(0.008 * SR)
        x[-f:] *= np.linspace(1, 0, f)    # no click at the end
        write_ogg(np.stack([x] * 2, axis=1), os.path.join(out, k + ".ogg"), q=5)
    print("sfx ->", out, list(s.keys()))


def mrrp():
    """v0.19t: a soft cat chirp for petting Suds ("mrrp?"): a rising-then-falling glide with a little trill."""
    dur = 0.3
    n = int(dur * SR); t = np.arange(n) / SR
    k = t / dur
    f = 430 + 330 * np.sin(np.pi * np.clip(k * 1.3, 0, 1)) - 120 * k
    f = f * (1 + 0.035 * np.sin(2 * np.pi * 28 * t))          # the trill
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    x = bp(x, 380, 2600)
    e = env_adsr(n, 0.02, 0.08, 0.7, 0.14)
    return lp(x * e, 2400)


def make_cat():
    out = os.path.join(ROOT, "assets", "game", "sfx")
    x = norm(mrrp(), 0.6)
    f = int(0.01 * SR)
    x[-f:] *= np.linspace(1, 0, f)
    write_ogg(np.stack([x] * 2, axis=1), os.path.join(out, "pop_mrrp.ogg"), q=5)
    print("cat ->", out)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("music", "all"):
        make_music()
    if what in ("sfx", "all"):
        make_sfx()
    if what == "cat":
        make_cat()
