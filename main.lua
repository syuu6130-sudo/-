--// 暗殺者対保安官2 完全版 v4 - パート1/2 (メインシステム) //--
-- 作者: @syu_u0316 --
-- PC/スマホ完全対応 & AI自動操作 --

-- ========== サービス読み込み ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== デバイス検出 ==========
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local deviceType = isMobile and "📱モバイル" or "🖥️PC"

print("========================================")
print("暗殺者対保安官2 完全版 v4")
print("デバイス: " .. deviceType)
print("作者: @syu_u0316")
print("========================================")

-- ========== グローバル設定変数 ==========
_G.AS2Config = {
    -- 戦闘設定
    softAimEnabled = false,
    autoAimEnabled = false,
    autoShootEnabled = false,
    silentAimEnabled = false,
    triggerBotEnabled = false,
    
    -- AI設定
    aiAutoPlayEnabled = false,
    
    -- その他
    autoEquipEnabled = true,
    flyEnabled = false,
    circleEnabled = false,
    magicCircleEnabled = false,
    
    -- 数値設定
    softAimStrength = 0.3,
    flySpeed = 50,
    aimPart = "Head",
    shootDelay = 0.08,
    burstCount = 1,
    circleRadius = 120,
    
    -- AI詳細設定
    ai = {
        aimSmoothing = 0.15,
        reactionTime = 0.2,
        searchInterval = 0.5,
        moveRandomness = 0.3,
        shootAccuracy = 0.9,
        idleMovement = true,
        strafeDirection = 1,
        lastTargetSwitch = 0,
        lastMoveUpdate = 0
    }
}

-- ========== 内部変数 ==========
local lastShootTime = 0
local isShootingActive = false
local weaponData = {
    currentTool = nil,
    remotes = {}
}

-- ========== ログシステム ==========
local function log(msg)
    print("[AS2] " .. msg)
end

