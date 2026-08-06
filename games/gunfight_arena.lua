-- VOR Hub - Gunfight Arena adapter
-- UniverseId 5012222382 | PlaceId 15514727567
--
-- The adapter deliberately uses the game's replicated Vortex modifiers,
-- custom Team attribute, MovementData module, and GameInfo values. Every
-- feature is capability checked so a round transition cannot kill the UI.

return function(context)
    local Window = assert(context.Window, "Gunfight Arena: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Gunfight Arena: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = Players.LocalPlayer

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local CombatPage = addHomeCategory("Combat", 1, CATEGORY_DECALS.Combat)
    local WeaponPage = addHomeCategory("Weapon", 2, CATEGORY_DECALS.Mastery or CATEGORY_DECALS.Combat)
    local VisualsPage = addHomeCategory("Visuals", 3, CATEGORY_DECALS.Visuals)
    local PlayerPage = addHomeCategory("Player", 4, CATEGORY_DECALS.Player)
    local WorldPage = addHomeCategory("World", 5, CATEGORY_DECALS.Progress)

    local AimSection = CombatPage:AddSection("Aim Assist", "Left")
    local TargetSection = CombatPage:AddSection("Targeting", "Right")
    local RecoilSection = WeaponPage:AddSection("Weapon Handling", "Left")
    local CameraSection = WeaponPage:AddSection("Camera", "Right")
    local EspSection = VisualsPage:AddSection("Player ESP", "Left")
    local LightingSection = VisualsPage:AddSection("Visibility", "Right")
    local MovementSection = PlayerPage:AddSection("Movement", "Left")
    local PlayerStatusSection = PlayerPage:AddSection("Player Status", "Right")
    local MatchSection = WorldPage:AddSection("Current Match", "Left")
    local ServerSection = WorldPage:AddSection("Server", "Right")

    local state = {
        Alive = true,
        AimAssist = false,
        AimActivation = "While Aiming",
        AimPart = "Head",
        AimRadius = 180,
        AimStrength = 22,
        TeamCheck = true,
        WallCheck = true,
        ShowFov = true,
        NoRecoil = false,
        NoWeaponSway = false,
        CameraFovOverride = false,
        CameraFov = 80,
        ThirdPerson = false,
        EnemyEsp = false,
        EspNames = true,
        EspDistance = true,
        EspHealth = true,
        EspThroughWalls = true,
        EspMaxDistance = 1500,
        Fullbright = false,
        MovementOverride = false,
        WalkSpeed = 12,
        RunSpeed = 28,
        JumpBoost = 0.6,
        IsAiming = false,
        IsFiring = false,
        CurrentTarget = nil,
    }

    local defaults = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        CameraFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
    }

    local function notify(message, color)
        Window:Notify("Gunfight Arena", message, 4, color or COLORS.accentBright)
    end

    local function getCharacter(player)
        player = player or LocalPlayer
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    local function isAlive(player)
        local character, humanoid, root = getCharacter(player)
        return character ~= nil and humanoid ~= nil and humanoid.Health > 0 and root ~= nil
    end

    local function sameTeam(player)
        local localTeam = LocalPlayer:GetAttribute("Team")
        local otherTeam = player:GetAttribute("Team")
        if localTeam ~= nil and otherTeam ~= nil then
            return localTeam == otherTeam
        end
        return LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team
    end

    local function isEnemy(player)
        return player ~= LocalPlayer and isAlive(player) and (not state.TeamCheck or not sameTeam(player))
    end

    local function getTargetPart(character)
        if not character then
            return nil
        end
        if state.AimPart == "Head" then
            return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        elseif state.AimPart == "Upper Torso" then
            return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        end
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    end

    local function hasLineOfSight(targetPart)
        if not state.WallCheck then
            return true
        end
        local camera = workspace.CurrentCamera
        if not camera or not targetPart then
            return false
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if LocalPlayer.Character then
            ignore[#ignore + 1] = LocalPlayer.Character
        end
        local viewModel = workspace:FindFirstChild("ViewModel")
        if viewModel then
            ignore[#ignore + 1] = viewModel
        end
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        local origin = camera.CFrame.Position
        local result = workspace:Raycast(origin, targetPart.Position - origin, params)
        return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
    end

    local function acquireTarget()
        local camera = workspace.CurrentCamera
        if not camera then
            return nil
        end
        local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
        local bestPlayer = nil
        local bestDistance = state.AimRadius
        for _, player in ipairs(Players:GetPlayers()) do
            if isEnemy(player) then
                local part = getTargetPart(player.Character)
                if part then
                    local viewport, visible = camera:WorldToViewportPoint(part.Position)
                    if visible and viewport.Z > 0 then
                        local distance = (Vector2.new(viewport.X, viewport.Y) - center).Magnitude
                        if distance < bestDistance and hasLineOfSight(part) then
                            bestDistance = distance
                            bestPlayer = player
                        end
                    end
                end
            end
        end
        return bestPlayer
    end

    local function aimIsActive()
        if not state.AimAssist then
            return false
        end
        if state.AimActivation == "Always" then
            return true
        elseif state.AimActivation == "While Firing" then
            return state.IsFiring
        end
        return state.IsAiming
    end

    local function applyAimAssist(deltaTime)
        if not aimIsActive() then
            state.CurrentTarget = nil
            return
        end
        local target = acquireTarget()
        state.CurrentTarget = target
        local part = target and getTargetPart(target.Character)
        local camera = workspace.CurrentCamera
        if not camera or not part then
            return
        end
        local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
        local rate = math.clamp(state.AimStrength / 100, 0.01, 1)
        local alpha = 1 - math.pow(1 - rate, math.max(deltaTime, 1 / 240) * 60)
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    end

    local overlayGui = Instance.new("Frame")
    overlayGui.Name = "VORGunfightOverlay"
    overlayGui.Size = UDim2.fromScale(1, 1)
    overlayGui.Position = UDim2.fromScale(0, 0)
    overlayGui.BackgroundTransparency = 1
    overlayGui.BorderSizePixel = 0
    overlayGui.ZIndex = 50
    overlayGui.Parent = gui

    local fovCircle = Instance.new("Frame")
    fovCircle.Name = "AimRadius"
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.ZIndex = 50
    fovCircle.Visible = false
    fovCircle.Parent = overlayGui
    local fovCorner = Instance.new("UICorner")
    fovCorner.CornerRadius = UDim.new(1, 0)
    fovCorner.Parent = fovCircle
    local fovStroke = Instance.new("UIStroke")
    fovStroke.Color = COLORS.accentBright or Color3.fromRGB(168, 85, 247)
    fovStroke.Thickness = 1.25
    fovStroke.Transparency = 0.25
    fovStroke.Parent = fovCircle

    local function updateFovCircle()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local diameter = state.AimRadius * 2
        fovCircle.Size = UDim2.fromOffset(diameter, diameter)
        fovCircle.Position = UDim2.fromOffset(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
        fovCircle.Visible = state.AimAssist and state.ShowFov
        fovStroke.Color = state.CurrentTarget and (COLORS.success or Color3.fromRGB(52, 211, 153))
            or (COLORS.accentBright or Color3.fromRGB(168, 85, 247))
    end

    local function getVortexModifiers()
        local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local vortex = scripts and scripts:FindFirstChild("Vortex")
        return vortex and vortex:FindFirstChild("Modifiers")
    end

    local function applyWeaponModifiers()
        local modifiers = getVortexModifiers()
        if not modifiers then
            return
        end
        if state.NoRecoil then
            for _, name in ipairs({"CameraMod", "CameraMod2", "Impulse"}) do
                local value = modifiers:FindFirstChild(name)
                if value and value:IsA("CFrameValue") then
                    value.Value = CFrame.new()
                end
            end
            local steadiness = modifiers:FindFirstChild("Steadiness")
            if steadiness and steadiness:IsA("NumberValue") then
                steadiness.Value = 100
            end
        end
        if state.NoWeaponSway then
            local weaponMod = modifiers:FindFirstChild("WeaponMod")
            if weaponMod and weaponMod:IsA("CFrameValue") then
                weaponMod.Value = CFrame.new()
            end
        end
        local thirdPerson = modifiers:FindFirstChild("IsThirdPerson")
        if thirdPerson and thirdPerson:IsA("BoolValue") then
            thirdPerson.Value = state.ThirdPerson
        end
    end

    local espRecords = {}

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
        if player == LocalPlayer then
            return nil
        end
        local character, humanoid, root = getCharacter(player)
        if not character or not humanoid or not root then
            destroyEsp(player)
            return nil
        end
        local record = espRecords[player]
        if record and record.Character == character then
            return record
        end
        destroyEsp(player)

        local highlight = Instance.new("Highlight")
        highlight.Name = "VORGunfightHighlight"
        highlight.FillTransparency = 0.72
        highlight.OutlineTransparency = 0
        highlight.Adornee = character
        highlight.Parent = character

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "VORGunfightTag"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(220, 42)
        billboard.StudsOffset = Vector3.new(0, 3.2, 0)
        billboard.Adornee = character:FindFirstChild("Head") or root
        billboard.Parent = character

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextStrokeTransparency = 0.35
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextWrapped = true
        label.Parent = billboard

        record = {
            Character = character,
            Humanoid = humanoid,
            Root = root,
            Highlight = highlight,
            Billboard = billboard,
            Label = label,
        }
        espRecords[player] = record
        return record
    end

    local function updateEsp()
        local _, _, localRoot = getCharacter(LocalPlayer)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if state.EnemyEsp and isEnemy(player) then
                    local record = ensureEsp(player)
                    if record then
                        local distance = localRoot and (record.Root.Position - localRoot.Position).Magnitude or 0
                        local visible = distance <= state.EspMaxDistance and record.Humanoid.Health > 0
                        record.Highlight.Enabled = visible
                        record.Highlight.DepthMode = state.EspThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop
                            or Enum.HighlightDepthMode.Occluded
                        record.Highlight.FillColor = COLORS.error or Color3.fromRGB(255, 72, 96)
                        record.Highlight.OutlineColor = Color3.fromRGB(255, 220, 230)
                        record.Billboard.Enabled = visible and (state.EspNames or state.EspDistance or state.EspHealth)
                        local chunks = {}
                        if state.EspNames then
                            chunks[#chunks + 1] = player.DisplayName
                        end
                        if state.EspDistance then
                            chunks[#chunks + 1] = tostring(math.floor(distance + 0.5)) .. "m"
                        end
                        if state.EspHealth then
                            chunks[#chunks + 1] = tostring(math.max(0, math.floor(record.Humanoid.Health + 0.5))) .. " HP"
                        end
                        record.Label.Text = table.concat(chunks, "  |  ")
                    end
                else
                    destroyEsp(player)
                end
            end
        end
    end

    local movementData
    pcall(function()
        movementData = require(ReplicatedStorage:WaitForChild("MovementData"))
    end)
    local movementDefaults = {
        WalkSpeed = movementData and movementData.WalkSpeed or 12,
        RunSpeed = movementData and movementData.RunSpeed or 28,
        JumpBoost = movementData and movementData.JumpBoost or 0.6,
    }

    local function applyMovement()
        if not movementData then
            return
        end
        if state.MovementOverride then
            movementData.WalkSpeed = state.WalkSpeed
            movementData.RunSpeed = state.RunSpeed
            movementData.JumpBoost = state.JumpBoost
        end
    end

    local function resetMovement()
        if not movementData then
            return
        end
        movementData.WalkSpeed = movementDefaults.WalkSpeed
        movementData.RunSpeed = movementDefaults.RunSpeed
        movementData.JumpBoost = movementDefaults.JumpBoost
    end

    local function setFullbright(enabled)
        if enabled then
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = defaults.Brightness
            Lighting.ClockTime = defaults.ClockTime
            Lighting.FogEnd = defaults.FogEnd
            Lighting.GlobalShadows = defaults.GlobalShadows
        end
    end

    local statusLabels = {
        Player = PlayerStatusSection:AddLabel("Reading player data..."),
        Loadout = PlayerStatusSection:AddLabel("Loadout: loading..."),
        Record = PlayerStatusSection:AddLabel("Record: loading..."),
        Match = MatchSection:AddLabel("Match: loading..."),
        Clock = MatchSection:AddLabel("Clock: loading..."),
        Target = TargetSection:AddLabel("Target: None"),
    }

    local function valueFrom(container, name, fallback)
        local object = container and container:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            return object.Value
        end
        return fallback
    end

    local function formatClock(seconds)
        seconds = math.max(0, tonumber(seconds) or 0)
        return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end

    local function updateStatus()
        local info = workspace:FindFirstChild("GameInfo")
        local mode = valueFrom(info, "Mode", "Unknown")
        local map = valueFrom(info, "CurrentMap", "Unknown")
        local clock = valueFrom(info, "Clock", 0)
        local level = LocalPlayer:GetAttribute("Level") or LocalPlayer:GetAttribute("LevelKills") or 0
        local kills = LocalPlayer:GetAttribute("GameKills") or 0
        local deaths = LocalPlayer:GetAttribute("GameDeaths") or 0
        local streak = LocalPlayer:GetAttribute("Streak") or 0
        local primary = LocalPlayer:GetAttribute("Primary") or "None"
        local secondary = LocalPlayer:GetAttribute("Secondary") or "None"
        statusLabels.Player.Text = string.format("Level %s  |  Coins %s", tostring(level), tostring(LocalPlayer:GetAttribute("Coins") or 0))
        statusLabels.Loadout.Text = string.format("Loadout: %s + %s", tostring(primary), tostring(secondary))
        statusLabels.Record.Text = string.format("Kills %s  |  Deaths %s  |  Streak %s", tostring(kills), tostring(deaths), tostring(streak))
        statusLabels.Match.Text = string.format("%s  |  %s", tostring(mode), tostring(map))
        statusLabels.Clock.Text = "Time left: " .. formatClock(clock)
        statusLabels.Target.Text = "Target: " .. (state.CurrentTarget and state.CurrentTarget.DisplayName or "None")
    end

    local function handleInput(input, began)
        if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
            state.IsAiming = began
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
            state.IsFiring = began
        end
    end

    local function buildCombatControls()
        AimSection:AddToggle({
            Name = "Aim Assist",
            Description = "Camera assistance using the game's center-screen FPS aim point. Always mode works on mobile.",
            Flag = "gfa_aim_assist",
            Default = false,
            Callback = function(value)
                state.AimAssist = value
            end,
        })
        AimSection:AddDropdown({
            Name = "Activation",
            Flag = "gfa_aim_activation",
            Options = {"While Aiming", "While Firing", "Always"},
            Default = "While Aiming",
            Callback = function(value)
                state.AimActivation = value or "While Aiming"
            end,
        })
        AimSection:AddSlider({
            Name = "Aim Strength",
            Flag = "gfa_aim_strength",
            Min = 1,
            Max = 100,
            Step = 1,
            Default = 22,
            Suffix = "%",
            Callback = function(value)
                state.AimStrength = tonumber(value) or 22
            end,
        })
        AimSection:AddSlider({
            Name = "Aim Radius",
            Flag = "gfa_aim_radius",
            Min = 30,
            Max = 600,
            Step = 5,
            Default = 180,
            Suffix = " px",
            Callback = function(value)
                state.AimRadius = tonumber(value) or 180
            end,
        })
        AimSection:AddToggle({Name = "Show Aim Radius", Flag = "gfa_show_aim_radius", Default = true, Callback = function(value) state.ShowFov = value end})

        TargetSection:AddDropdown({
            Name = "Target Part",
            Flag = "gfa_target_part",
            Options = {"Head", "Upper Torso", "Root"},
            Default = "Head",
            Callback = function(value)
                state.AimPart = value or "Head"
            end,
        })
        TargetSection:AddToggle({Name = "Team Check", Flag = "gfa_team_check", Default = true, Callback = function(value) state.TeamCheck = value end})
        TargetSection:AddToggle({Name = "Wall Check", Flag = "gfa_wall_check", Default = true, Callback = function(value) state.WallCheck = value end})
    end

    local function buildWeaponControls()
        RecoilSection:AddToggle({Name = "No Camera Recoil", Flag = "gfa_no_recoil", Default = false, Callback = function(value) state.NoRecoil = value end})
        RecoilSection:AddToggle({Name = "No Weapon Sway", Flag = "gfa_no_weapon_sway", Default = false, Callback = function(value) state.NoWeaponSway = value end})
        RecoilSection:AddParagraph({
            Title = "Native integration",
            Content = "These controls use Vortex Modifiers instead of cloning or replacing your weapon model.",
        })

        CameraSection:AddToggle({
            Name = "FOV Override",
            Flag = "gfa_camera_fov_override",
            Default = false,
            Callback = function(value)
                state.CameraFovOverride = value
                if not value and workspace.CurrentCamera then
                    workspace.CurrentCamera.FieldOfView = defaults.CameraFov
                end
            end,
        })
        CameraSection:AddSlider({Name = "Camera FOV", Flag = "gfa_camera_fov", Min = 50, Max = 120, Step = 1, Default = 80, Callback = function(value) state.CameraFov = tonumber(value) or 80 end})
        CameraSection:AddToggle({Name = "Third Person", Flag = "gfa_third_person", Default = false, Callback = function(value) state.ThirdPerson = value end})
    end

    local function buildVisualControls()
        EspSection:AddToggle({Name = "Enemy ESP", Flag = "gfa_enemy_esp", Default = false, Callback = function(value) state.EnemyEsp = value end})
        EspSection:AddToggle({Name = "Names", Flag = "gfa_esp_names", Default = true, Callback = function(value) state.EspNames = value end})
        EspSection:AddToggle({Name = "Distance", Flag = "gfa_esp_distance", Default = true, Callback = function(value) state.EspDistance = value end})
        EspSection:AddToggle({Name = "Health", Flag = "gfa_esp_health", Default = true, Callback = function(value) state.EspHealth = value end})
        EspSection:AddToggle({Name = "Through Walls", Flag = "gfa_esp_through_walls", Default = true, Callback = function(value) state.EspThroughWalls = value end})
        EspSection:AddSlider({Name = "ESP Range", Flag = "gfa_esp_range", Min = 100, Max = 5000, Step = 100, Default = 1500, Suffix = "m", Callback = function(value) state.EspMaxDistance = tonumber(value) or 1500 end})

        LightingSection:AddToggle({
            Name = "Fullbright",
            Flag = "gfa_fullbright",
            Default = false,
            Callback = function(value)
                state.Fullbright = value
                setFullbright(value)
            end,
        })
    end

    local function buildPlayerControls()
        MovementSection:AddToggle({
            Name = "Movement Override",
            Description = "Uses Gunfight Arena's MovementData module; disable it before changing servers.",
            Flag = "gfa_movement_override",
            Default = false,
            Callback = function(value)
                state.MovementOverride = value
                if not value then
                    resetMovement()
                end
            end,
        })
        MovementSection:AddSlider({Name = "Walk Speed", Flag = "gfa_walk_speed", Min = 8, Max = 40, Step = 1, Default = 12, Callback = function(value) state.WalkSpeed = tonumber(value) or 12 end})
        MovementSection:AddSlider({Name = "Sprint Speed", Flag = "gfa_run_speed", Min = 16, Max = 70, Step = 1, Default = 28, Callback = function(value) state.RunSpeed = tonumber(value) or 28 end})
        MovementSection:AddSlider({Name = "Jump Boost", Flag = "gfa_jump_boost", Min = 0.2, Max = 2, Step = 0.05, Default = 0.6, Callback = function(value) state.JumpBoost = tonumber(value) or 0.6 end})
        MovementSection:AddButton({
            Name = "Reset Native Movement",
            Callback = function()
                state.MovementOverride = false
                resetMovement()
                notify("Native movement values restored", COLORS.success)
            end,
        })
    end

    local function buildWorldControls()
        ServerSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))
        ServerSection:AddLabel("UniverseId: " .. tostring(game.GameId))
        ServerSection:AddButton({
            Name = "Rejoin Server",
            Callback = function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end,
        })
        ServerSection:AddButton({
            Name = "Copy Place Information",
            Callback = function()
                local text = string.format("Gunfight Arena | PlaceId %s | UniverseId %s", tostring(game.PlaceId), tostring(game.GameId))
                if type(setclipboard) == "function" then
                    setclipboard(text)
                    notify("Place information copied", COLORS.success)
                else
                    notify(text, COLORS.warning)
                end
            end,
        })
    end

    buildCombatControls()
    buildWeaponControls()
    buildVisualControls()
    buildPlayerControls()
    buildWorldControls()

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if not processed then
            handleInput(input, true)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        handleInput(input, false)
    end))
    track(Players.PlayerRemoving:Connect(destroyEsp))

    local statusAccumulator = 0
    local espAccumulator = 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then
            return
        end
        applyAimAssist(deltaTime)
        applyWeaponModifiers()
        applyMovement()
        updateFovCircle()
        local camera = workspace.CurrentCamera
        if camera and state.CameraFovOverride then
            camera.FieldOfView = state.CameraFov
        end
        espAccumulator = espAccumulator + deltaTime
        statusAccumulator = statusAccumulator + deltaTime
        if espAccumulator >= 0.1 then
            espAccumulator = 0
            updateEsp()
        end
        if statusAccumulator >= 0.25 then
            statusAccumulator = 0
            updateStatus()
        end
    end))

    updateStatus()
    updateFovCircle()
    selectHomeCategory("Combat")
    pcall(function()
        gui:SetAttribute("GunfightArenaModuleReady", true)
        gui:SetAttribute("GunfightArenaUniverseId", 5012222382)
        gui:SetAttribute("GunfightArenaPlaceId", 15514727567)
    end)
    notify("Gunfight Arena module ready", COLORS.success)
end
