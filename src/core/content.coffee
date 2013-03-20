### content.coffee ###

async = require 'async'
fs = require 'fs'
path = require 'path'
url = require 'url'
colors = require 'colors'
minimatch = require 'minimatch'

class ContentPlugin
  @property = (name, getter) ->
    ### Define read-only property with *name*. ###
    if typeof getter is 'string'
      get = -> this[getter].call this
    else
      get = -> getter.call this
    Object.defineProperty @prototype, name,
      get: get
      enumerable: true

  @property 'view', 'getView'
  getView: ->
    ### Return a view that renders the plugin. Either a string naming a exisitng view or a function:
        `(env, locals, contents, templates, callback) ->`
        Where *environment* is the current wintersmith environment, *contents* is the content-tree
        and *templates* is a map of all templates as: {filename: templateInstance}. *callback* should be
        called with a stream/buffer or null if this plugin instance should not be rendered. ###
    throw new Error 'Not implemented.'

  @property 'filename', 'getFilename'
  getFilename: ->
    ### Return filename for this content. This is where the result of the plugin's view will be written to. ###
    throw new Error 'Not implemented.'

  @property 'url', 'getUrl'
  getUrl: (base='/') ->
    ### Return url for this content relative to *base*. ###
    filename = @getFilename()
    if not base.match /\/$/
      base += '/'
    if process.platform is 'win32'
      filename = filename.replace /\\/g, '/' #'
    return url.resolve base, filename

  @property 'pluginColor', 'getPluginColor'
  getPluginColor: ->
    ### Return vanity color used to identify the plugin when printing the content tree
        choices are: bold, italic, underline, inverse, yellow, cyan, white, magenta,
        green, red, grey, blue, rainbow, zebra or none. ###
    return 'cyan'

  @property 'pluginInfo', 'getPluginInfo'
  getPluginInfo: ->
    ### Return plugin information. Also displayed in the content tree printout. ###
    return "url: #{ @url }"

ContentPlugin.fromFile = (env, filepath, callback) ->
  ### Calls *callback* with an instance of class. Where *env* is the current environment and
      *filepath* is an object containing both the absolute and realative paths for the file.
      E.g. {
        full: "/home/foo/mysite/contents/somedir/somefile.ext",
        relative: "somedir/somefile.ext"
      } ###
  throw new Error 'Not implemented.'

class StaticFile extends ContentPlugin
  ### Static file handler, simply serves content as-is. Last in chain. ###

  constructor: (@env, @filepath) ->

  getView: ->
    return (args..., callback) ->
      # locals, contents etc not used in this plugin
      try
        rs = fs.createReadStream @filepath.full
      catch error
        return callback error
      callback null, rs

  getFilename: ->
    @filepath.relative

  getPluginColor: ->
    'none'

StaticFile.fromFile = (env, filepath, callback) ->
  callback null, new StaticFile(env, filepath)

# Class ContentTree
# not using Class since we need a clean prototype
ContentTree = (environment, filename) ->
  parent = null
  groups = {directories: [], files: []}

  for plugin in environment.contentPlugins
    groups[plugin.group] = []

  Object.defineProperty this, '_',
    get: -> groups

  Object.defineProperty this, 'filename',
    get: -> filename

  Object.defineProperty this, 'index',
    get: ->
      for key, item of this
        if key[0...6] is 'index.'
          return item
      return

  Object.defineProperty this, 'parent',
    get: -> parent
    set: (val) -> parent = val

ContentTree.fromDirectory = (env, directory, callback) ->
  ### Recursively scan *directory* and build a ContentTree with enviroment *env*.
      Calls *callback* with a nested ContentTree or an error if something went wrong. ###

  reldir = env.relativeContentsPath directory
  tree = new ContentTree env, reldir

  # options passed to minimatch for ignore and plugin matching
  minimatchOptions =
    dot: false

  readDirectory = (callback) ->
    fs.readdir directory, callback

  resolveFilenames = (filenames, callback) ->
    async.map filenames, (filename, callback) ->
      relname = path.join reldir, filename
      callback null,
        full: path.join env.contentsPath, relname
        relative: relname
    , callback

  filterIgnored = (filenames, callback) ->
    ### Exclude *filenames* matching ignore patterns in environment config. ###
    if env.config.ignore.length > 0
      async.filter filenames, (filename, callback) ->
        include = true
        for pattern in env.config.ignore
          if minimatch filename.relative, pattern, minimatchOptions
            env.logger.verbose "ignoring #{ filename.relative } (matches: #{ pattern })"
            include = false
            break
        callback include
      , (result) -> callback null, result
    else
      callback null, filenames

  createInstance = (filepath, callback) ->
    ### Create plugin or subtree instance for *filepath*. ###
    async.waterfall [
      async.apply fs.lstat, filepath.full
      (stats, callback) ->
        basename = path.basename filepath.relative

        # recursively map directories to content tree instances
        if stats.isDirectory()
          ContentTree.fromDirectory env, filepath.full, (error, result) ->
            result.parent = tree
            tree[basename] = result
            tree._.directories.push result # add instance to the directory group of its parent
            callback error

        # map files to content plugins
        else if stats.isFile()
          # iterate backwards over all content plugins and check if any plugin can handle this file
          # any file not matched will be handled by the static file plug
          plugin =
            class: StaticFile
            group: 'files'
          for i in [env.contentPlugins.length - 1..0] by -1
            if minimatch filepath.relative, env.contentPlugins[i].pattern, minimatchOptions
              plugin = env.contentPlugins[i]
              break

          plugin.class.fromFile env, filepath, (error, instance) ->
            if not error
              instance.parent = tree
              instance.__filename = filepath.full # internal, used by preview server to watch files
              tree[basename] = instance
              tree._[plugin.group].push instance
            callback error

        # This should never happen™
        else
          callback new Error "Invalid file #{ filepath.full }."

    ], callback

  createInstances = (filenames, callback) ->
    async.forEach filenames, createInstance, callback

  async.waterfall [
    readDirectory
    resolveFilenames
    filterIgnored
    createInstances
  ], (error) ->
    callback error, tree

ContentTree.inspect = (tree, depth=0) ->
  ### Return a pretty formatted string representing the content *tree*. ###
  rv = []
  pad = ''
  for i in [0..depth]
    pad += '  '
  keys = Object.keys(tree).sort (a, b) ->
    # sort items by type and name to keep directories on top
    ad = tree[a] instanceof ContentTree
    bd = tree[b] instanceof ContentTree
    return bd - ad if ad isnt bd
    return -1 if a < b
    return 1 if a > b
    return 0
  for k in keys
    v = tree[k]
    if v instanceof ContentTree
      s = "#{ k }/\n".bold
      s += ContentTree.inspect v, depth + 1
    else
      s = if v.pluginColor isnt 'none' then k[v.pluginColor] else k
      s += " (#{ v.pluginInfo })".grey
    rv.push pad + s
  rv.join '\n'

ContentTree.flatten = (tree) ->
  ### Return all the items in the *tree* as an array of content plugins. ###
  rv = []
  for key, value of tree
    if value instanceof ContentTree
      rv = rv.concat ContentTree.flatten value
    else
      rv.push value
  return rv

### Exports ###

exports.ContentTree = ContentTree
exports.ContentPlugin = ContentPlugin
