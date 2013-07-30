###
A function that runs after diffs on Recipes to do some extra processing. This
is how usingBrauhausStyles is implemented.
###
Brauhaus.Recipe.postDiff = (left, right, diff) ->
    if Options.usingBrauhausStyles and diff.style?
        # Changes were made to the style, so check if it's one of the known
        # styles and remove unnecessary properties
        if diff.style instanceof ValueDiff
            if diff.style.left?.name? and diff.style.left.category?
                cleanStyle(diff.style.left) if (getStyle diff.style.left.category, diff.style.left.name)?

            if diff.style.right?.name? and diff.style.right.category?
                cleanStyle(diff.style.right) if (getStyle diff.style.right.category, diff.style.right.name)?

        else # Assuming ObjectDiff, since it can't be an ObjectArrayDiff
            leftName = diff.style.name?.left ? left.style.name
            leftCategory = diff.style.category?.left ? left.style.category
            rightName = diff.style.name?.right ? right.style.name
            rightCategory = diff.style.category?.right ? right.style.category

            if getStyle(leftCategory, leftName)? and getStyle(rightCategory, rightName)?
                cleanStyle diff.style

###
A function that runs after Diff.apply on Recipes to do some extra processing.
This is how usingBrauhausStyles is implemented.
###
Brauhaus.Recipe.postApply = (recipe, diff) ->
    if Options.usingBrauhausStyles
        # Changes were made to the style, so check if it's a known style that
        # we can pull from the style list
        style = getStyle recipe.style?.category, recipe.style?.name
        recipe.style = style if style?

# Try to get the style, if it exists
getStyle = (category, name) ->
    try
        Brauhaus.getStyle category, name
    catch e
        # Not a known style, nothing to do
        return

# Remove non-essential keys from the style
cleanStyle = (style) ->
    delete style[key] for own key of style when key not in ['name', 'category']
    return # Needed to avoid returning the results of the above loop