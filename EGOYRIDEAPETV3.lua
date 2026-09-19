--[[
    ═══════════════════════════════════════════════════════
    EGOY • RIDE A PET — Auto Farm & ESP  (v3.2 Ultra Mobile)
    By EGOY
    ═══════════════════════════════════════════════════════
]]

--==================================================
-- SERVICES
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

--==================================================
-- CONFIG (ULTRA COMPACT)
--==================================================
local C = {
    BgMain     = Color3.fromRGB(10, 6, 22),
    BgPanel    = Color3.fromRGB(14, 8, 30),
    BgCard     = Color3.fromRGB(22, 13, 44),
    BgCardAlt  = Color3.fromRGB(30, 18, 58),
    BgHover    = Color3.fromRGB(45, 26, 78),
    BgInput    = Color3.fromRGB(16, 10, 34),

    BorderMain = Color3.fromRGB(139, 63, 245),
    BorderCard = Color3.fromRGB(62, 36, 112),

    Accent      = Color3.fromRGB(147, 51, 234),
    AccentLight = Color3.fromRGB(185, 128, 255),
    AccentDeep  = Color3.fromRGB(109, 40, 217),

    TextWhite   = Color3.fromRGB(240, 235, 255),
    TextGray    = Color3.fromRGB(170, 160, 200),
    TextDim     = Color3.fromRGB(115, 105, 145),

    Success = Color3.fromRGB(34, 197, 94),
    Danger  = Color3.fromRGB(225, 60, 80),
    ToggleOn  = Color3.fromRGB(147, 51, 234),
    ToggleOff = Color3.fromRGB(55, 45, 85),

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

    DesignW = 270, DesignH = 400,
    HeaderH = 30, TabBarH = 26, FooterH = 16,
    AnimTime = 0.12,
}

--==================================================
-- STATE
--==================================================
local S = {
    mainESPActive = false, espPlayers = false, espPets = false,
    espChests = false, espItems = false, eggData = {},
    autoBestEggActive = false, autoBestEggThread = nil,
    autoFarmActive = false, autoFarmThread = nil,
    autoFarmEggs = {}, autoFarmProcessed = {},
    autoRebirthActive = false, autoRebirthThread = nil, autoRebirthDelay = 5,
    autoSell = false, autoCollectRewards = false, showDamage = false,
    movementMode = "AutoFarm",
    movementActive = false, movementHumanoid = nil, movementPartsState = nil,
    tpKeybind = Enum.KeyCode.T, listeningForKey = false,
    currentSearchQuery = "", sortMode = "Name",
    activeTab = "Home", isMinimized = false,
}
local UI = { tabs = {}, refs = {} }

--==================================================
-- GAME HELPERS
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
    local r = getRootPart(); local cf = getTargetCFrame(t)
    if not r or not cf then return math.huge end
    return (r.Position - cf.Position).Magnitude
end
local function getEggImage(n)
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return "" end
    local m = pg:FindFirstChild("Main")
    local i = m and m:FindFirstChild("Index")
    local h = i and i:FindFirstChild("Holders")
    local e = h and h:FindFirstChild("EggsHolder"); if not e then return "" end
    local f = e:FindFirstChild(n); if not f then return "" end
    local im = f:FindFirstChild("ImageLabel")
    return (im and im:IsA("ImageLabel") and im.Image) or ""
end
local function tween(o, p, d)
    if not o or not o.Parent then return end
    TweenService:Create(o, TweenInfo.new(d or C.AnimTime, Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out), p):Play()
end

--==================================================
-- ESP
--==================================================
local function createEggLabel(egg)
    local d = S.eggData[egg]
    if not d or (d.NameBillboard and d.NameBillboard.Parent) then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
    bb.MaxDistance = 2000; bb.Enabled = false; bb.Parent = egg
    local n = Instance.new("TextLabel")
    n.Name = "EggName"; n.Size = UDim2.new(1, 0, 0, 18)
    n.BackgroundTransparency = 1; n.Text = egg.Name
    n.TextColor3 = Color3.fromRGB(255,255,255)
    n.TextStrokeTransparency = 0.35; n.TextSize = 11
    n.Font = Enum.Font.GothamBold; n.Parent = bb
    local ds = Instance.new("TextLabel")
    ds.Name = "Distance"; ds.Size = UDim2.new(1, 0, 0, 14)
    ds.Position = UDim2.new(0, 0, 0, 18); ds.BackgroundTransparency = 1
    ds.TextColor3 = Color3.fromRGB(210,210,210)
    ds.TextStrokeTransparency = 0.4; ds.TextSize = 9
    ds.Font = Enum.Font.Gotham; ds.Parent = bb
    d.NameBillboard = bb
end
local function updateEggLabel(egg)
    local d = S.eggData[egg]
    if not d or not d.NameBillboard or not d.NameBillboard.Parent then return end
    local bb = d.NameBillboard
    local n = bb:FindFirstChild("EggName"); local ds = bb:FindFirstChild("Distance")
    if n then n.Text = egg.Name end
    if ds then
        local dd = getDistanceToTarget(egg)
        ds.Text = (dd == math.huge) and "?" or string.format("%dm", math.floor(dd + 0.5))
    end
