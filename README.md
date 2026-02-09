# sc-module

A Patchbox OS module that runs a headless SuperCollider patch on a Pisound. The included patch reads all incoming MIDI and forwards it on channels 9 and 10.

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

## What the patch does

`main.scd` listens for all MIDI input (notes, CC, pitch bend, aftertouch, program change) and duplicates every message to MIDI channels 9 and 10 via the Pisound MIDI output.

## Customisation

- To change the output channels, edit the `~chans` array in `main.scd`. SuperCollider uses 0-indexed channel numbers, so subtract 1 from the desired MIDI channel (e.g. MIDI channel 8 = `7`, channel 9 = `8`, channel 10 = `9`).
- The MIDI output is auto-detected by searching `MIDIClient.destinations` for a device named `pisound`. The output uses `MIDIOut(port, uid)` to send directly to the Pisound hardware via its uid. Run `MIDIClient.init; MIDIClient.destinations;` in sclang to list available outputs.
