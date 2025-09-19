--========================================================
-- UFO HUB X — KEY UI (v18+, full drop-in, UNIVERSAL KEY)
-- - API JSON: /verify?key=&uid=&place=  และ  /getkey?uid=&place=
-- - โหมด Universal: ผูกกับ uid เป็นหลัก (แนวคิดไม่ล็อกแผนที่)
--   * เพื่อให้เข้ากับเซิร์ฟเวอร์เดิมที่ยังต้องการ place ผมส่ง place ไปด้วย
-- - จำอายุคีย์ผ่าน _G.UFO_SaveKeyState (48 ชม. หรือ expires_at จาก server)
-- - ปุ่ม Get Key คัดลอกลิงก์พร้อม uid/place (ใช้ SERVER_BASES[1])
-- - รองรับหลายเซิร์ฟเวอร์ (failover & retry)
-- - มี verifyKey()/copyGetKeyUrl() แบบ “อันเก่า” ให้เรียกง่าย
-- - Fade-out แล้ว Destroy เมื่อสำเร็จ
--========================================================

-------------------- Services --------------------
local TS   = game:GetService("TweenService")
local CG   = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-------------------- THEME --------------------
local LOGO_ID   = 112676905543996
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)
local RED       = Color3.fromRGB(210,60,60)
local GREEN     = Color3.fromRGB(60,200,120)

-------------------- LINKS --------------------
local DISCORD_URL = "https://discord.gg/your-server"

-- URL เซิร์ฟเวอร์ (ลำดับความสำคัญ)
local SERVER_BASES = {
    "https://ufo-hub-x-key-umoq.onrender.com",         -- หลัก
    -- "https://ufo-hub-x-server-key2.onrender.com",   -- สำรอง (ถ้ามี)
}

-- อายุคีย์เริ่มต้น
local DEFAULT_TTL_SECONDS = 48 * 3600 -- 48 ชั่วโมง

----------------------------------------------------------------
-- Allow-list คีย์พิเศษ (ผ่านแน่)
----------------------------------------------------------------
local ALLOW_KEYS = {
    ["JJJMAX"]                 = { reusable = true,  ttl = DEFAULT_TTL_SECONDS },
    ["GMPANUPHONGARTPHAIRIN"]  = { reusable = true,  ttl = DEFAULT_TTL_SECONDS },
}

----------------------------------------------------------------
-- Helpers (HTTP/JSON)
----------------------------------------------------------------
local function http_get(url)
    if http and http.request then
        local ok, res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
        return false, "executor_http_request_failed"
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
        return false, "syn_request_failed"
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "roblox_httpget_failed"
end

local function http_json_get(url)
    local ok, body = http_get(url)
    if not ok or not body then return false, nil, "http_error" end
    local okj, data = pcall(function() return HttpService:JSONDecode(tostring(body)) end)
    if not okj then return false, nil, "json_error" end
    return true, data, nil
end

-- ลองทีละ SERVER_BASE + retry/backoff เผื่อ Render ตื่นช้า
local function json_get_with_failover(path_qs)
    local last_err = "no_servers"
    for _, base in ipairs(SERVER_BASES) do
        local url = (base..path_qs)
        -- 3 รอบต่อเซิร์ฟเวอร์: 0s / 0.6s / 1.2s
        for i=0,2 do
            if i>0 then task.wait(0.6*i) end
            local ok, data, err = http_json_get(url)
            if ok and data then return true, data end
            last_err = err or "http_error"
        end
    end
    return false, nil, last_err
end

----------------------------------------------------------------
-- Normalize & Allow check
----------------------------------------------------------------
local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

local function isAllowedKey(k)
    local nk = normKey(k)
    local meta = ALLOW_KEYS[nk]
    if meta then return true, nk, meta end
    return false, nk, nil
end

