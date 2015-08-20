method = {}

-- get the method structure for method named m on entity e
function method._get_method(e, m)
  return rawget(e, '_method_entries')[m]
end

-- methods is a table that can be used to associate names with methods by
-- setting methods.name.methodname, or to remove associations by setting
-- methods.name or methods.name.methodname to nil

method._method_table_meta = {
  __newindex = function (o, k, v)
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
    rawget(o, '_entries')[k] = { entrypoint = entrypoint, func = v }
  end,

  __index = function (o, k)
    return rawget(o, '_entries')[k]
  end
}

method._methods_meta = {
  __index = function (o, k)
    local v = setmetatable({ _entries = {} }, method._method_table_meta)
    rawset(o, k, v)
    return v
  end
}

methods = setmetatable({}, method._methods_meta)

