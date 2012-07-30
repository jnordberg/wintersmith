async = require 'async'
path = require 'path'
glob = require 'glob'

{logger, extend} = require './common'

templatePlugins = []
registerTemplatePlugin = (pattern, plugin) ->
  ### add a template *plugin*, all files in the template directory matching the
      glob *pattern* will be passed to the plugins fromFile function. ###
  templatePlugins.push
    pattern: pattern
    class: plugin

class TemplatePlugin

  render: (locals, callback) ->
    ### render template using *locals* and *callback* with a ReadStream or
        Buffer containing the rendered contents ###
    throw new Error 'not implemented'

TemplatePlugin.fromFile = (filename, base, callback) ->
  ### *callback* with a instance of <TemplatePlugin> created from *filename* ###
  throw new Error 'not implemented'

loadTemplates = (location, callback) ->
  ### load and compile all templates found in *location*
      returns map of templates {name: <TemplatePlugin> instance} ###
  rv = {}
  # glob options
  opts =
    cwd: location
    nosort: true

  loadPluginTemplates = (plugin, callback) ->
    ### scans *location* and loads any templates for *plugin* if its glob pattern matches ###
    async.waterfall [
      async.apply glob, plugin.pattern, opts
      (files, callback) ->
        templates = {}
        async.forEach files, (filename, callback) ->
          logger.verbose "loading template: #{ filename }"
          plugin.class.fromFile filename, location, (error, template) ->
            templates[filename] = template
            callback error
        , (error) ->
          callback error, templates
    ], callback

  async.waterfall [
    async.apply async.map, templatePlugins, loadPluginTemplates
    (result, callback) ->
      templates = {}
      extend templates, t for t in result
      callback null, templates
  ], callback

module.exports.loadTemplates = loadTemplates
module.exports.TemplatePlugin = TemplatePlugin
module.exports.registerTemplatePlugin = registerTemplatePlugin
