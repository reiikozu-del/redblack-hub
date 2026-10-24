-- language: Luau, file: core.lua, target: GitHub Raw (Anti-Pause Smooth Teleport)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- ===== Palette =====
local COL = {
    bg        = Color3.fromRGB(13, 13, 16),
    bg2       = Color3.fromRGB(20, 20, 24),
    bg3       = Color3.fromRGB(28, 28, 33),
    stroke    = Color3.fromRGB(180, 20, 20),
    strokeDim = Color3.fromRGB(60, 30, 30),
    accent    = Color3.fromRGB(220, 40, 40),
    accent2   = Color3.fromRGB(255, 90, 90),
    text      = Color3.fromRGB(235, 235, 240),
    textDim   = Color3.fromRGB(160, 160, 170),
    textMute  = Color3.fromRGB(110, 110, 120),
    on        = Color3.fromRGB(46, 18, 18),
    ok        = Color3.fromRGB(60, 200, 120),
}

-- ===== State =====
local noclip, infJump, wsVal = false, false, 16
local cfSpeedActive, cfSpeedVal = false, 1
local instantPromptActive = false
local waypoints = {nil, nil}
local espActive, espConns = false, {}
local flyActive, flySpeed = false, 50
local antiAfkActive, fullbrightActive = false, false
local tapTpActive = false
local isSpectating, spectateTarget = false, nil
local originalCameraSubject = nil
local smoothTpRunning = false

-- ===== Factory =====
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end
local function corner(r, parent) return make("UICorner", {CornerRadius = UDim.new(0, r)}, parent) end
local function stroke(c, t, parent) return make("UIStroke", {Color = c, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent) end
local function padding(p, parent) return make("UIPadding", {PaddingTop = UDim.new(0,p), PaddingBottom = UDim.new(0,p), PaddingLeft = UDim.new(0,p), PaddingRight = UDim.new(0,p)}, parent) end
local function gap(p, parent) return make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, p)}, parent) end

-- ===== Smooth Teleport Core =====
-- Teknik: split CFrame ke step kecil (default 20 stud/frame), lock Velocity + State biar
-- physics engine nggak ngirim delta raksasa ke server (yang memicu "Gameplay Paused").
local function smoothTeleport(targetCFrame, maxStep, stepDelay)
    if smoothTpRunning then return end
    maxStep = maxStep or 20
    stepDelay = stepDelay or 0.015

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    smoothTpRunning = true

    -- save physics state
    local oldAutoRotate = hrp.AutoRotate
    local oldCanCollide = hrp.CanCollide
    local bv = Instance.new("BodyVelocity")
    bv.Name = "HubSmoothTpVel"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    hrp.AutoRotate = false
    hrp.CanCollide = false
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    local startCF = hrp.CFrame
    local startPos = startCF.Position
    local targetPos = targetCFrame.Position
    local dist = (targetPos - startPos).Magnitude
    local steps = math.max(1, math.ceil(dist / maxStep))
    local stepVec = (targetPos - startPos) / steps

    local currentStep = 0
    local conn

    local function cleanup()
        if conn then conn:Disconnect() end
        if bv and bv.Parent then bv:Destroy() end
        if hrp and hrp.Parent then
            hrp.AutoRotate = oldAutoRotate
            hrp.CanCollide = oldCanCollide
        end
        if hum and hum.Parent then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        smoothTpRunning = false
    end

    conn = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent or not hum or hum.Health <= 0 then cleanup() return end

        currentStep = currentStep + 1
        local p = currentStep / steps
        -- interpolate posisi + rotasi target akhir
        local interpPos = startPos + stepVec * currentStep
        local interpCF = CFrame.new(interpPos) * startCF.Rotation:Lerp(targetCFrame.Rotation, p)

        -- teleport per-step, physics engine lihat ini sebagai gerakan wajar
        hrp.CFrame = interpCF

        -- zero velocity biar nggak nambah
        if bv then bv.Velocity = Vector3.zero end

        if currentStep >= steps then
            hrp.CFrame = targetCFrame
            cleanup()
        end
    end)
end

-- ===== Screen =====
local screen = make("ScreenGui", {Name = "RedBlackHubModular", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, gui)

-- ===== Floating Waypoint Buttons =====
local floatBar = make("Frame", {
    Size = UDim2.new(0, 100, 0, 46), Position = UDim2.new(0, 20, 0, 90),
    BackgroundTransparency = 1, Visible = false, ZIndex = 10
}, screen)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)}, floatBar)

