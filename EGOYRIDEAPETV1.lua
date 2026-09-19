--[[
    ═══════════════════════════════════════════════════════
    EGOY • RIDE A PET — Auto Farm & ESP  (v3.0)
    By EGOY
    ═══════════════════════════════════════════════════════
]]

--==================================================
-- [1] SERVICES
--==================================================
local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace           = game:GetService("Workspace")

local LocalPlayer         = Players.LocalPlayer
local TargetParent        = LocalPlayer:WaitForChild("PlayerGui")
local RenderedEggsFolder  = Workspace:WaitForChild("RenderedEggs", 10)

if not RenderedEggsFolder then
    warn("[EGOY] Workspace.RenderedEggs not found. UI will still open.")
end

--==================================================
-- [2] CONFIG
--==================================================
local C = {
    BgMain      = Color3.fromRGB(9, 5, 20),
    BgPanel     = Color3.fromRGB(14, 8, 30),
    BgCard      = Color3.fromRGB(21, 12, 42),
    BgCardAlt   = Color3.fromRGB(27, 16, 52),
    BgHover     = Color3.fromRGB(40, 24, 68),
    BgInput     = Color3.fromRGB(16, 10, 34),

    BorderMain  = Color3.fromRGB(139, 63, 245),
    BorderCard  = Color3.fromRGB(60, 35, 110),

    Accent      = Color3.fromRGB(147, 51, 234),
    AccentLight = Color3.fromRGB(180, 120, 255),
    AccentDeep  = Color3.fromRGB(109, 40, 217),

    TextWhite   = Color3.fromRGB(240, 235, 255),
    TextGray    = Color3.fromRGB(170, 160, 200),
    TextDim     = Color3.fromRGB(120, 110, 150),

    Success     = Color3.fromRGB(34, 197, 94),
    Danger      = Color3.fromRGB(225, 60, 80),
    Warning     = Color3.fromRGB(250, 200, 50),

    ToggleOn    = Color3.fromRGB(147, 51, 234),
    ToggleOff   = Color3.fromRGB(55, 45, 85),

    ESPFillTransparency    = 0.5,
    ESPOutlineTransparency = 0,
    GlobalESPColor         = Color3.fromRGB(255, 255, 0),
    CustomESPColor         = Color3.fromRGB(0, 255, 0),
    TPHeight               = 3,
    MovementSpeed          = 500,
    BestEggName            = "cherub",
    AutoEggHoldTime        = 3,
    AutoFarmHoldTime       = 2,
    AutoEggDelay           = 0.8,

    DesignW  = 900, DesignH = 540,
    SidebarW = 150, HeaderH = 60, FooterH = 32,
    AnimTime = 0.15,
}

--==================================================
-- [3] STATE
--==================================================
local S = {
    mainESPActive      = false,
    espPlayers         = false,
    espPets            = false,
    espChests          = false,
    espItems           = false,
    eggData            = {},

    autoBestEggActive  = false,
    autoBestEggThread  = nil,

    autoFarmActive     = false,
    autoFarmThread     = nil,
    autoFarmEggs       = {},
    autoFarmProcessed  = {},

    autoRebirthActive  = false,
    autoRebirthThread  = nil,
    autoRebirthDelay   = 5,

    autoSell           = false,
    autoCollectRewards = false,
    showDamage         = false,

    movementMode       = "AutoFarm",
    movementActive     = false,
    movementHumanoid   = nil,
    movementPartsState = nil,

    tpKeybind          = Enum.KeyCode.T,
    listeningForKey    = false,
    currentSearchQuery = "",
    sortMode           = "Name",
    deviceMode         = "PC",
    activeTab          = "Home",
    isMinimized        = false,
}

local UI = { tabs = {}, refs = {} }

--==================================================
-- [4] GAME HELPERS
--==================================================
local function getCharacter() return LocalPlayer.Character end
local function getRootPart()
    local ch = getCharacter()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function getTargetCFrame(t)
    if not t or not t.Parent then return nil end
    if t:IsA("Model") then return t:GetPivot() end
    if t:IsA("BasePart") then return t.CFrame end
    return nil
end

local function getDistanceToTarget(t)
    local root = getRootPart()
    local cf = getTargetCFrame(t)
    if not root or not cf then return math.huge end
    return (root.Position - cf.Position).Magnitude
end

local function getEggImage(eggName)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return "" end
    local main = pg:FindFirstChild("Main")
    local idx  = main and main:FindFirstChild("Index")
    local hld  = idx  and idx:FindFirstChild("Holders")
    local eh   = hld  and hld:FindFirstChild("EggsHolder")
    if not eh then return "" end
    local frame = eh:FindFirstChild(eggName)
    if not frame then return "" end
    local img = frame:FindFirstChild("ImageLabel")
    return (img and img:IsA("ImageLabel") and img.Image) or ""
end

local function tween(obj, props, dur)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj,
        TweenInfo.new(dur or C.AnimTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props):Play()
end

--==================================================
-- [5] ESP LOGIC
--==================================================
local function createEggLabel(egg)
    local d = S.eggData[egg]
    if not d or (d.NameBillboard and d.NameBillboard.Parent) then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "EggESP_Info"
    bb.Size = UDim2.new(0, 180, 0, 45)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.Enabled = false
    bb.Parent = egg

    local name = Instance.new("TextLabel")
    name.Name = "EggName"
    name.Size = UDim2.new(1, 0, 0, 23)
    name.BackgroundTransparency = 1
    name.Text = egg.Name
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextStrokeTransparency = 0.35
    name.TextSize = 13
    name.Font = Enum.Font.GothamBold
    name.Parent = bb

    local dist = Instance.new("TextLabel")
    dist.Name = "Distance"
    dist.Size = UDim2.new(1, 0, 0, 18)
    dist.Position = UDim2.new(0, 0, 0, 22)
    dist.BackgroundTransparency = 1
    dist.Text = "0 studs"
    dist.TextColor3 = Color3.fromRGB(210, 210, 210)
    dist.TextStrokeTransparency = 0.4
    dist.TextSize = 11
    dist.Font = Enum.Font.Gotham
    dist.Parent = bb

    d.NameBillboard = bb
end

local function updateEggLabel(egg)
    local d = S.eggData[egg]
    if not d or not d.NameBillboard or not d.NameBillboard.Parent then return end
    local bb = d.NameBillboard
    local n = bb:FindFirstChild("EggName")
    local ds = bb:FindFirstChild("Distance")
    if n then n.Text = egg.Name end
    if ds then
        local dist = getDistanceToTarget(egg)
        ds.Text = (dist == math.huge) and "?" or string.format("%d studs", math.floor(dist + 0.5))
    end
end

