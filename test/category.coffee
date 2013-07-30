Brauhaus = @Brauhaus ? require 'brauhaus'
Diff = Brauhaus.Diff ? require('../lib/brauhaus-diff')
Diff.configure({exportUtil: true})
assert = assert ? require 'assert'

helper = helper ? require './helper/helper'

c1 = helper.c1
c2 = helper.c2
c3 = helper.c3
c4 = helper.c4

describe 'Category', ->
    it 'Should have a unique object after construction', ->
        cat = new Diff.util.Category 'key', 1, c1
        assert.equal cat.obj, c1

    describe 'categorize, processLevel', ->
        it 'Should return a root node', ->
            root = Diff.util.Category.categorize [c1, c2, c3]
            assert.ok root instanceof Diff.util.Category
            assert.ok root.key is '_root'
            assert.ok root.val is null
            assert.ok root.obj?

        it 'Should contain a valid category even for one input', ->
            root = Diff.util.Category.categorize [c1]
            assert.ok root instanceof Diff.util.Category
            assert.ok root.key is '_root'
            assert.ok root.val is null
            assert.ok root.obj instanceof Array
            assert.ok root.obj[0] instanceof Diff.util.Category

        it 'Should handle unique, simple keys', ->
            root = Diff.util.Category.categorize [c1, c2, c3]
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            expected.add               new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected), JSON.stringify(root) + " | " + JSON.stringify(root)

        it 'Should handle non-unique, simple keys', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            expected = new Diff.util.Category '_root', null, []
            expected.add                      new Diff.util.Category 'a', 1, []
            expected.obj[0].add               new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add        new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add        new Diff.util.Category 'c', 2, []
            expected.obj[0].obj[0].obj[1].add c2
            expected.obj[0].obj[0].obj[1].add c4
            expected.add                      new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected)

        it 'Should handle unique, complex keys', ->
            # Switch to complex keys
            helper.C.setKeys ['a', ['b', 'c']]

            root = Diff.util.Category.categorize [c1, c2, c3]
            expected = new Diff.util.Category '_root', null, []
            expected.add        new Diff.util.Category 'a', 1, []
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 1], c1
            expected.obj[0].add new Diff.util.Category ['b', 'c'], [1, 2], c2
            expected.add        new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected)

        it 'Should handle non-unique, complex keys', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category ['b', 'c'], [1, 1], c1
            expected.obj[0].add        new Diff.util.Category ['b', 'c'], [1, 2], []
            expected.obj[0].obj[1].add c2
            expected.obj[0].obj[1].add c4
            expected.add               new Diff.util.Category 'a', 2, c3

            assert.ok helper.compareBothWays(root, expected)

            # Back to simple keys
            helper.C.setKeys ['a', 'b', 'c']

        it 'Should handle missing keys', ->
            badObj =
                _diffKeys: ['a']
                a: 2

            root = Diff.util.Category.categorize [c1, c2, c3, badObj]
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            expected.add               new Diff.util.Category 'a', 2, []
            expected.obj[1].add        new Diff.util.Category 'b', 2, c3
            expected.obj[1].add        new Diff.util.Category '_nokey', undefined, badObj

            assert.ok helper.compareBothWays(root, expected)

        it 'Should handle objects with different key types', ->
            otherObj =
                _diffKeys: ['x', 'y', 'z']
                x: 1
                y: 2
                z: 3

            otherc2 =
                _diffKeys: ['a', ['b', 'c']]
                a: 1
                b: 1
                c: 1

            root = Diff.util.Category.categorize [c1, c2, c3, otherObj, otherc2]
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c2
            expected.obj[0].add        new Diff.util.Category ['b', 'c'], [1, 1], otherc2
            expected.add               new Diff.util.Category 'a', 2, c3
            expected.add               new Diff.util.Category 'x', 1, otherObj

            assert.ok helper.compareBothWays(root, expected)

    describe 'add', ->
        cat = new Diff.util.Category 'key', 1, c1
        cat.add c2
        
        it 'Should convert a unique value to an array', ->    
            assert.deepEqual cat.obj, [c1, c2]

        it 'Should append values to the object array', ->
            cat.add c3
            assert.deepEqual cat.obj, [c1, c2, c3]

    describe 'remove', ->
        it 'Should handle terminal values', ->
            cat = new Diff.util.Category 'key', 1, c1
            cat.remove c1
            assert.equal cat.obj, null

        it 'Should handle terminal value lists', ->
            cat = new Diff.util.Category 'key', 1, c1
            cat.add c2
            cat.add c3
            cat.remove c2
            assert.deepEqual cat.obj, [c1, c3]

        it 'Should handle categories', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            root.remove c2
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c4
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            root.remove c2
            assert.ok helper.compareBothWays(root, expected)

            root.remove c4
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            root.remove c3
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            assert.ok helper.compareBothWays(root, expected)

            root.remove c1
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

        it 'Should return true if the value was removed, false otherwise', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4, c4]
            assert.ok root.remove c2
            assert.ok not root.remove c2
            assert.ok root.remove c3

            cat = new Diff.util.Category 'a', 1, c1
            assert.ok not cat.remove c2
            assert.ok cat.remove c1

        it 'Should handle all key levels', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            assert.ok root.obj[0].remove(c2)
            assert.ok not root.obj[0].remove(c3)
            assert.ok root.obj[0].obj[0].remove(c1)

    describe 'cleanUp', ->
        it 'Should handle terminal values', ->
            cat = new Diff.util.Category 'key', 1, c1
            cat.cleanUp 0, 1
            assert.equal cat.obj, null

        it 'Should handle arrays', ->
            cat = new Diff.util.Category 'key', 1, c1
            cat.add c2
            cat.add c3
            cat.add c4

            cat.cleanUp 0, 1
            assert.deepEqual cat.obj, [c2, c3, c4]

            cat.cleanUp 1, 1
            assert.deepEqual cat.obj, [c2, c4]

            cat.cleanUp 0, 2
            assert.deepEqual cat.obj, null

            cat.obj = [c1, c2]
            cat.cleanUp 1, 1
            assert.equal cat.obj, c1

            cat = new Diff.util.Category 'key', 1, []
            subcat = new Diff.util.Category('subkey', 0, c1)
            cat.add subcat
            cat.add new Diff.util.Category('subkey', 1, c2)
            cat.cleanUp 1, 1
            assert.deepEqual cat.obj, [subcat]

        it 'Should handle 0 count input', ->
            cat = new Diff.util.Category 'key', 1, []
            cat.cleanUp 0, 0
            assert.equal cat.obj, null

            cat.obj = [c1]
            cat.cleanUp 0, 0
            assert.equal cat.obj, c1

            cat.obj = c1
            cat.cleanUp 0, 0
            assert.equal cat.obj, c1

    describe 'getType', ->
        it 'Should return Category.Type.Unique for unique values', ->
            assert.equal (new Diff.util.Category 'key', 1, 1).getType(), Diff.util.Category.Type.Unique

        it 'Should return Category.Type.List for lists of values', ->
            assert.equal (new Diff.util.Category 'key', 1, [1, 2]).getType(), Diff.util.Category.Type.List

        it 'Should return Category.Type.Category for sub-categories', ->
            subcat = new Diff.util.Category 'a', 1, 1
            assert.equal (new Diff.util.Category 'key', 1, [subcat]).getType(), Diff.util.Category.Type.Category

