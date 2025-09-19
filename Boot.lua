--[[
UI First Aid (Single Drop) - วางที่ StarterPlayerScripts (LocalScript)
เป้าหมาย: บังคับให้ "หน้าคีย์" ของคุณโผล่ + วินิจฉัยสาเหตุถ้าไม่โผล่
- ไม่เปลี่ยนหน้าตาเดิม (แค่เปิดใช้/ดันลำดับ/แก้ค่าปลอดภัย)
- ถ้าไม่พบหน้าคีย์ จะสร้าง overlay เล็ก ๆ บอกทางแก้ พร้อมปุ่มรีเฟรช
- กด Shift+K เพื่อสลับแสดง/ซ่อนหน้าคีย์อย่างแรง และพิมพ์ Debug Tree

ตั้งชื่อชิ้นส่วนมาตรฐาน (แก้ได้):
  ScreenGui/Frame เดิมของคุณมี:
    - TextBox:  "KeyBox"
    - TextButton:"SubmitBtn"
    - TextLabel: "StatusLabel"
]]--

---------------- CONFIG ----------------
local KEYBOX_NAME      = "KeyBox"
local SUBMITBTN_NAME   = "SubmitBtn"
local STATUSLBL_NAME   = "StatusLabel"
local FORCE_DISPLAY_ORDER = 1000   -- ดันให้สูงกว่าพวก overlay อื่น
local FORCE_ZINDEX_BEHAV  = Enum.ZIndexBehavior.Sibling
local IGNORE_GUI_INSET    = true
local HOTKEY_TOGGLE       = Enum.KeyCode.K -- กด Shift+K เพื่อ toggle
---------------------------------------

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local Rep     = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local function waitForPlayerGui()
    local pg = plr:FindFirstChildOfClass("PlayerGui")
    while not pg do
        plr.ChildAdded:Wait()
        pg = plr:FindFirstChildOfClass("PlayerGui")
    end
    return pg
end

local PlayerGui = waitForPlayerGui()

-- หา ScreenGui "หน้าคีย์" โดยเดาอิงจากโครงเดิม (มี SubmitBtn/KeyBox)
local function findKeyScreenGui()
    for _, sg in ipairs(PlayerGui:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Enabled then
            if sg:FindFirstChild(SUBMITBTN_NAME, true) or sg:FindFirstChild(KEYBOX_NAME, true) then
                return sg
            end
        end
    end
    -- หาใน StarterGui แล้ว clone มาก็ได้
    local StarterGui = game:GetService("StarterGui")
    for _, sg in ipairs(StarterGui:GetChildren()) do
        if sg:IsA("ScreenGui") then
            if sg:FindFirstChild(SUBMITBTN_NAME, true) or sg:FindFirstChild(KEYBOX_NAME, true) then
                local clone = sg:Clone()
                clone.Parent = PlayerGui
                return clone
            end
        end
    end
    -- หาใน ReplicatedStorage เผื่อเก็บไว้ที่นั่น
    for _, sg in ipairs(Rep:GetChildren()) do
        if sg:IsA("ScreenGui") then
            if sg:FindFirstChild(SUBMITBTN_NAME, true) or sg:FindFirstChild(KEYBOX_NAME, true) then
                local clone = sg:Clone()
                clone.Parent = PlayerGui
                return clone
            end
        end
    end
    return nil
end

local function listAt(x, y)
    local list = UIS:GetGuiObjectsAtPosition(x,y)
    print((">> GuiAt(%d,%d) top→down:"):format(x,y))
    for i,g in ipairs(list) do
        print(("  %02d) %s [Z=%d Vis=%s Class=%s]"):format(i, g:GetFullName(), g.ZIndex, tostring(g.Visible), g.ClassName))
    end
    return list
end

local function highlight(gui)
    local box = Instance.new("Frame")
    box.Name = "__UIFirstAidHighlight"
    box.BorderSizePixel = 2
    box.BackgroundTransparency = 1
    box.BorderColor3 = Color3.fromRGB(255, 80, 80)
    box.ZIndex = 999999
    box.IgnoreGuiInset = true
    box.Parent = PlayerGui
    box.Size = UDim2.fromOffset(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
    box.Position = UDim2.fromOffset(gui.AbsolutePosition.X, gui.AbsolutePosition.Y)
    task.delay(0.5, function() box:Destroy() end)
end

local function makeOverlay(msg, onRefresh)
    local overlay = Instance.new("ScreenGui")
    overlay.Name = "__UIFirstAidOverlay"
    overlay.ResetOnSpawn = false
    overlay.DisplayOrder = FORCE_DISPLAY_ORDER + 10
    overlay.ZIndexBehavior = FORCE_ZINDEX_BEHAV
    overlay.IgnoreGuiInset = IGNORE_GUI_INSET
    overlay.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.12)
    frame.Size = UDim2.fromOffset(520, 86)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = overlay

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 10)

    local padding = Instance.new("UIPadding", frame)
    padding.PaddingLeft  = UDim.new(0,12)
    padding.PaddingRight = UDim.new(0,12)
    padding.PaddingTop   = UDim.new(0,10)
    padding.PaddingBottom= UDim.new(0,10)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text = msg
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 16
    label.TextColor3 = Color3.fromRGB(245,245,245)
    label.Size = UDim2.new(1, -130, 1, 0)
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Text = "รีเฟรช UI"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.AutoButtonColor = true
    btn.TextColor3 = Color3.fromRGB(20,20,20)
    btn.Size = UDim2.fromOffset(110, 36)
    btn.Position = UDim2.new(1, -110, 1, -36)
    btn.BackgroundColor3 = Color3.fromRGB(140, 220, 140)
    btn.BorderSizePixel = 0
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.Activated:Connect(function()
        if onRefresh then onRefresh() end
        overlay:Destroy()
    end)

    return overlay
