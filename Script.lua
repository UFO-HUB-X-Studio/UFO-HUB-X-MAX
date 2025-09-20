--========================================================
-- UFO HUB X — ONE-FILE BOOTSTRAP (Fixed Key UI pop-up)
-- Usage: run THIS file in your executor instead of running multiple files.
-- What it does:
--   1) Disable forced Key UI (so it won't pop up when key still valid)
--   2) Load Key UI (compat) — embedded
--   3) Load Expiry Watcher — embedded (auto re-open Key UI when expired)
--   4) Finally load MAX Boot (Script.lua) from your GitHub
-- Non-destructive: does NOT edit or remove your repos.
--========================================================

-- (1) Disable "always show Key UI" default in MAX
getgenv().UFO_FORCE_KEY_UI   = false   -- important
getgenv().UFO_REVALIDATE_ON_BOOT = false

-- Optional timing settings (you can tweak later)
getgenv().UFO_EXPIRY_POLL_SEC = 5      -- check every 5s
getgenv().UFO_KEY_RENEW_GRACE = 0      -- no early popup (0 = only when expired)

-- If you have multiple key servers, you can override here (optional)
-- getgenv().UFO_SERVER_BASES = {"https://ufo-hub-x-key-umoq.onrender.com"}

-- (2) + (3) Embed and run Key UI compat + Expiry Watcher
local function __ufo_run(chunk, tag)
    local f, e = loadstring(chunk, tag or "chunk")
    if not f then warn("[UFO-BOOT] loadstring fail:", e) return end
    local ok, err = pcall(f)
    if not ok then warn("[UFO-BOOT] run fail:", err) end
end

