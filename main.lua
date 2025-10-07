--// Rayfield統合版 - 暗殺者対保安官2 //--
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
local autoLockEnabled = false
local espEnabled = false
local flyEnabled = false
local rapidFireEnabled = false
local circleEnabled = false

local softAimStrength = 0.3
local flySpeed = 50

local lockLog = {}
local currentLockTarget = nil

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

-- ========== ヒットボックス拡張 ==========
local function expandHitbox(char)
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.Size = Vector3.new(5,5,5)
        char.HumanoidRootPart.Transparency = 0.7
        char.HumanoidRootPart.BrickColor = BrickColor.new("Bright red")
        char.HumanoidRootPart.Material = Enum.Material.Neon
    end
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
local function getClosestEnemy()
    local closest, dist = nil, math.huge
    local camCF = Camera.CFrame
    local camDir = camCF.LookVector
    local maxAngle = math.rad(60)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                local dir = (hrp.Position - camCF.Position).Unit
                local dot = camDir:Dot(dir)
                local angle = math.acos(math.clamp(dot, -1, 1))
                if angle < maxAngle then
                    local mag = (hrp.Position - camCF.Position).Magnitude
                    if mag < dist and isVisible(hrp) then
                        closest = p.Character
                        dist = mag
                    end
                end
            end
        end
    end

    return closest
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

-- ========== メインループ ==========
RunService.RenderStepped:Connect(function()
    if softAimEnabled or autoAimEnabled or autoLockEnabled then
        local target = getClosestEnemy()
        if target and target:FindFirstChild("HumanoidRootPart") then
            if softAimEnabled then
                local aimPos = target.HumanoidRootPart.Position
                local newCF = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, aimPos), softAimStrength)
                Camera.CFrame = newCF
            end
            if autoAimEnabled then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.HumanoidRootPart.Position)
            end
            if autoLockEnabled then
                currentLockTarget = target
                if target.Parent and target.Parent:FindFirstChildWhichIsA("Tool") then
                    target.Parent:FindFirstChildWhichIsA("Tool"):Activate()
                end
                lockLog[target.Name] = (lockLog[target.Name] or 0) + 1
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

local AutoLockToggle = CombatTab:CreateToggle({
   Name = "AutoLock (自動射撃)",
   CurrentValue = false,
   Flag = "AutoLockToggle",
   Callback = function(Value)
      autoLockEnabled = Value
   end,
})

local RapidFireToggle = CombatTab:CreateToggle({
   Name = "RapidFire (連射)",
   CurrentValue = false,
   Flag = "RapidFireToggle",
   Callback = function(Value)
      rapidFireEnabled = Value
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
local CSVButton = UtilityTab:CreateButton({
   Name = "ロックログをCSV出力",
   Callback = function()
      print("=== ロックログ ===")
      for name,count in pairs(lockLog) do
          print(name..","..count)
      end
      Rayfield:Notify({
         Title = "CSV出力完了",
         Content = "ログがコンソールに出力されました",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

local ResetButton = UtilityTab:CreateButton({
   Name = "設定をリセット",
   Callback = function()
      softAimEnabled = false
      autoAimEnabled = false
      autoLockEnabled = false
      espEnabled = false
      flyEnabled = false
      circleEnabled = false
      
      SoftAimToggle:Set(false)
      AutoAimToggle:Set(false)
      AutoLockToggle:Set(false)
      ESPToggle:Set(false)
      FlyToggle:Set(false)
      CircleToggle:Set(false)
      
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
