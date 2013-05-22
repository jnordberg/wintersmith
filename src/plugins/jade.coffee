async = require 'async'
fs = require 'fs'
jade = require 'jade'
path = require 'path'

module.exports = (env, callback) ->

  class JadeTemplate extends env.TemplatePlugin

    constructor: (@fn) ->

    render: (locals, callback) ->
      try
        callback null, new Buffer @fn(locals)
      catch error
        callback error

  JadeTemplate.fromFile = (filepath, callback) ->
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

  env.registerTemplatePlugin '**/*.jade', JadeTemplate
  callback()
