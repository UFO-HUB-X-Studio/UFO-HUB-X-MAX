--[[
SubmitBtn_Fix (ใช้ของเดิม, แก้เฉพาะให้กดได้)
- ใช้ _G.UFO_VerifyKeyWithServer(inputKey) และ _G.UFO_GoNext() ของเดิมคุณ
- ไม่เปลี่ยนสี ขนาด ฟอนต์ ข้อความ UI เดิมแม้แต่นิด
- แค่ผูกอีเวนต์ปุ่มให้รองรับเมาส์/ทัช + Enter และกันกดรัวเล็กน้อย
]]--

-- ===== ปรับชื่อให้ตรงกับของคุณถ้าจำเป็น =====
local NAME_KeyBox      = "KeyBox"       -- TextBox เดิมของคุณ
local NAME_SubmitBtn   = "SubmitBtn"    -- ปุ่มเดิมของคุณ (TextButton/ImageButton)
local NAME_StatusLabel = "StatusLabel"  -- (ถ้ามี) ไว้โชว์ข้อความ

local COOLDOWN_SEC = 0.3                -- กันกดรัว

-- ===== อ้างอิงชิ้นส่วนเดิม (ไม่สร้าง/ไม่แก้สไตล์) =====
local root = script.Parent
local screenGui = root:FindFirstAncestorWhichIsA("ScreenGui") or root

local function findDeep(where, name)
	for _, d in ipairs(where:GetDescendants()) do
		if d.Name == name then return d end
	end
end

local keyBox     = root:FindFirstChild(NAME_KeyBox, true)     or findDeep(screenGui, NAME_KeyBox)
local submitBtn  = root:FindFirstChild(NAME_SubmitBtn, true)  or findDeep(screenGui, NAME_SubmitBtn)
local statusLbl  = root:FindFirstChild(NAME_StatusLabel, true) or findDeep(screenGui, NAME_StatusLabel)

if not keyBox or not submitBtn then
	warn("[SubmitBtn_Fix] ไม่พบ '"..NAME_KeyBox.."' หรือ '"..NAME_SubmitBtn.."' ใน UI เดิมของคุณ")
	return
end

-- ไม่แตะสไตล์: เขียนเฉพาะข้อความลง StatusLabel ถ้ามี
local function setStatus(msg) if statusLbl then statusLbl.Text = msg or "" end end

-- ===== ฟังก์ชันยืนยัน (เรียกของเดิม) =====
local function verifyWithServer(inputKey)
	-- ต้องมี _G.UFO_VerifyKeyWithServer ของเดิมคุณ
	if typeof(_G) ~= "table" or typeof(_G.UFO_VerifyKeyWithServer) ~= "function" then
		return false, "ยังไม่ได้ประกาศ _G.UFO_VerifyKeyWithServer ในฝั่งเซิร์ฟเวอร์"
	end
	local ok, res = pcall(function() return _G.UFO_VerifyKeyWithServer(inputKey) end)
	if not ok then return false, "ติดต่อเซิร์ฟเวอร์ไม่ได้" end

	-- รองรับได้ทั้งแบบคืน true/false หรือ table {ok=, message=}
	if type(res) == "table" then
		return res.ok == true, res.message or (res.ok and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
	else
		return res == true, (res == true and "ยืนยันสำเร็จ" or "รหัสไม่ถูกต้อง")
	end
end

-- ===== แก้เฉพาะให้ปุ่มกดได้ =====
-- ไม่เปลี่ยนข้อความปุ่ม ไม่เปลี่ยนสี แค่เปิดให้รับคลิกและผูกอีเวนต์ครบทุกแพลตฟอร์ม
if submitBtn:IsA("GuiButton") then
	submitBtn.Active = true     -- ให้รับอินพุต
	submitBtn.Modal = false     -- ไม่กินอินพุตทั้งจอ
	-- ไม่แตะ AutoButtonColor/Text/ZIndex ใด ๆ
end

local busy, lastAt = false, 0
local function onSubmit()
	if busy then return end
	local now = os.clock()
	if now - lastAt < COOLDOWN_SEC then return end
	lastAt = now

	local inputKey = (keyBox.Text or ""):match("^%s*(.-)%s*$")
	if inputKey == "" then setStatus("กรุณากรอกรหัสก่อน"); return end

	busy = true
	local passed, msg = verifyWithServer(inputKey)
	busy = false

	if passed then
		setStatus(msg or "ยืนยันสำเร็จ")
		-- ไปหน้าถัดไปด้วยของเดิม ถ้ามี
		if typeof(_G) == "table" and typeof(_G.UFO_GoNext) == "function" then
			pcall(_G.UFO_GoNext)
		end
	else
		setStatus(msg or "ยืนยันไม่สำเร็จ")
	end
end

-- ผูกอีเวนต์ให้ครบ: Activated (ทัช/เมาส์), MouseButton1Click (เมาส์เก่า), Enter ใน TextBox
if submitBtn.Activated then submitBtn.Activated:Connect(onSubmit) end
if submitBtn.MouseButton1Click then submitBtn.MouseButton1Click:Connect(onSubmit) end
if keyBox.FocusLost then
	keyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then onSubmit() end
	end)
end

-- ข้อความเริ่มต้น (ถ้ามี StatusLabel)
setStatus("กรอกรหัสแล้วกดปุ่มยืนยัน")
