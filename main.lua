-- language: Luau, file: delta_mobile_aimbot_v3_autoshoot_fixed.lua, runtime: Delta Executor (Android), target: Roblox Mobile
-- Investigation Results & Fixes:
-- 1. Fixed mobile slider division-by-zero crash when AbsoluteSize.X is 0 during initial touch events.
-- 2. Hardened body-part resolution supporting R6/R15 models safely (Head, UpperTorso, LowerTorso, Torso, HumanoidRootPart).
-- 3. Wrapped tool activation in safe pcall with graceful fallback when no weapon/tool is equipped in test environments.
-- 4. Ensured robust CoreGui/gethui error handling for Android execution contexts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Configuration
local Config = {
    Aimbot = {
        Enabled = true,
        FOV = 9999,
        Smoothness = 0.12,
        TargetPart = "Head",
        TeamCheck = false,
        WallCheck = false,
        Sticky = true,
        MaxDistance = 900,
        Prediction = 0.08,
        AlwaysOn = true,
        Instant = false,
        AutoShoot = false,
        FiringDelay = 0.15,
        BodyMode = "Head", -- Options: "Head", "Torso", "Random"
    },
    ESP = {
        Enabled = true,
        Names = true,
        Health = true,
        Distance = true,
        TeamCheck = false,
        MaxDistance = 1200,
    }
}

local State = {
    CurrentTarget = nil,
    MenuOpen = true,
    ESPFolder = nil,
    StatusText = "booting...",
    Connections = {},
    LastShotTick = 0,
    ActivePartName = "Head",
    RandomBodyPart = "Head",
}

-- Cleanup previous instances safely
pcall(function()
    for _, conn in ipairs(State.Connections) do
        if conn then conn:Disconnect() end
    end
    if CoreGui:FindFirstChild("DeltaAimGuiV3") then
        CoreGui.DeltaAimGuiV3:Destroy()
    end
    if CoreGui:FindFirstChild("DeltaESPv3") then
        CoreGui.DeltaESPv3:Destroy()
    end
end)

-- Safe GUI Container (Delta / Android compatible)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaAimGuiV3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentSuccess = false
if syn and syn.protect_gui then
    pcall(function()
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
        parentSuccess = true
    end)
end

if not parentSuccess and gethui then
    pcall(function()
        ScreenGui.Parent = gethui()
        parentSuccess = true
    end)
end

if not parentSuccess then
    pcall(function()
        ScreenGui.Parent = CoreGui
        parentSuccess = true
    end)
end

if not parentSuccess then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Helper Functions
local function isAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
end