__ufo_run([===[
--========================================================
-- UFO HUB X — KEY UI (Server-Enabled, Single File)
-- - API JSON: /verify?key=&uid=&place=  และ  /getkey
-- - JSON parse ด้วย HttpService
-- - จำอายุคีย์ผ่าน _G.UFO_SaveKeyState (48 ชม. หรือ expires_at จาก server)
-- - ปุ่ม Get Key คัดลอกลิงก์พร้อม uid/place
-- - รองรับหลายเซิร์ฟเวอร์ (failover & retry)
-- - Fade-out แล้ว Destroy เมื่อสำเร็จ
--========================================================

-------------------- Safe Prelude --------------------
local Players = game:GetService("Players")
local CG      = game:GetService("CoreGui")
local TS      = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UIS     = game:GetService("UserInputService")

pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)

local LP = Players.LocalPlayer
do
    local t0=os.clock()
    repeat
        LP = Players.LocalPlayer
        if LP then break end
        task.wait(0.05)
    until (os.clock()-t0)>12
end

local function _getPG(timeout)
    local t1=os.clock()
    repeat
        if LP then
            local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",2)
            if pg then return pg end
        end
        task.wait(0.10)
    until (os.clock()-t1)>(timeout or 6)
end
local PREP_PG = _getPG(6)

local function SOFT_PARENT(gui)
    if not gui then return end
    pcall(function()
        if gui:IsA("ScreenGui") then
            gui.Enabled=true
            gui.DisplayOrder=999999
            gui.ResetOnSpawn=false
            gui.IgnoreGuiInset=true
            gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        end
    end)
    if syn and syn.protect_gui then pcall(function() syn.protect_gui(gui) end) end
    local ok=false
    if gethui then ok=pcall(function() gui.Parent=gethui() end) end
    if (not ok) or (not gui.Parent) then ok=pcall(function() gui.Parent=CG end) end
    if (not ok) or (not gui.Parent) then
        local pg = PREP_PG or _getPG(4)
        if pg then pcall(function() gui.Parent=pg end) end
    end
end

-------------------- Theme --------------------
local LOGO_ID   = 112676905543996
local ACCENT    = Color3.fromRGB(0,255,140)
local BG_DARK   = Color3.fromRGB(10,10,10)
local FG        = Color3.fromRGB(235,235,235)
local SUB       = Color3.fromRGB(22,22,22)
local RED       = Color3.fromRGB(210,60,60)
local GREEN     = Color3.fromRGB(60,200,120)

-------------------- Links / Servers --------------------
local DISCORD_URL = "https://discord.gg/your-server"

local SERVER_BASES = {
    "https://ufo-hub-x-key-umoq.onrender.com", -- หลัก
    -- "https://ufo-hub-x-server-key2.onrender.com", -- สำรอง (ถ้ามี)
}
local DEFAULT_TTL_SECONDS = 48*3600

-------------------- Allow-list (ผ่านแน่) --------------------
local ALLOW_KEYS = {
    ["JJJMAX"]                 = { reusable=true, ttl=DEFAULT_TTL_SECONDS },
    ["GMPANUPHONGARTPHAIRIN"]  = { reusable=true, ttl=DEFAULT_TTL_SECONDS },
}

local function normKey(s)
    s = tostring(s or ""):gsub("%c",""):gsub("%s+",""):gsub("[^%w]","")
    return string.upper(s)
end
local function isAllowedKey(k)
    local nk = normKey(k)
    local meta = ALLOW_KEYS[nk]
    if meta then return true, nk, meta end
    return false, nk, nil
end

-------------------- HTTP helpers --------------------
local function http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request,{Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
        return false,"executor_http_request_failed"
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request,{Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
        return false,"syn_request_failed"
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"roblox_httpget_failed"
end

local function http_json_get(url)
    local ok,body = http_get(url)
    if not ok or not body then return false,nil,"http_error" end
    local okj,data = pcall(function() return HttpService:JSONDecode(tostring(body)) end)
    if not okj then return false,nil,"json_error" end
    return true,data,nil
end

local function json_get_with_failover(path_qs)
    local last_err="no_servers"
    -- merge external bases (non-destructive)
    local bases = {}
    for i,v in ipairs(SERVER_BASES) do bases[#bases+1]=v end
    if type(_G.UFO_SERVER_BASES)=="table" then
        for _,b in ipairs(_G.UFO_SERVER_BASES) do
            if type(b)=="string" and b~="" then bases[#bases+1]=b end
        end
    end
    for _,base in ipairs(bases) do
        local url = (base..path_qs)
        for i=0,2 do
            if i>0 then task.wait(0.6*i) end
            local ok,data,err = http_json_get(url)
            if ok and data then return true,data end
            last_err = err or "http_error"
        end
    end
    return false,nil,last_err
end

local function verifyWithServer(k)
    local uid   = tostring(LP and LP.UserId or "")
    local place = tostring(game.PlaceId or "")
    local qs = string.format("/verify?key=%s&uid=%s&place=%s",
        HttpService:UrlEncode(k),
        HttpService:UrlEncode(uid),
        HttpService:UrlEncode(place)
    )
    local ok,data = json_get_with_failover(qs)
    if not ok or not data then return false,"server_unreachable",nil end
    -- accept a few schema variants: {ok=true,valid=true,expires_at=...} OR {valid=true,exp=...}
    local isOk   = (data.ok==nil) and true or (data.ok==true)
    local valid  = (data.valid==true) or (data.status=="valid") or (data.success==true)
    local expNum = tonumber(data.expires_at or data.exp or data.ttl and (os.time()+tonumber(data.ttl)))
    if isOk and valid then
        local exp = expNum or (os.time()+DEFAULT_TTL_SECONDS)
        return true,nil,exp
    end
    return false,tostring(data.reason or data.error or "invalid"),nil
end

-------------------- UI utils --------------------
local function make(class, props, kids)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end
local function tween(o, goal, t)
    TS:Create(o, TweenInfo.new(t or .18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end
local function setClipboard(s) if setclipboard then pcall(setclipboard, s) end end

-------------------- Root GUI --------------------
-- ถ้ามีตัวเก่าอยู่ ย้าย parent ให้ทน แล้วสร้างใหม่ (ไม่ลบของเดิม)
pcall(function()
    local old = CG:FindFirstChild("UFOHubX_KeyUI")
    if old and old:IsA("ScreenGui") then
        SOFT_PARENT(old)
        old.Enabled = false
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name="UFOHubX_KeyUI"
gui.IgnoreGuiInset=true
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SOFT_PARENT(gui)

-- watchdog กันโดนถอด parent
task.spawn(function()
    while gui do
        if not gui.Parent then SOFT_PARENT(gui) end
        if gui.Enabled==false then pcall(function() gui.Enabled=true end) end
        task.wait(0.25)
    end
end)

-------------------- Panel --------------------
local PANEL_W,PANEL_H = 740, 430
local panel = make("Frame",{
    Parent=gui, Active=true, Draggable=true,
    Size=UDim2.fromOffset(PANEL_W,PANEL_H),
    AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
    BackgroundColor3=BG_DARK, BorderSizePixel=0, ZIndex=1
},{
    make("UICorner",{CornerRadius=UDim.new(0,22)}),
    make("UIStroke",{Color=ACCENT, Thickness=2, Transparency=0.1}})
)

-- close
local btnClose = make("TextButton",{
    Parent=panel, Text="X", Font=Enum.Font.GothamBold, TextSize=20, TextColor3=Color3.new(1,1,1),
    AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(210,35,50),
    Size=UDim2.new(0,38,0,38), Position=UDim2.new(1,-50,0,14), ZIndex=50
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)})
})
btnClose.MouseButton1Click:Connect(function()
    pcall(function() if gui and gui.Parent then gui:Destroy() end end)
end)

-- header
local head = make("Frame",{
    Parent=panel, BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(14,14,14),
    Size=UDim2.new(1,-28,0,68), Position=UDim2.new(0,14,0,14), ZIndex=5
},{
    make("UICorner",{CornerRadius=UDim.new(0,16)}),
    make("UIStroke",{Color=ACCENT, Transparency=0.85})
})
make("ImageLabel",{
    Parent=head, BackgroundTransparency=1, Image="rbxassetid://"..LOGO_ID,
    Size=UDim2.new(0,34,0,34), Position=UDim2.new(0,16,0,17), ZIndex=6
},{})
make("TextLabel",{
    Parent=head, BackgroundTransparency=1, Position=UDim2.new(0,60,0,18),
    Size=UDim2.new(0,200,0,32), Font=Enum.Font.GothamBold, TextSize=20,
    Text="KEY SYSTEM", TextColor3=ACCENT, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6
},{})

-- title
local titleGroup = make("Frame",{Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,102), Size=UDim2.new(1,-56,0,76)},{})
make("UIListLayout",{
    Parent=titleGroup, FillDirection=Enum.FillDirection.Vertical,
    HorizontalAlignment=Enum.HorizontalAlignment.Left, VerticalAlignment=Enum.VerticalAlignment.Top,
    SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)
},{})
make("TextLabel",{
    Parent=titleGroup, LayoutOrder=1, BackgroundTransparency=1, Size=UDim2.new(1,0,0,32),
    Font=Enum.Font.GothamBlack, TextSize=30, Text="Welcome to the,", TextColor3=FG,
    TextXAlignment=Enum.TextXAlignment.Left
},{})
local titleLine2 = make("Frame",{Parent=titleGroup, LayoutOrder=2, BackgroundTransparency=1, Size=UDim2.new(1,0,0,36)},{})
make("UIListLayout",{
    Parent=titleLine2, FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Left, VerticalAlignment=Enum.VerticalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)
},{})
make("TextLabel",{Parent=titleLine2, LayoutOrder=1, BackgroundTransparency=1,
    Font=Enum.Font.GothamBlack, TextSize=32, Text="UFO", TextColor3=ACCENT, AutomaticSize=Enum.AutomaticSize.X},{})
make("TextLabel",{Parent=titleLine2, LayoutOrder=2, BackgroundTransparency=1,
    Font=Enum.Font.GothamBlack, TextSize=32, Text="HUB X", TextColor3=Color3.new(1,1,1), AutomaticSize=Enum.AutomaticSize.X},{})

-- key input
make("TextLabel",{
    Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,188),
    Size=UDim2.new(0,60,0,22), Font=Enum.Font.Gotham, TextSize=16,
    Text="Key", TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
},{})
local keyStroke
local keyBox = make("TextBox",{
    Parent=panel, ClearTextOnFocus=false, PlaceholderText="insert your key here",
    Font=Enum.Font.Gotham, TextSize=16, Text="", TextColor3=FG,
    BackgroundColor3=SUB, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,40), Position=UDim2.new(0,28,0,214)
},{
    make("UICorner",{CornerRadius=UDim.new(0,12)}),
    (function() keyStroke=make("UIStroke",{Color=ACCENT, Transparency=0.75}); return keyStroke end)()
})

-- submit button
local btnSubmit = make("TextButton",{
    Parent=panel, Text="🔒  Submit Key", Font=Enum.Font.GothamBlack, TextSize=20,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false, BackgroundColor3=RED, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,50), Position=UDim2.new(0,28,0,268)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)})
})

