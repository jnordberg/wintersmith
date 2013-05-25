async = require 'async'
fs = require 'fs'
path = require 'path'
npm = require 'npm'
mkdirp = require 'mkdirp'
childProcess = require 'child_process'

{NpmAdapter, getStorageDir, loadEnv, commonOptions} = require './common'
{fileExists, readJSON, extend} = require './../core/utils'
{logger} = require './../core/logger'

maxListAge = 3 * 24 * 60 * 60 * 1000 # 3 days, in ms
cacheDir = path.resolve getStorageDir(), './cache/'
listFile = path.join cacheDir, 'plugins.json'

usage = """

  usage: wintersmith plugin [options] <command>

  commands:

    #{ 'list'.bold } - list available plugins
    #{ 'install'.bold } <plugin> - install plugin

  options:

    -C, --chdir [path]      change the working directory
    -c, --config [path]     path to config
    -U, --update            force plugin listing refresh

"""

options =
  update:
    alias: 'U'
    default: false

extend options, commonOptions

max = (array, get) ->
  get ?= (item) -> item
  rv = null
  for item in array
    v = get(item)
    rv = v if v > rv
  return rv

lpad = (string, amount, char=' ') ->
  p = ''
  p += char for i in [0...amount-string.length]
  return p + string

clip = (string, maxlen) ->
  return string if string.length <= maxlen
  return string[0...maxlen-2].trim() + ".."

isPlugin = (module) ->
  'wintersmith-plugin' in module.keywords

ensureCacheDir = (callback) ->
  mkdirp cacheDir, (error) -> callback error

fetchListing = (callback) ->
  async.waterfall [
    (callback) -> npm.load {logstream: new NpmAdapter(logger)}, callback
    (_, callback) -> npm.commands.search 'wintersmith', true, 60, callback
    (result, callback) ->
      plugins = (value for key, value of result).filter(isPlugin)
      updated = Date.now()
      plugins.sort (a, b) ->
        an = normalizePluginName a.name
        bn = normalizePluginName b.name
        return -1 if an < bn
        return 1 if an > bn
        return 0
      callback null, {updated, plugins}
  ], callback

loadListing = (callback) ->
  fileExists listFile, (exists) ->
    if exists
      readJSON listFile, callback
    else
      logger.info 'fetching listing for the first time... hang on'
      fetchListing (error, list) ->
        list?._needsSave = true
        callback error, list

writeListing = (list, callback) ->
  json = JSON.stringify list
  fs.writeFile listFile, json, (error) ->
    callback error, list

displayListing = (list, callback) ->
  display = list.plugins.map (plugin) ->
    name = normalizePluginName plugin.name
    description = plugin.description
    maintainers = plugin.maintainers.map((name) -> name[1..]).join(' ')
    return {name, description, maintainers}

  pad = max(display, (item) -> item.name.length)
  maxw = process.stdout.getWindowSize()[0] - 2

  for plugin in display
    line = "#{ lpad(plugin.name, pad) }  #{ clip(plugin.description, maxw - pad - 2) }"
    left = maxw - line.length
    if left > plugin.maintainers.length
      line += lpad(plugin.maintainers, left).grey
    logger.info line.replace /^\s*(\S+)  /, (m) -> m.bold

  callback null, list

updateIfNeeded = (list, callback) ->
  if list._needsSave
    delete list._needsSave
    writeListing list, callback
  else
    delta = Date.now() - list.updated
    if delta > maxListAge
      logger.verbose 'plugin listing stale, updating'
      childProcess.fork module.id, [logger.transports.cli.level]
    callback()

waterfall = (flow, callback) ->
  ### async.waterfall that allows for parallel tasks ###
  resolved = []
  for item in flow
    switch typeof item
      when 'function'
        resolved.push item
      when 'object', 'array'
        resolved.push async.apply async.parallel, item
      else
        return callback new Error "Invalid item '#{ item }' in flow"
  async.waterfall resolved, callback

normalizePluginName = (name) ->
  name.replace /^wintersmith\-/, ''

main = (argv) ->
  action = argv._[1]

  if not action?
    console.log usage
    process.exit 0

  loadCurrentEnv = (callback) ->
    loadEnv argv, callback

  installPlugin = (res, callback) ->
    [env, list] = res

    name = argv._[2]
    plugin = null

    for p in list.plugins
      if normalizePluginName(p.name) is normalizePluginName(name)
        plugin = p
        break

    if not plugin
      return callback new Error "Unknown plugin: #{ name }"

    configFile = env.config.__filename
    packageFile = env.resolvePath 'package.json'

    createPackageJson = (callback) ->
      fileExists packageFile, (exists) ->
        if exists
          callback()
        else
          logger.warn "package.json missing, creating minimal package"
          fs.writeFile packageFile, '{\n  "dependencies": {}\n}\n', callback

    readConfig = (callback) ->
      readJSON configFile, callback

    updateConfig = (config, callback) ->
      config.plugins ?= []
      if plugin.name not in config.plugins
        config.plugins.push plugin.name
      callback null, config

    saveConfig = (config, callback) ->
      logger.verbose "saving config file: #{ configFile }"
      json = JSON.stringify config, null, 2
      fs.writeFile configFile, json + '\n', callback

    install = (callback) ->
      logger.verbose "installing #{ plugin.name }"
      process.chdir env.workDir
      async.series [
        createPackageJson
        (callback) -> npm.load {logstream: new NpmAdapter(logger), save: true}, callback
        (callback) -> npm.install plugin.name, callback
      ], (error) -> callback error

    async.waterfall [install, readConfig, updateConfig, saveConfig], callback

  switch action
    when 'list'
      if argv.update
        cmd = [ensureCacheDir, fetchListing, displayListing, writeListing]
      else
        cmd = [ensureCacheDir, loadListing, displayListing, updateIfNeeded]
    when 'install'
      cmd = [[loadCurrentEnv, loadListing], installPlugin]

    else
      cmd = [(callback) -> callback new Error "Unknown plugin action: #{ action }"]

  waterfall cmd, (error) ->
    if error?
      logger.error error.message, error
      process.exit 1
    else
      process.exit 0

if require.main is module
  logLevel = process.argv[2] or 'info'
  logger.transports.cli.level = logLevel
  async.waterfall [ensureCacheDir, fetchListing, writeListing], (error) ->
    if error?
      logger.error error.message, error
    else
      logger.verbose 'plugin listing updated'

module.exports = main
module.exports.usage = usage
module.exports.options = options
