-- for scripting the initial entity loadout for the boot image

bootstrap = {}

-- the steps in order, in form { name = step name, f = function to run }
bootstrap._steps = {}

-- reboot and save to file -- warning: destroys all existing entities!
function bootstrap.boot_and_save(filename)
  -- destroy all
  if entities.entity then
    for e in pairs(entities.entity:rsubs()) do e:destroy() end
    entities.entity:destroy()
  end

  -- boot
  print('booting...')
  for _, step in ipairs(bootstrap._steps) do
    print("running step '" .. step.name .. "'")
    step.f()
  end
  print("done!")

  -- save
  if not filename then return end
  print("saving to '" .. filename .. "'")
  local all_ents = {}
  for _, ent in pairs(entity._ids) do table.insert(all_ents, ent) end
  entity.save_file(filename, all_ents)
end

-- allows adding functions using function bootstrap.stepname() ... end
-- adds a step with given name, or overwrites the previous one of same name
local bootstrap_meta = {
  __newindex = function (_, stepname, f)
    for _, step in ipairs(bootstrap._steps) do
      if step.name == stepname then
        step.f = f
        break
      end
    end
    table.insert(bootstrap._steps, { name = stepname, f = f })
  end
}
setmetatable(bootstrap, bootstrap_meta)