local function makeFloatBtn(label, layoutOrder)
    local b = make("TextButton", {
        Size = UDim2.new(0, 46, 0, 46), BackgroundColor3 = COL.stroke,
        TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 11,
        Text = label, AutoButtonColor = false, LayoutOrder = layoutOrder
    }, floatBar)
    corner(8, b)
    stroke(COL.accent2, 1, b)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = COL.accent end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = COL.stroke end)
    return b
end
local floatBack1 = makeFloatBtn("BACK\n1", 1)
local floatBack2 = makeFloatBtn("BACK\n2", 2)

-- ===== Open Button =====
local openBtn = make("TextButton", {
    Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = COL.bg2, TextColor3 = COL.accent,
    Font = Enum.Font.GothamBold, TextSize = 18, Text = "UI",
    Visible = false, ZIndex = 10, AutoButtonColor = false
}, screen)
corner(10, openBtn)
stroke(COL.stroke, 2, openBtn)
openBtn.MouseEnter:Connect(function() openBtn.BackgroundColor3 = COL.bg3 end)
openBtn.MouseLeave:Connect(function() openBtn.BackgroundColor3 = COL.bg2 end)

-- ===== Main Frame =====
local main = make("Frame", {
    Size = UDim2.new(0, 560, 0, 380),
    Position = UDim2.new(0.5, -280, 0.5, -190),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0
}, screen)
corner(12, main)
stroke(COL.stroke, 1.5, main)

-- ===== Top Bar =====
local topBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = COL.bg2, BorderSizePixel = 0
}, main)
corner(12, topBar)
make("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6), BackgroundColor3 = COL.bg2, BorderSizePixel = 0}, topBar)

make("Frame", {
    Size = UDim2.new(0, 4, 0, 22), Position = UDim2.new(0, 16, 0.5, -11),
    BackgroundColor3 = COL.accent, BorderSizePixel = 0
}, topBar)
make("TextLabel", {
    Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "SYSTEM // HUB",
    TextColor3 = COL.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
}, topBar)

local minBtn = make("TextButton", {
    Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -40, 0.5, -16),
    BackgroundColor3 = COL.bg3, Font = Enum.Font.GothamBold, Text = "–",
    TextColor3 = COL.textDim, TextSize = 18, AutoButtonColor = false
}, topBar)
corner(6, minBtn)
minBtn.MouseEnter:Connect(function() minBtn.BackgroundColor3 = COL.accent; minBtn.TextColor3 = COL.text end)
minBtn.MouseLeave:Connect(function() minBtn.BackgroundColor3 = COL.bg3; minBtn.TextColor3 = COL.textDim end)

-- ===== Sidebar =====
local sidebar = make("ScrollingFrame", {
    Size = UDim2.new(0, 140, 1, -60), Position = UDim2.new(0, 12, 0, 50),
    BackgroundColor3 = COL.bg2, BorderSizePixel = 0,
    CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y
}, main)
corner(8, sidebar)
padding(8, sidebar)
gap(4, sidebar)

local contentArea = make("Frame", {
    Size = UDim2.new(1, -168, 1, -60), Position = UDim2.new(0, 156, 0, 50),
    BackgroundTransparency = 1, BorderSizePixel = 0
}, main)

-- ===== Tabs =====
local tabs, contents, tabBtns = {"Profile", "Menu", "Misc", "Server Hop", "Setting"}, {}, {}
local activeTab = 1

local function setActiveTab(idx)
    for i, btn in ipairs(tabBtns) do
        if i == idx then
            btn.BackgroundColor3 = COL.stroke
            btn.TextColor3 = COL.text
        else
            btn.BackgroundColor3 = COL.bg3
            btn.TextColor3 = COL.textDim
        end
    end
    for name, p in pairs(contents) do p.Visible = false end
    contents[tabs[idx]].Visible = true
    activeTab = idx
end

