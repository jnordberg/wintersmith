async = require 'async'
jade = require 'jade'
fs = require 'fs'
path = require 'path'

{TemplatePlugin} = require './../templates'

class JadeTemplate extends TemplatePlugin

  constructor: (@fn) ->

  render: (locals, callback) ->
    try
      callback null, new Buffer @fn(locals)
    catch error
      callback error

JadeTemplate.fromFile = (filename, base, callback) ->
  fullpath = path.join base, filename
  async.waterfall [
    (callback) ->
      fs.readFile fullpath, callback
    (buffer, callback) =>
      try
        rv = jade.compile buffer.toString(),
          filename: fullpath
          pretty: true
        callback null, new this rv
      catch error
        callback error
  ], callback

module.exports = JadeTemplate

