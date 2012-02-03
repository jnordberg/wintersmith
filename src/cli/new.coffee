
async = require 'async'
{app} = require 'flatiron'
{ncp} = require 'ncp'
fs = require 'fs'
path = require 'path'
{logger} = require '../common' # lib common

usage = """

  usage: wintersmith new [options] <path>

  creates a skeleton site in <path>

  options:

    -f, --force    overwrite existing files

  example:

    create a new site in your home directory
    $ wintersmith new ~/my-blog

"""

createSite = (location) ->
  ### copy example directory to *location* ###

  if !location.length
    logger.error 'you must specify a location'
    return

  from = path.join __dirname, '../../example'
  to = path.resolve location
  force = (app.argv.f or app.argv.force) or false

  logger.info "initializing new wintersmith site in #{ to }"

  async.waterfall [
    (callback) ->
      logger.verbose "checking validity of #{ to }"
      path.exists to, (exists) ->
        if exists and !force
          callback new Error "#{ to } already exists. Add --force to overwrite"
        else
          callback()
    (callback) ->
      logger.verbose "recursive copy #{ from } -> #{ to }"
      ncp from, to, {}, callback
  ], (error) ->
    if error
      logger.error error.message, error
    else
      logger.info 'done!'

module.exports = createSite
module.exports.usage = usage
module.exports.name = 'new'