-- toast
local toast = make("TextLabel",{
    Parent=panel, BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(30,30,30),
    Size=UDim2.fromOffset(0,32), Position=UDim2.new(0.5,0,0,16),
    AnchorPoint=Vector2.new(0.5,0), Visible=false, Font=Enum.Font.GothamBold,
    TextSize=14, Text="", TextColor3=Color3.new(1,1,1), ZIndex=100
},{
    make("UIPadding",{PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,14)}),
    make("UICorner",{CornerRadius=UDim.new(0,10)})
})
local function showToast(msg, ok)
    toast.Text = msg
    toast.BackgroundColor3 = ok and Color3.fromRGB(20,120,60) or Color3.fromRGB(150,35,35)
    toast.Size = UDim2.fromOffset(math.max(160,(#msg*8)+28),32)
    toast.Visible = true
    toast.BackgroundTransparency = 0.15
    tween(toast,{BackgroundTransparency=0.05},.08)
    task.delay(1.1,function()
        tween(toast,{BackgroundTransparency=1},.15)
        task.delay(.15,function() toast.Visible=false end)
    end)
end

-- status
local statusLabel = make("TextLabel",{
    Parent=panel, BackgroundTransparency=1, Position=UDim2.new(0,28,0,268+50+6),
    Size=UDim2.new(1,-56,0,24), Font=Enum.Font.Gotham, TextSize=14, Text="",
    TextColor3=Color3.fromRGB(200,200,200), TextXAlignment=Enum.TextXAlignment.Left
},{})
local function setStatus(txt, ok)
    statusLabel.Text = txt or ""
    if ok==nil then
        statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
    elseif ok then
        statusLabel.TextColor3 = Color3.fromRGB(120,255,170)
    else
        statusLabel.TextColor3 = Color3.fromRGB(255,120,120)
    end
end

-- error fx
local function flashInputError()
    if keyStroke then
        local old=keyStroke.Color
        tween(keyStroke,{Color=Color3.fromRGB(255,90,90), Transparency=0},.05)
        task.delay(.22,function() tween(keyStroke,{Color=old, Transparency=0.75},.12) end)
    end
    local p0=btnSubmit.Position
    TS:Create(btnSubmit, TweenInfo.new(0.05),{Position=p0+UDim2.fromOffset(-5,0)}):Play()
    task.delay(0.05,function()
        TS:Create(btnSubmit, TweenInfo.new(0.05),{Position=p0+UDim2.fromOffset(5,0)}):Play()
        task.delay(0.05,function()
            TS:Create(btnSubmit, TweenInfo.new(0.05),{Position=p0}):Play()
        end)
    end)
end

-- fade destroy
local function fadeOutAndDestroy()
    for _,d in ipairs(panel:GetDescendants()) do
        pcall(function()
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency=1}):Play()
                if d:IsA("TextBox") or d:IsA("TextButton") then
                    TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()
                end
            elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency=1, BackgroundTransparency=1}):Play()
            elseif d:IsA("Frame") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()
            elseif d:IsA("UIStroke") then
                TS:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency=1}):Play()
            end
        end)
    end
    TS:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()
    task.delay(0.22,function() if gui and gui.Parent then gui:Destroy() end end)
