### environment.coffee ###

path = require 'path'
async = require 'async'

{Config} = require './config'
{ContentTree} = require './content'
{readJSON} = require './utils'
{render} = require './renderer'
{loadTemplates} = require './templates'
{buildGraph} = require './graph'
{logger} = require './logger'

class Environment
  ### The Wintersmith environment. ###

  constructor: (@config, @workDir, @logger) ->
    # todo load default views templates and plugs
    @views = {}
    @generators = []
    @templatePlugins = []
    @contentPlugins = []

    @contentsPath = @resolvePath @config.contents
    @templatesPath = @resolvePath @config.templates

    # TODO: better default plugin handling
    @registerTemplatePlugin '**/*.jade', require('../plugins/jade-template')
    @registerContentPlugin 'pages', '**/*.*(markdown|mkd|md)', require('../plugins/markdown-page')
    @registerContentPlugin 'pages', '**/*.json', require('../plugins/json-page')

  resolvePath: (pathname) ->
    ### Resolve *pathname* in working directory, returns an absolute path. ###
    path.resolve @workDir, pathname or ''

  resolveContentsPath: (pathname) ->
    ### Resolve *pathname* in contents directory, returns an absolute path. ###
    path.resolve @contentsPath, pathname or ''

  relativePath: (pathname) ->
    ### Resolve path relative to working directory. ###
    path.relative @workDir, pathname

  relativeContentsPath: (pathname) ->
    ### Resolve path relative to contents directory. ###
    path.relative @contentsPath, pathname

  registerContentPlugin: (group, pattern, plugin) ->
    ### Add a content *plugin* to the environment. Files in the contents directory
        matching the glob *pattern* will be instanciated using the plugin's `fromFile`
        factory method. The *group* argument is used to group the loaded instances under
        each directory. I.e. plugin instances with the group 'textFiles' can be found
        in `contents.somedir._.textFiles`. ###
    @logger.verbose "registering template plugin that handles: #{ pattern }"
    @contentPlugins.push
      group: group
      pattern: pattern
      class: plugin

  registerTemplatePlugin: (pattern, plugin) ->
    ### Add a template *plugin* to the environment. All files in the template directory
        matching the glob *pattern* will be passed to the plugin's `fromFile` classmethod. ###
    @templatePlugins.push
      pattern: pattern
      class: plugin

  registerGenerator: (generator) ->
    ### Add a generator to the environment. The generator function is called with the env and the
        current content tree. It should return a object with nested ContentPlugin instances.
        These will be merged into the final content tree. Generators can also return filenames
        and a buffer/stream like: {filename: 'asd', stream: 'asd'}. See generator.coffee for more info ###
    @generators.push generator

  registerView: (name, view) ->
    ### Add a view to the environment. ###
    @views[name] = view

  getContents: (callback) ->
    ### Generate the content tree. Calls *callback* with the tree or error
        if something went wrong. ###
    # TODO: run generators
    ContentTree.fromDirectory this, @resolveContentsPath(), callback

  getTemplates: (callback) ->
    ### Load templates ###
    loadTemplates this, callback

  getLocals: (callback) ->
    ### Resolve locals. ###

    resolveModule = (moduleName) =>
      if moduleName[0] is '.'
        @resolvePath moduleName
      else
        moduleName

    resolveLocals = (callback) =>
      ### Load locals json if neccessary. ###
      if typeof @config.locals == 'string'
        filename = @resolvePath @config.locals
        @logger.verbose "loading locals from: #{ filename }"
        readJSON filename, callback
      else
        callback null, @config.locals

    addModules = (locals, callback) =>
      ### Loads and adds modules specefied with the require option to the locals context. ###
      # TODO: use module map instead, {name: id, ..}
      async.forEach @config.require, (moduleName, callback) ->
        moduleAlias = moduleName.split('/')[-1..]
        logger.verbose "loading module #{ moduleName } available in locals as: #{ moduleAlias }"
        if locals[moduleAlias]?
          logger.warning "module '#{ moduleName }' overwrites previous local with the same key"
        try
          locals[moduleAlias] = require moduleName
          callback()
        catch error
          callback error
      , (error) -> callback error, locals

    async.waterfall [
      resolveLocals
      addModules
    ], callback

  load: (callback) ->
    ### Convenience method to load contents, templates and locals. ###
    async.parallel
      contents: (callback) => @getContents callback
      templates: (callback) => @getTemplates callback
      locals: (callback) => @getLocals callback
    , callback

  preview: (options, callback) ->
    ### Start the preview server. Calls *callback* when server is up and
        running or error if something went wrong. ###

  build: (outputDir, callback) ->
    ### Build the content tree and render it to *outputDir*. ###
    if arguments.length < 2
      # *outputDir* is optional and if omitted config.output is used
      callback = outputDir or ->
      outputDir = @resolvePath @config.output
    async.waterfall [
      (callback) =>
        @load callback
      (result, callback) =>
        {contents, templates, locals} = result
        render this, outputDir, contents, templates, locals, callback
    ], callback

  getGraph: (callback) ->
    ### Build a dependency graph ###
    async.waterfall [
      (callback) =>
        @load callback
      (result, callback) =>
        {contents, templates, locals} = result
        buildGraph this, contents, templates, locals, callback
    ], callback

Environment.create = (config, workDir) ->
  ### Set up a new environment using the default logger, *config* can be
      either a config object, a Config instance or a path to a config file. ###

  if typeof config is 'string'
    # working directory will be where the config file resides
    workDir ?= path.dirname config
    config = Config.fromFileSync config
  else
    workDir ?= process.cwd()
    if not config instanceof Config
      config = new Config config

  return new Environment config, workDir, logger

### Exports ###

module.exports = {Environment}
