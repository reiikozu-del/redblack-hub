-- language: Luau, file: core.lua, target: GitHub Raw
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- State
local noclip, infJump, wsVal = false, false, 16
local instantPromptActive = false
local savedCFrame = nil
local espActive = false
local flyActive = false
local flySpeed = 50

-- UI Factory helper
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

-- ScreenGui
local screen = make("ScreenGui", {Name = "RedBlackHubModular", ResetOnSpawn = false}, gui)

-- Floating Teleport Back Button (Draggable)
local floatBackBtn = make("TextButton", {
    Size = UDim2.new(0, 45, 0, 45), Position = UDim2.new(0, 20, 0, 90),
    BackgroundColor3 = Color3.fromRGB(180, 20, 20), TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold, TextSize = 12, Text = "BACK", Visible = false, ZIndex = 10
}, screen)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, floatBackBtn)
make("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 0.8}, floatBackBtn)

-- Open Button (Draggable)
local openBtn = make("TextButton", {
    Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20), TextColor3 = Color3.fromRGB(220, 30, 30),
    Font = Enum.Font.GothamBold, TextSize = 18, Text = "UI", Visible = false, ZIndex = 10
}, screen)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, openBtn)
make("UIStroke", {Color = Color3.fromRGB(180, 20, 20), Thickness = 2}, openBtn)

-- Main Frame
local main = make("Frame", {
    Size = UDim2.new(0, 500, 0, 320), Position = UDim2.new(0.5, -250, 0.5, -160),
    BackgroundColor3 = Color3.fromRGB(15, 15, 15), BorderSizePixel = 0
}, screen)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, main)
make("UIStroke", {Color = Color3.fromRGB(180, 20, 20), Thickness = 1.5}, main)

-- Top Bar
local topBar = make("Frame", {Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1}, main)
make("TextLabel", {
    Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "SYSTEM // HUB",
    TextColor3 = Color3.fromRGB(240, 240, 240), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
}, topBar)

local minBtn = make("TextButton", {
    Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -35, 0, 2),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "-",
    TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 18
}, topBar)

-- Sidebar & Content
local sidebar = make("ScrollingFrame", {
    Size = UDim2.new(0, 130, 1, -45), Position = UDim2.new(0, 10, 0, 40),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0,
    CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 2
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, sidebar)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}, sidebar)

local contentArea = make("Frame", {
    Size = UDim2.new(1, -155, 1, -45), Position = UDim2.new(0, 145, 0, 40),
    BackgroundTransparency = 1, BorderSizePixel = 0
}, main)

-- Tabs & Panels
local tabs, contents = {"Profile", "Menu", "Misc", "Server Hop", "Setting"}, {}
for i, name in ipairs(tabs) do
    local tBtn = make("TextButton", {
        Size = UDim2.new(1, -10, 0, 35), BackgroundColor3 = i == 1 and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(28, 28, 28),
        Font = Enum.Font.GothamMedium, Text = name, TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180),
        TextSize = 13, LayoutOrder = i
    }, sidebar)
    make("UICorner", {CornerRadius = UDim.new(0, 4)}, tBtn)

    local panel = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = (i == 1), CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 2
    }, contentArea)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)}, panel)
    contents[name] = panel

    tBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3, child.TextColor3 = Color3.fromRGB(28, 28, 28), Color3.fromRGB(180, 180, 180)
            end
        end
        for _, p in pairs(contents) do p.Visible = false end
        tBtn.BackgroundColor3, tBtn.TextColor3 = Color3.fromRGB(180, 20, 20), Color3.fromRGB(255, 255, 255)
        panel.Visible = true
    end)
end

-- Profile Features
local pPanel = contents["Profile"]

local wsC = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, pPanel)
make("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "WalkSpeed", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, wsC)
local wsBox = make("TextBox", {Size = UDim2.new(0.35, 0, 0.8, 0), Position = UDim2.new(0.65, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(25, 25, 25), Font = Enum.Font.GothamMedium, Text = "16", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13}, wsC)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, wsBox)

wsBox.FocusLost:Connect(function(e)
    if e then wsVal = tonumber(wsBox.Text) or 16 end
end)

-- Toggle Generator
local function makeToggle(parentPanel, text, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        Font = Enum.Font.GothamMedium, Text = text .. ": OFF", TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 13
    }, parentPanel)
    make("UICorner", {CornerRadius = UDim.new(0, 4)}, btn)
    
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. (state and ": ON" or ": OFF")
        btn.TextColor3 = state and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(200, 200, 200)
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 15, 15) or Color3.fromRGB(22, 22, 22)
        callback(state)
    end)