end
local function updateEggESP(egg)
    if not egg or not (egg:IsA("Model") or egg:IsA("BasePart")) then return end
    if not S.eggData[egg] then
        S.eggData[egg] = {Highlight=nil, NameBillboard=nil,
            CustomColor = C.CustomESPColor, CustomActive = false}
    end
    local d = S.eggData[egg]
    local show, color = false, C.GlobalESPColor
    if d.CustomActive then show, color = true, d.CustomColor
    elseif S.mainESPActive then show, color = true, C.GlobalESPColor end
    if show then
        if not d.Highlight or not d.Highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Adornee = egg
            hl.FillTransparency = C.ESPFillTransparency
            hl.OutlineTransparency = C.ESPOutlineTransparency
            hl.Parent = egg; d.Highlight = hl
        end
        d.Highlight.FillColor = color; d.Highlight.OutlineColor = color
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
    for _, e in ipairs(RenderedEggsFolder:GetChildren()) do updateEggESP(e) end
end
local function removeEggData(egg)
    local d = S.eggData[egg]; if not d then return end
    if d.Highlight then d.Highlight:Destroy() end
    if d.NameBillboard then d.NameBillboard:Destroy() end
    S.eggData[egg] = nil
end

--==================================================
-- MOVEMENT
--==================================================
local function teleportToModel(target)
    local r = getRootPart(); if not r then return false end
    local cf = getTargetCFrame(target); if not cf then return false end
    r.CFrame = cf * CFrame.new(0, C.TPHeight, 0); return true
end
local function setNoclip(en)
    local ch = getCharacter(); if not ch then return end
    if en then
        S.movementPartsState = {}
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                S.movementPartsState[p] = p.CanCollide; p.CanCollide = false
            end
        end
    elseif S.movementPartsState then
        for p, o in pairs(S.movementPartsState) do
            if p and p.Parent then p.CanCollide = o end
        end
        S.movementPartsState = nil
    end
end
local function moveToModel(target)
    if S.movementMode == "Teleport" then return teleportToModel(target) end
    if S.movementActive then return false end
    local ch = getCharacter(); local root = getRootPart()
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local cf = getTargetCFrame(target)
    if not root or not hum or not cf then return false end
    local dest = cf.Position + Vector3.new(0, C.TPHeight, 0)
    local sd = (root.Position - dest).Magnitude
    if sd <= 2 then root.CFrame = cf * CFrame.new(0, C.TPHeight, 0); return true end
    S.movementActive = true; S.movementHumanoid = hum
    local oldRot = hum.AutoRotate; local ok = false
    local t0 = os.clock(); local mx = math.max(3, sd / C.MovementSpeed + 2)
    setNoclip(true); hum.AutoRotate = false
    while S.movementActive and (os.clock() - t0) <= mx do
        if not target or not target.Parent then break end
        if getRootPart() ~= root then break end
        local off = dest - root.Position; local d = off.Magnitude
        if d <= 2 then root.CFrame = cf * CFrame.new(0, C.TPHeight, 0); ok = true; break end
        local dt = RunService.Heartbeat:Wait()
        root.CFrame = root.CFrame + off.Unit * math.min(d, C.MovementSpeed * dt)
    end
    S.movementActive = false
    if hum.Parent then hum.AutoRotate = oldRot end
    S.movementHumanoid = nil; setNoclip(false); return ok
end
local function stopMovement()
    S.movementActive = false
    if S.movementHumanoid and S.movementHumanoid.Parent then
        S.movementHumanoid.AutoRotate = true
    end
    S.movementHumanoid = nil; setNoclip(false)
end
local function teleportToHomePlot()
    local p = Workspace:FindFirstChild("Plots"); if not p then return false end
    for _, plot in ipairs(p:GetChildren()) do
        local d = plot:FindFirstChild("Data")
        if d then
            local o = d:FindFirstChild("Owner")
            if o then
                local own
                if o:IsA("StringValue") then own = o.Value == LocalPlayer.Name
                elseif o:IsA("ObjectValue") then own = o.Value == LocalPlayer
                else own = tostring(o.Value) == LocalPlayer.Name end
                if own then return moveToModel(plot) end
            end
        end
    end
    return false
end

--==================================================
-- AUTO FARM
--==================================================
local function holdEKey(dur)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(dur)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
local function findBestEgg()
    if not RenderedEggsFolder then return nil end
    for _, e in ipairs(RenderedEggsFolder:GetChildren()) do
        if string.find(e.Name:lower(), C.BestEggName:lower(), 1, true) then return e end
    end
    return nil
end
local function stopAutoBestEgg()
    S.autoBestEggActive = false; stopMovement()
    if S.autoBestEggThread then task.cancel(S.autoBestEggThread); S.autoBestEggThread = nil end
