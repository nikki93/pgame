entity.create_named('drawable')

function entities.drawable.draw(self, cont) end

function entities.drawable.draw_rsubs(self, cont)
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e:live() then e:draw() end
  end
end

