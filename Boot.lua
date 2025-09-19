--========================================================
-- UFO HUB X — Boot.lua (หน้าตา UI คีย์ "เหมือนเดิม 100%" + ระบบใหม่)
-- Flow: Key OK -> ปิด UI -> Download UI -> HUB | Key หมดอายุ -> เด้ง UI ใหม่
--========================================================

-------------------- CONFIG (แก้ให้ตรงของคุณ) --------------------
local SERVER_BASE  = "https://ufo-hub-x-key-umoq.onrender.com" -- <== URL เซิร์ฟเวอร์ verify/getkey ของคุณ
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

-------------------- THEME (เหมือนเดิม) --------------------
local LOGO_ID   = 112676905543996
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)
local RED       = Color3.fromRGB(210,60,60)
local GREEN     = Color3.fromRGB(60,200,120)

-------------------- STATE helpers --------------------
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

-------------------- Verify API --------------------
local function verify_key_with_server(inputKey)
    local uid = tostring(LP and LP.UserId or "")
    local url = string.format("%s/verify?key=%s&uid=%s",
        SERVER_BASE, HttpService:UrlEncode(tostring(inputKey or "")), HttpService:UrlEncode(uid))
    local ok, data = http_json_get(url)
    if not ok or not data then return false, "server_unreachable" end
    if data.ok and data.valid then
        local ttl = tonumber(data.ttl) or DEFAULT_TTL_SECONDS
        return true, ttl -- client จะเอา ttl ไปตั้งหมดอายุครั้งแรก
    else
        return false, tostring(data.reason or "invalid")
    end
end

-------------------- UI helpers (เหมือนเดิม) --------------------
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

-------------------- GET KEY link (เหมือนเดิม) --------------------
local function getKeyUrlForCurrentPlayer()
    local uid  = tostring(LP and LP.UserId or "")
    local base = SERVER_BASE
    return string.format("%s/getkey?uid=%s", base, HttpService:UrlEncode(uid))
end

-------------------- GO NEXT: Download -> HUB --------------------
local function go_next()
    -- เปิดหน้าดาวน์โหลด
    pcall(function() loadstring(game:HttpGet(DOWNLOAD_URL))() end)
    -- รอให้ดาวน์โหลดปิด แล้วค่อยโหลด HUB
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

