Brauhaus = @Brauhaus ? require 'brauhaus'
Diff = Brauhaus.Diff ? require('../lib/brauhaus-diff')
Diff.configure({exportUtil: true})
assert = assert ? require 'assert'
murmur = @MurmurHash3 ? require 'imurmurhash'

helper = helper ? require './helper/helper'

c1 = helper.c1
c2 = helper.c2
c3 = helper.c3
c4 = helper.c4

describe 'Util', ->
    describe 'keyPass', ->
        validKey = 'key'
        invalidKey = '_key'
        
        it 'Should pass numbers', ->
            assert.ok Diff.util.keyPass(validKey, 0)

        it 'Should pass strings', ->
            assert.ok Diff.util.keyPass(validKey, 'string')

        it 'Should pass bool', ->
            assert.ok Diff.util.keyPass(validKey, false)

        it 'Should pass arrays', ->
            assert.ok Diff.util.keyPass(validKey, [])

        it 'Should pass objects', ->
            assert.ok Diff.util.keyPass(validKey, {})

        it 'Should not pass functions', ->
            assert.ok not Diff.util.keyPass(validKey, -> true)

        it 'Should not pass private keys', ->
            assert.ok not Diff.util.keyPass(invalidKey, 0)

    describe 'getKeys', ->
        left =
            a: 1
            b: '2'
            _c: 3
            d: {}
            e: -> true

        right =
            a: '1'
            _c: ''
            d: -> true
            e: 0
            f: []

        [leftOnly, rightOnly, both] = Diff.util.getKeys left, right

        it 'Should set left-only as ["b", "d"]', ->
            assert.deepEqual leftOnly, ['b', 'd']

        it 'Should set right-only as ["e", "f"]', ->
            assert.deepEqual rightOnly, ['e', 'f']

        it 'Should set both as ["a"]', ->
            assert.deepEqual both, ['a']

    describe 'isEmpty', ->
        it 'Should work for arrays', ->
            assert.ok Diff.util.isEmpty([])
            assert.ok not Diff.util.isEmpty([0])

        it 'Should work for objects', ->
            assert.ok Diff.util.isEmpty({})
            assert.ok Diff.util.isEmpty({_privateKey: 1})
            assert.ok not Diff.util.isEmpty({publicKey: 1})

        it 'Should work with null or undefined', ->
            assert.ok Diff.util.isEmpty(null)
            assert.ok Diff.util.isEmpty(-> return)

    describe 'areAll', ->
        arr0 = []
        arr1 = []
        arr2 = []

        obj1 = {}
        obj2 = {}
        obj3 = {}

        it 'Should pass all arrays', ->
            assert.ok Diff.util.areAll(Array, arr0, arr1, arr2)

        it 'Should pass all objects', ->
            assert.ok Diff.util.areAll(Object, obj1, obj2, obj3)

        it 'Should not pass objects as arrays', ->
            assert.ok not Diff.util.areAll(Array, arr0, obj1, obj2)
            assert.ok Diff.util.areAll(Object, arr0, obj1, obj2)

        it 'Should not pass empty parameter list', ->
            assert.ok not Diff.util.areAll(Object)

    describe 'areAny', ->
        arr0 = []
        arr1 = []
        arr2 = []

        obj1 = {}
        obj2 = {}
        obj3 = {}

        it 'Should pass all arrays', ->
            assert.ok Diff.util.areAny(Array, [arr0, arr1, arr2])

        it 'Should pass all objects', ->
            assert.ok Diff.util.areAny(Object, [obj1, obj2, obj3])

        it 'Should pass mixed arrays and objects', ->
            assert.ok Diff.util.areAny(Array, [obj1, arr0, obj2])
            assert.ok Diff.util.areAny(Object, [obj1, arr0, obj2])

        it 'Should not pass objects as arrays', ->
            assert.ok not Diff.util.areAny(Array, [obj1, obj2, obj3])

    describe 'compatibleTypes', ->
        class C1
            a: 1
            b: 2
            c: 3
            d: 4
            e: 5

        class C2
            a: 1
            b: 2
            c: 3
            d: 4

        class C3
            a: 1
            b: 2
            g: 7

        class C4 extends C1
            g: 7

        class C5 extends C3
            q: 1
            w: 2
            e: 3
            r: 4
            t: 5
            y: 6

        it 'Should pass arrays', ->
            assert.ok Diff.util.compatibleTypes([], [])

        it 'Should not pass array/object mix', ->
            assert.ok not Diff.util.compatibleTypes([], {})

        it 'Should pass generic objects', ->
            assert.ok Diff.util.compatibleTypes({}, {})
            assert.ok Diff.util.compatibleTypes({}, new C1)

        it 'Should pass types with >75% similar keys', ->
            assert.ok Diff.util.compatibleTypes(new C1, new C2)

        it 'Should pass subclasses', ->
            assert.ok Diff.util.compatibleTypes(new C1, new C4)
            assert.ok Diff.util.compatibleTypes(new C3, new C5)

        it 'Should not pass types that are not subclasses nor similar', ->
            assert.ok not Diff.util.compatibleTypes(new C2, new C4)
            assert.ok not Diff.util.compatibleTypes(new C1, new C3)

    describe 'hash', ->
        obj1 = {a: 1, b: 2, c: 3, _diffKeys: ['a', 'b', 'c']}
        obj2 = {a: 1, b: 2, c: 4, _diffKeys: ['a', 'b', 'c']}
        obj3 = {a: 1, b: 2, c: 3}
        obj4 = {a: 1, b: 2, c: 3, _diffKeys: ['a', 'b', 'c']}

        it 'Should have the same hash for the same input', ->
            assert.equal Diff.util.hash(obj1), Diff.util.hash(obj1)
            assert.equal Diff.util.hash(obj1), Diff.util.hash(obj4)
            assert.equal Diff.util.hash(obj3), Diff.util.hash(obj3)

        it 'Should not have same hash for different inputs', ->
            assert.notEqual Diff.util.hash(obj1), Diff.util.hash(obj2)
            assert.notEqual Diff.util.hash(obj1), Diff.util.hash(obj3)

    describe 'hashObjKeys', ->
        obj1 = {a: 1, b: 2, c: 3}
        it 'Should recursively hash the object\'s keys and values', ->
            expected = new murmur('a:1|b:2|c:3|')
            hash = murmur()
            Diff.util.hashObjKeys hash, obj1, ['a', 'b', 'c']
            assert.equal hash.result(), expected.result()

            hash.reset()
            Diff.util.hashObjKeys hash, obj1, ['a', ['b', 'c']]
            assert.equal hash.result(), expected.result()

    describe 'diffCopy', ->
        obj1 =
            a: 1
            b: 2
            c: -> true
            toJSON: -> [@a, @b, @c]

        obj2 = {a: 1, b: 2, _c: 3}

        obj3 =
            a: 1
            b: 2
            _c: 3
            toJSON: -> {@a, @b, @_c}

        it 'Should not copy private keys', ->
            assert.deepEqual Diff.util.diffCopy(obj2), {a: 1, b: 2}

        it 'Should not copy functions', ->
            assert.deepEqual Diff.util.diffCopy(obj1), [1, 2]

        it 'Should use toJSON when available', ->
            assert.deepEqual Diff.util.diffCopy(obj1), [1, 2]
            assert.deepEqual Diff.util.diffCopy(obj3), {a: 1, b: 2}

        it 'Should return the same value if not an object', ->
            assert.equal Diff.util.diffCopy(1), 1

        it 'Should ignore default values if requested', ->
            Diff.configure {removeDefaultValues: true}

            class X
                constructor: (x, y) ->
                    @x = x if x?
                    @y = y if y?
                x: 1
                y: 2

            x = Diff.util.diffCopy new X
            assert.ok not x.x?
            assert.ok not x.y?

            x = Diff.util.diffCopy new X 2
            assert.ok x.x?
            assert.ok not x.y?

            Diff.configure {removeDefaultValues: false}

            x = Diff.util.diffCopy new X
            assert.ok x.x?
            assert.ok x.y?

            x = Diff.util.diffCopy new X 2
            assert.ok x.x?
            assert.ok x.y?

    describe 'shallowCopy', ->
        it 'Should work for objects', ->
            obj1 =
                a: 1
                b: 2
                c: -> true

            obj2 = Diff.util.shallowCopy obj1
            assert.deepEqual obj1, obj2
            assert.notEqual obj1, obj2

            obj1 = new Brauhaus.Spice
            obj1.name = 'blah'
            obj2 = Diff.util.shallowCopy obj1
            assert.deepEqual obj1, obj2
            assert.notEqual obj1, obj2

        it 'Should work for arrays', ->
            arr1 = [{a: 1}, {b: 2}]
            arr2 = Diff.util.shallowCopy arr1
            assert.deepEqual arr1, arr2
            assert.notEqual arr1, arr2

        it 'Should return the same value for non-objects', ->
            assert.equal Diff.util.shallowCopy(5), 5
            assert.equal Diff.util.shallowCopy('test'), 'test'

        it 'Should preserve type by default', ->
            obj1 = new Brauhaus.Spice
            obj1.name = 'blah'
            obj2 = Diff.util.shallowCopy obj1
            assert.ok obj2 instanceof Brauhaus.Spice

        it 'Should ignore type if requested', ->
            obj1 = new Brauhaus.Spice
            obj1.name = 'blah'
            obj2 = Diff.util.shallowCopy obj1, true
            assert.ok obj2 not instanceof Brauhaus.Spice

    describe 'checkKeyVal', ->
        simpleKey = 'key'
        simpleVal = 1

        arrayKey = ['more', ['complex', 'keys', 'are'], 'fun']
        arrayVal = [1, [2, 3, 4], 5]

        it 'Should handle simple key/val pairs', ->
            assert.ok Diff.util.checkKeyVal(simpleKey, simpleVal, simpleKey, simpleVal)
            assert.ok not Diff.util.checkKeyVal(simpleKey, simpleVal, 'other', simpleVal)
            assert.ok not Diff.util.checkKeyVal(simpleKey, simpleVal, simpleKey, 0)
            assert.ok not Diff.util.checkKeyVal(simpleKey, simpleVal, arrayKey, simpleVal)

        it 'Should handle key/val arrays', ->
            assert.ok Diff.util.checkKeyVal(arrayKey,
                                            arrayVal,
                                            ['more', ['complex', 'keys', 'are'], 'fun'],
                                            [1, [2, 3, 4], 5])
            assert.ok not Diff.util.checkKeyVal(arrayKey,
                                                arrayVal,
                                                ['more', ['complex', 'keys', 'arent'], 'fun'],
                                                [1, [2, 3, 4], 5])
            assert.ok not Diff.util.checkKeyVal(arrayKey,
                                                arrayVal,
                                                ['more', ['complex', 'keys', 'are'], 'fun'],
                                                [1, [100, 3, 4], 5])
            assert.ok not Diff.util.checkKeyVal(arrayKey, arrayVal, simpleKey, arrayVal)

    describe 'getKeyVal, getValForKey', ->
        obj1 = {a: 1, b: 2, c: 3, _diffKeys: ['a', 'b', 'c']}
        obj2 = {a: 1, b: 2, c: 4, _diffKeys: ['a', ['b', 'c']]}
        obj3 = {a: 1, b: 2, c: 3}

        it 'Should handle all valid key levels', ->
            assert.deepEqual Diff.util.getKeyVal(obj1, 0), ['a', obj1.a]
            assert.deepEqual Diff.util.getKeyVal(obj1, 1), ['b', obj1.b]
            assert.deepEqual Diff.util.getKeyVal(obj1, 2), ['c', obj1.c]
            assert.deepEqual Diff.util.getKeyVal(obj2, 0), ['a', obj1.a]
            assert.deepEqual Diff.util.getKeyVal(obj2, 1), [['b', 'c'], [obj2.b, obj2.c]]

        it 'Should return ["_nokey", undefined] for invalid key levels', ->
            assert.equal Diff.util.getKeyVal(obj1, 3)[0], '_nokey'
            assert.equal Diff.util.getKeyVal(obj2, 2)[0], '_nokey'
            assert.equal Diff.util.getKeyVal(obj3, 0)[0], '_nokey'

        it 'Should cache values', ->
            assert.deepEqual Diff.util.getKeyVal(obj1, 0), ['a', obj1.a]
            assert.deepEqual obj1._diffKeyVal[0], ['a', obj1.a]

    describe 'arrayCompare', ->
        arr1 = [1]
        arr2 = [1, 2, [3, 4, 5], 6, [7, [8, 9]]]

        it 'Should pass identical arrays', ->
            assert.ok Diff.util.arrayCompare(arr1, arr1)
            assert.ok Diff.util.arrayCompare(arr2, arr2)

        it 'Should pass arrays with the same values', ->
            assert.ok Diff.util.arrayCompare(arr1, [1])
            assert.ok Diff.util.arrayCompare(arr2, [1, 2, [3, 4, 5], 6, [7, [8, 9]]])

        it 'Should not pass arrays with different values', ->
            assert.ok not Diff.util.arrayCompare(arr1, [2])
            assert.ok not Diff.util.arrayCompare(arr2, [1, 2, [3, 4, 5], 6, [100, [8, 9]]])

        it 'Should handle arrays with different dimensions/shapes', ->
            assert.ok not Diff.util.arrayCompare(arr2, arr1)

    describe 'getKeyValScore', ->
        it 'Should return 2 for simple key/pair match', ->
            assert.equal Diff.util.getKeyValScore('key', 1, 'key', 1), 2
            assert.equal Diff.util.getKeyValScore('key', 'test', 'key', 'test'), 2

        it 'Should return 1 for key-only match', ->
            assert.equal Diff.util.getKeyValScore('key', 1, 'key', 2), 1
            assert.equal Diff.util.getKeyValScore('key', 'test', 'key', 'testa'), 1

        it 'Should handle complex key/pair matches', ->
            assert.equal Diff.util.getKeyValScore(['a', 'b'], [1, 2], ['a', 'b'], [1, 2]), 4
            assert.equal Diff.util.getKeyValScore(['a', 'b'], [1, 2], ['a', 'b'], [1, 1]), 3
            assert.equal Diff.util.getKeyValScore(['a', 'b'], [1, 2], ['c', 'b'], [1, 2]), 2
            assert.equal Diff.util.getKeyValScore(['a', 'b'], [1, 2], ['a', 'c'], [2, 2]), 1

    describe 'getOne', ->
        it 'Should return the first available object', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]

            assert.equal Diff.util.getOne(root), c1
            root.remove c1
            assert.equal Diff.util.getOne(root), c2
            assert.equal Diff.util.getOne(c4), c4

    describe 'getMatchScore', ->
        it 'Should return an array', ->
            assert.ok Diff.util.getMatchScore(c1, c2, 0) instanceof Array

        it 'Should work on objects with keys', ->
            assert.deepEqual Diff.util.getMatchScore(c1, c2, 0), [2, 2, 1]

        it 'Should work on objects missing keys', ->
            assert.deepEqual Diff.util.getMatchScore(c1, {}, 0), [0, 0, 0]
            assert.deepEqual Diff.util.getMatchScore({}, {}, 0), [0]

        it 'Should work on objects with mixed keys', ->
            a = {a: 1, x: 1, c: 3, _diffKeys: ['a', 'x', 'c']}
            assert.deepEqual Diff.util.getMatchScore(c1, a, 0), [2, 0, 1]

        it 'Should work on all key levels', ->
            assert.deepEqual Diff.util.getMatchScore(c1, c2, 1), [2, 1]
            assert.deepEqual Diff.util.getMatchScore(c1, c2, 2), [1]

    describe 'getDirection', ->
        it 'Should default to left-to-right', ->
            assert.equal Diff.util.getDirection(), Diff.util.Directions.LeftToRight

        it 'Should should accept "f", "forward", "rightToLeft", and "rtol" as right-to-left', ->
            rtol = Diff.util.Directions.RightToLeft
            assert.equal Diff.util.getDirection('f'), rtol
            assert.equal Diff.util.getDirection('forward'), rtol
            assert.equal Diff.util.getDirection('rightToLeft'), rtol
            assert.equal Diff.util.getDirection('rtol'), rtol

        it 'Should should accept "b", "backward", "leftToRight", and "ltor" as left-to-right', ->
            ltor = Diff.util.Directions.LeftToRight
            assert.equal Diff.util.getDirection('b'), ltor
            assert.equal Diff.util.getDirection('backward'), ltor
            assert.equal Diff.util.getDirection('leftToRight'), ltor
            assert.equal Diff.util.getDirection('ltor'), ltor

    describe 'simpleCompare', ->
        it 'Should compare simple values', ->
            assert.ok Diff.util.simpleCompare(1, 1)
            assert.ok not Diff.util.simpleCompare(1, 2)

            assert.ok Diff.util.simpleCompare('test', 'test')
            assert.ok not Diff.util.simpleCompare('test', 't')

            assert.ok not Diff.util.simpleCompare('5', 5)

            assert.ok Diff.util.simpleCompare(true, true)
            assert.ok not Diff.util.simpleCompare(true, false)

        it 'Should evaluate objects as equal regardless of content', ->
            assert.ok Diff.util.simpleCompare({}, {a: 1})
            assert.ok Diff.util.simpleCompare({b: 4}, [])