for i, name in ipairs(tabs) do
    local tBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = COL.bg3,
        Font = Enum.Font.GothamMedium, Text = name,
        TextColor3 = COL.textDim, TextSize = 13, LayoutOrder = i,
        AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left
    }, sidebar)
    corner(6, tBtn)
    padding(10, tBtn)
    tBtn.MouseEnter:Connect(function()
        if activeTab ~= i then tBtn.BackgroundColor3 = COL.bg end
    end)
    tBtn.MouseLeave:Connect(function()
        if activeTab ~= i then tBtn.BackgroundColor3 = COL.bg3 end
    end)
    tBtn.MouseButton1Click:Connect(function() setActiveTab(i) end)
    tabBtns[i] = tBtn

    local panel = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = (i == 1), CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, contentArea)
    gap(10, panel)
    contents[name] = panel
end

-- ===== Components =====
local function sectionHeader(parent, text)
    local f = make("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1}, parent)
    make("Frame", {Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 0, 0.5, -6), BackgroundColor3 = COL.accent, BorderSizePixel = 0}, f)
    make("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = text, TextColor3 = COL.accent2, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left
    }, f)
    return f
end

local function makeToggle(parentPanel, text, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = COL.bg2,
        Font = Enum.Font.GothamMedium, Text = "", TextColor3 = COL.text,
        TextSize = 13, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left
    }, parentPanel)
    corner(6, btn)
    stroke(COL.strokeDim, 1, btn)
    padding(12, btn)
    make("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = COL.text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left
    }, btn)

    local pill = make("Frame", {Size = UDim2.new(0, 46, 0, 22), Position = UDim2.new(1, -46, 0.5, -11), BackgroundColor3 = COL.bg3, BorderSizePixel = 0}, btn)
    corner(11, pill)
    local dot = make("Frame", {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = COL.textMute, BorderSizePixel = 0}, pill)
    corner(8, dot)

    local state = false
    btn.MouseEnter:Connect(function() if not state then btn.BackgroundColor3 = COL.bg3 end end)
    btn.MouseLeave:Connect(function() if not state then btn.BackgroundColor3 = COL.bg2 end end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.BackgroundColor3 = COL.on
            pill.BackgroundColor3 = COL.accent
            dot.BackgroundColor3 = COL.text
            dot.Position = UDim2.new(1, -19, 0.5, -8)
            btn.TextColor3 = COL.accent2
        else
            btn.BackgroundColor3 = COL.bg2
            pill.BackgroundColor3 = COL.bg3
            dot.BackgroundColor3 = COL.textMute
            dot.Position = UDim2.new(0, 3, 0.5, -8)
            btn.TextColor3 = COL.text
        end
        callback(state)
    end)
end

local function makeButton(parentPanel, text, callback, accent)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = accent and COL.stroke or COL.bg2,
        Font = Enum.Font.GothamMedium, Text = text,
        TextColor3 = accent and COL.text or COL.textDim, TextSize = 13, AutoButtonColor = false
    }, parentPanel)
    corner(6, btn)
    stroke(COL.strokeDim, 1, btn)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = accent and COL.accent or COL.bg3; btn.TextColor3 = COL.text end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = accent and COL.stroke or COL.bg2; btn.TextColor3 = accent and COL.text or COL.textDim end)
    btn.MouseButton1Click:Connect(callback)
end

local function makeInput(parentPanel, label, placeholder, initial, onCommit, isNumeric)
    local f = make("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = COL.bg2, BorderSizePixel = 0}, parentPanel)
    corner(6, f)
    stroke(COL.strokeDim, 1, f)
    padding(12, f)
    make("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, Text = label, TextColor3 = COL.text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left
    }, f)
    local box = make("TextBox", {
        Size = UDim2.new(0.42, 0, 0, 26), Position = UDim2.new(0.58, 0, 0.5, -13),
        BackgroundColor3 = COL.bg3, Font = Enum.Font.GothamMedium, Text = initial,
        PlaceholderText = placeholder or "", TextColor3 = COL.text,
        PlaceholderColor3 = COL.textMute, TextSize = 13, ClearTextOnFocus = false
    }, f)
    corner(5, box)
    padding(6, box)
    box.FocusLost:Connect(function(e)
        if not e then return end
        if isNumeric then
            local n = tonumber(box.Text)
            if not n then box.Text = initial return end
        end
        onCommit(box.Text)
    end)
    return box
end

local function makeRow(parentPanel, height) return make("Frame", {Size = UDim2.new(1, 0, 0, height or 42), BackgroundTransparency = 1}, parentPanel) end

