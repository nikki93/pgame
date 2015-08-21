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

function bootstrap:universe()
  -- this table stores all entities that exist, so that entity._ids[o._id] == o,
  -- where o is an entity
  entity._ids = {}

  -- this table refers to entities by name, so that entities[o:get_name()] == o,
  -- where o is an entity with a name
  entities = {}

  -- list of entities to destroy on next cleanup
  entity._destroy_marks = { ord = {}, ids = {} }
end

function bootstrap:entity()
  self:depends('universe')

  -- our first entity! this is will be an rproto for all entities
  return entity.adds { { _name = 'entity' } }
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


-- sub/proto logic -------------------------------------------------------------

local function _get_slot(o, k)
  local r

  -- check in o
  r = rawget(o, k)
  if r ~= nil then return r end

  -- check for method
  r = rawget(o, '_method_entries')[k]
  if r ~= nil then return r.entrypoint end

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

    return rawset(o, k, v)
  end,

  __tostring = function (o)
    return o:to_string()
  end,

  -- to skip slots starting with '_' on serialization
  __keyallow = function (k)
    return k ~= '_method_entries' and k ~= '_sub_ids'
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


-- base entity methods ---------------------------------------------------------

-- get entity's name -- TODO: set to new name if given
function methods.entity.get_name(self, cont)
  return self._name
end

-- set entity's name
function methods.entity.set_name(self, cont, name)
  local old_name = self:get_name()
  if old_name ~= nil and old_name ~= name then entities[old_name] = nil end

  self._name = name
  if name ~= nil then
    entities[name] = self
    self._method_entries = rawget(methods[name], '_entries')
  else
    self._method_entries = {}
  end
end

-- add a proto
function methods.entity.add_proto(self, cont, proto, i)
  rawget(proto, '_sub_ids')[self._id] = true
  local pp = rawget(self, '_proto_ids')
  for _, proto_id in ipairs(pp) do
    if proto._id == proto_id then return end
  end
  table.insert(pp, i or #pp + 1, proto._id)
end

-- remove a proto
function methods.entity.remove_proto(self, cont, proto)
  rawget(proto, '_sub_ids')[self._id] = nil
  local pp = rawget(self, '_proto_ids')
  for i = 1, #pp do
    if pp[i] == proto._id then
      table.remove(pp, i)
    end
  end
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


-- immediately forget an entity and disconnect its sub/proto links -- remember
-- to call cont() (generally at end) while overriding!
function methods.entity.destroy(self, cont)
  -- remove from subs' list of _proto_ids
  for sub_id in pairs(rawget(self, '_sub_ids')) do
    local ps = rawget(entity.get(sub_id), '_proto_ids')
    for i = 1, #ps do if ps[i] == self._id then table.remove(ps, i) end end
  end

  -- remove from protos' sets of _sub_ids
  for _, proto_id in pairs(rawget(self, '_proto_ids')) do
    rawget(entity.get(proto_id), '_sub_ids')[self._id] = nil
  end

  entity._ids[self._id] = nil
  local name = self:get_name()
  if name then entities[name] = nil end
end

-- mark an entity to be destroyed on the next entities.entity:cleanup() call
function methods.entity.mark_destroy(self, cont)
  if not entity._destroy_marks.ids[self._id] then
    table.insert(entity._destroy_marks.ord, self._id)
    entity._destroy_marks.ids[self._id] = true
  end
end

-- destroy all entities marked with :mark_destroy() since last cleanup
function methods.entity.cleanup(self, cont)
  for _, id in ipairs(entity._destroy_marks.ord) do entity.get(id):destroy() end
  entity._destroy_marks = { ord = {}, ids = {} }
end


-- called on string conversion with tostring(...)
function methods.entity.to_string(self, cont)
  return '<ent:' .. (self:get_name() or self._id) .. '>'
end


-- entity creation utilities ---------------------------------------------------

-- add an entity from an 'entity description table'
--
-- an entity description table is identical in layout to the entity itself, but
-- can optionally have a '_protos' list instead of '_proto_ids,' directly
-- refering to the proto entities or referring to them by name for convenience
--
-- this function modifies the parameter into the resulting entity
--
-- replaces the existing with the same name or id if exists
function entity.add(ent)
  setmetatable(ent, nil) -- no fancy stuff, start from a plain table

  -- generate id -- hash of name or seed, new uuid if neither
  if not ent._id then
    local seed = ent._name or ent._id_seed
    ent._id = (seed and md5.sumhexa(seed) or uuid()):sub(1, 21)
  end
  ent._id_seed = nil
  local old = entity._ids[ent._id]

  -- initialize '_proto_ids' and convert from '_protos' list
  if not ent._proto_ids then ent._proto_ids = {} end
  if ent._protos then
    ent._proto_ids = {}
    for _, ref in ipairs(ent._protos) do
      if type(ref) == 'string' then
        ref = assert(entities[ref], "no entity with name '" .. ref .. "'")
      end
      table.insert(ent._proto_ids, ref._id)
    end
  end
  ent._protos = nil
  if ent._name ~= 'entity' and next(ent._proto_ids) == nil then
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
  if name ~= nil then
    entities[name] = ent
    ent._method_entries = rawget(methods[name], '_entries')
  else
    ent._method_entries = {}
  end
  if old then
    local old_name = old:get_name()
    if old_name ~= nil and old_name ~= name then entities[old_name] = nil end
  end

  -- finally, set metatable and put in id table
  setmetatable(ent, entity.meta)
  entity._ids[ent._id] = ent

  return ent
end

-- add many entities from many entity description tables -- just runs entity.add
-- on each and returns them all
function entity.adds(ts)
  for _, t in ipairs(ts) do entity.add(t) end
  return ts
end


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
  local success, ents = serpent.load(buf)
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


