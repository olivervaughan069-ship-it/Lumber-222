-- ================================================================
-- LT2 Mobile Mod Menu | by Kanha
-- Engine  : Roblox Luau (LocalScript via Executor)
-- Target  : Android / Mobile
-- ----------------------------------------------------------------
-- CHANGELOG v3:
--   FIX 4 (CRITICAL) — All MouseButton1Click replaced with
--           Activated. MouseButton1Click is PC-only and never
--           fires on Android touch. Activated fires on both.
--   FIX 5 (CRITICAL) — showToast delayed-hide rewritten using
--           taskSpawn + taskWait instead of taskDelay. delay()
--           fallback is unreliable in Delta executor on Android,
--           causing the toast to stay permanently on screen.
--   v1 FIX 1 — Lazy remote getters (no top-level WaitForChild)
--   v1 FIX 2 — task library safety shim
--   v1 FIX 3 — Silver Axe + Hardened Axe added to priority list
-- ================================================================

-- ── SERVICES ─────────────────────────────────────────────────────
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP           = Players.LocalPlayer

-- ── FIX 2: task LIBRARY SAFETY SHIM ─────────────────────────────
local taskWait  = (task and task.wait)  or wait
local taskSpawn = (task and task.spawn) or spawn

-- ── FIX 1: LAZY REMOTE GETTERS ───────────────────────────────────
local _RemoteProxy    = nil
local _ClientDragging = nil

local function getRemoteProxy()
    if _RemoteProxy and _RemoteProxy.Parent then return _RemoteProxy end
    local i = RS:FindFirstChild("Interaction")
    if not i then return nil end
    _RemoteProxy = i:FindFirstChild("RemoteProxy")
    return _RemoteProxy
end

local function getClientDragging()
    if _ClientDragging and _ClientDragging.Parent then return _ClientDragging end
    local i = RS:FindFirstChild("Interaction")
    if not i then return nil end
    _ClientDragging = i:FindFirstChild("ClientIsDragging")
    return _ClientDragging
end

-- ── WOOD TYPES ───────────────────────────────────────────────────
local WOOD_TYPES = {
    { name = "Oak",         class = "Oak",         emoji = "🌳", tier = "common" },
    { name = "Elm",         class = "Elm",         emoji = "🌲", tier = "common" },
    { name = "Cherry",      class = "Cherry",      emoji = "🌸", tier = "common" },
    { name = "Birch",       class = "Birch",       emoji = "⬜", tier = "mid"    },
    { name = "Walnut",      class = "Walnut",      emoji = "🟫", tier = "mid"    },
    { name = "Koa",         class = "Koa",         emoji = "🌴", tier = "mid"    },
    { name = "Fir",         class = "Fir",         emoji = "🌲", tier = "mid"    },
    { name = "Pine",        class = "Pine",        emoji = "🌲", tier = "mid"    },
    { name = "Palm",        class = "Palm",        emoji = "🌴", tier = "mid"    },
    { name = "Volcano",     class = "Volcano",     emoji = "🌋", tier = "rare"   },
    { name = "Zombie",      class = "Zombie",      emoji = "🧟", tier = "rare"   },
    { name = "Gold",        class = "Gold",        emoji = "✨", tier = "rare"   },
    { name = "Frost",       class = "Frost",       emoji = "❄️", tier = "rare"   },
    { name = "Cavecrawler", class = "Cavecrawler", emoji = "💙", tier = "rare"   },
    { name = "Phantom",     class = "LoneCave",    emoji = "👻", tier = "exotic" },
    { name = "Snowglow",    class = "Snowglow",    emoji = "🌟", tier = "exotic" },
    { name = "Spooky",      class = "Spooky",      emoji = "🎃", tier = "exotic" },
    { name = "Sinister",    class = "Sinister",    emoji = "☠️", tier = "exotic" },
}

local TIER_COLOUR = {
    common = Color3.fromRGB(100, 100, 120),
    mid    = Color3.fromRGB( 56, 120,  56),
    rare   = Color3.fromRGB( 80,  80, 200),
    exotic = Color3.fromRGB(160,  40, 160),
}

local COL = {
    bg       = Color3.fromRGB( 14,  14,  24),
    panel    = Color3.fromRGB( 20,  20,  36),
    header   = Color3.fromRGB( 26,  26,  46),
    accent   = Color3.fromRGB( 94,  58, 180),
    btnIdle  = Color3.fromRGB( 30,  30,  50),
    btnHover = Color3.fromRGB( 50,  40,  80),
    text     = Color3.fromRGB(230, 230, 255),
    subtext  = Color3.fromRGB(140, 140, 170),
    success  = Color3.fromRGB( 50, 200, 100),
    warn     = Color3.fromRGB(255, 180,  40),
    danger   = Color3.fromRGB(220,  60,  60),
    white    = Color3.fromRGB(255, 255, 255),
    fab      = Color3.fromRGB( 94,  58, 180),
}

