# Two Tangles v0.1

A dual shift register synthesis and sequencing instrument for Norns + Grid.

Two Tangles is inspired by the Lorre Mill Double Knot, implementing two 8-stage shift registers that can cross-patch and influence each other through a flexible routing matrix. Each shift register controls a voice with extensive sound shaping capabilities, while an advanced modulation system allows for evolving, generative patterns.

---

## Requirements

- **Norns** (any version)
- **Grid 128** (varibright recommended)
- **Audio input** (optional, for audio modulation features)

---

## Quick Start

1. **Install** Two Tangles via Maiden
2. **Connect** your Grid
3. **Load** the script
4. **Press K1** (start clock)
5. **Press** Grid column 1, row 1 (Register A output, stage 0)
6. **Press** Grid column 16, row 1 (Register B input, stage 0)
7. You've created your first patch! The shift registers are now connected.

---

## Core Concepts

### Shift Registers

Two Tangles has two 8-stage shift registers (A and B). Each stage holds a value from 0.0 to 1.0. On each clock tick:

1. Values shift through the register (stage 7 ← 6 ← 5... ← 1 ← 0)
2. Stage 0 receives a new value based on patches
3. Stage values control voice parameters

Think of it like a bucket brigade where water (values) passes from bucket to bucket, with the option to mix in water from the other brigade.

### Patching

**Patches** connect shift register stages together:

- **Source**: Any stage output (columns 1 or 15 on Grid)
- **Destination**: Any stage input (columns 2 or 16 on Grid)
- **Logic Operation**: How the signal is processed (AND, OR, ADD, etc.)
- **Weight**: How much influence (0-100%)

Patches can be:
- **Self-feedback**: Register A stage 7 → Register A stage 0
- **Cross-register**: Register A stage 3 → Register B stage 0
- **Complex networks**: Multiple patches targeting one stage

### Voice Synthesis

Each register drives one voice. The 8 stages map to parameters:

- **Stage 0**: Root pitch (quantized to scale)
- **Stage 1**: Harmonic intervals
- **Stage 2**: Gate/trigger
- **Stage 3**: Filter cutoff
- **Stage 4**: Filter resonance
- **Stage 5**: Waveshape morph
- **Stage 6**: FM amount / Sub oscillator
- **Stage 7**: FM ratio / Timbral variation

---

## Interface Overview

### Norns

**Five Pages** (hold K1 to cycle):
1. **Main**: Pattern view, patch info
2. **Clock**: Tempo, divisions, swing
3. **Performance**: Mute, freeze, pattern length, chaos
4. **Audio Input**: External audio modulation
5. **Mod Matrix**: Advanced modulation routing

**Keys:**
- **K1**: Start/Stop (hold: change page)
- **K2**: Cancel/Reset
- **K3**: Context-dependent (delete, toggle, etc.)

**Encoders:**
- **E1**: Tempo (or page-specific)
- **E2**: Logic operation (or page-specific)
- **E3**: Patch weight (or page-specific)

### Grid (128)

**Columns 1-2**: Register A (output | input)
**Columns 3**: Patch weight control
**Columns 6-11**: Logic operations (13 operations)
**Columns 15-16**: Register B (output | input)

**Row 8** (Performance controls):
- **Col 4**: Clock A enable/mute
- **Col 5**: Tap tempo
- **Col 6**: Randomize A
- **Col 7**: Clear A
- **Col 8**: Copy A → B
- **Col 9**: Copy B → A
- **Col 10**: Clear B
- **Col 11**: Randomize B
- **Col 12**: Clock B enable/mute
- **Col 13**: Start/Stop
- **Col 14**: Reset
- **Col 16**: Reset on downbeat

**Mod Matrix Page** (Page 5):
- **Cols 1-8**: Modulation sources
- **Cols 9-14**: Modulation destinations (per voice)

---

## Logic Operations

| Operation | Description | Musical Use |
|-----------|-------------|-------------|
| **DIRECT** | Pass through unchanged | Basic routing |
| **AND** | Both must be high | Rhythmic gating |
| **OR** | Either can be high | Combining patterns |
| **XOR** | One but not both | Complementary rhythms |
| **ADD** | Sum (clipped) | Building intensity |
| **MULTIPLY** | Ring modulation | Timbral complexity |
| **SUBTRACT** | Difference | Subtractive patterns |
| **MIN** | Lower value | Limiting |
| **MAX** | Higher value | Peak following |
| **AVERAGE** | Mean of both | Smoothing |
| **INVERT** | 1 - value | Phase inversion |
| **GREATER** | Binary comparison | Conditional logic |
| **MODULO** | Cycling patterns | Rhythmic loops |

---

## Workflow Examples

### Example 1: Self-Evolving Drone

**Goal**: Create a slowly evolving ambient texture

