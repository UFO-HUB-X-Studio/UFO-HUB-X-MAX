--[[
UFO HUB X — KeyOnly Boot
- โชว์เฉพาะ UI คีย์
- คีย์ถูก → ปิด UI แล้วจบ (ไม่เปิดดาวน์โหลด/เมน)
- บันทึกสถานะบนดิสก์; ครั้งต่อไปจะไม่ถามจนกว่าจะหมดอายุ
- ฮอตคีย์ RightAlt = ล้างคีย์+รีโหลด (ตั้ง URL ตัวเองใน getgenv().UFO_BootURL ถ้าจะรีโหลดตัวมัน)
]]

-------------------- Services / Helpers --------------------
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")

local function log(s)
    s = "[UFO-KeyOnly] "..tostring(s)
    if rconsoleprint then rconsoleprint(s.."\n") else print(s) end
end

local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url,Method="GET"}); if ok and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url,Method="GET"}); if ok and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"httpget_failed"
end

local function http_get_retry(urls, tries, delay_s)
    local list = type(urls)=="table" and urls or {urls}
    tries, delay_s = tries or 3, delay_s or 0.75
    local attempt = 0
    for r=1,tries do
        for _,u in ipairs(list) do
            attempt += 1
            log(("HTTP try #%d → %s"):format(attempt,u))
            local ok,body = http_get(u)
            if ok and body then return true,body,u end
        end
        task.wait(delay_s*r)
    end
    return false,"retry_failed"
end

local function safe_loadstring(src, tag)
    local f,e = loadstring(src, tag or "chunk"); if not f then return false,"loadstring: "..tostring(e) end
    local ok,err = pcall(f); if not ok then return false,"pcall: "..tostring(err) end
    return true
end

-------------------- Config --------------------
-- URL ของ “UI คีย์” ของนาย (แก้ได้)
local URL_KEYS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua",
}

-- allow-list (ถ้ามี)
local ALLOW_KEYS = {
    ["JJJMAX"]                = { permanent=true },
    ["GMPANUPHONGARTPHAIRIN"] = { permanent=true },
}

-- อายุคีย์เริ่มต้น (ถ้าเซิร์ฟเวอร์ไม่ได้ส่งมา)
local DEFAULT_TTL = 48*3600  -- 48 ชั่วโมง

-- ฮอตคีย์ล้างคีย์ (ตั้งค่า URL โหลดตัวเอง ถ้าจะรีโหลด)
local CLEAR_KEY_HOTKEY = true
local HOTKEY           = Enum.KeyCode.RightAlt
-- ตัวอย่าง: getgenv().UFO_BootURL = "https://raw.githubusercontent.com/<you>/<repo>/main/KeyOnly.lua"

-------------------- Key State (ไฟล์) --------------------
local DIR  = "UFOHubX"
local PATH = DIR.."/key_state.json"

local function ensureDir() if isfolder and not isfolder(DIR) then pcall(makefolder,DIR) end end
ensureDir()

local function readState()
    if not (isfile and readfile and isfile(PATH)) then return nil end
    local ok,raw = pcall(readfile,PATH); if not ok or not raw or #raw==0 then return nil end
    local ok2,st = pcall(function() return HttpService:JSONDecode(raw) end)
    return ok2 and st or nil
end

local function writeState(tbl)
    if not (writefile and tbl) then return end
    local ok,json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile,PATH,json) end
end

local function delState() if isfile and isfile(PATH) and delfile then pcall(delfile,PATH) end end

local function isValid(st)
    if not st or not st.key then return false end
    if st.permanent then return true end
    if st.expires_at and os.time() < st.expires_at then return true end
    return false
end

-------------------- Global callback (ให้อ่านจาก UI คีย์) --------------------
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    -- ถ้าเซิร์ฟเวอร์ไม่ได้ส่ง expires_at ก็ใส่ TTL เริ่มต้น
    if not permanent then
        expires_at = tonumber(expires_at) or (os.time() + DEFAULT_TTL)
    else
        expires_at = nil
    end
    log(("SaveKeyState: key=%s exp=%s perm=%s"):format(tostring(key), tostring(expires_at), tostring(permanent)))
    writeState({ key = key, expires_at = expires_at, permanent = permanent and true or false, saved_at = os.time() })
    _G.UFO_HUBX_KEY_OK = true
end

-------------------- ฮอตคีย์ล้างคีย์ --------------------
if CLEAR_KEY_HOTKEY then
    UIS.InputBegan:Connect(function(i,gpe)
        if gpe then return end
        if i.KeyCode == HOTKEY then
            log("Hotkey: clear key state")
            delState()
            local boot = getgenv and getgenv().UFO_BootURL
            if boot and #boot>0 then
                task.delay(0.1,function()
                    local ok,src = http_get(boot); if ok then local f=loadstring(src); if f then pcall(f) end end
                end)
            end
        end
    end)
end

-------------------- Boot: แสดง UI คีย์เฉพาะเมื่อ “ยังไม่มีคีย์” หรือ “คีย์หมดอายุ” --------------------
local cur = readState()
if isValid(cur) then
    log("Key is valid → skip Key UI, do nothing.")
    return
end

log("No/expired key → show Key UI")
local ok, src = http_get_retry(URL_KEYS, 5, 0.8)
if not ok then
    log("Key UI fetch failed; cannot continue.")
    return
end

-- ปะช์ให้ออกจาก UI อย่างเดียวเมื่อคีย์ผ่าน (ไม่เรียกดาวน์โหลด/เมนอื่น ๆ)
do
    local patched = src
    local injected = 0
    patched, injected = patched:gsub(
        "gui:Destroy%(%);?",
        [[
-- ก่อนปิด UI ไม่ต้องทำอะไรต่อ แค่ทำลาย UI
gui:Destroy();
]]
    )
    if injected == 0 then
        patched, injected = patched:gsub(
            'btnSubmit.Text%s*=%s*"✅ Key accepted"',
            [[btnSubmit.Text = "✅ Key accepted"
]]
        )
    end
    src = patched
end

local ok2, err = safe_loadstring(src, "UFO-KeyUI")
if not ok2 then
    log("Run Key UI failed: "..tostring(err))
end
