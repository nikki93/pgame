-- updated every frame

function bootstrap:update()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'update',
      _protos = { 'entity' },

      updating = false, -- whether to receive update events
    }
  }
end

function methods.update.update(self, cont, dt) cont(dt) end

function methods.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsubs()) do
    if e.updating then e:update(dt) end
  end
end

