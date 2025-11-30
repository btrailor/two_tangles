# Pulse Animation Redesign

## Current Behavior (Problems)

### Register Outputs
**Location**: Lines 2159-2176 (grid_redraw function)

```lua
for i=1,8 do
  local brightness = math.floor(shift_reg_a[i] * 10) + 4
  brightness = math.max(brightness, pulse_brightness[REG_A_OUT][i])  -- Overrides with pulse
  if i > pattern_length_a then brightness = 2 end
  g:led(REG_A_OUT, i, brightness)
  g:led(REG_A_IN, i, 4)
end
```

**Problems**:
- ❌ All register stages pulse at **full bright (15)** when clock steps
- ❌ Pulses regardless of whether stage has source patch
- ❌ Overrides register value brightness completely

### Sources
**Location**: Lines 2179-2191

```lua
for i, src in ipairs(SOURCES) do
  local value = source_values[src.name] or 0.5
  local brightness = math.floor(value * 13) + 2

  -- Only random source pulses
  if src.name == "random" and pulse_brightness[src.col] and pulse_brightness[src.col][src.row] then
    brightness = pulse_brightness[src.col][src.row]
  end

  g:led(src.col, src.row, brightness)
end
```

**Problems**:
- ❌ Only random source pulses
- ❌ Other sources (low, mid, high, max, params) don't pulse
- ❌ No visual feedback for clock running

## Desired Behavior

### Sources - Pulse at Current Brightness

**All sources should pulse when clock is running:**
- Random source: Pulses at random brightness (changes each pulse)
- Low source (0.25): Pulses between ~0-6 brightness
- Mid source (0.5): Pulses between ~0-9 brightness
- High source (0.75): Pulses between ~0-12 brightness
- Max source (1.0): Pulses between ~0-15 brightness
- Param sources: Pulse at current parameter value brightness

**Visual effect**: Pulsing "heartbeat" that shows source strength

### Register Outputs - Conditional Pulsing

**Register stages should pulse ONLY when they have a source patch:**

Example patches:
```
random → A[0]  ✅ A[0] output pulses
mid → A[3]     ✅ A[3] output pulses
B[2] → A[5]    ❌ A[5] output doesn't pulse (register source, not external source)
(no patch)     ❌ A[7] output doesn't pulse (just shifts from A[6])
```

**Visual effect**: Shows which stages are being actively "injected" with external source values

**Pulse brightness**: Should pulse at the register's current value brightness, not full bright

## Implementation Plan

### Step 1: Track Source Patches Per Stage

Need to know which register stages have source patches feeding them:

```lua
-- In grid_redraw or as separate function
local function has_source_patch(reg, stage)
  for _, patch in ipairs(patches) do
    if patch.is_source and patch.dst_reg == reg and patch.dst_stage == stage then
      return true
    end
  end
  return false
end
```

### Step 2: Modify Pulse Triggering

**Current**: Pulses triggered in `osc.event` callback (lines 1020-1089)

```lua
-- Trigger pulse for each active stage
if stages[i] == 1 then
  trigger_pulse(REG_A_OUT, i)
end
```

**New**: Add source pulse triggering on clock step

```lua
-- In stepShiftRegister callback (reg == 'a' section)
if reg == 'a' then
  -- Existing register pulse logic...
  for i=1,8 do
    if stages[i] == 1 then
      trigger_pulse(REG_A_OUT, i)
    end
  end

  -- NEW: Trigger pulses for all sources
  for _, src in ipairs(SOURCES) do
    trigger_pulse(src.col, src.row)
  end
end
```

### Step 3: Modify Pulse Animation

**Change pulse from "override to 15" to "multiplicative flash"**

