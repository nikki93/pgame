bootstrap:add {
  [[ can update with the passage of time

     rsubs of this can be notified of the passage of time per frame by
     implementing `update.update` ]],

  _name = 'update',
  _protos = { 'entity' },
}

bootstrap:add {
  [[ gets notified of frame updates ]],

  _name = 'updating',
  _protos = { 'update' },
}

methods.doc [[ step entity forward a frame with delta time 'dt' ]]
function methods.update.update(self, cont, dt) cont(dt) end

methods.doc [[ update all rsubs with delta time 'dt' ]]
function methods.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsubs()) do e:update(dt) end
end