end

local function ensureVisible(sg)
    if not sg then return end
    sg.Enabled = true
    sg.DisplayOrder = FORCE_DISPLAY_ORDER
    sg.ZIndexBehavior = FORCE_ZINDEX_BEHAV
    sg.IgnoreGuiInset = IGNORE_GUI_INSET
    -- ถ้าเฟรมหลักถูกซ่อนจะบังคับให้ Visible = true
    for _, d in ipairs(sg:GetDescendants()) do
        if d:IsA("GuiObject") and d.Visible == false then
            -- ไม่เปลี่ยนทุกชิ้น แต่ถ้าเป็น Container ใหญ่ ๆ ค่อยเปิด
            if d:IsA("Frame") or d:IsA("ScrollingFrame") then
                d.Visible = true
            end
        end
    end
end

local function pushButtonSafe(btn)
    if not (btn and btn:IsA("GuiButton")) then return end
    btn.Active = true
    btn.AutoButtonColor = true
    btn.Modal = false
    btn.ZIndex = math.max(btn.ZIndex, 10)
end

-- === Main flow ===
local keySG = findKeyScreenGui()

if not keySG then
    local ov
    local function refresher()
        keySG = findKeyScreenGui()
        if keySG then
            ensureVisible(keySG)
            print("[UIFirstAid] พบหน้าคีย์แล้ว:", keySG:GetFullName())
        else
            print("[UIFirstAid] ยังไม่พบหน้าคีย์ ตรวจว่าอยู่ใน StarterGui/ReplicatedStorage หรือชื่อปุ่ม/กล่องถูกต้อง")
        end
    end
    ov = makeOverlay(
        "ไม่พบ 'หน้าคีย์' ตอนโหลด\n- ตรวจว่า ScreenGui ของหน้าคีย์อยู่ใน StarterGui\n- ให้มีชิ้นส่วนชื่อ '"..SUBMITBTN_NAME.."' หรือ '"..KEYBOX_NAME.."' อย่างน้อย 1 ชิ้น\n- กดปุ่มด้านขวาเพื่อลองรีเฟรชค้นหาอีกครั้ง",
        refresher
    )
else
    ensureVisible(keySG)
    print("[UIFirstAid] ใช้งานหน้าคีย์:", keySG:GetFullName())
end

-- ดันปุ่มให้ใช้งานได้จริง + พิมพ์เหตุที่อาจโดนทับ
local function postCheck()
    if not keySG then return end
    local submitBtn = keySG:FindFirstChild(SUBMITBTN_NAME, true)
    local keyBox    = keySG:FindFirstChild(KEYBOX_NAME, true)
    local statusLbl = keySG:FindFirstChild(STATUSLBL_NAME, true)

    if submitBtn then pushButtonSafe(submitBtn) end
    if keyBox and keyBox:IsA("TextBox") then keyBox.ClearTextOnFocus = false end

    -- สแกนตำแหน่งกึ่งกลางของปุ่มว่ามีอะไร "ทับ" มั้ย
    if submitBtn and submitBtn.AbsoluteSize.X > 0 then
        local center = submitBtn.AbsolutePosition + submitBtn.AbsoluteSize/2
        local list = listAt(center.X, center.Y)
        if #list > 0 and list[1] ~= submitBtn then
            print("[UIFirstAid] ตัวบนสุดที่รับคลิกไม่ใช่ปุ่มของคุณ → มีของทับอยู่ (ไฮไลต์ให้ 0.5 วินาที)")
            highlight(list[1])
        end
    end

    -- สร้างข้อความเริ่มต้นให้ผู้เล่นรู้ว่าต้องทำอะไร
    if statusLbl and statusLbl:IsA("TextLabel") then
        statusLbl.Text = "กรอกรหัสแล้วกดปุ่มยืนยัน"
        statusLbl.TextColor3 = Color3.fromRGB(245,245,245)
    end
end

-- ทำหลังเฟรมเรนเดอร์เพื่อให้ AbsolutePosition/Size ถูกต้อง
RS.Heartbeat:Wait()
postCheck()

-- Hotkey: Shift+K → toggle หน้าคีย์ + dump debug
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == HOTKEY_TOGGLE and UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
        if keySG then
            keySG.Enabled = not keySG.Enabled
            print("[UIFirstAid] Toggle ScreenGui.Enabled →", keySG.Enabled)
            if keySG.Enabled then
                ensureVisible(keySG)
                postCheck()
            end
        end
    end
end)

-- เฝ้า: ถ้าหน้าคีย์ถูก Disable/ทำหายตอนรีสปอน → เปิดคืนอัตโนมัติ
PlayerGui.ChildRemoved:Connect(function(child)
    if child == keySG then
        task.defer(function()
            keySG = findKeyScreenGui()
            if keySG then
                ensureVisible(keySG)
                print("[UIFirstAid] หน้าคีย์ถูกลบ → กู้คืนแล้ว:", keySG:GetFullName())
                postCheck()
            end
        end)
    end
end)
