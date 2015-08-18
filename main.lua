-- main events -----------------------------------------------------------------

function love.load()
  love.window.setMode(800, 600, { x = 629, y = 56 })

  -- utilities
  require('util')

  -- basic entities
  require('entity')
  require('update')
  require('drawable')
  require('alive')
  require('scratch')
  require('transform')

  -- test entities
  require('test')

  test_scene()
end

function love.update(dt)
  entities.update:update_rsubs(dt)
  entities.entity:cleanup()
end

function love.draw()
  entities.drawable:draw_rsubs()
end


-- run -------------------------------------------------------------------------

local function safe_call(f)
  local succ, err = xpcall(f, debug.traceback)
  if not succ then
    print(err)
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

