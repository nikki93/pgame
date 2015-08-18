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
---    - protos are listed by 'id,' a kind of object used to identify entities
---    - an entity's id can be a string, in which case it is a 'named' entity,
---      otherwise it is given a generated id that is always unique
---
--- save/load:
---    - entities can be saved and loaded to and from in-memory or file buffers
---    - on loading, if an entity is named, it replaces the existing entity of
---      the same name (like Smalltalk's 'become:'), else it is just added
---      as a new entity
---    - on loading, if an entity's proto list refers to an id that isn't found,
---      a warning is generated and that entry in the proto list is ignored
---
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- namespace for all entity meta stuff
entity = {}


-- id handling -----------------------------------------------------------------

-- ids are either plains strings or special 'unique id' objects that are
-- generated when no name is provided

-- this table stores all entities that exist, so that entities[o.id] == o, where
-- o is an entity
entities = {}

-- stringify an id -- string ids get surrounded with quotes
function entity.stringify_id(id)
  if type(id) == 'string' then return "'" .. id .. "'" end
  return tostring(id)
end

-- same as entities[id], but error if not present
function entity.get(id)
  local e = entities[id]
  if e == nil then
    -- avoid concat when no error
    error ('no entity with id ' .. entity.stringify_id(id))
  end
  return e
end

-- nicer stringification of unique ids
entity._uniq_to_string = function (o)
  getmetatable(o).__tostring = nil
  local s = tostring(o):gsub('^%w+: ', '')
  getmetatable(o).__tostring = entity._uniq_to_string
  return s
end
entity._uniq_meta = { __tostring = entity._uniq_to_string }

-- generate a new unique id
function entity._gen_uniq()
  return setmetatable({}, entity._uniq_meta)
end


-- sub/proto logic -------------------------------------------------------------

-- metatable of all entities
entity.meta = {
  __index = function (o, k)
    local r

    -- check in o
    r = rawget(o, k)
    if r ~= nil then return r end
    r = rawget(o, '_methods')[k]
    if r ~= nil then return r.entrypoint end

    -- check recursively in each proto
    for _, proto in ipairs(rawget(o, 'proto_ids')) do
      r = entities[proto]
      if r then r = r[k] end
      if r then return r end
    end
    return nil
  end,

  __newindex = function (o, k, v)
    if v == nil then
      -- remove previous method structure if exists
      rawget(o, '_methods')[k] = nil
    elseif type(v) == 'function' then
      -- function? it's gonna be a method, need a call-next-method continuation
      -- the continuation is a closure that iterates through the proto order the
      -- entrypoint is a wrapper that starts off the chain
      local function entrypoint(self, ...)
        local ord = entity._proto_order(self)
        local i = #ord + 1
        local function cont(...)
          while true do
            i = i - 1
            if i < 1 then return nil end
            local pm = rawget(ord[i], '_methods')[k]
            if pm then return pm.func(self, cont, ...) end
          end
        end
        return cont(...)
      end
      rawget(o, '_methods')[k] = { entrypoint = entrypoint, func = v }
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
  return ord
end

-- introduce a new sub-proto relationship given the entity ids, and optionally
-- s or p as the entities themselves
function entity._link(sub, proto, s, p)
  p = p or entity.get(proto)
  s = s or entity.get(sub)

  -- add sub to proto's set of sub_ids
  local ss = rawget(p, 'sub_ids') or {}
  if ss[sub] then return end -- already linked
  ss[sub] = true
  rawset(p, 'sub_ids', ss)

  -- add proto to sub's ordered list of proto_ids
  local ps = rawget(s, 'proto_ids') or {}
  table.insert(ps, proto)
  rawset(s, 'proto_ids', ps)
end

-- create and return new entity with given id and no protos -- you really
-- should just use entity.create which ensures 'entity' is an rproto
function entity._create(id)
  -- id a string? make sure no clash, else find next numeric id
  if type(id) == 'string' then
    if entities[id] then
      error('entity with id ' .. id .. ' already exists!')
    end
  else
    id = entity._gen_uniq()
  end

  -- create and return entity
  local e = {
    _methods = {},
    id = id,
    proto_ids = {}, sub_ids = {}
  }
  setmetatable(e, entity.meta)
  entities[id] = e
  return e
end


-- 'entity' entity -------------------------------------------------------------

entity._create('entity')

-- immediately forget an entity and disconnect its sub/proto links -- remember
-- to call cont() (generally at end) while overriding!
function entities.entity.destroy(self, cont)
  -- remove from subs' list of proto_ids
  for sub_id in pairs(rawget(self, 'sub_ids')) do
    local ps = rawget(entity.get(sub_id), 'proto_ids')
    for i = 1, #ps do if ps[i] == self.id then table.remove(ps, i) end end
  end

  -- remove from protos' sets of sub_ids
  for _, proto_id in pairs(rawget(self, 'proto_ids')) do
    rawget(entity.get(proto_id), 'sub_ids')[self.id] = nil
  end

  entities[self.id] = nil
end

-- mark an entity to be destroyed on the next entities.entity:cleanup() call
entity._destroy_marks = { ord = {}, ids = {} }
function entities.entity.mark_destroy(self, cont)
  if not entity._destroy_marks.ids[self.id] then
    table.insert(entity._destroy_marks.ord, self.id)
    entity._destroy_marks.ids[self.id] = true
  end
end

-- destroy all entities marked with :mark_destroy() since last cleanup
function entities.entity.cleanup(self, cont)
  for _, id in ipairs(entity._destroy_marks.ord) do entity.get(id):destroy() end
  entity._destroy_marks = { ord = {}, ids = {} }
end

-- add entity with id proto_id as a proto
function entities.entity.add_proto_id(self, cont, proto_id)
  entity._link(self.id, proto_id, self)
end

-- return all subs, recursively, as a set
function entities.entity.rsubs(self, cont)
  local result = {}
  local function collect(e)
    for sub_id, _ in pairs(rawget(e, 'sub_ids') or {}) do
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
function entities.entity.to_string(self, cont)
  return '<entities[' .. self.id .. ']>'
end


-- entity creation utilities ---------------------------------------------------

-- create an entity with given ids of entities as proto_ids
function entity.create(proto_ids)
  return entity.create_named(nil, proto_ids)
end

-- create an entity with given string id, and given ids of entities as proto_ids
-- if name isn't a string, it is ignored (numeric id is generated)
function entity.create_named(name, proto_ids)
  if type(name) ~= 'string' then name = nil end
  local e = entity._create(name)
  if proto_ids then
    for _, proto in ipairs(proto_ids) do entity._link(e.id, proto, e) end
  end
  if #rawget(e, 'proto_ids') == 0 then
    entity._link(e.id, 'entity', e)
  end
  return e
end


-- save/load -------------------------------------------------------------------

-- save entities to a buffer -- ents must be an array of entities
function entity.save(ents)
  -- save everything except methods
  local keyallow = setmetatable({ _methods = false },
    { __index = function () return true end })
  return serpent.dump(ents, { keyallow = keyallow })
end

-- load entities from a buffer -- returns the array of entities as passed to
-- entity.save(...) to save the buffer
function entity.load(buf)
  local success, ents = serpent.load(buf)
  if not success then
    print('loading buffer failed: ')
    print(tostring(ents))
  end

  for _, ent in ipairs(ents) do
    if type(ent.id) ~= 'string' then
      setmetatable(ent.id, entity._uniq_meta)
    end
    rawset(ent, '_methods', {})

    -- if already exists with id, copy old methods, merge in old subs
    local old = entities[ent.id]
    if old then
      rawset(ent, '_methods', rawget(old, '_methods'))
      local ss = rawget(ent, 'sub_ids')
      for sub_id in pairs(rawget(old, 'sub_ids')) do
        ss[sub_id] = true
      end
    end

    -- merge into subs of existing entities as protos
    for _, proto_id in ipairs(rawget(ent, 'proto_ids')) do
      local p = entities[proto_id]
      if p then
        rawget(p, 'sub_ids')[ent.id] = true
      end
    end

    setmetatable(ent, entity.meta)
  end

  -- add to entity table
  for _, ent in ipairs(ents) do
    entities[ent.id] = ent
  end

  -- finally, remove inexistent subs and protos
  local warn = {}
  for _, ent in ipairs(ents) do
    local bad_ids = {}
    local ss = rawget(ent, 'sub_ids')
    for sub_id in pairs(ss) do
      if not entities[sub_id] then bad_ids[sub_id] = true end
    end
    for bad_id in pairs(bad_ids) do ss[bad_id] = nil end

    local pp = rawget(ent, 'proto_ids')
    for i = #pp, 1, -1 do
      if not entities[pp[i]] then
        warn[pp[i]] = true
        table.remove(pp, i)
      end
    end
  end
  for id in pairs(warn) do
    print("warning: couldn't find proto with id "
            .. entity.stringify_id(id) .. ", ignored")
  end

  return ents
end

-- save bunch of entities to a file, ents specified as in entity.save(...)
function entity.save_file(filename, ents)
  local f = assert(io.open(filename, 'w'))
  f:write(entity.save(ents))
  f:close()
end

-- load entities from a file -- returns the array of entities as passed to
-- entity.save_file(...) to save to the file
function entity.load_file(filename)
  local f = assert(io.open(filename, 'r'))
  local b = f:read('*a')
  f:close()
  return entity.load(b)
end


