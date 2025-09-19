-- ==== UFO: FORCE SHOW PATCH (วางท้ายไฟล์) ====
local Players = game:GetService("Players")
local CG = game:GetService("CoreGui")

local function _ufo_force_parent(sg)
    -- บังคับ Parent ตามลำดับ: gethui -> CoreGui -> PlayerGui
    local ok = false
    if gethui then ok = pcall(function() sg.Parent = gethui() end) end
    if not ok or not sg.Parent then
        ok = pcall(function() sg.Parent = CG end)
    end
    if (not ok) or (not sg.Parent) then
        local pg = Players.LocalPlayer and (Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Players.LocalPlayer:WaitForChild("PlayerGui", 2))
        if pg then sg.Parent = pg end
    end
end

-- ถ้า UI ยังไม่อยู่ ให้สร้างหรือบูตใหม่ทันที
task.defer(function()
    local sg = (gethui and gethui():FindFirstChild("UFOHubX_KeyUI"))
           or CG:FindFirstChild("UFOHubX_KeyUI")
           or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChild("UFOHubX_KeyUI"))

    if not sg then
        -- กรณีฟังก์ชันบูตอยู่ชื่อ _ufo_boot ให้เรียกซ้ำ
        if typeof(_ufo_boot) == "function" then
            local ok,err = pcall(_ufo_boot)
            if not ok then warn("[UFO] re-boot error: ", err) end
            -- หาใหม่หลังบูต
            task.wait(0.1)
            sg = (gethui and gethui():FindFirstChild("UFOHubX_KeyUI")) or CG:FindFirstChild("UFOHubX_KeyUI")
        end
    end
    if sg then
        _ufo_force_parent(sg)
        sg.Enabled = true
        sg.IgnoreGuiInset = true
        print("[UFO] UI forced visible.")
    else
        -- ถ้ายังไม่เจอเลย สร้าง fallback หน้าต่างเล็กๆ เพื่อยืนยันว่า GUI แสดงได้
        local F = Instance.new("ScreenGui")
        F.Name = "UFO_Fallback_Probe"
        _ufo_force_parent(F)
        local L = Instance.new("TextLabel", F)
        L.Size = UDim2.fromOffset(360, 36)
        L.Position = UDim2.fromScale(0.5, 0.12)
        L.AnchorPoint = Vector2.new(0.5,0.5)
        L.BackgroundColor3 = Color3.fromRGB(30,30,30)
        L.TextColor3 = Color3.new(1,1,1)
        L.Font = Enum.Font.GothamBold
        L.TextSize = 16
        L.Text = "UFO UI fallback probe — GUI แสดงได้"
        print("[UFO] Fallback probe shown (หมายความว่า UI หลักไม่บูต ให้เช็ค error ด้านล่าง).")
    end
end)
-- ==== END FORCE SHOW PATCH ====
