--!nonstrict
-- Torrent list panel. Fetches torrent-get itself while open (the service only
-- tracks session totals) and offers per-torrent and global start/stop.
--
--   noctalia msg panel-toggle mindows/transmission:panel

local rpc = require("./lib/rpc.luau")
local format = require("./lib/format.luau")

-- The panel polls on its own fast cadence, but only while open; refresh_seconds
-- (default 5 min) governs the background service.
local REFRESH_MS = 3000

local FIELDS = {
  "id", "name", "status", "percentDone", "rateDownload", "rateUpload",
  "eta", "error", "errorString", "totalSize", "uploadRatio",
}

local isOpen = false
local inFlight = false
local torrents = nil -- nil until the first response
local errorText = nil
local stats = noctalia.state.get("stats")

local render

-- Active first, then by name.
local function sortTorrents(list)
  table.sort(list, function(a, b)
    local aActive = a.status ~= format.STOPPED
    local bActive = b.status ~= format.STOPPED
    if aActive ~= bActive then
      return aActive
    end
    return string.lower(a.name) < string.lower(b.name)
  end)
end

local function fetch()
  if not isOpen or inFlight then
    return
  end
  inFlight = true
  rpc.call("torrent-get", { fields = FIELDS }, function(ok, result)
    inFlight = false
    if ok then
      torrents = result.torrents or {}
      sortTorrents(torrents)
      errorText = nil
    else
      errorText = result
    end
    if isOpen then
      render()
    end
  end)
end

-- Runs a mutating method, then refreshes the list and pokes the service so the
-- widget catches up without waiting a full interval.
local function act(method, ids)
  local args = nil
  if ids then
    args = { ids = ids }
  end
  rpc.call(method, args, function(ok, err)
    if not ok then
      noctalia.notifyError(noctalia.tr("title"), err)
    end
    noctalia.state.set("poke", noctalia.nowMs())
    fetch()
  end)
end

local function torrentRow(t)
  local stopped = t.status == format.STOPPED
  local hasError = (t.error or 0) ~= 0

  local detail
  if hasError then
    detail = t.errorString
  elseif t.status == format.DOWNLOADING then
    detail = `{format.status(t.status)} · ↓{format.speed(t.rateDownload)} ↑{format.speed(t.rateUpload)} · {format.eta(t.eta)}`
  elseif t.status == format.SEEDING then
    detail = `{format.status(t.status)} · ↑{format.speed(t.rateUpload)} · {noctalia.tr("panel.ratio")} {format.ratio(t.uploadRatio)}`
  else
    detail = format.status(t.status)
  end

  return ui.row({ key = `t{t.id}`, gap = 10, align = "center" }, {
    ui.column({ gap = 4, flexGrow = 1, align = "stretch" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = t.name, maxLines = 1, flexGrow = 1, fontWeight = "medium" }),
        ui.label({
          text = `{math.floor((t.percentDone or 0) * 1000) / 10}% · {format.bytes(t.totalSize)}`,
          color = "on_surface_variant",
        }),
      }),
      ui.progress({
        progress = t.percentDone or 0,
        fill = if hasError then "error" elseif stopped then "outline" else "primary",
        height = 4,
      }),
      ui.label({
        text = detail,
        maxLines = 1,
        color = if hasError then "error" else "on_surface_variant",
        fontSize = 11,
      }),
    }),
    ui.button({
      glyph = if stopped then "player-play" else "player-pause",
      variant = "ghost",
      controlSize = "sm",
      tooltip = noctalia.tr(if stopped then "panel.resume" else "panel.pause"),
      onClick = function()
        act(if stopped then "torrent-start" else "torrent-stop", { t.id })
      end,
    }),
  })
end

local function body()
  -- An error replaces the list: stale rows with dead buttons would mislead.
  if errorText then
    return ui.column({ gap = 12, align = "center", justify = "center", flexGrow = 1 }, {
      ui.glyph({ name = "plug-connected-x", size = 32, color = "error" }),
      ui.label({ text = errorText, color = "error", textAlign = "center", maxLines = 4 }),
      ui.row({ gap = 8 }, {
        ui.button({ text = noctalia.tr("panel.retry"), glyph = "refresh", onClick = fetch }),
        ui.button({ text = noctalia.tr("panel.settings"), glyph = "settings", variant = "outline",
          onClick = function() noctalia.openSettings() end }),
      }),
    })
  end
  if torrents == nil then
    return ui.column({ align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    })
  end
  if #torrents == 0 then
    return ui.column({ align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({ text = noctalia.tr("panel.empty"), color = "on_surface_variant" }),
    })
  end

  local rows = {}
  for _, t in torrents do
    table.insert(rows, torrentRow(t))
  end
  return ui.scroll({ flexGrow = 1, gap = 14, align = "stretch" }, rows)
end

function render()
  -- Sum the fresh torrent list rather than the service's (slowly polled) totals.
  local summary = ""
  if torrents ~= nil and errorText == nil then
    local down, up = 0, 0
    for _, t in torrents do
      down += t.rateDownload or 0
      up += t.rateUpload or 0
    end
    summary = `↓{format.speed(down)}  ↑{format.speed(up)}`
  elseif stats and stats.connected then
    summary = `↓{format.speed(stats.down)}  ↑{format.speed(stats.up)}`
  end

  panel.render(ui.column({ flexGrow = 1, gap = 14, align = "stretch" }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "magnet", size = 18, color = "primary" }),
      ui.label({ text = noctalia.tr("title"), fontSize = 16, fontWeight = "bold" }),
      ui.label({ text = summary, color = "on_surface_variant", flexGrow = 1 }),
      ui.button({ glyph = "player-play", variant = "ghost", controlSize = "sm",
        tooltip = noctalia.tr("panel.resume_all"), onClick = function() act("torrent-start", nil) end }),
      ui.button({ glyph = "player-pause", variant = "ghost", controlSize = "sm",
        tooltip = noctalia.tr("panel.pause_all"), onClick = function() act("torrent-stop", nil) end }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }),
    }),
    body(),
  }))
end

noctalia.state.watch("stats", function(value)
  stats = value
  if isOpen then
    render()
  end
end)

function onOpen(_context)
  isOpen = true
  noctalia.setUpdateInterval(REFRESH_MS)
  render()
  fetch()
  noctalia.state.set("poke", noctalia.nowMs())
end

function onClose()
  isOpen = false
  -- Stop the fast cadence; update() would only wake up to do nothing.
  noctalia.setUpdateInterval(3600000)
end

function update()
  fetch()
end

function onIpc(event, _payload)
  if event == "refresh" then
    fetch()
  end
end
