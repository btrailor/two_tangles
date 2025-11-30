# Patch Visualization Design

## Problem Statement

Currently there is no reliable way to see all active patches and their logic operators on the Norns screen. Users need a comprehensive view of the patch matrix to understand the system state.

## Current State

**Page 1 (Main)** - Lines 2434-2456

Shows only:
- Currently editing patch (when in edit mode)
- Currently creating patch (when in patch mode)
- **Total patch count** when idle: "Patches: 5"

**Missing**:
- ❌ List of all active patches
- ❌ Source and destination for each patch
- ❌ Logic operator for each patch
- ❌ Weight for each patch
- ❌ Way to review/edit existing patches
- ❌ Way to delete specific patches

## Design Options

### Option A: New Page 6 - Patch List (Recommended)

Create dedicated page for patch management:

```
╔════════════════════════════════╗
║ PATCH LIST (5)           Page 6║
║                                 ║
║ > random → A[0] REPLACE w:1.0  ║
║   B[2] → A[3] AND w:0.8        ║
║   mid → B[1] OR w:0.5          ║
║   A[7] → B[0] XOR w:0.6        ║
║   max → A[2] REPLACE w:1.0     ║
║                                 ║
║ E1:page E2:scroll E3:select    ║
║ K2:edit K3:delete              ║
╚════════════════════════════════╝
```

**Features**:
- Scrollable list (E2)
- Select patch (E3 or arrow cursor)
- Edit selected patch (K2) - enter edit mode
- Delete selected patch (K3)
- Shows all patch details on one screen
- Cursor/highlight for selected patch

### Option B: Improved Page 1

Add compact patch list to main page:

```
╔════════════════════════════════╗
║ TWO TANGLES            120 BPM ║
║ ▶ A:4 ⬛ B:4                    ║
║                                 ║
║ Register A: [████▄▄▄▄]         ║
║ Register B: [▄▄██████]         ║
║                                 ║
║ Patches (5):                    ║
║ • rnd→A0 REP 1.0                ║
║ • B2→A3 AND 0.8                 ║
║ • mid→B1 OR 0.5 ...             ║
║                                 ║
║ E1:page E2:logic E3:weight     ║
╚════════════════════════════════╝
```

**Pros**: Everything on main page
**Cons**: Less space, limited to ~3 patches visible

### Option C: Tabbed/Paged Patch View

Page 6 with multiple "tabs" for different views:

**Tab 1: List View**
```
PATCHES - LIST (5)        [1/2]

> random → A[0] REPLACE w:1.0
  B[2] → A[3] AND w:0.8
  mid → B[1] OR w:0.5
  A[7] → B[0] XOR w:0.6

E2:scroll E3:next-page K3:del
```

**Tab 2: Detail View**
```
PATCHES - DETAIL          [2/2]

Selected: random → A[0]

Logic: REPLACE
Weight: 1.0
Source: random (0.53)
Dest: Register A, Stage 0

E2:prev E3:edit K2:copy K3:del
```

**Pros**: Maximum information density
**Cons**: More complex navigation

## Recommended Implementation: Option A

Simple, focused page with essential features.

## Detailed Design - Page 6

### Data Structures

```lua
-- Patch list state
local patch_list_scroll = 0  -- Top visible patch index
local patch_list_selected = 1  -- Currently selected patch (1-indexed)
local patch_list_visible = 4  -- Number of patches visible at once
```

### Drawing Function

```lua
function draw_patch_list_page()
  screen.clear()
  screen.level(15)

  -- Header
  screen.move(0, 10)
  screen.text("PATCH LIST (" .. #patches .. ")")

  if #patches == 0 then
    screen.move(0, 30)
    screen.level(8)
    screen.text("No patches")
    screen.move(0, 40)
    screen.text("Create patch on grid:")
    screen.move(0, 50)
    screen.text("Press source, then dest")
    screen.update()
    return
  end

  -- Calculate visible range
  local top = patch_list_scroll + 1
  local bottom = math.min(top + patch_list_visible - 1, #patches)

  -- Draw patches
  for i = top, bottom do
    local patch = patches[i]
    local y = 20 + ((i - top) * 15)

    -- Selection cursor
    if i == patch_list_selected then
      screen.level(15)
      screen.move(0, y)
      screen.text(">")
    end

    -- Patch info
    screen.move(10, y)

    -- Source
    local src_text
    if patch.is_source then
      src_text = patch.src_reg  -- "random", "mid", etc.
    else
      src_text = patch.src_reg .. "[" .. patch.src_stage .. "]"
    end

    -- Destination
    local dst_text = patch.dst_reg .. "[" .. patch.dst_stage .. "]"

    -- Logic (abbreviated)
    local logic_text = get_logic_short_name(patch.logic)

    -- Weight
    local weight_text = string.format("%.1f", patch.weight)

    -- Combine
    local brightness = (i == patch_list_selected) and 15 or 10
    screen.level(brightness)

    -- Format: "src → dst LOGIC w:0.8"
    local line = src_text .. " → " .. dst_text .. " " .. logic_text .. " w:" .. weight_text
    screen.text(line)
  end

  -- Scroll indicator
  if #patches > patch_list_visible then
    screen.level(5)
    screen.move(118, 30)
    screen.text(patch_list_selected .. "/" .. #patches)
  end

  -- Help text
  screen.level(5)
  screen.move(0, 100)
  screen.text("E1:page E2:scroll E3:select")
  screen.move(0, 110)
  screen.text("K2:edit K3:delete")

  screen.update()
end
```

