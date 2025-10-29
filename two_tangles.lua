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

-- Grid layout constants
local REG_A_OUT = 1
local REG_A_IN = 2
local REG_B_OUT = 15
local REG_B_IN = 16
local LOGIC_COL_START = 6
local LOGIC_COL_END = 11
local WEIGHT_COL = 3
local CLOCK_CTRL_ROW = 8
local TEMPO_TAP_COL = 5

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

-- Modulation matrix state
local mod_matrix = {}
local mod_source_selected = nil
local mod_dest_selected = nil
local mod_amount = 0.5

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
local PAGES = {"Main", "Clock", "Performance", "Audio In", "Mod Matrix"}

-- Clocks
local animation_clock
local screen_refresh_clock

-- Key timing
local last_k1_time = 0

function init()
  params:add_separator("TWO TANGLES")
  
  -- Clock parameters
  params:add_separator("CLOCK")
  
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
    id = "clock_source",
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
        lua
] = args[i+9]
        
        if active_stages_a[i] == 1 then
          trigger_pulse(REG_A_OUT, i)
        end
      end
      last_step_time_a = util.time()
      
    elseif reg == 'b' then
      for i=1,8 do
        shift_reg_b[i] = args[i+1]
        active_stages_b[i] = args[i+9]
        
        if active_stages_b[i] == 1 then
          trigger_pulse(REG_B_OUT, i)
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
    local col = reg == 'a' and REG_A_OUT or REG_B_OUT
    trigger_pulse(col, stage + 1)
    
  elseif path == "/tt_input_values" then
    input_envelope = args[1]
    input_pitch = args[2]
    
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
  pulse_timers[col][row] = 1.0
  pulse_brightness[col][row] = 15
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
            pulse_brightness[col][row] = math.floor(15 * pulse_timers[col][row])
          end
        end
      end
    end
    
    grid_redraw()
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
    
    if current_page == 5 and y < 8 then
      if x <= 8 then
        local source_index = ((x - 1) * 8) + y - 1
        if source_index < #MOD_SOURCES then
          local src = MOD_SOURCES[source_index + 1]
          mod_source_selected = {type=src.type, index=src.index}
          print("Source: " .. src.name)
          grid_redraw()
          redraw()
          return
        end
      end
      
      if x >= 9 then
        local voice
        if x >= 9 and x <= 10 then
          voice = 0
        elseif x >= 11 and x <= 12 then
          voice = 1
        else
          voice = 2
        end
        
        if y <= #MOD_DESTINATIONS then
          local param = MOD_DESTINATIONS[y]
          mod_dest_selected = {voice=voice, param=param}
          print("Dest: " .. (voice == 0 and "A" or (voice == 1 and "B" or "Both")) .. ":" .. param)
          grid_redraw()
          redraw()
          return
        end
      end
    end
    
    if y == CLOCK_CTRL_ROW then
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
        engine.reset()
        beat_count = 0
        print("Clock reset")
        grid_redraw()
        redraw()
        return
      end
      
      if x == 16 then
        reset_on_downbeat = not reset_on_downbeat
        params:set("reset_downbeat", reset_on_downbeat and 2 or 1)
        print("Reset on downbeat: " .. (reset_on_downbeat and "ON" or "OFF"))
        grid_redraw()
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
  if x >= LOGIC_COL_START and x <= LOGIC_COL_END then
    local logic_index = ((x - LOGIC_COL_START) * 8) + (y - 1)
    
    if logic_index < #LOGIC_OPS then
      selected_logic = LOGIC_OPS[logic_index + 1].id
      logic_mode = true
      print("Logic selected: " .. LOGIC_OPS[logic_index + 1].name)
      
      if edit_mode and selected_patch then
        engine.patch_logic(
          selected_patch.src_reg,
          selected_patch.src_stage,
          selected_patch.dst_reg,
          selected_patch.dst_stage,
          selected_logic
        )
        selected_patch.logic = selected_logic
        print("Patch logic updated")
      end
      
      grid_redraw()
      redraw()
      return
    end
  end
  
  if x == REG_A_OUT and y <= 8 then
    handle_stage_press('a', y-1, 'out')
    return
  end
  
  if x == REG_A_IN and y <= 8 then
    handle_stage_press('a', y-1, 'in')
    return
  end
  
  if x == REG_B_OUT and y <= 8 then
    handle_stage_press('b', y-1, 'out')
    return
  end
  
  if x == REG_B_IN and y <= 8 then
    handle_stage_press('b', y-1, 'in')
    return
  end
  
  if x == WEIGHT_COL and y <= 8 then
    patch_weight = (9 - y) / 8.0
    
    if edit_mode and selected_patch then
      engine.patch_weight(
        selected_patch.src_reg,
        selected_patch.src_stage,
        selected_patch.dst_reg,
        selected_patch.dst_stage,
        patch_weight
      )
      selected_patch.weight = patch_weight
      print("Patch weight updated: " .. string.format("%.2f", patch_weight))
    else
      print("Patch weight set: " .. string.format("%.2f", patch_weight))
    end
    
    grid_redraw()
    redraw()
    return
  end