----------------------------------------------------------------
-- ตรวจคีย์กับ Server (UNIVERSAL: ใช้ uid เป็นหลัก; ส่ง place ไปเพื่อเข้ากันได้)
-- server ตอบ JSON: { ok:true, valid:true/false, expires_at:<unix>, reason:"..." }
----------------------------------------------------------------
local function verifyWithServer(k)
    local uid   = tostring(LP and LP.UserId or "")
    local place = tostring(game.PlaceId or "")
    local qs = string.format(
        "/verify?key=%s&uid=%s&place=%s&format=json",
        HttpService:UrlEncode(k),
        HttpService:UrlEncode(uid),
        HttpService:UrlEncode(place)
    )
    local ok, data = json_get_with_failover(qs)
    if not ok or not data then
        return false, "server_unreachable", nil
    end
    if (data.ok and data.valid) or (data.valid == true and data.ok == nil) then
        local exp = tonumber(data.expires_at) or (os.time() + DEFAULT_TTL_SECONDS)
        return true, nil, exp
    else
        return false, tostring(data.reason or "invalid"), nil
    end
end

----------------------------------------------------------------
-- === SIMPLE HELPERS (สไตล์เก่า) ===
-- ใช้ SERVER_BASES[1] เป็นฐานหลัก
----------------------------------------------------------------
local function getKeyUrlForCurrentPlayer()
    local uid   = tostring(LP and LP.UserId or "")
    local place = tostring(game.PlaceId or "")
    local base  = SERVER_BASES[1] or "https://ufo-hub-x-key-umoq.onrender.com"
    return string.format("%s/getkey?uid=%s&place=%s",
        base,
        HttpService:UrlEncode(uid),
        HttpService:UrlEncode(place)
    )
end

-- คัดลอกลิงก์ Get Key แบบรวดเร็ว (เหมือนระบบเก่า)
local function copyGetKeyUrl()
    local url = getKeyUrlForCurrentPlayer()
    if setclipboard then pcall(setclipboard, url) end
    return url
end

-- ตรวจคีย์แบบเก่า: เรียก /verify แล้วเช็คคำว่า "VALID"
local function verifyKey(inputKey)
    local uid   = tostring(LP and LP.UserId or "")
    local place = tostring(game.PlaceId or "")
    local base  = SERVER_BASES[1] or "https://ufo-hub-x-key-umoq.onrender.com"

    local url = string.format("%s/verify?key=%s&uid=%s&place=%s",
        base,
        HttpService:UrlEncode(tostring(inputKey or "")),
        HttpService:UrlEncode(uid),
        HttpService:UrlEncode(place)
    )

    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and tostring(body):upper():find("VALID") then
        print("VALID")
        return true
    else
        print("INVALID")
        return false
    end
end

----------------------------------------------------------------
-- UI Helpers
----------------------------------------------------------------
local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

local function make(class, props, kids)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end

local function tween(o, goal, t)
    TS:Create(o, TweenInfo.new(t or .18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function setClipboard(s) if setclipboard then pcall(setclipboard, s) end end

-------------------- ROOT --------------------
local gui = Instance.new("ScreenGui")
gui.Name = "UFOHubX_KeyUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
safeParent(gui)

-------------------- PANEL --------------------
local PANEL_W, PANEL_H = 740, 430
local panel = make("Frame", {
    Parent=gui, Active=true, Draggable=true,
    Size=UDim2.fromOffset(PANEL_W, PANEL_H),
    AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
    BackgroundColor3=BG_DARK, BorderSizePixel=0, ZIndex=1
},{
    make("UICorner",{CornerRadius=UDim.new(0,22)}),
    make("UIStroke",{Color=ACCENT, Thickness=2, Transparency=0.1})
})

-- ปุ่มปิด
local btnClose = make("TextButton", {
    Parent=panel, Text="X", Font=Enum.Font.GothamBold, TextSize=20, TextColor3=Color3.new(1,1,1),
    AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(210,35,50),
    Size=UDim2.new(0,38,0,38), Position=UDim2.new(1,-50,0,14), ZIndex=50
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)})
})
btnClose.MouseButton1Click:Connect(function() gui:Destroy() end)

