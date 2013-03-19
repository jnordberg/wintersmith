async = require 'async'
jade = require 'jade'
fs = require 'fs'
path = require 'path'

{TemplatePlugin} = require './../core/templates'

class JadeTemplate extends TemplatePlugin

  constructor: (@fn) ->

  render: (locals, callback) ->
    try
      callback null, new Buffer @fn(locals)
    catch error
      callback error

JadeTemplate.fromFile = (env, filepath, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile filepath.full, callback
    (buffer, callback) =>
      conf = env.config.jade or {}
      conf.filename = filepath.full
      try
        rv = jade.compile buffer.toString(), conf
        callback null, new this rv
      catch error
        callback error
  ], callback

module.exports = JadeTemplate
