recipe = {}

recipe._meta = {}

-- allows to easily define a step with the syntax,
--  function my_recipe:stepname()
--    ...
--  end
function recipe._meta.__newindex(self, stepname, f)
  self._steps[stepname] = f
end

recipe._meta.__index = {}

-- run a single step
function recipe._meta.__index._visit(self, stepname)
  if self._visited[stepname] then return end
  self._visited[stepname] = true
  for _, ent in ipairs(self._steps[stepname](self) or {}) do
    table.insert(self._ents, ent)
  end
  print("recipe '" .. self._name .. "' finished step '"
          .. stepname .. "'")
end

-- call this in a step to list steps ... as dependencies
function recipe._meta.__index.depends(self, ...)
  for _, stepname  in ipairs({ ... }) do
    self:_visit(stepname)
  end
end

-- add a step that runs entity.add on the given table, with the resulting
-- step name being the name of the entity -- adds names in '_protos' as
-- names of step dependencies
function recipe._meta.__index.add(self, ent)
  assert(ent._name, 'entity description table should include a name')
  self[ent._name] = function (self)
    local deps = {}
    for _, p in ipairs(ent._protos) do
      if self._steps[p] then table.insert(deps, p) end
    end
    if ent._protos then self:depends(unpack(deps)) end
    return { entity.add(ent) }
  end
end

-- add many entitya.add steps -- runs self:add on each table in the array
function recipe._meta.__index.adds(self, ents)
  for _, ent in ipairs(ents) do self:add(ent) end
end

-- run the recipe -- steps is the list of target steps to finish, if nil
-- then finishes all steps -- if filename is given, immediately saves
-- collected entities to file
function recipe._meta.__index.run(self, filename, steps)
  if steps then
    for _, name in ipairs(steps) do self:_visit(name) end
  else
    for name in pairs(self._steps) do self:_visit(name) end
  end

  if filename then
    print("saving to '" .. filename .. "'")
    entity.save_file(filename, self._ents)
  end

  self._visited = {}
  local ents = self._ents
  self._ents = {}
  return ents
end

-- create and return a new recipe with the given name -- the name is just used
-- for printing informative messages
function recipe.new(name)
  return setmetatable({ _name = name, _visited = {}, _steps = {}, _ents = {} },
    recipe._meta)
end

