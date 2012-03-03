
path = require 'path'
async = require 'async'
fs = require 'fs'
{compile} = require 'coffee-script'
{ContentPlugin} = require './../content'
{stripExtension} = require './../common'

class CoffeeScriptPlugin extends ContentPlugin
  ### plugin that compiles coffee files to javascript ###

  constructor: (@_filename, @_source) ->

  getFilename: ->
    stripExtension(@_filename) + '.js'

  render: (locals, contents, templates, callback) ->
    try
      callback null, new Buffer compile @_source
    catch error
      callback error

CoffeeScriptPlugin.fromFile = (filename, base, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile path.join(base, filename), callback
    (buffer, callback) ->
      callback null, new CoffeeScriptPlugin filename, buffer.toString()
  ], callback

module.exports = CoffeeScriptPlugin
