bootstrap:add {
  _name = 'drawable',
  _protos = { 'entity' },
  _doc = [[
    rsubs of this can be drawn by implementing `drawable.draw`:
      they are automatically drawn to the main window through the main camera
      per frame, and can also be drawn to other targets from other viewpoints
      (see `drawable.draw_rsubs`, `camera`)

      their visibility is set by `drawable.drawing` (initially invisible) (see
      `alive`)

      use `drawing.depth` to determine draw order and whether an entity ignores
      viewpoint (eg. the HUD)

    todo:
      rename `drawable.drawing` to 'visible'?
    ]],

  drawing = false, -- whether to receive draw events
  depth = 100, -- decreases back to front, negative ignores view transform
}

-- draw self to current love render target (make sure to take world orientation
-- into account)
function methods.drawable.draw(self, cont) cont() end

-- draw all `drawable` rsubs with given camera as viewpoint to the current love
-- render target (usually the main window, but possibly a Canvas etc.)
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

