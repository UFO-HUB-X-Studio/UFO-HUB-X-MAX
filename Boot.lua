-- === [UFO HUB X • Boot Loader: Key → Download → Main] ======================
-- Single-run guard (กันซ้ำ)
if getgenv and getgenv().__UFO_BOOT_RUNNING then return end
if getgenv then getgenv().__UFO_BOOT_RUNNING = true end

-- ★ ตั้งลิงก์ของคุณที่นี่ (แก้เป็นของตัวเองได้)
local URL_KEYS = {
  "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X/refs/heads/main/UFO%20HUB%20X%20key.lua",
}
local URL_DOWNLOADS = {
  "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-2/refs/heads/main/UFO%20HUB%20X%20Download.lua",
}
local URL_MAINS = {
  "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-3/refs/heads/main/UFO%20HUB%20X%20UI.lua",
}

-- ===== ไม่ต้องแก้ด้านล่างนี้ =====
local HttpService  = game:GetService("HttpService")
local UIS          = game:GetService("UserInputService")

local function log(s) s="[UFO-HUB-X] "..tostring(s); if rconsoleprint then rconsoleprint(s.."\n") else print(s) end end
local function http_get(u)
  if http and http.request then local ok,r=pcall(http.request,{Url=u,Method="GET"}); if ok and r and (r.Body or r.body) then return true,(r.Body or r.body) end end
  if syn and syn.request then local ok,r=pcall(syn.request,{Url=u,Method="GET"}); if ok and r and (r.Body or r.body) then return true,(r.Body or r.body) end end
  local ok,b=pcall(function() return game:HttpGet(u) end); if ok and b then return true,b end
  return false,"httpget_failed"
end
local function http_get_retry(urls, tries, delay_s)
  local list = (type(urls)=="table") and urls or {urls}; tries = tries or 3; delay_s = delay_s or 0.75
  local attempt=0
  for round=1,tries do
    for _,u in ipairs(list) do
      attempt+=1; log(("HTTP try #%d → %s"):format(attempt,u))
      local ok,body=http_get(u); if ok and body then return true,body,u end
    end
    task.wait(delay_s*round)
  end
  return false,"retry_failed"
end
local function safe_loadstring(src, tag)
  local f,e=loadstring(src,tag or "chunk"); if not f then return false,"loadstring: "..tostring(e) end
  local ok,err=pcall(f); if not ok then return false,"pcall: "..tostring(err) end
  return true
end

-- === บันทึกสถานะคีย์ในไฟล์ (หมดอายุแล้วเด้ง UI เอง) =====================
local DIR, STATE_FILE = "UFOHubX", "UFOHubX/key_state.json"
local function ensureDir() if isfolder and not isfolder(DIR) then pcall(makefolder,DIR) end end
ensureDir()
local function readState()
  if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
  local ok,d=pcall(readfile,STATE_FILE); if not ok or not d or #d==0 then return nil end
  local ok2,js=pcall(function() return HttpService:JSONDecode(d) end); if ok2 then return js end
  return nil
end
local function writeState(t)
  if not (writefile and t) then return end
  local ok,j=pcall(function() return HttpService:JSONEncode(t) end); if ok then pcall(writefile,STATE_FILE,j) end
end
local function deleteState() if isfile and isfile(STATE_FILE) and delfile then pcall(delfile,STATE_FILE) end end
local function isKeyStillValid(st)
  if not st or not st.key then return false end
  if st.permanent==true then return true end
  if st.expires_at and typeof(st.expires_at)=="number" then return os.time() < st.expires_at end
  return false
end
local function saveKeyState(key, expires_at, permanent)
  writeState({ key=key, permanent=permanent and true or false, expires_at=expires_at or nil, saved_at=os.time() })
end

-- === ปุ่มลัดลบคีย์แล้วรีโหลด (RightAlt) ====================================
local ENABLE_CLEAR_HOTKEY, CLEAR_HOTKEY = true, Enum.KeyCode.RightAlt
local function reloadSelf()
  local boot = (getgenv and getgenv().UFO_BootURL) or nil
  if not boot then log("reloadSelf: set getgenv().UFO_BootURL ก่อน"); return end
  task.delay(0.15,function() local ok,src=http_get(boot); if ok then local f=loadstring(src); if f then pcall(f) end end end)
end
if ENABLE_CLEAR_HOTKEY then
  UIS.InputBegan:Connect(function(i,g) if g then return end; if i.KeyCode==CLEAR_HOTKEY then log("Hotkey: clear & reload"); deleteState(); reloadSelf() end end)
end

-- === Callbacks ที่ UI ยิงกลับมา ============================================
_G.UFO_SaveKeyState = function(key, expires_at, permanent)
  log(("SaveKeyState: %s exp=%s perm=%s"):format(tostring(key),tostring(expires_at),tostring(permanent)))
  saveKeyState(key, expires_at, permanent)
  _G.UFO_HUBX_KEY_OK   = true
  _G.UFO_HUBX_KEY      = key
  _G.UFO_HUBX_KEY_EXP  = expires_at
  _G.UFO_HUBX_KEY_PERM = permanent and true or false
end

