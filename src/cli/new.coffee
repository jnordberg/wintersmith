async = require 'async'
fs = require 'fs'
path = require 'path'
npm = require 'npm'
{ncp} = require 'ncp'
{Stream} = require 'stream'

{fileExists} = require './../core/utils'
{logger} = require './../core/logger'

class NpmAdapter extends Stream
  ### Redirects output of npm to wintersmith logger ###

  constructor: ->
    @buffer = ''

  write: (data) ->
    @buffer += data
    @flush() if data.indexOf('\n') isnt -1

  flush: ->
    lines = @buffer.split('\n')
    @buffer = ''
    for line in lines
      continue unless line.length > 0
      line = line.replace /^npm /, ''
      if line[0...4] is 'WARN'
        logger.warn "npm: #{ line[5..] }"
      else
        logger.verbose "npm: #{ line }"

templatesDir = path.join __dirname, '../../examples/'
templateTypes = fs.readdirSync(templatesDir).filter (filename) ->
  fs.statSync(path.join(templatesDir, filename)).isDirectory()

usage = """

  usage: wintersmith new [options] <path>

  creates a skeleton site in <path>

  options:

    -f, --force             overwrite existing files
    -T, --template <name>   template to create new site from (defaults to 'blog')

    available templates are: #{ templateTypes.join(', ') }

  example:

    create a new site in your home directory
    $ wintersmith new ~/my-blog

"""

options =
  force:
    alias: 'f'
  template:
    alias: 'T'
    default: 'blog'

createSite = (argv) ->
  ### copy example directory to *location* ###

  location = argv._[1]
  if !location? or !location.length
    logger.error 'you must specify a location'
    return

  if argv.template not in templateTypes
    logger.error "unknown template type #{ argv.template }"
    return

  from = path.join templatesDir, argv.template
  to = path.resolve location

  logger.info "initializing new wintersmith site in #{ to } using template #{ argv.template }"

  validateDestination = (callback) ->
    logger.verbose "checking validity of #{ to }"
    fileExists to, (exists) ->
      if exists and !argv.force
        callback new Error "#{ to } already exists. Add --force to overwrite"
      else
        callback()

  copyTemplate = (callback) ->
    logger.verbose "recursive copy #{ from } -> #{ to }"
    ncp from, to, {}, callback

  installDeps = (callback) ->
    packagePath = path.join to, 'package.json'
    fileExists packagePath, (exists) ->
      if exists
        logger.verbose "installing template dependencies"
        process.chdir to
        conf = {logstream: new NpmAdapter}
        npm.load conf, (error) ->
          return callback error if error?
          npm.install callback
      else
        callback()

  async.series [validateDestination, copyTemplate, installDeps], (error) ->
    if error
      logger.error error.message, error
    else
      logger.info 'done!'

module.exports = createSite
module.exports.usage = usage
module.exports.options = options
