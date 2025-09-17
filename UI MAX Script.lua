-- UI MAX Script.lua
-- UFO HUB X — Boot Loader (Key → Download → Main UI)
-- รองรับ Delta / syn / KRNL / Script-Ware / Fluxus ฯลฯ + loadstring(HttpGet)
-- โฟลว์: ถ้า key ถาวร/ยังไม่หมดเวลา => ข้าม Key → ไป Download → แล้วค่อย Main
-- ถ้า key หมดเวลา => เปิด Key ก่อนเสมอ

--========================================================
-- Services + Compat
--========================================================
local HttpService = game:GetService("HttpService")

-- สั้น กระชับสำหรับ console
local function log(s)
    if rconsoleprint then
        rconsoleprint("[UFO-HUB-X] "..tostring(s).."\n")
    else
        print("[UFO-HUB-X] "..tostring(s))
    end
end

local function http_get(url)
    -- ครอบ executor ทั้งหมด
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

local function http_get_retry(url, tries, delay_s)
    tries = tries or 3
    delay_s = delay_s or 0.75
    for i=1, tries do
        local ok, body = http_get(url)
        if ok and body then return true, body end
        task.wait(delay_s)
    end
    return false, "retry_failed"
end

local function safe_loadstring(src)
    local f, e = loadstring(src)
    if not f then return false, e end
    local ok, err = pcall(f)
    if not ok then return false, err end
    return true
end

--========================================================
-- Filesystem (persist key state) — ใช้ได้ถ้ามี isfolder/readfile/writefile
--========================================================
local DIR        = "UFOHubX"
local STATE_FILE = DIR.."/key_state.json"

local function ensureDir()
    if isfolder then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
end
ensureDir()

local function readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function writeState(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

--========================================================
-- Config + Normalize Key
--========================================================
local URL_KEY      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- allow-list พิเศษ (เพิ่มได้เรื่อย ๆ) — จะผ่านตลอดและถือเป็น permanent
local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent=true,  reusable=true, expires_at=nil },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true,  reusable=true, expires_at=nil },
}

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

--========================================================
-- Key state helpers
--========================================================
local function isKeyStillValid(state)
    if not state or not state.key then return false end
    if state.permanent == true then return true end
    if state.expires_at and typeof(state.expires_at)=="number" then
        if os.time() < state.expires_at then return true end
    end
    return false
end

local function saveKeyState(key, expires_at, permanent)
    local st = {
        key       = key,
        permanent = (permanent and true or false),
        expires_at= expires_at or nil,
        saved_at  = os.time(),
    }
    writeState(st)
end

--========================================================
-- Global callbacks (ให้ Key/Download/Main UI เรียก)
--========================================================
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    log(("SaveKeyState: key=%s, exp=%s, perm=%s"):format(tostring(key), tostring(expires_at), tostring(permanent)))
    saveKeyState(key, expires_at, permanent)
    -- set flag เผื่อ watcher
    _G.UFO_HUBX_KEY_OK   = true
    _G.UFO_HUBX_KEY      = key
    _G.UFO_HUBX_KEY_EXP  = expires_at
    _G.UFO_HUBX_KEY_PERM = permanent and true or false
end

-- สั่งไปหน้า Download ต่อ (Key UI จะเรียกอันนี้ทันทีหลังผ่านคีย์)
_G.UFO_StartDownload = function()
    if _G.__UFO_Download_Started then return end
    _G.__UFO_Download_Started = true
    log("Start Download UI (by signal)")
    local ok, src = http_get_retry(URL_DOWNLOAD, 3, 0.6)
    if not ok then
        log("Download UI fetch failed (retry). Forcing main UI as fallback.")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
    local ok2, err = safe_loadstring(src)
    if not ok2 then
        log("Download UI run failed: "..tostring(err))
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
end

-- สั่งไปหน้า Main UI (หลังดาวน์โหลด/เตรียมระบบเสร็จ)
_G.UFO_ShowMain = function()
    if _G.__UFO_Main_Started then return end
    _G.__UFO_Main_Started = true
    log("Show Main UI")
    local ok, src = http_get_retry(URL_MAINUI, 3, 0.6)
    if not ok then
        log("Main UI fetch failed.")
        return
    end
    local ok2, err = safe_loadstring(src)
    if not ok2 then
        log("Main UI run failed: "..tostring(err))
        return
    end
end

