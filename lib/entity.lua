entity = {}


-- ids/names -------------------------------------------------------------------

-- this table refers to all entities by id, so that entity._ids[o._id] == o,
-- where o is an entity
entity._ids = {}

-- same as entity._ids[id], but error if not present
function entity.get(id)
  local e = entity._ids[id]
  if e == nil then
    -- avoid concat when no error
    error ("no entity with id '" .. tostring(id) .. "'")
  end
  return e
end

-- this table refers to named entities by name, so that entities[o:get_name()]
-- == o, where o is an entity with a name
entities = {}


-- slots -----------------------------------------------------------------------

entity._slot_desc_meta = {}

-- a slot descriptor which can be used as a slot value in entity descriptors
-- the table passed in is of the form { value, doc, m1 = v1, m2 = v2, ... }
-- where 'value' is the value of the slot, 'doc' is the doc string and (m1, v1),
-- (m2, v2), ... are the metadata associations
function entity.slot(desc)
  if not desc.doc then desc.doc = desc[2] end
  desc[2] = nil
  if desc.doc then desc.doc = desc.doc:claim() end
  return setmetatable(desc, entity._slot_desc_meta)
end

local function _get_slot(o, k)
  local r

  -- check in o
  r = rawget(o, k)
  if r ~= nil then return r end

  -- method registry entry? check for method
  r = rawget(o, '_methods')
  if r then
    r = r[k]
    if r ~= nil then return r.entrypoint end
  end

  -- check recursively in each proto if not starting with '_'
  if k:sub(1, 1) == '_' then return end
  for _, proto in ipairs(rawget(o, '_proto_ids')) do
    r = entity.get(proto)
    r = _get_slot(r, k)
    if r then return r end
  end
  return nil
end

-- metatable of all entities
entity.meta = {
  __index = function (o, k)
    local r = _get_slot(o, k)
    if r then return r end

    -- try getter
    r = _get_slot(o, 'get_' .. k)
    if r ~= nil then return r(o) end
  end,

  __newindex = function (o, k, v)
    -- check for setter
    local s = o['set_' .. k]
    if s ~= nil then return s(o, v) end

    -- is v a slot descriptor?
    if getmetatable(v) == entity._slot_desc_meta then
      local val = v[1]
      v[1] = nil
      setmetatable(v, nil)
      o['meta_' .. k] = v
      v = val
    end

    -- is o a method registry entry?
    if rawget(o, '_methods') then
      -- creating a new method?
      if type(v) == 'function' then
        -- need a call-next-method continuation -- the continuation is a closure
        -- that iterates through the proto order, the entrypoint is a wrapper
        -- that starts off the chain
        local function entrypoint(self, ...)
          local ord = entity._proto_order(self)
          local i = #ord + 1
          local function cont(...)
            while true do
              i = i - 1
              if i < 1 then return nil end
              local r = rawget(ord[i], '_methods')
              if r then
                r = r[k]
                if r then return r.func(self, cont, ...) end
              end
            end
          end
          return cont(...)
        end
        rawget(o, '_methods')[k] = { entrypoint = entrypoint, func = v }
        local doc = doc.pop_doc()
        if doc then o['meta_' .. k] = { doc = doc } end
        return
      elseif v == nil then -- removing a method?
        rawget(o, '_methods')[k] = nil
      end
    end

    return rawset(o, k, v)
  end,

  __tostring = function (o)
    return o:to_string()
  end,

  -- to skip slots starting with '_' on serialization
  __keyallow = function (o, k)
    local meta_k = o:slot_meta(k)
    return not (meta_k and meta_k.saveload == false)
  end
}

-- /reverse/ of order in which protos are visited for methods, an array of
-- entities -- the order is the reverse of the topological sort order, so that
-- entities appear after all their protos and ties are broken in right-left
-- order of _proto_ids list
function entity._proto_order(e)
  local ord, vis = {}, {}
  local function visit(e)
    if vis[e] then return end
    vis[e] = true
    local pids = rawget(e, '_proto_ids')
    for i = #pids, 1, -1 do
      local p = entity.get(pids[i])
      visit(p)
    end
    table.insert(ord, e)
  end
  visit(e)
  return ord
end


-- entity creation -------------------------------------------------------------

