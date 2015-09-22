-- rudimentary entity logic

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
    error("no entity with id '" .. tostring(id) .. "'")
  end
  return e
end

-- this table refers to named entities by name, so that entities[o._name] == o,
-- where o is an entity with a name
entities = {}


-- slots -----------------------------------------------------------------------

-- slot descriptors
--
-- a slot descriptor can be used as a slot value in entity descriptors
--
-- slot descriptors are created using the 'entity.slot' function -- for example:
--
--   my_ent = cg.add {
--     _name = 'test', _protos = { 'entity' },
--     my_slot = entity.slot { 42, DOC[[ my doc ]], saveload = true, ... }
--   }
--
-- here 'my_slot' is given a value of 42, with metadata 'doc' set to "my doc ",
-- 'saveload' set to true, and possibly other metadata defined in the elipsis
--
-- in general the form is entity.slot t, where t is a table of the form { value,
-- doc, m1 = v1, m2 = v2, ... } where 'value' is the value of the slot, 'doc' is
-- the doc string and (m1, v1), (m2, v2), ... are the metadata associations

entity._slot_desc_meta = {}

function entity.slot(desc)
  if not desc.doc then desc.doc = desc[2] end
  desc[2] = nil
  if desc.doc then desc.doc = desc.doc:claim() end
  return setmetatable(desc, entity._slot_desc_meta)
end


-- metatable -------------------------------------------------------------------

entity._meta = {}

-- lookup slot 'k' in entity 'o' -- ignores getter method, because otherwise you
-- get an infinite blowup of 'get_x' then 'get_get_x' and so on -- getter
-- methods should be handled in the caller of _get_slot(...) if required
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

-- slot lookup entrypoint
function entity._meta.__index(o, k)
  local r = _get_slot(o, k)
  if r then return r end

  -- try getter method
  r = _get_slot(o, 'get_' .. k)
  if r ~= nil then return r(o) end
end

-- /reverse/ of order in which protos are visited for methods, an array of
-- entities -- the order is the reverse of the topological sort order, so that
-- entities appear after all their protos and ties are broken in right-left
-- order of _proto_ids list
local function _proto_order(e)
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

-- slot definition entrypoint -- lua calls this on defining a new key
function entity._meta.__newindex(o, k, v)
  -- try setter method
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
        local ord = _proto_order(self)
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
      return -- don't actually set the value, force __newindex every time
    elseif v == nil then -- removing a method?
      rawget(o, '_methods')[k] = nil
    end
  end

  return rawset(o, k, v)
end

-- called by lua on automatic string conversion -- we just call the
-- entity's ':to_string()' method
function entity._meta.__tostring(o)
  return o:to_string()
end

-- serpent uses this to ask if key and value for key 'k' should be saved on
-- serialization -- we just check the slot's 'saveload' metadata
function entity._meta.__keyallow(o, k)
  local meta_k = o:slot_meta(k)
  return not (meta_k and meta_k.saveload == false)
end


-- add/remove ------------------------------------------------------------------

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
-- for example: 
--   my_ent = cg.add {
--     _name = 'test',
--     _protos = { 'entity', 'another_proto' },
--     my_slot = entity.slot { 42, DOC[[ my doc ]], saveload = true, ... }
--   }
--
-- replaces the existing with the same name or id if exists
function entity.add(t)
  ent = {}

  -- we try to do as much as possible in the :add() method, but to even call
  -- that method correctly we need to set up proto links and link with the
  -- metatable

  -- generate id -- hash of name or seed, new uuid if neither
  if t._id then
    ent._id = t._id
  else
    local seed = t._id_seed or t._name_ or t._name
    ent._id = (seed and md5.sumhexa(seed) or uuid()):sub(1, 21)
  end
  t._id_seed = nil
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
  and next(ent._proto_ids) == nil then
    -- ensure `entity` rproto if _protos not explicitly empty
    table.insert(ent._proto_ids, entities.entity._id)
  end
  t._protos = nil

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

  -- set metatable and put in id table -- methods are available after this
  setmetatable(ent, entity._meta)
  entity._ids[ent._id] = ent

  -- finally, call :add() method
  local add_method = ent.add
  if add_method then add_method(ent, t, old) end
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

entity._method_registry_meta = {}

-- the method registry (global 'methods') is a special table such that
-- 'methods.x' gets or creates the method registry entry for 'x' -- a method
-- registry entry is an entity that only has methods as slots, and can be added
-- as a proto to any other entity to endow it with those methods
--
-- this allows convenient method definition syntax:
--   function methods.my_entity.my_method(self, cont, ...)
--     ...
--   end
-- then 'methods.my_entity' can be added as a proto for any entity to give it
-- the method 'my_method' -- this gets around method serialization awkwardness
-- because methods can simply be defined in scripts, and it allows live
-- editing/deletion of methods

-- get or create a method registry entry
function entity._method_registry_meta.__index(o, k)
  -- already created?
  local entry = o._entries[k]
  if entry then return entry end

  -- create a new one -- no protos!
  entry = entity.add {
    _name = 'methods_' .. k,
    _protos = { 'entity' },
    _methods = {}, -- this will store the methods
  }
  o._entries[k] = entry
  return entry
end

-- update a method registry entry -- deletes the entry if v is nil
function entity._method_registry_meta.__newindex(o, k, v)
  if v == nil then
    -- destroying a method registry entry
    local entry = o._entries[k]
    if entry then entry:destroy() end
    return
  end
  rawset(o, k, v)