-------------------- HEADER --------------------
local head = make("Frame", {
    Parent=panel, BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(14,14,14),
    Size=UDim2.new(1,-28,0,68), Position=UDim2.new(0,14,0,14), ZIndex=5
},{
    make("UICorner",{CornerRadius=UDim.new(0,16)}),
    make("UIStroke",{Color=ACCENT, Transparency=0.85})
})
make("ImageLabel", {
    Parent=head, BackgroundTransparency=1, Image="rbxassetid://"..LOGO_ID,
    Size=UDim2.new(0,34,0,34), Position=UDim2.new(0,16,0,17), ZIndex=6
},{})
make("TextLabel", {
    Parent=head, BackgroundTransparency=1, Position=UDim2.new(0,60,0,18),
    Size=UDim2.new(0,200,0,32), Font=Enum.Font.GothamBold, TextSize=20,
    Text="KEY SYSTEM", TextColor3=ACCENT, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6
}, {})

-------------------- TITLE --------------------
local titleGroup = make("Frame", {
    Parent=panel, BackgroundTransparency=1,
    Position=UDim2.new(0,28,0,102), Size=UDim2.new(1,-56,0,76)
}, {})
make("UIListLayout", {
    Parent = titleGroup,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0,6)
}, {})
make("TextLabel", {
    Parent = titleGroup, LayoutOrder = 1, BackgroundTransparency = 1, Size=UDim2.new(1,0,0,32),
    Font=Enum.Font.GothamBlack, TextSize=30, Text="Welcome to the,", TextColor3=FG,
    TextXAlignment=Enum.TextXAlignment.Left
}, {})
local titleLine2 = make("Frame", {
    Parent = titleGroup, LayoutOrder = 2, BackgroundTransparency = 1, Size=UDim2.new(1,0,0,36)
}, {})
make("UIListLayout", {
    Parent=titleLine2, FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Left, VerticalAlignment=Enum.VerticalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)
},{})
make("TextLabel", { Parent=titleLine2, LayoutOrder=1, BackgroundTransparency=1,
    Font=Enum.Font.GothamBlack, TextSize=32, Text="UFO", TextColor3=ACCENT, AutomaticSize=Enum.AutomaticSize.X }, {})
make("TextLabel", { Parent=titleLine2, LayoutOrder=2, BackgroundTransparency=1,
    Font=Enum.Font.GothamBlack, TextSize=32, Text="HUB X", TextColor3=Color3.new(1,1,1), AutomaticSize=Enum.AutomaticSize.X }, {})

-------------------- KEY INPUT --------------------
make("TextLabel", {
    Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,188),
    Size=UDim2.new(0,60,0,22), Font=Enum.Font.Gotham, TextSize=16,
    Text="Key", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
}, {})
local keyStroke
local keyBox = make("TextBox", {
    Parent=panel, ClearTextOnFocus=false, PlaceholderText="insert your key here",
    Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
    BackgroundColor3=SUB, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,40), Position=UDim2.new(0,28,0,214)
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)}),
    (function() keyStroke = make("UIStroke",{Color=ACCENT, Transparency=0.75}); return keyStroke end)()
})

-------------------- SUBMIT BUTTON --------------------
local btnSubmit = make("TextButton", {
    Parent=panel, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
    BackgroundColor3=RED, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,50), Position=UDim2.new(0,28,0,268)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)})
})

