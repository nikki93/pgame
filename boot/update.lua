bootstrap:add {
  _name = 'update',
  _protos = { 'entity' },
  [[
    rsubs of this can be stepped ahead in time by implementing `update.update`
    ]],
}

bootstrap:add {
  _name = 'updating',
  _protos = { 'update' },
  [[
    rsubs of this have `update.update` called every frame
    ]],
}

function methods.update.update(self, cont, dt) cont(dt) end

function methods.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsubs()) do e:update(dt) end
end

