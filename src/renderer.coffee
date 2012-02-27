
fs = require 'fs'
util = require 'util'
async = require 'async'
path = require 'path'
underscore = require 'underscore'

{logger, extend, stripExtension} = require './common'
{ContentTree} = require './content'

renderPage = (page, templates, locals, writeStream, callback) ->
  logger.verbose "render page #{ page.filename } with template '#{ page.template }'"
  async.waterfall [
    (callback) ->
      template = templates[page.template]
      if not template?
        callback new Error "page '#{ page.filename }' specifies unknown template '#{ page.template }'"
      else
        callback null, template
    (template, callback) ->
      ctx = {page: page}
      extend ctx, locals
      renderTemplate template, ctx, callback
    (buffer, callback) ->
      writeStream.write buffer
      writeStream.end()
      callback()
  ], callback

renderResource = (resource, writeStream, callback) ->
  logger.verbose "render resource #{ resource.filename }"
  util.pump resource.readStream, writeStream, callback

renderTemplate = (template, locals, callback) ->
  ### render *template* with *locals*
      returns template output buffer ###
  try
    locals._ = underscore # add underscore functionality to template context
    rv = template locals
    callback null, new Buffer(rv, 'utf8')
  catch error
    callback error

render = (contents, templates, location, locals, callback) ->
  ### render ContentTree *contents* using *templates* to *location*
      *locals* can be used to provide extra data to all templates  ###

  logger.verbose "rendering into: #{ location }"
  logger.info "rendering tree:\n#{ ContentTree.inspect(contents, 1) }\n"

  locals.contents = contents # all pages have access to the content-tree

  resourceToFile = (resource, callback) ->
    destination = path.join(location, resource.filename)
    renderResource resource, fs.createWriteStream(destination), callback

  pageToFile = (page, callback) ->
    filename = stripExtension(page.filename) + '.html'
    destination = path.join location, filename
    renderPage page, templates, locals, fs.createWriteStream(destination), callback

  renderTree = (tree, callback) ->
    logger.verbose "rendering: #{ tree.filename }"
    async.waterfall [
      (callback) ->
        fs.mkdir path.join(location, tree.filename), (error) ->
          if not error or error.code == 'EEXIST'
            callback()
          else
            callback error
      (callback) ->
        async.parallel [
          async.apply async.forEach, tree.pages, pageToFile
          async.apply async.forEach, tree.resources, resourceToFile
          async.apply async.forEach, tree.directories, renderTree
        ], callback
    ], callback

  renderTree contents, callback

module.exports = render
module.exports.renderTemplate = renderTemplate
module.exports.renderResource = renderResource
module.exports.renderPage = renderPage
