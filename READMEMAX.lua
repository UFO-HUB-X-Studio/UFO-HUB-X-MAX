--========================================================
-- 👽 UFO HUB X — Bootloader (Key -> Splash -> UI -> Extras)
--========================================================

local DEBUG = true
local function log(...) if DEBUG then print("[UFOX]", ...) end end

-- prevent duplicate
local ENV = (getgenv and getgenv()) or _G
if ENV.__UFOX_BOOT_RUNNING then return end
ENV.__UFOX_BOOT_RUNNING = true

-- ---------- HTTP helper (executor-friendly) ----------
local function httpget(url)
    if syn and syn.request then
        local r = syn.request({Url=url, Method="GET"})
        if r and r.StatusCode==200 then return r.Body end
        error("syn.request fail "..tostring(r and r.StatusCode))
    elseif http_request then
        local r = http_request({Url=url, Method="GET"})
        if r and (r.StatusCode==200 or r.StatusCode==204) then return r.Body end
        error("http_request fail "..tostring(r and r.StatusCode))
    elseif request then
        local r = request({Url=url, Method="GET"})
        if r and r.StatusCode==200 then return r.Body end
        error("request fail "..tostring(r and r.StatusCode))
    else
        return game:HttpGet(url)
    end
end

local function fetch(url, retries)
    retries = retries or 2
    for i=1,retries+1 do
        local ok, body = pcall(httpget, url)
        if ok and type(body)=="string" and #body>0 then return body end
        if i<=retries then task.wait(0.35*i) end
    end
    error("HTTP failed: "..url)
end

local function loadModule(name, url)
    log("fetch:", name, url)
    local src = fetch(url)
    local fn, err = loadstring(src, name)
    if not fn then error("loadstring "..name.." failed: "..tostring(err)) end
    local ok, ret = pcall(fn)
    if not ok then error("run "..name.." failed: "..tostring(ret)) end
    if type(ret)=="table" then
        log(name, "-> module (table)")
        return ret
    else
        log(name, "-> script executed (no return)")
        return {}
    end
end

local function tryCall(mod, names, args)
    for _,n in ipairs(names) do
        local f = mod and mod[n]
        if type(f)=="function" then
            local ok, err = pcall(f, args or {})
            if not ok then warn("[UFOX]", n, "error:", err) return false, err end
            return true
        end
    end
    return nil
end

-- ---------- Global defaults (ใช้ร่วมกันทุกโมดูล) ----------
ENV.UFOX = ENV.UFOX or {
    logoId      = 106029438403666,
    title       = "UFO HUB X",
    accent      = Color3.fromRGB(22,247,123),
    centerOpen  = true,
    twoColumns  = true,
    keyDuration = 24*60*60,
    getKeyLink  = "https://linkunlocker.com/ufo-hub-x-wKfUt",
    discordLink = "https://discord.gg/JFHuVVVQ6D"
}

-- ---------- URLs ของนาย ----------
local URL_UI     = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/README.lua"      -- #1
local URL_SPLASH = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/README2.lua"   -- #2
local URL_KEY    = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/README3.lua"   -- #3
local URL_EXTRAS = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-4/refs/heads/main/README4.lua"   -- #4

-- ======================================================
--                ORDER = KEY -> SPLASH -> UI
-- ======================================================

-- 1) KEY FIRST
local keymod
do
    local ok, err = pcall(function() keymod = loadModule("UFOX_KEY", URL_KEY) end)
    if not ok then
        warn("[UFOX] key module load fail:", err, "-> fallback: no gate")
    else
        -- ถ้ามี check/isValid ให้ใช้, ถ้าไม่มีก็เปิด prompt เลย
        local valid = false
        if type(keymod.check)=="function" then
            local okc, v = pcall(function() return keymod.check({durationSec = ENV.UFOX.keyDuration}) end)
            valid = okc and v
        elseif type(keymod.isValid)=="function" then
            local okc, v = pcall(keymod.isValid); valid = okc and v
        end

        if not valid then
            -- แสดง UI ขอคีย์ก่อน
            tryCall(keymod, {"prompt","open","start","run"}, {
                durationSec  = ENV.UFOX.keyDuration,
                getKeyLink   = ENV.UFOX.getKeyLink,
                discordInvite= ENV.UFOX.discordLink
            })
            -- ถ้ามี isValid ให้รอจนผ่าน (สูงสุด ~60 วินาที)
            if type(keymod.isValid)=="function" then
                local passed=false
                for _=1,600 do
                    local okv, v = pcall(keymod.isValid)
                    if okv and v then passed=true; break end
                    task.wait(0.1)
                end
                if not passed then warn("[UFOX] key timeout; continue (dev mode)") end
            end
        else
            log("key: already valid")
        end
    end
end

-- 2) THEN SPLASH (DOWNLOAD)
local splash
do
    local ok, err = pcall(function() splash = loadModule("UFOX_SPLASH", URL_SPLASH) end)
    if not ok then
        warn("[UFOX] splash load fail:", err)
    else
        -- show/start/run รองรับได้หมด
        tryCall(splash, {"show","start","run"}, {
            seconds = 3.8,                          -- ปรับช้าหรือเร็วได้
            logoId  = ENV.UFOX.logoId,
            title   = ENV.UFOX.title
        })
        -- รอให้สปลัชทำงานอย่างน้อยระยะนี้ (กัน UI หลักโผล่เร็วไป)
        task.wait(0.25) -- กันชนเล็ก ๆ ถ้าโมดูลทำงานแบบ async
    end
end

-- 3) MAIN UI
local uimod
do
    local ok, err = pcall(function() uimod = loadModule("UFOX_UI", URL_UI) end)
    if not ok then
        error("[UFOX] UI load fail: "..tostring(err))
    else
        tryCall(uimod, {"start","run","open"}, {
            title      = ENV.UFOX.title,
            logoId     = ENV.UFOX.logoId,
            accent     = ENV.UFOX.accent,
            centerOpen = ENV.UFOX.centerOpen,
            twoColumns = ENV.UFOX.twoColumns
        })
    end
end

-- 4) EXTRAS (optional)
do
    local ok, extras = pcall(function() return loadModule("UFOX_EXTRAS", URL_EXTRAS) end)
    if ok and extras then
        tryCall(extras, {"start","run","init"}, { shared = ENV.UFOX })
    end
end

log("Boot completed: Key -> Splash -> UI -> Extras")