end

-- submit states
local submitting=false
local function refreshSubmit()
    if submitting then return end
    local hasText = (keyBox.Text and #keyBox.Text>0)
    if hasText then
        tween(btnSubmit,{BackgroundColor3=GREEN},.08)
        btnSubmit.Text="🔓  Submit Key"
        btnSubmit.TextColor3=Color3.new(0,0,0)
    else
        tween(btnSubmit,{BackgroundColor3=RED},.08)
        btnSubmit.Text="🔒  Submit Key"
        btnSubmit.TextColor3=Color3.new(1,1,1)
    end
end
keyBox:GetPropertyChangedSignal("Text"):Connect(function() setStatus("",nil); refreshSubmit() end)
refreshSubmit()
keyBox.FocusLost:Connect(function(enter) if enter then btnSubmit:Activate() end end)

-------------------- Submit Flow --------------------
local function forceErrorUI(mainText, toastText)
    tween(btnSubmit,{BackgroundColor3=Color3.fromRGB(255,80,80)},.08)
    btnSubmit.Text = mainText or "❌ Invalid Key"
    btnSubmit.TextColor3 = Color3.new(1,1,1)
    setStatus(toastText or "กุญแจไม่ถูกต้อง ลองอีกครั้ง", false)
    showToast(toastText or "รหัสไม่ถูกต้อง", false)
    flashInputError()
    keyBox.Text = ""
    task.delay(0.02,function() keyBox:CaptureFocus() end)
    task.delay(1.2,function() submitting=false; btnSubmit.Active=true; refreshSubmit() end)
end

local function doSubmit()
    if submitting then return end
    submitting=true; btnSubmit.AutoButtonColor=false; btnSubmit.Active=false

    local k = keyBox.Text or ""
    if k=="" then forceErrorUI("🚫 Please enter a key","โปรดใส่รหัสก่อนนะ"); return end

    setStatus("กำลังตรวจสอบคีย์...", nil)
    tween(btnSubmit,{BackgroundColor3=Color3.fromRGB(70,170,120)},.08)
    btnSubmit.Text="⏳ Verifying..."

    local valid,reason,expires_at = false,nil,nil
    local allowed,nk,meta = isAllowedKey(k)
    if allowed then
        valid=true
        expires_at = os.time() + (tonumber(meta.ttl) or DEFAULT_TTL_SECONDS)
        print("[UFO-HUB-X] allowed key:", nk, "exp:", expires_at)
    else
        valid,reason,expires_at = verifyWithServer(k)
        if valid then
            print("[UFO-HUB-X] server verified key:", k, "exp:", expires_at)
        else
            print("[UFO-HUB-X] key invalid:", k, "reason:", tostring(reason))
        end
    end

    if not valid then
        if reason=="server_unreachable" then
            forceErrorUI("❌ Invalid Key","เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่หรือตรวจเน็ต")
        else
            forceErrorUI("❌ Invalid Key","กุญแจไม่ถูกต้อง ลองอีกครั้ง")
        end
        return
    end

    -- ผ่าน ✅
    tween(btnSubmit,{BackgroundColor3=Color3.fromRGB(120,255,170)},.10)
    btnSubmit.Text="✅ Key accepted"
    btnSubmit.TextColor3=Color3.new(0,0,0)
    setStatus("ยืนยันคีย์สำเร็จ พร้อมใช้งาน!", true)
    showToast("ยืนยันสำเร็จ", true)

    _G.UFO_HUBX_KEY_OK = true
    _G.UFO_HUBX_KEY    = k
    if _G.UFO_SaveKeyState and expires_at then
        pcall(_G.UFO_SaveKeyState, k, tonumber(expires_at) or (os.time()+DEFAULT_TTL_SECONDS), false)
    end

    task.delay(0.15, function() 
        -- if outer asks not to destroy, keep alive but hide
        if _G.UFO_NoDestroy then
            pcall(function() gui.Enabled=false end)
        else
            fadeOutAndDestroy()
        end
    end)
end
btnSubmit.MouseButton1Click:Connect(doSubmit)
btnSubmit.Activated:Connect(doSubmit)

-------------------- GET KEY (copy link with uid/place) --------------------
local btnGetKey = make("TextButton",{
    Parent=panel, Text="🔐  Get Key", Font=Enum.Font.GothamBold, TextSize=18,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false, BackgroundColor3=SUB, BorderSizePixel=0,
    Size=UDim2.new(1,-56,0,44), Position=UDim2.new(0,28,0,324)
},{
    make("UICorner",{CornerRadius=UDim.new(0,14)}),
    make("UIStroke",{Color=ACCENT, Transparency=0.6})
})
btnGetKey.MouseButton1Click:Connect(function()
    local uid   = tostring(LP and LP.UserId or "")
    local place = tostring(game.PlaceId or "")
    local base  = (type(_G.UFO_SERVER_BASES)=="table" and _G.UFO_SERVER_BASES[1]) or SERVER_BASES[1] or ""
    local link  = string.format("%s/getkey?uid=%s&place=%s",
        base, HttpService:UrlEncode(uid), HttpService:UrlEncode(place)
    )
    setClipboard(link)
    btnGetKey.Text="✅ Link copied!"
    task.delay(1.5,function() btnGetKey.Text="🔐  Get Key" end)
end)

-------------------- Support row --------------------
local supportRow = make("Frame",{
    Parent=panel, AnchorPoint=Vector2.new(0.5,1),
    Position=UDim2.new(0.5,0,1,-18), Size=UDim2.new(1,-56,0,24), BackgroundTransparency=1
},{})
make("UIListLayout",{
    Parent=supportRow, FillDirection=Enum.FillDirection.HORIZONTAL,
    HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)
},{})
make("TextLabel",{
    Parent=supportRow, LayoutOrder=1, BackgroundTransparency=1,
    Font=Enum.Font.Gotham, TextSize=16, Text="Need support?",
    TextColor3=Color3.fromRGB(200,200,200), AutomaticSize=Enum.AutomaticSize.X
},{})
local btnDiscord = make("TextButton",{
    Parent=supportRow, LayoutOrder=2, BackgroundTransparency=1,
    Font=Enum.Font.GothamBold, TextSize=16, Text="Join the Discord",
    TextColor3=ACCENT, AutomaticSize=Enum.AutomaticSize.X
},{})
btnDiscord.MouseButton1Click:Connect(function()
    setClipboard(DISCORD_URL)
    btnDiscord.Text="✅ Link copied!"
    task.delay(1.5,function() btnDiscord.Text="Join the Discord" end)
end)

