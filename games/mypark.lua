-- Extracted from VOR_HUB.lua. The builder receives shared services through context.
return function(context)
    local Window = assert(context.Window, "game module requires Window")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "game module requires CreateCategoryHomePage")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS
    local track = assert(context.Track, "game module requires Track")
    local gui = assert(context.Gui, "game module requires Gui")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")
    local LocalPlayer = Players.LocalPlayer
    local create = assert(context.Create, "game module requires Create")
    local addCorner = assert(context.AddCorner, "game module requires AddCorner")
    local addStroke = assert(context.AddStroke, "game module requires AddStroke")
    local playToggleClick = assert(context.PlayToggleClick, "game module requires PlayToggleClick")
    local SNOW_WHITE = COLORS.white or Color3.fromRGB(232, 228, 242)

local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()

local ShootingPage = addHomeCategory("Shooting", 1, CATEGORY_DECALS.Shooting)
local PlayerPage = addHomeCategory("Player", 2, CATEGORY_DECALS.Player)
local DribblePage = addHomeCategory("Dribble", 3, CATEGORY_DECALS.Dribble)
local ExploitsPage = addHomeCategory("Exploits", 4, CATEGORY_DECALS.Exploits)

local AutoShotSection = ShootingPage:AddSection("Perfect Release", "Left")
local MeterSection = ShootingPage:AddSection("Shot Meter", "Right")
local ShotStatusSection = ShootingPage:AddSection("Live Shot Status", "Right")
local DefenseSection = PlayerPage:AddSection("1v1 Defense Assist", "Left")
local PlayerUtilitySection = PlayerPage:AddSection("Player Utility", "Left")
local ScoringSection = PlayerPage:AddSection("Scoring Assist", "Right")
local CameraSection = PlayerPage:AddSection("Camera", "Right")
local PlayerStatusSection = PlayerPage:AddSection("Live Player Status", "Right")
local DribbleSection = DribblePage:AddSection("Dribble Automation", "Left")
local DribbleStatusSection = DribblePage:AddSection("Live Dribble Status", "Right")
local ExploitStealSection = ExploitsPage:AddSection("Extended Steal", "Left")
local ExploitDefenseSection = ExploitsPage:AddSection("Unfair Defense", "Right")
local ExploitMovementSection = ExploitsPage:AddSection("Ball & Aim Advantages", "Left")
local ExploitStatusSection = ExploitsPage:AddSection("Exploit Status", "Right")

selectHomeCategory("Shooting")

local basketballState = {
    AutoGreen = false,
    AntiAfk = false,
    AutoGuard = false,
    SmartSteal = false,
    SmartBlock = false,
    AutoRebound = false,
    AutoDunk = false,
    AutoCombo = false,
    CourtVision = false,
    RemoteStealAura = false,
    RemoteBlockAura = false,
    LooseBallMagnet = false,
    GoalAimLock = false,
    Calibration = 0.78,
    GuideEnabled = true,
    MeterScale = 1,
    GuardDistance = 22,
    StealDistance = 14,
    BlockDistance = 20,
    BlockReaction = 0.10,
    ReboundDistance = 20,
    ComboDistance = 12,
    ComboInterval = 2.25,
    ComboStyle = "Smart Mix",
    RemoteStealRange = 32,
    RemoteStealInterval = 0.40,
    RemoteBlockRange = 45,
    MagnetRange = 35,
    ReleasedThisShot = false,
    ForceNextShot = false,
    LastMeterValue = 0,
    WasMeterVisible = false,
    MobileShootHeld = false,
    MobileReleaseMethod = "None",
    LastStatusUpdate = 0,
    LastAssistUpdate = 0,
    LastSteal = 0,
    LastBlock = 0,
    LastRebound = 0,
    LastDunk = 0,
    LastCombo = 0,
    LastRemoteSteal = 0,
    LastRemoteBlock = 0,
    LastMagnet = 0,
}

local meterStatusLabel = ShotStatusSection:AddLabel("Meter: Waiting for a shot")
local releaseStatusLabel = ShotStatusSection:AddLabel("Release: Auto Green disabled")
local timingStatusLabel = ShotStatusSection:AddLabel("Target: 78% visual -> approximately 100% server read")
local playerCourtLabel = PlayerStatusSection:AddLabel("Court: Reading...")
local playerBallLabel = PlayerStatusSection:AddLabel("Basketball: Reading...")
local playerModeLabel = PlayerStatusSection:AddLabel("Place: " .. tostring(game.PlaceId))
local antiAfkStatusLabel = PlayerUtilitySection:AddLabel("Anti-AFK: Disabled")
local defenseStatusLabel = DefenseSection:AddLabel("Defense: All assists disabled")
local scoringStatusLabel = ScoringSection:AddLabel("Scoring: Auto Dunk disabled")
local dribbleStatusLabel = DribbleStatusSection:AddLabel("Dribble: Auto Combo disabled")
DribbleStatusSection:AddLabel("Behind Back: current-hand key + X")
DribbleStatusSection:AddLabel("Spin: double current-hand input | Between Legs: double X")
DribbleStatusSection:AddLabel("Smart Mix rotates through every supported combo automatically.")
local exploitStatusLabel = ExploitStatusSection:AddLabel("Exploits: Disabled — every option is opt-in")
ExploitStatusSection:AddLabel("Experimental controls may still be rejected by server-side distance validation.")
ExploitStatusSection:AddLabel("Use the normal Player assists if a remote option is inconsistent.")

local shootingGui = nil
local shootingBar = nil
local releaseGuide = nil
local meterScaleObject = nil
local guardHeld = false
local ballHighlight = nil
local opponentHighlight = nil
local highlightedBall = nil
local highlightedOpponent = nil
local CollectionService = game:GetService("CollectionService")

local controlServiceFolder = ReplicatedStorage:FindFirstChild("Packages")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("Knit")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("Services")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("ControlService")
local controlEvents = controlServiceFolder and controlServiceFolder:FindFirstChild("RE")
local stealRemote = controlEvents and controlEvents:FindFirstChild("Steal")
local blockRemote = controlEvents and controlEvents:FindFirstChild("Block")
local shootMeterStartEvent = controlEvents and controlEvents:FindFirstChild("ShootMeterStart")

local okSharedUtil, BasketballSharedUtil = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SharedUtil"))
end)
if not okSharedUtil then
    BasketballSharedUtil = nil
end

local okBasketballModule, BasketballModule = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Basketball"))
end)
if not okBasketballModule then
    BasketballModule = nil
end

local okInput, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not okInput then
    VirtualInputManager = nil
end

