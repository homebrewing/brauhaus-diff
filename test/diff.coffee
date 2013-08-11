Brauhaus = @Brauhaus ? require 'brauhaus'
Diff = Brauhaus.Diff ? require('../lib/brauhaus-diff')
Diff.configure({exportUtil: true})
assert = assert ? require 'assert'

helper = helper ? require './helper/helper'

c1 = helper.c1
c2 = helper.c2
c3 = helper.c3
c4 = helper.c4

od = Diff.util.ObjectDiff
oad = Diff.util.ObjectArrayDiff

hash = Diff.util.hash

comparePairs = (left, right) ->
    comp = (l, r) ->
        for pl in l
            found = false
            for pr in r
                if pl[0] is pr[0] and pl[1] is pr[1]
                    found = true
                    break
            return false if not found
        true
    comp(left, right) and comp(right, left)

cat = (o, lev) -> new Diff.util.Category null, null, o, lev ? -1
vd = (left, right) -> new Diff.util.ValueDiff left, right

# Chai assert actual checks type, so we need to make the real deal
makeOd = (params) ->
    expected = new od
    expected[key] = val for key, val of params
    expected

makeOad = (arr) ->
    expected = new oad
    expected.diff = arr
    expected

describe 'Configuration', ->
    it 'Should be able to disable postDiff and postApply', ->
        class F
            constructor: (@x, @y) ->

            postDiff: (left, right, diff, options) ->
                throw new Error 'this should not happen'

            postApply: (obj, diff, options) ->
                throw new Error 'this should not happen'

        left = new F(1, 2)
        right = new F(2, 2)

        Diff.configure
            enablePostDiff: false
            enablePostApply: false

        assert.doesNotThrow (-> Diff.diff left, right)
        assert.doesNotThrow (-> Diff.apply left, Diff.diff(left, right))

        Diff.configure
            enablePostDiff: true
            enablePostApply: true

        assert.throws (-> Diff.diff left, right), 'this should not happen'
        assert.throws (-> Diff.apply left, Diff.diff(left, right)), 'this should not happen'

        options =
            enablePostDiff: false
            enablePostApply: false

        assert.doesNotThrow (-> Diff.diff left, right, options)
        assert.doesNotThrow (-> Diff.apply left, Diff.diff(left, right, options), options)


describe 'ValueDiff', ->
    it 'Should return an array from toJSON', ->
        assert.ok vd(1, 2).toJSON() instanceof Array

    it 'Should shallow copy objects', ->
        left = {a: 1}
        right = {b: 2, _c: 3}
        x = vd left, right
        assert.deepEqual x.left, left
        assert.notEqual x.left, left
        assert.notDeepEqual x.right, right
        assert.deepEqual x.right, {b: 2}

    describe 'apply', ->
        it 'Should work forward and backward (default)', ->
            diff = vd 1, 2
            assert.equal diff.apply(1), 2
            assert.equal diff.apply(1, direction: 'b'), 2
            assert.equal diff.apply(2, direction: 'f'), 1

        it 'Should return a value of type if requested', ->
            class F
                constructor: (@v) ->

            options =
                direction: 'b'
                fail: false

            diff = vd 1, 2
            assert.ok diff.apply(1, options, F) instanceof F
            assert.equal diff.apply(1, options, F).v, 2

            options.direction = 'f'
            assert.equal diff.apply(2, options, F).v, 1

        it 'Should throw an exception for inconsistent input', ->
            diff = vd 1, 2
            assert.throws (-> diff.apply 2), Error
            assert.doesNotThrow (-> diff.apply 1)

describe 'ObjectDiff', ->
    it 'Should support simple values', ->
        left = {a: 1, b: 2}
        right = {a: 1, b: 3}

        assert.deepEqual new od(left, right), makeOd({b: vd(2, 3)})

        left.a = 'test'
        right.a = 'asd'
        right.b = 2
        assert.deepEqual new od(left, right), makeOd({a: vd('test', 'asd')})

        left.a = false
        right.a = true
        assert.deepEqual new od(left, right), makeOd({a: vd(false, true)})

        left.a = null
        assert.deepEqual new od(left, right), makeOd({a: vd(null, true)})

        left.a = 1
        right.a = null
        assert.deepEqual new od(left, right), makeOd({a: vd(1, null)})

    it 'Should support adding and removing keys', ->
        left = {a: 1, b: 2, c: 3}
        right = {a: 1, b: 1, d: 4, e: 5}

        assert.deepEqual new od(left, right), makeOd({b: vd(2, 1), c: vd(3, null), d: vd(null, 4), e: vd(null, 5)})

    it 'Should ignore functions and private keys', ->
        left = {a: 1, _b: 2, c: -> true}
        right = {a: 2, _b: 3, c: 1}

        assert.deepEqual new od(left, right), makeOd({a: vd(1, 2), c: vd(null, 1)})

    it 'Should use toJSON if available', ->
        left = {a: 1, b: 2, toJSON: -> {@a}}
        right = {a: 2, b: 3, toJSON: -> {@a}}

        assert.deepEqual new od(left, right), makeOd({a: vd(1, 2)})

    it 'Should support sub-objects', ->
        left =
            a: 1
            b:
                x: 1
                y: 2

        right = 
            a: 2
            b:
                x: 2
                y: 2
                z: 2

        expected =
            a: vd(1, 2)
            b: makeOd(
                x: vd(1, 2)
                z: vd(null, 2))

        assert.deepEqual new od(left, right), makeOd(expected)

    it 'Should support sub-arrays', ->
        left = {a: 1, b: [1, 2], c: [c1, c2, c3]}
        right = {a: 2, b: [1, 1], c: [c1, c4]}

        expected =
            a: vd 1, 2
            b: makeOd(1: vd 2, 1)
            c: makeOad([{
                a: 2
                b: 2
                c: 1
                _h: vd(hash(c3), null) }])

        assert.deepEqual new od(left, right), makeOd(expected)

    it 'Should be convertible from a regular object', ->
        left = {a: 1, b: 2}
        right = {a: 2, b: 3}
        obj = {a: [1, 2], b: [2, 3]}
        assert.deepEqual new od(left, right), od.fromObject(obj)

    describe 'apply', ->
        it 'Should work forward and backward (default)', ->
            diff = new od {a: 1}, {a: 2}
            assert.deepEqual diff.apply({a: 1}), {a: 2}
            assert.deepEqual diff.apply({a: 1}, direction: 'b'), {a: 2}
            assert.deepEqual diff.apply({a: 2}, direction: 'f'), {a: 1}

        it 'Should return a value of type if requested', ->
            class F
                constructor: (@v) ->

            options =
                direction: 'b'
                fail: false

            diff = new od {a: 1}, {a: 2}
            assert.ok diff.apply({a: 1}, options, F) instanceof F
            assert.deepEqual diff.apply({a: 1}, options, F).v, {a: 2}

            options.direction = 'f'
            assert.deepEqual diff.apply({a: 2}, options, F).v, {a: 1}

        it 'Should throw an exception for inconsistent input', ->
            diff = new od {a: 1}, {a: 2}
            assert.throws (-> diff.apply 2), Error
            assert.throws (-> diff.apply {a: 2}), Error
            assert.throws (-> diff.apply {x: 'test'}), Error
            assert.doesNotThrow (-> diff.apply {a: 1})

            class F
                constructor: (@x, @y) ->
                _diffKeys: ['x', 'y']

            diff = new od {a: [new F(1, 1), new F(2, 1)]}, {a: [new F(2, 1), new F(1, 2)]}
            assert.throws (-> diff.apply {a: 1}), Error

        it 'Should use _paramMap to set the type for sub-objects', ->
            class Y
                constructor: (y) ->
                    @[key] = val for own key, val of y

            class F
                constructor: (@obj) ->
                _paramMap: 'obj': Y

            diff = new od {obj: 1, x: 2}, {obj: {y: 2}, x: 3}
            f = new F(1)
            f.x = 2
            r = null
            assert.doesNotThrow (-> r = diff.apply f)
            assert.ok r.obj instanceof Y, JSON.stringify(f.obj)
            assert.equal r.obj.y, 2
            assert.equal r.x, 3, '3'