-------------------- Open Animation --------------------
panel.Position = UDim2.fromScale(0.5,0.5) + UDim2.fromOffset(0,14)
TS:Create(panel, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.fromScale(0.5,0.5)}):Play()


-- =====================================================================
--  Compatibility & Integration Add-Ons (NON-DESTRUCTIVE)
--  * ไม่ลบ/แก้ของเดิม  — เพิ่มเฉพาะสิ่งที่ทำให้เข้ากับระบบอื่นทั้งหมด *
-- =====================================================================
_G.UFO = _G.UFO or { state = {} }

-- 1) Shared SaveKeyState (ถ้าไม่ได้ประกาศไว้ที่อื่น)
if type(_G.UFO_SaveKeyState) ~= "function" then
    _G.UFO_SaveKeyState = function(key, expires_at, silent)
        _G.UFO.state.saved_key       = tostring(key or "")
        _G.UFO.state.expires_at      = tonumber(expires_at) or (os.time() + DEFAULT_TTL_SECONDS)
        _G.UFO.state.last_saved_unix = os.time()
        _G.UFO_KeyExpiresAt          = _G.UFO.state.expires_at
        if not silent then
            print("[UFO] SaveKeyState:", _G.UFO.state.saved_key, "exp:", _G.UFO.state.expires_at)
        end
        -- broadcast to listeners
        if _G.UFO_KeyEvent and _G.UFO_KeyEvent.Fire then
            pcall(function() _G.UFO_KeyEvent:Fire("saved", _G.UFO.state.saved_key, _G.UFO.state.expires_at) end)
        end
        return true
    end
