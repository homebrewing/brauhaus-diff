Diff = require('./lib/brauhaus-diff').configure({exportUtil: true})
helper = require('./test/helper/helper')

c1 = helper.c1
c2 = helper.c2
c3 = helper.c3
c4 = helper.c4
c5 = new helper.C 2, 1, 2
c6 = new helper.C 2, 2, 2
c7 = new helper.C 3, 1, 4
c8 = new helper.C 1, 3, 2

oad = Diff.util.ObjectArrayDiff
duc = Diff.util.Category

expected = [[c6, c6], [c2, c2], [c7, c1], [c3, c5]]
left = null
right = null

setup = ->
    helper.C.setKeys [['a', 'b'], 'c']
    helper.uncache c5, c6, c7, c8
    left = duc.categorize [c3, c7, c6, c2]
    right = duc.categorize [c1, c2, c5, c4, c8, c6]

setup2 = ->
    helper.C.setKeys ['a', 'b', 'c']
    left = Diff.util.Category.categorize [c4, c1, c3, c2]
    right = Diff.util.Category.categorize [c3, c4, c4]

cvc2 = ->
    oad.catVsCatSecondPass left, right, -1

cvc = ->
    oad.catVsCat left, right, -1, true

t = process.hrtime()
i = 100000
while i--
    setup()
    cvc()
console.log 'catVsCat:'
console.log process.hrtime(t)

t = process.hrtime()
i = 100000
while i--
    setup()
    cvc2()
console.log 'catVsCatSecondPass:'
console.log process.hrtime(t)