-- ========== 武器検出システム ==========
local function deepScanTool(tool)
    log("🔍 武器スキャン: " .. tool.Name)
    weaponData.remotes = {}
    
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            table.insert(weaponData.remotes, desc)
        end
    end
    
    log("📊 Remote数: " .. #weaponData.remotes)
end

local function getEquippedWeapon()
    if not player.Character then return nil end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    
    if tool and tool ~= weaponData.currentTool then
        weaponData.currentTool = tool
        deepScanTool(tool)
    end
    
    return tool
end

local function autoEquipWeapon()
    if not _G.AS2Config.autoEquipEnabled then return getEquippedWeapon() end
    
    if not getEquippedWeapon() then
        for _, item in ipairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:EquipTool(item)
                    task.wait(0.15)
                    return item
                end
            end
        end
    end
    return getEquippedWeapon()
end

-- ========== PC/スマホ完全対応射撃システム ==========
function shootWeaponUniversal()
    if isShootingActive then return false end
    isShootingActive = true
    
    local tool = getEquippedWeapon()
    if not tool then
        isShootingActive = false
        return false
    end
    
    local successCount = 0
    
    -- === PC専用射撃 ===
    if not isMobile then
        task.spawn(function()
            if pcall(function() tool:Activate() end) then
                successCount = successCount + 1
            end
        end)
        
        task.spawn(function()
            if pcall(function()
                mouse1press()
                task.wait(0.05)
                mouse1release()
            end) then
                successCount = successCount + 1
            end
        end)
    end
    
    -- === モバイル専用射撃 ===
    if isMobile then
        task.spawn(function()
            local viewportSize = Camera.ViewportSize
            local centerX = viewportSize.X / 2
            local centerY = viewportSize.Y / 2
            
            pcall(function()
                VirtualInputManager:SendTouchEvent(0, centerX, centerY)
                task.wait(0.1)
                VirtualInputManager:SendTouchEvent(2, centerX, centerY)
            end)
        end)
        
        task.spawn(function()
            local viewportSize = Camera.ViewportSize
            local shootX = viewportSize.X * 0.85
            local shootY = viewportSize.Y * 0.75
            
            pcall(function()
                VirtualInputManager:SendTouchEvent(0, shootX, shootY)
                task.wait(0.1)
                VirtualInputManager:SendTouchEvent(2, shootX, shootY)
            end)
        end)
    end
    
    -- === 共通射撃（PC/モバイル両対応）===
    task.spawn(function()
        for _, remote in ipairs(weaponData.remotes) do
            if remote:IsA("RemoteEvent") then
                pcall(function()
                    remote:FireServer(mouse.Hit.Position)
                    remote:FireServer(mouse.Hit)
                    remote:FireServer()
                end)
            end
        end
    end)
    
    task.spawn(function()
        pcall(function()
            local pos = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end)
    end)
    
    task.spawn(function()
        pcall(function()
            for _, con in ipairs(getconnections(tool.Activated)) do
                con:Fire()
            end
        end)
    end)
    
    task.wait(0.15)
    isShootingActive = false
    return true
end

-- ========== 敵検出システム ==========
local function isVisible(target)
    local origin = Camera.CFrame.Position
    local direction = (target.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRay(ray, player.Character, false, true)
    return (not hit or hit:IsDescendantOf(target.Parent))
end

local function isEnemy(plr)
    if not player.Team or not plr.Team then return true end
    return plr.Team ~= player.Team
end

function getClosestEnemy()
    local closest, dist = nil, math.huge
    local camCF = Camera.CFrame
    local camDir = camCF.LookVector
    local maxAngle = math.rad(70)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(_G.AS2Config.aimPart) or p.Character:FindFirstChild("Head")
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

-- ========== AI自動操作システム ==========
local function getRandomOffset(magnitude)
    return Vector3.new(
        (math.random() - 0.5) * magnitude,
        (math.random() - 0.5) * magnitude,
        (math.random() - 0.5) * magnitude
    )
end

local function performStrafeMovement()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local currentPos = player.Character.HumanoidRootPart.Position
    local camRight = Camera.CFrame.RightVector
    
    if math.random() < 0.1 then
        _G.AS2Config.ai.strafeDirection = -_G.AS2Config.ai.strafeDirection
    end
    
    local strafePos = currentPos + (camRight * _G.AS2Config.ai.strafeDirection * 5)
    humanoid:MoveTo(strafePos)
end

local function performIdleMovement()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local currentPos = player.Character.HumanoidRootPart.Position
    local randomMove = currentPos + getRandomOffset(3)
    humanoid:MoveTo(randomMove)
end

local function aiSmoothAim(targetPart)
    if not targetPart then return end
    
    local targetPos = targetPart.Position
    local randomOffset = getRandomOffset((1 - _G.AS2Config.ai.shootAccuracy) * 2)
    local aimTarget = targetPos + randomOffset
    
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, aimTarget)
    
    Camera.CFrame = currentCF:Lerp(targetCF, _G.AS2Config.ai.aimSmoothing)
end

local function aiAutoPlay()
    if not _G.AS2Config.aiAutoPlayEnabled then return end
    
    local currentTime = tick()
    
    if currentTime - _G.AS2Config.ai.lastTargetSwitch > _G.AS2Config.ai.searchInterval then
        local target = getClosestEnemy()
        
        if target then
            local targetPart = target:FindFirstChild(_G.AS2Config.aimPart) or target:FindFirstChild("Head")
            
            if targetPart then
                task.wait(_G.AS2Config.ai.reactionTime * math.random(0.8, 1.2))
                
                aiSmoothAim(targetPart)
                
                if math.random() < 0.7 then
                    performStrafeMovement()
                end
                
                if currentTime - lastShootTime > _G.AS2Config.shootDelay then
                    if _G.AS2Config.autoEquipEnabled then
                        autoEquipWeapon()
                    end
                    
                    if math.random() < _G.AS2Config.ai.shootAccuracy then
                        shootWeaponUniversal()
                        lastShootTime = currentTime
                    end
                end
                
                _G.AS2Config.ai.lastTargetSwitch = currentTime
            end
        else
            if _G.AS2Config.ai.idleMovement and currentTime - _G.AS2Config.ai.lastMoveUpdate > 2 then
                performIdleMovement()
                _G.AS2Config.ai.lastMoveUpdate = currentTime
            end
        end
    end
end

-- ========== Silent Aim ==========
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if _G.AS2Config.silentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(_G.AS2Config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if typeof(args[1]) == "Vector3" then
                    args[1] = targetPart.Position
                elseif typeof(args[1]) == "CFrame" then
                    args[1] = targetPart.CFrame
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

mt.__index = newcclosure(function(self, key)
    if _G.AS2Config.silentAimEnabled and (key == "Hit" or key == "Target") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(_G.AS2Config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                return key == "Hit" and targetPart.CFrame or targetPart
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- ========== メインループ ==========
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
    -- AI自動操作
    if _G.AS2Config.aiAutoPlayEnabled then
        aiAutoPlay()
        return
    end
    
    -- 通常エイム
    if _G.AS2Config.softAimEnabled or _G.AS2Config.autoAimEnabled then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(_G.AS2Config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if _G.AS2Config.softAimEnabled then
                    local newCF = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPart.Position), _G.AS2Config.softAimStrength)
                    Camera.CFrame = newCF
                end
                if _G.AS2Config.autoAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
                
                -- 自動射撃
                if _G.AS2Config.autoShootEnabled and currentTime - lastShootTime > _G.AS2Config.shootDelay then
                    if _G.AS2Config.autoEquipEnabled then
                        autoEquipWeapon()
                    end
                    
                    task.spawn(function()
                        for i = 1, _G.AS2Config.burstCount do
                            if shootWeaponUniversal() then
                                lastShootTime = currentTime
                            end
                            if _G.AS2Config.burstCount > 1 then
                                task.wait(0.08)
                            end
                        end
                    end)
                end
            end
        end
    end
end)

-- ========== Fly機能 ==========
local bodyVel
local function toggleFly()
    if _G.AS2Config.flyEnabled then
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
    if _G.AS2Config.flyEnabled and bodyVel then
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        bodyVel.Velocity = moveDir * _G.AS2Config.flySpeed
    end
end)

-- ========== 虹色の円 ==========
local circleFolder = Instance.new("Folder")
circleFolder.Name = "DecorativeCircle"
circleFolder.Parent = game.CoreGui

local function createCircle()
    for _,v in ipairs(circleFolder:GetChildren()) do v:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Parent = circleFolder

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 240)
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
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(255, 255, 255)
end

