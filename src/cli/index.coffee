chalk = require 'chalk'
parseArgv = require 'minimist'
path = require 'path'

{logger} = require './../core/logger'
{extendOptions} = require './common'


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
  boolean: ['verbose', 'quiet', 'version', 'help']
  alias:
    verbose: 'v'
    quiet: 'q'
    version: 'V'
    help: 'h'

main = (argv) ->

  opts = parseArgv argv, globalOptions
  cmd = opts._[2]

  if cmd?
    try
      cmd = require "./#{ cmd }"
    catch error
      if error.code is 'MODULE_NOT_FOUND'
        console.log "'#{ cmd }' - no such command"
        process.exit 1
      else
        throw error

  if opts.version
    console.log require './version'
    process.exit 0

  if opts.help or !cmd
    console.log if cmd then cmd.usage else usage
    process.exit 0

  if opts.verbose
    if '-vv' in argv
      logger.transports[0].level = 'silly'
    else
      logger.transports[0].level = 'verbose'

  if opts.quiet
    logger.transports[0].quiet = true

  if cmd
    extendOptions cmd.options, globalOptions
    opts = parseArgv argv, cmd.options
    cmd opts

module.exports.main = main
