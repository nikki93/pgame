-- updated every frame

entity.create_named('update')

entities.update.updating = false -- whether to receive update events
entities.update.skip_next_frame = false -- to avoid dt spikes on process pause

function methods.update.update(self, cont, dt) cont(dt) end

function methods.update.update_rsubs(self, cont, dt)
  if self.skip_next_frame then
    self.skip_next_frame = false
    return
  end
  for e in pairs(self:rsubs()) do
    if e.updating then e:update(dt) end
  end
end

