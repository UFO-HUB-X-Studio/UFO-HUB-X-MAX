-- UI MAX Script.lua
-- UFO HUB X — Boot Loader (Key → Download → Main UI)
-- รองรับ Delta / syn / KRNL / Script-Ware / Fluxus ฯลฯ + loadstring(HttpGet)

--=========================[ Services + Compat ]===========================
local HttpService = game:GetService("HttpService")
local TS          = game:GetService("TweenService")
local CG          = game:GetService("CoreGui")

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

--=========================[ Config ]===========================
local GETKEY_URL   = "https://ufo-hub-x-key.onrender.com"
local ALLOW_KEYS   = {
    ["JJJMAX"]                = { permanent=true, reusable=true, expires_at=nil }, -- ทดลอง
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true, reusable=true, expires_at=nil }, -- ถาวร
}

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

--=========================[ Key validity ]===========================
local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    -- permanent key => valid always
    if st.permanent == true then return true end
    -- time-based
    if st.expires_at and typeof(st.expires_at)=="number" then
        return (os.time() < st.expires_at)
    end
    return false
end

--=========================[ Module sources (write files) ]===========================
-- เราเขียนไฟล์ 3 ตัวให้เสมอ เพื่ออัพเดตเวอร์ชันล่าสุด
local SRC_KEY = [[
-- UFO HUB X Key.lua
-- (v16+) Key UI : invalid → แดง/ลบข้อความ/Toast, allow-list, server verify, ยืนยันแล้วปิดตัวเอง
local TS   = game:GetService("TweenService")
local CG   = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local GETKEY_URL  = "https://ufo-hub-x-key.onrender.com"
local LOGO_ID     = 112676905543996
local ACCENT      = Color3.fromRGB(0,255,140)
local BG_DARK     = Color3.fromRGB(10,10,10)
local FG          = Color3.fromRGB(235,235,235)
local SUB         = Color3.fromRGB(22,22,22)

local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

-- allow-list พิเศษ
local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent = true, reusable = true },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent = true, reusable = true },
}
local function normKey(s) s=tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]",""); return string.upper(s) end
local function isAllowedKey(k) local nk=normKey(k); return (ALLOW_KEYS[nk]~=nil), nk, ALLOW_KEYS[nk] end

-- http wrapper
local function http_get(url)
    if http and http.request then local ok,res=pcall(http.request,{Url=url,Method="GET"}); if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end end
    if syn and syn.request then local ok,res=pcall(syn.request,{Url=url,Method="GET"}); if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end end
    local ok,body=pcall(function() return game:HttpGet(url) end); if ok and body then return true,body end
    return false,"httpget_failed"
end
local function verifyWithServer(k)
    local url = GETKEY_URL.."/verify?key="..HttpService:UrlEncode(k)
    local ok, res = http_get(url)
    if ok and res then
        local low = tostring(res):lower()
        -- รองรับทั้ง string/JSON ที่มีคำพวกนี้
        local valid = (low:find("valid") or low:find('"valid"%s*:%s*true') or low:find("ok") or low:find("true")) and true or false
        local exp   = nil
        -- ลองอ่าน expires_at ถ้ามี
        pcall(function()
            local js = HttpService:JSONDecode(res)
            if js and js.expires_at then
                exp = tonumber(js.expires_at)
            elseif js and js.expires_in then
                exp = os.time() + tonumber(js.expires_in)
            end
        end)
        return valid, (valid and exp or nil), (valid and nil or "server_invalid")
    end
    return false, nil, "unreachable"
end

-- UI สร้าง
local gui = Instance.new("ScreenGui")
gui.Name = "UFOHubX_KeyUI"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
safeParent(gui)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(740,430); panel.AnchorPoint=Vector2.new(0.5,0.5); panel.Position=UDim2.fromScale(0.5,0.5)
panel.BackgroundColor3=Color3.fromRGB(10,10,10); panel.BorderSizePixel=0; panel.Active=true; panel.Draggable=true; panel.Parent=gui
local c = Instance.new("UICorner",panel) c.CornerRadius=UDim.new(0,22)
local s = Instance.new("UIStroke",panel) s.Color=ACCENT; s.Thickness=2; s.Transparency=0.1

