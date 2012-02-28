
async = require 'async'
jade = require 'jade'
fs = require 'fs'

{TemplatePlugin} = require './../templates'

class JadeTemplate extends TemplatePlugin

  constructor: (@fn) ->

  render: (locals, callback) ->
    try
      callback null, new Buffer @fn(locals)
    catch error
      callback error

JadeTemplate.fromFile = (filename, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      try
        rv = jade.compile buffer.toString(),
          filename: filename
        callback null, new JadeTemplate rv
      catch error
        callback error
  ], callback

module.exports = JadeTemplate

