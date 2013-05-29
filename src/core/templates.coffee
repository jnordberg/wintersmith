### templates.coffee ###

async = require 'async'
fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'

{extend, readdirRecursive} = require './utils'

class TemplatePlugin
  ### A template plugin subclass have to implement a `render` instance method and a `fromFile` class method. ###

  render: (locals, callback) ->
    ### Render template using *locals* and *callback* with a ReadStream or Buffer containing the result. ###
    throw new Error 'Not implemented.'

TemplatePlugin.fromFile = (filepath, callback) ->
  ### *callback* with a instance of <TemplatePlugin> created from *filepath*. Where *filepath* is
      an object containing the full and relative (to templates directory) path to the file. ###
  throw new Error 'Not implemented.'

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
      plugin.class.fromFile filepath, (error, template) ->
        error.message = "template #{ filepath.relative }: #{ error.message }" if error?
        templates[filepath.relative] = template
        callback error
    else
      callback()

  async.waterfall [
    (callback) -> readdirRecursive env.templatesPath, callback
    resolveFilenames
    (filenames, callback) -> async.forEach filenames, loadTemplate, callback
  ], (error) -> callback error, templates

### Exports ###

module.exports = {TemplatePlugin, loadTemplates}
