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

# Create the top-level diff module
Diff = exports ? {}
Brauhaus.Diff = Diff

# Default options
Options =
    exportUtil: false
    usingBrauhausStyles: Brauhaus.STYLES? and typeof Brauhaus.getStyles is 'function'
    removeDefaultValues: false

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
###
Diff.configure = (options) ->
    if typeof options isnt 'object'
        return Diff

    Options.exportUtil = !!options.exportUtil if options.exportUtil?
    Options.usingBrauhausStyles = !!options.usingBrauhausStyles if options.usingBrauhausStyles?
    Options.removeDefaultValues = !!options.removeDefaultValues if options.removeDefaultValues?

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
