--[[
UI MAX Script.lua
UFO HUB X — Boot Loader (Key → Download → Main)
Version: v2.1 “Orchestra+”
Author: UFO-HUB-X Studio (assembled)

คุณสมบัติเด่น (ตามที่ขอ):
- รองรับ 100%: loadstring(game:HttpGet(...)), Delta/syn/KRNL/Fluxus/Script-Ware/ฯลฯ
- โหลด 3 UI ตามลำดับ: Key → Download → Main (ขึ้นตามเงื่อนไขเวลา/สถานะคีย์)
- จำสถานะคีย์ไว้ในเครื่อง (ถาวร/นับเวลา) → ถ้ายังไม่หมดอายุ ข้ามหน้า Key อัตโนมัติ
- หน้า Key ปิดตัวเองเมื่อผ่าน → เปิดหน้า Download → Download จบ → เปิด Main UI
- ระบบคอลแบ็กสองทาง (_G.*) ให้ UI ภายนอกเรียกเพื่อเดิน flow ต่อ
- มี fallback/timeout/retry และป้องกัน “โหลดซ้ำ/ซ้อน”
- ไม่แตะ/ไม่ลบของเก่าที่ UI แยกไว้ (เพิ่มความทนทาน+สื่อสารกันได้)
- โค้ดใส่คอมเมนต์ละเอียด ใช้งาน/ต่อยอดง่าย
]]--

--=========================[ CONFIG (แก้ได้) ]===========================
local URL_KEY      = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DOWNLOAD = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAINUI   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- โฟลเดอร์/ไฟล์เก็บสถานะคีย์ในเครื่อง
local DIR         = "UFOHubX"
local STATE_FILE  = DIR.."/key_state.json"

-- เวลารอ fallback/callback ต่าง ๆ
local TIMEOUT_KEY_TO_DOWNLOAD   = 120   -- Key ผ่านแล้ว รอไม่เกินนี้เพื่อเข้า Download (กันเงียบ)
local TIMEOUT_DOWNLOAD_TO_MAIN  = 2     -- ถ้าดาวน์โหลดไม่เรียกต่อ main ภายในเวลานี้ เราจะไปเอง
local HTTP_RETRY                = 3     -- ดึงสคริปต์เผื่อหลุดเน็ต

-- พิมพ์ log ลง console (true/false)
local VERBOSE_LOG = true

--=========================[ Services ]===========================
local HttpService  = game:GetService("HttpService")
local CG           = game:GetService("CoreGui")

--=========================[ Logger ]===========================
local function log(...)
    if VERBOSE_LOG then
        print("[UFO-HUB-X][BOOT]", ...)
    end
end
local function warnlog(...)
    warn("[UFO-HUB-X][BOOT][WARN]", ...)
end

--=========================[ HTTP Wrapper ]===========================
local function http_request_compat(url)
    -- ครอบ executor ให้ครบสาย
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

local function http_get(url, retries)
    retries = tonumber(retries or HTTP_RETRY) or 1
    for i = 1, math.max(1, retries) do
        local ok, body = http_request_compat(url)
        if ok and body and #tostring(body) > 0 then
            log("GET ok", url, "(try "..i..")")
            return true, body
        end
        warnlog("GET fail", url, "(try "..i..")")
        task.wait(0.35 + (i * 0.15))
    end
    return false, "GET failed after "..retries.." tries"
end

--=========================[ FS: persist key state ]===========================
local function ensureDir()
    if isfolder and makefolder then
        if not isfolder(DIR) then
            local ok,err = pcall(makefolder, DIR)
            if ok then log("Created dir:", DIR) else warnlog("makefolder error:", tostring(err)) end
        end
    else
        warnlog("filesystem APIs unavailable (isfolder/makefolder)")
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
    if not (writefile and HttpService and tbl) then
        warnlog("writeState skipped: writefile/HttpService unavailable?")
        return
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then
        local w, err = pcall(writefile, STATE_FILE, json)
        if w then log("State saved") else warnlog("writefile error:", tostring(err)) end
    else
        warnlog("JSONEncode state error")
    end
