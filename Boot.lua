--[[
KeyGate - FULL UI (Single File)
วางที่: StarterPlayer/StarterPlayerScripts (LocalScript)
- สร้าง UI ให้ครบ (ScreenGui + Frame + KeyBox + SubmitBtn + StatusLabel)
- รองรับเมาส์/ทัช/Enter, กันกดรัว, โทนสีปรับได้
- ถ้ามี _G.UFO_VerifyKeyWithServer หรือ ReplicatedStorage.VerifyKeyRF จะใช้ของคุณอัตโนมัติ
- ถ้าไม่มีฝั่งเซิร์ฟเวอร์ → โหมดทดสอบ (ผ่านชั่วคราว) เพื่อยืนยันว่าปุ่มและ UI ทำงาน

แก้ค่าที่ CONFIG ด้านล่างเพื่อปรับข้อความ/สี/ขนาดได้
]]--

------------------ CONFIG ------------------
local TITLE_TEXT        = "ใส่รหัสเพื่อเข้าใช้งาน"
local PLACEHOLDER_TEXT  = "กรอกรหัสที่นี่..."
local BUTTON_TEXT_IDLE  = "ยืนยัน"
local BUTTON_TEXT_BUSY  = "กำลังตรวจสอบ..."
local SUCCESS_TEXT      = "ยืนยันสำเร็จ"
local TEST_MODE_TEXT    = "ยืนยันสำเร็จ (โหมดทดสอบ)"
local ERROR_EMPTY_TEXT  = "กรุณากรอกรหัสก่อน"
local ERROR_NET_TEXT    = "ติดต่อเซิร์ฟเวอร์ไม่ได้"
local ERROR_FAIL_TEXT   = "รหัสไม่ถูกต้อง"

-- สีธีม
local COLOR_BG          = Color3.fromRGB(18, 22, 28)
local COLOR_CARD        = Color3.fromRGB(28, 34, 42)
local COLOR_ACCENT      = Color3.fromRGB(88, 180, 255)
local COLOR_BTN         = Color3.fromRGB(120, 210, 140)
local COLOR_TEXT        = Color3.fromRGB(235, 238, 243)
local COLOR_MUTED       = Color3.fromRGB(170, 178, 188)
local COLOR_OK          = Color3.fromRGB(40, 180, 80)
local COLOR_ERR         = Color3.fromRGB(220, 60, 60)

-- พฤติกรรม
local DISPLAY_ORDER     = 500
local COOLDOWN_SEC      = 0.35  -- กันกดรัว
local CLOSE_ON_SUCCESS  = true  -- ปิด UI เมื่อยืนยันผ่าน
--------------------------------------------

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Rep     = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local function getPlayerGui()
    local pg = plr:FindFirstChildOfClass("PlayerGui")
    while not pg do plr.ChildAdded:Wait(); pg = plr:FindFirstChildOfClass("PlayerGui") end
    return pg
end
local PlayerGui = getPlayerGui()

-- ถ้ามีของเก่า ค่อยๆ เคลียร์เพื่อไม่ให้ซ้อน
do
    local old = PlayerGui:FindFirstChild("__KeyGateUI")
    if old then old:Destroy() end
end

-- ===== สร้าง UI ทั้งชุด =====
local sg = Instance.new("ScreenGui")
sg.Name = "__KeyGateUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = DISPLAY_ORDER
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = PlayerGui

-- พื้นหลัง
local bg = Instance.new("Frame")
bg.BackgroundColor3 = COLOR_BG
bg.BackgroundTransparency = 0.1
bg.Size = UDim2.fromScale(1,1)
bg.Parent = sg

-- ทำให้ UI ปรับตามขนาดจอ
local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.Size = UDim2.fromScale(1,1)
holder.Parent = bg

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(520, 260)
card.BackgroundColor3 = COLOR_CARD
card.BorderSizePixel = 0
card.Parent = holder
local corner = Instance.new("UICorner", card); corner.CornerRadius = UDim.new(0, 16)
local shadow = Instance.new("ImageLabel", card)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5028857084"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.4
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24,24,276,276)
shadow.Size = UDim2.new(1, 24, 1, 24)
shadow.Position = UDim2.fromOffset(-12, -8)
shadow.ZIndex = 0

local pad = Instance.new("UIPadding", card)
pad.PaddingLeft   = UDim.new(0, 20)
pad.PaddingRight  = UDim.new(0, 20)
pad.PaddingTop    = UDim.new(0, 18)
pad.PaddingBottom = UDim.new(0, 18)

-- หัวข้อ
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Text = TITLE_TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = COLOR_TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Size = UDim2.new(1, 0, 0, 34)
title.Parent = card

-- เส้นคั่น
local sep = Instance.new("Frame")
sep.BorderSizePixel = 0
sep.BackgroundColor3 = COLOR_ACCENT
sep.BackgroundTransparency = 0.4
sep.Size = UDim2.new(1, 0, 0, 1)
sep.Position = UDim2.fromOffset(0, 52)
sep.Parent = card

-- กล่องรหัส
local keyBox = Instance.new("TextBox")
keyBox.Name = "KeyBox"
keyBox.PlaceholderText = PLACEHOLDER_TEXT
keyBox.Text = ""
keyBox.Font = Enum.Font.Gotham
keyBox.TextSize = 18
keyBox.TextColor3 = COLOR_TEXT
keyBox.PlaceholderColor3 = COLOR_MUTED
keyBox.BackgroundColor3 = Color3.fromRGB(35, 42, 52)
keyBox.BorderSizePixel = 0
keyBox.ClearTextOnFocus = false
keyBox.Size = UDim2.new(1, -40, 0, 40)
keyBox.Position = UDim2.fromOffset(20, 74)
keyBox.Parent = card
local kbCorner = Instance.new("UICorner", keyBox); kbCorner.CornerRadius = UDim.new(0, 10)
local kbPad = Instance.new("UIPadding", keyBox); kbPad.PaddingLeft = UDim.new(0, 10)

