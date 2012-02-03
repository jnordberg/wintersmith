
path = require 'path'
async = require 'async'
{logger, readJSON} = require '../common'

defaults =
  output:
    alias: 'o'
    default: './build'
  config:
    alias: 'c'
    default: './config.json'
  articles:
    alias: 'a'
    default: './articles'
  templates:
    alias: 't'
    default: './templates'
  static:
    alias: 's'
    default: './static'
  locals:
    alias: 'T'
    default: {}
  rebuild:
    alias: 'r'
    default: false
  clean:
    alias: 'X'
    default: false
  chdir:
    alias: 'C'
    default: null

exports.commonOptions = [
  "-C, --chdir [path]            change the working directory"
  "  -c, --config [path]           path to config (defaults to #{ defaults.config.default })"
  "  -a, --articles [path]         article location (defaults to #{ defaults.articles.default })"
  "  -s, --static [path]           static resource location (defaults to #{ defaults.static.default })"
  "  -t, --templates [path]        template location (defaults to #{ defaults.templates.default })"
  "  -T, --template-data [path]    optional path to json file containing template context data"
]

exports.getOptions = (argv={}, callback) ->
  ### resolves options with the hierarchy: argv > configfile > defaults
      returns a options object ###

  # normalize argv
  for key, item of defaults
    if argv[item.alias]?
      argv[key] = argv[item.alias]

  workDir = path.resolve (argv.chdir or process.cwd())
  logger.verbose "resolving options - work directory: #{ workDir }"

  if argv.templateData?
    argv.locals = argv.templateData
    delete argv.templateData

  async.waterfall [
    (callback) ->
      # load config if present
      configPath = path.join workDir, (argv.config or defaults.config.default)
      path.exists configPath, (exists) ->
        if exists
          logger.verbose "loading config file: #{ configPath }"
          readJSON configPath, callback
        else
          logger.verbose "no config file found"
          callback null, {}
    (options, callback) ->
      logger.verbose 'options:', options
      for key of defaults
        # assing defaults to missing conf options
        options[key] ?= defaults[key].default
        # ovveride conf and default options with any command line options
        if argv[key]?
          options[key] = argv[key]
        # expand paths
        if ['output', 'config', 'articles', 'templates', 'static'].indexOf(key) != -1
          options[key] = path.join workDir, options[key]
      callback null, options
    (options, callback) ->
      # load locals json if neccessary
      if typeof options.locals == 'string'
        filename = path.join workDir, options.locals
        logger.verbose "loading locals from: #{ filename }"
        readJSON filename, (error, result) ->
          if error
            callback error
          else
            options.locals = result
            callback null, options
      else
        callback null, options
    (options, callback) ->
      logger.verbose 'resolved options:', options
      logger.verbose 'checking that all paths are valid'
      paths = ['output', 'articles', 'templates', 'static']
      async.forEach paths, (filepath, callback) ->
        path.exists options[filepath], (exists) ->
          if exists
            callback()
          else
            callback new Error "#{ filepath } path invalid (#{ options[filepath] })"
      , (error) ->
        callback error, options
  ], callback
