--[[

    EGOY RIDE A PET - ESP Menu v3.0

    Original by ThiAez | Redesigned & Translated

    FEATURES:

    - ESP with aura + name + distance

    - Individual green ESP

    - Egg counter

    - Auto-updating list

    - Improved search

    - Sort by name or distance

    - Safer TP

    - Auto Best Egg with resilience

    - AutoFarm per Egg + red stop button

    - Egg icons from Index > EggsHolder

    - Smooth button & menu animations

    - Android / PC optimized

    - Minimize and drag

    - Configurable keybind for TP Home

]]

--==================================================

-- SERVICES

--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- EASY CONFIG
--==================================================

local Config = {
    -- ESP
    ESPFillTransparency = 0.50,
    ESPOutlineTransparency = 0,
    ESPNameSize = 13,
    ESPDistanceSize = 11,

    -- Colors
    GlobalESPColor = Color3.fromRGB(255, 255, 0),
    CustomESPColor = Color3.fromRGB(0, 255, 0),

    -- TP
    TPHeight = 3,
    MovementSpeed = 500,

    -- Auto Egg
    BestEggName = "cherub",
    AutoEggHoldTime = 3,
    AutoFarmHoldTime = 2,
    AutoEggDelay = 0.8,

    -- UI
    PCWidth = 340,
    PCHeight = 540,
    MobileWidth = 300,
    MobileHeight = 520,
    AnimationTime = 0.18,
}

-- Cool theme palette
local Theme = {
    Background = Color3.fromRGB(12, 14, 24),
    Surface = Color3.fromRGB(22, 26, 40),
    SurfaceLight = Color3.fromRGB(34, 40, 60),
    Accent = Color3.fromRGB(140, 90, 255),        -- purple
    Accent2 = Color3.fromRGB(80, 200, 255),       -- cyan
    Success = Color3.fromRGB(40, 210, 130),
    Danger = Color3.fromRGB(235, 70, 90),
    Warning = Color3.fromRGB(255, 190, 60),
    Text = Color3.fromRGB(235, 240, 255),
    TextDim = Color3.fromRGB(150, 160, 185),
    Outline = Color3.fromRGB(60, 70, 100),
}

--==================================================
-- MAIN FOLDERS / OBJECTS
--==================================================

local TargetParent = LocalPlayer:WaitForChild("PlayerGui")
local RenderedEggsFolder = Workspace:WaitForChild("RenderedEggs", 10)

if not RenderedEggsFolder then
    warn("[EGOY] Workspace.RenderedEggs not found. GUI will still open.")
end

--==================================================
-- STATES
--==================================================

local mainESPActive = false
local autoBestEggActive = false
local autoBestEggThread = nil
local autoFarmActive = false
local autoFarmThread = nil
local autoFarmEggs = {}
local autoFarmProcessed = {}
local autoFarmCurrentName = nil
local StopAutoFarmBtn
local StatusLabel
local currentSearchQuery = ""
local sortMode = "Name"
local tpKeybind = Enum.KeyCode.T
local listeningForKey = false
local isMobileMode = true  -- default to mobile
local isMinimized = false
local movementMode = "AutoFarm"
local movementActive = false
local movementHumanoid = nil
local movementPartsState = nil
local ModeAutoFarmBtn
local ModeTeleportBtn

-- Per-egg data table
local eggData = {}

--==================================================
-- SMALL HELPERS
--==================================================

local function getCharacter()
    return LocalPlayer.Character
end

local function getRootPart()
    local character = getCharacter()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

--==================================================
-- EGG IMAGE
--==================================================

