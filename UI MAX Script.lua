-- UI MAX Script.lua
-- UFO HUB X — Boot + Game Detector + Feature Orchestrator

----------------------------- Services -----------------------------
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local MPS         = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

----------------------------- Helpers ------------------------------
local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "httpget_failed"
end

local function load_from(url)
    local ok, src = http_get(url)
    if not ok then warn("[UFO] HttpGet fail:", src); return false end
    local f,err = loadstring(src)
    if not f then warn("[UFO] loadstring fail:", err); return false end
    local ok2, ret = pcall(f)
    if not ok2 then warn("[UFO] run fail:", ret); return false end
    return true, ret
end

----------------------------- Persist ------------------------------
local DIR        = "UFOHubX"
local STATE_FILE = DIR.."/key_state.json"
if isfolder and not isfolder(DIR) then pcall(makefolder, DIR) end

local function readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function writeState(tbl)
    if not (writefile and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    if st.permanent == true then return true end
    if st.expires_at and typeof(st.expires_at)=="number" then
        return (os.time() < st.expires_at)
    end
    return false
end

-- Callback ให้ไฟล์ Key เรียกกลับมาตอนผ่าน
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    writeState({ key = key, expires_at = expires_at, permanent = permanent == true })
end

----------------------------- Sources -------------------------------
local SRC_URL_KEY      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local SRC_URL_DOWNLOAD = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local SRC_URL_MAINUI   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- คอนฟิกเกมแบบไดนามิก (แก้บน Git ได้)
local GAMES_CFG_URL    = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-MAX/refs/heads/main/games.json"
-- โครงสร้าง games.json (ตัวอย่าง):
-- {
--   "Grow a Garden": {
--     "placeIds": [1234567890, 1234567891],
--     "features": ["autoPlant","autoWater","autoHarvest","speedBoost","teleportPads"],
--     "ui": true
--   }
-- }

----------------------------- Game Info -----------------------------
local PLACE_ID = game.PlaceId
local GAME_NAME = ""
pcall(function()
    local info = MPS:GetProductInfo(PLACE_ID)
    GAME_NAME = info and info.Name or ""
end)

----------------------------- Game Config ---------------------------
local GAME_CFG = nil
do
    local ok, json = http_get(GAMES_CFG_URL)
    if ok and json and #json>0 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(json) end)
        if ok2 and type(data)=="table" then
            GAME_CFG = data
        end
    end
end

local function pickGameEntry()
    if not GAME_CFG then return nil end
    -- 1) match ด้วย PlaceId
    for name, entry in pairs(GAME_CFG) do
        if entry.placeIds and table.find(entry.placeIds, PLACE_ID) then
            return name, entry
        end
    end
    -- 2) สำรองด้วยชื่อเกม (เท่ากันเป๊ะ)
    for name, entry in pairs(GAME_CFG) do
        if tostring(name) == tostring(GAME_NAME) then
            return name, entry
        end
    end
    -- 3) สำรองด้วย contains (กันชื่อเวอร์ชัน)
    for name, entry in pairs(GAME_CFG) do
        if tostring(GAME_NAME):lower():find(tostring(name):lower(), 1, true) then
            return name, entry
        end
    end
    return nil
end

local GAME_KEY, GAME_ENTRY = pickGameEntry()

----------------------------- Feature Loader ------------------------
-- จุดรวมโหลดฟีเจอร์ของแต่ละเกม (โครง—ยังไม่ใส่ logic ภายใน)
-- สมมุติใส่ไว้ใน repo UFO-HUB-X-Features/growagarden/*.lua
local FEATURES_BASE = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Features/refs/heads/main/growagarden/"

local FEATURE_FILES = {
    autoPlant     = FEATURES_BASE .. "autoPlant.lua",
    autoWater     = FEATURES_BASE .. "autoWater.lua",
    autoHarvest   = FEATURES_BASE .. "autoHarvest.lua",
    speedBoost    = FEATURES_BASE .. "speedBoost.lua",
    teleportPads  = FEATURES_BASE .. "teleportPads.lua",
}

-- API ให้ UI หลักเรียกเปิด/ปิดแต่ละฟีเจอร์
_G.UFO_Features = _G.UFO_Features or {}
_G.UFO_Features.__loaded = _G.UFO_Features.__loaded or {} -- cache module
_G.UFO_Features.start = function(name)
    local url = FEATURE_FILES[name]
    if not url then return false, "unknown_feature" end
    if _G.UFO_Features.__loaded[name] and _G.UFO_Features.__loaded[name].start then
        local ok,err = pcall(_G.UFO_Features.__loaded[name].start)
        return ok, err
    end
    -- โหลดครั้งแรก
    local ok, src = http_get(url)
    if not ok then return false, "get_fail" end
    local f, err = loadstring(src); if not f then return false, err end
    local ok2, module = pcall(f); if not ok2 then return false, module end
    _G.UFO_Features.__loaded[name] = module
    if module and module.start then
        local ok3, er3 = pcall(module.start)
        return ok3, er3
    end
    return false, "no_start"
end
_G.UFO_Features.stop = function(name)
    local m = _G.UFO_Features.__loaded[name]
    if m and m.stop then
        local ok,err = pcall(m.stop)
        return ok, err
    end
    return false, "not_running"
end

----------------------------- UI Bridges ----------------------------
-- ให้ Key/Download/MainUI เรียกต่อ ๆ กัน
_G.UFO_StartDownload = function()
    load_from(SRC_URL_DOWNLOAD)
end

_G.UFO_ShowMain = function()
    -- ก่อนเปิด UI หลัก: ผูก “รายการฟีเจอร์ของเกมนี้” ให้ UI ใช้ render
    _G.UFO_CurrentGame = {
        name     = GAME_KEY or GAME_NAME or "Unknown",
        placeId  = PLACE_ID,
        features = (GAME_ENTRY and GAME_ENTRY.features) or {},
        showUI   = (GAME_ENTRY and GAME_ENTRY.ui) == true
    }
    if _G.UFO_CurrentGame.showUI then
        load_from(SRC_URL_MAINUI)
    else
        warn("[UFO] Game config set ui=false; main UI not shown.")
    end
end

----------------------------- Boot Flow -----------------------------
if not isKeyStillValid() then
    -- ยังไม่ผ่านคีย์ → แสดง Key UI ก่อน (เมื่อผ่านแล้ว Key UI จะเรียก UFO_StartDownload เอง)
    load_from(SRC_URL_KEY)
else
    -- เคยผ่านคีย์แล้วและยังไม่หมดเวลา → ข้ามไป Download
    _G.UFO_StartDownload()
end