end

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


-- base entity -----------------------------------------------------------------

-- `entity` is its own methods registry entry -- this is needed to properly
-- bootstrap method handling

entity._entity_desc = {
  _name_ = 'entity', -- need to directly set _name_, no :set__name() method yet
  _id_seed = 'entity',
  _protos = {},
  _methods = {}, -- make this a method registry entry

  meta__sub_ids = { saveload = false },
}

-- entity.add(...) won't copy the slots from the descriptor yet here because the
-- :add() method hasn't been defined -- will call it manually below after
-- defining
entities.entity = entity.add(entity._entity_desc)
methods.entity = entities.entity


-- need to associate add method after setting slots (so that '_methods' etc. is
-- set), so have to do it in this weird way to bootstrap

DOC[[ called when an entity is added, with 'desc' being the entity descriptor
      table and 'old' the previously existing entity with same id that is being
      replaced (if one exists)

      the `entity` implementation of this method does some basic things like
      setting up name lookup and setting slots from 'desc', so remember to call
      cont() (generally in the beginning) when overriding -- before calling
      cont(), slots haven't been copied from 'desc' yet ]]
function entity._entity_add(self, cont, desc, old)
  -- associate in name map, disocciate old
  self._name_ = desc._name_
  if self._name_ ~= nil then entities[self._name_] = ent end
  if old then
    local old_name = old._name_
    if old_name and old_name ~= name then entities[old_name] = nil end
  end

  -- set slots
  for k, v in pairs(desc) do
    if k == 1 then ent._doc = v:claim() -- shortcut for doc
    else ent[k] = v end
  end
end
entity._entity_add(entities.entity, function () end, entity._entity_desc, nil)
methods.entity.add = entity._entity_add


DOC[[ get the entity's name ]]
function methods.entity.get__name(self, cont)
  return self._name_
end

DOC[[ set the entity's name ]]
function methods.entity.set__name(self, cont, name)
  -- disocciate old name, associate new one
  local old_name = self._name_
  if old_name ~= nil and old_name ~= name then entities[old_name] = nil end
  self._name_ = name
  if name ~= nil then entities[name] = self end
end

DOC[[ add 'proto' as a proto of self, at index i of the proto list if specified
      or at the end otherwise, does nothing if already a proto of self ]]
function methods.entity.add_proto(self, cont, proto, i)
  rawget(proto, '_sub_ids')[self._id] = true
  local pp = rawget(self, '_proto_ids')
  for _, proto_id in ipairs(pp) do
    if proto._id == proto_id then return end
  end
  table.insert(pp, i or #pp + 1, proto._id)
end

DOC[[ remove 'proto' as a proto of self, does nothing if not already a proto of
      self ]]
function methods.entity.remove_proto(self, cont, proto)
  rawget(proto, '_sub_ids')[self._id] = nil
  local pp = rawget(self, '_proto_ids')
  for i = 1, #pp do
    if pp[i] == proto._id then
      table.remove(pp, i)
    end
  end
end

DOC[[ return all subs, recursively, as a set ]]
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


DOC[[ immediately forget an entity and disconnect its sub/proto links

      the `entity` implementation of this method does some basic things, like
      dissociating the entity from name lookup and disconnecting from
      protos/subs, so make sure to call cont() (generally at the end) when
      overriding! ]]
function methods.entity.destroy(self, cont)
  -- remove from subs' list of _proto_ids
  for sub_id in pairs(rawget(self, '_sub_ids')) do
    local ps = rawget(entity.get(sub_id), '_proto_ids')
    for i = #ps, 1, -1 do if ps[i] == self._id then table.remove(ps, i) end end
  end

  -- remove from protos' sets of _sub_ids
  for _, proto_id in pairs(rawget(self, '_proto_ids')) do
    rawget(entity.get(proto_id), '_sub_ids')[self._id] = nil
  end

  -- disociate id, name
  entity._ids[self._id] = nil
  local name = self._name
  if name then entities[name] = nil end
end

entity._destroy_marks = { ord = {}, ids = {} }

DOC[[ mark an entity to be destroyed on the next `entity.cleanup` call (next
      frame update by default) ]]
function methods.entity.mark_destroy(self, cont)
  if not entity._destroy_marks.ids[self._id] then
    table.insert(entity._destroy_marks.ord, self._id)
    entity._destroy_marks.ids[self._id] = true
  end
end

DOC[[ destroy all entities marked with `entity.mark_destroy` ]]
function methods.entity.cleanup(self, cont)
  for _, id in ipairs(entity._destroy_marks.ord) do entity.get(id):destroy() end
  entity._destroy_marks = { ord = {}, ids = {} }
end


DOC[[ called on string conversion with tostring(self) ]]
function methods.entity.to_string(self, cont)
  return '<ent:' .. (self._name or self._id) .. '>'
end


DOC[[ get metadata for slot named slotname, nil if not found ]]
function methods.entity.slot_meta(self, cont, slotname)
  return self['meta_' .. slotname]
end

DOC[[ shortcut for self:slot_meta(slotname).doc, nil if no slot metadata ]]
function methods.entity.slot_doc(self, cont, slotname)
  local m = self:slot_meta(slotname)
  if m then return m.doc end
end


