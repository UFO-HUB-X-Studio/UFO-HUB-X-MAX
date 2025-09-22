--[[  UFO HUB X — Multi-Map, Language Picker, No-Key Boot
     - แมพไม่รองรับ -> ไม่ทำอะไรเลย
     - แมพรองรับ -> เลือกภาษา (TH/EN + ธง) -> รัน GameCore -> Main UI -> MAX -> Map Script ตามภาษา
     - จำภาษาที่เลือกไว้ในไฟล์ UFOHubX/lang.json
]]

--========================================================
-- Services / Utils
--========================================================
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")

local function log(s)
    s = "[UFO-MULTI] "..tostring(s)
    if rconsoleprint then rconsoleprint(s.."\n") else print(s) end
end

local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url,Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"http_failed"
end

local function http_get_retry(urls, tries, gap)
    local list = type(urls)=="table" and urls or {urls}
    tries, gap = tries or 3, gap or 0.7
    local n=0
    for r=1,tries do
        for _,u in ipairs(list) do
            n+=1; log(("GET try#%d %s"):format(n,u))
            local ok,body = http_get(u)
            if ok and body then return true,body,u end
        end
        task.wait(gap*r)
    end
    return false,"retry_fail"
end

local function safe_run(src, tag)
    local f,e=loadstring(src, tag or "chunk")
    if not f then return false,"load: "..tostring(e) end
    local ok,err=pcall(f)
    if not ok then return false,"pcall: "..tostring(err) end
    return true
end

--========================================================
-- File state (จำภาษา)
--========================================================
local DIR       = "UFOHubX"
local LANG_FILE = DIR.."/lang.json"
if isfolder and not isfolder(DIR) then pcall(makefolder,DIR) end

local function readLang()
    if not (isfile and isfile(LANG_FILE)) then return nil end
    local ok,raw=pcall(readfile,LANG_FILE); if not ok or not raw then return nil end
    local ok2,js=pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and js and js.lang then return js.lang end
    return nil
end
local function saveLang(code)
    if not writefile then return end
    local ok,raw=pcall(function() return HttpService:JSONEncode({lang=code, saved_at=os.time()}) end)
    if ok then pcall(writefile, LANG_FILE, raw) end
end

--========================================================
-- URLs กลาง
--========================================================
-- 1) ระบบเกมรวม (Boot ของโปรเจกต์เกมรวม)
local URL_GAME_BOOT = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Game/refs/heads/main/Boot.lua",
}
-- 2) UI หน้าหลัก
local URL_MAIN_UI = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua",
}
-- 3) MAX Script รวม
local URL_MAX_SCRIPT = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-MAX/refs/heads/main/Script.lua",
}

--========================================================
-- ตารางรองรับหลายแมพ + ภาษา (เติมแมพใหม่ ๆ ต่อท้ายได้)
--   key = PlaceId, value = { name="...", th="<raw>", en="<raw>" }
--========================================================
local MAPS = {
    [105555311806207] = {
        name = "Build a Zoo",
        en   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/Build-a-Zoo-EN/refs/heads/main/Build%20a%20Zoo%20EN.lua",
        th   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/Build-a-Zoo-TH/refs/heads/main/Build%20a%20Zoo%20TH.lua",
    },
}

