
async = require 'async'
fs = require 'fs'
path = require 'path'
parser = require './parser'
glob = require 'glob'
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

class Article extends Model

  constructor: (@body='', @metadata={}, @files=[]) ->

  getHtml: (baseURL='/') ->
    ### parse @body and return html. also resolves all relative
        to absolute ones using *baseURL* as base ###
    @_html ?= parser.parseMarkdownSync @body, path.join(baseURL, @slug) # cache html
    return @_html

  @property 'title', ->
    @metadata.title or 'Untitled'

  @property 'date', ->
    new Date(@metadata.date or 0)

  @property 'slug', ->
    @metadata.slug or slugify stripExtension @filename

  @property 'filename', ->
    @metadata.filename or 'unknown'

  @property 'rfc822date', ->
    rfc822 @date

  @property 'html', ->
    @getHtml()

Article.fromFile = (filename, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      parser buffer.toString(), callback
    (result, callback) ->
      {body, metadata} = result
      metadata.filename = path.basename filename
      callback null, new Article body, metadata
  ], callback

Article.fromDirectory = (directory, callback) ->
  opts = {cwd: directory, nosort: true} # glob options
  filename = null
  async.waterfall [
    async.apply glob, 'index.*(md|markdown)', opts
    (files, callback) ->
      if files.length == 1
        # read article markdown
        filename = files[0]
        fs.readFile path.join(directory, files[0]), callback
      else
        callback new Error "found too many index files in #{ directory }", files
    (buffer, callback) ->
      async.parallel
        # parse article
        parser: async.apply parser, buffer.toString()
        # get article files
        files: async.apply glob, '*', opts # glob negating broken - https://github.com/isaacs/node-glob/issues/33
      , callback
    (result, callback) ->
      # workaround for glob bug
      files = result.files.filter (file) ->
        file != filename
      files = files.map (file) ->
        path.join directory, file
      {body, metadata} = result.parser
      metadata.filename = path.basename directory
      callback null, new Article body, metadata, files
  ], callback

module.exports = Article