local function getActiveTargetPart(char)
    if not char then return nil end
    local mode = Config.Aimbot.BodyMode
    local partName = "Head"
    
    if mode == "Random" then
        if not State.RandomBodyPart or math.random() < 0.15 then
            local validParts = {}
            if char:FindFirstChild("Head") then table.insert(validParts, "Head") end
            if char:FindFirstChild("UpperTorso") then table.insert(validParts, "UpperTorso") end
            if char:FindFirstChild("LowerTorso") then table.insert(validParts, "LowerTorso") end
            if char:FindFirstChild("Torso") then table.insert(validParts, "Torso") end
            if #validParts > 0 then
                State.RandomBodyPart = validParts[math.random(1, #validParts)]
            else
                State.RandomBodyPart = "HumanoidRootPart"
            end
        end
        partName = State.RandomBodyPart
    elseif mode == "Torso" then
        if char:FindFirstChild("UpperTorso") then
            partName = "UpperTorso"
        elseif char:FindFirstChild("LowerTorso") then
            partName = "LowerTorso"
        elseif char:FindFirstChild("Torso") then
            partName = "Torso"
        else
            partName = "HumanoidRootPart"
        end
    else
        partName = char:FindFirstChild("Head") and "Head" or "HumanoidRootPart"
    end
    
    State.ActivePartName = partName
    return char:FindFirstChild(partName) or getRoot(char)
end

local function isVisible(origin, targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local result = Workspace:Raycast(origin, targetPart.Position - origin, params)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getClosest()
    local closest, closestDist = nil, Config.Aimbot.MaxDistance
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    if not myRoot then
        State.StatusText = "no character"
        return nil
    end

    local origin = Camera.CFrame.Position
    local found = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char or not isAlive(char) then continue end

        if Config.Aimbot.TeamCheck then
            if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
                continue
            end
        end

        local part = getActiveTargetPart(char)
        if not part then continue end

        local dist = (part.Position - myRoot.Position).Magnitude
        if dist > Config.Aimbot.MaxDistance then continue end

        if not isVisible(origin, part) then continue end

        found = found + 1
        if dist < closestDist then
            closestDist = dist
            closest = part
        end
    end

    if closest then
        State.StatusText = string.format("LOCK [%s] → %s (%.0f studs)", State.ActivePartName, closest.Parent and closest.Parent.Name or "?", closestDist)
    else
        State.StatusText = "searching... (" .. found .. " in range)"
    end
    return closest
end

-- Automatic Firing Trigger (Safely handles missing tools / no firing interface)
local function processAutoShoot(targetPart)
    if not Config.Aimbot.AutoShoot or not targetPart then return end
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    
    local tool = myChar:FindFirstChildOfClass("Tool")
    if not tool then
        -- Graceful handling when no firing interface/tool is equipped in test environments
        return
    end
    
    local origin = Camera.CFrame.Position
    if not isVisible(origin, targetPart) then return end
    
    local now = tick()
    if (now - State.LastShotTick) >= Config.Aimbot.FiringDelay then
        State.LastShotTick = now
        pcall(function()
            tool:Activate()
        end)
    end
end

-- ESP System Initialization
local function clearESP()
    if State.ESPFolder then pcall(function() State.ESPFolder:Destroy() end) end
    State.ESPFolder = Instance.new("Folder")
    State.ESPFolder.Name = "DeltaESPv3"
    pcall(function() State.ESPFolder.Parent = CoreGui end)
end
clearESP()

local function createPlayerESP(plr)
    if not State.ESPFolder or State.ESPFolder:FindFirstChild(plr.Name) then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = plr.Name
    bill.Size = UDim2.new(0, 180, 0, 48)
    bill.StudsOffset = Vector3.new(0, 3.4, 0)
    bill.AlwaysOnTop = true
    bill.MaxDistance = Config.ESP.MaxDistance
    bill.Parent = State.ESPFolder

    local nameL = Instance.new("TextLabel")
    nameL.Name = "Name"
    nameL.Size = UDim2.new(1, 0, 0.55, 0)
    nameL.BackgroundTransparency = 1
    nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameL.TextStrokeTransparency = 0.3
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 13
    nameL.Parent = bill

    local hpL = Instance.new("TextLabel")
    hpL.Name = "Health"
    hpL.Size = UDim2.new(1, 0, 0.45, 0)
    hpL.Position = UDim2.new(0, 0, 0.55, 0)
    hpL.BackgroundTransparency = 1
    hpL.TextColor3 = Color3.fromRGB(0, 255, 100)
    hpL.TextStrokeTransparency = 0.3
    hpL.Font = Enum.Font.Gotham
    hpL.TextSize = 11
    hpL.Parent = bill
end

local function updateESP()
    if not Config.ESP.Enabled or not State.ESPFolder then return end
    local myRoot = getRoot(LocalPlayer.Character)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local bill = State.ESPFolder:FindFirstChild(plr.Name)
        if not bill then
            createPlayerESP(plr)
            bill = State.ESPFolder:FindFirstChild(plr.Name)
        end
        if not bill then continue end

        local char = plr.Character
        local root = getRoot(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not root or not isAlive(char) then
            bill.Enabled = false
            continue
        end

        if Config.ESP.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
            bill.Enabled = false
            continue
        end

        local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 9999
        if dist > Config.ESP.MaxDistance then
            bill.Enabled = false
            continue
        end

        bill.Adornee = root
        bill.Enabled = true

        local nameL = bill:FindFirstChild("Name")
        local hpL = bill:FindFirstChild("Health")
        if nameL then
            nameL.Text = plr.Name .. (Config.ESP.Distance and (" [" .. math.floor(dist) .. "m]") or "")
            nameL.Visible = Config.ESP.Names
        end
        if hpL and hum then
            hpL.Text = math.floor(hum.Health) .. " HP"
            local healthRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            hpL.TextColor3 = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 40)
            hpL.Visible = Config.ESP.Health
        end
    end
end

-- Aimbot Processing Loop
local function doAim()
    if not Config.Aimbot.Enabled then
        State.CurrentTarget = nil
        State.StatusText = "aimbot OFF"
        return
    end

    local target = nil

    if Config.Aimbot.Sticky and State.CurrentTarget and State.CurrentTarget.Parent and isAlive(State.CurrentTarget.Parent) then
        local myRoot = getRoot(LocalPlayer.Character)
        if myRoot then
            local dist = (State.CurrentTarget.Position - myRoot.Position).Magnitude
            if dist <= Config.Aimbot.MaxDistance * 1.2 then
                target = State.CurrentTarget
            end
        end
    end

    if not target then
        target = getClosest()
    end

    State.CurrentTarget = target
    if not target then return end

    processAutoShoot(target)

    local aimPos = target.Position
    if Config.Aimbot.Prediction > 0 then
        local vel = Vector3.zero
        pcall(function()
            vel = target.AssemblyLinearVelocity or target.Velocity or Vector3.zero
        end)
        aimPos = aimPos + vel * Config.Aimbot.Prediction
    end

    local camPos = Camera.CFrame.Position
    if Config.Aimbot.Instant then
        Camera.CFrame = CFrame.lookAt(camPos, aimPos)
    else
        local targetCF = CFrame.lookAt(camPos, aimPos)
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, math.clamp(1 - Config.Aimbot.Smoothness, 0.05, 1.0))
    end
end

-- Floating GUI Construction (Mobile & Touch Optimized)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 360)
MainFrame.Position = UDim2.new(0.5, -190, 0.35, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 200, 100)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Top Bar (Draggable Header)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "KESTREL-7 // DELTA MOBILE V3.2.1"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 130)
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 32, 0, 32)
ToggleButton.Position = UDim2.new(1, -36, 0, 4)
ToggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
ToggleButton.Text = "-"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 16
ToggleButton.Parent = TopBar

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

