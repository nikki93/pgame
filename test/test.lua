test_protos = recipe.new('test_protos')

-- rotator

test_protos:add {
  _name = 'rotator',
  _protos = { methods.rotator, 'update', 'transform' },

  rotation_speed = 30,
}

function methods.rotator.update(self, cont, dt)
  cont(dt)
  self.rotation = self.rotation + self.rotation_speed * dt
end


-- player

test_protos:add {
  _name = 'player',
  _protos = { methods.player, 'drawable', 'update', 'input', 'transform' },
  
  dir = 1,
  position = vec2(10, 200),
}

function methods.player.update(self, cont, dt)
  cont(dt)

  if self.position[1] > 700 then self.dir = -1 end
  if self.position[1] < 100 then self.dir = 1 end

  self.position = self.position + 200 * dt * vec2(self.dir, 0)
end

function methods.player.draw(self, cont)
  cont()
  love.graphics.push()
  love.graphics.translate(unpack(self.position))
  love.graphics.rotate(self.rotation)
  love.graphics.print("<player>", 0, 0)
  love.graphics.pop()
end

function methods.player.keypressed(self, cont, unicode)
  print('key pressed: ' .. unicode)
end


-- scene

test_scene = recipe.new('test_scene')

test_scene:add {
  _protos = { 'alive', 'inputting', 'player', 'rotator' },
}