-- add an entity from an 'entity descriptor'
--
-- an entity descriptor table is a table of slot name to values to set, with
-- the following additions:
--   - can optionally have a '_protos' list instead of '_proto_ids,' directly
--     refering to the proto entities or referring to them by name for
--     convenience
--   - can optionally have an '_id_seed' to seed the id generator, useful if you
--     want to rename an entity but associate it with the old id
--
-- replaces the existing with the same name or id if exists
function entity.add(t)
  ent = {}
  ent._name = t._name

  -- generate id -- hash of name or seed, new uuid if neither
  if t._id then
    ent._id = t._id
  else
    local seed = t._name or t._id_seed
    ent._id = (seed and md5.sumhexa(seed) or uuid()):sub(1, 21)
  end
  local old = entity._ids[ent._id]

  -- initialize '_proto_ids' and convert from '_protos' list
  ent._proto_ids = t._proto_ids or {}
  if t._protos then
    ent._proto_ids = {}
    for _, ref in ipairs(t._protos) do
      if type(ref) == 'string' then
        ref = assert(entities[ref], "no entity with name '" .. ref .. "'")
      end
      table.insert(ent._proto_ids, ref._id)
    end
  end
  if not (t._protos and next(t._protos) == nil)
  and ent._name ~= 'entity' and next(ent._proto_ids) == nil then
    table.insert(ent._proto_ids, entities.entity._id) -- ensure root proto
  end

  -- dropping old protos: unset in their _sub_id caches
  if old then
    local ps = ent._proto_ids
    for _, old_proto_id in ipairs(rawget(old, '_proto_ids')) do
      local found = false
      for _, proto_id in ipairs(ps) do
        if old_proto_id == proto_id then
          found = true
          break
        end
      end
      if not found then
        rawget(entity.get(old_proto_id), '_sub_ids')[old._id] = nil
      end
    end
  end

  -- protos: set in their _sub_id caches
  local pp = rawget(ent, '_proto_ids')
  for i = #pp, 1, -1 do
    local p = entity._ids[pp[i]]
    if p then rawget(p, '_sub_ids')[ent._id] = true
    else
      print("warning: couldn't find proto with id '" .. pp[i] .. "'")
      table.remove(pp, i)
    end
  end

  -- subs: copy from old _sub_id cache or initialize
  rawset(ent, '_sub_ids', old and rawget(old, '_sub_ids') or {})

  -- associate with name and initialize method cache
  local name = ent._name
  if name ~= nil then entities[name] = ent end
  if old then
    local old_name = old:get_name()
    if old_name ~= nil and old_name ~= name then entities[old_name] = nil end
  end

  -- set metatable and put in id table -- after this methods are available
  setmetatable(ent, entity.meta)
  entity._ids[ent._id] = ent

  -- set slots -- do this after metatable association
  local skip = { _protos = true, _id_seed = true }
  for k, v in pairs(t) do
    if not skip[k] then
      if k == 1 then ent['_doc'] = v:claim() -- shortcut for doc
      else ent[k] = v end
    end
  end

  return ent
end

-- add many entities from many entity description tables -- just runs entity.add
-- on each and returns all resulting entities as an array
function entity.adds(ts)
  local ents = {}
  for _, t in ipairs(ts) do table.insert(ents, entity.add(t)) end
  return ents
end


-- method registry -------------------------------------------------------------

entity._method_registry_meta = {
  __index = function (o, k)
    -- already created?
    local entry = o._entries[k]
    if entry then return entry end

    -- create a new one -- no protos!
    entry = entity.add {
      _name = 'methods_' .. k,
      _protos = {},

      _methods = {},
    }
    o._entries[k] = entry
    return entry
  end,

  __newindex = function(o, k, v)
    if v == nil then
      -- destroying a method registry entry
      -- TODO: separate destruction logic into non-method common function
      local entry = o._entries[k]
      if entry then methods.entity.destroy(entry) end
      return
    end
    rawset(o, k, v)
  end
}

methods = setmetatable({ _entries = {} }, entity._method_registry_meta)


-- save/load -------------------------------------------------------------------

-- save entities to a image -- ents must be an array of entities
function entity.save(ents)
  -- pre-sort array for stability
  local sorted = {}
  for _, ent in ipairs(ents) do table.insert(sorted, ent) end
  table.sort(sorted, function (e, f) return e._id < f._id end)

  -- put into a new array with protos before subs, restricted to input array
  local ids = {}
  for _, ent in ipairs(sorted) do ids[ent._id] = true end
  local ord, vis = {}, {}
  local function visit(e)
    if vis[e] then return end
    vis[e] = true
    for _, proto_id in ipairs(rawget(e, '_proto_ids')) do
      if ids[proto_id] then visit(entity.get(proto_id)) end
    end
    table.insert(ord, e)
  end
  for _, ent in ipairs(sorted) do visit(ent) end

  -- serialize and return
  return serpent.dump(ord, { indent = ' ', sortkeys = true })
end

-- load entities from an image -- returns the array of entities loaded
function entity.load(buf)
  local success, ents = serpent.load(buf, { safe = false })
  if not success then
    print('loading image failed: ')
    print(tostring(ents))
  end
  return entity.adds(ents)
end

-- save bunch of entities to a file image, ents specified as in entity.save(...)
function entity.save_file(filename, ents)
  local f = assert(io.open(filename, 'w'))
  f:write(entity.save(ents))
  f:close()
end

-- load entities from a file image -- returns the array of entities loaded
function entity.load_file(filename)
  local f = love.filesystem.newFile(filename)
  f:open('r')
  local b = f:read()
  f:close()
  return entity.load(b)
end


