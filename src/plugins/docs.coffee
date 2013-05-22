sh = require 'shelljs'
path = require 'path'

coffeedoc = path.resolve __dirname, '../node_modules/.bin/coffeedoc'
tempPath = '/tmp/coffeedoc'

beginswith = (haystack, needle) ->
  haystack[0...needle.length] is needle

module.exports = (env, callback) ->
  env.logger.info "building docs in #{ env.config.docs.source }"

  sh.pushd env.config.docs.source
  sh.exec "#{ coffeedoc } --output #{ tempPath } --renderer json *.coffee"
  sh.popd()

  jsonfile = path.join tempPath, 'index.doc.json'
  docsData = JSON.parse sh.cat jsonfile
  sh.rm jsonfile

  # fix where cofeedoc misses static methods
  # and add links to github source
  for doc in docsData
    doc.srcUrl = env.config.docs.url + doc.path
    for cls in doc.classes
      #cls.srcUrl = doc.srcUrl + '#L' + (cls.lineno + 1)
      for fn in doc.functions
        if beginswith fn.name, cls.name
          fn.name = fn.name[cls.name.length+1...]
          cls.staticmethods.push fn
      for fn in cls.instancemethods
        fn.srcUrl = doc.srcUrl + '#L' + (fn.lineno + 1)
      for fn in cls.staticmethods
        fn.srcUrl = doc.srcUrl + '#L' + (fn.lineno + 1)

  class DocPlugin extends env.plugins.Page
    constructor: (@docs) -> super '', {template: 'docs.html'}
    getFilename: -> 'docs/index.html'

  tree = {docs: new DocPlugin(docsData)}
  env.registerGenerator 'docs', (contents, callback) ->
    callback null, tree

  callback()
