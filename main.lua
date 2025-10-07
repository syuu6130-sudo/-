--// Rayfield統合版 - 暗殺者対保安官2 (超精密オートエイム) //--
-- 作者: @syu_u0316 --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== 設定 ==========
local softAimEnabled = false
local autoAimEnabled = false
local autoShootEnabled = false
local espEnabled = false
local flyEnabled = false
local rapidFireEnabled = false
local circleEnabled = false
local magicCircleEnabled = false
local silentAimEnabled = false

local softAimStrength = 0.3
local flySpeed = 50
local aimPart = "Head" -- Head, UpperTorso, HumanoidRootPart

local lockLog = {}
local currentLockTarget = nil
local circleRadius = 120

-- ========== Rayfieldウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
   Name = "暗殺者対保安官2 | @syu_u0316",
   LoadingTitle = "統合メニュー",
   LoadingSubtitle = "by @syu_u0316",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "AssassinSheriff2",
      FileName = "config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false
})

-- ========== タブ作成 ==========
local CombatTab = Window:CreateTab("戦闘", nil)
local VisualTab = Window:CreateTab("視覚", nil)
local MovementTab = Window:CreateTab("移動", nil)
local UtilityTab = Window:CreateTab("その他", nil)

-- ========== チームチェック & 壁判定 ==========
local function isVisible(target)
    local origin = Camera.CFrame.Position
    local direction = (target.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRay(ray, player.Character, false, true)
    return (not hit or hit:IsDescendantOf(target.Parent))
end

local function isEnemy(plr)
    if not player.Team or not plr.Team then
        return true
    end
    return plr.Team ~= player.Team
end

-- ========== 最も近い敵を取得 ==========
local function getClosestEnemy()
    local closest, dist = nil, math.huge
    local camCF = Camera.CFrame
    local camDir = camCF.LookVector
    local maxAngle = math.rad(60)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(aimPart) or p.Character:FindFirstChild("Head")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetPart and humanoid and humanoid.Health > 0 then
                local dir = (targetPart.Position - camCF.Position).Unit
                local dot = camDir:Dot(dir)
                local angle = math.acos(math.clamp(dot, -1, 1))
                if angle < maxAngle then
                    local mag = (targetPart.Position - camCF.Position).Magnitude
                    if mag < dist and isVisible(targetPart) then
                        closest = p.Character
                        dist = mag
                    end
                end
            end
        end
    end

    return closest
end

-- ========== 円内の敵を取得 ==========
local function isInMagicCircle(screenPos)
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    
    local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    if isMobile then
        centerY = viewportSize.Y * 0.4
    end
    
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance <= circleRadius
end

local function getEnemyInCircle()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(aimPart) or p.Character:FindFirstChild("Head")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetPart and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and isInMagicCircle(Vector2.new(screenPos.X, screenPos.Y)) then
                    return p.Character, targetPart
                end
            end
        end
    end
    return nil, nil
end

-- ========== ESP ==========
local function createESP(char, color)
    if not char:FindFirstChild("HumanoidRootPart") then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0
    highlight.Parent = char
end

local function updateESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if espEnabled then
                if not p.Character:FindFirstChild("ESPHighlight") then
                    local c = isEnemy(p) and Color3.new(1,0,0) or Color3.new(0,1,0)
                    createESP(p.Character,c)
                end
            else
                if p.Character:FindFirstChild("ESPHighlight") then
                    p.Character.ESPHighlight:Destroy()
                end
            end
        end
    end
end

-- ========== 武器検出と自動射撃 ==========
local function getEquippedTool()
    return player.Character and player.Character:FindFirstChildOfClass("Tool")
end

local function autoEquipWeapon()
    if not getEquippedTool() then
        for _, item in ipairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                player.Character.Humanoid:EquipTool(item)
                return item
            end
        end
    end
    return getEquippedTool()
end

local function shootWeapon()
    local tool = getEquippedTool()
    if tool then
        tool:Activate()
        -- Remote検索して発火
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("RemoteEvent") and (v.Name:lower():find("fire") or v.Name:lower():find("shoot")) then
                pcall(function() v:FireServer() end)
            end
        end
    end
end

-- ========== Silent Aim (マウス位置偽装) ==========
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if silentAimEnabled and method == "FireServer" then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                -- 引数を書き換えてヘッドショットを強制
                if typeof(args[1]) == "Vector3" then
                    args[1] = targetPart.Position
                elseif typeof(args[1]) == "Instance" then
                    args[1] = targetPart
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

mt.__index = newcclosure(function(self, key)
    if silentAimEnabled and key == "Hit" then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                return targetPart
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- ========== メインループ ==========
local lastShootTime = 0
local shootCooldown = 0.1

RunService.RenderStepped:Connect(function()
    -- 通常のエイム
    if softAimEnabled or autoAimEnabled then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if softAimEnabled then
                    local newCF = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPart.Position), softAimStrength)
                    Camera.CFrame = newCF
                end
                if autoAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
                
                if autoShootEnabled and tick() - lastShootTime > shootCooldown then
                    autoEquipWeapon()
                    shootWeapon()
                    lastShootTime = tick()
                end
            end
        end
    end
    
    -- 魔法の円での自動エイム
    if magicCircleEnabled and circleEnabled then
        local target, targetPart = getEnemyInCircle()
        if target and targetPart then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            
            if tick() - lastShootTime > shootCooldown then
                autoEquipWeapon()
                shootWeapon()
                lastShootTime = tick()
            end
        end
    end
    
    updateESP()
end)

