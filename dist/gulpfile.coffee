beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
del = require "del"
gulp = require "gulp"
gulp_changed = require "gulp-changed"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_htmlmin = require "gulp-htmlmin"
gulp_inject = require "gulp-inject"
gulp_natural_sort = require "gulp-natural-sort"
gulp_notify = require "gulp-notify"
gulp_rename = require "gulp-rename"
gulp_replace = require "gulp-replace"
gulp_rev_all = require "gulp-rev-all"
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_uglify = require "gulp-uglify"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
path = require "path"
spawn = require("child_process").spawn


# STATE ##########################################################################################


prod = false
watching = false


# CONFIG ##########################################################################################


assetPacks = "{pressure,svga}"


paths =
  coffee: "source/**/*.coffee"
  dev:
    gulp: "dev/*/gulpfile.coffee"
    watch: "dev/**/dist/**/*"
  libs: [
    "node_modules/take-and-make/dist/take-and-make.js"
    "node_modules/pressure/dist/pressure.js"
    "node_modules/svga/dist/svga.css"
    "node_modules/svga/dist/svga.js"
  ]
  svg: "source/**/*.svg"
  wrapper: "node_modules/svga/dist/index.html"
  

config =
  svgmin_plugins: [
    {cleanupAttrs: true}
    {removeDoctype: true}
    {removeComments: true}
    {removeMetadata: true}
    {removeTitle: true}
    {removeUselessDefs: true}
    {removeEditorsNSData: true}
    {removeEmptyAttrs: true}
    {removeHiddenElems: true}
    {removeEmptyText: true}
    {removeEmptyContainers: true}
    # {minifyStyles: true}
    # {convertStyleToAttrs: true}
    {convertColors:
      names2hex: true
      rgb2hex: true
    }
    {convertPathData:
      applyTransforms: true
      applyTransformsStroked: true
      makeArcs: {
        threshold: 20 # coefficient of rounding error
        tolerance: 10  # percentage of radius
      }
      straightCurves: true
      lineShorthands: true
      curveSmoothShorthands: true
      floatPrecision: 2
      transformPrecision: 2
      removeUseless: true
      collapseRepeated: true
      utilizeAbsolute: true
      leadingZero: false
      negativeExtraSpace: true
    }
    {convertTransform:
      convertToShorts: true
      degPrecision: 2 # transformPrecision (or matrix precision) - 2 by default
      floatPrecision: 2
      transformPrecision: 2
      matrixToTransform: false # Setting to true causes an error because of the inverse() call in SVG Mask
      shortTranslate: true
      shortScale: true
      shortRotate: true
      removeUseless: true
      collapseIntoOne: true
      leadingZero: false
      negativeExtraSpace: false
    }
    {cleanupNumericValues: floatPrecision: 2}
    # {moveElemsAttrsToGroup: true}
    {removeEmptyContainers: true}
    {sortAttrs: true}
  ]


gulp_notify.logLevel(0)
gulp_notify.on "click", ()->
  do gulp_shell.task "open -a Terminal"


# HELPER FUNCTIONS ################################################################################


fileContents = (filePath, file)->
  file.contents.toString "utf8"

logAndKillError = (err)->
  beepbeep()
  console.log chalk.bgRed("\n## Error ##")
  console.log chalk.red err.toString() + "\n"
  gulp_notify.onError(
    emitError: true
    icon: false
    message: err.message
    title: "👻"
    wait: true
    )(err)
  @emit "end"

cond = (predicate, action)->
  if predicate
    action()
  else
    # This is what we use as a noop *shrug*
    gulp_rename (p)-> p

changed = (path = "public")->
  cond watching, ()->
    gulp_changed path, hasChanged: gulp_changed.compareSha1Digest

stream = (glob)->
  cond watching, ()->
    browser_sync.stream match: glob

initMaps = ()->
  cond !prod, ()->
    gulp_sourcemaps.init()

emitMaps = ()->
  cond !prod, ()->
    gulp_sourcemaps.write "."

notify = (msg)->
  cond watching, ()->
    gulp_notify
      title: "👍"
      message: msg

fixFlashWeirdness = (src)->
  src
    .on "error", logAndKillError
    .pipe gulp_replace "Lato_Regular_Regular", "Lato, sans-serif"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato, sans-serif"
    .pipe gulp_replace "MEMBER_", "M_"
    .pipe gulp_replace "Layer", "L"
    .pipe gulp_replace "STROKES", "S"
    .pipe gulp_replace "FILL", "F"
    .pipe gulp_replace "writing-mode=\"lr\"", ""
    .pipe gulp_replace "baseline-shift=\"0%\"", ""
    .pipe gulp_replace "kerning=\"0\"", ""
    .pipe gulp_replace "xml:space=\"preserve\"", ""
    .pipe gulp_replace "fill-opacity=\".99\"", "" # This is close enough to 1 that it's not worth the cost


