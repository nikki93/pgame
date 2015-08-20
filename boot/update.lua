-- updated every frame

function bootstrap.update()
  entity.add {
    name = 'update',

    updating = false, -- whether to receive update events
  }
end

function methods.update.update(self, cont, dt) cont(dt) end

function methods.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsubs()) do
    if e.updating then e:update(dt) end
  end
end