local function updateEggESP(egg)
    if not egg then return end
    if not (egg:IsA("Model") or egg:IsA("BasePart")) then return end
    if not S.eggData[egg] then
        S.eggData[egg] = {
            Highlight = nil, NameBillboard = nil,
            CustomColor = C.CustomESPColor, CustomActive = false,
        }
    end
    local d = S.eggData[egg]
    local shouldShow, color = false, C.GlobalESPColor
    if d.CustomActive then shouldShow, color = true, d.CustomColor
    elseif S.mainESPActive then shouldShow, color = true, C.GlobalESPColor end

    if shouldShow then
        if not d.Highlight or not d.Highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "EggESP_Highlight"
            hl.Adornee = egg
            hl.FillTransparency = C.ESPFillTransparency
            hl.OutlineTransparency = C.ESPOutlineTransparency
            hl.Parent = egg
            d.Highlight = hl
        end
        d.Highlight.FillColor = color
        d.Highlight.OutlineColor = color
        d.Highlight.Enabled = true
        createEggLabel(egg)
        if d.NameBillboard then d.NameBillboard.Enabled = true end
        updateEggLabel(egg)
    else
        if d.Highlight then d.Highlight.Enabled = false end
        if d.NameBillboard then d.NameBillboard.Enabled = false end
    end
end

local function updateAllESP()
    if not RenderedEggsFolder then return end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do updateEggESP(egg) end
end

local function removeEggData(egg)
    local d = S.eggData[egg]
    if not d then return end
    if d.Highlight then d.Highlight:Destroy() end
    if d.NameBillboard then d.NameBillboard:Destroy() end
    S.eggData[egg] = nil
end

--==================================================
-- [6] MOVEMENT / TP
--==================================================
local function teleportToModel(target)
    local root = getRootPart()
    if not root then return false end
    local cf = getTargetCFrame(target)
    if not cf then return false end
    root.CFrame = cf * CFrame.new(0, C.TPHeight, 0)
    return true
end

local function setNoclip(enabled)
    local ch = getCharacter()
    if not ch then return end
    if enabled then
        S.movementPartsState = {}
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                S.movementPartsState[p] = p.CanCollide
                p.CanCollide = false
            end
        end
    elseif S.movementPartsState then
        for p, old in pairs(S.movementPartsState) do
            if p and p.Parent then p.CanCollide = old end
        end
        S.movementPartsState = nil
    end
end

local function moveToModel(target)
    if S.movementMode == "Teleport" then return teleportToModel(target) end
    if S.movementActive then return false end

    local ch   = getCharacter()
    local root = getRootPart()
    local hum  = ch and ch:FindFirstChildOfClass("Humanoid")
    local cf   = getTargetCFrame(target)
    if not root or not hum or not cf then return false end

    local dest = cf.Position + Vector3.new(0, C.TPHeight, 0)
    local startDist = (root.Position - dest).Magnitude
    if startDist <= 2 then
        root.CFrame = cf * CFrame.new(0, C.TPHeight, 0)
        return true
    end

    S.movementActive = true
    S.movementHumanoid = hum
    local oldRot = hum.AutoRotate
    local success = false
    local t0 = os.clock()
    local maxT = math.max(3, startDist / C.MovementSpeed + 2)

    setNoclip(true)
    hum.AutoRotate = false

    while S.movementActive and (os.clock() - t0) <= maxT do
        if not target or not target.Parent then break end
        if getRootPart() ~= root then break end
        local off = dest - root.Position
        local d = off.Magnitude
        if d <= 2 then
            root.CFrame = cf * CFrame.new(0, C.TPHeight, 0)
            success = true
            break
        end
        local dt = RunService.Heartbeat:Wait()
        local step = math.min(d, C.MovementSpeed * dt)
        root.CFrame = root.CFrame + off.Unit * step
    end

    S.movementActive = false
    if hum.Parent then hum.AutoRotate = oldRot end
    S.movementHumanoid = nil
    setNoclip(false)
    return success
end

local function stopMovement()
    S.movementActive = false
    if S.movementHumanoid and S.movementHumanoid.Parent then
        S.movementHumanoid.AutoRotate = true
    end
    S.movementHumanoid = nil
    setNoclip(false)
end

