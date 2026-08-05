-- VOR Hub - Murder Mystery 2 adapter
-- Uses MM2's replicated round state, tagged weapons, collectible instances,
-- and normal client-side presentation objects. Executor-only helpers are
-- capability checked before use so one missing primitive cannot kill the hub.

return function(context)
    local Window = assert(context.Window, "Murder Mystery 2: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Murder Mystery 2: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local utilities = context.Utilities
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local CollectionService = game:GetService("CollectionService")
    local TeleportService = game:GetService("TeleportService")
    local Lighting = game:GetService("Lighting")
    local Debris = game:GetService("Debris")
    local SoundService = game:GetService("SoundService")
    local LocalPlayer = Players.LocalPlayer

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local CombatPage = addHomeCategory("Combat", 1, CATEGORY_DECALS.Combat)
    local FarmPage = addHomeCategory("Autofarm", 2, CATEGORY_DECALS.Overnight)
    local CharacterPage = addHomeCategory("Character", 3, CATEGORY_DECALS.Player)
    local VisualsPage = addHomeCategory("Visuals", 4, CATEGORY_DECALS.Visuals)
    local WorldPage = addHomeCategory("World", 5, CATEGORY_DECALS.Progress)
    local MiscPage = addHomeCategory("Misc", 6, CATEGORY_DECALS.Exploits)
    selectHomeCategory("Combat")

    local SheriffSection = CombatPage:AddSection("Sheriff", "Left")
    local MurdererSection = CombatPage:AddSection("Murderer", "Left")
    local AimSection = CombatPage:AddSection("Silent Aim", "Right")
    local FlingSection = CombatPage:AddSection("Fling", "Right")
    local CombatStatusSection = CombatPage:AddSection("Round Status", "Right")
    local CoinSection = FarmPage:AddSection("Coins", "Left")
    local RoundFarmSection = FarmPage:AddSection("Round Automation", "Left")
    local BoxesSection = FarmPage:AddSection("Boxes & Prestige", "Right")
    local FarmStatusSection = FarmPage:AddSection("Farm Status", "Right")
    local MovementSection = CharacterPage:AddSection("Movement", "Left")
    local SafetySection = CharacterPage:AddSection("Safety", "Left")
    local AppearanceSection = CharacterPage:AddSection("Appearance", "Right")
    local CameraSection = CharacterPage:AddSection("Camera", "Right")
    local EspSection = VisualsPage:AddSection("Player ESP", "Left")
    local RoleAuraSection = VisualsPage:AddSection("Role Auras", "Left")
    local WeaponVisualSection = VisualsPage:AddSection("Weapon Visuals", "Right")
    local VisualStatusSection = VisualsPage:AddSection("Visual Status", "Right")
    local LightingSection = WorldPage:AddSection("Lighting", "Left")
    local PostSection = WorldPage:AddSection("Post Effects", "Left")
    local PerformanceSection = WorldPage:AddSection("Performance", "Right")
    local TeleportSection = MiscPage:AddSection("Teleports", "Left")
    local ServerSection = MiscPage:AddSection("Server", "Left")
    local UtilitySection = MiscPage:AddSection("Utilities", "Right")
    local PlayerInfoSection = MiscPage:AddSection("Role Information", "Right")

    local state = {
        Alive = true,
        AutoKillMurderer = false,
        AutoShootMurderer = false,
        AutoGrabGun = false,
        KillAllKnife = false,
        KnifeReach = false,
        KnifeReachDistance = 15,
        AutoEquipKnife = false,
        EquipKnifeDelay = 1.1,
        SilentAim = false,
        SilentAimKnife = true,
        SilentAimGun = true,
        WallCheckKnife = false,
        WallCheckGun = false,
        ShootWhenKnifeVisible = false,
        AimVisualizer = false,
        FovRadius = 200,
        AutoFlingSheriff = false,
        TouchFling = false,
        FlingSpin = true,
        AntiFling = false,
        SelectedFlingPlayer = "",
        CoinFarm = false,
        EndRoundWhenFull = false,
        AvoidMode = false,
        KillAllWhenFull = false,
        KillMurdererWhenFull = false,
        FlingMurdererWhenFull = false,
        DieWhenFull = false,
        DieMurdererWhenFull = false,
        CoinMethod = "Tween",
        CoinSpeed = 16,
        CoinHeight = 5,
        CoinDelay = 0,
        CoinHitbox = false,
        CoinHitboxSize = 10,
        AutoSurvive = false,
        AutoOpenBoxes = false,
        BoxDelay = 1,
        SelectedBox = "MysteryBox1",
        AutoPrestige = false,
        PrestigeDelay = 1,
        AutoStrafe = false,
        StrafeMultiplier = 1,
        WalkSpeedEnabled = false,
        WalkSpeed = 50,
        JumpPowerEnabled = false,
        JumpPower = 50,
        NoClip = false,
        AntiVoid = false,
        Float = false,
        Fly = false,
        FlySpeed = 100,
        DisableAnimations = false,
        OverrideAppearance = false,
        AppearanceMaterial = "Neon",
        HideClothes = false,
        ChinaHat = false,
        EspEnabled = false,
        EspBox = true,
        EspHealth = true,
        EspName = true,
        EspDistance = true,
        EspWeapon = true,
        EspRole = true,
        EspTracer = false,
        EspVisibility = false,
        ShowMurderer = true,
        ShowSheriff = true,
        ShowHero = true,
        ShowInnocent = true,
        DroppedGunEsp = true,
        AuraMurderer = false,
        AuraSheriff = false,
        AuraHero = false,
        AuraInnocent = false,
        BulletTracers = false,
        HitSound = false,
        ScreenFlash = false,
        LightingOverride = false,
        Brightness = 2,
        ClockTime = 14,
        FogStart = 0,
        FogEnd = 100000,
        Exposure = 0,
        Bloom = false,
        BloomIntensity = 1,
        BloomSize = 24,
        SunRays = false,
        SunRaysIntensity = 0.3,
        MotionBlur = false,
        BlurAmount = 12,
        CustomFov = false,
        CameraFov = 70,
        MaxZoom = 100,
        FpsBoost = false,
        DisableRendering = false,
        AutoTeleportLobby = false,
        ServerHopOnLow = false,
        PlayerThreshold = 3,
        PreventKillAlts = false,
        PreventCoinStealAlts = false,
        AltNames = {},
        LastEquip = 0,
        LastShoot = 0,
        LastKnife = 0,
        LastThrow = 0,
        LastCoin = 0,
        LastBox = 0,
        LastPrestige = 0,
        LastFling = 0,
        LastRoundAlive = false,
        LastSafeCFrame = nil,
        ActiveTween = nil,
        Status = "Initializing...",
    }

    local roleModule
    local profileData
    local syncData
    pcall(function()
        roleModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    pcall(function()
        profileData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))
    end)
    pcall(function()
        syncData = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
    end)

    local roleLabel = CombatStatusSection:AddLabel("Role: Reading...")
    local murdererLabel = CombatStatusSection:AddLabel("Murderer: Unknown")
    local sheriffLabel = CombatStatusSection:AddLabel("Sheriff: Unknown")
    local heroLabel = CombatStatusSection:AddLabel("Hero: Unknown")
    local combatLabel = CombatStatusSection:AddLabel("Status: Initializing MM2 adapter...")
    local coinLabel = FarmStatusSection:AddLabel("Coin bag: Reading...")
    local farmLabel = FarmStatusSection:AddLabel("Farm: Idle")
    local visualLabel = VisualStatusSection:AddLabel("ESP: Idle")
    local playerCountLabel = PlayerInfoSection:AddLabel("Players: " .. tostring(#Players:GetPlayers()))
    local roundLabel = PlayerInfoSection:AddLabel("Round: Reading...")

    local roleColors = {
        Murderer = Color3.fromRGB(255, 70, 90),
        Sheriff = Color3.fromRGB(70, 150, 255),
        Hero = Color3.fromRGB(255, 220, 70),
        Innocent = Color3.fromRGB(90, 255, 145),
        Dead = Color3.fromRGB(125, 125, 135),
    }
    local espObjects = {}
    local droppedGunVisual
    local hatPart
    local hiddenClothes = {}
    local fovFrame
    local bloomEffect
    local sunRaysEffect
    local blurEffect
    local originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        ExposureCompensation = Lighting.ExposureCompensation,
        GlobalShadows = Lighting.GlobalShadows,
    }
    local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
    local originalZoom = LocalPlayer.CameraMaxZoomDistance

    local function setStatus(message, success)
        state.Status = tostring(message)
        combatLabel.Text = "Status: " .. state.Status
        combatLabel.TextColor3 = success == false and (COLORS.error or Color3.fromRGB(255, 95, 125))
            or success == true and (COLORS.success or Color3.fromRGB(80, 235, 150))
            or (COLORS.muted or Color3.fromRGB(190, 180, 210))
    end

    local function characterOf(player)
        return player and player.Character
    end

    local function humanoidOf(player)
        local character = characterOf(player)
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function rootOf(player)
        local character = characterOf(player)
        return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    end

    local function isAlive(player)
        local humanoid = humanoidOf(player)
        local data = roleModule and roleModule.PlayerData and roleModule.PlayerData[player.Name]
        return humanoid ~= nil and humanoid.Health > 0 and (not data or data.Dead ~= true)
    end

    local function roleOf(player)
        local data = roleModule and roleModule.PlayerData and roleModule.PlayerData[player.Name]
        if data and data.Role then
            if data.Role == "Innocent" then
                for _, container in pairs({characterOf(player), player and player:FindFirstChildOfClass("Backpack")}) do
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and (CollectionService:HasTag(tool, "Weapon_Gun") or tool.Name == "Gun") then
                                return "Hero"
                            end
                        end
                    end
                end
            end
            return data.Role
        end
        local character = characterOf(player)
        local backpack = player and player:FindFirstChildOfClass("Backpack")
        for _, container in pairs({character, backpack}) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        if CollectionService:HasTag(tool, "Weapon_Knife") or tool.Name == "Knife" then
                            return "Murderer"
                        elseif CollectionService:HasTag(tool, "Weapon_Gun") or tool.Name == "Gun" then
                            return "Sheriff"
                        end
                    end
                end
            end
        end
        return "Innocent"
    end

    local function playerWithRole(role)
        for _, player in ipairs(Players:GetPlayers()) do
            if roleOf(player) == role and isAlive(player) then
                return player
            end
        end
        return nil
    end

    local function isAlt(player)
        return player and state.AltNames[player.Name:lower()] == true
    end

    local function findWeapon(player, kind)
        local wantedTag = kind == "Knife" and "Weapon_Knife" or "Weapon_Gun"
        for _, container in pairs({characterOf(player), player and player:FindFirstChildOfClass("Backpack")}) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and (CollectionService:HasTag(tool, wantedTag) or tool.Name == kind) then
                        return tool
                    end
                end
            end
        end
        return nil
    end

    local function equipWeapon(kind)
        local tool = findWeapon(LocalPlayer, kind)
        local humanoid = humanoidOf(LocalPlayer)
        if tool and humanoid and tool.Parent ~= LocalPlayer.Character then
            pcall(function()
                humanoid:EquipTool(tool)
            end)
        end
        return tool
    end

    local function knifeIsVisible(player)
        local tool = findWeapon(player, "Knife")
        return tool ~= nil and tool.Parent == characterOf(player)
    end

    local function canSee(targetPlayer)
        local camera = workspace.CurrentCamera
        local targetRoot = rootOf(targetPlayer)
        local localCharacter = characterOf(LocalPlayer)
        if not camera or not targetRoot then
            return false
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {localCharacter, camera}
        local result = workspace:Raycast(camera.CFrame.Position, targetRoot.Position - camera.CFrame.Position, params)
        return result == nil or result.Instance:IsDescendantOf(characterOf(targetPlayer))
    end

    local function inFov(targetPlayer)
        local camera = workspace.CurrentCamera
        local targetRoot = rootOf(targetPlayer)
        if not camera or not targetRoot then
            return false
        end
        local point, visible = camera:WorldToViewportPoint(targetRoot.Position)
        if not visible then
            return false
        end
        local mouse = UserInputService:GetMouseLocation()
        return (Vector2.new(point.X, point.Y) - mouse).Magnitude <= state.FovRadius
    end

    local function getAimTarget(kind)
        if kind == "Gun" then
            local murderer = playerWithRole("Murderer")
            if murderer and inFov(murderer) and (not state.WallCheckGun or canSee(murderer)) then
                if not state.ShootWhenKnifeVisible or knifeIsVisible(murderer) then
                    return murderer
                end
            end
            return nil
        end
        local best, bestDistance
        local localRoot = rootOf(LocalPlayer)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isAlive(player) and not (state.PreventKillAlts and isAlt(player)) then
                local targetRoot = rootOf(player)
                if localRoot and targetRoot and inFov(player) and (not state.WallCheckKnife or canSee(player)) then
                    local distance = (localRoot.Position - targetRoot.Position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        best, bestDistance = player, distance
                    end
                end
            end
        end
        return best
    end

    local function fireGunAt(player)
        local targetRoot = rootOf(player)
        if not targetRoot then
            return false
        end
        local gun = equipWeapon("Gun")
        if not gun then
            return false
        end
        local remote = gun:FindFirstChild("Shoot", true)
        if remote and remote:IsA("RemoteEvent") then
            local localRoot = rootOf(LocalPlayer)
            local origin = localRoot and localRoot:FindFirstChild("GunRaycastAttachment")
            origin = origin and origin.WorldCFrame or (localRoot and localRoot.CFrame)
            local ok = pcall(function()
                remote:FireServer(origin, CFrame.new(targetRoot.Position))
            end)
            if ok then
                state.LastShoot = os.clock()
                return true
            end
        end
        pcall(function()
            gun:Activate()
        end)
        return false
    end

    local function touchParts(first, second)
        if type(firetouchinterest) ~= "function" or not first or not second then
            return false
        end
        return pcall(function()
            firetouchinterest(first, second, 0)
            firetouchinterest(first, second, 1)
        end)
    end

    local function knifeAttack(player)
        local targetRoot = rootOf(player)
        local knife = equipWeapon("Knife")
        if not targetRoot or not knife then
            return false
        end
        local handle = knife:FindFirstChild("Handle")
        local events = knife:FindFirstChild("Events")
        local stabbed = events and events:FindFirstChild("KnifeStabbed")
        local handleTouched = events and events:FindFirstChild("HandleTouched")
        if os.clock() - state.LastKnife >= 0.85 then
            pcall(function()
                knife:Activate()
            end)
            if stabbed and stabbed:IsA("RemoteEvent") then
                pcall(function()
                    stabbed:FireServer()
                end)
            end
            state.LastKnife = os.clock()
        end
        if handleTouched and handleTouched:IsA("RemoteEvent") then
            pcall(function()
                handleTouched:FireServer(targetRoot)
            end)
        end
        local touched = touchParts(handle, targetRoot)
        return touched
    end

    local function throwKnifeAt(player)
        local targetRoot = rootOf(player)
        local knife = equipWeapon("Knife")
        local handle = knife and knife:FindFirstChild("Handle")
        local events = knife and knife:FindFirstChild("Events")
        local remote = events and events:FindFirstChild("KnifeThrown")
        if not targetRoot or not handle or not remote or not remote:IsA("RemoteEvent") then
            return false
        end
        local ok = pcall(function()
            remote:FireServer(handle.CFrame, CFrame.new(targetRoot.Position))
        end)
        if ok then
            state.LastThrow = os.clock()
        end
        return ok
    end

    local function findDroppedGun()
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant.Name == "GunDrop" then
                if descendant:IsA("BasePart") then
                    return descendant
                elseif descendant:IsA("Model") or descendant:IsA("Tool") then
                    return descendant:FindFirstChildWhichIsA("BasePart", true)
                end
            end
        end
        return nil
    end

    local function moveTo(position, speed)
        local root = rootOf(LocalPlayer)
        if not root then
            return false
        end
        if state.ActiveTween then
            pcall(function()
                state.ActiveTween:Cancel()
            end)
            state.ActiveTween = nil
        end
        local target = CFrame.new(position)
        if state.CoinMethod == "Teleport" then
            root.CFrame = target
            return true
        end
        local duration = math.clamp((root.Position - position).Magnitude / math.max(speed or 16, 1), 0.05, 8)
        local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = target})
        state.ActiveTween = tween
        tween:Play()
        return true
    end

    local function grabDroppedGun()
        local gunPart = findDroppedGun()
        local root = rootOf(LocalPlayer)
        if not gunPart or not root then
            return false
        end
        moveTo(gunPart.Position + Vector3.new(0, 2, 0), math.max(state.CoinSpeed, 30))
        touchParts(root, gunPart)
        return true
    end

    local function currentMap()
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("CoinContainer") then
                return child
            end
        end
        return nil
    end

    local function nearestCoin()
        local map = currentMap()
        local root = rootOf(LocalPlayer)
        local container = map and map:FindFirstChild("CoinContainer")
        if not container or not root then
            return nil
        end
        local best, distance
        for _, coin in ipairs(container:GetChildren()) do
            local part = coin:IsA("BasePart") and coin or coin:FindFirstChildWhichIsA("BasePart", true)
            if part and part.Parent then
                local safe = true
                if state.AvoidMode then
                    for _, role in ipairs({"Murderer", "Sheriff"}) do
                        local threatRoot = rootOf(playerWithRole(role))
                        if threatRoot and (threatRoot.Position - part.Position).Magnitude < 28 then
                            safe = false
                        end
                    end
                end
                local d = (root.Position - part.Position).Magnitude
                if safe and (not distance or d < distance) then
                    best, distance = part, d
                end
            end
        end
        return best
    end

    local function coinBagText()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return "Unknown", false
        end
        local mainGui = playerGui:FindFirstChild("MainGUI")
        local gameFrame = mainGui and mainGui:FindFirstChild("Game")
        local coinBags = gameFrame and gameFrame:FindFirstChild("CoinBags")
        local container = coinBags and coinBags:FindFirstChild("Container")
        if container then
            for _, bag in ipairs(container:GetChildren()) do
                if bag:IsA("Frame") and bag.Visible then
                    local currencyFrame = bag:FindFirstChild("CurrencyFrame")
                    local icon = currencyFrame and currencyFrame:FindFirstChild("Icon")
                    local coins = icon and icon:FindFirstChild("Coins")
                    local full = bag:FindFirstChild("Full")
                    local count = coins and tostring(coins.Text) or "0"
                    return bag.Name .. ": " .. count, full ~= nil and full.Visible
                end
            end
        end
        local best = "Unknown"
        for _, descendant in ipairs(playerGui:GetDescendants()) do
            if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Visible then
                local text = tostring(descendant.Text or "")
                if text:match("%d+%s*/%s*%d+") then
                    best = text
                    local current, maximum = text:match("(%d+)%s*/%s*(%d+)")
                    if current and maximum then
                        return text, tonumber(current) >= tonumber(maximum)
                    end
                end
            end
        end
        return best, false
    end

    local function collectCoin()
        local coin = nearestCoin()
        local root = rootOf(LocalPlayer)
        if not coin or not root then
            return false
        end
        if state.CoinHitbox then
            pcall(function()
                coin.Size = Vector3.new(state.CoinHitboxSize, state.CoinHitboxSize, state.CoinHitboxSize)
                coin.CanCollide = false
            end)
        end
        moveTo(coin.Position + Vector3.new(0, state.CoinHeight, 0), state.CoinSpeed)
        touchParts(root, coin)
        state.LastCoin = os.clock()
        return true
    end

    local function dieNow()
        local humanoid = humanoidOf(LocalPlayer)
        if humanoid then
            humanoid.Health = 0
        end
    end

    local function handleFullBag()
        local role = roleOf(LocalPlayer)
        if state.KillAllWhenFull and role == "Murderer" then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and isAlive(player) then
                    knifeAttack(player)
                end
            end
        end
        if state.KillMurdererWhenFull and (role == "Sheriff" or role == "Hero") then
            local murderer = playerWithRole("Murderer")
            if murderer then
                fireGunAt(murderer)
            end
        end
        if state.FlingMurdererWhenFull then
            local murderer = playerWithRole("Murderer")
            local root = rootOf(murderer)
            local localRoot = rootOf(LocalPlayer)
            if root and localRoot then
                localRoot.CFrame = root.CFrame
            end
        end
        if state.DieWhenFull or (state.DieMurdererWhenFull and role == "Murderer") then
            dieNow()
        end
    end

    local function flingPlayer(player)
        local localRoot = rootOf(LocalPlayer)
        local targetRoot = rootOf(player)
        if not localRoot or not targetRoot or player == LocalPlayer then
            return false
        end
        localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.5)
        if state.FlingSpin then
            localRoot.AssemblyAngularVelocity = Vector3.new(0, 2500, 0)
        end
        local delta = targetRoot.Position - localRoot.Position
        localRoot.AssemblyLinearVelocity = delta.Magnitude > 0.01 and delta.Unit * 220 or Vector3.new(220, 0, 0)
        state.LastFling = os.clock()
        return true
    end

    local function openSelectedBox()
        local remote = ReplicatedStorage:FindFirstChild("Remotes")
        remote = remote and remote:FindFirstChild("Shop")
        remote = remote and remote:FindFirstChild("OpenCrate")
        if not remote or not remote:IsA("RemoteFunction") then
            return false
        end
        local ok, result = pcall(function()
            return remote:InvokeServer(state.SelectedBox, "MysteryBox", "Coins")
        end)
        return ok and result ~= nil
    end

    local function requestPrestige()
        local remote = ReplicatedStorage:FindFirstChild("Remotes")
        remote = remote and remote:FindFirstChild("Inventory")
        remote = remote and remote:FindFirstChild("Prestige")
        if not remote or not remote:IsA("RemoteEvent") then
            return false
        end
        local ok = pcall(function()
            remote:FireServer()
        end)
        return ok
    end

    local function teleportToLobby()
        local lobby = workspace:FindFirstChild("Lobby")
        local root = rootOf(LocalPlayer)
        if lobby and root then
            root.CFrame = lobby:GetPivot() + Vector3.new(0, 5, 0)
            return true
        end
        return false
    end

    local function teleportToMap()
        local map = currentMap()
        local root = rootOf(LocalPlayer)
        if map and root then
            root.CFrame = map:GetPivot() + Vector3.new(0, 8, 0)
            return true
        end
        return false
    end

    local function serverHop()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end

    local function roleAllowed(role)
        return role == "Murderer" and state.ShowMurderer
            or role == "Sheriff" and state.ShowSheriff
            or role == "Hero" and state.ShowHero
            or role == "Innocent" and state.ShowInnocent
    end

    local function clearEsp(player)
        local object = espObjects[player]
        if object then
            pcall(function()
                object.Highlight:Destroy()
            end)
            pcall(function()
                object.Gui:Destroy()
            end)
            espObjects[player] = nil
        end
    end

    local function updatePlayerEsp(player)
        if player == LocalPlayer then
            return
        end
        local character = characterOf(player)
        local head = character and character:FindFirstChild("Head")
        local humanoid = humanoidOf(player)
        local root = rootOf(player)
        local role = roleOf(player)
        if not state.EspEnabled or not character or not head or not root or not roleAllowed(role) then
            clearEsp(player)
            return
        end
        local object = espObjects[player]
        if not object then
            local highlight = Instance.new("Highlight")
            highlight.Name = "VOR_MM2_ESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.78
            highlight.OutlineTransparency = 0
            highlight.Adornee = character
            highlight.Parent = character
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "VOR_MM2_Info"
            billboard.Size = UDim2.fromOffset(220, 50)
            billboard.StudsOffset = Vector3.new(0, 3.4, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee = head
            billboard.Parent = head
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.fromScale(1, 1)
            textLabel.BackgroundTransparency = 1
            textLabel.TextStrokeTransparency = 0.15
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextSize = 13
            textLabel.Parent = billboard
            object = {Highlight = highlight, Gui = billboard, Text = textLabel}
            espObjects[player] = object
        end
        local color = roleColors[role] or roleColors.Innocent
        local visibleByRay = not state.EspVisibility or canSee(player)
        object.Highlight.Enabled = visibleByRay
        object.Gui.Enabled = visibleByRay
        object.Highlight.Adornee = character
        object.Highlight.FillColor = color
        object.Highlight.OutlineColor = color
        local parts = {}
        if state.EspName then
            parts[#parts + 1] = player.DisplayName
        end
        if state.EspRole then
            parts[#parts + 1] = role
        end
        if state.EspHealth and humanoid then
            parts[#parts + 1] = tostring(math.floor(humanoid.Health)) .. " HP"
        end
        if state.EspDistance then
            local localRoot = rootOf(LocalPlayer)
            if localRoot then
                parts[#parts + 1] = tostring(math.floor((localRoot.Position - root.Position).Magnitude)) .. "m"
            end
        end
        if state.EspWeapon then
            if findWeapon(player, "Knife") then
                parts[#parts + 1] = "Knife"
            elseif findWeapon(player, "Gun") then
                parts[#parts + 1] = "Gun"
            end
        end
        object.Text.Text = table.concat(parts, " | ")
        object.Text.TextColor3 = color
    end

    local function updateDroppedGunEsp()
        local gun = findDroppedGun()
        if not state.DroppedGunEsp or not gun then
            if droppedGunVisual then
                droppedGunVisual:Destroy()
                droppedGunVisual = nil
            end
            return
        end
        if not droppedGunVisual or droppedGunVisual.Adornee ~= gun then
            if droppedGunVisual then
                droppedGunVisual:Destroy()
            end
            local highlight = Instance.new("Highlight")
            highlight.Name = "VOR_MM2_DroppedGun"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = roleColors.Sheriff
            highlight.OutlineColor = Color3.new(1, 1, 1)
            highlight.FillTransparency = 0.3
            highlight.Adornee = gun
            highlight.Parent = gun
            droppedGunVisual = highlight
        end
    end

    local function updateAura(player)
        local character = characterOf(player)
        if not character then
            return
        end
        local role = roleOf(player)
        local enabled = role == "Murderer" and state.AuraMurderer
            or role == "Sheriff" and state.AuraSheriff
            or role == "Hero" and state.AuraHero
            or role == "Innocent" and state.AuraInnocent
        local aura = character:FindFirstChild("VOR_MM2_Aura")
        if enabled and not aura then
            aura = Instance.new("Highlight")
            aura.Name = "VOR_MM2_Aura"
            aura.DepthMode = Enum.HighlightDepthMode.Occluded
            aura.FillTransparency = 0.55
            aura.OutlineTransparency = 0.25
            aura.Parent = character
        end
        if aura then
            aura.Enabled = enabled
            aura.Adornee = character
            aura.FillColor = roleColors[role] or roleColors.Innocent
            aura.OutlineColor = aura.FillColor
        end
    end

    local function updateFov()
        if not fovFrame then
            fovFrame = Instance.new("Frame")
            fovFrame.Name = "VOR_MM2_FOV"
            fovFrame.BackgroundTransparency = 1
            fovFrame.BorderSizePixel = 0
            fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            fovFrame.ZIndex = 200
            fovFrame.Parent = gui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = fovFrame
            local stroke = Instance.new("UIStroke")
            stroke.Name = "Outline"
            stroke.Thickness = 2
            stroke.Color = COLORS.accentBright or Color3.fromRGB(190, 135, 255)
            stroke.Parent = fovFrame
        end
        local mouse = UserInputService:GetMouseLocation()
        fovFrame.Position = UDim2.fromOffset(mouse.X, mouse.Y)
        fovFrame.Size = UDim2.fromOffset(state.FovRadius * 2, state.FovRadius * 2)
        fovFrame.Visible = state.AimVisualizer
    end

    local function worldPosition(value)
        if typeof(value) == "Vector3" then
            return value
        elseif typeof(value) == "CFrame" then
            return value.Position
        elseif typeof(value) == "Instance" and value:IsA("Attachment") then
            return value.WorldPosition
        elseif typeof(value) == "Instance" and value:IsA("BasePart") then
            return value.Position
        end
        return nil
    end

    local function createTracer(startValue, endValue)
        if not state.BulletTracers then
            return
        end
        local startPosition = worldPosition(startValue)
        local endPosition = worldPosition(endValue)
        if not startPosition or not endPosition then
            return
        end
        local startPart = Instance.new("Part")
        startPart.Name = "VOR_MM2_TracerStart"
        startPart.Anchored = true
        startPart.CanCollide = false
        startPart.CanQuery = false
        startPart.Transparency = 1
        startPart.Size = Vector3.one
        startPart.Position = startPosition
        startPart.Parent = workspace
        local endPart = startPart:Clone()
        endPart.Name = "VOR_MM2_TracerEnd"
        endPart.Position = endPosition
        endPart.Parent = workspace
        local attachment0 = Instance.new("Attachment")
        attachment0.Parent = startPart
        local attachment1 = Instance.new("Attachment")
        attachment1.Parent = endPart
        local beam = Instance.new("Beam")
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        beam.FaceCamera = true
        beam.Width0 = 0.16
        beam.Width1 = 0.04
        beam.LightEmission = 1
        beam.Color = ColorSequence.new(COLORS.accentBright or Color3.fromRGB(190, 135, 255))
        beam.Parent = startPart
        Debris:AddItem(startPart, 0.35)
        Debris:AddItem(endPart, 0.35)
    end

    local function showHitFeedback()
        if state.HitSound then
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://8726881116"
            sound.Volume = 0.7
            sound.Parent = SoundService
            sound:Play()
            Debris:AddItem(sound, 2)
        end
        if state.ScreenFlash then
            local flash = Instance.new("Frame")
            flash.Name = "VOR_MM2_HitFlash"
            flash.Size = UDim2.fromScale(1, 1)
            flash.BackgroundColor3 = COLORS.accentBright or Color3.fromRGB(190, 135, 255)
            flash.BackgroundTransparency = 0.5
            flash.BorderSizePixel = 0
            flash.ZIndex = 500
            flash.Parent = gui
            TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            Debris:AddItem(flash, 0.35)
        end
    end

    local function updateAppearance()
        local character = characterOf(LocalPlayer)
        if not character then
            return
        end
        if not state.HideClothes then
            for clothing, parent in pairs(hiddenClothes) do
                if clothing and parent and clothing.Parent == nil then
                    clothing.Parent = parent
                end
                hiddenClothes[clothing] = nil
            end
        end
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
                if descendant:GetAttribute("VOR_MM2_OriginalMaterial") == nil then
                    descendant:SetAttribute("VOR_MM2_OriginalMaterial", descendant.Material.Name)
                    descendant:SetAttribute("VOR_MM2_OriginalColor", descendant.Color)
                end
                if state.OverrideAppearance then
                    local ok, material = pcall(function()
                        return Enum.Material[state.AppearanceMaterial]
                    end)
                    descendant.Material = ok and material or Enum.Material.Neon
                    descendant.Color = COLORS.accent or Color3.fromRGB(126, 55, 255)
                else
                    local materialName = descendant:GetAttribute("VOR_MM2_OriginalMaterial")
                    local color = descendant:GetAttribute("VOR_MM2_OriginalColor")
                    if materialName and Enum.Material[materialName] then
                        descendant.Material = Enum.Material[materialName]
                    end
                    if typeof(color) == "Color3" then
                        descendant.Color = color
                    end
                end
            elseif descendant:IsA("Clothing") then
                if state.HideClothes then
                    hiddenClothes[descendant] = descendant.Parent
                    descendant.Parent = nil
                end
            end
        end
        local head = character:FindFirstChild("Head")
        if state.ChinaHat and head and not hatPart then
            hatPart = Instance.new("Part")
            hatPart.Name = "VOR_MM2_ChinaHat"
            hatPart.CanCollide = false
            hatPart.CanTouch = false
            hatPart.Massless = true
            hatPart.Color = COLORS.accent or Color3.fromRGB(126, 55, 255)
            hatPart.Material = Enum.Material.Neon
            hatPart.Size = Vector3.new(3.8, 0.25, 3.8)
            hatPart.CFrame = head.CFrame * CFrame.new(0, 0.8, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.Cylinder
            mesh.Parent = hatPart
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = head
            weld.Part1 = hatPart
            weld.Parent = hatPart
            hatPart.Parent = character
        elseif not state.ChinaHat and hatPart then
            hatPart:Destroy()
            hatPart = nil
        end
    end

    local function updateWorld()
        if state.LightingOverride then
            Lighting.Brightness = state.Brightness
            Lighting.ClockTime = state.ClockTime
            Lighting.FogStart = state.FogStart
            Lighting.FogEnd = state.FogEnd
            Lighting.ExposureCompensation = state.Exposure
        else
            for property, value in pairs(originalLighting) do
                Lighting[property] = value
            end
        end
        Lighting.GlobalShadows = not state.FpsBoost and originalLighting.GlobalShadows or false
        if state.Bloom and not bloomEffect then
            bloomEffect = Instance.new("BloomEffect")
            bloomEffect.Name = "VOR_MM2_Bloom"
            bloomEffect.Parent = Lighting
        end
        if bloomEffect then
            bloomEffect.Enabled = state.Bloom
            bloomEffect.Intensity = state.BloomIntensity
            bloomEffect.Size = state.BloomSize
        end
        if state.SunRays and not sunRaysEffect then
            sunRaysEffect = Instance.new("SunRaysEffect")
            sunRaysEffect.Name = "VOR_MM2_SunRays"
            sunRaysEffect.Parent = Lighting
        end
        if sunRaysEffect then
            sunRaysEffect.Enabled = state.SunRays
            sunRaysEffect.Intensity = state.SunRaysIntensity
        end
        if state.MotionBlur and not blurEffect then
            blurEffect = Instance.new("BlurEffect")
            blurEffect.Name = "VOR_MM2_Blur"
            blurEffect.Parent = Lighting
        end
        if blurEffect then
            blurEffect.Enabled = state.MotionBlur
            blurEffect.Size = state.BlurAmount
        end
        local camera = workspace.CurrentCamera
        if camera then
            camera.FieldOfView = state.CustomFov and state.CameraFov or originalFov
        end
        LocalPlayer.CameraMaxZoomDistance = state.MaxZoom
        pcall(function()
            RunService:Set3dRenderingEnabled(not state.DisableRendering)
        end)
    end

    local function resetVisuals()
        for clothing, parent in pairs(hiddenClothes) do
            if clothing and parent and clothing.Parent == nil then
                clothing.Parent = parent
            end
            hiddenClothes[clothing] = nil
        end
        for player in pairs(espObjects) do
            clearEsp(player)
        end
        if droppedGunVisual then
            droppedGunVisual:Destroy()
            droppedGunVisual = nil
        end
        if fovFrame then
            fovFrame:Destroy()
            fovFrame = nil
        end
        for _, player in ipairs(Players:GetPlayers()) do
            local character = characterOf(player)
            local aura = character and character:FindFirstChild("VOR_MM2_Aura")
            if aura then
                aura:Destroy()
            end
        end
        for _, effect in pairs({bloomEffect, sunRaysEffect, blurEffect}) do
            if effect then
                effect:Destroy()
            end
        end
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        local camera = workspace.CurrentCamera
        if camera then
            camera.FieldOfView = originalFov
        end
        LocalPlayer.CameraMaxZoomDistance = originalZoom
        for property, value in pairs(originalLighting) do
            Lighting[property] = value
        end
    end

    if utilities and utilities.OnCleanup then
        utilities.OnCleanup(function()
            state.Alive = false
            if state.ActiveTween then
                pcall(function()
                    state.ActiveTween:Cancel()
                end)
            end
            resetVisuals()
        end)
    end

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.K then
            state.KillAllKnife = not state.KillAllKnife
            setStatus("Knife Kill All " .. (state.KillAllKnife and "enabled" or "disabled"), true)
        elseif input.KeyCode == Enum.KeyCode.H then
            local murderer = playerWithRole("Murderer")
            if murderer then
                fireGunAt(murderer)
            end
        elseif input.KeyCode == Enum.KeyCode.N then
            state.NoClip = not state.NoClip
        elseif input.KeyCode == Enum.KeyCode.U then
            state.Float = not state.Float
        elseif input.KeyCode == Enum.KeyCode.P then
            state.Fly = not state.Fly
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and state.SilentAim and state.SilentAimKnife
            and os.clock() - state.LastThrow >= 0.4 then
            local target = getAimTarget("Knife")
            if target then
                throwKnifeAt(target)
            end
        end
    end))

    local weaponEvents = ReplicatedStorage:FindFirstChild("WeaponEvents")
    local gunBeam = weaponEvents and weaponEvents:FindFirstChild("GunBeam")
    if gunBeam and gunBeam:IsA("RemoteEvent") then
        track(gunBeam.OnClientEvent:Connect(function(_, startValue, endValue)
            createTracer(startValue, endValue)
        end))
    end
    local gameplayEvents = ReplicatedStorage:FindFirstChild("Remotes")
    gameplayEvents = gameplayEvents and gameplayEvents:FindFirstChild("Gameplay")
    for _, eventName in ipairs({"KnifeKill", "GunKill"}) do
        local event = gameplayEvents and gameplayEvents:FindFirstChild(eventName)
        if event and event:IsA("BindableEvent") then
            track(event.Event:Connect(showHitFeedback))
        end
    end

    track(RunService.Stepped:Connect(function()
        local character = characterOf(LocalPlayer)
        local humanoid = humanoidOf(LocalPlayer)
        local root = rootOf(LocalPlayer)
        if not character or not humanoid or not root then
            return
        end
        if state.NoClip then
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    descendant.CanCollide = false
                end
            end
        end
        humanoid.WalkSpeed = state.WalkSpeedEnabled and state.WalkSpeed or 16
        humanoid.UseJumpPower = true
        humanoid.JumpPower = state.JumpPowerEnabled and state.JumpPower or 50
        if state.DisableAnimations then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, animation in ipairs(animator:GetPlayingAnimationTracks()) do
                    animation:Stop(0)
                end
            end
        end
        if state.Float then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
        if state.Fly then
            local camera = workspace.CurrentCamera
            local direction = humanoid.MoveDirection
            if camera and direction.Magnitude > 0 then
                root.AssemblyLinearVelocity = direction.Unit * state.FlySpeed
            else
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        if state.AntiFling then
            root.AssemblyAngularVelocity = Vector3.zero
            if root.AssemblyLinearVelocity.Magnitude > 180 then
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        if root.Position.Y > -80 then
            state.LastSafeCFrame = root.CFrame
        elseif state.AntiVoid and state.LastSafeCFrame then
            root.CFrame = state.LastSafeCFrame + Vector3.new(0, 4, 0)
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if state.AutoStrafe then
            local target = playerWithRole("Murderer") or playerWithRole("Sheriff")
            local targetRoot = rootOf(target)
            if targetRoot then
                local radial = root.Position - targetRoot.Position
                if radial.Magnitude > 0.1 then
                    local tangent = Vector3.new(-radial.Z, 0, radial.X).Unit
                    humanoid:Move(tangent * state.StrafeMultiplier, false)
                end
            end
        end
    end))

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            local localRole = roleOf(LocalPlayer)
            local localAlive = isAlive(LocalPlayer)
            local murderer = playerWithRole("Murderer")
            local sheriff = playerWithRole("Sheriff")
            roleLabel.Text = "Role: " .. tostring(localRole)
            murdererLabel.Text = "Murderer: " .. (murderer and murderer.Name or "Unknown")
            sheriffLabel.Text = "Sheriff: " .. (sheriff and sheriff.Name or "Unknown")
            heroLabel.Text = "Hero: " .. ((playerWithRole("Hero") or {}).Name or "Unknown")
            playerCountLabel.Text = "Players: " .. tostring(#Players:GetPlayers())
            roundLabel.Text = "Round: " .. (currentMap() and (localAlive and "Active" or "Spectating") or "Lobby")

            if state.AutoEquipKnife and localRole == "Murderer" and now - state.LastEquip >= state.EquipKnifeDelay then
                equipWeapon("Knife")
                state.LastEquip = now
            end
            if state.AutoGrabGun and not findWeapon(LocalPlayer, "Gun") then
                grabDroppedGun()
            end
            if state.AutoFlingSheriff and sheriff and now - state.LastFling >= 0.4 then
                flingPlayer(sheriff)
            end
            if state.TouchFling and now - state.LastFling >= 0.25 then
                local localRoot = rootOf(LocalPlayer)
                for _, player in ipairs(Players:GetPlayers()) do
                    local targetRoot = rootOf(player)
                    if player ~= LocalPlayer and localRoot and targetRoot
                        and (localRoot.Position - targetRoot.Position).Magnitude <= 7 then
                        flingPlayer(player)
                        break
                    end
                end
            end
            if state.AutoKillMurderer and murderer and now - state.LastShoot >= 0.35 then
                if not findWeapon(LocalPlayer, "Gun") then
                    grabDroppedGun()
                elseif (not state.WallCheckGun or canSee(murderer))
                    and (not state.ShootWhenKnifeVisible or knifeIsVisible(murderer)) then
                    fireGunAt(murderer)
                end
            elseif state.AutoShootMurderer and now - state.LastShoot >= 0.35 then
                local target = getAimTarget("Gun")
                if target then
                    fireGunAt(target)
                end
            end
            if state.KillAllKnife and localRole == "Murderer" and now - state.LastKnife >= 0.08 then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and isAlive(player) and not (state.PreventKillAlts and isAlt(player)) then
                        knifeAttack(player)
                    end
                end
            elseif state.KnifeReach and localRole == "Murderer" and now - state.LastKnife >= 0.08 then
                local localRoot = rootOf(LocalPlayer)
                for _, player in ipairs(Players:GetPlayers()) do
                    local targetRoot = rootOf(player)
                    if player ~= LocalPlayer and targetRoot and localRoot and isAlive(player)
                        and (localRoot.Position - targetRoot.Position).Magnitude <= state.KnifeReachDistance then
                        knifeAttack(player)
                    end
                end
            end
            if state.SilentAim then
                if state.SilentAimGun and findWeapon(LocalPlayer, "Gun") and now - state.LastShoot >= 0.35 then
                    local target = getAimTarget("Gun")
                    if target and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                        fireGunAt(target)
                    end
                end
                if state.SilentAimKnife and findWeapon(LocalPlayer, "Knife") and now - state.LastKnife >= 0.08 then
                    local target = getAimTarget("Knife")
                    if target and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                        knifeAttack(target)
                    end
                end
            end

            local bagText, bagFull = coinBagText()
            coinLabel.Text = "Coin bag: " .. bagText
            if state.CoinFarm and localAlive and not bagFull and now - state.LastCoin >= state.CoinDelay then
                farmLabel.Text = collectCoin() and "Farm: Collecting nearest coin" or "Farm: Waiting for coins"
            elseif bagFull then
                farmLabel.Text = "Farm: Coin bag full"
                handleFullBag()
            else
                farmLabel.Text = state.CoinFarm and "Farm: Waiting for round" or "Farm: Idle"
            end
            if state.AutoOpenBoxes and now - state.LastBox >= state.BoxDelay then
                openSelectedBox()
                state.LastBox = now
            end
            if state.AutoPrestige and now - state.LastPrestige >= state.PrestigeDelay then
                requestPrestige()
                state.LastPrestige = now
            end
            if state.AutoSurvive and localAlive then
                local map = currentMap()
                local root = rootOf(LocalPlayer)
                if map and root then
                    root.CFrame = CFrame.new(map:GetPivot().Position + Vector3.new(0, 180, 0))
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end
            if state.AutoTeleportLobby and state.LastRoundAlive and not localAlive then
                teleportToLobby()
            end
            state.LastRoundAlive = localAlive
            if state.ServerHopOnLow and #Players:GetPlayers() <= state.PlayerThreshold then
                serverHop()
            end

            for _, player in ipairs(Players:GetPlayers()) do
                updatePlayerEsp(player)
                updateAura(player)
            end
            updateDroppedGunEsp()
            updateFov()
            updateAppearance()
            updateWorld()
            visualLabel.Text = state.EspEnabled and "ESP: Role-aware overlays active" or "ESP: Idle"
            task.wait(0.12)
        end
    end)

    SheriffSection:AddToggle({Name = "Auto Kill Murderer", Flag = "mm2_auto_kill_murderer", Default = false, Callback = function(v) state.AutoKillMurderer = v end})
    SheriffSection:AddToggle({Name = "Auto Shoot Murderer", Description = "Shoots inside FOV after wall and knife checks", Flag = "mm2_auto_shoot_murderer", Default = false, Callback = function(v) state.AutoShootMurderer = v end})
    SheriffSection:AddToggle({Name = "Auto Grab Dropped Gun", Flag = "mm2_auto_grab_gun", Default = false, Callback = function(v) state.AutoGrabGun = v end})
    SheriffSection:AddButton({Name = "Grab Dropped Gun Now", Callback = grabDroppedGun})

    MurdererSection:AddToggle({Name = "Knife Kill All", Flag = "mm2_kill_all_knife", Default = false, Callback = function(v) state.KillAllKnife = v end})
    MurdererSection:AddToggle({Name = "Knife Reach", Flag = "mm2_knife_reach", Default = false, Callback = function(v) state.KnifeReach = v end})
    MurdererSection:AddSlider({Name = "Reach Distance", Flag = "mm2_knife_reach_distance", Min = 3, Max = 40, Step = 1, Default = 15, Suffix = " studs", Callback = function(v) state.KnifeReachDistance = tonumber(v) or 15 end})
    MurdererSection:AddToggle({Name = "Auto Equip Knife", Flag = "mm2_equip_knife", Default = false, Callback = function(v) state.AutoEquipKnife = v end})
    MurdererSection:AddSlider({Name = "Equip Knife Delay", Flag = "mm2_equip_knife_delay", Min = 0.1, Max = 3, Step = 0.1, Default = 1.1, Callback = function(v) state.EquipKnifeDelay = tonumber(v) or 1.1 end})

    AimSection:AddToggle({Name = "Silent Aim", Flag = "mm2_silent_aim", Default = false, Callback = function(v) state.SilentAim = v end})
    AimSection:AddToggle({Name = "Knife", Flag = "mm2_knife_silent_aim", Default = true, Callback = function(v) state.SilentAimKnife = v end})
    AimSection:AddToggle({Name = "Knife Wall Check", Flag = "mm2_wall_check_knife", Default = false, Callback = function(v) state.WallCheckKnife = v end})
    AimSection:AddToggle({Name = "Gun", Flag = "mm2_gun_silent_aim", Default = true, Callback = function(v) state.SilentAimGun = v end})
    AimSection:AddToggle({Name = "Gun Wall Check", Flag = "mm2_wall_check_gun", Default = false, Callback = function(v) state.WallCheckGun = v end})
    AimSection:AddToggle({Name = "Shoot When Knife Visible", Description = "Only targets the murderer once the knife is out", Flag = "mm2_shoot_when_knife_visible", Default = false, Callback = function(v) state.ShootWhenKnifeVisible = v end})
    AimSection:AddToggle({Name = "Aim Visualizer", Flag = "mm2_aim_visualizer", Default = false, Callback = function(v) state.AimVisualizer = v end})
    AimSection:AddSlider({Name = "FOV Size", Flag = "mm2_fov_size", Min = 30, Max = 500, Step = 5, Default = 200, Suffix = " px", Callback = function(v) state.FovRadius = tonumber(v) or 200 end})

    local flingOptions = {"None"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            flingOptions[#flingOptions + 1] = player.Name
        end
    end
    FlingSection:AddToggle({Name = "Auto Fling Sheriff", Flag = "mm2_auto_fling_sheriff", Default = false, Callback = function(v) state.AutoFlingSheriff = v end})
    FlingSection:AddToggle({Name = "Touch Fling", Description = "Players touched at close range receive the fling pulse", Flag = "mm2_touch_fling", Default = false, Callback = function(v) state.TouchFling = v end})
    FlingSection:AddToggle({Name = "Fling Spin", Flag = "mm2_fling_spin", Default = true, Callback = function(v) state.FlingSpin = v end})
    FlingSection:AddDropdown({Name = "Player", Flag = "mm2_fling_player", Options = flingOptions, Default = "None", Callback = function(v) state.SelectedFlingPlayer = v or "" end})
    FlingSection:AddButton({Name = "Fling Selected Player", Callback = function() flingPlayer(Players:FindFirstChild(state.SelectedFlingPlayer)) end})
    FlingSection:AddButton({Name = "Fling Murderer", Callback = function() flingPlayer(playerWithRole("Murderer")) end})
    FlingSection:AddButton({Name = "Fling Sheriff", Callback = function() flingPlayer(playerWithRole("Sheriff")) end})

    CoinSection:AddToggle({Name = "Coin Farm", Flag = "mm2_coin_farm", Default = false, Callback = function(v) state.CoinFarm = v end})
    CoinSection:AddToggle({Name = "End Round When Full", Flag = "mm2_end_round_full", Default = false, Callback = function(v) state.EndRoundWhenFull = v end})
    CoinSection:AddToggle({Name = "Avoid Murderer and Sheriff", Flag = "mm2_avoid_mode", Default = false, Callback = function(v) state.AvoidMode = v end})
    CoinSection:AddDropdown({Name = "Teleport Method", Flag = "mm2_coin_method", Options = {"Tween", "Teleport"}, Default = "Tween", Callback = function(v) state.CoinMethod = v or "Tween" end})
    CoinSection:AddSlider({Name = "Tween Speed", Flag = "mm2_coin_speed", Min = 5, Max = 100, Step = 1, Default = 16, Callback = function(v) state.CoinSpeed = tonumber(v) or 16 end})
    CoinSection:AddSlider({Name = "Height", Flag = "mm2_coin_height", Min = -5, Max = 15, Step = 1, Default = 5, Suffix = " Y", Callback = function(v) state.CoinHeight = tonumber(v) or 5 end})
    CoinSection:AddSlider({Name = "TP Delay", Flag = "mm2_coin_delay", Min = 0, Max = 3, Step = 0.05, Default = 0, Suffix = "s", Callback = function(v) state.CoinDelay = tonumber(v) or 0 end})
    CoinSection:AddToggle({Name = "Coin Hitbox", Flag = "mm2_coin_hitbox", Default = false, Callback = function(v) state.CoinHitbox = v end})
    CoinSection:AddSlider({Name = "Coin Hitbox Size", Flag = "mm2_coin_hitbox_size", Min = 1, Max = 30, Step = 1, Default = 10, Callback = function(v) state.CoinHitboxSize = tonumber(v) or 10 end})

    RoundFarmSection:AddToggle({Name = "Auto Survive Round", Flag = "mm2_auto_survive", Default = false, Callback = function(v) state.AutoSurvive = v end})
    RoundFarmSection:AddToggle({Name = "Kill All After Bag Full", Flag = "mm2_kill_all_full", Default = false, Callback = function(v) state.KillAllWhenFull = v end})
    RoundFarmSection:AddToggle({Name = "Kill Murderer On Bag Full", Description = "Sheriff or hero only", Flag = "mm2_kill_murderer_full", Default = false, Callback = function(v) state.KillMurdererWhenFull = v end})
    RoundFarmSection:AddToggle({Name = "Fling Murderer On Bag Full", Flag = "mm2_fling_murderer_full", Default = false, Callback = function(v) state.FlingMurdererWhenFull = v end})
    RoundFarmSection:AddToggle({Name = "Die After Bag Full", Flag = "mm2_die_full", Default = false, Callback = function(v) state.DieWhenFull = v end})
    RoundFarmSection:AddToggle({Name = "Die As Murderer On Full", Flag = "mm2_die_murderer_full", Default = false, Callback = function(v) state.DieMurdererWhenFull = v end})

    local boxOptions = {"MysteryBox1"}
    if syncData and syncData.MysteryBox then
        boxOptions = {}
        for name in pairs(syncData.MysteryBox) do
            boxOptions[#boxOptions + 1] = name
        end
        table.sort(boxOptions)
    end
    BoxesSection:AddDropdown({Name = "Box", Flag = "mm2_box", Options = boxOptions, Default = boxOptions[1], Callback = function(v) state.SelectedBox = v or boxOptions[1] end})
    BoxesSection:AddToggle({Name = "Auto Open Boxes", Flag = "mm2_auto_open_boxes", Default = false, Callback = function(v) state.AutoOpenBoxes = v end})
    BoxesSection:AddSlider({Name = "Box Delay", Flag = "mm2_box_delay", Min = 0.75, Max = 10, Step = 0.25, Default = 1, Callback = function(v) state.BoxDelay = tonumber(v) or 1 end})
    BoxesSection:AddButton({Name = "Open Selected Box Once", Callback = openSelectedBox})
    BoxesSection:AddToggle({Name = "Auto Prestige", Flag = "mm2_auto_prestige", Default = false, Callback = function(v) state.AutoPrestige = v end})
    BoxesSection:AddSlider({Name = "Prestige Delay", Flag = "mm2_prestige_delay", Min = 1, Max = 30, Step = 1, Default = 1, Callback = function(v) state.PrestigeDelay = tonumber(v) or 1 end})
    BoxesSection:AddButton({Name = "Prestige Once", Callback = requestPrestige})

    MovementSection:AddToggle({Name = "Auto Strafe", Flag = "mm2_auto_strafe", Default = false, Callback = function(v) state.AutoStrafe = v end})
    MovementSection:AddSlider({Name = "Strafe Multiplier", Flag = "mm2_strafe_mult", Min = 0.1, Max = 3, Step = 0.1, Default = 1, Callback = function(v) state.StrafeMultiplier = tonumber(v) or 1 end})
    MovementSection:AddToggle({Name = "WalkSpeed", Flag = "mm2_walkspeed_toggle", Default = false, Callback = function(v) state.WalkSpeedEnabled = v end})
    MovementSection:AddSlider({Name = "WalkSpeed Value", Flag = "mm2_walkspeed", Min = 16, Max = 150, Step = 1, Default = 50, Callback = function(v) state.WalkSpeed = tonumber(v) or 50 end})
    MovementSection:AddToggle({Name = "JumpPower", Flag = "mm2_jumppower_toggle", Default = false, Callback = function(v) state.JumpPowerEnabled = v end})
    MovementSection:AddSlider({Name = "JumpPower Value", Flag = "mm2_jumppower", Min = 50, Max = 200, Step = 5, Default = 50, Callback = function(v) state.JumpPower = tonumber(v) or 50 end})
    MovementSection:AddToggle({Name = "NoClip [N]", Flag = "mm2_noclip", Default = false, Callback = function(v) state.NoClip = v end})
    MovementSection:AddToggle({Name = "Float [U]", Flag = "mm2_float", Default = false, Callback = function(v) state.Float = v end})
    MovementSection:AddToggle({Name = "Fly [P]", Flag = "mm2_fly", Default = false, Callback = function(v) state.Fly = v end})
    MovementSection:AddSlider({Name = "Fly Speed", Flag = "mm2_fly_speed", Min = 10, Max = 300, Step = 5, Default = 100, Callback = function(v) state.FlySpeed = tonumber(v) or 100 end})

    SafetySection:AddToggle({Name = "Anti Void", Flag = "mm2_anti_void", Default = false, Callback = function(v) state.AntiVoid = v end})
    SafetySection:AddToggle({Name = "Anti Fling", Flag = "mm2_anti_fling", Default = false, Callback = function(v) state.AntiFling = v end})
    SafetySection:AddToggle({Name = "Disable Animations", Flag = "mm2_disable_animations", Default = false, Callback = function(v) state.DisableAnimations = v end})

    AppearanceSection:AddToggle({Name = "Override Appearance", Flag = "mm2_override_appearance", Default = false, Callback = function(v) state.OverrideAppearance = v end})
    AppearanceSection:AddDropdown({Name = "Material", Flag = "mm2_appearance_material", Options = {"Neon", "ForceField", "Plastic", "Glass"}, Default = "Neon", Callback = function(v) state.AppearanceMaterial = v or "Neon" end})
    AppearanceSection:AddToggle({Name = "Hide Clothes", Flag = "mm2_hide_clothes", Default = false, Callback = function(v) state.HideClothes = v end})
    AppearanceSection:AddToggle({Name = "China Hat", Flag = "mm2_china_hat", Default = false, Callback = function(v) state.ChinaHat = v end})

    CameraSection:AddToggle({Name = "Custom FOV", Flag = "mm2_custom_fov", Default = false, Callback = function(v) state.CustomFov = v end})
    CameraSection:AddSlider({Name = "Camera FOV", Flag = "mm2_camera_fov", Min = 40, Max = 120, Step = 1, Default = 70, Callback = function(v) state.CameraFov = tonumber(v) or 70 end})
    CameraSection:AddSlider({Name = "Max Zoom Distance", Flag = "mm2_max_zoom", Min = 20, Max = 1000, Step = 10, Default = 100, Callback = function(v) state.MaxZoom = tonumber(v) or 100 end})

    EspSection:AddToggle({Name = "Player ESP", Flag = "mm2_esp", Default = false, Callback = function(v) state.EspEnabled = v end})
    EspSection:AddToggle({Name = "Name", Flag = "mm2_esp_name", Default = true, Callback = function(v) state.EspName = v end})
    EspSection:AddToggle({Name = "Health", Flag = "mm2_esp_health", Default = true, Callback = function(v) state.EspHealth = v end})
    EspSection:AddToggle({Name = "Distance", Flag = "mm2_esp_distance", Default = true, Callback = function(v) state.EspDistance = v end})
    EspSection:AddToggle({Name = "Weapon", Flag = "mm2_esp_weapon", Default = true, Callback = function(v) state.EspWeapon = v end})
    EspSection:AddToggle({Name = "Role Flags", Flag = "mm2_esp_role", Default = true, Callback = function(v) state.EspRole = v end})
    EspSection:AddToggle({Name = "Visibility Check", Flag = "mm2_esp_visibility", Default = false, Callback = function(v) state.EspVisibility = v end})
    EspSection:AddToggle({Name = "Show Murderer", Flag = "mm2_show_murderer", Default = true, Callback = function(v) state.ShowMurderer = v end})
    EspSection:AddToggle({Name = "Show Sheriff", Flag = "mm2_show_sheriff", Default = true, Callback = function(v) state.ShowSheriff = v end})
    EspSection:AddToggle({Name = "Show Hero", Flag = "mm2_show_hero", Default = true, Callback = function(v) state.ShowHero = v end})
    EspSection:AddToggle({Name = "Show Innocent", Flag = "mm2_show_innocent", Default = true, Callback = function(v) state.ShowInnocent = v end})
    EspSection:AddToggle({Name = "Dropped Gun ESP", Flag = "mm2_dropped_gun_esp", Default = true, Callback = function(v) state.DroppedGunEsp = v end})

    RoleAuraSection:AddToggle({Name = "Murderer Aura", Flag = "mm2_aura_murderer", Default = false, Callback = function(v) state.AuraMurderer = v end})
    RoleAuraSection:AddToggle({Name = "Sheriff Aura", Flag = "mm2_aura_sheriff", Default = false, Callback = function(v) state.AuraSheriff = v end})
    RoleAuraSection:AddToggle({Name = "Hero Aura", Flag = "mm2_aura_hero", Default = false, Callback = function(v) state.AuraHero = v end})
    RoleAuraSection:AddToggle({Name = "Innocent Aura", Flag = "mm2_aura_innocent", Default = false, Callback = function(v) state.AuraInnocent = v end})

    WeaponVisualSection:AddToggle({Name = "Bullet Tracers", Flag = "mm2_bullet_tracers", Default = false, Callback = function(v) state.BulletTracers = v end})
    WeaponVisualSection:AddToggle({Name = "Hit Sound", Flag = "mm2_hit_sound", Default = false, Callback = function(v) state.HitSound = v end})
    WeaponVisualSection:AddToggle({Name = "Hit Screen Flash", Flag = "mm2_screen_flash", Default = false, Callback = function(v) state.ScreenFlash = v end})
    WeaponVisualSection:AddLabel("Role ESP and dropped-gun ESP use live MM2 round state, not backpack guesses.")

    LightingSection:AddToggle({Name = "Lighting Override", Flag = "mm2_lighting", Default = false, Callback = function(v) state.LightingOverride = v end})
    LightingSection:AddSlider({Name = "Brightness", Flag = "mm2_brightness", Min = 0, Max = 10, Step = 0.1, Default = 2, Callback = function(v) state.Brightness = tonumber(v) or 2 end})
    LightingSection:AddSlider({Name = "Clock Time", Flag = "mm2_clock_time", Min = 0, Max = 24, Step = 0.5, Default = 14, Callback = function(v) state.ClockTime = tonumber(v) or 14 end})
    LightingSection:AddSlider({Name = "Fog Start", Flag = "mm2_fog_start", Min = 0, Max = 1000, Step = 10, Default = 0, Callback = function(v) state.FogStart = tonumber(v) or 0 end})
    LightingSection:AddSlider({Name = "Fog End", Flag = "mm2_fog_end", Min = 100, Max = 100000, Step = 100, Default = 100000, Callback = function(v) state.FogEnd = tonumber(v) or 100000 end})
    LightingSection:AddSlider({Name = "Exposure", Flag = "mm2_exposure", Min = -3, Max = 3, Step = 0.1, Default = 0, Callback = function(v) state.Exposure = tonumber(v) or 0 end})

    PostSection:AddToggle({Name = "Motion Blur", Flag = "mm2_motion_blur", Default = false, Callback = function(v) state.MotionBlur = v end})
    PostSection:AddSlider({Name = "Blur Amount", Flag = "mm2_blur_amount", Min = 0, Max = 56, Step = 1, Default = 12, Callback = function(v) state.BlurAmount = tonumber(v) or 12 end})
    PostSection:AddToggle({Name = "Bloom", Flag = "mm2_bloom", Default = false, Callback = function(v) state.Bloom = v end})
    PostSection:AddSlider({Name = "Bloom Intensity", Flag = "mm2_bloom_intensity", Min = 0, Max = 5, Step = 0.1, Default = 1, Callback = function(v) state.BloomIntensity = tonumber(v) or 1 end})
    PostSection:AddSlider({Name = "Bloom Size", Flag = "mm2_bloom_size", Min = 0, Max = 56, Step = 1, Default = 24, Callback = function(v) state.BloomSize = tonumber(v) or 24 end})
    PostSection:AddToggle({Name = "Sun Rays", Flag = "mm2_sun_rays", Default = false, Callback = function(v) state.SunRays = v end})
    PostSection:AddSlider({Name = "Sun Rays Intensity", Flag = "mm2_sun_rays_intensity", Min = 0, Max = 1, Step = 0.05, Default = 0.3, Callback = function(v) state.SunRaysIntensity = tonumber(v) or 0.3 end})

    PerformanceSection:AddToggle({Name = "FPS Boost", Flag = "mm2_fps_boost", Default = false, Callback = function(v) state.FpsBoost = v end})
    PerformanceSection:AddToggle({Name = "Disable 3D Rendering", Flag = "mm2_disable_render", Default = false, Callback = function(v) state.DisableRendering = v end})
    PerformanceSection:AddButton({Name = "Restore World Visuals", Callback = function() state.LightingOverride = false state.Bloom = false state.SunRays = false state.MotionBlur = false state.DisableRendering = false updateWorld() end})

    TeleportSection:AddButton({Name = "Teleport To Lobby", Callback = teleportToLobby})
    TeleportSection:AddButton({Name = "Teleport To Main Map", Callback = teleportToMap})
    TeleportSection:AddToggle({Name = "Auto Teleport To Lobby", Flag = "mm2_auto_lobby", Default = false, Callback = function(v) state.AutoTeleportLobby = v end})

    ServerSection:AddToggle({Name = "Server Hop On Low", Flag = "mm2_hop_low", Default = false, Callback = function(v) state.ServerHopOnLow = v end})
    ServerSection:AddSlider({Name = "Players Left Threshold", Flag = "mm2_player_threshold", Min = 1, Max = 10, Step = 1, Default = 3, Callback = function(v) state.PlayerThreshold = tonumber(v) or 3 end})
    ServerSection:AddButton({Name = "Rejoin", Callback = function() pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end})
    ServerSection:AddButton({Name = "Server Hop", Callback = serverHop})

    UtilitySection:AddInput({Name = "Alt Names", Flag = "mm2_alts", Placeholder = "name1,name2", Default = "", Callback = function(value)
        table.clear(state.AltNames)
        for name in tostring(value or ""):gmatch("[^,%s]+") do
            state.AltNames[name:lower()] = true
        end
    end})
    UtilitySection:AddToggle({Name = "Prevent Killing Alts", Flag = "mm2_prevent_kill_alts", Default = false, Callback = function(v) state.PreventKillAlts = v end})
    UtilitySection:AddToggle({Name = "Prevent Coin Stealing From Alts", Flag = "mm2_prevent_coin_alts", Default = false, Callback = function(v) state.PreventCoinStealAlts = v end})
    UtilitySection:AddButton({Name = "Refresh Role Data", Callback = function()
        if roleModule and roleModule.GetLatestPlayerData then
            local ok, data = pcall(roleModule.GetLatestPlayerData)
            if ok and type(data) == "table" then
                roleModule.PlayerData = data
                setStatus("Role data refreshed", true)
            end
        end
    end})

    setStatus(roleModule and "MM2 native role adapter ready" or "Role module unavailable; using tagged weapon fallback", roleModule ~= nil)
end