-- Toast
local toast = make("TextLabel", {
    Parent = panel, BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(30,30,30),
    Size = UDim2.fromOffset(0,32), Position = UDim2.new(0.5,0,0,16),
    AnchorPoint = Vector2.new(0.5,0), Visible = false, Font = Enum.Font.GothamBold,
    TextSize = 14, Text = "", TextColor3 = Color3.new(1,1,1), ZIndex = 100
},{
    make("UIPadding",{PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,14)}),
    make("UICorner",{CornerRadius=UDim.new(0,10)})
})
local function showToast(msg, ok)
    toast.Text = msg
    toast.BackgroundColor3 = ok and Color3.fromRGB(20,120,60) or Color3.fromRGB(150,35,35)
    toast.Size = UDim2.fromOffset(math.max(160, (#msg*8)+28), 32)
    toast.Visible = true
    toast.BackgroundTransparency = 0.15
    tween(toast, {BackgroundTransparency = 0.05}, .08)
    task.delay(1.1, function()
        tween(toast, {BackgroundTransparency = 1}, .15)
        task.delay(.15, function() toast.Visible = false end)
    end)
end

-- Status text
local statusLabel = make("TextLabel", {
    Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,268+50+6),
    Size=UDim2.new(1,-56,0,24), Font=Enum.Font.Gotham, TextSize=14, Text="",
    TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
}, {})
local function setStatus(txt, ok)
    statusLabel.Text = txt or ""
    if ok == nil then
        statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
    elseif ok then
        statusLabel.TextColor3 = Color3.fromRGB(120,255,170)
    else
        statusLabel.TextColor3 = Color3.fromRGB(255,120,120)
    end
end

-- Error effect
local function flashInputError()
    if keyStroke then
        local old = keyStroke.Color
        tween(keyStroke, {Color = Color3.fromRGB(255,90,90), Transparency = 0}, .05)
        task.delay(.22, function()
            tween(keyStroke, {Color = old, Transparency = 0.75}, .12)
        end)
    end
    local p0 = btnSubmit.Position
    local dx = 5
    TS:Create(btnSubmit, TweenInfo.new(0.05), {Position = p0 + UDim2.fromOffset(-dx,0)}):Play()
    task.delay(0.05, function()
        TS:Create(btnSubmit, TweenInfo.new(0.05), {Position = p0 + UDim2.fromOffset(dx,0)}):Play()
        task.delay(0.05, function()
            TS:Create(btnSubmit, TweenInfo.new(0.05), {Position = p0}):Play()
        end)
    end)
end

-- Fade-out UI
local function fadeOutAndDestroy()
    for _, d in ipairs(panel:GetDescendants()) do
        pcall(function()
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
                if d:IsA("TextBox") or d:IsA("TextButton") then
                    TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
                end
            elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
            elseif d:IsA("Frame") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
            elseif d:IsA("UIStroke") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
            end
        end)
    end
    TS:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    task.delay(0.22, function() if gui and gui.Parent then gui:Destroy() end end)
end

-- Submit states
local submitting = false
local function refreshSubmit()
    if submitting then return end
    local hasText = keyBox.Text and (#keyBox.Text > 0)
    if hasText then
        tween(btnSubmit, {BackgroundColor3 = GREEN}, .08)
        btnSubmit.Text = "🔓  Submit Key"
        btnSubmit.TextColor3 = Color3.new(0,0,0)
    else
        tween(btnSubmit, {BackgroundColor3 = RED}, .08)
        btnSubmit.Text = "🔒  Submit Key"
        btnSubmit.TextColor3 = Color3.new(1,1,1)
    end
end
keyBox:GetPropertyChangedSignal("Text"):Connect(function()
    setStatus("", nil); refreshSubmit()
end)
refreshSubmit()
keyBox.FocusLost:Connect(function(enter) if enter then btnSubmit:Activate() end end)

-- รวม error
local function forceErrorUI(mainText, toastText)
    tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(255,80,80)}, .08)
    btnSubmit.Text = mainText or "❌ Invalid Key"
    btnSubmit.TextColor3 = Color3.new(1,1,1)
    setStatus(toastText or "กุญแจไม่ถูกต้อง ลองอีกครั้ง", false)
    showToast(toastText or "รหัสไม่ถูกต้อง", false)
    flashInputError()
    keyBox.Text = ""
    task.delay(0.02, function() keyBox:CaptureFocus() end)
    task.delay(1.2, function()
        submitting=false; btnSubmit.Active=true; refreshSubmit()
    end)
end

----------------------------------------------------------------
-- Submit flow
----------------------------------------------------------------
local function doSubmit()
    if submitting then return end
    submitting = true; btnSubmit.AutoButtonColor = false; btnSubmit.Active = false

    local k = keyBox.Text or ""
    if k == "" then
        forceErrorUI("🚫 Please enter a key", "โปรดใส่รหัสก่อนนะ"); return
    end

    setStatus("กำลังตรวจสอบคีย์...", nil)
    tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(70,170,120)}, .08)
    btnSubmit.Text = "⏳ Verifying..."

    local valid, reason, expires_at = false, nil, nil
    local allowed, nk, meta = isAllowedKey(k)
    if allowed then
        valid = true
        expires_at = os.time() + (tonumber(meta.ttl) or DEFAULT_TTL_SECONDS)
        print("[UFO-HUB-X] allowed key:", nk, "exp:", expires_at)
    else
        valid, reason, expires_at = verifyWithServer(k) -- โหมดทน (UNIVERSAL + compat)
        if valid then
            print("[UFO-HUB-X] server verified key:", k, "exp:", expires_at)
        else
            print("[UFO-HUB-X] key invalid:", k, "reason:", tostring(reason))
        end
    end

    if not valid then
        if reason == "server_unreachable" then
            forceErrorUI("❌ Invalid Key", "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่หรือตรวจเน็ต")
        else
            forceErrorUI("❌ Invalid Key", "กุญแจไม่ถูกต้อง ลองอีกครั้ง")
        end
        return
    end

    -- ผ่าน ✅
    tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(120,255,170)}, .10)
    btnSubmit.Text = "✅ Key accepted"
    btnSubmit.TextColor3 = Color3.new(0,0,0)
    setStatus("ยืนยันคีย์สำเร็จ พร้อมใช้งาน!", true)
    showToast("ยืนยันสำเร็จ", true)

    _G.UFO_HUBX_KEY_OK = true
    _G.UFO_HUBX_KEY    = k

    if _G.UFO_SaveKeyState and expires_at then
        pcall(_G.UFO_SaveKeyState, k, tonumber(expires_at) or (os.time()+DEFAULT_TTL_SECONDS), false)
    end

    task.delay(0.15, function()
        fadeOutAndDestroy()
    end)
