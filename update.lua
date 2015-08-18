-- updated every frame

entity.create_named('update')

entities.update.updating = false -- whether to receive update events
entities.update.skip_next_frame = false -- to avoid dt spikes on process pause

function entities.update.update(self, cont, dt) cont(dt) end

function entities.update.update_rsubs(self, cont, dt)
  if self.skip_next_frame then
    self.skip_next_frame = false
    return
  end
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e.updating then e:update(dt) end
  end
end

