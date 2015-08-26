-- has a physical position and rotation

function bootstrap:transform()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'transform',
      _protos = { 'entity' },

      position = vec2(10, 10),
      rotation = 0,
    }
  }
end

