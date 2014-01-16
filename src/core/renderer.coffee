### renderer.coffee ###

fs = require 'fs'
util = require 'util'
async = require 'async'
path = require 'path'
mkdirp = require 'mkdirp'
{Stream} = require 'stream'

{ContentTree} = require './content'
{pump, extend} = require './utils'

if not setImmediate?
  setImmediate = process.nextTick

renderView = (env, content, locals, contents, templates, callback) ->
  setImmediate ->
    # add env and contents to view locals
    _locals = {env, contents}
    extend _locals, locals

    # lookup view function if needed
    view = content.view
    if typeof view is 'string'
      name = view
      view = env.views[view]
      if not view?
        callback new Error "content '#{ content.filename }' specifies unknown view '#{ name }'"
        return

    # run view
    view.call content, env, _locals, contents, templates, (error, result) ->
      error.message = "#{ content.filename }: #{ error.message }" if error?
      callback error, result

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
      else if result instanceof Stream or result instanceof Buffer
        destination = path.join outputDir, content.filename
        env.logger.verbose "writing content #{ content.url } to #{ destination }"
        mkdirp.sync path.dirname destination
        writeStream = fs.createWriteStream destination
        if result instanceof Stream
          pump result, writeStream, callback
        else
          writeStream.end result, callback
      else
        env.logger.verbose "skipping #{ content.url }"
        callback()

  items = ContentTree.flatten contents
  async.forEachLimit items, env.config._fileLimit, renderPlugin, callback

### Exports ###

module.exports = {render, renderView}
