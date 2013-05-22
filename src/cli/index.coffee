
path = require 'path'
optimist = require 'optimist'
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

globalOptions =
  verbose:
    alias: 'v'
  quiet:
    alias: 'q'
  version:
    alias: 'V'
  help:
    alias: 'h'

main = (callback) ->

  argv = optimist.options(globalOptions).argv
  if argv._[0]?
    try
      cmd = require "./#{ argv._[0] }"
    catch error
      console.log "'#{ argv._[0] }' - no such command"

  if argv.version
    readJSON path.join(__dirname, '../../package.json'), (error, result) ->
      if error
        logger.error error.message, error
      else
        console.log result.version
        process.exit 0
    return

  if argv.help or !cmd
    console.log if cmd then cmd.usage else usage
    process.exit 0

  if argv.verbose
    logger.transports.cli.level = 'verbose'

  if argv.quiet
    logger.transports.cli.quiet = true

  if cmd
    cmd optimist.options(globalOptions).options(cmd.options).argv, (options) ->
      callback options if callback

module.exports.main = main
