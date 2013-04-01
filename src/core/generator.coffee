### generator.coffee ###

async = require 'async'
{ContentPlugin, ContentTree} = require './content'

runGenerator = (env, contents, generator, callback) ->

  merge = (items, root, callback) ->
    # merge output of generator back into content tree
    async.forEach Object.keys(items), (key, callback) ->
      if items[key] instanceof ContentPlugin
        env.logger.verbose "generator merging '#{ key }'"
        if root[key]?
          env.logger.warning "generator output overwrites previous item for '#{ key }'"
        root[key] = items[key]
        root._[generator.group].push items[key]
        items[key].parent = root
        items[key].__filename = 'generator'
        callback()
      else if items[key] instanceof Object
        if root[key]?
          if root[key] instanceof ContentTree
            merge items[key], root[key], callback
          else
            env.logger.warning "generator tries to overwrite existing item '#{ key }' with a tree, ignoring output."
            callback()
        else
          env.logger.verbose "generator creating subtree '#{ key }'"
          tree = new ContentTree env, key
          tree.parent = root
          tree.parent._.directories.push tree
          root[key] = tree
          merge items[key], tree, callback
      else
        callback new Error "invalid generator output for '#{ key }'"
    , (error) -> callback error, root

  async.waterfall [
    (callback) -> generator.fn contents, callback
    (generated, callback) -> merge generated, contents, callback
  ], callback

### Exports ###

module.exports = {runGenerator}
