async    = require 'async'
renderer = require './renderer'
{extend, stripExtension, rfc822, logger, readJSON}      = require './common'
{ContentTree, ContentPlugin, registerContentPlugin}     = require './content'
{TemplatePlugin, loadTemplates, registerTemplatePlugin} = require './templates'

defaultPlugins =
  Page: require('./plugins/markdown-page')
  MarkdownPage: require('./plugins/markdown-page')
  JsonPage: require('./plugins/json-page')
  JadeTemplate: require('./plugins/jade-template')

# register default plugins
registerContentPlugin 'pages', '**/*.*(markdown|md)', defaultPlugins.MarkdownPage
registerContentPlugin 'pages', '**/*.json', defaultPlugins.JsonPage
registerTemplatePlugin '**/*.jade', defaultPlugins.JadeTemplate

loadContents = (location, callback) ->
  ### traverse *location* and return a tree of contents ###
  logger.verbose "loading contents in #{ location }"
  ContentTree.fromDirectory location, callback

module.exports = (options, callback) ->
  ### build all contents and templates
      *options*:
        contents: path to contents
        templates: path to templates
        output: path to output directory
        locals: optional extra data to send to templates ###

  logger.verbose 'running with options:', {options: options}

  # load templates & contents then render
  async.waterfall [
    (callback) ->
      async.parallel
        contents: async.apply loadContents, options.contents
        templates: async.apply loadTemplates, options.templates
      , callback
    (result, callback) ->
      renderer result.contents, result.templates, options.output, options.locals, callback
  ], callback

# expose api
module.exports.ContentTree    = ContentTree
module.exports.ContentPlugin  = ContentPlugin
module.exports.TemplatePlugin = TemplatePlugin
module.exports.renderer       = renderer
module.exports.loadTemplates  = loadTemplates
module.exports.loadContents   = loadContents
module.exports.defaultPlugins = defaultPlugins
module.exports.registerContentPlugin  = registerContentPlugin
module.exports.registerTemplatePlugin = registerTemplatePlugin
# expose common api
module.exports.extend         = extend
module.exports.stripExtension = stripExtension
module.exports.rfc822         = rfc822
module.exports.logger         = logger
module.exports.readJSON       = readJSON
# expose our plugins
module.exports.Page         = require './plugins/markdown-page'
module.exports.MarkdownPage = require './plugins/markdown-page'
module.exports.JsonPage     = require './plugins/json-page'
module.exports.JadeTemplate = require './plugins/jade-template'
# expose some deps, so plugins dont' need their owns
module.exports.async = async
module.exports._ = require 'underscore'
