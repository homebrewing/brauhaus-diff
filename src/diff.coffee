###
Compute the diff between two objects or arrays, left and right. Left is
considered the newer object, such that the returned diff will convert right to
left when applied forward, or convert left to right when applied backward.
###
Diff.diff = (left, right) ->
    if diffutil.areAll Array, left, right
        objtest = (arr) ->
            for obj in arr
                return false if obj not instanceof Object or obj instanceof Array
            true

        if objtest(left) and objtest(right)
            diff = new ObjectArrayDiff left, right
        else
            diff = new ObjectDiff left, right
    else if diffutil.areAll(Object, left, right) and diffutil.compatibleTypes(left, right)
        diff = new ObjectDiff left, right
    else if left != right
        diff = new ValueDiff left, right
    else
        diff = {}

    diff

# Run the post diff function for a diff. If the post diff functions for left
# and right are the same, only call it once, otherwise call both.
postDiff = (left, right, diff) ->
    if typeof left?.postDiff is 'function'
        leftpd = left.postDiff
    else if typeof left?.constructor.postDiff is 'function'
        leftpd = left.constructor.postDiff
    
    if typeof right?.postDiff is 'function'
        rightpd = right.postDiff
    else if typeof right?.constructor.postDiff is 'function'
        rightpd = right.constructor.postDiff

    leftpd(left, right, diff) if leftpd?
    rightpd(left, right, diff) if rightpd? and rightpd isnt leftpd
    return # Needed so the result of rightpd isn't returned

###
Apply a diff to an object.

Diff can be either a single diff object or an array of diffs to be applied.
If multiple diffs are used, the diffs are applied to the object in the order of
iteration. The direction specifies the direction of the diff, i.e. is obj on
the left (backward) or right (forward), not the direction of iteration for
multiple diffs.

Valid directions are "f", "forward", "rightToLeft", and "rtol" for converting
a right object to a left object, or "b", "backward", "leftToRight", and "ltor"
for converting a left object to a right object. Backward diff is the default.

The fail parameter can either be a boolean or a function, indicating whether
the diff should abort when it encounters an inconsistency. For instance, if an
array diff can't find the object it's looking for, or a value diff determines
the current value isn't what was expected, it is considered an inconsistency.
If fail is true (the default), the diff will throw an exception. If fail is
false, the diff will continue silently if possible. If fail is a function, it
should take three parameters:
  1. An array that contains each key in the path to the failed object
  2. The expected value
  3. The actual value
The function should return true to abort (which throws the exception), or false
to abort to continue.

The returned object is a copy of the input object with the diff applied.

TODO: try to infer the direction based on the object and diff
###
Diff.apply = (obj, diff, direction, fail) ->
    # Convert to a usable diff
    if typeof diff is 'string'
        diff = Diff.parse diff
    else if diff instanceof Array
        for d, i in diff
            diff[i] = Diff.parse(d) if typeof d is 'string'

    if diff instanceof Array
        obj = d.apply(obj, direction, fail) for d in diff
    else
        obj = diff.apply obj, direction, fail

    obj

# Run the post apply function for a diff.
postApply = (obj, diff, direction) ->
    if typeof obj?.postApply is 'function'
        obj.postApply obj, diff, direction
    else if typeof obj?.constructor.postApply is 'function'
        obj.constructor.postApply obj, diff, direction
    obj

###
Combine multiple sequential diffs into a single diff. The diffs are processed
in the order of iteration. Direction gives the diff direction between
sequential pairs. The directions supported are the same as for Diff.apply.

TODO: implement!
###
Diff.combine = (diffs, direction) ->
    # Not implemented yet
    throw new Error 'not implemented yet'

###
Convert a JSON string into a diff object.
###
Diff.parse = (jsonOrObj) ->
    if typeof jsonOrObj is 'string'
        obj = JSON.parse jsonOrObj
    convertToDiffObject obj ? jsonOrObj

# Convert a regular object to one of the Diff objects
convertToDiffObject = (obj) ->
    if obj instanceof Array
        if obj.length > 0 and obj[0]?._h?
            ObjectArrayDiff.fromObject obj
        else if obj.length is 2
            ValueDiff.fromObject obj
        else
            throw new TypeError 'Trying to inflate non-diff object: ' + JSON.stringify(obj)
    else if obj instanceof Object
        ObjectDiff.fromObject obj
    else
        throw new TypeError 'Trying to inflate non-diff object: ' + JSON.stringify(obj)

