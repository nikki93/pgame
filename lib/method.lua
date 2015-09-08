method = {}

-- load methods from a directory
function method.load(dir)
  for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
    if string.find(file, "%.lua$") then
      require(dir .. '.' .. string.gsub(file, '%.lua$', ''))
    end
  end
end


-- get the method structure for method named m on entity e
function method._get_method(e, m)
  return rawget(e, '_method_entries')[m]
end

-- methods is a table that can be used to associate names with methods by
-- setting methods.name.methodname, or to remove associations by setting
-- methods.name or methods.name.methodname to nil

method._method_table_meta = {
  __newindex = function (o, k, v)
    if type(v) == 'function' then
      -- need a call-next-method continuation -- the continuation is a closure
      -- that iterates through the proto order, the entrypoint is a wrapper that
      -- starts off the chain
      local function entrypoint(self, ...)
        local ord = entity._proto_order(self)
        local i = #ord + 1
        local function cont(...)
          while true do
            i = i - 1
            if i < 1 then return nil end
            local pm = method._get_method(ord[i], k)
            if pm then return pm.func(self, cont, ...) end
          end
        end
        return cont(...)
      end
      rawget(o, '_entries')[k] = { entrypoint = entrypoint, func = v,
                                   doc = method._next_doc }
    elseif v == nil then
      -- remove a method?
      rawget(o, '_entries')[k] = nil
    end
  end,

  __index = function (o, k)
    return rawget(o, '_entries')[k]
  end
}

method._methods_meta = {
  __index = function (o, k)
    local entry = o._entries[k]
    if entry then return entry end

    local entries = {}
    local v = setmetatable({ _entries = entries }, method._method_table_meta)
    o._entries[k] = v
    local ent = entities and entities[k]
    if ent then ent._method_entries = entries end
    return v
  end,

  __newindex = function (o, k, v)
    if v == nil then
      local ent = entities[k]
      if ent then ent._method_entries = {} end
    end
    o._entries[k] = v
  end
}

methods = setmetatable({ _entries = {} }, method._methods_meta)

-- add documentation to next defined method
method._next_doc = nil
function method.doc(doc)
  method._next_doc = doc
end