local head = Instance.new("Frame")
head.Parent=panel; head.BackgroundTransparency=0.15; head.BackgroundColor3=Color3.fromRGB(14,14,14)
head.Size=UDim2.new(1,-28,0,68); head.Position=UDim2.new(0,14,0,14)
local hc = Instance.new("UICorner",head) hc.CornerRadius=UDim.new(0,16)
local hs = Instance.new("UIStroke",head) hs.Color=ACCENT; hs.Transparency=0.85

local logo = Instance.new("ImageLabel")
logo.Parent=head; logo.BackgroundTransparency=1; logo.Image="rbxassetid://"..LOGO_ID
logo.Size=UDim2.new(0,34,0,34); logo.Position=UDim2.new(0,16,0,17)

local title = Instance.new("TextLabel")
title.Parent=head; title.BackgroundTransparency=1; title.Position=UDim2.new(0,60,0,18)
title.Size=UDim2.new(0,200,0,32); title.Font=Enum.Font.GothamBold; title.TextSize=20
title.Text="KEY SYSTEM"; title.TextColor3=ACCENT; title.TextXAlignment=Enum.TextXAlignment.Left

local keyLbl = Instance.new("TextLabel")
keyLbl.Parent=panel; keyLbl.BackgroundTransparency=1; keyLbl.Position=UDim2.new(0,28,0,188)
keyLbl.Size=UDim2.new(0,60,0,22); keyLbl.Font=Enum.Font.Gotham; keyLbl.TextSize=16
keyLbl.Text="Key"; keyLbl.TextColor3=Color3.fromRGB(200,200,200); keyLbl.TextXAlignment=Enum.TextXAlignment.Left

local keyBox = Instance.new("TextBox")
keyBox.Parent=panel; keyBox.ClearTextOnFocus=false; keyBox.PlaceholderText="insert your key here"
keyBox.Font=Enum.Font.Gotham; keyBox.TextSize=16; keyBox.Text=""; keyBox.TextColor3=FG
keyBox.BackgroundColor3=Color3.fromRGB(22,22,22); keyBox.BorderSizePixel=0
keyBox.Size=UDim2.new(1,-56,0,40); keyBox.Position=UDim2.new(0,28,0,214)
local kC = Instance.new("UICorner",keyBox) kC.CornerRadius=UDim.new(0,12)
local kS = Instance.new("UIStroke",keyBox) kS.Color=ACCENT; kS.Transparency=0.75

local btnSubmit = Instance.new("TextButton")
btnSubmit.Parent=panel; btnSubmit.Text="🔒  Submit Key"; btnSubmit.Font=Enum.Font.GothamBlack; btnSubmit.TextSize=20
btnSubmit.TextColor3=Color3.new(1,1,1); btnSubmit.AutoButtonColor=false
btnSubmit.BackgroundColor3=Color3.fromRGB(210,60,60); btnSubmit.BorderSizePixel=0
btnSubmit.Size=UDim2.new(1,-56,0,50); btnSubmit.Position=UDim2.new(0,28,0,268)
local bC = Instance.new("UICorner",btnSubmit) bC.CornerRadius=UDim.new(0,14)

local statusLabel = Instance.new("TextLabel")
statusLabel.Parent=panel; statusLabel.BackgroundTransparency=1
statusLabel.Position=UDim2.new(0,28,0,268+50+6); statusLabel.Size=UDim2.new(1,-56,0,24)
statusLabel.Font=Enum.Font.Gotham; statusLabel.TextSize=14; statusLabel.Text=""
statusLabel.TextColor3=Color3.fromRGB(200,200,200); statusLabel.TextXAlignment=Enum.TextXAlignment.Left