local running     = false
local savedCFrame = nil

-- ── GUI HELPERS ──────────────────────────────────────────────────
local function newInstance(cls, props)
    local obj = Instance.new(cls)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function corner(parent, radius)
    newInstance("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent, colour, thickness)
    newInstance("UIStroke", {
        Color = colour or COL.accent, Thickness = thickness or 1.5, Parent = parent
    })
end

local function shadow(parent)
    newInstance("ImageLabel", {
        Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.new(1, 24, 1, 24),
        ZIndex = -1, Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0,0,0), ImageTransparency = 0.55,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49,49,450,450),
        Parent = parent,
    })
end

-- ── DRAG (Touch + Mouse) ─────────────────────────────────────────
local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

    local function update(input)
        local d = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  BUILD GUI
-- ════════════════════════════════════════════════════════════════
local existing = game:GetService("CoreGui"):FindFirstChild("KanhaLT2Menu")
if existing then existing:Destroy() end

local ScreenGui = newInstance("ScreenGui", {
    Name = "KanhaLT2Menu", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = game:GetService("CoreGui"),
})

-- ── FIX 5: TOAST — rewritten hide logic ──────────────────────────
-- Uses taskSpawn + taskWait instead of taskDelay.
-- taskDelay falls back to delay() which is unreliable in Delta Android.
local Toast = newInstance("Frame", {
    Name = "Toast", AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = COL.panel,
    Position = UDim2.new(0.5, 0, 0, -60),   -- starts OFF screen (above)
    Size = UDim2.new(0.85, 0, 0, 44),
    ZIndex = 20, Parent = ScreenGui,
})
corner(Toast, 10)
stroke(Toast, COL.accent, 1)

local ToastLabel = newInstance("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,8,0,0),
    Font = Enum.Font.GothamBold, Text = "",
    TextColor3 = COL.text, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21, Parent = Toast,
})

local toastShowing = false
local function showToast(msg, colour)
    ToastLabel.Text       = msg
    ToastLabel.TextColor3 = colour or COL.text

    -- FIX 5: spawn a coroutine — no taskDelay, no delay()
    taskSpawn(function()
        if toastShowing then
            -- already visible: just update text, reset the timer by waiting here
            taskWait(2.5)
        else
            toastShowing = true
            -- slide in
            TweenService:Create(Toast,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad),
                { Position = UDim2.new(0.5, 0, 0, 10) }
            ):Play()
            taskWait(2.8)
        end
        -- slide out
        TweenService:Create(Toast,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, 0, 0, -60) }
        ):Play()
        taskWait(0.3)
        toastShowing = false
    end)
end

-- ── MAIN PANEL ───────────────────────────────────────────────────
local Panel = newInstance("Frame", {
    Name = "Panel", AnchorPoint = Vector2.new(0, 0),
    BackgroundColor3 = COL.bg,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(0, 310, 0.88, 0),
    Visible = false, ZIndex = 10, Parent = ScreenGui,
})
corner(Panel, 14)
stroke(Panel, COL.accent, 1.5)
shadow(Panel)
makeDraggable(Panel)

-- Header
local Header = newInstance("Frame", {
    BackgroundColor3 = COL.header,
    Size = UDim2.new(1,0,0,56), ZIndex = 11, Parent = Panel,
})
corner(Header, 14)
newInstance("Frame", {   -- fills lower half so only top corners are rounded
    BackgroundColor3 = COL.header,
    Size = UDim2.new(1,0,0.5,0), Position = UDim2.new(0,0,0.5,0),
    ZIndex = 11, Parent = Header,
})
newInstance("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,14,0,0), Size = UDim2.new(1,-60,1,0),
    Font = Enum.Font.GothamBold, Text = "🪓  LT2 Auto-Chop",
    TextColor3 = COL.white, TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12, Parent = Header,
})

-- FIX 4: Activated (not MouseButton1Click) ──────────────────────
local CloseBtn = newInstance("TextButton", {
    AnchorPoint = Vector2.new(1,0.5),
    BackgroundColor3 = Color3.fromRGB(180,40,40),
    Position = UDim2.new(1,-10,0.5,0), Size = UDim2.new(0,36,0,36),
    Font = Enum.Font.GothamBold, Text = "✕",
    TextColor3 = COL.white, TextSize = 18,
    ZIndex = 13, Parent = Header,
})
corner(CloseBtn, 10)

