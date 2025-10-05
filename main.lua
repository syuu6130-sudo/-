--// 暗殺者対保安官2 統合メニュー 完全版 //--
-- 作者: @syu_0316 + RapidFire統合 + 完全GUI統合 --

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

local softAimStrength = 3
local flySpeed = 3
local fireInterval = 0.1 -- 連射速度

local lockLog = {}
local currentLockTarget = nil

-- ========== チームチェック & 壁判定 / FFA対応 ==========
local function isVisible(target)
    local origin = Camera.CFrame.Position
    local direction = (target.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRay(ray, player.Character, false, true)
    return (not hit or hit:IsDescendantOf(target.Parent))
end

local function isEnemy(plr)
    return plr ~= player -- FFA対応
end

-- ========== 最も近い敵を取得 ==========
local function getClosestEnemy()
    local closest, dist = nil, math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                local mag = (hrp.Position - Camera.CFrame.Position).Magnitude
                if mag < dist and isVisible(hrp) then
                    closest = p.Character
                    dist = mag
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
            if not p.Character:FindFirstChild("ESPHighlight") then
                local c = Color3.new(1,0,0)
                createESP(p.Character,c)
            end
        end
    end
end

-- ========== SoftAim / AutoAim / AutoLock / RapidFire ==========
RunService.RenderStepped:Connect(function()
    local target = getClosestEnemy()

    if target then
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            if softAimEnabled then
                local aimPos = target.HumanoidRootPart.Position
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, aimPos), softAimStrength*0.1)
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
        else
            currentLockTarget = nil
        end
    else
        currentLockTarget = nil
    end

    if espEnabled then
        updateESP()
    end

    if rapidFireEnabled then
        local char = player.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
            end
        end
    end
end)

-- ========== Fly ==========
local bodyVel
RunService.RenderStepped:Connect(function()
    if flyEnabled then
        if not bodyVel then
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
            bodyVel.Parent = player.Character:WaitForChild("HumanoidRootPart")
        end
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end
        bodyVel.Velocity = moveDir * flySpeed
    else
        if bodyVel then bodyVel:Destroy() bodyVel=nil end
    end
end)

-- ========== GUI構築 ==========
local screen = Instance.new("ScreenGui", game.CoreGui)
screen.Name = "暗殺者対保安官2"

local mainFrame = Instance.new("Frame", screen)
mainFrame.Size = UDim2.new(0,300,0,400)
mainFrame.Position = UDim2.new(0.3,0,0.3,0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1,0,0,40)
title.Text = "暗殺者対保安官2 - @syu_0316"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1

-- ====== GUI トグルボタン作成ヘルパー ======
local function makeToggle(name,callback)
    local btn = Instance.new("TextButton", mainFrame)
    btn.Size = UDim2.new(1,-20,0,30)
    btn.Position = UDim2.new(0,10,0,#mainFrame:GetChildren()*35)
    btn.Text = name
    btn.MouseButton1Click:Connect(callback)
end

-- ====== トグルボタン作成 ======
makeToggle("SoftAim", function() softAimEnabled = not softAimEnabled end)
makeToggle("AutoAim", function() autoAimEnabled = not autoAimEnabled end)
makeToggle("AutoLock", function() autoLockEnabled = not autoLockEnabled end)
makeToggle("ESP", function() espEnabled = not espEnabled end)
makeToggle("Fly", function() flyEnabled = not flyEnabled end)
makeToggle("CSV出力", function()
    print("=== ロックログ ===")
    for name,count in pairs(lockLog) do
        print(name..","..count)
    end
end)
makeToggle("連射(RapidFire)", function()
    rapidFireEnabled = not rapidFireEnabled
end)

-- ====== 閉じる & 最小化 & ドラッグ移動 ======
local close = Instance.new("TextButton", mainFrame)
close.Text = "×"
close.Size = UDim2.new(0,30,0,30)
close.Position = UDim2.new(1,-35,0,5)
close.MouseButton1Click:Connect(function()
    local confirm = Instance.new("Frame", screen)
    confirm.Size = UDim2.new(0,200,0,100)
    confirm.Position = UDim2.new(0.4,0,0.4,0)
    confirm.BackgroundColor3 = Color3.fromRGB(40,40,40)

    local lbl = Instance.new("TextLabel", confirm)
    lbl.Size = UDim2.new(1,0,0.5,0)
    lbl.Text = "本当に閉じますか？"
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.BackgroundTransparency = 1

    local yes = Instance.new("TextButton", confirm)
    yes.Size = UDim2.new(0.5,0,0.5,0)
    yes.Position = UDim2.new(0,0,0.5,0)
    yes.Text = "はい"
    yes.MouseButton1Click:Connect(function() screen:Destroy() end)

    local no = Instance.new("TextButton", confirm)
    no.Size = UDim2.new(0.5,0,0.5,0)
    no.Position = UDim2.new(0.5,0,0.5,0)
    no.Text = "いいえ"
    no.MouseButton1Click:Connect(function() confirm:Destroy() end)
end)

local minimize = Instance.new("TextButton", mainFrame)
minimize.Text = "-"
minimize.Size = UDim2.new(0,30,0,30)
minimize.Position = UDim2.new(1,-70,0,5)
minimize.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    local mini = Instance.new("TextButton", screen)
    mini.Size = UDim2.new(0,50,0,30)
    mini.Position = UDim2.new(0.5,-25,0,10)
    mini.Text = "開く"
    mini.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        mini:Destroy()
    end)
end)

-- ドラッグ移動対応
local dragging = false
local dragStart, startPos

mainFrame.Active = true
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