end

-- 2) Global Events / Bridge
_G.UFO_KeyEvent = _G.UFO_KeyEvent or Instance.new("BindableEvent")  -- other modules can :Wait() or :Connect()
_G.UFO_OnKeyVerified = _G.UFO_OnKeyVerified or nil                  -- optional callback(key, expires_at)

-- 3) Legacy flags mapping for other UIs
local function _bridgeOkFlags(key, exp)
    _G.UFO_KEY_OK   = true
    _G.UFOX_KEY_OK  = true
    _G.UFO_Key      = key
    _G.UFO_KeyExpiresAt = exp
    -- trigger callback & event
    if type(_G.UFO_OnKeyVerified)=="function" then pcall(_G.UFO_OnKeyVerified, key, exp) end
    if _G.UFO_KeyEvent and _G.UFO_KeyEvent.Fire then
        pcall(function() _G.UFO_KeyEvent:Fire("verified", key, exp) end)
    end
    -- downstream UI requests
    if type(_G.UFO_RequestOpenDownloadUI)=="function" then pcall(_G.UFO_RequestOpenDownloadUI) end
    if type(_G.UFO_RequestOpenMainUI)=="function" then pcall(_G.UFO_RequestOpenMainUI) end
end

-- 4) Auto-close if already verified (unless forced)
task.defer(function()
    if (_G.UFO_HUBX_KEY_OK or _G.UFO_KEY_OK or _G.UFOX_KEY_OK) and not _G.UFO_ForceKeyUI then
        -- already verified elsewhere
        pcall(function() gui.Enabled=false end)
        task.delay(0.05,function()
            if not _G.UFO_NoDestroy then pcall(function() gui:Destroy() end) end
        end)
    end
end)

-- 5) Hotkey to clear saved key (Ctrl+Shift+K) — non-destructive
local function _clearKeyState()
    _G.UFO_HUBX_KEY_OK = false
    _G.UFO_KEY_OK      = false
    _G.UFOX_KEY_OK     = false
    _G.UFO.state.saved_key = nil
    _G.UFO.state.expires_at = nil
    _G.UFO_Key = nil
    _G.UFO_KeyExpiresAt = nil
    showToast("Cleared saved key", false)
    setStatus("ล้างสถานะคีย์แล้ว", false)
    keyBox.Text = ""
    task.delay(0.02, function() keyBox:CaptureFocus() end)
end
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.K and UIS:IsKeyDown(Enum.KeyCode.LeftControl) and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        _clearKeyState()
    end
end)

-- 6) Submit bridge hook (wrap after doSubmit success)
--    เราเพิ่ม connection ที่รับเหตุการณ์ verified จาก SaveKeyState แล้ว sync flag legacy
if not _G.__UFO_KEY_BRIDGED then
    _G.__UFO_KEY_BRIDGED = true
    -- intercept when button changes to success (polling lightweight)
    task.spawn(function()
        while gui and btnSubmit do
            task.wait(0.05)
            if _G.UFO_HUBX_KEY_OK or _G.UFO_KEY_OK or _G.UFOX_KEY_OK then
                local key = _G.UFO_HUBX_KEY or _G.UFO_Key
                local exp = _G.UFO_KeyExpiresAt or (_G.UFO and _G.UFO.state and _G.UFO.state.expires_at)
                _bridgeOkFlags(key, exp or (os.time()+DEFAULT_TTL_SECONDS))
                break
            end
        end
    end)
