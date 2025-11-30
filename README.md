# Two Tangles v0.2.1

A modular shift register synthesis and sequencing instrument for Norns + Grid.

Two Tangles is inspired by the Lorre Mill Double Knot, implementing two 8-stage shift registers that generate evolving patterns. These patterns can be routed to control 2-4 independent synthesizer voices through a flexible modulation matrix. The shift registers create data through feedback loops and cross-patching, while voices respond with continuous drone-like tones that can be rhythmically gated and modulated.

---

## Requirements

- **Norns** (any version)
- **Grid 128** (varibright recommended)
- **Audio input** (optional, for audio modulation features)

---

## Quick Start

1. **Install** Two Tangles via Maiden
2. **Connect** your Grid
3. **Create a source patch**:
   - Press Grid column 4, row 4 (high source = 0.75)
   - Press Grid column 2, row 1 (Register A input, stage 0)
   - You've patched `high → A0`
4. **Add feedback**:
   - Press Grid column 1, row 1 (A0 output)
   - Press Grid column 2, row 1 (A0 input)
   - You've patched `A0 → A0` (self-feedback loop)
5. **Route to voice**:
   - Turn **E1** to navigate to Page 5 (Voice Mod)
   - Or hold Grid **[16,7]** and press **[1,5]** to jump directly
6. **Add modulation**:
   - Ensure Voice 1 is selected (columns 13-14, row 1 should be bright)
   - Ensure Register A is selected (column 15, row 1 should be bright)
   - Press **column 2, row 1** (A0 → Gate parameter)
7. **Start the clock**:
   - Press Grid **column 13, row 8** (Start/Stop button)
8. You should now hear a continuous drone tone!

---

## Core Concepts

### Architecture Overview

Two Tangles uses a **decoupled modular architecture**:

```
External Sources → Shift Registers (Pattern Generation) → Voice Mod Matrix → Synthesizer Voices
```

1. **External Sources** inject values into the system
2. **Shift Registers** create evolving patterns through feedback and patching
3. **Voice Modulation Matrix** routes register values to voice parameters
4. **Synthesizer Voices** (2-4) produce continuous sound with ADSR envelopes

### Shift Registers

Two Tangles has two 8-stage shift registers (A and B). Each stage holds a value from 0.0 to 1.0. On each clock tick:

1. Values shift through the register (stage 7 ← 6 ← 5... ← 1 ← 0)
2. Stage 0 receives a new value based on **patches from other stages or sources**
3. All voices update, applying modulations from the current register values

Think of registers as **pattern generators** rather than direct voice controllers. They're like complex LFOs that evolve based on feedback and logic operations.

### External Sources

To get non-zero values into the system, patch from **external sources** (Grid column 4):

- **random** (row 1): New random value each step - excellent for generative patterns
- **low** (row 2): Constant 0.25 - stable low offset
- **mid** (row 3): Constant 0.5 - centered value
- **high** (row 4): Constant 0.75 - stable high offset
- **max** (row 5): Constant 1.0 - maximum value
- **param1** (row 6): Controllable via encoder - real-time control
- **param2** (row 7): Controllable via encoder - real-time control

**Example**: Patch `random → A0` then `A0 → A0` creates a self-evolving random pattern.

### Register Patching

**Patches** connect sources and register stages together:

- **Source**: External source OR register stage output (columns 1, 4, or 15)
- **Destination**: Register stage input (columns 2 or 16)
- **Logic Operation**: How the signal is processed (AND, OR, ADD, etc.)
- **Weight**: How much influence (0-100%)

Patches create **feedback networks** that generate complex evolving patterns:
- **Self-feedback**: `A0 → A0` (stage feeds itself)
- **Circular feedback**: `A0 → A1 → A2 → A0` (values circulate)
- **Cross-register**: `A3 → B0` and `B5 → A2` (registers influence each other)
- **Source injection**: `random → A0` (external entropy)

### Voice Modulation Matrix

**Page 5** lets you route register stage values to voice parameters:

- **2-4 Voices** (configurable in params menu)
- **12 Parameters per voice**: Pitch, Gate, Amp, Waveshape, Filter, FM, etc.
- **Any stage can modulate any parameter on any voice**
- **Independent routing**: Voice 1 responds to different stages than Voice 2

**Example**:
- Register A generates an evolving pattern via feedback
- Route `A0 → Voice 1 Gate` (rhythm)
- Route `A1 → Voice 1 Pitch` (melody)
- Route `B0 → Voice 2 Filter` (timbre)

### Voice Synthesis

