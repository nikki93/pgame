--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---
--- defines basic sub/proto logic and the entity 'entity' that is an rproto
--- for all entities, as detailed below:
---
--- basics:
---    - an entity is simply a table with entity.meta as its metatable, but
---      its best to use the entity creation utilities below which handle some
---      other bookkeeping
---    - entities can keep 'slots' which are named places for holding data --
---      these are simply key-value pairs in the entity table
---
--- sub/proto:
---    - if x is a 'proto' of y then y is a 'sub' of x
---    - if x_1 is a proto of x_2 is a proto of ... is a proto of x_n, then
---      x_1 is an 'rproto' (recursive proto) of x_n
---    - if x_1 is a sub of x_2 is a sub of ... is a sub of x_n, then
---      x_1 is an 'rsub' of x_n
---    - no entity is an rproto or rsub of itself
---
--- slot lookup:
---    - protos of an entity are maintained in an order
---    - slot access in x looks in x first, then recursively in protos depth
---      first in left-right order of protos
---    - slots can be 'methods' which are functions called with a 'self' and
---      a 'cont' argument, so that calling x:m(a, b, ...) results in a call
---      to x.m(x, cont, a, b, ...) with x evaluated just once
---        - self is the receiver of the method call
---        - cont is a function which, when called, calls the next method in
---          the method call chain defined in topological sort order so that
---          methods by subs are called before those by protos, with ties
---          broken in left-right order of protos
---
--- ids:
---    - each entity has a unique id used to identify it, which is generated
---      when it is created
---    - use ids instead of direct entity references to ensure consistency
---      across saving and loading
---
--- names:
---    - entities can be given human-readable names for easier access and for
---      associating methods
---    - methods are defined as:
---          function methods.<name>.<methodname>(self, cont, ...) ... end
---      which means that the entities with the name <name> will have that
---      method (whether it already exists or will be created or loaded in the
---      future)
---    - this is so that methods can be written in source files and because
---      they don't get properly serialized
---
--- save/load:
---    - entities can be saved and loaded to and from in-memory or file images
---    - on loading, an entity replaces the existing entity with the same id
---      (like Smalltalk's 'become:') if one exists, else it is just added as a
---      new entity
---    - on loading, if an entity's proto list refers to an id that isn't found,
---      a warning is generated and that entry in the proto list is ignored
---
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

entity = {}


-- bootstrap -------------------------------------------------------------------

function bootstrap.universe()
  -- this table stores all entities that exist, so that entity._ids[o.id] == o,
  -- where o is an entity
  entity._ids = {}

  -- this table refers to entities by name, so that entities[o.name] == o, where
  -- o is an entity with a name
  entities = {}

  -- list of entities to destroy on next cleanup
  entity._destroy_marks = { ord = {}, ids = {} }
end

function bootstrap.entity()
  bootstrap.require('universe')

  -- our first entity! this is will be an rproto for all entities
  entity._name_entity('entity', entity._create('entity'))
end


-- ids/names -------------------------------------------------------------------

-- same as entity._ids[id], but error if not present
function entity.get(id)
  local e = entity._ids[id]
  if e == nil then
    -- avoid concat when no error
    error ("no entity with id '" .. tostring(id) .. "'")
  end
  return e
end

-- associate a name with an entity -- can use nil name to remove name
function entity._name_entity(name, ent)
  -- update entities[...] map
  local old_name = rawget(ent, 'name')
  if old_name ~= nil and old_name ~= name then entities[old_name] = nil end
  rawset(ent, 'name', name)
  if name ~= nil then entities[name] = ent end

  -- associate methods
  rawset(ent, '_method_entries', rawget(methods[name], '_entries'))
end


-- sub/proto logic -------------------------------------------------------------

-- metatable of all entities
entity.meta = {
  __index = function (o, k)
    local r

    -- check in o
    r = rawget(o, k)
    if r ~= nil then return r end

    -- check for method
    r = method._get_method(o, k)
    if r ~= nil then return r.entrypoint end

    -- check recursively in each proto
    for _, proto in ipairs(rawget(o, 'proto_ids')) do
      r = entity.get(proto)
      r = r[k]
      if r then return r end
    end
    return nil
  end,

  __newindex = function (o, k, v)
    if v == nil then
      -- remove previous method structure if exists
      rawget(o, '_methods')[k] = nil
    else
      rawset(o, k, v)
    end
  end,

  __tostring = function (o)
    return o:to_string()
  end
}

-- /reverse/ of order in which protos are visited for methods, an array of
-- entities -- the order is the reverse of the topological sort order, so that
-- entities appear after all their protos and ties are broken in right-left
-- order of proto_ids list
function entity._proto_order(e)
  local cache = entity._proto_order_cache[e]
  if cache then return cache end
  local ord, vis = {}, {}
  local function visit(e)
    if vis[e] then return end
    vis[e] = true
    local pids = rawget(e, 'proto_ids')
    for i = #pids, 1, -1 do
      local p = entity.get(pids[i])
      visit(p)
    end
    table.insert(ord, e)
  end
  visit(e)
  entity._proto_order_cache[e] = ord
  return ord
end

-- introduce a new sub-proto relationship given the entity ids, and optionally
-- s or p as the entities themselves
function entity._link(sub, proto, s, p)
  p = p or entity.get(proto)
  s = s or entity.get(sub)

  -- add sub to proto's cache of _sub_ids
  local ss = rawget(p, '_sub_ids') or {}
  if ss[sub] then return end -- already linked
  ss[sub] = true
  rawset(p, '_sub_ids', ss)

  -- add proto to sub's ordered list of proto_ids
  local ps = rawget(s, 'proto_ids') or {}
  table.insert(ps, proto)
  rawset(s, 'proto_ids', ps)

  entity._proto_order_cache = {}
end

-- create and return new entity with new unique id and no protos -- you really
-- should just use entity.create which ensures 'entity' is an rproto -- if
-- seed is given, it is used to deterministically generate a unique id
function entity._create(seed)
  local id = seed and md5.sumhexa(seed) or uuid()
  id = id:sub(1, 16)
  -- create and return entity
  local e = {
    id = id,
    proto_ids = {},
    _sub_ids = {},
    _method_entries = {}
  }
  setmetatable(e, entity.meta)
  entity._ids[id] = e
  return e
end


-- base entity methods ---------------------------------------------------------

-- immediately forget an entity and disconnect its sub/proto links -- remember
-- to call cont() (generally at end) while overriding!
function methods.entity.destroy(self, cont)
  -- remove from subs' list of proto_ids
  for sub_id in pairs(rawget(self, '_sub_ids')) do
    local ps = rawget(entity.get(sub_id), 'proto_ids')
    for i = 1, #ps do if ps[i] == self.id then table.remove(ps, i) end end
  end

  -- remove from protos' sets of _sub_ids
  for _, proto_id in pairs(rawget(self, 'proto_ids')) do
    rawget(entity.get(proto_id), '_sub_ids')[self.id] = nil
  end

  entity._ids[self.id] = nil
  if self.name then entities[self.name] = nil end

  entity._proto_order_cache = {}
end

-- mark an entity to be destroyed on the next entities.entity:cleanup() call
function methods.entity.mark_destroy(self, cont)
  if not entity._destroy_marks.ids[self.id] then
    table.insert(entity._destroy_marks.ord, self.id)
    entity._destroy_marks.ids[self.id] = true
  end
end

-- destroy all entities marked with :mark_destroy() since last cleanup
function methods.entity.cleanup(self, cont)
  for _, id in ipairs(entity._destroy_marks.ord) do entity.get(id):destroy() end
  entity._destroy_marks = { ord = {}, ids = {} }
end

-- add entity with id proto_id as a proto
function methods.entity.add_proto_id(self, cont, proto_id)
  entity._link(self.id, proto_id, self)
end

-- return all subs, recursively, as a set
function methods.entity.rsubs(self, cont)
  local result = {}
  local function collect(e)
    for sub_id, _ in pairs(rawget(e, '_sub_ids') or {}) do
      local e = entity.get(sub_id)
      if not result[e] then
        result[e] = true
        collect(e)
      end
    end
  end
  collect(self)
  return result
end

-- called on string conversion with tostring(...)
function methods.entity.to_string(self, cont)
  return '<entities[' .. tostring(self.id) .. ']>'
end


-- entity creation utilities ---------------------------------------------------

-- create an entity with given array of entities as protos
function entity.create(protos)
  return entity.create_named(nil, protos)
end

-- create an entity with given name and array of entities as protos -- also
-- optionally takes a seed to seed the id generator, useful if you're replacing
-- an old object with a new name
function entity.create_named(name, protos, seed)
  local e = entity._create(seed or name)
  if protos then
    for _, proto in ipairs(protos) do entity._link(e.id, proto.id, e) end
  end
  if #rawget(e, 'proto_ids') == 0 then
    entity._link(e.id, entities.entity.id, e)
  end
  if name then entity._name_entity(name, e) end
  return e
end


-- save/load -------------------------------------------------------------------

-- save entities to a image -- ents must be an array of entities
function entity.save(ents)
  -- sort array
  local sorted = {}
  for _, ent in ipairs(ents) do table.insert(sorted, ent) end
  table.sort(sorted, function (e, f) return e.id < f.id end)

  -- skip saving of caches
  local keyallow = setmetatable({ _method_entries = false, _sub_ids = false },
    { __index = function () return true end })
  return serpent.dump(sorted,
                      { indent = ' ', sortkeys = true, keyallow = keyallow })
end

-- load entities from an image -- returns the array of entities as passed to
-- entity.save(...) to save the image
function entity.load(buf)
  local success, ents = serpent.load(buf)
  if not success then
    print('loading image failed: ')
    print(tostring(ents))
  end

  -- first pass: loaded entities might drop protos, clean up _sub_id cache
  for _, ent in ipairs(ents) do
    local old = entity._ids[ent.id]
    if old then
      local ps = rawget(ent, 'proto_ids')
      for _, old_proto_id in ipairs(rawget(old, 'proto_ids')) do
        local found = false
        for _, proto_id in ipairs(ps) do
          if old_proto_id == proto_id then
            found = true
            break
          end
        end
        if not found then
          rawget(entity.get(old_proto_id), '_sub_ids')[old.id] = nil
        end
      end
    end
  end

  -- second pass: copy or initialize caches, set metatable and put in id table
  for _, ent in ipairs(ents) do
    local old = entity._ids[ent.id]
    rawset(ent, '_sub_ids', old and rawget(old, '_sub_ids') or {})
    rawset(ent, '_method_entries', {})
    setmetatable(ent, entity.meta)
    entity._ids[ent.id] = ent
  end

  -- third pass: add to _sub_ids list of new protos or warn about dangling ones
  local warn = {}
  for _, ent in ipairs(ents) do
    local pp = rawget(ent, 'proto_ids')
    for i = #pp, 1, -1 do
      local p = entity._ids[pp[i]]
      if p then 
        rawget(p, '_sub_ids')[ent.id] = true
      else
        warn[pp[i]] = true
        table.remove(pp, i)
      end
    end
  end
  for id in pairs(warn) do
    print("warning: couldn't find proto with id '"
            .. tostring(id) .. "', ignored")
  end

  -- fourth pass: associate with names -- this installs the methods too
  for _, ent in ipairs(ents) do
    local name = rawget(ent, 'name')
    if name then entity._name_entity(name, ent) end
  end

  entity._proto_order_cache = {}
  return ents
end

-- save bunch of entities to a file image, ents specified as in entity.save(...)
function entity.save_file(filename, ents)
  local f = assert(io.open(filename, 'w'))
  f:write(entity.save(ents))
  f:close()
end

-- load entities from a file image -- returns the array of entities as passed to
-- entity.save_file(...) to save to the file
function entity.load_file(filename)
  local f = assert(io.open(filename, 'r'))
  local b = f:read('*a')
  f:close()
  return entity.load(b)
end


