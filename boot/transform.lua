bootstrap:add {
  DOC[[ has world-space position, rotation and scale ]],

  _name = 'transform',
  _protos = { 'entity' },

  position = entity.slot { vec2(0, 0), "world-space position" },
  rotation = entity.slot { 0, "world-space rotation" },
  scale = entity.slot { vec2(1, 1), "world-space scale" }
}