###
Diff of two values.
###
class ValueDiff
    constructor: (left, right) ->
        if left not instanceof Array and left instanceof Object
            @left = diffutil.diffCopy left
        else
            @left = left
        if right not instanceof Array and right instanceof Object
            @right = diffutil.diffCopy right
        else
            @right = right

        postDiff left, right, this

    toJSON: ->
        [@left, @right]

    # Apply a diff. The parameters are similar to Diff.apply with the exception
    # of type. If type is given, the returned value will be `new type(obj)`
    # instead of `obj`.
    apply: (obj, direction, fail, type) ->
        fail = FailState.toFailState fail

        if diffutil.getDirection(direction) is diffutil.Directions.LeftToRight
            fail.check(@left, obj)
            obj = if type? then new type(@right) else @right
        else
            fail.check(@right, obj)
            obj = if type? then new type(@left) else @left

        postApply obj, this, direction

    @fromObject = (obj) ->
        new ValueDiff obj[0], obj[1]

###
Diff of a non-array object or an array of non-objects. The keys are those that
changed on the diffed object, with values set to an array containing [new, old].
###
class ObjectDiff
    constructor: (left, right) ->
        # If nothing was passed in, assume we're meant to be constructed from
        # a single object, which will be done by fromObject
        if not left? and not right?
            return

        # Get the JSON-ified object if it exists
        leftObj = if typeof left.toJSON is 'function' then left.toJSON() else left
        rightObj = if typeof right.toJSON is 'function' then right.toJSON() else right

        # Get the keys found in left, right, and both
        [leftKeys, rightKeys, bothKeys] = diffutil.getKeys leftObj, rightObj

        # Get the keys that were added
        @[key] = new ValueDiff(leftObj[key], null) for key in leftKeys

        # Get the keys that were removed
        @[key] = new ValueDiff(null, rightObj[key]) for key in rightKeys

        # Handle keys found in both
        for key in bothKeys
            tmp = Diff.diff leftObj[key] ? null, rightObj[key] ? null
            @[key] = tmp if not diffutil.isEmpty tmp

        postDiff left, right, this

    # Apply a diff. The parameters are similar to Diff.apply, with the
    # exception of type. If type is given, the returned object will be
    # `new type(obj)` instead of `obj`.
    apply: (obj, direction, fail, type) ->
        if obj not instanceof Object
            throw new Error 'Object diff being applied to non-object'

        # Create a copy so we don't modify the original object
        obj = diffutil.shallowCopy obj

        fail = FailState.toFailState fail
        for key, val of this when diffutil.keyPass key, val
            subtype = obj._paramMap?[key]
            fail.push key
            # If we have an array diff, make sure we're processing an array
            if val instanceof ObjectArrayDiff and obj[key] not instanceof Array
                fail.check 'array', typeof obj[key]
            else
                obj[key] = val.apply obj[key], direction, fail, subtype
            fail.pop()

        if type?
            obj = new type(obj)
        postApply obj, this, direction

    # Convert a regular object into an ObjectDiff
    @fromObject: (obj) ->
        diff = new ObjectDiff
        diff[key] = convertToDiffObject(val) for key, val of obj
        diff

