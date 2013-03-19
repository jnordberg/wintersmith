
async = require 'async'
fs = require 'fs'
path = require 'path'
url = require 'url'
colors = require 'colors'
minimatch = require 'minimatch'
{logger} = require './common'

contentPlugins = []
registerContentPlugin = (treeName, handles, plugin) ->
  ### register a plugin. arguments:
      *treeName* - name that will be shown in the content tree (eg. 'textFiles')
                   generally a plural name is recommended since it will appear in the content-tree
                   as an array of *plugin* instances (eg. contents.somedir.textFiles)
      *handles*: glob-pattern to match (eg. '** / *.*(txt|text)' )
      *plugin*: the <ContentPlugin> subclass ###
  contentPlugins.push
    treeName: treeName
    pattern: handles
    class: plugin

class Model
  @property = (name, method) ->
    ### define read-only property with *name* ###
    Object.defineProperty @prototype, name,
      get: -> method.call @
      enumerable: true

class ContentPlugin extends Model

  render: (locals, contents, templates, callback) ->
    ### *callback* with a ReadStream/Buffer or null if the contents should not be rendered
        *locals* rendering context variables
        *contents* is the full content tree
        *templates* is a map of all templates as: {filename: templateInstance} ###
    throw new Error 'not implemented'

  getFilename: ->
    ### return filename for this content ###
    throw new Error 'not implemented'

  getUrl: (base='/') ->
    ### return url for this content relative to *base* ###
    filename = @getFilename()
    if not base.match /\/$/
      base += '/'
    if process.platform is 'win32'
      filename = filename.replace /\\/g, '/' #'
    url.resolve base, filename

  # some shorthands
  @property 'url', -> @getUrl()
  @property 'filename', -> @getFilename()

ContentPlugin.fromFile = (filename, base, callback) ->
  ### *callback* with an instance of class. *filename* is the relative filename
      from *base* wich is the working directory (content directory) ###

class StaticFile extends ContentPlugin
  ### static file handler, simply serves content as-is. last in chain ###

  constructor: (@_filename, @_base) ->

  getFilename: ->
    @_filename

  render: (args..., callback) ->
    # locals, contents etc not used in this plugin
    try
      rs = fs.createReadStream path.join(@_base, @_filename)
    catch error
      return callback error
    callback null, rs

StaticFile.fromFile = (filename, base, callback) ->
  callback null, new StaticFile(filename, base)

registerContentPlugin 'files', '**/*', StaticFile

slugify = (s) ->
  s = s.replace(/[^\w\s-]/g, '').trim().toLowerCase()
  s = s.replace /[-\s]+/g, '-'
  return s

# Class ContentTree
# not using Class since we need a clean prototype
ContentTree = (filename) ->
  parent = null
  groups = {directories: []}

  for plugin in contentPlugins
    groups[plugin.treeName] = []

  Object.defineProperty this, '_',
    get: -> groups

  Object.defineProperty this, 'filename',
    get: -> filename

  Object.defineProperty this, 'index',
    get: ->
      for key, item of this
        if key[0...5] is 'index' then return item

  Object.defineProperty this, 'parent',
    get: -> parent
    set: (val) -> parent = val

ContentTree.fromDirectory = (directory, args..., callback) ->
  ### recursively scan a *directory* and build a ContentTree
      *args...* are *base* and *options* ###

  # *base* and *options* are optional and can be passed in arbitrary order
  for arg in args
    switch typeof arg
      when 'string'
        base = arg
      when 'object'
        options = arg
  base ?= directory
  options ?= {}

  # create the base tree from *directory*
  tree = new ContentTree path.relative(base, directory)

  # options passed to minimatch for ignore and plugin matching
  minimatchOptions =
    dot: false

  async.waterfall [
    # read directory
    async.apply fs.readdir, directory
    (filenames, callback) ->
      if options.ignore?
        # exclude files matching ignore patterns
        async.filter filenames, (filename, callback) ->
          filename = path.join directory, filename
          relname = path.relative base, filename
          include = true
          for pattern in options.ignore
            if minimatch relname, pattern, minimatchOptions
              logger.verbose "ignoring #{ relname } (matches: #{ pattern })"
              include = false
              break
          callback include
        , (result) -> callback null, result
      else
        callback null, filenames
    (filenames, callback) ->
      async.forEach filenames, (filename, callback) ->
        filename = path.join directory, filename
        async.waterfall [
          async.apply fs.lstat, filename
          (stats, callback) ->
            if stats.isDirectory()
              # recursively map directories to content tree instances
              ContentTree.fromDirectory filename, base, options, (error, result) ->
                result.parent = tree
                tree[path.relative(directory, filename)] = result
                tree._.directories.push result
                callback error

            else if stats.isFile()
              # map any files found to content plugins
              basename = path.basename filename
              relname = path.relative base, filename

              # iterate backwards over all content plugins
              # and check if any plugin can handle this file
              match = false
              for i in [contentPlugins.length - 1..0] by -1
                plugin = contentPlugins[i]
                if minimatch relname, plugin.pattern, minimatchOptions # TODO: dotfile plugin
                  plugin.class.fromFile relname, base, (error, instance) ->
                    if not error
                      instance.parent = tree
                      tree[basename] = instance
                      tree._[plugin.treeName].push instance
                    callback error
                  match = true
                  break
              if not match
                # no matching plugin
                logger.verbose "no plugin to handle #{ filename }"
                callback()
            else
              callback new Error "invalid file #{ filename }"
        ], callback
      , callback
  ], (error) ->
    callback error, tree

ContentTree.inspect = (tree, depth=0) ->
  ### return a pretty formatted string representing the content *tree* ###
  rv = []
  pad = ''
  for i in [0..depth]
    pad += '  '
  for k, v of tree
    if v instanceof ContentTree
      s = "#{ k }/\n".bold
      s += ContentTree.inspect v, depth + 1
    else if v.template?
      s = k.green + " (url: #{ v.url }, template: #{ v.template })".grey
    else if v instanceof StaticFile
      s = k + " (url: #{ v.url })".grey
    else
      s = k + " (url: #{ v.url })".cyan
    rv.push pad + s
  rv.join '\n'

util = require 'util'

ContentTree.flatten = (tree) ->
  ### return all the items in the *tree* as an array of content plugins ###
  rv = []
  for key, value of tree
    if value instanceof ContentTree
      rv = rv.concat ContentTree.flatten value
    else
      rv.push value
  return rv

module.exports.ContentTree = ContentTree
module.exports.ContentPlugin = ContentPlugin
module.exports.registerContentPlugin = registerContentPlugin
