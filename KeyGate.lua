--========================================================
-- UFO HUB X — KeyGate.lua (Minimal Key Gate with Expiry)
-- - มีแค่หน้า Key อย่างเดียว
-- - กดผ่านแล้ว UI ปิด, เซฟอายุคีย์ไว้ในไฟล์
-- - คีย์หมดอายุ เด้ง UI Key ขึ้นมาใหม่อัตโนมัติ
-- - รองรับ Delta / loadstring(game:HttpGet(...)) 100%
--========================================================

-------------------- CONFIG --------------------
local SERVER_BASES = {
    "https://ufo-hub-x-key-umoq.onrender.com", -- เปลี่ยนเป็นเซิร์ฟเวอร์ของคุณได้
    -- "https://backup-server-url.example.com",
}
local SAVE_FILE         = "ufo_key_state.json"     -- ไฟล์เก็บสถานะคีย์
local DEFAULT_TTL_SECS  = 48*3600                  -- สำรอง 48 ชม. ถ้า server ไม่ส่ง expires_at
local ALLOW_KEYS = {                                -- คีย์ผ่านแน่ (ถ้าต้องการ)
    ["JJJMAX"] = true,
    ["GMPANUPHONGARTPHAIRIN"] = true,
}

-------------------- Services --------------------
local Players     = game:GetService("Players")
local CoreGui     = game:GetService("CoreGui")
local TweenService= game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer

-------------------- Helpers: safe parent --------------------
local function safeParent(gui)
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    local ok=false
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CoreGui end
end

-------------------- Helpers: file save/load --------------------
local function canFS() return (isfile and writefile and readfile and makefolder) end
local function loadState()
    if not canFS() then return nil end
    local ok, data = pcall(function()
        if not isfile(SAVE_FILE) then return nil end
        local raw = readfile(SAVE_FILE)
        return HttpService:JSONDecode(raw)
    end)
    return ok and data or nil
end

local function saveState(tbl)
    if not canFS() then return end
    pcall(function()
        local raw = HttpService:JSONEncode(tbl or {})
        writefile(SAVE_FILE, raw)
    end)
end

-------------------- HTTP helpers --------------------
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

local function http_json_get(url)
    local ok, body = http_get(url)
    if not ok or not body then return false, nil end
    local okj, data = pcall(function() return HttpService:JSONDecode(tostring(body)) end)
    if not okj then return false, nil end
    return true, data
end

local function json_get_with_failover(path_qs)
    local lastErr
    for _,base in ipairs(SERVER_BASES) do
        local url = base..path_qs
        for i=0,2 do
            if i>0 then task.wait(0.6*i) end
            local ok, data = http_json_get(url)
            if ok and data then return true, data end
            lastErr = "err"
        end
    end
    return false, lastErr
end

-------------------- Key verify --------------------
local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

local function verifyWithServer(k)
    local nk = normKey(k)
    if ALLOW_KEYS[nk] then
        return true, os.time() + DEFAULT_TTL_SECS
    end
    local uid = tostring(LP and LP.UserId or "")
    local qs  = string.format("/verify?key=%s&uid=%s&format=json",
        HttpService:UrlEncode(k), HttpService:UrlEncode(uid))
    local ok, data = json_get_with_failover(qs)
    if not ok or not data then return false end
    if data.valid == true or (data.ok and data.valid) then
        local exp = tonumber(data.expires_at) or (os.time() + DEFAULT_TTL_SECS)
        return true, exp
    end
    return false
end

