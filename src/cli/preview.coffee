async = require 'async'
util = require 'util'

{extend} = require './../core/utils'
{Config} = require './../core/config'
{logger} = require './../core/logger'

{loadEnv, commonUsage, commonOptions} = require './common'

usage = """

  usage: wintersmith preview [options]

  options:

    -p, --port [port]             port to run server on (defaults to 8080)
    -d, --domain [domain]         host to run server on (defaults to localhost)
    #{ commonUsage }

    all options can also be set in the config file

  examples:

    preview using a config file (assuming config.json is found in working directory):
    $ wintersmith preview

"""

options =
  port:
    alias: 'p'
  domain:
    alias: 'd'

extend options, commonOptions

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

module.exports = preview
module.exports.usage = usage
module.exports.options = options
