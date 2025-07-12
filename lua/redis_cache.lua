local redis = require "resty.redis"
local _M = {}

local function get_red()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("redis", 6379)
  if not ok then
    ngx.log(ngx.ERR, "Redis connection error: ", err)
    return nil, err
  end
  return red
end

function _M.get(key)
  local red, err = get_red()
  if not red then return nil, err end

  local res, err = red:get(key)
  red:set_keepalive(10000, 100)
  if not res or res == ngx.null then
    return nil, err
  end

  return res, nil
end

function _M.set(key, val, ttl)
  local red, err = get_red()
  if not red then return nil, err end

  local ok, err = red:set(key, val)
  if not ok then
    red:set_keepalive(10000, 100)
    return nil, err
  end

  red:expire(key, ttl)
  red:set_keepalive(10000, 100)
  return true
end

return _M