###
Diff of an array.
###
class ObjectArrayDiff
    # Return the internal diff array so that it gets square braces when
    # serialized
    toJSON: ->
        @diff ? []

    constructor: (left, right) ->
        # If nothing was passed in, assume we're meant to be constructed from
        # a single object, which will be done by fromObject
        if not left? and not right?
            return

        # Matching pairs are searched for in the following ways:
        # 1. Look for an exact, unique match
        # 2. If exact, non-unique matches, pick the first possible choice
        # 3. If no exact matches, look for a similar match (primary key match,
        #    other keys may or may not match)
        # 4. If still no matches, look for "similar" primary key (levenshtein)
        #    and repeat 1-3
        # 5. If no similar matches, remain unmatched (add / sub)

        # Categorize the arrays based on the primary key
        leftCat = Category.categorize left
        rightCat = Category.categorize right

        # Look through for unique matches
        pairs = oad.getPairs leftCat, rightCat

        # Add fuzzy matches (if any)
        if leftCat.obj? and rightCat.obj?
            pairs = pairs.concat(oad.fuzzyMatch leftCat, rightCat)

        # Second pass, find additions / deletions
        if leftCat.obj?
            it = new CategoryIterator leftCat
            while (leftObj = it.next())?
                pairs.push [leftObj, null]

        if rightCat.obj?
            it = new CategoryIterator rightCat
            while (rightObj = it.next())?
                pairs.push [null, rightObj]

        # Start doing the actual diffs
        @diff = []
        for pair in pairs
            if pair[0]? and pair[1]?
                # Remove cached values before doing the diff
                delete pair[0]._diffKeyVal
                delete pair[1]._diffKeyVal
                diff = Diff.diff pair[0], pair[1]
                if not diffutil.isEmpty diff
                    diff._h = new ValueDiff diffutil.hash(pair[0]), diffutil.hash(pair[1])
            else
                tmp = pair[0] ? pair[1]
                # Remove cached values before doing the diff
                delete tmp._diffKeyVal
                diff = diffutil.diffCopy tmp
                hash = diffutil.hash tmp
                diff._h = if pair[0]? then new ValueDiff(hash, null) else new ValueDiff(null, hash)
            @diff.push diff if not diffutil.isEmpty diff

        delete @diff if @diff.length is 0

        postDiff left, right, this

    # Get a set of pairs from left and right.
    @getPairs = (left, right) ->
        # There are 9 possible combinations of left and right based on the
        # three possible types of values for Category trees.
        # The value types are:
        #   1. A single, terminal value (unique)
        #   2. A list of terminal values (list)
        #   3. A list of categories (categories)
        # The combination possibilities are
        #   1. Unique vs. unique
        #   2. Unique vs. list
        #   3. Unique vs. categories
        #   4. List vs. unique
        #   5. List vs. list
        #   6. List vs. categories
        #   7. Categories vs. unique
        #   8. Categories vs. list
        #   9. Categories vs. categories
        lType = left.getType()
        rType = right.getType()

        # Combos 1, 2, and 3
        if lType is Category.Type.Unique
            # Combo 1
            if rType is Category.Type.Unique
                oad.uniqueVsUnique left, right

            # Combos 2 and 3
            else
                oad.uniqueVsArray left, right, false

        # Combos 4 and 7
        else if rType is Category.Type.Unique
            oad.uniqueVsArray right, left, true

        # Combos 8 and 9
        else if lType is Category.Type.Category
            # Combo 9
            if rType is Category.Type.Category
                oad.catVsCat left, right

            # Combo 8
            else
                oad.listVsCategory right, left, true

        # Combo 6
        else if rType is Category.Type.Category
            oad.listVsCategory left, right, false

        # Combo 5
        else
            oad.listVsList left, right

    # Both left and right categories contain a unique value, this is a simple,
    # direct match.
    @uniqueVsUnique = (left, right) ->
        ret = [[left.obj, right.obj]]
        left.cleanUp 0, 1
        right.cleanUp 0, 1
        ret

    # Pair a unique value against an array of values. We search the array to
    # find the best match for the unique value. If no matches can be made, then
    # the array is empty and an empty list is returned.
    # If swap is true, the returned pair is [match, unique], otherwise it is
    # [unique, match].
    @uniqueVsArray = (unique, arr, swap) ->
        match = oad.takeBestMatch unique.obj, arr
        if match?
            ret = if swap then [[match, unique.obj]] else [[unique.obj, match]]
            unique.cleanUp 0, 1
            ret
        else
            []

    # Pair a list of terminal values against a list of categories. If no pairs
    # can be created, an empty list is returned.
    # If swap is true, the returned pairs are [match, listobject], otherwise
    # they are [listobject, match].
    @listVsCategory = (list, cat, swap) ->
        pairs = []
        count = 0
        for listObj in list.obj
            match = oad.takeBestMatch listObj, cat
            if match?
                pairs.push if swap then [match, listObj] else [listObj, match]
                ++count
            else
                break
            break if not cat.obj?
        list.cleanUp 0, count
        pairs

    # Pair a list of terminal values against a list of terminal values. If no
    # pairs can be created, then one of the lists is empty and an empty list is
    # returned.
    @listVsList = (left, right) ->
        pairs = []
        length = Math.min left.obj.length, right.obj.length
        pairs.push [left.obj[i], right.obj[i]] for i in [0...length]
        left.cleanUp 0, length
        right.cleanUp 0, length
        pairs

    # Pair a list of categories against another list of categories. If no pairs
    # can be created, an empty list is returned. This will first look for exact
    # matches across the lists of categories, then optionally perform a second
    # pass looking for matches across the top-level categories (left and
    # right). The secondPass parameter should ideally be set to false for root
    # nodes (level = -1), and true for any other node (level >= 0).
    @catVsCat = (left, right, secondPass) ->
        # Default parameters
        secondPass ?= left.level >= 0

        # Use an external loop variable since we'll be slicing and dicing our
        # arrays during processing
        i = 0
        pairs = []
        for _unused in left.obj
            leftCat = left.obj[i]
            for rightCat, j in right.obj
                # Look for a matching left and right category
                if diffutil.checkKeyVal leftCat.key, leftCat.val, rightCat.key, rightCat.val
                    pairs = pairs.concat(oad.getPairs leftCat, rightCat)

                    # Clean up right's category list
                    if rightCat.obj is null
                        right.obj.splice j, 1
                    break

            # Clean up left's category list
            if leftCat.obj is null
                left.obj.splice i, 1
            else
                ++i

            # Break out of processing if there are no more right values to check against
            if right.obj.length is 0
                break

        # Clean up both left and right as necessary
        left.cleanUp 0, 0
        right.cleanUp 0, 0

        if secondPass and left.obj? and right.obj?
            pairs = pairs.concat(oad.catVsCatSecondPass left, right)

        pairs

    # Pair a list of categories against another list of categories, when the
    # sub-categories failed to find matches. This is the second pass of the
    # catVsCat algorithm. It basically does a two-way match to find the pairs
    # that match best between left and right. E.g. bestMatch(leftObject)
    # returns rightObj and bestMatch(rightObj) returns leftObj.
    # This function can also work as a general replacement for catVsCat (and
    # all the other functions), but is about 35% slower in the test cases I
    # tried.
    @catVsCatSecondPass = (left, right) ->
        # Check that the best match for match is obj. If not, take the match
        # and try to find its best match, then do the same. Keep going until
        # a pair of matches points at each other.
        getMatchPair = (obj, match, onLeft) ->
            other = oad.bestMatch match, (if onLeft then left.obj else right.obj), left.level + 1
            if obj is other
                if onLeft then [obj, match] else [match, obj]
            else
                getMatchPair match, other, not onLeft

        pairs = []
        loop
            # We took everything there is to take
            if not right.obj? or not left.obj?
                break

            # Get the first available value to test. It's important for this
            # algorithm to work that the first object always be used and that
            # the order of iteration be consistent. Otherwise we might wind up
            # with circular best matches and an infinite loop.
            # The same consideration applies to the bestMatch function.
            it = new CategoryIterator left
            obj = it.next()
            if not obj?
                break

            # The last right object, we know we're done
            if right.obj not instanceof Array
                pairs.push [obj, right.obj]
                it.remove()
                right.cleanUp 0, 1
                break

            match = oad.bestMatch obj, right.obj, left.level + 1
            if not match?
                break

            # Get the pair and remove the matched items from left and right
            pair = getMatchPair obj, match, true
            if pair[0] is obj
                it.remove()
            else
                left.remove pair[0]
            right.remove pair[1]
            pairs.push pair

        pairs

    # Find the best match for the given object in the given array. Level must
    # be the level of the array passed in (e.g. if passing the root nodes'
    # object, level will be 0, not -1).
    @bestMatch = (obj, arr, level) ->
        matches = []
        bestScore = 0
        [objKey, objVal] = diffutil.getKeyVal obj, level

        updateScore = (k, v, o) ->
            score = diffutil.getKeyValScore objKey, objVal, k, v
            if score > bestScore
                matches = if o instanceof Array then [].concat(o) else [o]
                bestScore = score
            else if score is bestScore
                if o instanceof Array
                    matches = matches.concat o
                else
                    matches.push o

        for a in arr
            if a instanceof Category
                updateScore a.key, a.val, a.obj
            else
                [aKey, aVal] = diffutil.getKeyVal a, level
                updateScore aKey, aVal, a

        if objKey is '_nokey'
            # We can't go any deeper, so just pick the first match if any
            if matches.length > 0
                diffutil.getOne matches[0]
        else if matches.length > 0
            # Check if we found a unique match, otherwise keep trying
            if matches.length is 1 and matches[0] not instanceof Category
                matches[0]
            else
                oad.bestMatch obj, matches, level + 1

    # Find the best match for an object in a category and remove that match
    # from the category.
    @takeBestMatch = (obj, cat) ->
        arr = if cat.obj instanceof Array then cat.obj else [cat.obj]
        match = oad.bestMatch obj, arr, cat.level + 1
        cat.remove(match) if match?
        match

    # Search for fuzzy matches between the left and right category trees.
    @fuzzyMatch = (leftCat, rightCat) ->
        # Create a score matrix that will be used to find the best matches
        scores = []
        for leftSubCat in leftCat.obj
            tmpScores = []
            for rightSubCat in rightCat.obj
                tmpScores.push diffutil.getKeyValScore(leftSubCat.key,
                                                       leftSubCat.val,
                                                       rightSubCat.key,
                                                       rightSubCat.val,
                                                       true)
            scores.push tmpScores

        state = new FuzzyState scores

        pairs = []
        while (match = state.next())?
            [l, r] = match
            pairs = pairs.concat(oad.getPairs leftCat.obj[l], rightCat.obj[r])
            if not leftCat.obj[l].obj?
                scores[l] = [0]
            if not rightCat.obj[r].obj?
                for vec in scores
                    vec[r] = 0

        # Do clean up
        oad.fuzzyCleanUp leftCat
        oad.fuzzyCleanUp rightCat

        pairs

    # Cleans up after fuzzy matching
    @fuzzyCleanUp = (cat) ->
        for i in [cat.obj.length - 1 .. 0]
            cat.obj.splice(i, 1) if not cat.obj[i].obj?
        cat.cleanUp 0, 0

    # Convert a regular array into an ObjectArrayDiff
    @fromObject = (arr) ->
        diff = new ObjectArrayDiff
        diff.diff = []
        for val in arr
            if val._h[0]? and val._h[1]?
                diff.diff.push convertToDiffObject(val)
            else
                val._h = convertToDiffObject(val._h)
                diff.diff.push val
        diff

    # Apply a diff. The parameters are similar to Diff.apply, with the
    # exception of type. If type is given, then any objects added to the array
    # will be `new type(object)` instead of `object`.
    apply: (obj, direction, fail, type) ->
        if obj not instanceof Array
            throw new Error 'Array diff being applied to non-array'

        # Create a copy so we don't modify the original
        obj = diffutil.shallowCopy obj

        fail = FailState.toFailState fail
        dir = diffutil.getDirection(direction) is diffutil.Directions.LeftToRight
        # Set up the object hashes to search for the value
        hashes = (diffutil.hash(val) for val in obj)
        for val in @diff
            t = oad.determineType val, dir
            i = hashes.indexOf if dir
                if t is 1 then val._h.right else val._h.left
            else
                if t is 1 then val._h.left else val._h.right
            if i >= 0
                if t is 0
                    # Modify
                    fail.push i
                    obj[i] = val.apply obj[i], direction, fail
                    fail.pop()
                else if t is 2
                    # Delete
                    hashes.splice i, 1
                    obj.splice i, 1
                else
                    # Add
                    fail.push i
                    fail.check null, hashes[i]
                    fail.pop()
                    # Only add if we pass the fail check
                    tmp = diffutil.diffCopy val
                    obj.push if type? then new type(tmp) else tmp

            # Couldn't find hash, either we're adding or the object is missing
            else if t is 1
                # Add
                tmp = diffutil.diffCopy val
                obj.push if type? then new type(tmp) else tmp
            else
                # Missing
                fail.push -1
                fail.check (if dir then val._h.left else val._h.right), null
                fail.pop()

        postApply obj, this, direction

    # Get the type of change, possible values are
    # 0. Modification
    # 1. Addition
    # 2. Subtraction
    @determineType = (obj, dir) ->
        if obj._h.left?
            if obj._h.right?
                0
            else
                if dir then 2 else 1
        else
            if obj._h.right?
                if dir then 1 else 2
            else
                throw new Error 'Array diff missing object hashes'


oad = ObjectArrayDiff

diffutil.ValueDiff = ValueDiff
diffutil.ObjectDiff = ObjectDiff
diffutil.ObjectArrayDiff = ObjectArrayDiff
