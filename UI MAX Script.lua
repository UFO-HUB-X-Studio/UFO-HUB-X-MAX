-- UI MAX Script.lua
-- UFO HUB X — Orchestrator (Key → Download → Main UI)
-- แข็งแรง: รองรับ syn/http/KRNL/Delta + loadstring(HttpGet), กันชนกัน, กันซ้ำ, Timeout/Retry, Persist key, Bypass เมื่อ key ยังไม่หมดอายุ

-- =========================================================
--                   CONFIG (แก้ได้)
-- =========================================================
local URL_KEY      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- เวลารอให้หน้า Download แจ้ง “เสร็จ” ก่อนจะเปิด Main UI (กันโหลดไวเกิน)
local DOWNLOAD_HANDOFF_DELAY   = 0.50  -- วินาที
-- ถ้า Download UI ไม่ส่งสัญญาณภายในเวลานี้ ให้เตือนและรอเพิ่ม (ไม่เปิด Main UI เอง)
local DOWNLOAD_CALLBACK_TIMEOUT = 30.0  -- วินาที

-- Path เก็บสถานะ key
local DIR         = "UFOHubX"
local STATE_FILE  = DIR.."/key_state.json"

-- Allow-list (ซิงก์กับสคริปต์ Key UI)
local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent=true, reusable=true, expires_at=nil },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true, reusable=true, expires_at=nil },
}

-- =========================================================
--              EXECUTOR/HTTP + FS COMPAT WRAPPERS
-- =========================================================
local HttpService = game:GetService("HttpService")

local function http_get(url)
    -- รองรับทุก executor เท่าที่เป็นไปได้
    if http and http.request then
        local ok, res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true, (res.Body or res.body) end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true, body end
    return false, "httpget_failed"
end

local function fs_ensure_dir()
    if isfolder then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
