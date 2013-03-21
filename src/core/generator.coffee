### generator.coffee ###

async = require 'async'
{ContentPlugin, ContentTree} = require './content'

runGenerator = (env, contents, generator, callback) ->

  run = (callback) ->
    # run the generator
    generator.fn contents, callback

  merge = (generated, callback) ->
    # merge output of generator back into content tree
    m = (items, root, callback) ->
      async.forEach Object.keys(items), (key, callback) ->
        if items[key] instanceof ContentPlugin
          if root[key]?
            env.logger.warning "generator output overwrites previous item for '#{ key }'"
          env.logger.verbose "generator merging '#{ key }'"
          root[key] = items[key]
          root._[generator.group].push items[key]
          items[key].parent = root
          items[key].__filename = 'generator'
          callback()
        else if items[key] instanceof Object
          if contents[key]?
            if contents[key] instanceof ContentTree
              m items[key], contents[key], callback
            else
              env.logger.warning "generator tries to overwrite existing item '#{ key }'' with directory, ignoring output."
              callback()
          else
            env.logger.verbose "generator creating subtree '#{ key }'"
            tree = new ContentTree env, key
            tree.parent = root
            tree.parent._.directories.push tree
            root[key] = tree
            m items[key], tree, callback
        else
          callback new Error "invalid generator output for '#{ key }'"
      , callback
    m generated, contents, (error) -> callback error, contents

  async.waterfall [
    run
    merge
  ], callback

### Exports ###

module.exports = {runGenerator}
