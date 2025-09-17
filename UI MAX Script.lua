-- UI MAX Script.lua
-- UFO HUB X — Boot Loader Pro (Map → Key → Download → Main UI + Feature Registry)
-- รองรับ Delta / syn / KRNL / Script-Ware / Fluxus + loadstring(HttpGet)

--=========================[ Services + Compat ]===========================
local HttpService = game:GetService("HttpService")
local TS          = game:GetService("TweenService")
local CG          = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")

local function http_get(url)
    -- ครอบ executor ต่าง ๆ ให้หมด
    if http and http.request then
        local ok, res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "httpget_failed"
end

local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

--=========================[ FS: persist state ]===========================
local DIR           = "UFOHubX"
local STATE_FILE    = DIR.."/key_state.json"
local function ensureDir()
    if isfolder then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
end
ensureDir()

local function readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function writeState(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

--=========================[ Config URLs ]===========================
-- เปลี่ยน URL ด้านล่างให้เป็น RAW ของนายเองตาม repo ที่แจก
local URL_KEYUI     = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD  = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI    = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"
local URL_GAMESCFG  = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-MAX/refs/heads/main/games.json"

-- Server verify key (สำหรับ Key UI)
local GETKEY_URL   = "https://ufo-hub-x-key.onrender.com"

-- Allow-list พิเศษ (ผ่านถาวร)
local ALLOW_KEYS   = {
    ["JJJMAX"]                = { permanent=true, reusable=true, expires_at=nil }, -- ทดลอง
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true, reusable=true, expires_at=nil }, -- ถาวร
}
local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

--=========================[ Game Detector ]===========================
local PLACE_ID = game.PlaceId
local GAME_NAME = ""
pcall(function()
    local info = MarketplaceService:GetProductInfo(PLACE_ID)
    GAME_NAME = info and info.Name or ""
end)

local GAME_CFG = nil
do
    local ok, json = http_get(URL_GAMESCFG)
    if ok and json and #json>0 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(json) end)
        if ok2 and type(data)=="table" then GAME_CFG = data end
    end
end

local function pickGameEntry()
    if not GAME_CFG then return nil end
    -- 1) Match ด้วย placeId ก่อน
    for name, entry in pairs(GAME_CFG) do
        if entry.placeIds and table.find(entry.placeIds, PLACE_ID) then
            return name, entry
        end
    end
    -- 2) สำรองด้วยชื่อเกมแบบ fuzzy
    for name, entry in pairs(GAME_CFG) do
        if tostring(GAME_NAME):lower():find(tostring(name):lower(),1,true) then
            return name, entry
        end
    end
    return nil
end

local GAME_KEY, GAME_ENTRY = pickGameEntry()

-- ถ้าไม่มีใน config → หยุดเงียบๆ
if not GAME_ENTRY then
    warn("[UFO HUB X] Unsupported map. Nothing will be shown.")
    return
end

--=========================[ Key validity ]===========================
local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    -- allow-list ถาวร
    if st.permanent == true then return true end
    -- time-based
    if st.expires_at and typeof(st.expires_at)=="number" then
        return (os.time() < st.expires_at)
    end
    return false
end

--=========================[ Global Orchestrator Callbacks ]===========================
-- จะถูกเรียกจาก Key UI (ของนาย) เมื่อคีย์ผ่าน เพื่อบันทึกสถานะ
getgenv().UFO_SaveKeyState = function(key, expires_at, permanent)
    local nk = normKey(key)
    local allow = ALLOW_KEYS[nk]
    local st = {
        key       = key,
        permanent = (permanent == true) or (allow and allow.permanent == true) or false,
        expires_at= nil
    }
    -- ถ้า server ส่ง expires_at มา
    if expires_at and type(expires_at)=="number" then
        st.expires_at = expires_at
    end
    writeState(st)
end

-- เรียกจาก Key UI → ไปหน้า Download
getgenv().UFO_StartDownload = function()
    -- โหลดหน้าดาวน์โหลด
    local ok, src = http_get(URL_DOWNLOAD)
    if ok then
        local f, e = loadstring(src)
        if f then
            local s, err = pcall(f)
            if not s then warn("[UFO HUB X] Download UI error:", err) end
        else
            warn("[UFO HUB X] Download UI compile error:", e)
        end
    else
        warn("[UFO HUB X] Download UI http error:", src)
    end
end

