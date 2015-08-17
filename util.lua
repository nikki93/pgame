-- return an array b with each b[i] = f(a[i])
function map(f, a)
  b = {}
  for i, v in ipairs(a) do
    b[i] = f(v)
  end
  return b
end
