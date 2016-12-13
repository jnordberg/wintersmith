
class MiddlewarePlugin

	###*
	 * [property description]
	 * @param  {[type]} name   [description]
	 * @param  {[type]} getter [description]
	 * @return {[type]}        [description]
	###
	@property = (name, getter) ->
		### Define read-only property with *name*. ###
		if typeof getter is 'string'
			get = -> this[getter].call this
		else
			get = -> getter.call this
		Object.defineProperty @prototype, name,
			get: get
			enumerable: true

	###*
	 * [dispatch description]
	 * @param  {[type]}   request  [description]
	 * @param  {[type]}   response [description]
	 * @param  {Function} next     [description]
	 * @return {[type]}            [description]
	###
	dispatch: (request, response, next) ->


###*
 * [loadMiddleware description]
 * @param  {[type]}   env      [description]
 * @param  {Function} callback [description]
 * @return {[type]}            [description]
###
loadMiddleware = (env, callback)->

    middleware = []

    if env.middlewarePlugins?

      for plugin in env.middlewarePlugins
        middleware.push new plugin.class()

    callback null, middleware


module.exports = {MiddlewarePlugin, loadMiddleware}
