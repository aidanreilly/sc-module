# sc-module

A Patchbox OS module that runs a headless SuperCollider FIFO sequencer on a Pisound. A Keystep (or any MIDI controller sending clock and transport) acts as the master. Incoming notes fill a 5-slot note bank, and two voices (bass and alto) sequence through it when transport is running.

## Prerequisites

- Patchbox OS with a working JACK configuration
- SuperCollider (`sclang` / `scsynth`) installed
- A MIDI controller that sends clock and transport (e.g. Arturia Keystep)

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

1. **Keystep is master** — Clock ticks (24 PPQ) and transport (start/stop/continue) are received from the Keystep and forwarded out the pisound MIDI output so downstream devices stay synced.
2. **FIFO note bank** — Every incoming note-on is pushed to the front of a 5-slot FIFO. When full, the oldest note is discarded.
3. **Stopped** — Notes pass through to MIDI channels 9 and 10 with the current preset's transposition, and simultaneously fill the FIFO. You hear what you play.
4. **Playing** — The bass (ch 9) and alto (ch 10) voices take over, independently stepping through the FIFO at rhythmic divisions or multiples of the clock tempo. Direct note passthrough is disabled.
5. **Presets** — 10 variations control each voice's rhythm, transposition, shuffle, and miss probability. Cycle with OSC `/nextPreset`.

## Presets

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

## MIDI routing

- **Clock in → clock out** — Every clock tick is forwarded to the pisound output.
- **Transport in → transport out** — Start, stop, and continue messages are forwarded.
- **Notes (stopped)** — Passed through to ch 9 and ch 10 with transposition, and stored in the FIFO.
- **Notes (playing)** — Stored in the FIFO only; voices handle output.
- **CC / pitch bend** — Forwarded to both voice channels.

## Customisation

- Edit `main.scd` to change output channels. SuperCollider uses 0-indexed channel numbers (`~bassChan = 8` for MIDI channel 9, `~altoChan = 9` for channel 10).
- Modify or add entries to `~presets` and `~presetNames` to create new variations.
- The MIDI output is auto-detected by searching `MIDIClient.destinations` for a device named `pisound`. Run `MIDIClient.init; MIDIClient.destinations;` in sclang to list available outputs.
- Press `Cmd+.` in SuperCollider (or stop the process) to send all-notes-off, forward a MIDI stop, and halt the sequencer.
