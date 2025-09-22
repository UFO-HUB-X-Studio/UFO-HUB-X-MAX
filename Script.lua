--========================================================
-- UFO HUB X — Multi-Map Boot (No Key, Lang Picker → Download → Main UI → Map Script)
--========================================================
local HttpService  = game:GetService("HttpService")
local UIS          = game:GetService("UserInputService")
local CG           = game:GetService("CoreGui")

local function log(s)
    s = "[UFO-HUB-X] "..tostring(s)
    if rconsoleprint then rconsoleprint(s.."\n") else print(s) end
end

-- ---------------- HTTP helpers ----------------
local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"httpget_failed"
end

local function http_get_retry(urls, tries, delay_s)
    local list = type(urls)=="table" and urls or {urls}
    tries   = tries or 3
    delay_s = delay_s or 0.6
    local attempt = 0
    for r=1,tries do
        for _,u in ipairs(list) do
            attempt += 1
            log(("HTTP try #%d → %s"):format(attempt,u))
            local ok,body = http_get(u)
            if ok and body then return true,body,u end
        end
        task.wait(delay_s * r)
    end
    return false,"retry_failed"
end

local function safe_run(src, tag)
    local f, e = loadstring(src, tag or "chunk")
    if not f then return false, "loadstring: "..tostring(e) end
    local ok, err = pcall(f)
    if not ok then return false, "pcall: "..tostring(err) end
    return true
end

-- ---------------- Config: URLs ----------------
-- (1) ตัวบูตกลาง MAX (วิ่งเสมอ ก่อนเช็คแมพ)
local URL_RUN_ALL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-MAX/refs/heads/main/Script.lua"

-- (2) หน้าดาวน์โหลด + UI หลัก
local URL_DOWNLOADS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua",
}
local URL_MAINS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua",
}

-- (3) รายการแมพที่รองรับ + สคริปต์แยกภาษา
local SUPPORTED_MAPS = {
    -- Build a Zoo
    ["105555311806207"] = {
        name = "Build a Zoo",
        TH = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/Build-a-Zoo-TH/refs/heads/main/Build%20a%20Zoo%20TH.lua",
        EN = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/Build-a-Zoo-EN/refs/heads/main/Build%20a%20Zoo%20EN.lua",
    },
    -- เพิ่มแมพอื่น ๆ ต่อได้รูปแบบเดียวกัน
}

-- ---------------- UI helpers ----------------
local function make(class, props, kids)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do
        local ok,err = pcall(function() o[k]=v end)
        if not ok then warn("[UFO] prop set err:",k,err) end
    end
    for _,c in ipairs(kids or {}) do c.Parent = o end
    return o
end

