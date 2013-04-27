### environment.coffee ###

path = require 'path'
async = require 'async'
fs = require 'fs'

utils = require './utils'

{Config} = require './config'
{ContentPlugin, ContentTree, StaticFile} = require './content'
{TemplatePlugin, loadTemplates} = require './templates'
{logger} = require './logger'
{render} = require './renderer'
{runGenerator} = require './generator'

{readJSON} = utils

class Environment
  ### The Wintersmith environment. ###

  utils: utils
  ContentTree: ContentTree
  ContentPlugin: ContentPlugin
  TemplatePlugin: TemplatePlugin

  constructor: (@config, @workDir, @logger) ->
    @views = {}
    @generators = []
    @plugins = {StaticFile}
    @templatePlugins = []
    @contentPlugins = []

    @pluginsLoaded = false

    @workDir = path.resolve @workDir
    @contentsPath = @resolvePath @config.contents
    @templatesPath = @resolvePath @config.templates

    # load default plugins
    async.forEachSeries @constructor.defaultPlugins, (plugin, callback) =>
      @logger.verbose "loading default plugin '#{ plugin }'"
      fn = require "./../plugins/#{ plugin }"
      fn.call null, this, callback
    , (error) -> throw error if error?

  resolvePath: (pathname) ->
    ### Resolve *pathname* in working directory, returns an absolute path. ###
    path.resolve @workDir, pathname or ''

  resolveContentsPath: (pathname) ->
    ### Resolve *pathname* in contents directory, returns an absolute path. ###
    path.resolve @contentsPath, pathname or ''

  resolveModulePath: (moduleName) ->
    ### Resolve path to *moduleName* if needed. ###
    if moduleName[0] is '.'
      @resolvePath moduleName
    else
      moduleName

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
    @logger.verbose "registering content plugin #{ plugin.name } that handles: #{ pattern }"
    @plugins[plugin.name] = plugin
    @contentPlugins.push
      group: group
      pattern: pattern
      class: plugin

  registerTemplatePlugin: (pattern, plugin) ->
    ### Add a template *plugin* to the environment. All files in the template directory
        matching the glob *pattern* will be passed to the plugin's `fromFile` classmethod. ###
    @logger.verbose "registering template plugin #{ plugin.name } that handles: #{ pattern }"
    @plugins[plugin.name] = plugin
    @templatePlugins.push
      pattern: pattern
      class: plugin

  registerGenerator: (group, generator) ->
    ### Add a generator to the environment. The generator function is called with the env and the
        current content tree. It should return a object with nested ContentPlugin instances.
        These will be merged into the final content tree. Generators can also return filenames
        and a buffer/stream like: {filename: 'asd', stream: 'asd'}. See generator.coffee for more info ###
    @generators.push
      group: group
      fn: generator

  registerView: (name, view) ->
    ### Add a view to the environment. ###
    @views[name] = view

  getContentGroups: ->
    ### Return an array of all registered content groups ###
    groups = []
    for plugin in @contentPlugins
      groups.push plugin.group
    for generator in @generators
      groups.push generator.group
    return groups

  loadPluginModule: (module, callback) ->
    ### Load a plugin *module*. ###
    loaded = false
    done = (error) ->
      if error?
        if not loaded and error.code is 'MODULE_NOT_FOUND'
          error.message = "Can not find plugin '#{ module }'"
        else
          error.message = "Error loading plugin '#{ module }': #{ error.message }"
      callback error
    @logger.verbose "loading plugin: #{ module }"
    if module[0] isnt '.'
      # global module, first look in node_modules
      try
        fn = require @resolveModulePath "./node_modules/#{ module }"
      catch error
        if error.code is 'MODULE_NOT_FOUND'
          # not locally installed, check globally
          try
            fn = require @resolveModulePath module
          catch error
            done error
            return
        else
          done error
          return
    else
      require 'coffee-script' if module[-6..] is 'coffee'
      try
        fn = require @resolveModulePath module
      catch error
        done error
        return
    try
      # module loaded, run it
      loaded = true
      fn this, done
    catch error
      done error

  loadViewModule: (module, callback) ->
    ### Load a view *module* and add it to the environment. ###
    @logger.verbose "loading view: #{ module }"
    try
      fn = require @resolveModulePath module
    catch error
      error.message = "Error loading view '#{ module }': #{ error.message }"
      callback error
      return
    @registerView path.basename(module), fn
    callback()

  loadPlugins: (callback) ->
    ### Loads any plugin found in *@config.plugins*. ###
    return callback() if @pluginsLoaded
    async.forEachSeries @config.plugins, @loadPluginModule.bind(this), (error) =>
      @pluginsLoaded = true if not error?
      callback error

  loadViews: (callback) ->
    ### Loads files found in the *@config.views* directory and registers them as views. ###
    return callback() if not @config.views?
    async.waterfall [
      (callback) => fs.readdir @resolvePath(@config.views), callback
      (filenames, callback) =>
        modules = filenames.map (filename) => "#{ @config.views }/#{ filename }"
        async.forEach modules, @loadViewModule.bind(this), callback
    ], callback

  getContents: (callback) ->
    ### Build the ContentTree from *@contentsPath*, also runs any registered generators. ###
    async.waterfall [
      (callback) =>
        ContentTree.fromDirectory this, @contentsPath, callback
      (contents, callback) =>
        async.mapSeries @generators, (generator, callback) =>
          runGenerator this, contents, generator, callback
        , (error, generated) =>
          return callback(error, contents) if error? or generated.length is 0
          try
            tree = generated.reduce (prev, current) -> ContentTree.merge prev, current
            ContentTree.merge contents, tree
          catch error
            return callback error
          callback null, contents
    ], callback

  getTemplates: (callback) ->
    ### Load templates. ###
    loadTemplates this, callback

  getLocals: (callback) ->
    ### Resolve locals. ###

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
          logger.warn "module '#{ moduleName }' overwrites previous local with the same key"
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
    ### Convenience method to load plugins, views, contents, templates and locals. ###
    async.waterfall [
      (callback) =>
        async.parallel [
          (callback) => @loadPlugins callback
          (callback) => @loadViews callback
        ], callback
      (_, callback) =>
        async.parallel
          contents: (callback) => @getContents callback
          templates: (callback) => @getTemplates callback
          locals: (callback) => @getLocals callback
        , callback
    ], callback

  preview: (callback) ->
    ### Start the preview server. Calls *callback* when server is up and
        running or if an error occurs. ###
    server = require './server'
    server.run this, callback

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
    {buildGraph} = require './graph'
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

Environment.defaultPlugins = ['page', 'jade', 'markdown']

### Exports ###

module.exports = {Environment}