local function teleportToHomePlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return false end
    for _, plot in ipairs(plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        if data then
            local owner = data:FindFirstChild("Owner")
            if owner then
                local isOwner
                if owner:IsA("StringValue") then isOwner = owner.Value == LocalPlayer.Name
                elseif owner:IsA("ObjectValue") then isOwner = owner.Value == LocalPlayer
                else isOwner = tostring(owner.Value) == LocalPlayer.Name end
                if isOwner then return moveToModel(plot) end
            end
        end
    end
    return false
end

--==================================================
-- [7] AUTO BEST EGG + AUTOFARM + AUTO REBIRTH
--==================================================
local function holdEKey(dur)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(dur)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function findBestEgg()
    if not RenderedEggsFolder then return nil end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if string.find(egg.Name:lower(), C.BestEggName:lower(), 1, true) then
            return egg
        end
    end
    return nil
end

local function stopAutoBestEgg()
    S.autoBestEggActive = false
    stopMovement()
    if S.autoBestEggThread then
        task.cancel(S.autoBestEggThread)
        S.autoBestEggThread = nil
    end
end

local function startAutoBestEgg()
    stopAutoBestEgg()
    S.autoBestEggActive = true
    S.autoBestEggThread = task.spawn(function()
        while S.autoBestEggActive do
            local egg = findBestEgg()
            if egg and egg.Parent then
                if moveToModel(egg) then
                    task.wait(0.3)
                    if S.autoBestEggActive and egg.Parent then
                        holdEKey(C.AutoEggHoldTime)
                    end
                    task.wait(0.2)
                    if S.autoBestEggActive then teleportToHomePlot() end
                    task.wait(C.AutoEggDelay)
                end
            else
                task.wait(0.5)
            end
        end
    end)
end

local function isValidEgg(egg)
    return egg and egg.Parent == RenderedEggsFolder
        and (egg:IsA("Model") or egg:IsA("BasePart"))
end

local function getAutoFarmEggs()
    local found = {}
    if not RenderedEggsFolder then return found end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if isValidEgg(egg) and S.autoFarmEggs[egg.Name] and not S.autoFarmProcessed[egg] then
            table.insert(found, egg)
        end
    end
    table.sort(found, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return found
end

local function stopAutoFarm()
    S.autoFarmActive = false
    stopMovement()
    if S.autoFarmThread then
        task.cancel(S.autoFarmThread)
        S.autoFarmThread = nil
    end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function startAutoFarm()
    stopAutoFarm()
    S.autoFarmActive = true
    S.autoFarmThread = task.spawn(function()
        while S.autoFarmActive do
            local eggs = getAutoFarmEggs()
            if #eggs == 0 then
                S.autoFarmActive = false
                S.autoFarmThread = nil
                break
            end
            local didWork = false
            for _, egg in ipairs(eggs) do
                if not S.autoFarmActive then break end
                if isValidEgg(egg) and not S.autoFarmProcessed[egg] then
                    didWork = true
                    if moveToModel(egg) and S.autoFarmActive then
                        task.wait(0.3)
                        if S.autoFarmActive and isValidEgg(egg) then
                            holdEKey(C.AutoFarmHoldTime)
                        end
                        if S.autoFarmActive then
                            task.wait(0.2)
                            teleportToHomePlot()
                        end
                        S.autoFarmProcessed[egg] = true
                        task.wait(0.2)
                    end
                end
            end
            if not didWork then
                S.autoFarmActive = false
                S.autoFarmThread = nil
                break
            end
            task.wait(0.2)
        end
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function stopAutoRebirth()
    S.autoRebirthActive = false
    if S.autoRebirthThread then
        task.cancel(S.autoRebirthThread)
        S.autoRebirthThread = nil
    end
end

local function startAutoRebirth()
    stopAutoRebirth()
    S.autoRebirthActive = true
    S.autoRebirthThread = task.spawn(function()
        while S.autoRebirthActive do
            -- Try Rebirth button in PlayerGui if present
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local rebirthBtn = pg and pg:FindFirstChild("RebirthButton", true)
            if rebirthBtn and rebirthBtn:IsA("GuiButton") then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end)
            end
            task.wait(S.autoRebirthDelay)
        end
    end)
end

--==================================================
-- [8] UI BUILDERS
--==================================================
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, col, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.BorderCard
    s.Thickness = t or 1
    s.Transparency = tr or 0
    s.Parent = p
    return s
end

local function label(p, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextSize = size or 13
    l.TextColor3 = color or C.TextWhite
    l.Font = font or Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = p
    return l
end

local function makeCard(parent, title, subtitle, size, position, order)
    local card = Instance.new("Frame")
    card.Size = size
    card.Position = position or UDim2.new(0,0,0,0)
    card.BackgroundColor3 = C.BgCard
    card.BorderSizePixel = 0
    card.LayoutOrder = order or 0
    card.Parent = parent
    corner(card, 10)
    stroke(card, C.BorderCard, 1, 0.55)

    local tl = label(card, title, 14, C.TextWhite, Enum.Font.GothamBold)
    tl.Size = UDim2.new(1, -20, 0, 18)
    tl.Position = UDim2.new(0, 14, 0, 10)

    if subtitle then
        local sl = label(card, subtitle, 10, C.TextDim, Enum.Font.Gotham)
        sl.Size = UDim2.new(1, -20, 0, 14)
        sl.Position = UDim2.new(0, 14, 0, 27)
    end

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -20, 1, -54)
    body.Position = UDim2.new(0, 10, 0, 48)
    body.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = body

    return card, body
end

local function makeToggle(parent, text, initial, order, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order or 0
    row.Parent = parent

    local lbl = label(row, text, 12, C.TextWhite, Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(1, -60, 1, 0)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 42, 0, 22)
    track.Position = UDim2.new(1, -42, 0.5, -11)
    track.BackgroundColor3 = initial and C.ToggleOn or C.ToggleOff
    track.Text = ""
    track.AutoButtonColor = false
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initial and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,4,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 8)

    local state = initial
    local function setState(v, fire)
        state = v
        tween(track, {BackgroundColor3 = state and C.ToggleOn or C.ToggleOff}, 0.15)
        tween(knob,  {Position = state and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,4,0.5,-8)}, 0.15)
        if fire and callback then callback(state) end
    end
    track.MouseButton1Click:Connect(function() setState(not state, true) end)

    return { setState = setState, getState = function() return state end }
end

local function makeButton(parent, text, style, size, pos, callback)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos or UDim2.new(0,0,0,0)
    b.Text = text
    b.TextColor3 = C.TextWhite
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b, 8)

    if style == "primary" then
        b.BackgroundColor3 = C.Accent
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(C.AccentDeep, C.AccentLight)
        g.Parent = b
    elseif style == "danger" then
        b.BackgroundColor3 = C.Danger
    elseif style == "success" then
        b.BackgroundColor3 = C.Success
    else
        b.BackgroundColor3 = C.BgCardAlt
        stroke(b, C.BorderCard, 1, 0.4)
    end

    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.15}, 0.1) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0}, 0.1) end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

local function makeDropdown(parent, options, initial, size, pos, callback)
    local ctn = Instance.new("Frame")
    ctn.Size = size
    ctn.Position = pos or UDim2.new(0,0,0,0)
    ctn.BackgroundColor3 = C.BgInput
    ctn.BorderSizePixel = 0
    ctn.Parent = parent
    corner(ctn, 8)
    stroke(ctn, C.BorderCard, 1, 0.55)

    local sel = label(ctn, tostring(initial), 12, C.TextWhite, Enum.Font.GothamMedium)
    sel.Size = UDim2.new(1, -32, 1, 0)
    sel.Position = UDim2.new(0, 12, 0, 0)

    local chev = label(ctn, "▾", 14, C.TextGray, Enum.Font.GothamBold)
    chev.Size = UDim2.new(0, 20, 1, 0)
    chev.Position = UDim2.new(1, -24, 0, 0)
    chev.TextXAlignment = Enum.TextXAlignment.Center

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = ctn

    local idx = 1
    for i, o in ipairs(options) do if o == initial then idx = i break end end

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        local v = options[idx]
        sel.Text = tostring(v)
        if callback then callback(v) end
    end)

    return {
        getValue = function() return options[idx] end,
        setValue = function(v)
            for i, o in ipairs(options) do
                if o == v then idx = i; sel.Text = tostring(v) break end
            end
        end
    }
end

local function makeInput(parent, placeholder, initial, size, pos, callback)
    local box = Instance.new("TextBox")
    box.Size = size
    box.Position = pos or UDim2.new(0,0,0,0)
    box.BackgroundColor3 = C.BgInput
    box.BorderSizePixel = 0
    box.Text = tostring(initial or "")
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = C.TextDim
    box.TextColor3 = C.TextWhite
    box.TextSize = 12
    box.Font = Enum.Font.GothamMedium
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Parent = parent
    corner(box, 8)
    stroke(box, C.BorderCard, 1, 0.55)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = box

    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
    end)
    return box
end

local function makeScroll(parent)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 4
    s.ScrollBarImageColor3 = C.Accent
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.Parent = parent
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 4)
    ll.Parent = s
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        s.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 6)
    end)
    return s
end

