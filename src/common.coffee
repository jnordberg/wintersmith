winston = require 'winston'
colors = require 'colors'
util = require 'util'
fs = require 'fs'
path = require 'path'
async = require 'async'

extend = (obj, mixin) ->
  for name, method of mixin
    obj[name] = method

exports.extend = extend

stripExtension = (filename) ->
  filename.replace /(.+)\.[^.]+$/, '$1'

exports.stripExtension = stripExtension

rfc822 = (date) ->
  ### return a rfc822 representation of a javascript Date object
      http://www.w3.org/Protocols/rfc822/#z28 ###
  pad = (i) -> if i < 10 then '0' + i else i
  tzoffset = (offset) ->
    hours = Math.floor offset / 60
    minutes = Math.abs offset % 60
    direction = if hours > 0 then '-' else '+'
    return direction + pad(Math.abs(hours)) +  pad(minutes)
  months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',' Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  time = [pad(date.getHours()), pad(date.getMinutes()), pad(date.getSeconds())].join ':'

  return [
    days[date.getDay()] + ','
    pad(date.getDate())
    months[date.getMonth()]
    date.getFullYear()
    time
    tzoffset(date.getTimezoneOffset())
  ].join ' '

exports.rfc822 = rfc822

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

exports.readJSON = (filename, callback) ->
  ### read and try to parse *filename* as json ###
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      try
        rv = JSON.parse buffer.toString()
        callback null, rv
      catch error
        error.filename = filename
        error.message = "parsing #{ path.basename(filename) }: #{ error.message }"
        callback error
  ], callback
