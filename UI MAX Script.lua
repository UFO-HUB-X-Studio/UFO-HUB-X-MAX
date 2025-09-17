--========================================================
-- UI MAX Script.lua
-- UFO HUB X — Orchestrator (Key → Download → Main UI)
-- รองรับ Delta / Synapse / KRNL / Script-Ware / Fluxus ฯลฯ + loadstring(HttpGet)
-- ฟีเจอร์จัดเต็ม:
--  • เช็คคีย์จาก state ในเครื่อง + หมดเวลา → เรียก Key UI
--  • กรอกคีย์ผ่าน แล้วค่อยไป Download UI → เสร็จค่อยไป Main UI
--  • ป้องกันเปิดซ้ำ/ซ้อน (Guard + Debounce)
--  • FORCE_KEY_UI สำหรับเทสต์บังคับขึ้น Key
--  • Hotkey เคลียร์คีย์ (RightAlt) แล้วรีโหลดสคริปต์
--  • เคลียร์ UI เก่า, ตัวดูแลสถานะ, Watchdog กันโหลดค้าง
--========================================================

-------------------- ถ้ารันซ้ำ ให้ฆ่าของเก่าก่อน --------------------
if getgenv then
    local g = getgenv()
    if g.UFO_KillAll then pcall(g.UFO_KillAll) end
end

-------------------- Services --------------------
local HttpService = game:GetService("HttpService")
local CG          = game:GetService("CoreGui")
local UIS         = game:GetService("UserInputService")
local TS          = game:GetService("TweenService")

-------------------- CONFIG: URL ของ 3 UI --------------------
-- แก้ลิงก์ตรงนี้ถ้าคุณย้ายไฟล์
local URL_KEY  = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DL   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAIN = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua"

-- ถ้าจะบังคับขึ้น Key UI เสมอ (ไว้เทสต์) ให้เป็น true
local FORCE_KEY_UI = false

-- Hotkey เคลียร์คีย์ + รีโหลดสคริปต์ (กด RightAlt)
local ENABLE_CLEAR_HOTKEY = true
local CLEAR_HOTKEY        = Enum.KeyCode.RightAlt

-- เวลากันค้าง (วินาที) — ถ้า Download UI ไม่เรียก callback ภายในเวลานี้ จะรีเทิร์นไปเรียกแสดง Main อยู่ดี
local DOWNLOAD_WATCHDOG_SEC = 30

-------------------- Helper: HTTP GET ครอบ executor ต่าง ๆ --------------------
local function http_get(url)
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

-------------------- Helper: ปลอดภัยเวลา parent GUI --------------------
local function safeParent(gui)
    local ok=false
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if gethui then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then gui.Parent = CG end
end

-------------------- ไฟล์เก็บสถานะ (persist state) --------------------
local DIR        = "UFOHubX"
local STATE_FILE = DIR.."/key_state.json"

local function ensureDir()
    if isfolder and not isfolder(DIR) then pcall(makefolder, DIR) end
end
ensureDir()

local function readState()
    if not (isfile and isfile(STATE_FILE) and readfile) then return nil end
    local ok, s = pcall(readfile, STATE_FILE)
    if not ok or not s or #s==0 then return nil end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(s) end)
    if ok2 then return tbl end
    return nil
end

