title: Hello World
author: the-wintersmith
date: 2012-01-31 15:00
template: article.jade

Welcome to your new wintersmith site mortal.

This is an example of how you can set up a blog with RSS, and an archive using Wintersmith.
If you want a bare bones example check out the site in `examples/basic/` in the repository root or
use `wintersmith new <path> --template basic` when creating a new site.

Site structure:

```
├── config.json                          site configuration and metadata
├── contents
│   ├── archive.md
│   ├── articles                         each article is a subfolder of articles
│   │   ├── another-test
│   │   │   └── index.md
│   │   ├── bamboo-cutter
│   │   │   ├── Taketori_Monogatari.jpg
│   │   │   └── index.md
│   │   ├── hello-world
│   │   │   └── index.md
│   │   └── red-herring
│   │       ├── banana.jpg
│   │       └── index.md
│   ├── authors                          if an author is set in an articles metadata it
│   │   ├── baker.json                   will be read from here
│   │   └── the-wintersmith.json
│   ├── css
│   │   ├── github.css
│   │   └── main.css
│   ├── feed.json                        json page that renders the rss feed to feed.xml
│   ├── index.json
└── templates
    ├── archive.jade
    ├── article.jade
    ├── author.jade
    ├── feed.jade
    ├── index.jade
    └── layout.jade
```

Articles are sorted by date and the 3 most recent are shown (configurable in `config.json`). All other articles
are avalible via their permalink or the archive page.

Example article/post:

```markdown
title: My new shiny blog
author: johndoe
date: 2012-12-12 12:12

# Hello!

I'm an article. Bla bla bla so interesting.

```