**Steps**:
1. Set tempo to 40 BPM
2. Clock div A = 4, Clock div B = 6 (slow polyrhythm)
3. **Patch 1**: Register A, stage 7 → A, stage 0 (MULTIPLY, 80%)
4. **Patch 2**: Register B, stage 5 → A, stage 3 (ADD, 40%)
5. Randomize both registers (Grid row 8)
6. Set pattern length A = 6, B = 8
7. Add slight chaos (10-20%) for drift

**Result**: Slow-moving harmonies with evolving filter movement

---

### Example 2: Rhythmic Interaction

**Goal**: Two voices playing complementary rhythms

**Steps**:
1. Tempo: 120 BPM
2. Clock div A = 1, B = 1 (both on quarter notes)
3. **Patch 1**: A, stage 2 → B, stage 2 (XOR, 100%)
4. **Patch 2**: B, stage 7 → A, stage 0 (DIRECT, 60%)
5. **Patch 3**: A, stage 7 → B, stage 0 (DIRECT, 60%)
6. Set pattern length A = 3, B = 4

**Result**: Register A and B trade hits (XOR gates), creating 3 against 4 polyrhythm with melodic exchange

---

### Example 3: Audio-Reactive Sequence

**Goal**: External audio controls the sequence

**Steps**:
1. Connect audio source to Norns input
2. Go to Audio Input page (page 4)
3. Set input mod amount: 70%
4. Set target: "All"
5. Set gain to taste
6. Create feedback patches in registers
7. Speak/play into mic

**Result**: Shift registers respond to input dynamics and pitch, creating reactive patterns

---

### Example 4: LFO Modulated Timbre

**Goal**: Slowly shifting timbres on both voices

**Steps**:
1. Go to Mod Matrix page (page 5)
2. Set LFO 1 rate: 0.2 Hz, shape: Sine
3. Set LFO 2 rate: 0.33 Hz, shape: Triangle
4. **Mod 1**: LFO1 → Both Voices Filter Freq (50%)
5. **Mod 2**: LFO2 → Both Voices Waveshape (30%)
6. Create simple feedback patches
7. Let it evolve

**Result**: Timbres morph slowly, independent of shift register patterns

---

### Example 5: Generative Melody with Chaos

**Goal**: Controlled randomness creating melodies

**Steps**:
1. Tempo: 100 BPM
2. Pattern length A = 5, B = 7 (prime numbers)
3. **Patch 1**: A, stage 4 → A, stage 0 (ADD, 60%)
4. **Patch 2**: B, stage 3 → A, stage 1 (MULTIPLY, 40%)
5. Randomize Register A
6. Set mutation rate: 5% (slow evolution)
7. Set chaos: 15% (gentle wobble)

**Result**: Melodies slowly mutate while maintaining coherence

---

### Example 6: Percussive Patterns

**Goal**: Drum-like rhythms using short gates

**Steps**:
1. Tempo: 130 BPM, swing: 65% (shuffle feel)
2. Clock div A = 1, B = 2
3. Pattern length A = 4, B = 3
4. Stage mapping: Set stage 2 to mode 1 (probability gates)
5. **Patch 1**: A, stage 7 → A, stage 2 (OR, 100%)
6. Set slew mode: Sample-Hold (snappy)
7. Increase filter resonance (stage 4 values)

**Result**: Tight, percussive hits with evolving rhythms

---

### Example 7: Call and Response

**Goal**: Two voices trading phrases

**Steps**:
1. Tempo: 90 BPM
2. Pattern length A = 8, B = 8
3. Mute Register B
4. Build pattern in A, then freeze A
5. Copy A → B (Grid col 8, row 8)
6. Unmute B, mute A
7. Let B evolve for a few bars
8. Unmute A, alt-mute between them

**Result**: Structured call-and-response phrases

---

### Example 8: Extreme Feedback

**Goal**: Chaotic, dense textures

**Steps**:
1. Tempo: 160 BPM
2. Clock mult A = 2x, B = 4x (double/quad speed)
3. **Patch 1**: A, stage 7 → B, stage 0 (ADD, 100%)
4. **Patch 2**: B, stage 7 → A, stage 0 (ADD, 100%)
5. **Patch 3**: A, stage 3 → A, stage 0 (MULTIPLY, 80%)
6. **Patch 4**: B, stage 2 → B, stage 0 (XOR, 100%)
7. Set feedback amount: 150%
8. Chaos: 30%

**Result**: Dense, chaotic textures with complex rhythmic interactions

---

## Parameter Reference

### Clock
- **Tempo**: 20-300 BPM
- **Clock Source**: Internal / MIDI sync
- **Clock Div A/B**: 1, 2, 3, 4, 6, 8, 12, 16, 24, 32
- **Swing**: 0-100% (50% = straight)
- **Swing Subdiv**: 8th notes / 16th notes
- **Reset on Downbeat**: Auto-reset pattern every N beats
- **Bar Length**: 4, 8, 16, 32, 64 beats
- **Clock A/B Enable**: Per-register on/off

