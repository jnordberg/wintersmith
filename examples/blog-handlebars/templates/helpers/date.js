module.exports = function(context, block) {
	if (context=="now"){
		context = new Date();
	}
    var f = block.hash.format || "MMM Do, YYYY";
    return moment(context).format(f);
}