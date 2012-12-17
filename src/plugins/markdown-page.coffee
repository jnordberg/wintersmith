{Highlight} = require 'highlight'
marked = require 'marked'
async = require 'async'
path = require 'path'
url = require 'url'
fs = require 'fs'
yaml = require 'js-yaml'
{logger} = require './../common'
Page = require './page'

is_relative = (uri) ->
  ### returns true if *uri* is relative; otherwise false ###
  (url.parse(uri).protocol == undefined)

parseMetadata = (source, callback) ->
  try
    callback null, yaml.load(source) or {}
  catch error
    callback error

extractMetadata = (content, callback) ->
  # split metadata and markdown content

  if content[0...3] is '---'
    # "Front Matter"
    result = content.match /-{3,}\s([\s\S]*?)-{3,}\s([\s\S]*)/
    if result?.length is 3
      metadata = result[1]
      markdown = result[2]
    else
      metadata = ''
      markdown = content
  else
    # old style metadata
    logger.warn 'Deprecation warning: page metadata should be encapsulated by at least three dashes (---)'
    split_idx = content.indexOf '\n\n'
    metadata = content.slice(0, split_idx)
    markdown = content.slice(split_idx + 2)

  async.parallel
    metadata: (callback) ->
      parseMetadata metadata, callback
    markdown: (callback) ->
      callback null, markdown
  , callback

parseMarkdownSync = (content, baseUrl) ->
  ### takes markdown *content* and returns html using *baseUrl* for any relative urls
      returns html ###

  marked.inlineLexer.formatUrl = (uri) ->
    if is_relative uri
      return url.resolve baseUrl, uri
    else
      return uri

  tokens = marked.lexer content

  for token in tokens
    switch token.type
      when 'code'
        # token.lang is set since this is github markdown, but highlight has no way to manually set lang
        token.text = Highlight token.text, '  ' # string is tab replacement
        token.escaped = true

  return marked.parser tokens

class MarkdownPage extends Page

  getLocation: (base) ->
    uri = @getUrl base
    return uri[0..uri.lastIndexOf('/')]

  getHtml: (base) ->
    ### parse @markdown and return html. also resolves any relative urls to absolute ones ###
    @_html ?= parseMarkdownSync @_content, @getLocation(base) # cache html
    return @_html

MarkdownPage.fromFile = (filename, base, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile path.join(base, filename), callback
    (buffer, callback) ->
      extractMetadata buffer.toString(), callback
    (result, callback) =>
      {markdown, metadata} = result
      page = new this filename, markdown, metadata
      callback null, page
  ], callback

module.exports = MarkdownPage
