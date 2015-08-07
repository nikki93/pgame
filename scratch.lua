scratch = {}

scratch.path = 'scratch-buf.lua'

function scratch.load()
  scratch.last_existed = love.filesystem.exists(scratch.path)
  scratch.last_modified = scratch.last_existed
    and love.filesystem.getLastModified(scratch.path)
end

function scratch.update()
  if love.filesystem.exists(scratch.path) then
    local modified = love.filesystem.getLastModified(scratch.path)
    if not scratch.last_existed or scratch.last_modified < modified then
      scratch.last_existed = true
      scratch.last_modified = modified
      success, chunk = pcall(love.filesystem.load, scratch.path)
      if not success then
        print('loading scratch failed: ')
        print(tostring(chunk))
      else
        ok, err = xpcall(chunk, debug.traceback)
      end
    end
  end
end