end

-- 7) Preset key auto-submit (if outer sets _G.UFO_PRESET_KEY)
task.defer(function()
    local preset = rawget(_G, "UFO_PRESET_KEY")
    if type(preset)=="string" and preset~="" and gui and keyBox then
        keyBox.Text = preset
        task.wait(0.05)
        pcall(function() btnSubmit:Activate() end)
    end
end)

-- 8) Public API for other modules (non-breaking)
_G.UFO.ShowKeyUI = _G.UFO.ShowKeyUI or function()
    if gui then gui.Enabled=true end
end
_G.UFO.HideKeyUI = _G.UFO.HideKeyUI or function()
    if gui then gui.Enabled=false end
end
_G.UFO.GetSavedKey = _G.UFO.GetSavedKey or function()
    return (_G.UFO and _G.UFO.state and _G.UFO.state.saved_key) or _G.UFO_HUBX_KEY or _G.UFO_Key
end
_G.UFO.IsKeyValid = _G.UFO.IsKeyValid or function()
    local exp = _G.UFO_KeyExpiresAt or (_G.UFO and _G.UFO.state and _G.UFO.state.expires_at)
    return (exp and exp > os.time()) and true or false
end

-- 9) Gentle status heartbeat for other UIs to probe
_G.UFO.state.ui_key_ready = true
-- =====================================================================


]===], "UFO_HUB_X_Key_UI_compat.lua")

