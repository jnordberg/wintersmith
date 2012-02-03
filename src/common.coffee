
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

copyFile = (source, destination, overwrite, callback) ->
  if !callback?
    callback = overwrite
    overwrite = false

  path.exists destination, (exists) ->
    if exists and !overwrite
      callback new Error "File #{ destination } already exists."
    else
      fs.stat source, (error) ->
        if error
          callback error
        else
          read = fs.createReadStream source
          write = fs.createWriteStream destination
          util.pump read, write, callback

exports.copyFile = copyFile

class cli extends winston.Transport

  name: 'cli'

  constructor: (options) ->
    super(options)
    @quiet = options.quiet or false

  log: (level, msg, meta, callback) ->
    if level == 'error'
      process.stderr.write "\n  error".red + " #{ msg }\n"
      if @level == 'verbose' && meta?.stack
        stack = meta.stack.substr meta.stack.indexOf('\n') + 1
        process.stderr.write stack + "\n\n"
      else
        process.stderr.write "\n"
    else if !@quiet
      switch level
        when 'verbose'
          msg = msg.yellow
      if meta
        msg += util.format ' %j', meta
      if level != 'help' then msg = '  ' + msg # flatiron pads help messages :/
      process.stdout.write msg + '\n'

    @emit 'logged'
    callback null, true

transports = exports.transports = [
  new cli {level: 'info'}
]

exports.logger = new winston.Logger
  exitOnError: true
  transports: transports

exports.readJSON = (filename, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      try
        rv = JSON.parse buffer.toString()
        callback null, rv
      catch error
        callback error
  ], callback