describe 'FailState', ->
    it 'Should default to failing', ->
        f = new Diff.util.FailState
        assert.ok f.fail
        assert.ok f.canFail

    it 'Should manage key state unless failing is false', ->
        f = new Diff.util.FailState true
        f.push 'a'
        f.push 'b'
        assert.deepEqual f.state, ['a', 'b']
        f.pop()
        assert.deepEqual f.state, ['a']
        f.pop()
        assert.deepEqual f.state, []

        f = new Diff.util.FailState false
        f.push 'a'
        f.push 'b'
        assert.deepEqual f.state, []
        f.pop()
        assert.deepEqual f.state, []
        f.pop()
        assert.deepEqual f.state, []

    describe 'toFailState', ->
        it 'Should return the passed in value if already a FailState', ->
            f = new Diff.util.FailState
            assert.equal Diff.util.FailState.toFailState(f), f

        it 'Should wrap the value in a fail state otherwise', ->
            assert.ok Diff.util.FailState.toFailState(true) instanceof Diff.util.FailState

    describe 'check', ->
        checkException = (state, expected, actual) ->
            # Workaround for browser testing, since chai's assert.throws
            # doesn't accept a validation function like node's assert.
            if chai? and assert is chai.assert
                Error
            else
                (error) ->
                    return false if error not instanceof Error
                    assert.deepEqual state, error.keys
                    assert.equal expected, error.expected
                    assert.equal actual, error.actual
                    true

        it 'Should throw if failing is true and a simpleCompare fails', ->
            f = new Diff.util.FailState true
            assert.throws (-> f.check 1, 2), checkException([], 1, 2)
            assert.throws (-> f.check 'test', 'asd'), checkException([], 'test', 'asd')
            f.push 'a'
            f.push 'b'
            assert.throws (-> f.check 1, '1'), checkException(['a', 'b'], 1, '1')

        it 'Should not throw if failing is true and simpleCompare passes', ->
            f = new Diff.util.FailState true
            assert.doesNotThrow (-> f.check 1, 1)
            assert.doesNotThrow (-> f.check '1', '1')

        it 'Should not throw if failing is false', ->
            f = new Diff.util.FailState false
            assert.doesNotThrow (-> f.check 1, 1)
            assert.doesNotThrow (-> f.check '1', '1')
            assert.doesNotThrow (-> f.check 1, 2)
            assert.doesNotThrow (-> f.check '1', 'test')

        it 'Should not throw if the fail function returns false', ->
            pass = -> false
            f = new Diff.util.FailState pass
            assert.doesNotThrow (-> f.check 1, 1)
            assert.doesNotThrow (-> f.check '1', '1')
            assert.doesNotThrow (-> f.check 1, 2)
            assert.doesNotThrow (-> f.check '1', 'test')

        it 'Should throw if the fail function returns true', ->
            fail = -> true
            f = new Diff.util.FailState true
            assert.throws (-> f.check 1, 2), checkException([], 1, 2)
            assert.throws (-> f.check 'test', 'asd'), checkException([], 'test', 'asd')
            assert.throws (-> f.check 1, '1'), checkException([], 1, '1')

            fail = (path, expected, actual) -> if path.length > 0 then false else true
            f.fail = fail
            assert.throws (-> f.check 1, 2), checkException([], 1, 2)
            f.push 'key'
            assert.doesNotThrow (-> f.check 1, 2)

        it 'Should pass the key path, expected, and actual vals to fail functions', ->
            tester = (p, e, a) ->
                (path, expected, actual) ->
                    assert.deepEqual path, p
                    assert.equal expected, e
                    assert.equal actual, a
                    false

            f = new Diff.util.FailState tester(['a', 'q'], 'test', 4)
            f.push 'a'
            f.push 'q'
            f.check 'test', 4
