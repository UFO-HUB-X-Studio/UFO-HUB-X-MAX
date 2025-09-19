--========================================================
-- UFO HUB X — KEY GATE (UI Key เท่านั้น + จำอายุ + เด้งกลับเมื่อหมดเวลา)
--========================================================

-------------------- CONFIG --------------------
local SERVER_BASE = "https://ufo-hub-x-key-umoq.onrender.com"   -- เปลี่ยนได้
local DEFAULT_TTL = 48*3600                                      -- 48 ชม. (กรณี server ไม่ส่ง expires_at)
local SAVE_FILE   = "UFOX_key_state.json"                        -- ชื่อไฟล์ (ถ้า executor รองรับไฟล์)
local UI_NAME     = "UFOHubX_KeyUI"
local LOGO_ID     = 112676905543996
local ACCENT      = Color3.fromRGB(0,255,140)
local BG_DARK     = Color3.fromRGB(10,10,10)
local FG          = Color3.fromRGB(235,235,235)
local SUB         = Color3.fromRGB(22,22,22)
local RED         = Color3.fromRGB(210,60,60)
local GREEN       = Color3.fromRGB(60,200,120)

-------------------- Guards --------------------
if _G.__UFOX_KEYGATE_RUNNING then return end
_G.__UFOX_KEYGATE_RUNNING = true

-------------------- Services --------------------
local Players     = game:GetService("Players")
local LP          = Players.LocalPlayer
local CG          = game:GetService("CoreGui")
local TS          = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-------------------- Small helpers --------------------
local function pjson(tbl) return HttpService:JSONEncode(tbl) end
local function ujson(s) local ok,d=pcall(function()return HttpService:JSONDecode(s) end);return ok and d or nil end

local function now() return os.time() end
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

-------------------- Persist (ไฟล์ถ้ามี, ไม่งั้นใช้ _G) --------------------
local function canFile() return writefile and readfile and isfile end
local function saveState(key, exp)
    local data = { key = key, exp = tonumber(exp) or (now()+DEFAULT_TTL) }
    if canFile() then
        pcall(function() writefile(SAVE_FILE, pjson(data)) end)
    end
    _G.__UFOX_KEYSTATE = data
end
local function loadState()
    if canFile() and isfile(SAVE_FILE) then
        local ok,s = pcall(readfile, SAVE_FILE)
        if ok and s then
            local d = ujson(s)
            if d and d.exp then _G.__UFOX_KEYSTATE = d end
        end
    end
    return _G.__UFOX_KEYSTATE
end
local function clearState()
    if canFile() and isfile(SAVE_FILE) then pcall(function() writefile(SAVE_FILE, "") end) end
    _G.__UFOX_KEYSTATE = nil
end

-------------------- Server verify --------------------
local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "http_failed"
end

local function verifyWithServer(k)
    local uid = tostring(LP and LP.UserId or "")
    local url = string.format("%s/verify?key=%s&uid=%s&format=json",
        SERVER_BASE,
        HttpService:UrlEncode(k),
        HttpService:UrlEncode(uid)
    )
    local ok, body = http_get(url)
    if not ok then return false, "server_unreachable" end
    local data = ujson(tostring(body)) or {}
    if (data.ok and data.valid) or (data.valid==true) then
        local exp = tonumber(data.expires_at) or (now()+DEFAULT_TTL)
        return true, exp
    end
    return false, tostring(data.reason or "invalid")
end

-------------------- UI --------------------
local keyUI -- forward

local function destroyUI()
    if keyUI and keyUI.Parent then keyUI:Destroy() end
    keyUI = nil
end

