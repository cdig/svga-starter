beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
crypto = require "crypto"
del = require "del"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_changed = require "gulp-changed"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_inject = require "gulp-inject"
gulp_natural_sort = require "gulp-natural-sort"
gulp_notify = require "gulp-notify"
gulp_rename = require "gulp-rename"
gulp_replace = require "gulp-replace"
gulp_sass = require "gulp-sass"
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_svgmin = require "gulp-svgmin"
gulp_svgstore = require "gulp-svgstore"
gulp_uglify = require "gulp-uglify"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
main_bower_files = require "main-bower-files"
path = require "path"
spawn = require("child_process").spawn


# STATE ##########################################################################################


hashName = null
prod = false
svgName = null
watching = false


# CONFIG ##########################################################################################


paths =
  dev:
    watch: "dev/**/{dist,pack}/**/*"
    # gulp: "dev/*/gulpfile.coffee" # Saved for future reference
  svga:
    coffee: [
      "bower_components/**/pack/**/*.coffee"
      "source/**/*.coffee"
    ]
    svg:
      pack: "bower_components/**/pack/**/*.svg"
      source: "source/**/*.svg"
    scss: [
      "bower_components/**/pack/**/vars.scss"
      "source/**/vars.scss"
      "bower_components/**/pack/**/*.scss"
      "source/**/*.scss"
    ]
    watch: [
      "bower_components/**/{dist,pack}/**/*"
      "source/**/*.coffee"
    ]
  wrapper: "bower_components/svga/dist/wrapper.html"
  

