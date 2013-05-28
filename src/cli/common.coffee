path = require 'path'
async = require 'async'
stream = require 'stream'

{Config} = require './../core/config'
{Environment} = require './../core/environment'
{logger} = require './../core/logger'
{readJSON, fileExists} = require './../core/utils'

exports.commonOptions = defaults =
  config:
    alias: 'c'
    default: './config.json'
  chdir:
    alias: 'C'
    default: null
  contents:
    alias: 'i'
  templates:
    alias: 't'
  locals:
    alias: 'L'
  require:
    alias: 'R'
  plugins:
    alias: 'P'
  ignore:
    alias: 'I'

exports.commonUsage = [
  "-C, --chdir [path]            change the working directory"
  "  -c, --config [path]           path to config (defaults to #{ defaults.config.default })"
  "  -i, --contents [path]         contents location (defaults to #{ defaults.contents.default })"
  "  -t, --templates [path]        template location (defaults to #{ defaults.templates.default })"
  "  -L, --locals [path]           optional path to json file containing template context data"
  "  -R, --require                 comma separated list of modules to add to the template context"
  "  -P, --plugins                 comma separated list of modules to load as plugins"
  "  -I, --ignore                  comma separated list of files/glob-patterns to ignore"
].join '\n'

exports.loadEnv = (argv, callback) ->
  ### creates a new wintersmith environment
      options are resolved with the hierarchy: argv > configfile > defaults ###

  workDir = path.resolve (argv.chdir or process.cwd())
  logger.verbose "creating environment - work directory: #{ workDir }"

  async.waterfall [

    (callback) ->
      # load config if present
      configPath = path.join workDir, argv.config
      fileExists configPath, (exists) ->
        if exists
          logger.info "using config file: #{ configPath }"
          Config.fromFile configPath, callback
        else
          logger.verbose "no config file found"
          callback null, new Config

    (config, callback) ->
      # ovveride config options with any command line options
      for key, value of argv
        # don't include optimist stuff and cli-specific options
        excluded = ['_', 'chdir', 'config', 'clean']
        if key[0] is '$' or key.length is 1 or key in excluded
          continue
        if key in ['ignore', 'require', 'plugins']
          # split comma separated values to arrays
          value = value.split ','
          if key is 'require'
            # handle special alias:module mapping
            reqs = {}
            for v in value
              [alias, module] = v.split ':'
              if not module?
                module = alias
                alias = module.replace(/\/$/, '').split('/')[-1..]
              reqs[alias] = module
            value = reqs
        config[key] = value
      callback null, config

    (config, callback) ->
      # create environment
      logger.verbose 'config:', config
      env = new Environment config, workDir, logger
      callback null, env

    (env, callback) ->
      # validate paths
      paths = ['contents', 'templates']
      async.forEach paths, (pathname, callback) ->
        resolved = env.resolvePath env.config[pathname]
        fileExists resolved , (exists) ->
          if exists
            callback()
          else
            callback new Error "#{ pathname } path invalid (#{ resolved })"
      , (error) ->
        callback error, env

  ], callback

if not stream.Writable?
  # 0.10 writable stream for 0.8, not proper but works for this
  class stream.Writable extends stream.Stream
    constructor: ->
      super()
      @writable = true
    write: (string, encodig='utf8') ->
      @_write string, encodig, ->

exports.NpmAdapter = class NpmAdapter extends stream.Writable
  ### Redirects output of npm to a logger ###

  constructor: (@logger) ->
    @buffer = ''
    super {decodeStrings: false}

  _write: (chunk, encoding, callback) ->
    @buffer += chunk
    @flush() if chunk.indexOf('\n') isnt -1
    callback()

  flush: ->
    lines = @buffer.split('\n')
    @buffer = ''
    for line in lines
      continue unless line.length > 0
      line = line.replace /^npm /, ''
      if line[0...4] is 'WARN'
        @logger.warn "npm: #{ line[5..] }"
      else
        @logger.verbose "npm: #{ line }"

exports.getStorageDir = ->
  ### Return users wintersmith directory, used for cache and user templates. ###
  return process.env.WINTERSMITH_PATH if process.env.WINTERSMITH_PATH?
  home = process.env.HOME or process.env.USERPROFILE
  dir = 'wintersmith'
  if process.platform isnt 'win32'
    dir = '.' + dir
  return path.resolve(home, dir)
