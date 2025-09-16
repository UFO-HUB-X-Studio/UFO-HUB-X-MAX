--========================================================
-- UFO HUB X — Download Screen (FULL, fixed background + order + clamp)
--========================================================

-------------------- Services --------------------
local CG  = game:GetService("CoreGui")
local RS  = game:GetService("RunService")
local Cam = workspace.CurrentCamera

-------------------- CONFIG --------------------
local BG_IMAGE_ID = 98124588730893    -- รูปพื้นหลัง (เต็มจอ)
local LOGO_ID     = 112676905543996   -- โลโก้ด้านบน (อยู่เหนือชื่อ)
local UFO_RUN_ID  = 95708354427651    -- รูปยาน UFO ที่วิ่งบนหลอด
local DURATION    = 10                -- เวลาโหลด 10 วินาที
local Y_OFFSET    = -30               -- ยกกล่องขึ้นเล็กน้อย (ลบ=ขึ้น, บวก=ลง)

-------------------- THEME --------------------
local ACCENT = Color3.fromRGB(0,255,140)   -- เขียว UFO
local BG     = Color3.fromRGB(12,12,12)    -- พื้นกล่อง
local FG     = Color3.fromRGB(230,230,230) -- ตัวอักษร

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

-------------------- ROOT GUI --------------------
local gui = Instance.new("ScreenGui")
gui.Name = "UFOHubX_Download"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true         -- <<< ทำให้เต็มจอจริง ไม่โดน TopBar ดัน
safeParent(gui)

-------------------- BACKGROUND (เต็มจอ) --------------------
local bg = make("ImageLabel", {
    Parent=gui,
    AnchorPoint=Vector2.new(0.5,0.5),
    Position   =UDim2.fromScale(0.5,0.5),
    Size       =UDim2.fromScale(1,1),
    BackgroundTransparency=1,
    Image="rbxassetid://"..BG_IMAGE_ID,
    ScaleType=Enum.ScaleType.Crop
}, {})
bg.ZIndex = 0

-------------------- MAIN WINDOW --------------------
local win = make("Frame", {
    Parent=gui,
    Size=UDim2.fromOffset(460, 260),
    AnchorPoint=Vector2.new(0.5,0.5),
    Position   =UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0, Y_OFFSET),
    BackgroundColor3=BG,
    BorderSizePixel=0
}, {
    make("UICorner",{CornerRadius=UDim.new(0,16)}),
    make("UIStroke",{Thickness=2, Color=ACCENT, Transparency=0.08})
})
win.ZIndex = 2

-- รีเซ็นเตอร์เมื่อขนาดจอเปลี่ยน
Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    win.Position = UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0, Y_OFFSET)
end)

-------------------- HEADER: โลโก้ (บน) + ชื่อ (ล่าง) --------------------
local header = make("Frame", {
    Parent=win, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,120), Position=UDim2.new(0,0,0,12)
}, {})
local vlist = make("UIListLayout", {
    Parent=header,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment   = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0,8)
}, {})

-- โลโก้ (บน)
local logo = make("ImageLabel", {
    Parent=header, BackgroundTransparency=1,
    Image="rbxassetid://"..LOGO_ID,
    Size=UDim2.new(0,82,0,82),
    LayoutOrder = 1
}, {})
logo.ZIndex = 3

-- ชื่อ (ล่าง): UFO เขียว + HUB X ขาว
local titleRow = make("Frame", {
    Parent=header, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,34),
    LayoutOrder = 2
}, {})
make("UIListLayout", {
    Parent=titleRow,
    FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    VerticalAlignment=Enum.VerticalAlignment.Center,
    Padding=UDim.new(0,8)
}, {})
local lblUFO = make("TextLabel", {
    Parent=titleRow, BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.X,
    Font=Enum.Font.GothamBold, TextSize=28,
    Text="UFO", TextColor3=ACCENT
}, {})
local lblHUBX = make("TextLabel", {
    Parent=titleRow, BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.X,
    Font=Enum.Font.GothamBold, TextSize=28,
    Text="HUB X", TextColor3=Color3.new(1,1,1)
}, {})
titleRow.ZIndex = 3

-------------------- PROGRESS BAR --------------------
local barBG = make("Frame", {
    Parent=win,
    Size=UDim2.new(0, 340, 0, 22),
    AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,150),
    BackgroundColor3=Color3.fromRGB(40,40,40),
    BorderSizePixel=0
}, {
    make("UICorner",{CornerRadius=UDim.new(0,12)})
})
barBG.ZIndex = 3

local barFill = make("Frame", {
    Parent=barBG,
    Size=UDim2.new(0,0,1,0),
    BackgroundColor3=ACCENT,
    BorderSizePixel=0
}, {
    make("UICorner",{CornerRadius=UDim.new(0,12)})
})
barFill.ZIndex = 4

-- เปอร์เซ็นต์กลางหลอด (อยู่บนสุดเสมอ)
local percent = make("TextLabel", {
    Parent=barBG,
    BackgroundTransparency=1,
    Size=UDim2.new(1,0,1,0),
    Font=Enum.Font.GothamBold, TextSize=16,
    Text="0%", TextColor3=FG,
    TextXAlignment=Enum.TextXAlignment.Center,
    TextYAlignment=Enum.TextYAlignment.Center
}, {})
percent.ZIndex = 10
percent.TextStrokeColor3 = Color3.fromRGB(0,0,0)
percent.TextStrokeTransparency = 0.4

-- UFO วิ่งบนหลอด (จะถูก clamp ไม่ให้ออกนอก)
local ufo = make("ImageLabel", {
    Parent=barBG,
    BackgroundTransparency=1,
    Image="rbxassetid://"..UFO_RUN_ID,
    Size=UDim2.new(0,28,0,28),
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0,0,0.5,0)
}, {})
ufo.ZIndex = 6

-------------------- PROGRESS (10 วินาที) --------------------
local start = tick()
local done  = false

RS.RenderStepped:Connect(function()
    if done then return end

    local p = math.clamp((tick() - start) / DURATION, 0, 1)

    -- อัพเดตหลอด + เปอร์เซ็นต์
    barFill.Size = UDim2.new(p, 0, 1, 0)
    percent.Text = string.format("%d%%", math.floor(p*100 + 0.5))

    -- คุม UFO ให้อยู่ในกรอบหลอดเสมอ (clamp)
    local barW    = barBG.AbsoluteSize.X
    local halfUFO = ufo.AbsoluteSize.X / 2
    local minX    = halfUFO
    local maxX    = barW - halfUFO
    local x       = math.clamp(p * barW, minX, maxX)
    ufo.Position  = UDim2.fromOffset(x, barBG.AbsoluteSize.Y/2)

    if p >= 1 then
        done = true
        task.delay(0.25, function()
            gui:Destroy()
            -- TODO: เรียกเปิด UI UFO HUB X ต่อจากนี่ ถ้าต้องการ
            -- เช่น: loadstring(game:HttpGet("https://.../ufo_hub_x.lua"))()
        end)
    end
end)
