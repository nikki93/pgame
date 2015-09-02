-- can be visualized

function bootstrap:drawable()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'drawable',
      _protos = { 'entity' },

      drawing = false, -- whether to receive draw events
    }
  }
end

function methods.drawable.draw(self, cont) cont() end

function methods.drawable.draw_rsubs(self, cont, camera)
  if camera then
    love.graphics.push()
    camera:inverse_view_transform()
  end

  for e in pairs(self:rsubs()) do
    if e.drawing then e:draw() end
  end

  if camera then love.graphics.pop() end
end