-- ========== Fly ==========
local bodyVel
local function toggleFly()
    if flyEnabled then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not bodyVel then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
                bodyVel.Parent = player.Character.HumanoidRootPart
            end
        end
    else
        if bodyVel then 
            bodyVel:Destroy() 
            bodyVel = nil 
        end
    end
end

RunService.RenderStepped:Connect(function()
    if flyEnabled and bodyVel then
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        bodyVel.Velocity = moveDir * flySpeed
    end
end)

-- ========== 虹色の円 ==========
local circleFolder = Instance.new("Folder")
circleFolder.Name = "DecorativeCircle"
circleFolder.Parent = game.CoreGui

local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

local function hsvToRgb(h, s, v)
    return Color3.fromHSV(h, s, v)
end

local function createCircle(diameter, thickness)
    for _,v in ipairs(circleFolder:GetChildren()) do v:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "CircleScreen"
    screen.Parent = circleFolder

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, diameter, 0, diameter)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = screen

    if isMobile then
        frame.Position = UDim2.new(0.5, 0, 0.4, 0)
    else
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = thickness or 3
    stroke.Color = Color3.fromRGB(255, 255, 255)

    return frame
end

RunService.RenderStepped:Connect(function()
    if circleEnabled then
        local hue = (tick() * 0.2) % 1
        local rainbowColor = hsvToRgb(hue, 1, 1)

        for _,screen in ipairs(circleFolder:GetChildren()) do
            for _,circle in ipairs(screen:GetChildren()) do
                local stroke = circle:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = rainbowColor end

                local scale = 1 + 0.05 * math.sin(tick() * 2)
                circle.Size = UDim2.new(0, 240 * scale, 0, 240 * scale)

                if isMobile then
                    circle.Position = UDim2.new(0.5, 0, 0.4, 0)
                else
                    circle.Position = UDim2.new(0.5, 0, 0.5, 0)
                end
            end
        end
    end
end)

