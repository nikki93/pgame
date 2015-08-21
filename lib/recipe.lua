recipe = {}

recipe._recipe_meta = {
  __newindex = function (self, stepname, f)
    self._steps[stepname] = f
  end,

  __index = {
    _visit = function (self, stepname)
      if self._visited[stepname] then return end
      self._visited[stepname] = true
      for _, ent in ipairs(self._steps[stepname](self) or {}) do
        table.insert(self._ents, ent)
      end
      print("recipe '" .. self._name .. "' finished step '"
              .. stepname .. "'")
    end,

    -- call this in a step to list steps ... as dependencies
    depends = function (self, ...)
      for _, stepname  in ipairs({ ... }) do
        self:_visit(stepname)
      end
    end,

    -- run the recipe -- steps is the list of target steps to finish, if nil
    -- then finishes all steps -- if filename is given, immediately saves
    -- collected entities to file
    run = function (self, filename, steps)
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
  }
}

function recipe.new(name)
  return setmetatable({ _name = name, _visited = {}, _steps = {}, _ents = {} },
    recipe._recipe_meta)
end