-- Status bar
local StatusBar = newInstance("Frame", {
    BackgroundColor3 = COL.panel,
    Position = UDim2.new(0,8,0,60), Size = UDim2.new(1,-16,0,36),
    ZIndex = 11, Parent = Panel,
})
corner(StatusBar, 8)

local StatusLabel = newInstance("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,-12,1,0), Position = UDim2.new(0,6,0,0),
    Font = Enum.Font.Gotham, Text = "⏳  Idle — select a wood type below",
    TextColor3 = COL.subtext, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true, ZIndex = 12, Parent = StatusBar,
})

-- Stop button
local StopBtn = newInstance("TextButton", {
    BackgroundColor3 = Color3.fromRGB(180,40,40),
    Position = UDim2.new(0,8,0,102), Size = UDim2.new(1,-16,0,42),
    Font = Enum.Font.GothamBold, Text = "⛔  Stop Current Task",
    TextColor3 = COL.white, TextSize = 15,
    ZIndex = 11, Parent = Panel,
})
corner(StopBtn, 10)

-- Equip axe button (bottom of panel)
local EquipBtn = newInstance("TextButton", {
    BackgroundColor3 = Color3.fromRGB(40,80,40),
    Position = UDim2.new(0,8,1,-54), Size = UDim2.new(1,-16,0,42),
    Font = Enum.Font.GothamBold, Text = "🪓  Equip Best Axe",
    TextColor3 = COL.white, TextSize = 15,
    ZIndex = 11, Parent = Panel,
})
corner(EquipBtn, 10)

-- Scroll frame
local ScrollFrame = newInstance("ScrollingFrame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,8,0,152), Size = UDim2.new(1,-16,1,-204),
    CanvasSize = UDim2.new(0,0,0,0),
    ScrollBarThickness = 3, ScrollBarImageColor3 = COL.accent,
    ZIndex = 11, Parent = Panel,
})
local listLayout = newInstance("UIListLayout", {
    Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ScrollFrame,
})
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y + 10)
end)

-- Wood buttons
local tierOrder = { "common", "mid", "rare", "exotic" }
local tierNames = {
    common = "── COMMON ──", mid = "── MID TIER ──",
    rare = "── RARE ──", exotic = "── EXOTIC / SEASONAL ──",
}
local woodButtons = {}
local layoutOrder = 0

for _, tier in ipairs(tierOrder) do
    layoutOrder = layoutOrder + 1
    newInstance("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1,-8,0,22),
        Font = Enum.Font.GothamBold, Text = tierNames[tier],
        TextColor3 = TIER_COLOUR[tier], TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = layoutOrder, ZIndex = 12, Parent = ScrollFrame,
    })

    for _, wood in ipairs(WOOD_TYPES) do
        if wood.tier == tier then
            layoutOrder = layoutOrder + 1
            local btn = newInstance("TextButton", {
                BackgroundColor3 = COL.btnIdle,
                Size = UDim2.new(1,-4,0,48), Font = Enum.Font.GothamBold,
                Text = "", LayoutOrder = layoutOrder,
                ZIndex = 12, Parent = ScrollFrame,
            })
            corner(btn, 10)

            local stripe = newInstance("Frame", {
                BackgroundColor3 = TIER_COLOUR[tier],
                Size = UDim2.new(0,4,1,-12), Position = UDim2.new(0,0,0,6),
                ZIndex = 13, Parent = btn,
            })
            corner(stripe, 2)

            newInstance("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0,10,0,0), Size = UDim2.new(0,36,1,0),
                Font = Enum.Font.Gotham, Text = wood.emoji,
                TextSize = 22, ZIndex = 13, Parent = btn,
            })
            newInstance("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0,52,0,4), Size = UDim2.new(1,-100,0,20),
                Font = Enum.Font.GothamBold, Text = wood.name .. " Wood",
                TextColor3 = COL.white, TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13, Parent = btn,
            })
            local badge = newInstance("TextLabel", {
                BackgroundColor3 = TIER_COLOUR[tier], BackgroundTransparency = 0.5,
                Position = UDim2.new(0,52,0,26), Size = UDim2.new(0,56,0,14),
                Font = Enum.Font.GothamBold, Text = tier:upper(),
                TextColor3 = COL.white, TextSize = 9,
                ZIndex = 13, Parent = btn,
            })
            corner(badge, 4)
            newInstance("TextLabel", {
                BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5),
                Position = UDim2.new(1,-10,0.5,0), Size = UDim2.new(0,28,0,28),
                Font = Enum.Font.GothamBold, Text = "▶",
                TextColor3 = TIER_COLOUR[tier], TextSize = 18,
                ZIndex = 13, Parent = btn,
            })

            woodButtons[wood.class] = btn
        end
    end
