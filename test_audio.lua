-- test_audio.lua
-- Quick audio test for Two Tangles engine

engine.name = "TwoTangles"

function init()
  print("=== TWO TANGLES AUDIO TEST ===")

  -- Wait for engine to load
  clock.run(function()
    clock.sleep(1)

    print("Step 1: Setting unpatched behavior to random...")
    engine.unpatched_mode(1)  -- 1 = random (not 0 = hold zero)

    clock.sleep(0.1)

    print("Step 2: Creating feedback patch A0 -> A0...")
    engine.add_patch('a', 0, 'a', 0, 0, 1.0)

    print("Step 3: Creating gate patch A2 -> A2...")
    engine.add_patch('a', 2, 'a', 2, 0, 1.0)

    print("Step 4: Randomizing register A...")
    engine.randomize('a')

    clock.sleep(0.5)

    print("Step 5: Starting clock...")
    engine.start()

    clock.sleep(2)

    print("Step 6: Manually stepping register A...")
    for i = 1, 4 do
      engine.step('a')
      clock.sleep(0.5)
    end

    print("=== TEST COMPLETE ===")
    print("You should hear audio now.")
    print("If not, check SuperCollider logs for errors.")
  end)
end

function key(n, z)
  if n == 3 and z == 1 then
    print("Manual step A")
    engine.step('a')
  end
end

function redraw()
  screen.clear()
  screen.move(10, 30)
  screen.text("Audio Test Running")
  screen.move(10, 45)
  screen.text("Press K3 to manually step")
  screen.update()
end