RunService.RenderStepped:Connect(function()
    if _G.AS2Config.circleEnabled then
        local hue = (tick() * 0.2) % 1
        local rainbowColor = Color3.fromHSV(hue, 1, 1)

        for _,screen in ipairs(circleFolder:GetChildren()) do
            for _,circle in ipairs(screen:GetChildren()) do
                local stroke = circle:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = rainbowColor end
            end
        end
    end
end)

_G.toggleFly = toggleFly
_G.createCircle = createCircle

log("✅ パート1/2 読み込み完了")
log("次にパート2/2（UIメニュー）を実行してください")
--// 暗殺者対保安官2 完全版 v4 - パート2/2 (UIメニュー) //--
-- 作者: @syu_u0316 --
-- ※パート1を先に実行してください※

-- ========== パート1確認 ==========
if not _G.AS2Config then
    error("⚠️ エラー: パート1/2を先に実行してください！")
    return
end

-- ========== Rayfield読み込み ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
local deviceType = isMobile and "📱モバイル" or "🖥️PC"

-- ========== ウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
   Name = "暗殺者対保安官2 完全版 v4",
   LoadingTitle = deviceType .. " 対応版",
   LoadingSubtitle = "by @syu_u0316",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "AssassinSheriff2_v4",
      FileName = "config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvite",
      RememberJoins = true
   },
   KeySystem = false
})

-- ========== タブ作成 ==========
local AITab = Window:CreateTab("🤖 AI自動操作", nil)
local CombatTab = Window:CreateTab("⚔️ 戦闘", nil)
local ShootTab = Window:CreateTab("🔫 射撃", nil)
local MovementTab = Window:CreateTab("🏃 移動", nil)
local VisualTab = Window:CreateTab("👁️ 視覚", nil)

-- ========== AI自動操作タブ ==========
AITab:CreateParagraph({
   Title = "🤖 AI自動操作について", 
   Content = "AIが完全自動で敵を探し、エイムし、射撃し、ストレイフ移動します。人間らしい動きでBANリスク軽減。"
})

