(
s.waitForBoot({
    MIDIClient.init;

    AppClock.sched(3, {
        // === CLEANUP (safe re-evaluation) ===
        if(~bassRoutine.notNil, { ~bassRoutine.stop });
        if(~altoRoutine.notNil, { ~altoRoutine.stop });
        if(~clockRoutine.notNil, { ~clockRoutine.stop });
        if(~allNotesOff.notNil, { ~allNotesOff.value });

        // === MIDI SETUP ===
        ~pisoundSrc = MIDIClient.sources.detect { |ep| ep.device == "pisound" };
        if(~pisoundSrc.notNil, {
            try { MIDIIn.connect(0, ~pisoundSrc.uid) };
            ("MIDI input: " ++ ~pisoundSrc.device ++ " [" ++ ~pisoundSrc.name ++ "]").postln;
        }, {
            "ERROR: pisound not found in MIDI sources".postln;
        });

        ~pisound = MIDIClient.destinations.detect { |ep| ep.device == "pisound" };
        if(~pisound.notNil, {
            ~midiOut = MIDIOut(0, ~pisound.uid);
            ("MIDI output: " ++ ~pisound.device ++ " [" ++ ~pisound.name ++ "]").postln;
        }, {
            "ERROR: pisound not found in MIDI destinations".postln;
            MIDIClient.destinations.do { |ep, i|
                ("  " ++ i ++ ": " ++ ep.device ++ " - " ++ ep.name).postln;
            };
        });
        ~midiOut.latency = 0;

        // === FIFO NOTE BANK (16 slots) ===
        // Incoming notes are pushed to the front; oldest notes fall off the end.
        ~fifoNotes = Array.fill(16, { nil });
        ~fifoVels  = Array.fill(16, { nil });
        ~fifoCount = 0;

        ~pushNote = { |note, vel|
            ~fifoNotes = ([note] ++ ~fifoNotes[0..14]);
            ~fifoVels  = ([vel]  ++ ~fifoVels[0..14]);
            ~fifoCount = min(~fifoCount + 1, 16);
        };

        // === VOICE STATE ===
        // Bass = MIDI channel 9 (0-indexed 8)
        // Alto = MIDI channel 10 (0-indexed 9)
        ~bassChan = 8;
        ~altoChan = 9;
        ~bassIdx  = 0;
        ~altoIdx  = 0;
        ~bassStep = 0;
        ~altoStep = 0;
        ~bassCurrentNote = nil;
        ~altoCurrentNote = nil;

        // === TEMPO & TRANSPORT ===
        // This module is the clock master.
        // BPM default 120, adjustable via CC#14 (range 40–240).
        ~bpm = 120;
        ~quarterDur = 60 / ~bpm;
        ~transportRunning = true;

        ~setBpm = { |newBpm|
            ~bpm = newBpm.clip(40, 240);
            ~quarterDur = 60 / ~bpm;
        };

        // === PRESETS ===
        // Each preset is an 8-element array:
        //   [0] bassRhythm     — quarter-note multiplier (>1 slower, <1 faster)
        //   [1] altoRhythm
        //   [2] bassTranspose  — semitones
        //   [3] altoTranspose
        //   [4] bassShuffle    — 0.0 = straight, 0.33 = triplet swing
        //   [5] altoShuffle
        //   [6] bassMiss       — probability of skipping a note (0.0–1.0)
        //   [7] altoMiss

        ~presetNames = [
            "Unison Pulse",      // 0
            "Octave Split",      // 1
            "Fifth Shimmer",     // 2
            "Walking Bass",      // 3
            "Cathedral",         // 4
            "Tight Thirds",      // 5
            "Syncopated",        // 6
            "Double Time",       // 7
            "Polyrhythm",        // 8
            "Contrary Cascade"   // 9
        ];

        ~presets = [
            //  bassR  altoR  bassT  altoT  bassSh altoSh bassMs altoMs
            [  1.0,   1.0,    0,     0,     0.0,   0.0,   0.0,   0.0  ],  // 0: Unison Pulse — straight, clean
            [  2.0,   0.5,  -12,     0,     0.0,   0.0,   0.0,   0.0  ],  // 1: Octave Split — straight, clean
            [  1.0,   0.25,   0,     7,     0.0,   0.25,  0.0,   0.0  ],  // 2: Fifth Shimmer — alto shuffled
            [  0.5,   2.0,  -12,     7,     0.2,   0.0,   0.05,  0.0  ],  // 3: Walking Bass — bass shuffled, 5% miss
            [  4.0,   1.0,  -12,    12,     0.0,   0.0,   0.0,   0.0  ],  // 4: Cathedral — straight, clean
            [  0.5,   0.5,    0,     4,     0.15,  0.15,  0.0,   0.05 ],  // 5: Tight Thirds — both shuffled, 5% alto miss
            [  1.5,   1.0,   -7,     5,     0.25,  0.0,   0.05,  0.0  ],  // 6: Syncopated — bass shuffled, 5% bass miss
            [  0.25,  0.5,    0,     0,     0.0,   0.2,   0.0,   0.05 ],  // 7: Double Time — alto shuffled, 5% alto miss
            [  1.5,   0.5,   -5,    12,     0.3,   0.0,   0.05,  0.05 ],  // 8: Polyrhythm — bass shuffled, both 5% miss
            [  0.333, 2.0,   12,   -12,     0.2,   0.2,   0.05,  0.0  ]   // 9: Contrary Cascade — both shuffled, 5% bass miss
        ];

        ~presetIndex = 0;
        ~currentPreset = ~presets[0];

        // === HELPERS ===
        ~allNotesOff = {
            if(~bassCurrentNote.notNil, {
                ~midiOut.noteOff(~bassChan, ~bassCurrentNote, 0);
                ~bassCurrentNote = nil;
            });
            if(~altoCurrentNote.notNil, {
                ~midiOut.noteOff(~altoChan, ~altoCurrentNote, 0);
                ~altoCurrentNote = nil;
            });
        };

        ~shuffledDur = { |baseDur, shuffle, step|
            if(shuffle > 0, {
                if((step % 2) == 0, {
                    baseDur * (1 + shuffle);
                }, {
                    baseDur * (1 - shuffle);
                });
            }, {
                baseDur;
            });
        };

        // === MIDI CLOCK OUTPUT ===
        // This module is the clock master — sends 24 PPQ clock ticks
        // and transport start/stop out the pisound MIDI output.
        ~clockRoutine = Routine({
            ~midiOut.start;
            ">>> Clock master: transport START".postln;
            loop {
                if(~transportRunning, {
                    ~midiOut.midiClock;
                });
                (~quarterDur / 24).wait;
            }
        }).play(SystemClock);

        // === BASS VOICE ROUTINE ===
        ~bassRoutine = Routine({
            loop {
                if(~transportRunning, {
                    var baseDur, dur;
                    baseDur = ~quarterDur * ~currentPreset[0];
                    dur = ~shuffledDur.value(baseDur, ~currentPreset[4], ~bassStep);

                    if(~fifoCount > 0, {
                        if(1.0.rand >= ~currentPreset[6], {
                            var note, vel, out;
                            note = ~fifoNotes[~bassIdx % ~fifoCount];
                            vel  = ~fifoVels[~bassIdx % ~fifoCount];
                            out  = (note + ~currentPreset[2]).clip(0, 127);

                            if(~bassCurrentNote.notNil, {
                                ~midiOut.noteOff(~bassChan, ~bassCurrentNote, 0);
                            });
                            ~midiOut.noteOn(~bassChan, out, vel);
                            ~bassCurrentNote = out;
                        }, {
                            if(~bassCurrentNote.notNil, {
                                ~midiOut.noteOff(~bassChan, ~bassCurrentNote, 0);
                                ~bassCurrentNote = nil;
                            });
                        });
                        ~bassIdx = (~bassIdx + 1) % 16;
                    });

                    ~bassStep = ~bassStep + 1;
                    dur.wait;
                }, {
                    0.05.wait;
                });
            }
        }).play(SystemClock);

        // === ALTO VOICE ROUTINE ===
        ~altoRoutine = Routine({
            loop {
                if(~transportRunning, {
                    var baseDur, dur;
                    baseDur = ~quarterDur * ~currentPreset[1];
                    dur = ~shuffledDur.value(baseDur, ~currentPreset[5], ~altoStep);

                    if(~fifoCount > 0, {
                        if(1.0.rand >= ~currentPreset[7], {
                            var note, vel, out;
                            note = ~fifoNotes[~altoIdx % ~fifoCount];
                            vel  = ~fifoVels[~altoIdx % ~fifoCount];
                            out  = (note + ~currentPreset[3]).clip(0, 127);

                            if(~altoCurrentNote.notNil, {
                                ~midiOut.noteOff(~altoChan, ~altoCurrentNote, 0);
                            });
                            ~midiOut.noteOn(~altoChan, out, vel);
                            ~altoCurrentNote = out;
                        }, {
                            if(~altoCurrentNote.notNil, {
                                ~midiOut.noteOff(~altoChan, ~altoCurrentNote, 0);
                                ~altoCurrentNote = nil;
                            });
                        });
                        ~altoIdx = (~altoIdx + 1) % 16;
                    });

                    ~altoStep = ~altoStep + 1;
                    dur.wait;
                }, {
                    0.05.wait;
                });
            }
        }).play(SystemClock);

        // === INCOMING NOTES -> FIFO ===
        MIDIdef.noteOn(\noteIn, { |vel, note, chan, src|
            ~pushNote.value(note, vel);
        });

        MIDIdef.noteOff(\noteOffIn, { |vel, note, chan, src|
        });

        // === CC HANDLING ===
        // CC#14 → BPM (0–127 maps to 40–240 BPM)
        // All other CCs are forwarded to both voice channels.
        MIDIdef.cc(\ccIn, { |val, num, chan, src|
            if(num == 14, {
                var newBpm = val.linlin(0, 127, 40, 240).round(1);
                ~setBpm.value(newBpm);
                (">>> BPM: " ++ ~bpm).postln;
            }, {
                [~bassChan, ~altoChan].do { |ch| ~midiOut.control(ch, num, val) };
            });
        });

        MIDIdef.bend(\bendFwd, { |val, chan, src|
            [~bassChan, ~altoChan].do { |ch| ~midiOut.bend(ch, val) };
        });

        // === PRESET SWITCHING ===
        OSCdef(\nextPreset, { |msg|
            ~allNotesOff.value;
            ~presetIndex = (~presetIndex + 1) % ~presets.size;
            ~currentPreset = ~presets[~presetIndex];
            ~bassIdx = 0;
            ~altoIdx = 0;
            ~bassStep = 0;
            ~altoStep = 0;
            (">>> Preset " ++ ~presetIndex ++ ": " ++ ~presetNames[~presetIndex]).postln;
            ("    Bass: x" ++ ~currentPreset[0] ++ " | " ++ ~currentPreset[2] ++ "st | shuf:" ++ ~currentPreset[4] ++ " miss:" ++ ~currentPreset[6]).postln;
            ("    Alto: x" ++ ~currentPreset[1] ++ " | " ++ ~currentPreset[3] ++ "st | shuf:" ++ ~currentPreset[5] ++ " miss:" ++ ~currentPreset[7]).postln;
        }, '/nextPreset');

        // === TRANSPORT CONTROL VIA OSC ===
        OSCdef(\transportStart, { |msg|
            if(~transportRunning.not, {
                ~transportRunning = true;
                ~midiOut.start;
                ">>> Transport START".postln;
            });
        }, '/transportStart');

        OSCdef(\transportStop, { |msg|
            if(~transportRunning, {
                ~transportRunning = false;
                ~allNotesOff.value;
                ~midiOut.stop;
                ~fifoNotes = Array.fill(16, { nil });
                ~fifoVels  = Array.fill(16, { nil });
                ~fifoCount = 0;
                ~bassIdx = 0;
                ~altoIdx = 0;
                ~bassStep = 0;
                ~altoStep = 0;
                ">>> Transport STOP".postln;
            });
        }, '/transportStop');

        // === CMDPERIOD CLEANUP ===
        CmdPeriod.doOnce({
            ~allNotesOff.value;
            ~midiOut.stop;
            "Sequencer stopped, clock stopped".postln;
        });

        // === STATUS ===
        "".postln;
        "=== FIFO Sequencer (clock master) ===".postln;
        "Bass: ch9 | Alto: ch10".postln;
        ("Preset 0: " ++ ~presetNames[0]).postln;
        ("BPM: " ++ ~bpm ++ " (CC#14 to change, 0–127 → 40–240)").postln;
        "Clock + transport running — play notes to fill FIFO".postln;
        "OSC /nextPreset, /transportStart, /transportStop".postln;
        "".postln;

        nil;
    });
});
)