-------------------- KEY UI (หน้าตาเดิม 100%) --------------------
local function show_key_ui(onAccepted)
    -- ROOT
    local gui = Instance.new("ScreenGui")
    gui.Name = "UFOHubX_KeyUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    -- PANEL
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

    -- ปิด X
    local btnClose = make("TextButton", {
        Parent=panel, Text="X", Font=Enum.Font.GothamBold, TextSize=20, TextColor3=Color3.new(1,1,1),
        AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(210,35,50),
        Size=UDim2.new(0,38,0,38), Position=UDim2.new(1,-50,0,14), ZIndex=50
    },{
        make("UICorner",{CornerRadius=UDim.new(0,12)})
    })
    btnClose.MouseButton1Click:Connect(function()
        pcall(function() if gui and gui.Parent then gui:Destroy() end end)
    end)

    -- HEADER
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

    -- TITLE (Welcome + UFO HUB X)
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

    -- KEY INPUT
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

    -- SUBMIT
    local btnSubmit = make("TextButton", {
        Parent=panel, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
        BackgroundColor3=RED, BorderSizePixel=0,
        Size=UDim2.new(1,-56,0,50), Position=UDim2.new(0,28,0,268)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,14)})
    })

    -- TOAST
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

    -- STATUS
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

    -- เอฟเฟกต์ error เหมือนเดิม
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

    -- ปุ่ม Get Key (คัดลอกลิงก์พร้อม uid) เหมือนเดิม
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
        local link = getKeyUrlForCurrentPlayer()
        setClipboard(link)
        btnGetKey.Text = "✅ Link copied!"
        task.delay(1.5,function() btnGetKey.Text="🔐  Get Key" end)
    end)

    -- SUPPORT แถวล่าง (เหมือนเดิม แค่ label)
    local supportRow = make("Frame", {
        Parent=panel, AnchorPoint = Vector2.new(0.5,1),
        Position = UDim2.new(0.5,0,1,-18), Size = UDim2.new(1,-56,0,24),
        BackgroundTransparency = 1
    }, {})
    make("UIListLayout", {
        Parent = supportRow, FillDirection = Enum.FillDirection.HORIZONTAL,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)
    }, {})
    make("TextLabel", {
        Parent=supportRow, LayoutOrder=1, BackgroundTransparency=1,
        Font=Enum.Font.Gotham, TextSize=16, Text="Need support?",
        TextColor3=Color3.fromRGB(200,200,200), AutomaticSize=Enum.AutomaticSize.X
    }, {})

    -- Submit states (เหมือนเดิม)
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

    -- ปิด UI แบบ fade เหมือนเดิม
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

    -- Submit flow (เปลี่ยนแค่ “ระบบ” ด้านใน)
    local function doSubmit()
        if submitting then return end
        submitting = true; btnSubmit.AutoButtonColor = false; btnSubmit.Active = false

        local k = keyBox.Text or ""
        if k == "" then
            tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(255,80,80)}, .08)
            btnSubmit.Text = "🚫 Please enter a key"
            setStatus("โปรดใส่รหัสก่อนนะ", false)
            flashInputError()
            submitting=false; btnSubmit.Active=true; refreshSubmit()
            return
        end

        setStatus("กำลังตรวจสอบคีย์...", nil)
        tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(70,170,120)}, .08)
        btnSubmit.Text = "⏳ Verifying..."

        local ok, ttlOrReason = verify_key_with_server(k)
        if not ok then
            tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(255,80,80)}, .08)
            btnSubmit.Text = "❌ Invalid Key"
            setStatus(ttlOrReason=="server_unreachable" and "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่หรือตรวจเน็ต" or "กุญแจไม่ถูกต้อง ลองอีกครั้ง", false)
            showToast("รหัสไม่ถูกต้อง", false)
            flashInputError()
            submitting=false; btnSubmit.Active=true; refreshSubmit()
            return
        end

        -- ผ่าน ✅: เซฟหมดอายุครั้งแรก (ถ้ายังไม่เคยเซฟ/หรือคีย์ใหม่)
        local now = os.time()
        local cur = read_state()
        local needSet = true
        if cur and cur.key == k and tonumber(cur.expires_at or 0) and now < tonumber(cur.expires_at) then
            needSet = false
        end
        if needSet then
            local exp = now + (tonumber(ttlOrReason) or DEFAULT_TTL_SECONDS)
            write_state({ key = k, expires_at = exp })
        end

        tween(btnSubmit, {BackgroundColor3 = Color3.fromRGB(120,255,170)}, .10)
        btnSubmit.Text = "✅ Key accepted"
        btnSubmit.TextColor3 = Color3.new(0,0,0)
        setStatus("ยืนยันคีย์สำเร็จ พร้อมใช้งาน!", true)
        showToast("ยืนยันสำเร็จ", true)

        task.delay(0.15, function()
            fadeOutAndDestroy()
            if onAccepted then onAccepted() end
        end)
    end
    btnSubmit.MouseButton1Click:Connect(doSubmit)
    btnSubmit.Activated:Connect(doSubmit)
end

-------------------- ENTRY --------------------
local state = read_state()
local now   = os.time()
if state and tonumber(state.expires_at or 0) and now < tonumber(state.expires_at) then
    -- คีย์ยังไม่หมดอายุ -> ไป Download แล้ว HUB
    go_next()
else
    -- ไม่มี/หมดอายุ -> เด้ง UI คีย์ (หน้าตาเดิม)
    show_key_ui(go_next)
end
