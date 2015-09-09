doc = {}

doc._next_doc = {}

function DOC(str)
  doc._next_doc = str
  return str
end

function doc.pop_doc()
  local next_doc = doc._next_doc
  doc._next_doc = nil
  return next_doc
end
