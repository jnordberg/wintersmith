
jade = require 'jade'
fs = require 'fs'
async = require 'async'
path = require 'path'
{ncp} = require 'ncp'
glob = require 'glob'
util = require 'util'
colors = require 'colors'
Article = require './article'
{logger, extend, copyFile} = require './common'

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

loadArticles = (location, callback) ->
  ### parse all articles found in *location*
      an article can either be in the root of *location* as a markdown file
      or a directory with an index.markdown (< TODO)
      returns array of Article objects ###

  logger.verbose 'loading articles'

  # glob options
  opts =
    cwd: location
    nosort: true

  async.waterfall [
    (callback) ->
      async.parallel [
        (callback) ->
          # load single-file articles
          async.waterfall [
            async.apply glob, '*.*(md|markdown)', opts
            (result, callback) ->
              async.map result, (filename, callback) ->
                logger.verbose "loading article: #{ filename }"
                Article.fromFile path.join(location, filename), callback
              , callback
          ], callback
        (callback) ->
          # load directory articles
          async.waterfall [
            async.apply glob, '**/index.*(markdown|md)', opts
            (result, callback) ->
              async.map result, (filename, callback) ->
                directory = path.dirname filename
                logger.verbose "loading article directory: #{ directory }"
                Article.fromDirectory path.join(location, directory), callback
              , callback
          ], callback
      ], callback
    (result, callback) ->
      # merge results and sort by date
      articles = result[0].concat result[1]
      async.sortBy articles, (article, callback) ->
        callback null, article.date
      , callback
  ], callback

renderTemplate = (template, locals, callback) ->
  ### render *template* with *locals*
      returns template output (string) ###
  try
    rv = template locals
    callback null, rv
  catch error
    callback error

render = (templates, articles, location, rebuild, locals, callback) ->
  ### render all templates in *data.templates* once with the exception of 'article.jade' wich is
      rendered once for every article in *data.articles* to *location*. *locals* can be used to
      provide extra data to all templates ###

  logger.verbose "rendering templates into: #{ location }"

  required = ['article.jade', 'index.jade', 'feed.jade']
  keys = Object.keys templates
  for req in required
    if keys.indexOf(req) == -1
      callback new Error "required template '#{ req }' not found!"
      return

  collisionMap = {}

  async.parallel [
    (callback) ->
      # render articles
      async.forEach articles, (article, callback) ->
        async.waterfall [
          (callback) ->
            # check that article's slug does not collide with another article
            if collisionMap[article.slug]?
              callback new Error "article: #{ article.filename }'s slug colldes " +
                "with #{ collisionMap[article.slug].filename}'s slug (rename files or use another slug " +
                "by specifying in metadata as 'slug: my-slug')"
            else
              collisionMap[article.slug] = article
              callback()
          (callback) ->
            # check if article is already rendered
            path.exists path.join(location, article.slug), (exists) ->
              if !exists or rebuild
                callback()
              else
                callback.final() # skip to end of chain
          (callback) ->
            ctx = article: article
            extend ctx, locals
            logger.info "rendering article: #{ article.title.bold } (#{ article.slug })"
            renderTemplate templates['article.jade'], ctx, callback
          (html, callback) ->
            # write html to disk
            dir = path.join location, article.slug
            async.waterfall [
              (callback) ->
                fs.mkdir dir, (error) ->
                  # ignore possible error due to already existing dir
                  callback()
              (callback) ->
                logger.verbose "writing article #{ article.slug } in '#{ dir }'"
                fs.writeFile path.join(dir, 'index.html'), html, callback
              (callback) ->
                # copy any files associated with article
                async.forEach article.files, (filename, callback) ->
                  destination = path.join dir, path.basename(filename)
                  logger.verbose "copying #{ filename } to article #{ article.slug }"
                  copyFile filename, destination, true, callback
                , callback
            ], callback
        ], callback
      , callback
    (callback) ->
      # render rest of templates
      queue = []
      ctx = articles: articles
      extend ctx, locals

      for name, template of templates
        switch name
          when 'article.jade'
            continue
          when 'feed.jade'
            filename = 'feed.xml'
          else
            filename = name.replace /\.jade$/, '.html'
        queue.push
          template: template
          filename: filename

      async.forEach queue, (data, callback) ->
        async.waterfall [
          (callback) ->
            logger.info "rendering #{ data.filename.bold }"
            dirname = path.dirname data.filename
            if dirname != '.'
              fs.mkdir path.join(location, dirname), (error) ->
                # ignore errors, assume dir already exists
                callback()
            else
              callback()
          (callback) ->
            renderTemplate data.template, ctx, callback
          (html, callback) ->
            fs.writeFile path.join(location, data.filename), html, callback
        ], callback
      , callback

  ], callback

module.exports = (options, callback) ->
  ### build all articles and templates
      *options*:
        articles: path to article directory
        templates: path to template directory
        output: path to output directory
        static: path to static files directory
        locals: optional extra data to send to templates
        rebuild: rebuild all articles ###

  logger.verbose 'running with options:', {options: options}

  async.parallel [
    (callback) ->
      # load templates & articles then render
      async.waterfall [
        (callback) ->
          async.parallel
            articles: async.apply loadArticles, options.articles
            templates: async.apply loadTemplates, options.templates
          , callback
        (result, callback) ->
          render result.templates, result.articles, options.output,
            options.rebuild, options.locals, callback
      ], callback
    (callback) ->
      # copy static content
      logger.info "copying static content"
      ncp options.static, options.output, {}, callback
  ], callback

# expose api
module.exports.render = render
module.exports.loadTemplates = loadTemplates
module.exports.loadArticles = loadArticles
module.exports.renderTemplate = renderTemplate
module.exports.compileTemplate = compileTemplate
module.exports.Article = Article
