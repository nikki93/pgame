-- rsubs of this respond to button input:
--   they respond by implementing `input.keypressed`, `input.keyreleased`,
--   `input.mousepressed`, `input.mousereleased`, `input.joystickpressed` or
--   `input.joystickreleased`, with parameters same as the love events
--
--   they are chosen for notification by the `input.inputting` slot, or for
--   individual devices by the `input.mousing`, `input.keyboarding` or
--   `input.joysticking` slots
--
-- todo:
--   remove individual device flags?

function bootstrap:input()
  self:depends('entity')
  return entity.adds {
    {
      _name = 'input',
      _protos = { 'entity' },

      inputting = false, -- if true, receive all input events
      mousing = false, -- if true, receive mouse events
      keyboarding = false, -- if true, receive keyboard events
      joysticking = false, -- if true, receive joystick events
    }
  }
end

input = {}

-- helper to tie input event propagation with love callbacks
function input.register_event(event, flag)
  -- default event method
  methods.input[event] = function (self, cont, ...) cont(...) end

  -- register love callback
  love[event] = function (...)
    if not entities.input then return end
    for e in pairs(entities.input:rsubs()) do
      if e.inputting or e[flag] then e[event](e, ...) end
    end
  end
end

input.register_event('keypressed', 'keyboarding')
input.register_event('keyreleased', 'keyboarding')

input.register_event('mousepressed', 'mousing')
input.register_event('mousereleased', 'mousing')

input.register_event('joystickpressed', 'joysticking')
input.register_event('joystickreleased', 'joysticking')