local AIPlayToggle = AITab:CreateToggle({
   Name = "🤖 AI自動プレイ（完全自動）",
   CurrentValue = false,
   Flag = "AIPlayToggle",
   Callback = function(Value)
      _G.AS2Config.aiAutoPlayEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "AI自動操作 有効",
             Content = "人間らしい動きで完全自動プレイ開始！",
             Duration = 5,
             Image = 4483362458,
          })
      else
          Rayfield:Notify({
             Title = "AI自動操作 停止",
             Content = "手動操作に切り替えました",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

local AIAimSmoothSlider = AITab:CreateSlider({
   Name = "AIエイムの滑らかさ",
   Range = {0.05, 0.5},
   Increment = 0.05,
   CurrentValue = 0.15,
   Flag = "AIAimSmoothSlider",
   Callback = function(Value)
      _G.AS2Config.ai.aimSmoothing = Value
   end,
})

local AIReactionSlider = AITab:CreateSlider({
   Name = "AI反応速度 (秒)",
   Range = {0.1, 1.0},
   Increment = 0.1,
   CurrentValue = 0.2,
   Flag = "AIReactionSlider",
   Callback = function(Value)
      _G.AS2Config.ai.reactionTime = Value
   end,
})

local AIAccuracySlider = AITab:CreateSlider({
   Name = "AI射撃精度",
   Range = {0.5, 1.0},
   Increment = 0.05,
   CurrentValue = 0.9,
   Flag = "AIAccuracySlider",
   Callback = function(Value)
      _G.AS2Config.ai.shootAccuracy = Value
   end,
})

local AIIdleToggle = AITab:CreateToggle({
   Name = "待機中の自然な動き",
   CurrentValue = true,
   Flag = "AIIdleToggle",
   Callback = function(Value)
      _G.AS2Config.ai.idleMovement = Value
   end,
})

AITab:CreateParagraph({
   Title = "⚙️ AI設定のヒント", 
   Content = "エイム滑らかさ: 低いほど人間的 | 反応速度: 高いほど自然 | 精度: 0.9推奨"
})

-- ========== 戦闘タブ ==========
local SilentAimToggle = CombatTab:CreateToggle({
   Name = "🎯 Silent Aim（最強）",
   CurrentValue = false,
   Flag = "SilentAimToggle",
   Callback = function(Value)
      _G.AS2Config.silentAimEnabled = Value
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
   Name = "SoftAim（エイムアシスト）",
   CurrentValue = false,
   Flag = "SoftAimToggle",
   Callback = function(Value)
      _G.AS2Config.softAimEnabled = Value
   end,
})

local SoftAimSlider = CombatTab:CreateSlider({
   Name = "SoftAim強度",
   Range = {0, 1},
   Increment = 0.05,
   CurrentValue = 0.3,
   Flag = "SoftAimSlider",
   Callback = function(Value)
      _G.AS2Config.softAimStrength = Value
   end,
})

local AutoAimToggle = CombatTab:CreateToggle({
   Name = "AutoAim（完全自動エイム）",
   CurrentValue = false,
   Flag = "AutoAimToggle",
   Callback = function(Value)
      _G.AS2Config.autoAimEnabled = Value
   end,
})

local AimPartDropdown = CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "UpperTorso", "HumanoidRootPart"},
   CurrentOption = "Head",
   Flag = "AimPartDropdown",
   Callback = function(Option)
      _G.AS2Config.aimPart = Option
   end,
})

local TriggerBotToggle = CombatTab:CreateToggle({
   Name = "⚡ TriggerBot（視点内自動射撃）",
   CurrentValue = false,
   Flag = "TriggerBotToggle",
   Callback = function(Value)
      _G.AS2Config.triggerBotEnabled = Value
   end,
})

-- ========== 射撃設定タブ ==========
ShootTab:CreateParagraph({
   Title = "🔫 PC/スマホ完全対応", 
   Content = "デバイス: " .. deviceType .. " | 自動検出済み | 最適化された射撃システム"
})

local AutoShootToggle = ShootTab:CreateToggle({
   Name = "🔫 自動射撃（" .. deviceType .. "対応）",
   CurrentValue = false,
   Flag = "AutoShootToggle",
   Callback = function(Value)
      _G.AS2Config.autoShootEnabled = Value
      if Value then
          Rayfield:Notify({
             Title = "自動射撃 有効",
             Content = deviceType .. "用最適化システム起動！",
             Duration = 3,
             Image = 4483362458,
          })
      end
   end,
})

