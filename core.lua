-- language: Luau, file: core_streaming_fixed.lua, target: GitHub Raw (Full Features + StreamingEnabled Fix)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- State
local noclip, infJump, wsVal = false, false, 16
local cfSpeedActive = false
local cfSpeedVal = 1
local instantPromptActive = false
local savedCFrame = nil
local espActive = false
local flyActive = false
local flySpeed = 50
local antiAfkActive = false
local fullbrightActive = false
local tapTpActive = false
local isSpectating = false
local originalCameraSubject = nil

-- UI Factory helper
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

-- Safe Teleport Helper (Mencegah "Gameplay Paused" akibat StreamingEnabled)
local function safeTeleport(targetCFrame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local targetPosition = targetCFrame.Position
    pcall(function()
        if game.Workspace.StreamingEnabled then
            player:RequestStreamAroundAsync(targetPosition)
        end
    end)
    
    task.wait(0.05)
    char.HumanoidRootPart.CFrame = targetCFrame
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

-- Helper UI Components
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

local function makeButton(parentPanel, text, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 13
    }, parentPanel)
    make("UICorner", {CornerRadius = UDim.new(0, 4)}, btn)
    btn.MouseButton1Click:Connect(callback)
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

local cfC = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, pPanel)
make("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "CFrame Speed (0.5-2)", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, cfC)
local cfBox = make("TextBox", {Size = UDim2.new(0.35, 0, 0.8, 0), Position = UDim2.new(0.65, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(25, 25, 25), Font = Enum.Font.GothamMedium, Text = "1", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13}, cfC)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, cfBox)

cfBox.FocusLost:Connect(function(e)
    if e then cfSpeedVal = tonumber(cfBox.Text) or 1 end
end)

makeToggle(pPanel, "CFrame Speed Bypass", function(s) cfSpeedActive = s end)
makeToggle(pPanel, "NoClip", function(s) noclip = s end)
makeToggle(pPanel, "Infinite Jump", function(s) infJump = s end)

-- Menu Features (Instant Prompt, Waypoint, Tap TP, Spectate)
local mPanel = contents["Menu"]

makeToggle(mPanel, "Instant Prompt", function(s)
    instantPromptActive = s
end)

Workspace.DescendantAdded:Connect(function(obj)
    if instantPromptActive and obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
    end
end)

makeToggle(mPanel, "Tap TP (Mobile Friendly)", function(s)
    tapTpActive = s
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if tapTpActive and not gameProcessed then
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = player:GetMouse()
            if mouse and mouse.Hit then
                safeTeleport(CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)))
            end
        end
    end
end)

makeButton(mPanel, "Save Position", function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        savedCFrame = char.HumanoidRootPart.CFrame
        floatBackBtn.Visible = true 
    end
end)

local function teleportBack()
    if savedCFrame then
        safeTeleport(savedCFrame)
    end
end

makeButton(mPanel, "Teleport Back", teleportBack)
floatBackBtn.MouseButton1Click:Connect(teleportBack)

-- Player Teleport & Spectate Section
local tpBox = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(25, 25, 25),
    Font = Enum.Font.GothamMedium, Text = "", PlaceholderText = "Ketik Nama Player...",
    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13
}, mPanel)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, tpBox)

makeButton(mPanel, "Teleport Ke Player", function()
    local targetName = string.lower(tpBox.Text)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and (string.find(string.lower(p.Name), targetName) or string.find(string.lower(p.DisplayName), targetName)) then
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                safeTeleport(p.Character.HumanoidRootPart.CFrame)
                break
            end
        end
    end
end)

makeButton(mPanel, "Spectate / Tonton Player", function()
    local targetName = string.lower(tpBox.Text)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and (string.find(string.lower(p.Name), targetName) or string.find(string.lower(p.DisplayName), targetName)) then
            if p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
                if not isSpectating then
                    originalCameraSubject = camera.CameraSubject
                    camera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid")
                    isSpectating = true
                else
                    camera.CameraSubject = originalCameraSubject or player.Character:FindFirstChildOfClass("Humanoid")
                    isSpectating = false
                end
                break
            end
        end
    end
end)

-- Misc Features (ESP, Fly, Fullbright, FOV)
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

makeToggle(miscPanel, "Fullbright", function(s)
    fullbrightActive = s
    if fullbrightActive then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(127, 127, 127)
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end
end)

local fovC = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, miscPanel)
make("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "Field of View (FOV)", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, fovC)
local fovBox = make("TextBox", {Size = UDim2.new(0.35, 0, 0.8, 0), Position = UDim2.new(0.65, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(25, 25, 25), Font = Enum.Font.GothamMedium, Text = "70", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13}, fovC)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, fovBox)

fovBox.FocusLost:Connect(function(e)
    if e then
        local val = tonumber(fovBox.Text) or 70
        camera.FieldOfView = math.clamp(val, 30, 120)
    end
end)

-- Server Hop Tab
local shPanel = contents["Server Hop"]
makeButton(shPanel, "Rejoin Same Server", function()
    TeleportService:Teleport(game.PlaceId, player)
end)

-- Setting Tab (Anti-AFK)
local setPanel = contents["Setting"]
makeToggle(setPanel, "Anti-AFK (Prevent Kick)", function(s)
    antiAfkActive = s
end)

player.Idled:Connect(function()
    if antiAfkActive then
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
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

RunService.RenderStepped:Connect(function(delta)
    local char = player.Character
    if cfSpeedActive and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        
        if hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfSpeedVal)
        end
    end
end)

UserInputService.JumpRequest:Connect(function(input, gameProcessed)
    if infJump then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Dragging UI
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
