--========================================================
-- UFO HUB X — KeyGate (ไฟล์เดียวจบ)
-- - เปิดด้วย loadstring(...)() หรือวางในตัวรัน Delta ก็ได้
-- - ถ้ามีคีย์ที่ยังไม่หมดอายุ => ข้าม UI คีย์ ไป Download -> HUB
-- - ถ้าไม่มี/หมดอายุ => ขึ้น UI คีย์ กดตรวจแล้วบันทึกอายุคีย์
--========================================================

-------------------- CONFIG --------------------
local SERVER_BASE  = "https://ufo-hub-x-key-umoq.onrender.com"  -- <<<< แก้เป็นของคุณ
local DOWNLOAD_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local HUB_URL      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X.lua"
local STATE_FILE   = "ufo_hubx_state.json"   -- ต้องใช้ executor ที่รองรับ writefile/readfile

-------------------- Services --------------------
local Players     = game:GetService("Players")
local CoreGui     = game:GetService("CoreGui")
local TweenService= game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer

-------------------- State (persist) --------------------
local function read_state()
    if not isfile or not readfile then return _G.__UFO_STATE end
    if not isfile(STATE_FILE) then return _G.__UFO_STATE end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return _G.__UFO_STATE end
    local okj, obj = pcall(function() return HttpService:JSONDecode(data) end)
    if okj then _G.__UFO_STATE = obj return obj end
    return _G.__UFO_STATE
end

local function write_state(obj)
    _G.__UFO_STATE = obj
    if writefile then pcall(writefile, STATE_FILE, HttpService:JSONEncode(obj or {})) end
end

local function clear_state()
    _G.__UFO_STATE = nil
    if delfile and isfile and isfile(STATE_FILE) then pcall(delfile, STATE_FILE) end
end

_G.UFO_SaveKeyState = function(key, expires_at)
    write_state({ key = tostring(key or ""), exp = tonumber(expires_at) or (os.time()+172800) })
end

-------------------- Server verify --------------------
_G.UFO_VerifyKeyWithServer = function(inputKey)
    local uid = tostring(LP and LP.UserId or "")
    local url = string.format("%s/verify?key=%s&uid=%s",
        SERVER_BASE,
        HttpService:UrlEncode(tostring(inputKey or "")),
        HttpService:UrlEncode(uid)
    )
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or not body then return false, "server_unreachable" end
    local okj, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okj then return false, "json_error" end
    if data and data.valid then
        local exp = tonumber(data.expires_at) or (os.time()+172800)
        _G.UFO_SaveKeyState(inputKey, exp)
        return true, exp
    else
        return false, tostring(data and data.reason or "invalid")
    end
end

-------------------- Flow: ไปหน้าถัดไป (Download -> HUB) --------------------
_G.UFO_GoNext = function()
    -- ปิด UI คีย์ถ้ายังอยู่
    local g = CoreGui:FindFirstChild("UFOHubX_KeyUI")
    if g then pcall(function() g:Destroy() end) end

    -- เปิด Download UI
    pcall(function()
        loadstring(game:HttpGet(DOWNLOAD_URL))()
    end)

    -- หน่วงสั้นๆ แล้วเปิด HUB (Download UI จะ destroy ตัวเองตอนครบ 100%)
    task.delay(0.4, function()
        pcall(function()
            loadstring(game:HttpGet(HUB_URL))()
        end)
    end)
end

-------------------- UI คีย์ (เรียบง่าย ก๊อปวางจบ) --------------------
local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CoreGui end
end

local function make(class, props, kids)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end

