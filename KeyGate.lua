--========================================================
-- UFO HUB X — KEY UI (FULL MOBILE SAFE + SINGLETON)
--========================================================
local TS = game:GetService("TweenService")
local CG = game:GetService("CoreGui")
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- -------- CONFIG --------
local LOGO_ID = 112676905543996
local ACCENT  = Color3.fromRGB(0,255,140)
local BG      = Color3.fromRGB(10,10,10)
local SUB     = Color3.fromRGB(28,28,28)
local FG      = Color3.fromRGB(235,235,235)

-- เซิร์ฟเวอร์ของเพื่อน (แก้ได้)
local SERVER = "https://ufo-hub-x-key-umoq.onrender.com"

-- จำสถานะคีย์ (48 ชม. ถ้า server ไม่ส่งเวลาหมดอายุมา)
local DEFAULT_TTL = 48*3600
local SAVE_KEY = true  -- true = จำคีย์ข้ามเซสชัน (ผ่าน _G ก็พอสำหรับ executor ส่วนใหญ่)

-- -------- Helpers --------
local function safeParent(gui)
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    local ok=false
    if gethui then ok=pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

local function make(class, props, kids)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end

local function jsonGET(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then return false, "http_error" end
    local ok2, data = pcall(function() return Http:JSONDecode(body) end)
    if not ok2 then return false, "json_error" end
    return true, data
end

local function now() return os.time() end

local function hasValidSaved()
    if not SAVE_KEY then return false end
    local exp = tonumber(_G.UFO_Key_Exp or 0)
    return exp > now()
end

-- -------- Prevent duplicate UI --------
do
    local old = CG:FindFirstChild("UFOHubX_KeyUI")
    if old then pcall(function() old:Destroy() end) end
end

-- ถ้ามีคีย์ยังไม่หมดอายุ ก็ไม่ต้องโชว์ UI
if hasValidSaved() then return end

-- -------- BUILD UI --------
local gui = Instance.new("ScreenGui")
gui.Name = "UFOHubX_KeyUI"
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
safeParent(gui)

local root = make("Frame", {
    Parent=gui, AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.52),
    Size=UDim2.fromOffset(860, 520),
    BackgroundColor3=BG, BorderSizePixel=0
},{
    make("UICorner",{CornerRadius=UDim.new(0,22)}),
    make("UIStroke",{Color=ACCENT,Thickness=2,Transparency=0.08})
})
-- รองรับจอเล็ก: clamp ให้ไม่ล้น
local function fit()
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    local w = math.clamp(vp.X*0.86, 360, 860)
    local h = math.clamp(vp.Y*0.66, 360, 520)
    root.Size = UDim2.fromOffset(w,h)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- Header bar
local header = make("Frame", {
    Parent=root, BackgroundTransparency=0.1,
    BackgroundColor3=Color3.fromRGB(16,16,16),
    Size=UDim2.new(1,-28,0,68), Position=UDim2.new(0,14,0,14)
},{
    make("UICorner",{CornerRadius=UDim.new(0,16)}),
    make("UIStroke",{Color=ACCENT,Transparency=0.85})
})
make("ImageLabel",{
    Parent=header, BackgroundTransparency=1,
    Image="rbxassetid://"..LOGO_ID, Size=UDim2.fromOffset(36,36),
    Position=UDim2.new(0,16,0,16)
})
make("TextLabel",{
    Parent=header, BackgroundTransparency=1,
    Position=UDim2.new(0,64,0,18), Size=UDim2.fromOffset(300,32),
    Font=Enum.Font.GothamBold, TextSize=20, Text="KEY SYSTEM",
    TextColor3=ACCENT, TextXAlignment=Enum.TextXAlignment.Left
})

-- Body container
local body = make("Frame",{
    Parent=root, BackgroundTransparency=1,
    Position=UDim2.new(0,28,0,100), Size=UDim2.new(1,-56,1,-128)
},{})
make("UIListLayout",{
    Parent=body, FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Left,
    VerticalAlignment=Enum.VerticalAlignment.Top, Padding=UDim.new(0,12),
    SortOrder=Enum.SortOrder.LayoutOrder
})

-- Title
make("TextLabel",{
    Parent=body, LayoutOrder=1, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,42), Font=Enum.Font.GothamBlack, TextSize=30,
    Text="Welcome to the,", TextColor3=FG, TextXAlignment=Enum.TextXAlignment.Left
})
local titleRow = make("Frame",{Parent=body,LayoutOrder=2,BackgroundTransparency=1,Size=UDim2.new(1,0,0,40)},{})
make("UIListLayout",{Parent=titleRow,FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})
make("TextLabel",{Parent=titleRow,BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Font=Enum.Font.GothamBlack,TextSize=32,Text="UFO",TextColor3=ACCENT})
make("TextLabel",{Parent=titleRow,BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Font=Enum.Font.GothamBlack,TextSize=32,Text="HUB X",TextColor3=Color3.new(1,1,1)})

-- Key label
make("TextLabel",{
    Parent=body, LayoutOrder=3, BackgroundTransparency=1, Size=UDim2.new(1,0,0,20),
    Font=Enum.Font.Gotham, TextSize=16, Text="Key", TextColor3=Color3.fromRGB(200,200,200),
    TextXAlignment=Enum.TextXAlignment.Left
})