Voices are **continuous synthesizers** with:
- Multiple waveforms (sine, triangle, saw, pulse)
- RLPF resonant lowpass filter
- FM synthesis
- Sub oscillator
- Noise generator
- ADSR envelope (responds to gate modulation)
- Stereo panning

When a register stage is routed to the **gate** parameter, it controls note on/off. When routed to **pitch**, it controls frequency. This allows for both **rhythmic sequences** and **sustained drones**.

---

## Interface Overview

### Norns

**Five Pages**:
1. **Main**: Pattern view, patch info, register visualization
2. **Clock**: Tempo, divisions, swing, sync options
3. **Performance**: Mute, freeze, pattern length, chaos, feedback
4. **Audio Input**: External audio modulation (legacy feature)
5. **Voice Mod**: Voice modulation matrix - route stages to voice parameters

**Keys:**
- **K1**: Hold for alternate encoder functions (clock start/stop via grid)
- **K2**: Cancel/Reset
- **K3**: Context-dependent (delete, toggle, etc.)

**Encoders:**
- **E1**: **Page navigation** (turn to switch pages 1-5)
- **E2**: Page-specific control
- **E3**: Page-specific control

**K1 Hold + Encoders (Alternate Functions):**

*Page 1 (Main):*
- **K1+E1**: Tempo (20-300 BPM)
- **K1+E2**: Clock division A
- **K1+E3**: Clock division B

*Page 2 (Clock):*
- **K1+E2**: Swing subdivision (8th/16th)

*Page 3 (Performance):*
- **K1+E2**: Clock multiplier A (0.25x-4x)
- **K1+E3**: Clock multiplier B (0.25x-4x)

**Normal Encoder Functions (without K1):**

*Page 1 (Main):*
- **E2**: Logic operation selection
- **E3**: Patch weight

*Page 2 (Clock):*
- **E2**: Swing amount
- **E3**: Bar length

*Page 3 (Performance):*
- **E2**: Chaos amount
- **E3**: Pattern length A

*Page 4 (Audio Input):*
- **E2**: Input modulation amount
- **E3**: Input gain

*Page 5 (Voice Mod):*
- Encoders used for future features

### Grid (128) - Main Pages

**Columns 1-2**: Register A (output | input)
**Column 3**: Patch weight control (rows 1-8 = weight levels)
**Column 4**: External sources (rows 1-7)
**Columns 6-11**: Logic operations (13 operations across rows)
**Columns 15-16**: Register B (output | input)

**Row 7, Column 16**: **ALT button** (hold for alternative grid controls)

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

### ALT Mode (Hold Grid [16,7])

When holding the ALT button, the grid shows:

**Row 1 (Page Navigation):**
- **Col 1**: Jump to Page 1 (Main)
- **Col 2**: Jump to Page 2 (Clock)
- **Col 3**: Jump to Page 3 (Performance)
- **Col 4**: Jump to Page 4 (Audio Input)
- **Col 5**: Jump to Page 5 (Voice Mod)

**Row 2 (Clear Registers):**
- **Col 1**: Clear Register A
- **Col 2**: Clear Register B

**Row 3 (Randomize Registers):**
- **Col 1**: Randomize Register A
- **Col 2**: Randomize Register B

**Row 4 (Utilities):**
- **Col 1**: Clear all patches

### Grid - Page 5 (Voice Mod Matrix)

**Columns 1-12**: Voice parameters (Pitch, Gate, Amp, Wave, Filter, Res, FM, FMR, PW, Sub, Noise, Pan)
**Rows 1-8**: Register stages from selected register (A or B)
**Columns 13-14**: Voice selection (1-4, depending on voice_count setting)
**Column 15**: Register selection (A or B)
**Column 16**: Reserved for future features

**Workflow**:
1. Select voice (press column 13/14)
2. Select register source (press column 15, row 1 or 2)
3. Click at stage row × parameter column to toggle modulation
4. Bright LED = active modulation

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

### Example 1: Simple Generative Drone

**Goal**: Single voice with evolving pitch and rhythm

**Steps**:
1. **Main Page**: Press col 4, row 1 (random source)
2. Press col 2, row 1 (patch `random → A0`)
3. Press col 1, row 1 then col 2, row 1 (patch `A0 → A0` for self-feedback)
4. **Page 5** (hold K1 to cycle): Select Voice 1, Register A
5. Press col 2, row 1 (`A0 → Gate`)
6. Press col 1, row 2 (`A1 → Pitch`)
7. **K1** to start clock

