bootstrap:add {
  _name = 'update',
  _protos = { 'entity' },
  [[
    rsubs of this can be stepped ahead in time by implementing
    `update.update`:
      they are automatically stepped forward per frame of the game

      they can be paused/unpaused using `drawing.updating` (initially paused)
      (see `alive`)
    ]],

  updating = false, -- whether to receive update events
}

function methods.update.update(self, cont, dt) cont(dt) end

function methods.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsubs()) do
    if e.updating then e:update(dt) end
  end
end