-- เรียกจากหน้า Download → ไปหน้า UI หลัก
getgenv().UFO_ShowMain = function()
    -- โหลด UI หลัก
    local ok, src = http_get(URL_MAINUI)
    if ok then
        local f, e = loadstring(src)
        if f then
            local s, err = pcall(f)
            if not s then warn("[UFO HUB X] Main UI error:", err) end
        else
            warn("[UFO HUB X] Main UI compile error:", e)
        end
    else
        warn("[UFO HUB X] Main UI http error:", src)
    end

    -- Inject ฟีเจอร์เข้า UI หลัก (ถ้า UI หลักมี hook ให้ต่อ)
    task.delay(0.25, function()
        if getgenv().UFO_AttachFeaturePanel then
            -- ถ้า UI หลักของนายมีฟังก์ชันนี้ จะส่ง registry ไปให้สร้างปุ่มด้านใน
            getgenv().UFO_AttachFeaturePanel(getgenv().UFO_FeatureRegistry or {})
        else
            -- ถ้า UI หลักไม่มี hook → สร้าง Mini Overlay ให้ใช้ชั่วคราว
            local reg = getgenv().UFO_FeatureRegistry or {}
            local features = _G.UFO_CurrentGame and _G.UFO_CurrentGame.features or {}
            if #features > 0 then
                local gui = Instance.new("ScreenGui")
                gui.Name="UFOHubX_FeaturePanel"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
                safeParent(gui)
                local frame = Instance.new("Frame", gui)
                frame.Size=UDim2.fromOffset(260, (#features * 36) + 24 + 16)
                frame.Position=UDim2.fromScale(0.85, 0.5); frame.AnchorPoint=Vector2.new(0.5,0.5)
                frame.BackgroundColor3=Color3.fromRGB(14,14,14)
                local c = Instance.new("UICorner",frame) c.CornerRadius=UDim.new(0,12)
                local s = Instance.new("UIStroke",frame) s.Color=Color3.fromRGB(0,255,140); s.Transparency=0.4
                local h = Instance.new("TextLabel", frame)
                h.BackgroundTransparency=1; h.Size=UDim2.new(1, -16, 0, 24); h.Position=UDim2.new(0,8,0,8)
                h.Font=Enum.Font.GothamBold; h.TextSize=16; h.TextXAlignment=Enum.TextXAlignment.Left
                h.TextColor3=Color3.fromRGB(235,235,235); h.Text="UFO HUB X — Features"

                local y = 8+24+8
                for _,key in ipairs(features) do
                    local info = reg[key]
                    if info then
                        local b = Instance.new("TextButton", frame)
                        b.Size=UDim2.new(1,-16,0,32); b.Position=UDim2.new(0,8,0,y)
                        b.BackgroundColor3=Color3.fromRGB(24,24,24); b.TextColor3=Color3.new(1,1,1)
                        b.Font=Enum.Font.GothamBold; b.TextSize=14
                        b.Text = info.title or key
                        local bc = Instance.new("UICorner",b) bc.CornerRadius=UDim.new(0,8)
                        y = y + 36
                        b.MouseButton1Click:Connect(function()
                            local ok, err = pcall(function() info.callback() end)
                            if not ok then warn("[UFO HUB X] Feature error:", key, err) end
                        end)
                    end
                end
            end
        end
    end)
end

--=========================[ Publish Current Game Context ]===========================
_G.UFO_CurrentGame = {
    name     = GAME_KEY,
    placeId  = PLACE_ID,
    features = GAME_ENTRY.features or {},
    showUI   = GAME_ENTRY.ui == true
}

--=========================[ Feature Registry (ตามคอนฟิก) ]===========================
-- สร้าง registry รวมไว้ที่ getgenv().UFO_FeatureRegistry เพื่อให้ UI หลักหรือ mini panel ใช้งาน
getgenv().UFO_FeatureRegistry = getgenv().UFO_FeatureRegistry or {}

local function regFeature(key, title, callback)
    getgenv().UFO_FeatureRegistry[key] = { title = title, callback = callback }
end

-- ===== ตัวอย่างฟีเจอร์จริง (พร้อมใช้งาน) =====
-- 1) Speed Boost (วิ่งไว)
regFeature("speedBoost", "Speed Boost (Toggle)", function()
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = (hum.WalkSpeed > 16) and 16 or 36  -- toggle 16/36
end)

-- 2) Safe Mode (กันตก/กันค่าติดลบเบื้องต้น)
regFeature("safeMode", "Safe Mode", function()
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    task.spawn(function()
        while task.wait(0.3) do
            local char = lp.Character
            if not char then continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hrp.Position.Y < -10 then
                hrp.CFrame = CFrame.new(0, 20, 0)  -- วาร์ปกลับพื้น
                hum.Health = math.max(hum.Health, 10)
            end
        end
    end)
end)

-- 3) Grow a Garden เฉพาะ (ตัวอย่าง logic ง่าย ๆ)
regFeature("autoPlant", "Garden: Auto Plant", function()
    -- โค้ดตัวอย่าง: ตะลุยหา plot แล้ว plant (ต้องปรับตามชื่อ object/module ของเกมจริง)
    print("[UFO] AutoPlant started (example) — ปรับ ID/ชื่อ Object ให้ตรงแมพจริง")
end)

regFeature("autoWater", "Garden: Auto Water", function()
    print("[UFO] AutoWater started (example)")
end)

regFeature("autoHarvest", "Garden: Auto Harvest", function()
    print("[UFO] AutoHarvest started (example)")
end)

regFeature("teleportPads", "Garden: Teleport Pads", function()
    print("[UFO] Teleport Pads (example)")
end)

--=========================[ Boot Sequence ]===========================
-- 1) ถ้าแมพรองรับแต่ตั้งค่ามาให้ไม่ต้องโชว์ UI → หยุดฟีเจอร์ทั้งหมด (โชว์อะไรไม่ได้)
if _G.UFO_CurrentGame.showUI ~= true then
    warn("[UFO HUB X] This map configured to hide UI. Nothing will be shown.")
    return
end

-- 2) ตรวจคีย์ ถ้ายัง valid → ข้าม Key UI
local needKey = not isKeyStillValid()

if needKey then
    -- เปิด Key UI (ไฟล์ของนาย)
    local ok, src = http_get(URL_KEYUI)
    if ok then
        local f, e = loadstring(src)
        if f then
            local s, err = pcall(f)
            if not s then warn("[UFO HUB X] Key UI error:", err) end
        else
            warn("[UFO HUB X] Key UI compile error:", e)
        end
    else
        warn("[UFO HUB X] Key UI http error:", src)
    end
else
    -- ข้าม Key UI → ไป Download ทันที
    getgenv().UFO_StartDownload()
end
