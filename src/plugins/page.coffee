path = require 'path'
async = require 'async'
slugify = require 'slugg'

replaceAll = (string, map) ->
  re = new RegExp Object.keys(map).join('|'), 'gi'
  return string.replace re, (match) -> map[match]

module.exports = (env, callback) ->

  templateView = (env, locals, contents, templates, callback) ->
    ### Content view that expects content to have a @template instance var that
        matches a template in *templates*. Calls *callback* with output of template
        or null if @template is set to 'none'. ###

    if @template == 'none'
      return callback null, null

    template = templates[path.normalize @template]
    if not template?
      callback new Error "page '#{ @filename }' specifies unknown template '#{ @template }'"
      return

    ctx = {page: this}
    env.utils.extend ctx, locals

    template.render ctx, callback

  class Page extends env.ContentPlugin
    ### Page base class, a page is content that has metadata, html and a template that renders it ###

    constructor: (@filepath, @metadata) ->

    getFilename: ->
      ### Returns the filename for this page based on the filename template.
          The default template (filenameTemplate config key) is ':file.html'.

          Available variables:

            :year - Full year from page.date
            :month - Zero-padded month from page.date
            :day - Zero-padded day from page.date
            :title - Slugified version of page.title
            :basename - filename from @filepath
            :file - basename without file extension
            :ext - file extension

          You can also run javascript by wrapping it in double moustaches {{ }}, in that context
          this page instance is available as *page* and the environment as *env*.

          Examples:

            (for a page with the filename somedir/myfile.md and date set to 2001-02-03)

            template: :file.html (default)
            output: somedir/myfile.html

            template: /:year/:month/:day/index.html
            output: 2001/02/03/index.html

            template: :year-:title.html
            output: somedir/2001-slugified-title.html

            template: /otherdir/{{ page.metadata.category }}/:basename
            output: otherdir/the-category/myfile.md

      ###

      template = @filenameTemplate
      dirname = path.dirname @filepath.relative
      basename = path.basename @filepath.relative
      file = env.utils.stripExtension basename
      ext = path.extname basename

      filename = replaceAll template,
        ':year': @date.getFullYear()
        ':month': ('0' + (@date.getMonth()+1)).slice(-2)
        ':day': ('0' + @date.getDate()).slice(-2)
        ':title': slugify(@title+'')
        ':file': file
        ':ext': ext
        ':basename': basename
        ':dirname': dirname

      # eval code wrapped in double moustaches, use with care ;)
      vm = ctx = null
      filename = filename.replace /\{\{(.*?)\}\}/g, (match, code) =>
        vm ?= require 'vm'
        ctx ?= vm.createContext {env: env, page: this}
        return vm.runInContext code, ctx

      if filename[0] is '/'
        # filenames starting with a slash are absolute paths in the content tree
        return filename.slice(1)
      else
        # otherwise they are resolved from their directory in the tree
        return path.join dirname, filename

    getUrl: (base) ->
      # remove index.html for prettier links
      super(base).replace /([\/^])index\.html$/, '$1'

    getView: ->
      @metadata.view or 'template'

    ### Page specific properties ###

    @property 'html', 'getHtml'
    getHtml: (base=env.config.baseUrl) ->
      ### return html with all urls resolved using *base* ###
      throw new Error 'Not implemented.'

    @property 'intro', 'getIntro'
    getIntro: (base) ->
      html = @getHtml(base)
      cutoffs = env.config.introCutoffs or ['<span class="more', '<h2', '<hr']
      idx = Infinity
      for cutoff in cutoffs
        i = html.indexOf cutoff
        if i isnt -1 and i < idx
          idx = i
      if idx isnt Infinity
        return html.substr 0, idx
      else
        return html

    @property 'filenameTemplate', 'getFilenameTemplate'
    getFilenameTemplate: ->
      @metadata.filename or env.config.filenameTemplate or ':file.html'

    ### Template property used by the 'template' view ###
    @property 'template', 'getTemplate'
    getTemplate: ->
      @metadata.template or env.config.defaultTemplate or 'none'

    @property 'title', ->
      @metadata.title or 'Untitled'

    @property 'date', ->
      new Date(@metadata.date or 0)

    @property 'rfc822date', ->
      env.utils.rfc822(@date)

    @property 'hasMore', ->
      @_html ?= @getHtml()
      @_intro ?= @getIntro()
      @_hasMore ?= (@_html.length > @_intro.length)
      return @_hasMore

  # add the page plugin to the env since other plugins might want to subclass it
  # and we are not registering it as a plugin itself
  env.plugins.Page = Page

  # register the template view used by the page plugin
  env.registerView 'template', templateView

  callback()
