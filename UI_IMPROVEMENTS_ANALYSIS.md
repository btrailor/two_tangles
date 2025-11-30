# UI Improvements Analysis

## Issue 1: Patch Visualization on Norns Screen

### Current State

**Page 1 (Main)** shows limited patch information (lines 2434-2456):

```lua
if edit_mode and selected_patch then
  screen.text("EDIT: " .. selected_patch.src_reg .. "[" .. selected_patch.src_stage .. "] -> " ..
              selected_patch.dst_reg .. "[" .. selected_patch.dst_stage .. "]")
  screen.move(0, 85)
  screen.level(10)
  screen.text(get_logic_name(selected_patch.logic) ..
              " w:" .. string.format("%.2f", selected_patch.weight))
elseif patch_mode and patch_source then
  -- Shows source being patched and current settings
  screen.text("PATCH: " .. patch_source.source:upper())
  screen.move(0, 85)
  screen.level(10)
  screen.text(get_logic_name(selected_logic) ..
              " w:" .. string.format("%.2f", patch_weight))
else
  screen.text("Patches: " .. #patches)  -- Just count!
end
```

**Problems**:
- ❌ Only shows currently editing/creating patch
- ❌ No way to see list of all active patches
- ❌ Just shows count when not editing: "Patches: 5"
- ❌ Can't see logic operators for existing patches
- ❌ No overview of patch connections

### Proposed Solution

**Add Page 6: Patch List**

Display scrollable list of all active patches with details:

```
TWO TANGLES - PATCHES (5)

> random → A[0] REPLACE w:1.0
  B[2] → A[3] AND w:0.8
  mid → B[1] OR w:0.5
  A[7] → B[0] XOR w:0.6
  max → A[2] REPLACE w:1.0

E2:scroll E3:select K3:delete
```

Features:
- Show all patches with source→destination
- Display logic operator name
- Display weight value
- Scroll through list (E2)
- Select patch for editing (E3)
- Delete selected patch (K3)
- Visual indicator for selected patch (>)

### Alternative: Improve Page 1

Keep patches on Page 1 but show more info:

```
TWO TANGLES            120 BPM
▶ A:4 ⬛ B:4

Patches (5):
• rnd→A0 REPL 1.0
• B2→A3 AND 0.8
• mid→B1 OR 0.5
...

E2:logic E3:weight
```

## Issue 2: Source LED Brightness Override

### Current Problem

**Location**: lines 2259-2264

```lua
if not (edit_mode and patch == selected_patch) then
  local src_brightness = weight_brightness  -- Uses patch weight!
  if not patch.is_source and pulse_brightness[src_col][src_row] > 0 then
    src_brightness = 15
  end
  g:led(src_col, src_row, src_brightness)
  g:led(dst_col, patch.dst_stage + 1, weight_brightness)
end
```

**Problem**: When a source is patched, line 2260 sets `src_brightness = weight_brightness`, which is based on the **patch weight** (0.0-1.0), not the **source value** (0.0-1.0).

**Result**:
- Source LED shows patch weight instead of source value
- Loses visual feedback of source strength
- User expects: random source LED varies with random value
- User gets: random source LED fixed at patch weight brightness

### Solution

For source patches, use source value brightness instead of weight brightness:

```lua
if not (edit_mode and patch == selected_patch) then
  local src_brightness = weight_brightness

  -- Override for source patches: use source value brightness
  if patch.is_source then
    local value = source_values[patch.src_reg] or 0.5
    src_brightness = math.floor(value * 13) + 2
  end

  -- Add pulse for register stages
  if not patch.is_source and pulse_brightness[src_col][src_row] > 0 then
    src_brightness = 15
  end

  g:led(src_col, src_row, src_brightness)
  g:led(dst_col, patch.dst_stage + 1, weight_brightness)
end
```

**Result**:
- ✅ Source LEDs maintain value-based brightness even when patched
- ✅ Random source LED varies with random value
- ✅ Constant sources (low/mid/high/max) show steady appropriate brightness
- ✅ Param sources reflect current parameter values
- ✅ Register stage sources still show pulse animation

## Issue 3: Random Source Animation Timing

### Current Problem

**Location**: lines 1038-1046

```lua
-- Inside stepShiftRegister callback (only runs when clock steps)
if reg == 'a' then
  -- ... register A stepping ...

  -- Update random source on clock step
  source_values.random = math.random()
  -- Find random source position and trigger pulse
  for _, src in ipairs(SOURCES) do
    if src.name == "random" then
      trigger_pulse(src.col, src.row)
      break
    end
  end
```

**Problems**:
- ❌ Only updates when clock is stepping
- ❌ No animation when clock is stopped
- ❌ Tied to register A clock only
- ❌ User wants: tempo-based updates regardless of clock state

### Solution

Create independent clock for random source updates:

```lua
-- In init() section, add new clock:
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

    grid_redraw()

    -- Wait based on tempo (but independent of clock running state)
    -- Example: update at 1/4 note rate
    local beat_time = 60 / tempo
    clock.sleep(beat_time)
  end
end)
```

**Features**:
- ✅ Updates at tempo-based rate
- ✅ Works even when clock is stopped
- ✅ Independent of register stepping
- ✅ Still pulses/animates
- ✅ Rate changes with tempo parameter

**Alternative rates**:
- Every beat: `clock.sleep(60 / tempo)`
- Every 1/2 beat: `clock.sleep(60 / tempo / 2)`
- Every 1/4 beat: `clock.sleep(60 / tempo / 4)`
- Every bar: `clock.sleep(60 / tempo * 4)`

User preference: Which rate makes most sense?

## Implementation Priority

### Quick Fixes (15-30 min each)
1. **Fix source LED brightness** - Simple conditional change
2. **Fix random source timing** - Add independent clock

### Medium Tasks (1-2 hours)
3. **Add Patch List page** - New page with scrollable list
4. **Improve Page 1 display** - Better compact patch view

## Summary

| Issue | Location | Severity | Fix Complexity |
|-------|----------|----------|----------------|
| Source LED brightness override | line 2260 | Medium | Low - simple conditional |
| Random source clock coupling | line 1038 | Medium | Low - add independent clock |
| Patch visualization missing | line 2455 | High | Medium - new page needed |
| Page 1 patch display limited | lines 2434-2456 | Medium | Medium - redesign display |

## Questions for User

1. **Patch visualization**: Prefer dedicated Page 6, or improve Page 1?
2. **Random source rate**: How fast should it update? (every beat, 1/4 beat, etc.)
3. **Patch list features**: What info is most important? (logic, weight, source names?)
