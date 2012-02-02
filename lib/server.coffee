
util = require 'util'
wintersmith = require './'
async = require 'async'
fs = require 'fs'
path = require 'path'
url = require 'url'
colors = require 'colors'
{logger, extend, stripExtension} = require './common'

colorCode = (code) ->
  s = code.toString()
  switch Math.floor code / 100
    when 2
      return s.green
    when 4
      return s.yellow
    when 5
      return s.red
    else
      return s

setup = (options) ->

  articleHandler = (uri, response, callback) ->
    parts = uri.substr(1).split '/'
    slug = parts.shift()
    resource = parts.join '/'

    logger.verbose "looking for article (#{ slug }, #{ resource })"

    async.waterfall [
      (callback) ->
        async.parallel
          template: async.apply wintersmith.compileTemplate, path.join(options.templates, 'article.jade')
          articles: async.apply wintersmith.loadArticles, options.articles
        , callback
      (result, callback) ->
        {template, articles} = result
        async.waterfall [
          (callback) ->
            logger.verbose "looking for article #{ slug }"
            async.detect articles, (article, callback) ->
              callback (article.slug == slug)
            , (article) ->
              if article
                callback null, article
              else
                callback.final() # not found
          (article, callback) ->
            if resource
              logger.verbose "looking for resource #{ resource }"
              async.detect article.files, (file, callback) ->
                callback path.basename(file) == resource
              , (file) ->
                if file
                  fs.readFile file, callback
                else
                  callback.final()
            else
              logger.verbose "rendering article #{ article.title }"
              ctx = article: article
              extend ctx, options.locals
              wintersmith.renderTemplate template, ctx, callback
        ], callback
    ], (error, result) ->
      if error
        callback error
      else if result
        if result instanceof Buffer
          response.writeHead 200
          response.write result, 'binary'
          response.end()
        else
          response.writeHead 200, 'Content-Type': 'text/html'
          response.end result
        callback.final null, 200 # final since we handled the request
      else
        callback()

  templateHandler = (uri, response, callback) ->
    logger.verbose "template handler #{ uri }"
    async.waterfall [
      async.apply wintersmith.loadTemplates, options.templates
      (templates, callback) ->
        async.detect Object.keys(templates), (filename, callback) ->
          name = stripExtension filename
          switch name
            when 'article'
              # reserved name
              callback false
            when 'feed'
              callback (uri == '/feed.xml')
            else
              if uri.substr(uri.length - 1) == '/'
                uri += 'index.html'
              callback (uri == "/#{ name }.html")
        , (match) ->
          callback null, templates[match]
      (template, callback) ->
        if template
          async.waterfall [
            # get articles
            async.apply wintersmith.loadArticles, options.articles
            (articles, callback) ->
              # render template with context
              ctx = articles: articles
              extend ctx, options.locals
              wintersmith.renderTemplate template, ctx, callback
          ], callback
        else
          callback()
    ], (error, result) ->
      if error
        callback error
      else if result
        response.writeHead 200, 'Content-Type': 'text/html'
        response.end result
        callback.final null, 200
      else
        callback()

  staticHandler = (uri, response, callback) ->
    logger.verbose "static handler #{ uri }"

    async.waterfall [
      (callback) ->
        filename = path.join options.static, uri
        path.exists filename, (exists) ->
          if exists
            callback null, filename
          else
            callback.final() # not found
      (filename, callback) ->
        fs.stat filename, (error, stat) ->
          if error
            callback error
          else if stat.isDirectory()
            filename += '/index.html'
            if path.existsSync filename
              callback null, filename
            else
              callback.final(null, 403) # forbidden
          else
            callback null, filename
      (filename, callback) ->
        fs.readFile filename, callback
    ], (error, result) ->
      if error
        callback error
      else if result == 403
        response.writeHead 403, 'Content-Type': 'text/plain'
        response.end '403 Forbidden\n'
        callback.final null, 403
      else if result instanceof Buffer
        response.writeHead 200
        response.write result, 'binary'
        response.end()
        callback.final null, 200
      else
        callback()

  requestHandler = (request, response) ->
    uri = url.parse(request.url).pathname
    logger.verbose "handling #{ uri }"

    async.waterfall [
      async.apply articleHandler, uri, response
      async.apply templateHandler, uri, response
      async.apply staticHandler, uri, response
    ], (error, responseCode) ->
      if error or !responseCode?
        # request not handled or error
        responseCode = if error? then 500 else 404
        response.writeHead responseCode, 'Content-Type': 'text/plain'
        response.end if error? then error.message else '404 Not Found\n'
      logger.info "#{ colorCode(responseCode) } #{ uri.bold }"

  return requestHandler

run = (options) ->
  http = require 'http'
  server = http.createServer setup options
  server.listen options.port
  serverUrl = "http://localhost:#{ options.port }/".bold
  logger.info "server running on: #{ serverUrl }"

module.exports = setup
module.exports.run = run
