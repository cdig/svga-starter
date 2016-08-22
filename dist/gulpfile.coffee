beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
del = require "del"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_changed = require "gulp-changed"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_inject = require "gulp-inject"
gulp_notify = require "gulp-notify"
gulp_rename = require "gulp-rename"
gulp_replace = require "gulp-replace"
gulp_sass = require "gulp-sass"
gulp_shell = require "gulp-shell"
# gulp_sourcemaps = require "gulp-sourcemaps" # Uncomment and npm install for debug
gulp_svgmin = require "gulp-svgmin"
gulp_svgstore = require "gulp-svgstore"
gulp_uglify = require "gulp-uglify"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
main_bower_files = require "main-bower-files"
path = require "path"
# spawn = require("child_process").spawn # Uncomment for dev:watch

# STATE ##########################################################################################

deploy = false

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
      {cleanupNumericValues:
        floatPrecision: 2
      }
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



wrapJS = (src)->
  x = src.on "error", logAndKillError
  x = x.pipe gulp_uglify() if deploy
  x
    .pipe gulp_replace /^/, "<script type='text/javascript'><![CDATA["
    .pipe gulp_replace /$/, "]]></script>"


wrapCSS = (src)->
  src
    .on "error", logAndKillError
    .pipe gulp_autoprefixer
      browsers: "last 5 Chrome versions, last 2 ff versions, IE >= 10, Safari >= 8, iOS >= 8"
      cascade: false
      remove: false
    .pipe gulp_replace /^/, "<style><![CDATA["
    .pipe gulp_replace /$/, "]]></style>"


fixFlashWeirdness = (src)->
  src
    .on "error", logAndKillError
    .pipe gulp_replace "Lato_Regular_Regular", "Lato"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato"
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
    .pipe gulp_changed "source", hasChanged: gulp_changed.compareSha1Digest # Prevents an infinite loop
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
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 2
  
  js = gulp.src paths.svga.coffee
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
    .pipe gulp_replace "</defs>", "<!-- svga:css --><!-- endinject -->\n<!-- libs:js --><!-- endinject -->\n<!-- svga:js --><!-- endinject -->\n<!-- pack:svg --><!-- endinject -->\n</defs>"
    .pipe gulp_inject wrapCSS(css), name: "svga", transform: fileContents
    .pipe gulp_inject wrapJS(jsLibs), name: "libs", transform: fileContents
    .pipe gulp_inject wrapJS(js), name: "svga", transform: fileContents
    .pipe gulp_inject svgPack, name: "pack", transform: fileContents
    .pipe gulp_replace /<!--.*?-->/g, ""
    # Wrap the SVG content in a root element
    .pipe gulp_replace "</defs>", "</defs>\n<g id=\"root\">"
    .pipe gulp_replace "</svg>", "</g>\n</svg>"
    # Optimize
    .pipe gulp_svgmin
      full: true
      js2svg: pretty: deploy
      plugins: config.svgmin.publicPlugins
  
  name = null
  gulp.src paths.wrapper
    .pipe gulp_inject compiledSvg,
      name: "wrapper"
      removeTags: true
      transform: fileContents = (filePath, file)->
        name = filePath.replace "/source/", ""
        return file.contents.toString "utf8"
    # .pipe gulp_rename name
    .pipe gulp.dest "public"
    .pipe gulp_notify
      title: "👍"
      message: "SVGA"


gulp.task "del:public", ()->
  del "public"


gulp.task "dev:sync", gulp_shell.task [
  "if [ -d 'dev' ]; then rsync --exclude '*/.git/' --delete -ar dev/* bower_components; fi"
]


# Even though we aren't using this at the moment, let's keep it here for future reference.
# Note: it's no longer executed by the main tasks down below.
# Here's where you'd add it back: gulp.parallel "compile-svga", "dev:watch", "watch", "serve"
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


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    notify: false
    server:
      baseDir: "public"
      index: "wrapper.html"
    ui: false
    watchOptions:
      ignoreInitial: true


gulp.task "deploy:setup", (cb)->
  deploy = true
  cb()


gulp.task "reload", (cb)->
  browser_sync.reload()
  cb()


gulp.task "watch", (cb)->
  gulp.watch paths.dev.watch, gulp.series "dev:sync"
  gulp.watch paths.svga.svg.source, gulp.series "beautify-svg", "compile-svga", "reload"
  gulp.watch paths.svga.watch, gulp.series "compile-svga", "reload"
  cb()


# This task is used from the command line, for bulk updates
gulp.task "recompile", gulp.series "del:public", "beautify-svg", "compile-svga"


gulp.task "deploy",
  gulp.series "deploy:setup", "del:public", "beautify-svg", "compile-svga"


gulp.task "default",
  gulp.series "del:public", "dev:sync", "beautify-svg",
    gulp.parallel "compile-svga", "watch", "serve"
