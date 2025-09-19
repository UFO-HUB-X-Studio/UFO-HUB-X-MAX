--========================================================
-- UFO HUB X — One-Paste Loader (Key → Download → Main)
-- - รองรับ Delta 100% และใช้แค่ game:HttpGet + loadstring
-- - ขั้นตอน:
--     1) เปิด UI Key จาก GitHub (ลิงก์ที่ให้)
--     2) รอ _G.UFO_HUBX_KEY_OK == true หรือ UI Key ปิดเอง
--     3) เปิด UI Download (ลิงก์ที่ให้)
--     4) รอให้ UI Download จบ/ปิด แล้วค่อยเปิด Main (ถ้ามี)
-- - ถ้า UI Download โหลดตัวหลักเองอยู่แล้ว สคริปต์นี้จะไม่ซ้ำ
--========================================================

-- === URL ที่ให้มา (ไม่ต้องแก้) ===
local KEY_UI_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local DL_UI_URL  = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"

-- === (ตัวเลือก) MAIN URL กรณีอยากให้ loader นี้เป็นคนเปิดตัวหลักเองหลังจาก Download เสร็จ
-- ถ้า UI Download เป็นคนเปิดตัวหลักให้อยู่แล้ว ก็ปล่อยค่าว่างไว้ได้
local MAIN_UI_URL = _G.UFO_MAIN_URL or nil  -- ใส่ลิงก์ main ของคุณได้ เช่น: "https://raw.githubusercontent.com/...../UFO%20HUB%20X%20Main.lua"

--========================================================
-- Utilities (เน้นเรียบง่าย ใช้ได้กับ Delta)
--========================================================
local CoreGui  = game:GetService("CoreGui")
local Players  = game:GetService("Players")
local HttpGet  = function(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return body end
    return nil
end

local function safeLoad(url, label)
    local src = HttpGet(url)
    if not src then
        warn("[UFO Loader] โหลดไม่สำเร็จ:", label or url)
        return false
    end
    local f, err = loadstring(src)
    if not f then
        warn("[UFO Loader] loadstring error:", label or url, err)
        return false
    end
    local ok, runErr = pcall(f)
    if not ok then
        warn("[UFO Loader] runtime error:", label or url, runErr)
        return false
    end
    return true
end

local function waitFor(predicate, timeout)
    local t0 = os.clock()
    while true do
        local ok, res = pcall(predicate)
        if ok and res then return true end
        if timeout and (os.clock() - t0) > timeout then return false end
        task.wait(0.1)
    end
end

local function findGuiByHint(names)
    for _, g in ipairs(CoreGui:GetChildren()) do
        if g:IsA("ScreenGui") then
            local n = (g.Name or ""):lower()
            for _, hint in ipairs(names) do
                if n:find(hint) then return g end
            end
        end
    end
    return nil
end

--========================================================
-- 1) เปิด UI KEY
--========================================================
_G.UFO_HUBX_KEY_OK = _G.UFO_HUBX_KEY_OK or false  -- ให้สคริปต์ key ตั้งค่านี้เป็น true เมื่อผ่าน

print("[UFO Loader] Loading KEY UI …")
safeLoad(KEY_UI_URL, "KEY_UI")

-- ชื่อ GUI ที่มักใช้กับ Key UI (เผื่อเช็คว่าปิด/หายไป)
local keyHints = {"ufohubx_keyui", "keyui", "key ui"}

-- รอ: ผ่านคีย์ หรือ UI Key ถูกปิด พร้อม timeout กันหลุดเงียบ
local keyPassed = waitFor(function()
    if _G.UFO_HUBX_KEY_OK == true then return true end
    -- ถ้าไม่มี GUI Key แล้ว (ผู้ใช้ปิดเองหลังผ่าน) ก็ถือว่าผ่าน
    local g = findGuiByHint(keyHints)
    if not g and _G.UFO_HUBX_KEY_OK == true then return true end
    return false
end, 180) -- 3 นาทีพอ

if not keyPassed then
    warn("[UFO Loader] ไม่พบการยืนยันคีย์ในเวลาที่กำหนด")
    -- ถ้าต้องการบังคับให้หยุดตรงนี้ ให้ return ได้
    -- return
end

-- พยายามปิด Key UI ถ้ายังค้างอยู่
do
    local g = findGuiByHint(keyHints)
    if g then pcall(function() g.Enabled=false g:Destroy() end) end
end

print("[UFO Loader] KEY OK → เปิด UI Download")

--========================================================
-- 2) เปิด UI DOWNLOAD
--========================================================
-- UI Download ควรตั้ง _G.UFO_DOWNLOAD_DONE = true เมื่อกดเสร็จ/ปิด
_G.UFO_DOWNLOAD_DONE = _G.UFO_DOWNLOAD_DONE or false

safeLoad(DL_UI_URL, "DOWNLOAD_UI")

-- เดาฮินท์ชื่อ GUI ของ Download
local dlHints = {"download", "ufo hub x download", "downloader"}

-- รอจน UI Download ปิด/เสร็จ
local dlDone = waitFor(function()
    if _G.UFO_DOWNLOAD_DONE == true then return true end
    local g = findGuiByHint(dlHints)
    if not g then
        -- ไม่มี GUI download แล้ว ถือว่าเสร็จ
        return true
    end
    return false
end, 240) -- 4 นาที

if not dlDone then
    warn("[UFO Loader] Download UI ไม่เสร็จในเวลาที่กำหนด — จะไปต่อให้")
end

-- พยายามปิด Download UI ถ้ายังค้างอยู่
do
    local g = findGuiByHint(dlHints)
    if g then pcall(function() g.Enabled=false g:Destroy() end) end
end

print("[UFO Loader] DOWNLOAD OK → เตรียมเปิด MAIN")

--========================================================
-- 3) เปิด “UFO HUB X (ตัวหลัก)”
--    ลำดับความสำคัญ:
--      3.1 ถ้า UI Download สร้างฟังก์ชัน/ตัวแปรให้เรียก เช่น _G.UFO_LAUNCH_MAIN() → ใช้ก่อน
--      3.2 ถ้ามี _G.UFO_MAIN_URL → โหลดตาม URL นั้น
--      3.3 ถ้ากำหนด MAIN_UI_URL ไว้ด้านบน → โหลดอันนั้น
--      (ถ้า UI Download เปิดตัวหลักไว้แล้วอยู่แล้ว โค้ดนี้จะข้าม/ไม่ทำซ้ำ)
--========================================================

-- 3.1: ถ้า UI Download เตรียมฟังก์ชันไว้
if type(_G.UFO_LAUNCH_MAIN) == "function" then
    local ok, err = pcall(_G.UFO_LAUNCH_MAIN)
    if not ok then warn("[UFO Loader] _G.UFO_LAUNCH_MAIN error:", err) end
else
    -- 3.2 / 3.3: โหลดจาก URL
    local finalMain = _G.UFO_MAIN_URL or MAIN_UI_URL
    if finalMain and type(finalMain)=="string" and #finalMain>0 then
        print("[UFO Loader] Loading MAIN from URL …")
        safeLoad(finalMain, "MAIN_UI")
    else
        print("[UFO Loader] ไม่พบ MAIN URL / ไม่ได้กำหนดไว้ → หาก UI Download เป็นคนเปิดตัวหลักเอง ก็ถือว่าเสร็จแล้ว")
    end
end

print("[UFO Loader] DONE ✓")
