-- has a physical position and rotation

function bootstrap.transform()
  entity.create_named('transform')

  entities.transform.position = { 10, 10 }
  entities.transform.rotation = 0
end

