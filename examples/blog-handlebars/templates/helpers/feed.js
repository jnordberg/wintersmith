module.exports = function(env, contents, options) {
	var out="";
	env.helpers.getArticles(contents).forEach(function(article){
		out+= options.fn(article);
	});
	return out;
}