local fallbackVirtualKeys = {
    [Enum.KeyCode.E] = 0x45,
    [Enum.KeyCode.F] = 0x46,
    [Enum.KeyCode.R] = 0x52,
    [Enum.KeyCode.V] = 0x56,
    [Enum.KeyCode.X] = 0x58,
    [Enum.KeyCode.Z] = 0x5A,
    [Enum.KeyCode.C] = 0x43,
    [Enum.KeyCode.Space] = 0x20,
}

local function sendBasketballKey(keyCode, isDown)
    if VirtualInputManager then
        local ok = pcall(function()
            VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
        end)
        if ok then
            return true
        end
    end

    local virtualKey = fallbackVirtualKeys[keyCode]
    if not virtualKey then
        return false
    end
    if isDown and type(keypress) == "function" then
        return pcall(keypress, virtualKey)
    elseif not isDown and type(keyrelease) == "function" then
        return pcall(keyrelease, virtualKey)
    end
    return false
end

local function sendShootKey(isDown)
    return sendBasketballKey(Enum.KeyCode.E, isDown)
end

local function isTouchPrimary()
    if not UserInputService.TouchEnabled then
        return false
    end

    local preferredInput
    pcall(function()
        preferredInput = UserInputService.PreferredInput
    end)

    if preferredInput ~= nil then
        return preferredInput == Enum.PreferredInput.Touch
    end

    return not UserInputService.KeyboardEnabled
end

local activeTouchInputs = {}
local mobileShootButton = nil
local mobileShootTouch = nil
local mobileShootVirtualPress = false
local lastMobileShootScan = 0

local function pointInsideGui(guiObject, point)
    if not guiObject or not guiObject.Parent or not guiObject:IsA("GuiObject") then
        return false
    end

    local position = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return point.X >= position.X
        and point.Y >= position.Y
        and point.X <= position.X + size.X
        and point.Y <= position.Y + size.Y
end

local function isGuiActuallyVisible(guiObject)
    local current = guiObject
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("LayerCollector") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function containsShootWord(value)
    local lowered = string.lower(tostring(value or ""))
    return string.find(lowered, "shoot", 1, true) ~= nil
        or string.find(lowered, "shot", 1, true) ~= nil
        or string.find(lowered, "release", 1, true) ~= nil
end

local function actionInfoUsesShoot(actionName, actionInfo)
    if containsShootWord(actionName) then
        return true
    end

    local function inspect(value, depth)
        if depth > 4 then
            return false
        end
        if value == Enum.KeyCode.E then
            return true
        end
        if type(value) == "string" and containsShootWord(value) then
            return true
        end
        if type(value) == "table" then
            for key, child in pairs(value) do
                if inspect(key, depth + 1) or inspect(child, depth + 1) then
                    return true
                end
            end
        end
        return false
    end

    return inspect(actionInfo, 0)
end

local function scoreShootButton(button)
    if not button:IsA("GuiButton") or not isGuiActuallyVisible(button) then
        return -math.huge
    end
    if gui and button:IsDescendantOf(gui) then
        return -math.huge
    end

    local score = 0
    local signature = button.Name
    if button:IsA("TextButton") then
        signature = signature .. " " .. button.Text
    end

    local ancestor = button.Parent
    for _ = 1, 3 do
        if not ancestor then
            break
        end
        signature = signature .. " " .. ancestor.Name
        ancestor = ancestor.Parent
    end

    if containsShootWord(signature) then
        score += 150
    end

    for attributeName, attributeValue in pairs(button:GetAttributes()) do
        if containsShootWord(attributeName) or containsShootWord(attributeValue) or attributeValue == "E" then
            score += 80
        end
    end

    for _, descendant in ipairs(button:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            if containsShootWord(descendant.Text) then
                score += 110
                break
            end
        end
    end

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    if viewport then
        local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
        if center.X >= viewport.X * 0.52 then
            score += 10
        end
        if center.Y >= viewport.Y * 0.35 then
            score += 8
        end
    end

    if button.AbsoluteSize.X >= 42 and button.AbsoluteSize.Y >= 42 then
        score += 5
    end

    return score
end

local function findMobileShootButton(forceScan)
    if mobileShootButton and mobileShootButton.Parent and isGuiActuallyVisible(mobileShootButton) then
        return mobileShootButton
    end

    local now = os.clock()
    if not forceScan and now - lastMobileShootScan < 0.35 then
        return nil
    end
    lastMobileShootScan = now

    local bestButton = nil
    local bestScore = -math.huge

    -- Games that use ContextActionService normally expose the correct touch
    -- button here. Matching the E binding keeps the desktop control untouched.
    local okActions, actionInfo = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)
    if okActions and type(actionInfo) == "table" then
        for actionName, info in pairs(actionInfo) do
            if actionInfoUsesShoot(actionName, info) then
                local okButton, actionButton = pcall(function()
                    return ContextActionService:GetButton(actionName)
                end)
                if okButton and actionButton and actionButton:IsA("GuiButton")
                    and isGuiActuallyVisible(actionButton) then
                    mobileShootButton = actionButton
                    return actionButton
                end
            end
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, descendant in ipairs(playerGui:GetDescendants()) do
            if descendant:IsA("GuiButton") then
                local score = scoreShootButton(descendant)
                if score > bestScore then
                    bestScore = score
                    bestButton = descendant
                end
            end
        end
    end

    if bestScore >= 100 then
        mobileShootButton = bestButton
    else
        mobileShootButton = nil
    end
    return mobileShootButton
end

local function captureMobileShootTouch()
    if not UserInputService.TouchEnabled then
        return nil, nil
    end

    local button = findMobileShootButton(true)
    if not button then
        return nil, nil
    end

    if mobileShootTouch and activeTouchInputs[mobileShootTouch]
        and pointInsideGui(button, mobileShootTouch.Position) then
        basketballState.MobileShootHeld = true
        return button, mobileShootTouch
    end

    for touch in pairs(activeTouchInputs) do
        if touch.UserInputType == Enum.UserInputType.Touch
            and touch.UserInputState ~= Enum.UserInputState.End
            and touch.UserInputState ~= Enum.UserInputState.Cancel
            and pointInsideGui(button, touch.Position) then
            mobileShootTouch = touch
            basketballState.MobileShootHeld = true
            return button, touch
        end
    end

    return button, nil
end

local function fireInputSignal(signal, ...)
    if not signal then
        return false
    end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, signal, ...)
        if ok then
            return true
        end
    end

    if type(getconnections) == "function" then
        local okConnections, connections = pcall(getconnections, signal)
        if okConnections and type(connections) == "table" then
            local fired = false
            for _, connection in ipairs(connections) do
                local callback
                pcall(function()
                    callback = connection.Function
                end)
                if type(callback) == "function" then
                    local ok = pcall(callback, ...)
                    fired = fired or ok
                end
            end
            return fired
        end
    end

    return false
end

