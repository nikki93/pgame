bootstrap:add {
  _name = 'entity',
  _protos = { methods.entity },

  meta__sub_ids = { saveload = false },
}

DOC[[ get the entity's name ]]
function methods.entity.get_name(self, cont)
  return self._name
end

DOC[[ set the entity's name ]]
function methods.entity.set_name(self, cont, name)
  local old_name = self:get_name()
  if old_name ~= nil and old_name ~= name then entities[old_name] = nil end

  self._name = name
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


DOC[[ immediately forget an entity and disconnect its sub/proto links, remember
      to call cont() (generally at end) while overriding! ]]
function methods.entity.destroy(self, cont)
  entity.remove(self)
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
  return '<ent:' .. (self:get_name() or self._id) .. '>'
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



