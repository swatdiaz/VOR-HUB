-- Practical Basketball adapter for VOR Hub.
-- Universe 7529591378 uses Aero, workspace.Characters, and tagged basketballs.
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
        ReleasedThisShot = false,
        WasMeterActive = false,
        WasServerReleased = true,
        ShotToken = nil,
        ShotStartOffset = nil,
        ShotDirection = nil,
        ShotTravel = 0,
        LastShotOffset = nil,
        LastShotMeter = "Vertical",
        LastFeedback = "Waiting",
        PerfectOffsets = {
            -- Captured from a manual Perfect Release in Learn PB.
            Vertical = Vector2.new(0, -1.31517029),
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
        ComboInterval = 1.5,
        LastCombo = 0,

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

    local function resolveRoot(character)
        character = character or resolveCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
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

    local function setGuardHeld(held)
        held = held == true
        if state.GuardHeld == held then
            return
        end
        if fireRemote("HoldG", {HoldingG = held}) then
            state.GuardHeld = held
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

    local function movementInputHeld()
        return UserInputService:IsKeyDown(Enum.KeyCode.W)
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

    local meterNameLabel = MeterSection:AddLabel("Meter: Waiting")
    local meterProgressLabel = MeterSection:AddLabel("Charge: 0%")
    local meterReleaseLabel = MeterSection:AddLabel("Release: Disabled")
    local meterStateLabel = MeterSection:AddLabel("Shot state: Waiting")
    local comboLabel = ComboStatusSection:AddLabel("Combo: ZX | Manual")
    local playerStatusLabel = StatusSection:AddLabel("Player: Reading...")
    local ballStatusLabel = StatusSection:AddLabel("Ball: Reading...")
    local opponentStatusLabel = StatusSection:AddLabel("Opponent: Reading...")
    local adapterStatusLabel = StatusSection:AddLabel("Adapter: Aero remotes found")

    AutoGreenSection:AddToggle({
        Name = "Auto Green",
        Description = "Releases your held E or Space shot from the live Aero meter",
        Flag = "practical_basketball_auto_green",
        Default = false,
        Callback = function(enabled)
            state.AutoGreen = enabled
            state.ReleasedThisShot = false
            meterReleaseLabel.Text = enabled and "Release: Armed" or "Release: Disabled"
            meterReleaseLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        end,
    })
    AutoGreenSection:AddInput({
        Name = "Vertical Perfect Offset",
        Description = "Exact Learn PB Perfect Release offset; updates automatically after a manual perfect",
        Flag = "practical_basketball_vertical_perfect_offset",
        Placeholder = "-1.31517029",
        Default = "-1.31517029",
        Callback = function(value)
            local parsed = tonumber(value)
            if parsed then
                state.PerfectOffsets.Vertical = Vector2.new(0, parsed)
            end
        end,
    })
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
    AutoGreenSection:AddLabel("A manual Perfect Release teaches VOR the exact offset for that meter style.")

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
            setGuardHeld(enabled)
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
        Name = "Combo Input",
        Description = "Exact Aero dribble sequences; no fake move names",
        Flag = "practical_basketball_dribble_combo",
        Options = {"Z", "C", "V", "X", "ZX", "CX", "ZZ", "CC", "VV", "XX", "ZCX", "CVX"},
        Default = "ZX",
        Callback = function(value)
            state.Combo = tostring(value or "ZX")
            comboLabel.Text = "Combo: " .. state.Combo .. (state.AutoDribble and " | Auto" or " | Manual")
        end,
    })
    ComboSection:AddToggle({
        Name = "Auto Dribble Combo",
        Description = "Repeats the selected native combo while you hold the ball",
        Flag = "practical_basketball_auto_dribble",
        Default = false,
        Callback = function(enabled)
            state.AutoDribble = enabled
            state.LastCombo = 0
            comboLabel.Text = "Combo: " .. state.Combo .. (enabled and " | Auto" or " | Manual")
        end,
    })
    ComboSection:AddSlider({
        Name = "Combo Interval",
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
    ComboSection:AddButton({
        Name = "Run Combo Once",
        Callback = function()
            local character = resolveCharacter()
            fireRemote("Dribble", state.Combo, state.SprintHeld, currentMoveDirection(character))
        end,
    })
    ComboStatusSection:AddLabel("Z / C / V / X are the game's real keyboard dribble inputs.")
    ComboStatusSection:AddLabel("The server still validates stamina, possession, and animation state.")

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

    local function applyCamera()
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = cameraFov
        end
    end

    CameraSection:AddSlider({
        Name = "Camera FOV",
        Flag = "practical_basketball_camera_fov",
        Min = 50,
        Max = 110,
        Step = 1,
        Default = math.clamp(originalFov, 50, 110),
        Callback = function(value)
            cameraFov = tonumber(value) or originalFov
            applyCamera()
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
        task.defer(applyCamera)
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
        return UserInputService:IsKeyDown(Enum.KeyCode.E)
            or UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end

    local function resetShot(offset, token)
        state.ShotToken = token
        state.ShotStartOffset = typeof(offset) == "Vector2" and offset or nil
        state.ShotDirection = nil
        state.ShotTravel = 0
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
            end

            local target = state.PerfectOffsets[state.MeterName]
            if not target and state.ShotDirection then
                target = state.ShotStartOffset + state.ShotDirection * 0.11655831
            end
            local reachedTarget = false
            if target and state.ShotDirection then
                local targetTravel = (target - state.ShotStartOffset):Dot(state.ShotDirection)
                reachedTarget = targetTravel >= 0 and state.ShotTravel >= targetTravel
            elseif target then
                reachedTarget = (offset - target).Magnitude <= 0.002
            end

            if reachedTarget
                and not state.ReleasedThisShot
                and serverReleased == false
                and action == "Shooting"
                and shootInputHeld()
                and (state.AutoGreen or state.ForceNextGreen) then
                state.ReleasedThisShot = true
                state.ForceNextGreen = false
                if releaseShoot() then
                    state.LastRelease = string.format(
                        "%s at (%.5f, %.5f)",
                        state.MeterName,
                        offset.X,
                        offset.Y
                    )
                    meterReleaseLabel.Text = "Release: " .. state.LastRelease
                    meterReleaseLabel.TextColor3 = COLORS.success
                else
                    state.LastRelease = "Shoot remote unavailable"
                    meterReleaseLabel.Text = "Release: Shoot remote unavailable"
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
        if typeof(offset) == "Vector2" then
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
            if index == 5 and typeof(state.LastShotOffset) == "Vector2" then
                state.PerfectOffsets[state.LastShotMeter] = state.LastShotOffset
                meterReleaseLabel.Text = string.format(
                    "Calibrated %s: %.8f",
                    state.LastShotMeter,
                    state.LastShotOffset.Y
                )
                meterReleaseLabel.TextColor3 = COLORS.success
            end
        end))
    end

    local function updateAutomation(character, now)
        local stamina = tonumber(character and character:GetAttribute("Stamina")) or 0
        local inGame = character and (character:GetAttribute("InGame") == true
            or character:GetAttribute("OnCourt") == true)

        if state.AutoSprint and inGame then
            setSprintHeld(movementInputHeld() and stamina >= state.SprintThreshold)
        elseif state.SprintHeld then
            setSprintHeld(false)
        end

        if state.AutoGuard and inGame then
            setGuardHeld(true)
        elseif state.GuardHeld then
            setGuardHeld(false)
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
            and character:GetAttribute("Basketball") ~= true then
            local ball = nearestActiveBall(state.ReboundRange)
            local root = resolveRoot(character)
            if ball and root and ball.Position.Y >= root.Position.Y + 1 then
                state.LastRebound = now
                fireRemote("Jump")
            end
        end

        if state.AutoDribble and inGame and now - state.LastCombo >= state.ComboInterval
            and character:GetAttribute("Basketball") == true then
            local action = tostring(character:GetAttribute("Action") or "")
            if action == "" or action == "TripleThreat" or action == "Moving" then
                state.LastCombo = now
                fireRemote("Dribble", state.Combo, state.SprintHeld, currentMoveDirection(character))
            end
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
        local hasBall = character and character:GetAttribute("Basketball") == true
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
    end))

    track(gui.Destroying:Connect(function()
        state.Alive = false
        state.AutoGreen = false
        state.ForceNextGreen = false
        setSprintHeld(false)
        setGuardHeld(false)
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
