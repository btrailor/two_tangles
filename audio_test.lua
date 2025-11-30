-- audio_test.lua
-- Proper audio test with all necessary patches

engine.name = "TwoTangles"

function init()
  print("\n=== TWO TANGLES AUDIO TEST ===\n")

  clock.run(function()
    print("Waiting for engine...")
    clock.sleep(2)

    print("Setting unpatched mode to RANDOM...")
    engine.unpatched_mode(1)
    clock.sleep(0.1)

    print("\nCreating patches for Register A:")
    print("  A0 -> A0 (Pitch)")
    engine.add_patch('a', 0, 'a', 0, 0, 1.0)

    print("  A1 -> A1 (Harmony)")
    engine.add_patch('a', 1, 'a', 1, 0, 1.0)

    print("  A2 -> A2 (Gate) ***CRITICAL***")
    engine.add_patch('a', 2, 'a', 2, 0, 1.0)

    print("  A3 -> A3 (Filter) ***CRITICAL***")
    engine.add_patch('a', 3, 'a', 3, 0, 1.0)

    clock.sleep(0.1)

    print("\n*** You should hear audio now! ***")
    print("Starting clock...")
    engine.start()

    clock.sleep(2)

    print("\nIf you hear audio: SUCCESS!")
    print("If not: Check AUDIO > LEVELS on norns")
    print("\nK3 = Manual step for testing")
  end)
end

function key(n, z)
  if z == 1 then
    if n == 2 then
      print("Randomizing A")
      engine.randomize('a')
    elseif n == 3 then
      print("Manual step")
      engine.step('a')
    end
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(10, 30)
  screen.text("AUDIO TEST")
  screen.move(10, 50)
  screen.text("Listen for sound...")
  screen.move(10, 70)
  screen.text("K2: Randomize")
  screen.move(10, 80)
  screen.text("K3: Manual step")
  screen.update()
end
