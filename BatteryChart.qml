import QtQuick

// Battery percent over the last 24h. `points` is [[unixSeconds, percent], ...]
// from the daemon; gaps longer than `gapSec` (headset off) break the line
// instead of drawing a misleading ramp across them.
Canvas {
  id: root

  property var points: []
  property color lineColor: "white"
  property color lowColor: "red"
  property real lowLevel: 20
  property real windowSec: 86400
  property real gapSec: 600
  property real now: Date.now() / 1000

  antialiasing: true
  onPointsChanged: requestPaint()
  onLineColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onNowChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (width <= 0 || height <= 0) return
    var oldest = now - windowSec
    function px(t) { return Math.max(0, Math.min(width, (t - oldest) * width / windowSec)) }
    function py(v) { return height - 1 - Math.max(0, Math.min(100, v)) / 100 * (height - 2) }

    // 25/50/75% rules plus the low-battery line.
    ctx.lineWidth = 1
    ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.08)
    for (var g = 25; g <= 75; g += 25) {
      ctx.beginPath(); ctx.moveTo(0, Math.round(py(g)) + 0.5); ctx.lineTo(width, Math.round(py(g)) + 0.5); ctx.stroke()
    }
    ctx.strokeStyle = Qt.rgba(lowColor.r, lowColor.g, lowColor.b, 0.35)
    if (ctx.setLineDash) ctx.setLineDash([3, 3])
    ctx.beginPath(); ctx.moveTo(0, Math.round(py(lowLevel)) + 0.5); ctx.lineTo(width, Math.round(py(lowLevel)) + 0.5); ctx.stroke()
    if (ctx.setLineDash) ctx.setLineDash([])

    var list = points || []
    var runs = []
    var run = []
    for (var i = 0; i < list.length; i++) {
      if (list[i][0] < oldest) continue
      if (run.length && list[i][0] - run[run.length - 1][0] > gapSec) { runs.push(run); run = [] }
      run.push(list[i])
    }
    if (run.length) runs.push(run)

    for (var r = 0; r < runs.length; r++) {
      var pts = runs[r]
      if (pts.length === 1) pts = [pts[0], [pts[0][0] + 60, pts[0][1]]]
      ctx.beginPath()
      ctx.moveTo(px(pts[0][0]), height)
      for (var j = 0; j < pts.length; j++) ctx.lineTo(px(pts[j][0]), py(pts[j][1]))
      ctx.lineTo(px(pts[pts.length - 1][0]), height)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.12)
      ctx.fill()

      ctx.beginPath()
      ctx.moveTo(px(pts[0][0]), py(pts[0][1]))
      for (var k = 1; k < pts.length; k++) ctx.lineTo(px(pts[k][0]), py(pts[k][1]))
      ctx.strokeStyle = lineColor
      ctx.lineWidth = 1.5
      ctx.stroke()
    }
  }
}
