# Random Source Animation Timing Fix

## Problem Statement

The random source value and pulse animation are currently tied to the clock stepping, so they only update when the clock is running. User wants tempo-based updates that run independently of clock state.

## Current Behavior

**Location**: [two_tangles.lua:1038-1046](two_tangles.lua#L1038-L1046)

```lua
-- Inside OSC callback for clock step (only runs when clock running)
if reg == 'a' then
  -- ... register A stepping logic ...

  -- Update random source on clock step
  source_values.random = math.random()
  -- Find random source position and trigger pulse
  for _, src in ipairs(SOURCES) do
    if src.name == "random" then
      trigger_pulse(src.col, src.row)
      break
    end
  end

elseif reg == 'b' then
  -- ... register B stepping logic ...
```

### What Happens

1. SuperCollider steps register A
2. Sends OSC message to Lua
3. Lua updates random source value
4. Triggers pulse animation
5. **Only happens when clock is running**

### Problems

❌ **No animation when clock stopped**: Can't see random source working
❌ **Tied to register A only**: B register stepping doesn't update random
❌ **Coupled to stepping**: Can't have different update rates
❌ **No independent control**: Random rate always matches clock rate

### Example Scenarios

**Scenario 1: Clock stopped for patching**
- Action: Stop clock, create patch with random source
- Expected: Random source still animating, showing it's "alive"
- Actual: Random source frozen at last value

**Scenario 2: Very slow tempo (30 BPM)**
- Action: Set tempo to 30 BPM, watch random source
- Expected: Random updates smoothly, maybe faster than clock
- Actual: Random only updates every 2 seconds (feels laggy)

**Scenario 3: Clock divisions active**
- Action: Clock A at /8 division (very slow), watch random
- Expected: Random updates at base tempo rate
- Actual: Random updates every 8 beats (way too slow)

## Desired Behavior

**Random source should:**
- ✅ Update at tempo-based rate (independent of clock state)
- ✅ Continue animating when clock is stopped
- ✅ Have consistent update rate regardless of divisions
- ✅ Rate changes with tempo parameter
- ✅ Visually shows "activity" even when not patched

## Solution

### Implementation: Independent Clock

Create a dedicated clock for random source updates:

```lua
-- Global variable for clock reference
local random_source_clock = nil

-- In init() function, start the random source clock
function init()
  -- ... existing init code ...

  -- Start random source animation clock
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

      -- Redraw grid to show new brightness
      grid_redraw()

      -- Wait based on tempo (choose rate below)
      local beat_time = 60 / tempo
      clock.sleep(beat_time * update_rate_multiplier)
    end
  end)

  -- ... rest of init ...
end

-- Don't forget to add to cleanup()
function cleanup()
  engine.stop()
  clock.cancel(animation_clock)
  clock.cancel(screen_refresh_clock)
  clock.cancel(random_source_clock)  -- NEW
end
```

### Update Rate Options

**Option 1: Every quarter note (beat)**
```lua
local beat_time = 60 / tempo
clock.sleep(beat_time)
```
- 120 BPM = update every 0.5 seconds
- Clear, musical timing
- Matches typical step rate

**Option 2: Every eighth note (half beat)**
```lua
local beat_time = 60 / tempo
clock.sleep(beat_time / 2)
```
- 120 BPM = update every 0.25 seconds
- More active/lively
- Good for visual feedback

**Option 3: Every sixteenth note (quarter beat)**
```lua
local beat_time = 60 / tempo
clock.sleep(beat_time / 4)
```
- 120 BPM = update every 0.125 seconds
- Very active, almost continuous
- Might be too fast

**Option 4: Fixed rate (not tempo-synced)**
```lua
clock.sleep(0.1)  -- 10 times per second
```
- Independent of tempo
- Consistent visual speed
- Less musical, more "indicator light"

**Recommendation**: Option 2 (eighth note) - active enough to show life, musical enough to feel intentional

### Alternative: Update on Any Clock Step

Instead of independent clock, update on both A and B steps:

```lua
-- In OSC callback
if reg == 'a' or reg == 'b' then  -- Update for either register
  -- Update random source
  source_values.random = math.random()
  for _, src in ipairs(SOURCES) do
    if src.name == "random" then
      trigger_pulse(src.col, src.row)
      break
    end
  end
end
```

**Pros**:
- Simpler (no new clock)
- Updates more frequently (both A and B)
- Still tied to musical timing

**Cons**:
- Still requires clock running
- Rate varies with divisions/mutes
- Doesn't solve the "stopped clock" use case

## Integration with Pulse Redesign

This fix integrates with the pulse animation redesign:

```lua
random_source_clock = clock.run(function()
  while true do
    -- Update random value
    source_values.random = math.random()

    -- Trigger pulse (new system uses pulse multiplier, not override)
    for _, src in ipairs(SOURCES) do
      if src.name == "random" then
        trigger_pulse(src.col, src.row)
        break
      end
    end

    grid_redraw()

    -- Tempo-based timing
    local beat_time = 60 / tempo
    clock.sleep(beat_time / 2)  -- Eighth note rate
  end
end)
```

When pulse redesign is implemented, the pulse will brighten the LED multiplicatively based on the random value, not override to full bright.

## Testing Scenarios

### Test 1: Clock Stopped
```
Action:
  1. Stop clock (grid button [13,8])
  2. Watch random source LED
Expected: Continues pulsing/changing brightness
Timing: Updates at tempo-based rate
```

### Test 2: Tempo Change
```
Action:
  1. Start random animation
  2. Change tempo from 60 to 180 BPM
Expected: Animation speeds up (3x faster)
Should: Feel responsive, not laggy
```

### Test 3: Clock Running vs Stopped
```
Action:
  1. Run clock, observe random source
  2. Stop clock, observe random source
Expected: No visual difference in random animation
Note: Register stepping stops, but random continues
```

### Test 4: Very Slow Tempo
```
Action: Set tempo to 30 BPM
Expected: Random updates every 1 second (at eighth note rate)
Should NOT: Feel frozen or too slow
```

### Test 5: Patch with Random
```
Setup: Patch random → A[0] with logic REPLACE
Action: Watch A[0] LED and random source LED
Expected:
  - Random source pulses continuously
  - A[0] only pulses when clock steps
Note: Different update rates for source vs destination
```

## Parameters to Consider

### Add User Parameter?

Could add a parameter for random update rate:

```lua
params:add_option("random_rate", "Random Update Rate",
  {"1/4 note", "1/8 note", "1/16 note", "Fixed 10Hz"},
  2  -- Default to 1/8 note
)
```

**Pros**: User control, flexibility
**Cons**: More complexity, UI clutter
**Decision**: Start without parameter, add if users request it

### Respect Global Mute?

Should random source animation stop when everything is muted?

```lua
random_source_clock = clock.run(function()
  while true do
    -- Only update if not globally muted (optional)
    if not global_mute then
      source_values.random = math.random()
      -- ... trigger pulse ...
    end

    local beat_time = 60 / tempo
    clock.sleep(beat_time / 2)
  end
end)
```

**Recommendation**: Keep animating even when muted (it's a visual indicator, not audio)

## Implementation Checklist

- [ ] Add `random_source_clock` variable
- [ ] Create clock.run function in init()
- [ ] Update `source_values.random` in clock
- [ ] Trigger pulse in clock
- [ ] Call grid_redraw() to show changes
- [ ] Choose update rate (recommend 1/8 note)
- [ ] Add clock.cancel in cleanup()
- [ ] Remove random update from stepShiftRegister OSC callback
- [ ] Test with clock stopped
- [ ] Test with various tempos
- [ ] Test pulse animation appears correct

## Files Modified

- [two_tangles.lua:1038-1046](two_tangles.lua#L1038-L1046) - Remove from OSC callback
- [two_tangles.lua:~790](two_tangles.lua#L790) - Add to init()
- [two_tangles.lua:2813-2817](two_tangles.lua#L2813-L2817) - Add to cleanup()

## Estimated Complexity

**Low** - Simple clock addition, ~20 lines of code

## Priority

**Medium** - Improves UX but not breaking current functionality

## Related Issues

- **Pulse Animation Redesign**: Random source pulsing behavior
- **Source LED Brightness Fix**: Random brightness display
- Both should be implemented together for consistent behavior
