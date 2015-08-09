-- updated every frame

entity.create_named('update')

entities.update.updating = false -- whether to receive update events

function entities.update.update(self, cont, dt) end

function entities.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e.updating then e:update(dt) end
  end
end

