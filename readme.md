in a world of actualities, not cloudy abstractions, work by example -- make an
example of the monster, then inherit -- a 'proto' -- and now the abstraction is
a tangible object that is manipulable as data in an editor 

another attempt at reducing creative friction between the artist and the artwork


ideas
-----

+ now (technical-ish):
    - entities are each slot-value mappings
    - each entity can ordered list multiple 'protos'
    - slots of e are looked up recursively in e's protos in order, depth first
    - methods can be combined by a lisp-like call-next-method or a python-like
      super() call

    - a proto of a proto of a ... proto is an 'rproto' (recursive)
    - if x is a proto of y, y is a sub of x
    - a sub of a sub of a ... sub is an 'rsub'
    - prevent confusion with transform or any other 'parent/child' hierarchy
      nomenclatures that coexist

    - each entity has a universally unique id generated at birth if unnamed, or
      is hashed an id from its 'name'
    - protos are referred to by id, so that names can change

    - selected groups of entities can be saved to an 'image'
    - entities can be loaded from images
    - loaded entities replace entites of the same id -- changes are visible in
      rsubs too!

    - 'built-in' entities are in-fact loaded from a 'boot image'
    - images usually created and saved interactively but can script it with
      'recipes' -- `cg.add { name = 'player', protos = { 'drawable' , ... } }`
      etc.
    - recipe and image format is actually the same (: homoiconicity! --
      human-readable code and image format basically same -- human-machine

+ future (philosophy-ish):
    - add slot metadata (docs, inspectability) etc. for ultimate dev experience
    - add vec2 and other basic math

    - create basic visual sprite entity
        - other basics handled by love
        - consider boilerplate requirements cgame had and obsolete them through
        good design
    - start really early on gui design so that interface evolves with abstract
      idea
    - try to get people to use it


how to play
-----------

Make sure you have [love2d](https://love2d.org/).

```
git clone https://github.com/nikki93/pgame
cd pgame
love .
```


