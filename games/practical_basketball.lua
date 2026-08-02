-- Practical Basketball adapter for VOR Hub.
-- Universe 7529591378 uses Aero, workspace.Characters, and tagged basketballs.
local DRIBBLE_MOVE_INPUTS = {
    SwitchHand = {R = "H", L = "H"},
    Crossover = {R = "Z", L = "C"},
    Hesitation = {R = "C", L = "Z"},
    DoubleCrossover = {R = "CC", L = "ZZ"},
    Tween = {R = "ZZ", L = "CC"},
    BehindBack = {R = "CX", L = "ZX"},
    Spin = {R = "CXZ", L = "ZXC"},
    DoubleBehindBack = {R = "XZ", L = "XC"},
    StepBack = {R = "X", L = "X"},
    SnatchBack = {R = "XX", L = "XX"},
    Combo = {R = "VV", L = "VV"},
    Breakdown = {R = "VC", L = "VZ"},
    HalfSpin = {R = "V", L = "V"},
}

local AUTO_DRIBBLE_PRESETS = {
    ["Separation Chain"] = {
        {Move = "Crossover", Escape = true, Direction = "Horizontal"},
        {Move = "BehindBack", Escape = true, Direction = "Backward"},
        {Move = "StepBack"},
        {Move = "SnatchBack"},
        {Move = "Tween", Escape = true, Direction = "Forward"},
    },
    ["Forward Chain"] = {
        {Move = "Crossover", Escape = true, Direction = "Forward"},
        {Move = "Hesitation", Escape = true, Direction = "Forward"},
        {Move = "Tween", Escape = true, Direction = "Forward"},
        {Move = "BehindBack", Escape = true, Direction = "Forward"},
    },
    ["Standing Chain"] = {
        {Move = "Crossover", Escape = false},
        {Move = "Hesitation", Escape = false},
        {Move = "DoubleCrossover", Escape = false},
        {Move = "Tween", Escape = false},
        {Move = "BehindBack", Escape = false},
        {Move = "DoubleBehindBack", Escape = false},
    },
    ["Escape Mix"] = {
        {Move = "Crossover", Escape = true, Direction = "Idle"},
        {Move = "Hesitation", Escape = true, Direction = "Backward"},
        {Move = "BehindBack", Escape = true, Direction = "Horizontal"},
        {Move = "Breakdown", Escape = true, Direction = "Forward"},
        {Move = "SnatchBack"},
    },
    ["Ankle Breaker"] = {
        {Move = "Crossover", Escape = true, Direction = "Forward"},
        {Move = "DoubleCrossover", Escape = true},
        {Move = "Tween", Escape = true, Direction = "Forward"},
        {Move = "BehindBack", Escape = true, Direction = "Backward"},
        {Move = "Spin"},
        {Move = "SnatchBack"},
        {Move = "Combo"},
        {Move = "HalfSpin"},
    },
    ["All Moves"] = {
        {Move = "SwitchHand"},
        {Move = "Crossover", Escape = true, Direction = "Forward"},
        {Move = "Hesitation", Escape = true, Direction = "Backward"},
        {Move = "DoubleCrossover", Escape = false},
        {Move = "Tween", Escape = true, Direction = "Forward"},
        {Move = "BehindBack", Escape = true, Direction = "Horizontal"},
        {Move = "Spin"},
        {Move = "DoubleBehindBack", Escape = false},
        {Move = "StepBack"},
        {Move = "SnatchBack"},
        {Move = "Combo"},
        {Move = "Breakdown", Escape = true, Direction = "Forward"},
        {Move = "HalfSpin"},
    },
}