local function tween(o, goal, t)
    TweenService:Create(o, TweenInfo.new(t or .18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function show_key_ui()
    local ACCENT=Color3.fromRGB(0,255,140)
    local BG    = Color3.fromRGB(12,12,12)
    local SUB   = Color3.fromRGB(24,24,24)
    local FG    = Color3.fromRGB(235,235,235)

    local gui = Instance.new("ScreenGui")
    gui.Name="UFOHubX_KeyUI"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local panel = make("Frame", {
        Parent=gui, Active=true, Draggable=true, BackgroundColor3=BG, BorderSizePixel=0,
        Size=UDim2.fromOffset(680, 360), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5)
    }, {
        make("UICorner",{CornerRadius=UDim.new(0,20)}),
        make("UIStroke",{Color=ACCENT, Transparency=0.1, Thickness=2})
    })

    local title = make("TextLabel", {
        Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,24,0,22), Size=UDim2.new(1,-48,0,36),
        Font=Enum.Font.GothamBlack, TextSize=26, Text="UFO HUB X — KEY", TextColor3=FG, TextXAlignment=Enum.TextXAlignment.Left
    })

    local keyLabel = make("TextLabel", {
        Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,24,0,96), Size=UDim2.new(0,60,0,24),
        Font=Enum.Font.Gotham, TextSize=16, Text="Key", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
    })

    local keyStroke
    local keyBox = make("TextBox", {
        Parent=panel, ClearTextOnFocus=false, PlaceholderText="ใส่คีย์ของคุณที่นี่",
        Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
        BackgroundColor3=SUB, BorderSizePixel=0,
        Position=UDim2.new(0,24,0,124), Size=UDim2.new(1,-48,0,40)
    }, {
        make("UICorner",{CornerRadius=UDim.new(0,12)}),
        (function() keyStroke = make("UIStroke",{Color=ACCENT, Transparency=0.65}); return keyStroke end)()
    })

    local status = make("TextLabel", {
        Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,24,0,172), Size=UDim2.new(1,-48,0,22),
        Font=Enum.Font.Gotham, TextSize=14, Text="", TextColor3=Color3.fromRGB(200,200,200),
        TextXAlignment=Enum.TextXAlignment.Left
    })

    local btn = make("TextButton", {
        Parent=panel, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
        BackgroundColor3=Color3.fromRGB(210,60,60), BorderSizePixel=0,
        Position=UDim2.new(0,24,0,210), Size=UDim2.new(1,-48,0,50)
    }, {
        make("UICorner",{CornerRadius=UDim.new(0,14)})
    })

    local submitting=false
    local function setStatus(txt, good)
        status.Text = txt or ""
        if good==nil then status.TextColor3 = Color3.fromRGB(200,200,200)
        elseif good then status.TextColor3 = Color3.fromRGB(120,255,170)
        else status.TextColor3 = Color3.fromRGB(255,120,120) end
    end

    local function flashErr()
        local old = keyStroke.Color
        tween(keyStroke, {Color = Color3.fromRGB(255,90,90), Transparency=0}, .05)
        task.delay(.22, function() tween(keyStroke, {Color=old, Transparency=0.65}, .12) end)
    end

    local function doSubmit()
        if submitting then return end
        submitting=true; btn.Active=false
        local k = keyBox.Text or ""
        if k=="" then
            setStatus("โปรดใส่คีย์ก่อน", false)
            flashErr(); submitting=false; btn.Active=true; return
        end
        btn.Text="⏳ Verifying..."; tween(btn,{BackgroundColor3=Color3.fromRGB(70,170,120)},.08)
        setStatus("กำลังตรวจสอบคีย์...", nil)

        local ok, expOrReason = _G.UFO_VerifyKeyWithServer(k)
        if ok then
            setStatus("ยืนยันสำเร็จ! เปิดหน้าถัดไป...", true)
            btn.Text="✅ Key accepted"
            tween(btn,{BackgroundColor3=Color3.fromRGB(120,255,170)},.10)
            task.delay(0.15, function()
                _G.UFO_GoNext()
            end)
        else
            setStatus((expOrReason=="expired" and "คีย์หมดอายุแล้ว") or "คีย์ไม่ถูกต้อง/ต่อเซิร์ฟเวอร์ไม่ได้", false)
            btn.Text="🔒  Submit Key"
            tween(btn,{BackgroundColor3=Color3.fromRGB(210,60,60)},.10)
            flashErr()
            submitting=false; btn.Active=true
        end
    end

    btn.MouseButton1Click:Connect(doSubmit)
    keyBox.FocusLost:Connect(function(enter) if enter then doSubmit() end end)
end

-------------------- GATE (ตรวจ state ก่อน) --------------------
do
    local st = read_state()
    local now = os.time()
    if st and st.key and st.exp and now < st.exp then
        -- ยังไม่หมดอายุ => ข้าม UI คีย์
        _G.UFO_HUBX_KEY_OK = true
        _G.UFO_HUBX_KEY    = st.key
        _G.UFO_GoNext()
        return
    elseif st and st.exp and now >= st.exp then
        -- หมดอายุ => ล้าง แล้วแสดง UI คีย์ใหม่
        clear_state()
    end
end

-- ไม่มีคีย์/หมดอายุ => แสดง UI คีย์
show_key_ui()
