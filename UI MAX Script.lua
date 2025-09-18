--!strict
-- Roblox Studio Plugin: UFO HUB X (Dev Tool) - Safe Version
-- • ใช้ใน Roblox Studio เท่านั้น เพื่ออำนวยความสะดวก dev
-- • ไม่มีการใช้ executor APIs / ไม่มีการหลบระบบความปลอดภัยของแพลตฟอร์ม
-- • โฟกัสโครงสร้างที่ดี: namespace, feature flags, retry/backoff, state, watcher

----------------------------
-- Services
----------------------------
local Toolbar = plugin:CreateToolbar("UFO HUB X (Dev)")
local HttpService = game:GetService("HttpService")

----------------------------
-- Namespace & Config
----------------------------
local UFO = {
    cfg = {},
    state = {
        keyOk = false,
        mainStarted = false,
        downloadStarted = false,
        keyData = nil, -- {key=..., expires_at=..., permanent=...}
    },
}

local CFG = {
    VERSION = "studio-boot-1.1.0",
    FEATURES = {
        FORCE_KEY_UI_DEFAULT = true,
        TRUST_EXTERNAL_KEY = true, -- ถ้า false จะตรวจกับ ALLOW_KEYS
        ENABLE_CLEAR_BUTTON = true,
        DOWNLOAD_TIMEOUT_SEC = 90,
        KEY_TIMEOUT_SEC = 120,
        WATCHDOG_TOTAL_SEC = 180,
    },
    -- ปรับลิงก์ของคุณเอง (ควบคุมได้ และสอดคล้องกฎ Roblox/ทีมคุณ)
    URL_KEYS = {
        "https://example.com/dev/key-ui.lua",
    },
    URL_DOWNLOADS = {
        "https://example.com/dev/download-ui.lua",
    },
    URL_MAINS = {
        "https://example.com/dev/main-ui.lua",
    },
    -- allow-list ภายในสำหรับงาน dev (ถ้า TRUST_EXTERNAL_KEY=false จะใช้ตรงนี้)
    ALLOW_KEYS = {
        ["JJJMAX"] = { permanent=true,  reusable=true, expires_at=nil },
        ["GMPANUPHONGARTPHAIRIN"] = { permanent=true,  reusable=true, expires_at=nil },
    },
}

local SETTINGS_KEY = "UFO_HUBX_STATE_V1"

local function log(msg: string)
    print(("[UFO-HUB-X/Studio] %s"):format(msg))
end

----------------------------
-- Utils
----------------------------
local function normKey(s: string?): string
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end

local function encodeJSON(tbl)
    return HttpService:JSONEncode(tbl)
end

local function decodeJSON(s)
    return HttpService:JSONDecode(s)
end

local function readState()
    local raw = plugin:GetSetting(SETTINGS_KEY)
    if typeof(raw) == "string" and #raw > 0 then
        local ok, data = pcall(decodeJSON, raw)
        if ok and data then return data end
    end
    return nil
end

local function writeState(tbl)
    local ok, json = pcall(encodeJSON, tbl)
    if ok then
        plugin:SetSetting(SETTINGS_KEY, json)
    end
end

local function deleteState()
    plugin:SetSetting(SETTINGS_KEY, "")
end

local function isKeyStillValid(stateTbl)
    if not stateTbl or not stateTbl.key then return false end
    if stateTbl.permanent == true then return true end
    if stateTbl.expires_at and typeof(stateTbl.expires_at) == "number" then
        if os.time() < stateTbl.expires_at then return true end
    end
    return false
end

local function checkKeyAllowed(k: string)
    local nk = normKey(k)
    local meta = CFG.ALLOW_KEYS[nk]
    if not meta then return false, "key_not_allowed" end
    return true, meta
end

local function saveKeyState(key: string, expires_at: number?, permanent: boolean?)
    local st = {
        schema_version = 1,
        key        = key,
        permanent  = permanent and true or false,
        expires_at = expires_at or nil,
        saved_at   = os.time(),
    }
    writeState(st)
    UFO.state.keyData = st
end

local function http_get(url: string): (boolean, string?)
    -- ใช้ HttpService ของ Studio (ไม่ใช่ executor)
    local ok, body = pcall(function()
        return HttpService:GetAsync(url, true)
    end)
    if ok and typeof(body) == "string" and #body:gsub("%s+","") > 0 then
        return true, body
    end
    return false, nil
end

local function http_get_retry(urls: {string}, tries: number?, delay_s: number?)
    local list = urls or {}
    tries   = tries or 3
    delay_s = delay_s or 0.75
    local attempt = 0
    for r=1, tries do
        for _,u in ipairs(list) do
            attempt += 1
            log(("HTTP try #%d → %s"):format(attempt, u))
            local ok, body = http_get(u)
            if ok and body then return true, body, u end
        end
        task.wait(delay_s * r)
    end
    return false, nil, nil
end

