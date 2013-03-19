
path = require 'path'
async = require 'async'

Page = require './page'
{readJSON} = require './../core/utils'

class JsonPage extends Page

JsonPage.fromFile = (env, filepath, callback) ->
  async.waterfall [
    async.apply readJSON, filepath.full
    (metadata, callback) =>
      page = new this filepath, metadata.content or '', metadata
      callback null, page
  ], callback

module.exports = JsonPage