local function getEggImage(eggName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return "" end
    local main = playerGui:FindFirstChild("Main")
    local index = main and main:FindFirstChild("Index")
    local holders = index and index:FindFirstChild("Holders")
    local eggsHolder = holders and holders:FindFirstChild("EggsHolder")
    if not eggsHolder then return "" end
    local eggFrame = eggsHolder:FindFirstChild(eggName)
    if not eggFrame then return "" end
    local imageLabel = eggFrame:FindFirstChild("ImageLabel")
    if imageLabel and imageLabel:IsA("ImageLabel") then
        return imageLabel.Image or ""
    end
    return ""
end

local function getTargetCFrame(target)
    if not target or not target.Parent then return nil end
    if target:IsA("Model") then return target:GetPivot() end
    if target:IsA("BasePart") then return target.CFrame end
    return nil
end

local function getTargetPosition(target)
    local targetCFrame = getTargetCFrame(target)
    if not targetCFrame then return nil end
    return targetCFrame.Position
end

local function getDistanceToTarget(target)
    local root = getRootPart()
    local targetPosition = getTargetPosition(target)
    if not root or not targetPosition then return math.huge end
    return (root.Position - targetPosition).Magnitude
end

local function tween(object, properties, duration)
    if not object or not object.Parent then return end
    local info = TweenInfo.new(
        duration or Config.AnimationTime,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    TweenService:Create(object, info, properties):Play()
end

--==================================================
-- ESP: CREATE NAME + DISTANCE
--==================================================

local function createEggLabel(egg)
    local data = eggData[egg]
    if not data then return end
    if data.NameBillboard and data.NameBillboard.Parent then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EggESP_Info"
    billboard.Size = UDim2.new(0, 180, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Enabled = false
    billboard.Parent = egg

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "EggName"
    nameLabel.Size = UDim2.new(1, 0, 0, 23)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = egg.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.35
    nameLabel.TextSize = Config.ESPNameSize
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "Distance"
    distanceLabel.Size = UDim2.new(1, 0, 0, 18)
    distanceLabel.Position = UDim2.new(0, 0, 0, 22)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0 studs"
    distanceLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    distanceLabel.TextStrokeTransparency = 0.4
    distanceLabel.TextSize = Config.ESPDistanceSize
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = billboard

    data.NameBillboard = billboard
end

local function updateEggLabel(egg)
    local data = eggData[egg]
    if not data or not data.NameBillboard then return end
    local billboard = data.NameBillboard
    if not billboard.Parent then return end

    local nameLabel = billboard:FindFirstChild("EggName")
    local distanceLabel = billboard:FindFirstChild("Distance")

    if nameLabel then nameLabel.Text = egg.Name end
    if distanceLabel then
        local distance = getDistanceToTarget(egg)
        if distance == math.huge then
            distanceLabel.Text = "?"
        else
            distanceLabel.Text = string.format("%d studs", math.floor(distance + 0.5))
        end
    end
end

--==================================================
-- ESP: UPDATE ONE EGG
--==================================================

local function updateEggESP(egg)
    if not egg then return end
    if not egg:IsA("Model") and not egg:IsA("BasePart") then return end

    if not eggData[egg] then
        eggData[egg] = {
            Highlight = nil,
            NameBillboard = nil,
            CustomColor = Config.CustomESPColor,
            CustomActive = false
        }
    end

    local data = eggData[egg]
    local shouldShow = false
    local color = Config.GlobalESPColor

    if data.CustomActive then
        shouldShow = true
        color = data.CustomColor or Config.CustomESPColor
    elseif mainESPActive then
        shouldShow = true
        color = Config.GlobalESPColor
    end

    if shouldShow then
        if not data.Highlight or not data.Highlight.Parent then
            local highlight = Instance.new("Highlight")
            highlight.Name = "EggESP_Highlight"
            highlight.Adornee = egg
            highlight.FillTransparency = Config.ESPFillTransparency
            highlight.OutlineTransparency = Config.ESPOutlineTransparency
            highlight.Parent = egg
            data.Highlight = highlight
        end

        data.Highlight.FillColor = color
        data.Highlight.OutlineColor = color
        data.Highlight.Enabled = true

        createEggLabel(egg)
        if data.NameBillboard then data.NameBillboard.Enabled = true end
        updateEggLabel(egg)
    else
        if data.Highlight then data.Highlight.Enabled = false end
        if data.NameBillboard then data.NameBillboard.Enabled = false end
    end
end

local function updateAllESP()
    if not RenderedEggsFolder then return end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        updateEggESP(egg)
    end
end

local function applyGlobalESP(state)
    mainESPActive = state
    updateAllESP()
end

--==================================================
-- CLEANUP REMOVED EGG
--==================================================

local function removeEggData(egg)
    local data = eggData[egg]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.NameBillboard then data.NameBillboard:Destroy() end
    eggData[egg] = nil
end

--==================================================
-- TP TO OBJECT
--==================================================

local function teleportToModel(target)
    local root = getRootPart()
    if not root then return false end
    local targetCFrame = getTargetCFrame(target)
    if not targetCFrame then return false end
    root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
    return true
end

--==================================================
-- NOCLIP MOVEMENT
--==================================================

local function setNoclip(enabled)
    local character = getCharacter()
    if not character then return end
    if enabled then
        movementPartsState = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                movementPartsState[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    elseif movementPartsState then
        for part, oldCanCollide in pairs(movementPartsState) do
            if part and part.Parent then part.CanCollide = oldCanCollide end
        end
        movementPartsState = nil
    end
end

local function moveToModel(target)
    if movementMode == "Teleport" then return teleportToModel(target) end
    if movementActive then return false end

    local character = getCharacter()
    local root = getRootPart()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local targetCFrame = getTargetCFrame(target)
    if not root or not humanoid or not targetCFrame then return false end

    local destination = targetCFrame.Position + Vector3.new(0, Config.TPHeight, 0)
    local startDistance = (root.Position - destination).Magnitude

    if startDistance <= 2 then
        root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
        return true
    end

    movementActive = true
    movementHumanoid = humanoid
    local oldAutoRotate = humanoid.AutoRotate
    local success = false
    local startTime = os.clock()
    local maxTime = math.max(3, (startDistance / Config.MovementSpeed) + 2)

    setNoclip(true)
    humanoid.AutoRotate = false

    while movementActive and os.clock() - startTime <= maxTime do
        if not target or not target.Parent then break end
        if getRootPart() ~= root then break end
        local offset = destination - root.Position
        local distance = offset.Magnitude
        if distance <= 2 then
            root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
            success = true
            break
        end
        local dt = RunService.Heartbeat:Wait()
        local step = math.min(distance, Config.MovementSpeed * dt)
        root.CFrame = root.CFrame + offset.Unit * step
    end

    movementActive = false
    if humanoid.Parent then humanoid.AutoRotate = oldAutoRotate end
    movementHumanoid = nil
    setNoclip(false)
    return success
end

local function stopMovement()
    movementActive = false
    if movementHumanoid and movementHumanoid.Parent then movementHumanoid.AutoRotate = true end
    movementHumanoid = nil
    setNoclip(false)
end

local function updateMovementModeButtons()
    if not ModeAutoFarmBtn or not ModeTeleportBtn then return end
    if movementMode == "AutoFarm" then
        ModeAutoFarmBtn.BackgroundColor3 = Theme.Success
        ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ModeTeleportBtn.BackgroundColor3 = Theme.SurfaceLight
        ModeTeleportBtn.TextColor3 = Theme.TextDim
    else
        ModeAutoFarmBtn.BackgroundColor3 = Theme.SurfaceLight
        ModeAutoFarmBtn.TextColor3 = Theme.TextDim
        ModeTeleportBtn.BackgroundColor3 = Theme.Accent2
        ModeTeleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function setMovementMode(mode)
    if mode ~= "AutoFarm" and mode ~= "Teleport" then return end
    stopMovement()
    movementMode = mode
    updateMovementModeButtons()
    if StatusLabel then
        StatusLabel.Text = mode == "AutoFarm"
            and "● Mode: Walk + NoClip"
            or "● Mode: Instant Teleport"
        StatusLabel.TextColor3 = Theme.Success
    end
end

--==================================================
-- TP TO HOME PLOT
--==================================================

local function teleportToHomePlot()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return false end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local dataFolder = plot:FindFirstChild("Data")
        if dataFolder then
            local ownerValue = dataFolder:FindFirstChild("Owner")
            if ownerValue then
                local isOwner = false
                if ownerValue:IsA("StringValue") then
                    isOwner = ownerValue.Value == LocalPlayer.Name
                elseif ownerValue:IsA("ObjectValue") then
                    isOwner = ownerValue.Value == LocalPlayer
                else
                    isOwner = tostring(ownerValue.Value) == LocalPlayer.Name
                end
                if isOwner then
                    return moveToModel(plot)
                end
            end
        end
    end
    return false
end

--==================================================
-- AUTO BEST EGG
--==================================================

local function holdEKey(duration)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function findBestEgg()
    if not RenderedEggsFolder then return nil end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if string.find(egg.Name:lower(), Config.BestEggName:lower(), 1, true) then
            return egg
        end
    end
    return nil
end

local function stopAutoBestEgg()
    autoBestEggActive = false
    stopMovement()
    if autoBestEggThread then
        task.cancel(autoBestEggThread)
        autoBestEggThread = nil
    end
end

local function startAutoBestEgg()
    stopAutoBestEgg()
    autoBestEggActive = true
    autoBestEggThread = task.spawn(function()
        while autoBestEggActive do
            local egg = findBestEgg()
            if egg and egg.Parent then
                local teleported = moveToModel(egg)
                if teleported then
                    task.wait(0.3)
                    if autoBestEggActive and egg.Parent then
                        holdEKey(Config.AutoEggHoldTime)
                    end
                    task.wait(0.2)
                    if autoBestEggActive then
                        teleportToHomePlot()
                    end
                    task.wait(Config.AutoEggDelay)
                end
            else
                task.wait(0.5)
            end
        end
    end)
end

--==================================================
-- AUTOFARM SELECTED EGGS
--==================================================

local function setAutoFarmButtonState(button, active)
    if not button then return end
    if active then
        button.Text = "Farm: ON"
        button.BackgroundColor3 = Theme.Success
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        button.Text = "Farm"
        button.BackgroundColor3 = Theme.SurfaceLight
        button.TextColor3 = Theme.Text
    end
end

local function isValidEgg(egg)
    return egg
        and egg.Parent == RenderedEggsFolder
        and (egg:IsA("Model") or egg:IsA("BasePart"))
end

local function getAutoFarmEggs()
    local found = {}
    if not RenderedEggsFolder then return found end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if isValidEgg(egg) and autoFarmEggs[egg.Name] and not autoFarmProcessed[egg] then
            table.insert(found, egg)
        end
    end
    table.sort(found, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return found
end

local function stopAutoFarm()
    autoFarmActive = false
    stopMovement()
    autoFarmCurrentName = nil
    if autoFarmThread then
        task.cancel(autoFarmThread)
        autoFarmThread = nil
    end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function startAutoFarm()
    stopAutoFarm()
    autoFarmActive = true
    if StopAutoFarmBtn then StopAutoFarmBtn.Visible = true end

    autoFarmThread = task.spawn(function()
        while autoFarmActive do
            local eggs = getAutoFarmEggs()
            if #eggs == 0 then
                autoFarmActive = false
                autoFarmCurrentName = nil
                autoFarmThread = nil
                if StopAutoFarmBtn then StopAutoFarmBtn.Visible = false end
                break
            end

            local didWork = false
            for _, egg in ipairs(eggs) do
                if not autoFarmActive then break end
                if isValidEgg(egg) and not autoFarmProcessed[egg] then
                    didWork = true
                    autoFarmCurrentName = egg.Name
                    StatusLabel.Text = "● AutoFarm: " .. egg.Name
                    StatusLabel.TextColor3 = Theme.Success
                    local success = moveToModel(egg)
                    if success and autoFarmActive then
                        task.wait(0.3)
                        if autoFarmActive and isValidEgg(egg) then
                            holdEKey(Config.AutoFarmHoldTime)
                        end
                        if autoFarmActive then
                            task.wait(0.2)
                            teleportToHomePlot()
                        end
                        autoFarmProcessed[egg] = true
                        task.wait(0.2)
                    end
                end
            end

            autoFarmCurrentName = nil
            if not didWork then
                autoFarmActive = false
                autoFarmThread = nil
                if StopAutoFarmBtn then StopAutoFarmBtn.Visible = false end
                break
            end
            task.wait(0.2)
        end
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        if not autoFarmActive then
            StatusLabel.Text = "● AutoFarm done: no eggs left"
            StatusLabel.TextColor3 = Theme.TextDim
        end
    end)
end

--==================================================
-- MAIN GUI
--==================================================

local oldGui = nil
pcall(function()
    oldGui = TargetParent:FindFirstChild("EGOY_RideAPet_Menu")
end)
if oldGui then
    pcall(function() oldGui:Destroy() end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EGOY_RideAPet_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = TargetParent

--==================================================
-- DEVICE SELECTION FRAME
--==================================================

local DeviceFrame = Instance.new("Frame")
DeviceFrame.Name = "DeviceSelectionFrame"
DeviceFrame.Size = UDim2.new(0, 280, 0, 150)
DeviceFrame.Position = UDim2.new(0.5, -140, 0.5, -75)
DeviceFrame.BackgroundColor3 = Theme.Background
DeviceFrame.BorderSizePixel = 0
DeviceFrame.Active = true
DeviceFrame.Parent = ScreenGui

local DeviceCorner = Instance.new("UICorner")
DeviceCorner.CornerRadius = UDim.new(0, 14)
DeviceCorner.Parent = DeviceFrame

local DeviceStroke = Instance.new("UIStroke")
DeviceStroke.Color = Theme.Accent
DeviceStroke.Thickness = 1.6
DeviceStroke.Transparency = 0.3
DeviceStroke.Parent = DeviceFrame

local DeviceGradient = Instance.new("UIGradient")
DeviceGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Surface),
    ColorSequenceKeypoint.new(1, Theme.Background),
})
DeviceGradient.Rotation = 90
DeviceGradient.Parent = DeviceFrame

local DeviceTitle = Instance.new("TextLabel")
DeviceTitle.Size = UDim2.new(1, 0, 0, 40)
DeviceTitle.Position = UDim2.new(0, 0, 0, 12)
DeviceTitle.BackgroundTransparency = 1
DeviceTitle.Text = "EGOY RIDE A PET"
DeviceTitle.TextColor3 = Theme.Text
DeviceTitle.TextSize = 18
DeviceTitle.Font = Enum.Font.GothamBold
DeviceTitle.Parent = DeviceFrame

local DeviceSub = Instance.new("TextLabel")
DeviceSub.Size = UDim2.new(1, 0, 0, 18)
DeviceSub.Position = UDim2.new(0, 0, 0, 42)
DeviceSub.BackgroundTransparency = 1
DeviceSub.Text = "Choose your device"
DeviceSub.TextColor3 = Theme.TextDim
DeviceSub.TextSize = 12
DeviceSub.Font = Enum.Font.Gotham
DeviceSub.Parent = DeviceFrame

local PCBtn = Instance.new("TextButton")
PCBtn.Size = UDim2.new(0, 110, 0, 45)
PCBtn.Position = UDim2.new(0, 20, 0, 80)
PCBtn.BackgroundColor3 = Theme.SurfaceLight
PCBtn.Text = "PC"
PCBtn.TextColor3 = Theme.Text
PCBtn.TextSize = 14
PCBtn.Font = Enum.Font.GothamBold
PCBtn.AutoButtonColor = false
PCBtn.Parent = DeviceFrame

local PCCorner = Instance.new("UICorner")
PCCorner.CornerRadius = UDim.new(0, 10)
PCCorner.Parent = PCBtn

local PCStroke = Instance.new("UIStroke")
PCStroke.Color = Theme.Accent2
PCStroke.Transparency = 0.5
PCStroke.Parent = PCBtn

local MobileBtn = Instance.new("TextButton")
MobileBtn.Size = UDim2.new(0, 110, 0, 45)
MobileBtn.Position = UDim2.new(1, -130, 0, 80)
MobileBtn.BackgroundColor3 = Theme.SurfaceLight
MobileBtn.Text = "Mobile"
MobileBtn.TextColor3 = Theme.Text
MobileBtn.TextSize = 14
MobileBtn.Font = Enum.Font.GothamBold
MobileBtn.AutoButtonColor = false
MobileBtn.Parent = DeviceFrame

local MobileCorner = Instance.new("UICorner")
MobileCorner.CornerRadius = UDim.new(0, 10)
MobileCorner.Parent = MobileBtn

local MobileStroke = Instance.new("UIStroke")
MobileStroke.Color = Theme.Accent
MobileStroke.Transparency = 0.5
MobileStroke.Parent = MobileBtn

--==================================================
-- MAIN FRAME
--==================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, Config.MobileWidth, 0, Config.MobileHeight)
MainFrame.Position = UDim2.new(0.5, -Config.MobileWidth / 2, 0.5, -Config.MobileHeight / 2)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Outline
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.25
MainStroke.Parent = MainFrame

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Surface),
    ColorSequenceKeypoint.new(0.5, Theme.Background),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 18)),
})
MainGradient.Rotation = 90
MainGradient.Parent = MainFrame

