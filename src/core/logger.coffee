### logger.coffee ###

colors = require 'colors'
winston = require 'winston'
util = require 'util'

class cli extends winston.Transport
  ### Winston transport that logs info to stdout and errors stderr  ###

  name: 'cli'

  constructor: (options) ->
    super(options)
    @quiet = options.quiet or false

  log: (level, msg, meta, callback) ->
    if level == 'error'
      process.stderr.write "\n  error".red + " #{ msg }\n"
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
        msg = "#{ level[c] } #{ msg }"
      if Object.keys(meta).length > 0
        msg += util.format ' %j', meta
      process.stdout.write "  #{ msg }\n"

    @emit 'logged'
    callback null, true

transports = [
  new cli {level: 'info'}
]

logger = new winston.Logger
  exitOnError: true
  transports: transports

module.exports = {logger, transports}
