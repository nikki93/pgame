-- continuously checks the given file for modification and runs lua code in it
-- when modified -- can be used to 'eval' from text editors

scratch = {}

scratch.path = 'scratch-buf.lua'

scratch.last_existed = love.filesystem.exists(scratch.path)
scratch.last_modified = scratch.last_existed
  and love.filesystem.getLastModified(scratch.path)

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
        chunk()
      end
    end
  end
end

