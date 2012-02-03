
{Highlight} = require 'highlight'
marked = require 'marked';
async = require 'async'
path = require 'path'

is_relative = (url) ->
  ### returns true if *url* is relative; otherwise false ###
  !/(^\w+:)|(^\/)/.test url

parseMetadata = (metadata, callback) ->
  ### takes *metadata* in the format:
        key: value
        foo: bar
      returns parsed object ###

  rv = {}
  try
    lines = metadata.split '\n'

    for line in lines
      pos = line.indexOf ':'
      key = line.slice(0, pos).toLowerCase()
      value = line.slice(pos + 1).trim()
      rv[key] = value

    callback null, rv

  catch error
    callback error

parseMarkdownSync = (content, baseURL) ->
  ### takes markdown *content* and returns html using *baseURL* for any relative urls
      returns html ###

  marked.inlineLexer.formatUrl = (url) ->
    if is_relative url
      return path.join baseURL, url
    else
      return url

  tokens = marked.lexer content

  for token in tokens
    switch token.type
      when 'code'
        # token.lang is set since this is github markdown, but highlight has no way to manually set lang
        token.text = Highlight token.text, '  ' # string is tab replacement
        token.escaped = true

  return marked.parser tokens

module.exports = (content, callback) ->
  # split metadata and markdown content
  split_idx = content.indexOf '\n\n' # should probably make this a bit more robust

  async.parallel
    metadata: (callback) ->
      parseMetadata content.slice(0, split_idx), callback
    body: (callback) ->
      callback null, content.slice(split_idx + 2)
  , callback

module.exports.parseMarkdownSync = parseMarkdownSync
