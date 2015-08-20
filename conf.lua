function love.conf(t)
  -- options for love-release
  t.identity = nil
  t.version = "0.9.2"
  t.game_version = nil
  t.icon = nil
  t.console = false

  t.title = "pgame"
  t.author = "unknown"
  t.email = nil
  t.url = nil
  t.description = nil

  t.os = {
    "love",
    windows = {
      x32       = true,
      x64       = true,
      installer = false,
      appid     = nil,
    },
    "osx"
  }

  -- options for love
  t.window.title = "pgame"
  t.window.width = 800
  t.window.height = 600
  t.window.x = 629
  t.window.y = 56
end
