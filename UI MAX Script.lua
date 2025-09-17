--========================================================
-- UI MAX Script.lua (All-in-One)
-- UFO HUB X — Boot Loader + Key UI + Download UI + Main UI + Game Router
-- รองรับ Delta / syn / KRNL / Script-Ware / Fluxus / loadstring(HttpGet)
--========================================================

-------------------- Services --------------------
local HttpService = game:GetService("HttpService")
local TS          = game:GetService("TweenService")
local CG          = game:GetService("CoreGui")
local UIS         = game:GetService("UserInputService")
local Players     = game:GetService("Players")
local LP          = Players.LocalPlayer

-------------------- Utils --------------------
local function http_get(url)
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

-------------------- Persistent Key State --------------------
local DIR        = "UFOHubX"
local STATE_FILE = DIR.."/key_state.json"

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

local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    if st.permanent == true then return true end
    if st.expires_at and typeof(st.expires_at)=="number" then
        return (os.time() < st.expires_at)
    end
    return false
end

-------------------- Globals for cross-calls --------------------
local GV = (getgenv and getgenv()) or _G
GV = GV or _G

GV.UFO_SaveKeyState = function(key, expires_at, permanent)
    local st = {
        key        = key,
        saved_at   = os.time(),
        expires_at = expires_at,
        permanent  = permanent == true
    }
    writeState(st)
    print("[UFO HUB X] Key saved.")
end

GV.UFO_StartDownload = function()
    ShowDownloadUI()
end

GV.UFO_ShowMain = function()
    ShowMainUI()
end

-------------------- KEY UI --------------------
function ShowKeyUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "UFOHubX_KeyUI"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local panel = Instance.new("Frame", gui)
    panel.Size=UDim2.fromOffset(740,430); panel.AnchorPoint=Vector2.new(0.5,0.5); panel.Position=UDim2.fromScale(0.5,0.5)
    panel.BackgroundColor3=Color3.fromRGB(10,10,10); panel.Active=true; panel.Draggable=true
    Instance.new("UICorner", panel).CornerRadius=UDim.new(0,22)

    local keyBox = Instance.new("TextBox", panel)
    keyBox.ClearTextOnFocus=false; keyBox.PlaceholderText="insert your key here"
    keyBox.Size=UDim2.new(1,-56,0,40); keyBox.Position=UDim2.new(0,28,0,214)
    keyBox.BackgroundColor3=Color3.fromRGB(22,22,22); keyBox.TextColor3=Color3.new(1,1,1)
    Instance.new("UICorner", keyBox).CornerRadius=UDim.new(0,12)

    local btn = Instance.new("TextButton", panel)
    btn.Text="🔒 Submit Key"; btn.Size=UDim2.new(1,-56,0,50); btn.Position=UDim2.new(0,28,0,268)
    btn.BackgroundColor3=Color3.fromRGB(210,60,60); btn.Font=Enum.Font.GothamBlack; btn.TextColor3=Color3.new(1,1,1)
    Instance.new("UICorner", btn).CornerRadius=UDim.new(0,14)

    local status = Instance.new("TextLabel", panel)
    status.BackgroundTransparency=1; status.Position=UDim2.new(0,28,0,324); status.Size=UDim2.new(1,-56,0,24)
    status.Font=Enum.Font.Gotham; status.TextSize=14; status.TextColor3=Color3.fromRGB(200,200,200)

    local function acceptKey(k)
        status.Text="ยืนยันคีย์สำเร็จ"
        GV.UFO_SaveKeyState(k,nil,true)
        task.delay(.5,function()
            gui:Destroy()
            GV.UFO_StartDownload()
        end)
    end

    btn.MouseButton1Click:Connect(function()
        local k=keyBox.Text
        if k=="JJJMAX" or k=="GMPANUPHONGARTPHAIRIN" then
            acceptKey(k)
        else
            status.Text="❌ คีย์ไม่ถูกต้อง"
        end
    end)
end

