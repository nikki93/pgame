-- continuously checks the given file for modification and runs lua code in it
-- when modified -- can be used to 'eval' from text editors

entity.create_named('scratch', { 'update' })

entities.scratch.updating = true
entities.scratch.file_path = 'scratch-buf.lua'
entities.scratch.last_existed
  = love.filesystem.exists(entities.scratch.file_path)
entities.scratch.last_modified = entities.scratch.last_existed
  and love.filesystem.getLastModified(entities.scratch.file_path)

function entities.scratch.update(self, cont, dt)
  if love.filesystem.exists(self.file_path) then
    local modified = love.filesystem.getLastModified(self.file_path)
    if not self.last_existed or self.last_modified < modified then
      self.last_existed = true
      self.last_modified = modified
      success, chunk = pcall(love.filesystem.load, self.file_path)
      if not success then
        print('loading scratch failed: ')
        print(tostring(chunk))
      else
        ok, err = xpcall(chunk, debug.traceback)
        if not ok then print(err) end
      end
    end
  end
end

