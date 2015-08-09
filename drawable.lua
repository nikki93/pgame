-- can be visualized

entity.create_named('drawable')

entities.drawable.drawing = false -- whether to receive draw events

function entities.drawable.draw(self, cont) end

function entities.drawable.draw_rsubs(self, cont)
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e.drawing then e:draw() end
  end
end

