--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---
--- defines basic sub/proto logic and the entity 'entity' that is an rproto
--- for all entities, as detailed below:
---
---    - an entity is simply a table with entity.meta as its metatable, but
---      its best to use the entity creation utilities below which handle some
---      other bookkeeping
---    - entities can keep 'slots' which are named places for holding data --
---      these are simply key-value pairs in the entity table
---
---    - if x is a 'proto' of y then y is a 'sub' of x
---    - if x_1 is a proto of x_2 is a proto of ... is a proto of x_n, then
---      x_1 is an 'rproto' (recursive proto) of x_n
---    - if x_1 is a sub of x_2 is a sub of ... is a sub of x_n, then
---      x_1 is an 'rsub' of x_n
---    - no entity is an rproto or rsub of itself
---
---    - protos are maintained in an order
---    - slot access in x looks in x first, then recursively in protos depth
---      first in left-right order of protos
---    - slots can be 'methods' which are functions called with a 'self' and
---      a 'cont' argument, so that calling x:m(a, b, ...) results in a call
---      to x.m(x, cont, a, b, ...)
---        - self is the receiver of the method call
---        - cont is a function which, when called, calls the next method in
---          the method call chain defined in the same order as slot lookup
---
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local serpent = require('serpent')


-- namespace for all entity meta stuff
entity = {}

-- this table with store all entities that exist, so that entities[o.id] == o,
-- where o is an entity
entities = {}

-- same as entities[id], but error if not present
function entity.get(id)
  return assert(entities[id], 'no entity with id ' .. id)
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
      -- the continuation is a closure that iterates through the proto order
      -- the entrypoint is a wrapper that starts off the chain
      local function entrypoint(self, ...)
        local ord = entity._proto_order(self)
        local i = 0
        local function cont(...)
          while true do
            i = i + 1
            if i > #ord then return nil end
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

-- order in which protos are visited for methods, an array of objects (not ids)
-- the order is depth first and left to right in order of 'proto_ids' array,
-- with rprotos appearing only once
function entity._proto_order(e)
  local ord = {}
  local vis = {} -- set version of above

  local function visit(e)
    if not vis[e.id] then
      vis[e.id] = true
      table.insert(ord, e)
    end
    for _, proto_id in ipairs(rawget(e, 'proto_ids') or {}) do
      local p = entity.get(proto_id)
      visit(p)
    end
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

entity.next_id = 0
function entity._next_id()
  local id
  while entities[entity.next_id] ~= nil do
    entity.next_id = entity.next_id + 1
  end
  id = entity.next_id
  entity.next_id = entity.next_id + 1
  return id
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
    id = entity._next_id()
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

-- add entity with id proto_id as a proto
function entities.entity.add_proto_id(self, cont, proto_id)
  entity._link(self.id, proto_id, self)
end

-- return all sub ids, recursively, as a set
function entities.entity.rsub_ids(self, cont)
  local result = {}
  local function collect(e)
    for sub_id, _ in pairs(rawget(e, 'sub_ids') or {}) do
      if not result[sub_id] then
        result[sub_id] = true
        collect(entity.get(sub_id))
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

-- save a bunch of entities to a buffer -- ids can be a single id or an array
function entity.save(ids)
  if type(ids) ~= 'table' then ids = { ids } end
  -- save everything except methods
  local keyallow = setmetatable({ _methods = false },
    { __index = function () return true end })
  return serpent.dump(map(entity.get, ids), { keyallow = keyallow })
end

-- load entities from a buffer
function entity.load(buf)
  local success, ents = serpent.load(buf)
  if not success then
    print('loading buffer failed: ')
    print(tostring(ents))
  end

  for _, ent in ipairs(ents) do
    -- uniqify id -- TODO: do cgame-style deep id resolution
    if type(ent.id) ~= string then
      rawset(ent, 'id', entity._next_id())
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

  for _, ent in ipairs(ents) do
    entities[ent.id] = ent
  end
end