# TASKS: COMPILATION ##############################################################################


# This task MUST be idempotent, since it overwrites the original file
gulp.task "beautify-svg", ()->
  fixFlashWeirdness gulp.src paths.svg
    .pipe changed "source"
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" $1>'
    .on "error", logAndKillError
    .pipe gulp_svgmin
      full: true
      js2svg:
        pretty: true
        indent: "  "
      plugins: config.svgmin_plugins
    .pipe gulp.dest "source"


gulp.task "coffee:source", ()->
  gulp.src paths.coffee
    .pipe gulp_natural_sort()
    .pipe initMaps()
    .pipe gulp_concat "source.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError
    .pipe cond prod, gulp_uglify
    .pipe emitMaps()
    .pipe gulp.dest "public"
    .pipe stream "**/*.js"
    .pipe notify "Coffee"


gulp.task "wrap-svg", ()->
  libs = gulp.src paths.libs
    .pipe gulp.dest "public/_libs"
  svgSource = gulp.src paths.svg
    .pipe gulp_replace "</defs>", "</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
  gulp.src paths.wrapper
    .pipe gulp_inject svgSource, name: "source", transform: fileContents
    .pipe gulp_inject libs, name: "libs", ignorePath: "/public/", addRootSlash: false
    .pipe gulp_replace "<script src=\"_libs", "<script defer src=\"_libs"
    .pipe cond prod, ()-> gulp_htmlmin
      collapseWhitespace: true
      collapseBooleanAttributes: true
      collapseInlineTagWhitespace: true
      includeAutoGeneratedTags: false
      removeComments: true
    .on "error", logAndKillError
    .pipe gulp.dest "public"
    .pipe notify "SVG"


gulp.task "dev", gulp_shell.task [
  "if [ -d 'dev' ]; then rsync --exclude '*/.git/' --delete -ar dev/* node_modules; fi"
]


# TASKS: SYSTEM ###################################################################################


gulp.task "del:public", ()->
  del "public"


gulp.task "del:deploy", ()->
  del "deploy"


gulp.task "dev:watch", (cb)->
  gulp.src paths.dev.gulp
    .on "data", (chunk)->
      folder = chunk.path.replace "/gulpfile.coffee", ""
      process.chdir folder
      child = spawn "gulp", ["watch"]
      child.stdout.on "data", (data)->
        console.log chalk.green(folder.replace chunk.base, "") + " " + chalk.white data.toString() if data
      process.chdir "../.."
  cb()


gulp.task "prod:setup", (cb)->
  prod = true
  cb()


gulp.task "reload", (cb)->
  browser_sync.reload()
  cb()


gulp.task "rev", ()->
  gulp.src "public/**"
    .pipe gulp_rev_all.revision
      transformPath: (rev, source, path)-> # Applies to file references inside HTML/CSS/JS
        rev.replace /.*\//, ""
      transformFilename: (file, hash)->
        name = file.revHash + file.extname
        gulp_shell.task("mkdir -p deploy/index && touch deploy/index/#{name}")() if file.revPathOriginal.indexOf("/public/index.html") > 0
        name
    .pipe gulp_rename (path)->
      path.dirname = ""
      path
    .pipe gulp.dest "deploy/all"


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    notify: false
    server: baseDir: "public"
    ui: false
    watchOptions: ignoreInitial: true


gulp.task "watch", (cb)->
  watching = true
  gulp.watch paths.dev.watch, gulp.series "dev"
  gulp.watch paths.coffee, gulp.series "coffee:source"
  gulp.watch paths.libs, gulp.series "wrap-svg", "reload"
  gulp.watch paths.wrapper, gulp.series "wrap-svg", "reload"
  gulp.watch paths.svg, gulp.series "beautify-svg", "wrap-svg", "reload"
  cb()


gulp.task "recompile",
  gulp.series "del:public", "dev", "beautify-svg", "coffee:source", "wrap-svg"


gulp.task "prod",
  gulp.series "prod:setup", "recompile", "del:deploy", "rev"


gulp.task "default",
  gulp.series "dev:watch", "recompile", "watch", "serve"
