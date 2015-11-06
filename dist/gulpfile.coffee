beepbeep = require "beepbeep"
browser_sync = require("browser-sync").create()
del = require "del"
gulp = require "gulp"
gulp_autoprefixer = require "gulp-autoprefixer"
gulp_coffee = require "gulp-coffee"
gulp_concat = require "gulp-concat"
gulp_inject = require "gulp-inject"
gulp_json_editor = require "gulp-json-editor"
gulp_kit = require "gulp-kit"
gulp_notify = require "gulp-notify"
gulp_replace = require "gulp-replace"
gulp_sass = require "gulp-sass"
gulp_shell = require "gulp-shell"
gulp_sourcemaps = require "gulp-sourcemaps"
gulp_using = require "gulp-using"
gulp_util = require "gulp-util"
gulp_insert = require "gulp-insert"
main_bower_files = require "main-bower-files"
run_sequence = require "run-sequence"
path_exists = require("path-exists").sync
fs = require('fs')


gulp_notify.logLevel(0)
gulp_notify.on "click", ()->
  do gulp_shell.task "open -a Terminal"

fileContents = (filePath, file)->
  file.contents.toString "utf8"

logAndKillError = (err)->
  beepbeep()
  console.log gulp_util.colors.bgRed("\n## Error ##")
  console.log gulp_util.colors.red err.message + "\n"
  gulp_notify.onError(
    emitError: true
    icon: false
    message: err.message
    title: "👻"
    wait: true
    )(err)
  @emit "end"


paths =
  coffee:
    source: [
      "system/activity-start.coffee"
      ]
    watch: "{bower_components,system}/**/*.coffee"
  dev: [
    "dev/*/dist/**/*.*"
    "dev/*/bower.json"
  ]
  html:
    pack: "bower_components/**/pack/**/*.html"
  svg:
    source: [
      "source/assets/**/*.svg"
      ]
    watch: "source/assets/**/*.svg"
  svg_sass:
    source: [
      "source/activity/**/*.scss"]
    watch: "source/activity/**/*.scss"
  svg_activity_coffee: 
    source: [
      "system/activity-begin.coffee"
      "source/activity/**/*.coffee"
      ]
    watch: "source/activity/**/*.coffee"
  libs:
    source: [
      "public/libs/angular/angular*.js"
      "public/libs/take-and-make/dist/take-and-make.js"
      "public/libs/**/*.*"
    ]      
  kit:
    source: [
      "source/index.kit"
      # TODO: figure out how to add Kit/HTML components from Asset Packs
    ]
    watch: "{source}/**/*.{kit,html}"
  sass:
    source: [
      "bower_components/**/pack/**/vars.scss"
      "bower_components/**/pack/**/*.scss"
    ]
    watch: "{bower_components}/**/*.scss" 
    watch: "{source}/**/*.scss"

gulp.task "dev:copy", ()->
  gulp.src paths.dev
    .on "error", logAndKillError
    .pipe gulp.dest "bower_components"


gulp.task "dev", ()->
  run_sequence "dev:copy", "kit"
  

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

gulp.task "libs", ()->
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
  
  gulp.src bowerWithMin.concat(sourceMaps), base: 'bower_components/'
    # .pipe gulp_using() # Uncomment for debug
    .on "error", logAndKillError
    .pipe gulp.dest "public/libs"



gulp.task "sass", ()->
  gulp.src paths.sass.source.concat main_bower_files "**/*.scss"
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

# Thank me later ;)
gulp.task "scss", ["sass"]


gulp.task "serve", ()->
  browser_sync.init
    ghostMode: false
    server:
      baseDir: "public"
    ui: false


gulp.task "default", ["coffee","svg-activity-coffee","svg-compile", "dev", "kit", "sass", "serve"], ()->
  gulp.watch paths.coffee.watch, ["coffee"]
  gulp.watch paths.svg_activity_coffee.watch, ["svg-activity-coffee"]
  gulp.watch paths.svg.watch, ["svg-compile"]
  gulp.watch paths.svg_sass.watch, ["svg-compile"]
  gulp.watch paths.dev, ["dev"]
  gulp.watch paths.kit.watch, ["kit"]
  gulp.watch paths.sass.watch, ["sass"]
  gulp.watch("public/**/*.svg").on 'change', browser_sync.reload



gulp.task "kit", ["libs"], ()->
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
    .pipe gulp_replace "<script src=\"libs", "<script defer src=\"libs"
    .pipe gulp.dest "public"
    .pipe browser_sync.stream
      match: "**/*.html"
    .pipe gulp_notify
      title: "👍"
      message: "HTML"

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
    .pipe gulp.dest "public/libs/activity/"
    .pipe browser_sync.stream
      match: "**/*.js"
    .pipe gulp_notify
      title: "👍"
      message: "Activity compiled"

gulp.task "svg-compile", ()->
  css = gulp.src paths.svg_sass.source 
    .pipe gulp_concat "styles.scss"
    .pipe gulp_sass
      errLogToConsole: true
      outputStyle: "compressed"
      precision: 1
    .on "error", logAndKillError
    .pipe gulp_insert.prepend("<style>")
    .pipe gulp_insert.append("</style>")
  gulp.src paths.svg.source
    .pipe gulp_replace "<defs>", "<defs><!-- bower:css --><!-- endinject -->"
    .pipe gulp_inject css, name: "bower", transform: fileContents
    .pipe gulp.dest "public"
    .pipe browser_sync.stream 
      match: "public/**/*.svg"
    .pipe gulp_notify
      title: "👍"
      message: "SVG Compiled"
    
###################################################################################################

expandCurlPath = (p)->
  "curl -fsS https://raw.githubusercontent.com/cdig/svg-activity-starter/dist/#{p} > #{p}"

updateCmds = [
  expandCurlPath "package.json"
  expandCurlPath "gulpfile.coffee"
  expandCurlPath ".gitignore"
]



gulp.task 'update', gulp_shell.task updateCmds





###################################################################################################


