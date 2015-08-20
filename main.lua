-- main events -----------------------------------------------------------------

function love.load(arg)
  table.remove(arg, 1)

  -- libraries
  serpent = require('lib.serpent')
  dbg = require('lib.debugger')
  require('socket') -- for uuid
  uuid = require('lib.uuid')
  uuid.seed()
  md5 = require('lib.md5')
  require('lib.scratch')
  require('lib.method')
  require('lib.bootstrap')

  -- boot!
  method.load('boot')
  local boot_image = 'boot/boot.pgame'
  if arg[1] == '--bootstrap' then -- bootstrap, write to file and quit
    assert(arg[2], 'no image file specified...')
    bootstrap.boot(arg[2])
    love.event.push('quit')
    return
  elseif arg[1] == '--boot' then -- read from file
    assert(arg[2], 'no image file specified...')
    boot_image = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
  end
  bootstrap._visit('universe') -- need some basics for entity.load_file(...)
  entity.load_file(boot_image)

  -- run start script
  if arg[1] then method.load(arg[1]) end
  if arg[2] then entity.load_file(arg[2]) end
end

function love.update(dt)
  scratch.update()
  if entities.update then entities.update:update_rsubs(dt) end
  if entities.entity then entities.entity:cleanup() end
end

function love.draw()
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
  if entities.drawable then entities.drawable:draw_rsubs() end
end


-- run -------------------------------------------------------------------------

local function safe_call(f)
  local succ, err = dbg.call(f)
  if not succ then
    -- avoid dt spike by skipping next frame
    entities.update.skip_next_frame = true
  end
end

function love.run()
  if love.math then
    love.math.setRandomSeed(os.time())
    for i=1,3 do love.math.random() end
  end

  if love.event then love.event.pump() end

  if love.load then love.load(arg) end

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

