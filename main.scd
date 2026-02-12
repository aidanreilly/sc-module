(
s.waitForBoot({

    MIDIClient.init;

    AppClock.sched(3, {

        // ==============================
        // CLEANUP
        // ==============================
        if(~bassRoutine.notNil, { ~bassRoutine.stop });
        if(~altoRoutine.notNil, { ~altoRoutine.stop });
        if(~allNotesOff.notNil, { ~allNotesOff.value });

        // ==============================
        // MIDI INPUT
        // ==============================
        "MIDI sources:".postln;
        MIDIClient.sources.do { |src, i|
            ("  " ++ i.asString ++ ": " ++ src.device ++ " - " ++ src.name).postln;
        };

        ~pisoundSrcIdx = MIDIClient.sources.indexOf(
            MIDIClient.sources.detect { |ep| ep.device == "pisound" }
        );

        if(~pisoundSrcIdx.notNil) {
            MIDIIn.connect(~pisoundSrcIdx);
            ("MIDI input connected: pisound (index " ++ ~pisoundSrcIdx.asString ++ ")").postln;
        }{
            "ERROR: pisound source not found".postln;
        };

        // ==============================
        // MIDI OUTPUT
        // ==============================
        ~pisoundDest = MIDIClient.destinations.detect { |ep| ep.device == "pisound" };

        if(~pisoundDest.notNil) {
            ~midiOut = MIDIOut.newByName(~pisoundDest.device, ~pisoundDest.name);
            ("MIDI output: " ++ ~pisoundDest.device ++ " [" ++ ~pisoundDest.name ++ "]").postln;
        }{
            "ERROR: pisound destination not found".postln;
        };

        ~midiOut.latency = 0;

        // ==============================
        // FIFO NOTE BANK
        // ==============================
        ~fifoNotes = Array.fill(5, { nil });
        ~fifoVels  = Array.fill(5, { nil });
        ~fifoCount = 0;

        ~pushNote = { |note, vel|
            ~fifoNotes = ([note] ++ ~fifoNotes[0..3]);
            ~fifoVels  = ([vel]  ++ ~fifoVels[0..3]);
            ~fifoCount = min(~fifoCount + 1, 5);
        };

        // ==============================
        // VOICE STATE
        // ==============================
        ~bassChan = 8;
        ~altoChan = 9;

        ~bassIdx = 0;
        ~altoIdx = 0;
        ~bassStep = 0;
        ~altoStep = 0;

        ~bassCurrentNote = nil;
        ~altoCurrentNote = nil;

        // ==============================
        // TRANSPORT
        // ==============================
        ~transportRunning = false;
        ~tempoReady = false;

        ~quarterDur = 0.5;
        ~bpm = 120;

        ~lastClockTime = nil;
        ~clockTicks = 0;
        ~clockIntervals = Array.fill(24, { 60 / (120 * 24) });

        // ==============================
        // PRESETS
        // ==============================
        ~presetNames = [
            "Unison Pulse",
            "Octave Split",
            "Fifth Shimmer",
            "Walking Bass",
            "Cathedral",
            "Tight Thirds",
            "Syncopated",
            "Double Time",
            "Polyrhythm",
            "Contrary Cascade"
        ];

        ~presets = [
            [1.0,1.0,0,0,0,0,0,0],
            [2.0,0.5,-12,0,0,0,0,0],
            [1.0,0.25,0,7,0,0.25,0,0],
            [0.5,2.0,-12,7,0.2,0,0.05,0],
            [4.0,1.0,-12,12,0,0,0,0],
            [0.5,0.5,0,4,0.15,0.15,0,0.05],
            [1.5,1.0,-7,5,0.25,0,0.05,0],
            [0.25,0.5,0,0,0,0.2,0,0.05],
            [1.5,0.5,-5,12,0.3,0,0.05,0.05],
            [0.333,2.0,12,-12,0.2,0.2,0.05,0]
        ];

        ~presetIndex = 0;
        ~currentPreset = ~presets[0];

        // ==============================
        // HELPERS
        // ==============================
        ~allNotesOff = {
            if(~bassCurrentNote.notNil) {
                ~midiOut.noteOff(~bassChan, ~bassCurrentNote, 0);
                ~bassCurrentNote = nil;
            };
            if(~altoCurrentNote.notNil) {
                ~midiOut.noteOff(~altoChan, ~altoCurrentNote, 0);
                ~altoCurrentNote = nil;
            };
        };

        ~shuffledDur = { |baseDur, shuffle, step|
            if(shuffle > 0) {
                if((step % 2) == 0) {
                    baseDur * (1 + shuffle)
                }{
                    baseDur * (1 - shuffle)
                }
            }{
                baseDur
            }
        };

        // ==============================
        // BASS ROUTINE
        // ==============================
        ~bassRoutine = Routine({
            loop {
                if(~transportRunning && ~tempoReady) {

                    var baseDur = ~quarterDur * ~currentPreset[0];
                    var dur = ~shuffledDur.(baseDur, ~currentPreset[4], ~bassStep);

                    if(~fifoCount > 0) {
                        if(1.0.rand >= ~currentPreset[6]) {
                            var note = ~fifoNotes[~bassIdx % ~fifoCount];
                            var vel  = ~fifoVels[~bassIdx % ~fifoCount];
                            var out  = (note + ~currentPreset[2]).clip(0,127);

                            if(~bassCurrentNote.notNil) {
                                ~midiOut.noteOff(~bassChan, ~bassCurrentNote, 0);
                            };

                            ~midiOut.noteOn(~bassChan, out, vel);
                            ~bassCurrentNote = out;
                        };

                        ~bassIdx = (~bassIdx + 1) % 5;
                    };

                    ~bassStep = ~bassStep + 1;
                    dur.wait;
                }{
                    0.05.wait;
                };
            };
        }).play(SystemClock);

        // ==============================
        // ALTO ROUTINE
        // ==============================
        ~altoRoutine = Routine({
            loop {
                if(~transportRunning && ~tempoReady) {

                    var baseDur = ~quarterDur * ~currentPreset[1];
                    var dur = ~shuffledDur.(baseDur, ~currentPreset[5], ~altoStep);

                    if(~fifoCount > 0) {
                        if(1.0.rand >= ~currentPreset[7]) {
                            var note = ~fifoNotes[~altoIdx % ~fifoCount];
                            var vel  = ~fifoVels[~altoIdx % ~fifoCount];
                            var out  = (note + ~currentPreset[3]).clip(0,127);

                            if(~altoCurrentNote.notNil) {
                                ~midiOut.noteOff(~altoChan, ~altoCurrentNote, 0);
                            };

                            ~midiOut.noteOn(~altoChan, out, vel);
                            ~altoCurrentNote = out;
                        };

                        ~altoIdx = (~altoIdx + 1) % 5;
                    };

                    ~altoStep = ~altoStep + 1;
                    dur.wait;
                }{
                    0.05.wait;
                };
            };
        }).play(SystemClock);

        // ==============================
        // REALTIME THRU + TEMPO DERIVE
        // ==============================
        MIDIIn.addFuncTo(\sysrt, { |src, index|

            case
            { index == 8 } {
                // Clock tick (0xF8)
                var now = SystemClock.seconds;
                ~midiOut.midiClock;

                if(~lastClockTime.notNil) {
                    var interval = now - ~lastClockTime;
                    ~clockIntervals[~clockTicks % 24] = interval;
                    ~clockTicks = ~clockTicks + 1;

                    if((~clockTicks % 24) == 0) {
                        ~quarterDur = ~clockIntervals.mean * 24;
                        ~bpm = (60 / ~quarterDur).round(0.1);
                        ~tempoReady = true;
                    };
                };

                ~lastClockTime = now;
            }
            { index == 10 } {
                // Start (0xFA)
                ~midiOut.start;
                ~transportRunning = true;
                ~bassIdx = 0;
                ~altoIdx = 0;
                ~bassStep = 0;
                ~altoStep = 0;
                ">>> Transport START".postln;
            }
            { index == 11 } {
                // Continue (0xFB)
                ~midiOut.continue;
                ~transportRunning = true;
                ">>> Transport CONTINUE".postln;
            }
            { index == 12 } {
                // Stop (0xFC)
                ~midiOut.stop;
                ~transportRunning = false;
                ~allNotesOff.value;
                ~bassIdx = 0;
                ~altoIdx = 0;
                ~bassStep = 0;
                ~altoStep = 0;
                ">>> Transport STOP".postln;
            };
        });

        // ==============================
        // NOTE INPUT
        // ==============================
        MIDIdef.noteOn(\noteIn, { |vel, note|
            ~pushNote.(note, vel);

            if(~transportRunning.not) {
                ~midiOut.noteOn(~bassChan, (note + ~currentPreset[2]).clip(0,127), vel);
                ~midiOut.noteOn(~altoChan, (note + ~currentPreset[3]).clip(0,127), vel);
            };
        });

        MIDIdef.noteOff(\noteOffIn, { |vel, note|
            if(~transportRunning.not) {
                ~midiOut.noteOff(~bassChan, (note + ~currentPreset[2]).clip(0,127), vel);
                ~midiOut.noteOff(~altoChan, (note + ~currentPreset[3]).clip(0,127), vel);
            };
        });

        nil;

    });

});
)
