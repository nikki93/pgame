-- enables event notification

function bootstrap.alive()
  entity.create_named('alive')

  entities.alive.updating = true
  entities.alive.drawing = true
end

