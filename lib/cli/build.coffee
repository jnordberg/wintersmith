
async = require 'async'
{app} = require 'flatiron'
rimraf = require 'rimraf'
fs = require 'fs'
colors = require 'colors'
{logger} = require '../common' # lib common
{getOptions, commonOptions} = require './common' # cli common
wintersmith = require '../'

usage = """

  usage: wintersmith build [options]

  options:

    -o, --output [path]           directory to write build-output (defaults to ./output)
    -r, --rebuild                 force rebuild of all articles
    -X, --clean                   clean before building (warning: will recursively delete everything at output path)
    #{ commonOptions.join('\n') }

    all options can also be set in the config file

  examples:

    build using a config file (assuming config.json is found in working directory):
    $ wintersmith build

    build using command line options:
    $ wintersmith build -o /var/www/public/ -T extra_data.json -C ~/my-blog

    or using both (command-line options will override config options):
    $ wintersmith build --config another_config.json --rebuild
"""

build = ->
  start = new Date()
  logger.info 'building site'

  async.waterfall [
    # load options
    async.apply getOptions, app.argv
    (options, callback) ->
      async.waterfall [
        (callback) ->
          if options.clean
            logger.verbose "cleaning - running rimraf on #{ options.output }"
            async.waterfall [
              async.apply rimraf, options.output
              async.apply fs.mkdir, options.output
            ], callback
          else
            callback()
        (callback) ->
          # start building
          wintersmith options, callback
      ], callback
  ], (error) ->
    if error
      logger.error error.message, error
    else
      stop = new Date()
      delta = stop - start
      logger.info "done in #{ delta.toString().bold } ms\n"

module.exports = build
module.exports.usage = usage
module.exports.name = 'build'

