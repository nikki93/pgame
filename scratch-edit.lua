# scratch buffer with quick tests to eval

entity.link(the_player, 'rotator')

entities[the_player].position = { 200, 200 }

entities[the_player].rotation_speed = -5

the_other_player = entity.create({ 'player' })

entities[the_other_player].alive = true

entities[the_other_player].rotation_speed = 3


entity.link(the_other_player, 'rotator')

