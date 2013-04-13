async = require 'async'
fs = require 'fs'
hljs = require 'highlight.js'
marked = require 'marked'
path = require 'path'
url = require 'url'
yaml = require 'js-yaml'

# monkeypatch to add url resolving to marked
marked.InlineLexer.prototype._outputLink = marked.InlineLexer.prototype.outputLink
marked.InlineLexer.prototype._resolveLink = (href) -> href
marked.InlineLexer.prototype.outputLink = (cap, link) ->
  link.href = @_resolveLink link.href
  return @_outputLink cap, link

parseMarkdownSync = (content, baseUrl) ->
  ### Parse markdown *content* and resolve links using *baseUrl*, returns html. ###

  marked.InlineLexer.prototype._resolveLink = (uri) ->
    url.resolve baseUrl, uri

  tokens = marked.lexer content

  for token in tokens
    switch token.type
      when 'code'
        try
          if token.lang?
            token.text = hljs.highlight(token.lang, token.text).value
          else
            token.text = hljs.highlightAuto(token.text).value
          token.escaped = true
        catch error
          # hljs.highlight throws if lang is unknown

  return marked.parser tokens

module.exports = (env, callback) ->

  class MarkdownPage extends env.plugins.Page

    constructor: (@filepath, @metadata, @markdown) ->

    getLocation: (base) ->
      uri = @getUrl base
      return uri[0..uri.lastIndexOf('/')]

    getHtml: (base=env.config.baseUrl) ->
      ### parse @markdown and return html. also resolves any relative urls to absolute ones ###
      @_html ?= parseMarkdownSync @markdown, @getLocation(base) # cache html
      return @_html

  MarkdownPage.fromFile = (filepath, callback) ->
    async.waterfall [
      (callback) ->
        fs.readFile filepath.full, callback
      (buffer, callback) ->
        MarkdownPage.extractMetadata buffer.toString(), callback
      (result, callback) =>
        {markdown, metadata} = result
        page = new this filepath, metadata, markdown
        callback null, page
    ], callback

  MarkdownPage.extractMetadata = (content, callback) ->
    parseMetadata = (source, callback) ->
      return callback(null, {}) unless source.length > 0
      try
        callback null, yaml.load(source) or {}
      catch error
        callback error

    # split metadata and markdown content
    metadata = ''
    markdown = content

    if content[0...3] is '---'
      # "Front Matter"
      result = content.match /^-{3,}\s([\s\S]*?)-{3,}(\s[\s\S]*|\s?)$/
      if result?.length is 3
        metadata = result[1]
        markdown = result[2]

    async.parallel
      metadata: (callback) ->
        parseMetadata metadata, callback
      markdown: (callback) ->
        callback null, markdown
    , callback

  class JsonPage extends MarkdownPage
    ### Plugin that allows pages to be created with just metadata form a JSON file ###

  JsonPage.fromFile = (filepath, callback) ->
    async.waterfall [
      async.apply env.utils.readJSON, filepath.full
      (metadata, callback) =>
        markdown = metadata.content or ''
        page = new this filepath, metadata, markdown
        callback null, page
    ], callback

  # register the plugins
  env.registerContentPlugin 'pages', '**/*.*(markdown|mkd|md)', MarkdownPage
  env.registerContentPlugin 'pages', '**/*.json', JsonPage

  # done!
  callback()
