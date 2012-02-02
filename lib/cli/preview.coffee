
async = require 'async'
{app} = require 'flatiron'
rimraf = require 'rimraf'
fs = require 'fs'
{logger} = require '../common' # lib common
{getOptions, commonOptions} = require './common' # cli common


usage = """

  usage: wintersmith preview [options]

  options:

    -p, --port [port]             port to run server on (defaults to 8080)
    #{ commonOptions.join('\n') }

    all options can also be set in the config file

  examples:

    preview using a config file (assuming config.json is found in working directory):
    $ wintersmith preview

"""

preview = ->
  server = require '../server'
  logger.info 'starting preview server'

  async.waterfall [
    # load options
    async.apply getOptions, app.argv
    (options, callback) ->
      options.port = (app.argv.p or app.argv.port) or 8080
      server.run options, callback
  ], (error) ->
    if error
      logger.error error.message, error

module.exports = preview
module.exports.usage = usage
module.exports.name = 'preview'