--==================================================
-- TOP BAR
--==================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 54)
TopBar.BackgroundColor3 = Theme.Surface
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopMask = Instance.new("Frame")
TopMask.Size = UDim2.new(1, 0, 0, 14)
TopMask.Position = UDim2.new(0, 0, 1, -14)
TopMask.BackgroundColor3 = Theme.Surface
TopMask.BorderSizePixel = 0
TopMask.Parent = TopBar

local TopGradient = Instance.new("UIGradient")
TopGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Accent),
    ColorSequenceKeypoint.new(0.5, Theme.Accent2),
    ColorSequenceKeypoint.new(1, Theme.Accent),
})
TopGradient.Rotation = 0
TopGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.55),
    NumberSequenceKeypoint.new(0.5, 0.35),
    NumberSequenceKeypoint.new(1, 0.55),
})
TopGradient.Parent = TopBar

local AuthorLabel = Instance.new("TextLabel")
AuthorLabel.Size = UDim2.new(1, -60, 0, 14)
AuthorLabel.Position = UDim2.new(0, 14, 0, 4)
AuthorLabel.BackgroundTransparency = 1
AuthorLabel.Text = "By ThiAez  •  EGOY"
AuthorLabel.TextColor3 = Theme.TextDim
AuthorLabel.TextSize = 10
AuthorLabel.Font = Enum.Font.Gotham
AuthorLabel.TextXAlignment = Enum.TextXAlignment.Left
AuthorLabel.ZIndex = 2
AuthorLabel.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 0, 22)
TitleLabel.Position = UDim2.new(0, 14, 0, 18)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "RIDE A PET"
TitleLabel.TextColor3 = Theme.Text
TitleLabel.TextSize = 17
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 2
TitleLabel.Parent = TopBar

