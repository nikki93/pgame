bootstrap:adds {
  {
    _name = 'camera',
    _protos = { 'transform' },
    _doc = [[
      rsubs of this give a viewpoint for `drawable` to visualize the world:
        the viewport is a rectangle of the same pixel size as the visualization
        target (like the main window), oriented by `transform` trait
      ]],
  },
  {
    _name = 'main_camera',
    _protos = { 'camera' },
    _doc = [[
      `camera` rsub for the default viewport
      ]],
  }
}

-- apply view transform on current love context
function methods.camera.apply_view_transform(self, cont)
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(1 / self.scale[1], 1 / self.scale[2])
  love.graphics.translate(-self.position[1], -self.position[2])
end

