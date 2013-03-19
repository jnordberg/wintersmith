### graph.coffee ###

async = require 'async'
{EventEmitter} = require 'events'

{ContentPlugin, ContentTree} = require './content'

class Node

  constructor: (@id, @item) ->
    @edges = []

  addEdge: (node) ->
    @edges.push node

class Graph

  constructor: (@identify) ->
    ### *identify* is a function that identifies an item. should return
        a unique string value representing that item. ###
    @nodes = {}

  addItem: (item) ->
    id = @identify item
    node = new Node id, item
    @nodes[id] = node
    return node

  addDependency: (item, dependency) ->
    ### add a *dependency* for *item* ###
    node = @nodeFor item
    node.addEdge @nodeFor dependency

  dependenciesFor: (item) ->
    ### return an array with all depdenencies for *item* ###
    node = @nodeFor item
    resolved = @resolveNode node
    resolved.splice resolved.indexOf(node), 1
    return resolved.map (node) -> node.item

  ### private ###

  nodeFor: (item) ->
    @nodes[@identify(item)] or @addItem(item)

  resolveNode: (node, resolved=[], seen={}) ->
    seen[node.id] = true
    for edge in node.edges
      if edge not in resolved and edge.id not of seen
        @resolveNode edge, resolved, seen
    resolved.push node
    return resolved

class GraphHandler

  constructor: (@target, @fn) ->

  get: (receiver, key) ->
    rv = @target[key]
    if rv instanceof ContentPlugin
      @fn rv # emit dependency
      return rv
    else if rv instanceof Object
      handler = new GraphHandler rv, @fn
      return Proxy.create handler, Object.getPrototypeOf rv
    else
      return rv

  set: (receiver, key, value) ->
    @target[key] = value;
    return true

  getOwnPropertyNames: ->
    Object.getOwnPropertyNames @target

  keys: ->
    Object.keys @target

  enumerate: ->
    (key for key of @target)

  getPropertyDescriptor: (key) ->
    obj = @target
    while obj
      desc = Object.getOwnPropertyDescriptor obj, key
      if desc
        desc.configurable = true
        return desc
      obj = Object.getPrototypeOf obj
    return

  getOwnPropertyDescriptor: (key) ->
    desc = Object.getOwnPropertyDescriptor @target, key
    desc.configurable = true if desc
    return desc

  defineProperty: (key, desc) ->
    Object.defineProperty @target, key, desc

  has: (key) ->
    (key of @target)

  hasOwn: (key) ->
    Object.prototype.hasOwnProperty.call @target, key

  delete: (key) ->
    delete @target[key]
    return true

  apply: (receiver, args) ->
    Function.prototype.apply.call @target, receiver, args

  construct: (args) ->
    new Function.prototype.bind.apply @target, [null].concat(args)

GraphHandler.proxy = (tree, fn) ->
  handler = new GraphHandler tree, fn
  return Proxy.create handler, ContentTree.prototype

# generate dependency graph for environment

buildGraph = (env, contents, templates, locals, callback) ->
  if not Proxy?
    callback new Error "Harmony proxies not enabled. You need to run node with --harmony-proxies."
    return

  current = null
  items = ContentTree.flatten contents

  graph = new Graph (item) -> item.__filename
  graph.addItem item for item in items

  proxy = GraphHandler.proxy contents, (dep) ->
    graph.addDependency current, dep

  locals.contents = proxy

  async.eachSeries items, (item, callback) ->
    current = item
    # NOTE: is it ok to discard readstreams like this?
    item.view env, locals, proxy, templates, callback
  , (error) ->
    callback error, graph

exports.buildGraph = buildGraph
