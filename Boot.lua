--========================================================
-- UFO HUB X — Key Flow Manager (ครบลูป + ตรวจหมดอายุ + ทดสอบ TTL)
--========================================================

-------------------- CONFIG: URL --------------------
local URL_KEY_UI = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD_UI = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
-- ใส่ไฟล์ UI หลักของคุณ (ถ้าเปลี่ยนที่เก็บให้แก้ URL นี้)
local URL_MAIN_UI = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X.lua"

-------------------- CONFIG: ทดสอบหมดอายุไว (เลือกเปิด) --------------------
-- ตั้งเลขเป็นวินาทีเพื่อบังคับ TTL ของคีย์ให้สั้นลง (เพื่อทดสอบ)
-- ตัวอย่าง 15 = คีย์หมดอายุภายใน 15 วิ หลังยืนยันสำเร็จ
-- ปิดโหมดทดสอบ = ใส่ nil หรือ 0
local TEST_FORCE_TTL_SECONDS = nil  -- เช่น 15 หรือ 30, ถ้าไม่ทดสอบให้เป็น nil

-------------------- THEME / DEFAULT TTL --------------------
local DEFAULT_TTL_SECONDS = 48 * 3600 -- 48 ชั่วโมง

-------------------- HELPERS --------------------
local CG = game:GetService("CoreGui")
local function safeHttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return body end
    return nil
end
local function run(url)
    local src = safeHttpGet(url)
    if not src then return false, "http_failed" end
    local f, err = loadstring(src)
    if not f then return false, "compile_failed: "..tostring(err) end
    local ok, perr = pcall(f)
    if not ok then return false, "runtime_failed: "..tostring(perr) end
    return true
end

-- ปิด GUI ตามชื่อ ถ้ามี
local function closeGuiByNames(names)
    for _, n in ipairs(names) do
        pcall(function()
            local g = CG:FindFirstChild(n)
            if g then g:Destroy() end
        end)
    end
end

-- อ่าน/เขียนคีย์แบบถึก ๆ (ถ้า _G.UFO_SaveKeyState/_G.UFO_LoadKeyState ไม่มี ให้มีสำรอง)
_G.UFO_LoadKeyState = _G.UFO_LoadKeyState or function()
    return _G.UFO_HUBX_KEY, _G.UFO_HUBX_EXPIRES
end
_G.UFO_SaveKeyState = _G.UFO_SaveKeyState or function(key, expires_at, silent)
    _G.UFO_HUBX_KEY      = key
    _G.UFO_HUBX_EXPIRES  = tonumber(expires_at) or (os.time() + DEFAULT_TTL_SECONDS)
    if not silent then
        print(("[UFO] Saved key %s exp=%s"):format(tostring(key), tostring(_G.UFO_HUBX_EXPIRES)))
    end
end

-- ให้ UI Key ที่คุณใช้อยู่ เรียกใช้ได้: ถ้า UI Key ไม่ได้ส่ง expires_at มาเอง
_G.UFO_OnKeyAccepted = function(key, expires_at_from_server)
    local exp = tonumber(expires_at_from_server) or (os.time() + DEFAULT_TTL_SECONDS)
    -- โหมดลองหมดอายุไว
    if TEST_FORCE_TTL_SECONDS and TEST_FORCE_TTL_SECONDS > 0 then
        exp = os.time() + TEST_FORCE_TTL_SECONDS
    end
    _G.UFO_SaveKeyState(key, exp, true)
    _G.UFO_HUBX_KEY_OK = true
end

local function keyIsValid()
    local key, exp = _G.UFO_LoadKeyState()
    if not key or not exp then return false end
    return os.time() < tonumber(exp)
end

-- เปิด UI KEY (ให้ UI Key เดิมของคุณโหลด แล้วเมื่อกดยืนยันคีย์สำเร็จ มันควรเรียก _G.UFO_OnKeyAccepted)
local function openKeyUI()
    -- เผื่อ UI Key ตัวเก่าเปิดค้าง
    closeGuiByNames({"UFOHubX_KeyUI"})
    local ok, err = run(URL_KEY_UI)
    if not ok then
        warn("[UFO] openKeyUI failed: "..tostring(err))
        return false
    end
    return true
end

-- เปิด UI DOWNLOAD แล้วค่อยเปิด MAIN UI ต่อ
local function openDownloadThenMain()
    closeGuiByNames({"UFOHubX_Download"}) -- กันซ้อน
    local ok, err = run(URL_DOWNLOAD_UI)
    if not ok then
        warn("[UFO] openDownload UI failed: "..tostring(err))
        -- ถ้าโหลดหน้า Download ไม่ได้ ก็ข้ามไปเปิด Main เลย
        local ok2, err2 = run(URL_MAIN_UI)
        if not ok2 then warn("[UFO] openMain failed: "..tostring(err2)) end
        return
    end
    -- หมายเหตุ: ไฟล์ Download ของคุณทำลายตัวเองแล้วค่อย load main ในตัวอยู่แล้ว
    -- ถ้าไฟล์ Download ของคุณ “ไม่ได้” เรียก main ต่อ ให้ปลดคอมเมนต์บรรทัดด้านล่างแทน
    -- task.delay(10.5, function() run(URL_MAIN_UI) end) -- เผื่อเวลาโหลด 10 วิ + buffer
end

-- watchdog: ตรวจอายุคีย์ ถ้าหมดอายุ ให้ปิดหน้าที่เปิดอยู่ แล้วเปิด UI Key ใหม่
local function startKeyWatchdog()
    task.spawn(function()
        while true do
            task.wait(5)
            local key, exp = _G.UFO_LoadKeyState()
            if not key or not exp or os.time() >= tonumber(exp) then
                -- ปิดทุกหน้าที่เกี่ยว (กันซ้อน)
                closeGuiByNames({"UFOHubX_Download", "UFOHubX_KeyUI", "UFOHubX", "UFO_HUB_X_Main"})
                -- เปิด UI Key ใหม่
                openKeyUI()
                break
            end
        end
    end)
end

-------------------- BOOT --------------------
-- 1) ถ้า “ยังไม่มีคีย์” หรือ “คีย์หมดอายุแล้ว” → เปิด UI Key
-- 2) ถ้า “คีย์ยังไม่หมดอายุ” → เปิด Download แล้วต่อไป Main
-- 3) เปิด watchdog ให้รีเฟรชกลับไป UI Key เมื่อหมดอายุระหว่างใช้งาน
local function boot()
    if keyIsValid() then
        openDownloadThenMain()
        startKeyWatchdog()
    else
        openKeyUI()
        startKeyWatchdog()
    end
end

boot()

-- สำหรับ UI Key ของคุณ:
-- เมื่อผู้ใช้ใส่คีย์ถูก ให้ UI Key เรียก:
--   _G.UFO_OnKeyAccepted(theKey, expires_at_from_server)
-- แล้ว UI Key ปิดตัวเอง จากนั้นคุณจะเรียกเปิดหน้า Download ได้ด้วย:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"))()
-- (หรือปล่อยให้ตัวจัดการนี้เป็นคนเปิดให้เองตอน boot รอบถัดไป)
