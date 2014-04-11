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
redo = []
nextStroke = undefined
nextPath = undefined
currentStroke =
  prev: null
  path: []
  date: 1
allStrokes =
  1: currentStroke
transform = false
hold = false

rootX = 0
rootY = 0
scale = 1

ctx = undefined
kind = undefined
multitouch = undefined
hasTouch = false
panPos = undefined

#{{{2 draw+layout
redraw = ->
  ctx.fillStyle = "white"
  ctx.fillRect 0, 0, canvas.width, canvas.height
  ctx.fillStyle = "black"
  ctx.lineWidth = Math.sqrt(canvas.width * canvas.height) * 0.002

  stroke = currentStroke
  while stroke.prev
    path = stroke.path
    ctx.beginPath()
    ctx.moveTo (path[0] + rootX) * scale, (path[1] + rootY) * scale
    for i in [2..path.length] by 2
      ctx.lineTo (path[i] + rootX) * scale, (path[i + 1] + rootY) * scale
    ctx.stroke()
    stroke = allStrokes[stroke.prev]

drawSegment = (x0, y0, x1, y1) ->
  ctx.beginPath()
  ctx.moveTo (x0 + rootX) * scale, (y0 + rootY) * scale
  ctx.lineTo (x1 + rootX) * scale, (y1 + rootY) * scale
  ctx.stroke()

layout = ->
  window.devicePixelRatio ?= 1
  canvas.style.position = "absolute"
  canvas.style.top = "0px"
  canvas.style.left = "0px"
  canvas.height = window.innerHeight * window.devicePixelRatio | 0
  canvas.width = window.innerWidth * window.devicePixelRatio | 0
  canvas.style.width = "#{window.innerWidth}px"
  canvas.style.height= "#{window.innerHeight}px"
  console.log window.innerWidth, window.devicePixelRatio, canvas.width
  addButtons()
  redraw()
#{{{2 Utility
dist = (x0,y0,x1,y1) ->
  dx = x0 - x1
  dy = y0 - y1
  Math.sqrt(dx*dx + dy*dy)

#{{{2 touch
touchstart = (x,y) ->
  nextPath = [x/scale-rootX, y/scale-rootY]
  nextStroke =
    prev: currentStroke.date
    path: nextPath
    date: Date.now()
  kind = "draw"
  multitouch = undefined

touchend = ->
  if "draw" == kind
    allStrokes[nextStroke.date] = nextStroke
    currentStroke = nextStroke
  kind = "end"

touchmove = (x0, y0, x1, y1) ->
  if "draw" == kind
    x = (x0) / scale - rootX
    y = (y0) / scale - rootY
    drawSegment nextPath[nextPath.length - 2], nextPath[nextPath.length - 1], x, y
    nextPath.push x, y

  if "pan" == kind
    if panPos
      rootX += (x0 - panPos.x) / scale
      rootY += (y0 - panPos.y) / scale
      redraw()

    panPos =
      x: x0
      y: y0


  if "number" == typeof x1
    kind = "multitouch"
    if ! multitouch
      kind = "multitouch"
      multitouch =
        x: (x0 + x1) / 2 / scale - rootX
        y: (y0 + y1) / 2 / scale - rootY
        dist: dist x0, y0, x1, y1
        rootX: rootX
        rootY: rootY
        scale: scale
    else
      current =
        x: (x0 + x1) / 2 / multitouch.scale - multitouch.rootX
        y: (y0 + y1) / 2 / multitouch.scale - multitouch.rootY
        dist: dist x0, y0, x1, y1
      scale = multitouch.scale * current.dist / multitouch.dist
      rootX = (current.x + multitouch.rootX) * multitouch.scale / scale - multitouch.x
      rootY = (current.y + multitouch.rootY) * multitouch.scale / scale - multitouch.y
      uu.nextTick redraw()

#{{{2 buttons
buttonList = ["pan", "files", "undo", "redo", "pan", "pan", "info", "zoomin", "zoomout", "pan"]

buttonAwesome =
  pan: "arrows"
  zoomin: "search-plus"
  zoomout: "search-minus"
  undo: "undo"
  redo: "repeat"
  new: "square-o"
  download: "download"
  save: "cloud-upload gray"
  load: "cloud-download gray"
  info: "question"
  files: "th"

zoomFn = ->
  if "zoomin" == kind || "zoomout" == kind
    setTimeout zoomFn, 20
    zoomScale = if kind == "zoomin" then 1.05 else 1/1.05
    scale *= zoomScale
    rootX += canvas.width / scale * (1 - zoomScale) / 2
    rootY += canvas.height / scale * (1 - zoomScale) / 2
    setTimeout redraw, 0

buttonFns =
  pan: -> panPos = undefined
  download: ->
    a = document.createElement "a"
    a.download = "sketch-note-draw.png"
    a.href = canvas.toDataURL()
    a.target = "_blank"
    document.body.appendChild a
    a.click()
    document.body.removeChild a
  zoomin: zoomFn
  zoomout: zoomFn
  undo: -> if currentStroke.prev
    redo.push currentStroke
    currentStroke = allStrokes[currentStroke.prev]
    redraw()
  redo: -> if redo.length
    currentStroke = redo.pop()
    redraw()
  new: -> if strokes.length
    currentStroke = allStrokes[1]
    redraw()
buttonFns.files = buttonFns.new # TODO

addButtons = ->
  buttons = document.getElementById "buttons"
  buttons.innerHTML = ""
  for i in [0..buttonList.length - 1]
    buttonId = buttonList[i]
    button = document.createElement "i"
    button.className = "fa fa-#{buttonAwesome[buttonId]}"
    ((buttonId) ->
      touchhandler = (e) ->
        e.stopPropagation()
        e.preventDefault()
        kind = buttonId
        buttonFns[buttonId]?()
      button.ontouchstart = (e) -> hasTouch = true; touchhandler e
      button.onmousedown = (e) -> (touchhandler e if !hasTouch)
    )(buttonId)
    button.style.WebkitTapHighlightColor = "rgba(0,0,0,0)"
    button.style.tapHighlightColor = "rgba(0,0,0,0)"
    button.style.position = "absolute"
    button.style.fontSize = "36px"
    button.style.padding = "4px"
    button.style.top = if i < 5 then "0px" else "#{window.innerHeight - 44}px"
    s = (window.innerWidth - 5*44) / 4 + 44
    button.style.left = "#{(i % 5) * s}px"
    buttons.appendChild button

#{{{2 onReady
onReady ->
  ctx = canvas.getContext "2d"
  layout()

  uu.domListen window, "touchstart", (e) ->
    e.preventDefault()
    hasTouch = true
    touchstart(e.touches[0].clientX * devicePixelRatio, e.touches[0].clientY * devicePixelRatio) if 1 == e.touches.length

  uu.domListen window, "mousedown", (e) ->
    e.preventDefault()
    touchstart(e.clientX * devicePixelRatio, e.clientY * devicePixelRatio) if !hasTouch

  uu.domListen window, "touchmove", (e) ->
    e.preventDefault()
    args = []
    for touch in e.touches
      args.push touch.clientX * devicePixelRatio
      args.push touch.clientY * devicePixelRatio
    touchmove args...

  uu.domListen window, "mousemove", (e) ->
    e.preventDefault()
    touchmove e.clientX * devicePixelRatio, e.clientY * devicePixelRatio


  uu.domListen window, "touchend", (e) -> touchend()
  uu.domListen window, "mouseup", (e) -> (touchend() if !hasTouch)
  uu.domListen window, "resize", (e) -> layout()

