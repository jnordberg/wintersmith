{ContentTree, ContentPlugin} = require './core/content'
{Environment} = require './core/environment'
{TemplatePlugin} = require './core/templates'

module.exports = -> Environment.create.apply(null, arguments)
module.exports.Environment = Environment
module.exports.ContentPlugin = ContentPlugin
module.exports.ContentTree = ContentTree
module.exports.TemplatePlugin = TemplatePlugin