end
local function startAutoBestEgg()
    stopAutoBestEgg(); S.autoBestEggActive = true
    S.autoBestEggThread = task.spawn(function()
        while S.autoBestEggActive do
            local egg = findBestEgg()
            if egg and egg.Parent then
                if moveToModel(egg) then
                    task.wait(0.3)
                    if S.autoBestEggActive and egg.Parent then holdEKey(C.AutoEggHoldTime) end
                    task.wait(0.2)
                    if S.autoBestEggActive then teleportToHomePlot() end
                    task.wait(C.AutoEggDelay)
                end
            else task.wait(0.5) end
        end
    end)
end
local function isValidEgg(e)
    return e and e.Parent == RenderedEggsFolder and (e:IsA("Model") or e:IsA("BasePart"))
end
local function getAutoFarmEggs()
    local f = {}; if not RenderedEggsFolder then return f end
    for _, e in ipairs(RenderedEggsFolder:GetChildren()) do
        if isValidEgg(e) and S.autoFarmEggs[e.Name] and not S.autoFarmProcessed[e] then
            table.insert(f, e)
        end
    end
    table.sort(f, function(a,b) return a.Name:lower() < b.Name:lower() end)
    return f
end
local function stopAutoFarm()
    S.autoFarmActive = false; stopMovement()
    if S.autoFarmThread then task.cancel(S.autoFarmThread); S.autoFarmThread = nil end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
local function startAutoFarm()
    stopAutoFarm(); S.autoFarmActive = true
    S.autoFarmThread = task.spawn(function()
        while S.autoFarmActive do
            local eggs = getAutoFarmEggs()
            if #eggs == 0 then S.autoFarmActive = false; S.autoFarmThread = nil; break end
            local worked = false
            for _, egg in ipairs(eggs) do
                if not S.autoFarmActive then break end
                if isValidEgg(egg) and not S.autoFarmProcessed[egg] then
                    worked = true
                    if moveToModel(egg) and S.autoFarmActive then
                        task.wait(0.3)
                        if S.autoFarmActive and isValidEgg(egg) then holdEKey(C.AutoFarmHoldTime) end
                        if S.autoFarmActive then task.wait(0.2); teleportToHomePlot() end
                        S.autoFarmProcessed[egg] = true; task.wait(0.2)
                    end
                end
            end
            if not worked then S.autoFarmActive = false; S.autoFarmThread = nil; break end
            task.wait(0.2)
        end
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end
local function stopAutoRebirth()
    S.autoRebirthActive = false
    if S.autoRebirthThread then task.cancel(S.autoRebirthThread); S.autoRebirthThread = nil end
end
local function startAutoRebirth()
    stopAutoRebirth(); S.autoRebirthActive = true
    S.autoRebirthThread = task.spawn(function()
        while S.autoRebirthActive do
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                local btn = pg and pg:FindFirstChild("RebirthButton", true)
                if btn and btn:IsA("GuiButton") then
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true, game, 0)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false, game, 0)
                end
            end)
            task.wait(S.autoRebirthDelay)
        end
    end)
end

--==================================================
-- UI BUILDERS (MICRO)
--==================================================
local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 5); c.Parent = p
end
local function stroke(p, col, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.BorderCard; s.Thickness = t or 1
    s.Transparency = tr or 0; s.Parent = p
end
local function label(p, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = text or ""
    l.TextSize = size or 9; l.TextColor3 = color or C.TextWhite
    l.Font = font or Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = p
    return l
end
local function makeCard(parent, title, height, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 60)
    card.BackgroundColor3 = C.BgCard; card.BorderSizePixel = 0
    card.LayoutOrder = order or 0; card.Parent = parent
    corner(card, 6); stroke(card, C.BorderCard, 1, 0.55)
    local tl = label(card, title, 9, C.TextWhite, Enum.Font.GothamBold)
    tl.Size = UDim2.new(1, -12, 0, 12); tl.Position = UDim2.new(0, 8, 0, 4)
    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -12, 1, -20)
    body.Position = UDim2.new(0, 6, 0, 18)
    body.Parent = card
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 3); ll.Parent = body
    return card, body
end
local function makeToggle(parent, text, initial, order, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 16); row.BackgroundTransparency = 1
    row.LayoutOrder = order or 0; row.Parent = parent
    local l = label(row, text, 8, C.TextWhite, Enum.Font.GothamMedium)
    l.Size = UDim2.new(1, -40, 1, 0)
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 28, 0, 14)
    track.Position = UDim2.new(1, -28, 0.5, -7)
    track.BackgroundColor3 = initial and C.ToggleOn or C.ToggleOff
    track.Text = ""; track.AutoButtonColor = false; track.BorderSizePixel = 0
    track.Parent = row; corner(track, 7)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = initial and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0; knob.Parent = track; corner(knob, 5)
    local state = initial
    local function set(v, fire)
        state = v
        tween(track, {BackgroundColor3 = state and C.ToggleOn or C.ToggleOff}, 0.12)
        tween(knob, {Position = state and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)}, 0.12)
        if fire and callback then callback(state) end
    end
    track.MouseButton1Click:Connect(function() set(not state, true) end)
    return { setState = set, getState = function() return state end }
