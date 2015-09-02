-- can be visualized

function bootstrap:drawable()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'drawable',
      _protos = { 'entity' },

      drawing = false, -- whether to receive draw events
      depth = 100, -- decreases back to front, negative ignores view transform
    }
  }
end

function methods.drawable.draw(self, cont) cont() end

local function _depth_gt(a, b)
  -- break ties by id for stability
  if a.depth == b.depth then return a._id < b._id end
  return a.depth > b.depth
end
function methods.drawable.draw_rsubs(self, cont, camera)
  -- compute decreasing depth order
  local rsubs = {}
  for e in pairs(self:rsubs()) do table.insert(rsubs, e) end
  table.sort(rsubs, _depth_gt)
  local i, n = 1, #rsubs

  -- draw positive depth with the camera transform
  if camera then
    love.graphics.push()
    camera:inverse_view_transform()
  end
  while i <= n do
    local e = rsubs[i]
    if e.depth < 0 then break end
    if e.drawing then e:draw() end
    i = i + 1
  end
  if camera then love.graphics.pop() end

  -- draw the rest
  while i <= n do
    local e = rsubs[i]
    if e.drawing then e:draw() end
    i = i + 1
  end
end