local function twoBtnRow(parentPanel, t1, cb1, t2, cb2)
    local f = makeRow(parentPanel, 40)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)}, f)
    local function b(text, cb)
        local btn = make("TextButton", {
            Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = COL.bg2,
            Font = Enum.Font.GothamMedium, Text = text,
            TextColor3 = COL.textDim, TextSize = 13, AutoButtonColor = false
        }, f)
        corner(6, btn)
        stroke(COL.strokeDim, 1, btn)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = COL.bg3; btn.TextColor3 = COL.text end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = COL.bg2; btn.TextColor3 = COL.textDim end)
        btn.MouseButton1Click:Connect(cb)
    end
    b(t1, cb1)
    b(t2, cb2)
end

-- ===== Profile =====
local pPanel = contents["Profile"]
sectionHeader(pPanel, "MOVEMENT")
makeInput(pPanel, "WalkSpeed", "16", "16", function(v) wsVal = math.clamp(tonumber(v) or 16, 0, 500) end, true)
makeInput(pPanel, "CFrame Speed (0.1–5)", "1", "1", function(v) cfSpeedVal = math.clamp(tonumber(v) or 1, 0.1, 5) end, true)
makeToggle(pPanel, "CFrame Speed Bypass", function(s) cfSpeedActive = s end)
makeToggle(pPanel, "NoClip", function(s) noclip = s end)
makeToggle(pPanel, "Infinite Jump", function(s) infJump = s end)

-- ===== Menu =====
local mPanel = contents["Menu"]
sectionHeader(mPanel, "INTERACTION")
makeToggle(mPanel, "Instant Prompt", function(s) instantPromptActive = s end)
makeToggle(mPanel, "Tap TP (Mobile Friendly)", function(s) tapTpActive = s end)

sectionHeader(mPanel, "WAYPOINTS (2 SLOT)")
local slotRow = makeRow(mPanel, 42)
local slotLabel = make("TextLabel", {
    Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium, Text = "Active Slot", TextColor3 = COL.text,
    TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left
}, slotRow)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)}, slotRow)

local activeSlot = 1
local slotBtns = {}
for i = 1, 2 do
    local b = make("TextButton", {
        Size = UDim2.new(0.27, -4, 1, 0), BackgroundColor3 = i == 1 and COL.stroke or COL.bg2,
        Font = Enum.Font.GothamMedium, Text = "SLOT " .. i,
        TextColor3 = i == 1 and COL.text or COL.textDim, TextSize = 12, AutoButtonColor = false
    }, slotRow)
    corner(6, b)
    stroke(COL.strokeDim, 1, b)
    b.MouseButton1Click:Connect(function()
        activeSlot = i
        for j, bb in ipairs(slotBtns) do
            bb.BackgroundColor3 = j == i and COL.stroke or COL.bg2
            bb.TextColor3 = j == i and COL.text or COL.textDim
        end
    end)
    slotBtns[i] = b
end

twoBtnRow(mPanel,
    "Save Slot", function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            waypoints[activeSlot] = hrp.CFrame
            floatBar.Visible = true
            local fb = activeSlot == 1 and floatBack1 or floatBack2
            fb.BackgroundColor3 = COL.ok
            task.delay(0.4, function() fb.BackgroundColor3 = COL.stroke end)
        end
    end,
    "Clear Slot", function() waypoints[activeSlot] = nil end
)

twoBtnRow(mPanel,
    "Back Slot 1", function() if waypoints[1] then smoothTeleport(waypoints[1], 20, 0.015) end end,
    "Back Slot 2", function() if waypoints[2] then smoothTeleport(waypoints[2], 20, 0.015) end end
)

sectionHeader(mPanel, "PLAYER")
local tpBox = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = COL.bg2,
    Font = Enum.Font.GothamMedium, Text = "",
    PlaceholderText = "Ketik Nama Player...", PlaceholderColor3 = COL.textMute,
    TextColor3 = COL.text, TextSize = 13, ClearTextOnFocus = false
}, mPanel)
corner(6, tpBox)
stroke(COL.strokeDim, 1, tpBox)
padding(10, tpBox)

local function findPlayer(name)
    name = string.lower(name or "")
    if name == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and (string.find(string.lower(p.Name), name, 1, true) or string.find(string.lower(p.DisplayName), name, 1, true)) then
            return p
        end
    end
    return nil
end

