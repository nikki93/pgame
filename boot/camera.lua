bootstrap:add {
  [[ provide a viewport to visualize the world

     rsubs of this give a viewport for `drawable` to visualize the world:
       the viewport is a rectangle of the same pixel size as the visualization
       target (like the main window), oriented by `transform` trait ]],

  _name = 'camera',
  _protos = { 'transform' },
}

bootstrap:add {
  [[ the default camera for the main window ]],

  _name = 'main_camera',
  _protos = { 'camera' },
}

-- apply view transform on current love context
method.doc [[ apply a transform that maps world-space coordinates to their
              coordinates in the camera view space ]]
function methods.camera.apply_view_transform(self, cont)
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(1 / self.scale[1], 1 / self.scale[2])
  love.graphics.translate(-self.position[1], -self.position[2])
end

