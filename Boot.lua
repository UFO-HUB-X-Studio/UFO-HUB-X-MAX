--[[
SingleDrop Key Submit - ONE FILE ONLY (LocalScript)
วางไว้ใต้ Frame หรือใต้ ScreenGui ของหน้าใส่คีย์เดิมของคุณ
ไม่เปลี่ยนหน้าตา UI เดิม ใช้ได้ทั้งเมาส์/ทัช/กด Enter

ทำงานได้ 3 โหมดโดยอัตโนมัติ (ไม่ต้องแก้ถ้าไม่จำเป็น):
A) ถ้ามี _G.UFO_VerifyKeyWithServer อยู่แล้ว → เรียกอันนั้น
B) ถ้ามี ReplicatedStorage.VerifyKeyRF (RemoteFunction) → เรียก invoke อันนั้น
C) ถ้าไม่มีอะไรเลย → โหมดทดสอบปุ่ม (ยืนยันสำเร็จชั่วคราว) เพื่อพิสูจน์ว่าปุ่ม “กดติดแน่”

มีตัวช่วยหาว่า “อะไรทับปุ่มอยู่” เปิด-ปิดด้วย DEBUG_INSPECT
]]--

-------------------- CONFIG --------------------
local NAME_KeyBox      = "KeyBox"
local NAME_SubmitBtn   = "SubmitBtn"
local NAME_StatusLabel = "StatusLabel"
local DEBUG_INSPECT    = false   -- true = แตะจอ/คลิกแล้วโชว์ว่าอะไรทับอยู่
local BUTTON_MIN_Z     = 10      -- ดัน ZIndex ปุ่มให้สูงพอไม่โดนบัง
local COOLDOWN_SEC     = 0.35    -- กันกดรัว
------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local root = script.Parent
local screenGui = root:FindFirstAncestorWhichIsA("ScreenGui") or root

-- หา UI เป้าหมาย (จะค้นทั้งใต้ root)
local function findDeep(parent, name)
	for _, d in ipairs(parent:GetDescendants()) do
		if d.Name == name then return d end
	end
	return nil
end

local keyBox = root:FindFirstChild(NAME_KeyBox, true) or findDeep(screenGui, NAME_KeyBox)
local submitBtn = root:FindFirstChild(NAME_SubmitBtn, true) or findDeep(screenGui, NAME_SubmitBtn)
local statusLabel = root:FindFirstChild(NAME_StatusLabel, true) or findDeep(screenGui, NAME_StatusLabel)

-- เซ็ตค่าพื้นฐานแบบไม่รบกวนหน้าตา
if screenGui and screenGui:IsA("ScreenGui") then
	screenGui.Enabled = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
end
if submitBtn and submitBtn:IsA("GuiButton") then
	submitBtn.Active = true
	submitBtn.AutoButtonColor = true
	submitBtn.Modal = false
	submitBtn.ZIndex = math.max(submitBtn.ZIndex, BUTTON_MIN_Z)
end
if root.Visible ~= nil then root.Visible = true end

-- helper: สถานะ
local busy, lastClickAt = false, 0
local function setStatus(text, ok)
	if not statusLabel then return end
	statusLabel.Text = text or ""
	if ok == nil then return end
	if ok then
		statusLabel.TextColor3 = Color3.fromRGB(40,180,80)
	else
		statusLabel.TextColor3 = Color3.fromRGB(220,60,60)
	end
end

local function setBusy(isBusy, text)
	busy = isBusy
	if submitBtn and submitBtn:IsA("TextButton") then
		submitBtn.Text = isBusy and "กำลังตรวจสอบ..." or "ยืนยัน"
	end
	if text then setStatus(text) end
	if submitBtn then
		submitBtn.Active = not isBusy
		submitBtn.AutoButtonColor = not isBusy
	end
end

-- ตรวจว่ามีช่องทางใดให้ยืนยันคีย์กับเซิร์ฟเวอร์บ้าง
local VerifyMode = "local"  -- "global", "remote", "local"
local VerifyRF = nil

if typeof(_G) == "table" and typeof(_G.UFO_VerifyKeyWithServer) == "function" then
	VerifyMode = "global"
else
	local ok, rf = pcall(function() return ReplicatedStorage:FindFirstChild("VerifyKeyRF") end)
	if ok and rf and rf:IsA("RemoteFunction") then
		VerifyRF = rf
		VerifyMode = "remote"
	end
end