### Voice
- **Slew Mode**: Sample-Hold (stepped) / Slew (smooth)
- **Slew Time**: 1ms - 1s
- **Unpatched Stages**: Hold Zero / Random
- **Multi-Patch Mode**: Average / Sum / Max / Min
- **Global Feedback**: 0-100%

### Performance
- **Mute A/B**: Silence individual registers
- **Freeze A/B**: Stop shifting, hold pattern
- **Pattern Length A/B**: 1-8 active stages
- **Clock Mult A/B**: 0.25x - 4x speed
- **Feedback Amount**: 0-200% (quick control)
- **Chaos**: 0-100% controlled randomness
- **Mutation**: 0-100% random stage changes

### Audio Input
- **Input Mod Amount**: 0-100%
- **Input Mod Target**: Pitch / Gates / All / Complex
- **Input Modulates**: Register A / B / Both
- **Input Gain**: 0-4x
- **Input Smoothing**: 1ms - 1s

### Stage Probabilities
- Per register, per stage: 0-100% chance to update

### Stage Mappings
- Per register, per stage: 3 alternate modes
- Changes how each stage affects the voice

### Modulation Matrix
- 4 LFOs with rate (0.01-20 Hz) and shape control
- 24 mod sources → 11 destinations per voice
- Amount: -100% to +100%

---

## Performance Tips

### Building Complexity
1. Start with one register, simple patches
2. Add second register once first is interesting
3. Layer modulations gradually
4. Use freeze to capture good moments

### Live Manipulation
- **Mute/unmute** for arrangement
- **Pattern length** for rhythmic variation
- **Clock multipliers** for buildups
- **Chaos/mutation** for evolution
- **Freeze** for dramatic stops

### Sound Design
- **Short pattern lengths** (1-3) = rhythmic loops
- **Long pattern lengths** (6-8) = evolving sequences
- **High feedback** = complex interactions
- **Low feedback** = predictable patterns
- **Slew mode** = smooth vs. stepped character

### Saving Presets
- Use Norns PSET system (PARAMETERS > PSET)
- Patches and modulations save automatically
- 99 preset slots available

---

## Troubleshooting

**No sound?**
- Check clock is running (K1)
- Verify clock enables (Grid row 8, cols 4 & 12)
- Check mutes (Performance page or Grid)
- Ensure at least one patch exists

**Registers not moving?**
- Check freeze state (Performance page)
- Verify clock divisions aren't too high
- Check stage probabilities (might be set to 0%)

**Patches not working?**
- Check global feedback amount
- Verify patch weight isn't 0%
- Try different logic operations

**Too chaotic?**
- Reduce feedback amount
- Lower chaos and mutation
- Use simpler logic operations (DIRECT, AVERAGE)
- Reduce number of patches

**Too static?**
- Increase pattern lengths
- Add mutation (5-10%)
- Use more complex logic (XOR, MODULO)
- Add modulation matrix routings

---

## Technical Notes

### Audio Engine
- Custom SuperCollider engine
- Dual voices with independent synthesis
- Moog-style ladder filter
- FM synthesis with musical ratios
- Sub oscillator and noise generator

### Shift Register Implementation
- One-sample delay prevents infinite loops
- Patch matrix evaluated per clock tick
- 13 logic operations for signal processing
- Quantized pitch output (minor pentatonic default)

### Modulation System
- 4 independent LFO generators
- Audio input analysis (envelope + pitch tracking)
- Clock-synced modulation sources
- Per-voice destination routing

### File Structure
```
/home/we/dust/code/two_tangles/
├── two_tangles.lua          (main script)
├── lib/
│   └── Engine_TwoTangles.sc (SuperCollider engine)

/home/we/dust/data/two_tangles/
├── patches_N.json           (patch matrices per preset)
└── mods_N.json             (modulations per preset)
```

---

## Credits

**Concept**: Inspired by Lorre Mill Double Knot
**Development**: [Your Name]
**Version**: 0.1
**License**: MIT

---

## Changelog

### v0.1 (Initial Release)
- Dual 8-stage shift registers
- 13 logic operations
- Full Grid interface with visual patching
- 5-page Norns UI
- Clock system with MIDI sync, swing, divisions
- Performance macros (mute, freeze, pattern length, etc.)
- Audio input modulation
- Modulation matrix with 4 LFOs
- PSET integration
- Comprehensive parameter control

---

## Future Ideas

- More scales/quantization options
- MIDI note output
- Sequencer recording mode
- Visual scope display
- Additional synthesis models
- Macro controls
- CV output (via Crow)

---

## Support

For issues, questions, or patches to share:
- [lines forum thread]
- [GitHub issues]

---

**Now go make some tangles!** 🎛️✨
