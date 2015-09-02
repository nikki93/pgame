-- a world-space viewport to map to the screen-space viewport when drawing --
-- start with a viewport with top-left at (0, 0) with the same pixel size as the
-- render target, then apply transformation described by 'transform'

function bootstrap:camera()
  self:depends('transform')
  return entity.adds {
    {
      _name = 'camera',
      _protos = { 'transform' },
    },
    {
      _name = 'main_camera',
      _protos = { 'camera' }
    }
  }
end

function methods.camera.inverse_view_transform(self, cont)
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(1 / self.scale[1], 1 / self.scale[2])
  love.graphics.translate(-self.position[1], -self.position[2])
end

