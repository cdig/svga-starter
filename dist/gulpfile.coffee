beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
chalk = require "chalk"
del = require "del"
fs = require "fs"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_inject = require "gulp-inject"
gulp_kit = require "gulp-kit"
gulp_rename = require "gulp-rename"
gulp_notify = require "gulp-notify"
gulp_replace = require "gulp-replace"
gulp_sass = require "gulp-sass"
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_using = require "gulp-using"
gulp_insert = require "gulp-insert"
main_bower_files = require "main-bower-files"
path_exists = require("path-exists").sync
run_sequence = require "run-sequence"
spawn = require("child_process").spawn

assetTypes = "cdig,gif,ico,jpeg,jpg,json,m4v,mp3,mp4,pdf,png,swf,txt,woff,woff2"

gulp_notify.logLevel(0)
gulp_notify.on "click", ()->
  do gulp_shell.task "open -a Terminal"

fileContents = (filePath, file)->
  file.contents.toString "utf8"

logAndKillError = (err)->
  beepbeep()
  console.log chalk.bgRed("\n## Error ##")
  console.log chalk.red err.message + "\n"
  gulp_notify.onError(
    emitError: true
    icon: false
    message: err.message
    title: "👻"
    wait: true
    )(err)
  @emit "end"


paths =
  assets:
    public: "public/**/*.{#{assetTypes}}"
    source: [
      "source/**/*.{#{assetTypes}}"
      "bower_components/*/pack/**/*.{#{assetTypes}}"
    ]
  coffee:
    source: [
      "bower_components/**/pack/**/*.coffee"
      "system/activity-start.coffee"
      "source/standalone/**/*.coffee"
    ]
    watch: "{bower_components,system,source/standalone/}/**/*.coffee"
  dev:
    gulp: "dev/*"
    watch: "dev/**/dist/**/*"
  html:
    pack: "bower_components/**/pack/**/*.html"
  svg:
    sass: [
      "system/_activity.scss"
      "source/activity/**/*.scss"
    ]
    svg: [
      "source/**/*.svg"
    ]
    watch: [
      "source/**/*.svg"
      "{source/activity,system}/**/*.scss"
    ]
  svg_activity_coffee:
    source: [
      "system/activity-begin.coffee"
      "source/activity/**/*.coffee"
      ]
    watch: "source/activity/**/*.coffee"
  libs:
    source: [
      "public/_libs/bower/take-and-make/dist/take-and-make.js"
      "public/_libs/**/*"
      "public/activity/**/*.js"
    ]
  kit:
    source: [
      "source/index.kit"
      # TODO: figure out how to add Kit/HTML components from Asset Packs
    ]
    watch: [
      "source/**/*.{kit,html}"
      "bower_components/**/*" # Watch all file types, because kit runs libs which pulls from bower which pulls from dev (phew)
    ]
  scss:
    source: [
      "bower_components/cd-reset/dist/reset.scss"
      "bower_components/**/pack/**/vars.scss"
      "bower_components/**/pack/**/*.scss"
      "system/_styles.scss"
      "source/standalone/**/*.scss"
    ]
    watch: "{bower_components,source/standalone,system}/**/*.scss"


gulp.task "assets", ()->
  gulp.src paths.assets.source
    # .pipe gulp_using() # Uncomment for debug
    .pipe gulp_rename (path)->
      path.dirname = path.dirname.replace /.*\/pack\//, ''
      path
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "**/*.{#{assetTypes}}"
    .pipe gulp_notify
      title: "👍"
      message: "Assets"


gulp.task "coffee", ()->
  gulp.src paths.coffee.source
    # .pipe gulp_using() # Uncomment for debug
    .pipe gulp_sourcemaps.init()
    .pipe gulp_concat "scripts.coffee"
    .pipe gulp_coffee()
    .on "error", logAndKillError
    .pipe gulp_sourcemaps.write() # TODO: Don't write sourcemaps in production
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "**/*.js"
    .pipe gulp_notify
      title: "👍"
      message: "Coffee"


gulp.task "dev:watch", (cb)->
  gulp.src paths.dev.gulp
    .on "data", (chunk)->
      process.chdir chunk.path
      child = spawn "gulp", ["default"]
      child.stdout.on "data", (data)->
        console.log chalk.green(chunk.path.replace chunk.base, "") + " " + chalk.white data.toString() if data
      process.chdir "../.."
  cb()


gulp.task "dev:sync", gulp_shell.task [
  'if [ -d "dev" ]; then rsync --exclude "*/.git/" --delete -ar dev/* bower_components; fi'
]


