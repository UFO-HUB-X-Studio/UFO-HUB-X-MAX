--========================================================
-- UFO HUB X — KEY UI (v17) : Success = auto fade-out & destroy (keep all previous features)
--========================================================

-------------------- Services --------------------
local TS   = game:GetService("TweenService")
local CG   = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService") -- ใช้เชื่อม Server

-------------------- CONFIG --------------------
local LOGO_ID   = 112676905543996
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)

local DISCORD_URL = "https://discord.gg/your-server"
local GETKEY_URL  = "https://ufo-hub-x-key.onrender.com"  -- server จริง

-- เรียกใช้ตอนกด Submit (ค่อยผูกระบบจริงทีหลัง)
local function OnSubmitKey(key)
    print("[KEY SUBMIT] =>", key)
end

----------------------------------------------------------------
-- Allow-list คีย์พิเศษ (ผ่านแน่)
----------------------------------------------------------------
local ALLOW_KEYS = {
    ["JJJMAX"]                 = { permanent = true, reusable = true }, -- คีย์ทดลอง
    ["GMPANUPHONGARTPHAIRIN"]  = { permanent = true, reusable = true }, -- คีย์ถาวร
}

----------------------------------------------------------------
-- Normalize แข็งแรงขึ้น
----------------------------------------------------------------
local function normKey(s)
    s = tostring(s or "")
    s = s:gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    s = string.upper(s)
    return s
end

local function isAllowedKey(k)
    local nk = normKey(k)
    if ALLOW_KEYS[nk] then
        return true, nk
    end
    return false, nk
end

----------------------------------------------------------------
-- ตรวจสอบคีย์กับ server (ทนทานขึ้น + ส่งสาเหตุกลับ)
----------------------------------------------------------------
local function http_get(url)
    if http and http.request then
        local ok, res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and res.Body then return true, res.Body end
        return false, "executor_http_request_failed"
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and res.Body then return true, res.Body end
        return false, "syn_request_failed"
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "roblox_httpget_failed"
end

local function verifyWithServer(k)
    local url = GETKEY_URL.."/verify?key="..HttpService:UrlEncode(k)
    local ok, res = http_get(url)
    if ok and res then
        local low = tostring(res):lower()
        if low:find("valid") or low:find('"valid"%s*:%s*true') or low:find("ok") or low:find("true") then
            return true, nil
        else
            return false, "server_said_invalid"
        end
    end
    return false, "server_unreachable"
end

-------------------- Helpers (UI) --------------------
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

-- ปุ่มปิด (คงไว้)
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

-- Line 1
make("TextLabel", {
    Parent = titleGroup, LayoutOrder = 1,
    BackgroundTransparency = 1, Size=UDim2.new(1,0,0,32),
    Font=Enum.Font.GothamBlack, TextSize=30,
    Text="Welcome to the,", TextColor3=FG,
    TextXAlignment=Enum.TextXAlignment.Left
}, {})

-- Line 2 : UFO HUB X
local titleLine2 = make("Frame", {
    Parent = titleGroup, LayoutOrder = 2,
    BackgroundTransparency = 1, Size=UDim2.new(1,0,0,36)
}, {})
make("UIListLayout", {
    Parent=titleLine2,
    FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Left,
    VerticalAlignment=Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,6)
},{})
make("TextLabel", {
    Parent=titleLine2, LayoutOrder=1,
    BackgroundTransparency=1, Font=Enum.Font.GothamBlack, TextSize=32,
    Text="UFO", TextColor3=ACCENT, AutomaticSize=Enum.AutomaticSize.X
}, {})
make("TextLabel", {
    Parent=titleLine2, LayoutOrder=2,
    BackgroundTransparency=1, Font=Enum.Font.GothamBlack, TextSize=32,
    Text="HUB X", TextColor3=Color3.new(1,1,1), AutomaticSize=Enum.AutomaticSize.X
}, {})

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
    (function()
        keyStroke = make("UIStroke",{Color=ACCENT, Transparency=0.75})
        return keyStroke
    end)()
})

-------------------- SUBMIT BUTTON --------------------
local RED   = Color3.fromRGB(210,60,60)
local GREEN = Color3.fromRGB(60,200,120)

local btnSubmit = make("TextButton", {
    Parent=panel,
    Text="🔒  Submit Key",
    Font=Enum.Font.GothamBlack, TextSize=20,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
    BackgroundColor3=RED, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,50), Position=UDim2.new(0,28,0,268)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)})
})