-- Key input
local keyStroke
local keyBox = make("TextBox",{
    Parent=body, LayoutOrder=4, ClearTextOnFocus=false, PlaceholderText="insert your key here",
    Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
    BackgroundColor3=SUB, BorderSizePixel=0, Size=UDim2.new(1,0,0,44)
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)}),
    (function() keyStroke = make("UIStroke",{Color=ACCENT,Transparency=0.75}); return keyStroke end)()
})

-- Submit button
local btnSubmit = make("TextButton",{
    Parent=body, LayoutOrder=5, Text="🔒  Submit Key",
    Font=Enum.Font.GothamBlack, TextSize=20, TextColor3=Color3.new(1,1,1),
    AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(210,60,60),
    BorderSizePixel=0, Size=UDim2.new(1,0,0,48)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)})
})

-- Get Key button
local btnGet = make("TextButton",{
    Parent=body, LayoutOrder=6, Text="🔑  Get Key",
    Font=Enum.Font.GothamBold, TextSize=18, TextColor3=Color3.new(1,1,1),
    AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(36,36,36),
    BorderSizePixel=0, Size=UDim2.new(1,0,0,44)
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)}),
    make("UIStroke",{Color=ACCENT,Transparency=0.6})
})

-- Status label
local status = make("TextLabel",{
    Parent=body, LayoutOrder=7, BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,22), Font=Enum.Font.Gotham, TextSize=14, Text="",
    TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
})

local function setStatus(t, ok)
    status.Text = t or ""
    if ok==nil then
        status.TextColor3 = Color3.fromRGB(200,200,200)
    elseif ok then
        status.TextColor3 = Color3.fromRGB(120,255,170)
    else
        status.TextColor3 = Color3.fromRGB(255,120,120)
    end
end

-- -------- Actions --------
local function flashError()
    local old = keyStroke.Color
    TS:Create(keyStroke, TweenInfo.new(.07), {Color=Color3.fromRGB(255,90,90), Transparency=0}):Play()
    task.delay(.25, function()
        TS:Create(keyStroke, TweenInfo.new(.12), {Color=old, Transparency=0.75}):Play()
    end)
end

local function acceptKey(k, expUnix)
    -- เก็บไว้ (ง่ายๆผ่าน _G)
    if SAVE_KEY then
        _G.UFO_Key_Value = k
        _G.UFO_Key_Exp   = tonumber(expUnix) or (now()+DEFAULT_TTL)
    end
    -- ปิด UI
    TS:Create(root, TweenInfo.new(0.15), {BackgroundTransparency=1}):Play()
    for _,d in ipairs(root:GetDescendants()) do
        pcall(function()
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                TS:Create(d, TweenInfo.new(0.15), {TextTransparency=1, BackgroundTransparency=1}):Play()
            elseif d:IsA("ImageLabel") then
                TS:Create(d, TweenInfo.new(0.15), {ImageTransparency=1}):Play()
            elseif d:IsA("UIStroke") then
                TS:Create(d, TweenInfo.new(0.15), {Transparency=1}):Play()
            end
        end)
    end
    task.delay(0.18, function() gui:Destroy() end)
end

local function submit()
    local k = (keyBox.Text or ""):gsub("^%s+",""):gsub("%s+$","")
    if k=="" then
        setStatus("โปรดใส่คีย์ก่อน", false); flashError(); return
    end
    btnSubmit.Text = "⏳ Verifying..."
    btnSubmit.BackgroundColor3 = Color3.fromRGB(70,170,120)
    setStatus("กำลังตรวจสอบคีย์...", nil)

    -- เรียก /verify
    local url = string.format("%s/verify?key=%s&uid=%s&format=json",
        SERVER, Http:UrlEncode(k), Http:UrlEncode(tostring(LP and LP.UserId or "")))
    local ok, data = jsonGET(url)
    if not ok then
        setStatus("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่", false)
        btnSubmit.Text = "🔒  Submit Key"; btnSubmit.BackgroundColor3 = Color3.fromRGB(210,60,60)
        flashError(); return
    end
    if data.valid then
        btnSubmit.Text = "✅ Key accepted"
        btnSubmit.TextColor3 = Color3.new(0,0,0)
        btnSubmit.BackgroundColor3 = Color3.fromRGB(120,255,170)
        setStatus("ยืนยันคีย์สำเร็จ!", true)
        acceptKey(k, tonumber(data.expires_at))
    else
        setStatus("คีย์ไม่ถูกต้อง", false)
        btnSubmit.Text = "🔒  Submit Key"; btnSubmit.BackgroundColor3 = Color3.fromRGB(210,60,60)
        flashError()
    end
end

btnSubmit.MouseButton1Click:Connect(submit)

btnGet.MouseButton1Click:Connect(function()
    local uid = tostring(LP and LP.UserId or "")
    local link = string.format("%s/getkey?uid=%s", SERVER, Http:UrlEncode(uid))
    if setclipboard then pcall(setclipboard, link) end
    btnGet.Text = "✅ Link copied!"
    task.delay(1.2, function() btnGet.Text = "🔑  Get Key" end)
end)