local TitleStroke = Instance.new("UIStroke")
TitleStroke.Color = Theme.Accent2
TitleStroke.Thickness = 1
TitleStroke.Transparency = 0.5
TitleStroke.Parent = TitleLabel

local GameLabel = Instance.new("TextLabel")
GameLabel.Size = UDim2.new(1, -60, 0, 12)
GameLabel.Position = UDim2.new(0, 14, 0, 40)
GameLabel.BackgroundTransparency = 1
GameLabel.Text = "🎮 Ride A Pet  •  ESP & AutoFarm"
GameLabel.TextColor3 = Theme.TextDim
GameLabel.TextSize = 9
GameLabel.Font = Enum.Font.Gotham
GameLabel.TextXAlignment = Enum.TextXAlignment.Left
GameLabel.ZIndex = 2
GameLabel.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 34, 0, 34)
MinimizeBtn.Position = UDim2.new(1, -44, 0, 10)
MinimizeBtn.BackgroundColor3 = Theme.Background
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Theme.Text
MinimizeBtn.TextSize = 20
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.ZIndex = 3
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(1, 0)
MinCorner.Parent = MinimizeBtn

local MinStroke = Instance.new("UIStroke")
MinStroke.Color = Theme.Accent
MinStroke.Transparency = 0.4
MinStroke.Parent = MinimizeBtn

--==================================================
-- CONTENT CONTAINER
--==================================================

local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -20, 1, -64)
ContentContainer.Position = UDim2.new(0, 10, 0, 58)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

--==================================================
-- STATUS LABEL
--==================================================

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● System ready"
StatusLabel.TextColor3 = Theme.Success
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ContentContainer

--==================================================
-- BUTTON STYLER
--==================================================

local function styleButton(button, accentColor)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = accentColor or Theme.Outline
    stroke.Transparency = 0.55
    stroke.Thickness = 1
    stroke.Parent = button

    button.AutoButtonColor = false
    button.TextColor3 = button.TextColor3 or Theme.Text

    local baseTransparency = button.BackgroundTransparency

    button.MouseEnter:Connect(function()
        tween(button, {
            BackgroundTransparency = math.max(0, baseTransparency - 0.12)
        }, 0.10)
    end)

    button.MouseLeave:Connect(function()
        tween(button, {
            BackgroundTransparency = math.min(0.5, baseTransparency + 0.12)
        }, 0.10)
    end)

    button.MouseButton1Down:Connect(function()
        tween(button, { Size = button.Size }, 0.05)
    end)
end

--==================================================
-- MOVEMENT MODE BUTTONS
--==================================================

ModeAutoFarmBtn = Instance.new("TextButton")
ModeAutoFarmBtn.Name = "ModeAutoFarm"
ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 30)
ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 22)
ModeAutoFarmBtn.BackgroundColor3 = Theme.Success
ModeAutoFarmBtn.Text = "🚶 Walk Mode"
ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ModeAutoFarmBtn.TextSize = 11
ModeAutoFarmBtn.Font = Enum.Font.GothamBold
ModeAutoFarmBtn.Parent = ContentContainer
styleButton(ModeAutoFarmBtn, Theme.Success)

ModeTeleportBtn = Instance.new("TextButton")
ModeTeleportBtn.Name = "ModeTeleport"
ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 30)
ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 22)
ModeTeleportBtn.BackgroundColor3 = Theme.SurfaceLight
ModeTeleportBtn.Text = "⚡ Teleport"
ModeTeleportBtn.TextColor3 = Theme.TextDim
ModeTeleportBtn.TextSize = 11
ModeTeleportBtn.Font = Enum.Font.GothamBold
ModeTeleportBtn.Parent = ContentContainer
styleButton(ModeTeleportBtn, Theme.Accent2)

ModeAutoFarmBtn.MouseButton1Click:Connect(function() setMovementMode("AutoFarm") end)
ModeTeleportBtn.MouseButton1Click:Connect(function() setMovementMode("Teleport") end)
updateMovementModeButtons()

--==================================================
-- STOP AUTOFARM BUTTON
--==================================================

StopAutoFarmBtn = Instance.new("TextButton")
StopAutoFarmBtn.Name = "StopAutoFarm"
StopAutoFarmBtn.Size = UDim2.new(0, 110, 0, 20)
StopAutoFarmBtn.Position = UDim2.new(1, -110, 0, 0)
StopAutoFarmBtn.BackgroundColor3 = Theme.Danger
StopAutoFarmBtn.Text = "■ Stop AutoFarm"
StopAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopAutoFarmBtn.TextSize = 10
StopAutoFarmBtn.Font = Enum.Font.GothamBold
StopAutoFarmBtn.Visible = false
StopAutoFarmBtn.Parent = ContentContainer
styleButton(StopAutoFarmBtn, Theme.Danger)

