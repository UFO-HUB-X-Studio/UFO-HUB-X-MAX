--========================================================
-- UFO HUB X — Boot.lua : Key → Download → HUB (single file)
-- ใส่คีย์ถูก = ปิด UI → โหลด Download → แล้วโหลด HUB
-- คีย์หมดอายุครั้งหน้า = เด้ง UI key ใหม่
--========================================================

-------------------- CONFIG (แก้ให้ตรงของคุณ) --------------------
local SERVER_BASE = "https://ufo-hub-x-key-umoq.onrender.com" -- <== แก้โดเมนเซิร์ฟเวอร์ของคุณ
local DOWNLOAD_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local FINAL_HUB_URL= "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X.lua"

local DEFAULT_TTL_SECONDS = 48 * 3600
local STATE_FILE = "ufo_key_state.json"

-------------------- Services --------------------
local TS          = game:GetService("TweenService")
local CG          = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LP          = Players.LocalPlayer

-------------------- THEME --------------------
local LOGO_ID = 112676905543996
local ACCENT  = Color3.fromRGB(0,255,140)
local BG      = Color3.fromRGB(12,12,12)
local SUB     = Color3.fromRGB(22,22,22)
local FG      = Color3.fromRGB(235,235,235)
local RED     = Color3.fromRGB(210,60,60)
local GREEN   = Color3.fromRGB(60,200,120)

-------------------- Utils: file state --------------------
local function read_state()
    if readfile and isfile and pcall(function() return isfile(STATE_FILE) end) and isfile(STATE_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(STATE_FILE)) end)
        if ok and type(data)=="table" then return data end
    end
    if type(_G.UFO_KEY_STATE)=="table" then return _G.UFO_KEY_STATE end
    return nil
end
local function write_state(tbl)
    _G.UFO_KEY_STATE = tbl
    if writefile then pcall(function() writefile(STATE_FILE, HttpService:JSONEncode(tbl or {})) end) end
end

-------------------- HTTP helpers --------------------
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

-------------------- Verify API (client policy) --------------------
local function verify_key_with_server(k)
    local uid = tostring(LP and LP.UserId or "")
    local url = string.format("%s/verify?key=%s&uid=%s",
        SERVER_BASE, HttpService:UrlEncode(k), HttpService:UrlEncode(uid))
    local ok, data = http_json_get(url)
    if not ok or not data then return false, "server_unreachable" end
    if data.ok and data.valid then
        local ttl = tonumber(data.ttl) or DEFAULT_TTL_SECONDS
        return true, ttl
    else
        return false, tostring(data.reason or "invalid")
    end
end

-------------------- UI: Key --------------------
local function safeParent(gui)
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    local ok=false
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