local function releaseMobileShootInput()
    if not UserInputService.TouchEnabled then
        return false, nil
    end

    local button, touch = captureMobileShootTouch()
    if not button then
        return false, nil
    end

    local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
    local released = false
    local methods = {}

    -- Custom mobile controls commonly listen to the button signals directly.
    if touch then
        if fireInputSignal(button.InputEnded, touch) then
            released = true
            table.insert(methods, "Touch")
        end
        if fireInputSignal(UserInputService.TouchEnded, touch, false) then
            released = true
            table.insert(methods, "TouchService")
        end
        if fireInputSignal(UserInputService.InputEnded, touch, false) then
            released = true
            table.insert(methods, "InputService")
        end
    end

    if fireInputSignal(button.MouseButton1Up, center.X, center.Y) then
        released = true
        table.insert(methods, "ButtonUp")
    end

    -- This fallback handles touch buttons implemented through mouse-compatible
    -- GuiButton events. It does not replace the normal E release on PC.
    if VirtualInputManager then
        local okMouse = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                math.floor(center.X),
                math.floor(center.Y),
                0,
                false,
                game,
                0
            )
        end)
        if okMouse then
            released = true
            table.insert(methods, "VirtualButtonUp")
        end
    end

    basketballState.MobileShootHeld = false
    mobileShootTouch = nil
    mobileShootVirtualPress = false

    return released, (#methods > 0 and table.concat(methods, "+") or nil)
end

local function pressMobileShootInput()
    if not UserInputService.TouchEnabled then
        return false
    end

    local button = findMobileShootButton(true)
    if not button then
        return false
    end

    local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
    local pressed = fireInputSignal(button.MouseButton1Down, center.X, center.Y)

    if VirtualInputManager then
        local okMouse = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                math.floor(center.X),
                math.floor(center.Y),
                0,
                true,
                game,
                0
            )
        end)
        pressed = pressed or okMouse
    end

    mobileShootVirtualPress = pressed
    basketballState.MobileShootHeld = pressed
    return pressed
end

local function pressShootInput()
    if isTouchPrimary() and pressMobileShootInput() then
        basketballState.MobileReleaseMethod = "Mobile button"
        return true
    end

    local pressed = sendShootKey(true)
    if pressed then
        basketballState.MobileReleaseMethod = "Keyboard E"
    end
    return pressed
end

local function releaseShootInput()
    local mobileReleased, mobileMethod = false, nil
    if isTouchPrimary() or basketballState.MobileShootHeld or mobileShootTouch then
        mobileReleased, mobileMethod = releaseMobileShootInput()
    end

    -- Always send the desktop release too. On PC this remains the original
    -- behavior; on mobile it is a harmless fallback for executors that map E.
    local keyboardReleased = sendShootKey(false)

    if mobileReleased then
        basketballState.MobileReleaseMethod = mobileMethod or "Mobile touch"
    elseif keyboardReleased then
        basketballState.MobileReleaseMethod = "Keyboard E"
    else
        basketballState.MobileReleaseMethod = "Unsupported"
    end

    return mobileReleased or keyboardReleased, basketballState.MobileReleaseMethod
end

track(UserInputService.TouchStarted:Connect(function(touch)
    activeTouchInputs[touch] = true

    local button = findMobileShootButton(false)
    if button and pointInsideGui(button, touch.Position) then
        mobileShootButton = button
        mobileShootTouch = touch
        basketballState.MobileShootHeld = true
    end
end))

track(UserInputService.TouchEnded:Connect(function(touch)
    activeTouchInputs[touch] = nil
    if touch == mobileShootTouch then
        mobileShootTouch = nil
        basketballState.MobileShootHeld = false
    end
end))

local keyPulseBusy = {}
local function pulseBasketballKey(keyCode, holdTime)
    if keyPulseBusy[keyCode] then
        return false
    end
    keyPulseBusy[keyCode] = true
    task.spawn(function()
        sendBasketballKey(keyCode, true)
        task.wait(holdTime or 0.045)
        sendBasketballKey(keyCode, false)
        keyPulseBusy[keyCode] = nil
    end)
    return true
end

local function updateReleaseGuide()
    if not releaseGuide or not releaseGuide.Parent then
        return
    end
    releaseGuide.Position = UDim2.new(0, 0, 1 - basketballState.Calibration, 0)
    releaseGuide.Visible = basketballState.GuideEnabled
end

local function resolveShotMeter()
    if shootingGui and shootingGui.Parent and shootingBar and shootingBar.Parent then
        return shootingGui, shootingBar
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local visual = playerGui and playerGui:FindFirstChild("Visual")
    local candidate = visual and visual:FindFirstChild("Shooting")
    local bar = candidate and candidate:FindFirstChild("Bar")
    if not candidate or not bar or not candidate:IsA("GuiObject") or not bar:IsA("GuiObject") then
        shootingGui = nil
        shootingBar = nil
        return nil, nil
    end

    shootingGui = candidate
    shootingBar = bar

    meterScaleObject = shootingGui:FindFirstChild("VORMeterScale")
    if not meterScaleObject then
        meterScaleObject = create("UIScale", {
            Name = "VORMeterScale",
            Scale = basketballState.MeterScale,
        }, shootingGui)
    end
    meterScaleObject.Scale = basketballState.MeterScale

    releaseGuide = shootingGui:FindFirstChild("VORReleaseGuide")
    if not releaseGuide then
        releaseGuide = create("Frame", {
            Name = "VORReleaseGuide",
            Size = UDim2.new(1, 8, 0, 3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 1 - basketballState.Calibration, 0),
            BackgroundColor3 = COLORS.toggleOnBright,
            BorderSizePixel = 0,
            ZIndex = math.max(shootingBar.ZIndex + 4, 12),
        }, shootingGui)
        addCorner(releaseGuide, 2)
        addStroke(releaseGuide, SNOW_WHITE, 1, 0.08)
    end
    updateReleaseGuide()
    return shootingGui, shootingBar
end

local function getCharacterRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isSameCourt(player)
    if not player or player == LocalPlayer then
        return false
    end
    local localCourt = LocalPlayer:GetAttribute("Court")
    local otherCourt = player:GetAttribute("Court")
    return localCourt == nil or otherCourt == nil or localCourt == otherCourt
end

local function isOpponent(player)
    if not isSameCourt(player) then
        return false
    end
    local localTeam = LocalPlayer:GetAttribute("Team")
    local otherTeam = player:GetAttribute("Team")
    return localTeam == nil or otherTeam == nil or localTeam ~= otherTeam
end