-- Draggable Touch / Mouse Logic
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Minimize Button Logic
local minimized = false
ToggleButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child ~= TopBar and child ~= UICorner and child ~= UIStroke then
            child.Visible = not minimized
        end
    end
    TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = minimized and UDim2.new(0, 380, 0, 40) or UDim2.new(0, 380, 0, 360)}):Play()
    ToggleButton.Text = minimized and "+" or "-"
end)

-- Scrollable Content Area
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -16, 1, -55)
ContentContainer.Position = UDim2.new(0, 8, 0, 46)
ContentContainer.BackgroundTransparency = 1
ContentContainer.BorderSizePixel = 0
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 390)
ContentContainer.ScrollBarThickness = 3
ContentContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = ContentContainer

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 32)
StatusLabel.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "Status: Booting..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 220, 110)
StatusLabel.TextSize = 12
StatusLabel.Parent = ContentContainer

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

-- Toggle Component Builder
local function createMenuToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    frame.BorderSizePixel = 0
    frame.Parent = ContentContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 22)
    btn.Position = UDim2.new(1, -46, 0.5, -11)
    btn.BackgroundColor3 = default and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(50, 50, 65)
    btn.Text = ""
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.Parent = btn

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(50, 50, 65)}):Play()
        TweenService:Create(circle, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
        callback(state)
    end)
end

-- Slider Component Builder (Protected against zero-division on mobile touch)
local function createMenuSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    frame.BorderSizePixel = 0
    frame.Parent = ContentContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = name .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, 6)
    sliderBg.Position = UDim2.new(0, 10, 0, 32)
    sliderBg.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    local draggingSlider = false
    local funct