end

function handle_long_press(x, y)
  print("Long press detected at " .. x .. "," .. y)
  
  if (x == REG_A_OUT or x == REG_A_IN or x == REG_B_OUT or x == REG_B_IN) and y <= 8 then
    local reg = (x == REG_A_OUT or x == REG_A_IN) and 'a' or 'b'
    local stage = y - 1
    local is_output = (x == REG_A_OUT or x == REG_B_OUT)
    
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
    
    if #relevant_patches > 0 then
      selected_patch = relevant_patches[1]
      edit_mode = true
      
      selected_logic = selected_patch.logic
      patch_weight = selected_patch.weight
      
      print("Editing patch: " .. selected_patch.src_reg .. "[" .. selected_patch.src_stage .. "] -> " ..
            selected_patch.dst_reg .. "[" .. selected_patch.dst_stage .. "]")
      
      local src_col = selected_patch.src_reg == 'a' and REG_A_OUT or REG_B_OUT
      local dst_col = selected_patch.dst_reg == 'a' and REG_A_IN or REG_B_IN
      trigger_pulse(src_col, selected_patch.src_stage + 1)
      trigger_pulse(dst_col, selected_patch.dst_stage + 1)
      
      grid_redraw()
      redraw()
    end
  end
end

function handle_stage_press(reg, stage, direction)
  if edit_mode and selected_patch then
    local matches = false
    if direction == 'out' then
      matches = (selected_patch.src_reg == reg and selected_patch.src_stage == stage)
    else
      matches = (selected_patch.dst_reg == reg and selected_patch.dst_stage == stage)
    end
    
    if matches then
      delete_patch(selected_patch)
      edit_mode = false
      selected_patch = nil
      return
    end
  end
  
  if patch_mode then
    if direction == 'in' and patch_source then
      complete_patch(reg, stage)
    elseif direction == 'out' and patch_source then
      patch_source = {reg=reg, stage=stage}
      print("Patch source changed: " .. reg .. " stage " .. stage)
    end
  else
    if direction == 'out' then
      start_patch(reg, stage)
    end
  end
  
  grid_redraw()
  redraw()
end

function start_patch(reg, stage)
  patch_mode = true
  patch_source = {reg=reg, stage=stage}
  edit_mode = false
  selected_patch = nil
  print("Patch started: " .. reg .. " stage " .. stage)
  grid_redraw()
  redraw()
end

