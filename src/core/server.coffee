### server.coffee ###

async = require 'async'
chokidar = require 'chokidar'
chalk = require 'chalk'
http = require 'http'
mime = require 'mime'
url = require 'url'
minimatch = require 'minimatch'
enableDestroy = require 'server-destroy'
{Stream} = require 'stream'

{Config} = require './config'
{ContentTree, ContentPlugin, loadContent} = require './content'
{pump} = require './utils'
{renderView} = require './renderer'
{runGenerator} = require './generator'

colorCode = (code) ->
  switch Math.floor code / 100
    when 2
      return chalk.green code
    when 4
      return chalk.yellow code
    when 5
      return chalk.red code
    else
      return code.toString()

sleep = (callback) -> setTimeout callback, 50

normalizeUrl = (anUrl) ->
  anUrl += 'index.html' if anUrl[anUrl.length - 1] is '/'
  anUrl += '/index.html' if anUrl.match(/^([^.]*[^/])$/)
  anUrl = decodeURI anUrl
  return anUrl

urlEqual = (urlA, urlB) ->
  normalizeUrl(urlA) is normalizeUrl(urlB)

keyForValue = (object, value) ->
  for key of object
    return key if object[key] is value
  return null

replaceInArray = (array, oldItem, newItem)  ->
  idx = array.indexOf oldItem
  return false if idx is -1
  array[idx] = newItem
  return true

buildLookupMap = (contents) ->
  map = {}
  for item in ContentTree.flatten(contents)
    map[normalizeUrl(item.url)] = item
  return map

lookupCharset = (mimeType) ->
  return if /^text\/|^application\/(javascript|json)/.test(mimeType) then 'UTF-8' else null

setup = (env) ->
  ### Create a preview request handler. ###

  contents = null
  templates = null
  locals = null
  lookup = {} # url to content map

  # tasks that will block the request until completed
  block =
    contentsLoad: false
    templatesLoad: false
    viewsLoad: false
    localsLoad: false

  isReady = ->
    ### Returns true if we have no running tasks ###
    for k, v of block
      return false if v is true
    return true

  logop = (error) ->
    env.logger.error(error.message, error) if error?

  changeHandler = (error, path) ->
    ### Emits a change event if called without error ###
    unless error?
      env.emit 'change', path, false
    logop error

  loadContents = (callback=logop) ->
    block.contentsLoad = true
    lookup = {}
    contents = null
    ContentTree.fromDirectory env, env.contentsPath, (error, result) ->
      if not error?
        contents = result
        lookup = buildLookupMap result
      block.contentsLoad = false
      callback error

  loadTemplates = (callback=logop) ->
    block.templatesLoad = true
    templates = null
    env.getTemplates (error, result) ->
      if not error?
        templates = result
      block.templatesLoad = false
      callback error

  loadViews = (callback=logop) ->
    block.viewsLoad = true
    env.loadViews (error) ->
      block.viewsLoad = false
      callback error

  loadLocals = (callback=logop) ->
    block.localsLoad = true
    locals = null
    env.getLocals (error, result) ->
      if not error?
        locals = result
      block.localsLoad = false
      callback error

  contentWatcher = chokidar.watch env.contentsPath,
    ignoreInitial: true

  # reload content tree on changes
  contentWatcher.on 'all', (type, filename) ->
    return if block.contentsLoad
    relpath = env.relativeContentsPath filename
    for pattern in env.config.ignore
      if minimatch relpath, pattern
        env.emit 'change', relpath, true
        return
    loadContents (error) ->
      contentFilename = null
      if not error? and filename?
        # resolve filename for changed content
        for content in ContentTree.flatten contents
          if content.__filename is filename
            contentFilename = content.filename
            break
      changeHandler error, contentFilename

  templateWatcher = chokidar.watch env.templatesPath,
    ignoreInitial: true
  templateWatcher.on 'all', (event, path) -> loadTemplates(changeHandler) if not block.templatesLoad

  if env.config.views?
    viewsWatcher = chokidar.watch env.resolvePath(env.config.views),
      ignoreInitial: true
    viewsWatcher.on 'all', (event, path) ->
      if not block.viewsLoad
        delete require.cache[path]
        loadViews changeHandler

  contentHandler = (request, response, callback) ->
    uri = normalizeUrl url.parse(request.url).pathname

    env.logger.verbose "contentHandler - #{ uri }"

    async.waterfall [
      (callback) ->
        # run generators
        async.mapSeries env.generators, (generator, callback) ->
          runGenerator env, contents, generator, callback
        , callback
      (generated, callback) ->
        # merge generated
        if generated.length > 0
          try
            tree = new ContentTree '', env.getContentGroups()
            for gentree in generated
              ContentTree.merge tree, gentree
            map = buildLookupMap(generated)
            ContentTree.merge tree, contents
          catch error
            return callback error
          callback null, tree, map
        else
          callback null, contents, {}
      (tree, generatorLookup, callback) ->
        # render content
        content = generatorLookup[uri] or lookup[uri]
        if content?
          pluginName = content.constructor.name
          renderView env, content, locals, tree, templates, (error, result) ->
            if error then callback error, 500, pluginName
            else if result?
              mimeType = mime.getType(content.filename) ? mime.getType(uri)
              charset = lookupCharset mimeType
              if charset
                contentType = "#{ mimeType }; charset=#{ charset }"
              else
                contentType = mimeType
              if result instanceof Stream
                response.writeHead 200, 'Content-Type': contentType
                pump result, response, (error) -> callback error, 200, pluginName
              else if result instanceof Buffer
                response.writeHead 200, 'Content-Type': contentType
                response.write result
                response.end()
                callback null, 200, pluginName
              else
                callback new Error "View for content '#{ content.filename }' returned invalid response. Expected Buffer or Stream."
            else
              # not handled, no data from plugin
              response.writeHead 404, 'Content-Type': 'text/plain'
              response.end '404 Not Found\n'
              callback null, 404, pluginName
        else
          callback() # not handled, no matching url
    ], callback

  requestHandler = (request, response) ->
    start = Date.now()
    uri = url.parse(request.url).pathname

    async.waterfall [
      (callback) ->
        # load contents if needed and not already loading
        if not block.contentsLoad and not contents?
          loadContents callback
        else
          callback()
      (callback) ->
        # load templates if needed and not already loading
        if not block.templatesLoad and not templates?
          loadTemplates callback
        else
          callback()
      (callback) ->
        # block until we are ready
        async.until isReady, sleep, callback
      (callback) ->
        # finally pass the request to the contentHandler
        contentHandler request, response, callback
    ], (error, responseCode, pluginName) ->
      if error? or not responseCode?
        # request not handled or error
        responseCode = if error? then 500 else 404
        response.writeHead responseCode, 'Content-Type': 'text/plain'
        response.end if error? then error.message else '404 Not Found\n'
      delta = Date.now() - start
      logstr = "#{ colorCode(responseCode) } #{ chalk.bold uri }"
      logstr += " #{ chalk.grey pluginName }" if pluginName?
      logstr += chalk.grey " #{ delta }ms"
      env.logger.info logstr
      if error
        env.logger.error error.message, error

  # preload
  loadContents()
  loadTemplates()
  loadViews()
  loadLocals()

  requestHandler.destroy = ->
    contentWatcher.close()
    templateWatcher.close()
    viewsWatcher?.close()

  return requestHandler

