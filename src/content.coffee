
async = require 'async'
fs = require 'fs'
path = require 'path'
colors = require 'colors'
parser = require './parser'
{rfc822, stripExtension} = require './common'

slugify = (s) ->
  s = s.replace(/[^\w\s-]/g, '').trim().toLowerCase()
  s = s.replace /[-\s]+/g, '-'
  return s

class Model
  @property = (name, method) ->
    ### define read-only property with *name* ###
    Object.defineProperty @prototype, name,
      get: -> method.call @
      enumerable: true

class Resource extends Model

  constructor: (@filename, @fullPath) -> # store fullPath just so we dont need to open a readStream already

  getUrl: (baseUrl='/') ->
    path.join baseUrl, @filename

  @property 'readStream', ->
    fs.createReadStream @fullPath

  @property 'url', ->
    @getUrl()

Resource.fromFile = (filename, base, callback) ->
  if !callback?
    callback = base
    base = path.dirname filename
  callback null, new Resource path.relative(base, filename), filename

class Page extends Model

  constructor: (@filename, @markdown, @metadata) ->

  getUrl: (base='/') ->
    name = stripExtension(@filename)
    if path.basename(name) is 'index'
      url = path.dirname name
    else
      url = name + '.html'
    path.join base, url

  getLocation: (base='/') ->
    path.join base, path.dirname(@filename)

  getHtml: (base) ->
    ### parse @markdown and return html. also resolves any relative urls to absolute ones ###
    @_html ?= parser.parseMarkdownSync @markdown, @getLocation(base) # cache html
    return @_html

  @property 'url', ->
    @getUrl()

  @property 'html', ->
    @getHtml()

  @property 'title', ->
    @metadata.title or 'Untitled'

  @property 'template', ->
    @metadata.template or 'page'

  @property 'date', ->
    new Date(@metadata.date or 0)

  @property 'rfc822date', ->
    rfc822 @date

  @property 'intro', ->
    idx = ~@html.indexOf('<span class="more') or ~@html.indexOf('<h2')
    if idx
      return @html.substr 0, ~idx
    else
      return @html

  @property 'hasMore', ->
    @_hasMore ?= (@html.length > @intro.length)
    return @_hasMore

Page.fromFile = (filename, base, callback) ->
  if !callback?
    callback = base
    base = path.dirname filename

  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      parser buffer.toString(), callback
    (result, callback) ->
      {markdown, metadata} = result
      callback null, new Page path.relative(base, filename), markdown, metadata
  ], callback

# Class ContentTree
# not using Class since we need a clean prototype to iterate over
ContentTree = (filename) ->
  private = {}
  ['pages', 'directories', 'resources'].forEach (name) =>
    private[name] = []
    Object.defineProperty @, name,
      get: -> private[name]
  Object.defineProperty @, 'filename',
    get: -> filename
  Object.defineProperty @, 'index',
    get: ->
      @['index.md'] or @['index.markdown']

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
                tree.directories.push result
                callback error
            else if stats.isFile()
              ext = path.extname filename
              basename = path.basename filename
              if ext == '.md' or ext == '.markdown'
                Page.fromFile filename, base, (error, page) ->
                  page.metadata.fstats = stats
                  tree[basename] = page
                  tree.pages.push page
                  callback error
              else if basename.substr(0, 1) isnt '.'
                Resource.fromFile filename, base, (error, resource) ->
                  resource.stats = stats
                  tree[path.basename(filename)] = resource
                  tree.resources.push resource
                  callback error
              else
                # TODO: handle dotfiles
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
    else if v instanceof Page
      s = k.green + " (url: #{ v.url }, template: #{ v.template })".grey
    else
      s = k + " (url: #{ v.url })".grey
    rv.push pad + s
  rv.join '\n'

ContentTree.flatten = (tree) ->
  items = tree.pages.concat tree.resources
  for dir in tree.directories
    items = items.concat ContentTree.flatten dir
  return items

module.exports.Resource = Resource
module.exports.Page = Page
module.exports.ContentTree = ContentTree
