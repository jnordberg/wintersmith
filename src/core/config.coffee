### config.coffee ###

fs = require 'fs'
path = require 'path'
async = require 'async'

{readJSON, readJSONSync, fileExists, fileExistsSync} = require './utils'

class Config
  ### The configuration object ###

  @defaults =
    # path to the directory containing content's to be scanned
    contents: './contents'
    # list of glob patterns to ignore
    ignore: []
    # context variables, passed to views/templates
    locals: {}
    # list of modules/files to load as plugins
    plugins: []
    # modules/files loaded and added to locals, name: module
    require: {}
    # path to the directory containing the templates
    templates: './templates'
    # directory to load custom views from
    views: null
    # built product goes here
    output: './build'
    # base url that site lives on, e.g. '/blog/'
    baseUrl: '/'
    # preview server settings
    hostname: null # INADDR_ANY
    port: 8080
    # options prefixed with _ are undocumented and should generally not be modified
    _fileLimit: 40 # max files to keep open at once
    _restartOnConfChange: true # restart preview server on config change

  constructor: (options={}) ->
    for option, value of options
      this[option] = value
    for option, defaultValue of @constructor.defaults
      this[option] ?= defaultValue

Config.fromFile = (path, callback) ->
  ### Read config from *path* as JSON and *callback* with a Config instance. ###
  async.waterfall [
    (callback) ->
      fileExists path, (exists) ->
        if exists
          readJSON path, callback
        else
          callback new Error "Config file at '#{ path }' does not exist."
    (options, callback) ->
      config = new Config options
      config.__filename = path
      callback null, config
  ], callback

Config.fromFileSync = (path) ->
  ### Read config from *path* as JSON return a Config instance. ###
  if not fileExistsSync path
    throw new Error "Config file at '#{ path }' does not exist."
  config = new Config readJSONSync path
  config.__filename = path
  return config

### Exports ###

module.exports = {Config}