end
local function fs_read_state()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data == 0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end
local function fs_write_state(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

-- =========================================================
--                GLOBAL NAMESPACE / CALLBACKS
-- =========================================================
local G = (getgenv and getgenv()) or _G
G = G or _G             -- เผื่อบาง executor
getfenv = getfenv or function() return _G end

-- ตัวล็อกกันซ้ำ/ชนกัน
local flags = {
    key_ok            = false,
    key_permanent     = false,
    key_expires_at    = nil,

    key_ui_open       = false,
    download_ui_open  = false,
    main_ui_open      = false,

    download_done     = false,
}

-- save state (เรียกจาก Key UI)
G.UFO_SaveKeyState = function(key, expires_at, permanent)
    -- บันทึกไฟล์สถานะ key
    fs_ensure_dir()
    local st = {
        key       = key,
        permanent = permanent and true or false,
        expires_at= tonumber(expires_at)
    }
    fs_write_state(st)

    -- อัปเดตแฟล็กใน orchestrator
    flags.key_ok         = true
    flags.key_permanent  = st.permanent
    flags.key_expires_at = st.expires_at
end

-- เริ่มหน้า Download (เรียกจาก Key UI เมื่อผ่าน)
G.UFO_StartDownload = function()
    if flags.download_ui_open or flags.download_done then return end
    -- ปิด Key UI เป็นหน้าที่ของ Key UI เองอยู่แล้ว
    task.spawn(function()
        local ok, src = http_get(URL_DOWNLOAD .. ("?v="..tostring(os.time())))
        if not ok then
            warn("[UFO-HUB-X] fail to fetch Download UI:", src)
            return
        end
        flags.download_ui_open = true
        local f, err = loadstring(src)
        if not f then
            flags.download_ui_open = false
            warn("[UFO-HUB-X] Download UI loadstring error:", err)
            return
        end
        local suc, runerr = pcall(f)
        if not suc then
            flags.download_ui_open = false
            warn("[UFO-HUB-X] Download UI runtime error:", runerr)
        end
    end)
end

-- ให้ Download UI แจ้ง “พร้อมส่งต่อไป Main” ผ่านฟังก์ชันนี้
G.UFO_DownloadFinished = function()
    flags.download_done = true
end

-- เรียกให้เปิด Main UI (จะถูกเรียก “หลัง” Download เสร็จ เท่านั้น)
G.UFO_ShowMain = function()
    -- กันเรียกซ้ำ
    if flags.main_ui_open then return end

    -- ใส่ handoff delay เล็กน้อย กันกระพริบ/ชน
    task.delay(DOWNLOAD_HANDOFF_DELAY, function()
        if flags.main_ui_open then return end
        local ok, src = http_get(URL_MAINUI .. ("?v="..tostring(os.time())))
        if not ok then
            warn("[UFO-HUB-X] fail to fetch MAIN UI:", src)
            return
        end
        flags.main_ui_open = true
        local f, err = loadstring(src)
        if not f then
            flags.main_ui_open = false
            warn("[UFO-HUB-X] Main UI loadstring error:", err)
            return
        end
        local suc, runerr = pcall(f)
        if not suc then
            flags.main_ui_open = false
            warn("[UFO-HUB-X] Main UI runtime error:", runerr)
        end
    end)
end

-- =========================================================
--                     KEY VALIDITY CHECK
-- =========================================================
local function allow_key_valid_from_state()
    local st = fs_read_state()
    if not st or not st.key then return false end
    -- allow-list แบบ permanent
    if ALLOW_KEYS[normKey(st.key)] then
        return true
    end
    -- permanent ที่บันทึกไว้
    if st.permanent == true then return true end
    -- แบบมีอายุ
    if st.expires_at and type(st.expires_at) == "number" then
        if os.time() < st.expires_at then
            return true
        end
    end
    return false
end

-- =========================================================
--                     LAUNCH SEQUENCE
-- =========================================================
local function launch_key_ui()
    if flags.key_ui_open then return end
    task.spawn(function()
        local ok, src = http_get(URL_KEY .. ("?v="..tostring(os.time())))
        if not ok then
            warn("[UFO-HUB-X] fail to fetch KEY UI:", src)
            return
        end
        flags.key_ui_open = true
        local f, err = loadstring(src)
        if not f then
            flags.key_ui_open = false
            warn("[UFO-HUB-X] KEY UI loadstring error:", err)
            return
        end
        local suc, runerr = pcall(f)
        if not suc then
            flags.key_ui_open = false
            warn("[UFO-HUB-X] KEY UI runtime error:", runerr)
        end
    end)
end

local function launch_download_then_main()
    -- เปิด Download UI
    G.UFO_StartDownload()

    -- รอให้ Download UI ส่งสัญญาณ “เสร็จ” (หรือให้ตัวหน้า Download เรียก UFO_ShowMain เอง)
    -- ใช้ timeout เพื่อจับเคสค้าง แต่ **จะไม่** เปิด Main เองจนกว่า Download จะเรียก UFO_ShowMain
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < DOWNLOAD_CALLBACK_TIMEOUT do
            if flags.download_done then
                -- ปกติหน้า Download จะเรียก UFO_ShowMain แล้ว
                return
            end
            task.wait(0.25)
        end
        -- หมดเวลา → แค่เตือนใน console (ยังคงรอให้หน้า Download เรียก UFO_ShowMain)
        warn("[UFO-HUB-X] Download UI callback timeout (no UFO_ShowMain called). Waiting silently…")
    end)
end

-- =========================================================
--                    ENTRY / MAIN LOGIC
-- =========================================================
fs_ensure_dir()

local already_valid = allow_key_valid_from_state()

if already_valid then
    -- ข้าม Key UI → ไป Download → แล้วค่อยเข้าสู่ Main
    flags.key_ok = true
    launch_download_then_main()
else
    -- ยังไม่ผ่าน → เปิด Key UI ก่อน
    launch_key_ui()
end

-- ป้องกัน executor บางตัวจบเร็ว ปล่อยให้ thread นี้คงอยู่สักพัก (ไม่จำเป็นมาก แต่ช่วยบางเคส)
task.spawn(function()
    while true do
        task.wait(10)
    end
end)