local AutoEquipToggle = ShootTab:CreateToggle({
   Name = "🔧 自動武器装備",
   CurrentValue = true,
   Flag = "AutoEquipToggle",
   Callback = function(Value)
      _G.AS2Config.autoEquipEnabled = Value
   end,
})

local ShootDelaySlider = ShootTab:CreateSlider({
   Name = "射撃間隔（秒）",
   Range = {0.05, 0.5},
   Increment = 0.01,
   CurrentValue = 0.08,
   Flag = "ShootDelaySlider",
   Callback = function(Value)
      _G.AS2Config.shootDelay = Value
   end,
})

local BurstCountSlider = ShootTab:CreateSlider({
   Name = "バースト弾数",
   Range = {1, 5},
   Increment = 1,
   CurrentValue = 1,
   Flag = "BurstCountSlider",
   Callback = function(Value)
      _G.AS2Config.burstCount = Value
   end,
})

local TestShootButton = ShootTab:CreateButton({
   Name = "🧪 射撃テスト",
   Callback = function()
      local success = shootWeaponUniversal()
      Rayfield:Notify({
         Title = success and "✅ 射撃成功" or "❌ 射撃失敗",
         Content = success and "武器が正常に発射されました" or "武器を装備してください",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

local RescanButton = ShootTab:CreateButton({
   Name = "🔍 武器を再スキャン",
   Callback = function()
      local tool = getEquippedWeapon()
      if tool then
          Rayfield:Notify({
             Title = "スキャン完了",
             Content = "武器: " .. tool.Name,
             Duration = 2,
             Image = 4483362458,
          })
      else
          Rayfield:Notify({
             Title = "エラー",
             Content = "武器が装備されていません",
             Duration = 2,
             Image = 4483362458,
          })
      end
   end,
})

-- ========== 移動タブ ==========
local FlyToggle = MovementTab:CreateToggle({
   Name = "✈️ Fly（飛行）",
   CurrentValue = false,
   Flag = "FlyToggle",
   Callback = function(Value)
      _G.AS2Config.flyEnabled = Value
      _G.toggleFly()
   end,
})

local FlySpeedSlider = MovementTab:CreateSlider({
   Name = "飛行速度",
   Range = {10, 200},
   Increment = 5,
   CurrentValue = 50,
   Flag = "FlySpeedSlider",
   Callback = function(Value)
      _G.AS2Config.flySpeed = Value
   end,
})

MovementTab:CreateParagraph({
   Title = "✈️ 飛行の操作方法", 
   Content = "PC: WASD移動 | Space上昇 | Ctrl降下 | モバイル: 画面タッチで移動"
})

-- ========== 視覚タブ ==========
local CircleToggle = VisualTab:CreateToggle({
   Name = "🌈 中央に虹色の円",
   CurrentValue = false,
   Flag = "CircleToggle",
   Callback = function(Value)
      _G.AS2Config.circleEnabled = Value
      if Value then
          _G.createCircle()
      else
          for _,v in ipairs(game.CoreGui.DecorativeCircle:GetChildren()) do 
              v:Destroy() 
          end
      end
   end,
})

VisualTab:CreateParagraph({
   Title = "ℹ️ ESP機能について", 
   Content = "ESP機能は即座にBANされるため削除されました。代わりにSilent AimとAI自動操作をご利用ください。"
})

-- ========== 通知 ==========
Rayfield:Notify({
   Title = "✅ 読み込み完了",
   Content = "暗殺者対保安官2 完全版 v4 | デバイス: " .. deviceType,
   Duration = 5,
   Image = 4483362458,
})

print("========================================")
print("✅ パート2/2（UIメニュー）読み込み完了")
print("🎮 デバイス: " .. deviceType)
print("🤖 AI自動操作: 利用可能")
print("🔫 PC/スマホ対応射撃: 利用可能")
print("========================================")
print("📝 使い方:")
print("1. AI自動操作タブで完全自動プレイ")
print("2. または戦闘タブで手動エイム設定")
print("3. 射撃タブで自動射撃を有効化")
print("========================================")
