# Harbor audio

**The Blackwater Crew** is an original 80-second, 48-bar pirate shanty in 6/8 at 108 BPM (quarter note), centered on D minor. Accordion leads a jaunty call-and-response melody with fiddle, short bellows chords, plucked guitar, double bass, stomping low drums, and tambourine. Fiddle grace notes and a contrasting higher phrase give the loop movement before the crew returns to the opening tune.

The music is an original composition rendered with macOS's built-in General MIDI instruments through AudioToolbox; the system sound bank is not redistributed. The UI sounds are original procedural synthesis. No paid generation services are used. `manifest.json` records hashes, duration, and measured levels. Regenerate the music on macOS with Python 3 + NumPy: `python3 tools/audio/build_pirate_shanty.py`. The exact score is saved in `music/pirate_shanty_score.json`. `build_harbor_audio.py` regenerates only the UI cues. The rejected first track is retained locally in `art-review/audio-v1/`.

- `music/harbor_of_rivals.wav`: stable runtime filename for The Blackwater Crew; stereo 44.1 kHz / 16-bit PCM. Godot import forces a forward loop. A warm-up cycle preserves instrument releases; circular wooden-room reflections carry across the seam.
- `ui/hover.wav`: quiet, short plucked tick for pointer hover and keyboard focus.
- `ui/click.wav`: wooden tap and bright pluck for button activation.
- `ui/back.wav`: falling two-note cue for back/cancel.
- `ui/confirm.wav`: rising three-note cue after successfully saving a ship.

`MenuAudio` owns one music player and six UI voices. The music stays continuous across main menu, settings, and customization; it fades out when leaving the menu for sailing. Pause menus retain UI audio without starting menu music. Hover signals are deduplicated and initial/programmatic focus is silent. Music and SFX have independent buses, a master limiter, and saved volume controls in Settings → Audio (`user://audio_settings.cfg`).

Listen and adjust the artistic direction in the live menu; the automated checks verify playback behavior and signal levels, not subjective musical quality.