describe 'CategoryIterator', ->
    describe 'next', ->
        it 'Should handle terminal values', ->
            cat = new Diff.util.Category 'key', 1, c1
            it = new Diff.util.CategoryIterator cat
            assert.equal it.next(), c1
            assert.equal it.next(), null

            cat.add c2
            it = new Diff.util.CategoryIterator cat
            assert.equal it.next(), c1
            assert.equal it.next(), c2
            assert.equal it.next(), null

        it 'Should handle categories', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            it = new Diff.util.CategoryIterator root
            assert.equal it.next(), c1
            assert.equal it.next(), c2
            assert.equal it.next(), c4
            assert.equal it.next(), c3
            assert.equal it.next(), null

    describe 'remove', ->
        it 'Should handle terminal values', ->
            cat = new Diff.util.Category 'key', 1, c1
            it = new Diff.util.CategoryIterator cat
            it.next()
            it.remove()
            assert.equal cat.obj, null
            assert.equal it.next(), null

        it 'Should handle terminal value lists', ->
            cat = new Diff.util.Category 'key', 1, c1
            cat.add c2
            it = new Diff.util.CategoryIterator cat
            it.next()
            it.remove()
            assert.equal cat.obj, c2
            assert.equal it.next(), c2
            it.remove()
            assert.equal cat.obj, null
            assert.equal it.next(), null

            cat.obj = [c1, c2, c3]
            it = new Diff.util.CategoryIterator cat
            it.next()
            it.next()
            it.remove()
            assert.deepEqual cat.obj, [c1, c3]
            assert.equal it.next(), c3

            assert.equal it.next(), null
            assert.ok not it.remove()

        it 'Should handle categories', ->
            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            it = new Diff.util.CategoryIterator root
            it.next()
            it.next()
            it.remove()
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, c4
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            it.next()
            it.remove()
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)

            it.next()
            it.remove()
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 1, c1
            assert.ok helper.compareBothWays(root, expected)

            it = new Diff.util.CategoryIterator root
            it.next()
            it.remove()
            expected = new Diff.util.Category '_root', null, null
            assert.ok helper.compareBothWays(root, expected)

            # Check to make sure no more deletes happen
            assert.ok not it.remove()

            root = Diff.util.Category.categorize [c1, c2, c3, c4]
            it = new Diff.util.CategoryIterator root
            it.next()
            it.remove()
            expected = new Diff.util.Category '_root', null, []
            expected.add               new Diff.util.Category 'a', 1, []
            expected.obj[0].add        new Diff.util.Category 'b', 1, []
            expected.obj[0].obj[0].add new Diff.util.Category 'c', 2, []
            expected.obj[0].obj[0].obj[0].add c2
            expected.obj[0].obj[0].obj[0].add c4
            expected.add               new Diff.util.Category 'a', 2, c3
            assert.ok helper.compareBothWays(root, expected)
