--!nonstrict
-- Headless poller: fetches session stats and the alt-speed flag every
-- refresh_seconds and publishes them as the shared "stats" table, which the bar
-- widget and the control-center tile watch.
--
-- Other entries can request an immediate refresh by setting "poke" to a new
-- value (e.g. noctalia.nowMs()) after they change something on the daemon.
--
--   noctalia msg plugin mindows/transmission:service all refresh

local rpc = require("./lib/rpc.luau")

local inFlight = false
local pollAgain = false
local lastStatus = nil

-- Logs only on transitions, so a down daemon does not spam the log.
local function logStatus(status)
  if status ~= lastStatus then
    lastStatus = status
    noctalia.log(`transmission: {status}`)
  end
end

local function publishError(err)
  logStatus("error: " .. tostring(err))
  local previous = noctalia.state.get("stats") or {}
  noctalia.state.set("stats", {
    connected = false,
    error = err,
    altSpeed = previous.altSpeed == true,
  })
end

-- A poll requested while one is in flight is queued (not dropped), so a
-- config change or a poke right after an action is never lost; its result
-- could otherwise predate the change.
local function poll()
  if inFlight then
    pollAgain = true
    return
  end
  inFlight = true
  pollAgain = false

  -- Both requests go out together; publish once both have answered.
  local stats, session, failure = nil, nil, nil
  local remaining = 2

  local function finish()
    remaining -= 1
    if remaining > 0 then
      return
    end
    inFlight = false
    if failure then
      publishError(failure)
    else
      logStatus(`connected (Transmission {session.version or "?"})`)
      noctalia.state.set("stats", {
        connected = true,
        down = stats.downloadSpeed or 0,
        up = stats.uploadSpeed or 0,
        active = stats.activeTorrentCount or 0,
        paused = stats.pausedTorrentCount or 0,
        total = stats.torrentCount or 0,
        altSpeed = session["alt-speed-enabled"] == true,
        version = session.version,
      })
    end
    if pollAgain then
      poll()
    end
  end

  rpc.call("session-stats", nil, function(ok, result)
    if ok then stats = result else failure = failure or result end
    finish()
  end)
  rpc.call("session-get", { fields = { "alt-speed-enabled", "version" } }, function(ok, result)
    if ok then session = result else failure = failure or result end
    finish()
  end)
end

local function applyInterval()
  noctalia.setUpdateInterval(noctalia.getConfig("refresh_seconds") * 1000)
end

noctalia.state.watch("poke", function(_value)
  poll()
end)

applyInterval()
poll()

function update()
  poll()
end

function onConfigChanged()
  rpc.reset()
  applyInterval()
  poll()
end

function onIpc(event, _payload)
  if event == "refresh" then
    poll()
  end
end
