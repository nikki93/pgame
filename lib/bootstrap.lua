-- for scripting the initial entity loadout for the boot image

bootstrap = {}

-- map of stepname -> function to call
bootstrap._steps = {}

-- whether a step has been visited
bootstrap._visited = {}

-- do one step of the bootstrap
function bootstrap._visit(stepname)
  if bootstrap._visited[stepname] then return end
  bootstrap._visited[stepname] = true
  bootstrap._steps[stepname]()
  print("finished boot step '" .. stepname .. "'")
end

-- force execution of bootstrap steps -- use this to indicate dependencies
function bootstrap.require(...)
  for _, stepname in ipairs({ ... }) do
    bootstrap._visit(stepname)
  end
end

-- reboot the system, and if filename is given, immediately save image to file
-- warning: destroys all existing entities!
function bootstrap.boot(filename)
  print('booting...')
  bootstrap._visit('entity') -- always run 'entity' first
  for name in pairs(bootstrap._steps) do
    bootstrap._visit(name)
  end
  print('done!')

  if filename then
    print("saving to '" .. filename .. "'")
    local all_ents = {}
    for _, ent in pairs(entity._ids) do table.insert(all_ents, ent) end
    entity.save_file(filename, all_ents)
  end
end

-- allows adding functions using function bootstrap.stepname() ... end
-- adds a step with given name, or overwrites the previous one of same name
local bootstrap_meta = {
  __newindex = function (_, stepname, f)
    bootstrap._steps[stepname] = f
  end
}
setmetatable(bootstrap, bootstrap_meta)

