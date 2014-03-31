# {{{1 Notes
#
# User interface:
#
# - info
#   - touch'n'move = draw
#   - touch'n'hold = menu
#   - 2 fingers = pan/zoom
#   - solsort.com
# - menu
#   - clear
#   - save
#   - load
#   - png
#   - scroll 
#   - zoom
#   - on screen menu
#   - login
# - load
#   - thumbnails with date + `next`
#
# Implementation:
# - saved drawing
#   - thumbnail 80x80
#   - most-recent-edit-time
#   - list of strokes
#     - `size`
#     - `(time, x, y)*`
# - visualisation
#   - 3x canvas (2xscreensize): zoom, outer, rerender
#   - transformation matrix
#   - current strokes
#
# {{{1 Boilerplate
# predicates that can be optimised away by uglifyjs
if typeof isNodeJs == "undefined" or typeof runTest == "undefined" then do ->
  root = if typeof window == "undefined" then global else window
  root.isNodeJs = (typeof process != "undefined") if typeof isNodeJs == "undefined"
  root.isWindow = (typeof window != "undefined") if typeof isWindow == "undefined"
  root.isPhoneGap = typeof document?.ondeviceready != "undefined" if typeof isPhoneGap == "undefined"
  root.runTest = (if isNodeJs then process.argv[2] == "test" else location.hash.slice(1) == "test") if typeof runTest == "undefined"

# use - require/window.global with non-require name to avoid being processed in firefox plugins
use = if isNodeJs then ((module) -> require module) else ((module) -> window[module]) 
# execute main
onReady = (fn) ->
  if isWindow
    if document.readystate != "complete" then fn() else setTimeout (-> onReady fn), 17 
# {{{1 Actual code

t = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
info = (args...) ->
  t.shift()
  t.push args
  log.innerHTML = JSON.stringify t

strokes = []
stroke = []
transform = false
hold = false

rootX = rootX0 = 0
rootY = rootY0 = 0
scale = scale0 = 1

ctx = undefined

redraw = ->
  ctx.clearRect 0, 0, canvas.width, canvas.height
  for stroke in strokes
    ctx.beginPath()
    ctx.moveTo (stroke[0] + rootX) * scale, (stroke[1] + rootY) * scale
    for i in [2..stroke.length] by 2
      ctx.lineTo (stroke[i] + rootX) * scale, (stroke[i + 1] + rootY) * scale
    ctx.stroke()

drawSegment = (x0, y0, x1, y1) ->
  ctx.beginPath()
  ctx.moveTo (x0 + rootX) * scale, (y0 + rootY) * scale
  ctx.lineTo (x1 + rootX) * scale, (y1 + rootY) * scale
  ctx.stroke()

layout = ->
  canvas.style.position = "absolute"
  canvas.style.top = "0px"
  canvas.style.left = "0px"
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight

onReady ->
  ctx = canvas.getContext "2d"
  layout()
  events = Hammer(window)

  events.on "drag", (e)->
    x = (e.gesture.touches[0].clientX) / scale - rootX
    y = (e.gesture.touches[0].clientY) / scale - rootY
    drawSegment stroke[stroke.length - 2], stroke[stroke.length - 1], x, y
    stroke.push x, y

  events.on "dragstart", (e) ->
    x = (e.gesture.touches[0].clientX) / scale - rootX
    y = (e.gesture.touches[0].clientY) / scale - rootY
    stroke = [x, y]
    console.log "dragstart"
    transform = false
    hold = false

  events.on "transformstart transformend", ->
    transform = true

  events.on "transformstart", (e) ->
    scale0 = scale
    rootX0 = rootX - e.gesture.deltaX
    rootY0 = rootY - e.gesture.deltaY / scale

  events.on "transform", (e) ->
    rootX = rootX0 + e.gesture.deltaX / scale
    rootY = rootY0 + e.gesture.deltaY / scale
    scale = scale0 * e.gesture.scale
    redraw()


  events.on "hold tap", (e) ->
    console.log e
    hold = true
    redraw()
    #menu()

  events.on "dragend", ->
    if !transform and !hold
      strokes.push stroke
    else
      redraw()
