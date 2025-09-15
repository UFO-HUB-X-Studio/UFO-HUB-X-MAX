--================ BOOT (ใส่ในตัวรันหลัก) ================
local http = (syn and syn.request) or http_request or request
local function fetch(url)
  local ok,res = pcall(function() return game:HttpGet(url) end)
  return ok and res or nil
end

-- ป้ายกันซ้ำ: main/splash/toggle
if _G.__UFOX_RUNNING then return end
_G.__UFOX_RUNNING = true

-- 1) โหลด KEY MODULE แล้วบังคับให้ผ่านก่อน
local KEY_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/README3.lua"
local keySrc  = fetch(KEY_URL); assert(keySrc, "โหลด KEY MODULE ไม่ได้")
local KEY     = loadstring(keySrc)()

if not KEY.isValid() then
  KEY.prompt({ durationSec = 24*60*60 })        -- รอจนผู้ใช้กด Submit ถูก
  -- รอจนผ่านคีย์
  while not KEY.isValid() do task.wait(0.1) end
end

-- 2) (ออปชัน) Splash/Loading
local SPLASH_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/README2.lua"
local spSrc = fetch(SPLASH_URL)
if spSrc then
  local SPLASH = loadstring(spSrc)()
  if SPLASH and SPLASH.show then SPLASH.show({durationSec = 2.2}) end
end

-- 3) โหลด UI หลัก (ขึ้นเฉพาะหลังผ่าน Key)
local UI_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/README.lua"
local uiSrc = fetch(UI_URL); assert(uiSrc, "โหลด UI ไม่ได้")
local UI = loadstring(uiSrc)()

-- บังคับไม่ให้สร้าง UI ซ้ำ
if _G.__UFOX_UI_ON then
  if UI and UI.destroy then UI.destroy() end
end
_G.__UFOX_UI_ON = true

-- ทำให้ปุ่มเปิด/ปิด และหน้าต่างหลัก ลากได้สมูท (ถ้าโมดูล UI มี hook ให้)
if UI and UI.makeDraggable then
  UI.makeDraggable() -- ส่วนนี้ใน README.lua ควรมีฟังก์ชันรองรับ
end
