
path = require 'path'
async = require 'async'
underscore = require 'underscore'
moment = require 'moment'
marked = require 'marked'

{ContentPlugin} = require './../content'
{stripExtension, extend} = require './../common'

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
    
  getIntro: (base) ->
    @_html ?= @getHtml(base)
    idx = ~@_html.indexOf('<span class="more') or ~@_html.indexOf('<h2') or ~@_html.indexOf('<hr')
    if idx
      @_intro = @_html.substr 0, ~idx
    else
      @_intro = @_html
    return @_intro

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
          moment: moment
          marked: marked
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
    moment(@date).format('ddd, DD MMM YYYY HH:mm:ss ZZ')

  @property 'intro', ->
    @getIntro()

  @property 'hasMore', ->
    @_html ?= @getHtml()
    @_intro ?= @getIntro()
    @_hasMore ?= (@_html.length > @_intro.length)
    return @_hasMore

module.exports = Page
