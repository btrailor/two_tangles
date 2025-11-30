# Pitch Quantization Design

## Feature Request

Add pitch quantization options to constrain pitch modulation to selectable musical modes/scales.

## Current Pitch Behavior

**Location**: [Engine_TwoTangles.sc:851-854](lib/Engine_TwoTangles.sc#L851-L854)

```supercollider
\pitch, {
    // Modulate pitch: srcValue maps to ±2 octaves around base
    var semitones = (srcValue - 0.5) * 2 * amount * 24;
    freq = freq * (semitones / 12).midiratio;
```

### How It Works

1. Source value (0.0-1.0) maps to pitch range
2. Centered at 0.5 (no change)
3. Range: ±2 octaves (±24 semitones) with amount=1.0
4. **Continuous**: Can produce any microtonal frequency

### Example Values

```
srcValue = 0.0  → -24 semitones (2 octaves down)
srcValue = 0.25 → -12 semitones (1 octave down)
srcValue = 0.5  → 0 semitones (center/base pitch)
srcValue = 0.75 → +12 semitones (1 octave up)
srcValue = 1.0  → +24 semitones (2 octaves up)
```

## Quantization Concept

**Quantization** = Snap continuous pitch values to discrete scale degrees

### Example: C Major Scale

```
Without quantization:
  srcValue = 0.55 → +2.4 semitones (C# + 40 cents, microtonal)

With C Major quantization:
  srcValue = 0.55 → +2 semitones (D, snapped to scale)
```

## Scale Definitions

### Major Musical Modes

**Ionian (Major)**
- Intervals: W W H W W W H
- Semitones: 0, 2, 4, 5, 7, 9, 11, 12
- Character: Bright, happy, stable

**Dorian**
- Intervals: W H W W W H W
- Semitones: 0, 2, 3, 5, 7, 9, 10, 12
- Character: Minor with raised 6th, jazzy

**Phrygian**
- Intervals: H W W W H W W
- Semitones: 0, 1, 3, 5, 7, 8, 10, 12
- Character: Spanish/flamenco, dark minor

**Lydian**
- Intervals: W W W H W W H
- Semitones: 0, 2, 4, 6, 7, 9, 11, 12
- Character: Major with raised 4th, dreamy

**Mixolydian**
- Intervals: W W H W W H W
- Semitones: 0, 2, 4, 5, 7, 9, 10, 12
- Character: Major with flat 7th, bluesy/rock

**Aeolian (Natural Minor)**
- Intervals: W H W W H W W
- Semitones: 0, 2, 3, 5, 7, 8, 10, 12
- Character: Sad, dark, classical minor

**Locrian**
- Intervals: H W W H W W W
- Semitones: 0, 1, 3, 5, 6, 8, 10, 12
- Character: Diminished, unstable, dissonant

### Other Useful Scales

**Chromatic (No Quantization)**
- Semitones: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
- All notes available

**Pentatonic Major**
- Semitones: 0, 2, 4, 7, 9, 12
- Character: Simple, folk, Asian

**Pentatonic Minor**
- Semitones: 0, 3, 5, 7, 10, 12
- Character: Bluesy, rock

**Blues Scale**
- Semitones: 0, 3, 5, 6, 7, 10, 12
- Character: Blues, jazz, soulful

**Harmonic Minor**
- Semitones: 0, 2, 3, 5, 7, 8, 11, 12
- Character: Exotic, Middle Eastern

**Whole Tone**
- Semitones: 0, 2, 4, 6, 8, 10, 12
- Character: Dreamy, floating, ambiguous

**Diminished (Octatonic)**
- Semitones: 0, 2, 3, 5, 6, 8, 9, 11, 12
- Character: Symmetrical, jazzy, complex

## Implementation Options

### Option A: Per-Voice Quantization (Recommended)

Each voice has its own quantization setting:

```supercollider
var <quantizeScales;  // Dictionary of scale definitions
var <voiceQuantizeScale;  // Array[voiceCount] of scale indices

alloc {
  // ... existing code ...

  // Initialize quantization
  quantizeScales = Dictionary.new;
  this.initQuantizeScales();
  voiceQuantizeScale = Array.fill(4, { 0 });  // 0 = chromatic (off)
}

initQuantizeScales {
  // Chromatic = no quantization
  quantizeScales.put(\chromatic, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);

  // Major modes
  quantizeScales.put(\ionian, [0, 2, 4, 5, 7, 9, 11, 12]);
  quantizeScales.put(\dorian, [0, 2, 3, 5, 7, 9, 10, 12]);
  quantizeScales.put(\phrygian, [0, 1, 3, 5, 7, 8, 10, 12]);
  quantizeScales.put(\lydian, [0, 2, 4, 6, 7, 9, 11, 12]);
  quantizeScales.put(\mixolydian, [0, 2, 4, 5, 7, 9, 10, 12]);
  quantizeScales.put(\aeolian, [0, 2, 3, 5, 7, 8, 10, 12]);
  quantizeScales.put(\locrian, [0, 1, 3, 5, 6, 8, 10, 12]);

  // Pentatonic
  quantizeScales.put(\pentMajor, [0, 2, 4, 7, 9, 12]);
  quantizeScales.put(\pentMinor, [0, 3, 5, 7, 10, 12]);

  // Other
  quantizeScales.put(\blues, [0, 3, 5, 6, 7, 10, 12]);
  quantizeScales.put(\harmMin, [0, 2, 3, 5, 7, 8, 11, 12]);
  quantizeScales.put(\wholeTone, [0, 2, 4, 6, 8, 10, 12]);
}

quantizePitch { arg semitones, scaleIndex;
  var scale, octave, semiInOctave, quantized;

  // If chromatic or invalid, return unchanged
  if(scaleIndex == 0, { ^semitones });

  // Get the scale (with safety check)
  scale = quantizeScales.values[scaleIndex];
  if(scale.isNil, { ^semitones });

  // Separate octave and semitone within octave
  octave = semitones.div(12);
  semiInOctave = semitones % 12;

  // Find nearest scale degree
  quantized = scale.minItem({ arg note |
    (note - semiInOctave).abs
  });

  // Return quantized pitch
  ^(octave * 12) + quantized;
}
```

### Modified Pitch Modulation

```supercollider
\pitch, {
    // Calculate raw semitones
    var rawSemitones = (srcValue - 0.5) * 2 * amount * 24;

    // Quantize if enabled
    var quantizedSemitones = this.quantizePitch(rawSemitones, voiceQuantizeScale[voiceNum]);

    // Apply to frequency
    freq = freq * (quantizedSemitones / 12).midiratio;
},
```

### OSC Commands

```supercollider
this.addCommand(\voice_quantize, "ii", { arg msg;
  var voiceNum, scaleIndex;
  voiceNum = msg[1];
  scaleIndex = msg[2];

  if(voiceNum < voiceCount, {
    voiceQuantizeScale[voiceNum] = scaleIndex;
    ("Voice " ++ voiceNum ++ " quantize: " ++ quantizeScales.keys[scaleIndex]).postln;
  });
});
```

### Option B: Global Quantization

Single quantization setting affects all voices:

**Pros**: Simpler, more predictable harmony
**Cons**: Less flexible, can't mix quantized/unquantized

### Option C: Per-Modulation Quantization

Each voice modulation route can have its own quantization:

**Pros**: Maximum flexibility
**Cons**: Very complex, harder to understand/use

**Recommendation**: Start with Option A (per-voice)

## Lua UI Integration

### Add to Page 5 (Voice Mod)

Current Page 5 shows voice modulation matrix. Add quantization controls:

```lua
-- In draw_voice_mod_page()
screen.move(0, 100)
screen.text("E2:scale E3:root")

screen.move(0, 110)
local scale_names = {
  "Chromatic", "Ionian", "Dorian", "Phrygian",
  "Lydian", "Mixolydian", "Aeolian", "Locrian",
  "Pent Maj", "Pent Min", "Blues", "Harm Min", "Whole Tone"
}
screen.text("Scale: " .. scale_names[voice_quantize_scale[selected_voice] + 1])
```

### Add Encoders

```lua
-- Page 5 encoders
if current_page == 5 then
  if n == 2 then
    -- E2: Select scale
    voice_quantize_scale[selected_voice] = util.clamp(
      voice_quantize_scale[selected_voice] + d,
      0, 12  -- 0=chromatic, 1-12=scales
    )
    engine.voice_quantize(selected_voice, voice_quantize_scale[selected_voice])
    redraw()

  elseif n == 3 then
    -- E3: Root note (future feature)
    voice_root_note[selected_voice] = util.clamp(
      voice_root_note[selected_voice] + d,
      0, 11  -- C to B
    )
    engine.voice_root(selected_voice, voice_root_note[selected_voice])
    redraw()
  end
end
```

### Parameters

```lua
for v = 0, voice_count - 1 do
  params:add_option("voice_" .. v .. "_scale", "Voice " .. v .. " Scale",
    {
      "Chromatic", "Ionian", "Dorian", "Phrygian",
      "Lydian", "Mixolydian", "Aeolian", "Locrian",
      "Pent Major", "Pent Minor", "Blues", "Harmonic Minor", "Whole Tone"
    },
    1,  -- Default to Chromatic (off)
    false  -- Not hidden
  )
  params:set_action("voice_" .. v .. "_scale", function(value)
    voice_quantize_scale[v] = value - 1  -- 0-indexed
    engine.voice_quantize(v, value - 1)
  end)

  params:add_number("voice_" .. v .. "_root", "Voice " .. v .. " Root",
    0, 11, 0,  -- C to B
    function(param) return note_names[param:get() + 1] end
  )
  params:set_action("voice_" .. v .. "_root", function(value)
    voice_root_note[v] = value
    engine.voice_root(v, value)
  end)
end
```

## Root Note Transposition

Add ability to transpose the scale root:

```supercollider
var <voiceRootNote;  // Array[voiceCount] of root notes (0-11, C-B)

quantizePitch { arg semitones, scaleIndex, rootNote;
  var scale, octave, semiInOctave, transposedSemi, quantized;

  if(scaleIndex == 0, { ^semitones });

  scale = quantizeScales.values[scaleIndex];
  if(scale.isNil, { ^semitones });

  octave = semitones.div(12);
  semiInOctave = semitones % 12;

  // Transpose to C root for quantization
  transposedSemi = (semiInOctave - rootNote) % 12;

  // Quantize
  quantized = scale.minItem({ arg note |
    (note - transposedSemi).abs
  });

  // Transpose back to original root
  quantized = (quantized + rootNote) % 12;

  ^(octave * 12) + quantized;
}
```

**Example**: Scale = Ionian, Root = D (2 semitones)
- Input: +4 semitones (E)
- Transpose to C: +2 semitones (D in C major = 2nd degree)
- Quantize: +2 semitones (D)
- Transpose to D: +4 semitones (E in D major = 2nd degree)

## Testing Scenarios

### Test 1: Major Scale Quantization
```
Setup:
  - Voice 0: Ionian scale, root C
  - Register A → Voice 0 pitch (amount 1.0)
  - Register A values: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]

Expected pitches (semitones from base):
  0.0 → -24 → -24 (C, 2 octaves down)
  0.1 → -19.2 → -19 (F, quantized)
  0.2 → -14.4 → -14 (A, quantized)
  0.3 → -9.6 → -10 (D, quantized)
  0.4 → -4.8 → -5 (G, quantized)
  0.5 → 0 → 0 (C, center)
  0.6 → +4.8 → +5 (F, quantized)
  0.7 → +9.6 → +9 (A, quantized)

Should hear: Ascending major scale (with octave jumps)
```

### Test 2: Pentatonic vs Chromatic
```
Setup:
  - Voice 0: Pentatonic Major
  - Voice 1: Chromatic (off)
  - Random source → both voices pitch (amount 0.5)

Expected:
  - Voice 0: Jumps between pentatonic notes, always "in tune"
  - Voice 1: Smooth microtonal glides, can be "out of tune"

Listen for: Voice 0 has discrete jumps, Voice 1 is continuous
```

### Test 3: Root Note Transposition
```
Setup:
  - Voice 0: Ionian, root C
  - Voice 1: Ionian, root D
  - Both modulated identically

Expected:
  - Voice 1 is 2 semitones higher than Voice 0
  - Both play same scale degrees in different keys

Listen for: Parallel harmony, different keys
```

## UI Mockup - Page 5

```
VOICE MOD - Voice 0

Mod Matrix:
 [·][·][·][·][·][·][·][·]
 [·][█][·][·][·][·][·][·]  A1→pitch

Voice 0:
Scale: Ionian
Root: C

E1:page E2:scale E3:root
K2:voice K3:clear-mods
```

## Implementation Checklist

### SuperCollider (Engine_TwoTangles.sc)
- [ ] Add quantizeScales Dictionary
- [ ] Add voiceQuantizeScale array
- [ ] Add voiceRootNote array
- [ ] Implement initQuantizeScales()
- [ ] Implement quantizePitch()
- [ ] Modify pitch modulation to call quantizePitch()
- [ ] Add OSC command: voice_quantize
- [ ] Add OSC command: voice_root
- [ ] Test quantization with various scales

### Lua (two_tangles.lua)
- [ ] Add voice_quantize_scale table
- [ ] Add voice_root_note table
- [ ] Add scale names table
- [ ] Update Page 5 drawing
- [ ] Add E2/E3 controls for scale/root
- [ ] Add parameters for each voice
- [ ] Test UI responsiveness
- [ ] Test parameter save/recall

## Files Modified

- [lib/Engine_TwoTangles.sc](lib/Engine_TwoTangles.sc) - Add quantization system
- [two_tangles.lua](two_tangles.lua) - Add UI controls and parameters

## Estimated Complexity

**Medium** - Requires SuperCollider and Lua changes, ~150 lines of code

## Priority

**Low** - New feature, not fixing existing issues

## Future Enhancements

1. **Custom scales**: User-defined scale patterns
2. **Scale per modulation**: Different scales for different mod routes
3. **Probability**: Randomize scale degree selection
4. **Chord modes**: Quantize to specific chord tones
5. **MIDI note input**: Use MIDI keyboard to define scale
