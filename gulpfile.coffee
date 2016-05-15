##-- imports ------------------------------------------------------------------

fs = require("fs")
gulp = require("gulp")
path = require("path")
plug = require("gulp-load-plugins")(pattern: ["*"])
plug.browserSyncWeb = require("browser-sync").create("web")
plug.browserSyncWww = require("browser-sync").create("www")
spawn = require("child_process").spawn

##-- variables ----------------------------------------------------------------

opts = new (->
  @ext = ".xhtml"
  @src = path.join process.cwd(), "src"

  autoprefixer:
    browsers: plug.browserslist([">1% in my stats"], stats: ".caniuse.json")
    cascade: false
    remove: true
  browserSync: (dir, port) ->
    notify: false
    port: port
    reloadDelay: 500
    server:
      baseDir: dir
      index: "index" + @ext
      middleware: [ plug.connectModrewrite([ "!\\.\\w+$ /index" + @ext + " [L]" ]) ]
    snippetOptions: rule: match: /qqq/
    # startPath: "/index.xhtml"
    ui:
      port: port + 1
      weinre:
        port: port + 2
  coffee:
    bare: true
  cssbeautify:
    autosemicolon: true
    indent: "  "
  csslint:
    "box-model": true
    "display-property-grouping": true
    "duplicate-properties": true
    "empty-rules": true
    "known-properties": true
    "adjoining-classes": false
    "box-sizing": false
    "compatible-vendor-prefixes": false
    "gradients": true
    "text-indent": true
    "vendor-prefix": true
    "fallback-colors": true
    "star-property-hack": true
    "underscore-property-hack": true
    "bulletproof-font-face": true
    "font-faces": true
    "import": true
    "regex-selectors": true
    "universal-selector": true
    "unqualified-attributes": true
    "zero-units": true
    "overqualified-elements": true
    "shorthand": true
    "duplicate-background-images": true
    "floats": true
    "font-sizes": true
    "ids": true
    "important": true
    "outline-none": true
    "qualified-headings": true
    "unique-headings": true
  ext: @ext
  htmlmin: (ws) ->
    removeComments: true
    collapseWhitespace: ws
    useShortDoctype: true
    removeScriptTypeAttributes: true
    removeStyleLinkTypeAttributes: true
    keepClosingSlash: true
    minifyURLs: true
  htmltidy:
    "doctype": "html5"
    "indent": true
    "indent-spaces": 2
    "input-xml": true
    "logical-emphasis": true
    "new-blocklevel-tags": ""
    "output-xhtml": true
    "quiet": true
    "sort-attributes": "alpha"
    "tidy-mark": false
    "wrap": 80
  path:
    coffee: path.join(@src, "**", "*.coffee")
    js: path.join(@src, "**", "*.js")
    notags: "!" + path.join(@src, "tags", "**")
    sass: path.join(@src, "**", "*.s@(a|c)ss")
    slim: path.join(@src, "**", "*.sl?(i)m")
    tags: path.join(@src, "tags")
  restart:
    files: ["Gemfile.lock", "gulpfile.coffee", "package.json"]
  sass:
    riot:
      outputStyle: "compressed"
    nest:
      outputStyle: "nested"
  slim:
    chdir: true
    options: [
      "attr_quote='\"'"
      "format=:xhtml"
      "shortcut={
        '@' => { attr: 'role' },
        '#' => { attr: 'id' },
        '.' => { attr: 'class' },
        '%' => { attr: 'itemprop' },
        '&' => { attr: 'type', tag: 'input' } }"
      "sort_attrs=true" ]
    pretty: true
    require: "slim/include"
  src: @src
  web: path.join process.cwd(), "web"
  www: path.join process.cwd(), "www"
)

##-- tasks --------------------------------------------------------------------

getFolders = (dir) ->
  return fs.readdirSync(dir).filter (file) ->
    return fs.statSync(path.join(dir, file)).isDirectory()