local function safe_loadstring(src: string, tag: string?): (boolean, string?)
    local f, e = loadstring(src, tag or "chunk")
    if not f then return false, "loadstring: "..tostring(e) end
    local ok, err = pcall(f)
    if not ok then return false, "pcall: "..tostring(err) end
    return true, nil
end

local function untilOrTimeout(checkFn, timeout, sleep)
    local t0 = os.clock()
    timeout = timeout or 60
    sleep = sleep or 0.25
    while (os.clock() - t0) < timeout do
        if checkFn() then return true end
        task.wait(sleep)
    end
    return false
end

----------------------------
-- UI (DockWidget)
----------------------------
local toolbarButton = Toolbar:CreateButton("UFO_HUB_X_Open", "Open UFO HUB X (Dev)", "")

local info = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Left,
    true,   -- initial enabled
    true,   -- override previous enable
    350,    -- default width
    420,    -- default height
    300,    -- min width
    360     -- min height
)
local dock = plugin:CreateDockWidgetPluginGui("UFO_HUB_X_DEV", info)
dock.Title = "UFO HUB X (Dev)"

local Screen = Instance.new("Frame")
Screen.Size = UDim2.fromScale(1,1)
Screen.BackgroundColor3 = Color3.fromRGB(24,24,28)
Screen.Parent = dock

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 10)
Padding.PaddingLeft = UDim.new(0, 10)
Padding.PaddingRight = UDim.new(0, 10)
Padding.PaddingBottom = UDim.new(0, 10)
Padding.Parent = Screen

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 8)
List.FillDirection = Enum.FillDirection.Vertical
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Screen

local function mkLabel(text: string, bold: boolean?)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,26)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(230,230,235)
    l.Font = Enum.Font.Gotham
    l.TextSize = bold and 18 or 14
    l.Parent = Screen
    return l
end

local function mkButton(text: string, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,36)
    b.BackgroundColor3 = Color3.fromRGB(40,40,46)
    b.TextColor3 = Color3.fromRGB(240,240,245)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.Text = text
    b.AutoButtonColor = true
    b.MouseButton1Click:Connect(function()
        pcall(cb)
    end)
    b.Parent = Screen
    return b
end

local function mkTextBox(placeholder: string)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(1,0,0,34)
    t.BackgroundColor3 = Color3.fromRGB(35,35,40)
    t.PlaceholderText = placeholder
    t.Text = ""
    t.TextColor3 = Color3.fromRGB(240,240,245)
    t.PlaceholderColor3 = Color3.fromRGB(150,150,160)
    t.Font = Enum.Font.Gotham
    t.TextSize = 14
    t.ClearTextOnFocus = false
    t.Parent = Screen
    return t
end

mkLabel("UFO HUB X — Dev Loader (Studio Plugin)", true)
mkLabel("Version: "..CFG.VERSION)
local keyBox = mkTextBox("Enter dev key (internal)")
local statusLabel = mkLabel("Status: Idle")

local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1,0,0,36)
btnRow.BackgroundTransparency = 1
btnRow.Parent = Screen

local uiListRow = Instance.new("UIListLayout")
uiListRow.FillDirection = Enum.FillDirection.Horizontal
uiListRow.Padding = UDim.new(0,8)
uiListRow.Parent = btnRow

local btnCheck = mkButton("1) Validate Key", function() end)
btnCheck.Parent = btnRow

local btnDownload = mkButton("2) Download UI", function() end)
btnDownload.Parent = btnRow

local btnMain = mkButton("3) Show Main", function() end)
btnMain.Parent = btnRow

local btnClear
if CFG.FEATURES.ENABLE_CLEAR_BUTTON then
    btnClear = mkButton("Clear State", function()
        deleteState()
        UFO.state.keyOk = false
        UFO.state.keyData = nil
        statusLabel.Text = "Status: Cleared state."
    end)
end

----------------------------
-- Callbacks / Flow (Safe)
----------------------------
local function onKeyAccepted()
    statusLabel.Text = "Status: ✅ Key accepted."
    UFO.state.keyOk = true
end

local function startDownload()
    if UFO.state.downloadStarted then return end
    UFO.state.downloadStarted = true
    statusLabel.Text = "Status: Downloading..."
    local ok, src = http_get_retry(CFG.URL_DOWNLOADS, 5, 0.8)
    if not ok or not src then
        statusLabel.Text = "Status: Download failed → fallback to Main."
        task.defer(function()
            pcall(function()
                showMain()
            end)
        end)
        return
    end

    -- bootstrap hook แทนการ gsub fragile
    local wrapper = string.format([[
        local _ufo_done = false
        rawset(_G, "UFO_OnDone", function()
            _ufo_done = true
            if _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        end)
        %s
        task.delay(10, function()
            if not _ufo_done and _G and _G.UFO_ShowMain then _G.UFO_ShowMain() end
        end)
    ]], src)

    local ok2, err = safe_loadstring(wrapper, "UFO_Studio_Download")
    if not ok2 then
        statusLabel.Text = "Status: Download UI error → fallback Main."
        task.defer(function()
            pcall(function()
                showMain()
            end)
        end)
        return
    end
    statusLabel.Text = "Status: Download UI loaded."