local function setStatus(txt, ok)
    statusLabel.Text = txt or ""
    if ok==nil then statusLabel.TextColor3=Color3.fromRGB(200,200,200)
    elseif ok then statusLabel.TextColor3=Color3.fromRGB(120,255,170)
    else statusLabel.TextColor3=Color3.fromRGB(255,120,120) end
end

-- toast
local toast = Instance.new("TextLabel")
toast.Parent=panel; toast.BackgroundTransparency=0.15; toast.BackgroundColor3=Color3.fromRGB(30,30,30)
toast.Size=UDim2.fromOffset(0,32); toast.Position=UDim2.new(0.5,0,0,16); toast.AnchorPoint=Vector2.new(0.5,0)
toast.Visible=false; toast.Font=Enum.Font.GothamBold; toast.TextSize=14; toast.Text=""; toast.TextColor3=Color3.new(1,1,1); toast.ZIndex=100
local tPad = Instance.new("UIPadding",toast); tPad.PaddingLeft=UDim.new(0,14); tPad.PaddingRight=UDim.new(0,14)
local tC = Instance.new("UICorner",toast); tC.CornerRadius=UDim.new(0,10)
local function showToast(msg, ok)
    toast.Text = msg
    toast.TextColor3 = Color3.new(1,1,1)
    toast.BackgroundColor3 = ok and Color3.fromRGB(20,120,60) or Color3.fromRGB(150,35,35)
    toast.Size = UDim2.fromOffset(math.max(160, (#msg*8)+28), 32)
    toast.Visible = true
    toast.BackgroundTransparency = 0.15
    TS:Create(toast, TweenInfo.new(.08), {BackgroundTransparency = 0.05}):Play()
    task.delay(1.1, function()
        TS:Create(toast, TweenInfo.new(.15), {BackgroundTransparency = 1}):Play()
        task.delay(.15, function() toast.Visible=false end)
    end)
end

local submitting=false
local function refreshBtn()
    if submitting then return end
    local has = keyBox.Text and #keyBox.Text>0
    if has then
        TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(60,200,120)}):Play()
        btnSubmit.TextColor3=Color3.new(0,0,0)
        btnSubmit.Text="🔓  Submit Key"
    else
        TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(210,60,60)}):Play()
        btnSubmit.TextColor3=Color3.new(1,1,1)
        btnSubmit.Text="🔒  Submit Key"
    end
end
keyBox:GetPropertyChangedSignal("Text"):Connect(function() setStatus("",nil); refreshBtn() end)
refreshBtn()

local function flashError()
    local old = kS.Color
    TS:Create(kS, TweenInfo.new(.05), {Color=Color3.fromRGB(255,90,90), Transparency=0}):Play()
    task.delay(.22, function() TS:Create(kS, TweenInfo.new(.12), {Color=old, Transparency=0.75}):Play() end)
end

local function forceErrorUI(main, sub)
    TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(255,80,80)}):Play()
    btnSubmit.Text = main or "❌ Invalid Key"; btnSubmit.TextColor3=Color3.new(1,1,1)
    setStatus(sub or "กุญแจไม่ถูกต้อง ลองอีกครั้ง", false); showToast(sub or "รหัสไม่ถูกต้อง", false)
    flashError(); keyBox.Text=""; task.delay(0.02, function() keyBox:CaptureFocus() end)
    task.delay(1.2, function() submitting=false; btnSubmit.Active=true; refreshBtn() end)
end

local function successAndClose(k, expires_at, permanent)
    -- บันทึกสถานะผ่านไปให้ตัว orchestrator (ผ่าน shared/global callback)
    if getgenv and type(getgenv)=="function" then
        local g = getgenv()
        if g and g.UFO_SaveKeyState then
            g.UFO_SaveKeyState(k, expires_at, permanent and true or false)
        end
    elseif _G and _G.UFO_SaveKeyState then
        _G.UFO_SaveKeyState(k, expires_at, permanent and true or false)
    end

    -- แจ้ง orchestrator ให้ไปหน้า Download
    if getgenv and type(getgenv)=="function" then
        local g = getgenv()
        if g and g.UFO_StartDownload then g.UFO_StartDownload() end
    elseif _G and _G.UFO_StartDownload then
        _G.UFO_StartDownload()
    end

    gui:Destroy()
