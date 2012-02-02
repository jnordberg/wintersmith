# Wintersmith

A flexible static site generator.

## Features

 * Easy to use
 * Generated sites can be hosted anywhere (output is plain html)
 * Write articles/pages using markdown
 * Robust templating using [Jade](https://github.com/visionmedia/jade)
 * Preview server (no need to rebuild every time you make a change)
 * Highly configurable
 * FAST!

## Get going

Simple steps to getting started:

	[sudo] npm install wintersmith -g
	wintersmith new ~/my-site
	cd ~/my-site
	wintersmith preview

Now point your browser to `http://localhost:8080` and start editing templates and adding articles. When you are done run `wintersmith build` and the site will be generated.

Also give the old `--help` a look.

## Config

Configuration can be done with command-line options, a config file or both. The config file will be looked for as `config.json` in the root of your site. (you can set a custom path using `--config`)

### Options

 * output
	* output directory, this is where the generated site is output
	* default: `./build`
 * articles
	* article directory, where to look for markdown files
    * default: `./articles`
 * templates
    * template directory, where to look for Jade templates
    * default: `./templates`
 * static
    * static file directory, all static content for your site (css, images, etc)
    * default: `./static`
 * locals
    * javascript object to pass to all templates when rendering, useful for storing metadata for your site. can also be a path to a json file
    * default: `{}`
 * rebuild
	* if set all articles will be rebuilt
	* default: `false`
 * clean
	* if set output directory will emptied before build starts
	* default: `false`

All paths can either be relative or absolute. Relative paths will be resolved from the current directory or `--chdir` if set.

## Articles

An article is a markdown file combined with metadata on top

example:

```markdown
title: My first post
date: 2012-12-12 12:12
author: John Hjort <foo@bar.com>

# Hello friends!

Life is wonderful, isn't it?

```

### Article types

There are two article formats, either a markdown file in the root of your articles directory or a directory with a markdown index file.

If you use a directory all other contents in the it are copied when building, this allows you to easily add images, scripts etc specific to the article.

File extensions can be either `.md` or `.markdown`

### Links

All relative links used will be resolved correctly when rendering. This means you can just place *image.png* in your article directory and simply include it in your markdown as `![my image](image.png)`

This is especially convenient when using a markdown editor (read [Mou](http://mouapp.com/) if you're on a mac).

### Metadata

Metadata can be any `key: value` pair you want. And will be accessible in the article template as `article.metadata`.

There are two special metadata keys. The first one is `date`, articles will be sorted by this value. The date is parsed using JavaScript's Date constructor - so you can be very flexible on how you write your dates.

The second one is `slug`, if set it will override the location the article is built at (wich defaults to the articles filename)

### The Article model

Model for the article object passed to templates.

Properties:

  * `title` - `metadata.title` or `Untitled`
  * `date` - Date object from `metadata.date` or unix epoch time.
  * `slug` - article url `metadata.slug` or slugified version of `filename`
  * `filename` - path to article's markdown file
  * `files` - array with paths to all files included in article
  * `rfc822date` - a rfc-822 formatted string made from `date`
  * `body` - unparsed markdown content
  * `html` - shortcut for `getHtml`

Methods:

 * `getHtml(baseURL='/')` - parses `body` and resolves all relative urls using `baseURL`. Have a look at the example site's feed.jade to see how this can be used.

## Templates

Templating are done using [Jade](https://github.com/visionmedia/jade) and all templates are rendered out to `<template-name>.html` with a few exceptions.

  * `article.jade`
     this is the article template, rendered once for every article. the `article` object is available in its context.

  * `feed.jade`
    RSS-feed, only difference from a normal template is that it's rendered to `/feed.xml`

### Locals

Locals are the template variables, you can extend them in the config file. Avalible in all templates as `locals`.

Also all templates except `article.jade` have `articles` defined which is an array containing all articles.


## Static content

All files in the `options.static` directory are simply copied over to the root of output.

## Using wintersmith programmatically

example:

```javascript

var wintersmith = require('wintersmith');

var options = {
  'output': '/var/www/pub',
  'articles': '/foo/articles',
  'templates': '/foo/templates',
  'articles': '/foo/articles',
  'static': '/foo/articles',
  'locals': {foo: 'bar'}
};

wintersmith(options, callback(error) {
  if (error) {
    throw error;
  } else {
	console.log('great success!');
  }
});

// you can also use the api to get the articles for example
wintersmith.loadArticles('path/to/articles', callback(error, articles) {
  // do something with articles
});

```

There are more api methods defined, have a look at the source it's pretty well-commented.

## About

Wintersmith is written by [Johan Nordberg](http://johan-nordberg.com) using [CoffeeScript](http://coffeescript.org/) and licensed under the [MIT-license](http://en.wikipedia.org/wiki/MIT_License).

The name is a nod to [blacksmith](http://en.wikipedia.org/wiki/MIT_License) which  inspired this project. (and [Terry Pratchett](http://www.terrypratchett.co.uk/) of course)

Some of the great node.js projects that wintersmith uses:

 * [async](https://github.com/caolan/async)
 * [marked](https://github.com/chjj/marked)
 * [jade](https://github.com/visionmedia/jade)
 * [coffee-script](https://github.com/jashkenas/coffee-script)

Check the `package.json` for a complete list.


----

*Copyright 2012 FFFF00 Agents AB*








