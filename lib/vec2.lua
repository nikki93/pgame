vec2_meta = {}

function vec2(x, y)
  return setmetatable({ x, y }, vec2_meta)
end

function vec2_meta.__saveload(v)
  return 'vec2', { v[1], v[2] }
end

function vec2_meta.__tostring(v)
  return 'vec2(' .. v[1] .. ', ' .. v[2] .. ')'
end

function vec2_meta.__unm(v)
  return vec2(-v[1], -v[2])
end
function vec2_meta.__add(u, v)
  return vec2(u[1] + v[1], u[2] + v[2])
end
function vec2_meta.__sub(u, v)
  return vec2(u[1] - v[1], u[2] - v[2])
end
function vec2_meta.__mul(a, b)
  if type(a) == 'number' then return vec2(a * b[1], a * b[2]) end
  if type(b) == 'number' then return vec2(a[1] * b, a[2] * b) end
  return vec2(a[1] * b[1], a[2] * b[2])
end
function vec2_meta.__div(a, b)
  if type(a) == 'number' then return vec2(a / b[1], a / b[2]) end
  if type(b) == 'number' then return vec2(a[1] / b, a[2] / b) end
  return vec2(a[1] / b[1], a[2] / b[2])
end

function vec2_len(v)
  return math.sqrt(v[1] * v[1] + v[2] * v[2])
end


