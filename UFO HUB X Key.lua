--========================================================
-- UFO HUB X — KEY UI (v10) : Fixed Title + Support + Errors
--========================================================

-------------------- Services --------------------
local TS   = game:GetService("TweenService")
local CG   = game:GetService("CoreGui")

-------------------- CONFIG --------------------
local LOGO_ID   = 112676905543996
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)

local DISCORD_URL = "https://discord.gg/your-server"
local GETKEY_URL  = "https://yourwebsite.com/getkey"

-- เรียกใช้ตอนกด Submit (ค่อยผูกระบบจริงทีหลัง)
local function OnSubmitKey(key)
    print("[KEY SUBMIT] =>", key)
end

-------------------- Helpers --------------------
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

local keyBox = make("TextBox", {
    Parent=panel, ClearTextOnFocus=false, PlaceholderText="insert your key here",
    Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
    BackgroundColor3=SUB, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,40), Position=UDim2.new(0,28,0,214)
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)}),
    make("UIStroke",{Color=ACCENT, Transparency=0.75})
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

local function refreshSubmit()
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
keyBox:GetPropertyChangedSignal("Text"):Connect(refreshSubmit)
refreshSubmit()

btnSubmit.MouseButton1Click:Connect(function()
    local k = keyBox.Text
    if not k or k == "" then
        tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(255,80,80)}, .08)
        btnSubmit.Text = "🚫 Please enter a key\n(โปรดใส่รหัส)"
        task.delay(1.5, refreshSubmit)
        return
    end
    local valid = false -- สมมุติว่า key ไม่ถูก
    if not valid then
        tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(255,80,80)}, .08)
        btnSubmit.Text = "❌ Invalid Key — Try Again\n(กุญแจไม่ถูกต้อง)"
        task.delay(1.8, refreshSubmit)
        return
    end
    refreshSubmit()
    OnSubmitKey(k)
end)

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
    FillDirection = Enum.FillDirection.Horizontal,
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
