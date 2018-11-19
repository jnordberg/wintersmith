### logger.coffee ###

chalk = require 'chalk'
winston = require 'winston'
util = require 'util'

class cli extends winston.Transport
  ### Winston transport that logs info to stdout and errors stderr  ###

  name: 'cli'

  constructor: (options) ->
    super(options)
    @quiet = options.quiet or false

  log: (info, callback) ->
    {level, message} = info
    meta = info.meta ? {}
    if level == 'error'
      process.stderr.write "\n  #{ chalk.red 'error' } #{ message }\n"
      if @level == 'verbose' && meta?
        if meta.stack?
          stack = meta.stack.substr meta.stack.indexOf('\n') + 1
          process.stderr.write stack + "\n\n"
        for key, value of meta
          if key in ['message', 'stack']
            continue
          pval = util.inspect(value, false, 2, true).replace(/\n/g, '\n    ')
          process.stderr.write "    #{ key }: #{ pval }\n"
      else
        process.stderr.write "\n"
    else if !@quiet
      if level isnt 'info'
        c = if level is 'warn' then 'yellow' else 'grey'
        message = "#{ chalk[c] level } #{ message }"
      if Object.keys(meta).length > 0
        message += util.format ' %j', meta
      process.stdout.write "  #{ message }\n"

    @emit 'logged'
    callback null, true

transports = [
  new cli {level: 'info'}
]

logger = winston.createLogger
  exitOnError: true
  transports: transports

module.exports = {logger, transports}
