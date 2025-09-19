-- One-click Diagnostic & Quick-UI-Opener for UFO-HUB-X
-- วางเป็น LocalScript ใน StarterPlayerScripts แล้ว Play -> ดู Output window
local HttpService = game:GetService("HttpService")
local RunService  = game:GetService("RunService")

local function out(fmt, ...) 
    local s = (fmt):format(...)
    print("[UFO-DIAG] "..s)
end

local function safeCall(f, ...)
    local ok, res = pcall(f, ...)
    return ok, res
end

-- รายการเช็คที่สำคัญ
out("Starting diagnostic...")

-- 1) ตรวจสอบ global ฟังก์ชัน/ตัวแปรที่ระบบต้องการ
local globals = {
    "UFO_SaveKeyState", "UFO_StartDownload", "UFO_ShowMain",
    "__UFO_Download_Started", "__UFO_Main_Started", "UFO_HUBX_KEY_OK",
    "UFO_HUBX_KEY", "UFO_HUBX_KEY_EXP", "UFO_HUBX_KEY_PERM"
}
for _, name in ipairs(globals) do
    local exists = (type(_G[name]) ~= "nil")
    out("global %-24s : %s", name, exists and tostring(type(_G[name])) or "MISSING")
end

-- 2) ตรวจสถานะไฟล์ state
local STATE_FILE = "UFOHubX/key_state.json"
local hasState, stateRaw, stateTbl = false, nil, nil
if isfile and readfile and isfile(STATE_FILE) then
    hasState = true
    local ok, data = pcall(readfile, STATE_FILE)
    stateRaw = ok and data or ("<readfile error: "..tostring(data)..">")
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(stateRaw) end)
    if ok2 then stateTbl = decoded end
end
out("state file present : %s", tostring(hasState))
if hasState then
    out("state (raw) : %s", (type(stateRaw)=="string" and #stateRaw>200) and (stateRaw:sub(1,200).." ...") or tostring(stateRaw))
    if stateTbl then
        out("state.key = %s, permanent=%s, expires_at=%s", tostring(stateTbl.key), tostring(stateTbl.permanent), tostring(stateTbl.expires_at))
    end
end

-- 3) ตรวจไฟล์ external ที่เราช่วยเพิ่ม
local EXT_FILE = "UFO-HUB-X-Studio/UFO-HUB-X-key1"
local hasExt, extRaw, extTbl = false, nil, nil
if isfile and readfile and isfile(EXT_FILE) then
    hasExt = true
    local ok, data = pcall(readfile, EXT_FILE)
    extRaw = ok and data or ("<readfile error: "..tostring(data)..">")
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(extRaw) end)
    if ok2 then extTbl = decoded end
end
out("external file present: %s", tostring(hasExt))
if hasExt then
    out("external (raw) : %s", (type(extRaw)=="string" and #extRaw>200) and (extRaw:sub(1,200).." ...") or tostring(extRaw))
    if extTbl then out("external.key = %s, permanent=%s, expires_at=%s", tostring(extTbl.key), tostring(extTbl.permanent), tostring(extTbl.expires_at)) end
end

-- 4) ตรวจค่า cur/valid (ถ้ามี readState function)
local cur, valid = nil, nil
if type(_G.UFO_HUBX_KEY) ~= "nil" then
    out("_G.UFO_HUBX_KEY = %s", tostring(_G.UFO_HUBX_KEY))
end

-- Try to call readState if it exists in global scope (unlikely) - otherwise we just rely on files above.
-- Note: This LocalScript cannot access functions inside Script.lua that are not global. We already logged global state above.
out("NOTE: This diag checks globals and file-system only. If your Script.lua defines readState locally, this diag won't call it.")

-- 5) Attempt quick UI open:
-- Priority A: call _G.UFO_ShowMain() if present
if type(_G.UFO_ShowMain) == "function" then
    out("Attempting to call _G.UFO_ShowMain() ...")
    local ok, res = safeCall(function() _G.UFO_ShowMain() end)
    out("UFO_ShowMain call: ok=%s, err=%s", tostring(ok), tostring(res))
    out("Wait 2s to see if Main UI appears in PlayerGui...")
    task.wait(2)
else
    out("_G.UFO_ShowMain() not available, will try fetching Key UI URL and running it as a test.")
end

-- 6) If _G.UFO_ShowMain not available, attempt to fetch Key UI URL from known location
local TEST_URLS = {
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua",
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua",
    "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua",
}
local fetchedAny = false
for _, u in ipairs(TEST_URLS) do
    local ok, body = safeCall(function() return game:HttpGet(u) end)
    if ok and body and #tostring(body) > 0 then
        out("Fetched URL OK: %s (len=%d)", u, #tostring(body))
        fetchedAny = true
        -- Do not auto-run long code. Ask user to confirm if they want to run fetched source.
        break
    else
        out("Fetch failed (or blocked) for: %s", u)
    end
end

-- 7) Final guidance printed
out("DIAGNOSTIC COMPLETE.")
out("Summary:")
if not type(_G.UFO_ShowMain) == "function" then
    out("- _G.UFO_ShowMain not available? (check Script.lua running and not erroring).")
end
if not hasState and not hasExt then
    out("- No key_state.json and no external key file found -> Key UI will be shown.")
elseif hasExt and not hasState then
    out("- External key present but state file not found -> external import should run. If not, check Script.lua was loaded successfully and contains readKeyExternal + import block.")
else
    out("- Files: state=%s, external=%s", tostring(hasState), tostring(hasExt))
end

out("")
out("Next steps (pick one and tell me the Output lines):")
out("A) Paste the Output log here (copy all [UFO-DIAG] lines). I'll read and tell exact fix.")
out("B) If you want immediate quick UI test now, reply 'RUN_MAIN' and I'll give a one-line script to force-call UI (only runs locally in Studio).")
out("C) If there are runtime errors in your Script.lua (check Output window for red errors), paste them and I'll fix the exact syntax/placement.")
out("D) If you want I can produce a FULL Script.lua (complete, with the exact Boot Flow included + our adds) as one file for you to replace — reply 'FULL FILE' and I'll emit it (long).")

-- end diag
