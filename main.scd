(
s.waitForBoot({
    MIDIClient.init;

    AppClock.sched(3, {
        try { MIDIIn.connectAll } { |err|
            ("MIDI connectAll: " ++ err.errorString ++ " (continuing)").postln;
        };

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

        // MIDI channels are 0-indexed: ch9 = 8, ch10 = 9
        ~chans = [8, 9];

        // Preset pairs: [ch9_transposition, ch10_transposition] in semitones
        ~presets = [
            [0, 0],      // Unison
            [7, 12],     // Fifth + Octave
            [12, 19],    // Octave + Octave+Fifth
            [4, 7],      // Third + Fifth
            [-12, 12],   // Down Octave + Up Octave
            [3, 4],      // Minor Third + Major Third
        ];
        ~presetIndex = 0;
        ~transpose = ~presets[0];

        OSCdef(\nextPreset, { |msg|
            ~presetIndex = (~presetIndex + 1) % ~presets.size;
            ~transpose = ~presets[~presetIndex];
            ("Preset " ++ ~presetIndex ++ ": ch9=" ++ ~transpose[0] ++ " ch10=" ++ ~transpose[1]).postln;
        }, '/nextPreset');

        "MIDI Thru active: forwarding all input to channels 9 and 10".postln;
        ("Preset " ++ ~presetIndex ++ ": ch9=" ++ ~transpose[0] ++ " ch10=" ++ ~transpose[1]).postln;

        MIDIdef.noteOn(\noteOnThru, { |vel, note, chan, src|
            ~chans.do { |ch, i|
                ~midiOut.noteOn(ch, (note + ~transpose[i]).clip(0, 127), vel);
            };
        });

        MIDIdef.noteOff(\noteOffThru, { |vel, note, chan, src|
            ~chans.do { |ch, i|
                ~midiOut.noteOff(ch, (note + ~transpose[i]).clip(0, 127), vel);
            };
        });

        MIDIdef.cc(\ccThru, { |val, num, chan, src|
            ~chans.do { |ch| ~midiOut.control(ch, num, val) };
        });

        MIDIdef.bend(\bendThru, { |val, chan, src|
            ~chans.do { |ch| ~midiOut.bend(ch, val) };
        });

        MIDIdef.touch(\touchThru, { |val, chan, src|
            ~chans.do { |ch| ~midiOut.touch(ch, val) };
        });

        MIDIdef.polytouch(\polytouchThru, { |val, note, chan, src|
            ~chans.do { |ch, i|
                ~midiOut.polytouch(ch, (note + ~transpose[i]).clip(0, 127), val);
            };
        });

        MIDIdef.program(\programThru, { |val, chan, src|
            ~chans.do { |ch| ~midiOut.program(ch, val) };
        });

        nil;
    });
});
)
