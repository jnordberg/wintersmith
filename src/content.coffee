
async = require 'async'
fs = require 'fs'
path = require 'path'
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
    path.join base, @getFilename()

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
  private = {directories: []}
  for plugin in contentPlugins
    private[plugin.treeName] = []
  Object.defineProperty @, '_',
    get: -> private
  Object.defineProperty @, 'filename',
    get: -> filename
  Object.defineProperty @, 'index',
    get: -> @['index.md'] or @['index.markdown']

ContentTree.fromDirectory = (directory, base, callback) ->
  if !callback?
    callback = base
    base = directory

  tree = new ContentTree path.relative(base, directory)

  async.waterfall [
    async.apply fs.readdir, directory
    (filenames, callback) ->
      async.forEach filenames, (filename, callback) ->
        filename = path.join directory, filename
        async.waterfall [
          async.apply fs.lstat, filename
          (stats, callback) ->
            if stats.isDirectory()
              ContentTree.fromDirectory filename, base, (error, result) ->
                tree[path.relative(directory, filename)] = result
                tree._.directories.push result
                callback error
            else if stats.isFile()
              basename = path.basename filename
              relname = path.relative base, filename
              # iterate backwards over all content plugins
              match = false
              for i in [contentPlugins.length - 1..0] by -1
                plugin = contentPlugins[i]
                if minimatch relname, plugin.pattern, {dot: false} # TODO: dotfile plugin
                  plugin.class.fromFile relname, base, (error, instance) ->
                    if not error
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
