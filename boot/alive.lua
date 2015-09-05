bootstrap:add {
  _name = 'alive',
  _protos = { 'entity' },
  [[
    rsubs of this are part of the observed world:
      if rsub of `update` they are unpaused, if rsub of `drawable` they are
      visible (can be overriden by local slots for all cases)

      useful to list all event enabling slots in one place
    ]],

  updating = true,
  drawing = true,
}