### Helper Function - Abbreviated Logic Names

```lua
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
```

### Encoder Handlers

```lua
-- In enc() function
elseif current_page == 6 then
  if n == 1 then
    -- E1: Page navigation (global)
    current_page = util.clamp(current_page + d, 1, #PAGES)
    print("Page: " .. PAGES[current_page])
    redraw()

  elseif n == 2 then
    -- E2: Scroll through patch list
    if #patches > 0 then
      patch_list_selected = util.clamp(patch_list_selected + d, 1, #patches)

      -- Auto-scroll to keep selection visible
      if patch_list_selected < (patch_list_scroll + 1) then
        patch_list_scroll = patch_list_selected - 1
      elseif patch_list_selected > (patch_list_scroll + patch_list_visible) then
        patch_list_scroll = patch_list_selected - patch_list_visible
      end

      redraw()
    end

  elseif n == 3 then
    -- E3: Adjust weight of selected patch
    if #patches > 0 and patch_list_selected <= #patches then
      local patch = patches[patch_list_selected]
      patch.weight = util.clamp(patch.weight + (d * 0.05), 0.0, 1.0)

      -- Update engine
      engine.patch_weight(
        patch.src_reg,
        patch.src_stage or 0,  -- Sources don't have stage
        patch.dst_reg,
        patch.dst_stage,
        patch.weight
      )

      redraw()
    end
  end
end
```

### Key Handlers

```lua
-- In key() function, Page 6 section
elseif current_page == 6 then
  if n == 2 and z == 1 then
    -- K2: Edit selected patch
    if #patches > 0 and patch_list_selected <= #patches then
      selected_patch = patches[patch_list_selected]
      edit_mode = true
      patch_weight = selected_patch.weight
      selected_logic = selected_patch.logic
      current_page = 1  -- Jump to main page for editing
      print("Editing patch: " .. patch_list_selected)
      grid_redraw()
      redraw()
    end

  elseif n == 3 and z == 1 then
    -- K3: Delete selected patch
    if #patches > 0 and patch_list_selected <= #patches then
      local patch = patches[patch_list_selected]

      -- Confirm deletion (simple version)
      print("Deleting patch: " .. patch_list_selected)

      -- Delete from engine
      if patch.is_source then
        engine.remove_patch(patch.src_reg, 0, patch.dst_reg, patch.dst_stage)
      else
        engine.remove_patch(patch.src_reg, patch.src_stage, patch.dst_reg, patch.dst_stage)
      end

      -- Delete from Lua table
      table.remove(patches, patch_list_selected)

      -- Adjust selection
      if patch_list_selected > #patches then
        patch_list_selected = #patches
      end
      if patch_list_selected < 1 then
        patch_list_selected = 1
      end

      grid_redraw()
      redraw()
    end
  end
end
```

## Enhanced Features

### Feature 1: Filter by Register

Show only patches for a specific register:

```lua
local patch_filter = "all"  -- "all", "a", "b"

-- In drawing
screen.move(90, 10)
screen.text("[" .. patch_filter:upper() .. "]")

-- Filter patches
local visible_patches = {}
for _, patch in ipairs(patches) do
  if patch_filter == "all" or
     patch.src_reg == patch_filter or
     patch.dst_reg == patch_filter then
    table.insert(visible_patches, patch)
  end
end
```

### Feature 2: Sort Options

