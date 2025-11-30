-- two_tangles.lua
-- Dual shift register synthesis
-- v0.1
--
-- Grid required (128)
--
-- K1: Start/Stop (hold: page)
-- K2: Cancel/Reset
-- K3: Delete/Toggle
--
-- E1: Tempo
-- E2: Logic operation
-- E3: Patch weight

engine.name = "TwoTangles"

local g = grid.connect()

-- Logic operations
local LOGIC_OPS = {
  {id=0, name="DIRECT", short="DIR"},
  {id=1, name="AND", short="AND"},
  {id=2, name="OR", short="OR"},
  {id=3, name="XOR", short="XOR"},
  {id=4, name="ADD", short="ADD"},
  {id=5, name="MULTIPLY", short="MUL"},
  {id=6, name="SUBTRACT", short="SUB"},
  {id=7, name="MIN", short="MIN"},
  {id=8, name="MAX", short="MAX"},
  {id=9, name="AVERAGE", short="AVG"},
  {id=10, name="INVERT", short="INV"},
  {id=11, name="GREATER", short="GT"},
  {id=12, name="MODULO", short="MOD"}
}

-- State
local shift_reg_a = {0,0,0,0,0,0,0,0}
local shift_reg_b = {0,0,0,0,0,0,0,0}
local active_stages_a = {0,0,0,0,0,0,0,0}
local active_stages_b = {0,0,0,0,0,0,0,0}

-- Patch state
local patches = {}
local patch_mode = false
local patch_source = nil
local selected_logic = 0
local logic_mode = false
local patch_weight = 1.0

-- Patch editing
local selected_patch = nil
local edit_mode = false

-- Long-press detection
local press_start_time = {}
local LONG_PRESS_TIME = 0.5
local long_press_active = false

-- LED pulse animation
local pulse_timers = {}
local pulse_brightness = {}

-- Grid layout constants - NEW DESIGN
-- Shift registers are now horizontal in center (rows 2-3, 5-6, cols 5-12)
local REG_A_OUT_ROW = 2
local REG_A_IN_ROW = 3
local REG_B_OUT_ROW = 5
local REG_B_IN_ROW = 6
local REG_COL_START = 5
local REG_COL_END = 12

-- Operators/Weights area: 3x3 grid top-right (rows 1-3, cols 14-16)
-- Switches between operators (normal) and weights (ALT held)
-- Operators: cols 14-16, rows 1-5 (15 slots for 13 operators)
local OP_COL_START = 14
local OP_COL_END = 16
local OP_ROW_START = 1
local OP_ROW_END = 5
-- Weights: cols 1-2, rows 1-8 (16 weight levels)
local WEIGHT_COL_START = 1
local WEIGHT_COL_END = 2
local WEIGHT_ROW_START = 1
local WEIGHT_ROW_END = 8

local CLOCK_CTRL_ROW = 8
local TEMPO_TAP_COL = 5

-- Audio Input Sources only (row 1, cols 1-2)
-- Registers self-seed, only audio input can be patched in
local SOURCES = {
  {name = "input_env", col = 8, row = 1},
  {name = "input_pitch", col = 9, row = 1}
}

-- Source values (for LED brightness display)
local source_values = {
  input_env = 0.0,
  input_pitch = 0.5,
  param2 = 0.5,
  voice1 = 0.5,
  voice2 = 0.5
}

-- Clock state
local clock_running = false
local tempo = 120
local clock_div_a = 1
local clock_div_b = 1
local clock_a_enabled = true
local clock_b_enabled = true
local beat_count = 0
local swing = 0.5
local swing_subdiv = 2
local reset_on_downbeat = false
local bar_length = 16
local clock_source = 0
local last_step_time_a = 0
local last_step_time_b = 0
local step_flash_duration = 0.1

-- Performance macro state
local mute_a = false
local mute_b = false
local global_mute = false
local freeze_a = false
local freeze_b = false
local pattern_length_a = 8
local pattern_length_b = 8

-- Gate routing
local gate_route_a1 = true
local gate_route_a2 = false
local gate_route_b1 = true
local gate_route_b2 = false
local clock_mult_a = 1.0
local clock_mult_b = 1.0
local feedback_amount = 1.0
local chaos_amount = 0.0
local mutation_rate = 0.0

-- Audio input state
local input_mod_amount = 0.0
local input_mod_target = 2
local input_mod_reg = 2
local input_gain = 1.0
local input_smoothing = 0.1
local input_envelope = 0.0
local input_pitch = 440

-- Patch editing state
local patch_edit_mode = false
local patch_edit_data = nil  -- Currently editing patch
local patch_selection_mode = false
local patch_selection_list = {}  -- Patches to choose from
local patch_selection_index = 1
local patch_selection_pressed = nil  -- {reg, stage} that was pressed

-- Modulation matrix state
local mod_matrix = {}
local mod_source_selected = nil
local mod_dest_selected = nil
local mod_amount = 0.5

-- Voice modulation page state
local voice_count = 2
local voice_mod_matrix = {{}, {}, {}, {}}  -- 4 voices worth of mod routes
local selected_voice = 0  -- 0-3 for voices 1-4
local selected_register = 'a'  -- 'a' or 'b'

-- Pitch quantization state
local voice_quantize_scale = {0, 0, 0, 0}  -- 0=chromatic (off), 1-12=scales
local voice_root_note = {0, 0, 0, 0}       -- 0-11 for C-B

-- Scale definitions (matching SuperCollider order)
local SCALE_NAMES = {
  "Chromatic", "Ionian", "Dorian", "Phrygian",
  "Lydian", "Mixolydian", "Aeolian", "Locrian",
  "Pent Major", "Pent Minor", "Blues", "Harm Minor", "Whole Tone"
}

