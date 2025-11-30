-- source_test.lua
-- Test script for new 3x3 source layout with brightness visualization

engine.name = "TwoTangles"

local step_count = 0

function osc.event(path, args, from)
  if path == "/tt_state" then
    step_count = step_count + 1
    redraw()
  end
end

function init()
  print("\n========================================")
  print("TWO TANGLES SOURCE LAYOUT TEST")
  print("========================================\n")

  clock.run(function()
    print("Waiting for engine...")
    clock.sleep(2)

    print("\n--- Setting up sources ---")
    print("Sources now in 3x3 grid:")
    print("  Columns 10-12, Rows 3-5")
    print("  LED brightness = source value")
    print("")

    engine.unpatched_mode(1)  -- Random for unpatched stages
    clock.sleep(0.1)

    print("\n--- Creating test patches ---")
    print("Random source -> A0 (should pulse with clock)")
    engine.add_patch('a', 0, 'a', 0, 0, 1.0)  -- A0 feedback

    print("Mid source -> A1")
    engine.add_patch('a', 1, 'a', 1, 0, 1.0)  -- A1 feedback

    print("High source -> A2 (gate stage)")
    engine.add_patch('a', 2, 'a', 2, 0, 1.0)  -- A2 feedback (gate)

    print("Max source -> A3 (filter stage)")
    engine.add_patch('a', 3, 'a', 3, 0, 1.0)  -- A3 feedback (filter)

    clock.sleep(0.1)

    print("\n--- Starting clock ---")
    print("Watch the random source pulse!")
    engine.start()

    print("\n========================================")
    print("Look at grid columns 10-12, rows 3-5")
    print("Random source should pulse brightly")
    print("Other sources show steady brightness")
    print("")
    print("K2: Change param1 (affects brightness)")
    print("K3: Change param2 (affects brightness)")
    print("========================================\n")
  end)
end

function key(n, z)
  if z == 1 then
    if n == 2 then
      -- Randomize param1
      local val = math.random()
      params:set("param1", val)
      print("param1 = " .. string.format("%.2f", val))
    elseif n == 3 then
      -- Randomize param2
      local val = math.random()
      params:set("param2", val)
      print("param2 = " .. string.format("%.2f", val))
    end
  end
end

function redraw()
  screen.clear()
  screen.level(15)

  screen.move(10, 20)
  screen.text("Source Layout Test")

  screen.move(10, 35)
  screen.text("Grid [10-12, 3-5]")

  screen.move(10, 50)
  screen.text("Steps: " .. step_count)

  screen.move(10, 65)
  screen.text("K2/K3: Change params")

  screen.update()
end
