
util = require 'util'
async = require 'async'
fs = require 'fs'
path = require 'path'
url = require 'url'
colors = require 'colors'
mime = require 'mime'

{logger, extend, stripExtension} = require './common'
{loadTemplates, loadPlugins, ContentTree} = require './'

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
  ### returns a wintersmith http middleware ###

  # options passed to ContentTree.fromDirectory
  contentOptions =
    ignore: options.ignore

  contentHandler = (request, response, callback) ->
    uri = url.parse(request.url).pathname
    logger.verbose "contentHandler: #{ uri }"
    async.waterfall [
      (callback) ->
        # load contents and templates
        async.parallel
          templates: async.apply loadTemplates, options.templates
          contents: async.apply ContentTree.fromDirectory, options.contents, contentOptions
        , callback
      (result, callback) ->
        # render if uri matches
        {contents, templates} = result
        async.detect ContentTree.flatten(contents), (item, callback) ->
          callback (uri is item.url or (item.url[item.url.length - 1] is '/' and uri is (item.url + 'index.html')))
        , (result) ->
          if result
            result.render options.locals, contents, templates, (error, res) ->
              if error
                callback error
              else if res instanceof fs.ReadStream
                response.writeHead 200, 'Content-Type': mime.lookup(result.filename)
                util.pump res, response, (error) ->
                  callback error, 200
              else if res instanceof Buffer
                response.writeHead 200, 'Content-Type': mime.lookup(result.filename)
                response.write res
                response.end()
                callback null, 200
              else
                callback() # not handled
          else
            callback() # not handled
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
      if error
        logger.error error.message, error

  return requestHandler

run = (options) ->
  http = require 'http'
  logger.verbose 'setting up server'
  async.waterfall [
    async.apply loadPlugins, options.plugins
  ], (error) ->
    if error
      logger.error error.message, error
    else
      server = http.createServer setup options
      server.listen options.port
      serverUrl = "http://#{ options.domain }:#{ options.port }/".bold
      logger.info "server running on: #{ serverUrl }"

module.exports = setup
module.exports.run = run