end
local function makeButton(parent, text, style, height, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, height or 20)
    b.Text = text; b.TextColor3 = C.TextWhite; b.TextSize = 8
    b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false
    b.BorderSizePixel = 0; b.Parent = parent; corner(b, 5)
    if style == "primary" then
        b.BackgroundColor3 = C.Accent
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(C.AccentDeep, C.AccentLight); g.Parent = b
    elseif style == "danger" then b.BackgroundColor3 = C.Danger
    elseif style == "success" then b.BackgroundColor3 = C.Success
    else b.BackgroundColor3 = C.BgCardAlt; stroke(b, C.BorderCard, 1, 0.4) end
    b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.15}, 0.1) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0}, 0.1) end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end
local function makeInput(parent, placeholder, initial, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 18); box.BackgroundColor3 = C.BgInput
    box.BorderSizePixel = 0; box.Text = tostring(initial or "")
    box.PlaceholderText = placeholder or ""; box.PlaceholderColor3 = C.TextDim
    box.TextColor3 = C.TextWhite; box.TextSize = 8
    box.Font = Enum.Font.GothamMedium
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false; box.Parent = parent
    corner(box, 5); stroke(box, C.BorderCard, 1, 0.55)
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 6); pad.Parent = box
    box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
    return box
end
local function makeScroll(parent)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, 0); s.BackgroundTransparency = 1
    s.BorderSizePixel = 0; s.ScrollBarThickness = 2
    s.ScrollBarImageColor3 = C.Accent
    s.CanvasSize = UDim2.new(0, 0, 0, 0); s.Parent = parent
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 2); ll.Parent = s
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        s.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 4)
    end)
    return s
end
local function getEggList()
    local l = {}; if not RenderedEggsFolder then return l end
    for _, e in ipairs(RenderedEggsFolder:GetChildren()) do
        if e:IsA("Model") or e:IsA("BasePart") then table.insert(l, e) end
    end
    table.sort(l, function(a,b)
        if S.sortMode == "Distance" then
            return getDistanceToTarget(a) < getDistanceToTarget(b)
        end
        return a.Name:lower() < b.Name:lower()
    end)
    return l
end
local function clearList(s)
    for _, ch in ipairs(s:GetChildren()) do
        if not ch:IsA("UIListLayout") then ch:Destroy() end
    end
end
local function buildEggRow(parent, egg, actions)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 20)
    row.BackgroundColor3 = C.BgCardAlt
    row.BackgroundTransparency = 0.4; row.BorderSizePixel = 0
    row.Parent = parent; corner(row, 4); stroke(row, C.BorderCard, 1, 0.75)
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 16, 0, 16)
    icon.Position = UDim2.new(0, 2, 0.5, -8)
    icon.BackgroundTransparency = 1; icon.Image = getEggImage(egg.Name)
    icon.ScaleType = Enum.ScaleType.Fit; icon.Parent = row
    local n = #actions; local area = n * 26
    local dd = getDistanceToTarget(egg)
    local ds = (dd ~= math.huge) and string.format(" (%dm)", math.floor(dd + 0.5)) or ""
    local nl = label(row, egg.Name .. ds, 8, C.TextWhite, Enum.Font.GothamMedium)
    nl.Size = UDim2.new(1, -(28 + area), 1, 0)
    nl.Position = UDim2.new(0, 22, 0, 0)
    nl.TextTruncate = Enum.TextTruncate.AtEnd
    for i, act in ipairs(actions) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 24, 0, 14)
        b.Position = UDim2.new(1, -2 - (n - i) * 26 - 24, 0.5, -7)
        b.BackgroundColor3 = act.color or C.BgHover
        b.Text = act.text; b.TextColor3 = C.TextWhite
        b.TextSize = 7; b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false; b.BorderSizePixel = 0
        b.Parent = row; corner(b, 4)
        b.MouseButton1Click:Connect(function() if act.cb then act.cb(b) end end)
    end
    return row
end

--==================================================
-- CLEANUP
--==================================================
for _, name in ipairs({"EGOY_Menu","EGOY_RIDE_A_PET_Menu","RenderedEggsESP_Menu"}) do
    pcall(function()
        local o = TargetParent:FindFirstChild(name)
        if o then o:Destroy() end
    end)
end

--==================================================
-- ROOT
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
MainFrame.BorderSizePixel = 0; MainFrame.Active = true
MainFrame.Parent = ScreenGui
corner(MainFrame, 8)
stroke(MainFrame, C.BorderMain, 1.5, 0.2)

-- Fit to screen
local cam = Workspace.CurrentCamera
local function applyScale()
    if not cam then return end
    local v = cam.ViewportSize
    local s = math.min(v.X / (C.DesignW + 20), v.Y / (C.DesignH + 20), 1)
    local sc = MainFrame:FindFirstChildOfClass("UIScale")
    if not sc then sc = Instance.new("UIScale"); sc.Parent = MainFrame end
    sc.Scale = s
