
async = require 'async'
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

options =
  force:
    alias: 'f'

createSite = (argv) ->
  ### copy example directory to *location* ###

  for val in process.argv[3..]
    if val[0] == '-'
      continue
    location = val

  if !location.length
    logger.error 'you must specify a location'
    return

  from = path.join __dirname, '../../example'
  to = path.resolve location

  logger.info "initializing new wintersmith site in #{ to }"

  async.waterfall [
    (callback) ->
      logger.verbose "checking validity of #{ to }"
      path.exists to, (exists) ->
        if exists and !argv.force
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
module.exports.options = options