StopAutoFarmBtn.MouseButton1Click:Connect(function()
    stopAutoFarm()
    StopAutoFarmBtn.Visible = false
    StatusLabel.Text = "● AutoFarm stopped"
    StatusLabel.TextColor3 = Theme.Danger
end)

--==================================================
-- ESP BUTTON
--==================================================

local ToggleGlobalESPBtn = Instance.new("TextButton")
ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 34)
ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 58)
ToggleGlobalESPBtn.BackgroundColor3 = Theme.SurfaceLight
ToggleGlobalESPBtn.Text = "🔆 ESP All: OFF"
ToggleGlobalESPBtn.TextColor3 = Theme.Text
ToggleGlobalESPBtn.TextSize = 12
ToggleGlobalESPBtn.Font = Enum.Font.GothamBold
ToggleGlobalESPBtn.Parent = ContentContainer
styleButton(ToggleGlobalESPBtn, Theme.Accent)

ToggleGlobalESPBtn.MouseButton1Click:Connect(function()
    mainESPActive = not mainESPActive
    if mainESPActive then
        ToggleGlobalESPBtn.Text = "🔆 ESP All: ON"
        ToggleGlobalESPBtn.TextColor3 = Theme.Success
        ToggleGlobalESPBtn.BackgroundColor3 = Theme.Surface
        StatusLabel.Text = "● ESP active"
        StatusLabel.TextColor3 = Theme.Success
    else
        ToggleGlobalESPBtn.Text = "🔆 ESP All: OFF"
        ToggleGlobalESPBtn.TextColor3 = Theme.Text
        ToggleGlobalESPBtn.BackgroundColor3 = Theme.SurfaceLight
        StatusLabel.Text = "● ESP disabled"
        StatusLabel.TextColor3 = Theme.TextDim
    end
    applyGlobalESP(mainESPActive)
end)

--==================================================
-- AUTO BEST EGG BUTTON
--==================================================

local AutoBestEggBtn = Instance.new("TextButton")
AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 34)
AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 96)
AutoBestEggBtn.BackgroundColor3 = Theme.SurfaceLight
AutoBestEggBtn.Text = "🥚 Auto Best Egg: OFF"
AutoBestEggBtn.TextColor3 = Theme.Text
AutoBestEggBtn.TextSize = 12
AutoBestEggBtn.Font = Enum.Font.GothamBold
AutoBestEggBtn.Parent = ContentContainer
styleButton(AutoBestEggBtn, Theme.Warning)

AutoBestEggBtn.MouseButton1Click:Connect(function()
    autoBestEggActive = not autoBestEggActive
    if autoBestEggActive then
        AutoBestEggBtn.Text = "🥚 Auto Best Egg: ON"
        AutoBestEggBtn.TextColor3 = Theme.Warning
        AutoBestEggBtn.BackgroundColor3 = Theme.Surface
        StatusLabel.Text = "● Auto Best Egg active"
        StatusLabel.TextColor3 = Theme.Warning
        startAutoBestEgg()
    else
        AutoBestEggBtn.Text = "🥚 Auto Best Egg: OFF"
        AutoBestEggBtn.TextColor3 = Theme.Text
        AutoBestEggBtn.BackgroundColor3 = Theme.SurfaceLight
        StatusLabel.Text = "● System ready"
        StatusLabel.TextColor3 = Theme.Success
        stopAutoBestEgg()
    end
end)

--==================================================
-- TP HOME BUTTON
--==================================================

local TPHomeBtn = Instance.new("TextButton")
TPHomeBtn.Size = UDim2.new(1, 0, 0, 34)
TPHomeBtn.Position = UDim2.new(0, 0, 0, 134)
TPHomeBtn.BackgroundColor3 = Theme.SurfaceLight
TPHomeBtn.Text = "🏠 TP Home"
TPHomeBtn.TextColor3 = Theme.Text
TPHomeBtn.TextSize = 12
TPHomeBtn.Font = Enum.Font.GothamBold
TPHomeBtn.Parent = ContentContainer
styleButton(TPHomeBtn, Theme.Accent2)

TPHomeBtn.MouseButton1Click:Connect(function()
    local success = teleportToHomePlot()
    if success then
        StatusLabel.Text = movementMode == "AutoFarm"
            and "● Moved home (walk + noclip)"
            or "● Teleported home"
        StatusLabel.TextColor3 = Theme.Success
    else
        StatusLabel.Text = "● Home plot not found"
        StatusLabel.TextColor3 = Theme.Danger
    end
end)

--==================================================
-- KEYBIND
--==================================================

local KeybindBtn = Instance.new("TextButton")
KeybindBtn.Size = UDim2.new(1, 0, 0, 26)
KeybindBtn.Position = UDim2.new(0, 0, 0, 172)
KeybindBtn.BackgroundColor3 = Theme.Background
KeybindBtn.Text = "⌨  TP Home Key: [" .. tpKeybind.Name .. "]"
KeybindBtn.TextColor3 = Theme.TextDim
KeybindBtn.TextSize = 10
KeybindBtn.Font = Enum.Font.Gotham
KeybindBtn.Parent = ContentContainer
styleButton(KeybindBtn, Theme.Outline)

KeybindBtn.MouseButton1Click:Connect(function()
    listeningForKey = true
    KeybindBtn.Text = "⌨  Press a key..."
    KeybindBtn.TextColor3 = Theme.Warning
end)

--==================================================
-- TOGGLE LIST
--==================================================

local ToggleListBtn = Instance.new("TextButton")
ToggleListBtn.Size = UDim2.new(1, 0, 0, 34)
ToggleListBtn.Position = UDim2.new(0, 0, 0, 202)
ToggleListBtn.BackgroundColor3 = Theme.SurfaceLight
ToggleListBtn.Text = "📋 Show Egg List ▼"
ToggleListBtn.TextColor3 = Theme.Text
ToggleListBtn.TextSize = 12
ToggleListBtn.Font = Enum.Font.GothamBold
ToggleListBtn.Parent = ContentContainer
styleButton(ToggleListBtn, Theme.Accent)

--==================================================
-- LIST CONTAINER
--==================================================

local ListContainerFrame = Instance.new("Frame")
ListContainerFrame.Size = UDim2.new(1, 0, 0, 270)
ListContainerFrame.Position = UDim2.new(0, 0, 0, 242)
ListContainerFrame.BackgroundColor3 = Theme.Background
ListContainerFrame.BackgroundTransparency = 0.15
ListContainerFrame.Visible = false
ListContainerFrame.Parent = ContentContainer

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 10)
ListCorner.Parent = ListContainerFrame

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = Theme.Outline
ListStroke.Transparency = 0.4
ListStroke.Parent = ListContainerFrame

