-- VOR Hub - Iron Man: Reimagined adapter
-- UniverseId 5813007850 | PlaceId 16929212566
--
-- Live client mapping confirmed the native IronMan controller, suit attributes,
-- and the Call/Piece/Flight/Weapon action surface. Buttons prefer the game's
-- own input path where client animation/state must stay synchronized; automation
-- only calls remotes whose native client already fires with the same arguments.

local SUIT_OPTIONS = {
    "Endosym",
    "HELIOS",
    "Mark 2",
    "Mark 3",
    "Mark 4",
    "Mark 6",
    "Mark 7",
    "Mark 9",
    "Mark 12",
    "Mark 14",
    "Mark 16",
    "Mark 20",
    "Mark 21",
    "Mark 23",
    "Mark 27",
    "Mark 28",
    "Mark 30",
    "Mark 31",
    "Mark 33",
    "Mark 39",
    "Mark 40",
    "Mark 42",
    "Mark 43",
    "Mark 85",
    "Prototype",
    "Scavver",
    "War Machine",
}

-- Confirmed from the live Info("SuitsData") response. These are enforced by
-- the server; the adapter reports ownership instead of pretending a remote call
-- can bypass the purchase.
local SUIT_GAME_PASSES = {
    ["War Machine"] = 773087650,
    Scavver = 773087650,
    ["Mark 85"] = 791792311,
    Endosym = 791792311,
}

