async = require 'async'
chalk = require 'chalk'
fs = require 'fs'
path = require 'path'
npm = require 'npm'
mkdirp = require 'mkdirp'
https = require 'https'

{NpmAdapter, loadEnv, commonOptions, extendOptions} = require './common'
{fileExists, readJSON} = require './../core/utils'
{logger} = require './../core/logger'

usage = """

  usage: wintersmith plugin [options] <command>

  commands:

    #{ chalk.bold 'list' } - list available plugins
    #{ chalk.bold 'install' } <plugin> - install plugin

  options:

    -C, --chdir [path]      change the working directory
    -c, --config [path]     path to config

"""

options = {}

extendOptions options, commonOptions

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

fetchListing = (callback) ->
  request = https.get 'https://api.npms.io/v2/search?q=keywords:wintersmith-plugin&size=200', (response) ->
    if response.statusCode isnt 200
      error = new Error "Unexpected response when searching registry, HTTP #{ response.statusCode }"
    if not /^application\/json/.test response.headers['content-type']
      error = new Error "Invalid content-type: #{ response.headers['content-type'] }"
    if error?
      response.resume()
      callback error
      return
    data = []
    response.on 'data', (chunk) -> data.push chunk
    response.on 'end', ->
      try
        parsed = JSON.parse Buffer.concat data
      catch error
        callback error
        return
      listing = parsed.results.map (result) -> result.package
      listing.sort (a, b) ->
        return 1 if a.name > b.name
        return -1 if a.name < b.name
        return 0
      callback null, listing

displayListing = (list, callback) ->
  display = list.map (plugin) ->
    name = normalizePluginName plugin.name
    description = plugin.description
    maintainers = plugin.maintainers.map((v) -> v.username).join(' ')
    homepage = plugin.links?.homepage ? plugin.links?.npm
    return {name, description, maintainers, homepage}

  pad = max(display, (item) -> item.name.length)
  maxw = process.stdout.getWindowSize()[0] - 2
  margin = ([0...pad].map -> ' ').join ''

  for plugin in display
    line = "#{ lpad(plugin.name, pad) }  #{ clip(plugin.description, maxw - pad - 2) }"
    left = maxw - line.length
    if left > plugin.maintainers.length
      line += chalk.grey lpad(plugin.maintainers, left)
    logger.info line.replace /^\s*(\S+)  /, (m) -> chalk.bold m
    if plugin.homepage? and plugin.homepage.length < maxw - pad - 2
      logger.info "#{ margin }  #{ chalk.gray plugin.homepage }"
    logger.info ''

  callback null, list

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
  action = argv._[3]

  if not action?
    console.log usage
    process.exit 0

  loadCurrentEnv = (callback) ->
    loadEnv argv, callback

  installPlugin = (res, callback) ->
    [env, list] = res

    name = argv._[4]
    plugin = null

    for p in list
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
          fs.writeFile packageFile, '{\n  "dependencies": {},\n  "private": true\n}\n', callback

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
      cmd = [fetchListing, displayListing]
    when 'install'
      cmd = [[loadCurrentEnv, fetchListing], installPlugin]

    else
      cmd = [(callback) -> callback new Error "Unknown plugin action: #{ action }"]

  waterfall cmd, (error) ->
    if error?
      logger.error error.message, error
      process.exit 1
    else
      process.exit 0


module.exports = main
module.exports.usage = usage
module.exports.options = options