--==================================================
-- EGG COUNTER
--==================================================

local EggCountLabel = Instance.new("TextLabel")
EggCountLabel.Size = UDim2.new(1, -10, 0, 20)
EggCountLabel.Position = UDim2.new(0, 5, 0, 5)
EggCountLabel.BackgroundTransparency = 1
EggCountLabel.Text = "Eggs detected: 0"
EggCountLabel.TextColor3 = Theme.TextDim
EggCountLabel.TextSize = 10
EggCountLabel.Font = Enum.Font.GothamBold
EggCountLabel.TextXAlignment = Enum.TextXAlignment.Left
EggCountLabel.Parent = ListContainerFrame

--==================================================
-- REFRESH BUTTON
--==================================================

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0.48, -5, 0, 25)
RefreshBtn.Position = UDim2.new(0, 5, 0, 27)
RefreshBtn.BackgroundColor3 = Theme.SurfaceLight
RefreshBtn.Text = "🔄 Refresh"
RefreshBtn.TextColor3 = Theme.Text
RefreshBtn.TextSize = 11
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.Parent = ListContainerFrame
styleButton(RefreshBtn, Theme.Accent2)

--==================================================
-- SORT BUTTON
--==================================================

local SortBtn = Instance.new("TextButton")
SortBtn.Size = UDim2.new(0.48, -5, 0, 25)
SortBtn.Position = UDim2.new(0.52, 0, 0, 27)
SortBtn.BackgroundColor3 = Theme.SurfaceLight
SortBtn.Text = "Sort: Name"
SortBtn.TextColor3 = Theme.Text
SortBtn.TextSize = 11
SortBtn.Font = Enum.Font.GothamBold
SortBtn.Parent = ListContainerFrame
styleButton(SortBtn, Theme.Accent)

--==================================================
-- SEARCH BOX
--==================================================

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -10, 0, 25)
SearchBox.Position = UDim2.new(0, 5, 0, 57)
SearchBox.BackgroundColor3 = Theme.Background
SearchBox.BackgroundTransparency = 0.15
SearchBox.PlaceholderText = "🔍 Search egg..."
SearchBox.PlaceholderColor3 = Theme.TextDim
SearchBox.Text = ""
SearchBox.TextColor3 = Theme.Text
SearchBox.TextSize = 11
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = ListContainerFrame

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 8)
SearchCorner.Parent = SearchBox

local SearchStroke = Instance.new("UIStroke")
SearchStroke.Color = Theme.Outline
SearchStroke.Transparency = 0.5
SearchStroke.Parent = SearchBox

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 8)
SearchPadding.Parent = SearchBox

--==================================================
-- SCROLL LIST
--==================================================

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -10, 1, -87)
ScrollList.Position = UDim2.new(0, 5, 0, 87)
ScrollList.BackgroundTransparency = 1
ScrollList.BorderSizePixel = 0
ScrollList.ScrollBarThickness = 4
ScrollList.ScrollBarImageColor3 = Theme.Accent
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.Parent = ListContainerFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ScrollList

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 6)
end)

--==================================================
-- SORT EGGS
--==================================================

local function getEggsForList()
    local eggs = {}
    if not RenderedEggsFolder then return eggs end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            table.insert(eggs, egg)
        end
    end
    table.sort(eggs, function(a, b)
        if sortMode == "Distance" then
            return getDistanceToTarget(a) < getDistanceToTarget(b)
        end
        return a.Name:lower() < b.Name:lower()
    end)
    return eggs
end

--==================================================
-- CREATE LIST ITEM
--==================================================