-- ========== 戦闘タブ ==========
local SilentAimToggle = CombatTab:CreateToggle({
   Name = "🎯 Silent Aim (最強)",
   CurrentValue = false,
   Flag = "SilentAimToggle",
   Callback = function(Value)
      silentAimEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "Silent Aim 有効",
             Content = "撃つだけで自動ヘッドショット！",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

local SoftAimToggle = CombatTab:CreateToggle({
   Name = "SoftAim (エイムアシスト)",
   CurrentValue = false,
   Flag = "SoftAimToggle",
   Callback = function(Value)
      softAimEnabled = Value
   end,
})

local SoftAimSlider = CombatTab:CreateSlider({
   Name = "SoftAim強度",
   Range = {0, 1},
   Increment = 0.05,
   CurrentValue = 0.3,
   Flag = "SoftAimSlider",
   Callback = function(Value)
      softAimStrength = Value
   end,
})

local AutoAimToggle = CombatTab:CreateToggle({
   Name = "AutoAim (完全自動エイム)",
   CurrentValue = false,
   Flag = "AutoAimToggle",
   Callback = function(Value)
      autoAimEnabled = Value
   end,
})

local AutoShootToggle = CombatTab:CreateToggle({
   Name = "🔫 自動射撃",
   CurrentValue = false,
   Flag = "AutoShootToggle",
   Callback = function(Value)
      autoShootEnabled = Value
   end,
})

local AimPartDropdown = CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "UpperTorso", "HumanoidRootPart"},
   CurrentOption = "Head",
   Flag = "AimPartDropdown",
   Callback = function(Option)
      aimPart = Option
   end,
})

-- ========== 視覚タブ ==========
local ESPToggle = VisualTab:CreateToggle({
   Name = "ESP (敵表示)",
   CurrentValue = false,
   Flag = "ESPToggle",
   Callback = function(Value)
      espEnabled = Value
   end,
})

local CircleToggle = VisualTab:CreateToggle({
   Name = "中央に虹色の円",
   CurrentValue = false,
   Flag = "CircleToggle",
   Callback = function(Value)
      circleEnabled = Value
      if circleEnabled then
          createCircle(240, 4)
      else
          for _,v in ipairs(circleFolder:GetChildren()) do v:Destroy() end
      end
   end,
})

local MagicCircleToggle = VisualTab:CreateToggle({
   Name = "⚡ 魔法の円 (円内オート)",
   CurrentValue = false,
   Flag = "MagicCircleToggle",
   Callback = function(Value)
      magicCircleEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "魔法の円 有効",
             Content = "円内の敵に自動エイム＆射撃",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

-- ========== 移動タブ ==========
local FlyToggle = MovementTab:CreateToggle({
   Name = "Fly (飛行)",
   CurrentValue = false,
   Flag = "FlyToggle",
   Callback = function(Value)
      flyEnabled = Value
      toggleFly()
   end,
})

local FlySpeedSlider = MovementTab:CreateSlider({
   Name = "飛行速度",
   Range = {10, 200},
   Increment = 5,
   CurrentValue = 50,
   Flag = "FlySpeedSlider",
   Callback = function(Value)
      flySpeed = Value
   end,
})

-- ========== その他タブ ==========
local ResetButton = UtilityTab:CreateButton({
   Name = "設定をリセット",
   Callback = function()
      silentAimEnabled = false
      softAimEnabled = false
      autoAimEnabled = false
      autoShootEnabled = false
      espEnabled = false
      flyEnabled = false
      circleEnabled = false
      magicCircleEnabled = false
      
      SilentAimToggle:Set(false)
      SoftAimToggle:Set(false)
      AutoAimToggle:Set(false)
      AutoShootToggle:Set(false)
      ESPToggle:Set(false)
      FlyToggle:Set(false)
      CircleToggle:Set(false)
      MagicCircleToggle:Set(false)
      
      toggleFly()
      
      Rayfield:Notify({
         Title = "リセット完了",
         Content = "すべての機能がオフになりました",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

-- ========== 起動通知 ==========
Rayfield:Notify({
   Title = "スクリプト読み込み完了",
   Content = "暗殺者対保安官2 メニュー by @syu_u0316",
   Duration = 5,
   Image = 4483362458,
})

print("暗殺者対保安官2 スクリプト読み込み完了！")
