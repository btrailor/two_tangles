// Engine_TwoTangles.sc
// Dual shift register synthesis engine

Engine_TwoTangles : CroneEngine {
    var <voices;
    var <shiftRegA, <shiftRegB;
    var <clockA, <clockB;
    var <patchMatrix;
    var <stageOutputs;
    var <logicProcessors;
    var <synthBus;
    var <voiceParams;
    var <voiceParamsTarget;
    var <slewRoutine;
    var <stageProbability;
    var <stageMappings;
    var <slewMode;
    var <slewTime;
    var <unpatchedBehavior;
    var <multiPatchMode;
    var <globalFeedback;
    var <voiceCount;  // Number of active voices (2 or 4)
    var <voiceModMatrix;  // Voice modulation routing matrix
    var <sources;  // External sources for patching (random, low, mid, high, max, param1, param2)
    
    // Pitch quantization
    var <quantizeScales;     // Array of scale definitions
    var <voiceQuantizeScale; // Array[voiceCount] of scale indices
    var <voiceRootNote;      // Array[voiceCount] of root notes (0-11, C-B)

    // Clock parameters
    var <tempo;
    var <clockDivA, <clockDivB;
    var <clockRunning;
    var <beatCount;
    var <externalSync;
    var <swing;
    var <swingSubdiv;
    var <resetOnDownbeat;
    var <barLength;
    var <clockARunning;
    var <clockBRunning;
    var <midiClockIn;
    var <clockSource;
    
    // Performance macro parameters
    var <registerAMuted;
    var <registerBMuted;
    var <globalMute;
    var <freezeA;
    var <freezeB;
    var <patternLengthA;
    var <patternLengthB;
    var <clockMultiplierA;
    var <clockMultiplierB;
    var <feedbackAmount;
    var <chaosAmount;
    var <mutationRate;
    
    // Self-seeding parameters
    var <seedModeA;  // 0=random, 1=low(0.25), 2=mid(0.5), 3=high(0.75), 4=chaos
    var <seedModeB;
    
    // Gate routing
    var <gateRouteA1, <gateRouteA2, <gateRouteB1, <gateRouteB2;
    var <activeStagesA, <activeStagesB;  // Track active stages for gate routing
    
    // Audio input modulation
    var <audioInputBus;
    var <audioAnalyzer;
    var <inputModAmount;
    var <inputModTarget;
    var <inputFollower;
    var <inputPitch;
    var <inputEnvelope;
    var <inputPitchValue;
    var <inputModReg;
    var <inputGain;
    var <inputSmoothing;
    
    // Modulation matrix
    var <modMatrix;
    var <modSources;
    var <modDestinations;
    var <lfoSynths;
    var <lfoBuses;
    var <lfoRates;
    var <lfoShapes;
    
    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }
    
    alloc {
        // Audio buses
        synthBus = Array.fill(2, { Bus.audio(context.server, 1) });
        audioInputBus = Bus.audio(context.server, 1);
        
        // Initialize shift registers with zeros
        // They'll be seeded when patches are created
        shiftRegA = Array.fill(8, { 0 });
        shiftRegB = Array.fill(8, { 0 });

        // Patch matrix
        patchMatrix = List.new;

        // Stage outputs - start at zero
        stageOutputs = Dictionary.newFrom([
            \a, Array.fill(8, { 0 }),
            \b, Array.fill(8, { 0 })
        ]);
        
        // Stage probabilities
        stageProbability = Dictionary.newFrom([
            \a, Array.fill(8, { 1.0 }),
            \b, Array.fill(8, { 1.0 })
        ]);
        
        // Stage mappings
        stageMappings = Dictionary.newFrom([
            \a, Array.fill(8, { 0 }),
            \b, Array.fill(8, { 0 })
        ]);

        // External sources for patching
        sources = Dictionary.newFrom([
            \random, 0.5,      // Updated each step with random value
            \low, 0.25,        // Constant low value
            \mid, 0.5,         // Constant mid value
            \high, 0.75,       // Constant high value
            \max, 1.0,         // Constant max value
            \param1, 0.5,      // Encoder 1
            \param2, 0.5,      // Encoder 2
            \voice1, 0.5,      // Voice 1 oscillator output
            \voice2, 0.5       // Voice 2 oscillator output
        ]);

        // Voice parameters
        slewMode = 0;
        slewTime = 0.05;
        unpatchedBehavior = 0;
        multiPatchMode = 0;
        globalFeedback = 1.0;
        voiceCount = 2;  // Default to 2 voices, can be set to 4

        // Voice modulation matrix: voice -> list of [srcType, srcIndex, param, amount]
        // srcType: \regA or \regB, srcIndex: 0-7, param: symbol, amount: 0.0-1.0
        voiceModMatrix = Array.fill(4, { List.new });

        voiceParams = Array.fill(4, { 
            Dictionary.newFrom([
                \pitch, 440,
                \gate, 0,
                \filterFreq, 2000,
                \filterRes, 0.3,
                \waveShape, 0,
                \amp, 0.5,
                \fmAmount, 0,
                \fmRatio, 1,
                \subOscMix, 0,
                \pan, 0,
                \pulseWidth, 0.5,
                \noiseAmount, 0
            ])
        });
        
        voiceParamsTarget = Array.fill(4, { 
            Dictionary.newFrom([
                \pitch, 440,
                \filterFreq, 2000,
                \filterRes, 0.3,
                \waveShape, 0,
                \fmAmount, 0,
                \fmRatio, 1,
                \subOscMix, 0,
                \pan, 0,
                \pulseWidth, 0.5,
                \noiseAmount, 0
            ])
        });
        
        // Pitch quantization
        voiceQuantizeScale = Array.fill(4, { 0 });  // 0 = chromatic (off)
        voiceRootNote = Array.fill(4, { 0 });       // 0 = C
        this.initQuantizeScales;
        
        // Clock parameters
        tempo = 120;
        clockDivA = 1;
        clockDivB = 1;
        clockRunning = false;
        clockARunning = true;
        clockBRunning = true;
        beatCount = 0;
        externalSync = false;
        swing = 0.5;
        swingSubdiv = 2;
        resetOnDownbeat = false;
        barLength = 16;
        clockSource = 0;
        
        // Performance macros
        registerAMuted = false;
        registerBMuted = false;
        globalMute = false;
        freezeA = false;
        freezeB = false;
        patternLengthA = 8;
        patternLengthB = 8;
        clockMultiplierA = 1.0;
        clockMultiplierB = 1.0;
        feedbackAmount = 1.0;
        chaosAmount = 0.0;
        mutationRate = 0.0;
        
        // Self-seeding modes: 0=random, 1=low, 2=mid, 3=high (0.75 = drone), 4=chaos
        seedModeA = 3;  // Default to high (drone)
        seedModeB = 3;
        
        // Hardwired gate routing (registers directly trigger voices)
        gateRouteA1 = true;   // Register A → Voice 1 (default on)
        gateRouteA2 = false;  // Register A → Voice 2
        gateRouteB1 = true;   // Register B → Voice 1 (default on)
        gateRouteB2 = false;  // Register B → Voice 2
        
        // Active stage tracking for gate routing
        activeStagesA = Array.fill(8, { 0 });
        activeStagesB = Array.fill(8, { 0 });
        
        // Audio input
        inputModAmount = 0.0;
        inputModTarget = 2;
        inputModReg = 2;
        inputGain = 1.0;
        inputSmoothing = 0.1;
        inputEnvelope = 0.0;
        inputPitchValue = 440;
        
        // Modulation matrix
        modMatrix = List.new;
        lfoRates = Array.fill(4, { 1.0 });
        lfoShapes = Array.fill(4, { 0 });
        
        // Initialize
        this.initLogicProcessors;
        this.makeVoices;
        this.makeLFOs;
        this.makeAudioInputAnalyzers;
        this.makeClocks;
        this.addCommands;
        this.connectMIDIClock;
    }
    
    initLogicProcessors {
        logicProcessors = Dictionary.newFrom([
            0, { arg val1, val2; val1 },
            1, { arg val1, val2; 
                if((val1 > 0.5) && (val2 > 0.5), { 
                    (val1 + val2) * 0.5
                }, { 
                    0.0
                })
            },
            2, { arg val1, val2;
                if((val1 > 0.5) || (val2 > 0.5), {
                    max(val1, val2)
                }, {
                    0.0
                })
            },
            3, { arg val1, val2;
                var high1 = val1 > 0.5;
                var high2 = val2 > 0.5;
                if(high1 != high2, {
                    max(val1, val2)
                }, {
                    0.0
                })
            },
            4, { arg val1, val2;
                (val1 + val2).clip(0.0, 1.0)
            },
            5, { arg val1, val2;
                val1 * val2
            },
            6, { arg val1, val2;
                (val1 - val2).abs
            },
            7, { arg val1, val2;
                min(val1, val2)
            },
            8, { arg val1, val2;
                max(val1, val2)
            },
            9, { arg val1, val2;
                (val1 + val2) * 0.5
            },
            10, { arg val1, val2;
                1.0 - val1
            },
            11, { arg val1, val2;
                if(val1 > val2, { 1.0 }, { 0.0 })
            },
            12, { arg val1, val2;
                if(val2 > 0.01, {
                    (val1 / val2).frac
                }, {
                    val1
                })
            }
        ]);
    }
    
    makeVoices {
        // Persistent voices with gate-based ADSR for drones
        var voiceDef = SynthDef(\ttVoice, {
            arg out=0,
            freq=440,
            gate=0,
            amp=0.3,
            waveShape=0,
            filterFreq=2000,
            filterRes=0.3,
            fmAmount=0,
            fmRatio=1,
            pulseWidth=0.5,
            subOscMix=0,
            noiseAmount=0,
            pan=0,
            voiceIndex=0;

            var sig, env, filt, fmMod, subOsc, noise, mixed, sample;

            // FM modulation - limit the amount
            fmMod = SinOsc.ar(freq * fmRatio.clip(0.5, 8)) * fmAmount.clip(0, 500);

            // Multiple oscillators with FM
            sig = SelectX.ar(waveShape.clip(0, 2.99), [
                SinOsc.ar(freq + fmMod),
                LFTri.ar(freq + fmMod),
                LFSaw.ar(freq + fmMod),
                Pulse.ar(freq + fmMod, pulseWidth.clip(0.1, 0.9))
            ]);

            // Sub oscillator and noise
            subOsc = LFTri.ar(freq * 0.5);
            noise = WhiteNoise.ar() * noiseAmount.clip(0, 0.3);  // Limit noise amount
            mixed = (sig * (1 - subOscMix.clip(0, 1))) + (subOsc * subOscMix.clip(0, 1)) + noise;

            // Filter
            filt = RLPF.ar(
                mixed,
                filterFreq.clip(100, 18000),
                filterRes.clip(0.1, 1.0).linexp(0.1, 1.0, 1.0, 0.1)
            );

            // Clean up signal
            filt = LeakDC.ar(filt);
            filt = filt.clip2(0.8);

            // Send audio signal sample for voice 1 and 2 (for LED animation)
            // Use Amplitude follower instead of Peak
            sample = Amplitude.kr(filt, attackTime: 0.01, releaseTime: 0.1);
            SendReply.kr(Impulse.kr(60), '/ttVoiceSignal', [voiceIndex, sample]);

            // ADSR envelope for drones - responds to gate
            env = EnvGen.kr(
                Env.adsr(
                    attackTime: 0.01,
                    decayTime: 0.1,
                    sustainLevel: 1.0,
                    releaseTime: 0.3
                ),
                gate: gate,
                doneAction: 0  // Don't free - keep synth alive
            );

            Out.ar(out, Pan2.ar(filt * env * amp, pan.clip(-1, 1)));
        }).add;

        context.server.sync;

        // Create 4 persistent voices (only voiceCount will be actively used)
        voices = Array.fill(4, { arg i;
            Synth(\ttVoice, [
                \out, 0,
                \gate, 0,
                \amp, 0.5,
                \voiceIndex, i
            ], target: context.xg);
        });

        slewRoutine = Array.fill(4, { arg i;
            this.makeSlewRoutine(i);
        });
    }
    
    makeSlewRoutine { arg voiceNum;
        ^Task({
            var current, target, delta, steps, stepSize;
            var updateRate = 0.005;
            
            inf.do {
                if(slewMode == 1, {
                    voiceParamsTarget[voiceNum].keysValuesDo { arg key, targetVal;
                        current = voiceParams[voiceNum][key];
                        
                        if(current != targetVal, {
                            steps = (slewTime / updateRate).ceil;
                            delta = targetVal - current;
                            stepSize = delta / steps;
                            
                            voiceParams[voiceNum][key] = current + stepSize;
                            voices[voiceNum].set(key, current + stepSize);
                        });
                    };
                });
                
                updateRate.wait;
            };
        });
    }
    
    makeLFOs {
        lfoBuses = Array.fill(4, { Bus.control(context.server, 1) });
        
        SynthDef(\ttLFO, { arg outBus=0, rate=1.0, shape=0;
            var sig;
            
            sig = SelectX.kr(shape.clip(0, 4), [
                SinOsc.kr(rate),
                LFTri.kr(rate),
                LFSaw.kr(rate),
                LFPulse.kr(rate, width: 0.5),
                LFNoise1.kr(rate)
            ]);
            
            sig = sig.range(0, 1);
            Out.kr(outBus, sig);
        }).add;
        
        context.server.sync;
        
        lfoSynths = Array.fill(4, { arg i;
            Synth(\ttLFO, [
                \outBus, lfoBuses[i],
                \rate, lfoRates[i],
                \shape, lfoShapes[i]
            ], target: context.xg);
        });
    }
    
    makeAudioInputAnalyzers {
        SynthDef(\ttInputFollower, { arg inBus=0, outBus=0, gain=1.0, smoothing=0.1;
            var input, amplitude;
        
            input = SoundIn.ar(inBus) * gain;
            amplitude = Amplitude.kr(input, 
                attackTime: smoothing * 0.5, 
                releaseTime: smoothing
            );
        
            SendReply.kr(Impulse.kr(20), '/ttInputAmp', amplitude);
            Out.ar(outBus, input);
        }).add;
    
        SynthDef(\ttInputPitch, { arg inBus=0;
            var input, freq, hasFreq;
        
            input = In.ar(inBus, 1);
            # freq, hasFreq = Pitch.kr(input,
                initFreq: 440,
                minFreq: 60,
                maxFreq: 4000,
                execFreq: 100,
                maxBinsPerOctave: 16,
                median: 1,
                ampThreshold: 0.02,
                peakThreshold: 0.5,
                downSample: 1
            );
        
            freq = Select.kr(hasFreq, [440, freq]);
            SendReply.kr(Impulse.kr(20), '/ttInputPitch', freq);
        }).add;
    
        context.server.sync;
    
        inputFollower = Synth(\ttInputFollower, [
            \inBus, 0,
            \outBus, audioInputBus,
            \gain, inputGain,
            \smoothing, inputSmoothing
        ], target: context.ig);
    
        audioAnalyzer = Synth(\ttInputPitch, [
            \inBus, audioInputBus
        ], target: context.xg, addAction: \addAfter);
    
        OSCdef(\ttInputAmp, { arg msg;
            inputEnvelope = msg[3];
            // Don't call sendInputValues here - it creates a loop
        }, '/ttInputAmp');

        OSCdef(\ttInputPitch, { arg msg;
            inputPitchValue = msg[3];
        }, '/ttInputPitch');

        OSCdef(\ttVoiceSignal, { arg msg;
            var voiceIndex = msg[3];
            var sample = msg[4];
            var addr = NetAddr.new("127.0.0.1", 10111);
            // Forward to Lua
            addr.sendMsg('/ttVoiceSignal', voiceIndex, sample);
        }, '/ttVoiceSignal');
    }
    
    connectMIDIClock {
        MIDIIn.connectAll;
    
        // MIDI Clock (0xF8) handler
        midiClockIn = MIDIFunc.sysrt({ arg src, chan, type;
            if(type == 8, {  // 8 = MIDI Clock (0xF8)
                if(clockSource == 1, {
                    if(clockRunning, {
                        beatCount = beatCount + 1;
                        
                        if(beatCount % 24 == 0, {
                            this.clockTick;
                        });
                    });
                });
            });
        });
        
        // MIDI Start (0xFA)
        MIDIFunc.sysrt({ arg src, chan, type;
            if(type == 10, {  // 10 = MIDI Start (0xFA)
                if(clockSource == 1, {
                    this.startClock;
                });
            });
        });
        
        // MIDI Stop (0xFC)
        MIDIFunc.sysrt({ arg src, chan, type;
            if(type == 12, {  // 12 = MIDI Stop (0xFC)
                if(clockSource == 1, {
                    this.stopClock;
                });
            });
        });
        
        // MIDI Continue (0xFB)
        MIDIFunc.sysrt({ arg src, chan, type;
            if(type == 11, {  // 11 = MIDI Continue (0xFB)
                if(clockSource == 1, {
                    this.startClock;
                });
            });
        });
    }
    
    makeClocks {
        clockA = Routine({
            var beatDuration, stepsSinceLastTrigger = 0;
            var swingDelay, evenBeat = true;
            
            loop {
                if(clockRunning && clockARunning && (clockSource == 0), {
                    beatDuration = 60.0 / (tempo * clockMultiplierA);
                    
                    swingDelay = if(evenBeat, {
                        0;
                    }, {
                        (swing - 0.5) * 2 * beatDuration;
                    });
                    
                    if(beatCount % swingSubdiv == 0, {
                        evenBeat = true;
                    }, {
                        evenBeat = evenBeat.not;
                    });
                    
                    if(stepsSinceLastTrigger >= clockDivA, {
                        if(clockARunning, {
                            this.stepShiftRegister(\a);
                        });
                        stepsSinceLastTrigger = 0;
                    });
                    
                    stepsSinceLastTrigger = stepsSinceLastTrigger + 1;
                    beatCount = beatCount + 1;
                    
                    if(resetOnDownbeat && (beatCount % barLength == 0), {
                        this.resetRegisters;
                    });
                    
                    (beatDuration + swingDelay).wait;
                }, {
                    0.1.wait;
                });
            };
        });
        
        clockB = Routine({
            var beatDuration, stepsSinceLastTrigger = 0;
            var swingDelay, evenBeat = true;
            
            loop {
                if(clockRunning && clockBRunning && (clockSource == 0), {
                    beatDuration = 60.0 / (tempo * clockMultiplierB);
                    
                    swingDelay = if(evenBeat, {
                        0;
                    }, {
                        (swing - 0.5) * 2 * beatDuration;
                    });
                    
                    if(beatCount % swingSubdiv == 0, {
                        evenBeat = true;
                    }, {
                        evenBeat = evenBeat.not;
                    });
                    
                    if(stepsSinceLastTrigger >= clockDivB, {
                        if(clockBRunning, {
                            this.stepShiftRegister(\b);
                        });
                        stepsSinceLastTrigger = 0;
                    });
                    
                    stepsSinceLastTrigger = stepsSinceLastTrigger + 1;
                    
                    (beatDuration + swingDelay).wait;
                }, {
                    0.1.wait;
                });
            };
        });
    }
    
    clockTick {
        var currentBeat = beatCount / 24;
        
        if(clockARunning && ((currentBeat % clockDivA) == 0), {
            this.stepShiftRegister(\a);
        });
        
        if(clockBRunning && ((currentBeat % clockDivB) == 0), {
            this.stepShiftRegister(\b);
        });
        
        if(resetOnDownbeat && ((currentBeat % barLength) == 0), {
            this.resetRegisters;
        });
    }
    
    startClock {
        if(clockRunning.not, {
            clockRunning = true;

            if(clockSource == 0, {
                beatCount = 0;
                clockA.reset.play(TempoClock.default);
                clockB.reset.play(TempoClock.default);
            }, {
                beatCount = 0;
            });
        });
    }
    
    stopClock {
        if(clockRunning, {
            clockRunning = false;

            if(clockSource == 0, {
                clockA.stop;
                clockB.stop;
            });

            // Release all gates when clock stops
            voices.do({ arg voice;
                if(voice.notNil, {
                    voice.set(\gate, 0);
                });
            });

            "Clock stopped".postln;
        });
    }
    
    resetClock {
        this.stopClock;
        this.resetRegisters;
        "Clock reset".postln;
    }
    
    resetRegisters {
        beatCount = 0;
        shiftRegA = Array.fill(8, { 0 });
        shiftRegB = Array.fill(8, { 0 });
        
        this.sendOSCWithActivity(\a, shiftRegA, Array.fill(8, { 0 }));
        this.sendOSCWithActivity(\b, shiftRegB, Array.fill(8, { 0 }));
        
        "Registers reset".postln;
    }
    
    stepShiftRegister { arg which;
        var reg = if(which == \a, { shiftRegA }, { shiftRegB });
        var prob = stageProbability[which];
        var voiceIndex = if(which == \a, { 0 }, { 1 });
        var activeLength = if(which == \a, { patternLengthA }, { patternLengthB });
        var isFrozen = if(which == \a, { freezeA }, { freezeB });
        var isMuted = if(which == \a, { registerAMuted }, { registerBMuted });
        var shouldModulate = (inputModReg == 2) ||
                           ((inputModReg == 0) && (which == \a)) ||
                           ((inputModReg == 1) && (which == \b));
        var newValue;
        var activeStages;

        // Update random source on each step
        sources[\random] = 1.0.rand;
        
        if(isFrozen, {
            this.updateVoice(voiceIndex, reg);
            this.sendOSCWithActivity(which, reg, Array.fill(8, { 0 }));
            ^this;
        });
        
        stageOutputs[which] = reg.copy;
        activeStages = Array.fill(8, { 0 });

        // Shift stages from end to beginning (stages 7 down to 1)
        // Each stage shifts from previous, then patches modify that shifted value
        (activeLength - 1).do { arg i;
            var stageIndex = activeLength - 1 - i;
            var shiftedValue;
            var patchedValue;
            var hasPatches;

            // Check if this stage has any patches targeting it
            hasPatches = patchMatrix.any({ arg patch;
                (patch[2] == which) && (patch[3] == stageIndex)
            });

            if(1.0.rand < prob[stageIndex], {
                // ALWAYS shift from previous stage first
                shiftedValue = reg[stageIndex - 1];
                
                if(hasPatches, {
                    // Stage has patches - they MODIFY the shifted value
                    patchedValue = this.calculateStageInput(which, stageIndex, shiftedValue);
                    reg[stageIndex] = patchedValue;
                }, {
                    // No patches - just use the shifted value
                    reg[stageIndex] = shiftedValue;
                });

                activeStages[stageIndex] = 1;
            });
        };

        // Calculate stage 0 (input stage)
        newValue = this.calculateStageInput(which, 0);

        if(shouldModulate && (inputModAmount > 0), {
            newValue = this.applyAudioInputMod(newValue, which);
        });

        if(chaosAmount > 0, {
            if(chaosAmount.rand > 0.5, {
                newValue = newValue + ((chaosAmount * 0.5).rand2);
                newValue = newValue.clip(0.0, 1.0);
            });
        });

        if(mutationRate > 0, {
            activeLength.do { arg i;
                if(mutationRate.rand > 0.9, {
                    reg[i] = 1.0.rand;
                });
            };
        });

        if(1.0.rand < prob[0], {
            reg[0] = newValue;
            activeStages[0] = 1;
        });
        
        if(activeLength < 8, {
            reg[activeLength] = reg[0];
        });

        // Update all active voices with new register data via modulation matrix
        if(isMuted.not && globalMute.not, {
            voiceCount.do({ arg i;
                this.updateVoice(i);
            });
        });
        
        // Store active stages for gate routing (update AFTER calculation)
        if(which == \a, { activeStagesA = activeStages.copy; });
        if(which == \b, { activeStagesB = activeStages.copy; });

        this.sendOSCWithActivity(which, reg, activeStages);
    }
    
    calculateStageInput { arg dstReg, dstStage, currentValue = nil;
        var regKey = dstReg;
        var relevantPatches, result, patchValues;
        var seedMode;

        relevantPatches = patchMatrix.select({ arg patch;
            (patch[2] == regKey) && (patch[3] == dstStage)
        });

        if(relevantPatches.size == 0, {
            // No patches
            ^if(currentValue.notNil, {
                // Shifted value exists - use it
                currentValue;
            }, {
                // No shifted value (stage 0 with no patches) - self-seed based on mode
                seedMode = if(dstReg == \a, { seedModeA }, { seedModeB });
                
                switch(seedMode,
                    0, { 1.0.rand },           // Random
                    1, { 0.25 },               // Low
                    2, { 0.5 },                // Mid
                    3, { 0.75 },               // High
                    4, { (chaosAmount * 2).rand }  // Chaos (scaled by chaos param)
                );
            });
        });
        
        // If no current value provided, get it from the register
        if(currentValue.isNil, {
            currentValue = if(dstReg == \a, { shiftRegA[dstStage] }, { shiftRegB[dstStage] });
        });
        
        patchValues = relevantPatches.collect({ arg patch;
            var srcReg = patch[0];
            var srcStage = patch[1];
            var logic = patch[4].asInteger;  // Ensure logic is an integer
            var weight = patch[5];
            var srcValue, processed;

            // Check if source is an external source or a register stage
            srcValue = if(sources[srcReg].notNil, {
                // External source - ignore srcStage
                sources[srcReg];
            }, {
                // Register stage
                stageOutputs[srcReg][srcStage];
            });

            // Apply logic operation: srcValue modifies currentValue
            processed = logicProcessors[logic].value(srcValue, currentValue);
            processed * weight * globalFeedback * feedbackAmount;
        });
        
        if(patchValues.size == 1, {
            result = patchValues[0];
        }, {
            result = switch(multiPatchMode,
                0, { patchValues.sum / patchValues.size },
                1, { patchValues.sum },
                2, { patchValues.maxItem },
                3, { patchValues.minItem }
            );
        });
        
        ^result.clip(0.0, 1.0);
    }
    
    applyAudioInputMod { arg currentValue, which;
        var modded = currentValue;
        var envAmount = inputEnvelope * inputModAmount;
        
        switch(inputModTarget,
            0, {
                var pitchNorm = inputPitchValue.cpsmidi.linlin(36, 84, 0.0, 1.0);
                modded = modded.blend(pitchNorm, envAmount);
            },
            1, {
                if(inputEnvelope > 0.3, {
                    modded = modded.blend(1.0, envAmount);
                }, {
                    modded = modded.blend(0.0, envAmount * 0.5);
                });
            },
            2, {
                modded = modded.blend(inputEnvelope, envAmount);
            },
            3, {
                modded = currentValue;
            }
        );
        
        ^modded.clip(0.0, 1.0);
    }
    
    updateVoice { arg voiceNum;
        // NEW ARCHITECTURE: Voices are decoupled from registers
        // Base parameters, then apply modulations from voiceModMatrix
        var freq, gate, filterFreq, filterRes, waveShape;
        var fmAmount, fmRatio, subMix, amp, pan, pulseWidth, noiseAmount;
        var regAActive, regBActive;

        // Start with default base parameters
        freq = 440;  // A4
        gate = 0;
        
        // Check if registers have activity (hardwired gates)
        regAActive = (activeStagesA.sum > 0);  // Any active stage in register A
        regBActive = (activeStagesB.sum > 0);  // Any active stage in register B
        
        // Hardwired gate routing and pitch modulation
        // Gate opens when register value is above threshold (0.4)
        if(voiceNum == 0, {
            // Voice 1: Check register A and B routing
            if(gateRouteA1 && regAActive, {
                var regAValue;
                // Hardwired pitch and gate from register A stage 0
                regAValue = if(stageOutputs[\a].notNil && (stageOutputs[\a].size > 0), {
                    stageOutputs[\a][0];
                }, { 0.5 });
                
                // Gate opens when value is high enough
                if(regAValue > 0.4, {
                    gate = 1;
                });
                
                freq = freq * ((regAValue - 0.5) * 2 * 24 / 12.0).midiratio;
            });
            if(gateRouteB1 && regBActive, {
                var regBValue;
                // Hardwired pitch and gate from register B stage 0
                regBValue = if(stageOutputs[\b].notNil && (stageOutputs[\b].size > 0), {
                    stageOutputs[\b][0];
                }, { 0.5 });
                
                // Gate opens when value is high enough
                if(regBValue > 0.4, {
                    gate = 1;
                });
                
                freq = freq * ((regBValue - 0.5) * 2 * 24 / 12.0).midiratio;
            });
        });
        if(voiceNum == 1, {
            // Voice 2: Check register A and B routing
            if(gateRouteA2 && regAActive, {
                var regAValue;
                // Hardwired pitch and gate from register A stage 0
                regAValue = if(stageOutputs[\a].notNil && (stageOutputs[\a].size > 0), {
                    stageOutputs[\a][0];
                }, { 0.5 });
                
                // Gate opens when value is high enough
                if(regAValue > 0.4, {
                    gate = 1;
                });
                
                freq = freq * ((regAValue - 0.5) * 2 * 24 / 12.0).midiratio;
            });
            if(gateRouteB2 && regBActive, {
                var regBValue;
                // Hardwired pitch and gate from register B stage 0
                regBValue = if(stageOutputs[\b].notNil && (stageOutputs[\b].size > 0), {
                    stageOutputs[\b][0];
                }, { 0.5 });
                
                // Gate opens when value is high enough
                if(regBValue > 0.4, {
                    gate = 1;
                });
                
                freq = freq * ((regBValue - 0.5) * 2 * 24 / 12.0).midiratio;
            });
        });
        amp = 0.5;
        filterFreq = 2000;
        filterRes = 0.3;
        waveShape = 0;
        fmAmount = 0;
        fmRatio = 1;
        subMix = 0;
        pan = 0;
        pulseWidth = 0.5;
        noiseAmount = 0;

        // Apply modulations from voiceModMatrix (with safety check)
        if(voiceModMatrix[voiceNum].notNil, {
            voiceModMatrix[voiceNum].do({ arg modRoute;
                var srcReg = modRoute[0];     // \a or \b
                var srcStage = modRoute[1];   // 0-7
                var param = modRoute[2];      // parameter symbol
                var amount = modRoute[3];     // modulation amount 0.0-1.0
                var srcValue;

                // Get source value from register stage (with safety check)
                srcValue = if(stageOutputs[srcReg].notNil && (srcStage < stageOutputs[srcReg].size), {
                    stageOutputs[srcReg][srcStage];
                }, {
                    0.0;  // Default to 0 if invalid
                });

                // Apply modulation based on parameter
                switch(param,
                    \pitch, {
                        var rawSemitones, quantizedSemitones;
                        // Calculate raw semitones
                        rawSemitones = (srcValue - 0.5) * 2 * amount * 24;
                        
                        // Quantize if enabled
                        quantizedSemitones = this.quantizePitch(
                            rawSemitones, 
                            voiceQuantizeScale[voiceNum], 
                            voiceRootNote[voiceNum]
                        );
                        
                        // Apply to frequency
                        freq = freq * (quantizedSemitones / 12.0).midiratio;
                    },
                    \gate, {
                        // Gate: srcValue above threshold opens gate
                        if(srcValue * amount > 0.4, {
                            gate = 1;
                        });
                    },
                    \amp, {
                        // Amplitude modulation
                        amp = amp * (srcValue * amount).clip(0, 1);
                    },
                    \waveShape, {
                        // Waveshape: 0-2.99 (sine, tri, saw, pulse)
                        waveShape = waveShape + (srcValue * 2.99 * amount);
                        waveShape = waveShape.clip(0, 2.99);
                    },
                    \filterFreq, {
                        // Filter frequency modulation
                        var modFreq = srcValue.linexp(0.01, 1.0, 100, 18000);
                        filterFreq = filterFreq.blend(modFreq, amount);
                        filterFreq = filterFreq.clip(100, 18000);
                    },
                    \filterRes, {
                        // Filter resonance modulation
                        var modRes = srcValue.linlin(0, 1, 0.1, 4.0);
                        filterRes = filterRes + (modRes * amount);
                        filterRes = filterRes.clip(0.1, 4.0);
                    },
                    \fmAmount, {
                        // FM amount modulation
                        var modFM = srcValue.linlin(0, 1, 0, 1000);
                        fmAmount = fmAmount + (modFM * amount);
                        fmAmount = fmAmount.clip(0, 2000);
                    },
                    \fmRatio, {
                        // FM ratio modulation
                        var modRatio = srcValue.linexp(0.01, 1.0, 0.5, 16);
                        fmRatio = fmRatio.blend(modRatio, amount);
                        fmRatio = fmRatio.clip(0.5, 16);
                    },
                    \pulseWidth, {
                        // Pulse width modulation
                        pulseWidth = pulseWidth + ((srcValue - 0.5) * amount);
                        pulseWidth = pulseWidth.clip(0.1, 0.9);
                    },
                    \subOscMix, {
                        // Sub oscillator mix modulation
                        subMix = subMix + (srcValue * amount);
                        subMix = subMix.clip(0, 1);
                    },
                    \noiseAmount, {
                        // Noise amount modulation
                        noiseAmount = noiseAmount + (srcValue * amount * 0.3);
                        noiseAmount = noiseAmount.clip(0, 0.3);
                    },
                    \pan, {
                        // Pan modulation
                        pan = pan + ((srcValue - 0.5) * 2 * amount);
                        pan = pan.clip(-1, 1);
                    }
                );
            });  // Close .do
        });  // Close if

        // Update synth parameters
        voices[voiceNum].set(
            \freq, freq,
            \gate, gate,
            \amp, amp,
            \waveShape, waveShape,
            \filterFreq, filterFreq,
            \filterRes, filterRes,
            \fmAmount, fmAmount,
            \fmRatio, fmRatio,
            \pulseWidth, pulseWidth,
            \subOscMix, subMix,
            \noiseAmount, noiseAmount,
            \pan, pan
        );
    }
    
    getModSourceValue { arg srcType, srcIndex, regValues;
        var value = 0.0;
        
        switch(srcType,
            \register, {
                if(srcIndex < 8, {
                    value = shiftRegA[srcIndex];
                }, {
                    value = shiftRegB[srcIndex - 8];
                });
            },
            \audioInput, {
                if(srcIndex == 0, {
                    value = inputEnvelope;
                }, {
                    value = inputPitchValue.cpsmidi.linlin(36, 84, 0, 1);
                });
            },
            \lfo, {
                lfoBuses[srcIndex].get({ arg val; value = val; });
            },
            \clock, {
                if(srcIndex == 0, {
                    value = (beatCount % 1).frac;
                }, {
                    value = (beatCount % 16) / 16.0;
                });
            }
        );
        
        ^value.clip(0, 1);
    }
    
    initQuantizeScales {
        quantizeScales = [
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],  // 0: Chromatic
            [0, 2, 4, 5, 7, 9, 11, 12],                   // 1: Ionian (Major)
            [0, 2, 3, 5, 7, 9, 10, 12],                   // 2: Dorian
            [0, 1, 3, 5, 7, 8, 10, 12],                   // 3: Phrygian
            [0, 2, 4, 6, 7, 9, 11, 12],                   // 4: Lydian
            [0, 2, 4, 5, 7, 9, 10, 12],                   // 5: Mixolydian
            [0, 2, 3, 5, 7, 8, 10, 12],                   // 6: Aeolian (Minor)
            [0, 1, 3, 5, 6, 8, 10, 12],                   // 7: Locrian
            [0, 2, 4, 7, 9, 12],                          // 8: Pentatonic Major
            [0, 3, 5, 7, 10, 12],                         // 9: Pentatonic Minor
            [0, 3, 5, 6, 7, 10, 12],                      // 10: Blues
            [0, 2, 3, 5, 7, 8, 11, 12],                   // 11: Harmonic Minor
            [0, 2, 4, 6, 8, 10, 12]                       // 12: Whole Tone
        ];
    }
    
    quantizePitch { arg semitones, scaleIndex, rootNote;
        var scale, octave, semiInOctave, transposedSemi, quantized, distances, minIndex;
        
        // If chromatic or invalid scale index, return unchanged
        if((scaleIndex == 0) || (scaleIndex >= quantizeScales.size), { ^semitones });
        
        // Get the scale by index
        scale = quantizeScales[scaleIndex];
        if(scale.isNil, { ^semitones });
        
        // Separate octave and semitone within octave
        octave = semitones.floor.div(12);
        semiInOctave = semitones.floor % 12;
        
        // Handle negative semitones properly
        if(semiInOctave < 0, {
            semiInOctave = semiInOctave + 12;
            octave = octave - 1;
        });
        
        // Transpose to C root for quantization
        transposedSemi = (semiInOctave - rootNote + 12) % 12;
        
        // Find nearest scale degree
        distances = scale.collect({ arg note; (note - transposedSemi).abs });
        minIndex = distances.minIndex;
        quantized = scale[minIndex];
        
        // Transpose back to original root
        quantized = (quantized + rootNote) % 12;
        
        // Return quantized pitch
        ^(octave * 12) + quantized;
    }
    
    getHarmonicRatio { arg value;
        var ratios = [1.0, 1.125, 1.25, 1.333, 1.5, 1.667, 2.0];
        var index = (value * (ratios.size - 1)).floor;
        ^ratios[index];
    }
    
    getFMRatio { arg value;
        var ratios = [1, 2, 3, 4, 5, 7, 9];
        var index = (value * (ratios.size - 1)).floor;
        ^ratios[index];
    }
    
   sendOSCWithActivity { arg which, values, activeStages;
        var addr;
        addr = NetAddr.new("127.0.0.1", 10111);
        addr.sendMsg('/tt_state', which,
            values[0], values[1], values[2], values[3],
            values[4], values[5], values[6], values[7],
            activeStages[0], activeStages[1], activeStages[2], activeStages[3],
            activeStages[4], activeStages[5], activeStages[6], activeStages[7]
        );
    }
    
    addCommands {
        // Clock commands
        this.addCommand(\start, "", { arg msg;
            this.startClock;
        });
        
        this.addCommand(\stop, "", { arg msg;
            this.stopClock;
        });
        
        this.addCommand(\reset, "", { arg msg;
            this.resetClock;
        });
        
        this.addCommand(\tempo, "f", { arg msg;
            tempo = msg[1].clip(20, 300);
            ("Tempo: " ++ tempo ++ " BPM").postln;
        });
        
        this.addCommand(\clock_div_a, "i", { arg msg;
            clockDivA = msg[1].clip(1, 32);
            ("Clock A division: " ++ clockDivA).postln;
        });
        
        this.addCommand(\clock_div_b, "i", { arg msg;
            clockDivB = msg[1].clip(1, 32);
            ("Clock B division: " ++ clockDivB).postln;
        });
        
        this.addCommand(\swing, "f", { arg msg;
            swing = msg[1].clip(0.0, 1.0);
            ("Swing: " ++ ((swing - 0.5) * 200).round(1) ++ "%").postln;
        });
        
        this.addCommand(\swing_subdiv, "i", { arg msg;
            var subdivStr;

            swingSubdiv = msg[1].clip(2, 4);
            subdivStr = if(swingSubdiv == 2, { "8th" }, { "16th" });
            ("Swing subdivision: " ++ subdivStr ++ " notes").postln;
        });

        this.addCommand(\bar_length, "i", { arg msg;
            barLength = msg[1].clip(4, 64);
            ("Bar length: " ++ barLength ++ " beats").postln;
        });

        this.addCommand(\clock_a_enable, "i", { arg msg;
            clockARunning = msg[1] > 0;
            ("Clock A: " ++ if(clockARunning, { "enabled" }, { "disabled" })).postln;
        });

        this.addCommand(\clock_b_enable, "i", { arg msg;
            clockBRunning = msg[1] > 0;
            ("Clock B: " ++ if(clockBRunning, { "enabled" }, { "disabled" })).postln;
        });

        this.addCommand(\clock_source, "i", { arg msg;
            var sourceStr;

            clockSource = msg[1].clip(0, 1);
            sourceStr = if(clockSource == 0, { "internal" }, { "MIDI" });
            ("Clock source: " ++ sourceStr).postln;
        });
        
        this.addCommand(\step, "s", { arg msg;
            var which;

            which = msg[1].asSymbol;
            this.stepShiftRegister(which);
        });

        // Voice commands
        this.addCommand(\slew_mode, "i", { arg msg;
            var mode;

            mode = msg[1];
            slewMode = mode;
            
            if(mode == 1, {
                slewRoutine.do(_.play);
                "Slew mode: ON".postln;
            }, {
                slewRoutine.do(_.stop);
                "Slew mode: OFF".postln;
            });
        });
        
        this.addCommand(\slew_time, "f", { arg msg;
            slewTime = msg[1].clip(0.001, 1.0);
            ("Slew time: " ++ slewTime ++ "s").postln;
        });
        
        this.addCommand(\unpatched_mode, "i", { arg msg;
            var modeStr;

            unpatchedBehavior = msg[1].clip(0, 1);
            modeStr = if(unpatchedBehavior == 0, { "hold zero" }, { "random" });
            ("Unpatched stages: " ++ modeStr).postln;
        });

        this.addCommand(\multipatch_mode, "i", { arg msg;
            var modeStr;

            multiPatchMode = msg[1].clip(0, 3);
            modeStr = switch(multiPatchMode,
                0, { "average" },
                1, { "sum" },
                2, { "max" },
                3, { "min" }
            );
            ("Multi-patch mode: " ++ modeStr).postln;
        });
        
        this.addCommand(\global_feedback, "f", { arg msg;
            globalFeedback = msg[1].clip(0.0, 1.0);
            ("Global feedback: " ++ (globalFeedback * 100).round(1) ++ "%").postln;
        });
        
        this.addCommand(\stage_prob, "iif", { arg msg;
            var reg, stage, probability, regKey;

            reg = msg[1];
            stage = msg[2];
            probability = msg[3];

            regKey = if(reg == 0, { \a }, { \b });
            stageProbability[regKey][stage] = probability.clip(0.0, 1.0);
        });

        this.addCommand(\stage_mapping, "iii", { arg msg;
            var reg, stage, mode, regKey;

            reg = msg[1];
            stage = msg[2];
            mode = msg[3];

            regKey = if(reg == 0, { \a }, { \b });
            stageMappings[regKey][stage] = mode;
        });
        
        // Patch commands
        this.addCommand(\add_patch, "sisisf", { arg msg;
            var srcReg, srcStage, dstReg, dstStage, logicOp, weight;
            var patch, existing, index;

            srcReg = msg[1].asSymbol;
            srcStage = msg[2];
            dstReg = msg[3].asSymbol;
            dstStage = msg[4];
            logicOp = msg[5];
            weight = msg[6];

            patch = [srcReg, srcStage, dstReg, dstStage, logicOp, weight];

            existing = patchMatrix.detect({ arg p;
                (p[0] == srcReg) && (p[1] == srcStage) &&
                (p[2] == dstReg) && (p[3] == dstStage)
            });

            if(existing.notNil, {
                index = patchMatrix.indexOf(existing);
                patchMatrix[index] = patch;
            }, {
                patchMatrix.add(patch);
            });
        });
        
        this.addCommand(\remove_patch, "sisi", { arg msg;
            var srcReg, srcStage, dstReg, dstStage;

            srcReg = msg[1].asSymbol;
            srcStage = msg[2];
            dstReg = msg[3].asSymbol;
            dstStage = msg[4];

            patchMatrix.removeAllSuchThat({ arg patch;
                (patch[0] == srcReg) && (patch[1] == srcStage) &&
                (patch[2] == dstReg) && (patch[3] == dstStage)
            });
        });
        
        this.addCommand(\clear_patches, "", { arg msg;
            patchMatrix.clear;
            "All patches cleared".postln;
        });
        
        this.addCommand(\patch_weight, "sisif", { arg msg;
            var srcReg, srcStage, dstReg, dstStage, weight, patch;

            srcReg = msg[1].asSymbol;
            srcStage = msg[2];
            dstReg = msg[3].asSymbol;
            dstStage = msg[4];
            weight = msg[5];

            patch = patchMatrix.detect({ arg p;
                (p[0] == srcReg) && (p[1] == srcStage) &&
                (p[2] == dstReg) && (p[3] == dstStage)
            });

            if(patch.notNil, {
                patch[5] = weight.clip(0.0, 1.0);
            });
        });
        
        this.addCommand(\patch_logic, "sisii", { arg msg;
            var srcReg, srcStage, dstReg, dstStage, logic, patch;

            srcReg = msg[1].asSymbol;
            srcStage = msg[2];
            dstReg = msg[3].asSymbol;
            dstStage = msg[4];
            logic = msg[5];

            patch = patchMatrix.detect({ arg p;
                (p[0] == srcReg) && (p[1] == srcStage) &&
                (p[2] == dstReg) && (p[3] == dstStage)
            });

            if(patch.notNil, {
                patch[4] = logic.clip(0, 12);
            });
        });
        
        this.addCommand(\get_patches, "", { arg msg;
            var addr;
            addr = NetAddr.new("127.0.0.1", 10111);
            patchMatrix.do({ arg patch;
                addr.sendMsg('/patch_data',
                    patch[0], patch[1], patch[2], patch[3], patch[4], patch[5]
                );
            });
        });

        // Source parameter commands
        this.addCommand(\set_source, "sf", { arg msg;
            var sourceName, value;

            sourceName = msg[1].asSymbol;
            value = msg[2].clip(0.0, 1.0);

            if(sources[sourceName].notNil, {
                sources[sourceName] = value;
                ("Source " ++ sourceName ++ " = " ++ value).postln;
            }, {
                ("Unknown source: " ++ sourceName).postln;
            });
        });

        this.addCommand(\get_sources, "", { arg msg;
            var addr;
            addr = NetAddr.new("127.0.0.1", 10111);
            sources.keysValuesDo({ arg key, value;
                addr.sendMsg('/source_value', key, value);
            });
        });

        // Voice modulation matrix commands
        this.addCommand(\voice_count, "i", { arg msg;
            voiceCount = msg[1].clip(2, 4);
            ("Voice count: " ++ voiceCount).postln;
        });

        this.addCommand(\add_voice_mod, "isisf", { arg msg;
            var voiceNum, srcReg, srcStage, param, amount;
            var modRoute, existing, index;

            voiceNum = msg[1];
            srcReg = msg[2].asSymbol;
            srcStage = msg[3];
            param = msg[4].asSymbol;
            amount = msg[5].clip(0.0, 1.0);

            // Validate voice number
            if(voiceNum >= voiceCount, {
                ("Voice " ++ voiceNum ++ " not active (voiceCount=" ++ voiceCount ++ ")").postln;
                ^this;
            });

            // Create modulation route: [srcReg, srcStage, param, amount]
            modRoute = [srcReg, srcStage, param, amount];

            // Check if this mod already exists
            existing = voiceModMatrix[voiceNum].detect({ arg route;
                (route[0] == srcReg) && (route[1] == srcStage) && (route[2] == param)
            });

            if(existing.notNil, {
                // Update existing mod
                index = voiceModMatrix[voiceNum].indexOf(existing);
                voiceModMatrix[voiceNum][index] = modRoute;
                ("Updated voice mod: V" ++ voiceNum ++ " " ++ srcReg ++ srcStage ++ " -> " ++ param).postln;
            }, {
                // Add new mod
                voiceModMatrix[voiceNum].add(modRoute);
                ("Added voice mod: V" ++ voiceNum ++ " " ++ srcReg ++ srcStage ++ " -> " ++ param).postln;
            });
        });

        this.addCommand(\remove_voice_mod, "isis", { arg msg;
            var voiceNum, srcReg, srcStage, param;

            voiceNum = msg[1];
            srcReg = msg[2].asSymbol;
            srcStage = msg[3];
            param = msg[4].asSymbol;

            voiceModMatrix[voiceNum].removeAllSuchThat({ arg route;
                (route[0] == srcReg) && (route[1] == srcStage) && (route[2] == param)
            });

            ("Removed voice mod: V" ++ voiceNum ++ " " ++ srcReg ++ srcStage ++ " -> " ++ param).postln;
        });

        this.addCommand(\clear_voice_mods, "i", { arg msg;
            var voiceNum;

            voiceNum = msg[1];
            voiceModMatrix[voiceNum].clear;
            ("Cleared all mods for voice " ++ voiceNum).postln;
        });

        this.addCommand(\get_voice_mods, "i", { arg msg;
            var voiceNum, addr;

            voiceNum = msg[1];
            addr = NetAddr.new("127.0.0.1", 10111);

            voiceModMatrix[voiceNum].do({ arg route;
                addr.sendMsg('/voice_mod_data',
                    voiceNum,
                    route[0],  // srcReg
                    route[1],  // srcStage
                    route[2],  // param
                    route[3]   // amount
                );
            });
        });

        // Voice parameter commands (for direct control from Voice Sound page)
        this.addCommand(\set_voice_param, "isf", { arg msg;
            var voiceNum, paramName, value;

            voiceNum = msg[1];
            paramName = msg[2].asSymbol;
            value = msg[3];

            if(voiceNum < voiceCount, {
                voiceParamsTarget[voiceNum][paramName] = value;
                if(slewMode == 0, {
                    voiceParams[voiceNum][paramName] = value;
                });
                voices[voiceNum].set(paramName, value);
                ("Voice " ++ voiceNum ++ " " ++ paramName ++ " = " ++ value).postln;
            });
        });

        this.addCommand(\get_voice_param, "is", { arg msg;
            var voiceNum, paramName, value, addr;

            voiceNum = msg[1];
            paramName = msg[2].asSymbol;
            addr = NetAddr.new("127.0.0.1", 10111);

            if(voiceNum < voiceCount, {
                value = voiceParams[voiceNum][paramName];
                addr.sendMsg('/voice_param_value', voiceNum, paramName, value);
            });
        });

        // Pitch quantization commands
        // Pitch quantization commands
        this.addCommand(\voice_quantize, "ii", { arg msg;
            var voiceNum, scaleIndex;
            voiceNum = msg[1];
            scaleIndex = msg[2];
            if(voiceNum < voiceCount, {
                voiceQuantizeScale[voiceNum] = scaleIndex.clip(0, 12);
                ("Voice " ++ voiceNum ++ " quantize scale: " ++ scaleIndex).postln;
            });
        });
        
        this.addCommand(\voice_root, "ii", { arg msg;
            var voiceNum, rootNote;
            voiceNum = msg[1];
            rootNote = msg[2];
            if(voiceNum < voiceCount, {
                voiceRootNote[voiceNum] = rootNote.clip(0, 11);
                ("Voice " ++ voiceNum ++ " root note: " ++ rootNote).postln;
            });
        });

        // Performance commands
        this.addCommand(\mute_a, "i", { arg msg;
            registerAMuted = msg[1] > 0;
            // Note: Muting now only affects register stepping, not voices directly
            // Voices are controlled via modulation matrix
        });

        this.addCommand(\mute_b, "i", { arg msg;
            registerBMuted = msg[1] > 0;
            // Note: Muting now only affects register stepping, not voices directly
            // Voices are controlled via modulation matrix
        });

        this.addCommand(\mute_global, "i", { arg msg;
            globalMute = msg[1] > 0;
            // Note: Global mute affects register stepping, not voices directly
            // Voices are controlled via modulation matrix
        });
        
        this.addCommand(\freeze_a, "i", { arg msg;
            freezeA = msg[1] > 0;
        });
        
        this.addCommand(\freeze_b, "i", { arg msg;
            freezeB = msg[1] > 0;
        });
        
        this.addCommand(\pattern_length_a, "i", { arg msg;
            patternLengthA = msg[1].clip(1, 8);
        });
        
        this.addCommand(\pattern_length_b, "i", { arg msg;
            patternLengthB = msg[1].clip(1, 8);
        });
        
        this.addCommand(\clock_mult_a, "f", { arg msg;
            clockMultiplierA = msg[1].clip(0.25, 4.0);
        });
        
        this.addCommand(\clock_mult_b, "f", { arg msg;
            clockMultiplierB = msg[1].clip(0.25, 4.0);
        });
        
        this.addCommand(\feedback_amount, "f", { arg msg;
            feedbackAmount = msg[1].clip(0.0, 2.0);
        });
        
        this.addCommand(\chaos, "f", { arg msg;
            chaosAmount = msg[1].clip(0.0, 1.0);
        });
        
        this.addCommand(\mutation, "f", { arg msg;
            mutationRate = msg[1].clip(0.0, 1.0);
        });
        
        this.addCommand(\seed_mode_a, "i", { arg msg;
            seedModeA = msg[1].clip(0, 4);
            ("Seed Mode A: " ++ ["Random", "Low", "Mid", "High", "Chaos"][seedModeA]).postln;
        });
        
        this.addCommand(\seed_mode_b, "i", { arg msg;
            seedModeB = msg[1].clip(0, 4);
            ("Seed Mode B: " ++ ["Random", "Low", "Mid", "High", "Chaos"][seedModeB]).postln;
        });
        
        this.addCommand(\gate_route_a1, "i", { arg msg;
            gateRouteA1 = msg[1] > 0;
            ("Gate route A→1: " ++ gateRouteA1).postln;
        });
        
        this.addCommand(\gate_route_a2, "i", { arg msg;
            gateRouteA2 = msg[1] > 0;
            ("Gate route A→2: " ++ gateRouteA2).postln;
        });
        
        this.addCommand(\gate_route_b1, "i", { arg msg;
            gateRouteB1 = msg[1] > 0;
            ("Gate route B→1: " ++ gateRouteB1).postln;
        });
        
        this.addCommand(\gate_route_b2, "i", { arg msg;
            gateRouteB2 = msg[1] > 0;
            ("Gate route B→2: " ++ gateRouteB2).postln;
        });
        
        this.addCommand(\randomize, "s", { arg msg;
            var which = msg[1].asSymbol;
            var reg = if(which == \a, { shiftRegA }, { shiftRegB });
            
            8.do { arg i;
                reg[i] = 1.0.rand;
            };
            
            this.sendOSCWithActivity(which, reg, Array.fill(8, { 1 }));
        });
        
        this.addCommand(\clear_register, "s", { arg msg;
            var which = msg[1].asSymbol;
            var reg = if(which == \a, { shiftRegA }, { shiftRegB });
            
            8.do { arg i;
                reg[i] = 0.0;
            };
            
            this.sendOSCWithActivity(which, reg, Array.fill(8, { 0 }));
        });
        
        this.addCommand(\copy_register, "ss", { arg msg;
            var source = msg[1].asSymbol;
            var dest = msg[2].asSymbol;
            var srcReg = if(source == \a, { shiftRegA }, { shiftRegB });
            var dstReg = if(dest == \a, { shiftRegA }, { shiftRegB });
            
            8.do { arg i;
                dstReg[i] = srcReg[i];
            };
            
            this.sendOSCWithActivity(dest, dstReg, Array.fill(8, { 1 }));
        });
        
        // Audio input commands
        this.addCommand(\input_mod_amount, "f", { arg msg;
            inputModAmount = msg[1].clip(0.0, 1.0);
        });
        
        this.addCommand(\input_mod_target, "i", { arg msg;
            inputModTarget = msg[1].clip(0, 3);
        });
        
        this.addCommand(\input_mod_reg, "i", { arg msg;
            inputModReg = msg[1].clip(0, 2);
        });
        
        this.addCommand(\input_gain, "f", { arg msg;
            inputGain = msg[1].clip(0.0, 4.0);
            inputFollower.set(\gain, inputGain);
        });
        
        this.addCommand(\input_smoothing, "f", { arg msg;
            inputSmoothing = msg[1].clip(0.001, 1.0);
            inputFollower.set(\smoothing, inputSmoothing);
        });
        
        // Modulation matrix commands
        this.addCommand(\add_mod, "siisf", { arg msg;
            var srcType, srcIndex, destVoice, destParam, amount;
            var modRoute, existing, index;

            srcType = msg[1].asSymbol;
            srcIndex = msg[2];
            destVoice = msg[3];
            destParam = msg[4].asSymbol;
            amount = msg[5];

            modRoute = [srcType, srcIndex, destVoice, destParam, amount];

            existing = modMatrix.detect({ arg route;
                (route[0] == srcType) && (route[1] == srcIndex) &&
                (route[2] == destVoice) && (route[3] == destParam)
            });

            if(existing.notNil, {
                index = modMatrix.indexOf(existing);
                modMatrix[index] = modRoute;
            }, {
                modMatrix.add(modRoute);
            });
        });
        
        this.addCommand(\remove_mod, "siis", { arg msg;
            var srcType, srcIndex, destVoice, destParam;

            srcType = msg[1].asSymbol;
            srcIndex = msg[2];
            destVoice = msg[3];
            destParam = msg[4].asSymbol;

            modMatrix.removeAllSuchThat({ arg route;
                (route[0] == srcType) && (route[1] == srcIndex) &&
                (route[2] == destVoice) && (route[3] == destParam)
            });
        });
        
        this.addCommand(\clear_mods, "", { arg msg;
            modMatrix.clear;
            "All modulations cleared".postln;
        });
        
        this.addCommand(\lfo_rate, "if", { arg msg;
            var lfoNum, rate;

            lfoNum = msg[1].clip(0, 3);
            rate = msg[2].clip(0.01, 20);

            lfoRates[lfoNum] = rate;
            lfoSynths[lfoNum].set(\rate, rate);
        });

        this.addCommand(\lfo_shape, "ii", { arg msg;
            var lfoNum, shape;

            lfoNum = msg[1].clip(0, 3);
            shape = msg[2].clip(0, 4);

            lfoShapes[lfoNum] = shape;
            lfoSynths[lfoNum].set(\shape, shape);
        });
        
        this.addCommand(\get_mods, "", { arg msg;
            var addr;
            addr = NetAddr.new("127.0.0.1", 10111);
            modMatrix.do({ arg route;
                addr.sendMsg('/mod_data',
                    route[0], route[1], route[2], route[3], route[4]
                );
            });
        });
    }
    
    free {
        this.stopClock;
        midiClockIn.free;
        inputFollower.free;
        audioAnalyzer.free;
        audioInputBus.free;
        voices.do(_.free);
        clockA.stop;
        clockB.stop;
        slewRoutine.do(_.stop);
        lfoSynths.do(_.free);
        lfoBuses.do(_.free);
        synthBus.do(_.free);
        OSCdef(\ttInputAmp).free;
        OSCdef(\ttInputPitch).free;
        OSCdef(\ttVoiceSignal).free;
    }
}