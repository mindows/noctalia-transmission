--!nonstrict
-- Display helpers. Units are SI (1 kB = 1000 B), matching Transmission's own UI.

local M = {}

local UNITS = { "B", "kB", "MB", "GB", "TB" }

-- Picks the unit by the value as it will be displayed, so rounding can never
-- produce "1000 kB" (shown as "1.0 MB") or "100.0 MB" (shown as "100 MB").
function M.bytes(n)
  n = n or 0
  local i = 1
  while i < #UNITS do
    local shown = if n >= 100 or i == 1 then math.floor(n + 0.5) else math.floor(n * 10 + 0.5) / 10
    if shown < 1000 then
      break
    end
    n /= 1000
    i += 1
  end
  if i == 1 then
    return string.format("%d %s", math.floor(n + 0.5), UNITS[i])
  end
  if math.floor(n * 10 + 0.5) / 10 >= 100 then
    return string.format("%d %s", math.floor(n + 0.5), UNITS[i])
  end
  return string.format("%.1f %s", n, UNITS[i])
end

-- uploadRatio: -1 = not available, -2 = infinite (nothing was downloaded).
function M.ratio(r)
  if r == nil or r == -1 then
    return "–"
  elseif r == -2 then
    return "∞"
  end
  return string.format("%.2f", r)
end

function M.speed(n)
  return M.bytes(n) .. "/s"
end

-- Transmission reports eta in seconds; -1 = not available, -2 = unknown.
function M.eta(seconds)
  if seconds == nil or seconds < 0 then
    return "∞"
  end
  if seconds < 60 then
    return `{seconds}s`
  elseif seconds < 3600 then
    return `{seconds // 60}m`
  elseif seconds < 86400 then
    return `{seconds // 3600}h {(seconds % 3600) // 60}m`
  end
  return `{seconds // 86400}d {(seconds % 86400) // 3600}h`
end

-- torrent.status values from the RPC spec.
M.STOPPED = 0
M.CHECK_WAIT = 1
M.CHECKING = 2
M.DOWNLOAD_WAIT = 3
M.DOWNLOADING = 4
M.SEED_WAIT = 5
M.SEEDING = 6

local STATUS_KEYS = {
  [0] = "status.stopped",
  [1] = "status.check_wait",
  [2] = "status.checking",
  [3] = "status.download_wait",
  [4] = "status.downloading",
  [5] = "status.seed_wait",
  [6] = "status.seeding",
}

function M.status(code)
  return noctalia.tr(STATUS_KEYS[code] or "status.unknown")
end

return M