--========================================================
-- Watchers (Fallback/Fail-safe)
--========================================================
-- ถ้า Key UI ไม่ยิงสัญญาณ แต่ตั้ง _G.UFO_HUBX_KEY_OK เราจะจับและไป Download เอง
local function startKeyWatcher(timeout_sec)
    timeout_sec = timeout_sec or 120
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < timeout_sec do
            if _G and _G.UFO_HUBX_KEY_OK then
                log("Watcher: Detected KEY_OK flag → go Download")
                if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
                return
            end
            task.wait(0.2)
        end
        log("Watcher: Key timeout — no KEY_OK, staying in key stage (user idle?)")
    end)
end

-- ถ้า Download UI ไม่เรียกไป Main ภายในเวลาที่กำหนด จะบังคับไป Main
local function startDownloadWatcher(timeout_sec)
    timeout_sec = timeout_sec or 90
    task.spawn(function()
        local t0 = os.clock()
        while (os.clock() - t0) < timeout_sec do
            if _G and _G.__UFO_Main_Started then
                return
            end
            task.wait(0.5)
        end
        log("Watcher: Download timeout — forcing Main UI")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
    end)
end

--========================================================
-- Boot Flow
--========================================================
local curState = readState()
local valid = isKeyStillValid(curState)

if valid then
    -- ข้าม Key UI → ไป Download เลย
    log("Key state valid → skip Key UI, go Download")
    -- ตั้ง flag ไว้เผื่อระบบอื่นอยากใช้
    _G.UFO_HUBX_KEY_OK   = true
    _G.UFO_HUBX_KEY      = curState.key
    _G.UFO_HUBX_KEY_EXP  = curState.expires_at
    _G.UFO_HUBX_KEY_PERM = curState.permanent and true or false

    -- โหลด Download UI + watcher กันเงียบ
    startDownloadWatcher(90)
    local ok, src = http_get_retry(URL_DOWNLOAD, 3, 0.6)
    if not ok then
        log("Download UI fetch failed in skip-key path. Forcing Main UI.")
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end
    local ok2, err = safe_loadstring(src)
    if not ok2 then
        log("Download UI run failed: "..tostring(err))
        if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        return
    end

else
    -- ต้องแสดง Key UI ก่อน
    log("No valid key → show Key UI first")
    -- Watcher: ถ้าคีย์ผ่านแต่ Key UI ไม่ยิงสัญญาณ เราจะจับ flag แล้วไป Download ให้เอง
    startKeyWatcher(120)

    local ok, src = http_get_retry(URL_KEY, 3, 0.6)
    if not ok then
        log("Key UI fetch failed (cannot continue without key UI)")
        return
    end

    -- ✨ เสริมความชัวร์: ถ้า key UI เดิมไม่ได้ยิง _G.UFO_StartDownload ตอนผ่าน ให้ “แพตช์” โค้ดเบา ๆ
    -- เฉพาะกรณีเจอคำว่า successAndClose หรือจุดที่ destroy GUI — เราจะแทรกเรียก _G.UFO_StartDownload()
    do
        local patched = src
        local injected = false

        -- แพตช์แบบเบา: ถ้าไฟล์มีฟังก์ชัน successAndClose(...) ให้เติมสัญญาณก่อน gui:Destroy()
        patched, injected = patched:gsub(
            "gui:Destroy%(%);?",
            [[
if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
gui:Destroy();
]]
        )

        -- ถ้าไม่เจอ pattern ข้างบนเลย ลองแพตช์หลังข้อความ "✅ Key accepted"
        if injected == 0 then
            patched, injected = patched:gsub(
                'btnSubmit.Text%s*=%s*"✅ Key accepted"',
                [[btnSubmit.Text = "✅ Key accepted"
if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
]]
            )
        end

        if injected > 0 then
            log("Patched Key UI to always call UFO_StartDownload() on success.")
            src = patched
        else
            log("No patch point found in Key UI (it's fine if it already calls UFO_StartDownload).")
        end
    end

    local ok2, err = safe_loadstring(src)
    if not ok2 then
        log("Key UI run failed: "..tostring(err))
        return
    end
end

--========================================================
-- สรุป: 
-- - ถ้า key valid → ไป Download ทันที + watchdog → Main
-- - ถ้า key ไม่ valid → แสดง Key UI 
--   * เมื่อผ่านคีย์: Key UI จะยิง UFO_StartDownload() (เราแพตช์บังคับด้วย)
--   * ถ้าไม่ยิง: watcher จับ _G.UFO_HUBX_KEY_OK แล้วไป Download ให้เอง
-- - Download ถ้านานเกิน → watcher บังคับไป Main
--========================================================
