# Source LED Brightness Fix

## Problem Statement

When a source is patched to a register stage, the source LED brightness is overridden by the patch weight value instead of maintaining the source's actual value-based brightness.

## Current Behavior

**Location**: [two_tangles.lua:2259-2264](two_tangles.lua#L2259-L2264)

```lua
if not (edit_mode and patch == selected_patch) then
  local src_brightness = weight_brightness  -- Line 2260: Uses patch weight!
  if not patch.is_source and pulse_brightness[src_col][src_row] > 0 then
    src_brightness = 15
  end
  g:led(src_col, src_row, src_brightness)
  g:led(dst_col, patch.dst_stage + 1, weight_brightness)
end
```

### What Happens

1. When drawing patches, line 2257 calculates `weight_brightness = math.floor(patch.weight * 8) + 4`
2. Line 2260 sets `src_brightness = weight_brightness` for ALL patches (including source patches)
3. Source LED shows patch weight (e.g., 0.8 weight = brightness ~10)
4. **Lost**: Source's actual value (e.g., random = 0.3 should show brightness ~6)

### Example Problems

**Scenario 1: Random source patched with weight 1.0**
- Expected: Random source LED varies 2-15 based on random value
- Actual: Random source LED fixed at brightness 12 (weight 1.0)
- Lost: Visual feedback of randomness

**Scenario 2: Mid source (0.5) patched with weight 0.3**
- Expected: Mid source LED steady at brightness ~9 (value 0.5)
- Actual: Mid source LED at brightness ~6 (weight 0.3)
- Lost: Source identity (looks dimmer than "mid")

**Scenario 3: Param1 adjusted from 0.2 to 0.9**
- Expected: Param1 LED brightens to show new value
- Actual: Param1 LED stays same (shows patch weight, not param value)
- Lost: Real-time parameter feedback

## Desired Behavior

**Source LEDs should always reflect their source value, regardless of patch weight.**

- Random source: Brightness varies with random value (2-15)
- Low source (0.25): Brightness ~5 (steady)
- Mid source (0.5): Brightness ~9 (steady)
- High source (0.75): Brightness ~12 (steady)
- Max source (1.0): Brightness ~15 (steady)
- Param sources: Brightness reflects current parameter value (dynamic)

**Patch weight should only affect:**
- Destination stage LED brightness
- Logic operator LED brightness
- How much the source affects the destination (in SuperCollider)

## Solution

### Option A: Simple Conditional (Recommended)

```lua
if not (edit_mode and patch == selected_patch) then
  local src_brightness = weight_brightness

  -- Override for source patches: use source value brightness
  if patch.is_source then
    local value = source_values[patch.src_reg] or 0.5
    src_brightness = math.floor(value * 13) + 2  -- Same formula as source display
  end

  -- Add pulse for register stages (sources handled separately)
  if not patch.is_source and pulse_brightness[src_col][src_row] > 0 then
    src_brightness = 15
  end

  g:led(src_col, src_row, src_brightness)
  g:led(dst_col, patch.dst_stage + 1, weight_brightness)
end
```

**Changes**:
- Lines 2-5: Check if patch is from source, use source value brightness
- Line 8: Only apply pulse override to register stages (not sources)

**Why this works**:
- Source patches: LED shows source value (correct!)
- Register patches: LED shows weight (patch strength visualization)
- Pulse animation: Only affects register stages

### Option B: Remove Source Drawing from Patch Loop

Sources are already drawn separately at lines 2179-2191. We could skip drawing source LEDs in the patch loop entirely:

```lua
if not (edit_mode and patch == selected_patch) then
  local src_brightness = weight_brightness

  if not patch.is_source and pulse_brightness[src_col][src_row] > 0 then
    src_brightness = 15
  end

  -- Only draw source LED if it's a register stage patch
  if not patch.is_source then
    g:led(src_col, src_row, src_brightness)
  end

  g:led(dst_col, patch.dst_stage + 1, weight_brightness)
end
```

**Why this works**:
- Sources drawn once at lines 2179-2191 (value-based brightness)
- Patches don't redraw sources (no override)
- Register patches still show weight properly

**Advantage**: Cleaner separation of concerns
**Disadvantage**: Sources won't show any patch-related visual feedback

## Testing Scenarios

### Test 1: Random Source Patched
```
Patch: random → A[0] (weight 1.0)
Action: Watch random source LED while clock runs
Expected: LED varies in brightness (2-15) matching random values
Should NOT: Stay fixed at brightness 12
```

### Test 2: Multiple Weights, Same Source
```
Patches:
  mid → A[0] (weight 1.0)
  mid → A[3] (weight 0.5)
  mid → A[6] (weight 0.2)

Action: Observe mid source LED
Expected: Steady brightness ~9 (mid = 0.5 value)
Should NOT: Flicker or average the weights
```

### Test 3: Parameter Change
```
Patch: param1 → A[2] (weight 0.8)
Action: Change param1 from 0.2 to 0.8
Expected: Param1 LED brightens from ~5 to ~12
Should NOT: Stay at brightness ~10 (weight 0.8)
```

### Test 4: Register Stage Patch (Control)
```
Patch: A[7] → B[0] (weight 0.6)
Action: Observe A[7] LED when it pulses
Expected: Pulses to full bright (15) as current behavior
Note: This should NOT change (register patches different from source patches)
```

## Implementation Checklist

- [ ] Add conditional check for `patch.is_source` in patch drawing loop
- [ ] Use `source_values[patch.src_reg]` to get source value
- [ ] Apply source brightness formula: `math.floor(value * 13) + 2`
- [ ] Ensure pulse override only applies to register stages
- [ ] Test with random source (should vary)
- [ ] Test with constant sources (should stay steady)
- [ ] Test with param sources (should respond to param changes)
- [ ] Test with register patches (should still show weight/pulse)

## Related Issues

This fix is closely related to:
- **Pulse Animation Redesign**: Both deal with source LED brightness
- **Random Source Timing**: Random source needs to update values for brightness to vary

Should be implemented together for consistent behavior.

## Files Modified

- [two_tangles.lua:2259-2264](two_tangles.lua#L2259-L2264) - Patch drawing loop

## Estimated Complexity

**Low** - Simple conditional change, ~5 lines of code

## Priority

**High** - Visual feedback is core to understanding the system