local function openKeyUI()
    destroyUI() -- กันซ้อน
    local gui = Instance.new("ScreenGui")
    gui.Name = UI_NAME
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    safeParent(gui); keyUI = gui

    local panel = make("Frame",{
        Parent=gui, Active=true, Draggable=true,
        Size=UDim2.fromOffset(740, 430),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        BackgroundColor3=BG_DARK, BorderSizePixel=0
    },{
        make("UICorner",{CornerRadius=UDim.new(0,22)}),
        make("UIStroke",{Color=ACCENT, Thickness=2, Transparency=0.1})
    })

    local head = make("Frame",{
        Parent=panel, BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(14,14,14),
        Size=UDim2.new(1,-28,0,68), Position=UDim2.new(0,14,0,14)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,16)}),
        make("UIStroke",{Color=ACCENT, Transparency=0.85})
    })
    make("ImageLabel",{Parent=head, BackgroundTransparency=1, Image="rbxassetid://"..LOGO_ID, Size=UDim2.new(0,34,0,34), Position=UDim2.new(0,16,0,17)}, {})
    make("TextLabel",{Parent=head, BackgroundTransparency=1, Position=UDim2.new(0,60,0,18),
        Size=UDim2.new(0,200,0,32), Font=Enum.Font.GothamBold, TextSize=20, Text="KEY SYSTEM", TextColor3=ACCENT, TextXAlignment=Enum.TextXAlignment.Left},{})

    local keyStroke
    make("TextLabel",{Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,188),
        Size=UDim2.new(0,60,0,22), Font=Enum.Font.Gotham, TextSize=16, Text="Key", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left}, {})
    local keyBox = make("TextBox",{
        Parent=panel, ClearTextOnFocus=false, PlaceholderText="insert your key here",
        Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
        BackgroundColor3=SUB, BorderSizePixel=0,
        Size=UDim2.new(1,-56,0,40), Position=UDim2.new(0,28,0,214)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,12)}),
        (function() keyStroke = make("UIStroke",{Color=ACCENT, Transparency=0.75}); return keyStroke end)()
    })

    local status = make("TextLabel",{
        Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,268+50+6),
        Size=UDim2.new(1,-56,0,24), Font=Enum.Font.Gotham, TextSize=14, Text="", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
    },{})

    local submit = make("TextButton",{
        Parent=panel, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false,
        BackgroundColor3=RED, BorderSizePixel=0,
        Size=UDim2.new(1,-56,0,50), Position=UDim2.new(0,28,0,268)
    },{
        make("UICorner",{CornerRadius=UDim.new(0,14)})
    })

    local function setStatus(t, ok)
        status.Text = t or ""
        if ok==nil then status.TextColor3 = Color3.fromRGB(200,200,200)
        elseif ok then status.TextColor3 = Color3.fromRGB(120,255,170)
        else status.TextColor3 = Color3.fromRGB(255,120,120) end
    end

    local submitting=false
    local function refreshBtn()
        if submitting then return end
        if #(keyBox.Text or "")>0 then
            TS:Create(submit, TweenInfo.new(.08), {BackgroundColor3=GREEN}):Play()
            submit.Text = "🔓  Submit Key"
            submit.TextColor3 = Color3.new(0,0,0)
        else
            TS:Create(submit, TweenInfo.new(.08), {BackgroundColor3=RED}):Play()
            submit.Text = "🔒  Submit Key"
            submit.TextColor3 = Color3.new(1,1,1)
        end
    end
    keyBox:GetPropertyChangedSignal("Text"):Connect(refreshBtn); refreshBtn()

    local function doSubmit()
        if submitting then return end
        local k = keyBox.Text or ""
        if k=="" then setStatus("โปรดใส่รหัสก่อน", false) return end
        submitting=true; submit.Active=false
        setStatus("กำลังตรวจสอบ...", nil)
        TS:Create(submit, TweenInfo.new(.08), {BackgroundColor3=Color3.fromRGB(70,170,120)}):Play()
        submit.Text = "⏳ Verifying..."

        local ok, exp_or_reason = verifyWithServer(k)
        if not ok then
            setStatus(exp_or_reason=="server_unreachable" and "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้" or "คีย์ไม่ถูกต้อง", false)
            submitting=false; submit.Active=true; refreshBtn(); return
        end

        -- สำเร็จ
        saveState(k, exp_or_reason)
        setStatus("ยืนยันคีย์สำเร็จ!", true)
        TS:Create(submit, TweenInfo.new(.10), {BackgroundColor3=Color3.fromRGB(120,255,170)}):Play()
        submit.Text = "✅ Key accepted"
        task.delay(0.25, destroyUI)
    end
    submit.MouseButton1Click:Connect(doSubmit)
    keyBox.FocusLost:Connect(function(enter) if enter then doSubmit() end end)
end

-------------------- Boot logic --------------------
local function keyValid()
    local st = loadState()
    return st and st.exp and (tonumber(st.exp) or 0) > now()
end

-- เริ่ม: ถ้าคีย์ยังไม่หมดอายุ → ไม่ต้องแสดง UI
if not keyValid() then
    openKeyUI()
end

-- ตัวเฝ้า: หมดอายุเมื่อไรให้เปิด UI อัตโนมัติ
task.spawn(function()
    while true do
        task.wait(5)
        local st = loadState()
        local expired = not (st and st.exp and (tonumber(st.exp) or 0) > now())
        local uiOpen  = keyUI and keyUI.Parent
        if expired and not uiOpen then
            openKeyUI()
        end
    end
end)