-- Toast แจ้งผล
local toast = make("TextLabel", {
    Parent = panel, BackgroundTransparency = 0.15,
    BackgroundColor3 = Color3.fromRGB(30,30,30),
    Size = UDim2.fromOffset(0,32), Position = UDim2.new(0.5,0,0,16),
    AnchorPoint = Vector2.new(0.5,0), Visible = false,
    Font = Enum.Font.GothamBold, TextSize = 14, Text = "",
    TextColor3 = Color3.new(1,1,1), ZIndex = 100
},{
    make("UIPadding",{PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,14)}),
    make("UICorner",{CornerRadius=UDim.new(0,10)})
})
local function showToast(msg, ok)
    toast.Text = msg
    toast.TextColor3 = Color3.new(1,1,1)
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

-- สถานะใต้ปุ่ม
local statusLabel = make("TextLabel", {
    Parent=panel, BackgroundTransparency=1,
    Position=UDim2.new(0,28,0,268+50+6),
    Size=UDim2.new(1,-56,0,24),
    Font=Enum.Font.Gotham, TextSize=14, Text="",
    TextColor3=Color3.fromRGB(200,200,200),
    TextXAlignment=Enum.TextXAlignment.Left
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

-- เอฟเฟกต์แจ้งเตือนตอนผิด: กระพริบขอบแดง + เขย่าเล็กน้อย
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

-- [ADD] ฟังก์ชันเฟดทั้ง UI แล้วปิดทิ้ง
local function fadeOutAndDestroy()
    -- ทำให้ทุก element ค่อย ๆ โปร่งใส
    for _, d in ipairs(panel:GetDescendants()) do
        local ok,_ = pcall(function()
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
    task.delay(0.22, function()
        if gui and gui.Parent then
            gui:Destroy()
        end
    end)
end

local submitting = false  -- debounce

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
    setStatus("", nil)
    refreshSubmit()
end)
refreshSubmit()

-- รองรับกด Enter เพื่อ Submit
keyBox.FocusLost:Connect(function(enter)
    if enter then
        btnSubmit:Activate()
    end
end)

----------------------------------------------------------------
-- ฟังก์ชันสถานะผิดแบบรวม
----------------------------------------------------------------
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
        submitting = false
        btnSubmit.Active = true
        refreshSubmit()
    end)
end

local function doSubmit()
    if submitting then return end
    submitting = true
    btnSubmit.AutoButtonColor = false
    btnSubmit.Active = false

    local k = keyBox.Text or ""
    if k == "" then
        forceErrorUI("🚫 Please enter a key", "โปรดใส่รหัสก่อนนะ")
        return
    end

    setStatus("กำลังตรวจสอบคีย์...", nil)
    tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(70,170,120)}, .08)
    btnSubmit.Text = "⏳ Verifying..."

    local valid, reason = false, nil
    local allowed, nk = isAllowedKey(k)
    if allowed then
        valid = true
        print("[UFO-HUB-X] allowed key matched:", nk)
    else
        valid, reason = verifyWithServer(k)
        if valid then
            print("[UFO-HUB-X] server verified key:", k)
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
    _G.UFO_HUBX_KEY     = k

    OnSubmitKey(k)

    -- [NEW] ซ่อน UI ทั้งหมดหลังสำเร็จ
    task.delay(0.15, function()
        fadeOutAndDestroy()
    end)
end

-- คงของเดิมไว้ + เพิ่ม Activated ให้เรียก flow เดียวกัน
btnSubmit.MouseButton1Click:Connect(doSubmit)
btnSubmit.Activated:Connect(doSubmit)

-------------------- GET KEY --------------------
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
    setClipboard(GETKEY_URL)
    btnGetKey.Text = "✅ Link copied!"
    task.delay(1.5,function() btnGetKey.Text="🔐  Get Key" end)
end)

-------------------- SUPPORT --------------------
local supportRow = make("Frame", {
    Parent=panel, AnchorPoint = Vector2.new(0.5,1),
    Position = UDim2.new(0.5,0,1,-18), Size = UDim2.new(1,-56,0,24),
    BackgroundTransparency = 1
}, {})

make("UIListLayout", {
    Parent = supportRow,
    FillDirection = Enum.FillDirection.HORIZONTAL,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment   = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0,6)
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
