# sketch-note-draw 0.0.0

Simple sketching program, with clean interface

# Notes

User interface:

- info
  - touch'n'move = draw
  - touch'n'hold = menu
  - 2 fingers = pan/zoom
  - solsort.com
- menu
  - clear
  - save
  - load
  - png
  - scroll 
  - zoom
  - on screen menu
  - login
- load
  - thumbnails with date + `next`

Implementation:
- saved drawing
  - thumbnail 80x80
  - most-recent-edit-time
  - list of strokes
    - `size`
    - `(time, x, y)*`
- visualisation
  - 3x canvas (2xscreensize): zoom, outer, rerender
  - transformation matrix
  - current strokes

# Boilerplate
predicates that can be optimised away by uglifyjs

    if typeof isNodeJs == "undefined" or typeof runTest == "undefined" then do ->
      root = if typeof window == "undefined" then global else window
      root.isNodeJs = (typeof process != "undefined") if typeof isNodeJs == "undefined"
      root.isWindow = (typeof window != "undefined") if typeof isWindow == "undefined"
      root.isPhoneGap = typeof document?.ondeviceready != "undefined" if typeof isPhoneGap == "undefined"
      root.runTest = (if isNodeJs then process.argv[2] == "test" else location.hash.slice(1) == "test") if typeof runTest == "undefined"
    

use - require/window.global with non-require name to avoid being processed in firefox plugins

    use = if isNodeJs then ((module) -> require module) else ((module) -> window[module]) 

execute main

    onReady = (fn) ->
      if isWindow
        if document.readystate != "complete" then fn() else setTimeout (-> onReady fn), 17 

# Actual code

    

## state

    strokes = []
    redo = []
    stroke = []
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
    

## draw+layout

    redraw = ->
      ctx.fillStyle = "white"
      ctx.fillRect 0, 0, canvas.width, canvas.height
      ctx.fillStyle = "black"
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
      addButtons()
      redraw()

## Utility

    dist = (x0,y0,x1,y1) ->
      dx = x0 - x1
      dy = y0 - y1
      Math.sqrt(dx*dx + dy*dy)
    

## touch

    touchstart = (x,y) ->
      stroke = [x/scale-rootX, y/scale-rootY]
      kind = "draw"
      multitouch = undefined
    
    touchend = ->
      strokes.push stroke if "draw" == kind
      kind = "end"
    
    touchmove = (x0, y0, x1, y1) ->
      if "draw" == kind
        x = (x0) / scale - rootX
        y = (y0) / scale - rootY
        drawSegment stroke[stroke.length - 2], stroke[stroke.length - 1], x, y
        stroke.push x, y
    
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
            x: (e.touches[0].clientX + e.touches[1].clientX) / 2 / scale - rootX
            y: (e.touches[0].clientY + e.touches[1].clientY) / 2 / scale - rootY
            dist: dist e.touches[0].clientX, e.touches[0].clientY, e.touches[1].clientX, e.touches[1].clientY
            rootX: rootX
            rootY: rootY
            scale: scale
        else
          current =
            x: (e.touches[0].clientX + e.touches[1].clientX) / 2 / multitouch.scale - multitouch.rootX
            y: (e.touches[0].clientY + e.touches[1].clientY) / 2 / multitouch.scale - multitouch.rootY
            dist: dist e.touches[0].clientX, e.touches[0].clientY, e.touches[1].clientX, e.touches[1].clientY
          scale = multitouch.scale * current.dist / multitouch.dist
          rootX = (current.x + multitouch.rootX) * multitouch.scale / scale - multitouch.x
          rootY = (current.y + multitouch.rootY) * multitouch.scale / scale - multitouch.y
          uu.nextTick redraw()
    

## buttons

    buttonList = ["pan", "zoomin", "zoomout", "undo", "redo", "pan", "pan", "new", "download", "save", "load", "pan"]
    
    buttonAwesome =
      pan: "arrows"
      zoomin: "search-plus"
      zoomout: "search-minus"
      undo: "undo"
      redo: "repeat"
      new: "square-o"
      download: "download"
      save: "cloud-upload"
      load: "cloud-download"
    
    zoomFn = ->
      if kind.slice(0,4) == "zoom"
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
      undo: -> redo.push strokes.pop() if strokes.length; redraw()
      redo: -> strokes.push redo.pop() if redo.length; redraw()
      new: -> if strokes.length
        redo = strokes
        redo.reverse()
        strokes = []
        redraw()
    
    addButtons = ->
      buttons = document.getElementById "buttons"
      buttons.innerHTML = ""
      for i in [0..buttonList.length - 1]
        buttonId = buttonList[i]
        button = document.createElement "i"
        button.className = "fa fa-#{buttonAwesome[buttonId]}"
        button.onmousedown = button.ontouchstart = ((buttonId) -> (e) ->
            e.stopPropagation()
            e.preventDefault()
            kind = buttonId
            buttonFns[buttonId]?()
        )(buttonId)
        button.style.position = "absolute"
        button.style.fontSize = "36px"
        button.style.padding = "4px"
        button.style.top = if i < 6 then "0px" else "#{window.innerHeight - 44}px"
        s = (window.innerWidth - 6*44) / 5 + 44
        button.style.left = "#{(i % 6) * s}px"
        buttons.appendChild button
    

## onReady

    onReady ->
      ctx = canvas.getContext "2d"
      layout()
    
      uu.domListen window, "touchstart", (e) ->
        e.preventDefault()
        hasTouch = true
        touchstart(e.touches[0].clientX, e.touches[0].clientY) if 1 == e.touches.length
    
      uu.domListen window, "mousedown", (e) ->
        e.preventDefault()
        touchstart(e.clientX, e.clientY) if !hasTouch
    
      uu.domListen window, "touchmove", (e) ->
        e.preventDefault()
        args = []
        for touch in e.touches
          args.push touch.clientX
          args.push touch.clientY
        touchmove args...
    
      uu.domListen window, "mousemove", (e) ->
        e.preventDefault()
        touchmove e.clientX, e.clientY
    
    
      uu.domListen window, "touchend", (e) -> touchend()
      uu.domListen window, "mouseup", (e) -> (touchend() if !hasTouch)
      uu.domListen window, "resize", (e) -> layout()
    
    

----

README.md autogenerated from `sketch-note-draw.coffee` ![solsort](https://ssl.solsort.com/_reputil_rasmuserik_sketch-note-draw.png)
