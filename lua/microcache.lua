local cache = ngx.shared.microcache  -- Usa el nombre definido en nginx.conf

local function get_cache_key()
    return ngx.var.uri
end

local function set_cache(key, value, ttl)
    cache:set(key, value, ttl)
end

local function get_cache(key)
    return cache:get(key)
end

-- Lógica principal
local key = get_cache_key()
local cached = get_cache(key)

if cached then
    ngx.say(cached)
    return ngx.OK
end

-- Si no está en caché, procesar y guardar
local res = ngx.location.capture("/php")
if res.status == ngx.HTTP_OK then
    set_cache(key, res.body, 60)  -- TTL de 60 segundos
    ngx.say(res.body)
end
