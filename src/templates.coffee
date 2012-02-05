fs = require 'fs'
jade = require 'jade'
async = require 'async'
path = require 'path'
glob = require 'glob'

{logger} = require './common'

compileTemplate = (filename, callback) ->
  ### read template from disk and compile
      returns compiled template ###
  async.waterfall [
    (callback) ->
      fs.readFile filename, callback
    (buffer, callback) ->
      try
        rv = jade.compile buffer.toString(),
          filename: filename
        callback null, rv
      catch error
        callback error
  ], callback

loadTemplates = (location, callback) ->
  ### load and compile all templates found in *location*
      returns map of templates {name: fn} ###
  rv = {}
  # glob options
  opts =
    cwd: location
    nosort: true
  async.waterfall [
    async.apply glob, '**/*.jade', opts
    (files, callback) ->
      async.filter files, (filename, callback) ->
        # exclude templates starting with _ (useful for layout templates etc)
        callback (path.basename(filename).substr(0, 1) != '_')
      , (result) ->
        callback null, result
    (files, callback) ->
      templates = {}
      async.forEach files, (filename, callback) ->
        logger.verbose "loading template: #{ filename }"
        compileTemplate path.join(location, filename), (error, template) ->
          templates[filename] = template
          callback error
      , (error) ->
        callback error, templates
  ], callback

module.exports.compileTemplate = compileTemplate
module.exports.loadTemplates = loadTemplates
