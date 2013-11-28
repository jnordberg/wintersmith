### server.coffee ###

async = require 'async'
chokidar = require 'chokidar'
colors = require 'colors'
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

sleep = (callback) -> setTimeout callback, 50

normalizeUrl = (anUrl) ->
  anUrl += 'index.html' if anUrl[anUrl.length - 1] is '/'
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

setup = (env) ->
  ### Create a preview request handler. ###

  contents = null
  templates = null
  locals = null
  lookup = {} # url to content map

  # tasks that will block the request until completed
  block =
    contentChange: false
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

  changeHandler = (error) ->
    ### Emits a change event if called without error ###
    env.emit 'change' unless error?
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
    ignored: (path) ->
      for pattern in env.config.ignore
        if minimatch env.relativeContentsPath(path), pattern
          return true
      return false
    ignoreInitial: true
  contentWatcher.on 'change', (path) ->
    return if not contents? or block.contentsLoad
    # ignore if we dont have the tree loaded or it's loading

    block.contentChange = true

    content = null
    for item in ContentTree.flatten(contents)
      if item.__filename is path
        content = item
        break
    if not content
      throw new Error "Got a change event for item not previously in tree: #{ path }"

    filepath =
      relative: env.relativeContentsPath path
      full: path

    tree = content.parent
    key = keyForValue tree, content
    group = tree._[content.__plugin.group]

    if not key?
      throw new Error "Content #{ content.filename } not found in it's parent tree!"

    loadContent env, filepath, (error, newContent) ->
      if error?
        contents = null
        lookup = {}
        block.contentChange = false
        return

      # replace old contents
      newContent.parent = tree
      tree[key] = newContent

      # also in the trees plugin group
      if not replaceInArray(group, content, newContent)
        throw new Error "Content #{ content.filename } not found in it's plugin group!"

      # keep the lookup map fresh
      delete lookup[normalizeUrl(content.url)]
      lookup[normalizeUrl(newContent.url)] = newContent

      block.contentChange = false
      env.emit 'change', content.filename

  # reload entire tree if a file is removed or added
  # patches to modify the already loaded tree instead are welcome :-)
  contentWatcher.on 'add', -> loadContents(changeHandler) if not block.contentsLoad
  contentWatcher.on 'unlink', -> loadContents(changeHandler) if not block.contentsLoad

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
              mimeType = mime.lookup content.filename
              charset = mime.charsets.lookup mimeType
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
                callback new Error "View for content '#{ res.filename }' returned invalid response. Expected Buffer or Stream."
            else
              callback null, 404, pluginName # not handled, no data from plugin
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
      logstr = "#{ colorCode(responseCode) } #{ uri.bold }"
      logstr += " #{ pluginName }".grey if pluginName?
      logstr += " #{ delta }ms".grey
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
      serverUrl = "http://#{ host }:#{ env.config.port }#{ env.config.baseUrl }".bold
      env.logger.info "server running on: #{ serverUrl }"
    callback error, server

module.exports = {run, setup}