describe 'ObjectArrayDiff', ->
    describe 'toJSON', ->
        d = new oad([c1, c2], [c1, c3]).toJSON()
        it 'Should return an array', ->
            assert.ok d instanceof Array
            assert.ok (new oad).toJSON() instanceof Array

        it 'Should have "_h" subkey on elements', ->
            for obj in d
                assert.ok obj._h?

    describe 'bestMatch', ->
        it 'Should get an exact match where possible', ->
            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.equal oad.bestMatch(c2, root.obj, 0), c2
            assert.equal oad.bestMatch(c1, root.obj[0].obj, 1), c1

            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.equal oad.bestMatch(c2, root.obj, 0), c2

            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.equal oad.bestMatch(c3, root.obj, 0), c3

            # Switch to complex keys
            helper.C.setKeys [['a', 'b'], 'c']
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.equal oad.bestMatch(c1, root.obj, 0), c1
            assert.equal oad.bestMatch(c4, root.obj[0].obj, 1), c2
            assert.equal oad.bestMatch(c2, root.obj[0].obj[1].obj, 2), c2
            helper.C.setKeys ['a', 'b', 'c']

        it 'Should return the first choice for non-unique, exact matches', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.equal oad.bestMatch(c4, root.obj, 0), c2

            helper.C.setKeys [['a', 'b'], 'c']
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.equal oad.bestMatch(c1, root.obj, 0), c1
            assert.equal oad.bestMatch(c4, root.obj[0].obj, 1), c2
            assert.equal oad.bestMatch(c2, root.obj[0].obj[1].obj, 2), c2
            helper.C.setKeys ['a', 'b', 'c']

        it 'Should return the best match for simple keys', ->
            obj1 = new helper.C 2, 1, 1
            obj2 = new helper.C 1, 1, 3
            obj3 = new helper.C 2, 1, 2

            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.equal oad.bestMatch(obj1, root.obj, 0), c3
            assert.equal oad.bestMatch(obj2, root.obj, 0), c1
            assert.equal oad.bestMatch(obj1, root.obj[0].obj, 1), c1
            assert.equal oad.bestMatch(obj3, root.obj[0].obj, 1), c2

            root = Diff.util.Category.categorize [c1, c2, c4]
            assert.equal oad.bestMatch(obj1, root.obj, 0), c1
            assert.equal oad.bestMatch(obj2, root.obj, 0), c1
            assert.equal oad.bestMatch(obj3, root.obj, 0), c2

        it 'Should return the best match for complex keys', ->
            # Switch to complex keys
            helper.C.setKeys [['a', 'b'], 'c']
            obj1 = new helper.C 2, 1, 1
            obj2 = new helper.C 1, 1, 3
            obj3 = new helper.C 2, 1, 2
            obj4 = new helper.C 3, 2, 3

            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.equal oad.bestMatch(obj1, root.obj, 0), c1
            assert.equal oad.bestMatch(obj2, root.obj, 0), c1
            assert.equal oad.bestMatch(obj4, root.obj, 0), c3
            assert.equal oad.bestMatch(obj1, root.obj[0].obj, 1), c1
            assert.equal oad.bestMatch(obj3, root.obj[0].obj, 1), c2

            root = Diff.util.Category.categorize [c1, c2, c4]
            assert.equal oad.bestMatch(obj1, root.obj, 0), c1
            assert.equal oad.bestMatch(obj2, root.obj, 0), c1
            assert.equal oad.bestMatch(obj3, root.obj, 0), c2
            helper.C.setKeys ['a', 'b', 'c']

        it 'Should return nothing for no matches', ->
            assert.ok not oad.bestMatch(c1, [], 0)?

        it 'Should handle strange/invalid input', ->
            assert.ok not oad.bestMatch({}, [], 0)?

    describe 'takeBestMatch', ->
        it 'Should remove matches found by bestMatch', ->
            root = Diff.util.Category.categorize [c1, c2, c3]
            oad.takeBestMatch c1, root
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            expected.add               new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected)

            oad.takeBestMatch c2, root
            expected = new Diff.util.Category '_root', null, []
            expected.add new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected)

        it 'Should not return the same object twice', ->
            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.notEqual oad.takeBestMatch(c1, root),
                            oad.takeBestMatch(c1, root)
            assert.equal oad.takeBestMatch(c1, root), c3

        it 'Should not remove anything without a match', ->
            root = new Diff.util.Category 'key', 'val', []
            assert.ok not oad.takeBestMatch(c2, root)

    describe 'uniqueVsUnique', ->
        left = new Diff.util.Category 'key', 'val', c2
        right = new Diff.util.Category 'key', 'val', c4

        it 'Should return a single pair', ->
            assert.deepEqual oad.uniqueVsUnique(left, right), [[c2, c4]]

        it 'Should set left.obj and right.obj to null', ->
            assert.equal left.obj, null
            assert.equal right.obj, null

    describe 'uniqueVsArray', ->
        it 'Should return an empty list if no matches found', ->
            assert.deepEqual oad.uniqueVsArray(cat(c1), cat([]), 0, false), []

        it 'Should take the best match if possible', ->
            root = cat [c1, c2, c3], 0
            assert.deepEqual oad.uniqueVsArray(cat(c3, 0), root, false), [[c3, c3]]
            assert.deepEqual oad.uniqueVsArray(cat(c4, 0), root, false), [[c4, c2]]

            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.deepEqual oad.uniqueVsArray(cat(c1), root, false), [[c1, c1]]
            assert.deepEqual oad.uniqueVsArray(cat(c4), root, false), [[c4, c2]]

            helper.C.setKeys ['a', ['b', 'c']]

            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.deepEqual oad.uniqueVsArray(cat(c4), root, false), [[c4, c2]]
            assert.deepEqual oad.uniqueVsArray(cat(c3), root, false), [[c3, c3]]

            c5 = new helper.C 1, 2, 2
            c6 = new helper.C 2, 2, 2
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.deepEqual oad.uniqueVsArray(cat(c5), root, false), [[c5, c2]]
            assert.deepEqual oad.uniqueVsArray(cat(c6), root, false), [[c6, c3]]

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should set unique.obj to null', ->
            root = cat [c1, c2, c3], 0
            c = cat c1, 0
            oad.uniqueVsArray c, root, false
            assert.equal c.obj, null

        it 'Should remove matches from the array', ->
            root = cat [c1, c2, c3], 0
            oad.uniqueVsArray cat(c3, 0), root, false
            assert.deepEqual root.obj, [c1, c2]
            oad.uniqueVsArray cat(c4, 0), root, false
            assert.equal root.obj, c1

            root = Diff.util.Category.categorize [c1, c2, c3]
            oad.uniqueVsArray cat(c1), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            oad.uniqueVsArray cat(c4), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            helper.C.setKeys ['a', ['b', 'c']]

            root = Diff.util.Category.categorize [c1, c2, c3]
            oad.uniqueVsArray cat(c4), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 1], c1
            expected.add        new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            oad.uniqueVsArray cat(c3), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 1], c1
            assert.ok helper.compareBothWays(root, expected)

            c5 = new helper.C 1, 2, 2
            c6 = new helper.C 2, 2, 2
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            oad.uniqueVsArray cat(c5), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 1], c1
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 2], c4
            expected.add        new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            oad.uniqueVsArray cat(c6), root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 1], c1
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 2], c4
            assert.ok helper.compareBothWays(root, expected)

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should handle all key levels', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.deepEqual oad.uniqueVsArray(cat(c1, 0), root.obj[0], false), [[c1, c1]]
            assert.deepEqual oad.uniqueVsArray(cat(c4, 1), root.obj[0].obj[0], false), [[c4, c2]]

            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.deepEqual oad.uniqueVsArray(cat(c2, 2), root.obj[0].obj[0].obj[1], false), [[c2, c2]]

        it 'Should swap pairs if prompted', ->
            c5 = new helper.C 1, 1, 2
            c5.q = 5
            root = cat [c1, c2, c3], 0
            assert.deepEqual oad.uniqueVsArray(cat(c5, 0), root, false), [[c5, c2]]

            root = cat [c1, c2, c3], 0
            assert.deepEqual oad.uniqueVsArray(cat(c5, 0), root, true), [[c2, c5]]

    describe 'listVsCategory', ->
        it 'Should return an empty list if no matches found', ->
            assert.deepEqual oad.listVsCategory(cat([c1, c2], 0), cat([], 0), false), []

        it 'Should take the best match for each list item if possible', ->
            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            expected = [[c1, c4], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            expected = [[c3, c3], [c2, c1]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            helper.C.setKeys ['a', ['b', 'c']]

            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            expected = [[c1, c4], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            expected = [[c3, c3], [c2, c1]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should remove matched items from the list', ->
            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            oad.listVsCategory list, root, false
            assert.equal list.obj, null

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            oad.listVsCategory list, root, false
            assert.equal list.obj, null

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            oad.listVsCategory list, root, false
            assert.deepEqual list.obj, [c4, c1]

            helper.C.setKeys ['a', ['b', 'c']]

            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            oad.listVsCategory list, root, false
            assert.equal list.obj, null

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            oad.listVsCategory list, root, false
            assert.equal list.obj, null

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            oad.listVsCategory list, root, false
            assert.deepEqual list.obj, [c4, c1]

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should remove matched items from the category', ->
            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add                      new Diff.util.Category 'a', 1, []
            expected.obj[0].add               new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add        new Diff.util.Category 'c', 2, []
            expected.obj[0].obj[0].obj[0].obj = c2
            assert.ok helper.compareBothWays(root, expected)

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

            helper.C.setKeys ['a', ['b', 'c']]

            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

            list = cat [c1, c3]
            root = Diff.util.Category.categorize [c3, c4, c2]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 2], c2
            assert.ok helper.compareBothWays(root, expected)

            list = cat [c3, c2, c4, c1]
            root = Diff.util.Category.categorize [c3, c1]
            oad.listVsCategory list, root, false
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should handle all key levels', ->
            list = cat [c1, c2, c3], 0
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.listVsCategory(list, root.obj[0], false), expected)

            list = cat [c1, c2, c3], 1
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.listVsCategory(list, root.obj[0].obj[0], false), expected)

            list = cat [c1, c2, c3], 2
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c4]]
            assert.ok comparePairs(oad.listVsCategory(list, root.obj[0].obj[0].obj[1], false), expected)

        it 'Should swap pairs if prompted', ->
            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, false), expected)

            list = cat [c1, c2, c3]
            root = Diff.util.Category.categorize [c1, c3, c4]
            expected = [[c1, c1], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.listVsCategory(list, root, true), expected)

    describe 'listVsList', ->
        it 'Should return an empty list if no matches found', ->
            assert.deepEqual oad.listVsList(cat([c1, c2]), cat([])), []

        it 'Should take the first match for each list item', ->
            left = cat [c1, c2, c3]
            right = cat [c1, c3, c4]
            expected = [[c1, c1], [c2, c3], [c3, c4]]
            assert.ok comparePairs(oad.listVsList(left, right), expected)

            left = cat [c1, c2]
            right = cat [c1, c3, c4]
            expected = [[c1, c1], [c2, c3]]
            assert.ok comparePairs(oad.listVsList(left, right), expected)

            left = cat [c1, c2, c3, c4]
            right = cat [c1, c3]
            expected = [[c1, c1], [c2, c3]]
            assert.ok comparePairs(oad.listVsList(left, right), expected)

        it 'Should remove matched items from each list', ->
            left = cat [c1, c2, c3]
            right = cat [c1, c3, c4]
            expected = [[c1, c1], [c2, c3], [c3, c4]]
            oad.listVsList left, right
            assert.equal left.obj, null
            assert.equal right.obj, null

            left = cat [c1, c2]
            right = cat [c1, c3, c4]
            expected = [[c1, c1], [c2, c3]]
            oad.listVsList left, right
            assert.equal left.obj, null
            assert.equal right.obj, c4

            left = cat [c1, c2, c3, c4]
            right = cat [c1, c3]
            expected = [[c1, c1], [c2, c3]]
            oad.listVsList left, right
            assert.deepEqual left.obj, [c3, c4]
            assert.equal right.obj, null

    describe 'catVsCatSecondPass', ->
        c5 = new helper.C 2, 1, 2
        c6 = new helper.C 2, 2, 2
        c7 = new helper.C 3, 1, 4
        c8 = new helper.C 1, 3, 2

        it 'Should return an empty list if no matches found', ->
            root = Diff.util.Category.categorize [c1, c3, c2]
            assert.deepEqual oad.catVsCatSecondPass(cat([]), root, true), []
            assert.deepEqual oad.catVsCatSecondPass(root, cat([]), true), []

        it 'Should match exactly before inexactly', ->
            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c1, c1], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left, right), expected)

            helper.C.setKeys [['a', 'b'], 'c']

            left = Diff.util.Category.categorize [c3, c7]
            right = Diff.util.Category.categorize [c1, c5, c4, c8]
            expected = [[c3, c5], [c7, c1]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left, right), expected)

            left = Diff.util.Category.categorize [c1, c5, c4, c8]
            right = Diff.util.Category.categorize [c3, c7]
            expected = [[c1, c7], [c5, c3]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left, right), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2]
            right = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            expected = [[c6, c6], [c2, c2], [c7, c1], [c3, c5]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left, right), expected)

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should remove matched items from each category', ->
            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            oad.catVsCatSecondPass left, right
            expected = new Diff.util.Category '_root', null, []
            expected.add                      new Diff.util.Category 'a', 1, []
            expected.obj[0].add               new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add        new Diff.util.Category 'c', 2, []
            expected.obj[0].obj[0].obj[0].obj = c2
            assert.ok helper.compareBothWays(left, expected)
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(right, expected)

            helper.C.setKeys [['a', 'b'], 'c']

            left = Diff.util.Category.categorize [c3, c7]
            right = Diff.util.Category.categorize [c1, c5, c4, c8]
            oad.catVsCatSecondPass left, right
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(left, expected)
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category ['a', 'b'], [1, 1], []
            expected.obj[0].add new Diff.util.Category 'c', 2, c4
            expected.add        new Diff.util.Category ['a', 'b'], [1, 3], c8
            assert.ok helper.compareBothWays(right, expected)

            left = Diff.util.Category.categorize [c1, c5, c4, c8]
            right = Diff.util.Category.categorize [c3, c7]
            oad.catVsCatSecondPass left, right
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category ['a', 'b'], [1, 1], []
            expected.obj[0].add new Diff.util.Category 'c', 2, c4
            expected.add        new Diff.util.Category ['a', 'b'], [1, 3], c8
            assert.ok helper.compareBothWays(left, expected)
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(right, expected)

            helper.C.setKeys ['a', 'b', 'c']

        it 'Should support all key levels', ->
            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c1, c1], [c4, c2]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left.obj[0], right.obj[0]), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c1, c1], [c4, c2]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left.obj[0].obj[0], right.obj[0].obj[0]), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c4, c2]]
            assert.ok comparePairs(oad.catVsCatSecondPass(left.obj[0].obj[0].obj[0],
                                                          right.obj[0].obj[0].obj[1]), expected)

    describe 'catVsCat', ->
        c5 = new helper.C 2, 1, 2
        c6 = new helper.C 2, 2, 2
        c7 = new helper.C 3, 1, 4
        c8 = new helper.C 1, 3, 2

        it 'Should return an empty list if no matches found', ->
            root = Diff.util.Category.categorize [c1, c3, c2]
            assert.deepEqual oad.catVsCat(cat([]), root, true), []
            assert.deepEqual oad.catVsCat(root, cat([]), true), []

        it 'Should match exactly before matching inexactly', ->
            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c1, c1], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c1, c1], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c4, c4]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c4, c4], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c3, c4, c4]
            expected = [[c4, c4], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4]
            right = Diff.util.Category.categorize [c3, c1]
            expected = [[c4, c1]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c1]
            right = Diff.util.Category.categorize [c4]
            expected = [[c1, c4]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c1, c2, c3, c4, c5, c6, c7, c8]
            right = Diff.util.Category.categorize [c3, c7, c6, c2, c8]
            expected = [[c2, c2], [c3, c3], [c6, c6], [c7, c7], [c8, c8]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2, c8]
            right = Diff.util.Category.categorize [c1, c2, c3, c4, c5, c6, c7, c8]
            expected = [[c2, c2], [c3, c3], [c6, c6], [c7, c7], [c8, c8]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2]
            right = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            expected = [[c2, c2], [c6, c6], [c3, c5]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            right = Diff.util.Category.categorize [c3, c7, c6, c2]
            expected = [[c2, c2], [c6, c6], [c5, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            helper.C.setKeys [['a', 'b'], 'c']
            helper.uncache c5, c6, c7, c8

            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c1, c1], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            expected = [[c1, c1], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c4, c4]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c4, c4], [c4, c2], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c3, c4, c4]
            expected = [[c4, c4], [c2, c4], [c3, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c4]
            right = Diff.util.Category.categorize [c3, c1]
            expected = [[c4, c1]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c1]
            right = Diff.util.Category.categorize [c4]
            expected = [[c1, c4]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c1, c2, c3, c4, c5, c6, c7, c8]
            right = Diff.util.Category.categorize [c3, c7, c6, c2, c8]
            expected = [[c2, c2], [c3, c3], [c6, c6], [c7, c7], [c8, c8]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2, c8]
            right = Diff.util.Category.categorize [c1, c2, c3, c4, c5, c6, c7, c8]
            expected = [[c2, c2], [c3, c3], [c6, c6], [c7, c7], [c8, c8]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2]
            right = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            expected = [[c6, c6], [c2, c2]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c3, c7, c6, c2]
            right = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            expected = [[c6, c6], [c2, c2], [c3, c5], [c7, c1]]
            assert.ok comparePairs(oad.catVsCat(left, right, true), expected)

            left = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            right = Diff.util.Category.categorize [c3, c7, c6, c2]
            expected = [[c6, c6], [c2, c2]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c1, c2, c5, c4, c8, c6]
            right = Diff.util.Category.categorize [c3, c7, c6, c2]
            expected = [[c6, c6], [c2, c2], [c1, c7], [c5, c3]]
            assert.ok comparePairs(oad.catVsCat(left, right, true), expected)

            helper.C.setKeys ['a', 'b', 'c']
            helper.uncache c5, c6, c7, c8

        it 'Should not perform inexact matching for root nodes by default', ->
            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c2]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.catVsCat(left, right, false), expected)

            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c2]
            expected = [[c1, c1], [c2, c4], [c3, c2]]
            assert.ok comparePairs(oad.catVsCat(left, right, true), expected)

            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c2]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.catVsCat(left, right), expected)

        it 'Should remove matched items from each category', ->
            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            oad.catVsCat left, right, false
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(left, expected)
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            assert.ok helper.compareBothWays(right, expected)

            left = Diff.util.Category.categorize [c4, c1, c3, c2]
            right = Diff.util.Category.categorize [c1, c3, c2]
            oad.catVsCat left, right, false
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            assert.ok helper.compareBothWays(left, expected)
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(right, expected)

        it 'Should support all key levels', ->
            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.catVsCat(left.obj[0], right.obj[0], true), expected)

            left = Diff.util.Category.categorize [c1, c3, c2]
            right = Diff.util.Category.categorize [c4, c1, c3, c2]
            expected = [[c1, c1], [c2, c4]]
            assert.ok comparePairs(oad.catVsCat(left.obj[0].obj[0], right.obj[0].obj[0], true), expected)

    describe 'getPairs', ->
        it 'Should return an empty list if no matches found', ->
            left = cat []
            right = cat c1
            assert.deepEqual oad.getPairs(left, right), []

        it 'Should support unique vs unique', ->
            left = cat c1
            right = cat c2
            assert.deepEqual oad.getPairs(left, right), [[c1, c2]]

        it 'Should support unique vs list', ->
            left = cat c1
            right = cat [c1, c2]
            assert.deepEqual oad.getPairs(left, right), [[c1, c1]]

        it 'Should support unique vs categories', ->
            left = cat c1
            right = Diff.util.Category.categorize [c3, c2]
            assert.deepEqual oad.getPairs(left, right), [[c1, c2]]

        it 'Should support list vs unique', ->
            left = cat [c1, c2]
            right = cat c1
            assert.deepEqual oad.getPairs(left, right), [[c1, c1]]

        it 'Should support list vs list', ->
            left = cat [c3, c1]
            right = cat [c1, c2]
            assert.deepEqual oad.getPairs(left, right), [[c3, c1], [c1, c2]]

        it 'Should support list vs categories', ->
            left = cat [c1, c3]
            right = Diff.util.Category.categorize [c3, c2]
            assert.deepEqual oad.getPairs(left, right), [[c1, c2], [c3, c3]]

        it 'Should support categories vs unique', ->
            left = Diff.util.Category.categorize [c3, c2]
            right = cat c1
            assert.deepEqual oad.getPairs(left, right), [[c2, c1]]

        it 'Should support categories vs list', ->
            left = Diff.util.Category.categorize [c3, c2]
            right = cat [c1, c3]
            assert.deepEqual oad.getPairs(left, right), [[c2, c1], [c3, c3]]

        it 'Should support categories vs categories', ->
            left = Diff.util.Category.categorize [c3, c2]
            right = Diff.util.Category.categorize [c1, c2]
            assert.deepEqual oad.getPairs(left, right), [[c2, c2]]

        it 'Should support all key levels', ->
            left = Diff.util.Category.categorize [c3, c2, c1, c4]
            right = Diff.util.Category.categorize [c1, c2]
            assert.deepEqual oad.getPairs(left.obj[1], right.obj[0]), [[c2, c2], [c1, c1]]

            left = Diff.util.Category.categorize [c3, c2, c1, c4]
            right = Diff.util.Category.categorize [c1, c2]
            assert.deepEqual oad.getPairs(left.obj[1].obj[0], right.obj[0].obj[0]), [[c2, c2], [c1, c1]]

            left = Diff.util.Category.categorize [c3, c2, c1, c4]
            right = Diff.util.Category.categorize [c1, c2]
            assert.deepEqual oad.getPairs(left.obj[1].obj[0].obj[0],
                                          right.obj[0].obj[0].obj[1]), [[c2, c2]]

    describe 'fromObject', ->
        it 'Should convert a regular object into an ObjectArrayDiff', ->
            diff = new oad [c1, c3, c2], [c2, c4, c3]
            obj = [{c: [1, 2], _h: [hash(c1), hash(c4)]}]
            assert.deepEqual diff, oad.fromObject(obj)

            c5 = new helper.C 1, 3, 2
            diff = new oad [c1, c2, c1], [c2, c3, c5]
            obj = [{b: [1, 3], c: [1, 2], _h: [hash(c1), hash(c5)]},
                   {a: 1, b: 1, c: 1, _h: [hash(c1), null]},
                   {a: 2, b: 2, c: 1, _h: [null, hash(c3)]}]
            assert.deepEqual diff, oad.fromObject(obj)

    describe 'determineType', ->
        it 'Should return 0 for modification', ->
            obj = {_h: vd('', '')}
            assert.equal oad.determineType(obj, true), 0
            assert.equal oad.determineType(obj, false), 0

        it 'Should return 1 for addition', ->
            obj = {_h: vd(null, '')}
            assert.equal oad.determineType(obj, true), 1
            obj = {_h: vd('', null)}
            assert.equal oad.determineType(obj, false), 1

        it 'Should return 2 for subtraction', ->
            obj = {_h: vd(null, '')}
            assert.equal oad.determineType(obj, false), 2
            obj = {_h: vd('', null)}
            assert.equal oad.determineType(obj, true), 2

        it 'Should throw an exception for bad input', ->
            obj = {_h: vd(null, null)}
            assert.throws (-> oad.determineType(obj, true)), Error

    describe 'apply', ->
        class F
            constructor: (@x, @y) ->
            _diffKeys: ['x', 'y']

        it 'Should work forward and backward (default)', ->
            diff = new oad [new F(1, 1), new F(1, 2)], [new F(2, 1), new F(1, 1)]
            # Note, we can't use new F(2, 1) since chai assert checks the type
            # of the created object, and we didn't pass a constructor to apply
            assert.deepEqual diff.apply([new F(1, 1), new F(1, 2)]), [new F(1, 1), {x: 2, y: 1}]
            assert.deepEqual diff.apply([new F(1, 1), new F(1, 2)], direction: 'b'), [new F(1, 1), {x: 2, y: 1}]
            assert.deepEqual diff.apply([new F(2, 1), new F(1, 1)], direction: 'f'), [new F(1, 1), {x: 1, y: 2}]

        it 'Should create values of type if requested', ->
            class Q
                constructor: (q) ->
                    @[key] = val for own key, val of q
                _diffKeys: ['x', 'y']

            diff = new oad [new Q({x: 1, y: 1})], [new Q({x: 2, y: 1}), new Q({x: 1, y: 1})]
            f = diff.apply [new Q({x: 1, y: 1})], {direction: 'b', fail: false}, Q
            assert.ok f[0] instanceof Q and f[1] instanceof Q
            assert.deepEqual f[1], new Q({x: 2, y: 1})

        it 'Should throw an exception for bad or inconsistent input', ->
            diff = new oad [new F(1, 1), new F(1, 2)], [new F(2, 1), new F(1, 1)]
            assert.throws (-> diff.apply 2), Error
            assert.throws (-> diff.apply [new F(2, 1), new F(1, 1)]), Error
            assert.throws (-> diff.apply []), Error
            assert.throws (-> diff.apply [], 'r'), Error
            assert.throws (-> diff.apply [new F(1, 1), new F(1, 2), new F(2, 1)]), Error
            assert.doesNotThrow (-> diff.apply [new F(1, 1), new F(1, 2)])
            assert.doesNotThrow (-> diff.apply [new F(2, 1), new F(1, 1)], {direction: 'l', fail: false}, F)
            assert.doesNotThrow (-> diff.apply [new F(1, 2), new F(1, 1)], {direction: 'r', fail: false}, F)

            diff = new oad [new F(1, 2)], [new F(1, 3)]
            assert.throws (-> diff.apply [new F(2, 2)]), Error
            assert.doesNotThrow (-> diff.apply [new F(1, 2)])

    it 'Should find pairs', ->
        diff = new oad [c1, c2], [c2, c1]
        assert.deepEqual diff, new oad

        c5 = new helper.C 1, 3, 2
        diff = new oad [c1], [c5]
        assert.deepEqual diff, makeOad([makeOd({b: vd(1, 3), c: vd(1, 2), _h: vd(hash(c1), hash(c5))})])

    it 'Should support objects with different keys', ->
        class F
            _diffKeys: ['x', 'y']
            constructor: (@x, @y) ->

        f1 = new F 1, 1
        f2 = new F 1, 2
        diff = new oad [c1, c2, f1], [c2, c4, f2]
        expected = makeOad([
            makeOd({c: vd(1, 2), _h: vd(hash(c1), hash(c4))})
            makeOd({y: vd(1, 2), _h: vd(hash(f1), hash(f2))})
        ])
        assert.deepEqual diff, expected

        class Q
            _diffKeys: ['a', 'q']
            constructor: (@a, @q) ->

        q1 = new Q 1, 1
        diff = new oad [c1, c2, q1], [c1, c2]
        expected = makeOad([
            {a: 1, q: 1, _h: vd(hash(q1), null)}
        ])
        assert.deepEqual diff, expected

    it 'Should support complex keys', ->
        helper.C.setKeys [['a', 'b'], 'c']

        diff = new oad [c1, c3, c2], [c2, c4, c3]
        assert.deepEqual diff, makeOad([makeOd({c: vd(1, 2), _h: vd(hash(c1), hash(c4))})])

        helper.C.setKeys ['a', 'b', 'c']

    it 'Should support additions and deletions', ->
        diff = new oad [c1], [c3]
        assert.deepEqual diff, makeOad([{a: 1, b: 1, c: 1, _h: vd(hash(c1), null)},
                                       {a: 2, b: 2, c: 1, _h: vd(null, hash(c3))} ])

        c5 = new helper.C 1, 3, 2
        diff = new oad [c1, c2, c1], [c2, c3, c5]
        assert.deepEqual diff, makeOad([makeOd({b: vd(1, 3), c: vd(1, 2), _h: vd(hash(c1), hash(c5))}),
                                       {a: 1, b: 1, c: 1, _h: vd(hash(c1), null)},
                                       {a: 2, b: 2, c: 1, _h: vd(null, hash(c3))} ])

        diff = new oad [c1, c2], [c2]
        assert.deepEqual diff, makeOad([{a: 1, b: 1, c: 1, _h: vd(hash(c1), null)}])

    it 'Should support fuzzy string matching', ->
        # TODO

