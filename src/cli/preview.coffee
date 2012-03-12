
async = require 'async'
util = require 'util'
{logger, extend} = require '../common' # lib common
{getOptions, commonUsage, commonOptions, loadPlugins} = require './common' # cli common

usage = """

  usage: wintersmith preview [options]

  options:

    -p, --port [port]             port to run server on (defaults to 8080)
    #{ commonUsage }

    all options can also be set in the config file

  examples:

    preview using a config file (assuming config.json is found in working directory):
    $ wintersmith preview

"""

options =
  port:
    alias: 'p'
    default: 8080

extend options, commonOptions

preview = (argv) ->
  server = require '../server'
  logger.info 'starting preview server'

  async.waterfall [
    # load options
    async.apply getOptions, argv
    (options, callback) ->
      # load plugins
      loadPlugins options.plugins, (error) ->
        callback error, options
    (options, callback) ->
      server.run options, callback
  ], (error) ->
    if error
      logger.error error.message, error

module.exports = preview
module.exports.usage = usage
module.exports.options = options
