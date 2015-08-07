-- entity ----------------------------------------------------------------------

entity = {}

-- table of id --> entity
entities = {}

-- metatable of all entities
entity.meta = {
  __index = function (o, k)
    local r

    -- check in o
    r = rawget(o, k)
    if r ~= nil then return r end

    -- check recursively in each proto
    for _, proto in ipairs(rawget(o, 'proto_ids')) do
      r = entities[proto]
      if r then r = r[k] end
      if r then return r end
    end
    return nil
  end,

  __newindex = function (o, k, v)
    -- function? create a cont-continuation
    if type(v) == 'function' then
      rawget(o, '_methods')[k] = v

      local f = function(self, ...)
        local ord = entity._proto_order(self)
        local i = 0

        local function cont(...)
          while true do
            i = i + 1
            if i > #ord then return nil end
            local pf = rawget(ord[i], '_methods')[k]
            if pf then return pf(self, cont, ...) end
          end
        end

        return cont(...)
      end
      rawset(o, k, f)
    else
      rawset(o, k, v)
    end
  end
}

-- order in which protos are visited for methods, an array of objects (not ids)
function entity._proto_order(e)
  local ord = {}
  local vis = {} -- set version of above

  local function visit(e)
    if not vis[e.id] then
      vis[e.id] = true
      table.insert(ord, e)
    end
    for _, proto_id in ipairs(rawget(e, 'proto_ids') or {}) do
      local p = entities[proto_id]
      if not p then error('no entity with id ' .. proto_id) end
      visit(p)
    end
  end
  visit(e)
  return ord
end

-- create a sub-proto relationship -- sub and proto are both entity ids
function entity.link(sub, proto)
  local p = entities[proto]
  if not p then error('no entity with id ' .. proto) end
  local s = entities[sub]
  if not s then error('no entity with id ' .. sub) end

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

-- internal: create and return new entity with given id and no protos
entity.next_id = 0
function entity._create(id)
  -- id a string? make sure no clash, else find next numeric id
  if type(id) == 'string' then
    if entities[id] then
      error('entity with id ' .. id .. ' already exists!')
    end
  else
    while entities[entity.next_id] ~= nil do
      entity.next_id = entity.next_id + 1
    end
    id = entity.next_id
    entity.next_id = entity.next_id + 1
  end

  -- create and return entity
  local e = {
    _methods = {},
    id = id,
    proto_ids = {}, sub_ids = {},
    alive = false
  }
  setmetatable(e, entity.meta)
  entities[id] = e
  return e
end


-- the base entity
entity._create('entity')

-- convenience message to add a proto
function entities.entity.add_proto_id(self, cont, proto_id)
  entity.link(self.id, proto_id)
end

-- return all sub ids, recursively, as a set
function entities.entity.rsub_ids(self, cont)
  local result = {}
  local function collect(e)
    for sub_id, _ in pairs(rawget(e, 'sub_ids') or {}) do
      if not result[sub_id] then
        result[sub_id] = true
        collect(entities[sub_id] or error('no entity with id ' .. sub_id))
      end
    end
  end
  collect(self)
  return result
end

-- entities can be flagged as 'live' or not -- only live ones respond to events
-- this property isn't inherited
function entities.entity.live(self, cont, set)
  if set ~= nil then
    rawset(self, 'alive', set)
    return set
  end
  return rawget(self, 'alive')
end


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
    for _, proto in ipairs(proto_ids) do entity.link(e.id, proto) end
  end
  if #rawget(e, 'proto_ids') == 0 then
    entity.link(e.id, 'entity')
  end
  return e
end


-- basic entities --------------------------------------------------------------

-- update

entity.create_named('update')

function entities.update.update(self, cont, dt) end

function entities.update.update_rsubs(self, cont, dt)
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e:live() then e:update(dt) end
  end
end


-- transform

entity.create_named('transform')

entities.transform.position = { 10, 10 }
entities.transform.rotation = 0


-- drawable

entity.create_named('drawable')

function entities.drawable.draw(self, cont) end

function entities.drawable.draw_rsubs(self, cont)
  for e in pairs(self:rsub_ids()) do
    local e = entities[e]
    if e:live() then e:draw() end
  end
end


-- rotator

entity.create_named('rotator', { 'update', 'transform' })

entities.rotator.rotation_speed = 30

function entities.rotator.update(self, cont, dt)
  cont(dt)
  self.rotation = self.rotation + self.rotation_speed * dt
end


-- player

entity.create_named('player', { 'drawable', 'transform' })

function entities.player.update(self, cont, dt)
  cont(dt)
  self.position = { self.position[1] + 20 * dt, self.position[2] }
end

function entities.player.draw(self, cont)
  cont()
  love.graphics.push()
  love.graphics.translate(unpack(self.position))
  love.graphics.rotate(self.rotation)
  love.graphics.print("<player>", 0, 0)
  love.graphics.pop()
end


-- main events -----------------------------------------------------------------

require('scratch')

function love.load()
  love.window.setMode(800, 600, { x = 629, y = 56 })
  scratch.load()
end

function love.update(dt)
  scratch.update()
  entities.update:update_rsubs(dt)
end

the_player = entity.create({ 'player', 'rotator' })
the_player:live(true)

function love.draw()
  love.graphics.print("Hello World", 20, 300)
  entities.drawable:draw_rsubs()
end


-- run -------------------------------------------------------------------------

local function safe_call(f)
  local succ, err = xpcall(f, debug.traceback)
  if not succ then
    print(err)
  end
end

function love.run()
	if love.math then
		love.math.setRandomSeed(os.time())
		for i=1,3 do love.math.random() end
	end
 
	if love.event then love.event.pump() end
 
	if love.load then love.load(arg) end
 
	-- we don't want the first frame's dt to include time taken by love.load
	if love.timer then love.timer.step() end
 
	local dt = 0
 
	-- main loop
	while true do
		-- process events
		if love.event then
			love.event.pump()
			for e,a,b,c,d in love.event.poll() do
				if e == "quit" then
					if not love.quit or not love.quit() then
						if love.audio then
							love.audio.stop()
						end
						return
					end
				end
        safe_call(function () love.handlers[e](a,b,c,d) end)
      end
		end
 
		-- calculate dt
		if love.timer then
			love.timer.step()
			dt = love.timer.getDelta()
		end
 
		-- update, draw
		if love.update then
      safe_call(function () love.update(dt) end)
    end -- 0 if love.timer is disabled
 
		if love.window and love.graphics and love.window.isCreated() then
			love.graphics.clear()
			love.graphics.origin()
      if love.draw then
        safe_call(love.draw)
      end
			love.graphics.present()
		end
 
		if love.timer then love.timer.sleep(0.001) end
	end
end