function complete_patch(dst_reg, dst_stage)
  if patch_source then
    local existing_patch = find_patch(
      patch_source.reg, 
      patch_source.stage, 
      dst_reg, 
      dst_stage
    )
    
    if existing_patch then
      print("Updating existing patch...")
      engine.patch_logic(
        patch_source.reg,
        patch_source.stage,
        dst_reg,
        dst_stage,
        selected_logic
      )
      engine.patch_weight(
        patch_source.reg,
        patch_source.stage,
        dst_reg,
        dst_stage,
        patch_weight
      )
      
      existing_patch.logic = selected_logic
      existing_patch.weight = patch_weight
      
    else
      engine.add_patch(
        patch_source.reg,
        patch_source.stage,
        dst_reg,
        dst_stage,
        selected_logic,
        patch_weight
      )
      
      table.insert(patches, {
        src_reg = patch_source.reg,
        src_stage = patch_source.stage,
        dst_reg = dst_reg,
        dst_stage = dst_stage,
        logic = selected_logic,
        weight = patch_weight
      })
    end
    
    print("Patch: " .. patch_source.reg .. "[" .. patch_source.stage .. "]" .. 
          " -> " .. dst_reg .. "[" .. dst_stage .. "]" ..
          " [" .. get_logic_name(selected_logic) .. "]" ..
          " w:" .. string.format("%.2f", patch_weight))
    
    local src_col = patch_source.reg == 'a' and REG_A_OUT or REG_B_OUT
    local dst_col = dst_reg == 'a' and REG_A_IN or REG_B_IN
    trigger_pulse(src_col, patch_source.stage + 1)
    trigger_pulse(dst_col, dst_stage + 1)
    
    patch_mode = false
    patch_source = nil
    logic_mode = false
    
    grid_redraw()
    redraw()
  end
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
    if z == 1 then
      last_k1_time = util.time()
    else
      local hold_time = util.time() - last_k1_time
      if hold_time > 0.5 then
        current_page = current_page % #PAGES + 1
        print("Page: " .. PAGES[current_page])
      else
        clock_running = not clock_running
        if clock_running then
          engine.start()
          print("Clock started")
        else
          engine.stop()
          print("Clock stopped")
        end
      end
      redraw()
    end
    
  elseif n == 2 and z == 1 then
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
      if edit_mode then
        edit_mode = false
        selected_patch = nil
      elseif patch_mode then
        patch_mode = false
        patch_source = nil
        logic_mode = false
      else
        engine.reset()
        beat_count = 0
      end
    end
    grid_redraw()
    redraw()
    
  elseif n == 3 and z == 1 then
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
      if edit_mode and selected_patch then
        delete_patch(selected_patch)
        edit_mode = false
        selected_patch = nil
      end
    end
    grid_redraw()
    redraw()
  end
end

