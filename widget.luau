--!nonstrict
-- Bar widget: current download/upload rates, fed by the service's "stats".
-- Click opens the torrent panel.

local format = require("./lib/format.luau")

local glyph = noctalia.getConfig("glyph")
local hideWhenIdle = noctalia.getConfig("hide_when_idle")
local showRate = noctalia.getConfig("show_rate")

local stats = noctalia.state.get("stats")

local function render()
  if stats == nil then
    barWidget.setGlyph(glyph)
    barWidget.setText(if showRate then "…" else "")
    barWidget.setTooltip(noctalia.tr("widget.connecting"))
    return
  end

  if not stats.connected then
    barWidget.setVisible(true)
    barWidget.setGlyph("plug-connected-x")
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip({
      { noctalia.tr("title"), noctalia.tr("widget.disconnected") },
      { noctalia.tr("widget.error"), stats.error or "?" },
    })
    return
  end

  local idle = stats.down == 0 and stats.up == 0
  barWidget.setVisible(not (hideWhenIdle and idle))
  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(if stats.altSpeed then "tertiary" else "on_surface")
  barWidget.setText(if showRate then `↓{format.speed(stats.down)} ↑{format.speed(stats.up)}` else "")

  local rows = {
    { noctalia.tr("widget.download"), format.speed(stats.down) },
    { noctalia.tr("widget.upload"), format.speed(stats.up) },
    { noctalia.tr("widget.active"), tostring(stats.active) },
    { noctalia.tr("widget.paused"), tostring(stats.paused) },
    { noctalia.tr("widget.total"), tostring(stats.total) },
  }
  if stats.altSpeed then
    table.insert(rows, { noctalia.tr("widget.alt_speed"), noctalia.tr("widget.on") })
  end
  barWidget.setTooltip(rows)
end

noctalia.state.watch("stats", function(value)
  stats = value
  render()
end)

render()

function update()
  -- Purely reactive; the service drives refreshes.
  noctalia.setUpdateInterval(60000)
end

function onClick()
  noctalia.togglePanel("mindows/transmission:panel")
end
