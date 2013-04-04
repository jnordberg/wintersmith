### renderer.coffee ###

fs = require 'fs'
util = require 'util'
async = require 'async'
path = require 'path'
mkdirp = require 'mkdirp'

{ContentTree} = require './content'
{pump} = require './utils'

if not setImmediate?
  setImmediate = process.nextTick

renderView = (env, content, locals, contents, templates, callback) ->
  setImmediate ->
    view = content.view
    if typeof view is 'string'
      name = view
      view = env.views[view]
      if not view?
        callback new Error "content '#{ content.filename }' specifies unknown view '#{ name }'"
        return
    view.call content, env, locals, contents, templates, callback

render = (env, outputDir, contents, templates, locals, callback) ->
  ### Render *contents* and *templates* using environment *env* to *outputDir*.
      The output directory will be created if it does not exist. ###

  env.logger.info "rendering tree:\n#{ ContentTree.inspect(contents, 1) }\n"
  env.logger.verbose "render output directory: #{ outputDir }"

  renderPlugin = (content, callback) ->
    ### render *content* plugin, calls *callback* with true if a file is written; otherwise false. ###
    renderView env, content, locals, contents, templates, (error, result) ->
      if error
        callback error
      else if result instanceof fs.ReadStream or result instanceof Buffer
        destination = path.join outputDir, content.filename
        env.logger.verbose "writing content #{ content.url } to #{ destination }"
        mkdirp.sync path.dirname destination
        writeStream = fs.createWriteStream destination
        if result instanceof fs.ReadStream
          pump result, writeStream, callback
        else
          writeStream.write result
          writeStream.end()
          callback()
      else
        env.logger.verbose "skipping #{ content.url }"
        callback()

  items = ContentTree.flatten contents
  async.forEachLimit items, env.config._fileLimit, renderPlugin, callback

### Exports ###

module.exports = {render, renderView}
