--!nonstrict
-- Minimal Transmission RPC client (legacy JSON protocol, supported by every
-- Transmission release including 4.x).
--
--   rpc.call(method, arguments, cb)   cb(ok, argumentsOrError)
--   rpc.reset()                       forget the cached session id
--
-- Transmission's CSRF guard answers a request that lacks a valid
-- X-Transmission-Session-Id with 409 and the id to use; the call is retried once
-- with it. Each entry VM gets its own copy of this module, and so its own id.

local M = {}

local sessionId = nil

local function endpoint()
  local scheme = if noctalia.getConfig("use_https") then "https" else "http"
  local path = noctalia.getConfig("rpc_path")
  if string.sub(path, 1, 1) ~= "/" then
    path = "/" .. path
  end
  return `{scheme}://{noctalia.getConfig("host")}:{noctalia.getConfig("port")}{path}`
end

-- Returns the password, or nil plus an error message. Read on every call so
-- edits to the file take effect without a reload.
local function readPassword()
  local path = noctalia.getConfig("password_file")
  if path == nil or path == "" then
    return nil, noctalia.tr("error.no_password_file")
  end
  local raw = noctalia.readFile(path)
  if raw == nil then
    return nil, noctalia.tr("error.password_unreadable", { path = path })
  end
  return noctalia.string.trim(raw)
end

-- The 409 body repeats the header ("<code>X-Transmission-Session-Id: ...</code>"),
-- which is the only place the documented http() response exposes it.
local function sessionIdFrom(res)
  if type(res.headers) == "table" then
    for k, v in res.headers do
      if type(k) == "string" and string.lower(k) == "x-transmission-session-id" then
        return v
      end
      if type(v) == "string" then
        local id = string.match(v, "^[Xx]%-[Tt]ransmission%-[Ss]ession%-[Ii]d:%s*(%S+)")
        if id then
          return id
        end
      end
    end
  end
  return string.match(res.body or "", "X%-Transmission%-Session%-Id:%s*([%w]+)")
end

local function send(method, arguments, cb, retried)
  local request = {
    url = endpoint(),
    method = "POST",
    body = noctalia.json.encode({ method = method, arguments = arguments or {} }),
    headers = { "Content-Type: application/json" },
  }
  if sessionId then
    table.insert(request.headers, "X-Transmission-Session-Id: " .. sessionId)
  end

  local username = noctalia.getConfig("username")
  if username ~= nil and username ~= "" then
    local password, err = readPassword()
    if password == nil then
      cb(false, err)
      return
    end
    request.basic_username = username
    request.basic_password = password
  end

  local accepted = noctalia.http(request, function(res)
    if res.status == 409 and not retried then
      sessionId = sessionIdFrom(res)
      if sessionId then
        send(method, arguments, cb, true)
      else
        cb(false, noctalia.tr("error.no_session_id"))
      end
      return
    end
    if res.status == 401 then
      cb(false, noctalia.tr("error.unauthorized"))
      return
    end
    if not res.ok or res.status ~= 200 then
      if res.status == 0 or res.status == nil then
        cb(false, noctalia.tr("error.unreachable", { url = request.url }))
      else
        cb(false, noctalia.tr("error.http", { status = res.status }))
      end
      return
    end

    local decoded = noctalia.json.decode(res.body)
    if type(decoded) ~= "table" then
      cb(false, noctalia.tr("error.bad_response"))
    elseif decoded.result ~= "success" then
      cb(false, tostring(decoded.result))
    else
      cb(true, decoded.arguments or {})
    end
  end)

  if not accepted then
    cb(false, noctalia.tr("error.not_accepted"))
  end
end

function M.call(method, arguments, cb)
  send(method, arguments, cb or function() end, false)
end

function M.reset()
  sessionId = nil
end

return M
