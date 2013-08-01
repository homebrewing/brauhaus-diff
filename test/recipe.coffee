Brauhaus = @Brauhaus ? require 'brauhaus'
Diff = Brauhaus.Diff ? require('../lib/brauhaus-diff')
Diff.configure({exportUtil: true})
assert = assert ? require 'assert'

Brauhaus.STYLES =
    'Light Lager':
        'Lite American Lager':
            name: 'Lite American Lager'
            category: 'Light Lager'
            gu: [1.028, 1.040]
            fg: [0.998, 1.008]
            srm: [2, 3]
            ibu: [8, 12]
            abv: [2.8, 4.2]
            carb: [2.5, 2.8]
    'Pilsner':
        'German Pilsner (Pils)':
            name: 'German Pilsner (Pils)'
            category: 'Pilsner'
            gu: [1.044, 1.050]
            fg: [1.008, 1.013]
            srm: [2, 5]
            ibu: [25, 45]
            abv: [4.4, 5.2]
            carb: [2.4, 2.7]

Brauhaus.getStyle = (cat, name) ->
    Brauhaus.STYLES[cat][name]

# This is needed since some objects rely on properties set in their prototype.
# When an object is created from the diff, it doesn't check the prototype to
# see if the value would be changed or not, resulting in redefining some
# properties locally on the object. When deepEqual is called, it checks to make
# sure the objects have the same own properties, which will fail for our
# constructed objects.
# The only real way around this is to use `removeDefaultValues` to true when
# creating the diff.
customDeepEqual = (l, r) ->
    if r instanceof Object
        for key of r
            customDeepEqual l[key], r[key]
    else
        assert.deepEqual l, r

describe 'Recipe', ->
    it 'Should support fermentables, spices, and yeast', ->
        left = new Brauhaus.Recipe
        left.add 'fermentable', {name: 'Test Fermentable', late: true, yield: 70}
        left.add 'fermentable', {name: 'Other Fermentable', weight: 2.2}
        left.add 'spice', {name: 'Test spice', weight: 1, time: 45, use: 'smelt'}
        left.add 'yeast', {name: 'Yeast', form: 'solid'}
        left.boilSize = 12

        right = new Brauhaus.Recipe
        right.add 'fermentable', {name: 'Other Fermentable', yield: 20}
        right.add 'spice', {name: 'Random spice'}
        right.add 'yeast', {name: 'Yeast'}

        expected = Diff.parse '{"boilSize":[12,10],"fermentables":[{"weight":[2.2,1],"yield":[75,20],"_h":["3cbo011","1k3r2o8"]},{"name":"Test Fermentable","weight":1,"yield":70,"color":2,"late":true,"_h":["2a9l8k2",null]}],"spices":[{"name":"Test spice","weight":1,"aa":0,"use":"smelt","time":45,"form":"pellet","_h":["3nido1b",null]},{"name":"Random spice","weight":0.025,"aa":0,"use":"boil","time":60,"form":"pellet","_h":[null,"3oapu6s"]}],"yeast":[{"form":["solid","liquid"],"_h":["18d76iq","2cbviui"]}]}'

        diff = Diff.diff left, right
        assert.ok diff instanceof Diff.util.ObjectDiff
        assert.deepEqual diff, expected

        applied = Diff.apply left, diff
        #customDeepEqual applied, right
        assert.equal JSON.stringify(applied), JSON.stringify(right)

    it 'Should use _paramMap to construct objects', ->
        left = new Brauhaus.Recipe
        right = new Brauhaus.Recipe
        right.mash = new Brauhaus.Mash
        right.mash.addStep {}

        diff = Diff.diff left, right
        other = Diff.apply left, diff

        #customDeepEqual other, right
        assert.equal JSON.stringify(other), JSON.stringify(right)
        assert.ok other.mash instanceof Brauhaus.Mash
        assert.ok other.mash.steps[0] instanceof Brauhaus.MashStep

    it 'Should reduce style info when usingBrauhausStyles is true', ->
        Diff.configure({usingBrauhausStyles: false})

        left = new Brauhaus.Recipe
        left.style = Diff.util.shallowCopy Brauhaus.getStyle 'Light Lager', 'Lite American Lager'
        right = new Brauhaus.Recipe
        right.style = Diff.util.shallowCopy Brauhaus.getStyle 'Pilsner', 'German Pilsner (Pils)'

        diff = Diff.diff left, right
        assert.ok diff.style.gu?

        Diff.configure({usingBrauhausStyles: true})

        diff = Diff.diff left, right
        assert.ok not diff.style.gu?
        assert.equal diff.style.category.left, 'Light Lager'
        assert.equal diff.style.name.left, 'Lite American Lager'

        left.style.category = 'invalid'
        diff = Diff.diff left, right
        assert.ok diff.style.gu?
        diff = Diff.diff right, left
        assert.ok diff.style.gu?

        left.style.category = 'Pilsner'
        diff = Diff.diff left, right
        assert.ok diff.style.gu?
        diff = Diff.diff right, left
        assert.ok diff.style.gu?

        left.style.category = 'Light Lager'
        left.style.name = 'German Pilsner (Pils)'
        diff = Diff.diff left, right
        assert.ok diff.style.gu?
        diff = Diff.diff right, left
        assert.ok diff.style.gu?

        # Check the ValueDiff versions
        left.style = null
        diff = Diff.diff left, right
        assert.ok not diff.style.right.gu?
        diff = Diff.diff right, left
        assert.ok not diff.style.left.gu?

        right.style.name = 'invalid'
        diff = Diff.diff left, right
        assert.ok diff.style.right.gu?
        diff = Diff.diff right, left
        assert.ok diff.style.left.gu?

        Diff.configure({usingBrauhausStyles: false})

    it 'Should use the Brauhaus.STYLES object when applying with usingBrauhausStyles', ->
        Diff.configure({usingBrauhausStyles: false})

        left = new Brauhaus.Recipe
        left.style = Brauhaus.getStyle 'Light Lager', 'Lite American Lager'
        right = new Brauhaus.Recipe
        right.style = Brauhaus.getStyle 'Pilsner', 'German Pilsner (Pils)'

        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.notEqual other.style, right.style

        Diff.configure({usingBrauhausStyles: true})

        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.equal other.style, right.style

        left.style.name = 'invalid'
        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.equal other.style, right.style

        left.style.name = 'German Pilsner (Pils)'
        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.equal other.style, right.style

        left.style.name = 'Lite American Lager'
        left.style.category = 'Pilsner'
        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.equal other.style, right.style

        right.style.name = 'unknown'
        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.notEqual other.style, right.style

        left.style = null
        right.style.name = 'German Pilsner (Pils)'
        diff = Diff.diff left, right
        other = Diff.apply left, diff
        assert.deepEqual other.style, right.style
        assert.equal other.style, right.style

        left.style = null
        diff = Diff.diff right, left
        other = Diff.apply right, diff
        assert.equal other.style, null

        Diff.configure({usingBrauhausStyles: false})