local function show_key_ui(onAccepted)
    local gui = Instance.new("ScreenGui")
    gui.Name = "UFOHubX_KeyUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local win = make("Frame", {
        Parent=gui, Size=UDim2.fromOffset(720, 360),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        BackgroundColor3=BG, BorderSizePixel=0
    }, {
        make("UICorner",{CornerRadius=UDim.new(0,18)}),
        make("UIStroke",{Thickness=2, Color=ACCENT, Transparency=0.08})
    })

    local head = make("Frame", {
        Parent=win, BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(14,14,14),
        Size=UDim2.new(1,-24,0,64), Position=UDim2.new(0,12,0,12)
    }, {
        make("UICorner",{CornerRadius=UDim.new(0,14)}),
        make("UIStroke",{Color=ACCENT, Transparency=0.85})
    })
    make("ImageLabel", {
        Parent=head, BackgroundTransparency=1, Image="rbxassetid://"..LOGO_ID,
        Size=UDim2.new(0,32,0,32), Position=UDim2.new(0,16,0,16)
    },{})
    make("TextLabel", {
        Parent=head, BackgroundTransparency=1, Position=UDim2.new(0,60,0,16),
        Size=UDim2.new(0,240,0,32), Font=Enum.Font.GothamBold, TextSize=20,
        Text="KEY SYSTEM", TextColor3=ACCENT, TextXAlignment=Enum.TextXAlignment.Left
    }, {})

    make("TextLabel", {
        Parent=win, BackgroundTransparency=1, Position=UDim2.new(0,24,0,104),
        Size=UDim2.new(0,60,0,22), Font=Enum.Font.Gotham, TextSize=16,
        Text="Key", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
    }, {})

    local keyStroke
    local keyBox = make("TextBox", {
        Parent=win, ClearTextOnFocus=false, PlaceholderText="insert your key here",
        Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
        BackgroundColor3=SUB, BorderSizePixel=0,
        Size=UDim2.new(1,-48,0,42), Position=UDim2.new(0,24,0,132)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,12)}),
        (function() keyStroke = make("UIStroke",{Color=ACCENT, Transparency=0.75}); return keyStroke end)()
    })

    local statusLabel = make("TextLabel", {
        Parent=win, BackgroundTransparency=1, Position=UDim2.new(0,24,0,178),
        Size=UDim2.new(1,-48,0,20), Font=Enum.Font.Gotham, TextSize=14, Text="",
        TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
    }, {})
    local function setStatus(msg, good)
        statusLabel.Text = msg or ""
        if good == nil then
            statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
        elseif good then
            statusLabel.TextColor3 = Color3.fromRGB(120,255,170)
        else
            statusLabel.TextColor3 = Color3.fromRGB(255,120,120)
        end
    end

    local btnSubmit = make("TextButton", {
        Parent=win, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
        BackgroundColor3=RED, BorderSizePixel=0,
        Size=UDim2.new(1,-48,0,50), Position=UDim2.new(0,24,0,210)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,14)})
    })

    local submitting=false
    local function refreshSubmit()
        if submitting then return end
        local hasText = keyBox.Text and (#keyBox.Text>0)
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
    keyBox:GetPropertyChangedSignal("Text"):Connect(function() setStatus("", nil); refreshSubmit() end)
    refreshSubmit()

    local function closeUI()
        tween(win, {BackgroundTransparency = 1}, .15)
        for _,d in ipairs(win:GetDescendants()) do
            pcall(function()
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    TS:Create(d, TweenInfo.new(.15), {TextTransparency = 1}):Play()
                elseif d:IsA("ImageLabel") then
                    TS:Create(d, TweenInfo.new(.15), {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
                elseif d:IsA("Frame") then
                    TS:Create(d, TweenInfo.new(.15), {BackgroundTransparency = 1}):Play()
                elseif d:IsA("UIStroke") then
                    TS:Create(d, TweenInfo.new(.15), {Transparency = 1}):Play()
                end
            end)
        end
        task.delay(.18, function() pcall(function() gui:Destroy() end) end)
    end

    local function onSubmit()
        if submitting then return end
        submitting=true; btnSubmit.Active=false

        local inputKey = keyBox.Text or ""
        if inputKey == "" then
            setStatus("⚠️ กรุณาใส่รหัสก่อน", false)
            submitting=false; btnSubmit.Active=true; refreshSubmit()
            return
        end

        btnSubmit.Text = "⏳ Verifying..."
        setStatus("กำลังตรวจสอบคีย์...", nil)

        local ok, ttlOrReason = verify_key_with_server(inputKey)
        if ok then
            -- ฝั่ง client เป็นผู้ “ตั้ง” หมดอายุครั้งแรกเท่านั้น
            local now = os.time()
            local cur = read_state()
            local needSet = true
            if cur and cur.key == inputKey and tonumber(cur.expires_at or 0) and now < tonumber(cur.expires_at) then
                -- มีคีย์เดิมและยังไม่หมดอายุ -> ไม่ต่ออายุ
                needSet = false
            end
            if needSet then
                local exp = now + (tonumber(ttlOrReason) or DEFAULT_TTL_SECONDS)
                write_state({ key = inputKey, expires_at = exp })
            end

            setStatus("✅ ยืนยันสำเร็จ", true)
            btnSubmit.Text = "✅ Key Accepted"
            task.delay(0.25, function()
                closeUI()
                if onAccepted then onAccepted() end
            end)
        else
            if ttlOrReason=="server_unreachable" then
                setStatus("🌐 เซิร์ฟเวอร์ไม่ตอบสนอง", false)
            elseif ttlOrReason=="invalid" then
                setStatus("❌ คีย์ไม่ถูกต้อง", false)
            elseif ttlOrReason=="expired" then
                setStatus("⏰ คีย์หมดอายุแล้ว", false)
            else
                setStatus("❌ ไม่สามารถยืนยันคีย์ได้ ("..tostring(ttlOrReason)..")", false)
            end
            submitting=false; btnSubmit.Active=true; refreshSubmit()
        end
    end

    btnSubmit.MouseButton1Click:Connect(onSubmit)
    keyBox.FocusLost:Connect(function(enter) if enter then onSubmit() end end)
end

-------------------- Next steps: Download → HUB --------------------
local function go_next()
    -- โหลดหน้า Download
    pcall(function()
        loadstring(game:HttpGet(DOWNLOAD_URL))()
    end)
    -- รอให้ Download ปิด (หรือหมดเวลา) แล้วค่อยโหลด HUB
    task.spawn(function()
        local tmax = tick() + 60
        while tick() < tmax do
            if not CG:FindFirstChild("UFOHubX_Download") then break end
            task.wait(0.25)
        end
        pcall(function()
            if FINAL_HUB_URL and FINAL_HUB_URL ~= "" then
                loadstring(game:HttpGet(FINAL_HUB_URL))()
            end
        end)
    end)
end

-------------------- Entry --------------------
local state = read_state()
local now   = os.time()
if state and tonumber(state.expires_at or 0) and now < tonumber(state.expires_at) then
    -- คีย์ยังดี → ไปต่อเลย
    go_next()
else
    -- ไม่มีคีย์ / หมดอายุ → โชว์ UI key
    show_key_ui(go_next)
end
