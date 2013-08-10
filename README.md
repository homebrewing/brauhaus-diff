Brauhaus.js Diff Plugin
==========================
[![Dependency Status](https://gemnasium.com/homebrewing/brauhaus-diff.png)](https://gemnasium.com/homebrewing/brauhaus-diff) [![Build Status](https://travis-ci.org/homebrewing/brauhaus-diff.png?branch=master)](https://travis-ci.org/homebrewing/brauhaus-diff) [![Coverage Status](https://coveralls.io/repos/homebrewing/brauhaus-diff/badge.png?branch=master)](https://coveralls.io/r/homebrewing/brauhaus-diff?branch=master) [![NPM version](https://badge.fury.io/js/brauhaus-diff.png)](http://badge.fury.io/js/brauhaus-diff)

A plugin for [Brauhaus.js](https://github.com/homebrewing/brauhausjs) that adds diff functionality.

Installation
------------
There are two ways to use Brauhaus-Diff - either in a web browser (client-side) or on e.g. Node.js (server-side).

### Web Browser (client-side use)
To use Brauhaus-Diff in a web browser, simply download the following files and include them as you would any other script:

 * [Download the latest brauhaus.min.js](https://raw.github.com/homebrewing/brauhausjs/master/dist/brauhaus.min.js)
 * [Download the latest brauhaus-diff.min.js](https://raw.github.com/homebrewing/brauhaus-diff/master/dist/brauhaus-diff.min.js)
 * [Download the latest imurmurhash.min.js](https://raw.github.com/jensyt/imurmurhash-js/master/imurmurhash.min.js)

```html
<script type="text/javascript" src="/scripts/imurmurhash.min.js"></script>
<script type="text/javascript" src="/scripts/brauhaus.min.js"></script>
<script type="text/javascript" src="/scripts/brauhaus-diff.min.js"></script>
<script type="text/javascript">
    // Your code goes here!
    // See below for an example...
</script>
```

### Node.js (server-side use)
For Node.js, you can easily install Brauhaus-Diff using `npm`:

```bash
npm install brauhaus-diff
```

Quick Example (Diff)
--------------------

```javascript
// The following lines are NOT required for web browser use
var Brauhaus = require('brauhaus');
require('brauhaus-diff');

// Create two recipes to compare
var left = new Brauhaus.Recipe({
    description: 'A recipe that makes little sense',
    boilSize: 12
});
left.add('fermentable', {
    name: 'Test Fermentable',
    late: true,
    yield: 70
});
left.add('fermentable', {
    name: 'Other Fermentable',
    weight: 2.2
});
left.add('spice', {
    name: 'Test spice',
    weight: 1,
    time: 45,
    use: 'smelt'
})
left.add('yeast', {
    name: 'Yeast',
    form: 'solid'
});

var right = new Brauhaus.Recipe({
    description: 'TODO'
});
right.add('fermentable', {
    name: 'Other Fermentable',
    yield: 20
})
right.add('spice', {
    name: 'Random spice'
})
right.add('yeast', {
    name: 'Yeast'
})

// Calculate the diff
var diff = Brauhaus.Diff.diff(left, right);

// Print the diff in Node.js
console.log(util.inspect(diff, false, null));

// Diff looks like:
// { description: { left: 'A recipe that makes little sense', right: 'TODO' },
//   boilSize: { left: 12, right: 10 },
//   fermentables: 
//    { diff: 
//       [ { weight: { left: 2.2, right: 1 },
//           yield: { left: 75, right: 20 },
//           _h: { left: '1o4wdgh', right: 'sx87wo' } },
//         { name: 'Test Fermentable',
//           weight: 1,
//           yield: 70,
//           color: 2,
//           late: true,
//           _h: { left: '158d476', right: null } } ] },
//   spices: 
//    { diff: 
//       [ { name: 'Test spice',
//           weight: 1,
//           aa: 0,
//           use: 'smelt',
//           time: 45,
//           form: 'pellet',
//           _h: { left: '1uctkbv', right: null } },
//         { name: 'Random spice',
//           weight: 0.025,
//           aa: 0,
//           use: 'boil',
//           time: 60,
//           form: 'pellet',
//           _h: { left: null, right: '1us1ios' } } ] },
//   yeast: 
//    { diff: 
//       [ { form: { left: 'solid', right: 'liquid' },
//           _h: { left: 'mfcqxm', right: '16drowi' } } ] } }

// Or when converted to JSON and formatted (slightly less verbose):
// { description: ["A recipe that makes little sense", "TODO"],
//   boilSize: [12, 10],
//   fermentables: [
//      { weight: [2.2, 1],
//        yield: [75, 20],
//       _h: ["1o4wdgh", "sx87wo"] },
//      { name: "Test Fermentable",
//        weight: 1,
//        yield: 70,
//        color: 2,
//        late: true,
//        _h: ["158d476", null] } ],
//   spices: [
//      { name: "Test spice",
//        weight: 1,
//        aa: 0,
//        use: "smelt",
//        time:45,
//        form: "pellet",
//        _h: ["1uctkbv", null] },
//      { name: "Random spice",
//        weight: 0.025,
//        aa: 0,
//        use: "boil",
//        time: 60,
//        form: "pellet",
//        _h: [null, "1us1ios"] } ],
//   yeast: [
//      { form: ["solid", "liquid"],
//        _h: ["mfcqxm", "16drowi"] } ] }
```

Quick Example (Applying changes)
--------------------------------

```javascript
// The following lines are NOT required for web browser use
var Brauhaus = require('brauhaus');
require('brauhaus-diff');

// Create diff
// ... (see above example)

// Apply changes backward (go from left to right)
var recipe = Brauhaus.Diff.apply(left, diff);

// Print the new recipe in Node.js
console.log(util.inspect(recipe, false, null));

// Apply the changes forward (go from right to left)
recipe = Brauhaus.Diff.apply(right, diff);

// Print the new recipe in Node.js
console.log(util.inspect(recipe, false, null));

```

Quick Example (Converting to/from JSON)
---------------------------------------

```javascript
// The following lines are NOT required for web browser use
var Brauhaus = require('brauhaus');
require('brauhaus-diff');

// Create diff
// ... (see above example)

// Serialize to JSON
var json = JSON.stringify(diff);

// Deserialize from JSON
var diff = Diff.parse(json);
// or
var obj = JSON.parse(json);
diff = Diff.parse(obj);

```

Diff Configuration
------------------

Several global options are available for configuring how Brauhaus-Diff works. These options can be passed into `Brauhaus.Diff.configure()` as an object, e.g.

```javascript
Brauhaus.Diff.configure({
    usingBrauhausStyles: true
});
```

| Option              | Type    | Default | Description |
| ------------------- | ------- | ------- | ----------- |
| exportUtil          | boolean | false   | Export internal utility functions as Brauhaus.Diff.util. This is primarily intended for debugging purposes. |
| usingBrauhausStyles | boolean | depends | When diffing or applying changes to recipes, check if the style is one of the known styles. If so, some info from the diff can be dropped. This option defaults to `true` if the [Brauhaus-Styles](https://github.com/homebrewing/brauhaus-styles) plugin is loaded _before_ Brauhaus-Diff, and false otherwise. |
| removeDefaultValues | boolean | false   | Some Brauhaus objects use defaults supplied by their prototypes. If set to true, the diff will check whether values are different from default when adding or removing one of these objects. This option is disabled by default because it may remove useful information from the diff if you aren't sure what the prototype chain will be when you apply the changes to another object. If you only plan on diffing recipes, this option can be safely enabled to save some space in the diffs. |

An example of the difference from _removeDefaultValues_:

```javascript
// Create a Fermentable
var fermentable = new Brauhaus.Fermentable({
    weight: 2
});

// Run the diff with the option disabled
Brauhaus.Diff.configure({
    removeDefaultValues: false
});
Brauhaus.Diff.diff(fermentable, null)
// { left: 
//    { name: 'New Fermentable',
//      weight: 2,
//      yield: 75,
//      color: 2,
//      late: false },
//   right: null }

// Run the diff with the option enabled
Brauhaus.Diff.configure({
    removeDefaultValues: true
});
Brauhaus.Diff.diff(fermentable, null)
// { left:
//    { name: 'New Fermentable',
//      weight: 2 },
//   right: null }
```

Brauhaus.Diff
-------------

### Diff.diff (left, right, [options])
Compute the difference between _left_ and _right_, which can be primitive types, arrays, or objects. A diff object is returned which can be serialized or used to apply changes to other objects. If no changes are found, an empty object is returned.

_Options_ is an optional object containing configuration options for this diff. Any options not provided will use the global defaults. See the section on __Diff Configuration__ for more details.

Brauhaus-Diff treats arrays differently based on their contents. Arrays containing only objects are treated as unordered collections where matches are searched for between _left_ and _right_, while arrays containing mixed types are treated as simple ordered lists with pairwise diffing. See the sections on __Using Custom Types__ and __Diff Format__ for more details.

For the purposes of `Diff.apply`, _left_ is considered the newer object such that applying a diff forward means turning a right object into a left object, while applying a diff backward does the opposite. See `Diff.apply` for more details.

---

### Diff.apply (applyTo, diff, [options])
### Diff.apply (applyTo, diff, [direction], [fail]) [ __DEPRECATED__ ]

Apply a diff to an object, array, or primitive type _(applyTo)_. _Options_ is an optional object containing configuration options for this apply. Any options not provided will use the global defaults. A copy of _applyTo_ is returned with the modifications from _diff_.

_Diff_ can be a single diff object, a single JSON string, an array of diff objects, or an array of JSON strings. If multiple diffs are used, the diffs are applied to the object in the order of iteration. The _direction_ parameter specifies the direction of the diff, i.e. is _applyTo_ on the left (backward) or right (forward), not the direction of iteration for multiple diffs. So when applying the diff backward (left-to-right), the order of iteration must be left-most first; when applying forward (right-to-left), the order of iteration must be right-most first. An example of valid inputs:

```javascript
// A single diff object
var diff = Brauhaus.Diff.diff(1, 2);
Brauhaus.Diff.apply(1, diff);
// Returns 2

// Multiple diff objects
diff = [Diff.diff(1, 2), Brauhaus.Diff.diff(2, 3)];
Brauhaus.Diff.apply(1, diff);
// Returns 3

// A single JSON string
var diff = '[1, 2]';
Brauhaus.Diff.apply(1, diff);
// Returns 2

// Multiple JSON strings
var diff = ['[1, 2]', '[2, 3]'];
Brauhaus.Diff.apply(1, diff)
// Returns 3
```

The configurable options are provided in the following table in addition to the global options in section __Diff Configuration__.

| Option    | Type                | Default   | Description
-----------------------------------------------------------------------------------------
| direction | string              | 'forward' | The direction in which to apply the diff.
| fail      | boolean or function | true      | The failure mode to use.

The two basic direction options are turning a right object into a left object (forward diff) and turning a left object into a right object (backward diff, default). The valid inputs options for _direction_ are:
* 'backward', 'b', 'leftToRight', 'left-to-right', 'ltor', or 'l' for a backward diff
* 'forward', 'f', 'rightToLeft', 'right-to-left', 'rtol', or 'r' for a forward diff

Whenever `apply` encounters an inconsistency between _applyTo_ and _diff_, it consults the _fail_ option for what to do. Inconsistencies can occur when a value in _applyTo_ doesn't match the expected value from _diff_, when an object is missing or already present, etc. When _fail_ is false, all inconsistencies are ignored. When _fail_ is true (default) and an inconsistency is found, `apply` will throw an exception with the following properties:
* `e instanceof Error === true`
* `e.message` The error message
* `e.keys` An array containing the nested object keys where the inconsistency was found
* `e.expected` The expected value
* `e.actual` The actual value

When _fail_ is a function, whether `apply` throws an exception depends on the return value of the function. If the function returns true an exception is thrown, otherwise it is ignored. The fail function should accept up to three parameters: _keys_, _expected_, and _actual_, with the same definitions as above. An example of using a fail function:

```javascript
// Causes a failure if the inconsistency is in a nested object, but allows
// inconsistencies in a top-level object
function fail(keys, expected, actual) {
    return keys.length > 1
}

// Create some objects to diff
var left = {
    a: 1,
    b: {
        x: 5,
        y: 6 } };
var right = {
    a: 2,
    b: {
        x: 5,
        y: 7 } };
var diff = Brauhaus.Diff.diff(left, right);

// Create the options object using the default failure mode
options = {
    direction: 'backward'
};

// No failure function, exception will be thrown
Brauhaus.Diff.apply({
    a: 2,
    b: {
        x: 5,
        y: 6 } },
diff, options);
// Error: Diff encountered an inconsistency (key: a, expected: 1, actual: 2)

// Set the failure function
options.fail = fail;

// Using the fail function for the same input
Brauhaus.Diff.apply({
    a: 2,
    b: {
        x: 5,
        y: 6 } },
diff, options);
// { a: 2,
//   b: {
//      x: 5,
//      y: 7 } }

// Using the fail function with a nested inconsistency
Brauhaus.Diff.apply({
    a: 2,
    b: {
        x: 5,
        y: 3 } },
diff, options);
// Error: Diff encountered an inconsistency (key: b.y, expected: 6, actual: 3)
```

`apply` may also fail for reasons that are not handled by the failure mode / function; for instance trying to apply an object diff to a non-object, or an object array diff to a non-array. In those cases, an Error object is always thrown.

---

### Diff.parse (object/json)
Convert JSON or a diff-like object into a diff object that can be applied. The diff-like objects supported are the same as Brauhaus-Diff serializes. See the section on __Diff Format__ for more details.

Brauhaus.Recipe Support
-----------------------
Brauhaus-Diff can be used for many generic objects, but it has special support for Recipes (and by extension, Fermentables, Spices, Yeasts, and MashSteps). This support includes:

* [Brauhaus-Styles](https://github.com/homebrewing/brauhaus-styles) plugin support (see __Diff Configuration__ section)
* Use in object arrays
* Constructing the correct type on created sub-objects
* Diff only the properties that will be serialized

The next section covers adding these features to custom types.

Using Custom Types
------------------
For simple objects that will not be used in arrays, nothing extra needs to be done to diff them. Several examples throughout this document show how this can be done, but it's as simple as `Brauhaus.Diff.diff(left, right)`.

### Use in object arrays
To use objects in arrays and have them matched between left and right, a set of keys needs to be set on the object or its prototype. The keys property is called `_diffKeys`, and its value must be an array that contains only arrays and strings. The keys in the array are matched sequentially in the order of iteration, with each subsequent key being considered less important than the previous key. An example to illustrate:

```javascript
Brauhaus.Fermentable.prototype._diffKeys = ['name', 'late', ['weight', 'color', 'yield']];
```

When a Fermentable is included in an array, the diff algorithm will look in both left and right for matching _names_. If a single match is found in both sides, the values are paired and diffed. If no match is found, the value is considered an addition or deletion from the list. If multiple matches are found, the algorithm continues to the next key, _late_, and tries to pick the best match for each value. If multiple values have the same _late_ property, the diff algorithm goes to the _weight_, _color_, and _yield_ key. When a key is complex like this, the diff algorithm bases the match on the number of correct key/value combinations in the complex key. Both the key and value must match for the key/value pair to be considered equal. If two matches are found to be equally good, the diff algorithm simply picks the first choice available.

Note that two objects with different primary keys (the first key) will never be paired. However, objects with the same primary key but different secondary keys may be paired.

By setting diff keys on an object or its prototype, all of this matching will be done automatically by the diff algorithm. However, diff arrays of objects without keys will likely result in poor matches and unexpected output.

---

### Constructing sub-objects
By default, objects constructed by Brauhaus-Diff will have only `Object` in their prototype chain. In order to construct objects of a given type, a special property must be set on the object passed into `apply` or its prototype, called `_paramMap`. This property must be an object whose keys are the keys to which special construction should be applied, and whose values are constructors to use. An example to illustrate from Brauhaus.Recipe:

```javascript
Brauhaus.Recipe.prototype._paramMap = {
    fermentables: Brauhaus.Fermentable,
    spices: Brauhaus.Spice,
    yeast: Brauhaus.Yeast,
    mash: Brauhaus.Mash
};
```

Whenever a Recipe is diffed and a new object is created under the _fermentables_ key, for instance, the created object is passed to the Brauhaus.Fermentable constructor via `new Brauhaus.Fermentable(createdObject)`. The constructor should accept an object that _looks like_ an instance of the requested type, and return a copy of that object with the right type. To see how Brauhaus accomplishes this, take a look at [Brauhaus.OptionConstructor](https://github.com/homebrewing/brauhausjs/blob/master/src/base.coffee). Depending on your type, it could be as simple as:

```javascript
function MyType(obj) {
    for (key in obj) {
        this[key] = obj[key];
    }
}
```

---

### Diff only certain properties
Brauhaus-Diff checks whether an object contains a `toJSON` function before applying the diff. If the function exists, the diff will be performed on the object returned by calling `toJSON()` instead of the object itself. This allows for diffing only the properties that would be serialized to JSON for the object, instead of all properties on the object.

If this behavior is undesirable, the `toJSON` function should be removed or replaced with a non-function, or a copy of the object without the function should be passed to `Diff.diff`. This may change in the future to use another function instead of `toJSON`.

---

### Perform custom post-diff functions
While performing a diff, every changed object is checked for a `postDiff` function on itself, its prototype, and its constructor, in that order. If the function is found, it will be called with the left and right values, along with the diff and diff options. This function can modify the diff object if desired. If both left and right would call the same `postDiff` function, it will only be called once, otherwise the function for both objects will be called. An example from Brauhaus.Recipe (modified for readability):

```javascript
Brauhaus.Recipe.postDiff = function(left, right, diff, options) {
    if (options.usingBrauhausStyles && diff.style) {
        if (diff.style instanceof ValueDiff) {
            if (diff.style.left.name && diff.style.left.category)
                if (getStyle(diff.style.left.category, diff.style.left.name))
                    cleanStyle(diff.style.left);

            if (diff.style.right.name && diff.style.right.category)
                if (getStyle(diff.style.right.category, diff.style.right.name))
                    cleanStyle(diff.style.right);

        } else {
            var leftName = diff.style.name.left || left.style.name;
            var leftCategory = diff.style.category.left || left.style.category;
            var rightName = diff.style.name.right || right.style.name;
            var rightCategory = diff.style.category || right.style.category;
            if (getStyle(leftCategory, leftName) && getStyle(rightCategory, rightName))
                cleanStyle(diff.style);
        }
    }
};
```

Whenever a recipe is diffed, the above code checks to see whether the style was changed and, if so, whether the style information can be reconstructed from the Brauhaus.Styles plugin. If only known styles are being used, the other properties ( _gu_, _fg_, _srm_, etc.) are removed from the diff.

---

### Perform custom post-apply functions
Like `postDiff`, applying changes checks for a `postApply` function that accepts the modified object, the diff, and the options passed to `apply`. Any special changes may be made to the object in this function.

Unexpected Output
-----------------
If the diff output isn't what you expected, there are several possible reasons:

* Check the __Diff Configuration__ to make sure it's what you wanted.
* If you're diffing arrays of objects, make sure they have their _diff keys_ set (see __Using Custom Types__).
* Diffing different types will always result in removing one and adding the other, including diffing an array vs. an object (even with the same keys).
* You found a bug, please submit a [bug report](https://github.com/homebrewing/brauhaus-diff/issues) if you have the chance.

Diff Format (JSON)
------------------
The diff format saved to JSON is fairly simple, consisting of only three types: a value diff, an object diff, and an object array diff.

### Value Diff
Value diffs are simple `[left, right]` pairs of values. They represent a value difference or replacement.

### Object Diff
Object diffs are objects whose keys are the properties that were changed, and whose values are another diff object. They are used when comparing two objects, and are simply a container for the changes. Brauhaus-Diff does not distinguish between keys that are missing, keys that are set to `undefined`, and keys set to `null`; they are all considered equal to `null`. This means that Brauhaus-Diff will never delete keys on an object when applying changes, but it may set them to null. If you need keys deleted, you will need to delete them manually after applying a diff. An example of an object diff:

```javascript
var left = {
    a: 1,
    b: {
        x: 5,
        y: 6 } };
var right = {
    a: 2,
    b: {
        x: 5,
        y: 7 } };
Brauhaus.Diff.diff(left, right);
// { a: [1, 2],
//   b: {
//      y: [6, 7] } }
// The arrays [1, 2] and [6, 7] are Value Diffs representing the changes
```

Arrays of mixed types are considered objects for the purposes of diffing, and result in an object diff with numerical keys.

### Object Array Diff
Arrays of objects are represented exactly as such with the addition of an `_h` key on each of the contained objects or object diffs. The `_h` key contains a value diff with hashes for the left and right objects, which are needed to find the correct object to which to apply changes. Array values are either an object diff (if left and right both contain the object), or simply a copy of the object (if the object only exists in left or right). An example of an object array diff:

```javascript
var left = [];
left.push(new Brauhaus.Fermentable({
    name: 'fermentable',
    weight: 2
}));

var right = [];
right.push(new Brauhaus.Fermentable({
    name: 'fermentable'
}));
right.push(new Brauhaus.Fermentable({
    name: 'other',
    yield: 70
}));

Brauhaus.Diff.diff(left, right);
// [ { weight: [2, 1],
//     _h: ["u47usq", "1s5bg5s"] },
//   { name: "other",
//     yield: 70,
//     _h: [null, "cxt9ff"] } ]
//
// The first element is an Object Diff
// The second element is just a copy of right[1] with the extra _h key
```

Contributing
------------
Contributions are welcome - just fork the project and submit a pull request when you are ready!

### Getting Started
First, create a fork on GitHub. Then:

```bash
git clone ...
cd brauhaus-diff
npm install
```

### Style Guide
Brauhaus uses the [CoffeeScript Style Guide](https://github.com/polarmobile/coffeescript-style-guide) with the following exceptions:

 1. Indent 4 spaces
 1. Maximum line length is 120 characters

When building `brauhaus-diff.js` with `cake build` or `npm test` you will see the output of [CoffeeLint](http://www.coffeelint.org/), a static analysis code quality tool for CoffeeScript. Please adhere to the warnings and errors to ensure your changes will build.

### Unit Tests
Before submitting a pull request, please add any relevant tests and run them via:

```bash
npm test
```

If you have PhantomJS installed and on your path then you can use:

```bash
CI=true npm test
```

Pull requests will automatically be tested by Travis CI both in Node.js 0.8/0.10 and in a headless webkit environment (PhantomJS). Changes that cause tests to fail will not be accepted. New features should be tested to be accepted.

New tests can be added in the `test` directory. If you add a new file there, please don't forget to update the `test.html` to include it!

### Code Coverage
You can generate a unit test code coverage report for unit tests using the following:

```bash
cake coverage
```

You can find an HTML report in the `coverage` directory that is created. This report will show line-by-line code coverage information.

---

Please note that all contributions will be licensed under the MIT license in the following section.

License
-------
Copyright (c) 2013 Jens Taylor

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
