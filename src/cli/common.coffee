path = require 'path'
async = require 'async'

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
