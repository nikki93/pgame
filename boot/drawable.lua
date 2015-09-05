bootstrap:add {
  _name = 'drawable',
  _protos = { 'entity' },
  [[
    rsubs of this can be drawn by implementing `drawable.draw`:
      they are automatically drawn to the main window through the main camera
      per frame, and can also be drawn to other targets from other viewpoints
      (see `drawable.draw_rsubs`, `camera`)

      use `drawing.depth` to determine draw order and whether an entity ignores
      viewpoint (eg. the HUD)
    ]],

  depth = 100, -- decreases back to front, negative ignores view transform
}

bootstrap:add {
  _name = 'drawing',
  _protos = { 'drawable' },
  [[
    rubs of this are drawn to the main window per frame
    ]]
}

-- draw self to current love render target (make sure to take world orientation
-- into account)
function methods.drawable.draw(self, cont) cont() end

-- draw all self rsubs with given camera as viewpoint to the current love render
-- target (usually the main window, but possibly a Canvas etc.)
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
    camera:apply_view_transform()
  end
  while i <= n do
    local e = rsubs[i]
    if e.depth < 0 then break end
    e:draw()
    i = i + 1
  end
  if camera then love.graphics.pop() end

  -- draw the rest
  while i <= n do
    rsubs[i]:draw()
    i = i + 1
  end
end