local function SOFT_PARENT(gui)
    if not gui then return end
    pcall(function()
        if gui:IsA("ScreenGui") then
            gui.Enabled=true
            gui.DisplayOrder=999999
            gui.ResetOnSpawn=false
            gui.IgnoreGuiInset=true
            gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        end
    end)
    local ok=false
    if gethui then ok=pcall(function() gui.Parent = gethui() end) end
    if (not ok) or (not gui.Parent) then ok=pcall(function() gui.Parent = CG end) end
    if (not ok) or (not gui.Parent) then
        local pg = game.Players.LocalPlayer and (game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui",2))
        if pg then pcall(function() gui.Parent = pg end) end
    end
end

-- ---------------- Language Picker ----------------
local function showLanguagePicker(mapName, onPick)
    local gui = Instance.new("ScreenGui")
    gui.Name = "UFOX_LangPicker"
    SOFT_PARENT(gui)

    local panel = make("Frame",{
        Parent=gui, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(520,240), BackgroundColor3=Color3.fromRGB(12,12,12), BorderSizePixel=0
    },{
        make("UICorner",{CornerRadius=UDim.new(0,18)}),
        make("UIStroke",{Color=Color3.fromRGB(0,255,170), Transparency=0.75, Thickness=2})
    })

    make("TextLabel",{
        Parent=panel, BackgroundTransparency=1, Size=UDim2.new(1,0,0,44), Position=UDim2.new(0,0,0,14),
        Font=Enum.Font.GothamBlack, TextSize=22,
        Text=("Select Language for %s"):format(mapName or "Map"),
        TextColor3=Color3.fromRGB(220,255,240)
    },{})

    local row = make("Frame",{
        Parent=panel, BackgroundTransparency=1, Size=UDim2.new(1, -40, 0, 130), Position=UDim2.new(0,20,0,80)
    },{})
    make("UIListLayout",{
        Parent=row, FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,14),
        HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center
    },{})

    local function langButton(txt, sub, color)
        local b = make("TextButton",{
            Parent=row, AutoButtonColor=true,
            Size=UDim2.new(0.5,-7,1,0), BackgroundColor3=color or Color3.fromRGB(30,30,30),
            Font=Enum.Font.GothamBlack, TextSize=20, Text=txt, TextColor3=Color3.new(1,1,1)
        },{
            make("UICorner",{CornerRadius=UDim.new(0,14)}),
            make("UIStroke",{Color=Color3.fromRGB(255,255,255), Transparency=0.85})
        })
        make("TextLabel",{
            Parent=b, BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,1), Position=UDim2.new(0.5,0,1,-8),
            Size=UDim2.new(1,-20,0,16), Font=Enum.Font.Gotham, TextSize=14, Text=sub or "", TextColor3=Color3.fromRGB(230,230,230)
        },{})
        return b
    end

    local btnTH = langButton("ภาษาไทย 🇹🇭", "Thai", Color3.fromRGB(36,48,70))
    local btnEN = langButton("English 🇺🇸", "English", Color3.fromRGB(48,36,36))

    local done = false
    local function pick(code)
        if done then return end
        done = true
        pcall(function() gui:Destroy() end)
        if onPick then onPick(code) end
    end
    btnTH.MouseButton1Click:Connect(function() pick("TH") end)
    btnEN.MouseButton1Click:Connect(function() pick("EN") end)

    return gui
end

-- ---------------- Download → Main → Map chain ----------------
local function startDownloadThenMain(onMainReady)
    local ok, src = http_get_retry(URL_DOWNLOADS, 5, 0.8)
    if not ok then
        log("Download UI fetch failed → open Main directly")
        local okm, srcm = http_get_retry(URL_MAINS, 5, 0.8)
        if okm then safe_run(srcm, "UFOHubX_Main") end
        if onMainReady then onMainReady() end
        return
    end
    -- แพตช์ให้จบแล้วเรียก Main เสมอ
    local patched = src
    local injected = 0
    patched, injected = patched:gsub(
        "gui:Destroy%(%);?",
        [[
if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
gui:Destroy();
]]
    )
    _G.UFO_ShowMain = function()
        if _G.__UFO_Main_Started then return end
        _G.__UFO_Main_Started = true
        local okm, srcm = http_get_retry(URL_MAINS, 5, 0.8)
        if okm then safe_run(srcm, "UFOHubX_Main") end
        if onMainReady then onMainReady() end
    end
    safe_run(patched, "UFOHubX_Download")
end

local function runMapScript(url)
    if not url or #url==0 then return end
    local ok, src = http_get_retry(url, 4, 0.7)
    if not ok then log("Map script load failed: "..tostring(url)) return end
    safe_run(src, "UFOHubX_Map")
end

-- ---------------- Boot flow ----------------
-- 0) รันสคริปต์รวม MAX เสมอ
do
    local ok, src = http_get_retry(URL_RUN_ALL, 3, 0.6)
    if ok then
        local ok2, err = safe_run(src, "UFOHubX_MAX_All")
        if not ok2 then log("MAX run error: "..tostring(err)) end
    else
        log("MAX bundle fetch failed (continue anyway).")
    end
end

-- 1) เช็คว่าแมพรองรับไหม
local placeId = tostring(game.PlaceId or "")
local cfg = SUPPORTED_MAPS[placeId]
if not cfg then
    -- ไม่รองรับแมพ ⇒ ไม่แสดงอะไรเลย
    log("Map not supported. Boot ends silently.")
    return
end

-- 2) ถ้ารองรับ ⇒ ให้เลือกภาษา ก่อนขึ้น Download → Main → Map
showLanguagePicker(cfg.name or ("Place "..placeId), function(lang)
    local langKey = (lang == "TH") and "TH" or "EN"
    local mapURL  = cfg[langKey]
    -- ลุย: Download → Main → Map
    startDownloadThenMain(function()
        runMapScript(mapURL)
    end)
end)
