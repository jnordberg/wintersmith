chalk = require 'chalk'
optimist = require 'optimist'
path = require 'path'

{logger} = require './../core/logger'

usage = """

  usage: wintersmith [options] [command]

  commands:

    #{ chalk.bold 'build' } [options] - build a site
    #{ chalk.bold 'preview' } [options] - run local webserver
    #{ chalk.bold 'new' } <location> - create a new site
    #{ chalk.bold 'plugin' } - manage plugins

    also see [command] --help

  global options:

    -v, --verbose   show debug information
    -q, --quiet     only output critical errors
    -V, --version   output version and exit
    -h, --help      show help

"""

globalOptions =
  verbose:
    alias: 'v'
  quiet:
    alias: 'q'
  version:
    alias: 'V'
  help:
    alias: 'h'

main = ->

  argv = optimist.options(globalOptions).argv
  if argv._[0]?
    try
      cmd = require "./#{ argv._[0] }"
    catch error
      if error.code is 'MODULE_NOT_FOUND'
        console.log "'#{ argv._[0] }' - no such command"
        process.exit 1
      else
        throw error

  if argv.version
    console.log require './version'
    process.exit 0

  if argv.help or !cmd
    console.log if cmd then cmd.usage else usage
    process.exit 0

  if argv.verbose
    if '-vv' in process.argv
      logger.transports.cli.level = 'silly'
    else
      logger.transports.cli.level = 'verbose'

  if argv.quiet
    logger.transports.cli.quiet = true

  if cmd
    cmd optimist.options(globalOptions).options(cmd.options).argv

module.exports.main = main
