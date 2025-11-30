-- quantization_test.lua
-- Test script for pitch quantization system
-- This script tests the quantization functionality independently

-- Mock engine table for testing
local mock_engine = {}
local engine_calls = {}

function mock_engine.voice_quantize(voice, scale)
  table.insert(engine_calls, {type = "voice_quantize", voice = voice, scale = scale})
  print("Engine call: voice_quantize(" .. voice .. ", " .. scale .. ")")
end

function mock_engine.voice_root(voice, root)
  table.insert(engine_calls, {type = "voice_root", voice = voice, root = root})
  print("Engine call: voice_root(" .. voice .. ", " .. root .. ")")
end

-- Override global engine for testing
engine = mock_engine

-- Import the scale and note definitions
local SCALE_NAMES = {
  "Chromatic", "Ionian", "Dorian", "Phrygian",
  "Lydian", "Mixolydian", "Aeolian", "Locrian",
  "Pent Major", "Pent Minor", "Blues", "Harm Minor", "Whole Tone"
}

local NOTE_NAMES = {
  "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

-- Test state
local voice_quantize_scale = {0, 0, 0, 0}  -- 0=chromatic (off), 1-12=scales
local voice_root_note = {0, 0, 0, 0}       -- 0-11 for C-B
local selected_voice = 0

-- Test utility functions
function test_scale_selection()
  print("\n=== Testing Scale Selection ===")
  
  -- Test setting voice 0 to Ionian scale (index 1)
  voice_quantize_scale[selected_voice + 1] = 1
  engine.voice_quantize(selected_voice, voice_quantize_scale[selected_voice + 1])
  
  print("Voice " .. (selected_voice + 1) .. " scale: " .. SCALE_NAMES[voice_quantize_scale[selected_voice + 1] + 1])
  
  -- Test setting to Pentatonic Minor (index 9)  
  voice_quantize_scale[selected_voice + 1] = 9
  engine.voice_quantize(selected_voice, voice_quantize_scale[selected_voice + 1])
  
  print("Voice " .. (selected_voice + 1) .. " scale: " .. SCALE_NAMES[voice_quantize_scale[selected_voice + 1] + 1])
  
  -- Test boundary conditions
  voice_quantize_scale[selected_voice + 1] = math.max(0, math.min(#SCALE_NAMES - 1, 15))  -- Should clamp to 12
  print("Boundary test - scale index: " .. voice_quantize_scale[selected_voice + 1])
end

function test_root_note_selection()
  print("\n=== Testing Root Note Selection ===")
  
  -- Test setting root to D (index 2)
  voice_root_note[selected_voice + 1] = 2
  engine.voice_root(selected_voice, voice_root_note[selected_voice + 1])
  
  print("Voice " .. (selected_voice + 1) .. " root: " .. NOTE_NAMES[voice_root_note[selected_voice + 1] + 1])
  
  -- Test setting to F# (index 6)
  voice_root_note[selected_voice + 1] = 6
  engine.voice_root(selected_voice, voice_root_note[selected_voice + 1])
  
  print("Voice " .. (selected_voice + 1) .. " root: " .. NOTE_NAMES[voice_root_note[selected_voice + 1] + 1])
  
  -- Test boundary conditions  
  voice_root_note[selected_voice + 1] = math.max(0, math.min(11, 15))  -- Should clamp to 11
  print("Boundary test - root index: " .. voice_root_note[selected_voice + 1])
end

function test_all_voices()
  print("\n=== Testing All Voices ===")
  
  for v = 0, 3 do
    voice_quantize_scale[v + 1] = v + 1  -- Different scale for each voice
    voice_root_note[v + 1] = v * 3  -- Different root for each voice
    
    engine.voice_quantize(v, voice_quantize_scale[v + 1])
    engine.voice_root(v, voice_root_note[v + 1])
    
    local scale_name = SCALE_NAMES[voice_quantize_scale[v + 1] + 1] or "Unknown"
    local root_name = NOTE_NAMES[voice_root_note[v + 1] + 1] or "C"
    
    print("Voice " .. (v + 1) .. ": " .. scale_name .. " in " .. root_name)
  end
end

function test_chromatic_mode()
  print("\n=== Testing Chromatic Mode (Quantization Off) ===")
  
  -- Set to chromatic (should disable quantization)
  voice_quantize_scale[selected_voice + 1] = 0
  engine.voice_quantize(selected_voice, voice_quantize_scale[selected_voice + 1])
  
  print("Voice " .. (selected_voice + 1) .. " scale: " .. SCALE_NAMES[voice_quantize_scale[selected_voice + 1] + 1])
  print("Quantization should be OFF for this voice")
end

function run_all_tests()
  print("Starting Pitch Quantization Tests")
  print("==================================")
  
  test_scale_selection()
  test_root_note_selection()
  test_all_voices()
  test_chromatic_mode()
  
  print("\n=== Engine Call Summary ===")
  for i, call in ipairs(engine_calls) do
    print(i .. ": " .. call.type .. " - voice:" .. call.voice .. " value:" .. (call.scale or call.root))
  end
  
  print("\nTests completed successfully!")
  print("Expected: Engine calls should show proper voice/scale/root values")
  print("Verify: All scales and notes are within valid ranges")
end

-- Run the tests
run_all_tests()