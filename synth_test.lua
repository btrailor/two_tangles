-- synth_test.lua
-- Direct synth test - bypass all the register logic

engine.name = "TwoTangles"

function init()
  print("\n=== DIRECT SYNTH TEST ===\n")
  print("This tests the synths directly, bypassing registers\n")

  -- Wait a moment
  clock.run(function()
    clock.sleep(2)
    print("Press K3 to trigger a test tone")
  end)
end

function key(n, z)
  if z == 1 then
    if n == 2 then
      print("\n--- SIMPLE TEST (creates new synth) ---")
      engine.test_simple()
      print("This creates a basic sine tone")
      print("If you don't hear this, check norns audio output!")

    elseif n == 3 then
      print("\n--- VOICE TEST (uses existing voice) ---")
      engine.test_note()
      print("This tests the ttVoice synth")
      print("Check SuperCollider tab for status")
    end
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(10, 20)
  screen.text("SYNTH TEST")
  screen.move(10, 40)
  screen.text("K2: Simple test")
  screen.move(10, 50)
  screen.level(8)
  screen.text("(creates new synth)")
  screen.move(10, 70)
  screen.level(15)
  screen.text("K3: Voice test")
  screen.move(10, 80)
  screen.level(8)
  screen.text("(tests ttVoice)")
  screen.update()
end