-- ปุ่มยืนยัน
local submitBtn = Instance.new("TextButton")
submitBtn.Name = "SubmitBtn"
submitBtn.Text = BUTTON_TEXT_IDLE
submitBtn.Font = Enum.Font.GothamBold
submitBtn.TextSize = 18
submitBtn.TextColor3 = Color3.fromRGB(20, 22, 24)
submitBtn.BackgroundColor3 = COLOR_BTN
submitBtn.AutoButtonColor = true
submitBtn.BorderSizePixel = 0
submitBtn.Size = UDim2.fromOffset(140, 40)
submitBtn.Position = UDim2.fromOffset(card.AbsoluteSize.X - 160, 128) -- จะถูกจัดใหม่หลังวัดขนาด
submitBtn.Parent = card
local sbCorner = Instance.new("UICorner", submitBtn); sbCorner.CornerRadius = UDim.new(0, 10)

-- สถานะ
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "กรอกรหัสแล้วกดปุ่มยืนยัน"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 16
statusLabel.TextColor3 = COLOR_MUTED
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Size = UDim2.new(1, -40, 0, 28)
statusLabel.Position = UDim2.fromOffset(20, 176)
statusLabel.Parent = card

-- จัดปุ่มให้ชิดขวาอัตโนมัติหลังวัดขนาด
RS.Heartbeat:Wait()
submitBtn.Position = UDim2.fromOffset(card.AbsoluteSize.X - submitBtn.AbsoluteSize.X - 20, 128)

-- ตั้งค่าให้พร้อมคลิก
submitBtn.Active = true
submitBtn.Modal = false
submitBtn.ZIndex = math.max(submitBtn.ZIndex, 10)

-- ===== ฟังก์ชันช่วย =====
local busy, lastClick = false, 0
local function setStatus(text, ok)
    statusLabel.Text = text or ""
    if ok == nil then return end
    statusLabel.TextColor3 = ok and COLOR_OK or COLOR_ERR
end
local function setBusy(isBusy, text)
    busy = isBusy
    submitBtn.Text = isBusy and BUTTON_TEXT_BUSY or BUTTON_TEXT_IDLE
    submitBtn.Active = not isBusy
    submitBtn.AutoButtonColor = not isBusy
    if text then setStatus(text) end
end

-- ตรวจช่องทางยืนยันคีย์
local mode, VerifyRF = "local", nil
if typeof(_G)=="table" and typeof(_G.UFO_VerifyKeyWithServer)=="function" then
    mode = "global"
else
    local rf = Rep:FindFirstChild("VerifyKeyRF")
    if rf and rf:IsA("RemoteFunction") then
        mode, VerifyRF = "remote", rf
    end
end

local function verifyKey(k)
    k = (k or ""):match("^%s*(.-)%s*$")
    if k == "" then return false, ERROR_EMPTY_TEXT end
    if mode == "global" then
        local ok,res = pcall(function() return _G.UFO_VerifyKeyWithServer(k) end)
        if not ok then return false, ERROR_NET_TEXT end
        if type(res)=="table" then
            return res.ok==true, res.message or (res.ok and SUCCESS_TEXT or ERROR_FAIL_TEXT)
        else
            return res==true, (res==true and SUCCESS_TEXT or ERROR_FAIL_TEXT)
        end
    elseif mode == "remote" and VerifyRF then
        local ok,res = pcall(function() return VerifyRF:InvokeServer(k) end)
        if not ok then return false, ERROR_NET_TEXT end
        if type(res)=="table" then
            return res.ok==true, res.message or (res.ok and SUCCESS_TEXT or ERROR_FAIL_TEXT)
        else
            return res==true, (res==true and SUCCESS_TEXT or ERROR_FAIL_TEXT)
        end
    else
        return true, TEST_MODE_TEXT
    end
end

local function doSubmit()
    if busy then return end
    local now = os.clock()
    if now - lastClick < COOLDOWN_SEC then return end
    lastClick = now

    local text = keyBox.Text or ""
    if text == "" then setStatus(ERROR_EMPTY_TEXT, false); return end

    setBusy(true, "กำลังตรวจสอบรหัส...")
    local ok,msg = verifyKey(text)
    if ok then
        setStatus(msg or SUCCESS_TEXT, true)
        task.wait(0.2)
        if typeof(_G)=="table" and typeof(_G.UFO_GoNext)=="function" then pcall(_G.UFO_GoNext) end
        if CLOSE_ON_SUCCESS then sg.Enabled = false end
    else
        setBusy(false, msg or ERROR_FAIL_TEXT)
        setStatus(msg or ERROR_FAIL_TEXT, false)
    end
end

-- bind ปุ่ม + Enter
submitBtn.Activated:Connect(doSubmit)
if submitBtn.MouseButton1Click then submitBtn.MouseButton1Click:Connect(doSubmit) end
keyBox.FocusLost:Connect(function(enter) if enter then doSubmit() end end)

-- โฟกัสกล่องทันทีบนคีย์บอร์ด/พีซี
task.defer(function()
    if not UIS.TouchEnabled then keyBox:CaptureFocus() end
end)