describe 'Diff', ->
    describe 'diff', ->
        it 'Should return an empty object identical values', ->
            assert.deepEqual Diff.diff(1, 1), {}
            assert.deepEqual Diff.diff('test', 'test'), {}
            assert.deepEqual Diff.diff(false, false), {}

        it 'Should support plain values', ->
            diff = Diff.diff 1, 2
            assert.deepEqual diff, vd(1, 2)

            diff = Diff.diff 'test', 2
            assert.deepEqual diff, vd('test', 2)

        it 'Should support objects', ->
            diff = Diff.diff {a: 1, b: 1}, {b: 2}
            assert.deepEqual diff, new od({a: 1, b: 1}, {b: 2})

        it 'Should support arrays of mixed values/objects', ->
            diff = Diff.diff [1, {b: 1}], [2, {b: 2}]
            assert.deepEqual diff, new od([1, {b: 1}], [2, {b: 2}])

        it 'Should support arrays of objects', ->
            diff = Diff.diff [c1, c2, c3], [c3, c4]
            assert.deepEqual diff, new oad([c1, c2, c3], [c3, c4])

        it 'Should use a postDiff function if available', ->
            q = 1
            class Q
                constructor: (@x, @y) ->
                @postDiff = (left, right, diff) ->
                    diff.q = ++q

            q1 = new Q 1, 2
            q2 = new Q 2, 2
            diff = Diff.diff(q1, q2)
            assert.equal diff.q, 2

            p = 1
            q1.postDiff = (left, right, diff) -> diff.p = ++p
            diff = Diff.diff(q1, q2)
            assert.equal diff.p, 2
            assert.equal diff.q, 3

            diff = Diff.diff(q2, q1)
            assert.equal diff.p, 3
            assert.equal diff.q, 4

            q2.postDiff = q1.postDiff
            diff = Diff.diff(q1, q2)
            assert.equal diff.p, 4
            assert.ok not diff.q?

            diff = Diff.diff({x: 1, y: 1}, q2)
            assert.equal diff.p, 5
            assert.ok not diff.q?

            delete q2.postDiff
            diff = Diff.diff({x: 1, y: 1}, q2)
            assert.equal diff.q, 5
            assert.ok not diff.p?

            diff = Diff.diff({x: 1, y: 1}, q1)
            assert.equal diff.p, 6
            assert.ok not diff.q?

    describe 'apply', ->
        class F
            constructor: (@x, @y) ->
            _diffKeys: ['x', 'y']

        it 'Should support ValueDiffs', ->
            diff = vd(1, 2)
            assert.equal Diff.apply(1, diff, 'b'), 2
            assert.equal Diff.apply(2, diff, 'f'), 1

        it 'Should support ObjectDiffs', ->
            diff = new od {a: 1, b: 2}, {a: 'test', b: 2}
            assert.deepEqual Diff.apply({a: 1, b: 2}, diff, 'b'), {a: 'test', b: 2}
            assert.deepEqual Diff.apply({a: 'test', b: 2}, diff, 'f'), {a: 1, b: 2}

        it 'Should support ObjectArrayDiffs', ->
            diff = new oad [new F(1, 1), new F('test', 4)], [new F('test', 2), new F(2, 2)]
            assert.deepEqual Diff.apply([new F(1, 1), new F('test', 4)], diff, 'b'), [new F('test', 2), {x: 2, y: 2}]
            assert.deepEqual Diff.apply([new F('test', 2), new F(2, 2)], diff, 'f'), [new F('test', 4), {x: 1, y: 1}]

        it 'Should accept a single or multiple diffs as objects or JSON strings', ->
            diff = Diff.diff(1, 2)
            assert.equal Diff.apply(1, diff), 2
            assert.equal Diff.apply(1, JSON.stringify diff), 2

            diff = [Diff.diff({a: 1}, {a: 2}), Diff.diff({a: 2}, {a: 3})]
            assert.deepEqual Diff.apply({a: 1}, diff), {a: 3}
            diff = [JSON.stringify(diff[0]), JSON.stringify(diff[1])]
            assert.deepEqual Diff.apply({a: 1}, diff), {a: 3}

            diff = [Diff.diff([new F(1, 1)], [new F(1, 2)]), Diff.diff([new F(1, 2)], [new F(2, 1)])]
            assert.deepEqual Diff.apply([new F(1, 1)], diff), [{x: 2, y: 1}]
            diff = [JSON.stringify(diff[0]), JSON.stringify(diff[1])]
            assert.deepEqual Diff.apply([new F(1, 1)], diff), [{x: 2, y: 1}]

            d1 =
                x: 1
                y: [new F(1, 2), new F(2, 2)]
            d2 =
                x: 2
                y: [new F(1, 2), new F(2, 1)]
            d3 =
                x: 1
                y: [new F(1, 2), new F(2, 1)]
            d4 =
                x: 4
                y: [new F(4, 4), new F(2, 1)]

            diff = [Diff.diff(d1, d2), Diff.diff(d2, d3), Diff.diff(d3, d4)]
            assert.deepEqual Diff.apply({x: 1, y: [new F(1, 2), new F(2, 2)]}, diff),
                                        {x: 4, y: [new F(2, 1), {x: 4, y: 4}]}
            diff = [JSON.stringify(diff[0]), JSON.stringify(diff[1]), JSON.stringify(diff[2])]
            assert.deepEqual Diff.apply({x: 1, y: [new F(1, 2), new F(2, 2)]}, diff),
                                        {x: 4, y: [new F(2, 1), {x: 4, y: 4}]}

        it 'Should throw an exception if the diff parameter is not valid', ->
            assert.throws (-> Diff.apply 1, {left: 1, right: 2}), Error
            assert.throws (-> Diff.apply 1, '[1, 2, 3]'), Error

        it 'Should throw an exception if the diff cannot be applied', ->
            assert.throws (-> Diff.apply 1, vd(4, 5)), Error

        it 'Should be able to ignore non-critical errors', ->
            assert.equal Diff.apply(1, vd(4, 5), 'b', false), 5
            assert.equal Diff.apply(1, vd(4, 5), 'b', false), 5

            diff = new od {a: 1}, {a: 2}
            assert.deepEqual Diff.apply({a: 4}, diff, 'b', false), {a: 2}
            assert.deepEqual Diff.apply({x: 1}, diff, 'b', false), {x: 1, a: 2}

            diff = new oad [new F(1, 1), new F(1, 2)], [new F(2, 1), new F(1, 1)]
            assert.deepEqual Diff.apply([new F(2, 1), new F(1, 1)], diff, 'b', false),
                                        [new F(2, 1), new F(1, 1), {x: 2, y: 1}]

        it 'Should use a fail function if requested', ->
            fail = (path) ->
                if path.length > 1 then true else false

            diff = new od {a: 1, b: {q: 2}}, {a: 2, b: {q: 2, z: 4}}
            assert.throws (-> Diff.apply {a: 2, b: {z: 3}}, diff, 'b', fail), Error

            diff = new od {a: 1, b: 2}, {a: 2, b: 4}
            assert.doesNotThrow (-> Diff.apply {a: 2, b: 3}, diff, 'b', fail)

        it 'Should use a postApply function if available', ->
            class Q
                constructor: (@x, @y) ->
                @postApply = (obj, diff) ->
                    obj.q = 1

            q1 = new Q 1, 2
            q2 = new Q 2, 2
            diff = Diff.diff q1, q2
            result = Diff.apply new Q(1, 2), diff
            assert.equal result.q, 1

            q1.postApply = (obj, diff) -> obj.p = 2
            diff = Diff.diff q1, q2
            result = Diff.apply q1, diff
            assert.equal result.p, 2
            assert.ok not result.q?

            # Test weird corner case
            diff = Diff.diff null, 1
            Diff.apply null, diff
            diff = Diff.diff 1, null
            Diff.apply 1, diff

        it 'Should not affect the original object', ->
            obj1 = {a: 1, b: 2, c: [{x: 1, y: 2}, {x: 1, y: 1}, {x: 2, y: 2}]}
            obj2 = {a: 1, b: 2, c: [{x: 1, y: 2}, {x: 1, y: 1}, {x: 2, y: 2}]}
            obj3 = {a: 2, c: [{x: 1, y: 2}, {x: 3, y: 1}, {x: 2, y: 1}], d: 4}

            diff = Diff.diff obj1, obj3
            obj4 = Diff.apply obj1, diff

            # Diff doesn't distinguish between null and undefined, so we need
            # to manually items we don't want to keep
            delete obj4.b if obj4.b is null

            assert.deepEqual obj4, obj3
            assert.notEqual obj4, obj1
            assert.deepEqual obj1, obj2

            assert.notEqual obj4.c, obj1.c

    describe 'combine', ->
        it 'Is currently unsupported', ->
            assert.throws (-> Diff.combine()), /not implemented/
            assert.throws (-> Diff.combine('asdf')), /not implemented/

    describe 'parse', ->
        it 'Should support ValueDiffs', ->
            assert.deepEqual vd(1, 2), Diff.parse('[1, 2]')
            assert.deepEqual vd(1, 'test'), Diff.parse('[1, "test"]')
            assert.deepEqual vd(null, true), Diff.parse('[null, true]')

            assert.ok Diff.parse('[1, 2]') instanceof Diff.util.ValueDiff

        it 'Should support ObjectDiffs', ->
            left = {a: 1, b: 2}
            right = {a: 2, b: 3}
            json = '{"a": [1, 2], "b": [2, 3]}'
            assert.deepEqual new od(left, right), Diff.parse(json)

            left = {a: 1, b: 'test'}
            right = {a: 2, b: 3}
            json = '{"a": [1, 2], "b": ["test", 3]}'
            assert.deepEqual new od(left, right), Diff.parse(json)

            left = {a: 1, b: 2}
            right = {a: null, b: 3}
            json = '{"a": [1, null], "b": [2, 3]}'
            assert.deepEqual new od(left, right), Diff.parse(json)

            assert.ok Diff.parse(json) instanceof Diff.util.ObjectDiff

        it 'Should support ObjectArrayDiffs', ->
            diff = new oad [c1, c3, c2], [c2, c4, c3]
            json = '[{"c": [1, 2], "_h": [' + JSON.stringify(hash c1) + ', ' + JSON.stringify(hash c4) + ']}]'
            assert.deepEqual diff, Diff.parse(json)

            assert.ok Diff.parse(json) instanceof Diff.util.ObjectArrayDiff

        it 'Should throw TypeError for unsupported objects', ->
            assert.throws (-> Diff.parse '"test"'), TypeError
            assert.throws (-> Diff.parse '10'), TypeError
            assert.throws (-> Diff.parse '[1, 2, 3]'), TypeError

        it 'Should throw SyntaxError for bad JSON', ->
            assert.throws (-> Diff.parse '["test",'), SyntaxError

        it 'Should support diff-like objects', ->
            left = {a: 1, b: 'test'}
            right = {a: 2, b: 3}
            obj = JSON.parse '{"a": [1, 2], "b": ["test", 3]}'
            assert.deepEqual new od(left, right), Diff.parse(obj)

    describe 'configure', ->
        it 'Should do nothing for invalid input', ->
            assert.doesNotThrow (-> Diff.configure('test'))