test_protos = recipe.new('test_protos')

-- rotator

function test_protos:rotator()
  return entity.adds {
    {
      _name = 'rotator',
      _protos = { 'update', 'transform' },

      rotation_speed = 30,
    }
  }
end

function methods.rotator.update(self, cont, dt)
  cont(dt)
  self.rotation = self.rotation + self.rotation_speed * dt
end


-- player

function test_protos:player()
  return entity.adds {
    {
      _name = 'player',
      _protos = { 'drawable', 'update', 'input', 'transform' },
      
      dir = 1,
      position = vec2(10, 200),
    }
  }
end

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

function test_scene:main()
  return entity.adds {
    {
      _protos = { 'alive', 'inputting', 'player', 'rotator' },
    }
  }
end


