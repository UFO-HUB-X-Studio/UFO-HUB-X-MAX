--[[
KeySubmit.Attach (One-File, Zero-Style-Change)
วางเป็น LocalScript ใต้ Frame/ScreenGui ที่มี UI เดิมของคุณ
- ไม่แก้สี/ตัวอักษร/ขนาด/ZIndex/Visible ใด ๆ ของ UI เดิม
- ผูกการทำงานให้ปุ่ม + กล่องคีย์ เดิมของคุณทันที
- หา TextBox/ปุ่มเองได้อัตโนมัติถ้าชื่อไม่ตรง (ไม่สร้าง UI ใหม่)
- รองรับ _G.UFO_VerifyKeyWithServer() หรือ ReplicatedStorage.VerifyKeyRF (RemoteFunction)
- ถ้าไม่มีฝั่งเซิร์ฟเวอร์: ค่าเริ่มต้นผ่านแบบ "โหมดทดสอบ" เพื่อยืนยันว่าปุ่มทำงาน (ปิดได้)

ก็อปทั้งก้อนนี้ไปวางได้เลย
]]--

---------------- CONFIG (แก้ได้ถ้าจำเป็น) ----------------
local NAME_KeyBox      = "KeyBox"       -- ถ้ามีชื่อนี้จะใช้ก่อน
local NAME_SubmitBtn   = "SubmitBtn"    -- ถ้ามีชื่อนี้จะใช้ก่อน
local NAME_StatusLabel = "StatusLabel"  -- (ถ้ามี) ใช้แสดงข้อความผลลัพธ์
local ALLOW_AUTODETECT = true           -- true = เดา TextBox/ปุ่มให้เองถ้าหาไม่เจอ
local TEST_MODE_WHEN_NO_SERVER = true   -- true = ไม่มีฝั่งเซิร์ฟเวอร์ → ผ่านชั่วคราว
local COOLDOWN_SEC = 0.35               -- กันกดรัว
-----------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- utils
local function findByNameDeep(root, name)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then return d end
	end
end

local root = script.Parent
local screenGui = root:FindFirstAncestorWhichIsA("ScreenGui") or root

-- 1) พยายามหาโดยชื่อก่อน (ไม่เปลี่ยนอะไรใน UI เดิม)
local keyBox = findByNameDeep(root, NAME_KeyBox) or findByNameDeep(screenGui, NAME_KeyBox)
local submitBtn = findByNameDeep(root, NAME_SubmitBtn) or findByNameDeep(screenGui, NAME_SubmitBtn)
local statusLabel = findByNameDeep(root, NAME_StatusLabel) or findByNameDeep(screenGui, NAME_StatusLabel)

-- 2) ถ้าหาไม่เจอและอนุญาตให้เดา ลองเดาอย่างสุภาพ (ไม่แก้สไตล์, ไม่สร้างอะไรเพิ่ม)
if ALLOW_AUTODETECT then
	local function score(o)
		local s = 0
		if o:IsA("TextBox") then s += 5 end
		if o:IsA("GuiButton") then s += 5 end
		local n = o.Name:lower()
		if n:find("key") or n:find("code") or n:find("pass") then s += 3 end
		if n:find("submit") or n:find("confirm") or n:find("ok") then s += 3 end
		if o.Visible == true then s += 1 end
		if o.AbsoluteSize.X > 40 and o.AbsoluteSize.Y > 16 then s += 1 end
		return s
	end
	-- รอ 1 เฟรมเพื่อให้มี AbsoluteSize/Position ที่ถูกต้อง
	task.wait()
	if not keyBox then
		local bestS, best = -1, nil
		for _, d in ipairs(screenGui:GetDescendants()) do
			if d:IsA("TextBox") then
				local sc = score(d)
				if sc > bestS then bestS, best = sc, d end
			end
		end
		keyBox = best or keyBox
	end
	if not submitBtn then
		local bestS, best = -1, nil
		for _, d in ipairs(screenGui:GetDescendants()) do
			if d:IsA("GuiButton") then
				local sc = score(d)
				if sc > bestS then bestS, best = sc, d end
			end
		end
		submitBtn = best or submitBtn
	end
	if not statusLabel then
		for _, d in ipairs(screenGui:GetDescendants()) do
			if d:IsA("TextLabel") then statusLabel = d; break end
		end
	end
