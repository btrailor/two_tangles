-- debug_test.lua
-- Minimal test to diagnose Two Tangles issues

engine.name = "TwoTangles"

local step_count = 0

function osc.event(path, args, from)
  print(">>> OSC: " .. path)
  if path == "/tt_state" then
    print(">>> Register stepped! Args count: " .. #args)
    step_count = step_count + 1
    redraw()
  end
end

function init()
  print("\n========================================")
  print("TWO TANGLES DEBUG TEST")
  print("========================================\n")

  clock.run(function()
    print("Waiting for engine...")
    clock.sleep(2)

    print("\n--- Test 1: Setting unpatched mode to RANDOM ---")
    engine.unpatched_mode(1)  -- Random input for unpatched stages
    clock.sleep(0.1)

    print("\n--- Test 2: Creating patches ---")
    print("Creating: A0 -> A0")
    engine.add_patch('a', 0, 'a', 0, 0, 1.0)

    print("Creating: A1 -> A1")
    engine.add_patch('a', 1, 'a', 1, 0, 1.0)

    print("Creating: A2 -> A2 (GATE stage!)")
    engine.add_patch('a', 2, 'a', 2, 0, 1.0)

    print("Creating: A3 -> A3 (FILTER stage!)")
    engine.add_patch('a', 3, 'a', 3, 0, 1.0)
    clock.sleep(0.1)

    print("\n--- Test 3: Starting clock ---")
    engine.start()
    clock.sleep(0.5)

    print("\n--- Test 4: Manually stepping 5 times ---")
    for i = 1, 5 do
      print("Manual step " .. i)
      engine.step('a')
      clock.sleep(0.5)
    end

    print("\n========================================")
    print("TEST COMPLETE")
    print("Step count: " .. step_count)
    if step_count == 0 then
      print("ERROR: No OSC messages received!")
      print("Check SuperCollider logs for errors.")
    else
      print("SUCCESS: OSC working!")
      print("If no audio, check mixer levels.")
    end
    print("========================================\n")
  end)
end

function key(n, z)
  if z == 1 then
    if n == 2 then
      print("Stopping clock")
      engine.stop()
    elseif n == 3 then
      print("Manual step")
      engine.step('a')
    end
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(10, 20)
  screen.text("Debug Test")
  screen.move(10, 40)
  screen.text("Steps received: " .. step_count)
  screen.move(10, 60)
  screen.text("K2: Stop  K3: Step")
  screen.update()
end
