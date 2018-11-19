async = require 'async'
fs = require 'fs'
pug = require 'pug'
path = require 'path'

module.exports = (env, callback) ->

  class PugTemplate extends env.TemplatePlugin

    constructor: (@fn) ->

    render: (locals, callback) ->
      try
        callback null, Buffer.from @fn(locals)
      catch error
        callback error

  PugTemplate.fromFile = (filepath, callback) ->
    async.waterfall [
      (callback) ->
        fs.readFile filepath.full, callback
      (buffer, callback) =>
        conf = env.config.pug or {}
        conf.filename = filepath.full
        try
          rv = pug.compile buffer.toString(), conf
          callback null, new this rv
        catch error
          callback error
    ], callback

  env.registerTemplatePlugin '**/*.*(pug|jade)', PugTemplate
  callback()