end
applyScale()
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale) end

-- Floating reopen
local FBtn = Instance.new("TextButton")
FBtn.Size = UDim2.new(0, 36, 0, 36)
FBtn.Position = UDim2.new(0, 10, 0, 90)
FBtn.BackgroundColor3 = C.Accent
FBtn.Text = "👑"; FBtn.TextSize = 16
FBtn.TextColor3 = C.TextWhite; FBtn.Font = Enum.Font.GothamBold
FBtn.AutoButtonColor = false; FBtn.Visible = false
FBtn.ZIndex = 100; FBtn.Parent = ScreenGui
corner(FBtn, 18)
FBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true; FBtn.Visible = false
end)

--==================================================
-- HEADER
--==================================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, C.HeaderH)
Header.BackgroundColor3 = C.BgMain
Header.BorderSizePixel = 0; Header.Active = true
Header.Parent = MainFrame; corner(Header, 8)

local hFix = Instance.new("Frame")
hFix.Size = UDim2.new(1, 0, 0, 6)
hFix.Position = UDim2.new(0, 0, 1, -6)
hFix.BackgroundColor3 = C.BgMain; hFix.BorderSizePixel = 0
hFix.ZIndex = 0; hFix.Parent = Header

local crown = label(Header, "👑", 14, C.AccentLight, Enum.Font.GothamBold)
crown.Size = UDim2.new(0, 22, 1, 0); crown.Position = UDim2.new(0, 4, 0, 0)
crown.TextXAlignment = Enum.TextXAlignment.Center

local logoLbl = label(Header, "EGOY", 13, C.TextWhite, Enum.Font.GothamBlack)
logoLbl.Size = UDim2.new(0, 70, 0, 16); logoLbl.Position = UDim2.new(0, 28, 0, 2)
local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new(C.AccentLight, Color3.fromRGB(255, 200, 255))
logoGrad.Parent = logoLbl

local subLbl = label(Header, "RIDE A PET • By EGOY", 6, C.TextGray, Enum.Font.GothamBold)
subLbl.Size = UDim2.new(1, -110, 0, 8); subLbl.Position = UDim2.new(0, 30, 0, 18)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 18, 0, 18)
minBtn.Position = UDim2.new(1, -42, 0, 6)
minBtn.BackgroundColor3 = C.BgCardAlt
minBtn.Text = "—"; minBtn.TextColor3 = C.TextWhite
minBtn.TextSize = 10; minBtn.Font = Enum.Font.GothamBold
minBtn.AutoButtonColor = false; minBtn.BorderSizePixel = 0
minBtn.Parent = Header; corner(minBtn, 5); stroke(minBtn, C.BorderCard, 1, 0.5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 18, 0, 18)
closeBtn.Position = UDim2.new(1, -22, 0, 6)
closeBtn.BackgroundColor3 = C.BgCardAlt
closeBtn.Text = "✕"; closeBtn.TextColor3 = C.TextWhite
closeBtn.TextSize = 9; closeBtn.Font = Enum.Font.GothamBold
closeBtn.AutoButtonColor = false; closeBtn.BorderSizePixel = 0
closeBtn.Parent = Header; corner(closeBtn, 5); stroke(closeBtn, C.BorderCard, 1, 0.5)

--==================================================
-- TAB BAR (horizontal scroll)
--==================================================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, C.TabBarH)
TabBar.Position = UDim2.new(0, 0, 0, C.HeaderH)
TabBar.BackgroundColor3 = C.BgPanel
TabBar.BorderSizePixel = 0; TabBar.Parent = MainFrame

local tabDiv = Instance.new("Frame")
tabDiv.Size = UDim2.new(1, 0, 0, 1)
tabDiv.Position = UDim2.new(0, 0, 1, -1)
tabDiv.BackgroundColor3 = C.BorderCard; tabDiv.BorderSizePixel = 0
tabDiv.Parent = TabBar

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size = UDim2.new(1, -6, 1, 0)
TabScroll.Position = UDim2.new(0, 3, 0, 0)
TabScroll.BackgroundTransparency = 1; TabScroll.BorderSizePixel = 0
TabScroll.ScrollBarThickness = 0
TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
TabScroll.CanvasSize = UDim2.new(0, 0, 1, 0)
TabScroll.Parent = TabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 2)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = TabScroll
tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabScroll.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X + 6, 1, 0)
end)

--==================================================
-- CONTENT + FOOTER
--==================================================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, 0, 1, -(C.HeaderH + C.TabBarH + C.FooterH))
ContentArea.Position = UDim2.new(0, 0, 0, C.HeaderH + C.TabBarH)
ContentArea.BackgroundColor3 = C.BgMain
ContentArea.BorderSizePixel = 0; ContentArea.Parent = MainFrame

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, 0, 0, C.FooterH)
Footer.Position = UDim2.new(0, 0, 1, -C.FooterH)
Footer.BackgroundColor3 = C.BgPanel; Footer.BorderSizePixel = 0
Footer.Parent = MainFrame; corner(Footer, 8)