end

makeToggle(pPanel, "NoClip", function(s) noclip = s end)
makeToggle(pPanel, "Infinite Jump", function(s) infJump = s end)

-- Menu Features (Instant Prompt & Waypoint Teleport)
local mPanel = contents["Menu"]

makeToggle(mPanel, "Instant Prompt", function(s)
    instantPromptActive = s
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            obj.HoldDuration = instantPromptActive and 0 or (obj:GetAttribute("OriginalHoldDuration") or obj.HoldDuration)
        end
    end
end)

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then
        obj:SetAttribute("OriginalHoldDuration", obj.HoldDuration)
        if instantPromptActive then
            obj.HoldDuration = 0
        end
    end
end)

local function makeButton(parentPanel, text, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 13
    }, parentPanel)
    make("UICorner", {CornerRadius = UDim.new(0, 4)}, btn)
    btn.MouseButton1Click:Connect(callback)
end

makeButton(mPanel, "Save Position", function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        savedCFrame = char.HumanoidRootPart.CFrame
        floatBackBtn.Visible = true 
    end
end)

local function teleportBack()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and savedCFrame then
        char.HumanoidRootPart.CFrame = savedCFrame
    end
end

makeButton(mPanel, "Teleport Back", teleportBack)
floatBackBtn.MouseButton1Click:Connect(teleportBack)

-- Misc Features (ESP & Fly)
local miscPanel = contents["Misc"]

makeToggle(miscPanel, "Player ESP", function(s)
    espActive = s
    local function applyEsp(p)
        if p ~= player then
            local function onChar(char)
                if espActive then
                    if not char:FindFirstChild("HubHighlight") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "HubHighlight"
                        hl.Adornee = char
                        hl.FillColor = Color3.fromRGB(180, 20, 20)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = char
                    end
                else
                    local hl = char:FindFirstChild("HubHighlight")
                    if hl then hl:Destroy() end
                end
            end
            p.CharacterAdded:Connect(onChar)
            if p.Character then onChar(p.Character) end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do applyEsp(p) end
    if not espActive then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("HubHighlight")
                if hl then hl:Destroy() end
            end
        end
    end
end)

makeToggle(miscPanel, "Fly Mode", function(s)
    flyActive = s
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    if flyActive then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "HubFlyVel"
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
        
        local bg = Instance.new("BodyGyro")
        bg.Name = "HubFlyGyro"
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.CFrame = hrp.CFrame
        bg.Parent = hrp
    else
        if hrp:FindFirstChild("HubFlyVel") then hrp.HubFlyVel:Destroy() end
        if hrp:FindFirstChild("HubFlyGyro") then hrp.HubFlyGyro:Destroy() end
    end
end)

-- Loops & Handlers
RunService.Stepped:Connect(function()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum and hum.WalkSpeed ~= wsVal then
            hum.WalkSpeed = wsVal
        end
        if noclip then
            for _, p in ipairs(char:GetDescendants()) do 
                if p:IsA("BasePart") then p.CanCollide = false end 
            end
        end
        if flyActive and hrp then
            local bv = hrp:FindFirstChild("HubFlyVel")
            local bg = hrp:FindFirstChild("HubFlyGyro")
            if bv and bg then
                bg.CFrame = camera.CFrame
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    bv.Velocity = moveDir * flySpeed
                else
                    bv.Velocity = Vector3.zero
                end
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infJump then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Dragging UI & Buttons
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)

local btnDragging, btnDragStart, btnStartPos
openBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        btnDragging, btnDragStart, btnStartPos = true, i.Position, openBtn.Position
    end
end)

local backDragging, backDragStart, backStartPos
floatBackBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        backDragging, backDragStart, backStartPos = true, i.Position, floatBackBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        if dragging then
            local delta = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        elseif btnDragging then
            local delta = i.Position - btnDragStart
            openBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
        elseif backDragging then
            local delta = i.Position - backDragStart
            floatBackBtn.Position = UDim2.new(backStartPos.X.Scale, backStartPos.X.Offset + delta.X, backStartPos.Y.Scale, backStartPos.Y.Offset + delta.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        dragging = false
        btnDragging = false 
        backDragging = false
    end
end)

minBtn.MouseButton1Click:Connect(function() 
    main.Visible = false 
    openBtn.Visible = true 
end)

openBtn.MouseButton1Click:Connect(function() 
    main.Visible = true 
    openBtn.Visible = false 
end)
