async = require 'async'
chalk = require 'chalk'
fs = require 'fs'
path = require 'path'
rimraf = require 'rimraf'

{fileExistsSync} = require './../core/utils'
{loadEnv, commonOptions, commonUsage, extendOptions} = require './common'
{logger} = require './../core/logger'

usage = """

  usage: wintersmith build [options]

  options:

    -o, --output [path]           directory to write build-output (defaults to ./build)
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
  alias:
    output: 'o'
    clean: 'X'
  boolean: ['clean']
  string: ['output']

extendOptions options, commonOptions

build = (argv) ->
  start = new Date()
  logger.info 'building site'

  prepareOutputDir = (env, callback) ->
    # create clean and create output directory if needed
    outputDir = env.resolvePath env.config.output
    exists = fileExistsSync outputDir
    if exists
      if argv.clean
        logger.verbose "cleaning - running rimraf on #{ outputDir }"
        async.series [
          (callback) -> rimraf outputDir, callback
          (callback) -> fs.mkdir outputDir, callback
        ], callback
      else
        callback()
    else
      logger.verbose "creating output directory #{ outputDir }"
      fs.mkdir outputDir, callback

  async.waterfall [
    (callback) -> loadEnv argv, callback
    (env, callback) ->
      prepareOutputDir env, (error) -> callback error, env
    (env, callback) ->
      env.build callback
  ], (error) ->
    if error
      logger.error error.message, error
      process.exit 1
    else
      stop = new Date()
      delta = stop - start
      logger.info "done in #{ chalk.bold delta } ms\n"
      process.exit()

module.exports = build
module.exports.usage = usage
module.exports.options = options
