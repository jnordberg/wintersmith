### renderer.coffee ###

fs = require 'fs'
util = require 'util'
async = require 'async'
path = require 'path'

{logger, extend, stripExtension} = require './utils'
{ContentTree} = require './content'

render = (env, outputDir, contents, templates, locals, callback) ->
  ### Render *contents* and *templates* using environment *env* to *outputDir*.
      The output directory will be created if it does not exist. ###

  logger.info "rendering tree:\n#{ ContentTree.inspect(contents, 1) }\n"
  logger.verbose "render output directory: #{ outputDir }"

  locals.contents = contents # all plugins have access to the content-tree
  renderTree contents, callback

  renderPlugin = (content, callback) ->
    ### render *content* plugin, calls *callback* with true if a file is written;
        otherwise false. ###
    destination = path.join outputDir, content.filename # TODO: create intermediate directories if needed
    logger.verbose "writing content #{ content.url } to #{ destination }"
    content.view env, locals, contents, templates, (error, result) ->
      if error
        callback error, false
      else if result instanceof fs.ReadStream or result instanceof Buffer
        writeStream = fs.createWriteStream destination
        if result instanceof fs.ReadStream
          result.pipe writeStream, (error) -> callback error, true
        else
          writeStream.write result
          writeStream.end()
          callback null, true
      else
        logger.verbose "skipping #{ content.url }"
        callback null, false

  renderTree = (tree, callback) ->
    logger.verbose "rendering: #{ tree.filename }"
    directory = path.join outputDir, tree.filename
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

### Exports ###

exports.render = render
