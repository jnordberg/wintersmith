async = require 'async'
fs = require 'fs'
hljs = require 'highlight.js'
marked = require 'marked'
path = require 'path'
url = require 'url'
yaml = require 'js-yaml'

# monkeypatch to add url resolving to marked
if not marked.InlineLexer.prototype._outputLink?
  marked.InlineLexer.prototype._outputLink = marked.InlineLexer.prototype.outputLink
  marked.InlineLexer.prototype._resolveLink = (href) -> href
  marked.InlineLexer.prototype.outputLink = (cap, link) ->
    link.href = @_resolveLink link.href
    return @_outputLink cap, link

resolveLink = (content, uri, baseUrl) ->
  ### Resolve *uri* relative to *content*, resolves using
      *baseUrl* if no matching content is found. ###
  uriParts = url.parse uri
  if uriParts.protocol
    # absolute uri
    return uri
  else if uriParts.hash is uri
    # internal anchor
    return uri
  else
    # search pathname in content tree relative to *content*
    nav = content.parent
    path = uriParts.pathname?.split('/') or []
    while path.length and nav?
      part = path.shift()
      if part == ''
        # uri begins with / go to contents root
        nav = nav.parent while nav.parent
      else if part == '..'
        nav = nav.parent
      else
        nav = nav[part]
    if nav?.getUrl?
      return nav.getUrl() + [uriParts.hash]
    return url.resolve baseUrl, uri

parseMarkdownSync = (content, markdown, baseUrl, options) ->
  ### Parse *markdown* found on *content* node of contents and
  resolve links by navigating in the content tree. use *baseUrl* as a last resort
  returns html. ###

  marked.InlineLexer.prototype._resolveLink = (uri) ->
    resolveLink content, uri, baseUrl

  options.highlight = (code, lang) ->
    try
      if lang is 'auto'
        return hljs.highlightAuto(code).value
      else if hljs.getLanguage lang
        return hljs.highlight(lang, code).value
    catch error
      return code

  marked.setOptions options
  return marked markdown

module.exports = (env, callback) ->
  # Highlight.js configuration
  hljsConfigDefaults =
    classPrefix: ''

  hljsConfig = env.config.highlightjs or {}
  for key, value of hljsConfigDefaults
    hljsConfig[key] ?= hljsConfigDefaults[key]

  hljs.configure hljsConfig

  class MarkdownPage extends env.plugins.Page

    constructor: (@filepath, @metadata, @markdown) ->

    getLocation: (base) ->
      uri = @getUrl base
      return uri[0..uri.lastIndexOf('/')]

    getHtml: (base=env.config.baseUrl) ->
      ### parse @markdown and return html. also resolves any relative urls to absolute ones ###
      options = env.config.markdown or {}
      return parseMarkdownSync this, @markdown, @getLocation(base), options

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
        if error.problem? and error.problemMark?
          lines = error.problemMark.buffer.split '\n'
          markerPad = (' ' for [0...error.problemMark.column]).join('')
          error.message = """YAML: #{ error.problem }

              #{ lines[error.problemMark.line] }
              #{ markerPad }^

          """
        else
          error.message = "YAML Parsing error #{ error.message }"
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
    else if content[0...12] is '```metadata\n'
      # "Winter Matter"
      end = content.indexOf '\n```\n'
      if end isnt -1
        metadata = content.substring 12, end
        markdown = content.substring end + 5

    async.parallel
      metadata: (callback) ->
        parseMetadata metadata, callback
      markdown: (callback) ->
        callback null, markdown
    , callback

  MarkdownPage.resolveLink = resolveLink

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