local function getNearestOpponent(maxDistance, mustHaveBall)
    local root = getCharacterRoot(LocalPlayer)
    if not root then
        return nil, math.huge
    end

    local nearest = nil
    local nearestDistance = tonumber(maxDistance) or math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if isOpponent(player) then
            local otherRoot = getCharacterRoot(player)
            local hasBall = player.Character and player.Character:FindFirstChild("Basketball") ~= nil
            if otherRoot and (not mustHaveBall or hasBall) then
                local distance = (root.Position - otherRoot.Position).Magnitude
                if distance <= nearestDistance then
                    nearest = player
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function getClosestCourtBall(looseOnly)
    local root = getCharacterRoot(LocalPlayer)
    if not root then
        return nil, math.huge
    end

    local nearest = nil
    local nearestDistance = math.huge
    for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
        if ball:IsA("BasePart") and ball:IsDescendantOf(workspace) then
            local loose = ball.Parent == workspace
            if not looseOnly or loose then
                local distance = (root.Position - ball.Position).Magnitude
                if distance < nearestDistance then
                    nearest = ball
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function getCurrentGoal()
    if not BasketballSharedUtil or not BasketballSharedUtil.Ball then
        return nil
    end
    local ok, goal = pcall(function()
        return BasketballSharedUtil.Ball:GetGoal(LocalPlayer)
    end)
    return ok and goal or nil
end

local function horizontalDistance(left, right)
    local delta = left - right
    return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function setGuardHeld(value)
    value = value == true
    if guardHeld == value then
        return
    end
    guardHeld = value
    sendBasketballKey(Enum.KeyCode.F, value)
end

local function destroyHighlight(highlight)
    if highlight and highlight.Parent then
        highlight:Destroy()
    end
end