**Current pulse animation** (lines 1098-1116):
```lua
function trigger_pulse(col, row)
  pulse_timers[col][row] = 1.0
  pulse_brightness[col][row] = 15  -- Always full bright
end

function animate_pulses()
  while true do
    clock.sleep(1/60)
    for col=1,16 do
      for row=1,8 do
        if pulse_timers[col][row] > 0 then
          pulse_timers[col][row] = pulse_timers[col][row] - (1/60) / pulse_decay_time
          if pulse_timers[col][row] <= 0 then
            pulse_brightness[col][row] = 0
          else
            pulse_brightness[col][row] = math.floor(15 * pulse_timers[col][row])
          end
        end
      end
    end
  end
end
```

**New pulse animation** - Store pulse state separately:
```lua
-- Change pulse_brightness to pulse_active (boolean or 0-1 value)
local pulse_active = {}

function trigger_pulse(col, row)
  pulse_timers[col][row] = 1.0
  pulse_active[col][row] = 1.0
end

function animate_pulses()
  while true do
    clock.sleep(1/60)
    for col=1,16 do
      for row=1,8 do
        if pulse_timers[col][row] > 0 then
          pulse_timers[col][row] = pulse_timers[col][row] - (1/60) / pulse_decay_time
          if pulse_timers[col][row] <= 0 then
            pulse_active[col][row] = 0
          else
            pulse_active[col][row] = pulse_timers[col][row]  -- 0.0 to 1.0
          end
        end
      end
    end
  end
end
```

### Step 4: Apply Pulse to Drawing

**Sources** (lines 2179-2191):
```lua
for i, src in ipairs(SOURCES) do
  local value = source_values[src.name] or 0.5
  local base_brightness = math.floor(value * 13) + 2

  -- Apply pulse flash (brightens by ~50% during pulse)
  local brightness = base_brightness
  if pulse_active[src.col] and pulse_active[src.col][src.row] then
    local pulse_mult = 1.0 + (pulse_active[src.col][src.row] * 0.5)
    brightness = math.floor(base_brightness * pulse_mult)
    brightness = math.min(brightness, 15)  -- Cap at max
  end

  g:led(src.col, src.row, brightness)
end
```

**Register Outputs** (lines 2159-2176):
```lua
for i=1,8 do
  local base_brightness = math.floor(shift_reg_a[i] * 10) + 4
  if i > pattern_length_a then base_brightness = 2 end

  local brightness = base_brightness

  -- Only pulse if this stage has a source patch
  if has_source_patch('a', i-1) and pulse_active[REG_A_OUT] and pulse_active[REG_A_OUT][i] then
    local pulse_mult = 1.0 + (pulse_active[REG_A_OUT][i] * 0.5)
    brightness = math.floor(base_brightness * pulse_mult)
    brightness = math.min(brightness, 15)
  end

  g:led(REG_A_OUT, i, brightness)
  g:led(REG_A_IN, i, 4)
end
```

## Visual Effects

### Before (Current)
```
Sources:  [●]           [●]           [●]           (only random pulses)
          random        mid           max

Reg A:    [█] [█] [█] [█] [█] [█] [█] [█]          (all pulse full bright)
```

### After (Desired)
```
Sources:  [◐] [◑] [◐] [◑] [◐] [◑] [◐]              (all pulse at their brightness)
          rnd low mid high max p1  p2

Reg A:    [◐] [ ] [ ] [◑] [ ] [ ] [ ] [ ]          (only patched stages pulse)
          ^source      ^source                      (pulse at register brightness)
```

## Benefits

1. **Visual feedback for clock state**: Sources pulse when clock runs
2. **Shows source strength**: Pulse brightness reflects source value
3. **Shows injection points**: Only patched register stages pulse
4. **Less visual noise**: Unpатched stages don't pulse
5. **Better debugging**: Can see which stages are getting external values
6. **More intuitive**: Pulse = external activity, steady = internal shifting

## Implementation Order

1. ✅ Add `has_source_patch()` helper function
2. ✅ Change pulse system from "brightness override" to "pulse multiplier"
3. ✅ Add pulse triggering for all sources on clock step
4. ✅ Modify register output drawing to check for source patches
5. ✅ Modify source drawing to apply pulse multiplier
6. ✅ Test with various patch configurations