```lua
local patch_sort = "creation"  -- "creation", "source", "destination", "weight"

-- Sort function
local function sort_patches(mode)
  if mode == "source" then
    table.sort(patches, function(a, b)
      return (a.src_reg .. a.src_stage) < (b.src_reg .. b.src_stage)
    end)
  elseif mode == "destination" then
    table.sort(patches, function(a, b)
      return (a.dst_reg .. a.dst_stage) < (b.dst_reg .. b.dst_stage)
    end)
  elseif mode == "weight" then
    table.sort(patches, function(a, b)
      return a.weight > b.weight
    end)
  end
end
```

### Feature 3: Copy Patch

```lua
-- K2+K3: Copy selected patch to clipboard
local patch_clipboard = nil

if n == 2 and z == 1 and key3_held then
  patch_clipboard = util.copy(patches[patch_list_selected])
  print("Patch copied")
end

-- K3+K2: Paste patch from clipboard
if n == 3 and z == 1 and key2_held then
  if patch_clipboard then
    -- Create new patch with same parameters but different destination
    -- (Would need UI to select new destination)
    print("Paste not yet implemented")
  end
end
```

### Feature 4: Patch Info Detail View

Press K3 on selected patch to see detailed info:

```
╔════════════════════════════════╗
║ PATCH DETAIL                    ║
║                                 ║
║ random → A[0]                   ║
║                                 ║
║ Logic: REPLACE                  ║
║ Weight: 1.00                    ║
║                                 ║
║ Source Info:                    ║
║   Type: External source         ║
║   Value: 0.53 (current)         ║
║                                 ║
║ Dest Info:                      ║
║   Register: A, Stage: 0         ║
║   Current: 0.72                 ║
║                                 ║
║ K2:back K3:delete               ║
╚════════════════════════════════╝
```

## Update PAGES Table

```lua
local PAGES = {
  "Main",
  "Clock",
  "Performance",
  "Audio Input",
  "Voice Mod",
  "Patches"  -- NEW
}
```

## Integration with Grid

### ALT Mode Quick Jump

```lua
-- In grid ALT mode (lines 1128-1145)
if y == 1 and x >= 1 and x <= 6 then  -- Extended to column 6
  current_page = x
  print("Page: " .. PAGES[current_page])
  grid_redraw()
  redraw()
  return
end
```

## Testing Scenarios

### Test 1: Empty State
```
Action: Navigate to Page 6 with no patches
Expected: Shows "No patches" message with help text
```

### Test 2: Scroll Through Patches
```
Setup: Create 10 patches
Action: Turn E2 to scroll through list
Expected:
  - Cursor moves through patches
  - List scrolls when cursor reaches edge
  - Shows "N/10" indicator
```

### Test 3: Edit Patch
```
Setup: Navigate to patch #3 in list
Action: Press K2 (edit)
Expected:
  - Switches to Page 1
  - Enters edit mode
  - Patch #3 is highlighted on grid
  - Can adjust logic/weight with E2/E3
```

### Test 4: Delete Patch
```
Setup: Select patch #2
Action: Press K3 (delete)
Expected:
  - Patch removed from list
  - Patch removed from grid
  - Engine updated
  - Selection moves to next patch
```

### Test 5: Adjust Weight
```
Setup: Select a patch
Action: Turn E3
Expected:
  - Weight value updates in real-time
  - Engine receives new weight
  - Can hear difference in modulation
```

## Implementation Checklist

### Lua Changes
- [ ] Add patch_list_scroll variable
- [ ] Add patch_list_selected variable
- [ ] Add patch_list_visible constant
- [ ] Create draw_patch_list_page() function
- [ ] Create get_logic_short_name() helper
- [ ] Add Page 6 encoder handlers
- [ ] Add Page 6 key handlers
- [ ] Update PAGES table
- [ ] Update ALT mode for Page 6 jump
- [ ] Add to main redraw() dispatcher
- [ ] Test all interactions

### Optional Enhancements
- [ ] Add filter by register
- [ ] Add sort options
- [ ] Add patch copy/paste
- [ ] Add detailed info view
- [ ] Add batch delete (clear all)

## Files Modified

- [two_tangles.lua](two_tangles.lua) - Add Page 6 and all handlers
- [README.md](README.md) - Document new page

## Estimated Complexity

**Medium** - ~200 lines of code for full implementation

## Priority

**High** - Core feature for understanding system state

## Alternative: Multi-Page Approach

If 4 visible patches isn't enough, use pagination:

```
PATCHES (12)             [Page 1/3]

> random → A[0] REPLACE w:1.0
  B[2] → A[3] AND w:0.8
  mid → B[1] OR w:0.5
  A[7] → B[0] XOR w:0.6

E2:scroll E3:page K2:edit K3:del
```

Pros: Shows exactly 4 patches per screen
Cons: More button presses to see all patches