_G.UFO_StartDownload = function()
  if _G.__UFO_Download_Started then return end
  _G.__UFO_Download_Started = true
  log("Start Download UI")
  local ok,src=http_get_retry(URL_DOWNLOADS,5,0.8)
  if not ok then log("Download fail → Force Main"); if _G.UFO_ShowMain then _G.UFO_ShowMain() end; return end
  -- บังคับให้จบแล้วไป Main เสมอ
  local patched, n = src:gsub("gui:Destroy%(%);?","if _G.UFO_ShowMain then _G.UFO_ShowMain() end\ngui:Destroy();")
  if n>0 then src=patched end
  local ok2,err=safe_loadstring(src,"UFOHubX_Download"); if not ok2 then log("Download run err: "..tostring(err)); if _G.UFO_ShowMain then _G.UFO_ShowMain() end end
end

_G.UFO_ShowMain = function()
  if _G.__UFO_Main_Started then return end
  _G.__UFO_Main_Started = true
  log("Show Main UI")
  local ok,src=http_get_retry(URL_MAINS,5,0.8); if not ok then log("Main fetch failed"); return end
  local ok2,err=safe_loadstring(src,"UFOHubX_Main"); if not ok2 then log("Main run err: "..tostring(err)) end
end

-- === Watchers & Safe fallback ==============================================
local function startKeyWatcher(t) t=t or 120; task.spawn(function() local t0=os.clock(); while os.clock()-t0<t do if _G.UFO_HUBX_KEY_OK then log("KEY_OK → start download"); if _G.UFO_StartDownload then _G.UFO_StartDownload() end; return end; task.wait(0.25) end end) end
local function startDownloadWatcher(t) t=t or 90; task.spawn(function() local t0=os.clock(); while os.clock()-t0<t do if _G.__UFO_Main_Started then return end; task.wait(0.5) end; log("Download timeout → Force Main"); if _G.UFO_ShowMain then _G.UFO_ShowMain() end end) end
task.spawn(function() local t0=os.clock(); while os.clock()-t0<180 do if _G.__UFO_Main_Started then return end; task.wait(1) end; log("Ultimate watchdog → Force Main"); if _G.UFO_ShowMain then _G.UFO_ShowMain() end end)

-- === ตัดสินใจโชว์อะไร =======================================================
-- ค่าเริ่มต้น: บังคับโชว์ Key ก่อน (อยากให้ข้ามเมื่อคีย์ยังไม่หมดอายุ → ตั้ง getgenv().UFO_FORCE_KEY_UI=false ก่อนรัน)
local FORCE_KEY_UI = true
do
  local env = (getgenv and getgenv().UFO_FORCE_KEY_UI)
  if env ~= nil then FORCE_KEY_UI = env and true or false end
end

local state = readState()
local valid = isKeyStillValid(state)

if FORCE_KEY_UI then
  log("FORCE_KEY_UI=true → แสดง Key UI ก่อนเสมอ")
  startKeyWatcher(120); startDownloadWatcher(120)
  local ok,src=http_get_retry(URL_KEYS,5,0.8); if not ok then log("Key UI fetch failed"); return end
  -- ให้ไป Download เฉพาะตอนคีย์ผ่านจริง
  local patched, n = src:gsub("gui:Destroy%(%);?","if _G.UFO_HUBX_KEY_OK and _G.UFO_StartDownload then _G.UFO_StartDownload() end\ngui:Destroy();")
  if n==0 then patched, n = src:gsub('btnSubmit.Text%s*=%s*"✅ Key accepted"','btnSubmit.Text="✅ Key accepted"\nif _G.UFO_StartDownload then _G.UFO_StartDownload() end'); end
  if n>0 then src=patched end
  local ok2,err=safe_loadstring(src,"UFOHubX_Key"); if not ok2 then log("Key UI run err: "..tostring(err)) end
  return
end

if valid then
  log("Key valid → ข้าม Key UI → ไป Download")
  _G.UFO_HUBX_KEY_OK=true; _G.UFO_HUBX_KEY=state.key; _G.UFO_HUBX_KEY_EXP=state.expires_at; _G.UFO_HUBX_KEY_PERM=state.permanent==true
  startDownloadWatcher(90)
  local ok,src=http_get_retry(URL_DOWNLOADS,5,0.8)
  if not ok then log("Download fetch fail → Force Main"); if _G.UFO_ShowMain then _G.UFO_ShowMain() end; return end
  local patched, n = src:gsub("gui:Destroy%(%);?","if _G.UFO_ShowMain then _G.UFO_ShowMain() end\ngui:Destroy();")
  if n>0 then src=patched end
  local ok2,err=safe_loadstring(src,"UFOHubX_Download"); if not ok2 then log("Download run err: "..tostring(err)); if _G.UFO_ShowMain then _G.UFO_ShowMain() end end
else
  log("ไม่มีคีย์ที่ยังไม่หมดอายุ → แสดง Key UI")
  startKeyWatcher(120); startDownloadWatcher(120)
  local ok,src=http_get_retry(URL_KEYS,5,0.8); if not ok then log("Key UI fetch failed"); return end
  local patched, n = src:gsub("gui:Destroy%(%);?","if _G.UFO_HUBX_KEY_OK and _G.UFO_StartDownload then _G.UFO_StartDownload() end\ngui:Destroy();")
  if n==0 then patched, n = src:gsub('btnSubmit.Text%s*=%s*"✅ Key accepted"','btnSubmit.Text="✅ Key accepted"\nif _G.UFO_StartDownload then _G.UFO_StartDownload() end'); end
  if n>0 then src=patched end
  local ok2,err=safe_loadstring(src,"UFOHubX_Key"); if not ok2 then log("Key UI run err: "..tostring(err)) end
end
-- ============================================================================
