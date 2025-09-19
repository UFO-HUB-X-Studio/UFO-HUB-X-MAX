--========================================================
-- UFO HUB X — KEY-ONLY DEBUG LOADER (Delta-ready)
-- จุดประสงค์: โหลด "UI Key" จากลิงก์ GitHub ให้ขึ้นแน่นอน + มีจอ Debug
--========================================================

local KEY_UI_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"

--================ Debug Overlay ================
local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")

local function mk(class, props, kids)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end

local box = mk("ScreenGui", {Name="UFO_DebugKeyOnly", ResetOnSpawn=false})
box.Parent = CG

local panel = mk("Frame", {
    Size=UDim2.fromOffset(420, 140),
    Position=UDim2.new(0, 12, 0, 12),
    BackgroundColor3=Color3.fromRGB(14,14,14),
    BorderSizePixel=0,
}, {
    mk("UICorner",{CornerRadius=UDim.new(0,12)}),
    mk("UIStroke",{Color=Color3.fromRGB(0,255,140), Transparency=0.7}),
})
panel.Parent = box

local title = mk("TextLabel", {
    BackgroundTransparency=1,
    Size=UDim2.new(1, -16, 0, 26),
    Position=UDim2.new(0, 8, 0, 6),
    Font=Enum.Font.GothamBold,
    TextSize=16,
    TextColor3=Color3.fromRGB(220,255,230),
    TextXAlignment=Enum.TextXAlignment.Left,
    Text="UFO HUB X — KEY UI DEBUG"
})
title.Parent = panel

local status = mk("TextLabel", {
    BackgroundTransparency=1,
    Size=UDim2.new(1, -16, 1, -40),
    Position=UDim2.new(0, 8, 0, 34),
    Font=Enum.Font.Code,
    TextWrapped=true,
    TextYAlignment=Enum.TextYAlignment.Top,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextSize=14,
    TextColor3=Color3.fromRGB(235,235,235),
    Text="เริ่มทำงาน..."
})
status.Parent = panel

local function log(line)
    status.Text = (status.Text .. "\n" .. tostring(line))
end

--================ Helpers ================
local function httpget(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    return ok and body or nil, (ok and nil or "HttpGet failed")
end

local function tryLoad(url)
    log("> โหลดสคริปต์ Key UI …")
    local src, herr = httpget(url)
    if not src then
        log("✗ โหลดไม่ได้: " .. tostring(herr))
        return false, "HTTP_FAIL"
    end
    log("✓ โหลดได้ ("..tostring(#src).." bytes) → เริ่ม run")
    local f, lerr = loadstring(src)
    if not f then
        log("✗ loadstring error: "..tostring(lerr))
        return false, "LOADSTRING_FAIL"
    end
    local ok, rerr = pcall(f)
    if not ok then
        log("✗ runtime error: "..tostring(rerr))
        return false, "RUNTIME_FAIL"
    end
    log("✓ รันสำเร็จ")
    return true, nil
end

local function findKeyGUI()
    local hints = {"ufohubx_keyui","keyui","key ui","ufo hub x key"}
    for _, g in ipairs(CG:GetChildren()) do
        if g:IsA("ScreenGui") then
            local n = (g.Name or ""):lower()
            for _, h in ipairs(hints) do
                if n:find(h) then return g end
            end
        end
    end
    return nil
end

local function waitForKeyGUI(timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 8) do
        local g = findKeyGUI()
        if g then return g end
        task.wait(0.15)
    end
    return nil
end

--================ Flow ================
log("URL: "..KEY_UI_URL)

-- 1) ลองโหลด Key UI
local ok = false
do
    local success = false
    success = select(1, tryLoad(KEY_UI_URL))
    ok = success
end

-- 2) ตรวจว่ามี GUI Key โผล่ขึ้นไหม
local keyGui = waitForKeyGUI(10)
if keyGui then
    log("✓ พบ Key UI: ".. keyGui.Name)
else
    log("✗ ไม่พบ Key UI ใน CoreGui ภายในเวลา 10s")
    if ok then
        log("หมายเหตุ: สคริปต์ Key UI อาจสร้าง GUI ชื่ออื่น หรือไป parent ที่ PlayerGui → แต่ใน exploit/Delta ปกติมาที่ CoreGui")
        log("แนะนำ: ตรวจสอบโค้ด Key UI ให้ตั้งชื่อ ScreenGui ให้เด่น เช่น 'UFOHubX_KeyUI'")
    end
end

-- 3) แสดงคำใบ้การใช้งานตัวต่อไป
log("")
log("ถ้าขึ้น Key UI แล้ว: ให้ใส่คีย์ → กด Submit → UI Key จะหายไปเอง (โค้ดฝั่ง Key UI ต้อง set _G.UFO_HUBX_KEY_OK = true)")
log("ถ้าขึ้นไม่มา: ให้ส่งข้อความในช่องนี้ทั้งหมดให้ฉัน เพื่อแก้จุดที่ fail")

-- ให้ลาก panel ไปเก็บมุมได้
panel.Active = true
panel.Draggable = true
