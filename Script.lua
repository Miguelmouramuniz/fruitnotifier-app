-- TH Fruit Notifier
-- Mini interface nativa, leve, arrastável e minimizável.
-- Detecta frutas que aparecem no workspace, mostra o nome no ESP
-- e envia uma notificação única para cada fruta detectada.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local GUI_NAME = "TH_Fruit_Notifier"
local ACCENT = Color3.fromRGB(220, 30, 45)
local ACCENT_DARK = Color3.fromRGB(125, 14, 25)
local PANEL = Color3.fromRGB(18, 18, 22)
local PANEL_2 = Color3.fromRGB(27, 27, 33)
local TEXT = Color3.fromRGB(245, 245, 248)
local MUTED = Color3.fromRGB(165, 165, 175)

local oldGui = CoreGui:FindFirstChild(GUI_NAME)
if oldGui then
    oldGui:Destroy()
end

local running = true
local espEnabled = true
local notificationsEnabled = true
local minimized = false
local knownFruits = {}
local fruitObjects = {}
local connections = {}
local maxEntries = 30
local entryOrder = 0
local autoTravelEnabled = false
local autoTravelToken = 0

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999
}, CoreGui)

local shadow = make("Frame", {
    Name = "Shadow",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -8, 0, 8),
    Size = UDim2.fromOffset(228, 238),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, shadow)

local window = make("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -8, 0, 8),
    Size = UDim2.fromOffset(228, 238),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
    ClipsDescendants = true
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, window)
make("UIStroke", {Color = Color3.fromRGB(65, 65, 75), Thickness = 1, Transparency = 0.25}, window)

local topbar = make("Frame", {
    Name = "Topbar",
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = PANEL_2,
    BorderSizePixel = 0,
    Active = true
}, window)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, topbar)
local topbarCover = make("Frame", {
    Size = UDim2.new(1, 0, 0, 9),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = PANEL_2,
    BorderSizePixel = 0
}, topbar)

local dragHandle = make("TextButton", {
    Name = "DragHandle",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, -58, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    ZIndex = 1
}, topbar)

local title = make("TextLabel", {
    Name = "Title",
    Position = UDim2.fromOffset(9, 3),
    Size = UDim2.new(1, -112, 0, 20),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "TH Fruit Notifier",
    TextColor3 = TEXT,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)

local subtitle = make("TextLabel", {
    Position = UDim2.fromOffset(9, 19),
    Size = UDim2.new(1, -112, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "ESP e alertas de frutas no mapa",
    TextColor3 = MUTED,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)

local minimizeButton = make("TextButton", {
    Name = "Minimize",
    Position = UDim2.new(1, -50, 0, 7),
    Size = UDim2.fromOffset(19, 19),
    BackgroundColor3 = Color3.fromRGB(48, 48, 58),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "−",
    TextColor3 = TEXT,
    TextSize = 18,
    AutoButtonColor = false,
    ZIndex = 5
}, topbar)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, minimizeButton)

local closeButton = make("TextButton", {
    Name = "Close",
    Position = UDim2.new(1, -28, 0, 7),
    Size = UDim2.fromOffset(19, 19),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = TEXT,
    TextSize = 17,
    AutoButtonColor = false,
    ZIndex = 5
}, topbar)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, closeButton)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(7, 43),
    Size = UDim2.new(1, -14, 1, -50),
    BackgroundTransparency = 1
}, window)

local statusCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = PANEL_2,
    BorderSizePixel = 0
}, content)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, statusCard)
local statusDot = make("Frame", {
    Position = UDim2.fromOffset(8, 9),
    Size = UDim2.fromOffset(12, 12),
    BackgroundColor3 = Color3.fromRGB(60, 220, 110),
    BorderSizePixel = 0
}, statusCard)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, statusDot)
local statusText = make("TextLabel", {
    Position = UDim2.fromOffset(24, 3),
    Size = UDim2.new(1, -42, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "Monitoramento ativo",
    TextColor3 = TEXT,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
}, statusCard)
local countText = make("TextLabel", {
    Position = UDim2.fromOffset(24, 16),
    Size = UDim2.new(1, -42, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "0 frutas encontradas",
    TextColor3 = MUTED,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, statusCard)

local espButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 37),
    Size = UDim2.new(0.5, -3, 0, 23),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamSemibold,
    Text = "ESP: ON",
    TextColor3 = TEXT,
    TextSize = 9,
    AutoButtonColor = false
}, content)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, espButton)

local notifyButton = make("TextButton", {
    Position = UDim2.new(0.5, 3, 0, 37),
    Size = UDim2.new(0.5, -3, 0, 23),
    BackgroundColor3 = Color3.fromRGB(48, 48, 58),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamSemibold,
    Text = "Alertas: ON",
    TextColor3 = TEXT,
    TextSize = 9,
    AutoButtonColor = false
}, content)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, notifyButton)

local autoTravelButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 91),
    Size = UDim2.new(1, 0, 0, 23),
    BackgroundColor3 = Color3.fromRGB(48, 48, 58),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamSemibold,
    Text = "Auto Travel: OFF",
    TextColor3 = TEXT,
    TextSize = 9,
    AutoButtonColor = false
}, content)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, autoTravelButton)

local listTitle = make("TextLabel", {
    Position = UDim2.fromOffset(2, 118),
    Size = UDim2.new(1, -4, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "FRUTAS DETECTADAS",
    TextColor3 = MUTED,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, content)

local list = make("ScrollingFrame", {
    Name = "FruitList",
    Position = UDim2.fromOffset(0, 136),
    Size = UDim2.new(1, 0, 1, -136),
    BackgroundColor3 = Color3.fromRGB(13, 13, 17),
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, content)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, list)
local layout = make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, list)
make("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7)
}, list)

local function setStatus(text, active)
    statusText.Text = text
    statusDot.BackgroundColor3 = active and Color3.fromRGB(60, 220, 110) or Color3.fromRGB(230, 70, 70)
end

local function notifyFruit(name)
    if not notificationsEnabled then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "TH Fruit Notifier",
            Text = "Fruta encontrada: " .. name,
            Duration = 5
        })
    end)
end

local function getRoot(object)
    if not object or not object.Parent then return nil end
    -- O Handle pode ser criado depois do Tool/Model durante o carregamento.
    local handle = object:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then return handle end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then return descendant end
    end
    return nil
end
local function isFruit(object)
    if not object or not object:IsDescendantOf(Workspace) then return false end
    local name = string.lower(object.Name)
    local originalName = string.lower(tostring(object:GetAttribute("OriginalName") or ""))
    local hasFruitName = string.find(name, "fruit", 1, true) or string.find(originalName, "fruit", 1, true)
    local hasFruitRemote = object:FindFirstChild("EatRemote", true) ~= nil
    return (hasFruitName ~= nil or hasFruitRemote) and getRoot(object) ~= nil
end
local function removeESP(object)
    local root = object and object:FindFirstChild("Handle")
    local billboard = root and root:FindFirstChild("THFruitESP")
    if billboard then billboard:Destroy() end
end

local function addESP(object)
    if not espEnabled or not isFruit(object) then return end
    local root = getRoot(object)
    if not root then return end
    if not root:IsA("BasePart") then return end
    local billboard = root:FindFirstChild("THFruitESP")
    if not billboard then
        billboard = make("BillboardGui", {
            Name = "THFruitESP",
            Adornee = root,
            AlwaysOnTop = true,
            Size = UDim2.fromOffset(165, 28),
            StudsOffset = Vector3.new(0, 2.1, 0)
        }, root)
        local background = make("Frame", {
            Name = "Background",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(12, 12, 16),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0
        }, billboard)
        make("UICorner", {CornerRadius = UDim.new(0, 5)}, background)
        make("UIStroke", {Color = ACCENT, Thickness = 1}, background)
        local label = make("TextLabel", {
            Name = "Label",
            Position = UDim2.fromOffset(5, 3),
            Size = UDim2.new(1, -10, 1, -6),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextColor3 = TEXT,
            TextStrokeTransparency = 0.35,
            TextSize = 10,
            TextWrapped = true
        }, billboard)
    end
    local label = billboard:FindFirstChild("Label")
    if label then
        local distance = 0
        local character = LocalPlayer.Character
        local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
        if playerRoot then distance = math.floor((playerRoot.Position - root.Position).Magnitude / 3) end
        label.Text = object.Name .. "  •  " .. distance .. "m"
    end
end

