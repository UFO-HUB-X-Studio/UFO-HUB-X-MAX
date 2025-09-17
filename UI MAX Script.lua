-- UI MAX Script.lua
-- UFO HUB X — Orchestrator (Key -> Download -> Main UI) | v3-solid
-- รองรับ Delta/syn/KRNL/Script-Ware/Fluxus + loadstring(HttpGet)
-- มี watchdog/fallback เพื่อกันกรณี UI ลูกไม่ยิง callback กลับมา

--====================[ Config: RAW URLs ของทั้ง 3 UI ]====================
local URL_KEY     = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DL      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAIN    = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- เวลา fallback (วินาที) ถ้า UI ลูกไม่เรียก callback
local KEY_WATCHDOG_SECS      = 30    -- กรอกคีย์ไม่สำเร็จภายใน… จะยังคงรอ ไม่ Skip (ตั้งค่านี้ยาวไว้)
local DOWNLOAD_WATCHDOG_SECS = 10    -- Download UI ไม่ยิงสัญญาณภายใน… จะบังคับเปิด Main

--====================[ Services + Compat ]====================
local HttpService = game:GetService("HttpService")
local CG          = game:GetService("CoreGui")

local function http_get(url)
    -- พยายามครอบ executor ให้หมด
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

local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

--====================[ Persist state (folder/file) ]====================
local DIR        = "UFOHubX"
local STATE_FILE = DIR .. "/key_state.json"

local function ensureDir()
    if isfolder then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
end
ensureDir()

local function readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data == 0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function writeState(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    if st.permanent == true then return true end
    if st.expires_at and typeof(st.expires_at) == "number" then
        return os.time() < st.expires_at
    end
    return false
end

--====================[ Global callbacks ที่ UI ลูกจะเรียก ]====================
-- อันนี้ Key UI จะเรียกหลังยืนยันคีย์ผ่าน
_G.UFO_SaveKeyState = function(key, expires_at, is_permanent)
    local save = {
        key        = tostring(key or ""),
        expires_at = (expires_at and tonumber(expires_at) or nil),
        permanent  = (is_permanent and true or false),
        saved_at   = os.time(),
    }
    writeState(save)
end

-- ให้ Key UI เรียกเมื่อผ่าน → เปิดหน้า Download
_G.UFO_StartDownload = function()
    -- ป้องกันซ้ำ
    if _G.__UFO_StartedDownload then return end
    _G.__UFO_StartedDownload = true
    task.spawn(function()
        local ok, src = http_get(URL_DL)
        if ok then
            local f = loadstring(src)
            if f then pcall(f) end
        end
        -- ตั้ง watchdog บังคับเดินต่อถ้าไม่มีสัญญาณจบจาก Download UI
        task.delay(DOWNLOAD_WATCHDOG_SECS, function()
            if not _G.__UFO_DownloadDone then
                _G.UFO_DownloadFinished()  -- บังคับจบ
            end
        end)
    end)
end

-- ให้ Download UI เรียกเมื่อเสร็จ → เปิด Main UI
_G.UFO_DownloadFinished = function()
    if _G.__UFO_DownloadDone then return end
    _G.__UFO_DownloadDone = true
    -- เปิด Main UI
    task.spawn(function()
        local ok, src = http_get(URL_MAIN)
        if ok then
            local f = loadstring(src)
            if f then pcall(f) end
        end
    end)
end

-- สำรอง: เผื่อ UI ลูกเรียกชื่ออื่น ให้ alias ไว้
_G.UFO_ShowMain = _G.UFO_DownloadFinished

--====================[ Boot Flow ]====================
local function showKeyUI()
    local ok, src = http_get(URL_KEY)
    if ok then
        local f = loadstring(src)
        if f then pcall(f) end
    end
    -- ไม่ตั้ง watchdog ให้ Key UI บังคับข้าม เพราะต้อง “ผู้ใช้กรอกคีย์” เท่านั้นถึงจะไปต่อ
    -- แต่ใส่ตัวจับเวลายาวไว้กันลืม (ไม่บังคับเดินต่อ)
    task.delay(KEY_WATCHDOG_SECS, function()
        -- no-op (เจตนาให้ผู้ใช้กรอก)
    end)
end

local function showDownloadUI()
    -- เปิด Download UI เหมือนกับตอน Key ผ่าน
    _G.UFO_StartDownload()
end

-- ตัดสินใจว่าจะเริ่มจากหน้าไหน
if isKeyStillValid() then
    -- มีคีย์/ยังไม่หมด → ไปหน้า Download เลย
    showDownloadUI()
else
    -- ไม่มีคีย์/หมดอายุ → แสดง Key UI ก่อน
    showKeyUI()
end
