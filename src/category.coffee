###
Tree nodes in the categorization part of the array diff algorithm. Each object
is assigned to a sequence of Categories based on its keys (_diffKeys). The
result of categorization is a tree where, at each level, the potentially
non-unique objects are sorted into unique categories. A category has a
reference to the key and value assigned to it, as well as the objects with that
key and value. The obj property can be one of:
  1. An object
  2. A list of objects
  3. A list of subcategories for subsequent keys
###
class Category
    @Type =
        Unique: 1
        List: 2
        Category: 3

    constructor: (@key, @val, @obj, @level) ->

    # Add an object to this category
    add: (obj) ->
        @obj = [@obj] if @obj not instanceof Array
        @obj.push obj
        return this

    # Remove an object from this category.
    remove: (obj) ->
        found = false
        type = @getType()
        if type is Category.Type.Category
            [objKey, objVal] = diffutil.getKeyVal obj, @level + 1
            for cat, i in @obj when diffutil.checkKeyVal objKey, objVal, cat.key, cat.val
                found = cat.remove obj, @level + 1
                if cat.obj is null
                    @cleanUp i, 1
                break if found
        else if type is Category.Type.List
            i = @obj.indexOf obj
            if i >= 0
                @cleanUp i, 1
                found = true
        else if @obj is obj
            @obj = null
            found = true
        found

    # Clean up the obj property, removing objects and converting from an array
    # if necessary.
    cleanUp: (index, count) ->
        if @obj instanceof Array
            if @obj.length is count
                @obj = null
            else
                @obj.splice(index, count) if count > 0
                @obj = @obj[0] if @obj.length is 1 and @obj[0] not instanceof Category
        else
            @obj = null if count > 0

    # Get the type of this category. Returns one of the type constants in
    # Category.Type
    getType: ->
        if @obj instanceof Array
            if @obj.length > 0 and @obj[0] instanceof Category
                Category.Type.Category
            else
                Category.Type.List
        else
            Category.Type.Unique

    # Convert the array into a category tree based on the supplied objects'
    # keys. The returned tree will always be a root node with at least one
    # subcategory if arr.length > 0.
    @categorize = (arr) ->
        Category.processLevel new Category '_root', null, arr, -1

    # Process a level in the tree, creating subtrees where necessary
    @processLevel = (cat) ->
        # Shortcut to avoid processing
        if cat.obj not instanceof Array #or cat.obj.length is 1
            return cat

        findMatch = (key, val) ->
            for obj in catArr
                return obj if diffutil.checkKeyVal obj.key, obj.val, key, val

        level = cat.level + 1
        catArr = []
        for obj in cat.obj
            [key, val] = diffutil.getKeyVal obj, level
            match = findMatch key, val
            if match?
                match.add obj
            else
                catArr.push new Category(key, val, obj, level)

        # If the only subcategory is no key, no changes to be made
        if not (catArr.length is 1 and catArr[0].key is '_nokey')
            for subcat in catArr
                Category.processLevel subcat, level
            
            # Do some simplication to remove unecessary levels
            #if catArr.length is 1 and not diffutil.areAny Category, catArr[0].obj
            #    cat.key ?= catArr[0].key
            #    cat.val ?= catArr[0].val
            #    catArr = catArr[0].obj

            cat.obj = catArr
        cat


###
An iterator to process Category trees sequentially.
###
class CategoryIterator
    constructor: (cat) ->
        @cat = cat
        @i = 0
        if cat.getType() is Category.Type.Category
            @subit = new CategoryIterator cat.obj[0]

    # Get the next object in the tree, or null if no more. Calling next again
    # after it returns null results in undefined behavior.
    next: ->
        next = null
        if @cat.obj instanceof Array
            if @subit?
                next = @subit.next()
                while not next?
                    if ++@i >= @cat.obj.length
                        break
                    @subit = new CategoryIterator @cat.obj[@i]
                    next = @subit.next()
            else
                next = @cat.obj[@i] if @i < @cat.obj.length
                ++@i
        else
            next = @cat.obj if @i++ is 0
        next

    # Remove the last object returned by next from the tree. Calling remove
    # more than once without calling next results in undefined behavior.
    remove: ->
        removed = false
        if @cat.obj instanceof Array
            if @subit?
                removed = @subit.remove()
                if not @subit.cat.obj?
                    @cat.cleanUp @cat.obj.indexOf(@subit.cat), 1
                    if @cat.obj? and @i < @cat.obj.length
                        @subit = new CategoryIterator @cat.obj[@i]
                    else
                        @subit = null
            else if 0 < @i <= @cat.obj.length
                @cat.cleanUp --@i, 1
                removed = true
        else if @cat.obj?
            @cat.cleanUp 0, 1
            removed = true
        removed

diffutil.Category = Category
diffutil.CategoryIterator = CategoryIterator
