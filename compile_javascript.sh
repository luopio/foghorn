#!/bin/bash

# run `npm install` if you haven't already, then compile the ES6 code into ES5

./node_modules/.bin/babel --presets es2015 --minified priv/assets/Foghorn.es6 --out-file priv/assets/foghorn.min.js
