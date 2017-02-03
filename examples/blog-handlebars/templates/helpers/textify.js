var _ = require('underscore');

module.exports = function(text, stripWhite) {
	var out= _.unescape(text.replace(/(<([^>]+)>)/ig,""));
	return (!stripWhite) ? out : out.replace(/\r?\n|\r/g,"");
}