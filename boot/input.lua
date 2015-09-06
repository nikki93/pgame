bootstrap:add {
  [[ may be notified of input events

     rsubs of this may be notified of love input events:
       events are added using `input.register_events` ]],

  _name = 'input',
  _protos = { 'entity' },
}

bootstrap:add {
  [[ is notified of input events

     rsubs of this are notified of love keyboard, mouse and joystick button
     events:
       they respond by implementing `input.keypressed`, `input.keyreleased`,
       `input.mousepressed`, `input.mousereleased`, `input.joystickpressed` or
       `input.joystickreleased`, with parameters same as the love events ]],

  _name = 'inputting',
  _protos = { 'input' },
}

function methods.input.register_events(self, cont, ...)
  for _, event in pairs({ ... }) do
    methods.input[event] = function (self, cont, ...) cont(...) end
    love[event] = function (...)
      for e in pairs(self:rsubs()) do e[event](e, ...) end
    end
  end
end

