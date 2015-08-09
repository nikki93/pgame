-- rotator

entity.create_named('rotator', { 'update', 'transform' })

entities.rotator.rotation_speed = 30

function entities.rotator.update(self, cont, dt)
  cont(dt)
  self.rotation = self.rotation + self.rotation_speed * dt
end


-- player

entity.create_named('player', { 'drawable', 'transform' })

entities.player.dir = 1
entities.player.position[2] = 200

function entities.player.update(self, cont, dt)
  cont(dt)

  if self.position[1] > 700 then self.dir = -1 end
  if self.position[1] < 100 then self.dir = 1 end

  self.position = { self.position[1] + self.dir * 200 * dt, self.position[2] }
end

function entities.player.draw(self, cont)
  cont()
  love.graphics.push()
  love.graphics.translate(unpack(self.position))
  love.graphics.rotate(self.rotation)
  love.graphics.print("<player>", 0, 0)
  love.graphics.pop()
end


-- scene

function test_scene()
  the_player = entity.create({ 'alive', 'player', 'rotator' })
end

