dbg = require('lib.debugger')

-- main events -----------------------------------------------------------------

function require_all(dir)
  for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
    if string.find(file, "%.lua$") then
      require(dir .. '.' .. string.gsub(file, '%.lua$', ''))
    end
  end
end

function love.load(arg)
  table.remove(arg, 1) -- remove love directory argument

  -- libraries
  serpent = require('lib.serpent')
  require('socket') -- for uuid
  uuid = require('lib.uuid')
  uuid.seed()
  md5 = require('lib.md5')
  require('lib.doc')
  require('lib.scratch')
  require('lib.recipe')
  require('lib.vec2')
  require('lib.entity')

  -- load boot methods
  bootstrap = recipe.new('bootstrap')
  require_all('boot')

  -- bootstrap entire system? create boot image and exit
  if arg[1] == '--bootstrap' then
    assert(arg[2], 'no image file specified...')
    bootstrap:run(arg[2])
    love.event.push('quit')
    return
  end

  -- load boot image
  local boot_image = 'boot/boot.pgame'
  if arg[1] == '--boot' then
    assert(arg[2], 'no image file specified...')
    boot_image = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
  end
  entity.load_file(boot_image)

  -- register input events
  if entities.inputting then
    entities.inputting:register_events('keypressed', 'keyreleased',
                                       'mousepressed', 'mousereleased',
                                       'joystickpressed', 'joystickreleased')
  end

  -- load game methods and game images
  if arg[1] then require_all(arg[1]) end
  for i = 2, #arg do entity.load_file(arg[i]) end
end

main_skip_next_frame = false -- to avoid dt spikes
function love.update(dt)
  scratch.update() -- don't skip scratch updates
  if main_skip_next_frame then
    main_skip_next_frame = false
    return
  end

  if entities.updating then entities.updating:update_rsubs(dt) end
  if entities.entity then entities.entity:cleanup() end
end

function love.draw()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS()), 10, 10)
  if entities.drawing then
    entities.drawing:draw_rsubs(entities.main_camera)
  end
end


-- run -------------------------------------------------------------------------

local function safe_call(f)
  local succ, err = dbg.call(f)
  if not succ then
    -- avoid dt spike by skipping next frame
    main_skip_next_frame = true
  end
end

function love.run()
  if love.math then
    love.math.setRandomSeed(os.time())
    for i=1,3 do love.math.random() end
  end

  if love.event then love.event.pump() end

  if love.load then safe_call(function () love.load(arg) end) end

  -- we don't want the first frame's dt to include time taken by love.load
  if love.timer then love.timer.step() end

  local dt = 0

  -- main loop
  while true do
    -- process events
    if love.event then
      love.event.pump()
      for e,a,b,c,d in love.event.poll() do
        if e == "quit" then
          if not love.quit or not love.quit() then
            if love.audio then
              love.audio.stop()
            end
            return
          end
        end
        safe_call(function () love.handlers[e](a,b,c,d) end)
      end
    end

    -- calculate dt
    if love.timer then
      love.timer.step()
      dt = love.timer.getDelta()
    end

    -- update, draw
    if love.update then
      safe_call(function () love.update(dt) end)
    end -- 0 if love.timer is disabled

    if love.window and love.graphics and love.window.isCreated() then
      love.graphics.clear()
      love.graphics.origin()
      if love.draw then
        safe_call(love.draw)
      end
      love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end