local function buildEggRow(parent, egg, actions)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 32)
    row.BackgroundColor3 = C.BgCardAlt
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 6)
    stroke(row, C.BorderCard, 1, 0.7)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 24, 0, 24)
    icon.Position = UDim2.new(0, 5, 0.5, -12)
    icon.BackgroundTransparency = 1
    icon.Image = getEggImage(egg.Name)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = row

    local numA = #actions
    local actionArea = numA * 38

    local dist = getDistanceToTarget(egg)
    local distStr = (dist ~= math.huge) and string.format(" (%dm)", math.floor(dist + 0.5)) or ""

    local nameLbl = label(row, egg.Name .. distStr, 11, C.TextWhite, Enum.Font.GothamMedium)
    nameLbl.Size = UDim2.new(1, -(40 + actionArea), 1, 0)
    nameLbl.Position = UDim2.new(0, 34, 0, 0)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    for i, act in ipairs(actions) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 34, 0, 22)
        b.Position = UDim2.new(1, -5 - (numA - i) * 38 - 34, 0.5, -11)
        b.BackgroundColor3 = act.color or C.BgHover
        b.Text = act.text
        b.TextColor3 = C.TextWhite
        b.TextSize = 9
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = row
        corner(b, 6)
        b.MouseButton1Click:Connect(function()
            if act.cb then act.cb(b) end
        end)
    end

    return row
end

local function getEggList()
    local list = {}
    if not RenderedEggsFolder then return list end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            table.insert(list, egg)
        end
    end
    table.sort(list, function(a, b)
        if S.sortMode == "Distance" then
            return getDistanceToTarget(a) < getDistanceToTarget(b)
        end
        return a.Name:lower() < b.Name:lower()
    end)
    return list
end

local function clearList(scroll)
    for _, ch in ipairs(scroll:GetChildren()) do
        if not ch:IsA("UIListLayout") then ch:Destroy() end
    end
end

--==================================================
-- [9] CLEANUP OLD GUI
--==================================================
for _, name in ipairs({"EGOY_Menu", "EGOY_RIDE_A_PET_Menu", "RenderedEggsESP_Menu"}) do
    pcall(function()
        local old = TargetParent:FindFirstChild(name)
        if old then old:Destroy() end
    end)
end

--==================================================
-- [10] ROOT
--==================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EGOY_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = TargetParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, C.DesignW, 0, C.DesignH)
MainFrame.Position = UDim2.new(0.5, -C.DesignW/2, 0.5, -C.DesignH/2)
MainFrame.BackgroundColor3 = C.BgMain
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
corner(MainFrame, 12)
stroke(MainFrame, C.BorderMain, 2, 0.15)

-- Responsive scaling
local cam = Workspace.CurrentCamera
local function applyScale()
    if not cam then return end
    local v = cam.ViewportSize
    local s = math.min(v.X / (C.DesignW + 30), v.Y / (C.DesignH + 30), 1)
    local sc = MainFrame:FindFirstChildOfClass("UIScale")
    if not sc then
        sc = Instance.new("UIScale")
        sc.Parent = MainFrame
    end
    sc.Scale = s
end
applyScale()
if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
end

-- Floating reopen button
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
FloatingBtn.Position = UDim2.new(0, 20, 0.5, -26)
FloatingBtn.BackgroundColor3 = C.Accent
FloatingBtn.Text = "👑"
FloatingBtn.TextSize = 22
FloatingBtn.TextColor3 = C.TextWhite
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.AutoButtonColor = false
FloatingBtn.Visible = false
FloatingBtn.ZIndex = 100
FloatingBtn.Parent = ScreenGui
corner(FloatingBtn, 26)
FloatingBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    FloatingBtn.Visible = false
end)

--==================================================
-- [11] HEADER
--==================================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, C.HeaderH)
Header.BackgroundColor3 = C.BgMain
Header.BorderSizePixel = 0
Header.Parent = MainFrame
corner(Header, 12)

local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 12)
headerFill.Position = UDim2.new(0, 0, 1, -12)
headerFill.BackgroundColor3 = C.BgMain
headerFill.BorderSizePixel = 0
headerFill.ZIndex = 0
headerFill.Parent = Header

local crownLbl = label(Header, "👑", 30, C.AccentLight, Enum.Font.GothamBold)
crownLbl.Size = UDim2.new(0, 44, 0, 44)
crownLbl.Position = UDim2.new(0, 18, 0, 8)
crownLbl.TextXAlignment = Enum.TextXAlignment.Center

local logoLbl = label(Header, "EGOY", 26, C.TextWhite, Enum.Font.GothamBlack)
logoLbl.Size = UDim2.new(0, 150, 0, 30)
logoLbl.Position = UDim2.new(0, 65, 0, 6)

local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new(C.AccentLight, Color3.fromRGB(255, 200, 255))
logoGrad.Parent = logoLbl

local subLbl = label(Header, "AUTO FARM & ESP  •  By EGOY", 10, C.TextGray, Enum.Font.GothamBold)
subLbl.Size = UDim2.new(0, 240, 0, 14)
subLbl.Position = UDim2.new(0, 66, 0, 36)

local badge = Instance.new("Frame")
badge.Size = UDim2.new(0, 210, 0, 32)
badge.Position = UDim2.new(1, -310, 0, 14)
badge.BackgroundColor3 = C.AccentDeep
badge.BorderSizePixel = 0
badge.Parent = Header
corner(badge, 8)
local bGrad = Instance.new("UIGradient")
bGrad.Color = ColorSequence.new(C.AccentDeep, C.Accent)
bGrad.Parent = badge
local badgeIcon = label(badge, "🐾", 16, C.TextWhite, Enum.Font.GothamBold)
badgeIcon.Size = UDim2.new(0, 26, 1, 0)
badgeIcon.Position = UDim2.new(0, 8, 0, 0)
badgeIcon.TextXAlignment = Enum.TextXAlignment.Center
local badgeText = label(badge, "RIDE A PET", 13, C.TextWhite, Enum.Font.GothamBold)
badgeText.Size = UDim2.new(1, -34, 1, 0)
badgeText.Position = UDim2.new(0, 34, 0, 0)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -74, 0, 15)
minBtn.BackgroundColor3 = C.BgCardAlt
minBtn.Text = "—"
minBtn.TextColor3 = C.TextWhite
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.AutoButtonColor = false
minBtn.BorderSizePixel = 0
minBtn.Parent = Header
corner(minBtn, 8)
stroke(minBtn, C.BorderCard, 1, 0.5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 15)
closeBtn.BackgroundColor3 = C.BgCardAlt
closeBtn.Text = "✕"
closeBtn.TextColor3 = C.TextWhite
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = Header
corner(closeBtn, 8)
stroke(closeBtn, C.BorderCard, 1, 0.5)

