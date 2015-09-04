-- rsubs of this have world-space position/rotation/scale

function bootstrap:transform()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'transform',
      _protos = { 'entity' },

      position = vec2(0, 0), -- world-space position
      rotation = 0, -- world-space rotation
      scale = vec2(1, 1), -- world-space scale
    }
  }
end

