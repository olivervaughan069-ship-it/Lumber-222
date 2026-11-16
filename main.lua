
-- F SOCIETY | PLAYER TELEPORT MENU
-- Delta Executor

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

if CoreGui:FindFirstChild("FSocietyTeleport") then
    CoreGui.FSocietyTeleport:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FSocietyTeleport"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local function Create(class, properties, parent)
    local object = Instance.new(class)
    for property, value in pairs(properties) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local Main = Create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 270, 0, 190),
    Position = UDim2.new(0.5, -135, 0.5, -95),
    BackgroundColor3 = Color3.fromRGB(20, 20, 25),
    BorderSizePixel = 0,
    ClipsDescendants = true
}, ScreenGui)

Create("UICorner", {CornerRadius = UDim.new(0, 10)}, Main)
Create("UIStroke", {Color = Color3.fromRGB(120, 50, 220), Thickness = 1.5}, Main)

local Header = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Color3.fromRGB(35, 25, 50),
    BorderSizePixel = 0
}, Main)

Create("TextLabel", {
    Size = UDim2.new(1, -45, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "F SOCIETY",
    TextColor3 = Color3.fromRGB(210, 170, 255),
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local CloseButton = Create("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(1, -36, 0, 5),
    BackgroundColor3 = Color3.fromRGB(150, 45, 65),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
}, Header)
Create("UICorner", {CornerRadius = UDim.new(0, 6)}, CloseButton)

local Home = Create("Frame", {
    Name = "Home",
    Size = UDim2.new(1, 0, 1, -38),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundTransparency = 1
}, Main)

Create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 35),
    Position = UDim2.new(0, 10, 0, 15),
    BackgroundTransparency = 1,
    Text = "PLAYER TELEPORT",
    TextColor3 = Color3.fromRGB(235, 235, 235),
    TextSize = 15,
    Font = Enum.Font.GothamBold
}, Home)

local PlayersButton = Create("TextButton", {
    Size = UDim2.new(1, -40, 0, 42),
    Position = UDim2.new(0, 20, 0, 65),
    BackgroundColor3 = Color3.fromRGB(105, 55, 175),
    Text = "PLAYERS  >",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
}, Home)
Create("UICorner", {CornerRadius = UDim.new(0, 7)}, PlayersButton)

local PlayerPanel = Create("Frame", {
    Name = "PlayerPanel",
    Size = UDim2.new(1, 0, 1, -38),
    Position = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Color3.fromRGB(20, 20, 25),
    BorderSizePixel = 0
}, Main)

local BackButton = Create("TextButton", {
    Size = UDim2.new(0, 75, 0, 28),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundColor3 = Color3.fromRGB(65, 45, 90),
    Text = "< BACK",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
}, PlayerPanel)
Create("UICorner", {CornerRadius = UDim.new(0, 6)}, BackButton)

local RefreshButton = Create("TextButton", {
    Size = UDim2.new(0, 85, 0, 28),
    Position = UDim2.new(1, -95, 0, 8),
    BackgroundColor3 = Color3.fromRGB(75, 55, 120),
    Text = "REFRESH",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
}, PlayerPanel)
Create("UICorner", {CornerRadius = UDim.new(0, 6)}, RefreshButton)

local PlayerList = Create("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -52),
    Position = UDim2.new(0, 10, 0, 43),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(145, 90, 210),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, PlayerPanel)

Create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.Name
}, PlayerList)

local function Notify(message)
    local label = Create("TextLabel", {
        Size = UDim2.new(0, 230, 0, 34),
        Position = UDim2.new(0.5, -115, 1, -55),
        BackgroundColor3 = Color3.fromRGB(35, 25, 50),
        Text = message,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0
    }, ScreenGui)

    Create("UICorner", {CornerRadius = UDim.new(0, 7)}, label)

    task.delay(2, function()
        if label then
            label:Destroy()
        end
    end)
end

local function TeleportToPlayer(target)
    if target == LocalPlayer then
        Notify("You cannot teleport to yourself")
        return
    end

    local character = LocalPlayer.Character
    local targetCharacter = target.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

    if not root or not targetRoot then
        Notify("Player character unavailable")
        return
    end

    root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
    Notify("Teleport requested: " .. target.Name)
end

local function RefreshPlayers()
    for _, child in ipairs(PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local button = Create("TextButton", {
                Name = player.Name,
                Size = UDim2.new(1, -5, 0, 36),
                BackgroundColor3 = Color3.fromRGB(40, 35, 50),
                Text = player.DisplayName .. "  (@" .. player.Name .. ")",
                TextColor3 = Color3.fromRGB(235, 235, 235),
                TextSize = 12,
                Font = Enum.Font.GothamSemibold,
                BorderSizePixel = 0
            }, PlayerList)

            Create("UICorner", {CornerRadius = UDim.new(0, 6)}, button)

            button.MouseButton1Click:Connect(function()
                TeleportToPlayer(player)
            end)
        end
    end
end

local panelOpen = false

local function SetPlayersPanel(open)
    panelOpen = open

    local position = open and UDim2.new(0, 0, 0, 38)
        or UDim2.new(1, 0, 0, 38)

    TweenService:Create(
        PlayerPanel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = position}
    ):Play()
end

PlayersButton.MouseButton1Click:Connect(function()
    RefreshPlayers()
    SetPlayersPanel(true)
end)

BackButton.MouseButton1Click:Connect(function()
    SetPlayersPanel(false)
end)

RefreshButton.MouseButton1Click:Connect(RefreshPlayers)

Players.PlayerAdded:Connect(function()
    if panelOpen then RefreshPlayers() end
end)

Players.PlayerRemoving:Connect(function()
    if panelOpen then RefreshPlayers() end
end)

-- Floating open/close button
local ToggleButton = Create("TextButton", {
    Name = "OpenClose",
    Size = UDim2.new(0, 90, 0, 34),
    Position = UDim2.new(0, 15, 0.5, 110),
    BackgroundColor3 = Color3.fromRGB(105, 55, 175),
    Text = "OPEN MENU",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
}, ScreenGui)
Create("UICorner", {CornerRadius = UDim.new(0, 7)}, ToggleButton)

local menuVisible = true

ToggleButton.MouseButton1Click:Connect(function()
    menuVisible = not menuVisible
    Main.Visible = menuVisible
    ToggleButton.Text = menuVisible and "CLOSE MENU" or "OPEN MENU"
end)

CloseButton.MouseButton1Click:Connect(function()
    menuVisible = false
    Main.Visible = false
    ToggleButton.Text = "OPEN MENU"
end)

-- Drag the main menu using its header
local dragging = false
local dragInput
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

RefreshPlayers()
