-- can be visualized

entity.create_named('drawable')

entities.drawable.drawing = false -- whether to receive draw events

function methods.drawable.draw(self, cont) cont() end

function methods.drawable.draw_rsubs(self, cont)
  for e in pairs(self:rsubs()) do
    if e.drawing then e:draw() end
  end
end

