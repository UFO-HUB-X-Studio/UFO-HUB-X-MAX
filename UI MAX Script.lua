--========================================================
-- UFO HUB X — MAX Script.lua (FULL SYSTEM PACK)
--========================================================

-------------------- Services --------------------
local TS   = game:GetService("TweenService")
local UIS  = game:GetService("UserInputService")
local CG   = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-------------------- CONFIG --------------------
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)
local GREEN     = Color3.fromRGB(60,200,120)
local RED       = Color3.fromRGB(210,60,60)

-- URLs (เปลี่ยนเป็น repo ของเพื่อนเอง)
local URL_KEYUI      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOADUI = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI     = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"
local URL_GAMELIST   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Game/refs/heads/main/UFO%20HUB%20X%20Game.lua"

-------------------- Theme Helpers --------------------
local function ForceLabelTransparent(o)
    if o:IsA("TextLabel") or o:IsA("TextBox") or o:IsA("TextButton") then
        o.BackgroundTransparency = 1
        o.BorderSizePixel = 0
    end
    for _,c in ipairs(o:GetChildren()) do
        ForceLabelTransparent(c)
    end
end

local function AddShadow(parent)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "UFO_DropShadow"
    shadow.Parent = parent
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5028857084"
    shadow.ImageTransparency = 0.25
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(24,24,276,276)
    shadow.Size = UDim2.new(1,30,1,30)
    shadow.Position = UDim2.fromOffset(-15,-15)
    shadow.ZIndex = parent.ZIndex - 1
end

local function BuildHeader(parent, titleText)
    local head = Instance.new("Frame")
    head.Name = "UFO_Header"
    head.Parent = parent
    head.Size = UDim2.new(1,-28,0,56)
    head.Position = UDim2.new(0,14,0,14)
    head.BackgroundColor3 = Color3.fromRGB(14,14,14)
    head.BorderSizePixel = 0
    Instance.new("UICorner", head).CornerRadius = UDim.new(0,14)

    local stroke = Instance.new("UIStroke", head)
    stroke.Color = ACCENT
    stroke.Transparency = 0.65

    local grad = Instance.new("UIGradient", head)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18,18,18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,10))
    }

    local title = Instance.new("TextLabel")
    title.Name = "UFO_Title"
    title.Parent = head
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1,-24,1,0)
    title.Position = UDim2.new(0,12,0,0)
    title.Font = Enum.Font.GothamBlack
    title.Text = titleText or "UFO HUB X"
    title.TextSize = 20
    title.TextColor3 = ACCENT
    title.TextXAlignment = Enum.TextXAlignment.Center

    return head
end

local function AttachUIScale(rootGui)
    local sc = Instance.new("UIScale", rootGui)
    local function fit()
        local s = rootGui.AbsoluteSize
        local k = math.clamp(math.min(s.X/900, s.Y/550), 0.8, 1.0)
        sc.Scale = k
    end
    rootGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    task.defer(fit)
end

-------------------- Loader Utils --------------------
local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url,Method="GET"})
        if ok and res and res.Body then return true,res.Body end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url,Method="GET"})
        if ok and res and res.Body then return true,res.Body end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,nil
end

local function LoadRemote(url)
    local ok,src = http_get(url)
    if ok and src then
        local f,err = loadstring(src)
        if not f then warn("loadstring error",err) return end
        local suc,ret = pcall(f)
        if not suc then warn("runtime error",ret) end
        return ret
    else
        warn("http_get failed:",url)
    end
end

-------------------- Boot Flow --------------------
-- Step 1: Load Key UI
local KeyUI = LoadRemote(URL_KEYUI)
if KeyUI then
    print("[UFO-HUB-X] Key UI loaded.")
    -- UI theme apply
    if KeyUI.Root then
        AddShadow(KeyUI.Root)
        BuildHeader(KeyUI.Root,"UFO HUB X — KEY SYSTEM")
        ForceLabelTransparent(KeyUI.Root)
        AttachUIScale(KeyUI.Root)
    end
end

-- Wait for key accept (global flag)
repeat task.wait() until _G.UFO_HUBX_KEY_OK

-- Step 2: Load Download UI
local DLUI = LoadRemote(URL_DOWNLOADUI)
if DLUI then
    print("[UFO-HUB-X] Download UI loaded.")
    if DLUI.Root then
        AddShadow(DLUI.Root)
        BuildHeader(DLUI.Root,"UFO HUB X — PREPARING")
        ForceLabelTransparent(DLUI.Root)
        AttachUIScale(DLUI.Root)
    end
end

task.wait(2.5) -- simulate download

-- Close Download UI
if DLUI and DLUI.Close then DLUI.Close() end

-- Step 3: Load Main UI
local MainUI = LoadRemote(URL_MAINUI)
if MainUI then
    print("[UFO-HUB-X] Main UI loaded.")
    if MainUI.Root then
        AddShadow(MainUI.Root)
        BuildHeader(MainUI.Root,"UFO HUB X — MAIN")
        ForceLabelTransparent(MainUI.Root)
        AttachUIScale(MainUI.Root)
    end
end

-- Step 4: Load Game Feature
local GameList = LoadRemote(URL_GAMELIST)
if GameList then
    local pid = game.PlaceId
    local URL = GameList[pid]
    if URL then
        print("[UFO-HUB-X] Game detected:",pid,"->",URL)
        LoadRemote(URL)
    else
        print("[UFO-HUB-X] Game not supported.")
    end
end
