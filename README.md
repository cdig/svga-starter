# App Template

### What is an app?
A "library" is small and focussed on the developer, while an "app" is large and focussed on the user. Examples of apps: Piece It Together, Q'n'Eh, Match or Miss, Quizzer, etc.

### Why does this repo exist?
So that we have a standard place to put our app boilerplate — gitignore, bower.json, gulpfile, LICENSE, package.json, README, and so forth.

### How do I use it?

#### Development
Fork this repo when starting a new app. Put your source code in a "source" folder. Run `gulp` to compile.

#### Deployment
Install the app through bower and cd-module will automatically pick it up (due to the "main" in bower.json). Or for standalone use, just write a simple index.html that loads the script and stylesheet.

### What if I need...
If you need templates, ES6, CLJS, or other fancy bullshit, go ahead and add that to your fork. If you think it should live here too, make a compelling argument.

## License
Copyright (c) 2015 CD Industrial Group Inc.