end

function showMain()
    if UFO.state.mainStarted then return end
    UFO.state.mainStarted = true
    statusLabel.Text = "Status: Loading Main..."
    local ok, src = http_get_retry(CFG.URL_MAINS, 5, 0.8)
    if not ok or not src then
        statusLabel.Text = "Status: Main load failed. Check URL."
        return
    end
    local ok2, err = safe_loadstring(src, "UFO_Studio_Main")
    if not ok2 then
        statusLabel.Text = "Status: Main error. "..tostring(err)
        return
    end
    statusLabel.Text = "Status: Main shown."
end

_G.UFO_ShowMain = showMain

_G.UFO_SaveKeyState = function(key, expires_at, permanent)
    if not CFG.FEATURES.TRUST_EXTERNAL_KEY then
        local ok, meta = checkKeyAllowed(key)
        if not ok then
            statusLabel.Text = "Status: ❌ Key rejected (allow-list)."
            return
        end
        if meta.permanent then permanent = true end
        expires_at = expires_at or meta.expires_at
    end
    saveKeyState(key, expires_at, permanent)
    onKeyAccepted()
end

local function showKeyUIFirst()
    statusLabel.Text = "Status: Loading Key UI..."
    local ok, src = http_get_retry(CFG.URL_KEYS, 5, 0.8)
    if not ok or not src then
        statusLabel.Text = "Status: ❌ Key UI fetch failed."
        return
    end

    -- Hook ให้ UI เรียก UFO_OnKeyAccepted() (หรืออย่างน้อยเรียก UFO_SaveKeyState)
    local wrapper = string.format([[
        rawset(_G, "UFO_OnKeyAccepted", function()
            if _G and _G.UFO_SaveKeyState then
                -- ถ้า UI ไม่ส่ง key มา ก็ดึงจากกล่องข้อความของปลั๊กอินนี้แทน (dev only)
                _G.UFO_SaveKeyState("%s", nil, true)
            end
        end)
        %s
        -- Fallback: ถ้า UI ไม่เรียก ให้ dev กด Validate เพื่อยืนยันได้
    ]], normKey(keyBox.Text), src)

    local ok2, err = safe_loadstring(wrapper, "UFO_Studio_KeyUI")
    if not ok2 then
        statusLabel.Text = "Status: Key UI error. "..tostring(err)
        return
    end

    -- Watcher: ถ้าได้ key แล้วให้กดโหลดต่อได้
    task.spawn(function()
        local okW = untilOrTimeout(function()
            return UFO.state.keyOk
        end, CFG.FEATURES.KEY_TIMEOUT_SEC, 0.25)
        if not okW then
            log("Key stage timeout (waiting for user).")
        end
    end)
end

----------------------------
-- Wire Buttons
----------------------------
btnCheck.MouseButton1Click:Connect(function()
    local key = normKey(keyBox.Text)
    if key == "" then
        statusLabel.Text = "Status: Please enter key (dev)."
        return
    end
    if not CFG.FEATURES.TRUST_EXTERNAL_KEY then
        local ok, meta = checkKeyAllowed(key)
        if not ok then
            statusLabel.Text = "Status: ❌ Key not allowed (dev)."
            return
        end
        saveKeyState(key, meta.expires_at, meta.permanent)
    else
        saveKeyState(key, nil, true)
    end
    onKeyAccepted()
end)

btnDownload.MouseButton1Click:Connect(function()
    if not UFO.state.keyOk then
        statusLabel.Text = "Status: Enter/Validate key first."
        return
    end
    startDownload()
end)

btnMain.MouseButton1Click:Connect(function()
    showMain()
end)

toolbarButton.Click:Connect(function()
    dock.Enabled = not dock.Enabled
end)

----------------------------
-- Boot
----------------------------
log("Booting "..CFG.VERSION)
statusLabel.Text = "Status: Booting "..CFG.VERSION

local cur = readState()
local valid = isKeyStillValid(cur)
if valid then
    UFO.state.keyOk = true
    UFO.state.keyData = cur
    statusLabel.Text = "Status: Key OK (from state)."
else
    if CFG.FEATURES.FORCE_KEY_UI_DEFAULT then
        showKeyUIFirst()
    else
        statusLabel.Text = "Status: Waiting. Enter key or open Key UI."
    end
end

-- Watchdog (รวม)
task.spawn(function()
    local t0 = os.clock()
    while (os.clock() - t0) < CFG.FEATURES.WATCHDOG_TOTAL_SEC do
        if UFO.state.mainStarted then return end
        task.wait(1)
    end
    if not UFO.state.mainStarted then
        log("Watchdog: forcing Main (dev)")
        showMain()
    end
end)