end
btnSubmit.MouseButton1Click:Connect(doSubmit)
btnSubmit.Activated:Connect(doSubmit)

-------------------- GET KEY (ลิงก์พร้อม uid/place เพื่อกัน error เดิม) --------------------
local btnGetKey = make("TextButton", {
    Parent=panel, Text="🔐  Get Key", Font=Enum.Font.GothamBold, TextSize=18,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
    BackgroundColor3=SUB, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,44), Position=UDim2.new(0,28,0,324)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)}),
    make("UIStroke",{Color=ACCENT, Transparency=0.6})
})
btnGetKey.MouseButton1Click:Connect(function()
    local url = copyGetKeyUrl()
    if setclipboard then pcall(setclipboard, url) end
    btnGetKey.Text = "✅ Link copied!"
    task.delay(1.5,function() btnGetKey.Text="🔐  Get Key" end)
end)

-------------------- SUPPORT ----------------
utOrder, Padding = UDim.new(0,6)
}, {})
make("TextLabel", {
    Parent=supportRow, LayoutOrder=1, BackgroundTransparency=1,
    Font=Enum.Font.Gotham, TextSize=16, Text="Need support?",
    TextColor3=Color3.fromRGB(200,200,200), AutomaticSize=Enum.AutomaticSize.X
}, {})
local btnDiscord = make("TextButton", {
    Parent=supportRow, LayoutOrder=2, BackgroundTransparency=1,
    Font=Enum.Font.GothamBold, TextSize=16, Text="Join the Discord",
    TextColor3=ACCENT, AutomaticSize=Enum.AutomaticSize.X
},{})
btnDiscord.MouseButton1Click:Connect(function()
    setClipboard(DISCORD_URL)
    btnDiscord.Text = "✅ Link copied!"
    task.delay(1.5,function() btnDiscord.Text="Join the Discord" end)
end)

-------------------- Open Animation --------------------
panel.Position = UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0,14)
tween(panel, {Position = UDim2.fromScale(0.5,0.5)}, .18)