--==================================================
-- [12] SIDEBAR
--==================================================
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, C.SidebarW, 1, -(C.HeaderH + C.FooterH))
Sidebar.Position = UDim2.new(0, 0, 0, C.HeaderH)
Sidebar.BackgroundColor3 = C.BgPanel
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local sideDiv = Instance.new("Frame")
sideDiv.Size = UDim2.new(0, 1, 1, 0)
sideDiv.Position = UDim2.new(1, -1, 0, 0)
sideDiv.BackgroundColor3 = C.BorderCard
sideDiv.BorderSizePixel = 0
sideDiv.Parent = Sidebar

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.Parent = Sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop  = UDim.new(0, 10)
sidePad.PaddingLeft = UDim.new(0, 10)
sidePad.PaddingRight= UDim.new(0, 10)
sidePad.Parent = Sidebar

-- Sidebar bottom logo
local sideLogo = Instance.new("Frame")
sideLogo.Size = UDim2.new(1, -20, 0, 90)
sideLogo.Position = UDim2.new(0, 10, 1, -100)
sideLogo.BackgroundTransparency = 1
sideLogo.Parent = Sidebar

local slIcon = label(sideLogo, "👑", 22, C.AccentLight, Enum.Font.GothamBold)
slIcon.Size = UDim2.new(1, 0, 0, 26)
slIcon.TextXAlignment = Enum.TextXAlignment.Center

local slName = label(sideLogo, "E.G.O.Y", 22, C.AccentLight, Enum.Font.GothamBlack)
slName.Size = UDim2.new(1, 0, 0, 26)
slName.Position = UDim2.new(0, 0, 0, 24)
slName.TextXAlignment = Enum.TextXAlignment.Center
local slGrad = Instance.new("UIGradient")
slGrad.Color = ColorSequence.new(C.Accent, C.AccentLight)
slGrad.Parent = slName

local slTag = label(sideLogo, "PLAY FARM\nGET STRONGER", 9, C.TextDim, Enum.Font.GothamBold)
slTag.Size = UDim2.new(1, 0, 0, 26)
slTag.Position = UDim2.new(0, 0, 0, 54)
slTag.TextXAlignment = Enum.TextXAlignment.Center

--==================================================
-- [13] CONTENT AREA
--==================================================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -C.SidebarW, 1, -(C.HeaderH + C.FooterH))
ContentArea.Position = UDim2.new(0, C.SidebarW, 0, C.HeaderH)
ContentArea.BackgroundColor3 = C.BgMain
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

--==================================================
-- [14] FOOTER
--==================================================
local Footer = Instance.new("Frame")
Footer.Name = "Footer"
Footer.Size = UDim2.new(1, 0, 0, C.FooterH)
Footer.Position = UDim2.new(0, 0, 1, -C.FooterH)
Footer.BackgroundColor3 = C.BgPanel
Footer.BorderSizePixel = 0
Footer.Parent = MainFrame
corner(Footer, 12)

local fDiv = Instance.new("Frame")
fDiv.Size = UDim2.new(1, 0, 0, 1)
fDiv.BackgroundColor3 = C.BorderCard
fDiv.BorderSizePixel = 0
fDiv.Parent = Footer

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 16, 0.5, -4)
statusDot.BackgroundColor3 = C.Success
statusDot.BorderSizePixel = 0
statusDot.Parent = Footer
corner(statusDot, 4)

local statusFooter = label(Footer, "Menu Loaded", 11, C.TextGray, Enum.Font.GothamMedium)
statusFooter.Size = UDim2.new(0, 200, 1, 0)
statusFooter.Position = UDim2.new(0, 32, 0, 0)

local footerPipe = label(Footer, "|", 11, C.TextDim, Enum.Font.Gotham)
footerPipe.Size = UDim2.new(0, 12, 1, 0)
footerPipe.Position = UDim2.new(0, 138, 0, 0)

local footerTag = label(Footer, "EGOY", 11, C.AccentLight, Enum.Font.GothamBold)
footerTag.Size = UDim2.new(0, 60, 1, 0)
footerTag.Position = UDim2.new(0, 152, 0, 0)

local madeBadge = Instance.new("Frame")
madeBadge.Size = UDim2.new(0, 200, 0, 22)
madeBadge.Position = UDim2.new(1, -214, 0.5, -11)
madeBadge.BackgroundColor3 = C.BgCardAlt
madeBadge.BorderSizePixel = 0
madeBadge.Parent = Footer
corner(madeBadge, 6)
stroke(madeBadge, C.BorderCard, 1, 0.4)

local madeLbl = label(madeBadge, "♛   Made for the community", 10, C.TextGray, Enum.Font.GothamMedium)
madeLbl.Size = UDim2.new(1, 0, 1, 0)
madeLbl.TextXAlignment = Enum.TextXAlignment.Center

--==================================================
-- [15] TAB SYSTEM
--==================================================
local tabsOrder = {
    { id = "Home",      icon = "🏠", label = "Home" },
    { id = "ESP",       icon = "👁", label = "ESP" },
    { id = "AutoFarm",  icon = "⚙", label = "Auto Farm" },
    { id = "Teleports", icon = "📍", label = "Teleports" },
    { id = "Eggs",      icon = "🥚", label = "Eggs" },
    { id = "Misc",      icon = "✨", label = "Misc" },
    { id = "Settings",  icon = "🛠", label = "Settings" },
}

for i, tab in ipairs(tabsOrder) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. tab.id
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = C.BgPanel
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local iconLbl = label(btn, tab.icon, 16, C.TextGray, Enum.Font.GothamBold)
    iconLbl.Size = UDim2.new(0, 30, 1, 0)
    iconLbl.Position = UDim2.new(0, 8, 0, 0)
    iconLbl.TextXAlignment = Enum.TextXAlignment.Center

    local nameLbl = label(btn, tab.label, 12, C.TextGray, Enum.Font.GothamMedium)
    nameLbl.Size = UDim2.new(1, -46, 1, 0)
    nameLbl.Position = UDim2.new(0, 40, 0, 0)

    local content = Instance.new("Frame")
    content.Name = "TabContent_" .. tab.id
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = ContentArea

    UI.tabs[tab.id] = {
        button = btn, content = content,
        icon = iconLbl, label = nameLbl,
    }

    btn.MouseEnter:Connect(function()
        if S.activeTab ~= tab.id then
            btn.BackgroundTransparency = 0.6
            btn.BackgroundColor3 = C.BgHover
        end
    end)
    btn.MouseLeave:Connect(function()
        if S.activeTab ~= tab.id then
            btn.BackgroundTransparency = 1
        end
    end)
end

