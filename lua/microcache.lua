local _M = {}
local dict = ngx.shared.microcache

function _M.get(key)
  return dict:get(key)
end

function _M.set(key, val, ttl)
  dict:set(key, val, ttl)
end

return _M
