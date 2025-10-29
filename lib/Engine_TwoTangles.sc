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
        
        // Initialize shift registers
        shiftRegA = Array.fill(8, { 0 });
        shiftRegB = Array.fill(8, { 0 });
        
        // Patch matrix
        patchMatrix = List.new;
        
        // Stage outputs
        stageOutputs = Dictionary.newFrom([
            \a, Array.fill(8, { 0.0 }),
            \b, Array.fill(8, { 0.0 })
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
        
        // Voice parameters
        slewMode = 0;
        slewTime = 0.05;
        unpatchedBehavior = 0;
        multiPatchMode = 0;
        globalFeedback = 1.0;
        
        voiceParams = Array.fill(2, { 
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
        
        voiceParamsTarget = Array.fill(2, { 
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
        var voiceDef = SynthDef(\ttVoice, { 
            arg out=0, 
            freq=440, 
            gate=0, 
            amp=0.5,
            filterFreq=2000, 
            filterRes=0.3,
            waveShape=0,
            fmAmount=0,
            fmRatio=1,
            pulseWidth=0.5,
            subOscMix=0,
            noiseAmount=0,
            pan=0;
            
            var sig, env, filt, fmMod, subOsc, noise, mixed;
            
            fmMod = SinOsc.ar(freq * fmRatio) * fmAmount * freq;
            
            sig = SelectX.ar(waveShape.clip(0, 2.99), [
                SinOsc.ar(freq + fmMod),
                LFTri.ar(freq + fmMod),
                LFSaw.ar(freq + fmMod),
                Pulse.ar(freq + fmMod, pulseWidth)
            ]);
            
            subOsc = LFTri.ar(freq * 0.5);
            noise = WhiteNoise.ar() * noiseAmount;
            mixed = (sig * (1 - subOscMix)) + (subOsc * subOscMix) + noise;
            
            env = EnvGen.ar(
                Env.adsr(
                    attackTime: 0.001,
                    decayTime: 0.1,
                    sustainLevel: 0.7,
                    releaseTime: 0.2
                ),
                gate,
                doneAction: 0
            );
            
            filt = MoogFF.ar(
                mixed,
                filterFreq.clip(20, 18000),
                filterRes.clip(0, 4)
            );
            
            Out.ar(out, Pan2.ar(filt * env * amp, pan));
        }).add;
        
        context.server.sync;
        
        voices = Array.fill(2, { arg i;
            Synth(\ttVoice, [
                \out, 0,
                \amp, 0.5
            ], target: context.xg);
        });
        
        slewRoutine = Array.fill(2, { arg i;
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
            
            "Clock started".postln;
        });
    }
    
    stopClock {
        if(clockRunning, {
            clockRunning = false;
            
            if(clockSource == 0, {
                clockA.stop;
                clockB.stop;
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
        ("Stepping register: " ++ which).postln;
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
        
        if(isFrozen, {
            this.updateVoice(voiceIndex, reg);
            this.sendOSCWithActivity(which, reg, Array.fill(8, { 0 }));
            ^this;
        });
        
        stageOutputs[which] = reg.copy;
        activeStages = Array.fill(8, { 0 });
        
        (activeLength - 1).do { arg i;
            if(1.0.rand < prob[activeLength - 1 - i], {
                reg[activeLength - 1 - i] = reg[activeLength - 2 - i];
                activeStages[activeLength - 1 - i] = 1;
            });
        };
        
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
        
        if(isMuted.not && globalMute.not, {
            this.updateVoice(voiceIndex, reg);
        }, {
            voices[voiceIndex].set(\gate, 0, \amp, 0);
        });
        
        this.sendOSCWithActivity(which, reg, activeStages);
    }
    
    calculateStageInput { arg dstReg, dstStage;
        var regKey = dstReg;
        var relevantPatches, result, patchValues;
        
        relevantPatches = patchMatrix.select({ arg patch;
            (patch[2] == regKey) && (patch[3] == dstStage)
        });
        
        if(relevantPatches.size == 0, {
            ^if(unpatchedBehavior == 0, {
                0.0;
            }, {
                1.0.rand;
            });
        });
        
        patchValues = relevantPatches.collect({ arg patch;
            var srcReg = patch[0];
            var srcStage = patch[1];
            var logic = patch[4];
            var weight = patch[5];
            var srcValue, currentValue, processed;
            
            srcValue = stageOutputs[srcReg][srcStage];
            currentValue = if(dstReg == \a, { shiftRegA[dstStage] }, { shiftRegB[dstStage] });
            
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
    
    updateVoice { arg voiceNum, regValues;
        var params = voiceParams[voiceNum];
        var targets = voiceParamsTarget[voiceNum];
        var regKey = if(voiceNum == 0, { \a }, { \b });
        var mappings = stageMappings[regKey];
        var shouldModulateInput = (inputModReg == 2) || 
                           ((inputModReg == 0) && (voiceNum == 0)) ||
                           ((inputModReg == 1) && (voiceNum == 1));
        var freq, gate, filterFreq, filterRes, waveShape;
        var fmAmount, fmRatio, subMix, amp, pan, pulseWidth, noiseAmount;
        var pitchMod = 1.0;
        
        // Stage 0: Pitch
        freq = switch(mappings[0],
            0, { this.quantizePitch(regValues[0], baseOctave: 3) },
            1, { regValues[0].linexp(0.0, 1.0, 110, 1760) },
            2, { ([110, 220, 440, 880, 1760].wrapAt((regValues[0] * 5).floor)) }
        );
        
        // Stage 1: Harmony
        switch(mappings[1],
            0, { 
                pitchMod = this.getHarmonicRatio(regValues[1]);
                freq = freq * pitchMod;
            },
            1, { 
                var semitones = regValues[1].linlin(0, 1, -12, 12).round(1);
                freq = freq * (semitones / 12).midiratio;
            },
            2, { 
                targets[\vibratoDepth] = regValues[1] * 20;
            }
        );
        
        // Stage 2: Gate
        gate = switch(mappings[2],
            0, { if(regValues[2] > 0.4, { 1 }, { 0 }) },
            1, { if(1.0.rand < regValues[2], { 1 }, { 0 }) },
            2, { 
                var burstProb = regValues[2].squared;
                if(1.0.rand < burstProb, { 1 }, { 0 });
            }
        );
        
        // Stage 3: Filter Cutoff
        filterFreq = switch(mappings[3],
            0, { regValues[3].linexp(0.0, 1.0, 100, 8000) },
            1, { regValues[3].linexp(0.0, 1.0, 2000, 12000) },
            2, { regValues[3].linexp(0.0, 1.0, 200, 4000) }
        );
        
        // Stage 4: Filter Resonance
        filterRes = switch(mappings[4],
            0, { regValues[4].linlin(0.0, 1.0, 0.1, 3.5) },
            1, { regValues[4].linlin(0.0, 1.0, 2.0, 4.0) },
            2, { (1.0 - regValues[3]).linlin(0.0, 1.0, 0.5, 3.5) }
        );
        
        // Stage 5: Waveshape
        waveShape = switch(mappings[5],
            0, { regValues[5] * 2.99 },
            1, { if(regValues[5] < 0.5, { 0 }, { 3 }) },
            2, { (regValues[5] * 4).floor.clip(0, 3) }
        );
        
        // Stage 6: FM/Sub Mix
        switch(mappings[6],
            0, {
                fmAmount = regValues[6].linlin(0.0, 0.5, 0, 800);
                subMix = regValues[6].linlin(0.5, 1.0, 0, 0.5).clip(0, 0.5);
            },
            1, {
                fmAmount = regValues[6].linlin(0.0, 1.0, 0, 1200);
                subMix = 0;
            },
            2, {
                fmAmount = 0;
                subMix = 0;
            }
        );
        
        // Stage 7: FM Ratio
        switch(mappings[7],
            0, { fmRatio = this.getFMRatio(regValues[7]); },
            1, { fmRatio = regValues[7].linlin(0.0, 1.0, 0.5, 16); },
            2, { 
                fmRatio = 1;
                noiseAmount = regValues[7] * 0.3;
            }
        );
        
        // Defaults
        amp = 0.5;
        pan = 0;
        pulseWidth = 0.5;
        noiseAmount = noiseAmount ? 0;
        
        // Apply modulation matrix
        modMatrix.do({ arg modRoute;
            var srcType = modRoute[0];
            var srcIndex = modRoute[1];
            var destVoice = modRoute[2];
            var destParam = modRoute[3];
            var amount = modRoute[4];
            var srcValue;
            
            if((destVoice != 2) && (destVoice != voiceNum), {
                ^this;
            });
            
            srcValue = this.getModSourceValue(srcType, srcIndex, regValues);
            
            switch(destParam,
                \pitch, {
                    var semitones = (srcValue - 0.5) * 2 * amount * 24;
                    freq = freq * (semitones / 12).midiratio;
                },
                \filterFreq, {
                    var modFreq = srcValue.linexp(0, 1, 100, 8000);
                    filterFreq = filterFreq.blend(modFreq, amount.abs);
                },
                \filterRes, {
                    var modRes = srcValue.linlin(0, 1, 0.1, 3.5);
                    filterRes = filterRes + (modRes * amount);
                    filterRes = filterRes.clip(0.1, 4.0);
                },
                \waveShape, {
                    var modShape = srcValue * 2.99;
                    waveShape = waveShape + (modShape * amount);
                    waveShape = waveShape.clip(0, 2.99);
                },
                \fmAmount, {
                    var modFM = srcValue.linlin(0, 1, 0, 1000);
                    fmAmount = fmAmount + (modFM * amount);
                    fmAmount = fmAmount.clip(0, 2000);
                },
                \fmRatio, {
                    var modRatio = srcValue.linlin(0, 1, 0.5, 16);
                    fmRatio = fmRatio.blend(modRatio, amount.abs);
                },
                \subOscMix, {
                    subMix = subMix + (srcValue * amount);
                    subMix = subMix.clip(0, 1);
                },
                \amp, {
                    amp = amp + (srcValue * amount);
                    amp = amp.clip(0, 1);
                },
                \pan, {
                    pan = pan + ((srcValue - 0.5) * 2 * amount);
                    pan = pan.clip(-1, 1);
                },
                \pulseWidth, {
                    pulseWidth = pulseWidth + ((srcValue - 0.5) * amount);
                    pulseWidth = pulseWidth.clip(0.01, 0.99);
                },
                \noiseAmount, {
                    noiseAmount = (noiseAmount ? 0) + (srcValue * amount);
                    noiseAmount = noiseAmount.clip(0, 1);
                }
            );
        });
        
        // Apply audio input modulation (legacy)
        if(shouldModulateInput && (inputModAmount > 0), {
            var envAmount = inputEnvelope * inputModAmount;
            
            switch(inputModTarget,
                0, {
                    var pitchNorm = inputPitchValue.cpsmidi.linlin(36, 84, 0.0, 1.0);
                    var pitchSemitones = (pitchNorm - 0.5) * 24;
                    freq = freq * (pitchSemitones / 12).midiratio;
                },
                1, {
                    if(inputEnvelope > 0.3, { gate = 1; });
                },
                2, {
                    amp = amp * (0.5 + (inputEnvelope * 0.5));
                }
            );
        });
        
        // Set voice parameters
        if(slewMode == 0, {
            voices[voiceNum].set(
                \freq, freq,
                \gate, gate,
                \filterFreq, filterFreq,
                \filterRes, filterRes,
                \waveShape, waveShape,
                \fmAmount, fmAmount,
                \fmRatio, fmRatio,
                \subOscMix, subMix,
                \amp, amp,
                \pan, pan,
                \pulseWidth, pulseWidth,
                \noiseAmount, noiseAmount
            );
        }, {
            targets[\pitch] = freq;
            targets[\filterFreq] = filterFreq;
            targets[\filterRes] = filterRes;
            targets[\waveShape] = waveShape;
            targets[\fmAmount] = fmAmount;
            targets[\fmRatio] = fmRatio;
            targets[\subOscMix] = subMix;
            targets[\amp] = amp;
            targets[\pan] = pan;
            targets[\pulseWidth] = pulseWidth;
            targets[\noiseAmount] = noiseAmount;
            
            voices[voiceNum].set(\gate, gate);
        });
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
    
    quantizePitch { arg value, baseOctave=3;
        var scale = [0, 3, 5, 7, 10];
        var octaveRange = 3;
        var octave = baseOctave + (value * octaveRange).floor;
        var scaleIndex = (value * octaveRange * scale.size).floor % scale.size;
        var degree = scale[scaleIndex];
        var midiNote = (octave * 12) + degree + 48;
        ^midiNote.midicps;
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
            var which = msg[1].asSymbol;
            this.stepShiftRegister(which);
        });
        
        // Voice commands
        this.addCommand(\slew_mode, "i", { arg msg;
            var mode = msg[1];
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
            var reg = msg[1];
            var stage = msg[2];
            var probability = msg[3];
            
            var regKey = if(reg == 0, { \a }, { \b });
            stageProbability[regKey][stage] = probability.clip(0.0, 1.0);
        });
        
        this.addCommand(\stage_mapping, "iii", { arg msg;
            var reg = msg[1];
            var stage = msg[2];
            var mode = msg[3];
            
            var regKey = if(reg == 0, { \a }, { \b });
            stageMappings[regKey][stage] = mode;
        });
        
        // Patch commands
        this.addCommand(\add_patch, "sisisf", { arg msg;
            var srcReg = msg[1].asSymbol;
            var srcStage = msg[2];
            var dstReg = msg[3].asSymbol;
            var dstStage = msg[4];
            var logicOp = msg[5];
            var weight = msg[6];
            
            var patch = [srcReg, srcStage, dstReg, dstStage, logicOp, weight];
            
            var existing = patchMatrix.detect({ arg p;
                (p[0] == srcReg) && (p[1] == srcStage) && 
                (p[2] == dstReg) && (p[3] == dstStage)
            });
            
            if(existing.notNil, {
                var index = patchMatrix.indexOf(existing);
                patchMatrix[index] = patch;
            }, {
                patchMatrix.add(patch);
            });
        });
        
        this.addCommand(\remove_patch, "sisi", { arg msg;
            var srcReg = msg[1].asSymbol;
            var srcStage = msg[2];
            var dstReg = msg[3].asSymbol;
            var dstStage = msg[4];
            
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
            var srcReg = msg[1].asSymbol;
            var srcStage = msg[2];
            var dstReg = msg[3].asSymbol;
            var dstStage = msg[4];
            var weight = msg[5];
            
            var patch = patchMatrix.detect({ arg p;
                (p[0] == srcReg) && (p[1] == srcStage) && 
                (p[2] == dstReg) && (p[3] == dstStage)
            });
            
            if(patch.notNil, {
                patch[5] = weight.clip(0.0, 1.0);
            });
        });
        
        this.addCommand(\patch_logic, "sisii", { arg msg;
            var srcReg = msg[1].asSymbol;
            var srcStage = msg[2];
            var dstReg = msg[3].asSymbol;
            var dstStage = msg[4];
            var logic = msg[5];
            
            var patch = patchMatrix.detect({ arg p;
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
        
        // Performance commands
        this.addCommand(\mute_a, "i", { arg msg;
            registerAMuted = msg[1] > 0;
            if(registerAMuted, {
                voices[0].set(\gate, 0, \amp, 0);
            });
        });
        
        this.addCommand(\mute_b, "i", { arg msg;
            registerBMuted = msg[1] > 0;
            if(registerBMuted, {
                voices[1].set(\gate, 0, \amp, 0);
            });
        });
        
        this.addCommand(\mute_global, "i", { arg msg;
            globalMute = msg[1] > 0;
            if(globalMute, {
                voices[0].set(\gate, 0, \amp, 0);
                voices[1].set(\gate, 0, \amp, 0);
            });
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
            var srcType = msg[1].asSymbol;
            var srcIndex = msg[2];
            var destVoice = msg[3];
            var destParam = msg[4].asSymbol;
            var amount = msg[5];
            
            var modRoute = [srcType, srcIndex, destVoice, destParam, amount];
            
            var existing = modMatrix.detect({ arg route;
                (route[0] == srcType) && (route[1] == srcIndex) &&
                (route[2] == destVoice) && (route[3] == destParam)
            });
            
            if(existing.notNil, {
                var index = modMatrix.indexOf(existing);
                modMatrix[index] = modRoute;
            }, {
                modMatrix.add(modRoute);
            });
        });
        
        this.addCommand(\remove_mod, "siis", { arg msg;
            var srcType = msg[1].asSymbol;
            var srcIndex = msg[2];
            var destVoice = msg[3];
            var destParam = msg[4].asSymbol;
            
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
            var lfoNum = msg[1].clip(0, 3);
            var rate = msg[2].clip(0.01, 20);
            
            lfoRates[lfoNum] = rate;
            lfoSynths[lfoNum].set(\rate, rate);
        });
        
        this.addCommand(\lfo_shape, "ii", { arg msg;
            var lfoNum = msg[1].clip(0, 3);
            var shape = msg[2].clip(0, 4);
            
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
    }
}