**Result**: Voice 1 plays evolving random notes with rhythmic gates

---

### Example 2: Dual Voices with Cross-Modulation

**Goal**: Two voices with independent but related patterns

**Steps**:
1. Create random source feeding Register A with feedback:
   - `random → A0`, `A0 → A0`
2. Cross-patch to Register B:
   - `A3 → B0`, `B0 → B0`
3. **Page 5**:
   - Voice 1, Register A: `A0 → Gate`, `A1 → Pitch`, `A2 → Filter`
   - Voice 2, Register B: `B0 → Gate`, `B1 → Pitch`, `B3 → Pan`
4. Start clock

**Result**: Two voices with related but independent evolving patterns

---

### Example 3: Four-Voice Chord Generator

**Goal**: Harmonic chord progressions across 4 voices

**Steps**:
1. **Params menu**: Set Voice Count = 4
2. Create stable pattern with `mid → A0`, `A0 → A0`
3. Add variation with `A1 → A0 (ADD, 30%)`
4. **Page 5** - Route A0 to all 4 voice gates:
   - Voice 1: `A0 → Gate`, `A0 → Pitch`
   - Voice 2: `A0 → Gate`, `A1 → Pitch`
   - Voice 3: `A0 → Gate`, `A2 → Pitch`
   - Voice 4: `A0 → Gate`, `A3 → Pitch`
5. Start clock

**Result**: Four voices playing together with different pitches from different register stages

---

### Example 4: Rhythmic Interplay

**Goal**: Complex polyrhythmic patterns

**Steps**:
1. Set tempo 130 BPM, pattern length A=3, B=4
2. Register A: `random → A0`, `A0 → A1`, `A1 → A0` (circular pattern)
3. Register B: `random → B0`, `B0 → B1`, `B1 → B0`
4. **Page 5**:
   - Voice 1, Register A: `A0 → Gate`, `A1 → Pitch`, `A2 → Filter`
   - Voice 2, Register B: `B0 → Gate`, `B1 → Pitch`, `B2 → Amp`

**Result**: 3-against-4 polyrhythm with independent gate patterns

---

### Example 5: Slow-Moving Ambient Texture

**Goal**: Long sustained drones with slow modulation

**Steps**:
1. Tempo: 40 BPM, Clock div A=8 (very slow)
2. Register A: `low → A0`, `A0 → A0` (stable low value)
3. Register B: `random → B0`, `B0 → B1 → B2 → B0` (slow evolution)
4. **Page 5**:
   - Voice 1, Reg A: `A0 → Gate` (always on), `A0 → Amp` (stable)
   - Voice 1, Reg B: `B0 → Pitch`, `B1 → Filter`, `B2 → FMRatio`
5. Set slew mode: Slew, slew time: 500ms

**Result**: Sustained drone with slowly evolving timbre from Register B

---

### Example 6: Percussive Patterns

**Goal**: Short rhythmic hits

**Steps**:
1. Tempo: 140 BPM, pattern length A=4
2. Register A: `random → A0`, `A0 → A0`
3. **Page 5**:
   - Voice 1, Reg A: `A0 → Gate`, `A1 → Pitch`, `A2 → Amp`
4. Params: Set ADSR release time very short (adjust in engine if needed)
5. Set slew mode: Sample-Hold for sharp transients

**Result**: Percussive rhythmic patterns

---

### Example 7: Call and Response Between Voices

**Goal**: Two voices trading phrases

**Steps**:
1. Register A: `random → A0`, `A0 → A1 → A0` (circular feedback)
2. Register B: `A7 → B0` (copy end of A to start of B), `B0 → B0`
3. **Page 5**:
   - Voice 1, Reg A: `A0 → Gate`, `A1 → Pitch`
   - Voice 2, Reg B: `B0 → Gate`, `B1 → Pitch`
4. Alternate mutes between Voice 1 and Voice 2 manually

**Result**: Voices echo each other's patterns

---

### Example 8: Dense Textural Layers

**Goal**: Four voices creating thick textures

**Steps**:
1. **Params**: Voice Count = 4
2. Create complex feedback network:
   - `random → A0`, `A0 → A1`, `A1 → A2`, `A2 → A0`
   - `A3 → B0`, `B0 → B3`, `B3 → A5`
3. **Page 5** - Route different stages to each voice:
   - Voice 1: `A0 → Gate`, `A1 → Pitch`, `A2 → Filter`
   - Voice 2: `A3 → Gate`, `A4 → Pitch`, `A5 → Pan`
   - Voice 3: `B0 → Gate`, `B1 → Pitch`, `B2 → WaveShape`
   - Voice 4: `B3 → Gate`, `B4 → Pitch`, `B5 → NoiseAmount`
