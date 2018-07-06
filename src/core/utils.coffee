### utils.coffee ###

util = require 'util'
fs = require 'fs'
path = require 'path'
async = require 'async'

fileExists = fs.exists or path.exists
fileExistsSync = fs.existsSync or path.existsSync

extend = (obj, mixin) ->
  for name, method of mixin
    obj[name] = method
  return

stripExtension = (filename) ->
  ### Remove the file-extension from *filename* ###
  filename.replace /(.+)\.[^.]+$/, '$1'

readJSON = (filename, callback) ->
  ### Read and try to parse *filename* as JSON, *callback* with parsed object or error on fault. ###
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

readJSONSync = (filename) ->
  ### Synchronously read and try to parse *filename* as json. ###
  buffer = fs.readFileSync filename
  return JSON.parse buffer.toString()

readdirRecursive = (directory, callback) ->
  ### Returns an array representing *directory*, including subdirectories. ###
  result = []
  walk = (dir, callback) ->
    async.waterfall [
      async.apply fs.readdir, path.join(directory, dir)
      (filenames, callback) ->
        async.forEach filenames, (filename, callback) ->
          relname = path.join dir, filename
          async.waterfall [
            async.apply fs.stat, path.join(directory, relname)
            (stat, callback) ->
              if stat.isDirectory()
                walk relname, callback
              else
                result.push relname
                callback()
          ], callback
        , callback
    ], callback
  walk '', (error) -> callback error, result

pump = (source, destination, callback) ->
  ### Pipe *source* stream to *destination* stream calling *callback* when done ###
  source.pipe destination
  source.on 'error', (error) ->
    callback? error
    callback = null
  destination.on 'finish', ->
    callback?()
    callback = null

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

### Exports ###

module.exports = {fileExists, fileExistsSync, extend, stripExtension,
                  readJSON, readJSONSync, readdirRecursive, pump, rfc822}