run = (env, callback) ->
  server = null
  handler = null

  if env.config._restartOnConfChange and env.config.__filename?
    # watch config file and reload when changed
    env.logger.verbose "watching config file #{ env.config.__filename } for changes"
    configWatcher = chokidar.watch env.config.__filename
    configWatcher.on 'change', ->
      try
        config = Config.fromFileSync env.config.__filename
      catch error
        env.logger.error "Error reloading config: #{ error.message }", error
      if config?
        # restore any cli options passed in when starting
        if cliopts = env.config._cliopts
          config._cliopts = {}
          for key, value of cliopts
            config[key] = config._cliopts[key] = value
        env.setConfig config
        restart (error) ->
          throw error if error
          env.logger.verbose 'config file change detected, server reloaded'
          env.emit 'change'

  restart = (callback) ->
    env.logger.info 'restarting server'
    async.waterfall [stop, start], callback

  stop = (callback) ->
    if server?
      server.destroy (error) ->
        handler.destroy()
        env.reset()
        callback error
    else
      callback()

  start = (callback) ->
    async.series [
      (callback) -> env.loadPlugins callback
      (callback) ->
        handler = setup env
        server = http.createServer handler
        enableDestroy server
        server.on 'error', (error) ->
          callback? error
          callback = null
        server.on 'listening', ->
          callback? null, server
          callback = null
        server.listen env.config.port, env.config.hostname
    ], callback

  process.on 'uncaughtException', (error) ->
    env.logger.error error.message, error
    process.exit 1

  env.logger.verbose 'starting preview server'

  start (error, server) ->
    if not error?
      host = env.config.hostname or 'localhost'
      serverUrl = "http://#{ host }:#{ env.config.port }#{ env.config.baseUrl }"
      env.logger.info "server running on: #{ chalk.bold serverUrl }"
    callback error, server

module.exports = {run, setup}