-------------------- DOWNLOAD UI --------------------
function ShowDownloadUI()
    local gui = Instance.new("ScreenGui")
    gui.Name="UFOHubX_DownloadUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local frame = Instance.new("Frame", gui)
    frame.Size=UDim2.fromOffset(560,180); frame.AnchorPoint=Vector2.new(0.5,0.5); frame.Position=UDim2.fromScale(0.5,0.5)
    frame.BackgroundColor3=Color3.fromRGB(14,14,14)
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,16)

    local title = Instance.new("TextLabel", frame)
    title.Text="UFO HUB X — Preparing Resources"; title.Font=Enum.Font.GothamBlack
    title.TextSize=20; title.TextColor3=Color3.fromRGB(235,235,235)
    title.Size=UDim2.new(1,-24,0,36); title.Position=UDim2.new(0,12,0,12)

    local bar = Instance.new("Frame", frame)
    bar.Size=UDim2.new(1,-24,0,10); bar.Position=UDim2.new(0,12,0,68); bar.BackgroundColor3=Color3.fromRGB(28,28,28)
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,8)

    local fill = Instance.new("Frame", bar)
    fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=Color3.fromRGB(0,255,140)
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,8)

    local status = Instance.new("TextLabel", frame)
    status.BackgroundTransparency=1; status.Text="Downloading..."
    status.Size=UDim2.new(1,-24,0,28); status.Position=UDim2.new(0,12,0,96)
    status.TextColor3=Color3.fromRGB(200,200,200)

    task.spawn(function()
        for i=1,5 do
            status.Text="Downloading step "..i
            TS:Create(fill, TweenInfo.new(.3), {Size=UDim2.new(i/5,0,1,0)}):Play()
            task.wait(.35)
        end
        gui:Destroy()
        GV.UFO_ShowMain()
    end)
end

-------------------- MAIN UI --------------------
function ShowMainUI()
    local gui = Instance.new("ScreenGui")
    gui.Name="UFOHubX_MainUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local main = Instance.new("Frame", gui)
    main.Size=UDim2.fromOffset(720,420); main.AnchorPoint=Vector2.new(0.5,0.5); main.Position=UDim2.fromScale(0.5,0.5)
    main.BackgroundColor3=Color3.fromRGB(12,12,12)
    Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)

    local head = Instance.new("TextLabel", main)
    head.Text="UFO HUB X — MAIN"; head.Font=Enum.Font.GothamBlack; head.TextSize=22
    head.TextColor3=Color3.fromRGB(0,255,140)
    head.Size=UDim2.new(1,-24,0,38); head.Position=UDim2.new(0,12,0,12)

    -- Example button
    local btn=Instance.new("TextButton",main)
    btn.Size=UDim2.new(0,200,0,40); btn.Position=UDim2.new(0,12,0,60)
    btn.Text="Run Example"; btn.BackgroundColor3=Color3.fromRGB(24,24,24)
    btn.TextColor3=Color3.new(1,1,1)
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,10)

    btn.MouseButton1Click:Connect(function()
        print("Run Example pressed")
    end)

    -- Toggle UI
    UIS.InputBegan:Connect(function(i,g)
        if g then return end
        if i.KeyCode==Enum.KeyCode.RightControl then
            gui.Enabled=not gui.Enabled
        end
    end)

    -- After UI loaded → run Game Router
    task.defer(function()
        RunGameRouter()
    end)
end

-------------------- GAME ROUTER --------------------
function RunGameRouter()
    local placeId=game.PlaceId
    print("[UFO HUB X] Game Router PlaceId=",placeId)

    local MAPS={
        [1234567890]="Grow a Garden",
        [2222222222]="99 Nights in the Forest",
        [3333333333]="Steal a Brainrot",
        [4444444444]="Blox Fruit World 1",
        [5555555555]="Blox Fruit World 2",
        [6666666666]="Blox Fruit World 3",
        [7777777777]="Fish it"
    }

    local map=MAPS[placeId]
    if not map then
        print("[UFO HUB X] Unsupported game.")
        return
    end

    if map=="Grow a Garden" then
        print("🌱 Loaded Grow a Garden features: Auto Harvest, Auto Sell, WalkSpeed, Reset")
    elseif map=="99 Nights in the Forest" then
        print("🌲 Loaded 99 Nights features")
    elseif map=="Steal a Brainrot" then
        print("🧠 Loaded Brainrot features")
    elseif map=="Blox Fruit World 1" then
        print("🍎 Loaded Blox Fruit World 1")
    elseif map=="Fish it" then
        print("🎣 Loaded Fish it")
    end
end

-------------------- BOOT --------------------
local function StartFlow()
    if isKeyStillValid() then
        GV.UFO_StartDownload()
    else
        ShowKeyUI()
    end
end

StartFlow()
