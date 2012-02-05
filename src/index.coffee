
async = require 'async'

{logger} = require './common'
{Resource, Page, ContentTree} = require './content'
{loadTemplates} = require './templates'
renderer = require './renderer'

loadContents = (location, callback) ->
  ### traverse *location* and return a tree of contents ###
  logger.verbose "loading contents in #{ location }"
  ContentTree.fromDirectory location, callback

module.exports = (options, callback) ->
  ### build all contents and templates
      *options*:
        contents: path to contents
        templates: path to templates
        output: path to output directory
        locals: optional extra data to send to templates ###

  logger.verbose 'running with options:', {options: options}

  # load templates & contents then render
  async.waterfall [
    (callback) ->
      async.parallel
        contents: async.apply loadContents, options.contents
        templates: async.apply loadTemplates, options.templates
      , callback
    (result, callback) ->
      renderer result.contents, result.templates, options.output, options.locals, callback
  ], callback

# expose api
module.exports.renderer = renderer
module.exports.loadTemplates = loadTemplates
module.exports.loadContents= loadContents
module.exports.ContentTree = ContentTree
module.exports.Resource = Resource
module.exports.Page = Page