end

local function doSubmit()
    if submitting then return end
    submitting=true; btnSubmit.Active=false
    local raw = keyBox.Text or ""
    if raw=="" then forceErrorUI("🚫 Please enter a key","โปรดใส่รหัสก่อนนะ"); return end

    setStatus("กำลังตรวจสอบคีย์...", nil)
    TS:Create(btnSubmit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(70,170,120)}):Play()
    btnSubmit.Text="⏳ Verifying..."

    local okAllowed, nk, meta = isAllowedKey(raw)
    if okAllowed then
        TS:Create(btnSubmit, TweenInfo.new(.10), {BackgroundColor3=Color3.fromRGB(120,255,170)}):Play()
        btnSubmit.Text="✅ Key accepted"; btnSubmit.TextColor3=Color3.new(0,0,0)
        setStatus("ยืนยันคีย์สำเร็จ พร้อมใช้งาน!", true)
        task.delay(.25, function()
            successAndClose(raw, nil, true) -- permanent
        end)
        return
    end

    local ok, exp, reason = verifyWithServer(raw)
    if not ok then
        if reason=="unreachable" then
            forceErrorUI("❌ Invalid Key","เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่หรือตรวจเน็ต")
        else
            forceErrorUI("❌ Invalid Key","กุญแจไม่ถูกต้อง ลองอีกครั้ง")
        end
        return
    end

    -- ผ่าน (อาจมี exp หรือไม่มี)
    TS:Create(btnSubmit, TweenInfo.new(.10), {BackgroundColor3=Color3.fromRGB(120,255,170)}):Play()
    btnSubmit.Text="✅ Key accepted"; btnSubmit.TextColor3=Color3.new(0,0,0)
    setStatus("ยืนยันคีย์สำเร็จ พร้อมใช้งาน!", true)
    task.delay(.25, function()
        successAndClose(raw, exp, false)
    end)
end

btnSubmit.MouseButton1Click:Connect(doSubmit)
keyBox.FocusLost:Connect(function(enter) if enter then doSubmit() end end)

panel.Position = UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0,14)
TS:Create(panel, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.fromScale(0.5,0.5)}):Play()
]]

