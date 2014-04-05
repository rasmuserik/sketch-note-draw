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
#{{{1 Actual code

#{{{2 state
strokes = []
stroke = []
transform = false
hold = false

rootX = 0
rootY = 0
scale = 1

ctx = undefined
kind = undefined
multitouch = undefined

#{{{2 draw+layout
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
#{{{2 Utility
dist = (x0,y0,x1,y1) ->
  dx = x0 - x1
  dy = y0 - y1
  Math.sqrt(dx*dx + dy*dy)

#{{{2 handle touches
onReady ->
  ctx = canvas.getContext "2d"
  layout()

  #{{{2 touchstart
  uu.domListen canvas, "touchstart", (e) ->
    e.preventDefault()
    if 1 == e.touches.length
      x = (e.touches[0].clientX) / scale - rootX
      y = (e.touches[0].clientY) / scale - rootY
      stroke = [x, y]
      kind = "draw"
    else if 2 == e.touches.length
      kind = "multitouch"
      multitouch =
        x: (e.touches[0].clientX + e.touches[1].clientX) / 2 / scale - rootX
        y: (e.touches[0].clientY + e.touches[1].clientY) / 2 / scale - rootY
        dist: dist e.touches[0].clientX, e.touches[0].clientY, e.touches[1].clientX, e.touches[1].clientY
        rootX: rootX
        rootY: rootY
        scale: scale

  #{{{2 touchmove
  uu.domListen canvas, "touchmove", (e) ->
    e.preventDefault()
    ctx.fillText JSON.stringify([kind, e.touches.length]), 10, 10

    if "draw" == kind
      x = (e.touches[0].clientX) / scale - rootX
      y = (e.touches[0].clientY) / scale - rootY
      drawSegment stroke[stroke.length - 2], stroke[stroke.length - 1], x, y
      stroke.push x, y

    if 2 == e.touches.length
      current =
        x: (e.touches[0].clientX + e.touches[1].clientX) / 2 / multitouch.scale - multitouch.rootX
        y: (e.touches[0].clientY + e.touches[1].clientY) / 2 / multitouch.scale - multitouch.rootY
        dist: dist e.touches[0].clientX, e.touches[0].clientY, e.touches[1].clientX, e.touches[1].clientY
      scale = multitouch.scale * current.dist / multitouch.dist
      rootX = (current.x + multitouch.rootX) * multitouch.scale / scale - multitouch.x
      rootY = (current.y + multitouch.rootY) * multitouch.scale / scale - multitouch.y
      uu.nextTick redraw()

  #{{{2 touchend
  uu.domListen canvas, "touchend", (e) ->

    if "draw" == kind
      strokes.push stroke

    kind = "end"

  #{{{2 resize
  uu.domListen window, "resize", (e) ->
    layout()

