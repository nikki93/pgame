-- has a physical position and rotation

function bootstrap:transform()
  self:depends('entity')
  return entity.adds {
    {
      name = 'transform',
      protos = { 'entity' },

      position = { 10, 10 },
      rotation = 0,
    }
  }
end

