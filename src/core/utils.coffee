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

stripExtension = (filename) ->
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

module.exports = {fileExists, fileExistsSync, extend, stripExtension, readJSON, readJSONSync}