config =
  svgmin:
    packPlugins: (file)-> [
      prefixIDsWithFileName:
        type: "full"
        fn: (data)->
          prefix = path.basename file.relative, path.extname file.relative
          prefixIDs data, prefix + "_"
    ]
    publicPlugins: [
      {minifyStyles: true}
    ]
    sourcePlugins: [
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
    referencesProps: [
      "clip-path"
      "color-profile"
      "fill"
      "filter"
      "marker-start"
      "marker-mid"
      "marker-end"
      "mask"
      "stroke"
      "style"
    ]


gulp_notify.logLevel(0)
gulp_notify.on "click", ()->
  do gulp_shell.task "open -a Terminal"


# HELPER FUNCTIONS ################################################################################


# This attaches the filename to the beginning of IDs, so that identical IDs across files don't collide
prefixIDs = (items, prefix)->
  for item, i in items.content
    if item.isElem()
      item.eachAttr (attr)->
        # id="EXAMPLE"
        if attr.name is "id"
          attr.value = prefix + attr.value
        # url(#EXAMPLE)
        else if config.svgmin.referencesProps.indexOf(attr.name) > -1
          if attr.value.match /\burl\(("|')?#(.+?)\1\)/
            attr.value = attr.value.replace "#", "#" + prefix
        # href="#EXAMPLE"
        else if attr.local is "href"
          if attr.value.match /^#(.+?)$/
            attr.value = attr.value.replace "#", "#" + prefix
    prefixIDs item, prefix if item.content
  return items

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

changed = ()->
  cond watching, ()->
    gulp_changed "public", hasChanged: gulp_changed.compareSha1Digest

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

wrapJS = (src)->
  x = src.on "error", logAndKillError
  x = x.pipe gulp_uglify() if prod
  x

wrapCSS = (src)->
  src
    .on "error", logAndKillError
    .pipe gulp_autoprefixer
      browsers: "last 5 Chrome versions, last 2 ff versions, IE >= 10, Safari >= 8, iOS >= 8"
      cascade: false
      remove: false
    .pipe gulp_replace /^/, "<style>"
    .pipe gulp_replace /$/, "</style>"

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


# TASKS: ACTIVITY COMPILATION #######################################################################


gulp.task "beautify-svg", ()->
  fixFlashWeirdness gulp.src paths.svga.svg.source
    .pipe changed()
    .pipe gulp_replace /<svg .*?(width=.+? height=.+?").*?>/, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" font-family="Lato, sans-serif" $1>'
    .pipe gulp_svgmin
      full: true
      js2svg:
        pretty: true
        indent: "  "
      plugins: config.svgmin.sourcePlugins
    .pipe gulp.dest "source" # overwrite the original file with optimized, pretty-printed version


gulp.task "compile-svga", ()->
  jsLibs = gulp.src main_bower_files("**/*.js"), base: "bower_components/"
  
  css = gulp.src paths.svga.scss
    .pipe gulp_natural_sort()
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 2
  
  js = gulp.src paths.svga.coffee
    .pipe gulp_natural_sort()
    .pipe gulp_concat "scripts.coffee"
    .pipe gulp_coffee()
  
  svgPack = fixFlashWeirdness gulp.src paths.svga.svg.pack
    .pipe gulp_svgmin (file)->
      full: true
      plugins: config.svgmin.sourcePlugins.concat config.svgmin.packPlugins file
    .pipe gulp_svgstore inlineSvg: true
    .pipe gulp_replace '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">', ""
    .pipe gulp_replace "<defs>", ""
    .pipe gulp_replace "</defs>", ""
    .pipe gulp_replace "</svg>", ""
  
  compiledSvg = gulp.src paths.svga.svg.source
    # Inject dependencies
    # Wrap the SVG content in a root element
    .pipe gulp_replace "</defs>", "<!-- svga:css --><!-- endinject --><!-- pack:svg --><!-- endinject -->\n</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
    # Optimize
    .pipe gulp_svgmin
      full: true
      js2svg: pretty: !prod
      plugins: config.svgmin.publicPlugins
    .pipe gulp_replace "</svg>", "</svg>\n<script>\n<!-- libs:js --><!-- endinject -->\n<!-- svga:js --><!-- endinject -->\n</script>"
    .pipe gulp_inject wrapCSS(css), name: "svga", transform: fileContents
    .pipe gulp_inject wrapJS(jsLibs), name: "libs", transform: fileContents
    .pipe gulp_inject wrapJS(js), name: "svga", transform: fileContents
    .pipe gulp_inject svgPack, name: "pack", transform: fileContents
    .pipe gulp_replace /<!--.*?-->/g, ""
  
  gulp.src paths.wrapper
    .pipe gulp_inject compiledSvg,
      name: "wrapper"
      transform: (filePath, file)->
        if prod
          md5 = crypto.createHash "md5"
          md5.update file.contents, "utf8"
          hashName = md5.digest "hex"
        svgName = path.basename filePath
        return file.contents.toString "utf8"
    .pipe gulp_rename (path)->
      if not svgName? then throw new Error "\n\nYou must have an SVG file in your source folder.\n"
      path.basename = svgName.replace ".svg", ""
      path.basename += ".min" if prod
    .pipe gulp.dest "public"
    .pipe notify "SVGA"


gulp.task "dev", gulp_shell.task [
  "if [ -d 'dev' ]; then rsync --exclude '*/.git/' --delete -ar dev/* bower_components; fi"
]


# TASKS: SYSTEM ###################################################################################


# Even though we aren't using this at the moment, let's keep it here for future reference.
# Note: it's no longer executed by the main tasks down below.
# Here's where you'd add it back: gulp.series "compile-svga", "dev:watch", "watch", "serve"
#
# gulp.task "dev:watch", (cb)->
#   gulp.src paths.dev.gulp
#     .on "data", (chunk)->
#       folder = chunk.path.replace "/gulpfile.coffee", ""
#       process.chdir folder
#       child = spawn "gulp", ["default"]
#       child.stdout.on "data", (data)->
#         console.log chalk.green(folder.replace chunk.base, "") + " " + chalk.white data.toString() if data
#       process.chdir "../.."
#   cb()


gulp.task "del:public", ()->
  del "public"


gulp.task "del:deploy", ()->
  del "deploy"


gulp.task "prod:setup", (cb)->
  prod = true
  cb()


gulp.task "reload", (cb)->
  browser_sync.reload()
  cb()


gulp.task "rev", ()->
  gulp.src "public/**/*"
    .pipe gulp_rename (path)->
      path.basename = hashName
      gulp_shell.task("rm -rf .deploy && mkdir .deploy && touch .deploy/#{hashName}.html")()
    .pipe gulp.dest "deploy"


gulp.task "serve", ()->
  if not svgName? then throw new Error "\n\nYou must have an SVG file in your source folder.\n"
  browser_sync.init
    ghostMode: false
    notify: false
    server:
      baseDir: "public"
      index: svgName.replace ".svg", ".html" # Set by compile-svg
    ui: false
    watchOptions:
      ignoreInitial: true


gulp.task "watch", (cb)->
  watching = true
  gulp.watch paths.dev.watch, gulp.series "dev"
  gulp.watch paths.svga.svg.source, gulp.series "beautify-svg", "compile-svga", "reload"
  gulp.watch paths.svga.watch, gulp.series "compile-svga", "reload"
  cb()


gulp.task "recompile",
  gulp.series "del:public", "dev", "beautify-svg", "compile-svga"


gulp.task "prod",
  gulp.series "prod:setup", "recompile", "del:deploy", "rev"


gulp.task "default",
  gulp.series "recompile", "watch", "serve"