end

-- ให้ผู้ใช้สั่ง “รีเซ็ตคีย์” ได้ (เรียกในคอนโซล _G.UFO_ResetKey())
_G.UFO_ResetKey = function()
    local s = { key=nil, expires_at=nil, permanent=false }
    writeState(s)
    log("Key state reset.")
end

--=========================[ Key validity check ]===========================
local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    if st.permanent == true then
        log("Permanent key found → valid")
        return true
    end
    if st.expires_at and typeof(st.expires_at) == "number" then
        local left = st.expires_at - os.time()
        if left > 0 then
            log(("Timed key valid (left %ds)"):format(left))
            return true
        else
            log("Timed key expired.")
            return false
        end
    end
    log("State found but not permanent/timed → invalid")
    return false
end

--=========================[ Anti-duplicate instance ]===========================
-- ป้องกันวางซ้ำแล้วบูตซ้อน (ถ้ามีตัวเก่าอยู่)
if _G.__UFO_BOOT_RUNNING then
    warnlog("Another boot instance is running; exiting this instance.")
    return
end
_G.__UFO_BOOT_RUNNING = true

--=========================[ Cross-file callbacks (ให้ UI ทั้งสามเรียก) ]===========================
-- 1) Key UI เรียกตอน “คีย์ผ่าน” → บันทึกสถานะ
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    local s = readState() or {}
    s.key = tostring(key or "")
    s.expires_at = (typeof(expires_at)=="number" and expires_at) or nil
    s.permanent  = (permanent == true)
    writeState(s)
    log("UFO_SaveKeyState:", s.key and #s.key or 0, "expires_at=", s.expires_at, "permanent=", s.permanent)
end

-- 2) Key UI บอกให้ “ไปหน้า Download”
_G.UFO_StartDownload = function()
    log("Signal: StartDownload")
    task.spawn(function()
        local ok, src = http_get(URL_DOWNLOAD, HTTP_RETRY)
        if ok then
            local f, err = loadstring(src)
            if f then
                local okrun, perr = pcall(f)
                if not okrun then warnlog("Download UI runtime error:", tostring(perr)) end
            else
                warnlog("Download UI loadstring error:", tostring(err))
            end
        else
            warnlog("Download UI http_get failed; going to Main as fallback after delay")
        end
        -- เผื่อไฟล์ Download ไม่เรียกต่อ → เราจะแชร์ไป Main เองหลัง 2s
        task.delay(TIMEOUT_DOWNLOAD_TO_MAIN, function()
            if not _G.__UFO_MAIN_SHOWN then
                if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
            end
        end)
    end)
end

-- 3) Download UI เรียกให้ “แสดงหน้า UI หลัก”
_G.UFO_ShowMain = function()
    if _G.__UFO_MAIN_SHOWN then
        log("Main UI already shown; ignore duplicate.")
        return
    end
    _G.__UFO_MAIN_SHOWN = true
    log("Signal: ShowMain")
    task.spawn(function()
        local ok, src = http_get(URL_MAINUI, HTTP_RETRY)
        if ok then
            local f, err = loadstring(src)
            if f then
                local okrun, perr = pcall(f)
                if not okrun then warnlog("Main UI runtime error:", tostring(perr)) end
            else
                warnlog("Main UI loadstring error:", tostring(err))
            end
        else
            warnlog("Main UI http_get failed; nothing more we can do")
        end
    end)
end

