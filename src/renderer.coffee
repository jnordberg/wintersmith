
fs = require 'fs'
util = require 'util'
async = require 'async'
path = require 'path'

{logger, extend, stripExtension} = require './common'
{ContentTree} = require './content'

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
    if page.template == 'none'
      logger.verbose "skipping page w/o template: #{ page.filename }"
      return
    filename = stripExtension(page.filename) + '.html'
    destination = path.join location, filename
    renderPage page, templates, locals, fs.createWriteStream(destination), callback

  renderPlugin = (content, callback) ->
    destination = path.join location, content.filename
    writeStream = fs.createWriteStream destination
    logger.verbose "writing content #{ content.url } to #{ destination }"
    content.render locals, contents, templates, (error, result) ->
      if error
        callback error
      else if result instanceof fs.ReadStream
        util.pump result, writeStream, callback
      else if result instanceof Buffer
        writeStream.write result
        writeStream.end()
        callback()
      else
        logger.verbose "skipping #{ content.url }"
        callback()

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
        async.forEach Object.keys(tree), (key, callback) ->
          item = tree[key]
          if item instanceof ContentTree
            renderTree item, callback
          else
            renderPlugin item, callback
        , callback
    ], callback

  renderTree contents, callback

module.exports = render