return function(context)
    local Window = assert(context.Window, "game module requires Window")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "game module requires CreateCategoryHomePage")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = assert(context.Colors or context.COLORS, "game module requires colors")
    local track = assert(context.Track, "game module requires Track")
    local gui = assert(context.Gui, "game module requires Gui")

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")
    local CollectionService = game:GetService("CollectionService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local ShootingPage = addHomeCategory("Shooting", 1, CATEGORY_DECALS.Shooting)
    local OffensePage = addHomeCategory("Offense", 2, CATEGORY_DECALS.Player)
    local DefensePage = addHomeCategory("Defense", 3, CATEGORY_DECALS.Combat)
    local DribblePage = addHomeCategory("Dribble", 4, CATEGORY_DECALS.Dribble)
    local VisualsPage = addHomeCategory("Visuals", 5, CATEGORY_DECALS.Visuals)
    selectHomeCategory("Shooting")

    local AutoGreenSection = ShootingPage:AddSection("Auto Green", "Left")
    local MeterSection = ShootingPage:AddSection("Live Meter", "Right")
    local MovementSection = OffensePage:AddSection("Movement", "Left")
    local PassingSection = OffensePage:AddSection("Passing & Screens", "Right")
    local GuardSection = DefensePage:AddSection("Guard & Steal", "Left")
    local ContestSection = DefensePage:AddSection("Contest & Rebound", "Right")
    local ComboSection = DribblePage:AddSection("Dribble Automation", "Left")
    local ComboStatusSection = DribblePage:AddSection("Combo Status", "Right")
    local VisionSection = VisualsPage:AddSection("Court Vision", "Left")
    local CameraSection = VisualsPage:AddSection("Camera", "Right")
    local StatusSection = VisualsPage:AddSection("Live Status", "Right")

    local state = {
        Alive = true,
        AutoGreen = false,
        ForceNextGreen = false,
        -- The displayed meter advances in roughly 0.05-stud frame steps, while
        -- the server's Perfect window sits between those samples. Track an
        -- interpolated release target instead of waiting for the next frame.
        PerfectTravels = {},
        TargetLowerTravels = {},
        TargetUpperTravels = {},
        ReleasedThisShot = false,
        WasMeterActive = false,
        WasServerReleased = true,
        ShotToken = nil,
        ShotStartOffset = nil,
        ShotDirection = nil,
        ShotTravel = 0,
        ShotFurthestOffset = nil,
        ShotFurthestTravel = 0,
        LastMeterSampleAt = nil,
        LastMeterSampleOffset = nil,
        MeterSpeed = 0,
        LastShotOffset = nil,
        LastShotMeter = "Vertical",
        MobileShootHeld = false,
        PendingReleaseOffset = nil,
        PendingReleaseTravel = nil,
        PendingReleaseMeter = nil,
        PendingReleaseDirection = nil,
        LastFeedback = "Waiting",
        LastTimingCorrection = "Waiting",
        FullOffsets = {
            -- Live Vertical meter endpoint when the white bar is completely filled.
            Vertical = Vector2.new(0, -1.46824694),
        },
        PerfectOffsets = {
            -- Confirmed by the live server: -1.4148 graded Good and -1.4150
            -- graded Perfect at 0% contest.
            Vertical = Vector2.new(0, -1.415),
        },
        MeterName = "None",
        LastRelease = "Waiting",

        AutoSprint = false,
        SprintThreshold = 25,
        SprintHeld = false,
        AutoScreen = false,
        ScreenHeld = false,

        AutoGuard = false,
        GuardHeld = false,
        GuardRefreshAt = 0,
        AutoSteal = false,
        StealRange = 11,
        StealInterval = 0.45,
        LastSteal = 0,
        AutoContest = false,
        ContestRange = 14,
        LastContest = 0,
        LastContestToken = "",
        AutoRebound = false,
        ReboundRange = 18,
        LastRebound = 0,

        AutoDribble = false,
        Combo = "ZX",
        DribblePreset = "Separation Chain",
        DribblePresetIndex = 1,
        DribbleTrigger = "Guarded Only",
        DribbleRange = 14,
        CustomDribbleChain = {"Z", "C", "CC", "ZZ", "CX", "XZ", "XX", "VV", "VC", "V"},
        ComboInterval = 1.5,
        LastCombo = 0,
        ComboHotkey = false,
        MobileDribbleButton = UserInputService.TouchEnabled,

        CourtVision = false,
        AntiAfk = true,
        LastStatus = 0,
    }

    local remoteRoot = ReplicatedStorage:FindFirstChild("Aero")
    remoteRoot = remoteRoot and remoteRoot:FindFirstChild("AeroRemoteServices")
    local inputRemotes = remoteRoot and remoteRoot:FindFirstChild("InputService")

    local remotes = {}
    for _, name in ipairs({
        "Shoot",
        "Sprint",
        "Steal",
        "Jump",
        "HoldG",
        "Dribble",
        "Pass",
        "Screen",
    }) do
        remotes[name] = inputRemotes and inputRemotes:FindFirstChild(name)
    end

    local function fireRemote(name, ...)
        local remote = remotes[name]
        if not remote or not remote:IsA("RemoteEvent") then
            return false
        end
        return pcall(remote.FireServer, remote, ...)
    end

    local function resolveCharacter()
        local characters = workspace:FindFirstChild("Characters")
        return characters and characters:FindFirstChild(LocalPlayer.Name)
    end

    local characterFolder = workspace:FindFirstChild("Characters")
    Window.AvatarCharacterResolver = resolveCharacter
    Window.AvatarCharacterAddedSignal = characterFolder and characterFolder.ChildAdded or nil
    Window.AvatarCharacterFilter = function(character)
        return character and character.Name == LocalPlayer.Name
    end

    local function resolveRoot(character)
        character = character or resolveCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function resolveValueObject(character, name)
        local attributes = character and character:FindFirstChild("Attributes")
        local valueObject = attributes and attributes:FindFirstChild(name)
        return valueObject and valueObject:IsA("ValueBase") and valueObject.Value or nil
    end

    local function hasBasketball(character)
        return character ~= nil and (
            character:GetAttribute("Basketball") == true
            or resolveValueObject(character, "Basketball") ~= nil
        )
    end

    local function getTeam(character)
        if not character then
            return nil
        end
        local team = character:GetAttribute("Team")
        if team == nil then
            team = character:GetAttribute("TeamIndex")
        end
        return team
    end

    local function sameTeam(first, second)
        local firstTeam = getTeam(first)
        local secondTeam = getTeam(second)
        return firstTeam ~= nil and secondTeam ~= nil and firstTeam == secondTeam
    end

    local function isPlayableCharacter(character)
        if not character or character.Name == "InvisCharacter" then
            return false
        end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root or root.Position.Y < -100 then
            return false
        end
        return character:GetAttribute("InGame") == true
            or character:GetAttribute("OnCourt") == true
    end

    local function nearestCharacter(filter, maximumDistance)
        local ownCharacter = resolveCharacter()
        local ownRoot = resolveRoot(ownCharacter)
        local characters = workspace:FindFirstChild("Characters")
        if not ownCharacter or not ownRoot or not characters then
            return nil, math.huge
        end

        local best, bestDistance = nil, maximumDistance or math.huge
        for _, candidate in ipairs(characters:GetChildren()) do
            if candidate ~= ownCharacter and isPlayableCharacter(candidate) then
                local root = resolveRoot(candidate)
                local distance = root and (root.Position - ownRoot.Position).Magnitude or math.huge
                if distance < bestDistance and (not filter or filter(candidate)) then
                    best = candidate
                    bestDistance = distance
                end
            end
        end
        return best, bestDistance
    end

    local function nearestOpponent(maximumDistance, requireBall)
        local ownCharacter = resolveCharacter()
        return nearestCharacter(function(candidate)
            if sameTeam(ownCharacter, candidate) then
                return false
            end
            return not requireBall or candidate:GetAttribute("Basketball") == true
        end, maximumDistance)
    end

    local function nearestTeammate(maximumDistance)
        local ownCharacter = resolveCharacter()
        return nearestCharacter(function(candidate)
            return sameTeam(ownCharacter, candidate)
        end, maximumDistance)
    end

    local function nearestActiveBall(maximumDistance)
        local root = resolveRoot()
        if not root then
            return nil, math.huge
        end

        local best, bestDistance = nil, maximumDistance or math.huge
        for _, ball in ipairs(CollectionService:GetTagged("Basketballs")) do
            if ball:IsA("BasePart") and ball:IsDescendantOf(workspace)
                and ball:GetAttribute("Active") == true then
                local distance = (ball.Position - root.Position).Magnitude
                if distance < bestDistance then
                    best = ball
                    bestDistance = distance
                end
            end
        end
        return best, bestDistance
    end

    local function findActiveMeter(character)
        if not character then
            return nil
        end
        for _, holderName in ipairs({"HumanoidRootPart", "Head"}) do
            local holder = character:FindFirstChild(holderName)
            if holder then
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA("BillboardGui") and child.Name:match("Meter$")
                        and child:GetAttribute("Active") == true then
                        return child
                    end
                end
            end
        end
        return nil
    end

    local function releaseShoot()
        -- Never simulate key-up here. The tutorial keyboard component owns the
        -- physical E state; forcing it up can leave the character pose stuck.
        return fireRemote("Shoot", {Shoot = false})
    end

    local function setSprintHeld(held)
        held = held == true
        if state.SprintHeld == held then
            return
        end
        if fireRemote("Sprint", held) then
            state.SprintHeld = held
        end
    end

    local function setGuardHeld(held, force)
        held = held == true
        if not force and state.GuardHeld == held then
            return
        end
        if fireRemote("HoldG", {HoldingG = held}) then
            state.GuardHeld = held
            state.GuardRefreshAt = os.clock() + 1
        end
    end

    local function setScreenHeld(held)
        held = held == true
        if state.ScreenHeld == held then
            return
        end
        if fireRemote("Screen", held) then
            state.ScreenHeld = held
        end
    end

    local function movementInputHeld(character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
            or UserInputService:IsKeyDown(Enum.KeyCode.W)
            or UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.S)
            or UserInputService:IsKeyDown(Enum.KeyCode.D)
            or UserInputService:IsKeyDown(Enum.KeyCode.Up)
            or UserInputService:IsKeyDown(Enum.KeyCode.Down)
            or UserInputService:IsKeyDown(Enum.KeyCode.Left)
            or UserInputService:IsKeyDown(Enum.KeyCode.Right)
    end

    local function currentMoveDirection(character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.MoveDirection.Magnitude > 0 then
            return humanoid.MoveDirection
        end
        local root = resolveRoot(character)
        return root and root.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.zero
    end

    local function getDribbleDirection(character, direction)
        if not direction or direction == "Idle" then
            return Vector3.zero
        end

        local root = resolveRoot(character)
        if not root then
            return Vector3.zero
        end

        local goal = resolveValueObject(character, "Goal")
        local flatRoot = root.Position * Vector3.new(1, 0, 1)
        local flatGoal = goal and goal:IsA("BasePart")
            and goal.Position * Vector3.new(1, 0, 1)
            or flatRoot + root.CFrame.LookVector * Vector3.new(1, 0, 1)
        local basis = (flatGoal - flatRoot).Magnitude > 0.01
            and CFrame.lookAt(flatRoot, flatGoal)
            or root.CFrame.Rotation
        local forward = basis.LookVector * Vector3.new(1, 0, 1)
        local right = basis.RightVector * Vector3.new(1, 0, 1)

        if direction == "Forward" then
            return forward.Unit
        elseif direction == "Backward" then
            return -forward.Unit
        elseif direction == "OppositeHorizontal" then
            return character:GetAttribute("Hand") == "L" and -right.Unit or right.Unit
        elseif direction == "Horizontal" then
            return character:GetAttribute("Hand") == "L" and right.Unit or -right.Unit
        end
        return Vector3.zero
    end

    local function runDribbleStep(character, step)
        if not character or not step then
            return false, "Waiting"
        end
        local hand = character:GetAttribute("Hand") == "L" and "L" or "R"
        local input = step.Input
        if not input and step.Move then
            local moveInputs = DRIBBLE_MOVE_INPUTS[step.Move]
            input = moveInputs and moveInputs[hand]
        end
        if not input then
            return false, "Invalid move"
        end

        if step.Escape ~= nil then
            setSprintHeld(step.Escape)
        end
        local fired
        if input == "H" then
            fired = fireRemote("Dribble", input)
        else
            fired = fireRemote(
                "Dribble",
                input,
                step.Escape == true,
                step.Direction and getDribbleDirection(character, step.Direction)
                    or currentMoveDirection(character)
            )
        end
        return fired, fired
            and string.format("%s | %s hand", step.Move or input, hand)
            or "Dribble remote unavailable"
    end

    local function getSelectedDribbleStep()
        local preset = AUTO_DRIBBLE_PRESETS[state.DribblePreset]
        local custom = state.DribblePreset == "Custom Chain"
        local count = custom and #state.CustomDribbleChain or (preset and #preset or 0)
        if count <= 0 then
            return nil, 0, 0
        end
        if state.DribblePresetIndex > count then
            state.DribblePresetIndex = 1
        end
        local index = state.DribblePresetIndex
        local step = custom
            and {
                Input = state.CustomDribbleChain[index],
                Escape = true,
                Direction = "Forward",
            }
            or preset[index]
        return step, count, index
    end

    local function runNextDribbleStep(character)
        local step, count, index = getSelectedDribbleStep()
        if not step then
            return false, "Empty chain", index, count
        end
        local fired, status = runDribbleStep(character, step)
        if fired then
            state.DribblePresetIndex = index % count + 1
        end
        return fired, status, index, count
    end

    local meterNameLabel = MeterSection:AddLabel("Meter: Waiting")
    local meterProgressLabel = MeterSection:AddLabel("Charge: 0%")
    local meterReleaseLabel = MeterSection:AddLabel("Release: Disabled")
    local meterStateLabel = MeterSection:AddLabel("Shot state: Waiting")
    local comboLabel = ComboStatusSection:AddLabel("Single move: ZX")
    local chainStatusLabel = ComboStatusSection:AddLabel("Chain: Separation Chain | Waiting")
    local playerStatusLabel = StatusSection:AddLabel("Player: Reading...")
    local ballStatusLabel = StatusSection:AddLabel("Ball: Reading...")
    local opponentStatusLabel = StatusSection:AddLabel("Opponent: Reading...")
    local adapterStatusLabel = StatusSection:AddLabel("Adapter: Aero remotes found")
    local comboHotkeyAction = "VORPracticalBasketballComboF"

    local function triggerSelectedChain(source)
        local character = resolveCharacter()
        local action = tostring(character and character:GetAttribute("Action") or "")
        if not character or not hasBasketball(character) then
            chainStatusLabel.Text = "Chain: " .. source .. " waiting for possession"
            return false
        elseif action ~= "" and action ~= "TripleThreat" and action ~= "Moving" then
            chainStatusLabel.Text = "Chain: " .. source .. " waiting for " .. action
            return false
        end
        local fired, status, index, count = runNextDribbleStep(character)
        chainStatusLabel.Text = string.format(
            "Chain: %s | %s | %d/%d",
            source,
            status,
            index,
            count
        )
        return fired
    end

    local function setComboHotkey(enabled)
        ContextActionService:UnbindAction(comboHotkeyAction)
        state.ComboHotkey = enabled == true
        if not state.ComboHotkey then
            return
        end
        ContextActionService:BindActionAtPriority(
            comboHotkeyAction,
            function(_, inputState)
                if inputState == Enum.UserInputState.Begin then
                    triggerSelectedChain("F")
                end
                return Enum.ContextActionResult.Sink
            end,
            false,
            Enum.ContextActionPriority.High.Value + 100,
            Enum.KeyCode.F
        )
    end

    local buttonHost = gui:FindFirstChild("Overlay") or gui
    local mobileDribbleButton = Instance.new("TextButton")
    mobileDribbleButton.Name = "PracticalBasketballMobileDribble"
    mobileDribbleButton.AnchorPoint = Vector2.new(0.5, 0.5)
    mobileDribbleButton.Position = UDim2.fromScale(0.84, 0.52)
    mobileDribbleButton.Size = UDim2.fromOffset(64, 64)
    mobileDribbleButton.BackgroundColor3 = COLORS.surfaceRaised
    mobileDribbleButton.BackgroundTransparency = 0.08
    mobileDribbleButton.BorderSizePixel = 0
    mobileDribbleButton.Text = utf8.char(0x1F3C0)
    mobileDribbleButton.TextColor3 = COLORS.white
    mobileDribbleButton.TextSize = 32
    mobileDribbleButton.Font = Enum.Font.GothamBold
    mobileDribbleButton.AutoButtonColor = false
    mobileDribbleButton.Active = true
    mobileDribbleButton.Visible = state.MobileDribbleButton
    mobileDribbleButton.ZIndex = 95
    mobileDribbleButton.Parent = buttonHost

    local mobileButtonCorner = Instance.new("UICorner")
    mobileButtonCorner.CornerRadius = UDim.new(1, 0)
    mobileButtonCorner.Parent = mobileDribbleButton
    local mobileButtonStroke = Instance.new("UIStroke")
    mobileButtonStroke.Color = COLORS.accentBright
    mobileButtonStroke.Thickness = 2
    mobileButtonStroke.Transparency = 0.08
    mobileButtonStroke.Parent = mobileDribbleButton

    local mobileDragging = false
    local mobileDragged = false
    local mobileDragInput
    local mobileDragStart
    local mobileButtonStart

    track(mobileDribbleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            mobileDragging = true
            mobileDragged = false
            mobileDragInput = input
            mobileDragStart = Vector2.new(input.Position.X, input.Position.Y)
            mobileButtonStart = mobileDribbleButton.AbsolutePosition
                + mobileDribbleButton.AbsoluteSize * 0.5
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not mobileDragging or not mobileDragStart or not mobileButtonStart then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= mobileDragInput then
            return
        end
        local position = Vector2.new(input.Position.X, input.Position.Y)
        local delta = position - mobileDragStart
        if delta.Magnitude > 6 then
            mobileDragged = true
        end
        local hostSize = buttonHost.AbsoluteSize
        local half = mobileDribbleButton.AbsoluteSize * 0.5
        local center = mobileButtonStart + delta - buttonHost.AbsolutePosition
        center = Vector2.new(
            math.clamp(center.X, half.X, math.max(half.X, hostSize.X - half.X)),
            math.clamp(center.Y, half.Y, math.max(half.Y, hostSize.Y - half.Y))
        )
        mobileDribbleButton.Position = UDim2.fromScale(
            center.X / math.max(1, hostSize.X),
            center.Y / math.max(1, hostSize.Y)
        )
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input == mobileDragInput
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            mobileDragging = false
            mobileDragInput = nil
            mobileDragStart = nil
            mobileButtonStart = nil
            if mobileDragged then
                task.defer(function()
                    mobileDragged = false
                end)
            end
        end
    end))
    track(mobileDribbleButton.Activated:Connect(function()
        if not mobileDragged then
            triggerSelectedChain("Mobile")
        end
    end))

    local trackedMobileShootButtons = setmetatable({}, {__mode = "k"})
    local function trackMobileShootButton(button)
        if not button or trackedMobileShootButtons[button] then
            return
        end
        trackedMobileShootButtons[button] = true
        track(button.MouseButton1Down:Connect(function()
            state.MobileShootHeld = true
        end))
        track(button.MouseButton1Up:Connect(function()
            state.MobileShootHeld = false
        end))
        track(button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                state.MobileShootHeld = false
            end
        end))
    end

    local function attachMobileShootControls(mobileGui)
        if not mobileGui then
            return
        end
        for _, layoutName in ipairs({"OffenseButton", "OffenseThumbstick"}) do
            local layout = mobileGui:FindFirstChild(layoutName)
            trackMobileShootButton(layout and layout:FindFirstChild("Shoot"))
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    attachMobileShootControls(playerGui and playerGui:FindFirstChild("Mobile"))
    if playerGui then
        track(playerGui.ChildAdded:Connect(function(child)
            if child.Name == "Mobile" then
                task.defer(attachMobileShootControls, child)
            end
        end))
    end

    AutoGreenSection:AddToggle({
        Name = "Auto Green",
        Description = "Releases held keyboard or native mobile Shoot input from the live Aero meter",
        Flag = "practical_basketball_auto_green",
        Default = false,
        Callback = function(enabled)
            state.AutoGreen = enabled
            state.ReleasedThisShot = false
            meterReleaseLabel.Text = enabled and "Release: Armed" or "Release: Disabled"
            meterReleaseLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        end,
    })
    AutoGreenSection:AddLabel("Timing is fully automatic; manual offset and lead controls are locked out.")
    AutoGreenSection:AddButton({
        Name = "Green Next Shot",
        Description = "Arms Auto Green for one shot without leaving it enabled",
        Callback = function()
            state.ForceNextGreen = true
            state.ReleasedThisShot = false
            meterReleaseLabel.Text = "Release: Next shot armed"
            meterReleaseLabel.TextColor3 = COLORS.success
        end,
    })
    AutoGreenSection:AddLabel("Safe release: no hooks, no VirtualInputManager, and no forced E key-up.")
    AutoGreenSection:AddLabel("Every server grade narrows the exact local release offset for that meter style.")

    MovementSection:AddToggle({
        Name = "Auto Sprint",
        Description = "Uses the game's real Sprint remote while movement keys are held",
        Flag = "practical_basketball_auto_sprint",
        Default = false,
        Callback = function(enabled)
            state.AutoSprint = enabled
            if not enabled then
                setSprintHeld(false)
            end
        end,
    })
    MovementSection:AddSlider({
        Name = "Minimum Sprint Stamina",
        Flag = "practical_basketball_sprint_stamina",
        Min = 0,
        Max = 80,
        Step = 5,
        Default = 25,
        Callback = function(value)
            state.SprintThreshold = tonumber(value) or 25
        end,
    })
    MovementSection:AddToggle({
        Name = "Anti AFK",
        Flag = "practical_basketball_anti_afk",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })

    PassingSection:AddToggle({
        Name = "Auto Hold Screen",
        Description = "Uses the native T-screen state until disabled",
        Flag = "practical_basketball_auto_screen",
        Default = false,
        Callback = function(enabled)
            state.AutoScreen = enabled
            setScreenHeld(enabled)
        end,
    })
    PassingSection:AddButton({
        Name = "Pass To Closest Teammate",
        Callback = function()
            local teammate = nearestTeammate(250)
            if teammate then
                fireRemote("Pass", {
                    Player = teammate.Name,
                    PassType = 1,
                })
            end
        end,
    })
    PassingSection:AddButton({
        Name = "Drop Ball",
        Description = "Uses the game's P-key behavior",
        Callback = function()
            local drop = inputRemotes and inputRemotes:FindFirstChild("DropBall")
            if drop and drop:IsA("RemoteEvent") then
                pcall(drop.FireServer, drop)
            end
        end,
    })

    GuardSection:AddToggle({
        Name = "Auto Hold Guard",
        Description = "Keeps the native G guard state held; you still control direction",
        Flag = "practical_basketball_auto_guard",
        Default = false,
        Callback = function(enabled)
            state.AutoGuard = enabled
            setGuardHeld(enabled, true)
        end,
    })
    GuardSection:AddToggle({
        Name = "Auto Steal Ball Handler",
        Description = "Uses the native R steal only when an opponent with the ball is close",
        Flag = "practical_basketball_auto_steal",
        Default = false,
        Callback = function(enabled)
            state.AutoSteal = enabled
        end,
    })
    GuardSection:AddSlider({
        Name = "Steal Range",
        Flag = "practical_basketball_steal_range",
        Min = 4,
        Max = 18,
        Step = 1,
        Default = 11,
        Suffix = " studs",
        Callback = function(value)
            state.StealRange = tonumber(value) or 11
        end,
    })
    GuardSection:AddSlider({
        Name = "Steal Interval",
        Flag = "practical_basketball_steal_interval",
        Min = 0.25,
        Max = 1.5,
        Step = 0.05,
        Default = 0.45,
        Suffix = "s",
        Callback = function(value)
            state.StealInterval = tonumber(value) or 0.45
        end,
    })

    ContestSection:AddToggle({
        Name = "Auto Contest",
        Description = "Jumps once when a nearby opponent enters Shooting or Dunking",
        Flag = "practical_basketball_auto_contest",
        Default = false,
        Callback = function(enabled)
            state.AutoContest = enabled
        end,
    })
    ContestSection:AddSlider({
        Name = "Contest Range",
        Flag = "practical_basketball_contest_range",
        Min = 6,
        Max = 24,
        Step = 1,
        Default = 14,
        Suffix = " studs",
        Callback = function(value)
            state.ContestRange = tonumber(value) or 14
        end,
    })
    ContestSection:AddToggle({
        Name = "Auto Rebound Jump",
        Description = "Jumps for the nearest active tagged basketball",
        Flag = "practical_basketball_auto_rebound",
        Default = false,
        Callback = function(enabled)
            state.AutoRebound = enabled
        end,
    })
    ContestSection:AddSlider({
        Name = "Rebound Range",
        Flag = "practical_basketball_rebound_range",
        Min = 6,
        Max = 30,
        Step = 1,
        Default = 18,
        Suffix = " studs",
        Callback = function(value)
            state.ReboundRange = tonumber(value) or 18
        end,
    })

    ComboSection:AddDropdown({
        Name = "Dribble Chain",
        Description = "Selects the move sequence used to create separation",
        Flag = "practical_basketball_dribble_chain",
        Options = {
            "Separation Chain",
            "Forward Chain",
            "Standing Chain",
            "Escape Mix",
            "Ankle Breaker",
            "All Moves",
            "Custom Chain",
        },
        Default = "Separation Chain",
        Callback = function(value)
            state.DribblePreset = tostring(value or "Separation Chain")
            state.DribblePresetIndex = 1
            chainStatusLabel.Text = "Chain: " .. state.DribblePreset .. " | Waiting"
        end,
    })
    ComboSection:AddDropdown({
        Name = "Chain Trigger",
        Description = "Guarded Only stops the chain after you create shooting space",
        Flag = "practical_basketball_dribble_trigger",
        Options = {"Guarded Only", "Always"},
        Default = "Guarded Only",
        Callback = function(value)
            state.DribbleTrigger = tostring(value or "Guarded Only")
        end,
    })
    ComboSection:AddSlider({
        Name = "Defender Trigger Range",
        Description = "A defender inside this range starts the guarded chain",
        Flag = "practical_basketball_dribble_defender_range",
        Min = 5,
        Max = 30,
        Step = 1,
        Default = 14,
        Suffix = " studs",
        Callback = function(value)
            state.DribbleRange = tonumber(value) or 14
        end,
    })
    ComboSection:AddInput({
        Name = "Custom Chain",
        Description = "Comma-separated native inputs, for example Z,C,CC,ZZ,CX,XZ,XX,VV",
        Flag = "practical_basketball_custom_dribble_chain",
        Placeholder = "Z,C,CC,ZZ,CX,XZ,XX,VV,VC,V",
        Default = "Z,C,CC,ZZ,CX,XZ,XX,VV,VC,V",
        Callback = function(value)
            local validInputs = {
                H = true, Z = true, C = true, V = true, X = true,
                ZZ = true, CC = true, ZX = true, CX = true,
                XZ = true, XC = true, XX = true, VV = true,
                VC = true, VZ = true, ZXC = true, CXZ = true,
            }
            local parsed = {}
            for token in string.gmatch(string.upper(tostring(value or "")), "[A-Z]+") do
                if validInputs[token] then
                    table.insert(parsed, token)
                end
            end
            if #parsed > 0 then
                state.CustomDribbleChain = parsed
                state.DribblePresetIndex = 1
            end
        end,
    })
    ComboSection:AddToggle({
        Name = "Auto Dribble Chain",
        Description = "Runs the selected chain while you hold the ball and the trigger is active",
        Flag = "practical_basketball_auto_dribble",
        Default = false,
        Callback = function(enabled)
            state.AutoDribble = enabled
            state.LastCombo = 0
            state.DribblePresetIndex = 1
            chainStatusLabel.Text = "Chain: " .. state.DribblePreset
                .. (enabled and " | Armed" or " | Disabled")
            if not enabled then
                setSprintHeld(false)
            end
        end,
    })
    ComboSection:AddToggle({
        Name = "F Chain Hotkey",
        Description = "F advances the selected chain and temporarily replaces native foul/clutch/self-pass",
        Flag = "practical_basketball_f_chain_hotkey",
        Default = false,
        Callback = function(enabled)
            setComboHotkey(enabled)
            chainStatusLabel.Text = enabled
                and "Chain: F hotkey armed"
                or "Chain: F hotkey disabled"
        end,
    })
    ComboSection:AddToggle({
        Name = "Mobile Basketball Button",
        Description = "Shows a draggable floating basketball that advances the selected chain per tap",
        Flag = "practical_basketball_mobile_dribble_button",
        Default = UserInputService.TouchEnabled,
        Callback = function(enabled)
            state.MobileDribbleButton = enabled
            mobileDribbleButton.Visible = enabled
            chainStatusLabel.Text = enabled
                and "Chain: Mobile basketball button ready"
                or "Chain: Mobile basketball button hidden"
        end,
    })
    ComboSection:AddSlider({
        Name = "Move Interval",
        Description = "Delay between accepted moves in the chain",
        Flag = "practical_basketball_combo_interval",
        Min = 0.6,
        Max = 4,
        Step = 0.1,
        Default = 1.5,
        Suffix = "s",
        Callback = function(value)
            state.ComboInterval = tonumber(value) or 1.5
        end,
    })
    ComboSection:AddDropdown({
        Name = "Single Move Input",
        Description = "Exact Aero input for manual testing",
        Flag = "practical_basketball_dribble_combo",
        Options = {
            "H", "Z", "C", "V", "X", "ZZ", "CC", "ZX", "CX",
            "XZ", "XC", "XX", "VV", "VC", "VZ", "ZXC", "CXZ",
        },
        Default = "ZX",
        Callback = function(value)
            state.Combo = tostring(value or "ZX")
            comboLabel.Text = "Single move: " .. state.Combo
        end,
    })
    ComboSection:AddButton({
        Name = "Run Single Move",
        Callback = function()
            runDribbleStep(resolveCharacter(), {
                Input = state.Combo,
                Escape = state.SprintHeld,
            })
        end,
    })
    ComboStatusSection:AddLabel("Guarded Only chains stop once the defender leaves your trigger range.")
    ComboStatusSection:AddLabel("Mobile uses the Guarded Only trigger; F hotkey is desktop-only.")
    ComboStatusSection:AddLabel("Presets cover every native move family found in the Dribbling lesson.")
    ComboStatusSection:AddLabel("The server still validates possession, stamina, and animation state.")

    local ballHighlight = Instance.new("Highlight")
    ballHighlight.Name = "VORPracticalBallVision"
    ballHighlight.FillColor = COLORS.accentBright
    ballHighlight.OutlineColor = COLORS.white
    ballHighlight.FillTransparency = 0.35
    ballHighlight.OutlineTransparency = 0
    ballHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    ballHighlight.Enabled = false
    ballHighlight.Parent = gui

    local opponentHighlight = Instance.new("Highlight")
    opponentHighlight.Name = "VORPracticalOpponentVision"
    opponentHighlight.FillColor = COLORS.error
    opponentHighlight.OutlineColor = COLORS.white
    opponentHighlight.FillTransparency = 0.65
    opponentHighlight.OutlineTransparency = 0
    opponentHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    opponentHighlight.Enabled = false
    opponentHighlight.Parent = gui

    VisionSection:AddToggle({
        Name = "Court Vision",
        Description = "Highlights the active ball and closest opposing ball handler",
        Flag = "practical_basketball_court_vision",
        Default = false,
        Callback = function(enabled)
            state.CourtVision = enabled
            if not enabled then
                ballHighlight.Enabled = false
                opponentHighlight.Enabled = false
            end
        end,
    })

    local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
    local originalZoom = LocalPlayer.CameraMaxZoomDistance
    local cameraFov = originalFov
    local fovOverride = true
    local fovApplying = false
    local fovConnection

    local function applyCamera()
        if fovOverride and workspace.CurrentCamera
            and math.abs(workspace.CurrentCamera.FieldOfView - cameraFov) > 0.01 then
            fovApplying = true
            workspace.CurrentCamera.FieldOfView = cameraFov
            fovApplying = false
        end
    end

    local function watchCamera()
        if fovConnection then
            fovConnection:Disconnect()
            fovConnection = nil
        end
        local camera = workspace.CurrentCamera
        if camera then
            fovConnection = camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
                if fovOverride and not fovApplying then
                    applyCamera()
                end
            end)
        end
        applyCamera()
    end
    watchCamera()

    CameraSection:AddSlider({
        Name = "Camera FOV",
        Description = "Locks the active camera after the game's camera controller updates",
        Flag = "practical_basketball_camera_fov",
        Min = 50,
        Max = 110,
        Step = 1,
        Default = math.clamp(originalFov, 50, 110),
        Callback = function(value)
            cameraFov = tonumber(value) or originalFov
            fovOverride = true
            applyCamera()
        end,
    })
    CameraSection:AddButton({
        Name = "Reset Camera FOV",
        Description = "Releases VOR's FOV lock and restores the original value",
        Callback = function()
            fovOverride = false
            if workspace.CurrentCamera then
                workspace.CurrentCamera.FieldOfView = originalFov
            end
        end,
    })
    CameraSection:AddSlider({
        Name = "Maximum Camera Zoom",
        Flag = "practical_basketball_camera_zoom",
        Min = 8,
        Max = 60,
        Step = 1,
        Default = math.clamp(originalZoom, 8, 60),
        Callback = function(value)
            LocalPlayer.CameraMaxZoomDistance = tonumber(value) or originalZoom
        end,
    })
    track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        task.defer(watchCamera)
    end))

    track(LocalPlayer.Idled:Connect(function()
        if state.Alive and state.AntiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end
    end))

    local function shootInputHeld()
        return state.MobileShootHeld
            or UserInputService:IsKeyDown(Enum.KeyCode.E)
            or UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end

    local function resetShot(offset, token)
        state.ShotToken = token
        state.ShotStartOffset = typeof(offset) == "Vector2" and offset or nil
        state.ShotDirection = nil
        state.ShotTravel = 0
        state.ShotFurthestOffset = typeof(offset) == "Vector2" and offset or nil
        state.ShotFurthestTravel = 0
        state.LastMeterSampleAt = os.clock()
        state.LastMeterSampleOffset = typeof(offset) == "Vector2" and offset or nil
        state.MeterSpeed = 0
        state.PendingReleaseOffset = nil
        state.PendingReleaseTravel = nil
        state.PendingReleaseMeter = nil
        state.PendingReleaseDirection = nil
        state.ReleasedThisShot = false
    end

    local function updateShooting(character)
        local meter = findActiveMeter(character)
        local meterActive = meter ~= nil
        local offset = character and character:GetAttribute("meterOffset")
        local token = character and character:GetAttribute("ShotStartTime")
        local serverReleased = character and character:GetAttribute("ReleasedShot")
        local action = character and tostring(character:GetAttribute("Action") or "") or ""

        if token ~= state.ShotToken or (meterActive and not state.WasMeterActive) then
            resetShot(offset, token)
        end
        state.WasMeterActive = meterActive
        if meter then
            state.MeterName = meter.Name:gsub("Meter$", "")
            state.LastShotMeter = state.MeterName
        elseif not meterActive then
            state.MeterName = "None"
        end

        if meterActive and typeof(offset) == "Vector2" then
            local sampleAt = os.clock()
            if not state.ShotStartOffset then
                state.ShotStartOffset = offset
            end
            state.LastShotOffset = offset
            local delta = offset - state.ShotStartOffset
            if delta.Magnitude > 0.00001 and not state.ShotDirection then
                state.ShotDirection = delta.Unit
            end
            if state.ShotDirection then
                state.ShotTravel = delta:Dot(state.ShotDirection)
                if state.ShotTravel >= state.ShotFurthestTravel then
                    state.ShotFurthestTravel = state.ShotTravel
                    state.ShotFurthestOffset = offset
                end
                local previousOffset = state.LastMeterSampleOffset
                local previousAt = state.LastMeterSampleAt
                if typeof(previousOffset) == "Vector2" and type(previousAt) == "number" then
                    local sampleDuration = sampleAt - previousAt
                    if sampleDuration > 0.0001 and sampleDuration < 0.25 then
                        local observedSpeed = (offset - previousOffset):Dot(state.ShotDirection) / sampleDuration
                        -- Clean Vertical traces travel at about 3.05 units/s.
                        -- Tiny callback intervals occasionally report 9+ and
                        -- would make interpolation release several ms early.
                        if observedSpeed > 0 and observedSpeed < 5 then
                            state.MeterSpeed = state.MeterSpeed > 0
                                and state.MeterSpeed * 0.7 + observedSpeed * 0.3
                                or observedSpeed
                        end
                    end
                end
            end
            state.LastMeterSampleAt = sampleAt
            state.LastMeterSampleOffset = offset

            local reachedTarget = false
            local targetOffset = state.PerfectOffsets[state.MeterName]
            local targetTravel
            if typeof(targetOffset) == "Vector2" and state.ShotDirection then
                -- Shot travel starts from this shot's live initial offset (about
                -- -0.24 in the current Vertical meter), not from Vector2.zero.
                -- Recompute every shot so the target can never be unreachable.
                targetTravel = (targetOffset - state.ShotStartOffset):Dot(state.ShotDirection)
                state.PerfectTravels[state.MeterName] = targetTravel
                reachedTarget = targetTravel >= 0 and state.ShotTravel >= targetTravel
            end

            local releaseDelay
            if not reachedTarget and targetTravel and state.MeterSpeed > 0 then
                local remainingTravel = targetTravel - state.ShotTravel
                local predictedDelay = remainingTravel / state.MeterSpeed
                if remainingTravel > 0 and predictedDelay >= 0 and predictedDelay <= 0.004 then
                    releaseDelay = predictedDelay
                end
            end

            if (reachedTarget or releaseDelay)
                and not state.ReleasedThisShot
                and serverReleased == false
                and action == "Shooting"
                and shootInputHeld()
                and (state.AutoGreen or state.ForceNextGreen) then
                if releaseDelay and releaseDelay > 0 then
                    -- task.wait/task.delay round tiny waits to several
                    -- milliseconds and skipped the measured Perfect slice.
                    -- This spin is capped at 4 ms and happens once per shot.
                    local deadline = os.clock() + releaseDelay
                    repeat until os.clock() >= deadline
                end
                local releaseMeter = state.MeterName
                local releaseDirection = state.ShotDirection
                local releaseTravel = releaseDelay and targetTravel or state.ShotTravel
                local releaseOffset = releaseDelay
                    and state.ShotStartOffset + releaseDirection * releaseTravel
                    or offset
                local stillShooting = character:GetAttribute("ReleasedShot") == false
                    and tostring(character:GetAttribute("Action") or "") == "Shooting"
                    and shootInputHeld()
                if stillShooting and releaseShoot() then
                    state.ReleasedThisShot = true
                    state.ForceNextGreen = false
                    state.PendingReleaseOffset = releaseOffset
                    state.PendingReleaseTravel = releaseTravel
                    state.PendingReleaseMeter = releaseMeter
                    state.PendingReleaseDirection = releaseDirection
                    state.LastRelease = string.format(
                        "%s at (%.5f, %.5f) | travel %.5f",
                        releaseMeter,
                        releaseOffset.X,
                        releaseOffset.Y,
                        releaseTravel
                    )
                    meterReleaseLabel.Text = "Release: " .. state.LastRelease
                    meterReleaseLabel.TextColor3 = COLORS.success
                else
                    state.LastRelease = "Shoot remote unavailable; retrying"
                    meterReleaseLabel.Text = "Release: Shoot remote unavailable; retrying"
                    meterReleaseLabel.TextColor3 = COLORS.error
                end
            end
        end

        if state.WasServerReleased == false and serverReleased == true
            and typeof(offset) == "Vector2" then
            state.LastShotOffset = offset
        end
        state.WasServerReleased = serverReleased ~= false
    end

    track(UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode ~= Enum.KeyCode.E and input.KeyCode ~= Enum.KeyCode.Space then
            return
        end
        local character = resolveCharacter()
        local offset = character and character:GetAttribute("meterOffset")
        if typeof(offset) == "Vector2" and not state.PendingReleaseOffset then
            state.PendingReleaseOffset = offset
            if typeof(state.ShotStartOffset) == "Vector2"
                and typeof(state.ShotDirection) == "Vector2" then
                state.PendingReleaseTravel = (offset - state.ShotStartOffset)
                    :Dot(state.ShotDirection)
            end
            state.PendingReleaseMeter = state.LastShotMeter
            state.PendingReleaseDirection = state.ShotDirection
            state.LastShotOffset = offset
        end
    end))

    local interfaceRemotes = remoteRoot and remoteRoot:FindFirstChild("InterfaceService")
    local showFeedbackRemote = interfaceRemotes and interfaceRemotes:FindFirstChild("ShowFeedback")
    if showFeedbackRemote and showFeedbackRemote:IsA("RemoteEvent") then
        local timingNames = {
            "Very Early",
            "Early",
            "Slightly Early",
            "Good",
            "Perfect",
            "Slightly Late",
            "Late",
            "Very Late",
        }
        track(showFeedbackRemote.OnClientEvent:Connect(function(feedbackCharacter, contest, timingIndex)
            local character = resolveCharacter()
            if feedbackCharacter ~= character then
                return
            end
            local index = tonumber(timingIndex)
            local timingName = timingNames[index] or "Unknown"
            state.LastFeedback = string.format(
                "%s Release | %d%% Contested",
                timingName,
                math.round(tonumber(contest) or 0)
            )
            local canLearnTravel = type(state.PendingReleaseTravel) == "number"
                or typeof(state.PendingReleaseOffset) == "Vector2"
                    and typeof(state.PendingReleaseDirection) == "Vector2"
                    and typeof(state.ShotStartOffset) == "Vector2"
            if canLearnTravel then
                local learnedMeter = state.PendingReleaseMeter or state.LastShotMeter
                local usedTravel = state.PendingReleaseTravel
                if type(usedTravel) ~= "number" then
                    usedTravel = (state.PendingReleaseOffset - state.ShotStartOffset)
                        :Dot(state.PendingReleaseDirection)
                end
                if index and index < 5 then
                    state.TargetLowerTravels[learnedMeter] = math.max(
                        state.TargetLowerTravels[learnedMeter] or 0,
                        usedTravel
                    )
                elseif index and index > 5 then
                    state.TargetUpperTravels[learnedMeter] = math.min(
                        state.TargetUpperTravels[learnedMeter] or math.huge,
                        usedTravel
                    )
                end

                local travelCorrection = ({
                    [1] = 0.01,
                    [2] = 0.003,
                    [3] = 0.001,
                    [4] = 0.0002,
                    [5] = 0,
                    [6] = -0.0002,
                    [7] = -0.003,
                    [8] = -0.01,
                })[index]
                if travelCorrection then
                    local nextTravel = usedTravel + travelCorrection
                    local lowerTravel = state.TargetLowerTravels[learnedMeter]
                    local upperTravel = state.TargetUpperTravels[learnedMeter]
                    if lowerTravel and upperTravel and lowerTravel <= upperTravel then
                        nextTravel = (lowerTravel + upperTravel) * 0.5
                    end
                    local fullOffset = state.FullOffsets[learnedMeter]
                    if typeof(fullOffset) == "Vector2" then
                        local fullTravel = (fullOffset - state.ShotStartOffset)
                            :Dot(state.PendingReleaseDirection)
                        nextTravel = math.min(nextTravel, fullTravel)
                    end
                    nextTravel = math.max(0, nextTravel)
                    state.PerfectTravels[learnedMeter] = nextTravel
                    state.PerfectOffsets[learnedMeter] = state.ShotStartOffset
                        + state.PendingReleaseDirection * nextTravel
                    state.LastTimingCorrection = string.format(
                        "%s %+.3f travel -> %.5f",
                        timingName,
                        travelCorrection,
                        nextTravel
                    )
                end
            end
            if index == 5 and typeof(state.PendingReleaseOffset) == "Vector2" then
                local learnedMeter = state.PendingReleaseMeter or state.LastShotMeter
                meterReleaseLabel.Text = state.ReleasedThisShot
                    and string.format(
                        "Perfect confirmed: %s",
                        state.LastRelease
                    )
                    or string.format(
                        "Manual Perfect %s: %.8f",
                        learnedMeter,
                        state.PendingReleaseOffset.Y
                    )
                meterReleaseLabel.TextColor3 = COLORS.success
            end
        end))
    end

    local function updateAutomation(character, now)
        local stamina = tonumber(character and character:GetAttribute("Stamina")) or 0
        local inGame = character and (character:GetAttribute("InGame") == true
            or character:GetAttribute("OnCourt") == true)

        if state.AutoSprint then
            setSprintHeld(movementInputHeld(character) and stamina >= state.SprintThreshold)
        elseif state.SprintHeld then
            setSprintHeld(false)
        end

        local carryingBasketball = hasBasketball(character)
        if state.AutoGuard and inGame and not carryingBasketball then
            local authoritativeGuard = character:GetAttribute("HoldingG")
            if authoritativeGuard ~= true or now >= state.GuardRefreshAt then
                setGuardHeld(true, true)
            end
        elseif state.GuardHeld then
            setGuardHeld(false, true)
        end

        if state.AutoScreen and inGame then
            setScreenHeld(true)
        elseif state.ScreenHeld then
            setScreenHeld(false)
        end

        if state.AutoSteal and inGame and now - state.LastSteal >= state.StealInterval then
            local opponent = nearestOpponent(state.StealRange, true)
            if opponent then
                state.LastSteal = now
                fireRemote("Steal")
            end
        end

        if state.AutoContest and inGame and now - state.LastContest >= 0.35 then
            local opponent = nearestOpponent(state.ContestRange, false)
            local action = opponent and tostring(opponent:GetAttribute("Action") or "") or ""
            local tokenValue = opponent and (opponent.Name .. ":" .. action .. ":"
                .. tostring(opponent:GetAttribute("ShotStartTime") or "")) or ""
            if opponent and (action == "Shooting" or action == "Dunking")
                and tokenValue ~= state.LastContestToken then
                state.LastContest = now
                state.LastContestToken = tokenValue
                fireRemote("Jump")
            end
        end

        if state.AutoRebound and inGame and now - state.LastRebound >= 0.40
            and not hasBasketball(character) then
            local ball = nearestActiveBall(state.ReboundRange)
            local root = resolveRoot(character)
            if ball and root and ball.Position.Y >= root.Position.Y + 1 then
                state.LastRebound = now
                fireRemote("Jump")
            end
        end

        if state.AutoDribble and inGame and hasBasketball(character) then
            local defender = nearestOpponent(state.DribbleRange, false)
            local triggerActive = state.DribbleTrigger == "Always" or defender ~= nil
            local action = tostring(character:GetAttribute("Action") or "")
            if not triggerActive then
                setSprintHeld(false)
                chainStatusLabel.Text = "Chain: Open | Defender outside "
                    .. tostring(state.DribbleRange) .. " studs"
            elseif now - state.LastCombo >= state.ComboInterval
                and (action == "" or action == "TripleThreat" or action == "Moving") then
                local fired, status, index, count = runNextDribbleStep(character)
                if count > 0 then
                    if fired then
                        state.LastCombo = now
                    end
                    chainStatusLabel.Text = string.format(
                        "Chain: %s | %s | %d/%d",
                        state.DribblePreset,
                        status,
                        index,
                        count
                    )
                end
            end
        elseif state.AutoDribble then
            chainStatusLabel.Text = "Chain: Waiting for possession"
        end
    end

    local function updateVisionAndStatus(character, now)
        local ball, ballDistance = nearestActiveBall(500)
        local opponent, opponentDistance = nearestOpponent(500, true)

        if state.CourtVision then
            ballHighlight.Adornee = ball
            ballHighlight.Enabled = ball ~= nil
            opponentHighlight.Adornee = opponent
            opponentHighlight.Enabled = opponent ~= nil
        end

        if now - state.LastStatus < 0.15 then
            return
        end
        state.LastStatus = now

        local action = character and tostring(character:GetAttribute("Action") or "") or "No character"
        local stamina = character and tonumber(character:GetAttribute("Stamina")) or 0
        local hasBall = hasBasketball(character)
        meterNameLabel.Text = "Meter: " .. state.MeterName
        meterNameLabel.TextColor3 = state.MeterName ~= "None" and COLORS.success or COLORS.muted
        local meterOffset = character and character:GetAttribute("meterOffset")
        local targetOffset = state.PerfectOffsets[state.LastShotMeter]
        meterProgressLabel.Text = typeof(meterOffset) == "Vector2"
            and string.format(
                "Offset Y: %.8f | Perfect: %s",
                meterOffset.Y,
                targetOffset and string.format("%.8f", targetOffset.Y) or "learning"
            )
            or "Offset: Waiting"
        meterStateLabel.Text = "Shot state: " .. action .. " | " .. state.LastFeedback
        playerStatusLabel.Text = string.format("Player: %s | Stamina: %.0f", action, stamina)
        ballStatusLabel.Text = ball
            and string.format("Active ball: %.1f studs", ballDistance)
            or "Active ball: None"
        opponentStatusLabel.Text = opponent
            and string.format("Ball handler: %s | %.1f studs", opponent.Name, opponentDistance)
            or "Ball handler: None"
        adapterStatusLabel.Text = string.format(
            "Adapter: %s | Ball: %s | Place: %s",
            inputRemotes and "Aero ready" or "Aero missing",
            hasBall and "Held" or "Not held",
            tostring(game.PlaceId)
        )

        pcall(function()
            gui:SetAttribute("PracticalBasketballMeter", state.MeterName)
            gui:SetAttribute(
                "PracticalBasketballMeterOffset",
                character and character:GetAttribute("meterOffset")
            )
            gui:SetAttribute("PracticalBasketballLastRelease", state.LastRelease)
            gui:SetAttribute("PracticalBasketballLastFeedback", state.LastFeedback)
            gui:SetAttribute("PracticalBasketballTimingCorrection", state.LastTimingCorrection)
            gui:SetAttribute("PracticalBasketballReleaseTravel", state.PerfectTravels[state.LastShotMeter])
            gui:SetAttribute("PracticalBasketballAction", action)
            gui:SetAttribute("PracticalBasketballHasBall", hasBall)
        end)
    end

    track(RunService.RenderStepped:Connect(function()
        if not state.Alive then
            return
        end
        local character = resolveCharacter()
        local now = os.clock()
        if character then
            updateShooting(character)
            updateAutomation(character, now)
        end
        updateVisionAndStatus(character, now)
        applyCamera()
    end))

    track(gui.Destroying:Connect(function()
        state.Alive = false
        state.AutoGreen = false
        state.ForceNextGreen = false
        setComboHotkey(false)
        fovOverride = false
        if fovConnection then
            fovConnection:Disconnect()
            fovConnection = nil
        end
        setSprintHeld(false)
        setGuardHeld(false, true)
        setScreenHeld(false)
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = originalFov
        end
        LocalPlayer.CameraMaxZoomDistance = originalZoom
    end))

    pcall(function()
        gui:SetAttribute("PracticalBasketballAdapter", true)
        gui:SetAttribute("PracticalBasketballUniverseId", 7529591378)
        gui:SetAttribute("PracticalBasketballCharacterPath", "workspace.Characters." .. LocalPlayer.Name)
        gui:SetAttribute("PracticalBasketballBallTag", "Basketballs")
        gui:SetAttribute("PracticalBasketballRemotePath", "ReplicatedStorage.Aero.AeroRemoteServices.InputService")
    end)
end
