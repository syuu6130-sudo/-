--// Rayfield統合版 - 暗殺者対保安官2 (超精密オートエイム v2) //--
-- 作者: @syu_u0316 --
-- ESP削除 & 自動射撃完全リメイク版 --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== 設定 ==========
local softAimEnabled = false
local autoAimEnabled = false
local autoShootEnabled = false
local flyEnabled = false
local circleEnabled = false
local magicCircleEnabled = false
local silentAimEnabled = false
local triggerBotEnabled = false
local autoEquipEnabled = false

local softAimStrength = 0.3
local flySpeed = 50
local aimPart = "Head"
local shootDelay = 0.05
local burstCount = 1

local currentLockTarget = nil
local circleRadius = 120
local lastShootTime = 0

-- ========== 武器検出システム (超精密版) ==========
local weaponCache = {}
local remoteCache = {}

local function findShootRemote(tool)
    if remoteCache[tool] then
        return remoteCache[tool]
    end
    
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            local name = desc.Name:lower()
            if name:find("fire") or name:find("shoot") or name:find("gun") or name:find("attack") then
                remoteCache[tool] = desc
                return desc
            end
        end
    end
    
    -- フォールバック: 最初のRemoteEventを使用
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            remoteCache[tool] = desc
            return desc
        end
    end
    
    return nil
end

local function getEquippedWeapon()
    if not player.Character then return nil end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then
        weaponCache.current = tool
        return tool
    end
    return nil
end

local function autoEquipWeapon()
    if autoEquipEnabled and not getEquippedWeapon() then
        for _, item in ipairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:EquipTool(item)
                    task.wait(0.1)
                    return item
                end
            end
        end
    end
    return getEquippedWeapon()
end

-- ========== 自動射撃システム (多層アプローチ) ==========
local function shootWeapon()
    local tool = getEquippedWeapon()
    if not tool then return false end
    
    local success = false
    
    -- 方法1: Tool:Activate()
    pcall(function()
        tool:Activate()
        success = true
    end)
    
    -- 方法2: RemoteEvent発火
    local remote = findShootRemote(tool)
    if remote then
        pcall(function()
            remote:FireServer()
            success = true
        end)
    end
    
    -- 方法3: マウスクリックシミュレーション
    pcall(function()
        mouse1press()
        task.wait(0.05)
        mouse1release()
        success = true
    end)
    
    -- 方法4: Handle検索して直接発火
    local handle = tool:FindFirstChild("Handle")
    if handle then
        for _, v in ipairs(handle:GetChildren()) do
            if v:IsA("Sound") and v.Name:lower():find("fire") then
                pcall(function()
                    v:Play()
                    success = true
                end)
            end
        end
    end
    
    return success
end

-- ========== トリガーボット (視点内の敵を検出して自動射撃) ==========
local function isLookingAtEnemy()
    local target = getClosestEnemy()
    if not target then return false end
    
    local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
    if not targetPart then return false end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance < 100
end

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
function getClosestEnemy()
    local closest, dist = nil, math.huge
    local camCF = Camera.CFrame
    local camDir = camCF.LookVector
    local maxAngle = math.rad(70)

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

-- ========== Silent Aim (マウス位置偽装) ==========
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if silentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if typeof(args[1]) == "Vector3" then
                    args[1] = targetPart.Position
                elseif typeof(args[1]) == "CFrame" then
                    args[1] = targetPart.CFrame
                elseif typeof(args[1]) == "Instance" then
                    args[1] = targetPart
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

