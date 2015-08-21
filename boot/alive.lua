-- enables event notification

function bootstrap:alive()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'alive',
      _protos = { 'entity' },

      updating = true,
      drawing = true,
    }
  }
end

