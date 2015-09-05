bootstrap:add {
  _name = 'input',
  _protos = { 'entity' },
  [[
    rsubs of this may be notified of love input events:
      events are added using `input.register_events`
    ]],
}

bootstrap:add {
  _name = 'inputting',
  _protos = { 'input' },
  [[
    rsubs of this are notified of love keyboard, mouse and joystick button
    events:
      they respond by implementing `input.keypressed`, `input.keyreleased`,
      `input.mousepressed`, `input.mousereleased`, `input.joystickpressed` or
      `input.joystickreleased`, with parameters same as the love events
    ]]
}

function methods.input.register_events(self, cont, ...)
  for _, event in pairs({ ... }) do
    methods.input[event] = function (self, cont, ...) cont(...) end
    love[event] = function (...)
      for e in pairs(self:rsubs()) do e[event](e, ...) end
    end
  end
end