gulp.task "kit", ["libs:bower", "libs:source"], ()->
  # This grabs .js.map too, but don't worry, they aren't injected
  libs = gulp.src paths.libs.source, read: false
  html = gulp.src main_bower_files "**/*.{html}"
  pack = gulp.src paths.html.pack

  # libs.pipe(gulp_using()) # Uncomment for debug
  # html.pipe(gulp_using()) # Uncomment for debug
  # pack.pipe(gulp_using()) # Uncomment for debug

  gulp.src paths.kit.source
    # .pipe gulp_using() # Uncomment for debug
    .pipe gulp_kit()
    .on "error", logAndKillError
    .pipe gulp_inject libs, name: "bower", ignorePath: "/public/", addRootSlash: false
    .pipe gulp_inject html, name: "bower", transform: fileContents
    .pipe gulp_inject pack, name: "pack", transform: fileContents
    .pipe gulp_replace "<script src=\"", "<script defer src=\""
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "**/*.{css,html,js}"
    .pipe gulp_notify
      title: "👍"
      message: "HTML"


# gulp.task "libs", ()->
#   sourceMaps = []
#   bowerWithMin = main_bower_files "**/*.{css,js}"
#     .map (path)->
#       minPath = path.replace /.([^.]+)$/g, ".min.$1" # Check for minified version
#       if path_exists minPath
#         mapPath = minPath + ".map"
#         sourceMaps.push mapPath if path_exists mapPath
#         return minPath
#       else
#         return path
#   gulp.src bowerWithMin.concat(sourceMaps), base: 'bower_components/'
#     # .pipe gulp_using() # Uncomment for debug
#     .on "error", logAndKillError
#     .pipe gulp.dest "public/libs"


gulp.task "libs:bower", ()->
  sourceMaps = []
  bowerWithMin = main_bower_files "**/*.{css,js}"
    .map (path)->
      minPath = path.replace /.([^.]+)$/g, ".min.$1" # Check for minified version
      if path_exists minPath
        mapPath = minPath + ".map"
        sourceMaps.push mapPath if path_exists mapPath
        return minPath
      else
        return path
  gulp.src bowerWithMin.concat(sourceMaps), base: "bower_components/"
    # .pipe gulp_using() # Uncomment for debug
    .on "error", logAndKillError
    .pipe gulp.dest "public/_libs/bower"


gulp.task "libs:source", ()->
  gulp.src "source/**/*.js"
    # .pipe gulp_using() # Uncomment for debug
    .on "error", logAndKillError
    .pipe gulp.dest "public/_libs/source"


gulp.task "scss", ()->
  gulp.src paths.scss.source.concat main_bower_files "**/*.scss"
    # .pipe gulp_using() # Uncomment for debug
    .pipe gulp_sourcemaps.init()
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 1
    .on "error", logAndKillError
    .pipe gulp_autoprefixer
      browsers: "last 5 Chrome versions, last 2 ff versions, IE >= 10, Safari >= 8, iOS >= 8"
      cascade: false
      remove: false
    .pipe gulp_sourcemaps.write "." # TODO: Don't write sourcemaps in production
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "**/*.css"
    .pipe gulp_notify
      title: "👍"
      message: "SCSS"


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    server:
      baseDir: "public"
    ui: false


gulp.task "svg-activity-coffee", ()->
  json = JSON.parse(fs.readFileSync('./source/svg-activity.json'))
  gulp.src paths.svg_activity_coffee.source
    # .pipe gulp_using() # Uncomment for debug
    .pipe gulp_sourcemaps.init()
    .pipe gulp_concat "#{json.name}.coffee"
    .pipe gulp_replace "%activity_name", json.name
    .pipe gulp_coffee()
    .on "error", logAndKillError
    .pipe gulp_sourcemaps.write() # TODO: Don't write sourcemaps in production
    .pipe gulp.dest "public/activity/"
    .pipe browser_sync.stream
      match: "**/*.js"
    .pipe gulp_notify
      title: "👍"
      message: "Activity compiled"


gulp.task "svg-compile", ()->
  css = gulp.src paths.svg.sass
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 1
    .on "error", logAndKillError
    .pipe gulp_insert.prepend("<style>")
    .pipe gulp_insert.append("</style>")
  gulp.src paths.svg.svg
    .pipe gulp_replace "<defs>", "<defs><!-- bower:css --><!-- endinject -->"
    .pipe gulp_replace /preserveAspectRatio="(.*?)"/, ''
    .pipe gulp_inject css, name: "bower", transform: fileContents
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "public/**/*.svg"
    .pipe gulp_notify
      title: "👍"
      message: "SVG Compiled"


gulp.task "init:compile", [], ()->
  

gulp.task "default", ["assets", "coffee", "kit", "scss", "svg-activity-coffee", "svg-compile"], ()->
  gulp.watch paths.coffee.watch, ["coffee"]
  gulp.watch paths.dev.watch, ["dev:sync"]
  gulp.watch paths.kit.watch, ["kit"]
  gulp.watch paths.scss.watch, ["scss"]
  gulp.watch paths.svg_activity_coffee.watch, ["svg-activity-coffee"]
  gulp.watch paths.svg.watch, ["svg-compile"]
  gulp.watch("public/**/*.svg").on 'change', browser_sync.reload
  run_sequence "dev:watch"
  run_sequence "serve" # Must come last