--=========================[ Orchestration Helpers ]===========================
local function showKeyUI()
    log("Showing Key UI...")
    local ok, src = http_get(URL_KEY, HTTP_RETRY)
    if not ok then
        warnlog("Key UI http_get failed → cannot continue")
        return
    end
    local f, err = loadstring(src)
    if not f then
        warnlog("Key UI loadstring failed:", tostring(err))
        return
    end
    local okrun, perr = pcall(f)
    if not okrun then
        warnlog("Key UI runtime error:", tostring(perr))
        return
    end

    -- Fallback เผื่อไฟล์ Key UI ใช้ _G.UFO_HUBX_KEY_OK แทน callback
    -- เราจะคอยดู flag นี้ถ้าถูก set จะบันทึกสถานะและไหลไป Download เอง
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < TIMEOUT_KEY_TO_DOWNLOAD do
            if _G.UFO_HUBX_KEY_OK then
                -- เผื่อ UI Key ตั้งค่าเสริมไว้
                local exp = nil
                if _G.UFO_HUBX_EXPIRES_AT and typeof(_G.UFO_HUBX_EXPIRES_AT)=="number" then
                    exp = _G.UFO_HUBX_EXPIRES_AT
                end
                local perm = (_G.UFO_HUBX_KEY_PERMANENT == true)
                _G.UFO_SaveKeyState(_G.UFO_HUBX_KEY or "", exp, perm)
                -- ไปหน้า Download (ใช้ callback ปกติ)
                if _G and _G.UFO_StartDownload then _G.UFO_StartDownload() end
                break
            end
            task.wait(0.1)
        end
    end)
end

local function goDownloadNow()
    -- ใช้ callback ถ้ามี
    if _G and _G.UFO_StartDownload then
        _G.UFO_StartDownload()
        return
    end
    -- ถ้าไม่มี callback → โหลดตรง ๆ
    log("Download via direct path (no callback)")
    local ok, src = http_get(URL_DOWNLOAD, HTTP_RETRY)
    if ok then
        local f, err = loadstring(src)
        if f then
            local okrun, perr = pcall(f)
            if not okrun then warnlog("Download UI runtime error:", tostring(perr)) end
        else
            warnlog("Download UI loadstring error:", tostring(err))
        end
    else
        warnlog("Download UI http_get failed (direct). Fallback to main after delay.")
    end
    task.delay(TIMEOUT_DOWNLOAD_TO_MAIN, function()
        if not _G.__UFO_MAIN_SHOWN then
            if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        end
    end)
end

--=========================[ ENTRY POINT ]===========================
do
    log("=== UFO HUB X Boot Start ===")
    log("Executor:",
        (identifyexecutor and pcall(identifyexecutor)) and (select(2, pcall(identifyexecutor)) or "unknown") or "unknown")
    log("Key state file:", STATE_FILE)

    if isKeyStillValid() then
        -- ถ้ายัง valid: ข้าม Key → ไปหน้า Download เลย
        log("Key valid → skip Key UI → Download")
        goDownloadNow()
    else
        -- ไม่มีคีย์/หมดอายุ → แสดง Key UI ก่อน
        log("No/expired key → show Key UI")
        showKeyUI()
    end

    -- Safety guard: ถ้า Key/Download ไม่เดิน flow ไป Main เองเลยสักที
    -- เราไม่ force เปิด Main โดยตรงที่นี่ เพราะเงื่อนไขของคุณคือ:
    --   Key → (ผ่าน) → Download → (จบ) → Main เท่านั้น
    -- ดังนั้น fallback ทั้งหมดอยู่ใน callback ของแต่ละเฟสแล้ว
    log("=== UFO HUB X Boot Ready ===")
end

--=========================[ OPTIONAL UTILS ]===========================
-- ผู้ใช้เรียกดูสถานะคีย์ในคอนโซล: _G.UFO_PrintKeyState()
_G.UFO_PrintKeyState = function()
    local st = readState()
    print("[UFO-HUB-X] KeyState =", st and HttpService:JSONEncode(st) or "nil")
end

-- ผู้ใช้บังคับกระโดดไป Download (ทดสอบ): _G.UFO_StartDownload()
-- ผู้ใช้บังคับกระโดดไป Main (ทดสอบ): _G.UFO_ShowMain()

-- จบไฟล์
