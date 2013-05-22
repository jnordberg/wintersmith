ready = require './vendor/ready'
require 'browsernizr/test/css/rgba'
require 'browsernizr/test/css/transforms3d'
Modernizr = require 'browsernizr'

getTransformProperty = (element) ->
  properties = ['transform', 'WebkitTransform', 'msTransform', 'MozTransform', 'OTransform']
  for prop in properties
    return prop if element.style[prop]?
  return properties[0]

class Cylon
  ### Just a stupid Hello World example ###

  constructor: (@element) ->
    text = @element.innerHTML
    @element.innerHTML = ''
    @letters = []
    for letter in text
      el = document.createElement 'span'
      el.innerHTML = letter.replace ' ', '&nbsp;'
      @element.appendChild el
      @letters.push el
    @tprop = getTransformProperty @element

  start: ->
    last = Date.now()
    step = =>
      time = Date.now()
      delta = time - last
      @step time, delta
      last = time
      return
    @timer = setInterval step, 1000 / 30
    step()

  stop: ->
    clearInterval @timer
    @timer = null

  step: (time, delta) ->
    for el, i in @letters
      a = Math.sin (time / 400) - 5 * (i / @letters.length)
      a = (a + 1) / 2
      rgb = [10 + Math.round(a * 245), 10, 10]
      el.style.color = "rgb(#{ rgb.join(',') })"
      el.style.textShadow = "0 0 #{ a / 12 }em red"
      if Modernizr.csstransforms3d
        el.style[@tprop] = "rotateX(#{ -20 + a * 40 }deg)"

main = ->
  cylon = new Cylon document.querySelector 'h1'
  cylon.start()

ready main