4. Add chaos: 15%, feedback: 120%

**Result**: Dense evolving texture with 4 independent but related voices

---

## Parameter Reference

### Voice
- **Voice Count**: 2 or 4 voices (requires restart to take effect)
- **Slew Mode**: Sample-Hold (stepped) / Slew (smooth)
- **Slew Time**: 1ms - 1s (smooths parameter changes)
- **Unpatched Stages**: Hold Zero / Random
- **Multi-Patch Mode**: Average / Sum / Max / Min
- **Global Feedback**: 0-100%

### Clock
- **Tempo**: 20-300 BPM
- **Clock Source**: Internal / MIDI sync
- **Clock Div A/B**: 1, 2, 3, 4, 6, 8, 12, 16, 24, 32
- **Swing**: 0-100% (50% = straight)
- **Swing Subdiv**: 8th notes / 16th notes
- **Reset on Downbeat**: Auto-reset pattern every N beats
- **Bar Length**: 4, 8, 16, 32, 64 beats
- **Clock A/B Enable**: Per-register on/off

### Performance
- **Mute A/B**: Silence individual registers (stops voice updates from that register)
- **Freeze A/B**: Stop shifting, hold pattern
- **Pattern Length A/B**: 1-8 active stages
- **Clock Mult A/B**: 0.25x - 4x speed
- **Feedback Amount**: 0-200% (quick control)
- **Chaos**: 0-100% controlled randomness added to register values
- **Mutation**: 0-100% random stage changes per step

### Stage Probabilities
- Per register, per stage: 0-100% chance to update
- Lower probability = stage skips updates = rhythmic variation

### Stage Mappings (Legacy)
- Per register, per stage: 3 alternate modes
- Note: With new architecture, use Voice Mod page instead

---

## Performance Tips

### Building Patches from Scratch

1. **Start with a source**: Pick `random` for generative, `mid/high` for stable
2. **Create self-feedback**: Source → A0, A0 → A0
3. **Go to Page 5**: Route A0 to Gate and Pitch for basic sequence
4. **Start clock**: You should hear evolving tones
5. **Add complexity**: More stages, cross-register patches, multiple voices

### Understanding Feedback Loops

- **No feedback = decay**: Without loops, values return to zero
- **Self-feedback**: `A0 → A0` maintains and transforms value
- **Circular**: `A0 → A1 → A2 → A0` creates rotating patterns
- **Cross-register**: `A7 → B0` shares pattern end with other register

### Voice Modulation Strategy

- **Gate**: Controls note on/off - essential for rhythm
- **Pitch**: Controls frequency - creates melody
- **Filter**: Controls timbre - adds movement
- **Amp**: Controls volume - creates dynamics
- **Others**: Add timbral complexity (FM, waveshape, sub osc)

### Live Manipulation

- **Switch voices**: Change which voice/register you're modulating
- **Toggle mods**: Add/remove routings to reshape sound
- **Mute registers**: Stop pattern generation without clearing
- **Freeze**: Capture interesting patterns
- **Chaos/Mutation**: Inject controlled randomness

### Sound Design

- **Short ADSR release** + fast tempo = percussive
- **Long ADSR sustain** + slow tempo = ambient drones
- **Many modulations** = complex evolving timbre
- **Minimal modulations** = predictable, focused sound
- **High feedback amount** = more interaction, instability
- **Low feedback** = more controlled, stable patterns

### Saving Work

- Use Norns PSET system (PARAMETERS > PSET)
- Patches and voice modulations save automatically
- 99 preset slots available
- Consider naming presets descriptively

---

## Troubleshooting

**No sound?**
- Check clock is running (K1)
- Verify at least one **voice modulation** exists (Page 5)
- Ensure the modulation includes **gate** and **pitch**
- Check that register has non-zero values (needs source + feedback)
- Verify voice not muted

**Registers stay at zero?**
- You need **external sources** (column 4) to inject values
- You need **feedback loops** to maintain values
- Example: `random → A0` and `A0 → A0`

**Patches not working?**
- Patches alone don't make sound - they generate patterns in registers
- You need **voice modulations** (Page 5) to route patterns to sound
- Check global feedback amount isn't zero

**Voice modulations not working?**
- Ensure register stages have non-zero values
- Check that you've selected the correct voice and register
- Try routing to Gate and Pitch first for basic test

