
flatiron = require 'flatiron'
path = require 'path'
{logger, transports, readJSON} = require './../common'

usage = """

  usage: wintersmith [options] [command]

  commands:

    #{ 'build'.bold } [options] - build a site
    #{ 'preview'.bold } [options] - run local webserver
    #{ 'new'.bold } <location> - create a new site

    also see [command] --help

  global options:

    -v, --verbose   show debug information
    -q, --quiet     only output critical errors
    -V, --version   output version and exit
    -h, --help      show help
"""

main = ->
  process.on 'uncaughtException', (error) ->
    # flatiron hooks into this somewhere and outputs json.. ¿que?
    logger.error error.message, error
    process.exit 0

  app = flatiron.app

  app.use flatiron.plugins.cli,
    dir: __dirname
    argv:
      verbose: alias: 'v'
      quiet: alias: 'q'
      version: alias: 'V'
      help: alias: 'h'
    usage: usage

  if app.argv.version
    readJSON path.join(__dirname, '../../package.json'), (error, result) ->
      if error
        logger.error error.message, error
      else
        console.log result.version
        process.exit 0
    return # prevent app.start

  if app.argv.verbose
    logger.transports.cli.level = 'verbose'

  if app.argv.quiet
    logger.transports.cli.quiet = true

  app.start
    log: {transports: transports}

module.exports.main = main
