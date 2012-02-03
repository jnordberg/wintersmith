#![Wintersmith](http://jnordberg.github.com/wintersmith/img/wintersmith.svg)

A flexible static site generator.

## Features

 * Easy to use
 * Generated sites can be hosted anywhere (output is plain html)
 * Write articles/pages using markdown
 * Robust templating using [Jade](https://github.com/visionmedia/jade)
 * Preview server (no need to rebuild every time you make a change)
 * Highly configurable
 * FAST!

## Quickstart

First install wintersmith using [npm](http://npmjs.org/):

```bash
$ npm install wintersmith -g
```

This will install wintersmith globally on your system so that you can access the `wintersmith` command from anywhere. Once that is complete run:

```bash
$ wintersmith new <path>
```

Where `<path>` is the location you want the site to be generated. This creates a skeleton site with a basic set of templates and some articles, while not strictly needed it's a good starting point.

Now enter the directory and start the preview server:

```bash
$ cd <path>
$ wintersmith preview
```

At this point you are ready to start customizing your site. Point your browser to `http://localhost:8080` and start editing templates and articles.

When done run:

```bash
$ wintersmith build
```

This generates your site and places it in the `build/` directory - all ready to be copied to your webserver!

And remember to give the old `--help` a look :-)

## Config

Configuration can be done with command-line options, a config file or both. The config file will be looked for as `config.json` in the root of your site (you can set a custom path using `--config`).

### Options

<table>
  <tr>
    <th>Name</th>
    <th>Default</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>output</td>
    <td>./build</td>
    <td>output directory, this is where the generated site is output</td>
  </tr>
  <tr>
    <td>articles</td>
    <td>./articles</td>
    <td>article directory, where to look for markdown files</td>
  </tr>
  <tr>
    <td>templates</td>
    <td>./templates</td>
    <td>template directory, where to look for Jade templates</td>
  </tr>
  <tr>
    <td>static</td>
    <td>./static</td>
    <td>static file directory, all static content for your site (css, images, etc)</td>
  </tr>
  <tr>
    <td>locals</td>
    <td>{}</td>
    <td>javascript object to pass to all templates when rendering, useful for storing metadata for your site. can also be a path to a json file</td>
  </tr>
  <tr>
    <td>rebuild</td>
    <td>false</td>
    <td>whether to force a rebuild of all articles</td>
  </tr>
  <tr>
    <td>clean</td>
    <td>false</td>
    <td>whether to empty output directory before building</td>
  </tr>
</table>

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

*© 2012 FFFF00 Agents AB*








