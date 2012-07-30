
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

  locals.contents = contents # all plugins have access to the content-tree

  renderPlugin = (content, callback) ->
    ### render *content* plugin, calls *callback* with true if a file is written;
        otherwise false. ###
    destination = path.join location, content.filename
    logger.verbose "writing content #{ content.url } to #{ destination }"
    content.render locals, contents, templates, (error, result) ->
      if error
        callback error, false
      else if result instanceof fs.ReadStream or result instanceof Buffer
        # TODO: use in-memory readstreams instead of buffers if possible
        writeStream = fs.createWriteStream destination
        if result instanceof fs.ReadStream
          util.pump result, writeStream, (error) ->
            callback error, true
        else
          writeStream.write result
          writeStream.end()
        callback null, true
      else
        logger.verbose "skipping #{ content.url }"
        callback null, false

  renderTree = (tree, callback) ->
    logger.verbose "rendering: #{ tree.filename }"
    directory = path.join location, tree.filename
    async.waterfall [
      (callback) ->
        # create directory for tree
        fs.mkdir directory, (error) ->
          if not error or error.code == 'EEXIST'
            callback()
          else
            callback error
      (callback) ->
        # recursively render tree and its plugins
        async.map Object.keys(tree), (key, callback) ->
          item = tree[key]
          if item instanceof ContentTree
            renderTree item, callback
          else
            renderPlugin item, callback
        , callback
      (written, callback) ->
        # remove directory if no files where written to it
        detector = (didWrite, callback) ->
          callback !didWrite
        async.every written, detector, (isEmpty) ->
          if isEmpty
            logger.verbose "removing empty directory #{ directory }"
            fs.rmdir directory, callback
          else
            callback()
    ], (error) ->
      callback error, true

  renderTree contents, callback

module.exports = render
