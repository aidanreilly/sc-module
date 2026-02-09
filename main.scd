(
s.waitForBoot({
    MIDIClient.init;

    AppClock.sched(3, {
        MIDIIn.connectAll;

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

        "MIDI Thru active: forwarding all input to channels 9 and 10".postln;

        MIDIdef.noteOn(\noteOnThru, { |vel, note, chan, src|
            ~chans.do { |ch| ~midiOut.noteOn(ch, note, vel) };
        });

        MIDIdef.noteOff(\noteOffThru, { |vel, note, chan, src|
            ~chans.do { |ch| ~midiOut.noteOff(ch, note, vel) };
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
            ~chans.do { |ch| ~midiOut.polytouch(ch, note, val) };
        });

        MIDIdef.program(\programThru, { |val, chan, src|
            ~chans.do { |ch| ~midiOut.program(ch, val) };
        });

        nil;
    });
});
)
