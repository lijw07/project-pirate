"""Original procedural UI foley. Music is built by build_pirate_shanty.py. Requires Python 3 and NumPy.

No recordings, sample libraries, external services, or borrowed melodies.
Run from any directory; generated WAVs are the shipping assets.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio"
SR = 44100
RNG = np.random.default_rng(7102026)
stats = {}


def envelope(t, duration, attack, release):
    return np.minimum(t / attack, 1) * np.clip((duration - t) / release, 0, 1)


def voice(note, duration, kind):
    t = np.arange(round(duration * SR)) / SR
    f = 440 * 2 ** ((note - 69) / 12)
    phase = 2 * np.pi * f * t
    if kind == "pluck":
        y = sum(np.sin(phase * h + .06 * h) * np.exp(-t * (2.8 + h * .85)) / h ** 1.35 for h in range(1, 9))
        y *= envelope(t, duration, .004, .10)
    elif kind == "bass":
        y = (np.sin(phase) + .24 * np.sin(phase * 2) + .08 * np.sin(phase * 3)) * np.exp(-t * 1.5)
        y *= envelope(t, duration, .018, .16)
    elif kind == "flute":
        phase += .024 * np.sin(2 * np.pi * 4.7 * t) * np.minimum(t / .18, 1)
        y = np.sin(phase) + .22 * np.sin(phase * 2) + .075 * np.sin(phase * 3)
        breath = RNG.normal(0, 1, len(t))
        breath = np.convolve(breath, np.ones(13) / 13, mode="same")
        y = (y + .045 * breath) * envelope(t, duration, .075, .18)
        y *= .9 + .1 * np.sin(np.pi * t / duration)
    elif kind == "horn":
        y = sum(np.sin(phase * h + .018 * h * np.sin(2 * np.pi * 4.1 * t)) / h ** 1.9 for h in range(1, 8))
        y *= envelope(t, duration, .22, .3)
    else:  # Three slightly detuned bowed voices with a slow, soft attack.
        y = np.zeros(len(t))
        for detune in [-.0024, 0, .0021]:
            p = phase * (1 + detune) + .012 * np.sin(2 * np.pi * 4.4 * t)
            y += sum(np.sin(p * h) / h ** 1.8 for h in range(1, 7)) / 3
        y *= envelope(t, duration, .36, .42)
    return y


def place(target, y, seconds, gain, pan=0):
    start = round(seconds * SR)
    idx = (start + np.arange(len(y))) % len(target)
    target[idx, 0] += y * gain * np.sqrt((1 - pan) / 2)
    target[idx, 1] += y * gain * np.sqrt((1 + pan) / 2)


def drum(kind):
    duration = .40 if kind == "tom" else .12
    t = np.arange(round(duration * SR)) / SR
    if kind == "tom":
        y = np.sin(2 * np.pi * (72 * t + 3.8 * (1 - np.exp(-t * 30)))) * np.exp(-t * 13)
        y += .045 * RNG.normal(0, 1, len(t)) * np.exp(-t * 65)
    else:
        y = (np.sin(2 * np.pi * 910 * t) + .5 * np.sin(2 * np.pi * 1433 * t)) * np.exp(-t * 68)
        y += .13 * RNG.normal(0, 1, len(t)) * np.exp(-t * 100)
    return y * envelope(t, duration, .001, .02)


def save(relative, data):
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(data, -.999, .999) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(data.shape[1] if data.ndim > 1 else 1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    stats[relative] = {"seconds": len(data) / SR, "peak_dbfs": float(20 * np.log10(np.max(np.abs(data)))),
                       "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(data ** 2)))),
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}




def cue(name, tones, wood_gain, duration):
    result = np.zeros((round(duration * SR), 2))
    for start, pitch, gain in tones:
        y = voice(pitch, min(.32, duration - start), "pluck")
        place(result, y, start, gain, 0)
    place(result, drum("wood")[:len(result)], 0, wood_gain, 0)
    # Quiet, short cues with sample-accurate silence at each end.
    fade = min(round(.018 * SR), len(result))
    result[-fade:] *= np.linspace(1, 0, fade)[:, None]
    result[0] = 0
    save("ui/" + name + ".wav", result)


cue("hover", [(0, 86, .18)], .025, .105)
cue("click", [(0, 74, .37), (.023, 81, .19)], .24, .21)
cue("back", [(0, 77, .25), (.065, 69, .25)], .09, .30)
cue("confirm", [(0, 74, .25), (.075, 77, .24), (.15, 81, .28)], .11, .48)
manifest = json.loads((OUT / "manifest.json").read_text())
manifest["files"].update(stats)
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(stats, indent=2))
