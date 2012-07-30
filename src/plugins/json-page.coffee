path = require 'path'
async = require 'async'
Page = require './page'
{readJSON} = require './../common'

class JsonPage extends Page

JsonPage.fromFile = (filename, base, callback) ->
  async.waterfall [
    async.apply readJSON, path.join(base, filename)
    (metadata, callback) =>
      page = new this filename, metadata.content or '', metadata
      callback null, page
  ], callback

module.exports = JsonPage
