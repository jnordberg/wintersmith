async = require 'async'
fs = require 'fs'
path = require 'path'
npm = require 'npm'
{ncp} = require 'ncp'

{NpmAdapter, getStorageDir} = require './common'
{fileExists, fileExistsSync} = require './../core/utils'
{logger} = require './../core/logger'

templates = {}
loadTemplates = (directory) ->
  return unless fileExistsSync directory
  fs.readdirSync(directory)
    .map((filename) -> path.join(directory, filename))
    .filter((filename) -> fs.statSync(filename).isDirectory())
    .forEach((filename) -> templates[path.basename(filename)] = filename)

loadTemplates path.join __dirname, '../../examples/'
loadTemplates path.join getStorageDir(), 'templates/'

usage = """

  usage: wintersmith new [options] <path>

  creates a skeleton site in <path>

  options:

    -f, --force             overwrite existing files
    -T, --template <name>   template to create new site from (defaults to 'blog')

    available templates are: #{ Object.keys(templates).join(', ') }

  example:

    create a new site in your home directory
    $ wintersmith new ~/my-blog

"""

options =
  string: ['template']
  boolean: ['force']
  alias:
    force: 'f'
    template: 'T'
  default:
    template: 'blog'

createSite = (argv) ->
  ### copy example directory to *location* ###

  location = argv._[3]
  if !location? or !location.length
    logger.error 'you must specify a location'
    return

  if not templates[argv.template]?
    logger.error "unknown template '#{ argv.template }'"
    return

  from = templates[argv.template]
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
        conf = {logstream: new NpmAdapter(logger)}
        npm.load conf, (error) ->
          return callback error if error?
          npm.install callback
      else
        callback()

  async.series [validateDestination, copyTemplate, installDeps], (error) ->
    if error
      logger.error error.message, error
      process.exit 1
    else
      logger.info 'done!'

module.exports = createSite
module.exports.usage = usage
module.exports.options = options