local SRC_DOWNLOAD = [[
-- UFO HUB X Download.lua
-- หน้าดาวน์โหลด/เตรียมระบบ → เสร็จแล้วปิดตัวเอง แล้วเรียกหน้า UI หลัก
local TS = game:GetService("TweenService")
local CG = game:GetService("CoreGui")

local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

local gui = Instance.new("ScreenGui")
gui.Name="UFOHubX_DownloadUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
safeParent(gui)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(560,180); frame.AnchorPoint=Vector2.new(0.5,0.5); frame.Position=UDim2.fromScale(0.5,0.5)
frame.BackgroundColor3=Color3.fromRGB(14,14,14)
local c = Instance.new("UICorner",frame) c.CornerRadius=UDim.new(0,16)
local s = Instance.new("UIStroke",frame) s.Color=Color3.fromRGB(0,255,140); s.Transparency=0.4

local title = Instance.new("TextLabel", frame)
title.BackgroundTransparency=1; title.Text="UFO HUB X — Preparing Resources"
title.Font=Enum.Font.GothamBlack; title.TextSize=20; title.TextColor3=Color3.fromRGB(235,235,235)
title.Size=UDim2.new(1, -24, 0, 36); title.Position=UDim2.new(0,12,0,12); title.TextXAlignment=Enum.TextXAlignment.Left

local bar = Instance.new("Frame", frame)
bar.Size=UDim2.new(1,-24,0,10); bar.Position=UDim2.new(0,12,0,68); bar.BackgroundColor3=Color3.fromRGB(28,28,28)
local bc = Instance.new("UICorner",bar) bc.CornerRadius=UDim.new(0,8)

local fill = Instance.new("Frame", bar)
fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=Color3.fromRGB(0,255,140)
local fc = Instance.new("UICorner",fill) fc.CornerRadius=UDim.new(0,8)

local status = Instance.new("TextLabel", frame)
status.BackgroundTransparency=1; status.Font=Enum.Font.Gotham; status.TextSize=16
status.TextColor3=Color3.fromRGB(200,200,200)
status.Size=UDim2.new(1,-24,0,28); status.Position=UDim2.new(0,12,0,96)
status.TextXAlignment=Enum.TextXAlignment.Left
status.Text="Downloading modules..."

-- (จำลอง/หรือจะไปโหลดจริงก็ได้; ถ้าจะโหลดจริง เพิ่ม URL แล้วใช้ game:HttpGet)
local steps = {
    {name="Core libraries", delay=0.35},
    {name="UI components", delay=0.35},
    {name="Services", delay=0.35},
    {name="Patches", delay=0.35},
}
task.spawn(function()
    for i,st in ipairs(steps) do
        status.Text = "Downloading: "..st.name
        TS:Create(fill, TweenInfo.new(st.delay), {Size = UDim2.new(i/#steps,0,1,0)}):Play()
        task.wait(st.delay)
    end
    status.Text = "Finalizing..."
    TS:Create(fill, TweenInfo.new(0.25), {Size=UDim2.new(1,0,1,0)}):Play()
    task.wait(0.25)
    -- เสร็จ → เรียก UI หลัก
    if getgenv and type(getgenv)=="function" then
        local g=getgenv()
        if g and g.UFO_ShowMain then g.UFO_ShowMain() end
    elseif _G and _G.UFO_ShowMain then
        _G.UFO_ShowMain()
    end
    gui:Destroy()
end)

return true
]]

local SRC_MAINUI = [[
-- UFO HUB X UI.lua
-- UI หลัก + ปุ่มปิด/เปิด (RightControl toggle)
local TS = game:GetService("TweenService")
local CG = game:GetService("CoreGui")
local UIS= game:GetService("UserInputService")

local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

local gui = Instance.new("ScreenGui")
gui.Name="UFOHubX_MainUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
safeParent(gui)

local main = Instance.new("Frame", gui)
main.Size=UDim2.fromOffset(720,420); main.AnchorPoint=Vector2.new(0.5,0.5); main.Position=UDim2.fromScale(0.5,0.5)
main.BackgroundColor3=Color3.fromRGB(12,12,12)
local c = Instance.new("UICorner",main) c.CornerRadius=UDim.new(0,16)
local s = Instance.new("UIStroke",main) s.Color=Color3.fromRGB(0,255,140); s.Transparency=0.4

local head = Instance.new("TextLabel", main)
head.BackgroundTransparency=1; head.Font=Enum.Font.GothamBlack; head.TextSize=22
head.TextColor3=Color3.fromRGB(0,255,140); head.Text="UFO HUB X — MAIN"
head.Size=UDim2.new(1,-24,0,38); head.Position=UDim2.new(0,12,0,12); head.TextXAlignment=Enum.TextXAlignment.Left

-- ตัวอย่างเมนู/ปุ่มรันสคริปต์
local runBtn = Instance.new("TextButton", main)
runBtn.Size=UDim2.new(0,220,0,44); runBtn.Position=UDim2.new(0,12,0,68)
runBtn.BackgroundColor3=Color3.fromRGB(24,24,24); runBtn.Font=Enum.Font.GothamBold; runBtn.TextSize=16
runBtn.TextColor3=Color3.new(1,1,1); runBtn.Text="Run Example (loadstring HttpGet)"
local rc = Instance.new("UICorner",runBtn) rc.CornerRadius=UDim.new(0,10)
local rs = Instance.new("UIStroke",runBtn) rs.Color=Color3.fromRGB(0,255,140); rs.Transparency=0.6

local function http_get(url)
    if http and http.request then local ok,res=pcall(http.request,{Url=url,Method="GET"}); if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end end
    if syn and syn.request then local ok,res=pcall(syn.request,{Url=url,Method="GET"}); if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end end
    local ok,body=pcall(function() return game:HttpGet(url) end); if ok and body then return true,body end
    return false,"httpget_failed"
end

runBtn.MouseButton1Click:Connect(function()
    runBtn.Text="Fetching..."
    local ok, src = http_get("https://pastebin.com/raw/gg7HVQTv") -- ตัวอย่าง URL เปลี่ยนได้
    if ok then
        runBtn.Text="Running..."
        local f,err = loadstring(src)
        if f then
            local suc,er = pcall(f)
            runBtn.Text = suc and "Done!" or ("Error: "..tostring(er))
        else
            runBtn.Text="loadstring error"
        end
    else
        runBtn.Text="HttpGet failed"
    end
    task.delay(1.2,function() runBtn.Text="Run Example (loadstring HttpGet)" end)
end)

-- ปุ่มสลับแสดง/ซ่อนด้วย RightControl
local visible = true
local function setVisible(v)
    visible = v
    TS:Create(main, TweenInfo.new(0.12), {BackgroundTransparency = v and 0 or 1}):Play()
    main.Visible = v
end

UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        setVisible(not visible)
    end
end)

-- ให้ orchestrator เรียกสลับได้
if getgenv and type(getgenv)=="function" then
    getgenv().UFO_ToggleUI = function() setVisible(not visible) end
elseif _G then
    _G.UFO_ToggleUI = function() setVisible(not visible) end
end

return true
]]

-- เขียนไฟล์ 3 ตัวออกไป (Key / Download / Main UI)
local function writeAllFiles()
    if writefile then
        pcall(writefile, "UFO HUB X Key.lua",       SRC_KEY)
        pcall(writefile, "UFO HUB X Download.lua",  SRC_DOWNLOAD)
        pcall(writefile, "UFO HUB X UI.lua",        SRC_MAINUI)
    end
end
writeAllFiles()

--============== Orchestrator callbacks ==============
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    local st = { key = key, permanent = permanent and true or false, expires_at = expires_at }
    writeState(st)
end

_G.UFO_StartDownload = function()
    if isfile and readfile and isfile("UFO HUB X Download.lua") then
        local src = readfile("UFO HUB X Download.lua")
        local f, e = loadstring(src)
        if f then pcall(f) end
    else
        -- fallback ถ้าหาไฟล์ไม่เจอ (โหลดจากตัวแปรในสคริปต์)
        local f,e = loadstring(SRC_DOWNLOAD)
        if f then pcall(f) end
    end
end

_G.UFO_ShowMain = function()
    if isfile and readfile and isfile("UFO HUB X UI.lua") then
        local src = readfile("UFO HUB X UI.lua")
        local f, e = loadstring(src)
        if f then pcall(f) end
    else
        local f,e = loadstring(SRC_MAINUI)
        if f then pcall(f) end
    end
end

--========================== Boot flow ==========================
do
    local valid = isKeyStillValid()
    if not valid then
        -- แสดงหน้า KEY (ยังไม่เคยยืนยัน/หมดเวลา)
        if isfile and readfile and isfile("UFO HUB X Key.lua") then
            local src = readfile("UFO HUB X Key.lua")
            local f, e = loadstring(src)
            if f then pcall(f) end
        else
            local f,e = loadstring(SRC_KEY)
            if f then pcall(f) end
        end
    else
        -- คีย์ยังไม่หมดอายุ/ถาวร → ข้ามไป Download
        _G.UFO_StartDownload()
    end
end
```0
