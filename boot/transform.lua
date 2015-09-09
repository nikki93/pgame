bootstrap:add {
  DOC[[ has world-space position, rotation and scale ]],

  _name = 'transform',
  _protos = { 'entity' },

  position = entity.slot { vec2(0, 0), DOC[[ world-space position ]] },
  rotation = entity.slot { 0, DOC[[ world-space position ]] },
  scale = entity.slot { vec2(1, 1), DOC[[ world-space position ]] }
}