local fDiv = Instance.new("Frame")
fDiv.Size = UDim2.new(1, 0, 0, 1); fDiv.BackgroundColor3 = C.BorderCard
fDiv.BorderSizePixel = 0; fDiv.Parent = Footer

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 5, 0, 5)
dot.Position = UDim2.new(0, 6, 0.5, -2.5)
dot.BackgroundColor3 = C.Success; dot.BorderSizePixel = 0
dot.Parent = Footer; corner(dot, 3)

local statusFooter = label(Footer, "Menu Loaded", 7, C.TextGray, Enum.Font.GothamMedium)
statusFooter.Size = UDim2.new(0, 100, 1, 0)
statusFooter.Position = UDim2.new(0, 14, 0, 0)

local madeLbl = label(Footer, "♛ EGOY", 7, C.TextDim, Enum.Font.GothamMedium)
madeLbl.Size = UDim2.new(0, 80, 1, 0)
madeLbl.Position = UDim2.new(1, -84, 0, 0)
madeLbl.TextXAlignment = Enum.TextXAlignment.Right

--==================================================
-- TABS
--==================================================
local tabsOrder = {
    { id = "Home",      icon = "🏠", short = "Home" },
    { id = "ESP",       icon = "👁", short = "ESP" },
    { id = "AutoFarm",  icon = "⚙",  short = "Farm" },
    { id = "Teleports", icon = "📍", short = "TP" },
    { id = "Eggs",      icon = "🥚", short = "Eggs" },
    { id = "Misc",      icon = "✨", short = "Misc" },
    { id = "Settings",  icon = "🛠", short = "Set" },
}
for i, tab in ipairs(tabsOrder) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. tab.id
    btn.Size = UDim2.new(0, 44, 0, 20)
    btn.BackgroundColor3 = C.BgPanel; btn.BackgroundTransparency = 1
    btn.Text = ""; btn.AutoButtonColor = false
    btn.BorderSizePixel = 0; btn.LayoutOrder = i
    btn.Parent = TabScroll
    corner(btn, 5)
    local ic = label(btn, tab.icon, 10, C.TextGray, Enum.Font.GothamBold)
    ic.Size = UDim2.new(0, 14, 1, 0); ic.Position = UDim2.new(0, 2, 0, 0)
    ic.TextXAlignment = Enum.TextXAlignment.Center
    local nm = label(btn, tab.short, 7, C.TextGray, Enum.Font.GothamMedium)
    nm.Size = UDim2.new(1, -18, 1, 0); nm.Position = UDim2.new(0, 16, 0, 0)
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1; content.Visible = false
    content.Parent = ContentArea
    UI.tabs[tab.id] = { button = btn, content = content, icon = ic, label = nm }
    btn.MouseEnter:Connect(function()
        if S.activeTab ~= tab.id then
            btn.BackgroundTransparency = 0.5; btn.BackgroundColor3 = C.BgHover
        end
    end)
    btn.MouseLeave:Connect(function()
        if S.activeTab ~= tab.id then btn.BackgroundTransparency = 1 end
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

local function tabBody(tabId)
    local content = UI.tabs[tabId].content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = content
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = C.Accent
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.Parent = content
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 4); ll.Parent = scroll
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 6)
    end)
    return scroll
end

--==================================================
-- HOME
--==================================================
do
    local body = tabBody("Home")
    local c1, b1 = makeCard(body, "👁  ESP ALL", 62, 1)
    makeToggle(b1, "Enable ESP All", false, 1, function(v)
        S.mainESPActive = v; updateAllESP()
    end)
    makeToggle(b1, "Players ESP", false, 2, function(v) S.espPlayers = v end)
    makeToggle(b1, "Pets ESP", false, 3, function(v) S.espPets = v end)

    local c2, b2 = makeCard(body, "🥚  AUTO BEST EGG", 50, 2)
    makeToggle(b2, "Enable Auto Best Egg", false, 1, function(v)
        S.autoBestEggActive = v
        if v then startAutoBestEgg() else stopAutoBestEgg() end
    end)
    makeInput(b2, "Best egg name", C.BestEggName, function(t)
        C.BestEggName = (t ~= "" and t) or C.BestEggName
    end)

    local c3, b3 = makeCard(body, "🏠  TP HOME", 42, 3)
    makeButton(b3, "🏠  Teleport Home", "primary", 18, function()
        teleportToHomePlot()
    end)

    local c4, b4 = makeCard(body, "ℹ  INFO", 60, 4)
    local il = label(b4, "• Drag header to move\n• Tap — to minimize\n• 7 tabs available", 7, C.TextGray, Enum.Font.Gotham)
    il.Size = UDim2.new(1, 0, 1, 0); il.TextYAlignment = Enum.TextYAlignment.Top
end

