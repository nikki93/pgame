-- rsubs of this are part of the observed world:
--   they receive the relevant events from `updateable` or `drawable` if they
--   rsub those

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

