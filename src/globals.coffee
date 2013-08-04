###
@preserve
Brauhaus.js Diff Plugin
Copyright 2013 Jens Taylor <jensyt@gmail.com>
https://github.com/homebrewing/brauhaus-diff
###

# Import Brauhaus if it hasn't already been defined
Brauhaus = @Brauhaus ? require 'brauhaus'

# Import Murmur Hash
murmur = @MurmurHash3 ? require 'imurmurhash'

# Import fast Levenshtein
levenshtein = @Levenshtein ? require 'fast-levenshtein'

# Create the top-level diff module
Diff = if exports? then exports else {}
Brauhaus.Diff = Diff

# Default matching function for fuzzy strings
defaultFuzzyStrings = (left, right) ->
    len = Math.max left.length, right.length
    if len > 3
        0.25
    else
        1 / len

# Global options. See Diff.configure for descriptions of all the options.
Options =
    exportUtil: false
    usingBrauhausStyles: Brauhaus.STYLES? and typeof Brauhaus.getStyles is 'function'
    removeDefaultValues: false
    fuzzyStrings: defaultFuzzyStrings


###
Set package-wide options for diff. Currently supported options are:
    exportUtil: bool
        Exposes utility functions in Diff.util, including all types used
        internally. Defaults to false.

    usingBrauhausStyles: bool
        Whether Recipe styles should be checked against the styles defined by
        the Brauhaus.Styles plugin. When enabled, all recipe diffs and applies
        will check whether the style is one of the known styles, and minimize
        the amount of information stored to recreate the style. Defaults to
        true if Brauhaus.STYLES and Brauhaus.getStyles are defined,
        false otherwise.
    
    removeDefaultValues: bool
        Checks whether properties are own properties or prototype properties
        before saving them. This only affects objects that are added or
        removed, not modifications. If true, only own properties and properties
        that have changed will be saved. If false, all properties will be saved
        for additions and deletions. Defaults to false. If you only plan on
        diffing recipes or you can keep track of the types used in the diff,
        this can be safely set to true.

    fuzzyStrings: mixed
        Used to configure fuzzy string matching. If set to false, then fuzzy
        string matching is disabled. If set to true, fuzzy string matching is
        enabled with the default match criteria. If set to a number, the number
        represents the maximum percentage difference allowed to be considered a
        viable match. If set to a function, the function will be called with
        the two strings being matched and must return a number indicating the
        maximum percentage difference allowed to consider this specific pair of
        strings a viable match. If set to anything else, fuzzy string matching
        will be disabled.
###
Diff.configure = (options) ->
    if typeof options isnt 'object'
        return Diff

    Options.exportUtil = !!options.exportUtil
    Options.usingBrauhausStyles = !!options.usingBrauhausStyles
    Options.removeDefaultValues = !!options.removeDefaultValues

    if options.fuzzyStrings?
        if options.fuzzyStrings is true
            Options.fuzzyStrings = defaultFuzzyStrings
        else if typeof options.fuzzyStrings is 'number'
            Options.fuzzyStrings = -> options.fuzzyStrings
        else if typeof options.fuzzyStrings is 'function'
            Options.fuzzyStrings = options.fuzzyStrings
        else
            Options.fuzzyStrings = false

    if Options.exportUtil and not Diff.util?
        Diff.util = diffutil

    Diff

# Set up keys for Brauhaus types
# The keys are in order of precedence, with multiple keys at a given level
# given equal weight. E.g. for Fermentables: weight, color, and yield are all
# considered to have equal weight, so matching any 2 out of 3 is considered to
# have equal validity. It will only get to that point, though, if two
# Fermentables have identical names and late properties.
Brauhaus.Fermentable::_diffKeys = ['name', 'late', ['weight', 'color', 'yield']]
Brauhaus.Spice::_diffKeys = ['name', ['use', 'form'], ['time', 'weight', 'aa']]
Brauhaus.Yeast::_diffKeys = ['name', ['type', 'form'], 'attenuation']
Brauhaus.MashStep::_diffKeys = [['name', 'type'], ['waterRatio', 'temp', 'endTemp', 'time', 'rampTime']]
