# Source Relocation Changes - v0.2.2

## Summary

Sources have been relocated from a vertical column layout to a 3×3 grid layout with value-based LED brightness visualization and random source pulse animation.

## Layout Changes

### Old Layout
- **Location**: Column 4, Rows 1-7
- **Brightness**: Fixed brightness
- **Animation**: None

### New Layout
- **Location**: 3×3 grid, Columns 10-12, Rows 3-5
- **Brightness**: Dynamic, based on source values (0.0-1.0 → LED brightness 2-15)
- **Animation**: Random source pulses with clock and changes brightness randomly

## Grid Mapping

```
Row 3:  [random]  [low]     [mid]      (cols 10-12)
Row 4:  [high]    [max]     [param1]   (cols 10-12)
Row 5:  [param2]  [empty]   [empty]    (cols 10-12)
```

## Source Brightness Mapping

Each source LED brightness reflects its current value:

| Source  | Value Range | Behavior |
|---------|-------------|----------|
| random  | 0.0-1.0 (random) | Pulses with clock, random brightness |
| low     | 0.25 | Steady dim |
| mid     | 0.5 | Steady medium |
| high    | 0.75 | Steady bright |
| max     | 1.0 | Steady maximum |
| param1  | 0.0-1.0 (user control) | Steady, reflects param value |
| param2  | 0.0-1.0 (user control) | Steady, reflects param value |

Formula: `brightness = floor(value * 13) + 2` (range 2-15)

## Code Changes

### 1. SOURCES Table (lines 74-82)
Changed from single column index to col/row pairs:
```lua
local SOURCES = {
  {name = "random", col = 10, row = 3},
  {name = "low", col = 11, row = 3},
  {name = "mid", col = 12, row = 3},
  {name = "high", col = 10, row = 4},
  {name = "max", col = 11, row = 4},
  {name = "param1", col = 12, row = 4},
  {name = "param2", col = 10, row = 5}
}
```

### 2. source_values Table (lines 85-93)
Added to track current values for LED brightness:
```lua
local source_values = {
  random = 0.5,
  low = 0.25,
  mid = 0.5,
  high = 0.75,
  max = 1.0,
  param1 = 0.5,
  param2 = 0.5
}
```

### 3. Grid Key Handler (lines ~1570-1595)
Updated source detection to check new grid positions:
```lua
-- Check for source selection in 3x3 grid
for i, src in ipairs(SOURCES) do
  if x == src.col and y == src.row then
    -- Handle source selection
  end
end
```

### 4. Random Source Update (lines 1038-1046)
On each clock step:
```lua
-- Update random source value and trigger pulse
source_values.random = math.random()
for _, src in ipairs(SOURCES) do
  if src.name == "random" then
    trigger_pulse(src.col, src.row)
    break
  end
end
```

### 5. Grid Drawing (lines 2179-2191)
Sources drawn with value-based brightness:
```lua
for i, src in ipairs(SOURCES) do
  local value = source_values[src.name] or 0.5
  local brightness = math.floor(value * 13) + 2

  -- Random source uses pulse animation
  if src.name == "random" and pulse_brightness[src.col] and pulse_brightness[src.col][src.row] then
    brightness = pulse_brightness[src.col][src.row]
  end

  g:led(src.col, src.row, brightness)
end
```

### 6. Patch Highlighting (lines 2233-2247)
Updated to find source position in 3×3 grid:
```lua
if patch_source.source then
  for _, src in ipairs(SOURCES) do
    if src.name == patch_source.source then
      g:led(src.col, src.row, 15)
      break
    end
  end
end
```

### 7. Patch Drawing (lines 2249-2263 and 2295-2309)
Two loops updated to find source col/row in 3×3 grid:
```lua
if patch.is_source then
  for _, src in ipairs(SOURCES) do
    if src.name == patch.src_reg then
      src_col = src.col
      src_row = src.row
      break
    end
  end
end
```

### 8. Patch Completion (lines 1652-1660)
Triggers pulse at source position after patch:
```lua
for _, src in ipairs(SOURCES) do
  if src.name == source_name then
    trigger_pulse(src.col, src.row)
    break
  end
end
```

### 9. Parameter Actions (lines ~444, ~456)
Update source_values when params change:
```lua
action = function(v)
  source_values.param1 = v
  engine.set_source("param1", v)
  grid_redraw()
end
```

## Removed

- `SOURCE_COL` constant (no longer needed)
- All references to column-based source indexing

## Testing

Use `source_test.lua` to verify:
1. Sources appear in 3×3 grid at columns 10-12, rows 3-5
2. Random source pulses brightly with clock
3. Random source brightness changes with each pulse
4. Other sources maintain steady brightness based on values
5. Param1/Param2 brightness updates when values change

## Visual Feedback

- **Random source**: Bright pulsing LED that changes brightness randomly (simulates random injection)
- **Constant sources** (low/mid/high/max): Steady brightness indicating their fixed values
- **User params**: Brightness reflects current parameter value, updates in real-time

## User Experience

The new layout:
- ✓ Groups sources together spatially
- ✓ Provides visual feedback of source strengths
- ✓ Makes random source activity visible through pulsing
- ✓ Frees up column 4 for future features
- ✓ Creates more intuitive source selection area
