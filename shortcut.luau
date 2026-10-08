--!nonstrict
-- Control-center tile: toggles Transmission's alternative speed limits.

local rpc = require("./lib/rpc.luau")

local stats = noctalia.state.get("stats")
local pending = false

local function render()
  local on = stats ~= nil and stats.altSpeed == true
  shortcut.setLabel(noctalia.tr("shortcut.label"))
  shortcut.setIcon("gauge", "gauge")
  shortcut.setActive(on)
  shortcut.setEnabled(stats ~= nil and stats.connected == true and not pending)
end

noctalia.state.watch("stats", function(value)
  stats = value
  render()
end)

render()

function onClick()
  if stats == nil or not stats.connected or pending then
    return
  end
  pending = true
  render()

  local function done(err)
    pending = false
    if err then
      noctalia.notifyError(noctalia.tr("title"), err)
    end
    noctalia.state.set("poke", noctalia.nowMs())
    render()
  end

  -- The shared stats can be a full refresh interval old (and the flag may have
  -- been changed elsewhere, e.g. the web UI), so flip the daemon's live value.
  rpc.call("session-get", { fields = { "alt-speed-enabled" } }, function(ok, session)
    if not ok then
      done(session)
      return
    end
    rpc.call("session-set", { ["alt-speed-enabled"] = session["alt-speed-enabled"] ~= true }, function(ok2, err)
      done(if ok2 then nil else err)
    end)
  end)
end
