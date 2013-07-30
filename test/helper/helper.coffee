Brauhaus = @Brauhaus ? require 'brauhaus'
Diff = Brauhaus.Diff ? require('../lib/brauhaus-diff').configure({exportUtil: true})

helper = if exports? then exports else @helper = {}

# Utility functions to compare Category trees
helper.compareTrees = (left, right) ->
    if (left.obj instanceof Array) != (right.obj instanceof Array)
        return false
    if left.obj instanceof Array
        if (left.obj[0] instanceof Diff.util.Category) != (right.obj[0] instanceof Diff.util.Category)
            return false
        if left.obj[0] instanceof Diff.util.Category
            for leftObj in left.obj
                found = false
                for rightObj in right.obj
                    if Diff.util.checkKeyVal leftObj.key, leftObj.val, rightObj.key, rightObj.val
                        found = helper.compareTrees leftObj, rightObj
                        break
                if not found
                    return false
        else
            for leftObj in left.obj
                found = false
                for rightObj in right.obj
                    if leftObj is rightObj
                        found = true
                        break
                if not found
                    return false
        true
    else
        if left.obj isnt right.obj
            false
        else
            true

helper.compareBothWays = (left, right) ->
    s = helper.compareTrees left, right
    if s then helper.compareTrees(right, left) else s

helper.uncache = (obj...) ->
    for o in obj
        delete o._diffKeyVal

# Objects used in several tests
class helper.C
    _diffKeys: ['a', 'b', 'c']
    constructor: (a, b, c) ->
        @a = a
        @b = b
        @c = c

    @setKeys = (keys) ->
        C::_diffKeys = keys
        helper.uncache helper.c1, helper.c2, helper.c3, helper.c4

helper.c1 = new helper.C 1, 1, 1
helper.c2 = new helper.C 1, 1, 2
helper.c3 = new helper.C 2, 2, 1
helper.c4 = new helper.C 1, 1, 2
