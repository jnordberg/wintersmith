
module.exports = (env, locals, contents, templates, callback) ->
  ### view that acts as a middleware and adds articles to locals then
      passes it along to the default 'template' view ###
  articles = env.helpers.getArticles contents # getArticles provided by the paginator plugin
  locals.articles = articles
  env.views.template.apply this, arguments