end

if not keyBox or not submitBtn then
	warn("[KeySubmit.Attach] ไม่พบ TextBox หรือ ปุ่มยืนยันใน UI เดิมของคุณ",
	     "(ตั้งชื่อให้ตรง หรือเปิด ALLOW_AUTODETECT)")
	return
end

-- ไม่แก้ style ใด ๆ ทั้งสิ้น; จะเขียนเฉพาะข้อความลง statusLabel (ถ้ามี)
local function setStatus(msg)
	if statusLabel then statusLabel.Text = msg or "" end
end

-- ช่องทางตรวจคีย์ (อัตโนมัติ)
local VerifyMode, VerifyRF = "none", nil
if typeof(_G) == "table" and typeof(_G.UFO_VerifyKeyWithServer) == "function" then
	VerifyMode = "global"
else
	local rf = ReplicatedStorage:FindFirstChild("VerifyKeyRF")
	if rf and rf:IsA("RemoteFunction") then
		VerifyMode, VerifyRF = "remote", rf
	end
end

local function verifyKey(inputKey)
	inputKey = (inputKey or ""):match("^%s*(.-)%s*$")
	if inputKey == "" then return false, "กรุณากรอกรหัสก่อน" end

	if VerifyMode == "global" then
		local ok, res = pcall(function() return _G.UFO_VerifyKeyWithServer(inputKey) end)
		if not ok then return false, "ติดต่อเซิร์ฟเวอร์ไม่ได้" end
		if type(res) == "table" then return res.ok == true, res.message end
		return res == true, (res == true and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
	elseif VerifyMode == "remote" and VerifyRF then
		local ok, res = pcall(function() return VerifyRF:InvokeServer(inputKey) end)
		if not ok then return false, "ติดต่อเซิร์ฟเวอร์ไม่ได้" end
		if type(res) == "table" then return res.ok == true, res.message end
		return res == true, (res == true and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
	else
		if TEST_MODE_WHEN_NO_SERVER then
			return true, "ยืนยันสำเร็จ (โหมดทดสอบ)"
		else
			return false, "ยังไม่เชื่อมฝั่งเซิร์ฟเวอร์"
		end
	end
end

-- การกด (ไม่เปลี่ยนข้อความปุ่ม/สี/ขนาดของเดิม)
local busy, lastAt = false, 0
local function doSubmit()
	if busy then return end
	local now = os.clock()
	if now - lastAt < COOLDOWN_SEC then return end
	lastAt = now

	local text = keyBox.Text or ""
	if text == "" then setStatus("กรุณากรอกรหัสก่อน"); return end

	busy = true
	local ok, msg = verifyKey(text)
	busy = false

	if ok then
		setStatus(msg or "ยืนยันสำเร็จ")
		-- เรียกไปหน้าถัดไปถ้ามีของเดิม
		if typeof(_G) == "table" and typeof(_G.UFO_GoNext) == "function" then
			pcall(_G.UFO_GoNext)
		end
	else
		setStatus(msg or "ยืนยันไม่สำเร็จ")
	end
end

-- bind สำหรับเมาส์/ทัช + Enter
if submitBtn.Activated then submitBtn.Activated:Connect(doSubmit) end
if submitBtn.MouseButton1Click then submitBtn.MouseButton1Click:Connect(doSubmit) end
if keyBox.FocusLost then
	keyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then doSubmit() end
	end)
end

-- ข้อความเริ่มต้น (เฉพาะถ้ามี StatusLabel)
setStatus("กรอกรหัสแล้วกดปุ่มยืนยัน")