--==================================================
-- ESP
--==================================================
do
    local body = tabBody("ESP")
    local c1, b1 = makeCard(body, "🎯  ESP TARGETS", 95, 1)
    makeToggle(b1, "Players ESP", false, 1, function(v) S.espPlayers = v end)
    makeToggle(b1, "Pets ESP", false, 2, function(v) S.espPets = v end)
    makeToggle(b1, "Eggs ESP", false, 3, function(v)
        S.mainESPActive = v; updateAllESP()
    end)
    makeToggle(b1, "Chests ESP", false, 4, function(v) S.espChests = v end)
    makeToggle(b1, "Items ESP", false, 5, function(v) S.espItems = v end)

    local c2, b2 = makeCard(body, "🥚  INDIVIDUAL EGGS", 200, 2)
    local scroll = makeScroll(b2)
    local function refreshESPList()
        clearList(scroll)
        local eggs = getEggList()
        if #eggs == 0 then
            local n = label(scroll, "No eggs detected", 8, C.TextDim, Enum.Font.GothamItalic)
            n.Size = UDim2.new(1, -4, 0, 16); return
        end
        for _, egg in ipairs(eggs) do
            local isOn = S.eggData[egg] and S.eggData[egg].CustomActive
            buildEggRow(scroll, egg, {
                {text = isOn and "ON" or "ESP",
                    color = isOn and C.Success or C.BgHover,
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
                    end}
            })
        end
    end
    UI.refs.refresh_ESP = refreshESPList
end

--==================================================
-- AUTO FARM
--==================================================
do
    local body = tabBody("AutoFarm")
    local c1, b1 = makeCard(body, "⚙  FARM MODE", 52, 1)
    makeButton(b1, "🚶  AutoFarm Mode", "success", 16, function()
        S.movementMode = "AutoFarm"
    end)
    makeButton(b1, "⚡  Teleport Mode", "default", 16, function()
        S.movementMode = "Teleport"
    end)

    local c2, b2 = makeCard(body, "🛑  STOP", 26, 2)
    makeButton(b2, "🛑  Stop Auto Farm", "danger", 18, function()
        stopAutoFarm()
    end)

    local c3, b3 = makeCard(body, "🔁  AUTO REBIRTH", 52, 3)
    makeToggle(b3, "Auto Rebirth", false, 1, function(v)
        S.autoRebirthActive = v
        if v then startAutoRebirth() else stopAutoRebirth() end
    end)
    makeInput(b3, "Delay (s)", 5, function(t)
        local n = tonumber(t); if n then S.autoRebirthDelay = n end
    end)

    local c4, b4 = makeCard(body, "📋  FARM STATUS", 50, 4)
    local st = label(b4, "Active: false", 8, C.TextGray, Enum.Font.Gotham)
    st.Size = UDim2.new(1, 0, 0, 12)
    local ct = label(b4, "Selected: 0", 8, C.TextGray, Enum.Font.Gotham)
    ct.Size = UDim2.new(1, 0, 0, 12)
    local function upd()
        st.Text = "Active: " .. tostring(S.autoFarmActive)
        local n = 0
        for _ in pairs(S.autoFarmEggs) do n += 1 end
        ct.Text = "Selected: " .. n
    end
    upd()
    makeButton(b4, "🔄  Update", "default", 16, upd)
end

--==================================================
-- TELEPORTS
--==================================================
do
    local body = tabBody("Teleports")
    local c1, b1 = makeCard(body, "📍  QUICK TELEPORTS", 80, 1)
    makeButton(b1, "🏠  Home Plot", "primary", 18, function() teleportToHomePlot() end)
    makeButton(b1, "🚶  Walk Home", "default", 16, function()
        S.movementMode = "AutoFarm"; teleportToHomePlot()
    end)
    makeButton(b1, "⚡  Instant Home", "default", 16, function()
        S.movementMode = "Teleport"; teleportToHomePlot()
    end)

    local c2, b2 = makeCard(body, "🥚  TP TO EGG", 200, 2)
    local scroll = makeScroll(b2)
    local function refreshTP()
        clearList(scroll)
        local eggs = getEggList()
        if #eggs == 0 then
            local n = label(scroll, "No eggs", 8, C.TextDim, Enum.Font.GothamItalic)
            n.Size = UDim2.new(1, -4, 0, 16); return
        end
        for _, egg in ipairs(eggs) do
            buildEggRow(scroll, egg, {
                {text = "TP", color = C.Accent, cb = function() teleportToModel(egg) end}
            })
        end
    end
    UI.refs.refresh_Teleports = refreshTP
end