local function writeState(tbl)
    if not (writefile and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

local function deleteState()
    if isfile and isfile(STATE_FILE) and delfile then pcall(delfile, STATE_FILE) end
end

-------------------- เช็คคีย์ยัง valid ไหม --------------------
local function isKeyStillValid()
    local st = readState()
    if not st or not st.key then return false end
    -- permanent
    if st.permanent == true then return true end
    -- time-based
    if st.expires_at and typeof(st.expires_at) == "number" then
        return (os.time() < st.expires_at)
    end
    return false
end

-------------------- Global Guard & KillAll --------------------
local function destroyIfExists(name)
    local g = CG:FindFirstChild(name)
    if g then pcall(function() g:Destroy() end) end
end

local function killAll()
    destroyIfExists("UFOHubX_KeyUI")
    destroyIfExists("UFOHubX_DownloadUI")
    destroyIfExists("UFOHubX_MainUI")
end

if getgenv then
    local g = getgenv()
    g.UFO_KillAll = killAll
end

-------------------- สถานะในหน่วยความจำ (not persisted) --------------------
local State = {
    key_ok            = false,
    download_finished = false,
    showing_key       = false,
    showing_dl        = false,
    showing_main      = false,
    started_at        = os.clock(),
}

-------------------- Callback ให้ 3 UI เรียกกลับ --------------------
-- บันทึกคีย์ + บอกว่า key ผ่านแล้ว
local function SaveKeyState_cb(key, expires_at, permanent)
    writeState({
        key        = key,
        expires_at = tonumber(expires_at),
        permanent  = (permanent == true)
    })
    State.key_ok = true
end

-- ให้ Key UI เรียกใช้งานเพื่อไปหน้า Download
local function StartDownload_cb()
    if State.showing_dl or State.showing_main then return end
    State.showing_key = false
    killAll()
    -- โหลด Download UI
    local ok, src = http_get(URL_DL)
    if ok then
        local f = loadstring(src)
        if f then
            State.showing_dl = true
            pcall(f)
            -- Watchdog กันดาวน์โหลดค้าง
            task.delay(DOWNLOAD_WATCHDOG_SEC, function()
                if not State.download_finished and State.showing_dl then
                    warn("[UFO-HUB-X] Download watchdog timeout → going to Main UI")
                    State.download_finished = true
                    if getgenv and getgenv().UFO_ShowMain then
                        pcall(getgenv().UFO_ShowMain)
                    elseif _G and _G.UFO_ShowMain then
                        pcall(_G.UFO_ShowMain)
                    end
                end
            end)
        end
    else
        warn("[UFO-HUB-X] cannot fetch Download UI, fallback directly to Main")
        State.download_finished = true
        if getgenv and getgenv().UFO_ShowMain then
            pcall(getgenv().UFO_ShowMain)
        elseif _G and _G.UFO_ShowMain then
            pcall(_G.UFO_ShowMain)
        end
    end
end

-- ให้ Download UI เรียกบอกว่าเสร็จแล้ว (แล้วไป Main)
local function DownloadFinished_cb()
    State.download_finished = true
    State.showing_dl = false
    -- ไปหน้า Main
    if getgenv and getgenv().UFO_ShowMain then
        pcall(getgenv().UFO_ShowMain)
    elseif _G and _G.UFO_ShowMain then
        pcall(_G.UFO_ShowMain)
    end
end

-- แสดง Main UI
local function ShowMain_cb()
    if State.showing_main then return end
    killAll()
    local ok, src = http_get(URL_MAIN)
    if ok then
        local f = loadstring(src)
        if f then
            State.showing_main = true
            pcall(f)
        end
    else
        warn("[UFO-HUB-X] cannot fetch Main UI")
    end
end

-- โยน callback ขึ้น global ให้ 3 UI เรียกใช้ได้ทุก executor
if getgenv then
    local g = getgenv()
    g.UFO_SaveKeyState     = SaveKeyState_cb
    g.UFO_StartDownload    = StartDownload_cb
    g.UFO_DownloadFinished = DownloadFinished_cb
    g.UFO_ShowMain         = ShowMain_cb
else
    _G.UFO_SaveKeyState     = SaveKeyState_cb
    _G.UFO_StartDownload    = StartDownload_cb
    _G.UFO_DownloadFinished = DownloadFinished_cb
    _G.UFO_ShowMain         = ShowMain_cb
end

-------------------- ปุ่มลัดเคลียร์คีย์ + รีโหลดสคริปต์ --------------------
local function reloadSelf()
    local boot = (getgenv and getgenv().UFO_BootURL) or nil
    if boot and #boot > 0 then
        task.delay(0.15, function()
            local ok, src = http_get(boot)
            if ok then
                local f = loadstring(src)
                if f then pcall(f) end
            end
        end)
    else
        warn("[UFO-HUB-X] UFO_BootURL is not set; cannot reload automatically.")
    end
end

local function clearSavedKey()
    deleteState()
    print("[UFO-HUB-X] key cache cleared.")
    reloadSelf()
end

if ENABLE_CLEAR_HOTKEY then
    UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == CLEAR_HOTKEY then
            clearSavedKey()
        end
    end)
end

-------------------- เริ่ม Flow --------------------
local function showKeyUI()
    if State.showing_key then return end
    killAll()
    local ok, src = http_get(URL_KEY)
    if ok then
        local f = loadstring(src)
        if f then
            State.showing_key = true
            pcall(f)
        end
    else
        warn("[UFO-HUB-X] cannot fetch Key UI; fallback → Download")
        StartDownload_cb()
    end
end

local function boot()
    if FORCE_KEY_UI then
        showKeyUI()
        return
    end

    if isKeyStillValid() then
        -- ผ่านแล้ว → ไปโหลดหน้า Download
        StartDownload_cb()
    else
        -- ยังไม่ผ่าน/หมดเวลา → ขึ้น Key
        showKeyUI()
    end
end

boot()