local function createEggListItem(egg, itemHeight, textSize)
    local ItemFrame = Instance.new("Frame")
    ItemFrame.Size = UDim2.new(1, -6, 0, itemHeight)
    ItemFrame.BackgroundColor3 = Theme.Surface
    ItemFrame.BackgroundTransparency = 0.15
    ItemFrame.Parent = ScrollList

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = ItemFrame

    local itemStroke = Instance.new("UIStroke")
    itemStroke.Color = Theme.Outline
    itemStroke.Transparency = 0.6
    itemStroke.Parent = ItemFrame

    local eggIcon = Instance.new("ImageLabel")
    eggIcon.Name = "EggIcon"
    eggIcon.Size = UDim2.new(0, itemHeight - 8, 0, itemHeight - 8)
    eggIcon.Position = UDim2.new(0, 5, 0.5, -(itemHeight - 8) / 2)
    eggIcon.BackgroundTransparency = 1
    eggIcon.Image = getEggImage(egg.Name)
    eggIcon.ScaleType = Enum.ScaleType.Fit
    eggIcon.Parent = ItemFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -205, 1, 0)
    nameLabel.Position = UDim2.new(0, itemHeight + 7, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = egg.Name
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextSize = textSize
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = ItemFrame

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(0, 55, 1, 0)
    distanceLabel.Position = UDim2.new(1, -150, 0, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Theme.TextDim
    distanceLabel.TextSize = textSize - 1
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Text = "--"
    distanceLabel.Parent = ItemFrame

    local distance = getDistanceToTarget(egg)
    if distance ~= math.huge then
        distanceLabel.Text = string.format("%dm", math.floor(distance + 0.5))
    end

    -- TP button
    local TPBtn = Instance.new("TextButton")
    TPBtn.Size = UDim2.new(0, 36, 0, itemHeight - 8)
    TPBtn.Position = UDim2.new(1, -148, 0.5, -(itemHeight - 8) / 2)
    TPBtn.BackgroundColor3 = Theme.SurfaceLight
    TPBtn.Text = "TP"
    TPBtn.TextColor3 = Theme.Text
    TPBtn.TextSize = 10
    TPBtn.Font = Enum.Font.GothamBold
    TPBtn.Parent = ItemFrame
    styleButton(TPBtn, Theme.Accent2)

    TPBtn.MouseButton1Click:Connect(function()
        if not egg.Parent then return end
        local success = teleportToModel(egg)
        if success then
            StatusLabel.Text = "● TP: " .. egg.Name
            StatusLabel.TextColor3 = Theme.Success
        end
    end)

    -- AutoFarm toggle
    local AutoFarmBtn = Instance.new("TextButton")
    AutoFarmBtn.Name = "AutoFarmButton"
    AutoFarmBtn.Size = UDim2.new(0, 55, 0, itemHeight - 8)
    AutoFarmBtn.Position = UDim2.new(1, -107, 0.5, -(itemHeight - 8) / 2)
    AutoFarmBtn.BackgroundColor3 = Theme.SurfaceLight
    AutoFarmBtn.Text = "Farm"
    AutoFarmBtn.TextColor3 = Theme.Text
    AutoFarmBtn.TextSize = 9
    AutoFarmBtn.Font = Enum.Font.GothamBold
    AutoFarmBtn.Parent = ItemFrame
    styleButton(AutoFarmBtn, Theme.Success)

    setAutoFarmButtonState(AutoFarmBtn, autoFarmEggs[egg.Name] == true)

    AutoFarmBtn.MouseButton1Click:Connect(function()
        if not egg.Parent then return end
        local name = egg.Name
        autoFarmEggs[name] = not autoFarmEggs[name]

        for processedEgg in pairs(autoFarmProcessed) do
            if processedEgg and processedEgg.Name == name then
                autoFarmProcessed[processedEgg] = nil
            end
        end

        setAutoFarmButtonState(AutoFarmBtn, autoFarmEggs[name] == true)

        if autoFarmEggs[name] then
            StatusLabel.Text = "● AutoFarm selected: " .. name
            StatusLabel.TextColor3 = Theme.Success
            if not autoFarmActive then startAutoFarm() end
        else
            StatusLabel.Text = "● AutoFarm removed: " .. name
            StatusLabel.TextColor3 = Theme.TextDim
            local anySelected = false
            for _ in pairs(autoFarmEggs) do anySelected = true break end
            if not anySelected then
                stopAutoFarm()
                StopAutoFarmBtn.Visible = false
            end
        end
        StopAutoFarmBtn.Visible = autoFarmActive
    end)

    -- Individual green ESP
    local GreenESPBtn = Instance.new("TextButton")
    GreenESPBtn.Size = UDim2.new(0, 45, 0, itemHeight - 8)
    GreenESPBtn.Position = UDim2.new(1, -48, 0.5, -(itemHeight - 8) / 2)
    GreenESPBtn.BackgroundColor3 = Theme.Success
    GreenESPBtn.BackgroundTransparency = 0.2
    GreenESPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    GreenESPBtn.TextSize = 10
    GreenESPBtn.Font = Enum.Font.GothamBold
    GreenESPBtn.Parent = ItemFrame
    styleButton(GreenESPBtn, Theme.Success)

    local data = eggData[egg]
    if data and data.CustomActive then
        GreenESPBtn.Text = "ON"
        GreenESPBtn.BackgroundColor3 = Theme.Success
    else
        GreenESPBtn.Text = "ESP"
        GreenESPBtn.BackgroundColor3 = Theme.SurfaceLight
    end

    GreenESPBtn.MouseButton1Click:Connect(function()
        if not eggData[egg] then
            eggData[egg] = {
                Highlight = nil,
                NameBillboard = nil,
                CustomColor = Config.CustomESPColor,
                CustomActive = false
            }
        end
        local eggInfo = eggData[egg]
        eggInfo.CustomActive = not eggInfo.CustomActive
        eggInfo.CustomColor = Config.CustomESPColor

        if eggInfo.CustomActive then
            GreenESPBtn.Text = "ON"
            GreenESPBtn.BackgroundColor3 = Theme.Success
            StatusLabel.Text = "● Green ESP: " .. egg.Name
            StatusLabel.TextColor3 = Theme.Success
        else
            GreenESPBtn.Text = "ESP"
            GreenESPBtn.BackgroundColor3 = Theme.SurfaceLight
            StatusLabel.Text = "● Green ESP off"
            StatusLabel.TextColor3 = Theme.TextDim
        end
        updateEggESP(egg)
    end)
end

--==================================================
-- POPULATE LIST
--==================================================

local function clearEggList()
    for _, child in ipairs(ScrollList:GetChildren()) do
        if child ~= UIListLayout then
            child:Destroy()
        end
    end
end

local function populateList()
    clearEggList()
    if not RenderedEggsFolder then
        EggCountLabel.Text = "Eggs: 0  |  Results: 0"
        return
    end

    local query = currentSearchQuery:lower()
    local eggs = getEggsForList()
    local visibleCount = 0
    local itemHeight = isMobileMode and 32 or 30
    local textSize = isMobileMode and 11 or 12

    for _, egg in ipairs(eggs) do
        local matches = query == "" or string.find(egg.Name:lower(), query, 1, true)
        if matches then
            visibleCount += 1
            createEggListItem(egg, itemHeight, textSize)
        end
    end

    EggCountLabel.Text = "Eggs: " .. tostring(#eggs) .. "  |  Results: " .. tostring(visibleCount)

    if visibleCount == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Name = "NoResultsLabel"
        emptyLabel.Size = UDim2.new(1, -10, 0, 35)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "No eggs found"
        emptyLabel.TextColor3 = Theme.TextDim
        emptyLabel.TextSize = 12
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Parent = ScrollList
    end
end

--==================================================
-- SEARCH
--==================================================

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local newQuery = SearchBox.Text
    if newQuery == currentSearchQuery then return end
    currentSearchQuery = newQuery
    populateList()
end)

--==================================================
-- REFRESH
--==================================================

RefreshBtn.MouseButton1Click:Connect(function()
    populateList()
    updateAllESP()
    StatusLabel.Text = "● List updated"
    StatusLabel.TextColor3 = Theme.Success
end)

--==================================================
-- CHANGE SORT
--==================================================

SortBtn.MouseButton1Click:Connect(function()
    if sortMode == "Name" then
        sortMode = "Distance"
        SortBtn.Text = "Sort: Distance"
    else
        sortMode = "Name"
        SortBtn.Text = "Sort: Name"
    end
    populateList()
end)

--==================================================
-- SHOW / HIDE LIST
--==================================================

ToggleListBtn.MouseButton1Click:Connect(function()
    ListContainerFrame.Visible = not ListContainerFrame.Visible
    if ListContainerFrame.Visible then
        ToggleListBtn.Text = "📋 Hide Egg List ▲"
        populateList()
    else
        ToggleListBtn.Text = "📋 Show Egg List ▼"
    end
end)

--==================================================
-- MINIMIZE
--==================================================

local currentExpandedWidth = Config.MobileWidth
local currentExpandedHeight = Config.MobileHeight

MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        ContentContainer.Visible = false
        tween(MainFrame, {
            Size = UDim2.new(0, currentExpandedWidth, 0, TopBar.Size.Y.Offset)
        }, 0.20)
        MinimizeBtn.Text = "+"
    else
        tween(MainFrame, {
            Size = UDim2.new(0, currentExpandedWidth, 0, currentExpandedHeight)
        }, 0.20)
        task.delay(0.12, function()
            if not isMinimized then
                ContentContainer.Visible = true
            end
        end)
        MinimizeBtn.Text = "−"
    end
end)

--==================================================
-- DRAG
--==================================================

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

--==================================================
-- KEYBIND HANDLER
--==================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if listeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            tpKeybind = input.KeyCode
            listeningForKey = false
            KeybindBtn.Text = "⌨  TP Home Key: [" .. tpKeybind.Name .. "]"
            KeybindBtn.TextColor3 = Theme.TextDim
        end
        return
    end
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == tpKeybind then
            teleportToHomePlot()
        end
    end
end)

