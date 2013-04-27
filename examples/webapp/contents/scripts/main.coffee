require './vendor/es5-shim'
ready = require './vendor/ready'

class Cylon
  ### Just a stupid Hello World example ###

  constructor: (@element) ->
    text = @element.innerHTML
    @element.innerHTML = ''
    @letters = []
    for letter in text
      el = document.createElement 'span'
      el.innerHTML = letter
      @element.appendChild el
      @letters.push el

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
      a = Math.sin (time / 300) - 5 * (i / @letters.length)
      a = (a + 1) / 2
      rgb = [10 + parseInt(a * 245), 10, 10]
      el.style.color = "rgb(#{ rgb.join(',') })"
      el.style.textShadow = "0 0 #{ a / 12 }em red"

main = ->
  cylon = new Cylon document.querySelector 'h1'
  cylon.start()

ready main
