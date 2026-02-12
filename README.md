# sc-module

A Patchbox OS module that runs a headless SuperCollider FIFO sequencer on a Pisound. Incoming MIDI notes are captured into a 16-slot note bank, and two autonomous voices (bass and alto) cycle through the bank at rhythmic divisions or multiples of the tempo.

## Prerequisites

- Patchbox OS with a working JACK configuration
- SuperCollider (`sclang` / `scsynth`) installed
- A connected MIDI input device

## Install

```
patchbox module install https://github.com/aidanreilly/sc-module
```

## Activate

```
patchbox module activate sc-module
```

Once activated, the module starts automatically on boot.

## How it works

1. **FIFO note bank** — Every incoming MIDI note-on is pushed to the front of a 16-slot FIFO. When the bank is full the oldest note is discarded.
2. **Two voices** — A bass voice on MIDI channel 9 and an alto voice on MIDI channel 10 independently step through the bank from the top, each at their own rhythm.
3. **Tempo sync** — Defaults to 120 BPM. Automatically syncs to incoming MIDI clock (24 PPQ) when present.
4. **Presets** — 10 preset variations control each voice's rhythm, transposition, shuffle, and miss probability. Cycle through them by sending an OSC `/nextPreset` message.

## Presets

Each preset defines 8 parameters per voice pair:

| # | Name | Bass | Alto | Character |
|---|------|------|------|-----------|
| 0 | Unison Pulse | quarter, 0st | quarter, 0st | Both voices in unison, straight |
| 1 | Octave Split | half, -12st | eighth, 0st | Wide spacing, bass drones below |
| 2 | Fifth Shimmer | quarter, 0st | sixteenth, +7st | Alto shimmers a fifth above, shuffled |
| 3 | Walking Bass | eighth, -12st | half, +7st | Bass walks below (shuffled, 5% miss), alto sustains |
| 4 | Cathedral | whole, -12st | quarter, +12st | Two-octave spread, slow and clean |
| 5 | Tight Thirds | eighth, 0st | eighth, +4st | Parallel thirds, both shuffled, 5% alto miss |
| 6 | Syncopated | dotted quarter, -7st | quarter, +5st | 3-against-4 bass feel, shuffled with 5% miss |
| 7 | Double Time | sixteenth, 0st | eighth, 0st | Fast unison energy, alto shuffled with 5% miss |
| 8 | Polyrhythm | dotted quarter, -5st | eighth, +12st | Heavy bass shuffle, alto up an octave, both 5% miss |
| 9 | Contrary Cascade | triplet, +12st | half, -12st | Bass races up, alto drones below, both shuffled |

### Preset parameters

- **Rhythm** — Multiplier of the quarter-note duration. Values >1 divide the tempo (slower); values <1 multiply it (faster).
- **Transpose** — Semitone offset applied to the FIFO note for that voice.
- **Shuffle** — Alternates long/short timing on consecutive steps (0.0 = straight, 0.33 = triplet swing).
- **Miss** — Probability that a step is skipped (note-off / rest instead of note-on).

## Customisation

- Edit `main.scd` to change output channels. SuperCollider uses 0-indexed channel numbers (`~bassChan = 8` for MIDI channel 9, `~altoChan = 9` for channel 10).
- Modify or add entries to `~presets` and `~presetNames` to create new variations.
- The MIDI output is auto-detected by searching `MIDIClient.destinations` for a device named `pisound`. Run `MIDIClient.init; MIDIClient.destinations;` in sclang to list available outputs.
- CC and pitch bend messages are forwarded to both voices.
- Press `Cmd+.` in SuperCollider (or stop the process) to send all-notes-off and halt the sequencer.