-- ฟังก์ชันยืนยัน (เลือกทางที่เจอ)
local function verifyKey(inputKey: string)
	inputKey = (inputKey or ""):match("^%s*(.-)%s*$")
	if inputKey == "" then
		return false, "กรุณากรอกรหัสก่อน"
	end

	if VerifyMode == "global" then
		local ok, res = pcall(function()
			return _G.UFO_VerifyKeyWithServer(inputKey)
		end)
		if not ok then return false, "ติดต่อเซิร์ฟเวอร์ไม่ได้" end

		-- รองรับได้ทั้งแบบคืน true/false หรือ table {ok=, message=}
		if type(res) == "table" then
			return res.ok == true, res.message or (res.ok and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
		else
			return res == true, (res == true and "ยืนยันสำเร็จ" or (tostring(res) ~= "true" and tostring(res) or "รหัสไม่ถูกต้อง"))
		end
	elseif VerifyMode == "remote" and VerifyRF then
		local ok, res = pcall(function()
			return VerifyRF:InvokeServer(inputKey)
		end)
		if not ok then return false, "ติดต่อเซิร์ฟเวอร์ไม่ได้" end
		if type(res) == "table" then
			return res.ok == true, res.message or (res.ok and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
		else
			return res == true, (res == true and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
		end
	else
		-- โหมดทดสอบปุ่มล้วน ๆ (เพื่อยืนยันว่า UI “กดติด” แน่)
		return true, "ยืนยันสำเร็จ (โหมดทดสอบปุ่ม)"
	end
end

-- ตัวช่วยดูว่าอะไรทับอยู่ (ถ้าต้องการดีบักให้ตั้ง DEBUG_INSPECT = true)
if DEBUG_INSPECT then
	local function highlight(gui)
		local box = Instance.new("Frame")
		box.Name = "__HighlightTemp"
		box.BorderSizePixel = 2
		box.BackgroundTransparency = 1
		box.BorderColor3 = Color3.fromRGB(255,80,80)
		box.ZIndex = 999999
		box.Parent = screenGui
		box.Size = UDim2.fromOffset(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
		box.Position = UDim2.fromOffset(gui.AbsolutePosition.X, gui.AbsolutePosition.Y)
		task.delay(0.4, function() box:Destroy() end)
	end
	local function dumpAt(x,y)
		local list = UIS:GetGuiObjectsAtPosition(x,y)
		if #list == 0 then
			print(("[Inspector] (%d,%d) ไม่มี GUI"):format(x,y)); return
		end
		print(("[Inspector] (%d,%d) บน→ล่าง:"):format(x,y))
		for i,g in ipairs(list) do
			print(("  %d) %s [Z=%d, Visible=%s, Class=%s]")
				:format(i, g:GetFullName(), g.ZIndex, tostring(g.Visible), g.ClassName))
			highlight(g)
		end
		if submitBtn and list[1] ~= submitBtn then
			print("[Inspector] ตัวบนสุดไม่ใช่ SubmitBtn → มีของทับ ให้ลด ZIndex/ซ่อนตัวนั้น")
		end
	end
	UIS.InputBegan:Connect(function(input,gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			local p = input.Position
			dumpAt(p.X, p.Y)
		end
	end)
end

-- การกดปุ่ม (รวมป้องกันกดรัว)
local function doSubmit()
	if busy then return end
	-- กันกดรัวเร็วเกิน
	local now = os.clock()
	if now - lastClickAt < COOLDOWN_SEC then return end
	lastClickAt = now

	local inputKey = (keyBox and keyBox.Text) or ""
	if inputKey == "" then
		setStatus("กรุณากรอกรหัสก่อน", false)
		return
	end

	setBusy(true, "กำลังตรวจสอบรหัส...")

	local ok, msg = verifyKey(inputKey)
	if ok then
		setStatus(msg or "ยืนยันสำเร็จ", true)
		task.wait(0.2)
		-- เรียกไปหน้าถัดไปถ้าคุณมีอยู่แล้ว
		if typeof(_G)=="table" and typeof(_G.UFO_GoNext)=="function" then
			pcall(_G.UFO_GoNext)
		end
		-- ปิดหน้าคีย์
		local sg = submitBtn and submitBtn:FindFirstAncestorWhichIsA("ScreenGui") or screenGui
		if sg then sg.Enabled = false end
	else
		setBusy(false, msg or "ยืนยันไม่สำเร็จ")
		setStatus(msg or "ยืนยันไม่สำเร็จ", false)
	end
end

-- bind event: ปุ่ม & เมาส์/ทัช & Enter
if submitBtn then
	if submitBtn.Activated then submitBtn.Activated:Connect(doSubmit) end
	if submitBtn.MouseButton1Click then submitBtn.MouseButton1Click:Connect(doSubmit) end
end
if keyBox and keyBox.FocusLost then
	keyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then doSubmit() end
	end)
end

-- ข้อความเริ่มต้น
setBusy(false, "กรอกรหัสแล้วกดปุ่มยืนยัน")