mt.__index = newcclosure(function(self, key)
    if silentAimEnabled and (key == "Hit" or key == "Target") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if key == "Hit" then
                    return targetPart.CFrame
                else
                    return targetPart
                end
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- ========== メインループ (最適化版) ==========
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
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
                
                -- 自動射撃 (改良版)
                if autoShootEnabled and currentTime - lastShootTime > shootDelay then
                    if autoEquipEnabled then
                        autoEquipWeapon()
                    end
                    
                    for i = 1, burstCount do
                        if shootWeapon() then
                            lastShootTime = currentTime
                        end
                        if burstCount > 1 then
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end
    
    -- 魔法の円での自動エイム
    if magicCircleEnabled and circleEnabled then
        local target, targetPart = getEnemyInCircle()
        if target and targetPart then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            
            if currentTime - lastShootTime > shootDelay then
                if autoEquipEnabled then
                    autoEquipWeapon()
                end
                
                for i = 1, burstCount do
                    if shootWeapon() then
                        lastShootTime = currentTime
                    end
                    if burstCount > 1 then
                        task.wait(0.05)
                    end
                end
            end
        end
    end
    
    -- トリガーボット
    if triggerBotEnabled and isLookingAtEnemy() then
        if currentTime - lastShootTime > shootDelay then
            if autoEquipEnabled then
                autoEquipWeapon()
            end
            
            if shootWeapon() then
                lastShootTime = currentTime
            end
        end
    end
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

-- ========== Rayfieldウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
   Name = "暗殺者対保安官2 v2 | @syu_u0316",
   LoadingTitle = "超精密統合メニュー",
   LoadingSubtitle = "by @syu_u0316 - ESP削除版",
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
local ShootTab = Window:CreateTab("射撃設定", nil)
local MovementTab = Window:CreateTab("移動", nil)
local VisualTab = Window:CreateTab("視覚", nil)

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

local AimPartDropdown = CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "UpperTorso", "HumanoidRootPart"},
   CurrentOption = "Head",
   Flag = "AimPartDropdown",
   Callback = function(Option)
      aimPart = Option
   end,
})

local TriggerBotToggle = CombatTab:CreateToggle({
   Name = "⚡ TriggerBot (視点内自動射撃)",
   CurrentValue = false,
   Flag = "TriggerBotToggle",
   Callback = function(Value)
      triggerBotEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "TriggerBot 有効",
             Content = "敵を見るだけで自動射撃！",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

-- ========== 射撃設定タブ ==========
local AutoShootToggle = ShootTab:CreateToggle({
   Name = "🔫 自動射撃",
   CurrentValue = false,
   Flag = "AutoShootToggle",
   Callback = function(Value)
      autoShootEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "自動射撃 有効",
             Content = "多層システムで確実に発射！",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

local AutoEquipToggle = ShootTab:CreateToggle({
   Name = "🔧 自動武器装備",
   CurrentValue = false,
   Flag = "AutoEquipToggle",
   Callback = function(Value)
      autoEquipEnabled = Value
   end,
})

local ShootDelaySlider = ShootTab:CreateSlider({
   Name = "射撃間隔 (秒)",
   Range = {0.01, 0.5},
   Increment = 0.01,
   CurrentValue = 0.05,
   Flag = "ShootDelaySlider",
   Callback = function(Value)
      shootDelay = Value
   end,
})

local BurstCountSlider = ShootTab:CreateSlider({
   Name = "バースト弾数",
   Range = {1, 5},
   Increment = 1,
   CurrentValue = 1,
   Flag = "BurstCountSlider",
   Callback = function(Value)
      burstCount = Value
   end,
})

local TestShootButton = ShootTab:CreateButton({
   Name = "🔫 射撃テスト",
   Callback = function()
      autoEquipWeapon()
      local success = shootWeapon()
      Rayfield:Notify({
         Title = success and "射撃成功" or "射撃失敗",
         Content = success and "武器が正常に発射されました" or "武器が見つからないか発射に失敗しました",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

-- ========== 視覚タブ ==========
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

-- ========== 起動通知 ==========
Rayfield:Notify({
   Title = "スクリプト読み込み完了 v2",
   Content = "ESP削除 & 自動射撃超強化版 by @syu_u0316",
   Duration = 5,
   Image = 4483362458,
})

print("暗殺者対保安官2 v2 スクリプト読み込み完了！")
print("ESP機能: 完全削除 (BAN回避)")
print("自動射撃: 多層システム実装")
