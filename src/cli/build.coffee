
async = require 'async'
rimraf = require 'rimraf'
fs = require 'fs'
path = require 'path'
colors = require 'colors'
{logger, extend} = require '../common' # lib common
{getOptions, commonOptions, commonUsage, fileExists} = require './common' # cli common
wintersmith = require '../'

usage = """

  usage: wintersmith build [options]

  options:

    -o, --output [path]           directory to write build-output (defaults to ./output)
    -X, --clean                   clean before building (warning: will recursively delete everything at output path)
    #{ commonUsage }

    all options can also be set in the config file

  examples:

    build using a config file (assuming config.json is found in working directory):
    $ wintersmith build

    build using command line options:
    $ wintersmith build -o /var/www/public/ -T extra_data.json -C ~/my-blog

    or using both (command-line options will override config options):
    $ wintersmith build --config another_config.json --clean
"""

options =
  output:
    alias: 'o'
    default: './build'
  clean:
    alias: 'X'
    default: false

extend options, commonOptions

build = (argv) ->
  start = new Date()
  logger.info 'building site'

  async.waterfall [
    # load options
    async.apply getOptions, argv
    (options, callback) ->
      async.waterfall [
        (callback) ->
          # create output dir if not existing
          fileExists options.output, (exists) ->
            if exists
              callback()
            else
              logger.verbose "creating output directory #{ options.output }"
              fs.mkdir options.output, callback
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
module.exports.options = options