local function switchTab(id)
    S.activeTab = id
    for tid, t in pairs(UI.tabs) do
        if tid == id then
            t.content.Visible = true
            t.button.BackgroundTransparency = 0
            t.button.BackgroundColor3 = C.Accent
            t.icon.TextColor3 = C.TextWhite
            t.label.TextColor3 = C.TextWhite
            t.label.Font = Enum.Font.GothamBold
            if not t.button:FindFirstChildOfClass("UIGradient") then
                local g = Instance.new("UIGradient")
                g.Color = ColorSequence.new(C.AccentDeep, C.AccentLight)
                g.Parent = t.button
            end
        else
            t.content.Visible = false
            t.button.BackgroundTransparency = 1
            t.icon.TextColor3 = C.TextGray
            t.label.TextColor3 = C.TextGray
            t.label.Font = Enum.Font.GothamMedium
            local g = t.button:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        end
    end
    local r = UI.refs["refresh_" .. id]
    if r then pcall(r) end
end

for id, t in pairs(UI.tabs) do
    t.button.MouseButton1Click:Connect(function() switchTab(id) end)
end

--==================================================
-- [16] TAB: HOME
--==================================================
do
    local content = UI.tabs.Home.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 1, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = content

    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -8, 0, 165)
    gl.CellPadding = UDim2.new(0, 16, 0, 16)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    -- Card: ESP All
    local c1, b1 = makeCard(grid, "👁   ESP All", "Show eggs through walls",
        UDim2.new(1,0,1,0), nil, 1)
    makeToggle(b1, "Enable ESP on all eggs", false, 1, function(v)
        S.mainESPActive = v
        updateAllESP()
    end)
    makeToggle(b1, "Players ESP", false, 2, function(v) S.espPlayers = v end)
    makeToggle(b1, "Pets ESP",    false, 3, function(v) S.espPets = v end)

    -- Card: Auto Best Egg
    local c2, b2 = makeCard(grid, "🥚   Auto Best Egg", "Automatically open best egg",
        UDim2.new(1,0,1,0), nil, 2)
    makeToggle(b2, "Enable Auto Best Egg", false, 1, function(v)
        S.autoBestEggActive = v
        if v then startAutoBestEgg() else stopAutoBestEgg() end
    end)
    local bestInp = makeInput(b2, "Best egg name", C.BestEggName,
        UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), function(t)
            C.BestEggName = t ~= "" and t or C.BestEggName
        end)

    -- Card: TP Home
    local c3, b3 = makeCard(grid, "🏠   TP Home", "Teleport to your plot",
        UDim2.new(1,0,1,0), nil, 3)
    makeButton(b3, "🏠  Teleport Home", "primary",
        UDim2.new(1, 0, 0, 34), nil, function()
            teleportToHomePlot()
        end)
    makeToggle(b3, "Teleport Mode (instant)", false, 2, function(v)
        S.movementMode = v and "Teleport" or "AutoFarm"
    end)

    -- Card: Info
    local c4, b4 = makeCard(grid, "ℹ   Info", "EGOY • Auto Farm & ESP",
        UDim2.new(1,0,1,0), nil, 4)
    local infoLbl = label(b4, "• Drag the header to move the menu\n• Use sidebar tabs to navigate\n• Press minimizer to shrink the menu", 10, C.TextGray, Enum.Font.Gotham)
    infoLbl.Size = UDim2.new(1, 0, 1, 0)
    infoLbl.TextYAlignment = Enum.TextYAlignment.Top
end

--==================================================
-- [17] TAB: ESP
--==================================================
do
    local content = UI.tabs.ESP.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local left = Instance.new("Frame")
    left.Size = UDim2.new(0.45, -8, 1, 0)
    left.BackgroundTransparency = 1
    left.Parent = content

    local right = Instance.new("Frame")
    right.Size = UDim2.new(0.55, -8, 1, 0)
    right.Position = UDim2.new(0.45, 8, 0, 0)
    right.BackgroundTransparency = 1
    right.Parent = content

    -- Left: ESP toggles card
    local cardL, bodyL = makeCard(left, "🎯   ESP Targets", "Choose what to highlight",
        UDim2.new(1, 0, 0, 300), nil, 1)
    makeToggle(bodyL, "Players ESP", false, 1, function(v) S.espPlayers = v end)
    makeToggle(bodyL, "Pets ESP",    false, 2, function(v) S.espPets = v end)
    makeToggle(bodyL, "Eggs ESP",    false, 3, function(v)
        S.mainESPActive = v
        updateAllESP()
    end)
    makeToggle(bodyL, "Chests ESP",  false, 4, function(v) S.espChests = v end)
    makeToggle(bodyL, "Items ESP",   false, 5, function(v) S.espItems = v end)

    -- Right: Egg list with individual ESP
    local cardR, bodyR = makeCard(right, "🥚   Eggs (Individual ESP)", "Tap ESP to toggle for one egg",
        UDim2.new(1, 0, 1, 0), nil, 1)
    local scrollR = makeScroll(bodyR)
    UI.refs.espScroll = scrollR

    local function refreshESPList()
        clearList(scrollR)
        local eggs = getEggList()
        if #eggs == 0 then
            local none = label(scrollR, "No eggs detected", 11, C.TextDim, Enum.Font.GothamItalic)
            none.Size = UDim2.new(1, -8, 0, 30)
            return
        end
        for _, egg in ipairs(eggs) do
            local isOn = S.eggData[egg] and S.eggData[egg].CustomActive
            buildEggRow(scrollR, egg, {
                {text = isOn and "ON" or "ESP", color = isOn and C.Success or C.BgHover, cb = function(btn)
                    if not S.eggData[egg] then
                        S.eggData[egg] = {Highlight=nil, NameBillboard=nil,
                            CustomColor = C.CustomESPColor, CustomActive = false}
                    end
                    local d = S.eggData[egg]
                    d.CustomActive = not d.CustomActive
                    d.CustomColor = C.CustomESPColor
                    btn.Text = d.CustomActive and "ON" or "ESP"
                    btn.BackgroundColor3 = d.CustomActive and C.Success or C.BgHover
                    updateEggESP(egg)
                end}
            })
        end
    end
    UI.refs.refresh_ESP = refreshESPList
end