end

-- ── FAB ──────────────────────────────────────────────────────────
local FAB = newInstance("TextButton", {
    Name = "FAB", AnchorPoint = Vector2.new(1,1),
    BackgroundColor3 = COL.fab,
    Position = UDim2.new(1,-18,1,-100),
    Size = UDim2.new(0,60,0,60),
    Font = Enum.Font.GothamBold, Text = "🪓",
    TextSize = 26, ZIndex = 15, Parent = ScreenGui,
})
corner(FAB, 30)
stroke(FAB, Color3.fromRGB(140,100,220), 2)
shadow(FAB)
makeDraggable(FAB)

-- ════════════════════════════════════════════════════════════════
--  LT2 CORE FUNCTIONS
-- ════════════════════════════════════════════════════════════════
local function setStatus(msg, colour)
    StatusLabel.Text       = msg
    StatusLabel.TextColor3 = colour or COL.subtext
end

-- FIX 3: AXE PRIORITY with Silver + Hardened Axe included
local AXE_PRIORITY = {
    "Rukiryaxe",       -- DPS ~4.2
    "Axe3",            -- Silver Axe DPS ~3.33
    "HardenedAxe",     -- Hardened Axe DPS ~2.23
    "AxeAlphaTesters", -- Alpha Axe DPS ~3
    "AxeBetaTesters",  -- Beta Axe DPS ~2.69
    "Axe2",            -- Steel Axe DPS ~1.33
    "Axe1",            -- Plain Axe DPS ~0.75
    "BasicHatchet",    -- fallback
}

local function getBestAxe()
    local char     = LP.Character
    local backpack = LP.Backpack
    if not char or not backpack then return nil end
    local equipped = char:FindFirstChildWhichIsA("Tool")
    if equipped and equipped:FindFirstChild("ToolName") then return equipped end
    for _, toolNameVal in ipairs(AXE_PRIORITY) do
        for _, item in ipairs(backpack:GetChildren()) do
            if item:FindFirstChild("ToolName")
            and item.ToolName.Value == toolNameVal then
                return item
            end
        end
    end
    for _, item in ipairs(backpack:GetChildren()) do
        if item.Name ~= "BlueprintTool" and item:FindFirstChild("ToolName") then
            return item
        end
    end
    return nil
end

local function equipAxe(axe)
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end
    hum:UnequipTools()
    taskWait(0.15)
    hum:EquipTool(axe)
    taskWait(0.2)
    return true
end

local function findTree(treeClass)
    local function searchIn(container)
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") then
                local cutEvent = obj:FindFirstChild("CutEvent")
                local tClass   = obj:FindFirstChild("TreeClass")
                local owner    = obj:FindFirstChild("Owner")
                if cutEvent and tClass and tClass.Value == treeClass then
                    if not owner or not owner.Value or owner.Value == LP then
                        local ws = obj:FindFirstChild("WoodSection")
                        if ws and ws:FindFirstChild("ID") then return obj end
                    end
                end
                local found = searchIn(obj)
                if found then return found end
            end
        end
        return nil
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local found = searchIn(child)
            if found then return found end
        end
    end
    return nil
end

local function cutTree(treeModel, axe)
    local char = LP.Character
    if not char then return false end
    local sections = {}
    for _, part in ipairs(treeModel:GetDescendants()) do
        if part.Name == "WoodSection" and part:FindFirstChild("ID") then
            table.insert(sections, part)
        end
    end
    table.sort(sections, function(a,b) return a.ID.Value < b.ID.Value end)
    if #sections == 0 then return false end
    local cutEvent = treeModel:FindFirstChild("CutEvent")
    if not cutEvent then return false end
    char.HumanoidRootPart.CFrame = CFrame.new(sections[1].Position + Vector3.new(5,0.5,0))
    taskWait(0.3)
    for _, section in ipairs(sections) do
        if not running then break end
        if not treeModel or not treeModel.Parent then break end
        if not section or not section.Parent then break end
        for i = 1, 12 do
            if not running then break end
            if not section or not section.Parent then break end
            local proxy = getRemoteProxy()
            if proxy then
                pcall(function()
                    proxy:FireServer(cutEvent, {
                        tool = axe, faceVector = Vector3.new(1,0,0),
                        height = 0.3, sectionId = section.ID.Value,
            