function enc(n, d)
  if current_page == 1 then
    if n == 1 then
      tempo = util.clamp(tempo + d, 20, 300)
      params:set("tempo", tempo)
      
    elseif n == 2 then
      local k1_held = (util.time() - last_k1_time) < 0.3
      
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
      local k1_held = (util.time() - last_k1_time) < 0.3
      
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
    if n == 1 then
      swing = util.clamp(swing + (d * 0.01), 0, 1)
      params:set("swing", swing)
      
    elseif n == 2 then
      local lengths = {4, 8, 16, 32, 64}
      local current_index = tab.key(lengths, bar_length) or 3
      local new_index = util.clamp(current_index + d, 1, #lengths)
      bar_length = lengths[new_index]
      params:set("bar_length", new_index)
    end
    
  elseif current_page == 3 then
    if n == 1 then
      chaos_amount = util.clamp(chaos_amount + (d * 0.01), 0, 1)
      params:set("chaos", chaos_amount)
      
    elseif n == 2 then
      local k1_held = (util.time() - last_k1_time) < 0.3
      
      if k1_held then
        clock_mult_a = util.clamp(clock_mult_a + (d * 0.25), 0.25, 4.0)
        params:set("clock_mult_a", clock_mult_a)
        print("Clock mult A: " .. string.format("%.2fx", clock_mult_a))
      else
        pattern_length_a = util.clamp(pattern_length_a + d, 1, 8)
        params:set("pattern_length_a", pattern_length_a)
        print("Pattern length A: " .. pattern_length_a)
      end
      
    elseif n == 3 then
      local k1_held = (util.time() - last_k1_time) < 0.3
      
      if k1_held then
        clock_mult_b = util.clamp(clock_mult_b + (d * 0.25), 0.25, 4.0)
        params:set("clock_mult_b", clock_mult_b)
        print("Clock mult B: " .. string.format("%.2fx", clock_mult_b))
      else
        pattern_length_b = util.clamp(pattern_length_b + d, 1, 8)
        params:set("pattern_length_b", pattern_length_b)
        print("Pattern length B: " .. pattern_length_b)
      end
    end
    
  elseif current_page == 4 then
    if n == 1 then
      input_mod_amount = util.clamp(input_mod_amount + (d * 0.01), 0, 1)
      params:set("input_mod_amount", input_mod_amount)
      
    elseif n == 2 then
      input_gain = util.clamp(input_gain + (d * 0.1), 0, 4.0)
      params:set("input_gain", input_gain)
      
    elseif n == 3 then
      local exp_d = d * 0.01
      input_smoothing = util.clamp(input_smoothing * (1 + exp_d), 0.001, 1.0)
      params:set("input_smoothing", input_smoothing)
    end
    
  elseif current_page == 5 then
    if n == 3 then
      mod_amount = util.clamp(mod_amount + (d * 0.01), -1, 1)
      print("Mod amount: " .. string.format("%.2f", mod_amount))
    end
  end
  
  grid_redraw()
  redraw()
end

function grid_redraw()
  g:all(0)
  
  if current_page == 5 then
    for i, src in ipairs(MOD_SOURCES) do
      local index = i - 1
      local col = math.floor(index / 8) + 1
      local row = (index % 8) + 1
      
      if col <= 8 then
        local brightness = 4
        
        if mod_source_selected and 
           mod_source_selected.type == src.type and
           mod_source_selected.index == src.index then
          brightness = 15
        end
        
        for _, m in ipairs(mod_matrix) do
          if m.src_type == src.type and m.src_index == src.index then
            brightness = math.max(brightness, 8)
            break
          end
        end
        
        g:led(col, row, brightness)
      end
    end
    
    for i, param in ipairs(MOD_DESTINATIONS) do
      local brightness_a = 4
      if mod_dest_selected and 
         mod_dest_selected.voice == 0 and 
         mod_dest_selected.param == param then
        brightness_a = 15
      end
      for _, m in ipairs(mod_matrix) do
        if (m.dest_voice == 0 or m.dest_voice == 2) and m.dest_param == param then
          brightness_a = math.max(brightness_a, 8)
          break
        end
      end
      g:led(9, i, brightness_a)
      
      local brightness_b = 4
      if mod_dest_selected and 
         mod_dest_selected.voice == 1 and 
         mod_dest_selected.param == param then
        brightness_b = 15
      end
      for _, m in ipairs(mod_matrix) do
        if (m.dest_voice == 1 or m.dest_voice == 2) and m.dest_param == param then
        brightness_b = math.max(brightness_b, 8)
          break
        end
      end
      g:led(11, i, brightness_b)
      
      local brightness_both = 4
      if mod_dest_selected and 
         mod_dest_selected.voice == 2 and 
         mod_dest_selected.param == param then
        brightness_both = 15
      end
      for _, m in ipairs(mod_matrix) do
        if m.dest_voice == 2 and m.dest_param == param then
          brightness_both = math.max(brightness_both, 8)
          break
        end
      end
      g:led(13, i, brightness_both)
    end
    
    if mod_source_selected then
      for _, m in ipairs(mod_matrix) do
        if m.src_type == mod_source_selected.type and 
           m.src_index == mod_source_selected.index then
          for i, param in ipairs(MOD_DESTINATIONS) do
            if param == m.dest_param then
              local voice_col = m.dest_voice == 0 and 9 or 
                              (m.dest_voice == 1 and 11 or 13)
              
              local flash = math.floor(util.time() * 4) % 2 == 0
              if flash then
                g:led(voice_col, i, 12)
              end
              break
            end
          end
        end
      end
    end
    
  else
    for i=1,8 do
      local brightness = math.floor(shift_reg_a[i] * 10) + 4
      brightness = math.max(brightness, pulse_brightness[REG_A_OUT][i])
      if i > pattern_length_a then brightness = 2 end
      g:led(REG_A_OUT, i, brightness)
      g:led(REG_A_IN, i, 4)
    end
    
    for i=1,8 do
      local brightness = math.floor(shift_reg_b[i] * 10) + 4
      brightness = math.max(brightness, pulse_brightness[REG_B_OUT][i])
      if i > pattern_length_b then brightness = 2 end
      g:led(REG_B_OUT, i, brightness)
      g:led(REG_B_IN, i, 4)
    end
    
    for i, op in ipairs(LOGIC_OPS) do
      local index = i - 1
      local col = LOGIC_COL_START + math.floor(index / 8)
      local row = (index % 8) + 1
      
      if col <= LOGIC_COL_END then
        local brightness = 3
        
        if op.id == selected_logic then
          brightness = 12
        end
        
        if logic_mode or edit_mode then
          brightness = brightness + 2
        end
        
        g:led(col, row, brightness)
      end
    end
    
    for row=1,8 do
      local brightness = 2
      local threshold = math.floor(patch_weight * 8)
      if (9 - row) <= threshold then
        brightness = 8
      end
      g:led(WEIGHT_COL, row, brightness)
    end
    
    if edit_mode and selected_patch then
      local src_col = selected_patch.src_reg == 'a' and REG_A_OUT or REG_B_OUT
      local dst_col = selected_patch.dst_reg == 'a' and REG_A_IN or REG_B_IN
      
      local blink = math.floor(util.time() * 4) % 2 == 0
      if blink then
        g:led(src_col, selected_patch.src_stage + 1, 15)
        g:led(dst_col, selected_patch.dst_stage + 1, 15)
      end
    end
    
    if patch_mode and patch_source then
      local col = patch_source.reg == 'a' and REG_A_OUT or REG_B_OUT
      g:led(col, patch_source.stage + 1, 15)
    end
    
    for _, patch in ipairs(patches) do
      local src_col = patch.src_reg == 'a' and REG_A_OUT or REG_B_OUT
      local dst_col = patch.dst_reg == 'a' and REG_A_IN or REG_B_IN
      local weight_brightness = math.floor(patch.weight * 8) + 4
      
      if not (edit_mode and patch == selected_patch) then
        local src_brightness = weight_brightness
        if pulse_brightness[src_col][patch.src_stage + 1] > 0 then
          src_brightness = 15
        end
        g:led(src_col, patch.src_stage + 1, src_brightness)
        g:led(dst_col, patch.dst_stage + 1, weight_brightness)
      end
      
      for i, op in ipairs(LOGIC_OPS) do
        if op.id == patch.logic then
          local index = i - 1
          local logic_col = LOGIC_COL_START + math.floor(index / 8)
          local logic_row = (index % 8) + 1
          
          if logic_col <= LOGIC_COL_END then
            local logic_brightness = 6
            if pulse_brightness[src_col][patch.src_stage + 1] > 8 then
              logic_brightness = 12
            end
            g:led(logic_col, logic_row, logic_brightness)
          end
          break
        end
      end
    end
    
    for _, patch in ipairs(patches) do
      local src_col = patch.src_reg == 'a' and REG_A_OUT or REG_B_OUT
      local dst_col = patch.dst_reg == 'a' and REG_A_IN or REG_B_IN
      local src_row = patch.src_stage + 1
      local dst_row = patch.dst_stage + 1
      
      for x = src_col + 1, LOGIC_COL_START - 1 do
        g:led(x, src_row, 2)
      end
      
      for x = LOGIC_COL_END + 1, dst_col - 1 do
        g:led(x, dst_row, 2)
      end
    end
  end
  
  g:led(4, CLOCK_CTRL_ROW, clock_a_enabled and (mute_a and 4 or 12) or 2)
  
  local tap_brightness = 6
  if pulse_brightness[TEMPO_TAP_COL] and pulse_brightness[TEMPO_TAP_COL][CLOCK_CTRL_ROW] then
    tap_brightness = pulse_brightness[TEMPO_TAP_COL][CLOCK_CTRL_ROW]
  end
  g:led(TEMPO_TAP_COL, CLOCK_CTRL_ROW, tap_brightness)
  
  g:led(6, CLOCK_CTRL_ROW, 6)
  g:led(7, CLOCK_CTRL_ROW, 6)
  g:led(8, CLOCK_CTRL_ROW, 8)
  g:led(9, CLOCK_CTRL_ROW, 8)
  g:led(10, CLOCK_CTRL_ROW, 6)
  g:led(11, CLOCK_CTRL_ROW, 6)
  
  g:led(12, CLOCK_CTRL_ROW, clock_b_enabled and (mute_b and 4 or 12) or 2)
  g:led(13, CLOCK_CTRL_ROW, clock_running and 15 or 8)
  g:led(14, CLOCK_CTRL_ROW, 8)
  g:led(16, CLOCK_CTRL_ROW, reset_on_downbeat and 12 or 4)
  
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
  
  screen.level(15)
  screen.move(0, 35)
  screen.text("Register A:")
  for i=1,8 do
    local level = clock_a_enabled and math.floor(shift_reg_a[i] * 15) or 2
    screen.level(level)
    screen.rect(10 + (i*8), 40, 6, 6)
    screen.fill()
  end
  
  screen.level(15)
  screen.move(0, 55)
  screen.text("Register B:")
  for i=1,8 do
    local level = clock_b_enabled and math.floor(shift_reg_b[i] * 15) or 2
    screen.level(level)
    screen.rect(10 + (i*8), 60, 6, 6)
    screen.fill()
  end
  
  screen.level(15)
  screen.move(0, 75)
  if edit_mode and selected_patch then
    screen.text("EDIT: " .. selected_patch.src_reg .. "[" .. selected_patch.src_stage .. "] -> " ..
                selected_patch.dst_reg .. "[" .. selected_patch.dst_stage .. "]")
    screen.move(0, 85)
    screen.level(10)
    screen.text(get_logic_name(selected_patch.logic) .. 
                " w:" .. string.format("%.2f", selected_patch.weight))
  elseif patch_mode and patch_source then
    screen.text("PATCH: " .. patch_source.reg .. "[" .. patch_source.stage .. "]")
    screen.move(0, 85)
    screen.level(10)
    screen.text(get_logic_name(selected_logic) .. 
                " w:" .. string.format("%.2f", patch_weight))
  else
    screen.text("Patches: " .. #patches)
  end
  
  screen.level(5)
  screen.move(0, 100)
  screen.text("K1:start E1:tempo")
  screen.move(0, 110)
  screen.text("Hold K1: page  +E2/3:divs")
  
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
  screen.move(0, 60)
  screen.text("Subdiv:")
  screen.level(15)
  screen.move(50, 60)
  screen.text(swing_subdiv == 2 and "8th" or "16th")
  
  screen.level(10)
  screen.move(0, 70)
  screen.text("Bar:")
  screen.level(15)
  screen.move(50, 70)
  screen.text(bar_length .. " beats")
  
  screen.level(10)
  screen.move(0, 80)
  screen.text("Reset:")
  screen.level(15)
  screen.move(50, 80)
  screen.text(reset_on_downbeat and "On" or "Off")
  
  screen.level(10)
  screen.move(0, 90)
  screen.text("Clocks:")
  screen.level(clock_a_enabled and 15 or 5)
  screen.move(50, 90)
  screen.text("A")
  screen.level(clock_b_enabled and 15 or 5)
  screen.move(65, 90)
  screen.text("B")
  
  screen.level(5)
  screen.move(0, 105)
  screen.text("E1:swing E2:bar")
  screen.move(0, 115)
  screen.text("K1:page K2:reset K3:toggles")
  
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
  screen.move(0, 68)
  screen.text("Speed:")
  screen.level(15)
  screen.move(45, 68)
  screen.text(string.format("A:%.2fx", clock_mult_a))
  screen.move(85, 68)
  screen.text(string.format("B:%.2fx", clock_mult_b))
  
  screen.level(10)
  screen.move(0, 80)
  screen.text("Chaos:")
  screen.level(15)
  screen.move(45, 80)
  screen.text(string.format("%.0f%%", chaos_amount * 100))
  
  local chaos_width = math.floor(chaos_amount * 78)
  screen.level(5)
  screen.rect(45, 83, 78, 2)
  screen.fill()
  screen.level(15)
  screen.rect(45, 83, chaos_width, 2)
  screen.fill()
  
  screen.level(10)
  screen.move(0, 92)
  screen.text("Mutation:")
  screen.level(15)
  screen.move(60, 92)
  screen.text(string.format("%.0f%%", mutation_rate * 100))
  
  screen.level(10)
  screen.move(0, 104)
  screen.text("Feedback:")
  screen.level(15)
  screen.move(60, 104)
  screen.text(string.format("%.0f%%", feedback_amount * 100))
  
  screen.level(5)
  screen.move(0, 118)
  screen.text("K2:mute K3:freeze E1:chaos")
  
  screen.update()
end

function draw_audio_input_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("AUDIO INPUT")
  
  screen.level(10)
  screen.move(0, 25)
  screen.text("Mod Amount:")
  screen.level(15)
  screen.move(75, 25)
  screen.text(string.format("%.0f%%", input_mod_amount * 100))
  
  local mod_width = math.floor(input_mod_amount * 118)
  screen.level(5)
  screen.rect(5, 28, 118, 3)
  screen.fill()
  screen.level(15)
  screen.rect(5, 28, mod_width, 3)
  screen.fill()
  
  screen.level(10)
  screen.move(0, 40)
  screen.text("Input Gain:")
  screen.level(15)
  screen.move(75, 40)
  screen.text(string.format("%.1fx", input_gain))
  
  screen.level(10)
  screen.move(0, 50)
  screen.text("Smoothing:")
  screen.level(15)
  screen.move(75, 50)
  screen.text(string.format("%.0fms", input_smoothing * 1000))
  
  screen.level(10)
  screen.move(0, 65)
  screen.text("Target:")
  screen.level(15)
  screen.move(50, 65)
  local targets = {"Pitch", "Gates", "All", "Complex"}
  screen.text(targets[input_mod_target + 1])
  
  screen.level(10)
  screen.move(0, 75)
  screen.text("Modulates:")
  screen.level(15)
  screen.move(70, 75)
  local regs = {"A", "B", "Both"}
  screen.text(regs[input_mod_reg + 1])
  
  screen.level(10)
  screen.move(0, 90)
  screen.text("Input Level:")
  
  local env_width = math.floor(input_envelope * 80)
  screen.level(5)
  screen.rect(5, 93, 80, 6)
  screen.stroke()
  screen.level(15)
  screen.rect(5, 93, env_width, 6)
  screen.fill()
  
  screen.level(10)
  screen.move(0, 105)
  screen.text("Pitch:")
  screen.level(15)
  screen.move(40, 105)
  screen.text(string.format("%.1f Hz", input_pitch))
  
  screen.level(5)
  screen.move(0, 118)
  screen.text("E1:amt E2:gain E3:smooth K3:target")
  
  screen.update()
end

function draw_mod_matrix_page()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("MODULATION MATRIX")
  
  screen.level(10)
  screen.move(110, 10)
  screen.text(#mod_matrix)
  
  if #mod_matrix > 0 then
    screen.level(10)
    screen.move(0, 25)
    screen.text("Active:")
    
    local y = 35
    for i = 1, math.min(#mod_matrix, 6) do
      local m = mod_matrix[i]
      local src_name = get_source_name(m.src_type, m.src_index)
      local dest_name = MOD_DEST_NAMES[m.dest_param] or m.dest_param
      local voice_name = m.dest_voice == 0 and "A" or (m.dest_voice == 1 and "B" or "AB")
      
      screen.level(8)
      screen.move(0, y)
      screen.text(src_name .. " -> " .. voice_name .. ":" .. dest_name)
      
      screen.level(15)
      screen.move(100, y)
      screen.text(string.format("%.2f", m.amount))
      
      y = y + 8
    end
    
    if #mod_matrix > 6 then
      screen.level(5)
      screen.move(0, y)
      screen.text("+" .. (#mod_matrix - 6) .. " more")
    end
  else
    screen.level(5)
    screen.move(0, 35)
    screen.text("No modulations")
  end
  
  screen.level(15)
  screen.move(0, 90)
  if mod_source_selected then
    screen.text("Src: " .. get_source_name(mod_source_selected.type, mod_source_selected.index))
  else
    screen.level(5)
    screen.text("Select source")
  end
  
  screen.level(15)
  screen.move(0, 100)
  if mod_dest_selected then
    local voice_name = mod_dest_selected.voice == 0 and "A" or 
                      (mod_dest_selected.voice == 1 and "B" or "Both")
    local param_name = MOD_DEST_NAMES[mod_dest_selected.param]
    screen.text("Dst: " .. voice_name .. ":" .. param_name)
  else
    screen.level(5)
    screen.text("Select destination")
  end
  
  screen.level(10)
  screen.move(0, 110)
  screen.text("Amount:")
  screen.level(15)
  screen.move(50, 110)
  screen.text(string.format("%.0f%%", mod_amount * 100))
  
  local amt_width = math.floor(math.abs(mod_amount) * 60)
  local amt_x = mod_amount >= 0 and 64 or (64 - amt_width)
  screen.level(5)
  screen.rect(4, 113, 120, 2)
  screen.fill()
  screen.level(15)
  screen.rect(64, 113, 1, 2)
  screen.fill()
  screen.level(12)
  screen.rect(amt_x, 113, amt_width, 2)
  screen.fill()
  
  screen.level(5)
  screen.move(0, 125)
  screen.text("Use Grid to select  K3:add/remove")
  
  screen.update()
end

function redraw()
  if current_page == 1 then
    draw_main_page()
  elseif current_page == 2 then
    draw_clock_page()
  elseif current_page == 3 then
    draw_performance_page()
  elseif current_page == 4 then
    draw_audio_input_page()
  elseif current_page == 5 then
    draw_mod_matrix_page()
  end
  
  screen.update()
end

function cleanup()
  engine.stop()
  clock.cancel(animation_clock)
  clock.cancel(screen_refresh_clock)
end