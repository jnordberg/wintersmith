### environment.coffee ###

path = require 'path'
async = require 'async'
fs = require 'fs'
{EventEmitter} = require 'events'

utils = require './utils'

{Config} = require './config'
{ContentPlugin, ContentTree, StaticFile} = require './content'
{TemplatePlugin, loadTemplates} = require './templates'
{logger} = require './logger'
{render} = require './renderer'
{runGenerator} = require './generator'

{readJSON, readJSONSync} = utils

class Environment extends EventEmitter
  ### The Wintersmith environment. ###

  utils: utils
  ContentTree: ContentTree
  ContentPlugin: ContentPlugin
  TemplatePlugin: TemplatePlugin

  constructor: (config, @workDir, @logger) ->
    ### Create a new Environment, *config* is a Config instance, *workDir* is the
        working directory and *logger* is a log instance implementing methods for
        error, warn, verbose and silly loglevels. ###
    @loadedModules = []
    @workDir = path.resolve @workDir
    @setConfig config
    @reset()

  reset: ->
    ### Reset environment and clear any loaded modules from require.cache ###
    @views = {none: (args..., callback) -> callback()}
    @generators = []
    @plugins = {StaticFile}
    @templatePlugins = []
    @contentPlugins = []
    @helpers = {}

    while id = @loadedModules.pop()
      @logger.verbose "unloading: #{ id }"
      delete require.cache[id]

    @setupLocals()

  setConfig: (@config) ->
    @contentsPath = @resolvePath @config.contents
    @templatesPath = @resolvePath @config.templates

  setupLocals: ->
    ### Resolve locals and loads any required modules. ###
    @locals = {}

    # Load locals json if necessary
    if typeof @config.locals == 'string'
      filename = @resolvePath @config.locals
      @logger.verbose "loading locals from: #{ filename }"
      @locals = readJSONSync filename
    else
      @locals = @config.locals

    # Load and add modules specified with the require option to the locals context.
    for alias, id of @config.require
      logger.verbose "loading module '#{ id }' available in locals as '#{ alias }'"
      if @locals[alias]?
        logger.warn "module '#{ id }' overwrites previous local with the same key ('#{ alias }')"
      try
        @locals[alias] = @loadModule id
      catch error
        logger.warn "unable to load '#{ id }': #{ error.message }"

    return

  resolvePath: (pathname) ->
    ### Resolve *pathname* in working directory, returns an absolute path. ###
    path.resolve @workDir, pathname or ''

  resolveContentsPath: (pathname) ->
    ### Resolve *pathname* in contents directory, returns an absolute path. ###
    path.resolve @contentsPath, pathname or ''

  resolveModule: (module) ->
    ### Resolve *module* to an absolute path, mimicking the node.js module loading system. ###
    switch module[0]
      when '.'
        require.resolve @resolvePath module
      when '/'
        require.resolve module
      else
        nodeDir = @resolvePath 'node_modules'
        try
          require.resolve path.join(nodeDir, module)
        catch error
          require.resolve module

  relativePath: (pathname) ->
    ### Resolve path relative to working directory. ###
    path.relative @workDir, pathname

  relativeContentsPath: (pathname) ->
    ### Resolve path relative to contents directory. ###
    path.relative @contentsPath, pathname

  registerContentPlugin: (group, pattern, plugin) ->
    ### Add a content *plugin* to the environment. Files in the contents directory
        matching the glob *pattern* will be instantiated using the plugin's `fromFile`
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
        These will be merged into the final content tree. ###
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
      groups.push plugin.group unless plugin.group in groups
    for generator in @generators
      groups.push generator.group unless generator.group in groups
    return groups

  loadModule: (module, unloadOnReset=false) ->
    ### Requires and returns *module*, resolved from the current working directory. ###
    require 'coffee-script/register' if module[-7..] is '.coffee'
    @logger.silly "loading module: #{ module }"
    id = @resolveModule module
    @logger.silly "resolved: #{ id }"
    rv = require id
    @loadedModules.push id if unloadOnReset
    return rv

  loadPluginModule: (module, callback) ->
    ### Load a plugin *module*. Calls *callback* when plugin is done loading, or an error occurred. ###
    id = 'unknown'
    done = (error) ->
      error.message = "Error loading plugin '#{ id }': #{ error.message }" if error?
      callback error

    if typeof module is 'string'
      id = module
      try
        module = @loadModule module
      catch error
        done error
        return

    try
      module.call null, this, done
    catch error
      done error

  loadViewModule: (id, callback) ->
    ### Load a view *module* and add it to the environment. ###
    @logger.verbose "loading view: #{ id }"
    try
      module = @loadModule id, true
    catch error
      error.message = "Error loading view '#{ id }': #{ error.message }"
      callback error
      return
    @registerView path.basename(id), module
    callback()

  loadPlugins: (callback) ->
    ### Loads any plugin found in *@config.plugins*. ###
    async.series [
      # load default plugins
      (callback) =>
        async.forEachSeries @constructor.defaultPlugins, (plugin, callback) =>
          @logger.verbose "loading default plugin: #{ plugin }"
          id = require.resolve "./../plugins/#{ plugin }"
          module = require id
          @loadedModules.push id
          @loadPluginModule module, callback
        , callback
      # load user plugins
      (callback) =>
        async.forEachSeries @config.plugins, (plugin, callback) =>
          @logger.verbose "loading plugin: #{ plugin }"
          @loadPluginModule plugin, callback
        , callback
    ], callback

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
            tree = new ContentTree '', @getContentGroups()
            for gentree in generated
              ContentTree.merge tree, gentree
            ContentTree.merge tree, contents
          catch error
            return callback error
          callback null, tree
    ], callback

  getTemplates: (callback) ->
    ### Load templates. ###
    loadTemplates this, callback

  getLocals: (callback) ->
    ### Returns locals. ###
    # TODO: locals are no longer loaded async, this method should eventually be removed
    callback null, @locals

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
    ### Start the preview server. Calls *callback* with the server instance when it is up and
        running or if an error occurs. NOTE: The returned server instance will be invalid if the
        config file changes and the server is restarted because of it. As a temporary workaround
        you can set the _restartOnConfChange key in settings to false. ###
    @mode = 'preview'
    server = require './server'
    server.run this, callback

  build: (outputDir, callback) ->
    ### Build the content tree and render it to *outputDir*. ###
    @mode = 'build'
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

Environment.create = (config, workDir, log=logger) ->
  ### Set up a new environment using the default logger, *config* can be
      either a config object, a Config instance or a path to a config file. ###

  if typeof config is 'string'
    # working directory will be where the config file resides
    workDir ?= path.dirname config
    config = Config.fromFileSync config
  else
    workDir ?= process.cwd()
    if config not instanceof Config
      config = new Config config

  return new Environment config, workDir, log

Environment.defaultPlugins = ['page', 'pug', 'markdown']

### Exports ###

module.exports = {Environment}
