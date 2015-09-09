require 'boot.entity'

bootstrap:add {
  DOC[[ can be drawn to a render target

        rsubs of this can be drawn by implementing `drawable.draw`:
          they are automatically drawn to the main window through the main
          camera per frame, and can also be drawn to other targets from other
          viewports (see `drawable.draw_rsubs`, `camera`)

          use `drawing.depth` to determine draw order, and whether an entity
          ignores viewport orientation (eg. for HUD elements) ]],

  _name = 'drawable',
  _protos = { 'entity' },

  depth = entity.slot {
    100, DOC[[ determines draw order (lower depth drawn on top), entities with
               negative depth ignore view transform (eg. for HUD elements) ]]
  }
}

bootstrap:add {
  DOC[[ drawn to the main window per frame ]],

  _name = 'drawing',
  _protos = { 'drawable' },
}

DOC[[ draw self to current love render target (make sure to take world
      orientation into account) ]]
function methods.drawable.draw(self, cont) cont() end

local function _depth_gt(a, b)
  -- break ties by id for stability
  if a.depth == b.depth then return a._id < b._id end
  return a.depth > b.depth
end

DOC[[ draw all rsubs to the current love render target, as viewed from the given
      `camera` ]]
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

