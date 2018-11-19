## 2.5.0
*2018-11-19*

* Switch from `jade-legacy` to `pug` (thanks @sirodoht @VaelynPhi @SuriyaaKudoIsc @yusufhm)
* Upgrade to winston 3
* Upgrade to mime 2
* Upgrade to npm 6
* Update other dependencies minor versions (see https://github.com/jnordberg/wintersmith/commit/6e23ba624bbcd39f4a234429255991052bb780f0)
* [Fix rendering bug in blog example](https://github.com/jnordberg/wintersmith/pull/335)

## 2.4.0
*2017-05-15*

* [Better error reporting when template requires are missing](https://github.com/jnordberg/wintersmith/commit/5766cb533b503cc91dea03547dc9ce2698204240)
* [Update dependencies](https://github.com/jnordberg/wintersmith/commit/4d1beb7250d44841547cc667c1fe8fbc88e18c5b)
* Switched from `~` to `^` semver versioning for dependencies
* Update for npm 5

## 2.3.6
*2016-12-12*

* [Fix bug causing ignore option to break contents loading](https://github.com/jnordberg/wintersmith/commit/e0c5c5f799feb87e50f6acf4bed8e0ddc0d549a7)

## 2.3.5
*2016-12-11*

* [Depend on jade-legacy instead of deprecated jade module](https://github.com/jnordberg/wintersmith/commit/31ddafaa45306b3b8ac57cd99873c9157c703822)

## 2.3.4
*2016-12-11*

* [Update dependencies](https://github.com/jnordberg/wintersmith/commit/a5087b8abaf3589c0ebf897c9bcde24f8cd7d5d0)
* [Use npms.io for plugin listings instead of npm's built-in search](https://github.com/jnordberg/wintersmith/commit/5641e420e65c92f40e8ad1f2d6ee5acb4bdb1972)
* [Fix hardcoded http protocol in blog template](https://github.com/jnordberg/wintersmith/commit/053c36d5f3055534eaca9dd29b51707db1fe0e2d)

## 2.3.3
*2016-09-15*

* [Fix bug where the render callback could be called before the all the data where written to disk](https://github.com/jnordberg/wintersmith/commit/4e255568fb0a66b680e85d6c1948ba5448197f7c)

## 2.3.2
*2016-06-06*

* [Update dependencies](https://github.com/jnordberg/wintersmith/commit/5634b192d80c18f5d13c012a23c632cc086c2795)

## 2.3.1
*2016-02-29*

* [Fix regression where resolved filenames where no longer emitted with the 'change' event during preview](https://github.com/jnordberg/wintersmith/commit/145875ec1d502d57a6fdefbb8ed9404e53abb5b7)

## 2.3.0
*2016-02-24*

* [Removed individual file change monitoring during preview](https://github.com/jnordberg/wintersmith/commit/1f905cc2b48fe0fffd07dbc14bb7f10dc9b780e7)
* [Add config option to change the list of intro cutoff strings](https://github.com/jnordberg/wintersmith/pull/304)
* [Use laquo and raquo in blog template](https://github.com/jnordberg/wintersmith/pull/302)
* [Fallback to the normalized URI when determining the content type of files in the preview server](https://github.com/jnordberg/wintersmith/pull/303)
* [Update dependencies](https://github.com/jnordberg/wintersmith/commit/0a4489e3299c69a702381684820d1e5176f1867e)

## 2.2.5
*2016-01-02*

* [Added support for custom Highlight.js options](https://github.com/jnordberg/wintersmith/pull/297/files)
* [Fix bug where content nodes parent references where not being updated when trees where merged](https://github.com/jnordberg/wintersmith/pull/296/files) - refs [#295](https://github.com/jnordberg/wintersmith/issues/295)
* [Disable nunjucks autoescaping in webapp example](https://github.com/jnordberg/wintersmith/commit/d75b60c207eaae3ad7e252280fbc5e1a00388b99)
* [Update dependencies](https://github.com/jnordberg/wintersmith/commit/4911c15a5e79d46f020cdea8ad0320894dae45e6)
* Started keeping this changelog
