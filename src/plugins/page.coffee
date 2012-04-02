
path = require 'path'
async = require 'async'
underscore = require 'underscore'

{ContentPlugin} = require './../content'
{stripExtension, extend, rfc822} = require './../common'

class Page extends ContentPlugin
  ### page content plugin, a page is a file that has
      metadata, html and a template that renders it ###

  constructor: (@_filename, @_content, @_metadata) ->

  getFilename: ->
    @_metadata.filename or stripExtension(@_filename) + '.html'

  getHtml: (base='/') ->
    @_content

  getUrl: (base) ->
    super(base).replace /index\.html$/, ''

  render: (locals, contents, templates, callback) ->
    if @template == 'none'
      # dont render
      return callback null, null

    async.waterfall [
      (callback) =>
        template = templates[@template]
        if not template?
          callback new Error "page '#{ @filename }' specifies unknown template '#{ @template }'"
        else
          callback null, template
      (template, callback) =>
        ctx =
          page: @
          contents: contents
          _: underscore
        extend ctx, locals
        template.render ctx, callback
    ], callback

  @property 'metadata', ->
    @_metadata

  @property 'template', ->
    @_metadata.template or 'none'

  @property 'html', ->
    @getHtml()

  @property 'title', ->
    @_metadata.title or 'Untitled'

  @property 'date', ->
    new Date(@_metadata.date or 0)

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

module.exports = Page