makeButton(mPanel, "Teleport Ke Player", function()
    local p = findPlayer(tpBox.Text)
    if not p then return end
    local c, t = player.Character, p.Character
    if c and t and c:FindFirstChild("HumanoidRootPart") and t:FindFirstChild("HumanoidRootPart") then
        smoothTeleport(t.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3), 20, 0.015)
    end
end)

local function stopSpectate()
    if isSpectating then
        camera.CameraSubject = originalCameraSubject or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
        isSpectating, spectateTarget, originalCameraSubject = false, nil, nil
    end
end

makeButton(mPanel, "Spectate / Tonton Player", function()
    if isSpectating then stopSpectate() return end
    local p = findPlayer(tpBox.Text)
    if not p or not p.Character then return end
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    originalCameraSubject = camera.CameraSubject
    camera.CameraSubject = hum
    isSpectating, spectateTarget = true, p
end)

Players.PlayerRemoving:Connect(function(p)
    if isSpectating and p == spectateTarget then stopSpectate() end
end)

-- ===== Misc =====
local miscPanel = contents["Misc"]
sectionHeader(miscPanel, "VISUAL")

local function clearEspFor(char)
    if not char then return end
    local hl = char:FindFirstChild("HubHighlight")
    if hl then hl:Destroy() end
end

local function applyEspTo(p)
    if p == player or not espActive then return end
    local function onChar(char)
        if not espActive then clearEspFor(char) return end
        if not char:FindFirstChild("HubHighlight") then
            local hl = Instance.new("Highlight")
            hl.Name = "HubHighlight"
            hl.Adornee = char
            hl.FillColor = COL.accent
            hl.OutlineColor = COL.text
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
    end
    local c = p.CharacterAdded:Connect(onChar)
    table.insert(espConns, c)
    if p.Character then onChar(p.Character) end
end

local function teardownEsp()
    for _, c in ipairs(espConns) do c:Disconnect() end
    espConns = {}
    for _, p in ipairs(Players:GetPlayers()) do clearEspFor(p.Character) end
end

makeToggle(miscPanel, "Player ESP", function(s)
    espActive = s
    if s then for _, p in ipairs(Players:GetPlayers()) do applyEspTo(p) end
    else teardownEsp() end
end)

Players.PlayerAdded:Connect(function(p) if espActive then applyEspTo(p) end end)

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
    if s then
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

makeInput(miscPanel, "FOV (30–120)", "70", "70", function(v) camera.FieldOfView = math.clamp(tonumber(v) or 70, 30, 120) end, true)

-- ===== Server Hop =====
local shPanel = contents["Server Hop"]
sectionHeader(shPanel, "SESSION")
makeButton(shPanel, "Rejoin Same Server", function()
    TeleportService:Teleport(game.PlaceId, player)
end)

-- ===== Setting =====
local setPanel = contents["Setting"]
sectionHeader(setPanel, "ANTI-KICK")
makeToggle(setPanel, "Anti-AFK (Prevent Kick)", function(s) antiAfkActive = s end)

player.Idled:Connect(function()
    if antiAfkActive then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ===== Loops =====
RunService.Stepped:Connect(function()
    if instantPromptActive then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.HoldDuration > 0 then
                obj.HoldDuration = 0
            end
        end
    end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum and hum.WalkSpeed ~= wsVal then hum.WalkSpeed = wsVal end
        if noclip and hrp then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
        if flyActive and hrp then
            local bv = hrp:FindFirstChild("HubFlyVel")
            local bg = hrp:FindFirstChild("HubFlyGyro")
            if bv and bg then
                bg.CFrame = camera.CFrame
                local md = hum.MoveDirection
                bv.Velocity = md.Magnitude > 0 and md * flySpeed or Vector3.zero
            end
        end
    end
end)

RunService.RenderStepped:Connect(function(delta)
    if not cfSpeedActive then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp and hum.MoveDirection.Magnitude > 0 then
        hrp.CFrame = hrp.CFrame + hum.MoveDirection * (cfSpeedVal * 60 * delta)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infJump then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not tapTpActive then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local mouse = player:GetMouse()
    if not mouse or not mouse.Hit then return end
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        smoothTeleport(CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)), 15, 0.01)
    end
end)

-- ===== Dragging =====
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)
local btnDragging, btnDragStart, btnStartPos
openBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.User
