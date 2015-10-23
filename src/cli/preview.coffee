async = require 'async'
util = require 'util'

{Config} = require './../core/config'
{logger} = require './../core/logger'

{loadEnv, commonUsage, commonOptions, extendOptions} = require './common'

usage = """

  usage: wintersmith preview [options]

  options:

    -p, --port [port]             port to run server on (defaults to #{ Config.defaults.port })
    -H, --hostname [host]         host to bind server onto (defaults to INADDR_ANY)
    #{ commonUsage }

    all options can also be set in the config file

  examples:

    preview using a config file (assuming config.json is found in working directory):
    $ wintersmith preview

"""

options =
  string: ['port', 'hostname']
  alias:
    port: 'p'
    hostname: 'H'

extendOptions options, commonOptions

preview = (argv) ->
  logger.info 'starting preview server'

  async.waterfall [
    (callback) ->
      # create environment
      loadEnv argv, callback
    (env, callback) ->
      # start preview server
      env.preview callback
  ], (error) ->
    if error
      logger.error error.message, error
      process.exit 1

module.exports = preview
module.exports.usage = usage
module.exports.options = options