-------------------- UI (Key only) --------------------
local function showKeyUI(onAccept)
    local gui = Instance.new("ScreenGui")
    gui.Name = "UFOHubX_KeyUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    safeParent(gui)

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(720, 260)
    panel.AnchorPoint = Vector2.new(0.5,0.5)
    panel.Position = UDim2.fromScale(0.5,0.5)
    panel.BackgroundColor3 = Color3.fromRGB(14,14,14)
    panel.Parent = gui

    Instance.new("UICorner", panel).CornerRadius = UDim.new(0,18)
    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = Color3.fromRGB(0,255,140); stroke.Transparency = 0.1

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 28
    title.Text = "KEY SYSTEM — UFO HUB X"
    title.TextColor3 = Color3.fromRGB(230,230,230)
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.fromOffset(20, 16)
    title.Parent = panel

    local tb = Instance.new("TextBox")
    tb.PlaceholderText = "insert your key here"
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 16
    tb.Text = ""
    tb.TextColor3 = Color3.fromRGB(230,230,230)
    tb.BackgroundColor3 = Color3.fromRGB(30,30,30)
    tb.Size = UDim2.new(1,-60,0,40)
    tb.Position = UDim2.fromOffset(30, 90)
    tb.Parent = panel
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,12)

    local btn = Instance.new("TextButton")
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.Text = "🔒  Submit Key"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = Color3.fromRGB(210,60,60)
    btn.Size = UDim2.new(1,-60,0,46)
    btn.Position = UDim2.fromOffset(30, 150)
    btn.Parent = panel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,14)

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.Text = ""
    status.Size = UDim2.new(1,-60,0,22)
    status.Position = UDim2.fromOffset(30, 202)
    status.Parent = panel

    local submitting = false
    local function setOKUI()
        btn.BackgroundColor3 = Color3.fromRGB(120,255,170)
        btn.Text = "✅ Key accepted"
        btn.TextColor3 = Color3.new(0,0,0)
    end

    local function doSubmit()
        if submitting then return end
        submitting = true
        local k = tb.Text or ""
        if k == "" then
            status.TextColor3 = Color3.fromRGB(255,120,120)
            status.Text = "โปรดใส่รหัสก่อน"
            submitting = false
            return
        end
        status.TextColor3 = Color3.fromRGB(200,200,200)
        status.Text = "กำลังตรวจสอบคีย์..."
        btn.Text = "⏳ Verifying..."

        task.spawn(function()
            local ok, exp = verifyWithServer(k)
            if not ok then
                btn.BackgroundColor3 = Color3.fromRGB(255,80,80)
                btn.Text = "❌ Invalid Key"
                status.TextColor3 = Color3.fromRGB(255,120,120)
                status.Text = "รหัสไม่ถูกต้อง หรือเชื่อมต่อเซิร์ฟเวอร์ไม่ได้"
                task.wait(1.1)
                btn.Text = "🔒  Submit Key"
                btn.BackgroundColor3 = Color3.fromRGB(210,60,60)
                submitting = false
                return
            end

            -- ผ่าน ✅
            setOKUI()
            status.TextColor3 = Color3.fromRGB(120,255,170)
            status.Text = "ยืนยันคีย์สำเร็จ"

            -- เซฟสถานะ
            saveState({ key = k, expires_at = tonumber(exp) or (os.time()+DEFAULT_TTL_SECS) })

            -- ปิด UI แล้วเรียก callback
            task.wait(0.15)
            pcall(function() gui:Destroy() end)
            if onAccept then pcall(onAccept) end
        end)
    end

    btn.MouseButton1Click:Connect(doSubmit)
    tb.FocusLost:Connect(function(enter) if enter then doSubmit() end end)

    return gui
end

-------------------- Expiry Watcher (เด้ง Key UI เมื่อหมดอายุ) --------------------
local function startExpiryWatcher()
    task.spawn(function()
        while true do
            task.wait(30) -- เช็กทุก 30 วิ (พอ)
            local st = loadState()
            local now = os.time()
            if not st or not st.expires_at or now >= tonumber(st.expires_at) then
                -- หมดอายุแล้ว → ล้างสถานะ + เปิด UI Key ทับ
                saveState({})
                if not CoreGui:FindFirstChild("UFOHubX_KeyUI") then
                    showKeyUI(function() end)
                end
            end
        end
    end)
end

-------------------- BOOT --------------------
-- 1) ถ้ามีคีย์และยังไม่หมดอายุ → ไม่ต้องแสดง UI
-- 2) ถ้าไม่มี/หมดอายุ → เปิด UI Key
local state = loadState()
local now   = os.time()
if state and state.expires_at and now < tonumber(state.expires_at) then
    -- มีคีย์ที่ยังใช้ได้
    _G.UFO_HUBX_KEY_OK = true
    _G.UFO_HUBX_KEY    = state.key
else
    -- เปิด UI Key เพื่อขอคีย์
    showKeyUI(function()
        _G.UFO_HUBX_KEY_OK = true
        -- ตรงนี้คือ "ผ่านแล้วทำอะไรต่อ" ถ้าต้องการเชื่อมไปเมนหลัก ก็ loadstring ได้เลย
        -- ตัวอย่าง:
        -- loadstring(game:HttpGet("https://raw.githubusercontent.com/คุณ/Repo/main/UFO%20HUB%20X%20UI.lua"))()
    end)
end

-- เปิดตัวจับหมดอายุเสมอ
startExpiryWatcher()
