title: Hello World
author: The Wintersmith
date: 2012-01-31 15:00

Welcome to your new wintersmith site. Have a look at the readme in the repository root for additional information.

An article can either be a markdown file in the articles folder or a directory with a
index.md any other contents in the directory will be copied over to the build output (useful for images, styles, etc).

An article is written with github flavored markdown with metadata on top, example:

```
title: My new shiny blog
author: Someone <someone@somewhere.com>
date: 2012-12-12 12:12

# Hello!

I'm an article. Bla bla bla so interesting.

```

The slug (permalink) for an article is determined by its filename (or directory name if using that format) but can  be overridden using if `slug: my-slug` is defined in the metadata.

Dates are parsed using the javascript date constructor, so you can use a vide variety of formats for `date:`.

All metadata you specify can be accessed in the templates, for example you could do something like this:


```
article.markdown

..
mood: Hungry
..

article.jade

..
div.article
  h1= article.title
  h2 author's mood =article.metadata.mood
..

```
