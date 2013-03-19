### logger.coffee ###

colors = require 'colors'
winston = require 'winston'

class cli extends winston.Transport

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
      switch level
        when 'verbose'
          msg = msg.yellow
      if meta
        msg += util.format ' %j', meta
      process.stdout.write "  #{ msg }\n"

    @emit 'logged'
    callback null, true

transports = exports.transports = [
  new cli {level: 'info'}
]

exports.logger = new winston.Logger
  exitOnError: true
  transports: transports
