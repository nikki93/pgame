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
      _protos = { 'drawable', 'update', 'transform' },
      
      dir = 1,
      position = { 10, 200 },
    }
  }
end

function methods.player.update(self, cont, dt)
  cont(dt)

  if self.position[1] > 700 then self.dir = -1 end
  if self.position[1] < 100 then self.dir = 1 end

  self.position = { self.position[1] + self.dir * 200 * dt, self.position[2] }
end

function methods.player.draw(self, cont)
  cont()
  love.graphics.push()
  love.graphics.translate(unpack(self.position))
  love.graphics.rotate(self.rotation)
  love.graphics.print("<player>", 0, 0)
  love.graphics.pop()
end


-- scene

test_scene = recipe.new('test_scene')

function test_scene:main()
  return entity.adds {
    { _protos = { 'alive', 'player', 'rotator' } }
  }
end


