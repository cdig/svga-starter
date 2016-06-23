beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
del = require "del"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
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
gulp_uglify = require "gulp-uglify"
# gulp_using = require "gulp-using" # Uncomment and npm install for debug
main_bower_files = require "main-bower-files"
run_sequence = require "run-sequence"
spawn = require("child_process").spawn


# CONFIG ##########################################################################################


assetTypes = "cdig,gif,ico,jpeg,jpg,json,m4v,mp3,mp4,pdf,png,swf,txt,woff,woff2"


paths =
  activity: watch: [
    "source/**/*"
    "bower_components/**/pack/**/*"
    "bower_components/**/*.{css,js}"
  ]
  coffee: source: [
    "bower_components/**/pack/**/*.coffee"
    "source/**/*.coffee"
  ]
  dev:
    gulp: "dev/*/gulpfile.coffee"
    watch: "dev/**/{dist,pack}/**/*"
  js: source: "bower_components/take-and-make/dist/take-and-make.js"
  scss: source: [
    "bower_components/**/pack/**/*.scss"
    "system/activity/activity.scss"
    "source/activity/**/vars.scss"
    "source/activity/**/*.scss"
  ]
  svg:
    source: "bower_components/**/pack/**/*.svg"
    activity: "source/**/*.svg"


config =
  svgmin:
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
      {moveElemsAttrsToGroup: true}
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


wrapJS = (src)->
  src
    .on "error", logAndKillError
    # .pipe gulp_uglify()
    .pipe gulp_replace /^/, "<script type='text/ecmascript'><![CDATA["
    .pipe gulp_replace /$/, "]]></script>"


wrapCSS = (src)->
  src
    .on "error", logAndKillError
    .pipe gulp_autoprefixer
      browsers: "last 5 Chrome versions, last 2 ff versions, IE >= 10, Safari >= 8, iOS >= 8"
      cascade: false
      remove: false
    .pipe gulp_replace /^/, "<style>"
    .pipe gulp_replace /$/, "</style>"


indexPath = null


# TASKS: ACTIVITY COMPILATION #######################################################################


gulp.task "activity", ()->
  cssLibs = gulp.src main_bower_files("**/*.css"), base: "bower_components/"
  jsLibs = gulp.src main_bower_files("**/*.js"), base: "bower_components/"
  css = gulp.src paths.scss.source
    .pipe gulp_concat "activity.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 2
  js = gulp.src paths.coffee.source
    .pipe gulp_concat "activity.coffee"
    .pipe gulp_coffee()
  
  gulp.src paths.svg.activity
    .on "error", logAndKillError
    .pipe gulp_replace /preserveAspectRatio="(.*?)"/, ""
    .pipe gulp_replace /viewBox="(.*?)"/, ""
    .pipe gulp_replace /\swidth="(.*?)"/, " "
    .pipe gulp_replace /\sheight="(.*?)"/, " "
    .pipe gulp_replace /\sx="(.*?)"/, " "
    .pipe gulp_replace /\sy="(.*?)"/, " "
    .pipe gulp_replace "Lato_Regular_Regular", "Lato"
    .pipe gulp_replace "Lato_Bold_Bold", "Lato"
    .pipe gulp_svgmin
      full: true # Only runs plugins we specify
      js2svg:
        pretty: true
        indent: "  "
      plugins: config.svgmin.sourcePlugins
    .pipe gulp.dest "source" # overwrite the original file with optimized, pretty-printed version
    .pipe gulp_svgmin
      full: true # Only runs plugins we specify
      js2svg:
        pretty: true
      plugins: config.svgmin.publicPlugins
    .pipe gulp_replace "<defs>", "<!-- libs:css --><!-- endinject --><!-- activity:css --><!-- endinject --><defs>"
    .pipe gulp_replace "</svg>", "<!-- libs:js --><!-- endinject --><!-- activity:js --><!-- endinject --></svg>"
    .pipe gulp_inject wrapCSS(cssLibs), name: "libs", transform: fileContents
    .pipe gulp_inject wrapCSS(css), name: "activity", transform: fileContents
    .pipe gulp_inject wrapJS(jsLibs), name: "libs", transform: fileContents
    .pipe gulp_inject wrapJS(js), name: "activity", transform: fileContents
    .pipe gulp_rename (path)->
      indexPath ?= path.basename + path.extname
      path
    .pipe gulp.dest "public"
    # .pipe browser_sync.stream # Doesn't seem to work
    #   match: "**/*.svg"
    .pipe gulp_notify
      title: "👍"
      message: "SVG Activity"


gulp.task "del:public", ()->
  del "public"


gulp.task "dev:sync", gulp_shell.task [
  "if [ -d 'dev' ]; then rsync --exclude '*/.git/' --delete -ar dev/* bower_components; fi"
]


gulp.task "dev:watch", (cb)->
  gulp.src paths.dev.gulp
    .on "data", (chunk)->
      folder = chunk.path.replace "/gulpfile.coffee", ""
      process.chdir folder
      child = spawn "gulp", ["default"]
      child.stdout.on "data", (data)->
        console.log chalk.green(folder.replace chunk.base, "") + " " + chalk.white data.toString() if data
      process.chdir "../.."
  cb()


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    server:
      baseDir: "public"
      index: indexPath # it is okay if this is null
    ui: false


gulp.task "watch", ()->
  gulp.watch paths.activity.watch, ["activity"]
  gulp.watch paths.dev.watch, ["dev:sync"]
  gulp.watch("public/*.svg").on "change", browser_sync.reload


# This task is also used from the command line, for bulk updates
gulp.task "recompile", (cb)->
  run_sequence "del:public", "activity", cb


gulp.task "default", ()->
  run_sequence "recompile", "dev:watch", "watch", "serve"