--==================================================
-- AUTO UPDATE ESP
--==================================================

task.spawn(function()
    while ScreenGui.Parent do
        if mainESPActive then
            for egg, data in pairs(eggData) do
                if egg and egg.Parent then
                    if data.NameBillboard and data.NameBillboard.Enabled then
                        updateEggLabel(egg)
                    end
                end
            end
        end
        task.wait(0.20)
    end
end)

--==================================================
-- DETECT NEW / REMOVED EGGS
--==================================================

if RenderedEggsFolder then
    RenderedEggsFolder.ChildAdded:Connect(function(egg)
        autoFarmProcessed[egg] = nil
        task.wait(0.05)
        updateEggESP(egg)
        if ListContainerFrame.Visible then
            populateList()
        end
    end)

    RenderedEggsFolder.ChildRemoved:Connect(function(egg)
        removeEggData(egg)
        if ListContainerFrame.Visible then
            populateList()
        end
    end)

    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        updateEggESP(egg)
    end
end

--==================================================
-- PC MODE
--==================================================

local function setPCMode()
    isMobileMode = false
    currentExpandedWidth = Config.PCWidth
    currentExpandedHeight = Config.PCHeight

    MainFrame.Size = UDim2.new(0, Config.PCWidth, 0, Config.PCHeight)
    MainFrame.Position = UDim2.new(0.5, -Config.PCWidth / 2, 0.4, -Config.PCHeight / 2)

    TopBar.Size = UDim2.new(1, 0, 0, 54)
    AuthorLabel.TextSize = 10
    TitleLabel.TextSize = 17
    GameLabel.TextSize = 9

    ContentContainer.Size = UDim2.new(1, -20, 1, -64)
    ContentContainer.Position = UDim2.new(0, 10, 0, 58)

    StatusLabel.TextSize = 11
    StopAutoFarmBtn.Size = UDim2.new(0, 110, 0, 20)
    StopAutoFarmBtn.Position = UDim2.new(1, -110, 0, 0)

    ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 22)
    ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 22)

    ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 34)
    ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 58)

    AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 34)
    AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 96)

    TPHomeBtn.Size = UDim2.new(1, 0, 0, 34)
    TPHomeBtn.Position = UDim2.new(0, 0, 0, 134)

    KeybindBtn.Size = UDim2.new(1, 0, 0, 26)
    KeybindBtn.Position = UDim2.new(0, 0, 0, 172)

    ToggleListBtn.Size = UDim2.new(1, 0, 0, 34)
    ToggleListBtn.Position = UDim2.new(0, 0, 0, 202)

    ListContainerFrame.Size = UDim2.new(1, 0, 0, 270)
    ListContainerFrame.Position = UDim2.new(0, 0, 0, 242)

    DeviceFrame:Destroy()
    MainFrame.Visible = true
    populateList()
end

--==================================================
-- MOBILE MODE
--==================================================

local function setMobileMode()
    isMobileMode = true
    currentExpandedWidth = Config.MobileWidth
    currentExpandedHeight = Config.MobileHeight

    MainFrame.Size = UDim2.new(0, Config.MobileWidth, 0, Config.MobileHeight)
    MainFrame.Position = UDim2.new(0.5, -Config.MobileWidth / 2, 0.5, -Config.MobileHeight / 2)

    TopBar.Size = UDim2.new(1, 0, 0, 54)
    AuthorLabel.TextSize = 10
    TitleLabel.TextSize = 17
    GameLabel.TextSize = 9
    MinimizeBtn.Size = UDim2.new(0, 34, 0, 34)
    MinimizeBtn.Position = UDim2.new(1, -44, 0, 10)

    ContentContainer.Size = UDim2.new(1, -20, 1, -64)
    ContentContainer.Position = UDim2.new(0, 10, 0, 58)

    StatusLabel.TextSize = 11
    StopAutoFarmBtn.Size = UDim2.new(0, 110, 0, 20)
    StopAutoFarmBtn.Position = UDim2.new(1, -110, 0, 0)
    StopAutoFarmBtn.TextSize = 10

    ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 22)
    ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 22)

    ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 34)
    ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 58)
    ToggleGlobalESPBtn.TextSize = 12

    AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 34)
    AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 96)
    AutoBestEggBtn.TextSize = 12

    TPHomeBtn.Size = UDim2.new(1, 0, 0, 34)
    TPHomeBtn.Position = UDim2.new(0, 0, 0, 134)
    TPHomeBtn.TextSize = 12

    KeybindBtn.Size = UDim2.new(1, 0, 0, 26)
    KeybindBtn.Position = UDim2.new(0, 0, 0, 172)
    KeybindBtn.TextSize = 10

    ToggleListBtn.Size = UDim2.new(1, 0, 0, 34)
    ToggleListBtn.Position = UDim2.new(0, 0, 0, 202)
    ToggleListBtn.TextSize = 12

    ListContainerFrame.Size = UDim2.new(1, 0, 0, 270)
    ListContainerFrame.Position = UDim2.new(0, 0, 0, 242)

    EggCountLabel.TextSize = 10
    RefreshBtn.Size = UDim2.new(0.48, -5, 0, 25)
    RefreshBtn.Position = UDim2.new(0, 5, 0, 27)
    RefreshBtn.TextSize = 11

    SortBtn.Size = UDim2.new(0.48, -5, 0, 25)
    SortBtn.Position = UDim2.new(0.52, 0, 0, 27)
    SortBtn.TextSize = 11

    SearchBox.Size = UDim2.new(1, -10, 0, 25)
    SearchBox.Position = UDim2.new(0, 5, 0, 57)
    SearchBox.TextSize = 11

    ScrollList.Size = UDim2.new(1, -10, 1, -87)
    ScrollList.Position = UDim2.new(0, 5, 0, 87)

    DeviceFrame:Destroy()
    MainFrame.Visible = true
    populateList()
end

--==================================================
-- DEVICE BUTTONS
--==================================================

PCBtn.MouseButton1Click:Connect(function()
    setPCMode()
end)

MobileBtn.MouseButton1Click:Connect(function()
    setMobileMode()
end)

--==================================================
-- AUTO-DETECT DEVICE AND OPEN MENU
--==================================================

task.spawn(function()
    task.wait(0.4)
    -- Auto-select mobile on touch devices, PC otherwise
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        setMobileMode()
    elseif UserInputService.TouchEnabled and UserInputService.KeyboardEnabled then
        -- Hybrid device: prefer mobile sizing for touch comfort
        setMobileMode()
    else
        setPCMode()
    end
end)

--==================================================
-- END
--==================================================

print("[EGOY RIDE A PET v3.0] Loaded successfully.")