local function addListEntry(object)
    if knownFruits[object] then return end
    knownFruits[object] = true
    table.insert(fruitObjects, object)
    while #fruitObjects > maxEntries do
        local oldest = table.remove(fruitObjects, 1)
        knownFruits[oldest] = nil
    end
    entryOrder = entryOrder + 1
    local entry = make("TextLabel", {
        Name = "FruitEntry",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = PANEL_2,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        Text = "  " .. object.Name,
        TextColor3 = TEXT,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = -entryOrder
    }, list)
    make("UICorner", {CornerRadius = UDim.new(0, 5)}, entry)
    make("UIStroke", {Color = Color3.fromRGB(65, 65, 75), Thickness = 1, Transparency = 0.4}, entry)
    countText.Text = tostring(#fruitObjects) .. " frutas encontradas"
    notifyFruit(object.Name)
end

local function scanFruit(object)
    if not isFruit(object) then return end
    addListEntry(object)
    addESP(object)
end

local function removeAllESP()
    for _, object in ipairs(Workspace:GetChildren()) do
        removeESP(object)
    end
end

local function scanAll()
    for _, object in ipairs(Workspace:GetChildren()) do
        if isFruit(object) then
            scanFruit(object)
            if espEnabled then addESP(object) end
        end
    end
end

local function getNearestFruit()
    local character = LocalPlayer.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not playerRoot then return nil end
    local nearest, nearestDistance = nil, math.huge
    for _, object in ipairs(Workspace:GetChildren()) do
        if isFruit(object) then
            local root = getRoot(object)
            if root and root:IsA("BasePart") then
                local distance = (playerRoot.Position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearest, nearestDistance = object, distance
                end
            end
        end
    end
    return nearest
end

local function stopAutoTravel(message)
    autoTravelEnabled = false
    autoTravelToken = autoTravelToken + 1
    autoTravelButton.Text = "Auto Travel: OFF"
    autoTravelButton.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    if message then setStatus(message, true) end
end

local function teleportToFruit(object)
    local character = LocalPlayer.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    local targetRoot = object and getRoot(object)
    if not character or not playerRoot or not targetRoot or not targetRoot:IsA("BasePart") then
        return false
    end
    local targetCFrame = targetRoot.CFrame * CFrame.new(0, 4, 0)
    return pcall(function()
        character:PivotTo(targetCFrame)
    end)
end

local function startAutoTravel()
    if autoTravelEnabled then
        stopAutoTravel("Auto Travel cancelado")
        return
    end

    autoTravelEnabled = true
    autoTravelToken = autoTravelToken + 1
    local thisToken = autoTravelToken
    autoTravelButton.Text = "Auto Travel: ON"
    autoTravelButton.BackgroundColor3 = ACCENT
    setStatus("Procurando frutas spawnadas", true)

    task.spawn(function()
        while running and autoTravelEnabled and thisToken == autoTravelToken do
            local target = getNearestFruit()
            if target and target.Parent then
                if teleportToFruit(target) then
                    setStatus("Foi até " .. target.Name, true)
                end
                task.wait(0.8)
            else
                setStatus("Aguardando fruta spawnar", true)
                task.wait(0.5)
            end
        end
    end)
end

local dragging = false
local dragStart
local startPosition
connect(dragHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        shadow.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X + 2, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y + 3)
    end
end)

connect(minimizeButton.MouseButton1Click, function()
    minimized = not minimized
    content.Visible = not minimized
    window.Size = minimized and UDim2.fromOffset(228, 36) or UDim2.fromOffset(228, 238)
    shadow.Size = window.Size
    minimizeButton.Text = minimized and "+" or "−"
end)

connect(espButton.MouseButton1Click, function()
    espEnabled = not espEnabled
    espButton.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    espButton.BackgroundColor3 = espEnabled and ACCENT or Color3.fromRGB(48, 48, 58)
    if not espEnabled then removeAllESP() else scanAll() end
end)

connect(notifyButton.MouseButton1Click, function()
    notificationsEnabled = not notificationsEnabled
    notifyButton.Text = notificationsEnabled and "Alertas: ON" or "Alertas: OFF"
    notifyButton.BackgroundColor3 = notificationsEnabled and Color3.fromRGB(48, 48, 58) or ACCENT_DARK
end)

connect(autoTravelButton.MouseButton1Click, function()
    startAutoTravel()
end)
connect(closeButton.MouseButton1Click, function()
    running = false
    stopAutoTravel()
    disconnectAll()
    removeAllESP()
    gui:Destroy()
end)

connect(Workspace.ChildAdded, function(object)
    -- Tenta depois que o objeto entra e novamente quando o Handle termina de carregar.
    task.delay(0.15, function()
        if running then scanFruit(object) end
    end)
    task.delay(0.75, function()
        if running then scanFruit(object) end
    end)
end)
connect(Workspace.DescendantAdded, function(descendant)
    -- Também captura frutas já existentes cujo Handle aparece depois.
    if descendant.Name == "Handle" or descendant:IsA("Tool") then
        task.delay(0.2, function()
            if running then scanAll() end
        end)
    end
end)
connect(Workspace.ChildRemoved, function(object)
    if knownFruits[object] then knownFruits[object] = nil end
    removeESP(object)
end)

local scanClock = 0
connect(RunService.Heartbeat, function(deltaTime)
    if not running then return end
    scanClock = scanClock + deltaTime
    if scanClock < 0.25 then return end
    scanClock = 0
    for _, object in ipairs(Workspace:GetChildren()) do
        -- Registra a fruta na lista assim que o Handle ficar disponível.
        if isFruit(object) then scanFruit(object) end
    end
end)
scanAll()
-- Repetições durante os primeiros 10 segundos cobrem o carregamento inicial do servidor.
task.spawn(function()
    for _ = 1, 40 do
        if not running then return end
        scanAll()
        task.wait(0.25)
    end
end)
setStatus("Monitoramento ativo", true)