--==================================================
-- EGGS
--==================================================
do
    local content = UI.tabs.Eggs.content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = content

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 20); top.BackgroundTransparency = 1
    top.Parent = content

    local search = makeInput(top, "🔍 Search...", "", function(t)
        S.currentSearchQuery = t; UI.refs.refresh_Eggs()
    end)
    search.Size = UDim2.new(1, -92, 1, 0); search.Position = UDim2.new(0, 0, 0, 0)

    local sortB = makeButton(top, "Name", "default", 20, function(b)
        if S.sortMode == "Name" then
            S.sortMode = "Distance"; b.Text = "Dist"
        else
            S.sortMode = "Name"; b.Text = "Name"
        end
        UI.refs.refresh_Eggs()
    end)
    sortB.Size = UDim2.new(0, 44, 1, 0); sortB.Position = UDim2.new(1, -90, 0, 0)

    local refreshB = makeButton(top, "🔄", "primary", 20, function()
        UI.refs.refresh_Eggs(); updateAllESP()
    end)
    refreshB.Size = UDim2.new(0, 40, 1, 0); refreshB.Position = UDim2.new(1, -40, 0, 0)

    local cnt = label(content, "Eggs: 0 | Results: 0", 8, C.TextGray, Enum.Font.GothamBold)
    cnt.Size = UDim2.new(1, 0, 0, 12); cnt.Position = UDim2.new(0, 0, 0, 22)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 1, -36)
    holder.Position = UDim2.new(0, 0, 0, 36)
    holder.BackgroundTransparency = 1; holder.Parent = content

    local scroll = makeScroll(holder)
    local function refreshEggs()
        clearList(scroll)
        local all = getEggList()
        local q = S.currentSearchQuery:lower()
        local shown = 0
        for _, egg in ipairs(all) do
            local match = q == "" or string.find(egg.Name:lower(), q, 1, true)
            if match then
                shown += 1
                local farmOn = S.autoFarmEggs[egg.Name] == true
                local espOn = S.eggData[egg] and S.eggData[egg].CustomActive
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
                            if on and not S.autoFarmActive then startAutoFarm() end
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
        cnt.Text = "Eggs: " .. tostring(#all) .. " | Results: " .. tostring(shown)
        if shown == 0 then
            local n = label(scroll, "No eggs found", 8, C.TextDim, Enum.Font.GothamItalic)
            n.Size = UDim2.new(1, -4, 0, 16)
        end
    end
    UI.refs.refresh_Eggs = refreshEggs
end

--==================================================
-- MISC
--==================================================
do
    local body = tabBody("Misc")
    local c1, b1 = makeCard(body, "✨  MISC", 68, 1)
    makeToggle(b1, "Auto Sell", false, 1, function(v) S.autoSell = v end)
    makeToggle(b1, "Auto Collect Rewards", false, 2, function(v) S.autoCollectRewards = v end)
    makeToggle(b1, "Show Damage", false, 3, function(v) S.showDamage = v end)

    local c2, b2 = makeCard(body, "🖥  UI SIZE", 50, 2)
    makeButton(b2, "📱  Mobile", "primary", 16, function() end)
    makeButton(b2, "💻  PC", "default", 16, function() end)
end

--==================================================
-- SETTINGS
--==================================================
do
    local body = tabBody("Settings")
    local c1, b1 = makeCard(body, "⌨  KEYBIND", 40, 1)
    local kbB = makeButton(b1, "Key: [" .. S.tpKeybind.Name .. "]", "default", 18, function(b)
        S.listeningForKey = true; b.Text = "Press a key..."
    end)
    UI.refs.keybindBtn = kbB

    local c2, b2 = makeCard(body, "ℹ  CREDITS", 70, 2)
    local cr = label(b2, "• By EGOY\n• Ride A Pet\n• Auto Farm & ESP\n• Community Edition", 8, C.TextGray, Enum.Font.Gotham)
    cr.Size = UDim2.new(1, 0, 1, 0); cr.TextYAlignment = Enum.TextYAlignment.Top
end

--==================================================
-- DRAG (multi-handle)
--==================================================
local dragging, dragInput, dragStart, startPos
local function beginDrag(input)
    dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end
local function bindDrag(el)
    el.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
end
bindDrag(Header); bindDrag(crown); bindDrag(logoLbl)
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
        MainFrame.Visible = false; FBtn.Visible = true
    else
        MainFrame.Visible = true; FBtn.Visible = false
    end
end)
closeBtn.MouseButton1Click:Connect(function()
    pcall(function() ScreenGui:Destroy() end)
end)

--==================================================
-- KEYBIND
--==================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if S.listeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            S.tpKeybind = input.KeyCode; S.listeningForKey = false
            if UI.refs.keybindBtn then
                UI.refs.keybindBtn.Text = "Key: [" .. S.tpKeybind.Name .. "]"
            end
        end
        return
    end
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == S.tpKeybind then teleportToHomePlot() end
    end
end)

--==================================================
-- UPDATERS
--==================================================
task.spawn(function()
    while ScreenGui.Parent do
        if S.mainESPActive then
            for egg, d in pairs(S.eggData) do
                if egg and egg.Parent and d.NameBillboard and d.NameBillboard.Enabled then
                    updateEggLabel(egg)
                end
            end
        end
        task.wait(0.25)
    end
end)
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
-- WATCH EGGS
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
-- BOOT
--==================================================
switchTab("Home")
print("[EGOY] Ultra Mobile Edition loaded. By EGOY 👑")