__ufo_run([===[
--========================================================
-- UFO HUB X — Key Expiry Watcher (ADD-ONLY module)
-- Purpose:
--   - Monitor key expiry time.
--   - When expired, clear flags/state and re-open the Key UI for re-auth.
--   - Non-destructive: does NOT modify or remove existing code; only uses globals/APIs if present.
--========================================================
local HttpService = game:GetService("HttpService")

local log = function(...) print("[UFO-EXPIRY]", ...) end

-- ============= Config via getgenv() (optional) =============
local POLL_SEC    = (getgenv and tonumber(getgenv().UFO_EXPIRY_POLL_SEC)) or 5     -- how frequently to check
local GRACE_SEC   = (getgenv and tonumber(getgenv().UFO_KEY_RENEW_GRACE)) or 0     -- seconds before expiry to trigger renew UI
local STATE_DIR   = (getgenv and getgenv().UFO_STATE_DIR) or "UFOHubX"             -- fallback state path
local STATE_FILE  = (getgenv and getgenv().UFO_STATE_FILE) or (STATE_DIR.."/key_state.json")

-- ============= Helpers for optional FS persistence =========
local function _ensureDir()
    if isfolder then
        if not isfolder(STATE_DIR) then pcall(makefolder, STATE_DIR) end
    end
end
_ensureDir()

local function _readState()
    if not (isfile and readfile and isfile(STATE_FILE)) then return nil end
    local ok, data = pcall(readfile, STATE_FILE)
    if not ok or not data or #data==0 then return nil end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 then return decoded end
    return nil
end

local function _writeState(tbl)
    if not (writefile and HttpService and tbl) then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(writefile, STATE_FILE, json) end
end

local function _deleteState()
    if isfile and isfile(STATE_FILE) and delfile then pcall(delfile, STATE_FILE) end
end

-- ============= Expiry Resolution ===========================
local function _now() return os.time() end

local function _getSavedKey()
    -- Try multiple sources without modifying them
    if _G and _G.UFO_Key then return _G.UFO_Key end
    if _G and _G.UFO_HUBX_KEY then return _G.UFO_HUBX_KEY end
    if _G and _G.UFO and _G.UFO.state and _G.UFO.state.saved_key then return _G.UFO.state.saved_key end
    local st = _readState()
    if st and st.key then return st.key end
    return nil
end

local function _getExpiresAt()
    -- Prefer explicit globals if present
    if _G and _G.UFO_KeyExpiresAt and tonumber(_G.UFO_KeyExpiresAt) then return tonumber(_G.UFO_KeyExpiresAt) end
    if _G and _G.UFO and _G.UFO.state and tonumber(_G.UFO.state.expires_at) then return tonumber(_G.UFO.state.expires_at) end
    -- Fallback to state file
    local st = _readState()
    if st and tonumber(st.expires_at) then return tonumber(st.expires_at) end
    return nil
end

local function _isPermanent()
    if _G and _G.UFO_HUBX_KEY_PERM == true then return true end
    local st = _readState()
    if st and st.permanent==true then return true end
    return false
end

-- ============= Re-open Key UI on Expiry ====================
local function _openKeyUI()
    -- Use public APIs if available; otherwise fallback to URL loader
    if _G and _G.UFO and type(_G.UFO.ShowKeyUI)=="function" then
        return _G.UFO.ShowKeyUI()
    end
    if type(_G.UFO_RequestOpenKeyUI)=="function" then
        return _G.UFO_RequestOpenKeyUI()
    end
    local url = rawget(_G, "UFO_KEY_UI_URL")
    if type(url)=="string" and #url>0 then
        local ok, body
        if http and http.request then
            local resOk, res = pcall(http.request, {Url=url, Method="GET"})
            if resOk and res and (res.Body or res.body) then ok, body = true, (res.Body or res.body) end
        end
        if (not ok) and syn and syn.request then
            local resOk, res = pcall(syn.request, {Url=url, Method="GET"})
            if resOk and res and (res.Body or res.body) then ok, body = true, (res.Body or res.body) end
        end
        if (not ok) then
            local got, b = pcall(function() return game:HttpGet(url) end)
            if got and b then ok, body = true, b end
        end
        if ok and body then
            local f, e = loadstring(body, "UFO_Key_Compat")
            if f then pcall(f) else warn("[UFO-EXPIRY] load compat failed:", e) end
        else
            warn("[UFO-EXPIRY] fetch compat failed, set _G.UFO_KEY_UI_URL properly")
        end
    else
        warn("[UFO-EXPIRY] No way to open Key UI (set _G.UFO_KEY_UI_URL or provide UFO.ShowKeyUI)")
    end
end

local function _clearFlags()
    if _G then
        _G.UFO_HUBX_KEY_OK = false
        _G.UFO_KEY_OK      = false
        _G.UFOX_KEY_OK     = false
        -- don't nuke saved key text; only mark invalid
        _G.UFO_KeyExpiresAt = nil
    end
end

local _RUN = true
local function _loop()
    while _RUN do
        task.wait(POLL_SEC)
        if _isPermanent() then
            -- Permanent key: nothing to do
            goto continue
        end
        local exp = _getExpiresAt()
        if exp and type(exp)=="number" then
            local now = _now()
            local threshold = exp - (GRACE_SEC or 0)
            if now >= threshold then
                log("Key expired (or in grace) → re-open Key UI")
                -- Broadcast "expired" event if present
                if _G and _G.UFO_KeyEvent and _G.UFO_KeyEvent.Fire then
                    pcall(function() _G.UFO_KeyEvent:Fire("expired", _getSavedKey(), exp) end)
                end
                _clearFlags()
                -- Delete state file to force re-auth
                _deleteState()
                -- Ensure UI appears
                _G.UFO_ForceKeyUI = true
                task.defer(_openKeyUI)
            end
        end
        ::continue::
    end
end

-- ============= Public Controls ============================
_G.UFO_StartExpiryWatcher = _G.UFO_StartExpiryWatcher or function()
    if _G.__UFO_EXPIRY_ACTIVE then return end
    _G.__UFO_EXPIRY_ACTIVE = true
    _RUN = true
    task.spawn(_loop)
    log(("started (poll=%ss, grace=%ss)"):format(tostring(POLL_SEC), tostring(GRACE_SEC)))
end

_G.UFO_StopExpiryWatcher = _G.UFO_StopExpiryWatcher or function()
    _RUN = false
    _G.__UFO_EXPIRY_ACTIVE = false
    log("stopped")
end

-- Auto-start by default (can be disabled by setting getgenv().UFO_DISABLE_EXPIRY_WATCHER=true before load)
if not (getgenv and getgenv().UFO_DISABLE_EXPIRY_WATCHER) then
    _G.UFO_StartExpiryWatcher()
end
--========================================================

]===], "UFO_HUB_X_Key_Expiry_Watcher.lua")

-- (4) Load MAX Boot from GitHub (no edits needed)
local function __ufo_http_get(url)
    if http and http.request then
        local ok,res = pcall(http.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    if syn and syn.request then
        local ok,res = pcall(syn.request, {Url=url, Method="GET"})
        if ok and res and (res.Body or res.body) then return true,(res.Body or res.body) end
    end
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return true,body end
    return false,"http_failed"
end

local MAX_URL = "https://raw.githubusercontent.com/UFO-HUB-X-Studio/UFO-HUB-X-MAX/refs/heads/main/Script.lua"
local ok, src = __ufo_http_get(MAX_URL)
if not ok then
    warn("[UFO-BOOT] Fetch MAX failed. Check internet or URL:", MAX_URL)
else
    __ufo_run(src, "UFO_MAX_Script.lua")
end
--========================================================
