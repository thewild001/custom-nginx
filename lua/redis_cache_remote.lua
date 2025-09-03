local redis = require "resty.redis"
local cjson = require "cjson"

local _M = {}
_M._VERSION = "1.0"

-- Pool de conexiones para optimizar performance
local redis_pool = {}

-- Configuración dinámica desde variables de entorno
local function get_redis_config()
    return {
        host = os.getenv("REDIS_HOST") or "redis",
        port = tonumber(os.getenv("REDIS_PORT")) or 6379,
        password = os.getenv("REDIS_PASSWORD") or nil,
        timeout = tonumber(os.getenv("REDIS_TIMEOUT")) or 1000,
        pool_size = tonumber(os.getenv("REDIS_POOL_SIZE")) or 100,
        keepalive = tonumber(os.getenv("REDIS_KEEPALIVE")) or 10000
    }
end

-- Crear conexión con retry automático y circuit breaker
function _M.new()
    local config = get_redis_config()
    local red = redis:new()
    
    red:set_timeout(config.timeout)
    
    -- Implementar circuit breaker básico
    local cache_key = "redis_circuit_breaker"
    local failures = ngx.shared.cache_dict:get(cache_key) or 0
    
    -- Si hay muchas fallas, usar cache local temporal
    if failures > 5 then
        ngx.log(ngx.WARN, "Circuit breaker OPEN - usando cache local")
        return nil
    end
    
    local ok, err = red:connect(config.host, config.port)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis at ", config.host, ":", config.port, " - ", err)
        -- Incrementar contador de fallas
        ngx.shared.cache_dict:incr(cache_key, 1, 0)
        ngx.shared.cache_dict:expire(cache_key, 60) -- Reset después de 1 minuto
        return nil
    end
    
    -- Autenticar si hay password
    if config.password and config.password ~= "" then
        local res, err = red:auth(config.password)
        if not res then
            ngx.log(ngx.ERR, "Failed to authenticate with Redis: ", err)
            red:close()
            return nil
        end
    end
    
    -- Reset circuit breaker en conexión exitosa
    ngx.shared.cache_dict:delete(cache_key)
    
    return red, config
end

-- Obtener desde cache con fallback local
function _M.get_cache(key)
    -- Intentar cache local primero (más rápido)
    local local_cache = ngx.shared.cache_dict:get("local_" .. key)
    if local_cache then
        ngx.header["X-Cache-Status"] = "LOCAL-HIT"
        return local_cache
    end
    
    local red, config = _M.new()
    if not red then
        ngx.log(ngx.WARN, "Redis no disponible - usando cache local si existe")
        return nil
    end
    
    local res, err = red:get("symfony_cache:" .. key)
    if not res or res == ngx.null then
        red:set_keepalive(config.keepalive, config.pool_size)
        return nil
    end
    
    -- Guardar copia en cache local como backup
    ngx.shared.cache_dict:set("local_" .. key, res, 300) -- 5 minutos local
    
    red:set_keepalive(config.keepalive, config.pool_size)
    ngx.header["X-Cache-Status"] = "REDIS-HIT"
    return res
end

-- Establecer en cache con redundancia local
function _M.set_cache(key, value, expire)
    expire = expire or 3600 -- Default 1 hora
    
    -- Siempre guardar en cache local como backup
    ngx.shared.cache_dict:set("local_" .. key, value, math.min(expire, 300))
    
    local red, config = _M.new()
    if not red then
        ngx.log(ngx.WARN, "Redis no disponible - guardado solo en cache local")
        return false
    end
    
    local ok, err = red:setex("symfony_cache:" .. key, expire, value)
    if not ok then
        ngx.log(ngx.ERR, "Failed to set cache in Redis: ", err)
        red:set_keepalive(config.keepalive, config.pool_size)
        return false
    end
    
    red:set_keepalive(config.keepalive, config.pool_size)
    return true
end

-- Invalidar cache específico
function _M.delete_cache(key)
    ngx.shared.cache_dict:delete("local_" .. key)
    
    local red, config = _M.new()
    if not red then
        return false
    end
    
    local ok, err = red:del("symfony_cache:" .. key)
    red:set_keepalive(config.keepalive, config.pool_size)
    return ok
end

return _M
