-- UFO HUB X — Multi-Map Bootstrapper with Language Picker
-- ถ้าแมพไม่รองรับ: จะไม่แสดงอะไรเลย
-- ถ้าแมพรองรับ: เด้ง UI ให้เลือกภาษา (TH/EN) แล้วโหลดสคริปต์ของแมพนั้น

local HttpGet = function(u)
    local ok, body
    if http and http.request then
        ok, body = pcall(function() return http.request({Url=u, Method="GET"}).Body end)
        if ok and body then return body end
    end
    if syn and syn.request then
        ok, body = pcall(function() return syn.request({Url=u, Method="GET"}).Body end)
        if ok and body then return body end
    end
    ok, body = pcall(function() return game:HttpGet(u) end)
    if ok and body then return body end
    return nil
end

local function SafeLoadString(src, tag)
    local f, e = loadstring(src, tag or "chunk")
    if not f then return false, e end
    local ok, err = pcall(f)
    if not ok then return false, err end
    return true
end

-- โหลดตารางแมพ
local mapsSrc = HttpGet("https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-Game/refs/heads/main/MultiMapBoot.lua")
if not mapsSrc then return end
local okBoot, Maps = pcall(function() return loadstring(mapsSrc, "MultiMapBoot")() end)
if not okBoot or type(Maps)~="table" then return end

local entry = Maps[game.PlaceId]
if not entry or (not entry.th and not entry.en) then
    -- แมพไม่รองรับ → ไม่ทำอะไรเลย
    return
end

-- ===== UI เลือกภาษา (CoreGui / PlayerGui) =====
local Players = game:GetService("Players")
local CG      = game:GetService("CoreGui")
local TS      = game:GetService("TweenService")
local LP      = Players.LocalPlayer

local function softParent(gui)
    if not gui then return end
    pcall(function()
        if gui:IsA("ScreenGui") then
            gui.IgnoreGuiInset = true
            gui.DisplayOrder   = 999999
            gui.ResetOnSpawn   = false
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        end
    end)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    local ok=false
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if (not ok) or (not gui.Parent) then ok = pcall(function() gui.Parent = CG end) end
    if (not ok) or (not gui.Parent) then
        if LP then
            local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 2)
            if pg then pcall(function() gui.Parent = pg end) end
        end
    end
end

local ACCENT    = Color3.fromRGB(0,255,140)
local BG        = Color3.fromRGB(12,12,12)
local SUB       = Color3.fromRGB(22,22,22)
local FG        = Color3.fromRGB(235,235,235)

local gui = Instance.new("ScreenGui")
gui.Name = "UFOX_LangPicker"
softParent(gui)

local panel = Instance.new("Frame")
panel.Parent = gui
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(460, 220)
panel.BackgroundColor3 = BG
panel.ZIndex = 10

local corner = Instance.new("UICorner", panel)
corner.CornerRadius = UDim.new(0,16)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = ACCENT
stroke.Transparency = 0.4

local title = Instance.new("TextLabel")
title.Parent = panel
title.BackgroundTransparency = 1
title.Position = UDim2.new(0,18,0,16)
title.Size = UDim2.new(1,-36,0,28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = ACCENT
title.Text = (entry.name and ("Select Language • "..tostring(entry.name))) or "Select Language"

local sub = Instance.new("TextLabel")
sub.Parent = panel
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0,18,0,48)
sub.Size = UDim2.new(1,-36,0,22)
sub.Font = Enum.Font.Gotham
sub.TextSize = 14
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(200,200,200)
sub.Text = "โปรดเลือกภาษา (Choose a language):"

local row = Instance.new("Frame")
row.Parent = panel
row.BackgroundTransparency = 1
row.Position = UDim2.new(0,18,0,92)
row.Size = UDim2.new(1,-36,0,100)

local layout = Instance.new("UIListLayout", row)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0,14)

local function makeBtn(txt)
    local b = Instance.new("TextButton")
    b.Parent = row
    b.AutoButtonColor = false
    b.Size = UDim2.fromOffset(190, 60)
    b.BackgroundColor3 = SUB
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.TextColor3 = FG
    b.Text = txt
    local c = Instance.new("UICorner", b)
    c.CornerRadius = UDim.new(0,12)
    local s = Instance.new("UIStroke", b)
    s.Color = ACCENT
    s.Transparency = 0.6
    return b
end

local btnTH = makeBtn("🇹🇭  ภาษาไทย")
local btnEN = makeBtn("🇺🇸  English")

local function fadeAway(callback)
    TS:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency=1}):Play()
    for _,d in ipairs(panel:GetDescendants()) do
        pcall(function()
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                TS:Create(d, TweenInfo.new(0.12), {TextTransparency=1, BackgroundTransparency=1}):Play()
            elseif d:IsA("UIStroke") then
                TS:Create(d, TweenInfo.new(0.12), {Transparency=1}):Play()
            end
        end)
    end
    task.delay(0.18, function()
        if gui and gui.Parent then gui:Destroy() end
        if callback then callback() end
    end)
end

local function go(url)
    if not url or #url==0 then return end
    fadeAway(function()
        local src = HttpGet(url)
        if src then SafeLoadString(src, "UFOX_GameScript") end
    end)
end

btnTH.MouseButton1Click:Connect(function()
    go(entry.th or entry.en)
end)
btnEN.MouseButton1Click:Connect(function()
    go(entry.en or entry.th)
end)

-- default focus / hover effect
local function hover(btn)
    btn.MouseEnter:Connect(function()
        TS:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(32,32,32)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TS:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = SUB}):Play()
    end)
end
hover(btnTH); hover(btnEN)