--========================================================
-- Language Picker UI (เล็ก ๆ + ธง)
--========================================================
local function showLangPicker()
    local CG = game:GetService("CoreGui")
    local scr = Instance.new("ScreenGui")
    scr.Name="UFO_LangPicker"; scr.IgnoreGuiInset=true; scr.ResetOnSpawn=false
    local ok=false
    if gethui then ok=pcall(function() scr.Parent=gethui() end) end
    if not ok then scr.Parent=CG end

    local panel=Instance.new("Frame",scr)
    panel.AnchorPoint=Vector2.new(0.5,0.5)
    panel.Position=UDim2.fromScale(0.5,0.5)
    panel.Size=UDim2.fromOffset(420,160)
    panel.BackgroundColor3=Color3.fromRGB(12,12,12)
    panel.BorderSizePixel=0
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
    local st=Instance.new("UIStroke",panel); st.Color=Color3.fromRGB(0,255,140); st.Transparency=0.25

    local title=Instance.new("TextLabel",panel)
    title.BackgroundTransparency=1; title.Position=UDim2.new(0,0,0,14); title.Size=UDim2.new(1,0,0,28)
    title.Text="Choose your language"; title.Font=Enum.Font.GothamBlack; title.TextSize=22
    title.TextColor3=Color3.fromRGB(230,230,230)

    local row=Instance.new("Frame",panel); row.BackgroundTransparency=1; row.Position=UDim2.new(0,20,0,64); row.Size=UDim2.new(1,-40,0,72)
    local list=Instance.new("UIListLayout",row); list.FillDirection=Enum.FillDirection.Horizontal; list.Padding=UDim.new(0,20)
    list.HorizontalAlignment=Enum.HorizontalAlignment.Center; list.VerticalAlignment=Enum.VerticalAlignment.Center

    local function makeBtn(txt, flagId)
        local b=Instance.new("TextButton"); b.Parent=row; b.Size=UDim2.fromOffset(160,64)
        b.AutoButtonColor=false; b.BackgroundColor3=Color3.fromRGB(26,26,26); b.Text=""
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,12)
        local s=Instance.new("UIStroke",b); s.Color=Color3.fromRGB(80,180,140); s.Transparency=0.4
        local img=Instance.new("ImageLabel",b); img.BackgroundTransparency=1; img.Size=UDim2.new(0,32,0,32); img.Position=UDim2.new(0,16,0.5,-16)
        img.Image = flagId or "rbxassetid://14278548871" -- เปลี่ยนเป็น asset id ธงที่ชอบได้
        local lab=Instance.new("TextLabel",b); lab.BackgroundTransparency=1; lab.Position=UDim2.new(0,56,0,0); lab.Size=UDim2.new(1,-64,1,0)
        lab.Font=Enum.Font.GothamBold; lab.TextSize=20; lab.TextXAlignment=Enum.TextXAlignment.Left; lab.TextColor3=Color3.fromRGB(230,230,230); lab.Text=txt
        return b
    end

    local btnTH = makeBtn("ภาษาไทย 🇹🇭", "rbxassetid://14278548871")
    local btnEN = makeBtn("English 🇬🇧", "rbxassetid://14278549254")

    local chosen=nil
    btnTH.MouseButton1Click:Connect(function() chosen="th"; scr:Destroy() end)
    btnEN.MouseButton1Click:Connect(function() chosen="en"; scr:Destroy() end)

    UIS.InputBegan:Connect(function(i,gpe) if not gpe and i.KeyCode==Enum.KeyCode.Escape then scr:Destroy() end end)
    repeat task.wait(0.05) until not scr.Parent
    return chosen
end

--========================================================
-- Boot sequence
--========================================================
local placeId = game.PlaceId
local entry   = MAPS[placeId]

if not entry then
    log(("Place %s not supported → do nothing."):format(tostring(placeId)))
    return
end

log(("Place supported: %s (%s)"):format(entry.name or "?", tostring(placeId)))

-- เลือกภาษา (อ่านจากไฟล์ก่อน ถ้าไม่มีให้ถาม)
local lang = readLang()
if lang ~= "th" and lang ~= "en" then
    lang = showLangPicker() or "en"
    saveLang(lang)
end

-- เลือก URL ตามภาษา
local mapURL = (lang=="th" and entry.th) or entry.en or entry.th
if not mapURL then
    log("No script URL for selected language → abort.")
    return
end

local function run_url_list(name, urls)
    local ok,src = http_get_retry(urls, 5, 0.8)
    if not ok then log(name.." fetch failed."); return false end
    local ok2,err = safe_run(src, name)
    if not ok2 then log(name.." run failed: "..tostring(err)); return false end
    log(name.." started."); return true
end

-- 1) ระบบเกมรวม
run_url_list("GameCore", URL_GAME_BOOT)
-- 2) UI หลัก
run_url_list("MainUI", URL_MAIN_UI)
-- 3) MAX Script รวม
run_url_list("MAX", URL_MAX_SCRIPT)
-- 4) Map Script ตามภาษา
do
    local ok, src = http_get(mapURL)
    if not ok then log("Map script fetch failed.") return end
    local ok2, err = safe_run(src, (entry.name or "Map").."_"..lang)
    if not ok2 then log("Map script run failed: "..tostring(err)) return end
    log("Map script started.")
end
