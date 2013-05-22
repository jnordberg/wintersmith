### generator.coffee ###

{ContentPlugin, ContentTree} = require './content'

runGenerator = (env, contents, generator, callback) ->

  groups = env.getContentGroups()

  resolve = (root, items) ->
    # create content tree instances for objects and set content metadata for renderer
    for key, item of items
      if item instanceof ContentPlugin
        item.parent = root
        item.__env = env
        item.__filename = 'generator'
        item.__plugin = generator
        root[key] = item
        root._[generator.group].push item
      else if item instanceof Object
        tree = new ContentTree key, groups
        tree.parent = root
        tree.parent._.directories.push tree
        root[key] = tree
        resolve root[key], item
      else
        throw new Error "Invalid item for '#{ key }' encountered when resolving generator output"

  generator.fn contents, (error, generated) ->
    tree = new ContentTree '', groups
    try
      resolve tree, generated
    catch error
      return callback error
    callback null, tree

### Exports ###

module.exports = {runGenerator}
