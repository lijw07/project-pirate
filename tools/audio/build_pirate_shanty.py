"""Compose and render The Blackwater Crew, an original pirate menu shanty.

macOS + Python 3 + NumPy. Apple's system instruments are rendered, not copied.
The previous procedural UI cues remain unchanged.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from render_score import render

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio"
SR = 44100
EIGHTH = 60 / 108 / 2
DURATION = 80.0
rng = np.random.default_rng(7102027)
events = []
parts = [
    {"channel": 0, "program": 21, "volume": 97, "pan": 57},  # Accordion melody
    {"channel": 1, "program": 110, "volume": 75, "pan": 79},  # Fiddle
    {"channel": 2, "program": 24, "volume": 88, "pan": 37},  # Plucked guitar
    {"channel": 3, "program": 43, "volume": 96, "pan": 64},  # Double bass
    {"channel": 4, "program": 21, "volume": 58, "pan": 86},  # Short bellows chords
    {"channel": 9, "program": 0, "volume": 76, "pan": 64},   # Deck percussion
]


def note(channel, pitch, start, length, velocity):
    start = max(0.0, start * EIGHTH)
    velocity = max(1, min(127, velocity + int(rng.integers(-4, 5))))
    events.append(dict(time=start, channel=channel, pitch=pitch, velocity=velocity, on=True))
    events.append(dict(time=start + length * EIGHTH, channel=channel, pitch=pitch, velocity=0, on=False))


# Original call-and-response phrases: dotted pulse, fiddle turns and dominant cadences.
melody = [
    [(0, 69, .75), (1, 74, .85), (2, 74, .75), (3, 77, 1.7), (5, 76, .75)],
    [(0, 74, 1.7), (2, 72, .75), (3, 69, 1.65), (5, 67, .7)],
    [(0, 65, .75), (1, 69, .75), (2, 70, .75), (3, 74, 1.65), (5, 72, .75)],
    [(0, 69, 1.7), (2, 67, .75), (3, 64, 1.8)],
    [(0, 65, .75), (1, 69, .75), (2, 74, .75), (3, 77, .75), (4, 76, .75), (5, 74, .75)],
    [(0, 79, 1.6), (2, 77, .75), (3, 76, 1.65), (5, 72, .75)],
    [(0, 74, .75), (1, 72, .75), (2, 70, .75), (3, 69, .75), (4, 67, .75), (5, 65, .75)],
    [(0, 64, 1.6), (2, 61, .75), (3, 57, 1.65), (5, 69, .7)],
]
answer = [
    [(0, 77, 1.65), (2, 81, .75), (3, 84, 1.65), (5, 81, .7)],
    [(0, 79, .75), (1, 76, .75), (2, 72, .75), (3, 76, 1.7), (5, 79, .75)],
    [(0, 82, 1.6), (2, 81, .75), (3, 77, 1.65), (5, 74, .75)],
    [(0, 79, 1.6), (2, 77, .75), (3, 76, 1.7), (5, 72, .75)],
    [(0, 74, .75), (1, 77, .75), (2, 81, .75), (3, 86, 1.7), (5, 84, .75)],
    [(0, 82, .75), (1, 81, .75), (2, 79, .75), (3, 77, 1.7), (5, 74, .75)],
    [(0, 79, 1.65), (2, 77, .75), (3, 76, .75), (4, 74, .75), (5, 73, .75)],
    [(0, 76, 1.65), (2, 73, .75), (3, 69, 1.75)],
]
chords_a = [(50, [62, 65, 69]), (48, [60, 64, 67]), (46, [58, 62, 65]), (45, [57, 61, 64]),
            (50, [62, 65, 69]), (48, [60, 64, 67]), (46, [58, 62, 65]), (45, [57, 61, 64])]
chords_b = [(53, [60, 65, 69]), (48, [60, 64, 67]), (46, [58, 62, 65]), (48, [60, 64, 67]),
            (50, [62, 65, 69]), (46, [58, 62, 65]), (55, [62, 67, 70]), (45, [57, 61, 64])]

for bar in range(48):
    section, phrase = divmod(bar, 8)
    base = bar * 6
    root, chord = (chords_b if section == 3 else chords_a)[phrase]
    intensity = [0, 8, 4, 2, 10, -5][section]
    for beat, pitch in [(0, root - 12), (3, root - 5)]:
        note(3, pitch, base + beat, 2.35, 92 + intensity)
    for beat in [1, 2, 4, 5]:
        for i, pitch in enumerate(chord):
            note(4, pitch - 12, base + beat + i * .015, .57, 64 + intensity + (5 if beat in [2, 5] else 0))
    for beat, pitch in enumerate([root, chord[1], chord[2], root + 7, chord[0], chord[2]]):
        note(2, pitch, base + beat + .016, .9, 73 + intensity + (8 if beat in [0, 3] else 0))
    # Boots on timber, a loose hand drum and tambourine, not a modern drum kit beat.
    for beat in [0, 3]:
        note(9, 36, base + beat, .18, 68 + intensity)
        note(9, 41 if beat == 0 else 45, base + beat + .022, .22, 74 + intensity)
    for beat in [2, 5]:
        note(9, 54, base + beat, .12, 52 + intensity)
    if section in [1, 2, 4] and phrase % 2 == 1:
        note(9, 38, base + 3, .15, 46 + intensity)
    tune = answer[phrase] if section == 3 else melody[phrase]
    fiddle_lead = section in [2, 3]
    for beat, pitch, length in tune:
        # Fiddle grace notes on downbeats make the response more dance-like.
        if fiddle_lead and beat == 0 and phrase % 2 == 0:
            note(1, pitch + 2, base + beat, .16, 67)
            note(1, pitch, base + beat + .16, length - .16, 85 + intensity)
        else:
            note(1 if fiddle_lead else 0, pitch, base + beat, length, 87 + intensity)
        if section == 4:
            note(1, pitch - 12, base + beat + .025, length * .9, 68)
    if section == 1 and phrase in [1, 3, 5, 7]:
        for beat, pitch in [(4.5, chord[1] + 12), (5, chord[0] + 12), (5.5, chord[2])]:
            note(1, pitch, base + beat, .42, 68)
    if phrase == 7 and section in [1, 3, 4]:
        for beat, pitch in [(4.5, 45), (5, 47), (5.5, 50)]:
            note(9, pitch, base + beat, .15, 65 + intensity)

# Two identical cycles warm up instrument releases and room tails. Ship the second.
score = dict(title="The Blackwater Crew", bpm=108, meter="6/8", duration=DURATION * 2,
             parts=parts, events=events + [dict(e, time=e["time"] + DURATION) for e in events])
(OUT / "music/pirate_shanty_score.json").write_text(json.dumps(score, separators=(",", ":")) + "\n")
rendered = render(score)
audio = rendered[round(DURATION * SR):round(DURATION * SR) * 2].astype(np.float64)
# A small wooden room rather than the first track's spacious fantasy ambience.
dry = audio.copy()
for delay, gain in [(.047, .10), (.083, .065), (.137, .035)]:
    audio += np.roll(dry[:, ::-1], round(delay * SR), axis=0) * gain
audio -= audio.mean(axis=0)
audio *= .79 / np.max(np.abs(audio))
path = OUT / "music/harbor_of_rivals.wav"
with wave.open(str(path), "wb") as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes(np.round(audio * 32767).astype("<i2").tobytes())
manifest = json.loads((OUT / "manifest.json").read_text())
manifest.update(title="The Blackwater Crew", bpm=108, bars=48, duration_seconds=DURATION,
                seed=7102027, provenance="Original shanty composition rendered with macOS built-in General MIDI instruments. System sound bank is not redistributed. UI cues use original procedural synthesis.")
manifest["files"]["music/harbor_of_rivals.wav"] = dict(seconds=DURATION,
    peak_dbfs=float(20 * np.log10(np.max(np.abs(audio)))),
    rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(audio ** 2)))),
    sha256=hashlib.sha256(path.read_bytes()).hexdigest())
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest["files"]["music/harbor_of_rivals.wav"], indent=2))
print("Loop seam delta:", np.abs(audio[0] - audio[-1]))
