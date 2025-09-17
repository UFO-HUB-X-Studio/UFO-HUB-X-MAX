--========================================================
-- UI MAX Script.lua
-- UFO HUB X — Ultimate Orchestrator (Key → Download → Main UI + Map Features)
--========================================================

-------------------- CONFIG --------------------
local URL_KEY      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- Map Features
local URL_GAME     = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Game/refs/heads/main/UFO%20HUB%20X%20Game.lua"
local MAPS = {
    ["Grow a Garden"]           = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Grow-a-Garden/refs/heads/main/UFO%20HUB%20X%20Grow%20a%20Garden.lua",
    ["99 Nights in the Forest"] = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-99--Nights-in--the-Forest/refs/heads/main/UFO%20HUB%20X%2099%20Nights%20in%20the%20Forest.lua",
    ["Steal a Brainrot"]        = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Steal-a--Brainrot/refs/heads/main/UFO%20HUB%20X%20Steal%20a%20Brainrot.lua",
    ["Blox Fruit1"]             = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Blox-Fruit1/refs/heads/main/UFO%20HUB%20X%20Blox%20Fruit1.lua",
    ["Blox Fruit2"]             = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Blox-Fruit2/refs/heads/main/UFO%20HUB%20X%20Blox%20Fruit2.lua",
    ["Blox Fruit3"]             = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Blox-Fruit3/refs/heads/main/UFO%20HUB%20X%20Blox%20Fruit3.lua",
    ["Fish it"]                 = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Fish-it/refs/heads/main/UFO%20HUB%20X%20Fish%20it.lua",
}

-- Key System Config
local DIR          = "UFOHubX"
local STATE_FILE   = DIR.."/key_state.json"
local DOWNLOAD_HANDOFF_DELAY   = 0.5
local DOWNLOAD_CALLBACK_TIMEOUT= 30.0

local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent=true },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true },
}

-------------------- Services --------------------
local HttpService = game:GetService("HttpService")

-------------------- HTTP + FS --------------------
local function http_get(url)
    if http and http.request then
        local ok,res=pcall(http.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res=pcall(syn.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body=pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"httpget_failed"
end

local function fs_ensure_dir()
    if isfolder and not isfolder(DIR) then pcall(makefolder,DIR) end
end
local function fs_read_state()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok,data=pcall(readfile,STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2,decoded=pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end
local function fs_write_state(tbl)
    if not (writefile and HttpService) then return end
    local ok,json=pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile,STATE_FILE,json) end
end
local function normKey(s) s=tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]",""); return string.upper(s) end

-------------------- Globals --------------------
local G = (getgenv and getgenv()) or _G
local flags = { key_ok=false, main_ui_open=false, download_done=false }

G.UFO_SaveKeyState=function(key,exp,perm)
    fs_ensure_dir()
    fs_write_state({ key=key, permanent=perm, expires_at=exp })
    flags.key_ok=true
end

G.UFO_StartDownload=function()
    task.spawn(function()
        local ok,src=http_get(URL_DOWNLOAD)
        if ok then loadstring(src)() end
    end)
end

G.UFO_DownloadFinished=function()
    flags.download_done=true
end

G.UFO_ShowMain=function()
    if flags.main_ui_open then return end
    task.delay(DOWNLOAD_HANDOFF_DELAY,function()
        if flags.main_ui_open then return end
        local ok,src=http_get(URL_MAINUI)
        if ok then
            flags.main_ui_open=true
            loadstring(src)()
            -- เมื่อ Main UI ขึ้น → โหลดฟีเจอร์เกมตามชื่อ
            task.delay(0.5,function()
                local place=game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
                local mapUrl=MAPS[place]
                if mapUrl then
                    local ok2,src2=http_get(mapUrl)
                    if ok2 then
                        print("[UFO-HUB-X] Loading features for map:",place)
                        loadstring(src2)()
                    else
                        warn("[UFO-HUB-X] Failed to load map:",place)
                    end
                else
                    print("[UFO-HUB-X] No features mapped for this game:",place)
                end
            end)
        end
    end)
end

-------------------- Key State --------------------
local function key_valid()
    local st=fs_read_state()
    if not st or not st.key then return false end
    if ALLOW_KEYS[normKey(st.key)] then return true end
    if st.permanent then return true end
    if st.expires_at and os.time()<st.expires_at then return true end
    return false
end

-------------------- Boot --------------------
fs_ensure_dir()
if key_valid() then
    G.UFO_StartDownload()
    task.spawn(function()
        local t0=os.clock()
        while (os.clock()-t0)<DOWNLOAD_CALLBACK_TIMEOUT do
            if flags.download_done then return end
            task.wait(0.25)
        end
        warn("[UFO-HUB-X] Download UI timeout")
    end)
else
    local ok,src=http_get(URL_KEY)
    if ok then loadstring(src)() end
end

-- กันสคริปต์ปิดเอง
while true do task.wait(10) end
