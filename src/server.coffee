
util = require 'util'

async = require 'async'
fs = require 'fs'
path = require 'path'
url = require 'url'
colors = require 'colors'


{loadTemplates} = require './templates'
{ContentTree, Page, Resource} = require './content'
{logger, extend, stripExtension} = require './common'
{renderResource, renderPage} = require './renderer'

colorCode = (code) ->
  s = code.toString()
  switch Math.floor code / 100
    when 2
      return s.green
    when 4
      return s.yellow
    when 5
      return s.red
    else
      return s

setup = (options, callback) ->

  contentHandler = (request, response, callback) ->
    uri = url.parse(request.url).pathname.replace /(.+)\/$/, '$1'
    logger.verbose "contentHandler: #{ uri }"
    async.waterfall [
      (callback) ->
        async.parallel
          templates: async.apply loadTemplates, options.templates
          contents: async.apply ContentTree.fromDirectory, options.contents
        , callback
      (result, callback) ->
        {contents, templates} = result
        async.detect ContentTree.flatten(contents), (item, callback) ->
          callback (uri is item.url)
        , (result) ->
          if result
            if result instanceof Resource
              response.writeHead 200
              renderResource result, response, (error) ->
                callback error, 200
            else
              # page
              ctx = {contents: contents}
              extend ctx, options.locals
              response.writeHead 200, 'Content-Type': 'text/html'
              renderPage result, templates, ctx, response, (error) ->
                callback error, 200
          else
            callback.final() # not handled
    ], callback

  requestHandler = (request, response) ->
    start = new Date()
    uri = url.parse(request.url).pathname
    async.waterfall [
      async.apply contentHandler, request, response
    ], (error, responseCode) ->
      if error or !responseCode?
        # request not handled or error
        responseCode = if error? then 500 else 404
        response.writeHead responseCode, 'Content-Type': 'text/plain'
        response.end if error? then error.message else '404 Not Found\n'
      delta = new Date() - start
      logger.info "#{ colorCode(responseCode) } #{ uri.bold } " + "#{ delta }ms".grey

  return requestHandler

run = (options) ->
  http = require 'http'
  server = http.createServer setup options
  server.listen options.port
  serverUrl = "http://localhost:#{ options.port }/".bold
  logger.info "server running on: #{ serverUrl }"

module.exports = setup
module.exports.run = run
