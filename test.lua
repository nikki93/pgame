-- rotator

entity.create_named('rotator', { entities.update,
                                 entities.transform })

entities.rotator.rotation_speed = 30

function methods.rotator.update(self, cont, dt)
  cont(dt)
  self.rotation = self.rotation + self.rotation_speed * dt
end


-- player

entity.create_named('player', { entities.drawable,
                                entities.update,
                                entities.transform })

entities.player.dir = 1
entities.player.position = { 10, 200 }

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

function test_scene()
  the_player = entity.create({ entities.alive,
                               entities.player,
                               entities.rotator })
end