local NOTE_NAMES = {
  "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

-- Voice modulation parameter names (matching SuperCollider)
local VOICE_PARAMS = {
  'pitch', 'gate', 'amp', 'waveShape',
  'filterFreq', 'filterRes', 'fmAmount', 'fmRatio',
  'pulseWidth', 'subOscMix', 'noiseAmount', 'pan'
}

local VOICE_PARAM_NAMES = {
  pitch = 'Pitch',
  gate = 'Gate',
  amp = 'Amp',
  waveShape = 'Wave',
  filterFreq = 'Filt',
  filterRes = 'Res',
  fmAmount = 'FM',
  fmRatio = 'FMR',
  pulseWidth = 'PW',
  subOscMix = 'Sub',
  noiseAmount = 'Noi',
  pan = 'Pan'
}

-- LFO state
local lfo_rates = {1.0, 2.0, 0.5, 0.25}
local lfo_shapes = {0, 0, 0, 0}
local LFO_SHAPES = {"Sine", "Tri", "Saw", "Square", "Random"}

-- Mod source/dest definitions
local MOD_SOURCES = {
  -- Registers
  {type='register', index=0, name='A0'},
  {type='register', index=1, name='A1'},
  {type='register', index=2, name='A2'},
  {type='register', index=3, name='A3'},
  {type='register', index=4, name='A4'},
  {type='register', index=5, name='A5'},
  {type='register', index=6, name='A6'},
  {type='register', index=7, name='A7'},
  {type='register', index=8, name='B0'},
  {type='register', index=9, name='B1'},
  {type='register', index=10, name='B2'},
  {type='register', index=11, name='B3'},
  {type='register', index=12, name='B4'},
  {type='register', index=13, name='B5'},
  {type='register', index=14, name='B6'},
  {type='register', index=15, name='B7'},
  {type='audioInput', index=0, name='InEnv'},
  {type='audioInput', index=1, name='InPitch'},
  {type='lfo', index=0, name='LFO1'},
  {type='lfo', index=1, name='LFO2'},
  {type='lfo', index=2, name='LFO3'},
  {type='lfo', index=3, name='LFO4'},
  {type='clock', index=0, name='ClkPhase'},
  {type='clock', index=1, name='BeatCnt'}
}

local MOD_DESTINATIONS = {
  'pitch', 'filterFreq', 'filterRes', 'waveShape',
  'fmAmount', 'fmRatio', 'subOscMix', 'amp',
  'pan', 'pulseWidth', 'noiseAmount'
}

local MOD_DEST_NAMES = {
  pitch='Pitch', filterFreq='Filter', filterRes='Resonance',
  waveShape='Wave', fmAmount='FM Amt', fmRatio='FM Ratio',
  subOscMix='Sub', amp='Amp', pan='Pan',
  pulseWidth='PW', noiseAmount='Noise'
}

-- UI pages
local current_page = 1
local PAGES = {"Tangles", "Clock", "Performance", "Audio In", "Voice Mod", "Voice Sound"}

-- Voice Sound page state
local sound_page_voice = 0  -- Currently selected voice for sound editing (0-3)
local sound_page_param = 1  -- Currently selected parameter (1-based index)

-- Voice sound parameters (editable on page 6)
local SOUND_PARAMS = {
  {name = "waveShape", label = "Wave", min = 0, max = 3, step = 1, format = function(v)
    local waves = {"Sine", "Tri", "Saw", "Pulse"}
    return waves[math.floor(v) + 1] or "Sine"
  end},
  {name = "filterFreq", label = "Filter", min = 100, max = 18000, step = 100, format = function(v)
    return string.format("%.0f Hz", v)
  end},
  {name = "filterRes", label = "Res", min = 0.1, max = 1.0, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end},
  {name = "fmAmount", label = "FM Amt", min = 0, max = 500, step = 10, format = function(v)
    return string.format("%.0f", v)
  end},
  {name = "fmRatio", label = "FM Ratio", min = 0.5, max = 8, step = 0.1, format = function(v)
    return string.format("%.1f", v)
  end},
  {name = "pulseWidth", label = "PW", min = 0.1, max = 0.9, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end},
  {name = "subOscMix", label = "Sub", min = 0, max = 1, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end},
  {name = "noiseAmount", label = "Noise", min = 0, max = 0.3, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end},
  {name = "amp", label = "Amp", min = 0, max = 1, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end},
  {name = "pan", label = "Pan", min = -1, max = 1, step = 0.01, format = function(v)
    return string.format("%.2f", v)
  end}
}

-- Cache of current voice parameter values (initialized with defaults)
local voice_param_cache = {
  {waveShape=0, filterFreq=2000, filterRes=0.3, fmAmount=0, fmRatio=1, pulseWidth=0.5, subOscMix=0, noiseAmount=0, amp=0.5, pan=0},
  {waveShape=0, filterFreq=2000, filterRes=0.3, fmAmount=0, fmRatio=1, pulseWidth=0.5, subOscMix=0, noiseAmount=0, amp=0.5, pan=0},
  {waveShape=0, filterFreq=2000, filterRes=0.3, fmAmount=0, fmRatio=1, pulseWidth=0.5, subOscMix=0, noiseAmount=0, amp=0.5, pan=0},
  {waveShape=0, filterFreq=2000, filterRes=0.3, fmAmount=0, fmRatio=1, pulseWidth=0.5, subOscMix=0, noiseAmount=0, amp=0.5, pan=0}
}

-- Patch visualization subpage (page 1a, accessed via ALT from Tangles page)
local patch_viz_mode = false
local patch_viz_index = 1  -- Currently selected patch in viz mode

-- Clocks
local animation_clock
local screen_refresh_clock
local random_source_clock
local clock_button_pulse_clock

-- Key state
local k1_held = false

function init()
  params:add_separator("TWO TANGLES")
  
  -- Clock parameters
  params:add_separator("TT_CLOCK")
  
  params:add{
    type = "number",
    id = "tempo",
    name = "Tempo",
    min = 20,
    max = 300,
    default = 120,
    action = function(v)
      tempo = v
      engine.tempo(v)
    end
  }
  
  params:add{
    type = "option",
    id = "tt_clock_source",
    name = "Clock Source",
    options = {"Internal", "MIDI"},
    default = 1,
    action = function(v)
      clock_source = v - 1
      engine.clock_source(clock_source)
    end
  }
  
  params:add{
    type = "option",
    id = "clock_div_a",
    name = "Clock Div A",
    options = {"1", "2", "3", "4", "6", "8", "12", "16", "24", "32"},
    default = 1,
    action = function(v)
      local divs = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32}
      clock_div_a = divs[v]
      engine.clock_div_a(clock_div_a)
    end
  }
  
  params:add{
    type = "option",
    id = "clock_div_b",
    name = "Clock Div B",
    options = {"1", "2", "3", "4", "6", "8", "12", "16", "24", "32"},
    default = 1,
    action = function(v)
      local divs = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32}
      clock_div_b = divs[v]
      engine.clock_div_b(clock_div_b)
    end
  }
  
  params:add{
    type = "option",
    id = "clock_a_enable",
    name = "Clock A Enable",
    options = {"Off", "On"},
    default = 2,
    action = function(v)
      clock_a_enabled = (v == 2)
      engine.clock_a_enable(clock_a_enabled and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "clock_b_enable",
    name = "Clock B Enable",
    options = {"Off", "On"},
    default = 2,
    action = function(v)
      clock_b_enabled = (v == 2)
      engine.clock_b_enable(clock_b_enabled and 1 or 0)
    end
  }
  
  params:add{
    type = "control",
    id = "swing",
    name = "Swing",
    controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5, ''),
    formatter = function(param)
      return string.format("%.0f%%", (param:get() - 0.5) * 200)
    end,
    action = function(v)
      swing = v
      engine.swing(v)
    end
  }
  
  params:add{
    type = "option",
    id = "swing_subdiv",
    name = "Swing Subdiv",
    options = {"8th", "16th"},
    default = 1,
    action = function(v)
      swing_subdiv = v + 1
      engine.swing_subdiv(swing_subdiv)
    end
  }
  
  params:add{
    type = "option",
    id = "reset_downbeat",
    name = "Reset on Downbeat",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      reset_on_downbeat = (v == 2)
      engine.reset_downbeat(reset_on_downbeat and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "bar_length",
    name = "Bar Length",
    options = {"4", "8", "16", "32", "64"},
    default = 3,
    action = function(v)
      local lengths = {4, 8, 16, 32, 64}
      bar_length = lengths[v]
      engine.bar_length(bar_length)
    end
  }
  
  -- Voice parameters
  params:add_separator("VOICE")

  params:add{
    type = "option",
    id = "voice_count",
    name = "Voice Count",
    options = {"2", "4"},
    default = 1,
    action = function(v)
      voice_count = v == 1 and 2 or 4
      engine.voice_count(voice_count)
      print("Voice count: " .. voice_count)
    end
  }

  params:add{
    type = "option",
    id = "slew_mode",
    name = "Slew Mode",
    options = {"Sample-Hold", "Slew"},
    default = 1,
    action = function(v)
      engine.slew_mode(v-1)
    end
  }
  
  params:add{
    type = "control",
    id = "slew_time",
    name = "Slew Time",
    controlspec = controlspec.new(0.001, 1.0, 'exp', 0.001, 0.05, 's'),
    action = function(v)
      engine.slew_time(v)
    end
  }
  
  params:add{
    type = "option",
    id = "unpatched_mode",
    name = "Unpatched Stages",
    options = {"Hold Zero", "Random"},
    default = 1,
    action = function(v)
      engine.unpatched_mode(v-1)
    end
  }
  
  params:add{
    type = "option",
    id = "multipatch_mode",
    name = "Multi-Patch Mode",
    options = {"Average", "Sum", "Max", "Min"},
    default = 1,
    action = function(v)
      engine.multipatch_mode(v-1)
    end
  }
  
  params:add{
    type = "control",
    id = "global_feedback",
    name = "Global Feedback",
    controlspec = controlspec.new(0, 1, 'lin', 0.01, 1.0, ''),
    action = function(v)
      engine.global_feedback(v)
    end
  }

  -- Pitch quantization parameters
  params:add_separator("PITCH QUANTIZATION")
  
  for v = 0, 3 do  -- 4 voices (0-3)
    params:add{
      type = "option",
      id = "voice_" .. v .. "_scale",
      name = "Voice " .. (v + 1) .. " Scale",
      options = SCALE_NAMES,
      default = 1,  -- Default to Chromatic (off)
      action = function(value)
        voice_quantize_scale[v + 1] = value - 1  -- 0-indexed
        engine.voice_quantize(v, value - 1)
      end
    }
    
    params:add{
      type = "option",
      id = "voice_" .. v .. "_root",
      name = "Voice " .. (v + 1) .. " Root",
      options = NOTE_NAMES,
      default = 1,  -- Default to C
      action = function(value)
        voice_root_note[v + 1] = value - 1  -- 0-indexed
        engine.voice_root(v, value - 1)
      end
    }
  end

  -- External sources
  params:add_separator("SOURCES")

  params:add{
    type = "control",
    id = "source_param1",
    name = "Param 1",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5, ''),
    action = function(v)
      source_values.param1 = v
      engine.set_source("param1", v)
      grid_redraw()
    end
  }

  params:add{
    type = "control",
    id = "source_param2",
    name = "Param 2",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5, ''),
    action = function(v)
      source_values.param2 = v
      engine.set_source("param2", v)
      grid_redraw()
    end
  }

  params:add{
    type = "control",
    id = "source_low",
    name = "Low Value",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.25, ''),
    action = function(v)
      source_values.low = v
      engine.set_source("low", v)
      grid_redraw()
    end
  }

  params:add{
    type = "control",
    id = "source_mid",
    name = "Mid Value",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5, ''),
    action = function(v)
      source_values.mid = v
      engine.set_source("mid", v)
      grid_redraw()
    end
  }

  params:add{
    type = "control",
    id = "source_high",
    name = "High Value",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.75, ''),
    action = function(v)
      source_values.high = v
      engine.set_source("high", v)
      grid_redraw()
    end
  }

  params:add{
    type = "control",
    id = "source_max",
    name = "Max Value",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0, ''),
    action = function(v)
      source_values.max = v
      engine.set_source("max", v)
      grid_redraw()
    end
  }

  -- Stage probabilities
  for reg=1,2 do
    local reg_name = reg==1 and "A" or "B"
    params:add_separator("Register " .. reg_name .. " Probabilities")
    
    for stage=0,7 do
      params:add{
        type="control",
        id="prob_"..reg_name.."_"..stage,
        name="Stage "..stage.." Prob",
        controlspec=controlspec.new(0, 1, 'lin', 0.01, 1.0, ''),
        action=function(v)
          engine.stage_prob(reg-1, stage, v)
        end
      }
    end
  end
  
  -- Stage mappings
  params:add_separator("Stage Mappings")
  local mapping_options = {"Mode 0", "Mode 1", "Mode 2"}
  
  for reg=1,2 do
    local reg_name = reg==1 and "A" or "B"
    for stage=0,7 do
      params:add{
        type="option",
        id="map_"..reg_name.."_"..stage,
        name=reg_name.." Stage "..stage.." Map",
        options=mapping_options,
        default=1,
        action=function(v)
          engine.stage_mapping(reg-1, stage, v-1)
        end
      }
    end
  end
  
  -- Performance parameters
  params:add_separator("PERFORMANCE")
  
  params:add{
    type = "option",
    id = "mute_a",
    name = "Mute Register A",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      mute_a = (v == 2)
      engine.mute_a(mute_a and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "mute_b",
    name = "Mute Register B",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      mute_b = (v == 2)
      engine.mute_b(mute_b and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "global_mute",
    name = "Global Mute",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      global_mute = (v == 2)
      engine.mute_global(global_mute and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "freeze_a",
    name = "Freeze Register A",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      freeze_a = (v == 2)
      engine.freeze_a(freeze_a and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "freeze_b",
    name = "Freeze Register B",
    options = {"Off", "On"},
    default = 1,
    action = function(v)
      freeze_b = (v == 2)
      engine.freeze_b(freeze_b and 1 or 0)
    end
  }
  
  params:add{
    type = "number",
    id = "pattern_length_a",
    name = "Pattern Length A",
    min = 1,
    max = 8,
    default = 8,
    action = function(v)
      pattern_length_a = v
      engine.pattern_length_a(v)
    end
  }
  
  params:add{
    type = "number",
    id = "pattern_length_b",
    name = "Pattern Length B",
    min = 1,
    max = 8,
    default = 8,
    action = function(v)
      pattern_length_b = v
      engine.pattern_length_b(v)
    end
  }
  
  params:add{
    type = "option",
    id = "seed_mode_a",
    name = "Seed Mode A",
    options = {"Random", "Low", "Mid", "High", "Chaos"},
    default = 4,  -- High (drone)
    action = function(v)
      engine.seed_mode_a(v - 1)
    end
  }
  
  params:add{
    type = "option",
    id = "seed_mode_b",
    name = "Seed Mode B",
    options = {"Random", "Low", "Mid", "High", "Chaos"},
    default = 4,  -- High (drone)
    action = function(v)
      engine.seed_mode_b(v - 1)
    end
  }
  
  -- Gate routing
  params:add_separator("GATE ROUTING")
  
  params:add{
    type = "option",
    id = "gate_route_a1",
    name = "Register A → Voice 1",
    options = {"Off", "On"},
    default = 2,  -- On
    action = function(v)
      gate_route_a1 = (v == 2)
      engine.gate_route_a1(gate_route_a1 and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "gate_route_a2",
    name = "Register A → Voice 2",
    options = {"Off", "On"},
    default = 1,  -- Off
    action = function(v)
      gate_route_a2 = (v == 2)
      engine.gate_route_a2(gate_route_a2 and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "gate_route_b1",
    name = "Register B → Voice 1",
    options = {"Off", "On"},
    default = 2,  -- On
    action = function(v)
      gate_route_b1 = (v == 2)
      engine.gate_route_b1(gate_route_b1 and 1 or 0)
    end
  }
  
  params:add{
    type = "option",
    id = "gate_route_b2",
    name = "Register B → Voice 2",
    options = {"Off", "On"},
    default = 1,  -- Off
    action = function(v)
      gate_route_b2 = (v == 2)
      engine.gate_route_b2(gate_route_b2 and 1 or 0)
    end
  }
  
  params:add{
    type = "control",
    id = "clock_mult_a",
    name = "Clock Mult A",
    controlspec = controlspec.new(0.25, 4.0, 'exp', 0.25, 1.0, 'x'),
    action = function(v)
      clock_mult_a = v
      engine.clock_mult_a(v)
    end
  }
  
  params:add{
    type = "control",
    id = "clock_mult_b",
    name = "Clock Mult B",
    controlspec = controlspec.new(0.25, 4.0, 'exp', 0.25, 1.0, 'x'),
    action = function(v)
      clock_mult_b = v
      engine.clock_mult_b(v)
    end
  }
  
  params:add{
    type = "control",
    id = "feedback_amount",
    name = "Feedback Amount",
    controlspec = controlspec.new(0, 2.0, 'lin', 0.01, 1.0, ''),
    action = function(v)
      feedback_amount = v
      engine.feedback_amount(v)
    end
  }
  
  params:add{
    type = "control",
    id = "chaos",
    name = "Chaos",
    controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0, ''),
    action = function(v)
      chaos_amount = v
      engine.chaos(v)
    end
  }
  
  params:add{
    type = "control",
    id = "mutation",
    name = "Mutation",
    controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0, ''),
    action = function(v)
      mutation_rate = v
      engine.mutation(v)
    end
  }
  
  -- Audio input parameters
  params:add_separator("AUDIO INPUT")
  
  params:add{
    type = "control",
    id = "input_mod_amount",
    name = "Input Mod Amount",
    controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0, ''),
    action = function(v)
      input_mod_amount = v
      engine.input_mod_amount(v)
    end
  }
  
  params:add{
    type = "option",
    id = "input_mod_target",
    name = "Input Mod Target",
    options = {"Pitch", "Gates", "All", "Complex"},
    default = 3,
    action = function(v)
      input_mod_target = v - 1
      engine.input_mod_target(input_mod_target)
    end
  }
  
  params:add{
    type = "option",
    id = "input_mod_reg",
    name = "Input Modulates",
    options = {"Register A", "Register B", "Both"},
    default = 3,
    action = function(v)
      input_mod_reg = v - 1
      engine.input_mod_reg(input_mod_reg)
    end
  }
  
  params:add{
    type = "control",
    id = "input_gain",
    name = "Input Gain",
    controlspec = controlspec.new(0, 4.0, 'lin', 0.1, 1.0, 'x'),
    action = function(v)
      input_gain = v
      engine.input_gain(v)
    end
  }
  
  params:add{
    type = "control",
    id = "input_smoothing",
    name = "Input Smoothing",
    controlspec = controlspec.new(0.001, 1.0, 'exp', 0.001, 0.1, 's'),
    action = function(v)
      input_smoothing = v
      engine.input_smoothing(v)
    end
  }
  
  -- Modulation matrix parameters
  params:add_separator("MODULATION MATRIX")
  
  for i = 1, 4 do
    params:add{
      type = "control",
      id = "lfo_rate_" .. i,
      name = "LFO " .. i .. " Rate",
      controlspec = controlspec.new(0.01, 20, 'exp', 0.01, lfo_rates[i], 'Hz'),
      action = function(v)
        lfo_rates[i] = v
        engine.lfo_rate(i - 1, v)
      end
    }
    
    params:add{
      type = "option",
      id = "lfo_shape_" .. i,
      name = "LFO " .. i .. " Shape",
      options = LFO_SHAPES,
      default = 1,
      action = function(v)
        lfo_shapes[i] = v - 1
        engine.lfo_shape(i - 1, v - 1)
      end
    }
  end
  
  -- PSET callbacks
  params.action_write = function(filename, name, number)
    print("Saved PSET: " .. name)
    save_patches(number)
    save_mod_matrix(number)
  end
  
  params.action_read = function(filename, silent, number)
    print("Loaded PSET: " .. number)
    load_patches(number)
    load_mod_matrix(number)
    clock.run(function()
      clock.sleep(0.1)
      sync_all_params_to_engine()
    end)
  end
  
  params.action_delete = function(filename, name, number)
    print("Deleted PSET: " .. name)
    delete_patches(number)
    local mod_file = _path.data .. "two_tangles/mods_" .. number .. ".json"
    if util.file_exists(mod_file) then
      os.remove(mod_file)
    end
  end
  
  -- Initialize pulse animation
  for i=1,16 do
    pulse_timers[i] = {}
    pulse_brightness[i] = {}
    for j=1,8 do
      pulse_timers[i][j] = 0
      pulse_brightness[i][j] = 0
    end
  end
  
  -- Start clocks
  animation_clock = clock.run(animate_pulses)
  screen_refresh_clock = clock.run(screen_refresh)
  random_source_clock = clock.run(function()
    while true do
      -- Update random source value
      source_values.random = math.random()

      -- Trigger pulse animation
      for _, src in ipairs(SOURCES) do
        if src.name == "random" then
          trigger_pulse(src.col, src.row)
          break
        end
      end

      if g and g.device then
        grid_redraw()
      end

      -- Wait based on tempo (1/8 note rate)
      local beat_time = 60 / tempo
      clock.sleep(beat_time / 2)
    end
  end)

  -- Clock button pulse (always running for visual workflow indication)
  clock_button_pulse_clock = clock.run(function()
    while true do
      -- Pulse the clock start/stop button at tempo rate
      trigger_pulse(13, CLOCK_CTRL_ROW)

      local beat_time = 60 / tempo
      clock.sleep(beat_time)  -- Pulse every beat
    end
  end)

  -- Initialize source patch cache
  rebuild_source_patch_cache()
  
  -- Request initial state
  engine.get_patches()
  engine.get_mods()
  
  redraw()
  grid_redraw()
end

function sync_all_params_to_engine()
  print("Syncing parameters to engine...")
  
  engine.tempo(params:get("tempo"))
  engine.clock_div_a(clock_div_a)
  engine.clock_div_b(clock_div_b)
  engine.swing(params:get("swing"))
  engine.swing_subdiv(params:get("swing_subdiv") == 1 and 2 or 3)
  engine.reset_downbeat(params:get("reset_downbeat") == 2 and 1 or 0)
  engine.bar_length(bar_length)
  engine.clock_a_enable(params:get("clock_a_enable") == 2 and 1 or 0)
  engine.clock_b_enable(params:get("clock_b_enable") == 2 and 1 or 0)
  engine.clock_source(params:get("clock_source") - 1)
  
  engine.slew_mode(params:get("slew_mode") - 1)
  engine.slew_time(params:get("slew_time"))
  engine.unpatched_mode(params:get("unpatched_mode") - 1)
  engine.multipatch_mode(params:get("multipatch_mode") - 1)
  engine.global_feedback(params:get("global_feedback"))
  
  engine.mute_a(params:get("mute_a") == 2 and 1 or 0)
  engine.mute_b(params:get("mute_b") == 2 and 1 or 0)
  engine.freeze_a(params:get("freeze_a") == 2 and 1 or 0)
  engine.freeze_b(params:get("freeze_b") == 2 and 1 or 0)
  engine.pattern_length_a(params:get("pattern_length_a"))
  engine.pattern_length_b(params:get("pattern_length_b"))
  engine.clock_mult_a(params:get("clock_mult_a"))
  engine.clock_mult_b(params:get("clock_mult_b"))
  engine.feedback_amount(params:get("feedback_amount"))
  engine.chaos(params:get("chaos"))
  engine.mutation(params:get("mutation"))
  
  for reg = 0, 1 do
    local reg_name = reg == 0 and "A" or "B"
    for stage = 0, 7 do
      local prob = params:get("prob_" .. reg_name .. "_" .. stage)
      engine.stage_prob(reg, stage, prob)
    end
  end
  
  for reg = 0, 1 do
    local reg_name = reg == 0 and "A" or "B"
    for stage = 0, 7 do
      local mapping = params:get("map_" .. reg_name .. "_" .. stage) - 1
      engine.stage_mapping(reg, stage, mapping)
    end
  end
  
  print("Sync complete")
  redraw()
end

function save_patches(preset_number)
  local data_dir = _path.data .. "two_tangles/"
  
  if util.file_exists(data_dir) == false then
    util.make_dir(data_dir)
  end
  
  local filename = data_dir .. "patches_" .. preset_number .. ".json"
  
  local patch_data = {
    patches = patches,
    version = 1
  }
  
  local json = require("json")
  local file = io.open(filename, "w")
  if file then
    file:write(json.encode(patch_data))
    file:close()
    print("Saved " .. #patches .. " patches")
  end
end

function load_patches(preset_number)
  local data_dir = _path.data .. "two_tangles/"
  local filename = data_dir .. "patches_" .. preset_number .. ".json"
  
  if util.file_exists(filename) then
    local json = require("json")
    local file = io.open(filename, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      local patch_data = json.decode(content)
      if patch_data and patch_data.patches then
        patches = {}
        engine.clear_patches()
        
        for _, patch in ipairs(patch_data.patches) do
          engine.add_patch(
            patch.src_reg,
            patch.src_stage,
            patch.dst_reg,
            patch.dst_stage,
            patch.logic,
            patch.weight
          )
          table.insert(patches, patch)
        end
        
        print("Loaded " .. #patches .. " patches")
        grid_redraw()
      end
    end
  end
end

function delete_patches(preset_number)
  local data_dir = _path.data .. "two_tangles/"
  local filename = data_dir .. "patches_" .. preset_number .. ".json"
  
  if util.file_exists(filename) then
    os.remove(filename)
  end
end

function save_mod_matrix(preset_number)
  local data_dir = _path.data .. "two_tangles/"
  
  if util.file_exists(data_dir) == false then
    util.make_dir(data_dir)
  end
  
  local filename = data_dir .. "mods_" .. preset_number .. ".json"
  
  local mod_data = {
    modulations = mod_matrix,
    lfo_rates = lfo_rates,
    lfo_shapes = lfo_shapes,
    version = 1
  }
  
  local json = require("json")
  local file = io.open(filename, "w")
  if file then
    file:write(json.encode(mod_data))
    file:close()
    print("Saved " .. #mod_matrix .. " modulations")
  end
end

function load_mod_matrix(preset_number)
  local data_dir = _path.data .. "two_tangles/"
  local filename = data_dir .. "mods_" .. preset_number .. ".json"
  
  if util.file_exists(filename) then
    local json = require("json")
    local file = io.open(filename, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      local mod_data = json.decode(content)
      if mod_data and mod_data.modulations then
        mod_matrix = {}
        engine.clear_mods()
        
        for _, mod in ipairs(mod_data.modulations) do
          engine.add_mod(
            mod.src_type,
            mod.src_index,
            mod.dest_voice,
            mod.dest_param,
            mod.amount
          )
          table.insert(mod_matrix, mod)
        end
        
        if mod_data.lfo_rates then
          for i, rate in ipairs(mod_data.lfo_rates) do
            lfo_rates[i] = rate
            params:set("lfo_rate_" .. i, rate)
          end
        end
        
        if mod_data.lfo_shapes then
          for i, shape in ipairs(mod_data.lfo_shapes) do
            lfo_shapes[i] = shape
            params:set("lfo_shape_" .. i, shape + 1)
          end
        end
        
        print("Loaded " .. #mod_matrix .. " modulations")
        grid_redraw()
      end
    end
  end
end

function osc.event(path, args, from)
  if path == "/tt_state" then
    local reg = args[1]

    if reg == 'a' then
      for i=1,8 do
        shift_reg_a[i] = args[i+1]
        active_stages_a[i] = args[i+9]
        if active_stages_a[i] == 1 then
          trigger_pulse(stage_to_col(i-1), REG_A_OUT_ROW)
        end
      end
      last_step_time_a = util.time()

      -- Trigger pulse for all sources on clock step
      for _, src in ipairs(SOURCES) do
        trigger_pulse(src.col, src.row)
      end

    elseif reg == 'b' then
      for i=1,8 do
        shift_reg_b[i] = args[i+1]
        active_stages_b[i] = args[i+9]

        if active_stages_b[i] == 1 then
          trigger_pulse(stage_to_col(i-1), REG_B_OUT_ROW)
        end
      end
      last_step_time_b = util.time()
    end

    grid_redraw()
    
  elseif path == "/patch_data" then
    local patch = {
      src_reg = args[1],
      src_stage = args[2],
      dst_reg = args[3],
      dst_stage = args[4],
      logic = args[5],
      weight = args[6]
    }
    table.insert(patches, patch)
    grid_redraw()
    
  elseif path == "/tt_pulse" then
    local reg = args[1]
    local stage = args[2]
    local col = stage_to_col(stage)
    local row = reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
    trigger_pulse(col, row)
    
  elseif path == "/tt_input_values" then
    input_envelope = args[1]
    input_pitch = args[2]
    -- Update source values for display
    source_values.input_env = input_envelope
    source_values.input_pitch = input_pitch

  elseif path == "/voice_param_value" then
    local voice_num = args[1]
    local param_name = args[2]
    local value = args[3]

    -- Update the parameter cache
    if voice_num < voice_count then
      voice_param_cache[voice_num + 1][param_name] = value
      redraw()
    end

  elseif path == "/mod_data" then
    local mod = {
      src_type = args[1],
      src_index = args[2],
      dest_voice = args[3],
      dest_param = args[4],
      amount = args[5]
    }
    table.insert(mod_matrix, mod)
  end
end

function trigger_pulse(col, row)
  if col and row and pulse_timers[col] and pulse_timers[col][row] then
    pulse_timers[col][row] = 1.0
    pulse_brightness[col][row] = 1.0  -- Now a 0-1 multiplier, not direct brightness
  end
end

function animate_pulses()
  while true do
    clock.sleep(1/30)

    for col=1,16 do
      for row=1,8 do
        if pulse_timers[col][row] > 0 then
          pulse_timers[col][row] = pulse_timers[col][row] - 0.1

          if pulse_timers[col][row] <= 0 then
            pulse_timers[col][row] = 0
            pulse_brightness[col][row] = 0
          else
            pulse_brightness[col][row] = pulse_timers[col][row]  -- 0.0-1.0 value
          end
        end
      end
    end
    
    if g and g.device then
      grid_redraw()
    end
  end
end

function screen_refresh()
  while true do
    clock.sleep(1/15)
    redraw()
  end
end

function g.key(x, y, z)
  local key_id = x .. "," .. y

  if z == 1 then
    -- Handle grid presses during patch selection mode
    if patch_selection_mode then
      -- Determine which node was pressed
      local pressed_node = nil
      
      -- Check register A outputs
      for col = REG_COL_START, REG_COL_END do
        if x == col and y == REG_A_OUT_ROW then
          pressed_node = {reg = 'a', stage = col - REG_COL_START, is_output = true}
          break
        end
      end
      
      -- Check register A inputs
      if not pressed_node then
        for col = REG_COL_START, REG_COL_END do
          if x == col and y == REG_A_IN_ROW then
            pressed_node = {reg = 'a', stage = col - REG_COL_START, is_output = false}
            break
          end
        end
      end
      
      -- Check register B outputs
      if not pressed_node then
        for col = REG_COL_START, REG_COL_END do
          if x == col and y == REG_B_OUT_ROW then
            pressed_node = {reg = 'b', stage = col - REG_COL_START, is_output = true}
            break
          end
        end
      end
      
      -- Check register B inputs
      if not pressed_node then
        for col = REG_COL_START, REG_COL_END do
          if x == col and y == REG_B_IN_ROW then
            pressed_node = {reg = 'b', stage = col - REG_COL_START, is_output = false}
            break
          end
        end
      end
      
      -- Check audio input sources
      if not pressed_node then
        for _, src in ipairs(SOURCES) do
          if x == src.col and y == src.row then
            pressed_node = {type = "source", stage = src.name == "input_env" and 1 or 2, is_output = true}
            break
          end
        end
      end
      
      -- If a valid node was pressed, find matching patch
      if pressed_node then
        for i, patch in ipairs(patch_selection_list) do
          local match = false
          
          if pressed_node.is_output then
            -- Check if this patch has this source
            if pressed_node.type == "source" then
              if patch.src_type == "source" and patch.src_stage == pressed_node.stage then
                match = true
              end
            else
              if patch.src_reg == pressed_node.reg and patch.src_stage == pressed_node.stage then
                match = true
              end
            end
          else
            -- Check if this patch has this destination
            if patch.dst_reg == pressed_node.reg and patch.dst_stage == pressed_node.stage then
              match = true
            end
          end
          
          if match then
            patch_selection_index = i
            exit_patch_selection_mode()
            enter_patch_edit_mode(patch)
            redraw()
            return
          end
        end
      end
      
      return
    end

    -- Page 5: Voice Modulation Matrix
    if current_page == 5 and y <= 8 then
      -- Register selection buttons (column 14, rows 1-2)
      if x == 14 then
        if y == 1 then
          selected_register = 'a'
          print("Selected register: A")
          grid_redraw()
          redraw()
          return
        elseif y == 2 then
          selected_register = 'b'
          print("Selected register: B")
          grid_redraw()
          redraw()
          return
        end
      end

      -- Voice selection buttons (column 15, rows 1-4)
      if x == 15 then
        if y <= voice_count then
          selected_voice = y - 1  -- 0-indexed
          print("Selected voice: " .. (selected_voice + 1))
          grid_redraw()
          redraw()
          return
        end
      end

      -- Columns 13, 16: Reserved for future features

      -- Modulation matrix (columns 1-12 for params, rows 1-8 for stages)
      if x >= 1 and x <= 12 and y >= 1 and y <= 8 then
        local param = VOICE_PARAMS[x]
        local stage = y - 1  -- 0-indexed
        toggle_voice_mod(selected_voice, selected_register, stage, param)
        grid_redraw()
        redraw()
        return
      end
    end

    -- Page 6: Voice Sound (Oscillator Control)
    if current_page == 6 then
      -- Voice selection buttons (column 15, rows 1-4)
      if x == 15 and y >= 1 and y <= voice_count then
        sound_page_voice = y - 1  -- 0-indexed
        print("Selected voice: " .. (sound_page_voice + 1))
        grid_redraw()
        redraw()
        return
      end
    end

    if y == CLOCK_CTRL_ROW then
      -- Gate routing toggles
      if x == 2 then
        gate_route_a2 = not gate_route_a2
        params:set("gate_route_a2", gate_route_a2 and 2 or 1)
        print("A→Voice 2: " .. (gate_route_a2 and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == 3 then
        gate_route_a1 = not gate_route_a1
        params:set("gate_route_a1", gate_route_a1 and 2 or 1)
        print("A→Voice 1: " .. (gate_route_a1 and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == 4 then
        clock_a_enabled = not clock_a_enabled
        params:set("clock_a_enable", clock_a_enabled and 2 or 1)
        print("Clock A: " .. (clock_a_enabled and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == TEMPO_TAP_COL then
        tap_tempo()
        return
      end
      
      if x == 6 then
        engine.randomize('a')
        print("Randomized register A")
        return
      end
      
      if x == 7 then
        engine.clear_register('a')
        print("Cleared register A")
        return
      end
      
      if x == 8 then
        engine.copy_register('a', 'b')
        print("Copied A to B")
        return
      end
      
      if x == 9 then
        engine.copy_register('b', 'a')
        print("Copied B to A")
        return
      end
      
      if x == 10 then
        engine.clear_register('b')
        print("Cleared register B")
        return
      end
      
      if x == 11 then
        engine.randomize('b')
        print("Randomized register B")
        return
      end
      
      if x == 12 then
        clock_b_enabled = not clock_b_enabled
        params:set("clock_b_enable", clock_b_enabled and 2 or 1)
        print("Clock B: " .. (clock_b_enabled and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == 13 then
        clock_running = not clock_running
        if clock_running then
          engine.start()
          print("Clock started")
        else
          engine.stop()
          print("Clock stopped")
        end
        grid_redraw()
        redraw()
        return
      end
      
      if x == 14 then
        gate_route_b1 = not gate_route_b1
        params:set("gate_route_b1", gate_route_b1 and 2 or 1)
        print("B→Voice 1: " .. (gate_route_b1 and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == 15 then
        gate_route_b2 = not gate_route_b2
        params:set("gate_route_b2", gate_route_b2 and 2 or 1)
        print("B→Voice 2: " .. (gate_route_b2 and "ON" or "OFF"))
        grid_redraw()
        return
      end
      
      if x == 16 then
        engine.reset()
        beat_count = 0
        print("Clock reset")
        grid_redraw()
        redraw()
        return
      end
      
      return
    end
    
    press_start_time[key_id] = util.time()
    long_press_active = false
    
    clock.run(function()
      clock.sleep(LONG_PRESS_TIME)
      if press_start_time[key_id] ~= nil then
        long_press_active = true
        handle_long_press(x, y)
      end
    end)
    
  else
    local press_duration = util.time() - (press_start_time[key_id] or 0)
    press_start_time[key_id] = nil
    
    if long_press_active then
      long_press_active = false
      return
    end
    
    if current_page ~= 5 then
      handle_short_press(x, y)
    end
  end
end

function handle_short_press(x, y)
  -- Operator selection (right side: cols 14-16, rows 1-5) - only active during patch edit
  if patch_edit_mode and x >= OP_COL_START and x <= OP_COL_END and
     y >= OP_ROW_START and y <= OP_ROW_END then
    
    local op_index = ((y - OP_ROW_START) * 3) + (x - OP_COL_START)
    
    if op_index < #LOGIC_OPS then
      selected_logic = LOGIC_OPS[op_index + 1].id
      logic_mode = true
      print("Logic selected: " .. LOGIC_OPS[op_index + 1].name)
      
      -- Update patch edit screen
      if patch_edit_data then
        patch_edit_data.logic = selected_logic
        if not patch_edit_data.is_creating then
          -- Update existing patch
          engine.patch_logic(
            patch_edit_data.src_reg,
            patch_edit_data.src_stage,
            patch_edit_data.dst_reg,
            patch_edit_data.dst_stage,
            selected_logic
          )
          -- Update in patches table
          for i, p in ipairs(patches) do
            if p.src_reg == patch_edit_data.src_reg and p.src_stage == patch_edit_data.src_stage and
               p.dst_reg == patch_edit_data.dst_reg and p.dst_stage == patch_edit_data.dst_stage then
              p.logic = selected_logic
              break
            end
          end
        end
      end
    end
    
    grid_redraw()
    redraw()
    return
  end
  
  -- Weight selection (left side: cols 1-2, rows 1-8) - only active during patch edit
  if patch_edit_mode and x >= WEIGHT_COL_START and x <= WEIGHT_COL_END and
     y >= WEIGHT_ROW_START and y <= WEIGHT_ROW_END then
    
    local weight_index = ((y - WEIGHT_ROW_START) * 2) + (x - WEIGHT_COL_START)
    patch_weight = (weight_index + 1) / 16.0
    
    -- Update patch edit screen
    if patch_edit_data then
      patch_edit_data.weight = patch_weight
      if not patch_edit_data.is_creating then
        -- Update existing patch
        engine.patch_weight(
          patch_edit_data.src_reg,
          patch_edit_data.src_stage,
          patch_edit_data.dst_reg,
          patch_edit_data.dst_stage,
          patch_weight
        )
        -- Update in patches table
        for i, p in ipairs(patches) do
          if p.src_reg == patch_edit_data.src_reg and p.src_stage == patch_edit_data.src_stage and
             p.dst_reg == patch_edit_data.dst_reg and p.dst_stage == patch_edit_data.dst_stage then
            p.weight = patch_weight
            break
          end
        end
      end
      print("Patch weight: " .. string.format("%.2f", patch_weight))
    end
    
    grid_redraw()
    redraw()
    return
  end

  -- Audio input sources (row 1, cols 8-9)
  for i, src in ipairs(SOURCES) do
    if x == src.col and y == src.row then
      -- If viewing an existing patch, close it first
      if patch_edit_mode or patch_selection_mode then
        exit_patch_edit_mode()
        exit_patch_selection_mode()
      end
      -- Start patch from this source
      start_patch_from_source(src.name, i)
      return
    end
  end

  -- NEW: Horizontal register layout (rows 3-6, cols 5-12)
  local stage = col_to_stage(x)
  if stage then
    -- Register A output (row 3)
    if y == REG_A_OUT_ROW then
      handle_stage_press('a', stage, 'out')
      return
    end
    
    -- Register A input (row 4)
    if y == REG_A_IN_ROW then
      handle_stage_press('a', stage, 'in')
      return
    end
    
    -- Register B output (row 5)
    if y == REG_B_OUT_ROW then
      handle_stage_press('b', stage, 'out')
      return
    end
    
    -- Register B input (row 6)
    if y == REG_B_IN_ROW then
      handle_stage_press('b', stage, 'in')
      return
    end
  end
end

function handle_long_press(x, y)
  print("Long press detected at " .. x .. "," .. y)
  
  -- NEW: Horizontal register layout
  local stage = col_to_stage(x)
  if stage then
    local reg, is_output
    
    if y == REG_A_OUT_ROW then
      reg = 'a'
      is_output = true
    elseif y == REG_A_IN_ROW then
      reg = 'a'
      is_output = false
    elseif y == REG_B_OUT_ROW then
      reg = 'b'
      is_output = true
    elseif y == REG_B_IN_ROW then
      reg = 'b'
      is_output = false
    end
    
    if reg then
      -- Find all patches connected to this node
      local relevant_patches = {}
      for _, patch in ipairs(patches) do
        if is_output then
          if patch.src_reg == reg and patch.src_stage == stage then
            table.insert(relevant_patches, patch)
          end
        else
          if patch.dst_reg == reg and patch.dst_stage == stage then
            table.insert(relevant_patches, patch)
          end
        end
      end
      
      if #relevant_patches == 0 then
        print("No patches at this node")
        return
      elseif #relevant_patches == 1 then
        -- Single patch - go directly to edit mode
        enter_patch_edit_mode(relevant_patches[1])
      else
        -- Multiple patches - enter selection mode
        enter_patch_selection_mode(relevant_patches, {reg=reg, stage=stage, is_output=is_output})
      end
    end
  end
end

function enter_patch_edit_mode(patch)
  patch_edit_mode = true
  patch_selection_mode = false
  patch_edit_data = patch
  selected_logic = patch.logic
  patch_weight = patch.weight
  
  print("Editing patch: " .. patch.src_reg .. "[" .. patch.src_stage .. "] -> " ..
        patch.dst_reg .. "[" .. patch.dst_stage .. "]")
  
  grid_redraw()
  redraw()
end

function enter_patch_selection_mode(patch_list, pressed_node)
  patch_selection_mode = true
  patch_selection_list = patch_list
  patch_selection_index = 1
  patch_selection_pressed = pressed_node
  
  print("Multiple patches found - select one")
  grid_redraw()
  redraw()
end

function exit_patch_edit_mode()
  patch_edit_mode = false
  patch_edit_data = nil
  grid_redraw()
  redraw()
end

function exit_patch_selection_mode()
  patch_selection_mode = false
  patch_selection_list = {}
  patch_selection_index = 1
  patch_selection_pressed = nil
  grid_redraw()
  redraw()
end

function handle_stage_press(reg, stage, direction)
  -- If currently creating a patch (edit screen showing with is_creating = true)
  if patch_edit_mode and patch_edit_data and patch_edit_data.is_creating then
    if direction == 'in' then
      -- Complete the patch
      if patch_edit_data.src_type == "source" then
        complete_patch_source_to_stage(patch_edit_data.src_reg, reg, stage)
      else
        complete_patch(reg, stage)
      end
    elseif direction == 'out' then
      -- Change the source (restart patch creation)
      start_patch(reg, stage)
    end
    return
  end
  
  -- If viewing an existing patch, close it first
  if patch_edit_mode or patch_selection_mode then
    exit_patch_edit_mode()
    exit_patch_selection_mode()
    -- Don't return - continue to start new patch
  end
  
  -- Start new patch from output
  if direction == 'out' then
    start_patch(reg, stage)
  end
  
  grid_redraw()
  redraw()
end

-- Helper to get register stage from column (NEW horizontal layout)
function col_to_stage(col)
  if col >= REG_COL_START and col <= REG_COL_END then
    return col - REG_COL_START
  end
  return nil
end

-- Helper to get column from stage (NEW horizontal layout)
function stage_to_col(stage)
  return REG_COL_START + stage
end

function start_patch(reg, stage)
  -- Enter patch edit mode with temporary patch data
  patch_edit_data = {
    src_reg = reg,
    src_stage = stage,
    dst_reg = "?",
    dst_stage = "?",
    logic = selected_logic,
    weight = patch_weight,
    is_creating = true
  }
  patch_edit_mode = true
  
  print("Patch started: " .. reg .. " stage " .. stage)
  grid_redraw()
  redraw()
end

function complete_patch(dst_reg, dst_stage)
  if not patch_edit_data or not patch_edit_data.is_creating then
    return
  end
  
  local src_reg = patch_edit_data.src_reg
  local src_stage = patch_edit_data.src_stage
  
  -- Check if patch already exists
  local existing_patch = find_patch(src_reg, src_stage, dst_reg, dst_stage)
  
  if existing_patch then
    print("Updating existing patch...")
    engine.patch_logic(src_reg, src_stage, dst_reg, dst_stage, patch_edit_data.logic)
    engine.patch_weight(src_reg, src_stage, dst_reg, dst_stage, patch_edit_data.weight)
    
    existing_patch.logic = patch_edit_data.logic
    existing_patch.weight = patch_edit_data.weight
  else
    local new_patch = {
      src_reg = src_reg,
      src_stage = src_stage,
      dst_reg = dst_reg,
      dst_stage = dst_stage,
      logic = patch_edit_data.logic,
      weight = patch_edit_data.weight
    }
    
    engine.add_patch(src_reg, src_stage, dst_reg, dst_stage, new_patch.logic, new_patch.weight)
    table.insert(patches, new_patch)
    existing_patch = new_patch
  end
  
  print("Patch: " .. src_reg .. "[" .. src_stage .. "]" .. 
        " -> " .. dst_reg .. "[" .. dst_stage .. "]" ..
        " [" .. get_logic_name(patch_edit_data.logic) .. "]" ..
        " w:" .. string.format("%.2f", patch_edit_data.weight))
  
  -- Rebuild source patch cache
  rebuild_source_patch_cache()
  
  local src_col = stage_to_col(src_stage)
  local src_row = src_reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
  local dst_col = stage_to_col(dst_stage)
  local dst_row = dst_reg == 'a' and REG_A_IN_ROW or REG_B_IN_ROW
  trigger_pulse(src_col, src_row)
  trigger_pulse(dst_col, dst_row)
  
  -- Update edit screen with completed patch
  patch_edit_data = existing_patch
  patch_edit_data.is_creating = false
  
  grid_redraw()
  redraw()
end

function start_patch_from_source(source_name, row)
  -- Enter patch edit mode with temporary patch data
  patch_edit_data = {
    src_reg = source_name,
    src_stage = 0,
    src_type = "source",
    dst_reg = "?",
    dst_stage = "?",
    logic = selected_logic,
    weight = patch_weight,
    is_creating = true
  }
  patch_edit_mode = true
  
  print("Patch started from source: " .. source_name)
  grid_redraw()
  redraw()
end

function complete_patch_source_to_stage(source_name, dst_reg, dst_stage)
  if not patch_edit_data or not patch_edit_data.is_creating then
    return
  end
  
  local new_patch = {
    src_reg = source_name,
    src_stage = 0,
    dst_reg = dst_reg,
    dst_stage = dst_stage,
    logic = patch_edit_data.logic,
    weight = patch_edit_data.weight,
    src_type = "source"
  }
  
  engine.add_patch(source_name, 0, dst_reg, dst_stage, new_patch.logic, new_patch.weight)
  table.insert(patches, new_patch)

  print("Patch: " .. source_name .. " -> " .. dst_reg .. "[" .. dst_stage .. "]" ..
        " [" .. get_logic_name(new_patch.logic) .. "]" ..
        " w:" .. string.format("%.2f", new_patch.weight))

  -- Rebuild source patch cache
  rebuild_source_patch_cache()

  local dst_col = stage_to_col(dst_stage)
  local dst_row = dst_reg == 'a' and REG_A_IN_ROW or REG_B_IN_ROW

  -- Find source position and trigger pulse
  for _, src in ipairs(SOURCES) do
    if src.name == source_name then
      trigger_pulse(src.col, src.row)
      break
    end
  end

  trigger_pulse(dst_col, dst_row)

  -- Update edit screen with completed patch
  patch_edit_data = new_patch
  patch_edit_data.is_creating = false

  grid_redraw()
  redraw()
end

function delete_patch(patch)
  engine.remove_patch(
    patch.src_reg,
    patch.src_stage,
    patch.dst_reg,
    patch.dst_stage
  )
  
  for i, p in ipairs(patches) do
    if p == patch then
      table.remove(patches, i)
      print("Patch deleted: " .. patch.src_reg .. "[" .. patch.src_stage .. "] -> " ..
            patch.dst_reg .. "[" .. patch.dst_stage .. "]")
      break
    end
  end
  
  -- Rebuild source patch cache
  rebuild_source_patch_cache()
  
  grid_redraw()
  redraw()
end

function find_patch(src_reg, src_stage, dst_reg, dst_stage)
  for i, patch in ipairs(patches) do
    if patch.src_reg == src_reg and 
       patch.src_stage == src_stage and
       patch.dst_reg == dst_reg and
       patch.dst_stage == dst_stage then
      return patch
    end
  end
  return nil
end

function get_logic_name(logic_id)
  for _, op in ipairs(LOGIC_OPS) do
    if op.id == logic_id then
      return op.short
    end
  end
  return "?"
end

function get_logic_description(logic_id)
  local descriptions = {
    [0] = "Pass input directly",
    [1] = "Logical AND operation",
    [2] = "Logical OR operation", 
    [3] = "Logical XOR (difference)",
    [4] = "Add values",
    [5] = "Multiply values",
    [6] = "Subtract destination from source",
    [7] = "Minimum of two values",
    [8] = "Maximum of two values",
    [9] = "Average of two values",
    [10] = "Invert destination",
    [11] = "Source modulo destination",
    [12] = "Threshold comparison"
  }
  return descriptions[logic_id] or "Unknown operation"
end

-- Voice modulation functions
function toggle_voice_mod(voice_num, src_reg, src_stage, param)
  -- Check if this modulation already exists
  local existing = find_voice_mod(voice_num, src_reg, src_stage, param)

  if existing then
    -- Remove existing modulation
    remove_voice_mod(voice_num, src_reg, src_stage, param)
    print("Removed: V" .. (voice_num + 1) .. " " .. src_reg:upper() .. src_stage .. " -> " .. param)
  else
    -- Add new modulation with default amount
    add_voice_mod(voice_num, src_reg, src_stage, param, 1.0)
    print("Added: V" .. (voice_num + 1) .. " " .. src_reg:upper() .. src_stage .. " -> " .. param)
  end
end

function add_voice_mod(voice_num, src_reg, src_stage, param, amount)
  -- Add to local table
  table.insert(voice_mod_matrix[voice_num + 1], {
    src_reg = src_reg,
    src_stage = src_stage,
    param = param,
    amount = amount
  })

  -- Send to engine
  engine.add_voice_mod(voice_num, src_reg, src_stage, param, amount)
end

function remove_voice_mod(voice_num, src_reg, src_stage, param)
  -- Remove from local table
  for i = #voice_mod_matrix[voice_num + 1], 1, -1 do
    local mod = voice_mod_matrix[voice_num + 1][i]
    if mod.src_reg == src_reg and mod.src_stage == src_stage and mod.param == param then
      table.remove(voice_mod_matrix[voice_num + 1], i)
    end
  end

  -- Send to engine
  engine.remove_voice_mod(voice_num, src_reg, src_stage, param)
end

function find_voice_mod(voice_num, src_reg, src_stage, param)
  for _, mod in ipairs(voice_mod_matrix[voice_num + 1]) do
    if mod.src_reg == src_reg and mod.src_stage == src_stage and mod.param == param then
      return mod
    end
  end
  return nil
end

function add_modulation(src_type, src_index, dest_voice, dest_param, amount)
  engine.add_mod(src_type, src_index, dest_voice, dest_param, amount)
  
  local mod = {
    src_type = src_type,
    src_index = src_index,
    dest_voice = dest_voice,
    dest_param = dest_param,
    amount = amount
  }
  
  local found = false
  for i, m in ipairs(mod_matrix) do
    if m.src_type == src_type and m.src_index == src_index and
       m.dest_voice == dest_voice and m.dest_param == dest_param then
      mod_matrix[i] = mod
      found = true
      break
    end
  end
  
  if not found then
    table.insert(mod_matrix, mod)
  end
  
  print("Mod: " .. src_type .. src_index .. " -> " .. dest_param .. " amt:" .. amount)
end

function remove_modulation(src_type, src_index, dest_voice, dest_param)
  engine.remove_mod(src_type, src_index, dest_voice, dest_param)
  
  for i = #mod_matrix, 1, -1 do
    local m = mod_matrix[i]
    if m.src_type == src_type and m.src_index == src_index and
       m.dest_voice == dest_voice and m.dest_param == dest_param then
      table.remove(mod_matrix, i)
      break
    end
  end
  
  print("Removed mod")
end

function get_source_name(src_type, src_index)
  for _, src in ipairs(MOD_SOURCES) do
    if src.type == src_type and src.index == src_index then
      return src.name
    end
  end
  return "?"
end

local tap_times = {}
local MAX_TAP_INTERVAL = 2.0

function tap_tempo()
  local now = util.time()
  
  local valid_taps = {}
  for _, t in ipairs(tap_times) do
    if (now - t) < MAX_TAP_INTERVAL then
      table.insert(valid_taps, t)
    end
  end
  tap_times = valid_taps
  
  table.insert(tap_times, now)
  
  if #tap_times >= 2 then
    local total_interval = 0
    for i = 2, #tap_times do
      total_interval = total_interval + (tap_times[i] - tap_times[i-1])
    end
    local avg_interval = total_interval / (#tap_times - 1)
    
    local new_tempo = 60 / avg_interval
    new_tempo = util.clamp(math.floor(new_tempo + 0.5), 20, 300)
    
    tempo = new_tempo
    params:set("tempo", tempo)
    print("Tap tempo: " .. tempo .. " BPM")
  end
  
  trigger_pulse(TEMPO_TAP_COL, CLOCK_CTRL_ROW)
end

function key(n, z)
  if n == 1 then
    -- Track K1 held state
    k1_held = (z == 1)
    -- K1 is used as a hold modifier for alternate encoder functions
    -- Clock start/stop is handled by grid buttons

  elseif n == 2 and z == 1 then
    -- Patch edit mode: K2 deletes patch or cancels creation
    if patch_edit_mode and patch_edit_data then
      local patch = patch_edit_data
      
      if patch.is_creating then
        -- Cancel patch creation
        print("Patch creation cancelled")
        patch_mode = false
        patch_source = nil
        logic_mode = false
      else
        -- Delete existing patch
        engine.patch_remove(
          patch.src_reg,
          patch.src_stage,
          patch.dst_reg,
          patch.dst_stage
        )
        -- Remove from patches table
        for i = #patches, 1, -1 do
          local p = patches[i]
          if p.src_reg == patch.src_reg and p.src_stage == patch.src_stage and
             p.dst_reg == patch.dst_reg and p.dst_stage == patch.dst_stage then
            table.remove(patches, i)
            break
          end
        end
        -- Rebuild source patch cache
        rebuild_source_patch_cache()
        print("Patch deleted")
      end
      
      exit_patch_edit_mode()
      grid_redraw()
      redraw()
      return
    end
    
    -- Patch selection mode: K2 cancels
    if patch_selection_mode then
      exit_patch_selection_mode()
      redraw()
      return
    end
    
    -- In patch viz mode, K2 does nothing (reserved for future use)
    if current_page == 1 and patch_viz_mode then
      return
    end

    if current_page == 3 then
      if mute_a and mute_b then
        mute_a = false
        mute_b = false
      elseif mute_a then
        mute_b = true
      elseif mute_b then
        mute_b = false
        mute_a = true
      else
        mute_a = true
      end
      params:set("mute_a", mute_a and 2 or 1)
      params:set("mute_b", mute_b and 2 or 1)
    else
      -- K2 on other pages resets
      engine.reset()
      beat_count = 0
    end
    grid_redraw()
    redraw()
    
  elseif n == 3 and z == 1 then
    -- Patch edit mode: K3 saves and exits (but not during creation)
    if patch_edit_mode then
      if patch_edit_data and patch_edit_data.is_creating then
        -- During creation, K3 does nothing (wait for destination selection)
        print("Select destination on grid")
        return
      else
        -- Existing patch, save and exit
        print("Patch saved")
        exit_patch_edit_mode()
        redraw()
        return
      end
    end
    
    -- Patch selection mode: K3 selects patch and enters edit mode
    if patch_selection_mode then
      local selected_patch = patch_selection_list[patch_selection_index]
      exit_patch_selection_mode()
      enter_patch_edit_mode(selected_patch)
      redraw()
      return
    end
    
    if current_page == 3 then
      if freeze_a and freeze_b then
        freeze_a = false
        freeze_b = false
      elseif freeze_a then
        freeze_b = true
      elseif freeze_b then
        freeze_b = false
        freeze_a = true
      else
        freeze_a = true
      end
      params:set("freeze_a", freeze_a and 2 or 1)
      params:set("freeze_b", freeze_b and 2 or 1)
    elseif current_page == 4 then
      input_mod_target = (input_mod_target + 1) % 4
      params:set("input_mod_target", input_mod_target + 1)
      local target_names = {"Pitch", "Gates", "All", "Complex"}
      print("Input target: " .. target_names[input_mod_target + 1])
    elseif current_page == 5 then
      if mod_source_selected and mod_dest_selected then
        local exists = false
        for _, m in ipairs(mod_matrix) do
          if m.src_type == mod_source_selected.type and
             m.src_index == mod_source_selected.index and
             m.dest_voice == mod_dest_selected.voice and
             m.dest_param == mod_dest_selected.param then
            exists = true
            remove_modulation(
              m.src_type, m.src_index,
              m.dest_voice, m.dest_param
            )
            break
          end
        end
        
        if not exists then
          add_modulation(
            mod_source_selected.type,
            mod_source_selected.index,
            mod_dest_selected.voice,
            mod_dest_selected.param,
            mod_amount
          )
        end
      end
    else
      -- K3: Delete patch in patch viz mode, or delete selected patch in edit mode
      if current_page == 1 and patch_viz_mode and #patches > 0 then
        local patch = patches[patch_viz_index]
        delete_patch(patch)
        -- Adjust index if needed
        if patch_viz_index > #patches then
          patch_viz_index = math.max(1, #patches)
        end
        print("Patch deleted")
      elseif edit_mode and selected_patch then
        delete_patch(selected_patch)
        edit_mode = false
        selected_patch = nil
      end
    end
    grid_redraw()
    redraw()
  end
end

-- Initialize Voice Sound page by requesting current parameter values from engine
function init_voice_sound_page()
  -- Request current values for all voices and all parameters
  for v = 0, voice_count - 1 do
    for _, param_def in ipairs(SOUND_PARAMS) do
      engine.get_voice_param(v, param_def.name)
    end
  end
end

function enc(n, d)
  -- Patch edit mode encoders
  if patch_edit_mode and patch_edit_data then
    if n == 2 then
      -- E2: Change logic operator
      local patch = patch_edit_data
      local new_logic = util.clamp(patch.logic + d, 0, #LOGIC_OPS - 1)
      engine.patch_logic(
        patch.src_reg,
        patch.src_stage,
        patch.dst_reg,
        patch.dst_stage,
        new_logic
      )
      patch.logic = new_logic
      -- Update in patches table
      for i, p in ipairs(patches) do
        if p.src_reg == patch.src_reg and p.src_stage == patch.src_stage and
           p.dst_reg == patch.dst_reg and p.dst_stage == patch.dst_stage then
          p.logic = new_logic
          break
        end
      end
      redraw()
      return
    elseif n == 3 then
      -- E3: Change weight
      local patch = patch_edit_data
      local new_weight = util.clamp(patch.weight + (d * 0.05), 0.0, 1.0)
      engine.patch_weight(
        patch.src_reg,
        patch.src_stage,
        patch.dst_reg,
        patch.dst_stage,
        new_weight
      )
      patch.weight = new_weight
      -- Update in patches table
      for i, p in ipairs(patches) do
        if p.src_reg == patch.src_reg and p.src_stage == patch.src_stage and
           p.dst_reg == patch.dst_reg and p.dst_stage == patch.dst_stage then
          p.weight = new_weight
          break
        end
      end
      redraw()
      return
    end
  end
  
  -- Patch selection mode encoder
  if patch_selection_mode then
    if n == 2 then
      -- E2: Navigate patch list
      patch_selection_index = util.clamp(patch_selection_index + d, 1, #patch_selection_list)
      redraw()
      return
    end
  end
  
  -- E1 with K1 held = Tempo control (Page 1 only)
  if n == 1 and k1_held and current_page == 1 then
    tempo = util.clamp(tempo + d, 20, 300)
    params:set("tempo", tempo)
    redraw()
    return
  end

  -- E1 handling: patch selection in viz mode, otherwise page navigation
  if n == 1 then
    -- In patch viz mode, E1 selects patches instead of changing pages
    if current_page == 1 and patch_viz_mode then
      patch_viz_index = util.clamp(patch_viz_index + d, 1, #patches)
      redraw()
      return
    else
      -- Normal page navigation
      local old_page = current_page
      current_page = util.clamp(current_page + d, 1, #PAGES)
      patch_viz_mode = false  -- Exit patch viz when changing pages

      -- Initialize Voice Sound page when entering it
      if current_page == 6 and old_page ~= 6 then
        init_voice_sound_page()
      end

      print("Page: " .. PAGES[current_page])
      grid_redraw()
      redraw()
      return
    end
  end

  if current_page == 1 then
    -- Patch Visualization Mode encoders (E2 and E3)
    if patch_viz_mode then
      if n == 2 and #patches > 0 then
        -- E2: Change logic operator
        local patch = patches[patch_viz_index]
        local new_logic = util.clamp(patch.logic + d, 0, #LOGIC_OPS - 1)
        engine.patch_logic(
          patch.src_reg,
          patch.src_stage,
          patch.dst_reg,
          patch.dst_stage,
          new_logic
        )
        patch.logic = new_logic
        print("Logic: " .. get_logic_name(new_logic))
        redraw()
        return
      elseif n == 3 and #patches > 0 then
        -- E3: Change weight
        local patch = patches[patch_viz_index]
        local new_weight = util.clamp(patch.weight + (d * 0.05), 0.0, 1.0)
        engine.patch_weight(
          patch.src_reg,
          patch.src_stage,
          patch.dst_reg,
          patch.dst_stage,
          new_weight
        )
        patch.weight = new_weight
        print("Weight: " .. string.format("%.2f", new_weight))
        redraw()
        return
      end
    end

    -- Normal Tangles mode encoders
    if n == 2 then
      if k1_held then
        local divs = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32}
        local current_index = tab.key(divs, clock_div_a) or 1
        local new_index = util.clamp(current_index + d, 1, #divs)
        clock_div_a = divs[new_index]
        engine.clock_div_a(clock_div_a)
        print("Clock A div: " .. clock_div_a)
      else
        selected_logic = util.clamp(selected_logic + d, 0, #LOGIC_OPS - 1)
        logic_mode = true

        if edit_mode and selected_patch then
          engine.patch_logic(
            selected_patch.src_reg,
            selected_patch.src_stage,
            selected_patch.dst_reg,
            selected_patch.dst_stage,
            selected_logic
          )
          selected_patch.logic = selected_logic
        end

        print("Logic: " .. get_logic_name(selected_logic))
      end

    elseif n == 3 then
      if k1_held then
        local divs = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32}
        local current_index = tab.key(divs, clock_div_b) or 1
        local new_index = util.clamp(current_index + d, 1, #divs)
        clock_div_b = divs[new_index]
        engine.clock_div_b(clock_div_b)
        print("Clock B div: " .. clock_div_b)
      else
        patch_weight = util.clamp(patch_weight + (d * 0.05), 0.0, 1.0)

        if edit_mode and selected_patch then
          engine.patch_weight(
            selected_patch.src_reg,
            selected_patch.src_stage,
            selected_patch.dst_reg,
            selected_patch.dst_stage,
            patch_weight
          )
          selected_patch.weight = patch_weight
        end

        print("Weight: " .. string.format("%.2f", patch_weight))
      end
    end
    
  elseif current_page == 2 then
    if n == 2 then
      if k1_held then
        -- K1+E2: Swing subdivision
        swingSubdiv = util.clamp(swingSubdiv + d, 2, 4)
        params:set("swing_subdiv", swingSubdiv == 2 and 1 or 2)
        local subdivStr = swingSubdiv == 2 and "8th" or "16th"
        print("Swing subdivision: " .. subdivStr)
      else
        swing = util.clamp(swing + (d * 0.01), 0, 1)
        params:set("swing", swing)
      end

    elseif n == 3 then
      local lengths = {4, 8, 16, 32, 64}
      local current_index = tab.key(lengths, bar_length) or 3
      local new_index = util.clamp(current_index + d, 1, #lengths)
      bar_length = lengths[new_index]
      params:set("bar_length", new_index)
    end

  elseif current_page == 3 then
    if n == 2 then
      if k1_held then
        -- K1+E2: Clock multiplier A
        clock_mult_a = util.clamp(clock_mult_a + (d * 0.25), 0.25, 4.0)
        params:set("clock_mult_a", clock_mult_a)
        print("Clock mult A: " .. string.format("%.2fx", clock_mult_a))
      else
        chaos_amount = util.clamp(chaos_amount + (d * 0.01), 0, 1)
        params:set("chaos", chaos_amount)
      end

    elseif n == 3 then
      if k1_held then
        -- K1+E3: Clock multiplier B
        clock_mult_b = util.clamp(clock_mult_b + (d * 0.25), 0.25, 4.0)
        params:set("clock_mult_b", clock_mult_b)
        print("Clock mult B: " .. string.format("%.2fx", clock_mult_b))
      else
        pattern_length_a = util.clamp(pattern_length_a + d, 1, 8)
        params:set("pattern_length_a", pattern_length_a)
        print("Pattern length A: " .. pattern_length_a)
      end
    end
    
  elseif current_page == 4 then
    if n == 2 then
      input_mod_amount = util.clamp(input_mod_amount + (d * 0.01), 0, 1)
      params:set("input_mod_amount", input_mod_amount)

    elseif n == 3 then
      input_gain = util.clamp(input_gain + (d * 0.1), 0, 4.0)
      params:set("input_gain", input_gain)
    end
    
  elseif current_page == 5 then
    if n == 2 then
      -- E2: Select scale
      voice_quantize_scale[selected_voice + 1] = util.clamp(
        voice_quantize_scale[selected_voice + 1] + d,
        0, #SCALE_NAMES - 1  -- 0=chromatic, 1-12=scales
      )
      engine.voice_quantize(selected_voice, voice_quantize_scale[selected_voice + 1])
      print("Voice " .. (selected_voice + 1) .. " scale: " .. SCALE_NAMES[voice_quantize_scale[selected_voice + 1] + 1])
      redraw()
      
    elseif n == 3 then
      -- E3: Root note (only if not chromatic)
      if voice_quantize_scale[selected_voice + 1] > 0 then
        voice_root_note[selected_voice + 1] = util.clamp(
          voice_root_note[selected_voice + 1] + d,
          0, 11  -- C to B
        )
        engine.voice_root(selected_voice, voice_root_note[selected_voice + 1])
        print("Voice " .. (selected_voice + 1) .. " root: " .. NOTE_NAMES[voice_root_note[selected_voice + 1] + 1])
        redraw()
      else
        -- If chromatic scale, control modulation amount as before
        mod_amount = util.clamp(mod_amount + (d * 0.01), -1, 1)
        print("Mod amount: " .. string.format("%.2f", mod_amount))
      end
    end

  elseif current_page == 6 then
    -- Voice Sound page
    if n == 2 then
      -- E2: Select parameter
      sound_page_param = util.clamp(sound_page_param + d, 1, #SOUND_PARAMS)
      print("Param: " .. SOUND_PARAMS[sound_page_param].label)

    elseif n == 3 then
      -- E3: Adjust parameter value
      local param_def = SOUND_PARAMS[sound_page_param]
      local cache = voice_param_cache[sound_page_voice + 1]
      local current_value = cache[param_def.name]
      local new_value = util.clamp(current_value + (d * param_def.step), param_def.min, param_def.max)

      -- Update cache
      cache[param_def.name] = new_value

      -- Send to engine
      engine.set_voice_param(sound_page_voice, param_def.name, new_value)

      print(param_def.label .. ": " .. param_def.format(new_value))
    end
  end

  grid_redraw()
  redraw()
end

-- Helper function: check if a register stage has a source patch feeding it
function rebuild_source_patch_cache()
  -- Clear cache
  source_patch_cache = {
    a = {},
    b = {}
  }
  
  -- Rebuild cache from patches
  for _, patch in ipairs(patches) do
    if patch.src_type == "source" then
      local reg = patch.dst_reg
      local stage = patch.dst_stage
      if source_patch_cache[reg] then
        source_patch_cache[reg][stage] = true
      end
    end
  end
end

function has_source_patch(reg, stage)
  -- Use cache instead of iterating through all patches
  return source_patch_cache[reg] and source_patch_cache[reg][stage] or false
end

function grid_redraw()
  if not (g and g.device) then return end
  
  g:all(0)



  -- Page 5: Voice Modulation Matrix
  if current_page == 5 then
    -- Draw modulation matrix (columns 1-12 for params, rows 1-8 for register stages)
    for x = 1, 12 do
      for y = 1, 8 do
        local param = VOICE_PARAMS[x]
        local stage = y - 1
        local brightness = 2  -- Dim for available slots

        -- Check if this modulation exists for the selected voice
        local mod = find_voice_mod(selected_voice, selected_register, stage, param)
        if mod then
          brightness = 10  -- Bright for active modulation
        end

        g:led(x, y, brightness)
      end
    end

    -- Draw register selection buttons (column 14, rows 1-2)
    g:led(14, 1, (selected_register == 'a') and 15 or 6)  -- Register A
    g:led(14, 2, (selected_register == 'b') and 15 or 6)  -- Register B

    -- Draw voice selection buttons (column 15, rows 1-4)
    -- Always show rows 1-2, show 3-4 only in 4-voice mode
    for v = 0, voice_count - 1 do
      local row = v + 1
      local brightness = (v == selected_voice) and 15 or 6
      g:led(15, row, brightness)
    end

    -- Columns 13, 16: Reserved for future features

  elseif current_page == 6 then
    -- Page 6: Voice Sound (Oscillator Control)
    -- Draw voice selection buttons (column 15, rows 1-4)
    for v = 0, voice_count - 1 do
      local row = v + 1
      local brightness = (v == sound_page_voice) and 15 or 6
      g:led(15, row, brightness)
    end

  elseif current_page == 1 and patch_viz_mode then
    -- Patch Visualization Mode (Page 1a)
    -- Draw a visual map of all patches

    -- Draw sources (columns 10-12, rows 3-5) - dimmed
    for i, src in ipairs(SOURCES) do
      local brightness = 4
      -- Highlight if source has any patches
      for _, patch in ipairs(patches) do
        if patch.src_reg == src.name then
          brightness = 10
          break
        end
      end
      g:led(src.col, src.row, brightness)
    end

    -- Draw registers (columns 1-2 for A, 15-16 for B)
    -- Register A stages
    for i=1,8 do
      local has_input = false
      local has_output = false

      for _, patch in ipairs(patches) do
        if patch.dst_reg == 'a' and patch.dst_stage == (i-1) then
          has_input = true
        end
        if patch.src_reg == 'a' and patch.src_stage == (i-1) then
          has_output = true
        end
      end

      g:led(1, i, has_input and 12 or 3)  -- Input side
      g:led(2, i, has_output and 12 or 3) -- Output side
    end

    -- Register B stages
    for i=1,8 do
      local has_input = false
      local has_output = false

      for _, patch in ipairs(patches) do
        if patch.dst_reg == 'b' and patch.dst_stage == (i-1) then
          has_input = true
        end
        if patch.src_reg == 'b' and patch.src_stage == (i-1) then
          has_output = true
        end
      end

      g:led(15, i, has_input and 12 or 3)  -- Input side
      g:led(16, i, has_output and 12 or 3) -- Output side
    end

    -- Draw patch count indicator in center (columns 6-11, row 4)
    local patch_count = #patches
    local indicator_leds = math.min(patch_count, 6)
    for i=1,6 do
      if i <= indicator_leds then
        g:led(5 + i, 4, 10)
      else
        g:led(5 + i, 4, 2)
      end
    end

  else
    -- NEW LAYOUT: Horizontal registers (rows 3-6, cols 5-12)
    
    -- Register A (rows 2-3)
    for stage=0,7 do
      local col = stage_to_col(stage)
      local base_brightness = math.floor(shift_reg_a[stage + 1] * 10) + 4
      if stage >= pattern_length_a then base_brightness = 2 end

      local brightness_out = base_brightness
      local brightness_in = 2  -- Dimmer to distinguish input from output

      -- Pulse effect on output row
      if has_source_patch('a', stage) and pulse_brightness[col] and pulse_brightness[col][REG_A_OUT_ROW] and pulse_brightness[col][REG_A_OUT_ROW] > 0 then
        local pulse_mult = 1.0 + (pulse_brightness[col][REG_A_OUT_ROW] * 0.5)
        brightness_out = math.floor(base_brightness * pulse_mult)
        brightness_out = math.min(brightness_out, 15)
      end

      g:led(col, REG_A_OUT_ROW, brightness_out)  -- Output row
      g:led(col, REG_A_IN_ROW, brightness_in)     -- Input row
    end

    -- Register B (rows 5-6)
    for stage=0,7 do
      local col = stage_to_col(stage)
      local base_brightness = math.floor(shift_reg_b[stage + 1] * 10) + 4
      if stage >= pattern_length_b then base_brightness = 2 end

      local brightness_out = base_brightness
      local brightness_in = 2  -- Dimmer to distinguish input from output

      -- Pulse effect on output row
      if has_source_patch('b', stage) and pulse_brightness[col] and pulse_brightness[col][REG_B_OUT_ROW] and pulse_brightness[col][REG_B_OUT_ROW] > 0 then
        local pulse_mult = 1.0 + (pulse_brightness[col][REG_B_OUT_ROW] * 0.5)
        brightness_out = math.floor(base_brightness * pulse_mult)
        brightness_out = math.min(brightness_out, 15)
      end

      g:led(col, REG_B_OUT_ROW, brightness_out)  -- Output row
      g:led(col, REG_B_IN_ROW, brightness_in)     -- Input row
    end

    -- Source 3x3 grid display (top-left: rows 1-3, cols 1-3)
    for i, src in ipairs(SOURCES) do
      local value = source_values[src.name] or 0.5
      local base_brightness = math.floor(value * 13) + 2  -- Range: 2-15

      local brightness = base_brightness

      -- Apply pulse flash for ALL sources
      if pulse_brightness[src.col] and pulse_brightness[src.col][src.row] and pulse_brightness[src.col][src.row] > 0 then
        local pulse_mult = 1.0 + (pulse_brightness[src.col][src.row] * 0.5)
        brightness = math.floor(base_brightness * pulse_mult)
        brightness = math.min(brightness, 15)
      end

      g:led(src.col, src.row, brightness)
    end

    -- Operators (right side: cols 14-16, rows 1-5) - only show during patch edit
    if patch_edit_mode then
      for row = OP_ROW_START, OP_ROW_END do
        for col = OP_COL_START, OP_COL_END do
          local op_index = ((row - OP_ROW_START) * 3) + (col - OP_COL_START)
          local brightness = 3
          
          if op_index < #LOGIC_OPS then
            local op = LOGIC_OPS[op_index + 1]
            if patch_edit_data and op.id == patch_edit_data.logic then
              brightness = 12
            end
          end
          
          g:led(col, row, brightness)
        end
      end
      
      -- Weights (left side: cols 1-2, rows 1-8) - only show during patch edit
      for row = WEIGHT_ROW_START, WEIGHT_ROW_END do
        for col = WEIGHT_COL_START, WEIGHT_COL_END do
          local weight_index = ((row - WEIGHT_ROW_START) * 2) + (col - WEIGHT_COL_START)
          local weight_level = (weight_index + 1) / 16.0
          local brightness = 3
          
          if patch_edit_data and math.abs(weight_level - patch_edit_data.weight) < 0.07 then
            brightness = 12
          end
          
          g:led(col, row, brightness)
        end
      end
    end
    
    -- Patch selection mode: highlight all connected nodes
    if patch_selection_mode then
      local blink = math.floor(util.time() * 6) % 2 == 0
      if blink then
        for _, patch in ipairs(patch_selection_list) do
          if patch_selection_pressed.is_output then
            -- Pressed output - highlight all destinations
            local dst_col = stage_to_col(patch.dst_stage)
            local dst_row = patch.dst_reg == 'a' and REG_A_IN_ROW or REG_B_IN_ROW
            g:led(dst_col, dst_row, 15)
          else
            -- Pressed input - highlight all sources
            local src_col = stage_to_col(patch.src_stage)
            local src_row = patch.src_reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
            g:led(src_col, src_row, 15)
          end
        end
      end
    end
    
    -- Highlight source node during patch creation
    if patch_edit_mode and patch_edit_data and patch_edit_data.is_creating then
      if patch_edit_data.src_type == "source" then
        -- Highlight audio input source
        for _, src in ipairs(SOURCES) do
          if src.name == patch_edit_data.src_reg then
            g:led(src.col, src.row, 15)
            break
          end
        end
      else
        -- Highlight register stage
        local col = stage_to_col(patch_edit_data.src_stage)
        local row = patch_edit_data.src_reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
        g:led(col, row, 15)
      end
    end
    
    for _, patch in ipairs(patches) do
      local src_col, src_row
      if patch.is_source then
        -- Find the source position in 3x3 grid
        for _, src in ipairs(SOURCES) do
          if src.name == patch.src_reg then
            src_col = src.col
            src_row = src.row
            break
          end
        end
      else
        src_col = stage_to_col(patch.src_stage)
        src_row = patch.src_reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
      end

      local dst_col = stage_to_col(patch.dst_stage)
      local dst_row = patch.dst_reg == 'a' and REG_A_IN_ROW or REG_B_IN_ROW
      local weight_brightness = math.floor(patch.weight * 8) + 4

      if not (edit_mode and patch == selected_patch) then
        local src_brightness = weight_brightness

        -- Override for source patches: use source value brightness
        if patch.is_source then
          local value = source_values[patch.src_reg] or 0.5
          src_brightness = math.floor(value * 13) + 2  -- Same formula as source display
        end

        -- Add pulse for register stages (not sources) - multiplicative
        if not patch.is_source and pulse_brightness[src_col] and pulse_brightness[src_col][src_row] and pulse_brightness[src_col][src_row] > 0 then
          local pulse_mult = 1.0 + (pulse_brightness[src_col][src_row] * 0.5)
          src_brightness = math.floor(src_brightness * pulse_mult)
          src_brightness = math.min(src_brightness, 15)
        end

        g:led(src_col, src_row, src_brightness)
        g:led(dst_col, dst_row, weight_brightness)
      end

      -- TODO: Logic operator visualization disabled - needs redesign for new layout
      -- for i, op in ipairs(LOGIC_OPS) do
      --   if op.id == patch.logic then
      --     local index = i - 1
      --     local logic_col = LOGIC_COL_START + math.floor(index / 8)
      --     local logic_row = (index % 8) + 1
      --     if logic_col <= LOGIC_COL_END then
      --       local logic_brightness = 6
      --       if not patch.is_source and pulse_brightness[src_col] and pulse_brightness[src_col][src_row] and pulse_brightness[src_col][src_row] > 0.5 then
      --         logic_brightness = 12
      --       end
      --       g:led(logic_col, logic_row, logic_brightness)
      --     end
      --     break
      --   end
      -- end
    end
    
    for _, patch in ipairs(patches) do
      local src_col, src_row
      if patch.is_source then
        -- Find the source position in 3x3 grid
        for _, src in ipairs(SOURCES) do
          if src.name == patch.src_reg then
            src_col = src.col
            src_row = src.row
            break
          end
        end
      else
        src_col = stage_to_col(patch.src_stage)
        src_row = patch.src_reg == 'a' and REG_A_OUT_ROW or REG_B_OUT_ROW
      end

      local dst_col = stage_to_col(patch.dst_stage)
      local dst_row = patch.dst_reg == 'a' and REG_A_IN_ROW or REG_B_IN_ROW

      -- TODO: Patch connection lines disabled - needs redesign for new layout
      -- for x = src_col + 1, LOGIC_COL_START - 1 do
      --   g:led(x, src_row, 2)
      -- end
      -- for x = LOGIC_COL_END + 1, dst_col - 1 do
      --   g:led(x, dst_row, 2)
      -- end
    end
  end
  
  -- Gate routing indicators (row 8)
  g:led(2, CLOCK_CTRL_ROW, gate_route_a2 and 12 or 4)  -- A→Voice 2
  g:led(3, CLOCK_CTRL_ROW, gate_route_a1 and 12 or 4)  -- A→Voice 1
  g:led(4, CLOCK_CTRL_ROW, clock_a_enabled and (mute_a and 4 or 12) or 2)
  
  local tap_brightness = 6
  if pulse_brightness[TEMPO_TAP_COL] and pulse_brightness[TEMPO_TAP_COL][CLOCK_CTRL_ROW] and pulse_brightness[TEMPO_TAP_COL][CLOCK_CTRL_ROW] > 0 then
    local pulse_mult = 1.0 + (pulse_brightness[TEMPO_TAP_COL][CLOCK_CTRL_ROW] * 0.5)
    tap_brightness = math.floor(6 * pulse_mult)
    tap_brightness = math.min(tap_brightness, 15)
  end
  g:led(TEMPO_TAP_COL, CLOCK_CTRL_ROW, tap_brightness)
  
  g:led(6, CLOCK_CTRL_ROW, 6)
  g:led(7, CLOCK_CTRL_ROW, 6)
  g:led(8, CLOCK_CTRL_ROW, 8)
  g:led(9, CLOCK_CTRL_ROW, 8)
  g:led(10, CLOCK_CTRL_ROW, 6)
  g:led(11, CLOCK_CTRL_ROW, 6)
  
  g:led(12, CLOCK_CTRL_ROW, clock_b_enabled and (mute_b and 4 or 12) or 2)

  -- Clock start/stop button with pulse
  local clock_btn_brightness = clock_running and 15 or 8
  if pulse_brightness[13] and pulse_brightness[13][CLOCK_CTRL_ROW] and pulse_brightness[13][CLOCK_CTRL_ROW] > 0 then
    local pulse_mult = 1.0 + (pulse_brightness[13][CLOCK_CTRL_ROW] * 0.5)
    clock_btn_brightness = math.floor(clock_btn_brightness * pulse_mult)
    clock_btn_brightness = math.min(clock_btn_brightness, 15)
  end
  g:led(13, CLOCK_CTRL_ROW, clock_btn_brightness)

  g:led(14, CLOCK_CTRL_ROW, gate_route_b1 and 12 or 4)  -- B→Voice 1
  g:led(15, CLOCK_CTRL_ROW, gate_route_b2 and 12 or 4)  -- B→Voice 2
  g:led(16, CLOCK_CTRL_ROW, 8)  -- Clock reset
  
  if freeze_a then
    local blink = math.floor(util.time() * 2) % 2 == 0
    if blink then
      g:led(4, CLOCK_CTRL_ROW, 15)
    end
  end
  
  if freeze_b then
    local blink = math.floor(util.time() * 2) % 2 == 0
    if blink then
      g:led(12, CLOCK_CTRL_ROW, 15)
    end
  end
  
  g:refresh()
end

-- Helper function: get abbreviated logic operator name
function get_logic_short_name(logic_id)
  local short_names = {
    "REP",   -- REPLACE
    "ADD",   -- ADD
    "SUB",   -- SUBTRACT
    "MUL",   -- MULTIPLY
    "AVG",   -- AVERAGE
    "MIN",   -- MIN
    "MAX",   -- MAX
    "AND",   -- AND
    "OR",    -- OR
    "XOR",   -- XOR
    "GT",    -- GREATER THAN
    "LT",    -- LESS THAN
    "MOD"    -- MODULO
  }
  return short_names[logic_id + 1] or "?"
end

-- Helper function: format patch compactly for display
function format_patch_compact(patch)
  local src, dst, logic

  -- Format source
  if patch.is_source then
    src = patch.src_reg:sub(1, 3)  -- Abbreviate source names
  else
    src = patch.src_reg:upper() .. patch.src_stage
  end

  -- Format destination
  dst = patch.dst_reg:upper() .. patch.dst_stage

  -- Get abbreviated logic name
  local logic_short = get_logic_short_name(patch.logic)

  -- Format: "src→dst LOG w:0.8"
  return src .. "→" .. dst .. " " .. logic_short .. " " .. string.format("%.1f", patch.weight)
end

function draw_patch_edit_screen()
  if not patch_edit_data then return end
  
  local patch = patch_edit_data
  screen.clear()
  screen.level(15)
  
  -- Title
  screen.move(0, 10)
  screen.font_face(1)
  screen.font_size(8)
  screen.text(patch.is_creating and "CREATE PATCH" or "EDIT PATCH")
  
  -- Source and destination
  screen.move(0, 22)
  screen.level(10)
  local src = ""
  if patch.src_type == "source" then
    src = "Input " .. patch.src_stage
  else
    src = patch.src_reg:upper() .. patch.src_stage
  end
  local dst = patch.dst_reg ~= "?" and (patch.dst_reg:upper() .. patch.dst_stage) or "?"
  screen.text(src .. " → " .. dst)
  
  -- Operator name (large)
  screen.move(0, 38)
  screen.level(15)
  screen.font_size(10)
  local op_name = get_logic_name(patch.logic)
  screen.text(op_name)
  
  -- Operator description
  screen.move(0, 50)
  screen.level(8)
  screen.font_size(8)
  local op_desc = get_logic_description(patch.logic)
  screen.text(op_desc)
  
  -- Weight
  screen.move(0, 62)
  screen.level(15)
  screen.text(string.format("Weight: %.2f", patch.weight))
  
  -- Instructions
  screen.move(0, 76)
  screen.level(5)
  screen.text("E2: Operator  E3: Weight")
  screen.move(0, 84)
  if patch.is_creating then
    screen.text("K2: Cancel    K3: Next →")
  else
    screen.text("K2: Delete    K3: Save")
  end
  
  screen.update()
end

function draw_patch_selection_screen()
  if not patch_selection_mode or #patch_selection_list == 0 then return end
  
  screen.clear()
  screen.level(15)
  
  -- Title
  screen.move(0, 10)
  screen.font_face(1)
  screen.font_size(8)
  screen.text("SELECT PATCH")
  
  -- Pressed node info
  if patch_selection_pressed then
    local node = patch_selection_pressed
    local node_str = ""
    if node.is_output then
      node_str = node.reg:upper() .. node.stage .. " (out)"
    else
      node_str = node.reg:upper() .. node.stage .. " (in)"
    end
    screen.move(0, 22)
    screen.level(10)
    screen.text(node_str)
  end
  
  -- Patch list
  local start_y = 32
  for i = 1, math.min(3, #patch_selection_list) do
    local patch = patch_selection_list[i]
    screen.move(5, start_y + (i - 1) * 10)
    
    if i == patch_selection_index then
      screen.level(15)
      screen.text("> ")
      screen.move(15, start_y + (i - 1) * 10)
    else
      screen.level(8)
    end
    
    -- Format patch info
    local src = ""
    if patch.src_type == "source" then
      src = "In" .. patch.src_stage
    else
      src = patch.src_reg:upper() .. patch.src_stage
    end
    local dst = patch.dst_reg:upper() .. patch.dst_stage
    local logic_short = get_logic_short_name(patch.logic)
    
    screen.text(src .. "→" .. dst .. " " .. logic_short)
  end
  
  -- Instructions
  screen.move(0, 60)
  screen.level(5)
  screen.text("E2: Navigate  K3: Select")
  
  screen.update()
end

function draw_main_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("TWO TANGLES")
  
  screen.move(90, 10)
  if clock_source == 1 then
    screen.text("MIDI")
  else
    screen.text(tempo .. " BPM")
  end
  
  screen.move(0, 20)
  if clock_running then
    screen.level(15)
    screen.text("▶")
  else
    screen.level(5)
    screen.text("■")
  end
  
  screen.level(clock_a_enabled and 10 or 3)
  screen.move(15, 20)
  screen.text("A:" .. clock_div_a)
  
  if util.time() - last_step_time_a < step_flash_duration and clock_a_enabled then
    screen.level(15)
    screen.rect(35, 13, 8, 8)
    screen.fill()
  else
    screen.level(clock_a_enabled and 5 or 2)
    screen.rect(35, 13, 8, 8)
    screen.stroke()
  end
  
  screen.level(clock_b_enabled and 10 or 3)
  screen.move(50, 20)
  screen.text("B:" .. clock_div_b)
  
  if util.time() - last_step_time_b < step_flash_duration and clock_b_enabled then
    screen.level(15)
    screen.rect(70, 13, 8, 8)
    screen.fill()
  else
    screen.level(clock_b_enabled and 5 or 2)
    screen.rect(70, 13, 8, 8)
    screen.stroke()
  end
  
  if swing ~= 0.5 then
    screen.level(8)
    screen.move(85, 20)
    screen.text("SW:" .. string.format("%.0f%%", (swing - 0.5) * 200))
  end
  
  if reset_on_downbeat then
    screen.level(8)
    screen.move(115, 20)
    screen.text("R")
  end
  
  -- Compact register display
  screen.level(10)
  screen.move(0, 30)
  screen.text("A")
  for i=1,8 do
    local level = clock_a_enabled and math.floor(shift_reg_a[i] * 15) or 2
    screen.level(level)
    screen.rect(10 + (i*7), 26, 5, 5)
    screen.fill()
  end

  screen.level(10)
  screen.move(0, 40)
  screen.text("B")
  for i=1,8 do
    local level = clock_b_enabled and math.floor(shift_reg_b[i] * 15) or 2
    screen.level(level)
    screen.rect(10 + (i*7), 36, 5, 5)
    screen.fill()
  end
  
  -- Patch count
  screen.level(15)
  screen.move(0, 48)
  if #patches == 0 then
    screen.level(8)
    screen.text("No patches")
  else
    screen.text("Patches: " .. #patches)
  end

  -- Help text
  screen.level(5)
  screen.move(0, 64)
  if k1_held then
    screen.text("K1: E1=tempo E2=divA E3=divB")
  else
    screen.text("E1=page  Long press: edit patch")
  end

  screen.update()
end

function draw_clock_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("CLOCK SETTINGS")
  
  screen.move(0, 25)
  screen.level(10)
  screen.text("Source:")
  screen.level(15)
  screen.move(50, 25)
  screen.text(clock_source == 0 and "Internal" or "MIDI")
  
  if clock_source == 0 then
    screen.level(10)
    screen.move(0, 35)
    screen.text("Tempo:")
    screen.level(15)
    screen.move(50, 35)
    screen.text(tempo .. " BPM")
  end
  
  screen.level(10)
  screen.move(0, 45)
  screen.text("Swing:")
  screen.level(15)
  screen.move(50, 45)
  screen.text(string.format("%.0f%%", (swing - 0.5) * 200))
  
  local swing_bar_width = 60
  local swing_center = swing_bar_width / 2
  local swing_pos = swing_center + ((swing - 0.5) * swing_bar_width)
  screen.level(5)
  screen.rect(50, 48, swing_bar_width, 2)
  screen.fill()
  screen.level(15)
  screen.rect(50 + swing_pos - 1, 46, 2, 6)
  screen.fill()
  
  screen.level(10)
  screen.move(0, 56)
  screen.text("Bar: " .. bar_length .. " beats")

  screen.level(10)
  screen.move(70, 56)
  screen.text("Reset:" .. (reset_on_downbeat and "On" or "Off"))

  screen.level(10)
  screen.move(0, 64)
  if k1_held then
    screen.text("K1: E1=page E2=subdiv E3=bar")
  else
    screen.text("E1=page E2=swing E3=bar")
  end
  
  screen.update()
end

function draw_performance_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("PERFORMANCE")
  
  screen.level(10)
  screen.move(0, 25)
  screen.text("Mute:")
  screen.level(mute_a and 15 or 5)
  screen.move(35, 25)
  screen.text("A")
  screen.level(mute_b and 15 or 5)
  screen.move(50, 25)
  screen.text("B")
  screen.level(global_mute and 15 or 2)
  screen.move(65, 25)
  screen.text("GLB")
  
  screen.level(10)
  screen.move(0, 35)
  screen.text("Freeze:")
  screen.level(freeze_a and 15 or 5)
  screen.move(45, 35)
  screen.text("A")
  screen.level(freeze_b and 15 or 5)
  screen.move(60, 35)
  screen.text("B")
  
  screen.level(10)
  screen.move(0, 50)
  screen.text("Length:")
  screen.level(15)
  screen.move(45, 50)
  screen.text("A:" .. pattern_length_a)
  
  for i = 1, 8 do
    screen.level(i <= pattern_length_a and 15 or 3)
    screen.rect(45 + (i * 4), 53, 2, 4)
    screen.fill()
  end
  
  screen.level(15)
  screen.move(85, 50)
  screen.text("B:" .. pattern_length_b)
  
  for i = 1, 8 do
    screen.level(i <= pattern_length_b and 15 or 3)
    screen.rect(85 + (i * 4), 53, 2, 4)
    screen.fill()
  end
  
  screen.level(10)
  screen.move(0, 61)
  screen.text("Chaos:" .. string.format("%.0f%%", chaos_amount * 100))
  screen.move(60, 61)
  screen.text("Mut:" .. string.format("%.0f%%", mutation_rate * 100))

  screen.level(5)
  screen.move(0, 64)
  if k1_held then
    screen.text("K1: E1=page E2=multA E3=multB")
  else
    screen.text("E1=page E2=chaos E3=patA")
  end
  
  screen.update()
end

function draw_audio_input_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("AUDIO INPUT")

  -- Mod Amount with bar (Y=20-24)
  screen.level(10)
  screen.move(0, 20)
  screen.text("Amt:")
  screen.level(15)
  screen.move(30, 20)
  screen.text(string.format("%.0f%%", input_mod_amount * 100))

  local mod_width = math.floor(input_mod_amount * 60)
  screen.level(5)
  screen.rect(65, 17, 60, 3)
  screen.fill()
  screen.level(15)
  screen.rect(65, 17, mod_width, 3)
  screen.fill()

  -- Gain and Smoothing (Y=30)
  screen.level(10)
  screen.move(0, 30)
  screen.text("Gain:")
  screen.level(15)
  screen.move(35, 30)
  screen.text(string.format("%.1fx", input_gain))

  screen.level(10)
  screen.move(65, 30)
  screen.text("Smooth:")
  screen.level(15)
  screen.move(105, 30)
  screen.text(string.format("%.0f", input_smoothing * 1000))

  -- Target and Register (Y=40)
  screen.level(10)
  screen.move(0, 40)
  screen.text("Tgt:")
  screen.level(15)
  screen.move(25, 40)
  local targets = {"Pitch", "Gates", "All", "Complex"}
  screen.text(targets[input_mod_target + 1])

  screen.level(10)
  screen.move(65, 40)
  screen.text("Reg:")
  screen.level(15)
  screen.move(90, 40)
  local regs = {"A", "B", "Both"}
  screen.text(regs[input_mod_reg + 1])

  -- Input Level meter (Y=48-54)
  screen.level(10)
  screen.move(0, 50)
  screen.text("Level:")

  local env_width = math.floor(input_envelope * 85)
  screen.level(5)
  screen.rect(38, 47, 85, 4)
  screen.stroke()
  screen.level(15)
  screen.rect(38, 47, env_width, 4)
  screen.fill()

  -- Pitch (Y=58)
  screen.level(10)
  screen.move(0, 58)
  screen.text("Pitch:")
  screen.level(15)
  screen.move(35, 58)
  screen.text(string.format("%.1f Hz", input_pitch))

  -- Help text (Y=64)
  screen.level(5)
  screen.move(0, 64)
  screen.text("E1:page E2:amt E3:gain")

  screen.update()
end

function draw_voice_mod_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("VOICE MOD")

  -- Show current selection (Y=20)
  -- Match grid layout: Register (col 14) on left, Voice (col 15) on right
  screen.level(10)
  screen.move(0, 20)
  screen.text("Reg:" .. selected_register:upper())

  screen.move(50, 20)
  screen.text("V:" .. (selected_voice + 1) .. "/" .. voice_count)

  -- Show active modulations for current voice
  local mods = voice_mod_matrix[selected_voice + 1]
  local mod_count = #mods

  screen.level(10)
  screen.move(0, 30)
  screen.text("Active (" .. mod_count .. "):")

  if mod_count > 0 then
    local y = 38
    for i = 1, math.min(mod_count, 2) do  -- Show fewer mods to make room for quantization
      local m = mods[i]
      local stage_name = m.src_reg:upper() .. m.src_stage
      local param_name = VOICE_PARAM_NAMES[m.param] or m.param

      screen.level(8)
      screen.move(0, y)
      screen.text(stage_name .. " -> " .. param_name)

      y = y + 8
    end

    if mod_count > 2 then
      screen.level(5)
      screen.move(0, 48)
      screen.text("+" .. (mod_count - 2) .. " more")
    end
  else
    screen.level(5)
    screen.move(0, 38)
    screen.text("No modulations")
  end

  -- Pitch quantization display
  screen.level(10)
  screen.move(0, 58)
  screen.text("Quantize:")
  
  screen.level(15)
  screen.move(60, 58)
  local scale_name = SCALE_NAMES[voice_quantize_scale[selected_voice + 1] + 1] or "Unknown"
  screen.text(scale_name)
  
  if voice_quantize_scale[selected_voice + 1] > 0 then  -- If not chromatic
    screen.level(10)
    screen.move(0, 68)
    screen.text("Root:")
    
    screen.level(15)
    screen.move(30, 68)
    local root_name = NOTE_NAMES[voice_root_note[selected_voice + 1] + 1] or "C"
    screen.text(root_name)
  end

  -- Help text
  screen.level(5)
  screen.move(0, 86)
  screen.text("E2:scale E3:root ALT[16,7] Mod")

  screen.update()
end

function draw_voice_sound_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("VOICE SOUND")

  -- Voice indicator
  screen.level(10)
  screen.move(0, 20)
  screen.text("Voice: " .. (sound_page_voice + 1) .. "/" .. voice_count)

  -- Get cached parameter values for current voice
  local cache = voice_param_cache[sound_page_voice + 1]
  local param_def = SOUND_PARAMS[sound_page_param]

  -- Show current parameter (highlighted)
  screen.level(15)
  screen.move(0, 30)
  screen.text("> " .. param_def.label)

  -- Show current value
  screen.level(12)
  screen.move(0, 38)
  screen.text(param_def.format(cache[param_def.name]))

  -- Show next 3 parameters as preview
  local y = 48
  for i = 1, 3 do
    local preview_idx = sound_page_param + i
    if preview_idx <= #SOUND_PARAMS then
      local preview_def = SOUND_PARAMS[preview_idx]
      screen.level(6)
      screen.move(0, y)
      screen.text(preview_def.label .. ": " .. preview_def.format(cache[preview_def.name]))
      y = y + 6
    end
  end

  -- Help text
  screen.level(5)
  screen.move(0, 64)
  screen.text("E2:param E3:value Grid:voice")

  screen.update()
end

function draw_patch_viz_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("PATCH VISUALIZATION")

  if #patches > 0 then
    -- Clamp patch index
    patch_viz_index = util.clamp(patch_viz_index, 1, #patches)
    local patch = patches[patch_viz_index]

    -- Show current patch info
    screen.level(15)
    screen.move(0, 22)
    screen.text("Patch " .. patch_viz_index .. "/" .. #patches)

    local src_str
    if patch.src_reg == "random" or patch.src_reg == "low" or patch.src_reg == "mid" or
       patch.src_reg == "high" or patch.src_reg == "max" or patch.src_reg == "param1" or
       patch.src_reg == "param2" or patch.src_reg == "voice1" or patch.src_reg == "voice2" then
      src_str = patch.src_reg:sub(1,5)
    else
      src_str = patch.src_reg:upper() .. patch.src_stage
    end

    local dst_str = patch.dst_reg:upper() .. patch.dst_stage

    screen.level(12)
    screen.move(0, 32)
    screen.text("Route: " .. src_str .. " -> " .. dst_str)

    -- Logic operator
    screen.level(10)
    screen.move(0, 42)
    screen.text("Logic:")
    screen.level(15)
    screen.move(42, 42)
    screen.text(get_logic_short_name(patch.logic) .. " (" .. LOGIC_OPS[patch.logic + 1].name .. ")")

    -- Weight
    screen.level(10)
    screen.move(0, 52)
    screen.text("Weight:")
    screen.level(15)
    screen.move(42, 52)
    screen.text(string.format("%.2f", patch.weight))

    -- Weight bar
    local bar_width = math.floor(patch.weight * 80)
    screen.level(5)
    screen.rect(42, 54, 80, 2)
    screen.fill()
    screen.level(15)
    screen.rect(42, 54, bar_width, 2)
    screen.fill()

  else
    screen.level(5)
    screen.move(0, 30)
    screen.text("No patches")
  end

  -- Help text
  screen.level(5)
  screen.move(0, 64)
  screen.text("E1:sel E2:logic E3:wt K3:del")

  screen.update()
end

function redraw()
  if patch_edit_mode then
    draw_patch_edit_screen()
  elseif patch_selection_mode then
    draw_patch_selection_screen()
  elseif current_page == 1 and patch_viz_mode then
    draw_patch_viz_page()
  elseif current_page == 1 then
    draw_main_page()
  elseif current_page == 2 then
    draw_clock_page()
  elseif current_page == 3 then
    draw_performance_page()
  elseif current_page == 4 then
    draw_audio_input_page()
  elseif current_page == 5 then
    draw_voice_mod_page()
  elseif current_page == 6 then
    draw_voice_sound_page()
  end

  screen.update()
end

function cleanup()
  engine.stop()
  if animation_clock then clock.cancel(animation_clock) end
  if screen_refresh_clock then clock.cancel(screen_refresh_clock) end
  if random_source_clock then clock.cancel(random_source_clock) end
  if clock_button_pulse_clock then clock.cancel(clock_button_pulse_clock) end
  
  -- Clear OSC event handler to prevent messages after cleanup
  osc.event = nil
  
  -- Disconnect grid
  if g and g.device then
    g.key = nil
    g:all(0)
    g:refresh()
  end
end