gulp.task "build", (done) ->
  notminjs = plug.filter ["**/*", "!**/*.min.js"], restore: true

  cs = gulp
    .src([opts.path.coffee, opts.path.notags])
    .pipe(plug.coffee opts.coffee)
    .pipe(gulp.dest opts.web)
    .pipe(plug.uglify())
    .pipe(gulp.dest opts.www)

  css = gulp
    .src([opts.path.sass, opts.path.notags])
    .pipe(plug.cached "sass", optimizeMemory: true)
    .pipe(plug.csscomb())
    .pipe(gulp.dest opts.src)
    .pipe(plug.sassLint())
    .pipe(plug.sassLint.format())
    .pipe(plug.sass opts.sass.nest)
    .pipe(plug.autoprefixer opts.autoprefixer)
    .pipe(plug.cssbeautify opts.cssbeautify)
    .pipe(plug.csslint opts.csslint)
    .pipe(plug.csslint.reporter())
    .pipe(gulp.dest opts.web)
    .pipe(plug.cssnano())
    .pipe(gulp.dest opts.www)

  html = gulp
    .src([opts.path.slim, opts.path.notags])
    .pipe(plug.slim opts.slim)
    .pipe(plug.rename extname: opts.ext)
    .pipe(plug.htmltidy opts.htmltidy)
    .pipe(plug.w3cjs())
    .pipe(gulp.dest opts.web)
    .pipe(plug.htmlmin opts.htmlmin(true))
    .pipe(gulp.dest opts.www)

  js = gulp
    .src([opts.path.js, opts.path.notags])
    .pipe(gulp.dest opts.web)
    .pipe(notminjs)
    .pipe(plug.uglify())
    .pipe(notminjs.restore)
    .pipe(gulp.dest opts.www)

  tags = getFolders(opts.path.tags).map((folder) ->
    coffee = plug.filter "**/*.coffee", restore: true
    notags = plug.filter ["**/*", "!**/*.tag"], restore: true
    sass = plug.filter "**/*.s@(a|c)ss", restore: true
    slim = plug.filter "**/*.slim", restore: true
    svg = plug.filter "**/*.svg", restore: true

    gulp
      .src(path.join(opts.path.tags, folder, "*"))

      .pipe(svg)
      .pipe(plug.svgmin())
      .pipe(svg.restore)

      .pipe(slim)
      .pipe(plug.slim opts.slim)
      .pipe(plug.htmlmin opts.htmlmin(true))
      .pipe(plug.injectString.append("\n"))
      .pipe(slim.restore)

      .pipe(sass)
      .pipe(plug.csscomb())
      .pipe(plug.sassLint())
      .pipe(plug.sassLint.format())
      .pipe(plug.sass opts.sass.riot)
      .pipe(plug.autoprefixer opts.autoprefixer)
      .pipe(plug.cssbeautify opts.cssbeautify)
      .pipe(plug.csslint opts.csslint)
      .pipe(plug.csslint.reporter())
      .pipe(plug.cssnano())
      .pipe(plug.injectString.wrap("  <style scoped>\n", "  </style>\n"))
      .pipe(sass.restore)

      .pipe(coffee)
      .pipe(plug.coffee opts.coffee)
      .pipe(plug.injectString.wrap("  <script>\n", "  </script>\n"))
      .pipe(coffee.restore)

      .pipe(notags)
      .pipe(plug.concat(folder  + ".tag"))
      .pipe(plug.injectString.wrap("<" + folder + ">\n", "</" + folder + ">"))
      .pipe(notags.restore)
      .pipe(plug.riot())
      .pipe(gulp.dest path.join(opts.web, "js"))
      .pipe(plug.uglify())
      .pipe(plug.injectString.prepend("/*! github.com/ptb/riot-tags, @license Apache-2.0 */\n"))

      .pipe(gulp.dest path.join(opts.www, "js"))
  )
  done()

gulp.task "reload", (done) ->
  plug.browserSyncWeb.reload()
  plug.browserSyncWww.reload()
  done()

gulp.task "restart", (done) ->
  plug.browserSyncWeb.exit()
  plug.browserSyncWww.exit()
  if process.platform is "darwin"
    spawn "osascript", [
      "-e", 'activate app "Terminal"'
      "-e", 'tell app "System Events" to keystroke "k" using command down' ]
  plug.kexec("npm", ["start"])
  done()

gulp.task "serve", (done) ->
  plug.browserSyncWeb.init opts.browserSync(opts.web, 8000)
  plug.browserSyncWww.init opts.browserSync(opts.www, 8010)
  done()

gulp.task "watch", (done) ->
  gulp.watch opts.restart.files, gulp.series("restart")
  gulp.watch path.join(opts.src, "**", "*"), gulp.series("build", "reload")
  done()

gulp.task "default", gulp.series("build", gulp.parallel("serve", "watch"))
