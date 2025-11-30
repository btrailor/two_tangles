# Pitch Quantization Implementation Summary

## What Was Implemented

A comprehensive pitch quantization system has been added to Two Tangles that allows each voice to have its pitch modulation constrained to musical scales.

## Features

### ✅ Comprehensive Scale Support

- **13 scales total** including chromatic (off), major modes, pentatonic, and exotic scales
- **Chromatic** (no quantization) - default setting
- **Major Modes**: Ionian, Dorian, Phrygian, Lydian, Mixolydian, Aeolian, Locrian
- **Pentatonic**: Major and Minor pentatonic scales
- **Other**: Blues, Harmonic Minor, Whole Tone

### ✅ Per-Voice Configuration

- Each of the 4 voices has independent quantization settings
- Voice can be set to chromatic (quantization off) or any musical scale
- Root note transposition (C through B) for each voice when quantized

### ✅ User Interface Integration

- **Page 5 (Voice Mod)** now displays quantization settings
- **E2**: Select scale for current voice
- **E3**: Select root note for current voice (when not chromatic)
- Visual feedback shows current scale name and root note
- When scale is chromatic, E3 controls modulation amount as before

### ✅ Parameters Menu Integration

- **PITCH QUANTIZATION section** in norns parameters
- **8 parameters total**: Scale and Root for each of 4 voices
- Settings are saved/recalled with patches
- Default: All voices set to Chromatic (quantization off)

### ✅ SuperCollider Engine Integration

- Modular quantization system with proper scale definitions
- Per-voice quantization with root note transposition
- OSC commands: `voice_quantize` and `voice_root`
- Efficient quantization algorithm that handles negative values and octave wrapping

## How It Works

### Quantization Process

1. **Source value** (0.0-1.0) from shift register/source is converted to **semitones** (±24 semitones = ±2 octaves)
2. **Quantization** snaps the continuous semitone value to the nearest scale degree
3. **Root transposition** shifts the scale to the selected root note
4. **Result** is applied as pitch modulation to the voice

### Example

```
Source Value: 0.6
Raw Semitones: +4.8 semitones (from base pitch)
Scale: Ionian (Major), Root: C
Quantized: +5 semitones (F note)
Result: Voice plays F (2nd octave above base)
```

## Usage Examples

### Musical Pattern Creation

1. Set **Voice 1** to **Pentatonic Major in C** for lead melodies
2. Set **Voice 2** to **Pentatonic Minor in G** for bass lines
3. Patch different shift register stages to voice pitch modulation
4. Create evolving harmonic patterns as registers shift

### Experimental Sounds

1. Set **Voice 1** to **Whole Tone** scale for dreamy, floating textures
2. Set **Voice 2** to **Blues** scale for soulful, expressive patterns
3. Use **Harmonic Minor** for exotic, middle-eastern flavors

### Traditional Harmony

1. Set multiple voices to **Ionian** (Major) in different root notes
2. Create chord progressions by changing root notes via parameters
3. Use **Dorian** and **Mixolydian** for modal harmony

## Technical Implementation

### Files Modified

- `lib/Engine_TwoTangles.sc` - Added quantization system (~120 lines)
- `two_tangles.lua` - Added UI and parameters (~80 lines)

### Key Components

- **Scale Dictionary** - 13 predefined musical scales
- **Quantization Algorithm** - Finds nearest scale degree with root transposition
- **UI Integration** - Page 5 controls with visual feedback
- **Parameter System** - Save/recall quantization settings

## Default Behavior

⚠️ **Important**: Quantization is **OFF by default**. All voices start with **Chromatic** scale, meaning pitch modulation behaves exactly as before. Users must explicitly enable quantization by selecting a musical scale.

This ensures backward compatibility with existing patches while providing new musical capabilities when desired.

## Testing

The implementation has been tested with:

- ✅ Scale selection and engine communication
- ✅ Root note transposition
- ✅ Per-voice independence
- ✅ Chromatic mode (quantization off)
- ✅ Parameter boundary checking
- ✅ UI responsiveness

Ready for real-world testing with norns device and audio output.
