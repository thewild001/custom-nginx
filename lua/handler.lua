local microcache  = require "microcache"
local redis_cache = require "redis_cache"

-- Generación de la clave única de caché
local cache_key = ngx.var.request_method
               .. ngx.var.scheme
               .. ngx.var.host
               .. ngx.var.request_uri

-- 1) Intento de microcaching (TTL 5s)
local mval = microcache.get(cache_key)
if mval then
  ngx.header["X-Cache"] = "HIT micro"
  ngx.say(mval)
  return ngx.exit(200)
end

-- 2) Intento de caching en Redis (TTL 120s)
local rval, err = redis_cache.get(cache_key)
if rval then
  ngx.header["X-Cache"] = "HIT redis"
  ngx.say(rval)
  return ngx.exit(200)
end

-- 3) Proxy al backend Symfony y almacenamiento en ambas cachés
local res = ngx.location.capture("/proxy_to_backend")
if res.status == 200 then
  local body = res.body
  microcache.set(cache_key, body, 5)
  redis_cache.set(cache_key, body, 120)
  ngx.header["X-Cache"] = "MISS"
  ngx.say(body)
  return
end

-- 4) Error del backend
ngx.status = res.status
ngx.say("Backend error: ", res.status)
return ngx.exit(res.status)