local function updateCourtVision()
    if not basketballState.CourtVision then
        destroyHighlight(ballHighlight)
        destroyHighlight(opponentHighlight)
        ballHighlight = nil
        opponentHighlight = nil
        highlightedBall = nil
        highlightedOpponent = nil
        return
    end

    local ball = getClosestCourtBall(false)
    local opponent = getNearestOpponent(80, false)
    local opponentCharacter = opponent and opponent.Character

    if ball ~= highlightedBall then
        destroyHighlight(ballHighlight)
        ballHighlight = nil
        highlightedBall = ball
        if ball then
            ballHighlight = create("Highlight", {
                Name = "VORBasketballVision",
                Adornee = ball,
                FillColor = Color3.fromRGB(76, 224, 255),
                FillTransparency = 0.32,
                OutlineColor = SNOW_WHITE,
                OutlineTransparency = 0.02,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, ball)
        end
    end

    if opponentCharacter ~= highlightedOpponent then
        destroyHighlight(opponentHighlight)
        opponentHighlight = nil
        highlightedOpponent = opponentCharacter
        if opponentCharacter then
            opponentHighlight = create("Highlight", {
                Name = "VOROpponentVision",
                Adornee = opponentCharacter,
                FillColor = Color3.fromRGB(255, 92, 118),
                FillTransparency = 0.68,
                OutlineColor = Color3.fromRGB(255, 222, 230),
                OutlineTransparency = 0.06,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, opponentCharacter)
        end
    end
end

local function getBallHand()
    if not BasketballModule then
        return "Right"
    end
    local ok, _, values = pcall(function()
        local object, currentValues = BasketballModule:GetValues()
        return object, currentValues
    end)
    return ok and values and values.Hand or "Right"
end

local function runDribbleSequence(style)
    local handKey = getBallHand() == "Left" and Enum.KeyCode.Z or Enum.KeyCode.C
    local sequence
    if style == "Behind Back" then
        sequence = {handKey, Enum.KeyCode.X}
    elseif style == "Spin" then
        sequence = {handKey, handKey}
    elseif style == "Between Legs" then
        sequence = {Enum.KeyCode.X, Enum.KeyCode.X}
    elseif style == "Stepback" then
        sequence = {Enum.KeyCode.X}
    else
        local choices = {"Behind Back", "Spin", "Between Legs", "Stepback"}
        return runDribbleSequence(choices[math.random(1, #choices)])
    end

    task.spawn(function()
        for _, keyCode in ipairs(sequence) do
            pulseBasketballKey(keyCode, 0.035)
            task.wait(0.085)
        end
    end)
end

local function runBasketballAssists(now)
    if now - basketballState.LastAssistUpdate < 0.05 then
        return
    end
    basketballState.LastAssistUpdate = now

    local character = LocalPlayer.Character
    local root = getCharacterRoot(LocalPlayer)
    if not character or not root then
        setGuardHeld(false)
        return
    end

    local hasBall = character:FindFirstChild("Basketball") ~= nil
    local ballSearchDistance = math.max(
        basketballState.GuardDistance,
        basketballState.StealDistance,
        basketballState.RemoteStealRange
    )
    local ballOpponent, ballOpponentDistance = getNearestOpponent(ballSearchDistance, true)
    local nearestOpponent, nearestOpponentDistance = getNearestOpponent(80, false)
    local guardSuspended = now < (basketballState.GuardResumeAt or 0)
    local remoteStealFired = false

    if basketballState.RemoteStealAura and not hasBall and ballOpponent
        and ballOpponentDistance <= basketballState.RemoteStealRange
        and now - basketballState.LastRemoteSteal >= basketballState.RemoteStealInterval then
        basketballState.LastRemoteSteal = now
        remoteStealFired = true
        if stealRemote and stealRemote:IsA("RemoteEvent") then
            pcall(function()
                stealRemote:FireServer()
            end)
            exploitStatusLabel.Text = string.format(
                "Exploits: Steal Aura fired at %s from %.1f studs",
                ballOpponent.Name,
                ballOpponentDistance
            )
            exploitStatusLabel.TextColor3 = COLORS.success
        else
            exploitStatusLabel.Text = "Exploits: Steal remote was not found"
            exploitStatusLabel.TextColor3 = COLORS.warning
        end
    end

    if not remoteStealFired and basketballState.SmartSteal and not hasBall and ballOpponent
        and ballOpponentDistance <= basketballState.StealDistance
        and now - basketballState.LastSteal >= 4.15 then
        basketballState.LastSteal = now
        basketballState.GuardResumeAt = now + 0.95
        setGuardHeld(false)
        pulseBasketballKey(Enum.KeyCode.R, 0.05)
        defenseStatusLabel.Text = "Defense: Smart steal attempted on " .. ballOpponent.Name
        defenseStatusLabel.TextColor3 = COLORS.success
    elseif basketballState.AutoGuard and not hasBall and ballOpponent and not guardSuspended then
        setGuardHeld(true)
        defenseStatusLabel.Text = string.format("Defense: Guarding %s (%.1f studs)", ballOpponent.Name, ballOpponentDistance)
        defenseStatusLabel.TextColor3 = COLORS.success
    else
        setGuardHeld(false)
    end

    if basketballState.AutoRebound and not hasBall
        and now - basketballState.LastRebound >= 2.25
        and now - basketballState.LastBlock >= 1.10 then
        local looseBall, looseDistance = getClosestCourtBall(true)
        if looseBall and looseBall.Position.Y > 3 and looseDistance <= basketballState.ReboundDistance then
            basketballState.LastRebound = now
            basketballState.GuardResumeAt = now + 1
            setGuardHeld(false)
            pulseBasketballKey(Enum.KeyCode.Space, 0.05)
            defenseStatusLabel.Text = string.format("Defense: Rebound triggered (%.1f studs)", looseDistance)
            defenseStatusLabel.TextColor3 = COLORS.success
        end
    end

    if basketballState.LooseBallMagnet and not hasBall
        and now - basketballState.LastMagnet >= 0.30 then
        local looseBall, looseDistance = getClosestCourtBall(true)
        if looseBall and looseDistance > 3.5 and looseDistance <= basketballState.MagnetRange then
            basketballState.LastMagnet = now
            local targetPosition = looseBall.Position + Vector3.new(0, 2.65, 0)
            local flatLook = Vector3.new(looseBall.Position.X, targetPosition.Y, looseBall.Position.Z)
            root.CFrame = CFrame.lookAt(targetPosition, flatLook + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
            exploitStatusLabel.Text = string.format("Exploits: Loose-ball magnet snapped %.1f studs", looseDistance)
            exploitStatusLabel.TextColor3 = COLORS.success
        end
    end

    if basketballState.GoalAimLock and hasBall then
        local goal = getCurrentGoal()
        if goal and goal:IsA("BasePart") then
            local lookPosition = Vector3.new(goal.Position.X, root.Position.Y, goal.Position.Z)
            if (lookPosition - root.Position).Magnitude > 0.1 then
                root.CFrame = CFrame.lookAt(root.Position, lookPosition)
            end
        end
    end

    if basketballState.AutoDunk and hasBall and now - basketballState.LastDunk >= 4.25 then
        local goal = getCurrentGoal()
        if goal and goal:IsA("BasePart") then
            local distance = horizontalDistance(root.Position, goal.Position)
            local dunkDistanceValue = ReplicatedStorage:FindFirstChild("DunkDistance")
            local dunkDistance = dunkDistanceValue and tonumber(dunkDistanceValue.Value) or 12.5
            if distance > 5 and distance <= dunkDistance and root.AssemblyLinearVelocity.Magnitude > 3 then
                basketballState.LastDunk = now
                pulseBasketballKey(Enum.KeyCode.Space, 0.05)
                scoringStatusLabel.Text = string.format("Scoring: Dunk assist triggered at %.1f studs", distance)
                scoringStatusLabel.TextColor3 = COLORS.success
            end
        end
    end

    if basketballState.AutoCombo and hasBall and nearestOpponent
        and nearestOpponentDistance <= basketballState.ComboDistance
        and now - basketballState.LastCombo >= basketballState.ComboInterval then
        local meter = resolveShotMeter()
        if not meter or not meter.Visible then
            basketballState.LastCombo = now
            runDribbleSequence(basketballState.ComboStyle)
            dribbleStatusLabel.Text = "Dribble: " .. basketballState.ComboStyle .. " used near " .. nearestOpponent.Name
            dribbleStatusLabel.TextColor3 = COLORS.success
        end
    end

    if now - basketballState.LastStatusUpdate < 0.06 then
        updateCourtVision()
    end
end

local autoGreenControl = AutoShotSection:AddToggle({
    Name = "Auto Green Jumpshots",
    Description = "Releases the active PC E key or mobile Shoot touch at the calibrated meter point",
    Default = false,
    Flag = "basketball_auto_green",
    Callback = function(value)
        basketballState.AutoGreen = value
        basketballState.ReleasedThisShot = false
        releaseStatusLabel.Text = value and "Release: Armed for the next shot" or "Release: Auto Green disabled"
        releaseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

AutoShotSection:AddSlider({
    Name = "Release Calibration",
    Min = 0.70,
    Max = 0.88,
    Step = 0.01,
    Default = 0.78,
    Flag = "basketball_release_calibration",
    Callback = function(value)
        basketballState.Calibration = value
        timingStatusLabel.Text = string.format(
            "Target: %.0f%% visual -> approximately 100%% server read",
            value * 100
        )
        updateReleaseGuide()
    end,
})

AutoShotSection:AddLabel("PC: hold E. Mobile: hold the game's Shoot button. VOR releases the active input at the calibrated point. Start at 0.78; adjust only if your connection lands early or late.")

AutoShotSection:AddButton({
    Name = "Test One Perfect Shot",
    Description = "Presses the PC E key or mobile Shoot button, then auto-releases the next detected meter cycle",
    Callback = function()
        playToggleClick(true)
        basketballState.ForceNextShot = true
        basketballState.ReleasedThisShot = false
        releaseStatusLabel.Text = "Release: Test shot armed"
        if not pressShootInput() then
            basketballState.ForceNextShot = false
            releaseStatusLabel.Text = "Release: This executor cannot press E or the mobile Shoot button"
            releaseStatusLabel.TextColor3 = COLORS.warning
            return
        end
        task.delay(1.25, function()
            if basketballState.ForceNextShot then
                basketballState.ForceNextShot = false
                releaseShootInput()
                if releaseStatusLabel.Parent then
                    releaseStatusLabel.Text = "Release: No valid shot meter appeared"
                    releaseStatusLabel.TextColor3 = COLORS.warning
                end
            end
        end)
    end,
})

MeterSection:AddToggle({
    Name = "Release Guide Line",
    Description = "Shows the calibrated trigger point directly on the game's shot meter",
    Default = true,
    Flag = "basketball_release_guide",
    Callback = function(value)
        basketballState.GuideEnabled = value
        resolveShotMeter()
        updateReleaseGuide()
    end,
})

MeterSection:AddSlider({
    Name = "Shot Meter Scale",
    Min = 0.75,
    Max = 1.50,
    Step = 0.05,
    Default = 1,
    Flag = "basketball_meter_scale",
    Callback = function(value)
        basketballState.MeterScale = value
        resolveShotMeter()
        if meterScaleObject and meterScaleObject.Parent then
            meterScaleObject.Scale = value
        end
    end,
})

MeterSection:AddButton({
    Name = "Rescan Shot Meter",
        Description = "Reconnects VOR Hub after the game's UI reloads",
    Callback = function()
        playToggleClick(true)
        shootingGui = nil
        shootingBar = nil
        releaseGuide = nil
        meterScaleObject = nil
        local found = resolveShotMeter() ~= nil
        meterStatusLabel.Text = found and "Meter: Connected" or "Meter: PlayerGui.Visual.Shooting not found"
        meterStatusLabel.TextColor3 = found and COLORS.success or COLORS.warning
    end,
})

local autoGuardControl = DefenseSection:AddToggle({
    Name = "Auto Guard Ball Handler",
    Description = "Holds the game's Guard action while the opposing ball handler is nearby",
    Default = false,
    Flag = "basketball_auto_guard",
    Callback = function(value)
        basketballState.AutoGuard = value
        if not value then
            setGuardHeld(false)
        end
        defenseStatusLabel.Text = value and "Defense: Auto Guard armed" or "Defense: Auto Guard disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Guard Distance",
    Min = 10,
    Max = 25,
    Step = 1,
    Default = 22,
    Flag = "basketball_guard_distance",
    Callback = function(value)
        basketballState.GuardDistance = value
    end,
})

local smartStealControl = DefenseSection:AddToggle({
    Name = "Smart Steal",
    Description = "Drops Guard briefly and uses the normal steal action when the opponent is close",
    Default = false,
    Flag = "basketball_smart_steal",
    Callback = function(value)
        basketballState.SmartSteal = value
        defenseStatusLabel.Text = value and "Defense: Smart Steal armed" or "Defense: Smart Steal disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local stealDistanceControl = DefenseSection:AddSlider({
    Name = "Steal Distance",
    Min = 4,
    Max = 40,
    Step = 0.5,
    Default = 14,
    Flag = "basketball_steal_distance",
    Callback = function(value)
        basketballState.StealDistance = value
    end,
})

local smartBlockControl = DefenseSection:AddToggle({
    Name = "Smart Block",
    Description = "Reacts to the opponent's real ShootMeterStart event and contests with Space",
    Default = false,
    Flag = "basketball_smart_block",
    Callback = function(value)
        basketballState.SmartBlock = value
        defenseStatusLabel.Text = value and "Defense: Smart Block listening for opponent shots" or "Defense: Smart Block disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Block Reaction Delay",
    Min = 0,
    Max = 0.35,
    Step = 0.01,
    Default = 0.10,
    Flag = "basketball_block_reaction",
    Callback = function(value)
        basketballState.BlockReaction = value
    end,
})

DefenseSection:AddSlider({
    Name = "Block Distance",
    Min = 8,
    Max = 25,
    Step = 1,
    Default = 20,
    Flag = "basketball_block_distance",
    Callback = function(value)
        basketballState.BlockDistance = value
    end,
})

local autoReboundControl = DefenseSection:AddToggle({
    Name = "Auto Rebound",
    Description = "Uses the game's normal rebound jump when a loose ball rises nearby",
    Default = false,
    Flag = "basketball_auto_rebound",
    Callback = function(value)
        basketballState.AutoRebound = value
        defenseStatusLabel.Text = value and "Defense: Auto Rebound armed" or "Defense: Auto Rebound disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Rebound Distance",
    Min = 8,
    Max = 25,
    Step = 1,
    Default = 20,
    Flag = "basketball_rebound_distance",
    Callback = function(value)
        basketballState.ReboundDistance = value
    end,
})

local autoDunkControl = ScoringSection:AddToggle({
    Name = "Auto Dunk Assist",
    Description = "Triggers Space only inside the game's live dunk distance while running at the rim",
    Default = false,
    Flag = "basketball_auto_dunk",
    Callback = function(value)
        basketballState.AutoDunk = value
        scoringStatusLabel.Text = value and "Scoring: Auto Dunk armed" or "Scoring: Auto Dunk disabled"
        scoringStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local autoComboControl = DribbleSection:AddToggle({
    Name = "Auto Dribble Combo",
    Description = "Runs the selected legal combo when a defender closes the gap",
    Default = false,
    Flag = "basketball_auto_dribble_combo",
    Callback = function(value)
        basketballState.AutoCombo = value
        dribbleStatusLabel.Text = value and "Dribble: Auto Combo armed" or "Dribble: Auto Combo disabled"
        dribbleStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DribbleSection:AddDropdown({
    Name = "Dribble Combo Style",
    Options = {"Smart Mix", "Behind Back", "Spin", "Between Legs", "Stepback"},
    Default = "Smart Mix",
    Flag = "basketball_dribble_combo_style",
    Callback = function(value)
        basketballState.ComboStyle = value or "Smart Mix"
    end,
})

DribbleSection:AddSlider({
    Name = "Combo Trigger Distance",
    Min = 6,
    Max = 20,
    Step = 1,
    Default = 12,
    Flag = "basketball_combo_distance",
    Callback = function(value)
        basketballState.ComboDistance = value
    end,
})

DribbleSection:AddSlider({
    Name = "Combo Interval",
    Min = 1,
    Max = 5,
    Step = 0.25,
    Default = 2.25,
    Flag = "basketball_combo_interval",
    Callback = function(value)
        basketballState.ComboInterval = value
    end,
})

local courtVisionControl = PlayerUtilitySection:AddToggle({
    Name = "Court Vision ESP",
    Description = "Locally highlights the nearest ball and nearby opponent through visual clutter",
    Default = false,
    Flag = "basketball_court_vision",
    Callback = function(value)
        basketballState.CourtVision = value
        updateCourtVision()
    end,
})

local remoteStealControl = ExploitStealSection:AddToggle({
    Name = "Extended Remote Steal Aura",
    Description = "Fires the Steal remote directly and bypasses the client's four-second action cooldown",
    Default = false,
    Flag = "basketball_exploit_remote_steal",
    Callback = function(value)
        basketballState.RemoteStealAura = value
        exploitStatusLabel.Text = value and "Exploits: Extended Steal Aura armed" or "Exploits: Extended Steal Aura disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitStealSection:AddSlider({
    Name = "Remote Steal Range",
    Min = 10,
    Max = 75,
    Step = 1,
    Default = 32,
    Flag = "basketball_exploit_steal_range",
    Callback = function(value)
        basketballState.RemoteStealRange = value
    end,
})

ExploitStealSection:AddSlider({
    Name = "Remote Steal Interval",
    Min = 0.10,
    Max = 2,
    Step = 0.05,
    Default = 0.40,
    Flag = "basketball_exploit_steal_interval",
    Callback = function(value)
        basketballState.RemoteStealInterval = value
    end,
})

ExploitStealSection:AddButton({
    Name = "Test One Remote Steal",
    Description = "Sends one direct Steal request without enabling the repeating aura",
    Callback = function()
        playToggleClick(true)
        if stealRemote and stealRemote:IsA("RemoteEvent") then
            pcall(function()
                stealRemote:FireServer()
            end)
            exploitStatusLabel.Text = "Exploits: One remote Steal request sent"
            exploitStatusLabel.TextColor3 = COLORS.success
        else
            exploitStatusLabel.Text = "Exploits: Steal remote was not found"
            exploitStatusLabel.TextColor3 = COLORS.warning
        end
    end,
})

local remoteBlockControl = ExploitDefenseSection:AddToggle({
    Name = "Remote Block Aura",
    Description = "Sends Block directly when a nearby opponent starts charging a shot",
    Default = false,
    Flag = "basketball_exploit_remote_block",
    Callback = function(value)
        basketballState.RemoteBlockAura = value
        exploitStatusLabel.Text = value and "Exploits: Remote Block Aura listening" or "Exploits: Remote Block Aura disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitDefenseSection:AddSlider({
    Name = "Remote Block Range",
    Min = 10,
    Max = 75,
    Step = 1,
    Default = 45,
    Flag = "basketball_exploit_block_range",
    Callback = function(value)
        basketballState.RemoteBlockRange = value
    end,
})

local ballMagnetControl = ExploitMovementSection:AddToggle({
    Name = "Loose Ball Magnet",
    Description = "Snaps your character onto a nearby loose ball before normal rebound logic runs",
    Default = false,
    Flag = "basketball_exploit_ball_magnet",
    Callback = function(value)
        basketballState.LooseBallMagnet = value
        exploitStatusLabel.Text = value and "Exploits: Loose Ball Magnet armed" or "Exploits: Loose Ball Magnet disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitMovementSection:AddSlider({
    Name = "Ball Magnet Range",
    Min = 10,
    Max = 80,
    Step = 1,
    Default = 35,
    Flag = "basketball_exploit_magnet_range",
    Callback = function(value)
        basketballState.MagnetRange = value
    end,
})

local goalAimControl = ExploitMovementSection:AddToggle({
    Name = "Goal Aim Lock",
    Description = "Forces your character to face the current scoring goal while holding the ball",
    Default = false,
    Flag = "basketball_exploit_goal_aim",
    Callback = function(value)
        basketballState.GoalAimLock = value
        exploitStatusLabel.Text = value and "Exploits: Goal Aim Lock active" or "Exploits: Goal Aim Lock disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitStatusSection:AddButton({
    Name = "Disable Every Exploit",
    Description = "Turns off all direct-remote and movement advantage options",
    Callback = function()
        playToggleClick(false)
        remoteStealControl:Set(false)
        remoteBlockControl:Set(false)
        ballMagnetControl:Set(false)
        goalAimControl:Set(false)
        exploitStatusLabel.Text = "Exploits: All experimental options disabled"
        exploitStatusLabel.TextColor3 = COLORS.muted
    end,
})

if shootMeterStartEvent and shootMeterStartEvent:IsA("RemoteEvent") then
    track(shootMeterStartEvent.OnClientEvent:Connect(function(shooter)
        if not (basketballState.SmartBlock or basketballState.RemoteBlockAura)
            or typeof(shooter) ~= "Instance" or not shooter:IsA("Player")
            or not isOpponent(shooter) then
            return
        end

        local localRoot = getCharacterRoot(LocalPlayer)
        local shooterRoot = getCharacterRoot(shooter)
        local character = LocalPlayer.Character
        if not localRoot or not shooterRoot or not character or character:FindFirstChild("Basketball") then
            return
        end
        local shooterDistance = (localRoot.Position - shooterRoot.Position).Magnitude
        local allowedDistance = basketballState.RemoteBlockAura
            and basketballState.RemoteBlockRange
            or basketballState.BlockDistance
        if shooterDistance > allowedDistance then
            return
        end

        local requestedAt = os.clock()
        if basketballState.RemoteBlockAura then
            if requestedAt - basketballState.LastRemoteBlock < 0.30 then
                return
            end
            basketballState.LastRemoteBlock = requestedAt
            if blockRemote and blockRemote:IsA("RemoteEvent") then
                pcall(function()
                    blockRemote:FireServer()
                end)
                exploitStatusLabel.Text = string.format(
                    "Exploits: Remote Block fired at %s from %.1f studs",
                    shooter.Name,
                    shooterDistance
                )
                exploitStatusLabel.TextColor3 = COLORS.success
            else
                exploitStatusLabel.Text = "Exploits: Block remote was not found"
                exploitStatusLabel.TextColor3 = COLORS.warning
            end
            return
        end

        if requestedAt - basketballState.LastBlock < 3.05 then
            return
        end
        basketballState.LastBlock = requestedAt
        basketballState.GuardResumeAt = requestedAt + 1.20
        setGuardHeld(false)
        task.delay(basketballState.BlockReaction, function()
            if basketballState.SmartBlock and gui.Parent then
                pulseBasketballKey(Enum.KeyCode.Space, 0.055)
                if defenseStatusLabel.Parent then
                    defenseStatusLabel.Text = "Defense: Contested " .. shooter.Name .. "'s shot"
                    defenseStatusLabel.TextColor3 = COLORS.success
                end
            end
        end)
    end))
end

PlayerUtilitySection:AddButton({
    Name = "Enable Competitive 1v1 Preset",
    Description = "Turns on Auto Green, Guard, Steal, Block, Rebound, Dunk, Combo, and Court Vision",
    Callback = function()
        playToggleClick(true)
        autoGreenControl:Set(true)
        autoGuardControl:Set(true)
        smartStealControl:Set(true)
        stealDistanceControl:Set(14)
        smartBlockControl:Set(true)
        autoReboundControl:Set(true)
        autoDunkControl:Set(true)
        autoComboControl:Set(true)
        courtVisionControl:Set(true)
        defenseStatusLabel.Text = "Defense: Competitive 1v1 preset active"
        scoringStatusLabel.Text = "Scoring: Competitive 1v1 preset active"
        dribbleStatusLabel.Text = "Dribble: Competitive 1v1 preset active"
        defenseStatusLabel.TextColor3 = COLORS.success
        scoringStatusLabel.TextColor3 = COLORS.success
        dribbleStatusLabel.TextColor3 = COLORS.success
        Window:Notify("Basketball", "Competitive 1v1 preset enabled", 3)
    end,
})

PlayerUtilitySection:AddButton({
    Name = "Disable All 1v1 Assists",
    Description = "Stops every automatic basketball action while keeping visual/camera settings",
    Callback = function()
        playToggleClick(false)
        autoGuardControl:Set(false)
        smartStealControl:Set(false)
        smartBlockControl:Set(false)
        autoReboundControl:Set(false)
        autoDunkControl:Set(false)
        autoComboControl:Set(false)
        setGuardHeld(false)
        defenseStatusLabel.Text = "Defense: All assists disabled"
        scoringStatusLabel.Text = "Scoring: All assists disabled"
        dribbleStatusLabel.Text = "Dribble: All assists disabled"
        defenseStatusLabel.TextColor3 = COLORS.muted
        scoringStatusLabel.TextColor3 = COLORS.muted
        dribbleStatusLabel.TextColor3 = COLORS.muted
    end,
})

PlayerUtilitySection:AddToggle({
    Name = "Anti-AFK / Anti-Idle",
    Description = "Responds whenever Roblox sends an inactivity signal",
    Default = false,
    Flag = "basketball_anti_afk",
    Callback = function(value)
        basketballState.AntiAfk = value
        antiAfkStatusLabel.Text = value and "Anti-AFK: Armed and waiting for an idle signal" or "Anti-AFK: Disabled"
        antiAfkStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local virtualUser = game:GetService("VirtualUser")
track(LocalPlayer.Idled:Connect(function()
    if not basketballState.AntiAfk then
        return
    end
    pcall(function()
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    antiAfkStatusLabel.Text = "Anti-AFK: Idle signal handled"
    antiAfkStatusLabel.TextColor3 = COLORS.success
end))

PlayerUtilitySection:AddButton({
    Name = "Test Anti-AFK Pulse",
    Description = "Runs one harmless idle-prevention pulse",
    Callback = function()
        playToggleClick(true)
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        antiAfkStatusLabel.Text = "Anti-AFK: Test pulse completed"
        antiAfkStatusLabel.TextColor3 = COLORS.success
    end,
})

local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local originalZoom = LocalPlayer.CameraMaxZoomDistance
local cameraFov = originalFov

local function applyCameraSettings()
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = cameraFov
    end
end

CameraSection:AddSlider({
    Name = "Camera FOV",
    Min = 50,
    Max = 100,
    Step = 1,
    Default = originalFov,
    Flag = "basketball_camera_fov",
    Callback = function(value)
        cameraFov = value
        applyCameraSettings()
    end,
})

CameraSection:AddSlider({
    Name = "Maximum Camera Zoom",
    Min = 8,
    Max = 40,
    Step = 1,
    Default = math.clamp(originalZoom, 8, 40),
    Flag = "basketball_camera_zoom",
    Callback = function(value)
        LocalPlayer.CameraMaxZoomDistance = value
    end,
})

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(applyCameraSettings)
end))

PlayerStatusSection:AddButton({
    Name = "Refresh Player Status",
    Description = "Refreshes court, ball, and meter information now",
    Callback = function()
        playToggleClick(true)
        basketballState.LastStatusUpdate = 0
    end,
})

track(RunService.RenderStepped:Connect(function()
    local meter, bar = resolveShotMeter()
    local visible = meter and meter.Visible == true
    local value = bar and tonumber(bar.Size.Y.Scale) or 0
    local startedNewShot = visible and not basketballState.WasMeterVisible
    local rising = visible and value > basketballState.LastMeterValue + 0.0005

    if startedNewShot or value <= 0.02 or (visible and value + 0.08 < basketballState.LastMeterValue) then
        basketballState.ReleasedThisShot = false
        if startedNewShot and UserInputService.TouchEnabled then
            captureMobileShootTouch()
        end
    end

    if visible and rising and value >= basketballState.Calibration
        and not basketballState.ReleasedThisShot
        and (basketballState.AutoGreen or basketballState.ForceNextShot) then
        basketballState.ReleasedThisShot = true
        basketballState.ForceNextShot = false
        local released, releaseMethod = releaseShootInput()
        if released then
            releaseStatusLabel.Text = string.format(
                "Release: %s fired at %.0f%% visual for the delayed full-power read",
                releaseMethod or "Input",
                value * 100
            )
            releaseStatusLabel.TextColor3 = COLORS.success
        else
            releaseStatusLabel.Text = "Release: PC E and mobile Shoot release are unsupported by this executor"
            releaseStatusLabel.TextColor3 = COLORS.warning
        end
    end

    basketballState.LastMeterValue = value
    basketballState.WasMeterVisible = visible

    local now = os.clock()
    runBasketballAssists(now)
    if now - basketballState.LastStatusUpdate >= 0.20 then
        basketballState.LastStatusUpdate = now
        meterStatusLabel.Text = visible
            and string.format("Meter: %.0f%% %s", value * 100, rising and "(charging)" or "")
            or (meter and "Meter: Ready" or "Meter: Waiting for PlayerGui.Visual.Shooting")
        meterStatusLabel.TextColor3 = visible and COLORS.success or COLORS.muted

        local character = LocalPlayer.Character
        local hasBall = character and character:FindFirstChild("Basketball") ~= nil
        local court = LocalPlayer:GetAttribute("Court")
        playerCourtLabel.Text = "Court: " .. (court == nil and "Not assigned" or tostring(court))
        playerBallLabel.Text = "Basketball: " .. (hasBall and "Equipped" or "Not held")
        playerBallLabel.TextColor3 = hasBall and COLORS.success or COLORS.muted
        playerModeLabel.Text = "Place: " .. tostring(game.PlaceId) .. " | Universe: " .. tostring(game.GameId)
    end
end))

resolveShotMeter()

track(gui.Destroying:Connect(function()
    basketballState.AutoGreen = false
    basketballState.ForceNextShot = false
    basketballState.AutoGuard = false
    basketballState.SmartSteal = false
    basketballState.SmartBlock = false
    basketballState.AutoRebound = false
    basketballState.AutoDunk = false
    basketballState.AutoCombo = false
    basketballState.CourtVision = false
    basketballState.RemoteStealAura = false
    basketballState.RemoteBlockAura = false
    basketballState.LooseBallMagnet = false
    basketballState.GoalAimLock = false
    setGuardHeld(false)
    releaseShootInput()
    for keyCode in pairs(fallbackVirtualKeys) do
        sendBasketballKey(keyCode, false)
    end
    destroyHighlight(ballHighlight)
    destroyHighlight(opponentHighlight)
    if releaseGuide and releaseGuide.Parent then
        releaseGuide:Destroy()
    end
    if meterScaleObject and meterScaleObject.Parent then
        meterScaleObject:Destroy()
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = originalFov
    end
    LocalPlayer.CameraMaxZoomDistance = originalZoom
end))

gui:SetAttribute("BasketballShotMeterPath", "PlayerGui.Visual.Shooting")
gui:SetAttribute("BasketballAutoGreenPlatforms", "PC E + Mobile Shoot Touch")
gui:SetAttribute("BasketballReleaseCalibration", basketballState.Calibration)
gui:SetAttribute("BasketballShootingDecal", CATEGORY_DECALS.Shooting)
gui:SetAttribute("BasketballPlayerDecal", CATEGORY_DECALS.Player)
gui:SetAttribute("BasketballDribbleDecal", CATEGORY_DECALS.Dribble)
gui:SetAttribute("BasketballExploitsDecal", CATEGORY_DECALS.Exploits)
end
