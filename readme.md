#![Wintersmith](http://jnordberg.github.com/wintersmith/img/wintersmith.svg)

A flexible static site generator – http://jnordberg.github.com/wintersmith/

## Features

 * Easy to use
 * Generated sites can be hosted anywhere (output is plain html)
 * Write articles/pages using markdown
 * Robust templating using [Jade](https://github.com/visionmedia/jade)
 * Preview server (no need to rebuild every time you make a change)
 * Highly configurable
 * Extendable using [plugins](https://github.com/jnordberg/wintersmith/wiki/Plugins)
 * FAST!

## Quick-start

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

This generates your site and places it in the `build/` directory - all ready to be copied to your web server!

And remember to give the old `--help` a look :-)

## Overview

A wintersmith site is built up of two main components, contents and templates.

Contents is a directory where all the sites raw material goes (markdown files, images, javascript etc). This directory is then scanned to produce what's internally called a ContentTree.

The ContentTree is a nested object built up of ContentPlugins and looks something like this:

```javascript
{
  "myfile.md": {MarkdownPlugin} // plugin instance, subclass of ContentPlugin
  "some-dir/": { // another ContentTree instance
    "image.jpg": {StaticPlugin}
    "random.file": {StaticPlugin}
  }
}
```

This content tree is provided in full to all plugins in turn when rendering. This gives you a lot of flexibility when writing plugins, you could for example write a plugin that generates a mosaic using images located in a specific directory.

Wintersmith comes with a default Page plugin that renders markdown content using templates. This plugin takes markdown (combined with some metadata, more on this later) compiles it and provides it to a template along with the content tree and some utility functions.

This brings us to the second component, the template directory. All templates found in this directory are loaded and are also passed to the content plugins when rendering.

By default only `.jade` templates are loaded, but you can easily add template plugins to use a template engine of your choosing.

Check the `examples/` directory for some inspiration on how you can use wintersmith or the [showcase](https://github.com/jnordberg/wintersmith/wiki/Showcase) to see what others are doing.

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
    <td>contents</td>
    <td>./contents</td>
    <td>contents directory, where to look for site contents (markdown, images, etc)</td>
  </tr>
  <tr>
    <td>templates</td>
    <td>./templates</td>
    <td>template directory, where to look for templates</td>
  </tr>
  <tr>
    <td>locals</td>
    <td>{}</td>
    <td>javascript object to pass to all templates when rendering, useful for storing metadata for your site. can also be a path to a json file</td>
  </tr>
  <tr>
    <td>require</td>
    <td>[]</td>
    <td>list of modules to load and provide to the template context</td>
  </tr>
  <tr>
    <td>plugins</td>
    <td>[]</td>
    <td>list of plugin modules to load</td>
  </tr>
  <tr>
    <td>ignore</td>
    <td>[]</td>
    <td>list of files/globpatterns in contents to ignore</td>
  </tr>
</table>

All paths can either be relative or absolute. Relative paths will be resolved from the current directory or `--chdir` if set.

## The Page plugin

A page is either a markdown file with metadata on top or a json file located in the contents directory.

```markdown
---
title: My first post
date: 2012-12-12 12:12
author: John Hjort <foo@bar.com>
template: article.jade
----

# Hello friends!

Life is wonderful, isn't it?

```

or use json to simply pass metadata to a template:

```json
{
  "template": "template.jade",
  "meta": {
  	"greta": 123,
  	"peta": [1, 2, 3]
  }
}
```

Pages will be rendered as html, so for example `index.md` would be rendered to `index.html` and `some-dir/data.json` to `some-dir/data.html`.

### Links

All relative links in the markdown will be resolved correctly when rendering. This means you can just place *image.png* in the same directory and simply include it in your markdown as `![my image](image.png)`

This is especially convenient when using a markdown editor (read [Mou](http://mouapp.com/) if you're on a mac).

### Metadata

Metadata is parsed using [js-yaml](https://github.com/nodeca/js-yaml) and will be accessible in the template as `page.metadata`.

There are two special metadata keys, The first one is `template` which specifies what template to render the page with. If the key is omitted or set to `none` the page will not be rendered (but still available in the content tree).

The second one is `filename` which can be used to override the output filename of the page. Useful if you need to output a `.xml` file or something similar.

### Templates

When a page is rendered to a template the page instance is available as `page` in the template context. The content tree is also available as `contents` and the config.locals object as `locals`.

[underscore.js](http://documentcloud.github.com/underscore/) is also available as `_` to provide some utility to aid you sorting and filtering the content tree.

### The Page model

The Page model (inherits from ContentPlugin)

Properties:

<table>
  <tr>
    <td>metadata</td>
    <td>the metadata object</td>
  </tr>
  <tr>
    <td>title</td>
    <td>`metadata.title` or `Untitled`</td>
  </tr>
  <tr>
    <td>date</td>
    <td>Date object from `metadata.date` if set or unix epoch time</td>
  </tr>
  <tr>
    <td>rfc822date</td>
    <td>a rfc-822 formatted string made from `date`</td>
  </tr>
  <tr>
    <td>body</td>
    <td>unparsed markdown content</td>
  </tr>
  <tr>
    <td>html</td>
    <td>parsed markdown content</td>
  </tr>
</table>

## Writing plugins

Wintersmith has two types of plugins, content plugins that transform contents and template plugins that are provided to the content plugins to help render contents.

A list of 3rd party plugins can be found on [the wiki](https://github.com/jnordberg/wintersmith/wiki/Plugins).


### Content Plugins

A content plugin is a subclass of `ContentPlugin` and should provide a `fromFile` class method, a `render` instance method and a `getFilename` instance method.

`render` is called with the content tree, template list, locals and a callback. Have a look in `src/contents.coffee` it's pretty well documented.

Content plugins are registered using the `registerContentPlugin` function.

<table>
  <tr>
    <th colspan=2>registerContentPlugin(group, pattern, plugin)</th>
  </tr>
  <tr>
    <td>group</td>
    <td>
      <p><em>string</em> - plugin group name

      <p>Groups are used to easily access a specific type of content in the tree. The content tree has a special property <code>_</code> that returns a object with all plugin groups as <code>{groupname: [pluginInstance, ..], ..}</code>

      <p>For example you can use <code>contents.somedir._.pages</code> to get an array of all pages in a directory.
    </td>
  </tr>
  <tr>
    <td>pattern</td>
    <td>
      <p><em>string</em> - glob pattern (e.g. <code>**/*.txt</code>)

      <p>Glob pattern used to match files that should be handled by the plugin. Uses the [minimatch](https://github.com/isaacs/minimatch) module.
    </td>
  </tr>
  <tr>
    <td>plugin</td>
    <td>
      <p><em>class</em> - the ContentPlugin subclass
    </td>
  </tr>
</table>


### Template Plugins

A template plugins is a subclass of `TemplatePlugin` and should also provide a `fromFile` class method and a `render` instance method.

Template plugins are registered using:

`function registerTemplatePlugin(pattern, plugin) { .. }`

where *pattern* is the glob pattern to match in the template directory and plugin is the plugin subclass.

### Plugin Modules

The easiest way to load a wintersmith plugin is to use the `plugins` config option.

Example:

`myplugin.coffee`

```coffeescript

module.exports = (wintersmith, callback) ->

  class TextPlugin extends wintersmith.ContentPlugin

    constructor: (@_filename, @_text) ->

    getFilename: ->
      @_filename

    render: (locals, contents, templates, callback) ->
      # do something with the text!
      callback null, new Buffer @_text

  TextPlugin.fromFile = (filename, base, callback) ->
    fs.readFile path.join(base, filename), (error, buffer) ->
      if error
        callback error
      else
        callback null, new TextPlugin filename, buffer.toString()

  wintersmith.registerContentPlugin 'text', '**/*.txt', TextPlugin
  callback() # tell the plugin manager we are done

```

To use this plugin simply pass the path to the file to the cli tool (`--plugins ./myplugin.coffee`)

You can also use globally or locally installed modules as plugins.

## Using wintersmith programmatically

example:

```javascript

var wintersmith = require('wintersmith');

var options = {
  'output': '/var/www/pub',
  'contents': '/foo/contents',
  'contents': '/foo/templates',
  'plugins': ['some-plugin'],
  'locals': {foo: 'bar'}
};

wintersmith(options, callback(error) {
  if (error) {
    throw error;
  } else {
	console.log('great success!');
  }
});

// you can also use the api to get the content tree
wintersmith.loadContents('path/to/contents', callback(error, contents) {
  // do something with the content tree
});

```

There are more API methods defined, have a look at the source it's pretty well-commented.

## About

Wintersmith is written by [Johan Nordberg](http://johan-nordberg.com) using [CoffeeScript](http://coffeescript.org/) and licensed under the [MIT-license](http://en.wikipedia.org/wiki/MIT_License).

The name is a nod to [blacksmith](https://github.com/flatiron/blacksmith) which inspired this project (and [Terry Pratchett](http://www.terrypratchett.co.uk/) of course).

Some of the great node.js modules that wintersmith uses:

 * [async](https://github.com/caolan/async)
 * [marked](https://github.com/chjj/marked)
 * [jade](https://github.com/visionmedia/jade)
 * [coffee-script](https://github.com/jashkenas/coffee-script)

Check the `package.json` for a complete list.


----

*© 2012 FFFF00 Agents AB*