--==================================================
-- [18] TAB: AUTO FARM
--==================================================
do
    local content = UI.tabs.AutoFarm.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 1, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = content

    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -8, 0, 230)
    gl.CellPadding = UDim2.new(0, 16, 0, 16)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    -- Card: Auto Farm
    local c1, b1 = makeCard(grid, "⚙   Auto Farm", "Farm eggs automatically",
        UDim2.new(1,0,1,0), nil, 1)
    makeDropdown(b1, {"AutoFarm", "Teleport"}, "AutoFarm",
        UDim2.new(1, 0, 0, 32), nil, function(v)
            S.movementMode = v
        end)
    local lbl1 = label(b1, "Farm Mode", 10, C.TextDim, Enum.Font.Gotham)
    lbl1.Size = UDim2.new(1, 0, 0, 14)
    makeButton(b1, "🛑  Stop Auto Farm", "danger",
        UDim2.new(1, 0, 0, 34), nil, function()
            stopAutoFarm()
        end)

    -- Card: Auto Rebirth
    local c2, b2 = makeCard(grid, "🔁   Auto Rebirth", "Rebirth automatically",
        UDim2.new(1,0,1,0), nil, 2)
    makeToggle(b2, "Auto Rebirth", false, 1, function(v)
        S.autoRebirthActive = v
        if v then startAutoRebirth() else stopAutoRebirth() end
    end)
    local delayLbl = label(b2, "Rebirth Delay (s)", 10, C.TextDim, Enum.Font.Gotham)
    delayLbl.Size = UDim2.new(1, 0, 0, 14)
    makeInput(b2, "5", 5, UDim2.new(1, 0, 0, 28), nil, function(t)
        local n = tonumber(t)
        if n then S.autoRebirthDelay = n end
    end)

    -- Card: Farm Status / targets
    local c3, b3 = makeCard(grid, "📋   Farm Targets", "Select eggs from the Eggs tab",
        UDim2.new(1,0,1,0), nil, 3)
    local statLbl = label(b3, "Active: " .. tostring(S.autoFarmActive), 11, C.TextGray, Enum.Font.Gotham)
    statLbl.Size = UDim2.new(1, 0, 0, 20)
    local countLbl = label(b3, "Selected eggs: 0", 11, C.TextGray, Enum.Font.Gotham)
    countLbl.Size = UDim2.new(1, 0, 0, 20)
    local function upd()
        statLbl.Text = "Active: " .. tostring(S.autoFarmActive)
        local n = 0
        for _ in pairs(S.autoFarmEggs) do n += 1 end
        countLbl.Text = "Selected eggs: " .. n
    end
    upd()
    makeButton(b3, "🔄  Update Status", "default",
        UDim2.new(1, 0, 0, 28), nil, upd)

    -- Card: Best Egg
    local c4, b4 = makeCard(grid, "🥚   Best Egg", "Auto-opens best egg",
        UDim2.new(1,0,1,0), nil, 4)
    makeToggle(b4, "Enable Auto Best Egg", false, 1, function(v)
        S.autoBestEggActive = v
        if v then startAutoBestEgg() else stopAutoBestEgg() end
    end)
    makeInput(b4, "Best egg name", C.BestEggName,
        UDim2.new(1, 0, 0, 28), nil, function(t)
            C.BestEggName = t ~= "" and t or C.BestEggName
        end)
end

--==================================================
-- [19] TAB: TELEPORTS
--==================================================
do
    local content = UI.tabs.Teleports.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 1, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = content

    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -8, 0, 240)
    gl.CellPadding = UDim2.new(0, 16, 0, 16)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    -- Quick teleports card
    local c1, b1 = makeCard(grid, "📍   Quick Teleports", "One-tap teleports",
        UDim2.new(1,0,1,0), nil, 1)
    makeButton(b1, "🏠  Home Plot", "primary",
        UDim2.new(1, 0, 0, 34), nil, function() teleportToHomePlot() end)
    makeButton(b1, "🚶  Move to Home (walk)", "default",
        UDim2.new(1, 0, 0, 30), nil, function()
            S.movementMode = "AutoFarm"
            teleportToHomePlot()
        end)
    makeButton(b1, "⚡  Instant TP Home", "default",
        UDim2.new(1, 0, 0, 30), nil, function()
            S.movementMode = "Teleport"
            teleportToHomePlot()
        end)

    -- Teleport to egg list
    local c2, b2 = makeCard(grid, "🥚   Teleport to Egg", "Tap TP to teleport",
        UDim2.new(1,0,1,0), nil, 2)
    local scroll = makeScroll(b2)
    UI.refs.tpScroll = scroll

    local function refreshTPList()
        clearList(scroll)
        local eggs = getEggList()
        if #eggs == 0 then
            local none = label(scroll, "No eggs detected", 11, C.TextDim, Enum.Font.GothamItalic)
            none.Size = UDim2.new(1, -8, 0, 30)
            return
        end
        for _, egg in ipairs(eggs) do
            buildEggRow(scroll, egg, {
                {text = "TP", color = C.Accent, cb = function()
                    teleportToModel(egg)
                end}
            })
        end
    end
    UI.refs.refresh_Teleports = refreshTPList
end

