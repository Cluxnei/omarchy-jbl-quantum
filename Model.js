.pragma library

// Pure helpers for the panel; kept out of QML so they can be tested with node.

function parseState(raw) {
  try {
    var s = JSON.parse(String(raw || ""))
    return s && typeof s === "object" ? s : null
  } catch (e) {
    return null
  }
}

function duration(minutes) {
  var m = Math.max(0, Math.round(Number(minutes) || 0))
  if (m < 60) return m + "m"
  var h = Math.floor(m / 60)
  var r = m % 60
  if (h >= 48) return Math.round(h / 24) + "d"
  return r === 0 ? h + "h" : h + "h " + r + "m"
}

function hours(h) {
  if (h === null || h === undefined || !isFinite(Number(h))) return "—"
  return Number(h).toFixed(1) + " h"
}

// "glyph" for the bar: headphones when linked, crossed headphones when off.
function barGlyph(state) {
  if (!state || !state.dongle) return "󰟎"
  if (!state.connected) return "󰟎"
  if (state.charging) return "󰂄"
  return "󰋋"
}

function statusLine(state) {
  if (!state) return "Daemon not running"
  if (!state.dongle) return "Dongle not plugged in"
  if (!state.connected) return "Headset off"
  if (state.full) return "Fully charged"
  if (state.charging) return "Charging"
  return "Connected"
}

function remainingText(state) {
  if (!state || !state.connected) return ""
  if (state.full) return "Full"
  if (state.charging) return "Charging"
  if (state.remainingMin === null || state.remainingMin === undefined) return "Estimating…"
  return "~" + duration(state.remainingMin) + " left"
}

function healthText(stats) {
  if (!stats || stats.healthPct === null || stats.healthPct === undefined) return "Collecting data"
  return stats.healthPct + "%"
}

function healthNote(stats) {
  if (!stats) return ""
  if (stats.fullHours === null || stats.fullHours === undefined) {
    var need = Math.max(0, 10 - (stats.sampleDrop || 0))
    return "Needs " + need + "% more discharge while connected for a first estimate"
  }
  return hours(stats.fullHours) + " per charge vs " + stats.ratedHours + " h rated"
}

function baselineText(stats) {
  if (!stats || !stats.baselineFullHours || !stats.fullHours) return "—"
  var pct = Math.round(stats.fullHours / stats.baselineFullHours * 100)
  return pct + "% of first estimate (" + hours(stats.baselineFullHours) + ")"
}

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

function weekday(ts) {
  return WEEKDAYS[new Date(Number(ts) * 1000).getDay()]
}
