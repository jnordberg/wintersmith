### templates.coffee ###

async = require 'async'
fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'

{extend} = require './utils'

class TemplatePlugin

  render: (locals, callback) ->
    ### Render template using *locals* and *callback* with a ReadStream or Buffer containing the result. ###
    throw new Error 'Not implemented.'

TemplatePlugin.fromFile = (env, filepath, callback) ->
  ### *callback* with a instance of <TemplatePlugin> created from *filepath*. Where *filepath* is
      an object containing the full and relative (to templates directory) path to the file. ###
  throw new Error 'Not implemented.'

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

loadTemplates = (env, callback) ->
  ### Load and any templates associated with the environment *env*. Calls *callback* with
      a map of templates as {<filename>: <TemplatePlugin instance>} ###

  templates = {}

  resolveFilenames = (filenames, callback) ->
    async.map filenames, (filename, callback) ->
      callback null,
        full: path.join env.templatesPath, filename
        relative: filename
    , callback

  loadTemplate = (filepath, callback) ->
    ### Create an template plugin instance from *filepath*. ###
    plugin = null
    for i in [env.templatePlugins.length - 1..0] by -1
      if minimatch filepath.relative, env.templatePlugins[i].pattern
        plugin = env.templatePlugins[i]
        break
    if plugin?
      plugin.class.fromFile env, filepath, (error, template) ->
        templates[filepath.relative] = template
        callback error
    else
      callback()

  async.waterfall [
    (callback) -> readdirRecursive env.templatesPath, callback
    resolveFilenames
    (filenames, callback) -> async.forEach filenames, loadTemplate, callback
  ], (error) -> callback error, templates

module.exports.loadTemplates = loadTemplates
module.exports.TemplatePlugin = TemplatePlugin