--==================================================
-- [20] TAB: EGGS
--==================================================
do
    local content = UI.tabs.Eggs.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    -- Top bar: search, sort, count
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36)
    top.BackgroundTransparency = 1
    top.Parent = content

    local searchBox = makeInput(top, "🔍 Search egg...", "", 
        UDim2.new(1, -270, 1, 0), UDim2.new(0, 0, 0, 0), function(t)
            S.currentSearchQuery = t
            UI.refs.refresh_Eggs()
        end)

    local sortBtn = makeButton(top, "Sort: Name", "default",
        UDim2.new(0, 130, 1, 0), UDim2.new(1, -258, 0, 0), function(b)
            if S.sortMode == "Name" then
                S.sortMode = "Distance"
                b.Text = "Sort: Distance"
            else
                S.sortMode = "Name"
                b.Text = "Sort: Name"
            end
            UI.refs.refresh_Eggs()
        end)

    local refreshBtn = makeButton(top, "🔄 Refresh", "primary",
        UDim2.new(0, 120, 1, 0), UDim2.new(1, -120, 0, 0), function()
            UI.refs.refresh_Eggs()
            updateAllESP()
        end)

    -- Counter
    local cnt = label(content, "Eggs: 0  |  Results: 0", 11, C.TextGray, Enum.Font.GothamBold)
    cnt.Size = UDim2.new(1, 0, 0, 18)
    cnt.Position = UDim2.new(0, 0, 0, 42)
    UI.refs.eggCount = cnt

    -- Scrolling list
    local listHolder = Instance.new("Frame")
    listHolder.Size = UDim2.new(1, 0, 1, -66)
    listHolder.Position = UDim2.new(0, 0, 0, 66)
    listHolder.BackgroundTransparency = 1
    listHolder.Parent = content

    local scroll = makeScroll(listHolder)
    UI.refs.eggScroll = scroll

    local function refreshEggList()
        clearList(scroll)
        local all = getEggList()
        local query = S.currentSearchQuery:lower()
        local shown = 0
        for _, egg in ipairs(all) do
            local match = query == "" or string.find(egg.Name:lower(), query, 1, true)
            if match then
                shown += 1
                local farmOn = S.autoFarmEggs[egg.Name] == true
                local espOn  = S.eggData[egg] and S.eggData[egg].CustomActive
                buildEggRow(scroll, egg, {
                    {text = "TP", color = C.Accent, cb = function()
                        teleportToModel(egg)
                    end},
                    {text = farmOn and "F:ON" or "FARM",
                        color = farmOn and C.Success or C.BgHover,
                        cb = function(btn)
                            S.autoFarmEggs[egg.Name] = not S.autoFarmEggs[egg.Name]
                            for p in pairs(S.autoFarmProcessed) do
                                if p and p.Name == egg.Name then
                                    S.autoFarmProcessed[p] = nil
                                end
                            end
                            local on = S.autoFarmEggs[egg.Name]
                            btn.Text = on and "F:ON" or "FARM"
                            btn.BackgroundColor3 = on and C.Success or C.BgHover
                            if on and not S.autoFarmActive then
                                startAutoFarm()
                            end
                            local any = false
                            for _ in pairs(S.autoFarmEggs) do any = true; break end
                            if not any then stopAutoFarm() end
                        end},
                    {text = espOn and "ON" or "ESP",
                        color = espOn and C.Success or C.BgHover,
                        cb = function(btn)
                            if not S.eggData[egg] then
                                S.eggData[egg] = {Highlight=nil, NameBillboard=nil,
                                    CustomColor = C.CustomESPColor, CustomActive = false}
                            end
                            local d = S.eggData[egg]
                            d.CustomActive = not d.CustomActive
                            d.CustomColor = C.CustomESPColor
                            btn.Text = d.CustomActive and "ON" or "ESP"
                            btn.BackgroundColor3 = d.CustomActive and C.Success or C.BgHover
                            updateEggESP(egg)
                        end},
                })
            end
        end
        cnt.Text = "Eggs: " .. tostring(#all) .. "  |  Results: " .. tostring(shown)
        if shown == 0 then
            local none = label(scroll, "No eggs found", 11, C.TextDim, Enum.Font.GothamItalic)
            none.Size = UDim2.new(1, -8, 0, 30)
        end
    end
    UI.refs.refresh_Eggs = refreshEggList
end

--==================================================
-- [21] TAB: MISC
--==================================================
do
    local content = UI.tabs.Misc.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 1, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = content

    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -8, 0, 220)
    gl.CellPadding = UDim2.new(0, 16, 0, 16)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    -- Misc toggles
    local c1, b1 = makeCard(grid, "✨   Misc", "Extra features",
        UDim2.new(1,0,1,0), nil, 1)
    makeToggle(b1, "Auto Sell", false, 1, function(v) S.autoSell = v end)
    makeToggle(b1, "Auto Collect Rewards", false, 2, function(v) S.autoCollectRewards = v end)
    makeToggle(b1, "Show Damage", false, 3, function(v) S.showDamage = v end)

    -- UI size
    local c2, b2 = makeCard(grid, "🖥   UI Size", "Adjust menu size for your device",
        UDim2.new(1,0,1,0), nil, 2)
    makeButton(b2, "📱  Mobile", "primary",
        UDim2.new(1, 0, 0, 36), nil, function()
            S.deviceMode = "Mobile"
        end)
    makeButton(b2, "💻  PC", "default",
        UDim2.new(1, 0, 0, 36), nil, function()
            S.deviceMode = "PC"
        end)
end

--==================================================
-- [22] TAB: SETTINGS
--==================================================
do
    local content = UI.tabs.Settings.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = content

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, 0, 1, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = content

    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -8, 0, 220)
    gl.CellPadding = UDim2.new(0, 16, 0, 16)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = grid

    -- Keybind
    local c1, b1 = makeCard(grid, "⌨   Keybind", "TP Home hotkey",
        UDim2.new(1,0,1,0), nil, 1)
    local kbBtn = makeButton(b1, "Key: [" .. S.tpKeybind.Name .. "]", "default",
        UDim2.new(1, 0, 0, 34), nil, function(b)
            S.listeningForKey = true
            b.Text = "Press a key..."
        end)
    UI.refs.keybindBtn = kbBtn

    -- Info / credits
    local c2, b2 = makeCard(grid, "ℹ   Credits", "EGOY project",
        UDim2.new(1,0,1,0), nil, 2)
    local cred = label(b2, "• Script by EGOY\n• Ride A Pet Eggs ESP\n• Auto Farm & Teleports\n• Community Edition", 11, C.TextGray, Enum.Font.Gotham)
    cred.Size = UDim2.new(1, 0, 1, 0)
    cred.TextYAlignment = Enum.TextYAlignment.Top
end

--==================================================
-- [23] HEADER INTERACTIONS
--==================================================
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
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
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local d = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

minBtn.MouseButton1Click:Connect(function()
    S.isMinimized = not S.isMinimized
    if S.isMinimized then
        MainFrame.Visible = false
        FloatingBtn.Visible = true
    else
        MainFrame.Visible = true
        FloatingBtn.Visible = false
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    pcall(function() ScreenGui:Destroy() end)
end)

--==================================================
-- [24] KEYBIND LISTENER
--==================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if S.listeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            S.tpKeybind = input.KeyCode
            S.listeningForKey = false
            if UI.refs.keybindBtn then
                UI.refs.keybindBtn.Text = "Key: [" .. S.tpKeybind.Name .. "]"
            end
        end
        return
    end
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == S.tpKeybind then
            teleportToHomePlot()
        end
    end
end)

--==================================================
-- [25] AUTO UPDATERS
--==================================================
task.spawn(function()
    while ScreenGui.Parent do
        if S.mainESPActive then
            for egg, data in pairs(S.eggData) do
                if egg and egg.Parent and data.NameBillboard and data.NameBillboard.Enabled then
                    updateEggLabel(egg)
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Refresh visible list periodically
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1.5)
        if S.activeTab == "Eggs" and UI.refs.refresh_Eggs then
            pcall(UI.refs.refresh_Eggs)
        elseif S.activeTab == "ESP" and UI.refs.refresh_ESP then
            pcall(UI.refs.refresh_ESP)
        elseif S.activeTab == "Teleports" and UI.refs.refresh_Teleports then
            pcall(UI.refs.refresh_Teleports)
        end
    end
end)

--==================================================
-- [26] WATCH EGG CHANGES
--==================================================
if RenderedEggsFolder then
    RenderedEggsFolder.ChildAdded:Connect(function(egg)
        S.autoFarmProcessed[egg] = nil
        task.wait(0.05)
        updateEggESP(egg)
    end)
    RenderedEggsFolder.ChildRemoved:Connect(function(egg)
        removeEggData(egg)
    end)
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        updateEggESP(egg)
    end
end

--==================================================
-- [27] BOOT
--==================================================
switchTab("Home")
print("[EGOY] Loaded successfully. By EGOY 👑")