**Too chaotic?**
- Reduce chaos and mutation parameters
- Use simpler logic operations (DIRECT, AVERAGE)
- Reduce feedback amount
- Use stable sources (mid, high) instead of random

**Too static?**
- Add `random` source injection
- Increase pattern lengths
- Add mutation (5-15%)
- Use more complex logic (XOR, MULTIPLY, MODULO)
- Add more feedback loops

**All 4 voices playing?**
- Check voice count setting in params (2 vs 4)
- Verify voice modulations exist for each voice on Page 5
- Check per-voice routing isn't muted

---

## Technical Notes

### Architecture

**v0.2 introduces decoupled voices:**
- Shift registers are pure **pattern generators**
- Voices are **independent synthesizers**
- **Voice Modulation Matrix** connects the two
- Allows 2-4 voices vs. previous fixed 2 (1 per register)

### Audio Engine
- Custom SuperCollider engine
- Up to 4 persistent voices with ADSR envelopes
- Voices always exist, gate parameter controls on/off
- RLPF resonant lowpass filter
- FM synthesis with musical ratios
- Sub oscillator and noise generator
- Stereo panning per voice

### Shift Register Implementation
- 8 stages per register (A and B)
- Values 0.0-1.0 representing voltage-like control data
- Patch matrix evaluated per clock tick
- 13 logic operations for signal processing
- External sources inject initial values
- Feedback networks create evolving patterns

### Voice Modulation System
- Per-voice routing: any stage → any parameter
- 12 parameters per voice can be modulated
- Modulation applied every clock step
- Amount fixed at 1.0 (future: adjustable per route)
- Gate parameter uses threshold (>0.4 = gate open)
- Pitch modulation uses ±2 octave range from base freq

### File Structure
```
/home/we/dust/code/two_tangles/
├── two_tangles.lua          (main script)
├── lib/
│   └── Engine_TwoTangles.sc (SuperCollider engine)

/home/we/dust/data/two_tangles/
├── patches_N.json           (register patch matrices per preset)
└── voice_mods_N.json        (voice modulations per preset - NEW in v0.2)
```

---

## Credits

**Concept**: Inspired by Lorre Mill Double Knot
**Architecture**: Modular shift register synthesis
**Version**: 0.2
**License**: MIT

---

## Changelog

### v0.2.1 (UI/UX Improvements)
- **E1 global page navigation**: Turn E1 to quickly switch between pages 1-5
- **ALT button on grid [16,7]**: Hold for alternative controls including page navigation
- **K1 hold modifier**: Access alternate encoder functions (tempo, clock divs, multipliers)
- **Improved screen help text**: Dynamic display shows current encoder assignments
- **Quick utility access**: Clear/randomize registers via ALT mode
- **Direct page jumping**: Hold ALT and press row 1 buttons to jump to any page
- **Tempo control**: K1+E1 on Page 1 for quick tempo adjustments

### v0.2 (Major Architecture Update)
- **Decoupled voices from registers**: Voices are now independent synthesizers
- **Voice count configurable**: 2 or 4 voices (params menu)
- **Voice Modulation Matrix**: New Page 5 for routing stages to voice parameters
- **External sources**: 7 sources (random, constants, params) for injecting values
- **Removed stage mappings**: Replaced with flexible voice modulation routing
- **Updated register logic**: Registers are pure pattern generators
- **Persistent voices**: ADSR envelopes with gate control
- **12 modulatable parameters per voice**: Pitch, Gate, Amp, Wave, Filter, Res, FM, FMR, PW, Sub, Noise, Pan

### v0.1 (Initial Release)
- Dual 8-stage shift registers
- 13 logic operations
- Full Grid interface with visual patching
- 5-page Norns UI
- Clock system with MIDI sync, swing, divisions
- Performance macros (mute, freeze, pattern length, etc.)
- Audio input modulation
- Legacy modulation matrix with 4 LFOs
- PSET integration

---

## Future Ideas

- **Per-modulation amount control** (currently fixed at 1.0)
- **Modulation polarity modes** (unipolar/bipolar/inverted)
- **Quick actions on column 16** (clear, copy, randomize per voice)
- **Per-voice base parameters** (octave, detune, volume offsets)
- **Additional voice types** (different synthesis models)
- **More quantization scales** for pitch modulation
- **MIDI note output** for external synths
- **Visual scope** of register evolution
- **CV output** via Crow

---

## Support

For issues, questions, or patches to share:
- [lines forum thread]
- [GitHub issues]

---

**Now go make some tangles!** 🎛️✨
