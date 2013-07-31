Brauhaus = require('brauhaus')
Diff = require('./lib/brauhaus-diff').configure({exportUtil: true})
helper = require('./test/helper/helper')

catVsCatTest = ->
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

hashTest = ->
    murmurJs = require('murmurhash').v3
    murmurC = require('murmurhash3').murmur32Sync
    murmurI = require('imurmurhash')
    crypto = require('crypto')
    md5 = (str) ->
        hash = crypto.createHash('md5')
        hash.update str
        hash.digest

    strings = []
    i = 10000
    while i--
        count = Math.floor(Math.random() * 50 + 5)
        bytes = crypto.pseudoRandomBytes count
        strings.push String.fromCharCode.apply(null, bytes)
        #strings.push(crypto.pseudoRandomBytes(count).toString())

    t = process.hrtime()
    i = 5000000
    while i--
        murmurC(strings[i % 10000]).toString(32)
    t = process.hrtime t
    console.log 'murmur (C):'
    console.log t

    t = process.hrtime()
    i = 5000000
    while i--
        murmurJs(strings[i % 10000]).toString(32)
    t = process.hrtime t
    console.log 'murmur (JS):'
    console.log t

    t = process.hrtime()
    i = 5000000
    while i--
        murmurI(strings[i % 10000]).result().toString(32)
    t = process.hrtime t
    console.log 'murmur (I):'
    console.log t

    # t = process.hrtime()
    # i = 5000000
    # while i--
    #     md5(strings[i % 10000]).toString(32)
    # console.log 'md5:'
    # console.log process.hrtime(t)

recipeTest = ->
    left = new Brauhaus.Recipe
        description: 'A recipe that makes little sense'
        boilSize: 12

    left.add 'fermentable',
        name: 'Test Fermentable'
        late: true
        yield: 70

    left.add 'fermentable',
        name: 'Other Fermentable'
        weight: 2.2

    left.add 'spice',
        name: 'Test spice'
        weight: 1
        time: 45
        use: 'smelt'

    left.add 'yeast',
        name: 'Yeast'
        form: 'solid'

    right = new Brauhaus.Recipe
        description: 'TODO'

    right.add 'fermentable',
        name: 'Other Fermentable'
        yield: 20

    right.add 'spice',
        name: 'Random spice'

    right.add 'yeast',
        name: 'Yeast'

    t = process.hrtime()
    i = 100000
    while i--
        Diff.diff left, right
    diff = process.hrtime t
    console.log 'Recipe Diff:'
    console.log diff
    console.log (100000 / (diff[1] / 1e9 + diff[0])) + ' per second'

    t = process.hrtime()
    i = 100000
    while i--
        Diff.util.hash left.fermentables[0]
        Diff.util.hash left.fermentables[1]
        Diff.util.hash left.spices[0]
        Diff.util.hash left.yeast[0]

        Diff.util.hash left.fermentables[0]
        Diff.util.hash left.spices[0]
        Diff.util.hash left.yeast[0]
    console.log 'Hash time:'
    console.log process.hrtime(t)

recipeTest()