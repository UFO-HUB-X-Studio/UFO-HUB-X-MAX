--========================================================
-- UFO HUB X — BOOT (One-file Orchestrator)
-- - ลำดับ: KEY → DOWNLOAD → MAIN
-- - กันซ้อน, มีตัวรอสถานะ + fallback
-- - รองรับ Delta / loadstring(game:HttpGet(...))
--========================================================

if _G.__UFO_BOOT_RUNNING then return end
_G.__UFO_BOOT_RUNNING = true

-------------------- URLs (แก้ได้ตาม repo ของคุณ) --------------------
local URL_KEY  = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua"
local URL_DL   = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua"
local URL_MAIN = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20Main.lua" -- เปลี่ยนเป็นไฟล์หลักจริงของคุณ

-------------------- Services --------------------
local CG  = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-------------------- Helpers --------------------
local function httpget(u)
    -- รองรับ executor ส่วนใหญ่
    local ok, body = pcall(function() return game:HttpGet(u) end)
    if ok and body then return body end
    error("HttpGet failed: "..tostring(u))
end

local function safe_load(url)
    local src = httpget(url)
    local f, err = loadstring(src)
    if not f then error("loadstring error: "..tostring(err)) end
    local ok, res = pcall(f)
    if not ok then error("exec error: "..tostring(res)) end
    return res
end

local function kill_gui(name)
    pcall(function() local o = CG:FindFirstChild(name); if o then o:Destroy() end end)
end

local function wait_until(fn, timeout)
    local t0 = os.clock()
    while true do
        local ok, yes = pcall(fn)
        if ok and yes then return true end
        if (os.clock() - t0) > (timeout or 30) then return false end
        task.wait(0.1)
    end
end

-------------------- Guards กันซ้อนทุกตัว --------------------
_G.UFO_KEY_UI_MOUNTED = false
_G.UFO_DL_UI_MOUNTED  = false
_G.UFO_MAIN_UI_MOUNTED= false

-------------------- Flow --------------------
local function run_key_ui()
    -- กันซ้อนหน้าคีย์
    kill_gui("UFOHubX_KeyUI")
    _G.UFO_HUBX_KEY_OK = false
    -- โหลด Key UI
    safe_load(URL_KEY)
    -- รอผลคีย์ (UI ของคุณจะ set: _G.UFO_HUBX_KEY_OK = true เมื่อสำเร็จ)
    local ok = wait_until(function() return _G.UFO_HUBX_KEY_OK == true end, 300) -- เผื่อไว้ 5 นาที
    -- ปิดหน้าคีย์ถ้ายังค้าง
    kill_gui("UFOHubX_KeyUI")
    return ok
end

local function run_download_ui()
    -- กันซ้อนหน้า DL
    kill_gui("UFOHubX_Download")
    _G.UFO_DOWNLOAD_DONE = false
    -- โหลด Download UI
    safe_load(URL_DL)
    -- วิธีรอจบ: 1) ถ้าสคริปต์ DL เซ็ต _G.UFO_DOWNLOAD_DONE = true
    --          2) หรือ GUI ชื่อ "UFOHubX_Download" ถูกทำลายไปเอง
    local ok = wait_until(function()
        if _G.UFO_DOWNLOAD_DONE == true then return true end
        local alive = CG:FindFirstChild("UFOHubX_Download") ~= nil
        return (not alive)
    end, 60) -- ปกติ DL ของคุณ 10 วิ; ให้เวลา 60 วิเผื่อเน็ต
    -- ปิด DL ถ้ายังค้าง
    kill_gui("UFOHubX_Download")
    return ok
end

local function run_main_ui()
    -- กันซ้อนหน้า Main
    kill_gui("UFOHubX_Main")
    -- โหลด Main UI
    safe_load(URL_MAIN)
end

-------------------- Orchestrate --------------------
local okKey = run_key_ui()
if not okKey then
    warn("[UFO BOOT] Key stage timed out/failed.")
    return
end

local okDL = run_download_ui()
if not okDL then
    warn("[UFO BOOT] Download stage timed out/failed, continuing to Main anyway.")
end

run_main_ui()

-- จบงาน
_G.__UFO_BOOT_RUNNING = false