return function(context)
    local Window = assert(context.Window, "Iron Man: Reimagined: Window is required")
    local createCategoryHomePage = assert(
        context.CreateCategoryHomePage,
        "Iron Man: Reimagined: category builder is required"
    )
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G
    local previousCleanup = runtimeEnvironment.__VORIronManReimaginedCleanup
    runtimeEnvironment.__VORIronManReimaginedCleanup = nil
    if type(previousCleanup) == "function" then
        pcall(previousCleanup)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LocalPlayer = Players.LocalPlayer

    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Characters = Assets and Assets:FindFirstChild("Characters")
    local IronMan = Characters and Characters:FindFirstChild("IronMan")
    local Events = IronMan and IronMan:FindFirstChild("Events")
    local Core = Assets and Assets:FindFirstChild("Core")
    local CoreModules = Core and Core:FindFirstChild("Modules")
    local FunctionsModule = CoreModules and CoreModules:FindFirstChild("Functions")

    local remotes = {}
    for _, name in ipairs({
        "Call",
        "Destruct",
        "Eject",
        "Flight",
        "Helmet",
        "HighAltitude",
        "Info",
        "Laser",
        "Mask",
        "Piece",
        "Sentry",
        "Weapon",
    }) do
        remotes[name] = Events and Events:FindFirstChild(name)
    end

    local nativeFunctions = nil
    if FunctionsModule and FunctionsModule:IsA("ModuleScript") then
        pcall(function()
            nativeFunctions = require(FunctionsModule)
        end)
    end

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local SuitPage = addHomeCategory("Suit", 1, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)
    local FlightPage = addHomeCategory("Flight", 2, CATEGORY_DECALS.Movement or CATEGORY_DECALS.Player)
    local CombatPage = addHomeCategory("Combat", 3, CATEGORY_DECALS.Combat)
    local VisualsPage = addHomeCategory("Visuals", 4, CATEGORY_DECALS.Visuals)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Progress)

    local SuitSelectionSection = SuitPage:AddSection("Suit Selection", "Left")
    local SuitActionsSection = SuitPage:AddSection("Suit Actions", "Right")
    local FlightActionsSection = FlightPage:AddSection("Native Flight", "Left")
    local FlightAutomationSection = FlightPage:AddSection("Flight Automation", "Right")
    local WeaponSection = CombatPage:AddSection("Weapons", "Left")
    local CombatAutomationSection = CombatPage:AddSection("Combat Assist", "Right")
    local EspSection = VisualsPage:AddSection("Player ESP", "Left")
    local CameraSection = VisualsPage:AddSection("Camera", "Right")
    local SuitStatusSection = StatusPage:AddSection("Live Suit", "Left")
    local AdapterStatusSection = StatusPage:AddSection("Adapter", "Right")

    local state = {
        Alive = true,
        SelectedSuit = "Mark 42",
        AutoRepair = false,
        AutoFlares = false,
        AutoFlight = false,
        FlightSpeedMultiplier = 1,
        FlightVelocity = nil,
        FlightNativeVelocity = nil,
        FlightAppliedVelocity = nil,
        AimAssist = false,
        AimPart = "Head",
        AimRadius = 260,
        AimStrength = 24,
        AimRange = 2500,
        WallCheck = true,
        TeamCheck = false,
        PlayerEsp = false,
        EspDistance = true,
        EspRange = 3500,
        NoCameraShake = false,
        LastRepair = 0,
        LastFlares = 0,
        LastAutoFlight = 0,
        CurrentTarget = nil,
        LastAction = "Ready",
        PassOwnership = {},
    }

    local originalCameraShake = nativeFunctions and nativeFunctions.canCameraShake
    local espRecords = {}

    local function notify(message, color)
        Window:Notify("Iron Man: Reimagined", message, 4, color or COLORS.accentBright)
    end

    local function getCharacter(player)
        player = player or LocalPlayer
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    local function getSuit(character)
        character = character or LocalPlayer.Character
        return character and character:FindFirstChild("Suit")
    end

    local function getSuitHumanoid(character)
        character = character or LocalPlayer.Character
        local skeleton = character and character:FindFirstChild("Skeleton")
        return skeleton and skeleton:FindFirstChildOfClass("Humanoid")
            or character and character:FindFirstChildOfClass("Humanoid")
    end

    local function clearFlightSpeedOverride()
        local velocity = state.FlightVelocity
        local nativeVelocity = state.FlightNativeVelocity
        if velocity and velocity.Parent and nativeVelocity then
            pcall(function()
                velocity.VectorVelocity = nativeVelocity
            end)
        end
        state.FlightVelocity = nil
        state.FlightNativeVelocity = nil
        state.FlightAppliedVelocity = nil
    end

    local function findNativeFlightVelocity(character)
        if not character then
            return nil
        end
        local characterPrimary = character.PrimaryPart
        local skeleton = character:FindFirstChild("Skeleton")
        local skeletonPrimary = skeleton and skeleton.PrimaryPart
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("LinearVelocity") and object.MaxForce >= 100000 then
                local attachment = object.Attachment0
                local bodyPart = attachment and attachment.Parent
                if bodyPart and (bodyPart == characterPrimary
                    or bodyPart == skeletonPrimary
                    or bodyPart.Name == "HumanoidRootPart") then
                    return object
                end
            end
        end
        return nil
    end

    local function isFiniteNumber(value)
        return type(value) == "number"
            and value == value
            and value > -math.huge
            and value < math.huge
    end

    local function parseFlightSpeedMultiplier(value)
        local multiplier = tonumber(value)
        if not isFiniteNumber(multiplier) then
            return nil
        end
        return math.max(1, multiplier)
    end

    local function isFiniteVelocity(velocity)
        return isFiniteNumber(velocity.X)
            and isFiniteNumber(velocity.Y)
            and isFiniteNumber(velocity.Z)
    end

    local function updateFlightSpeedOverride()
        local character = LocalPlayer.Character
        local suit = getSuit(character)
        local multiplier = parseFlightSpeedMultiplier(state.FlightSpeedMultiplier) or 1
        if multiplier <= 1 or not suit or suit:GetAttribute("Flight") ~= true then
            clearFlightSpeedOverride()
            return
        end

        local velocity = findNativeFlightVelocity(character)
        if velocity ~= state.FlightVelocity then
            clearFlightSpeedOverride()
            state.FlightVelocity = velocity
        end
        if not velocity then
            return
        end

        local currentVelocity = velocity.VectorVelocity
        local lastApplied = state.FlightAppliedVelocity
        local nativeVelocity = currentVelocity
        if lastApplied and (currentVelocity - lastApplied).Magnitude <= 0.05 then
            nativeVelocity = state.FlightNativeVelocity or currentVelocity
        end
        local appliedVelocity = nativeVelocity * multiplier
        if not isFiniteVelocity(appliedVelocity) then
            state.FlightSpeedMultiplier = 1
            state.LastAction = "Flight multiplier overflow; reset to 1x"
            clearFlightSpeedOverride()
            return
        end
        state.FlightNativeVelocity = nativeVelocity
        state.FlightAppliedVelocity = appliedVelocity
        velocity.VectorVelocity = state.FlightAppliedVelocity
    end

    local function fireRemote(name, ...)
        local remote = remotes[name]
        if not remote or not remote:IsA("RemoteEvent") then
            state.LastAction = name .. " remote missing"
            return false
        end
        local ok, result = pcall(remote.FireServer, remote, ...)
        state.LastAction = ok and name or (name .. " failed: " .. tostring(result))
        return ok
    end

    local function ownsGamePass(passId, refresh)
        if not passId then
            return true, true
        end
        if not refresh and state.PassOwnership[passId] ~= nil then
            return state.PassOwnership[passId], true
        end
        local ok, owned = pcall(
            MarketplaceService.UserOwnsGamePassAsync,
            MarketplaceService,
            LocalPlayer.UserId,
            passId
        )
        if ok then
            state.PassOwnership[passId] = owned == true
        end
        return ok and owned == true, ok
    end

    local function tapKey(keyCode)
        if typeof(keyCode) ~= "EnumItem" then
            return false
        end
        local ok, result = pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.04)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
        state.LastAction = ok and ("Pressed " .. keyCode.Name)
            or ("Input failed: " .. tostring(result))
        return ok
    end

    local function suitNeedsRepair()
        local character = LocalPlayer.Character
        local suit = getSuit(character)
        if not suit or suit:GetAttribute("Power") ~= true then
            return false
        end
        local suitHumanoid = getSuitHumanoid(character)
        if suitHumanoid and suitHumanoid.Health < suitHumanoid.MaxHealth - 1 then
            return true
        end
        for _, piece in ipairs(suit:GetChildren()) do
            if piece:IsA("Model") and piece:GetAttribute("Attached") == false then
                return true
            end
        end
        return false
    end

    local function incomingRocketExists()
        local character = LocalPlayer.Character
        if not character then
            return false
        end
        for _, object in ipairs(workspace.Terrain:GetChildren()) do
            if string.find(object.Name, "Rocket", 1, true)
                and object:GetAttribute("TargetName") == character.Name then
                return true
            end
        end
        return false
    end

    local function sameTeam(player)
        if not state.TeamCheck then
            return false
        end
        if LocalPlayer.Team ~= nil and player.Team ~= nil then
            return LocalPlayer.Team == player.Team
        end
        local ownTeam = LocalPlayer:GetAttribute("Team")
        local otherTeam = player:GetAttribute("Team")
        return ownTeam ~= nil and otherTeam ~= nil and ownTeam == otherTeam
    end

    local function targetPart(character)
        if not character then
            return nil
        end
        if state.AimPart == "Root" then
            return character:FindFirstChild("HumanoidRootPart")
        elseif state.AimPart == "Upper Torso" then
            return character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("Torso")
        end
        return character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
    end

    local function targetVisible(part)
        if not state.WallCheck then
            return true
        end
        local camera = workspace.CurrentCamera
        local character = LocalPlayer.Character
        if not camera or not part then
            return false
        end
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Exclude
        parameters.FilterDescendantsInstances = {character, camera}
        parameters.IgnoreWater = true
        local origin = camera.CFrame.Position
        local result = workspace:Raycast(origin, part.Position - origin, parameters)
        return result == nil or result.Instance:IsDescendantOf(part.Parent)
    end

    local function acquireTarget()
        local camera = workspace.CurrentCamera
        local _, _, ownRoot = getCharacter()
        if not camera or not ownRoot then
            return nil
        end
        local pointer = UserInputService:GetMouseLocation()
        local best, bestScreenDistance = nil, state.AimRadius
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not sameTeam(player) then
                local character, humanoid, root = getCharacter(player)
                local part = targetPart(character)
                if humanoid and humanoid.Health > 0 and root and part then
                    local worldDistance = (root.Position - ownRoot.Position).Magnitude
                    local screen, visible = camera:WorldToViewportPoint(part.Position)
                    local screenDistance = (Vector2.new(screen.X, screen.Y) - pointer).Magnitude
                    if visible and screen.Z > 0 and worldDistance <= state.AimRange
                        and screenDistance < bestScreenDistance and targetVisible(part) then
                        best = player
                        bestScreenDistance = screenDistance
                    end
                end
            end
        end
        return best
    end

    local function destroyEsp(player)
        local record = espRecords[player]
        if not record then
            return
        end
        for _, object in pairs(record) do
            if typeof(object) == "Instance" then
                object:Destroy()
            end
        end
        espRecords[player] = nil
    end

    local function ensureEsp(player)
        local character, humanoid, root = getCharacter(player)
        if not character or not humanoid or humanoid.Health <= 0 or not root then
            destroyEsp(player)
            return nil
        end
        local record = espRecords[player]
        if record and record.Character ~= character then
            destroyEsp(player)
            record = nil
        end
        if not record then
            local highlight = Instance.new("Highlight")
            highlight.Name = "VORIronManESP"
            highlight.FillColor = Color3.fromRGB(70, 170, 255)
            highlight.OutlineColor = Color3.fromRGB(210, 240, 255)
            highlight.FillTransparency = 0.7
            highlight.OutlineTransparency = 0.05
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = character
            highlight.Parent = character

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "VORIronManName"
            billboard.AlwaysOnTop = true
            billboard.Size = UDim2.fromOffset(220, 34)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
            billboard.Adornee = root
            billboard.Parent = root

            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextColor3 = Color3.fromRGB(225, 245, 255)
            label.TextStrokeTransparency = 0.35
            label.TextScaled = true
            label.Parent = billboard

            record = {
                Character = character,
                Highlight = highlight,
                Billboard = billboard,
                Label = label,
            }
            espRecords[player] = record
        end
        return record
    end

    local function updateEsp()
        local _, _, ownRoot = getCharacter()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local _, _, root = getCharacter(player)
                local distance = ownRoot and root and (root.Position - ownRoot.Position).Magnitude
                    or math.huge
                local show = state.PlayerEsp and not sameTeam(player) and distance <= state.EspRange
                if show then
                    local record = ensureEsp(player)
                    if record then
                        record.Highlight.Enabled = true
                        record.Billboard.Enabled = true
                        record.Label.Text = state.EspDistance
                            and string.format("%s  |  %dm", player.DisplayName, math.floor(distance))
                            or player.DisplayName
                    end
                else
                    destroyEsp(player)
                end
            end
        end
        for player in pairs(espRecords) do
            if player.Parent ~= Players then
                destroyEsp(player)
            end
        end
    end

    local suitLabel = SuitStatusSection:AddLabel("Suit: scanning...")
    local energyLabel = SuitStatusSection:AddLabel("Energy: --")
    local healthLabel = SuitStatusSection:AddLabel("Health: --")
    local modeLabel = SuitStatusSection:AddLabel("Mode: --")
    local piecesLabel = SuitStatusSection:AddLabel("Pieces: --")
    local targetLabel = CombatAutomationSection:AddLabel("Target: None")
    local flightSpeedLabel = FlightAutomationSection:AddLabel("Flight speed: native 1.0x")
    local actionLabel = AdapterStatusSection:AddLabel("Last action: Ready")
    local remoteLabel = AdapterStatusSection:AddLabel("Native remotes: scanning...")
    AdapterStatusSection:AddLabel("Verified live: Mark 42, 2000 suit HP, 100 base flight speed.")
    AdapterStatusSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))
    AdapterStatusSection:AddLabel("UniverseId: " .. tostring(game.GameId))

    local suitAccessLabel = SuitSelectionSection:AddLabel("Access: checking...")

    local function updateSelectedSuitAccess(refresh)
        local passId = SUIT_GAME_PASSES[state.SelectedSuit]
        if not passId then
            suitAccessLabel.Text = "Access: included suit"
            return true, nil
        end
        local owned, checked = ownsGamePass(passId, refresh)
        if not checked then
            suitAccessLabel.Text = "Access: ownership check failed | Pass " .. tostring(passId)
            return false, passId
        end
        suitAccessLabel.Text = owned
            and ("Access: owned | Pass " .. tostring(passId))
            or ("Access: LOCKED (Robux) | Pass " .. tostring(passId))
        return owned, passId
    end

    SuitSelectionSection:AddDropdown({
        Name = "Suit Model",
        Flag = "imr_selected_suit",
        Options = SUIT_OPTIONS,
        Default = "Mark 42",
        Callback = function(value)
            state.SelectedSuit = value or "Mark 42"
            updateSelectedSuitAccess(false)
        end,
    })
    SuitSelectionSection:AddButton({
        Name = "Call Selected Suit",
        Callback = function()
            local owned, passId = updateSelectedSuitAccess(true)
            if passId and not owned then
                state.LastAction = string.format("%s locked by pass %d", state.SelectedSuit, passId)
                notify(
                    string.format("%s requires Robux game pass %d", state.SelectedSuit, passId),
                    COLORS.warning
                )
                return
            end
            if fireRemote("Call", state.SelectedSuit) then
                notify("Calling " .. state.SelectedSuit, COLORS.success)
            else
                notify("Suit call remote is unavailable", COLORS.warning)
            end
        end,
    })
    SuitSelectionSection:AddButton({
        Name = "Buy Selected Suit Pass",
        Callback = function()
            local owned, passId = updateSelectedSuitAccess(true)
            if not passId then
                notify(state.SelectedSuit .. " does not require a suit game pass", COLORS.success)
                return
            end
            if owned then
                notify(state.SelectedSuit .. " pass is already owned", COLORS.success)
                return
            end
            local ok, result = pcall(
                MarketplaceService.PromptGamePassPurchase,
                MarketplaceService,
                LocalPlayer,
                passId
            )
            state.LastAction = ok and ("Opened pass " .. tostring(passId))
                or ("Purchase prompt failed: " .. tostring(result))
            if not ok then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    SuitSelectionSection:AddButton({
        Name = "Open Native Suit Menu",
        Callback = function()
            tapKey(Enum.KeyCode.Q)
        end,
    })

    SuitActionsSection:AddButton({Name = "Repair All", Callback = function() fireRemote("Piece", "RepairAll") end})
    SuitActionsSection:AddButton({Name = "Toggle Mask", Callback = function() tapKey(Enum.KeyCode.M) end})
    SuitActionsSection:AddButton({Name = "Toggle Helmet", Callback = function() tapKey(Enum.KeyCode.Backspace) end})
    SuitActionsSection:AddButton({Name = "Toggle Sentry", Callback = function() tapKey(Enum.KeyCode.K) end})
    SuitActionsSection:AddButton({Name = "Eject Suit", Callback = function() tapKey(Enum.KeyCode.N) end})
    SuitActionsSection:AddButton({Name = "Destruct Ejected Suit", Callback = function() tapKey(Enum.KeyCode.X) end})
    SuitActionsSection:AddToggle({
        Name = "Auto Repair",
        Description = "Uses the native RepairAll request only when HP or an attached piece needs repair.",
        Flag = "imr_auto_repair",
        Default = false,
        Callback = function(value)
            state.AutoRepair = value == true
        end,
    })

    FlightActionsSection:AddButton({Name = "Toggle Flight", Callback = function() tapKey(Enum.KeyCode.F) end})
    FlightActionsSection:AddButton({Name = "Supersonic Boost", Callback = function() tapKey(Enum.KeyCode.B) end})
    FlightActionsSection:AddButton({Name = "Deploy Flares", Callback = function() tapKey(Enum.KeyCode.C) end})
    FlightActionsSection:AddButton({Name = "Dash", Callback = function() tapKey(Enum.KeyCode.LeftControl) end})
    FlightAutomationSection:AddInput({
        Name = "Flight Speed Multiplier",
        Description = "Type any finite multiplier. Huge values can make Roblox physics violently stupid.",
        Flag = "imr_flight_speed_multiplier",
        Default = "1",
        Placeholder = "Example: 10, 100, 1000",
        Callback = function(value)
            local multiplier = parseFlightSpeedMultiplier(value)
            if not multiplier then
                state.FlightSpeedMultiplier = 1
                clearFlightSpeedOverride()
                notify("Flight multiplier must be a finite number; reset to 1x", COLORS.warning)
                return
            end
            state.FlightSpeedMultiplier = multiplier
            if state.FlightSpeedMultiplier <= 1 then
                clearFlightSpeedOverride()
            end
        end,
    })
    FlightAutomationSection:AddToggle({
        Name = "Auto Flight",
        Description = "Re-enables native flight after suit/character transitions when the suit is powered.",
        Flag = "imr_auto_flight",
        Default = false,
        Callback = function(value)
            state.AutoFlight = value == true
        end,
    })
    FlightAutomationSection:AddToggle({
        Name = "Auto Flares",
        Description = "Matches the native incoming-rocket TargetName check and respects the 10-second cooldown.",
        Flag = "imr_auto_flares",
        Default = false,
        Callback = function(value)
            state.AutoFlares = value == true
        end,
    })

    WeaponSection:AddButton({Name = "Fire Left", Callback = function() tapKey(Enum.KeyCode.Q) end})
    WeaponSection:AddButton({Name = "Fire Right", Callback = function() tapKey(Enum.KeyCode.E) end})
    WeaponSection:AddButton({Name = "Fire Center", Callback = function() tapKey(Enum.KeyCode.R) end})
    WeaponSection:AddButton({Name = "Cycle Left Weapon", Callback = function() tapKey(Enum.KeyCode.G) end})
    WeaponSection:AddButton({Name = "Cycle Right Weapon", Callback = function() tapKey(Enum.KeyCode.H) end})
    WeaponSection:AddButton({Name = "Cycle Center Weapon", Callback = function() tapKey(Enum.KeyCode.J) end})
    WeaponSection:AddButton({Name = "Microguns", Callback = function() tapKey(Enum.KeyCode.V) end})

    CombatAutomationSection:AddToggle({
        Name = "Aim Assist",
        Description = "Smoothly steers the camera toward the closest visible player near the cursor.",
        Flag = "imr_aim_assist",
        Default = false,
        Callback = function(value)
            state.AimAssist = value == true
            if not state.AimAssist then
                state.CurrentTarget = nil
            end
        end,
    })
    CombatAutomationSection:AddDropdown({
        Name = "Target Part",
        Flag = "imr_aim_part",
        Options = {"Head", "Upper Torso", "Root"},
        Default = "Head",
        Callback = function(value)
            state.AimPart = value or "Head"
        end,
    })
    CombatAutomationSection:AddSlider({
        Name = "Aim Radius",
        Flag = "imr_aim_radius",
        Min = 40,
        Max = 700,
        Step = 10,
        Default = 260,
        Suffix = " px",
        Callback = function(value)
            state.AimRadius = tonumber(value) or 260
        end,
    })
    CombatAutomationSection:AddSlider({
        Name = "Aim Strength",
        Flag = "imr_aim_strength",
        Min = 1,
        Max = 100,
        Step = 1,
        Default = 24,
        Suffix = "%",
        Callback = function(value)
            state.AimStrength = tonumber(value) or 24
        end,
    })
    CombatAutomationSection:AddToggle({Name = "Wall Check", Flag = "imr_wall_check", Default = true, Callback = function(value) state.WallCheck = value == true end})
    CombatAutomationSection:AddToggle({Name = "Team Check", Flag = "imr_team_check", Default = false, Callback = function(value) state.TeamCheck = value == true end})

    EspSection:AddToggle({Name = "Player ESP", Flag = "imr_player_esp", Default = false, Callback = function(value) state.PlayerEsp = value == true end})
    EspSection:AddToggle({Name = "Show Distance", Flag = "imr_esp_distance", Default = true, Callback = function(value) state.EspDistance = value == true end})
    EspSection:AddSlider({Name = "ESP Range", Flag = "imr_esp_range", Min = 100, Max = 10000, Step = 100, Default = 3500, Suffix = "m", Callback = function(value) state.EspRange = tonumber(value) or 3500 end})
    CameraSection:AddToggle({
        Name = "Disable Camera Shake",
        Flag = "imr_no_camera_shake",
        Default = false,
        Callback = function(value)
            state.NoCameraShake = value == true
            if nativeFunctions then
                nativeFunctions.canCameraShake = not state.NoCameraShake
            end
        end,
    })

    local function updateStatus()
        local character = LocalPlayer.Character
        local suit = getSuit(character)
        local humanoid = getSuitHumanoid(character)
        local attached, total = 0, 0
        if suit then
            for _, piece in ipairs(suit:GetChildren()) do
                if piece:IsA("Model") then
                    total = total + 1
                    if piece:GetAttribute("Attached") == true then
                        attached = attached + 1
                    end
                end
            end
        end
        suitLabel.Text = "Suit: " .. tostring(suit and suit:GetAttribute("Model") or "None")
        energyLabel.Text = string.format("Energy: %.1f", tonumber(suit and suit:GetAttribute("Energy")) or 0)
        healthLabel.Text = humanoid and string.format("Health: %.0f / %.0f", humanoid.Health, humanoid.MaxHealth)
            or "Health: --"
        modeLabel.Text = suit and string.format(
            "Power %s | Flight %s | Sentry %s | Ejected %s",
            suit:GetAttribute("Power") and "ON" or "OFF",
            suit:GetAttribute("Flight") and "ON" or "OFF",
            suit:GetAttribute("Sentry") and "ON" or "OFF",
            suit:GetAttribute("Ejected") and "YES" or "NO"
        ) or "Mode: no suit"
        piecesLabel.Text = string.format("Pieces attached: %d / %d", attached, total)
        targetLabel.Text = "Target: " .. (state.CurrentTarget and state.CurrentTarget.DisplayName or "None")
        local _, _, root = getCharacter()
        flightSpeedLabel.Text = string.format(
            "Flight speed: %.0f studs/s | %.3gx",
            root and root.AssemblyLinearVelocity.Magnitude or 0,
            state.FlightSpeedMultiplier
        )
        actionLabel.Text = "Last action: " .. state.LastAction
        local ready, count = 0, 0
        for _, remote in pairs(remotes) do
            count = count + 1
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                ready = ready + 1
            end
        end
        remoteLabel.Text = string.format("Native remotes: %d / %d ready", ready, count)
        pcall(function()
            gui:SetAttribute("IronManReimaginedModuleReady", true)
            gui:SetAttribute("IronManSuit", suit and suit:GetAttribute("Model") or "None")
            gui:SetAttribute("IronManEnergy", tonumber(suit and suit:GetAttribute("Energy")) or 0)
            gui:SetAttribute("IronManPower", suit and suit:GetAttribute("Power") == true or false)
            gui:SetAttribute("IronManFlight", suit and suit:GetAttribute("Flight") == true or false)
            gui:SetAttribute("IronManFlightSpeedMultiplier", state.FlightSpeedMultiplier)
            gui:SetAttribute("IronManAttachedPieces", attached)
            gui:SetAttribute("IronManTotalPieces", total)
        end)
    end

    runtimeEnvironment.__VORIronManReimaginedCleanup = function()
        if not state.Alive then
            return
        end
        state.Alive = false
        state.AutoRepair = false
        state.AutoFlares = false
        state.AutoFlight = false
        state.FlightSpeedMultiplier = 1
        clearFlightSpeedOverride()
        state.AimAssist = false
        state.PlayerEsp = false
        if nativeFunctions then
            nativeFunctions.canCameraShake = originalCameraShake ~= false
        end
        for player in pairs(espRecords) do
            destroyEsp(player)
        end
    end

    track(Players.PlayerRemoving:Connect(destroyEsp))
    track(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        if player == LocalPlayer and SUIT_GAME_PASSES[state.SelectedSuit] == passId then
            if purchased then
                state.PassOwnership[passId] = true
                state.LastAction = "Purchased pass " .. tostring(passId)
            end
            updateSelectedSuitAccess(true)
        end
    end))
    if gui then
        track(gui.Destroying:Connect(function()
            local cleanup = runtimeEnvironment.__VORIronManReimaginedCleanup
            runtimeEnvironment.__VORIronManReimaginedCleanup = nil
            if type(cleanup) == "function" then
                cleanup()
            end
        end))
    end

    local statusAccumulator = 0
    local espAccumulator = 0
    local automationAccumulator = 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then
            return
        end

        updateFlightSpeedOverride()

        if state.AimAssist then
            local camera = workspace.CurrentCamera
            local target = acquireTarget()
            local part = target and targetPart(target.Character)
            state.CurrentTarget = target
            if camera and part then
                local alpha = math.clamp((state.AimStrength / 100) * deltaTime * 10, 0, 1)
                camera.CFrame = camera.CFrame:Lerp(
                    CFrame.lookAt(camera.CFrame.Position, part.Position),
                    alpha
                )
            end
        else
            state.CurrentTarget = nil
        end

        espAccumulator = espAccumulator + deltaTime
        statusAccumulator = statusAccumulator + deltaTime
        automationAccumulator = automationAccumulator + deltaTime

        if espAccumulator >= 0.1 then
            espAccumulator = 0
            updateEsp()
        end
        if statusAccumulator >= 0.25 then
            statusAccumulator = 0
            updateStatus()
        end
        if automationAccumulator >= 0.2 then
            automationAccumulator = 0
            local now = os.clock()
            local suit = getSuit()
            if state.AutoRepair and now - state.LastRepair >= 5 and suitNeedsRepair() then
                state.LastRepair = now
                fireRemote("Piece", "RepairAll")
            end
            if state.AutoFlares and now - state.LastFlares >= 10 and incomingRocketExists() then
                state.LastFlares = now
                fireRemote("Flight", "Flares")
            end
            if state.AutoFlight and suit and suit:GetAttribute("Power") == true
                and suit:GetAttribute("Ejected") ~= true and suit:GetAttribute("Flight") ~= true
                and now - state.LastAutoFlight >= 3 then
                state.LastAutoFlight = now
                tapKey(Enum.KeyCode.F)
            end
        end
    end))

    updateSelectedSuitAccess(false)
    updateStatus()
    updateEsp()
    selectHomeCategory("Suit")
    pcall(function()
        gui:SetAttribute("IronManReimaginedModuleReady", true)
        gui:SetAttribute("IronManReimaginedUniverseId", 5813007850)
        gui:SetAttribute("IronManReimaginedPlaceId", 16929212566)
    end)
    notify("Iron Man module ready", COLORS.success)
end
