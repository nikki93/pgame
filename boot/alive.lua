-- enables event notification

function bootstrap:alive()
  self:depends('entity')
  return entity.adds {
    {
      name = 'alive',
      protos = { 'entity' },

      updating = true,
      drawing = true,
    }
  }
end

