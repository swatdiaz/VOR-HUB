-- VOR Hub - Sniper Arena adapter
-- UniverseId 9534705677 | observed places 122446657157717, 126042865144779

return function(context)
    local Window = assert(context.Window, "Sniper Arena: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Sniper Arena: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local SETTINGS = context.SETTINGS or context.Settings or {}
    local track = context.Track or function(connection) return connection end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local Lighting = game:GetService("Lighting")
    local CollectionService = game:GetService("CollectionService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    local LocalMouse = LocalPlayer:GetMouse()
    local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G
    local moveMouseRelative = type(runtimeEnvironment.mousemoverel) == "function" and runtimeEnvironment.mousemoverel
        or (type(mousemoverel) == "function" and mousemoverel or nil)
    local clickMouseOne = type(runtimeEnvironment.mouse1click) == "function" and runtimeEnvironment.mouse1click
        or (type(mouse1click) == "function" and mouse1click or nil)

    local function installSniperArenaBackground()
        local requestFunction = runtimeEnvironment.request or runtimeEnvironment.http_request
            or (type(runtimeEnvironment.syn) == "table" and runtimeEnvironment.syn.request)
        local writeFile = runtimeEnvironment.writefile
        local isFile = runtimeEnvironment.isfile
        local makeFolder = runtimeEnvironment.makefolder
        local isFolder = runtimeEnvironment.isfolder
        local customAsset = runtimeEnvironment.getcustomasset or runtimeEnvironment.getsynasset
        if type(requestFunction) ~= "function" or type(writeFile) ~= "function"
            or type(customAsset) ~= "function" then return false end

        local assetFolder = "VORHub/Assets"
        local assetPath = assetFolder .. "/sniper_arena_9534705677.png"
        local ok = pcall(function()
            if type(makeFolder) == "function" then
                if type(isFolder) ~= "function" or not isFolder("VORHub") then makeFolder("VORHub") end
                if type(isFolder) ~= "function" or not isFolder(assetFolder) then makeFolder(assetFolder) end
            end
            if type(isFile) ~= "function" or not isFile(assetPath) then
                local metadataJson = game:HttpGet("https://thumbnails.roblox.com/v1/games/icons?universeIds=9534705677&returnPolicy=PlaceHolder&size=512x512&format=Png&isCircular=false")
                local metadata = HttpService:JSONDecode(metadataJson)
                local imageUrl = metadata and metadata.data and metadata.data[1] and metadata.data[1].imageUrl
                assert(type(imageUrl) == "string" and imageUrl ~= "", "Sniper Arena thumbnail URL unavailable")
                local response = requestFunction({Url = imageUrl, Method = "GET"})
                local body = response and (response.Body or response.body)
                assert(type(body) == "string" and #body > 0, "Sniper Arena thumbnail download failed")
                writeFile(assetPath, body)
            end
            SETTINGS.PanelBackgrounds = SETTINGS.PanelBackgrounds or {}
            SETTINGS.PanelBackgrounds["🎯 Sniper Arena"] = customAsset(assetPath)
            SETTINGS.DefaultPanelBackground = "🎯 Sniper Arena"
        end)
        return ok
    end

    installSniperArenaBackground()

    local previousCleanup = runtimeEnvironment.__VORSniperArenaCleanup
    runtimeEnvironment.__VORSniperArenaCleanup = nil
    if type(previousCleanup) == "function" then pcall(previousCleanup) end

    local Remote = ReplicatedStorage:FindFirstChild("Remote")
    local Config = ReplicatedStorage:FindFirstChild("Config")
    local Client = ReplicatedStorage:FindFirstChild("Client")

    local function safeRequire(module)
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok, value = pcall(require, module)
        return ok and value or nil
    end

    local WeaponService = safeRequire(Remote and Remote:FindFirstChild("WeaponService"))
    local WeaponStore = safeRequire(Remote and Remote:FindFirstChild("WeaponService") and Remote.WeaponService:FindFirstChild("LocalWeaponStore"))
    local LoadoutService = safeRequire(Remote and Remote:FindFirstChild("LoadoutService"))
    local BackpackService = safeRequire(Remote and Remote:FindFirstChild("BackpackService"))
    local CombatService = safeRequire(Remote and Remote:FindFirstChild("CombatService"))
    local EntityService = safeRequire(Remote and Remote:FindFirstChild("EntityService"))
    local StatusService = safeRequire(Remote and Remote:FindFirstChild("StatusService"))
    local StatsStore = safeRequire(Remote and Remote:FindFirstChild("StatsService") and Remote.StatsService:FindFirstChild("LocalStatsStore"))
    local QuestService = safeRequire(Remote and Remote:FindFirstChild("QuestService"))
    local MailboxService = safeRequire(Remote and Remote:FindFirstChild("MailboxService"))
    local MailboxStore = safeRequire(Remote and Remote:FindFirstChild("MailboxService") and Remote.MailboxService:FindFirstChild("LocalMailboxStore"))
    local MatchmakingService = safeRequire(Remote and Remote:FindFirstChild("MatchmakingService"))
    local CareerStore = safeRequire(Remote and Remote:FindFirstChild("CareerStatsService") and Remote.CareerStatsService:FindFirstChild("LocalCareerStatsStore"))
    local GachaService = safeRequire(Remote and Remote:FindFirstChild("GachaService"))
    local GachaConfig = safeRequire(Config and Config:FindFirstChild("GachaConfig")) or {}
    local CombatController = Client and Client:FindFirstChild("CombatController")
    local CombatControllerApi = safeRequire(CombatController)
    local WeaponControllerApi = safeRequire(Client and Client:FindFirstChild("WeaponController"))
    local ClientComponent = CombatController and CombatController:FindFirstChild("ClientComponent")
    local ClientShootableComponent = safeRequire(ClientComponent and ClientComponent:FindFirstChild("ClientShootableComponent"))
    local SlideHelper = safeRequire(Client and Client:FindFirstChild("CombatHelper") and Client.CombatHelper:FindFirstChild("Slide"))
    local GameConfig = safeRequire(Config and Config:FindFirstChild("Config")) or {}
    local WeaponConfig = safeRequire(Config and Config:FindFirstChild("Config") and Config.Config:FindFirstChild("Weapon")) or {}
    local CosmeticConfig = safeRequire(Config and Config:FindFirstChild("WeaponConfig")) or {}
    local MatchConfig = safeRequire(Config and Config:FindFirstChild("Config") and Config.Config:FindFirstChild("Matchmaking")) or {}

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local CombatPage = addHomeCategory("🎯 Combat", 1, CATEGORY_DECALS.Combat)
    local InventoryPage = addHomeCategory("🎒 Inventory", 2, CATEGORY_DECALS.Mastery or CATEGORY_DECALS.Progress)
    local ProgressPage = addHomeCategory("🏆 Progress", 3, CATEGORY_DECALS.Progress)
    local VisualsPage = addHomeCategory("👁️ Visuals", 4, CATEGORY_DECALS.Visuals)
    local PlayerPage = addHomeCategory("🧍 Player", 5, CATEGORY_DECALS.Player or CATEGORY_DECALS.World)
    local WorldPage = addHomeCategory("🌍 World", 6, CATEGORY_DECALS.World or CATEGORY_DECALS.Player)

    local AimSection = CombatPage:AddSection("Aim Assist", "Left")
    local CombatStatusSection = CombatPage:AddSection("Combat Status", "Right")
    local WeaponModsSection = CombatPage:AddSection("Weapon Mods", "Left")
    local WeaponSection = InventoryPage:AddSection("Owned Snipers", "Left")
    local UnlockSection = InventoryPage:AddSection("Server Unlock Progress", "Right")
    local CosmeticSection = InventoryPage:AddSection("FE Cosmetic Showcase", "Left")
    local CaseSection = InventoryPage:AddSection("Owned Cases", "Right")
    local ClaimSection = ProgressPage:AddSection("Claims", "Left")
    local CoachSection = ProgressPage:AddSection("What To Do Next", "Right")
    local EspSection = VisualsPage:AddSection("Enemy ESP", "Left")
    local VisibilitySection = VisualsPage:AddSection("Visibility", "Right")
    local QueueSection = WorldPage:AddSection("Matchmaking", "Left")
    local MovementSection = PlayerPage:AddSection("Movement", "Left")
    local PlayerStatusSection = PlayerPage:AddSection("Player Status", "Right")
    local WorldStatusSection = WorldPage:AddSection("Server Status", "Right")

    HomePage:AddSection("Sniper Arena Support", "Left"):AddParagraph({
        Title = "Progression + local showcase",
        Content = "Earned progression stays server-checked. FE Cosmetic Showcase is a separate local-only preview: it changes what you see without claiming ownership or changing server damage.",
    })
    local guide = HomePage:AddSection("Quick Start", "Right")
    guide:AddParagraph({Title = "Combat", Content = "Silent Aim redirects native shot rays without moving the camera. Cursor Aimbot visibly tracks targets. Trigger Assist, hitbox expansion, recoil, spread, and reload controls are separate toggles."})
    guide:AddParagraph({Title = "Progress", Content = "Use Auto Unlock Earned Snipers and Auto Claim. The server still enforces kill requirements and reward readiness."})
    guide:AddParagraph({Title = "Cosmetics", Content = "FE Cosmetic Showcase previews sniper, melee, glove, and charm skins only on your client. Toggle it off to restore the server-equipped look."})
    guide:AddButton({Name = "Open Combat", Persist = false, Callback = function() selectHomeCategory("🎯 Combat") end})
    guide:AddButton({Name = "Open Progress", Persist = false, Callback = function() selectHomeCategory("🏆 Progress") end})

    local defaults = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        ExposureCompensation = Lighting.ExposureCompensation,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ShadowSoftness = Lighting.ShadowSoftness,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Technology = Lighting.Technology,
        QualityLevel = (function()
            local value
            pcall(function() value = settings().Rendering.QualityLevel end)
            return value
        end)(),
        CameraFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
    }
    local state = {
        Alive = true,
        AimAssist = true,
        SilentAim = false,
        SilentAimChance = 100,
        SilentAimPrediction = 0,
        AimActivation = "While Aiming",
        AimPart = "Head",
        AimRadius = 2000,
        AimSmoothness = 10,
        TeamCheck = true,
        WallCheck = false,
        ShowFov = false,
        TriggerBot = false,
        TriggerDelay = 0,
        TriggerClicks = 0,
        TriggerNativeAttempts = 0,
        TriggerNativeShots = 0,
        TriggerMouseFallbacks = 0,
        TriggerRaycastHits = 0,
        TriggerViewmodelBlocks = 0,
        TriggerBlockReason = "idle",
        LastTriggerTarget = "",
        HitboxAssistedShots = 0,
        HitboxExpand = false,
        HitboxSize = 5,
        NoRecoil = false,
        NoSpread = false,
        FastReload = false,
        ModifiedWeaponValues = 0,
        EnemyEsp = false,
        EspRefreshes = 0,
        EspLastError = "",
        EspNameText = false,
        EspNameRange = 350,
        EspMaxDistance = 2000,
        EspColor = Color3.fromRGB(72, 205, 255),
        EspAccent = Color3.fromRGB(155, 103, 255),
        EspFillTransparency = 0.78,
        Fullbright = false,
        RealismGraphics = false,
        RealismStrength = 0.82,
        RealismDepthOfField = false,
        RealismFutureApplied = false,
        FovOverride = false,
        CameraFov = 80,
        IsAiming = false,
        IsFiring = false,
        AutoUnlock = false,
        AutoTasks = false,
        AutoMail = false,
        AutoOnlineRewards = false,
        AutoOpenCases = false,
        CaseBatchSize = 5,
        CasesOpened = 0,
        LastCaseOpen = 0,
        SlideBoost = false,
        SlideMultiplier = 1.5,
        BoostedSlides = 0,
        JumpBoost = false,
        JumpHeight = 25,
        FEUnlock = false,
        FESniperFamily = "SSG",
        FEMeleeFamily = "Karambit",
        FESelections = {Sniper = nil, Melee = nil, Glove = nil, Charm = nil},
        FEAppliedCount = 0,
        FELocalAppliedCount = 0,
        FELastApply = "Original server cosmetics",
        FELocalStatus = "Local inventory route idle",
        SelectedFamily = "SSG",
        LastClaim = 0,
        LastUnlock = 0,
        LastStatus = 0,
        LastAction = "Ready",
        CurrentTarget = nil,
    }
    local drawings = {}
    local highlights = {}
    local hitboxDefaults = setmetatable({}, {__mode = "k"})
    local weaponValueDefaults = setmetatable({}, {__mode = "k"})
    local jumpDefaults = setmetatable({}, {__mode = "k"})
    local feAppliedWeapons = setmetatable({}, {__mode = "k"})
    local feFakeKeys = {}
    local feOriginalSlots = {}
    local feCharmState
    state.GraphicsEffects = {}
    state.VisibilityControls = {}
    state.SetHiddenProperty = type(runtimeEnvironment.sethiddenproperty) == "function" and runtimeEnvironment.sethiddenproperty
        or (type(sethiddenproperty) == "function" and sethiddenproperty or nil)

    state.EnsureGraphicsEffect = function(className, name)
        local effect = state.GraphicsEffects[name]
        if effect and effect.Parent == Lighting then return effect end
        effect = Instance.new(className)
        effect.Name = name
        effect.Parent = Lighting
        state.GraphicsEffects[name] = effect
        return effect
    end

    state.DestroyGraphicsEffects = function()
        for name, effect in pairs(state.GraphicsEffects) do
            if effect then pcall(function() effect:Destroy() end) end
            state.GraphicsEffects[name] = nil
        end
    end

    state.RestoreGraphicsDefaults = function()
        Lighting.Brightness = defaults.Brightness
        Lighting.ClockTime = defaults.ClockTime
        Lighting.ExposureCompensation = defaults.ExposureCompensation
        Lighting.Ambient = defaults.Ambient
        Lighting.OutdoorAmbient = defaults.OutdoorAmbient
        Lighting.EnvironmentDiffuseScale = defaults.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = defaults.EnvironmentSpecularScale
        Lighting.ShadowSoftness = defaults.ShadowSoftness
        Lighting.FogEnd = defaults.FogEnd
        Lighting.GlobalShadows = defaults.GlobalShadows
        if state.SetHiddenProperty then pcall(state.SetHiddenProperty, Lighting, "Technology", defaults.Technology) end
        if defaults.QualityLevel ~= nil then
            pcall(function() settings().Rendering.QualityLevel = defaults.QualityLevel end)
        end
        state.RealismFutureApplied = false
        state.DestroyGraphicsEffects()
    end

    state.ApplyRealismGraphics = function()
        if not state.RealismGraphics then
            state.RestoreGraphicsDefaults()
            return
        end

        local strength = math.clamp(tonumber(state.RealismStrength) or 0.82, 0, 1)
        Lighting.Brightness = math.max(1, defaults.Brightness + 0.2 * strength)
        Lighting.ExposureCompensation = defaults.ExposureCompensation - 0.12 * strength
        Lighting.Ambient = defaults.Ambient:Lerp(Color3.fromRGB(54, 62, 78), 0.68 * strength)
        Lighting.OutdoorAmbient = defaults.OutdoorAmbient:Lerp(Color3.fromRGB(116, 128, 150), 0.52 * strength)
        Lighting.EnvironmentDiffuseScale = math.clamp(defaults.EnvironmentDiffuseScale * (1 - 0.25 * strength), 0, 1)
        Lighting.EnvironmentSpecularScale = math.clamp(math.max(defaults.EnvironmentSpecularScale, 0.88 + 0.12 * strength), 0, 1)
        Lighting.ShadowSoftness = defaults.ShadowSoftness + (0.12 - defaults.ShadowSoftness) * (0.9 * strength)
        Lighting.FogEnd = defaults.FogEnd
        Lighting.GlobalShadows = true

        if not state.RealismFutureApplied or Lighting.Technology ~= Enum.Technology.Future then
            local applied = false
            if state.SetHiddenProperty then
                applied = pcall(state.SetHiddenProperty, Lighting, "Technology", Enum.Technology.Future)
            end
            state.RealismFutureApplied = applied
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level21 end)
        end

        local color = state.EnsureGraphicsEffect("ColorCorrectionEffect", "VORSniperRealismColor")
        color.Enabled = true
        color.Brightness = -0.04 * strength
        color.Contrast = 0.28 * strength
        color.Saturation = 0.035 * strength
        color.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 244, 232), 0.36 * strength)

        local bloom = state.EnsureGraphicsEffect("BloomEffect", "VORSniperRealismBloom")
        bloom.Enabled = true
        bloom.Intensity = 0.12 + 0.2 * strength
        bloom.Size = 28 + 18 * strength
        bloom.Threshold = 1.38 - 0.23 * strength

        local rays = state.EnsureGraphicsEffect("SunRaysEffect", "VORSniperRealismRays")
        rays.Enabled = true
        rays.Intensity = 0.09 * strength
        rays.Spread = 0.72

        local atmosphere = state.EnsureGraphicsEffect("Atmosphere", "VORSniperRealismAtmosphere")
        atmosphere.Density = 0.22 * strength
        atmosphere.Offset = 0.05
        atmosphere.Color = Color3.fromRGB(205, 220, 235)
        atmosphere.Decay = Color3.fromRGB(92, 105, 126)
        atmosphere.Glare = 0.24 * strength
        atmosphere.Haze = 1.45 * strength

        local depth = state.EnsureGraphicsEffect("DepthOfFieldEffect", "VORSniperRealismDepth")
        depth.Enabled = state.RealismDepthOfField == true
        depth.FarIntensity = 0.13 * strength
        depth.FocusDistance = 38
        depth.InFocusRadius = 30
        depth.NearIntensity = 0.055 * strength
    end

    local originalSlide, boostedSlide
    if SlideHelper and type(SlideHelper.Slide) == "function" then
        originalSlide = SlideHelper.Slide
        boostedSlide = function(options, token)
            if not state.Alive or not state.SlideBoost then
                return originalSlide(options, token)
            end
            local adjusted = {}
            if type(options) == "table" then
                for key, value in pairs(options) do adjusted[key] = value end
            end
            local multiplier = math.clamp(tonumber(state.SlideMultiplier) or 1, 1, 3)
            if tonumber(adjusted.CustomSpeed) then
                adjusted.CustomSpeed = adjusted.CustomSpeed * multiplier
            else
                local defaultSpeed = GameConfig.Movement and tonumber(GameConfig.Movement.SlideSpeed) or 1
                adjusted.Speed = (tonumber(adjusted.Speed) or defaultSpeed) * multiplier
            end
            local result = originalSlide(adjusted, token)
            if result then state.BoostedSlides += 1 end
            return result
        end
        SlideHelper.Slide = boostedSlide
    end

    local function notify(message, color)
        Window:Notify("Sniper Arena", tostring(message), 4, color or COLORS.accentBright)
    end

    local function character(player)
        player = player or LocalPlayer
        local model = player and player.Character
        return model, model and model:FindFirstChildOfClass("Humanoid"), model and model:FindFirstChild("HumanoidRootPart")
    end

    local function serverMode()
        local server = Remote and Remote:FindFirstChild("Server")
        local mode = server and server:FindFirstChild("Mode")
        return mode and tostring(mode.Value) or "Unknown"
    end

    local function activeGameRoom()
        local roomId = LocalPlayer:GetAttribute("GameRoom")
        if roomId == nil or tostring(roomId) == "" then return nil end
        local world = workspace:FindFirstChild("World")
        local room = world and world:FindFirstChild(tostring(roomId))
        return room and room:FindFirstChild("Entities") and room or nil
    end

    local function isActiveMatch()
        return activeGameRoom() ~= nil and tonumber(LocalPlayer:GetAttribute("Health") or 0) > 0
    end

    local function sameTeam(player)
        local mode = serverMode()
        if string.find(mode, "FFA", 1, true) then return false end
        local mine, theirs = LocalPlayer:GetAttribute("Team"), player:GetAttribute("Team")
        if mine ~= nil and theirs ~= nil then return tostring(mine) == tostring(theirs) end
        return LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team
    end

    local function playerForModel(model)
        if not model then return nil end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == model then return player end
        end
        return nil
    end

    local function sameTeamModel(model)
        if not state.TeamCheck or not model then return false end
        local mode = serverMode()
        if string.find(mode, "FFA", 1, true) then return false end
        local mine = LocalPlayer:GetAttribute("Team")
        local theirs = model:GetAttribute("Team")
        local player = playerForModel(model)
        if theirs == nil and player then theirs = player:GetAttribute("Team") end
        if mine ~= nil and theirs ~= nil then return tostring(mine) == tostring(theirs) end
        return player ~= nil and sameTeam(player)
    end

    local function isEnemy(player)
        local _, humanoid, root = character(player)
        local replicatedHealth = player and tonumber(player:GetAttribute("Health"))
        return player ~= LocalPlayer and humanoid ~= nil and humanoid.Health > 0 and root ~= nil
            and (replicatedHealth == nil or replicatedHealth > 0)
            and (not state.TeamCheck or not sameTeam(player))
    end

    local function modelHealth(model, humanoid)
        local attributed = model and tonumber(model:GetAttribute("Health"))
        if attributed ~= nil then return attributed end
        return humanoid and humanoid.Health or 0
    end

    local function addHostile(records, seen, model, displayName, kind)
        if not model or not model:IsA("Model") or seen[model] or model == LocalPlayer.Character then return end
        if sameTeamModel(model) then return end
        local tempRoot = workspace:FindFirstChild("_Temp")
        if tempRoot and model:IsDescendantOf(tempRoot) then return end
        local modelPlayer = playerForModel(model) or Players:FindFirstChild(model.Name)
        local playerHealth = modelPlayer and tonumber(modelPlayer:GetAttribute("Health"))
        if playerHealth ~= nil and playerHealth <= 0 then return end
        if model:GetAttribute("Dead") == true or model:GetAttribute("Ragdoll") == true then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart", true) or model.PrimaryPart
        if not humanoid or not root or modelHealth(model, humanoid) <= 0 then return end
        seen[model] = true
        records[#records + 1] = {
            Model = model,
            Humanoid = humanoid,
            Root = root,
            Name = tostring(displayName or model:GetAttribute("DisplayName") or model.Name),
            Kind = kind or "ENEMY",
        }
    end

    local function hostileModels()
        local records, seen = {}, {}
        local highlightRoot = workspace:FindFirstChild("Highlight")
        local enemyRoot = highlightRoot and highlightRoot:FindFirstChild("Enemy")
        local holder = enemyRoot and enemyRoot:FindFirstChild("HighlightHolder")
        if holder then
            for _, model in ipairs(holder:GetChildren()) do
                if model:IsA("Model") then
                    local kind = playerForModel(model) and "PLAYER"
                        or (CollectionService:HasTag(model, "Bot") and "BOT" or "ENEMY")
                    addHostile(records, seen, model, model:GetAttribute("DisplayName") or model.Name, kind)
                end
            end
        end
        for _, tagged in ipairs(CollectionService:GetTagged("Bot")) do
            local model = tagged:IsA("Model") and tagged or tagged:FindFirstAncestorOfClass("Model")
            addHostile(records, seen, model, model and (model:GetAttribute("DisplayName") or model.Name), "BOT")
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if isEnemy(player) then addHostile(records, seen, player.Character, player.DisplayName, "PLAYER") end
        end
        return records
    end

    local function headPart(model)
        if not model then return nil end
        local collider = model:FindFirstChild("Collider")
        local colliderHead = collider and collider:FindFirstChild("Head")
        return colliderHead and colliderHead:IsA("BasePart") and colliderHead
            or model:FindFirstChild("Head", true)
    end

    local function targetPart(model)
        if not model then return nil end
        if state.AimPart == "Head" then return headPart(model) or model:FindFirstChild("HumanoidRootPart", true) end
        if state.AimPart == "Torso" then return model:FindFirstChild("UpperTorso", true) or model:FindFirstChild("Torso", true) or model:FindFirstChild("HumanoidRootPart", true) end
        return model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChild("Head", true)
    end

    local function rayVisible(part, model)
        local camera = workspace.CurrentCamera
        if not camera or not part then return false end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
        params.IgnoreWater = true
        local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
        return result == nil or result.Instance:IsDescendantOf(model or part.Parent)
    end

    local function lineOfSight(part)
        if not state.WallCheck then return true end
        local model = part and part:FindFirstAncestorOfClass("Model")
        return rayVisible(part, model)
    end

    local function visibleBodyPart(model)
        if not model then return nil end
        return model:FindFirstChild("UpperTorso", true)
            or model:FindFirstChild("Torso", true)
            or model:FindFirstChild("HumanoidRootPart", true)
    end

    local function hasVisibleBody(model)
        local body = visibleBodyPart(model)
        return body ~= nil and rayVisible(body, model)
    end

    local function acquireTarget()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local center = UserInputService:GetMouseLocation()
        local best, bestDistance = nil, state.AimRadius
        for _, hostile in ipairs(hostileModels()) do
            local part = targetPart(hostile.Model)
            if part then
                local point, visible = camera:WorldToViewportPoint(part.Position)
                if visible and point.Z > 0 then
                    local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
                    if distance < bestDistance and lineOfSight(part) then best, bestDistance = part, distance end
                end
            end
        end
        return best
    end

    local function acquireExpandedHitboxTarget()
        if not state.HitboxExpand or not isActiveMatch() then return nil end
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local pointer = UserInputService:GetMouseLocation()
        local best, bestDistance = nil, math.huge
        for _, hostile in ipairs(hostileModels()) do
            local part = hostile.Kind == "PLAYER" and headPart(hostile.Model) or nil
            if part then
                local center, visible = camera:WorldToViewportPoint(part.Position)
                if visible and center.Z > 0 then
                    local halfSize = math.clamp(state.HitboxSize, 1, 30) / 2
                    local rightEdge = camera:WorldToViewportPoint(part.Position + camera.CFrame.RightVector * halfSize)
                    local upEdge = camera:WorldToViewportPoint(part.Position + camera.CFrame.UpVector * halfSize)
                    local radius = math.max(
                        (Vector2.new(rightEdge.X, rightEdge.Y) - Vector2.new(center.X, center.Y)).Magnitude,
                        (Vector2.new(upEdge.X, upEdge.Y) - Vector2.new(center.X, center.Y)).Magnitude,
                        8
                    )
                    local distance = (Vector2.new(center.X, center.Y) - pointer).Magnitude
                    if distance <= radius and distance < bestDistance and hasVisibleBody(hostile.Model) then
                        best, bestDistance = part, distance
                    end
                end
            end
        end
        return best
    end

    local function aimActive()
        if not state.AimAssist or not isActiveMatch() then return false end
        if state.AimActivation == "Always" then return true end
        if state.AimActivation == "While Firing" then return state.IsFiring end
        return state.IsAiming or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    local function updateAim(deltaTime)
        if not aimActive() then state.CurrentTarget = nil return end
        local camera = workspace.CurrentCamera
        local part = acquireTarget()
        state.CurrentTarget = part
        if not camera or not part then return end
        local point, visible = camera:WorldToViewportPoint(part.Position)
        if not visible or point.Z <= 0 then return end
        local mousePosition = UserInputService:GetMouseLocation()
        local smoothness = math.clamp(state.AimSmoothness, 1, 30)
        local delta = Vector2.new(point.X - mousePosition.X, point.Y - mousePosition.Y)
        local distance = delta.Magnitude
        if distance < 0.75 then return end
        local response = 30 / smoothness
        local alpha = 1 - math.exp(-response * math.max(deltaTime, 1 / 240))
        local approach = math.clamp(distance / 24, 0.2, 1)
        local step = delta * math.clamp(alpha * approach, 0.002, 0.65)
        if moveMouseRelative then
            pcall(moveMouseRelative, step.X, step.Y)
        else
            local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
            camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
        end
    end

    local originalLocalShoot, originalCameraGetter, originalTargetResolver, silentCameraGetter, silentTargetResolver
    local silentAimHooked = false
    if ClientShootableComponent and type(ClientShootableComponent.LocalShoot) == "function"
        and type(debug) == "table" and type(debug.getupvalues) == "function" and type(debug.setupvalue) == "function" then
        originalLocalShoot = ClientShootableComponent.LocalShoot
        local readOk, shotUpvalues = pcall(debug.getupvalues, originalLocalShoot)
        originalCameraGetter = readOk and shotUpvalues[2] or nil
        originalTargetResolver = readOk and shotUpvalues[4] or nil
        if type(originalCameraGetter) == "function" and type(originalTargetResolver) == "function" then
            local cachedTarget, cachedAt = nil, -math.huge
            local function resolveSilentTarget()
                local now = os.clock()
                if now - cachedAt <= 0.04 then return cachedTarget end
                cachedAt, cachedTarget = now, nil
                if state.Alive and state.SilentAim and math.random(1, 100) <= state.SilentAimChance then
                    cachedTarget = acquireTarget()
                elseif state.Alive and state.HitboxExpand then
                    cachedTarget = acquireExpandedHitboxTarget()
                    if cachedTarget then state.HitboxAssistedShots += 1 end
                end
                return cachedTarget
            end
            local function predictedPosition(part)
                return part.Position + part.AssemblyLinearVelocity * state.SilentAimPrediction
            end
            silentCameraGetter = function(...)
                local originalResults = table.pack(originalCameraGetter(...))
                local part = resolveSilentTarget()
                local cameraFrame = originalResults[1]
                if part and typeof(cameraFrame) == "CFrame" then
                    state.CurrentTarget = part
                    originalResults[1] = CFrame.lookAt(cameraFrame.Position, predictedPosition(part))
                end
                return table.unpack(originalResults, 1, originalResults.n)
            end
            silentTargetResolver = function(...)
                local originalResults = table.pack(originalTargetResolver(...))
                local part = resolveSilentTarget()
                if part then
                    state.CurrentTarget = part
                    return predictedPosition(part), part
                end
                return table.unpack(originalResults, 1, originalResults.n)
            end
            local cameraInstalled = pcall(debug.setupvalue, originalLocalShoot, 2, silentCameraGetter)
            local targetInstalled = pcall(debug.setupvalue, originalLocalShoot, 4, silentTargetResolver)
            local installed = cameraInstalled and targetInstalled
            if installed then
                local verifyOk, verifyUpvalues = pcall(debug.getupvalues, originalLocalShoot)
                silentAimHooked = verifyOk and verifyUpvalues[2] == silentCameraGetter and verifyUpvalues[4] == silentTargetResolver
            end
        end
    end

    local fovCircle
    if type(Drawing) == "table" and type(Drawing.new) == "function" then
        local ok, circle = pcall(Drawing.new, "Circle")
        if ok then
            fovCircle = circle
            circle.Color = Color3.fromRGB(255, 80, 110)
            circle.Thickness = 1.5
            circle.Filled = false
            circle.Transparency = 0.85
            drawings[#drawings + 1] = circle
        end
    end

    local function updateFovCircle()
        if not fovCircle then return end
        local camera = workspace.CurrentCamera
        fovCircle.Visible = state.Alive and state.AimAssist and state.ShowFov and isActiveMatch() and camera ~= nil
        if camera then
            fovCircle.Position = UserInputService:GetMouseLocation()
            fovCircle.Radius = state.AimRadius
        end
    end

    local function restoreHitboxes()
        for head, original in pairs(hitboxDefaults) do
            if head and head.Parent then
                pcall(function()
                    head.Size = original.Size
                    head.Transparency = original.Transparency
                    head.CanCollide = original.CanCollide
                    head.CanQuery = original.CanQuery
                end)
            end
            hitboxDefaults[head] = nil
        end
    end

    local function updateHitboxes()
        if not state.HitboxExpand or not isActiveMatch() then restoreHitboxes() return end
        local active = {}
        local function expandModelHead(model)
            if not model or not model:IsA("Model") then return end
            local head = headPart(model)
            if not head or not head:IsA("BasePart") then return end
            active[head] = true
            if not hitboxDefaults[head] then
                hitboxDefaults[head] = {Size = head.Size, Transparency = head.Transparency, CanCollide = head.CanCollide, CanQuery = head.CanQuery}
            end
            local size = math.clamp(state.HitboxSize, 1, 30)
            head.Size = Vector3.new(size, size, size)
            head.Transparency = 0.5
            head.CanCollide = false
            head.CanQuery = true
        end
        for _, hostile in ipairs(hostileModels()) do
            if hostile.Kind == "PLAYER" then expandModelHead(hostile.Model) end
        end
        for head, original in pairs(hitboxDefaults) do
            if not active[head] then
                if head and head.Parent then
                    pcall(function()
                        head.Size = original.Size
                        head.Transparency = original.Transparency
                        head.CanCollide = original.CanCollide
                        head.CanQuery = original.CanQuery
                    end)
                end
                hitboxDefaults[head] = nil
            end
        end
    end

    local function hostileForTarget(instance)
        if not instance then return nil end
        for _, hostile in ipairs(hostileModels()) do
            if instance:IsDescendantOf(hostile.Model) then return hostile end
        end
        return nil
    end

    local function menuBlocksTrigger()
        if GuiService.MenuIsOpen then return true end
        if not gui or not gui.Enabled then return false end
        local mainWindow = gui:FindFirstChild("LuxuryWindow", true)
        return mainWindow == nil or mainWindow.Visible
    end

    local triggerInputToken = "VOR_TRIGGER_" .. tostring(LocalPlayer.UserId)
    local triggerInputHeld = false

    local function releaseTriggerInput()
        if not triggerInputHeld then return end
        triggerInputHeld = false
        local primaryAction = CombatControllerApi and CombatControllerApi.PrimaryAction
        if primaryAction and type(primaryAction.End) == "function" then
            pcall(primaryAction.End, triggerInputToken)
        end
    end

    local function fireTriggerInput()
        local primaryAction = CombatControllerApi and CombatControllerApi.PrimaryAction
        if primaryAction and type(primaryAction.Begin) == "function" then
            if triggerInputHeld then return false end
            triggerInputHeld = true
            state.TriggerNativeAttempts += 1
            local ok, fired = pcall(primaryAction.Begin, triggerInputToken)
            task.spawn(function()
                RunService.Heartbeat:Wait()
                releaseTriggerInput()
            end)
            if ok and fired then
                state.TriggerNativeShots += 1
                return true
            end
            return false
        end
        if clickMouseOne then
            local ok = pcall(clickMouseOne)
            if ok then state.TriggerMouseFallbacks += 1 end
            return ok
        end
        return false
    end

    state.ResolveTriggerTarget = function()
        local camera = workspace.CurrentCamera
        if camera then
            local mousePosition = Vector2.new(LocalMouse.X, LocalMouse.Y)
            if mousePosition.X <= 0 and mousePosition.Y <= 0 then
                mousePosition = camera.ViewportSize * 0.5
            end
            local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
            local filter = {camera}
            if LocalPlayer.Character then filter[#filter + 1] = LocalPlayer.Character end
            local temp = workspace:FindFirstChild("_Temp")
            if temp then filter[#filter + 1] = temp end
            local highlightRoot = workspace:FindFirstChild("Highlight")
            if highlightRoot then filter[#filter + 1] = highlightRoot end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = filter
            params.IgnoreWater = true
            params.RespectCanCollide = false
            local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
            if result and result.Instance then
                local hostile = hostileForTarget(result.Instance)
                if hostile then state.TriggerRaycastHits += 1 end
                return result.Instance, hostile
            end
        end

        local target = LocalMouse.Target
        if target and ((camera and target:IsDescendantOf(camera))
            or (LocalPlayer.Character and target:IsDescendantOf(LocalPlayer.Character))) then
            state.TriggerViewmodelBlocks += 1
            return nil, nil
        end
        return target, hostileForTarget(target)
    end

    local lastTriggerTarget, lastTriggerAt = nil, -math.huge
    local function tryTrigger()
        if not state.Alive or not state.TriggerBot then
            state.TriggerBlockReason = "disabled"
            lastTriggerTarget = nil
            return false
        end
        if not isActiveMatch() then
            state.TriggerBlockReason = "no active match"
            lastTriggerTarget = nil
            return false
        end
        if menuBlocksTrigger() then
            state.TriggerBlockReason = "VOR or Roblox menu open"
            lastTriggerTarget = nil
            return false
        end
        if UserInputService:GetFocusedTextBox() ~= nil then
            state.TriggerBlockReason = "typing"
            lastTriggerTarget = nil
            return false
        end
        local target, hostile = state.ResolveTriggerTarget()
        if hostile and state.HitboxExpand and not hasVisibleBody(hostile.Model) then
            target, hostile = nil, nil
        end
        if not hostile and state.HitboxExpand then
            target = acquireExpandedHitboxTarget()
            hostile = hostileForTarget(target)
        end
        if not target or not hostile then
            state.TriggerBlockReason = "no hostile under crosshair"
            lastTriggerTarget = nil
            return false
        end
        state.TriggerBlockReason = "hostile acquired"
        local now = os.clock()
        local firstHover = target ~= lastTriggerTarget
        local repeatDelay = math.max(tonumber(state.TriggerDelay) or 0, 1 / 240)
        if not firstHover and now - lastTriggerAt < repeatDelay then return false end
        lastTriggerTarget = target
        lastTriggerAt = now
        local clicked = fireTriggerInput()
        if clicked then
            state.TriggerClicks += 1
            state.LastTriggerTarget = target:GetFullName()
        end
        return clicked
    end

    local function restoreWeaponValues()
        for valueObject, original in pairs(weaponValueDefaults) do
            if valueObject and valueObject.Parent then
                pcall(function() valueObject.Value = original end)
            end
            weaponValueDefaults[valueObject] = nil
        end
        state.ModifiedWeaponValues = 0
    end

    local function updateWeaponModifiers()
        if not (state.NoRecoil or state.NoSpread or state.FastReload) then
            restoreWeaponValues()
            return
        end
        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if not tool then
            restoreWeaponValues()
            return
        end
        local active, modified = {}, 0
        for _, valueObject in ipairs(tool:GetDescendants()) do
            if valueObject:IsA("NumberValue") or valueObject:IsA("IntValue") or valueObject:IsA("DoubleConstrainedValue") then
                local name = valueObject.Name:lower()
                local replacement
                if state.NoRecoil and (name:find("recoil", 1, true) or name:find("kick", 1, true)) then
                    replacement = 0
                elseif state.NoSpread and (name:find("spread", 1, true) or name:find("accuracy", 1, true)) then
                    replacement = 0
                elseif state.FastReload and (name:find("reload", 1, true) or name:find("time", 1, true)) then
                    replacement = 0.05
                end
                if replacement ~= nil then
                    active[valueObject] = true
                    if weaponValueDefaults[valueObject] == nil then weaponValueDefaults[valueObject] = valueObject.Value end
                    valueObject.Value = replacement
                    modified = modified + 1
                end
            end
        end
        for valueObject, original in pairs(weaponValueDefaults) do
            if not active[valueObject] then
                if valueObject and valueObject.Parent then pcall(function() valueObject.Value = original end) end
                weaponValueDefaults[valueObject] = nil
            end
        end
        state.ModifiedWeaponValues = modified
    end

    local function clearEsp(player)
        local entry = highlights[player]
        if entry then
            for _, object in pairs(entry) do pcall(function() object:Destroy() end) end
            highlights[player] = nil
        end
    end

    local function updateEsp()
        local _, _, localRoot = character()
        local active = {}
        for _, hostile in ipairs(hostileModels()) do
            local model = hostile.Model
            local ok, err = pcall(function()
                local root = hostile.Root
                if not model or not model.Parent or not root or not root.Parent then return end
                active[model] = true
                if state.EnemyEsp then
                    local distance = localRoot and localRoot.Parent and (root.Position - localRoot.Position).Magnitude or math.huge
                    if distance <= state.EspMaxDistance then
                        local entry = highlights[model]
                        if not entry or not entry.Highlight or not entry.Highlight.Parent then
                            clearEsp(model)
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "VORSniperEnemy"
                            highlight.FillColor = state.EspColor
                            highlight.OutlineColor = state.EspAccent
                            highlight.FillTransparency = state.EspFillTransparency
                            highlight.OutlineTransparency = 0
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            highlight.Adornee = model
                            highlight.Parent = model
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "VORSniperLabel"
                            billboard.AlwaysOnTop = true
                            billboard.Size = UDim2.fromOffset(160, 20)
                            billboard.StudsOffset = Vector3.new(0, 2.85, 0)
                            billboard.Adornee = model:FindFirstChild("Head") or root
                            billboard.Parent = model
                            local label = Instance.new("TextLabel")
                            label.BackgroundTransparency = 1
                            label.Size = UDim2.fromScale(1, 1)
                            label.Font = Enum.Font.GothamMedium
                            label.TextColor3 = state.EspColor
                            label.TextStrokeColor3 = Color3.fromRGB(5, 8, 14)
                            label.TextStrokeTransparency = 0.35
                            label.TextSize = 11
                            label.Parent = billboard
                            entry = {Highlight = highlight, Billboard = billboard, Label = label}
                            highlights[model] = entry
                        end
                        entry.Highlight.FillColor = state.EspColor
                        entry.Highlight.OutlineColor = state.EspAccent
                        entry.Highlight.FillTransparency = state.EspFillTransparency
                        entry.Billboard.Enabled = state.EspNameText and distance <= state.EspNameRange
                        entry.Label.TextColor3 = state.EspColor
                        entry.Label.Text = hostile.Kind == "BOT" and "BOT" or hostile.Name
                    else clearEsp(model) end
                else clearEsp(model) end
            end)
            if not ok then
                state.EspLastError = tostring(err)
                if model then clearEsp(model) end
            end
        end
        for model in pairs(highlights) do
            if not active[model] then clearEsp(model) end
        end
        state.EspRefreshes += 1
    end

    local function ownedWeapons()
        if not WeaponStore or type(WeaponStore.GetContent) ~= "function" then return {} end
        local ok, content = pcall(WeaponStore.GetContent, WeaponStore)
        return ok and type(content) == "table" and content or {}
    end

    local function familyOf(item)
        return type(item) == "table" and tostring(item.Name or ""):match("^([^.]+)") or nil
    end

    local function ownedFamilies()
        local seen, list = {}, {}
        for _, item in pairs(ownedWeapons()) do
            local family = familyOf(item)
            if family and not seen[family] then seen[family] = true list[#list + 1] = family end
        end
        table.sort(list, function(a, b)
            local order = WeaponConfig.BaseWeaponOrder or {}
            return (tonumber(order[a]) or 999) < (tonumber(order[b]) or 999)
        end)
        return list
    end

    local function bestKeyForFamily(family)
        local bestKey, bestPrice = nil, -math.huge
        for key, item in pairs(ownedWeapons()) do
            if familyOf(item) == family then
                local price = tonumber(item.Price) or 0
                if price > bestPrice then bestKey, bestPrice = key, price end
            end
        end
        return bestKey, bestPrice
    end

    local function bestOwnedPrimary()
        local order = WeaponConfig.BaseWeaponOrder or {}
        local bestFamily, bestOrder = nil, -math.huge
        for _, family in ipairs(ownedFamilies()) do
            local rank = tonumber(order[family])
            if rank and rank <= 13 and rank > bestOrder then bestFamily, bestOrder = family, rank end
        end
        return bestFamily
    end

    local function equipFamily(family)
        if not LoadoutService or type(LoadoutService.SetSlot) ~= "function" then state.LastAction = "Loadout service unavailable" return false end
        local key = bestKeyForFamily(family)
        if not key then state.LastAction = "No owned " .. tostring(family) return false end
        local changed = 0
        for index = 1, 3 do
            local ok, result = pcall(LoadoutService.SetSlot, index, "Primary", key)
            if ok and result ~= false then changed = changed + 1 end
        end
        state.LastAction = changed > 0 and ("Equipped best owned " .. family) or ("Server rejected " .. family .. " loadout")
        return changed > 0
    end

    local function creditedKills()
        if StatusService and type(StatusService.GetStatus) == "function" then
            local ok, value = pcall(StatusService.GetStatus, "Killed")
            if ok then return tonumber(value) or 0 end
        end
        return 0
    end

    local function unlockEarned()
        if not WeaponService or type(WeaponService.Unlock) ~= "function" then state.LastAction = "Weapon unlock service unavailable" return 0 end
        local kills, unlocked = creditedKills(), 0
        for family, required in pairs(WeaponConfig.KilledUnlock or {}) do
            local owned = type(WeaponService.HasWeapon) == "function" and WeaponService.HasWeapon(family)
            if not owned and kills >= (tonumber(required) or math.huge) then
                local ok, result = pcall(WeaponService.Unlock, family)
                if ok and result ~= false then unlocked = unlocked + 1 end
            end
        end
        state.LastAction = unlocked > 0 and string.format("Server unlocked %d earned sniper(s)", unlocked)
            or "No newly earned sniper unlocks"
        return unlocked
    end

    local function claimTasks()
        if not QuestService or type(QuestService.GetData) ~= "function" or type(QuestService.ClaimReward) ~= "function" then return 0 end
        local ok, data = pcall(QuestService.GetData)
        local claimed = 0
        for name in pairs(ok and data and data.Quests or {}) do
            local finished = type(QuestService.IsFinished) == "function" and QuestService.IsFinished(name)
            local already = type(QuestService.IsClaimed) == "function" and QuestService.IsClaimed(name)
            if finished and not already then
                local callOk, result = pcall(QuestService.ClaimReward, name, nil)
                if callOk and result ~= false then claimed = claimed + 1 end
            end
        end
        if claimed > 0 then state.LastAction = string.format("Claimed %d task reward(s)", claimed) end
        return claimed
    end

    local function claimMail()
        if not MailboxService or not MailboxStore or type(MailboxService.Claim) ~= "function" then return 0 end
        local claimed = 0
        local mails = MailboxStore.Data and MailboxStore.Data.Mails or {}
        for id, mail in pairs(mails) do
            if type(mail) == "table" and not mail.Claimed then
                local ok, result = pcall(MailboxService.Claim, id)
                if ok and result ~= false then claimed = claimed + 1 end
            end
        end
        if claimed > 0 then state.LastAction = string.format("Claimed %d mailbox reward(s)", claimed) end
        return claimed
    end

    local function claimOnlineRewards()
        local rewards = Remote and Remote:FindFirstChild("Rewards")
        local claim = rewards and rewards:FindFirstChild("OnlineRewardClaim")
        if not claim or not claim:IsA("RemoteFunction") then return 0 end
        local claimed = 0
        for index = 1, 9 do
            local ok, result = pcall(claim.InvokeServer, claim, index)
            if ok and result ~= false and result ~= nil then claimed = claimed + 1 end
        end
        if claimed > 0 then state.LastAction = string.format("Claimed %d online reward(s)", claimed) end
        return claimed
    end

    local function ownedCases()
        local cases = {}
        local store = GachaService and GachaService.LocalGachaStore
        if not store then return cases end
        local ok, data = pcall(store.data, store)
        if not ok or type(data) ~= "table" then return cases end
        for id, entry in pairs(data) do
            local owned = type(entry) == "table" and tonumber(entry.Owned) or 0
            if owned and owned > 0 and GachaConfig[id] then
                cases[#cases + 1] = {Id = id, Owned = owned, Display = tostring(GachaConfig[id].Display or id)}
            end
        end
        table.sort(cases, function(a, b) return a.Display < b.Display end)
        return cases
    end

    local function openOwnedCases()
        if not GachaService or type(GachaService.Gacha) ~= "function" then
            state.LastAction = "Case service unavailable"
            return 0
        end
        if os.clock() - state.LastCaseOpen < 0.75 then return 0 end
        state.LastCaseOpen = os.clock()
        local cases = ownedCases()
        if #cases == 0 then
            state.LastAction = "No owned cases ready"
            return 0
        end
        local selected = cases[1]
        local count = math.min(selected.Owned, math.clamp(state.CaseBatchSize, 1, 5))
        local ok, result = pcall(GachaService.Gacha, selected.Id, count)
        if not ok or type(result) ~= "table" or not result.Success then
            local message = type(result) == "table" and (result.Message or result.Error) or result
            state.LastAction = "Case open stopped: " .. tostring(message or "server rejected request")
            return 0
        end
        state.CasesOpened += count
        state.LastAction = string.format("Opened %d %s", count, selected.Display)
        local finish = Remote and Remote:FindFirstChild("GachaService") and Remote.GachaService:FindFirstChild("GachaEnd")
        if finish and finish:IsA("RemoteEvent") then pcall(finish.FireServer, finish) end
        return count
    end

    local function queue(name)
        if not MatchmakingService or type(MatchmakingService.Match) ~= "function" then notify("Matchmaking unavailable", COLORS.warning) return end
        local ok, result = pcall(MatchmakingService.Match, name)
        state.LastAction = ok and result ~= false and ("Queued for " .. name) or ("Queue failed: " .. tostring(result))
        notify(state.LastAction, ok and COLORS.success or COLORS.warning)
    end

    local ORIGINAL_COSMETIC = "Original / Server Equipped"
    local cosmeticCatalog = {Sniper = {}, Melee = {}, Glove = {}, Charm = {}}
    local cosmeticKeyByLabel = {}
    state.CosmeticBrowserGui = nil
    state.CosmeticBrowserRoot = nil
    state.CosmeticItemsByKind = {Sniper = {}, Melee = {}, Glove = {}, Charm = {}}
    state.CosmeticLabelByKey = {}

    do
    local function cosmeticImage(config)
        if type(config) ~= "table" then return "" end
        local image = config.Image or config.Icon or config.Thumbnail or config.ImageId
            or config.IconId or config.ThumbnailId or config.TextureId or config.AssetId
        if (image == nil or image == "") and type(config.Instances) == "table" then
            local imageLabel = config.Instances.ImageLabel
            if typeof(imageLabel) == "Instance" and imageLabel:IsA("ImageLabel") then
                image = imageLabel.Image
            end
        end
        if type(image) == "table" then image = image.Image or image.AssetId or image.Id or image[1] end
        if type(image) == "number" then return "rbxassetid://" .. tostring(math.floor(image)) end
        if type(image) ~= "string" or image == "" then return "" end
        if string.find(image, "rbxassetid://", 1, true) == 1 or string.find(image, "rbxthumb://", 1, true) == 1
            or string.find(image, "http://", 1, true) == 1 or string.find(image, "https://", 1, true) == 1 then
            return image
        end
        local numeric = tonumber(image)
        return numeric and ("rbxassetid://" .. tostring(math.floor(numeric))) or image
    end

    for key, config in pairs(CosmeticConfig) do
        if type(key) == "string" and type(config) == "table" and type(config.Display) == "string" then
            local weaponType = tostring(config.WeaponType or "")
            local bucket = cosmeticCatalog[weaponType]
            if bucket then
                local family = tostring(config.Family or weaponType)
                bucket[family] = bucket[family] or {}
                local label = string.format("%s  [%s]", config.Display, key)
                bucket[family][#bucket[family] + 1] = label
                cosmeticKeyByLabel[label] = key
                state.CosmeticLabelByKey[key] = label
                state.CosmeticItemsByKind[weaponType][#state.CosmeticItemsByKind[weaponType] + 1] = {
                    Kind = weaponType,
                    Family = family,
                    Key = key,
                    Label = label,
                    Display = config.Display,
                    Image = cosmeticImage(config),
                    Rarity = tostring(config.Rarity or "Standard"),
                    Search = string.lower(table.concat({config.Display, key, family, tostring(config.Rarity or "")}, " ")),
                }
            end
        end
    end
    end
    for _, familiesByType in pairs(cosmeticCatalog) do
        for _, labels in pairs(familiesByType) do
            table.sort(labels, function(a, b) return string.lower(a) < string.lower(b) end)
        end
    end
    for _, items in pairs(state.CosmeticItemsByKind) do
        table.sort(items, function(a, b) return string.lower(a.Display) < string.lower(b.Display) end)
    end

    do
    local COSMETIC_STATE_PATH = "VORHub/SniperArenaCosmetics.json"
    local COSMETIC_STATE_VERSION = 1
    local function validCosmeticSelection(kind, key)
        local config = type(key) == "string" and CosmeticConfig[key] or nil
        return config and tostring(config.WeaponType or "") == kind and key or nil
    end
    local function readSavedCosmeticState()
        local saved = runtimeEnvironment.__VORSniperArenaCosmetics
        local readFile = runtimeEnvironment.readfile
        local isFile = runtimeEnvironment.isfile
        if type(saved) ~= "table" and type(readFile) == "function" and type(isFile) == "function" then
            local ok, decoded = pcall(function()
                if not isFile(COSMETIC_STATE_PATH) then return nil end
                return HttpService:JSONDecode(readFile(COSMETIC_STATE_PATH))
            end)
            if ok and type(decoded) == "table" then saved = decoded end
        end
        if type(saved) ~= "table" or tonumber(saved.Version) ~= COSMETIC_STATE_VERSION then
            state.CosmeticPersistenceReady = true
            return
        end
        state.CosmeticResume = saved
        state.CosmeticPersistenceReady = false
        state.FEUnlock = saved.Enabled == true
        state.FESniperFamily = tostring(saved.SniperFamily or state.FESniperFamily)
        state.FEMeleeFamily = tostring(saved.MeleeFamily or state.FEMeleeFamily)
        local selections = type(saved.Selections) == "table" and saved.Selections or {}
        for _, kind in ipairs({"Sniper", "Melee", "Glove", "Charm"}) do
            state.FESelections[kind] = validCosmeticSelection(kind, selections[kind])
        end
        if state.FESelections.Sniper then state.FESniperFamily = tostring(CosmeticConfig[state.FESelections.Sniper].Family or state.FESniperFamily) end
        if state.FESelections.Melee then state.FEMeleeFamily = tostring(CosmeticConfig[state.FESelections.Melee].Family or state.FEMeleeFamily) end
    end

    state.SaveCosmeticState = function()
        if state.CosmeticPersistenceReady == false then return end
        local payload = {
            Version = COSMETIC_STATE_VERSION,
            Enabled = state.FEUnlock == true,
            SniperFamily = state.FESniperFamily,
            MeleeFamily = state.FEMeleeFamily,
            Selections = {
                Sniper = state.FESelections.Sniper,
                Melee = state.FESelections.Melee,
                Glove = state.FESelections.Glove,
                Charm = state.FESelections.Charm,
            },
        }
        runtimeEnvironment.__VORSniperArenaCosmetics = payload
        local writeFile = runtimeEnvironment.writefile
        if type(writeFile) ~= "function" then return end
        pcall(function()
            local makeFolder = runtimeEnvironment.makefolder
            local isFolder = runtimeEnvironment.isfolder
            if type(makeFolder) == "function" then
                if type(isFolder) ~= "function" or not isFolder("VORHub") then makeFolder("VORHub") end
            end
            writeFile(COSMETIC_STATE_PATH, HttpService:JSONEncode(payload))
        end)
    end
    readSavedCosmeticState()
    end

    local function cosmeticFamilies(kind)
        local result = {}
        for family, labels in pairs(cosmeticCatalog[kind] or {}) do
            if #labels > 0 then result[#result + 1] = family end
        end
        table.sort(result)
        return result
    end

    local function cosmeticOptions(kind, family)
        local result = {ORIGINAL_COSMETIC}
        if family then
            for _, label in ipairs((cosmeticCatalog[kind] or {})[family] or {}) do result[#result + 1] = label end
        else
            for _, labels in pairs(cosmeticCatalog[kind] or {}) do
                for _, label in ipairs(labels) do result[#result + 1] = label end
            end
            table.sort(result, function(a, b)
                if a == ORIGINAL_COSMETIC then return true end
                if b == ORIGINAL_COSMETIC then return false end
                return string.lower(a) < string.lower(b)
            end)
        end
        return result
    end

    local localSetEquip
    if BackpackService and type(BackpackService.TryEquip) == "function" and type(debug) == "table"
        and type(debug.getupvalue) == "function" then
        local ok, first, second = pcall(debug.getupvalue, BackpackService.TryEquip, 5)
        localSetEquip = ok and (type(first) == "function" and first or type(second) == "function" and second) or nil
    end

    local function selectedCosmetic(kind)
        local key = state.FESelections[kind]
        return key and CosmeticConfig[key] and key or nil
    end

    local function fakeKeyFor(kind, configKey)
        return "__VOR_FE_" .. kind .. "_" .. tostring(configKey):gsub("[^%w_]", "_")
    end

    local function ensureFakeCosmetic(kind, configKey)
        if not WeaponStore or type(WeaponStore.GetWeapon) ~= "function" or type(WeaponStore.AddOne) ~= "function" then return nil end
        local fakeKey = fakeKeyFor(kind, configKey)
        local itemData = {
            Name = configKey,
            CreateTime = workspace:GetServerTimeNow(),
            Seed = 0.5,
            WearFactor = 0,
        }
        if not WeaponStore:GetWeapon(fakeKey) then
            pcall(WeaponStore.AddOne, WeaponStore, fakeKey, itemData)
        end
        local content = WeaponService and type(WeaponService.GetContent) == "function" and WeaponService.GetContent() or nil
        if type(content) == "table" and not content[fakeKey] then
            content[fakeKey] = itemData
        end
        if type(content) ~= "table" or not content[fakeKey] then return nil end
        feFakeKeys[fakeKey] = true
        return fakeKey
    end

    local function setLocalEquip(backpackId, slot, key, options)
        if not BackpackService or type(BackpackService.GetBackpack) ~= "function" then return false end
        local backpack = BackpackService.GetBackpack(backpackId)
        if type(backpack) ~= "table" then return false end
        options = options or {}
        if type(localSetEquip) == "function" then
            pcall(localSetEquip, backpackId, slot, key, nil, options)
            if backpack[slot] == key then return true end
        end

        local previous = backpack[slot]
        if previous and previous ~= key and WeaponService and type(WeaponService.SetBackpack) == "function" then
            pcall(WeaponService.SetBackpack, previous, nil, nil, options)
        end
        if key and WeaponService and type(WeaponService.SetBackpack) == "function" then
            pcall(WeaponService.SetBackpack, key, backpackId, slot, options)
        end
        backpack[slot] = key
        if BackpackService.DataUpdated and type(BackpackService.DataUpdated.Fire) == "function" then
            local changed = {}
            if previous then changed[previous] = true end
            if key then changed[key] = true end
            pcall(BackpackService.DataUpdated.Fire, BackpackService.DataUpdated, backpackId, {
                UpdateEquip = true,
                UpdateSlot = slot,
                UpdateKeys = changed,
            })
        end
        return backpack[slot] == key
    end

    local function restoreCharmOverlay(backpackId)
        local saved = feCharmState
        if not saved then return end
        local options = {Charm = {
            Key = saved.FakeKey,
            CharmSlot = "Primary",
            CharmIndex = saved.Index,
            EquipTarget = saved.Target,
        }}
        setLocalEquip(backpackId, "Charm", nil, options)
        if saved.OriginalKey then
            options.Charm.Key = saved.OriginalKey
            setLocalEquip(backpackId, "Charm", saved.OriginalKey, options)
        end
        feCharmState = nil
    end

    local function applyLocalCosmeticSlots()
        if not state.FEUnlock or not BackpackService or type(BackpackService.GetBackpack) ~= "function"
            or type(BackpackService.GetBackpackIdSelected) ~= "function" then
            return 0, string.format("Local inventory unavailable (enabled=%s, backpack=%s)", tostring(state.FEUnlock), tostring(BackpackService ~= nil))
        end
        local okId, backpackId = pcall(BackpackService.GetBackpackIdSelected)
        local okBag, backpack = false, nil
        if okId then okBag, backpack = pcall(BackpackService.GetBackpack, backpackId) end
        if not okBag or type(backpack) ~= "table" then return 0, "Local backpack data unavailable" end
        local changed = 0
        for _, entry in ipairs({{"Sniper", "Primary"}, {"Melee", "Secondary"}, {"Glove", "Glove"}}) do
            local kind, slot = entry[1], entry[2]
            local configKey = selectedCosmetic(kind)
            if configKey then
                if feOriginalSlots[slot] == nil then feOriginalSlots[slot] = backpack[slot] or false end
                local fakeKey = ensureFakeCosmetic(kind, configKey)
                if not fakeKey then return changed, "Local item injection failed: " .. kind end
                if fakeKey and backpack[slot] ~= fakeKey then
                    local equipped = setLocalEquip(backpackId, slot, fakeKey, {})
                    if equipped then changed += 1 end
                end
            elseif feOriginalSlots[slot] ~= nil then
                local original = feOriginalSlots[slot]
                setLocalEquip(backpackId, slot, original ~= false and original or nil, {})
                feOriginalSlots[slot] = nil
            end
        end

        local charmKey = selectedCosmetic("Charm")
        local charmFake = charmKey and ensureFakeCosmetic("Charm", charmKey) or nil
        local charmTarget = backpack.Primary
        if feCharmState and (not charmFake or feCharmState.FakeKey ~= charmFake or feCharmState.Target ~= charmTarget) then
            restoreCharmOverlay(backpackId)
        end
        if charmFake and charmTarget and not feCharmState then
            local content = WeaponService and type(WeaponService.GetContent) == "function" and WeaponService.GetContent() or nil
            local targetData = type(content) == "table" and content[charmTarget] or nil
            local targetConfig = targetData and CosmeticConfig[targetData.Name]
            local slotCount = math.max(tonumber(targetConfig and targetConfig.CharmSlotCount) or 1, 1)
            local occupied = {}
            for key, charm in pairs(targetData and targetData.Charm or {}) do
                if type(charm) == "table" and tonumber(charm.Index) then occupied[tonumber(charm.Index)] = key end
            end
            local index = 1
            while index <= slotCount and occupied[index] do index += 1 end
            if index > slotCount then index = slotCount end
            feCharmState = {FakeKey = charmFake, Target = charmTarget, Index = index, OriginalKey = occupied[index]}
            local options = {Charm = {Key = charmFake, CharmSlot = "Primary", CharmIndex = index, EquipTarget = charmTarget}}
            local equipped = setLocalEquip(backpackId, "Charm", charmFake, options)
            if equipped then changed += 1 end
        end
        return changed, string.format("Local inventory route ready (%d change%s)", changed, changed == 1 and "" or "s")
    end

    local function tryApplyLocalCosmeticSlots()
        local ok, result, status = pcall(applyLocalCosmeticSlots)
        if ok then
            state.FELocalAppliedCount = tonumber(result) or 0
            state.FELocalStatus = tostring(status or string.format("Local inventory route ready (%d change%s)", state.FELocalAppliedCount,
                state.FELocalAppliedCount == 1 and "" or "s"))
            return state.FELocalAppliedCount
        end
        state.FELocalAppliedCount = 0
        state.FELocalStatus = "Local inventory route failed: " .. string.sub(tostring(result), 1, 160)
        return 0
    end

    local function recreateLocalController(weapon, cosmeticKey)
        if not weapon or not WeaponControllerApi or type(WeaponControllerApi.Create) ~= "function"
            or not EntityService or not EntityService.LocalEntity then return false end
        local realName, realConfig = weapon.Name, weapon.Config
        if type(realName) ~= "string" then return false end
        local oldController = weapon.Controller
        if oldController and type(oldController.Destroy) == "function" then pcall(oldController.Destroy, oldController) end
        weapon.Name = cosmeticKey or realName
        weapon.Config = realConfig
        local ok, controller = pcall(WeaponControllerApi.Create, EntityService.LocalEntity, weapon)
        weapon.Name = realName
        weapon.Config = realConfig
        if not ok then
            if not weapon.Controller then pcall(WeaponControllerApi.Create, EntityService.LocalEntity, weapon) end
            return false
        end
        feAppliedWeapons[weapon] = cosmeticKey or false
        return controller ~= nil
    end

    local function applyCombatCosmetics()
        if not CombatService or type(CombatService.GetWeapons) ~= "function" or not EntityService or not EntityService.LocalEntity then return 0 end
        local ok, weapons = pcall(CombatService.GetWeapons, EntityService.LocalEntity)
        if not ok or type(weapons) ~= "table" then return 0 end
        local applied = 0
        for _, weapon in pairs(weapons) do
            local realConfig = type(weapon) == "table" and (weapon.Config or WeaponConfig[weapon.Name]) or nil
            local kind = realConfig and tostring(realConfig.WeaponType or "") or ""
            local desired = state.FEUnlock and selectedCosmetic(kind) or nil
            local controller = type(weapon) == "table" and weapon.Controller or nil
            local controllerName = controller and controller.Name or nil
            local desiredName = desired or (type(weapon) == "table" and weapon.Name or nil)
            if desiredName and controllerName ~= desiredName then recreateLocalController(weapon, desired) end
            if desired and weapon.Controller and weapon.Controller.Name == desired then applied += 1 end
        end
        state.FEAppliedCount = applied
        state.FELastApply = applied > 0 and string.format("%d local combat cosmetic(s) active", applied)
            or (state.FEUnlock and "Waiting for a compatible weapon" or "Original server cosmetics")
        return applied
    end

    local function restoreLocalCosmeticSlots()
        if BackpackService and type(BackpackService.GetBackpack) == "function"
            and type(BackpackService.GetBackpackIdSelected) == "function" then
            local okId, backpackId = pcall(BackpackService.GetBackpackIdSelected)
            local okBag, backpack = false, nil
            if okId then okBag, backpack = pcall(BackpackService.GetBackpack, backpackId) end
            if okBag and type(backpack) == "table" then
                restoreCharmOverlay(backpackId)
                for slot, original in pairs(feOriginalSlots) do
                    local key = original ~= false and original or nil
                    setLocalEquip(backpackId, slot, key, {})
                    feOriginalSlots[slot] = nil
                end
            end
        end
        if WeaponStore and type(WeaponStore.Remove) == "function" then
            local keys = {}
            for key in pairs(feFakeKeys) do keys[#keys + 1] = key end
            if #keys > 0 then pcall(WeaponStore.Remove, WeaponStore, keys) end
        end
        local content = WeaponService and type(WeaponService.GetContent) == "function" and WeaponService.GetContent() or nil
        if type(content) == "table" then
            for key in pairs(feFakeKeys) do content[key] = nil end
        end
        table.clear(feFakeKeys)
    end

    local function restoreFECosmetics()
        local wasEnabled = state.FEUnlock
        state.FEUnlock = false
        applyCombatCosmetics()
        restoreLocalCosmeticSlots()
        state.FEUnlock = wasEnabled
        state.FEAppliedCount = 0
        state.FELastApply = "Original server cosmetics"
    end

    local function applyJumpBoost()
        local _, humanoid = character()
        if not humanoid then return end
        if not jumpDefaults[humanoid] then
            jumpDefaults[humanoid] = {
                UseJumpPower = humanoid.UseJumpPower,
                JumpPower = humanoid.JumpPower,
                JumpHeight = humanoid.JumpHeight,
            }
        end
        if state.JumpBoost then
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = math.clamp(tonumber(state.JumpHeight) or 25, 7, 100)
        end
    end

    local function restoreJumpBoost()
        for humanoid, original in pairs(jumpDefaults) do
            if humanoid and humanoid.Parent then
                pcall(function()
                    humanoid.UseJumpPower = original.UseJumpPower
                    humanoid.JumpPower = original.JumpPower
                    humanoid.JumpHeight = original.JumpHeight
                end)
            end
            jumpDefaults[humanoid] = nil
        end
    end

    local families = ownedFamilies()
    if #families == 0 then families = {"SSG"} end
    state.SelectedFamily = bestOwnedPrimary() or families[1]

    local sniperFamilies = cosmeticFamilies("Sniper")
    local meleeFamilies = cosmeticFamilies("Melee")
    if not cosmeticCatalog.Sniper[state.FESniperFamily] then state.FESniperFamily = sniperFamilies[1] or "SSG" end
    if not cosmeticCatalog.Melee[state.FEMeleeFamily] then state.FEMeleeFamily = meleeFamilies[1] or "Karambit" end
    state.StatusLabels = {}
    do
    local cosmeticControls = {}

    AimSection:AddToggle({Name = "Cursor Aimbot", Description = "Uses the executor mouse mover like the proven Polo script. Hold right-click by default.", Flag = "sniper_arena_cursor_aimbot", Default = true, Callback = function(v) state.AimAssist = v == true end})
    AimSection:AddToggle({Name = "Silent Aim", Description = "Optional. Dead players and one-second ragdolls are rejected immediately.", Flag = "sniper_arena_silent_aim", Default = false, Callback = function(v) state.SilentAim = v == true end})
    AimSection:AddSlider({Name = "Silent Hit Chance", Flag = "sniper_arena_silent_chance", Min = 1, Max = 100, Step = 1, Default = 100, Suffix = "%", Callback = function(v) state.SilentAimChance = tonumber(v) or 100 end})
    AimSection:AddSlider({Name = "Target Prediction", Flag = "sniper_arena_silent_prediction", Min = 0, Max = 0.3, Step = 0.01, Default = 0, Suffix = "s", Callback = function(v) state.SilentAimPrediction = tonumber(v) or 0 end})
    AimSection:AddDropdown({Name = "Activation", Flag = "sniper_arena_cursor_activation", Options = {"While Aiming", "While Firing", "Always"}, Default = "While Aiming", Callback = function(v) state.AimActivation = v or "While Aiming" end})
    AimSection:AddDropdown({Name = "Target Part", Flag = "sniper_arena_target_part_v2", Options = {"Head", "Torso", "Root"}, Default = "Head", Callback = function(v) state.AimPart = v or "Head" end})
    AimSection:AddSlider({Name = "Aimbot Smoothness", Description = "Higher is slower and more human. The movement eases as it reaches the target.", Flag = "sniper_arena_cursor_smoothness", Min = 1, Max = 30, Step = 1, Default = 10, Callback = function(v) state.AimSmoothness = tonumber(v) or 10 end})
    AimSection:AddSlider({Name = "Aim Radius", Flag = "sniper_arena_cursor_radius", Min = 100, Max = 2000, Step = 50, Default = 2000, Suffix = "px", Callback = function(v) state.AimRadius = tonumber(v) or 2000 end})
    AimSection:AddToggle({Name = "Team Check", Flag = "sniper_arena_team_check", Default = true, Callback = function(v) state.TeamCheck = v == true end})
    AimSection:AddToggle({Name = "Wall Check", Description = "Off is aggressive; on only selects targets with a clear ray.", Flag = "sniper_arena_wall_check_v2", Default = false, Callback = function(v) state.WallCheck = v == true end})
    AimSection:AddToggle({Name = "Show Aim Radius", Flag = "sniper_arena_show_fov_v2", Default = false, Callback = function(v) state.ShowFov = v == true end})

    CombatStatusSection:AddToggle({Name = "Trigger Assist (Auto Fire)", Description = "Pauses while the VOR or Roblox menu is open, then resumes automatically when it closes.", Flag = "sniper_arena_triggerbot", Default = false, Callback = function(v) state.TriggerBot = v == true end})
    CombatStatusSection:AddSlider({Name = "Trigger Repeat Delay", Description = "First hover fires immediately. Zero repeats every rendered frame.", Flag = "sniper_arena_trigger_delay_ms", Min = 0, Max = 250, Step = 5, Default = 0, Suffix = "ms", Callback = function(v) state.TriggerDelay = (tonumber(v) or 0) / 1000 end})
    CombatStatusSection:AddToggle({Name = "Big Head (Players Only)", Description = "Manual and session-only. NPCs, bots, and dead ragdolls are ignored; a living player's real body must be visible.", Flag = "sniper_arena_hitbox_visible_body_v3", Persist = false, Default = false, Callback = function(v)
        state.HitboxExpand = v == true
        if not state.HitboxExpand then restoreHitboxes() end
    end})
    CombatStatusSection:AddSlider({Name = "Big Head Size (Experimental)", Description = "Expands living enemy-player heads only. Very large values may not register every server-checked shot.", Flag = "sniper_arena_hitbox_size_v3", Persist = false, Min = 1, Max = 30, Step = 1, Default = 5, Callback = function(v) state.HitboxSize = math.clamp(tonumber(v) or 5, 1, 30) end})
    state.StatusLabels.Combat = CombatStatusSection:AddLabel("Target: none")
    state.StatusLabels.Ammo = CombatStatusSection:AddLabel("Combat: scanning...")

    WeaponModsSection:AddToggle({Name = "No Recoil", Description = "Zeros recoil and kick values on the equipped tool.", Flag = "sniper_arena_no_recoil", Default = false, Callback = function(v) state.NoRecoil = v == true if not state.NoRecoil then updateWeaponModifiers() end end})
    WeaponModsSection:AddToggle({Name = "No Spread", Description = "Zeros spread and accuracy values on the equipped tool.", Flag = "sniper_arena_no_spread", Default = false, Callback = function(v) state.NoSpread = v == true if not state.NoSpread then updateWeaponModifiers() end end})
    WeaponModsSection:AddToggle({Name = "Fast Reload", Description = "Sets equipped-tool reload/time values to 0.05 and restores them on toggle-off.", Flag = "sniper_arena_fast_reload", Default = false, Callback = function(v) state.FastReload = v == true if not state.FastReload then updateWeaponModifiers() end end})
    state.StatusLabels.WeaponMods = WeaponModsSection:AddLabel("Modified weapon values: 0")

    WeaponSection:AddDropdown({Name = "Owned Family", Flag = "sniper_arena_family", Options = families, Default = state.SelectedFamily, Callback = function(v) state.SelectedFamily = v or state.SelectedFamily end})
    WeaponSection:AddButton({Name = "Equip Selected Family", Callback = function() if not equipFamily(state.SelectedFamily) then notify(state.LastAction, COLORS.warning) end end})
    WeaponSection:AddButton({Name = "Equip Best Owned Sniper", Callback = function()
        local family = bestOwnedPrimary()
        if family then state.SelectedFamily = family equipFamily(family) else notify("No owned primary sniper found", COLORS.warning) end
    end})
    WeaponSection:AddLabel("Only server-owned weapon IDs are accepted by loadouts.")
    state.StatusLabels.Inventory = WeaponSection:AddLabel("Inventory: scanning...")

    UnlockSection:AddToggle({Name = "Auto Unlock Earned Snipers", Description = "Calls the native unlock only after credited kills meet the server requirement.", Flag = "sniper_arena_auto_unlock", Default = false, Callback = function(v) state.AutoUnlock = v == true end})
    UnlockSection:AddButton({Name = "Unlock Everything Earned", Callback = function() local n = unlockEarned() notify(state.LastAction, n > 0 and COLORS.success or COLORS.warning) end})
    UnlockSection:AddLabel("Server ownership stays untouched. The FE showcase below is local-only.")
    state.StatusLabels.Unlock = UnlockSection:AddLabel("Unlocks: scanning...")

    CosmeticSection:AddParagraph({
        Title = "Soft unlock — only you see it",
        Content = "Choose any sniper, melee, glove, or charm model. VOR swaps the local inventory/first-person presentation while every real server weapon ID and ownership record stays unchanged.",
    })
    cosmeticControls.FE = CosmeticSection:AddToggle({Name = "FE Unlock All Cosmetics", Description = "Enables client-only inventory and viewmodel swaps. Toggle off restores the exact server-equipped cosmetics.", Flag = "sniper_arena_fe_unlock_all", Default = state.FEUnlock, Callback = function(v)
        local enabled = v == true
        if not enabled then restoreFECosmetics() end
        state.FEUnlock = enabled
        if enabled then
            tryApplyLocalCosmeticSlots()
            applyCombatCosmetics()
        end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.SniperFamily = CosmeticSection:AddDropdown({Name = "Sniper Family", Flag = "sniper_arena_fe_sniper_family", Options = sniperFamilies, Default = state.FESniperFamily, Callback = function(v)
        state.FESniperFamily = v or state.FESniperFamily
        local selected = state.FESelections.Sniper
        if selected and tostring((CosmeticConfig[selected] or {}).Family or "") ~= state.FESniperFamily then state.FESelections.Sniper = nil end
        if cosmeticControls.SniperSkin then
            cosmeticControls.SniperSkin:SetOptions(cosmeticOptions("Sniper", state.FESniperFamily))
            cosmeticControls.SniperSkin:Set(ORIGINAL_COSMETIC)
        end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.SniperSkin = CosmeticSection:AddDropdown({Name = "Sniper Model / Skin", Flag = "sniper_arena_fe_sniper_skin", Options = cosmeticOptions("Sniper", state.FESniperFamily), Default = state.FESelections.Sniper and state.CosmeticLabelByKey[state.FESelections.Sniper] or ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Sniper = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() applyCombatCosmetics() end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.MeleeFamily = CosmeticSection:AddDropdown({Name = "Melee Family", Flag = "sniper_arena_fe_melee_family", Options = meleeFamilies, Default = state.FEMeleeFamily, Callback = function(v)
        state.FEMeleeFamily = v or state.FEMeleeFamily
        local selected = state.FESelections.Melee
        if selected and tostring((CosmeticConfig[selected] or {}).Family or "") ~= state.FEMeleeFamily then state.FESelections.Melee = nil end
        if cosmeticControls.MeleeSkin then
            cosmeticControls.MeleeSkin:SetOptions(cosmeticOptions("Melee", state.FEMeleeFamily))
            cosmeticControls.MeleeSkin:Set(ORIGINAL_COSMETIC)
        end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.MeleeSkin = CosmeticSection:AddDropdown({Name = "Knife / Melee Model", Flag = "sniper_arena_fe_melee_skin", Options = cosmeticOptions("Melee", state.FEMeleeFamily), Default = state.FESelections.Melee and state.CosmeticLabelByKey[state.FESelections.Melee] or ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Melee = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() applyCombatCosmetics() end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.GloveSkin = CosmeticSection:AddDropdown({Name = "Glove Model", Flag = "sniper_arena_fe_glove", Options = cosmeticOptions("Glove"), Default = state.FESelections.Glove and state.CosmeticLabelByKey[state.FESelections.Glove] or ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Glove = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})
    cosmeticControls.CharmSkin = CosmeticSection:AddDropdown({Name = "Charm Model", Flag = "sniper_arena_fe_charm", Options = cosmeticOptions("Charm"), Default = state.FESelections.Charm and state.CosmeticLabelByKey[state.FESelections.Charm] or ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Charm = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() end
        state.SaveCosmeticState()
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end})

    local function installCosmeticBrowser()
    local create = context.Create
    local addCorner = context.AddCorner
    local addStroke = context.AddStroke
    local browserState = {Kind = "Sniper", Family = "All", Query = "", Page = 1, PageSize = 12, PreviewKey = nil}
    local browserCards, browserFamilies, browserCategoryButtons = {}, {}, {}
    local browserGrid, browserFamilyBar, browserPageLabel, browserResultLabel
    local browserPanel, browserBackdrop, browserBubble
    local browserPreviewImage, browserPreviewName, browserPreviewMeta, browserEquipButton, browserOriginalButton
    local browserPreviewViewport, browserPreviewWorld, browserPreviewCamera, browserPreviewModel, browserPreviewFallback
    local browserPreviewBasePivot, browserPreviewDistance = nil, 8
    local previewYaw, previewPitch, previewZoom = -24, -7, 1
    local previewDragging, previewHovered, previewLastPosition = false, false, Vector2.zero
    local previewAutoSpin, previewEffects = true, true
    local previewSpinButton, previewEffectsButton

    local function rarityColor(rarity)
        local name = string.lower(tostring(rarity or ""))
        if string.find(name, "myth", 1, true) or string.find(name, "exotic", 1, true) then return Color3.fromRGB(255, 82, 173) end
        if string.find(name, "legend", 1, true) then return Color3.fromRGB(255, 174, 58) end
        if string.find(name, "epic", 1, true) then return Color3.fromRGB(190, 92, 255) end
        if string.find(name, "rare", 1, true) then return Color3.fromRGB(72, 154, 255) end
        if string.find(name, "uncommon", 1, true) then return Color3.fromRGB(82, 214, 138) end
        return COLORS.muted or Color3.fromRGB(172, 163, 190)
    end

    local function browserItem(kind, key)
        if not key then return nil end
        for _, item in ipairs(state.CosmeticItemsByKind[kind] or {}) do
            if item.Key == key then return item end
        end
        return nil
    end

    local function filteredBrowserItems()
        local result = {}
        local query = string.lower(browserState.Query or ""):match("^%s*(.-)%s*$")
        for _, item in ipairs(state.CosmeticItemsByKind[browserState.Kind] or {}) do
            if (browserState.Family == "All" or item.Family == browserState.Family)
                and (query == "" or string.find(item.Search, query, 1, true)) then
                result[#result + 1] = item
            end
        end
        return result
    end

    local function previewModelSource(item)
        local config = item and CosmeticConfig[item.Key]
        if type(config) ~= "table" then return nil, false end
        local source = config.ThirdPersonModel or config.FirstPersonModel
        local inherited = false
        if typeof(source) ~= "Instance" then
            local base = CosmeticConfig[tostring(config.Family or "")]
            source = type(base) == "table" and (base.ThirdPersonModel or base.FirstPersonModel) or nil
            inherited = typeof(source) == "Instance"
        end
        return typeof(source) == "Instance" and source or nil, inherited
    end

    local function updatePreviewCamera()
        if not browserPreviewCamera then return end
        local distance = math.max(browserPreviewDistance * previewZoom, 2.5)
        browserPreviewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.15, distance), Vector3.new(0, 0, 0))
    end

    local function rotatePreviewModel()
        if browserPreviewModel and browserPreviewModel.Parent and browserPreviewBasePivot then
            browserPreviewModel:PivotTo(CFrame.Angles(math.rad(previewPitch), math.rad(previewYaw), 0) * browserPreviewBasePivot)
        end
    end

    local function clearPreviewModel()
        if browserPreviewModel then browserPreviewModel:Destroy() browserPreviewModel = nil end
        browserPreviewBasePivot = nil
        if browserPreviewWorld then
            for _, child in ipairs(browserPreviewWorld:GetChildren()) do child:Destroy() end
        end
    end

    local function setPreviewEffects(enabled)
        previewEffects = enabled == true
        if previewEffectsButton then previewEffectsButton.Text = previewEffects and "FX  ON" or "FX  OFF" end
        if not browserPreviewModel then return end
        for _, object in ipairs(browserPreviewModel:GetDescendants()) do
            if object:IsA("ParticleEmitter") then
                object.Enabled = previewEffects
                if previewEffects then pcall(object.Emit, object, math.clamp(math.floor(object.Rate * 0.2), 2, 18)) end
            elseif object:IsA("Beam") or object:IsA("Trail") then
                object.Enabled = previewEffects
            end
        end
    end

    local function refreshPreviewModel(item)
        clearPreviewModel()
        if not browserPreviewViewport then return false, false end
        previewYaw, previewPitch, previewZoom = -24, -7, 1
        local source, inherited = previewModelSource(item)
        local loaded = false
        if source then
            local ok, clone = pcall(source.Clone, source)
            if ok and clone then
                clone.Name = "CosmeticPreviewModel"
                for _, object in ipairs(clone:GetDescendants()) do
                    if object:IsA("LuaSourceContainer") then
                        object:Destroy()
                    elseif object:IsA("BasePart") then
                        object.Anchored = true
                        object.CanCollide = false
                        object.CanTouch = false
                        object.CanQuery = false
                    end
                end
                clone.Parent = browserPreviewWorld
                browserPreviewModel = clone
                local boxCFrame, size = clone:GetBoundingBox()
                local originalPivot = clone:GetPivot()
                browserPreviewBasePivot = CFrame.new(-boxCFrame.Position) * originalPivot
                clone:PivotTo(browserPreviewBasePivot)
                local longest = math.max(size.X, size.Y, size.Z, 0.5)
                browserPreviewDistance = math.max(longest * 1.65, 3.4)
                browserPreviewCamera.FieldOfView = 32
                updatePreviewCamera()
                rotatePreviewModel()
                setPreviewEffects(previewEffects)
                loaded = true
            end
        end
        browserPreviewViewport.Visible = loaded
        if browserPreviewImage then
            local hasImage = item and item.Image ~= ""
            browserPreviewImage.Visible = hasImage
            browserPreviewImage.Image = hasImage and item.Image or ""
            browserPreviewImage.Position = loaded and UDim2.new(1, -132, 1, -92) or UDim2.fromOffset(10, 10)
            browserPreviewImage.Size = loaded and UDim2.fromOffset(120, 80) or UDim2.new(1, -20, 1, -20)
        end
        if browserPreviewFallback then
            browserPreviewFallback.Visible = not loaded and (not item or item.Image == "")
            browserPreviewFallback.Text = item and (string.upper(item.Family) .. "\n3D ASSET UNAVAILABLE") or "SELECT AN ITEM"
        end
        return loaded, inherited
    end

    local function setBrowserSelection(kind, key)
        local label = key and state.CosmeticLabelByKey[key] or ORIGINAL_COSMETIC
        local config = key and CosmeticConfig[key] or nil
        if kind == "Sniper" then
            if config and cosmeticControls.SniperFamily then cosmeticControls.SniperFamily:Set(tostring(config.Family or state.FESniperFamily)) end
            if cosmeticControls.SniperSkin then cosmeticControls.SniperSkin:Set(label) end
        elseif kind == "Melee" then
            if config and cosmeticControls.MeleeFamily then cosmeticControls.MeleeFamily:Set(tostring(config.Family or state.FEMeleeFamily)) end
            if cosmeticControls.MeleeSkin then cosmeticControls.MeleeSkin:Set(label) end
        elseif kind == "Glove" and cosmeticControls.GloveSkin then
            cosmeticControls.GloveSkin:Set(label)
        elseif kind == "Charm" and cosmeticControls.CharmSkin then
            cosmeticControls.CharmSkin:Set(label)
        end
        if key and cosmeticControls.FE then cosmeticControls.FE:Set(true) end
        browserState.PreviewKey = key
        if cosmeticControls.Refresh then cosmeticControls.Refresh() end
    end

    local function closeCosmeticBrowser()
        if state.CosmeticBrowserRoot then state.CosmeticBrowserRoot.Visible = false end
    end

    local function setBrowserMinimized(minimized)
        minimized = minimized == true
        if not state.CosmeticBrowserRoot then return end
        state.CosmeticBrowserRoot.Visible = true
        if browserPanel then browserPanel.Visible = not minimized end
        if browserBackdrop then browserBackdrop.Visible = not minimized end
        if browserBubble then browserBubble.Visible = minimized end
        state.CosmeticBrowserMinimized = minimized
        if gui then gui:SetAttribute("SniperArenaCosmeticBrowserMinimized", minimized) end
    end

    local function makeBrowserButton(parent, text, size, position)
        local button = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamSemibold,
            Position = position or UDim2.new(),
            Size = size or UDim2.fromOffset(110, 34),
            Text = text,
            TextColor3 = COLORS.text or Color3.fromRGB(244, 239, 251),
            TextSize = 12,
            ZIndex = 607,
        }, parent)
        addCorner(button, 9)
        addStroke(button, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.35)
        return button
    end

    local function buildCosmeticBrowser()
        if not gui or state.CosmeticBrowserRoot then return end
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
        if not playerGui then return end
        local compactLayout = camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 600
        local staleBrowser = playerGui:FindFirstChild("VORSniperCosmeticInventory")
        if staleBrowser then staleBrowser:Destroy() end
        state.CosmeticBrowserGui = create("ScreenGui", {
            DisplayOrder = math.max(1001, (tonumber(gui.DisplayOrder) or 0) + 10),
            Enabled = true,
            IgnoreGuiInset = true,
            Name = "VORSniperCosmeticInventory",
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        }, playerGui)
        state.CosmeticBrowserRoot = create("Frame", {
            Active = false,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 600,
        }, state.CosmeticBrowserGui)
        state.CosmeticBrowserRoot.Name = "SniperCosmeticBrowser"

        browserBackdrop = create("Frame", {
            Active = false,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.52,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 600,
        }, state.CosmeticBrowserRoot)

        local panel = create("Frame", {
            Active = true,
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = COLORS.surface or Color3.fromRGB(18, 11, 29),
            BackgroundTransparency = 0.02,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = compactLayout and UDim2.new(0.98, 0, 0.96, 0) or UDim2.new(0.96, 0, 0.92, 0),
            ZIndex = 602,
        }, state.CosmeticBrowserRoot)
        browserPanel = panel
        panel.Name = "InventoryWindow"
        addCorner(panel, 16)
        addStroke(panel, COLORS.accentBright or Color3.fromRGB(151, 70, 255), 1.4, 0.12)
        create("UISizeConstraint", {MinSize = Vector2.new(360, 320), MaxSize = Vector2.new(1680, 940)}, panel)

        browserBubble = create("TextButton", {
            Active = true,
            AnchorPoint = Vector2.new(0.5, 0.5),
            AutoButtonColor = false,
            BackgroundColor3 = COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39),
            BackgroundTransparency = 0.02,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            Position = UDim2.new(1, -58, 0.5, 0),
            Size = UDim2.fromOffset(58, 58),
            Text = utf8.char(0x1F3AF),
            TextColor3 = COLORS.text or Color3.fromRGB(246, 242, 251),
            TextSize = 29,
            Visible = false,
            ZIndex = 620,
        }, state.CosmeticBrowserRoot)
        browserBubble.Name = "DraggableInventoryBubble"
        addCorner(browserBubble, 18)
        addStroke(browserBubble, COLORS.accentBright or Color3.fromRGB(151, 70, 255), 2, 0.08)
        local bubbleDrag = {Active = false, Start = nil, Center = nil, Moved = false}
        track(browserBubble.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            bubbleDrag.Active = true
            bubbleDrag.Start = input.Position
            bubbleDrag.Center = Vector2.new(
                browserBubble.AbsolutePosition.X + browserBubble.AbsoluteSize.X * 0.5,
                browserBubble.AbsolutePosition.Y + browserBubble.AbsoluteSize.Y * 0.5
            )
            bubbleDrag.Moved = false
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not bubbleDrag.Active or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
            local delta = input.Position - bubbleDrag.Start
            bubbleDrag.Moved = bubbleDrag.Moved or delta.Magnitude > 8
            local rootSize = state.CosmeticBrowserRoot.AbsoluteSize
            local half = browserBubble.AbsoluteSize * 0.5
            local center = bubbleDrag.Center + delta
            center = Vector2.new(
                math.clamp(center.X, half.X + 8, math.max(half.X + 8, rootSize.X - half.X - 8)),
                math.clamp(center.Y, half.Y + 8, math.max(half.Y + 8, rootSize.Y - half.Y - 8))
            )
            browserBubble.Position = UDim2.fromOffset(center.X, center.Y)
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if not bubbleDrag.Active or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
            bubbleDrag.Active = false
            if not bubbleDrag.Moved then setBrowserMinimized(false) end
        end))

        local dragHandle = create("TextButton", {
            Active = true,
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 62),
            Text = "",
            ZIndex = 603,
        }, panel)
        dragHandle.Name = "WindowDragHandle"
        local windowDrag = {Active = false, Start = nil, Center = nil}
        track(dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            windowDrag.Active = true
            windowDrag.Start = input.Position
            windowDrag.Center = Vector2.new(
                panel.AbsolutePosition.X + panel.AbsoluteSize.X * 0.5,
                panel.AbsolutePosition.Y + panel.AbsoluteSize.Y * 0.5
            )
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not windowDrag.Active or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
            local delta = input.Position - windowDrag.Start
            local rootSize = state.CosmeticBrowserRoot.AbsoluteSize
            local half = panel.AbsoluteSize * 0.5
            local center = windowDrag.Center + delta
            center = Vector2.new(
                math.clamp(center.X, half.X + 8, math.max(half.X + 8, rootSize.X - half.X - 8)),
                math.clamp(center.Y, half.Y + 8, math.max(half.Y + 8, rootSize.Y - half.Y - 8))
            )
            panel.Position = UDim2.fromOffset(center.X, center.Y)
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                windowDrag.Active = false
            end
        end))

        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.fromOffset(22, 8),
            Size = UDim2.new(0.42, 0, 0, 44),
            Text = compactLayout and "FE INVENTORY" or "FE COSMETIC INVENTORY",
            TextColor3 = COLORS.text or Color3.fromRGB(246, 242, 251),
            TextSize = compactLayout and 14 or 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 604,
        }, panel)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(24, 38),
            Size = UDim2.new(0.45, 0, 0, 20),
            Text = "CLIENT-ONLY PREVIEW  /  SERVER OWNERSHIP UNCHANGED",
            TextColor3 = COLORS.dim or Color3.fromRGB(140, 130, 157),
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not compactLayout,
            ZIndex = 604,
        }, panel)

        local search = create("TextBox", {
            BackgroundColor3 = COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = Enum.Font.Gotham,
            PlaceholderColor3 = COLORS.dim or Color3.fromRGB(140, 130, 157),
            PlaceholderText = "Search name, family, rarity...",
            Position = compactLayout and UDim2.new(0.34, 0, 0, 10) or UDim2.new(0.54, 0, 0, 13),
            Size = compactLayout and UDim2.new(0.66, -108, 0, 38) or UDim2.new(0.30, 0, 0, 38),
            Text = "",
            TextColor3 = COLORS.text or Color3.fromRGB(246, 242, 251),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 605,
        }, panel)
        addCorner(search, 10)
        addStroke(search, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.35)
        create("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, search)

        local minimize = makeBrowserButton(panel, "-", UDim2.fromOffset(40, 38), UDim2.new(1, -100, 0, 13))
        minimize.Name = "MinimizeToBubble"
        minimize.TextSize = 22
        track(minimize.Activated:Connect(function() setBrowserMinimized(true) end))
        local close = makeBrowserButton(panel, "×", UDim2.fromOffset(40, 38), UDim2.new(1, -52, 0, 13))
        close.Name = "CloseInventory"
        close.TextSize = 22
        track(close.Activated:Connect(closeCosmeticBrowser))

        local categoryBar = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, compactLayout and 58 or 66),
            Size = UDim2.new(1, -36, 0, 38),
            ZIndex = 604,
        }, panel)
        create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, categoryBar)
        for index, kind in ipairs({"Sniper", "Melee", "Glove", "Charm"}) do
            local button = makeBrowserButton(categoryBar, kind == "Sniper" and "🎯 SNIPERS" or kind == "Melee" and "🔪 MELEE" or kind == "Glove" and "🧤 GLOVES" or "✨ CHARMS", UDim2.new(0.25, -6, 1, 0))
            button.LayoutOrder = index
            browserCategoryButtons[kind] = button
            track(button.Activated:Connect(function()
                browserState.Kind = kind
                browserState.Family = "All"
                browserState.Page = 1
                browserState.PreviewKey = state.FESelections[kind]
                if cosmeticControls.Refresh then cosmeticControls.Refresh(true) end
            end))
        end

        browserFamilyBar = create("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            Position = UDim2.fromOffset(18, compactLayout and 102 or 110),
            ScrollBarImageColor3 = COLORS.accentBright or Color3.fromRGB(151, 70, 255),
            ScrollBarThickness = 3,
            ScrollingDirection = Enum.ScrollingDirection.X,
            Size = UDim2.new(1, -36, 0, 42),
            ZIndex = 604,
        }, panel)

        local body = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, compactLayout and 148 or 160),
            Size = UDim2.new(1, -36, 1, compactLayout and -158 or -178),
            ZIndex = 604,
        }, panel)
        local gridPanel = create("Frame", {
            BackgroundColor3 = COLORS.rail or Color3.fromRGB(13, 8, 22),
            BackgroundTransparency = 0.14,
            BorderSizePixel = 0,
            Size = UDim2.new(0.62, -8, 1, 0),
            ZIndex = 603,
        }, body)
        addCorner(gridPanel, 12)
        addStroke(gridPanel, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.45)

        browserResultLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(12, 6),
            Size = UDim2.new(1, -24, 0, 24),
            Text = "Loading catalog...",
            TextColor3 = COLORS.muted or Color3.fromRGB(180, 171, 194),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 605,
        }, gridPanel)
        browserGrid = create("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            Position = UDim2.fromOffset(10, 34),
            ScrollBarImageColor3 = COLORS.accentBright or Color3.fromRGB(151, 70, 255),
            ScrollBarThickness = 4,
            Size = UDim2.new(1, -20, 1, -76),
            ZIndex = 604,
        }, gridPanel)

        local footer = create("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 1, -38), Size = UDim2.new(1, -20, 0, 32), ZIndex = 605}, gridPanel)
        local previous = makeBrowserButton(footer, "‹ PREV", UDim2.fromOffset(86, 30), UDim2.fromOffset(0, 0))
        local nextButton = makeBrowserButton(footer, "NEXT ›", UDim2.fromOffset(86, 30), UDim2.new(1, -86, 0, 0))
        browserPageLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            Position = UDim2.new(0.5, -90, 0, 0),
            Size = UDim2.fromOffset(180, 30),
            Text = "PAGE 1 / 1",
            TextColor3 = COLORS.muted or Color3.fromRGB(180, 171, 194),
            TextSize = 11,
            ZIndex = 606,
        }, footer)
        track(previous.Activated:Connect(function()
            browserState.Page = math.max(browserState.Page - 1, 1)
            if cosmeticControls.Refresh then cosmeticControls.Refresh() end
        end))
        track(nextButton.Activated:Connect(function()
            browserState.Page += 1
            if cosmeticControls.Refresh then cosmeticControls.Refresh() end
        end))

        local preview = create("Frame", {
            BackgroundColor3 = COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Position = UDim2.new(0.62, 8, 0, 0),
            Size = UDim2.new(0.38, -8, 1, 0),
            ZIndex = 603,
        }, body)
        addCorner(preview, 12)
        addStroke(preview, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.35)
        local previewStage = create("Frame", {
            BackgroundColor3 = COLORS.rail or Color3.fromRGB(13, 8, 22),
            BackgroundTransparency = 0.04,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 12),
            Size = UDim2.new(1, -24, 0.58, 0),
            ZIndex = 605,
        }, preview)
        addCorner(previewStage, 12)
        addStroke(previewStage, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.38)
        browserPreviewViewport = create("ViewportFrame", {
            Active = true,
            Ambient = Color3.fromRGB(148, 164, 205),
            BackgroundColor3 = Color3.fromRGB(7, 11, 20),
            BackgroundTransparency = 0.12,
            BorderSizePixel = 0,
            LightColor = Color3.fromRGB(230, 240, 255),
            LightDirection = Vector3.new(-1, -0.5, -1),
            Size = UDim2.fromScale(1, 1),
            ZIndex = 606,
        }, previewStage)
        addCorner(browserPreviewViewport, 12)
        browserPreviewWorld = create("WorldModel", {Name = "CosmeticWorld"}, browserPreviewViewport)
        browserPreviewCamera = create("Camera", {Name = "CosmeticCamera", FieldOfView = 32}, browserPreviewViewport)
        browserPreviewViewport.CurrentCamera = browserPreviewCamera
        browserPreviewImage = create("ImageLabel", {
            BackgroundColor3 = Color3.fromRGB(11, 15, 26),
            BackgroundTransparency = 0.04,
            BorderSizePixel = 0,
            Image = "",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 608,
        }, previewStage)
        addCorner(browserPreviewImage, 10)
        addStroke(browserPreviewImage, COLORS.borderBright or Color3.fromRGB(101, 68, 132), 1, 0.28)
        browserPreviewFallback = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Size = UDim2.fromScale(1, 1),
            Text = "SELECT AN ITEM",
            TextColor3 = COLORS.dim or Color3.fromRGB(140, 130, 157),
            TextSize = 14,
            Visible = false,
            ZIndex = 607,
        }, previewStage)
        local interactionHint = create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 1),
            BackgroundColor3 = Color3.fromRGB(7, 11, 20),
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamSemibold,
            Position = UDim2.new(0.5, 0, 1, -8),
            Size = UDim2.fromOffset(230, 24),
            Text = "DRAG TO ORBIT   |   SCROLL TO ZOOM",
            TextColor3 = Color3.fromRGB(188, 199, 222),
            TextSize = 9,
            ZIndex = 609,
        }, previewStage)
        addCorner(interactionHint, 12)
        previewSpinButton = makeBrowserButton(previewStage, "SPIN  ON", UDim2.fromOffset(82, 28), UDim2.fromOffset(10, 10))
        previewSpinButton.ZIndex = 610
        previewEffectsButton = makeBrowserButton(previewStage, "FX  ON", UDim2.fromOffset(70, 28), UDim2.fromOffset(100, 10))
        previewEffectsButton.ZIndex = 610
        track(previewSpinButton.Activated:Connect(function()
            previewAutoSpin = not previewAutoSpin
            previewSpinButton.Text = previewAutoSpin and "SPIN  ON" or "SPIN  OFF"
        end))
        track(previewEffectsButton.Activated:Connect(function() setPreviewEffects(not previewEffects) end))
        track(browserPreviewViewport.MouseEnter:Connect(function() previewHovered = true end))
        track(browserPreviewViewport.MouseLeave:Connect(function() previewHovered = false previewDragging = false end))
        track(browserPreviewViewport.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                previewDragging = true
                previewLastPosition = input.Position
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if previewDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - previewLastPosition
                previewLastPosition = input.Position
                previewYaw = (previewYaw - delta.X * 0.55) % 360
                previewPitch = math.clamp(previewPitch - delta.Y * 0.28, -38, 38)
                rotatePreviewModel()
            elseif previewHovered and input.UserInputType == Enum.UserInputType.MouseWheel then
                previewZoom = math.clamp(previewZoom - input.Position.Z * 0.08, 0.55, 1.8)
                updatePreviewCamera()
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then previewDragging = false end
        end))
        track(RunService.RenderStepped:Connect(function(deltaTime)
            if previewAutoSpin and not previewDragging and state.CosmeticBrowserRoot and state.CosmeticBrowserRoot.Visible and browserPreviewModel then
                previewYaw = (previewYaw + deltaTime * 18) % 360
                rotatePreviewModel()
            end
        end))
        browserPreviewName = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.new(0, 14, 0.60, 8),
            Size = UDim2.new(1, -28, 0, 44),
            Text = "Select a cosmetic",
            TextColor3 = COLORS.text or Color3.fromRGB(246, 242, 251),
            TextSize = 18,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 605,
        }, preview)
        browserPreviewMeta = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Position = UDim2.new(0, 14, 0.60, 56),
            Size = UDim2.new(1, -28, 0, 74),
            Text = "",
            TextColor3 = COLORS.muted or Color3.fromRGB(180, 171, 194),
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 605,
        }, preview)
        browserEquipButton = makeBrowserButton(preview, "EQUIP LOCALLY", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -94))
        browserEquipButton.BackgroundColor3 = COLORS.accent or Color3.fromRGB(121, 45, 218)
        browserOriginalButton = makeBrowserButton(preview, "USE ORIGINAL", UDim2.new(1, -28, 0, 34), UDim2.new(0, 14, 1, -48))
        track(browserEquipButton.Activated:Connect(function()
            if browserState.PreviewKey then setBrowserSelection(browserState.Kind, browserState.PreviewKey) end
        end))
        track(browserOriginalButton.Activated:Connect(function() setBrowserSelection(browserState.Kind, nil) end))

        track(search:GetPropertyChangedSignal("Text"):Connect(function()
            browserState.Query = search.Text
            browserState.Page = 1
            browserState.PreviewKey = nil
            if cosmeticControls.Refresh then cosmeticControls.Refresh() end
        end))
        track(UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == Enum.KeyCode.Escape and state.CosmeticBrowserRoot and state.CosmeticBrowserRoot.Visible then
                closeCosmeticBrowser()
            end
        end))
    end

    cosmeticControls.Refresh = function(rebuildFamilies)
        if not state.CosmeticBrowserRoot or not browserGrid then return end
        for kind, button in pairs(browserCategoryButtons) do
            local active = kind == browserState.Kind
            button.BackgroundColor3 = active and (COLORS.accent or Color3.fromRGB(121, 45, 218))
                or (COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39))
        end

        if rebuildFamilies or #browserFamilies == 0 then
            for _, child in ipairs(browserFamilyBar:GetChildren()) do child:Destroy() end
            table.clear(browserFamilies)
            create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, browserFamilyBar)
            local familiesForKind = cosmeticFamilies(browserState.Kind)
            table.insert(familiesForKind, 1, "All")
            for index, family in ipairs(familiesForKind) do
                local button = makeBrowserButton(browserFamilyBar, string.upper(family), UDim2.fromOffset(math.clamp(54 + #family * 6, 76, 170), 34))
                button.LayoutOrder = index
                browserFamilies[#browserFamilies + 1] = {Name = family, Button = button}
                button.Activated:Connect(function()
                    browserState.Family = family
                    browserState.Page = 1
                    browserState.PreviewKey = nil
                    if cosmeticControls.Refresh then cosmeticControls.Refresh() end
                end)
            end
        end
        for _, entry in ipairs(browserFamilies) do
            entry.Button.BackgroundColor3 = entry.Name == browserState.Family and (COLORS.accent or Color3.fromRGB(121, 45, 218))
                or (COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39))
        end

        for _, child in ipairs(browserGrid:GetChildren()) do child:Destroy() end
        table.clear(browserCards)
        local gridLayout = create("UIGridLayout", {
            CellPadding = UDim2.fromOffset(12, 12),
            CellSize = UDim2.fromOffset(196, 208),
            FillDirectionMaxCells = 4,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, browserGrid)
        create("UIPadding", {PaddingBottom = UDim.new(0, 8)}, browserGrid)

        local results = filteredBrowserItems()
        local pageCount = math.max(math.ceil(#results / browserState.PageSize), 1)
        browserState.Page = math.clamp(browserState.Page, 1, pageCount)
        local first = (browserState.Page - 1) * browserState.PageSize + 1
        local last = math.min(first + browserState.PageSize - 1, #results)
        browserResultLabel.Text = string.format("%s  /  %s  /  %d RESULT%s", string.upper(browserState.Kind), string.upper(browserState.Family), #results, #results == 1 and "" or "S")
        browserPageLabel.Text = string.format("PAGE %d / %d", browserState.Page, pageCount)
        browserGrid.CanvasPosition = Vector2.zero

        for index = first, last do
            local item = results[index]
            local selected = state.FESelections[item.Kind] == item.Key
            local card = create("ImageButton", {
                AutoButtonColor = false,
                BackgroundColor3 = selected and (COLORS.surfaceHover or Color3.fromRGB(48, 28, 70)) or (COLORS.surfaceRaised or Color3.fromRGB(28, 20, 39)),
                BackgroundTransparency = 0.04,
                BorderSizePixel = 0,
                Image = "",
                LayoutOrder = index,
                Size = UDim2.fromOffset(196, 208),
                ZIndex = 605,
            }, browserGrid)
            addCorner(card, 10)
            addStroke(card, selected and (COLORS.accentBright or Color3.fromRGB(166, 93, 255)) or rarityColor(item.Rarity), selected and 2 or 1, selected and 0.05 or 0.42)
            local image = create("ImageLabel", {
                BackgroundColor3 = COLORS.rail or Color3.fromRGB(13, 8, 22),
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                Image = item.Image,
                Position = UDim2.fromOffset(7, 7),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.new(1, -14, 0, 130),
                ZIndex = 606,
            }, card)
            addCorner(image, 8)
            if item.Image == "" then
                create("TextLabel", {BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Size = UDim2.fromScale(1, 1), Text = "NO IMAGE", TextColor3 = COLORS.dim or Color3.fromRGB(140, 130, 157), TextSize = 10, ZIndex = 607}, image)
            end
            create("TextLabel", {
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                Position = UDim2.fromOffset(10, 145),
                Size = UDim2.new(1, -20, 0, 34),
                Text = item.Display,
                TextColor3 = COLORS.text or Color3.fromRGB(246, 242, 251),
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 606,
            }, card)
            create("TextLabel", {
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Position = UDim2.new(0, 10, 1, -22),
                Size = UDim2.new(1, -20, 0, 16),
                Text = string.upper(item.Rarity),
                TextColor3 = rarityColor(item.Rarity),
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 606,
            }, card)
            browserCards[#browserCards + 1] = card
            card.Activated:Connect(function()
                browserState.PreviewKey = item.Key
                if cosmeticControls.Refresh then cosmeticControls.Refresh() end
            end)
        end

        local previewItem = browserItem(browserState.Kind, browserState.PreviewKey)
        local previewIsVisible = false
        if previewItem then
            for _, item in ipairs(results) do
                if item.Key == previewItem.Key then previewIsVisible = true break end
            end
        end
        if not previewIsVisible then previewItem = results[1] end
        if previewItem then
            browserState.PreviewKey = previewItem.Key
            local modelLoaded, inheritedModel = refreshPreviewModel(previewItem)
            browserPreviewName.Text = previewItem.Display
            local previewMode = modelLoaded and (inheritedModel and "LIVE BASE MODEL + EXACT SKIN ART" or "LIVE 3D MODEL + EFFECTS") or "EXACT CATALOG ART"
            browserPreviewMeta.Text = string.format("%s\n%s  /  %s  /  %s\n%s", previewItem.Key, previewItem.Kind, previewItem.Family, previewItem.Rarity, previewMode)
            browserPreviewMeta.TextColor3 = rarityColor(previewItem.Rarity)
            browserEquipButton.Text = state.FESelections[previewItem.Kind] == previewItem.Key and "EQUIPPED LOCALLY" or "EQUIP LOCALLY"
            browserEquipButton.Active = state.FESelections[previewItem.Kind] ~= previewItem.Key
        else
            browserState.PreviewKey = nil
            refreshPreviewModel(nil)
            browserPreviewName.Text = "No cosmetics found"
            browserPreviewMeta.Text = "Try another search or family."
            browserEquipButton.Text = "NOTHING TO EQUIP"
            browserEquipButton.Active = false
        end
        if gui then
            gui:SetAttribute("SniperArenaCosmeticBrowserReady", true)
            gui:SetAttribute("SniperArenaCosmeticBrowserKind", browserState.Kind)
            gui:SetAttribute("SniperArenaCosmeticBrowserResults", #results)
            gui:SetAttribute("SniperArenaCosmeticBrowserPage", browserState.Page)
            gui:SetAttribute("SniperArenaCosmeticBrowserCards", math.max(last - first + 1, 0))
        end
    end

    buildCosmeticBrowser()
    CosmeticSection:AddButton({Name = "Open Separate FE Inventory", Description = "Opens the independent draggable inventory and hides the main VOR window without closing the inventory.", Callback = function()
        if state.CosmeticBrowserRoot then
            setBrowserMinimized(false)
            browserState.PreviewKey = state.FESelections[browserState.Kind]
            cosmeticControls.Refresh(true)
            if Window.SetVisible then Window:SetVisible(false) end
        end
    end})
    end
    installCosmeticBrowser()
    task.delay(1.25, function()
        if not state.Alive then return end
        local resume = state.CosmeticResume
        local selections = type(resume) == "table" and type(resume.Selections) == "table" and resume.Selections or {}
        local function resumeKey(kind, key)
            local config = type(key) == "string" and CosmeticConfig[key] or nil
            return config and tostring(config.WeaponType or "") == kind and key or nil
        end
        local sniperKey = resumeKey("Sniper", selections.Sniper)
        local meleeKey = resumeKey("Melee", selections.Melee)
        local gloveKey = resumeKey("Glove", selections.Glove)
        local charmKey = resumeKey("Charm", selections.Charm)
        if sniperKey then
            cosmeticControls.SniperFamily:Set(tostring(CosmeticConfig[sniperKey].Family or state.FESniperFamily))
            cosmeticControls.SniperSkin:Set(state.CosmeticLabelByKey[sniperKey])
        end
        if meleeKey then
            cosmeticControls.MeleeFamily:Set(tostring(CosmeticConfig[meleeKey].Family or state.FEMeleeFamily))
            cosmeticControls.MeleeSkin:Set(state.CosmeticLabelByKey[meleeKey])
        end
        if gloveKey then cosmeticControls.GloveSkin:Set(state.CosmeticLabelByKey[gloveKey]) end
        if charmKey then cosmeticControls.CharmSkin:Set(state.CosmeticLabelByKey[charmKey]) end
        if type(resume) == "table" then cosmeticControls.FE:Set(resume.Enabled == true) end
        state.CosmeticResume = nil
        state.CosmeticPersistenceReady = true
        state.SaveCosmeticState()
    end)
    end
    CosmeticSection:AddButton({Name = "Reapply FE Cosmetics", Callback = function()
        local localCount = tryApplyLocalCosmeticSlots()
        local combatCount = applyCombatCosmetics()
        notify(string.format("FE cosmetics reapplied (%d local, %d combat)", localCount, combatCount), COLORS.success)
    end})
    local cosmeticLabel = CosmeticSection:AddLabel("FE: original server cosmetics")

    CaseSection:AddToggle({Name = "Auto Open Owned Cases", Description = "Uses the native case service and stops when ownership or inventory-space checks fail.", Flag = "sniper_arena_auto_open_cases", Default = false, Callback = function(v) state.AutoOpenCases = v == true end})
    CaseSection:AddSlider({Name = "Cases Per Batch", Flag = "sniper_arena_case_batch", Min = 1, Max = 5, Step = 1, Default = 5, Callback = function(v) state.CaseBatchSize = math.clamp(tonumber(v) or 5, 1, 5) end})
    CaseSection:AddButton({Name = "Open Next Owned Case Batch", Callback = function() local n = openOwnedCases() notify(state.LastAction, n > 0 and COLORS.success or COLORS.warning) end})
    local caseLabel = CaseSection:AddLabel("Cases: scanning...")

    ClaimSection:AddToggle({Name = "Auto Claim Tasks", Flag = "sniper_arena_auto_tasks", Default = false, Callback = function(v) state.AutoTasks = v == true end})
    ClaimSection:AddToggle({Name = "Auto Claim Mail", Flag = "sniper_arena_auto_mail", Default = false, Callback = function(v) state.AutoMail = v == true end})
    ClaimSection:AddToggle({Name = "Auto Claim Online Rewards", Flag = "sniper_arena_auto_online", Default = false, Callback = function(v) state.AutoOnlineRewards = v == true end})
    ClaimSection:AddButton({Name = "Claim Ready Rewards", Callback = function() claimTasks() claimMail() claimOnlineRewards() notify(state.LastAction, COLORS.success) end})
    local claimLabel = ClaimSection:AddLabel("Claims: scanning...")
    local coachLabel = CoachSection:AddLabel("Scanning progression...")
    local actionLabel = CoachSection:AddLabel("Last action: Ready")

    EspSection:AddToggle({Name = "Enemy ESP", Flag = "sniper_arena_esp", Default = false, Callback = function(v) state.EnemyEsp = v == true if not state.EnemyEsp then for p in pairs(highlights) do clearEsp(p) end end end})
    EspSection:AddToggle({Name = "Minimal Name Text", Description = "Optional transparent text only. Bots show BOT.", Flag = "sniper_arena_esp_minimal_names", Default = false, Callback = function(v) state.EspNameText = v == true end})
    EspSection:AddSlider({Name = "Name Text Range", Flag = "sniper_arena_esp_name_range", Min = 50, Max = 1500, Step = 50, Default = 350, Suffix = "m", Callback = function(v) state.EspNameRange = tonumber(v) or 350 end})
    EspSection:AddColorPicker({Name = "Outline Color", Flag = "sniper_arena_esp_color", Default = state.EspColor, Callback = function(v) if typeof(v) == "Color3" then state.EspColor = v end end})
    EspSection:AddColorPicker({Name = "Body Accent", Flag = "sniper_arena_esp_accent", Default = state.EspAccent, Callback = function(v) if typeof(v) == "Color3" then state.EspAccent = v end end})
    EspSection:AddSlider({Name = "Body Fill", Flag = "sniper_arena_esp_fill", Min = 0, Max = 100, Step = 1, Default = 22, Suffix = "%", Callback = function(v) state.EspFillTransparency = 1 - math.clamp(tonumber(v) or 22, 0, 100) / 100 end})
    EspSection:AddSlider({Name = "ESP Range", Flag = "sniper_arena_esp_range", Min = 100, Max = 5000, Step = 100, Default = 2000, Suffix = "m", Callback = function(v) state.EspMaxDistance = tonumber(v) or 2000 end})

    state.VisibilityControls.Fullbright = VisibilitySection:AddToggle({Name = "Fullbright", Description = "Flat visibility mode. This disables realistic shadows and is mutually exclusive with RTX-style graphics.", Flag = "sniper_arena_fullbright", Default = false, Callback = function(v)
        state.Fullbright = v == true
        if state.Fullbright and state.RealismGraphics then
            state.RealismGraphics = false
            if state.VisibilityControls.Realism then state.VisibilityControls.Realism:Set(false) end
        elseif not state.Fullbright and not state.RealismGraphics then
            state.RestoreGraphicsDefaults()
        end
    end})
    VisibilitySection:AddParagraph({
        Title = "RTX Ultra realism",
        Content = "Client-only Future lighting, harder contact shadows, atmospheric depth, stronger specular response, cinematic grading, bloom, sun rays, and optional depth of field. It is still not hardware ray tracing; Roblox does not expose that renderer.",
    })
    state.VisibilityControls.Realism = VisibilitySection:AddToggle({Name = "RTX ULTRA Realism", Description = "Maximum local renderer preset for capable GPUs: Future lighting, shadows, atmosphere, reflections, and post processing at Roblox quality level 21.", Flag = "sniper_arena_rtx_realism", Default = false, Callback = function(v)
        state.RealismGraphics = v == true
        if state.RealismGraphics and state.Fullbright then
            state.Fullbright = false
            if state.VisibilityControls.Fullbright then state.VisibilityControls.Fullbright:Set(false) end
        end
        state.ApplyRealismGraphics()
    end})
    state.VisibilityControls.RealismStrength = VisibilitySection:AddSlider({Name = "Realism Strength", Flag = "sniper_arena_rtx_strength", Min = 0, Max = 100, Step = 1, Default = 82, Suffix = "%", Callback = function(v)
        state.RealismStrength = math.clamp((tonumber(v) or 82) / 100, 0, 1)
        if state.RealismGraphics then state.ApplyRealismGraphics() end
    end})
    state.VisibilityControls.Depth = VisibilitySection:AddToggle({Name = "Cinematic Depth of Field", Description = "Optional subtle camera focus. Leave this off for the clearest competitive view.", Flag = "sniper_arena_rtx_dof", Default = false, Callback = function(v)
        state.RealismDepthOfField = v == true
        if state.RealismGraphics then state.ApplyRealismGraphics() end
    end})
    VisibilitySection:AddButton({Name = "Restore Original Graphics", Persist = false, Callback = function()
        state.Fullbright = false
        state.RealismGraphics = false
        if state.VisibilityControls.Fullbright then state.VisibilityControls.Fullbright:Set(false) end
        if state.VisibilityControls.Realism then state.VisibilityControls.Realism:Set(false) end
        state.RestoreGraphicsDefaults()
        notify("Original Sniper Arena lighting restored", COLORS.success)
    end})
    state.StatusLabels.Graphics = VisibilitySection:AddLabel("Graphics: original game lighting")
    VisibilitySection:AddToggle({Name = "Camera FOV Override", Flag = "sniper_arena_fov_override", Default = false, Callback = function(v)
        state.FovOverride = v == true
        local camera = workspace.CurrentCamera
        if camera and not state.FovOverride then camera.FieldOfView = defaults.CameraFov end
    end})
    VisibilitySection:AddSlider({Name = "Camera FOV", Flag = "sniper_arena_camera_fov", Min = 50, Max = 120, Step = 1, Default = 80, Callback = function(v) state.CameraFov = tonumber(v) or 80 end})

    MovementSection:AddToggle({Name = "Native Slide Speed", Description = "Multiplies the game's own slide impulse. No CFrame teleporting.", Flag = "sniper_arena_native_slide_speed", Default = false, Callback = function(v) state.SlideBoost = v == true end})
    MovementSection:AddSlider({Name = "Slide Multiplier", Description = "Experimental native range. Start at 1.5x.", Flag = "sniper_arena_slide_multiplier", Min = 1, Max = 3, Step = 0.1, Default = 1.5, Suffix = "x", Callback = function(v) state.SlideMultiplier = math.clamp(tonumber(v) or 1.5, 1, 3) end})
    MovementSection:AddToggle({Name = "Jump Height Override", Description = "Uses the character's native Humanoid jump height. No teleport or CFrame movement.", Flag = "sniper_arena_jump_override", Default = false, Callback = function(v)
        state.JumpBoost = v == true
        if state.JumpBoost then applyJumpBoost() else restoreJumpBoost() end
    end})
    MovementSection:AddSlider({Name = "Jump Height", Flag = "sniper_arena_jump_height", Min = 7, Max = 100, Step = 1, Default = 25, Suffix = " studs", Callback = function(v)
        state.JumpHeight = math.clamp(tonumber(v) or 25, 7, 100)
        if state.JumpBoost then applyJumpBoost() end
    end})
    MovementSection:AddLabel("Movement stays native: slide impulse + Humanoid jump only.")
    local playerStatusLabel = PlayerStatusSection:AddLabel("Player: scanning...")

    local queueNames = {}
    for name in pairs(MatchConfig.Queues or {}) do queueNames[#queueNames + 1] = name end
    table.sort(queueNames)
    for _, name in ipairs(queueNames) do QueueSection:AddButton({Name = "Queue " .. name, Callback = function() queue(name) end}) end
    QueueSection:AddButton({Name = "Cancel Queue", Callback = function()
        local ok, result = false, "matchmaking cancel unavailable"
        if MatchmakingService and type(MatchmakingService.Cancel) == "function" then
            ok, result = pcall(MatchmakingService.Cancel)
        end
        state.LastAction = ok and "Cancelled matchmaking" or ("Cancel failed: " .. tostring(result))
    end})
    local queueLabel = QueueSection:AddLabel("Queue: scanning...")
    local serverLabel = WorldStatusSection:AddLabel("Server: scanning...")
    local careerLabel = WorldStatusSection:AddLabel("Career: scanning...")

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then state.IsAiming = true end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then state.IsFiring = true end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then state.IsAiming = false end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then state.IsFiring = false end
    end))
    track(Players.PlayerRemoving:Connect(function(player)
        if player and player.Character then clearEsp(player.Character) end
    end))
    track(Players.PlayerAdded:Connect(function(player)
        track(player.CharacterAdded:Connect(function()
            task.defer(updateEsp)
        end))
    end))
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            track(player.CharacterAdded:Connect(function()
                task.defer(updateEsp)
            end))
        end
    end

    local function updateEnvironment()
        if state.RealismGraphics then
            state.ApplyRealismGraphics()
        elseif state.Fullbright then
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        end
        local camera = workspace.CurrentCamera
        if camera and state.FovOverride then camera.FieldOfView = state.CameraFov end
    end

    local function updateStatus()
        local kills = creditedKills()
        local content, familySet = ownedWeapons(), {}
        local count = 0
        for _, item in pairs(content) do count = count + 1 local family = familyOf(item) if family then familySet[family] = true end end
        local familyCount = 0 for _ in pairs(familySet) do familyCount = familyCount + 1 end
        state.StatusLabels.Inventory.Text = string.format("Owned: %d items | %d families | %s best", count, familyCount, tostring(bestOwnedPrimary() or "none"))
        local nextFamily, nextRequired = nil, math.huge
        for family, required in pairs(WeaponConfig.KilledUnlock or {}) do
            local owned = WeaponService and type(WeaponService.HasWeapon) == "function" and WeaponService.HasWeapon(family)
            required = tonumber(required) or math.huge
            if not owned and required < nextRequired then nextFamily, nextRequired = family, required end
        end
        state.StatusLabels.Unlock.Text = nextFamily and string.format("Kills: %d | Next: %s at %d (%d left)", kills, nextFamily, nextRequired, math.max(0, nextRequired - kills))
            or string.format("Kills: %d | All kill-gated snipers owned", kills)
        coachLabel.Text = nextFamily and string.format("Best move: earn %d more kills for %s", math.max(0, nextRequired - kills), nextFamily)
            or "Best move: tasks, battlepass, and ranked rewards"
        local mails = MailboxStore and MailboxStore.Data and MailboxStore.Data.Mails or {}
        local mailCount = 0 for _ in pairs(mails) do mailCount = mailCount + 1 end
        claimLabel.Text = string.format("Mail: %d | Tasks %s | Online %s", mailCount, state.AutoTasks and "AUTO" or "OFF", state.AutoOnlineRewards and "AUTO" or "OFF")
        local values = MatchmakingService and MatchmakingService.Values
        local queueValue = values and values:FindFirstChild("Queue")
        local waitingValue = values and values:FindFirstChild("Waiting")
        queueLabel.Text = string.format("Queue: %s | Waiting %s", queueValue and tostring(queueValue.Value) or "none", waitingValue and tostring(waitingValue.Value) or "false")
        local server = Remote and Remote:FindFirstChild("Server")
        local nameValue = server and server:FindFirstChild("ServerName")
        serverLabel.Text = string.format("%s | %s | Place %s", serverMode(), nameValue and tostring(nameValue.Value) or "Server", tostring(game.PlaceId))
        local stats = StatsStore and StatsStore.Data and StatsStore.Data._global or {}
        careerLabel.Text = string.format("Played %s | Kills %s | Deaths %s | Wins %s", tostring(stats.Played or 0), tostring(stats.Kill or 0), tostring(stats.Death or 0), tostring(stats.Win or 0))
        state.StatusLabels.Combat.Text = "Target: " .. (state.CurrentTarget and state.CurrentTarget.Parent and state.CurrentTarget.Parent.Name or "none")
        state.StatusLabels.Ammo.Text = string.format("Team %s | Health %s | Ping %sms", tostring(LocalPlayer:GetAttribute("Team") or "--"), tostring(LocalPlayer:GetAttribute("Health") or "--"), tostring(LocalPlayer:GetAttribute("Ping") or "--"))
        state.StatusLabels.WeaponMods.Text = string.format("Modified weapon values: %d", state.ModifiedWeaponValues)
        local cases = ownedCases()
        local caseTotal = 0
        for _, entry in ipairs(cases) do caseTotal += entry.Owned end
        caseLabel.Text = string.format("Owned %d across %d case type(s) | Opened %d", caseTotal, #cases, state.CasesOpened)
        cosmeticLabel.Text = "FE: " .. state.FELastApply .. " | " .. state.FELocalStatus
        local _, humanoid = character()
        playerStatusLabel.Text = string.format("Health %s | Jump %.1f | Slide %.1fx", tostring(LocalPlayer:GetAttribute("Health") or "--"),
            humanoid and humanoid.JumpHeight or 0, state.SlideMultiplier)
        state.StatusLabels.Graphics.Text = state.RealismGraphics
            and string.format("Graphics: RTX ULTRA %d%% | %s", math.floor(state.RealismStrength * 100 + 0.5), tostring(Lighting.Technology):gsub("Enum.Technology.", ""))
            or (state.Fullbright and "Graphics: Fullbright (shadows disabled)" or "Graphics: original game lighting")
        actionLabel.Text = "Last action: " .. state.LastAction
        pcall(function()
            gui:SetAttribute("SniperArenaModuleReady", true)
            gui:SetAttribute("SniperArenaUniverseId", game.GameId)
            gui:SetAttribute("SniperArenaPlaceId", game.PlaceId)
            gui:SetAttribute("SniperArenaMode", serverMode())
            gui:SetAttribute("SniperArenaMatchActive", isActiveMatch())
            gui:SetAttribute("SniperArenaCreditedKills", kills)
            gui:SetAttribute("SniperArenaOwnedWeapons", count)
            gui:SetAttribute("SniperArenaBestOwnedFamily", bestOwnedPrimary() or "")
            gui:SetAttribute("SniperArenaAutoUnlock", state.AutoUnlock)
            gui:SetAttribute("SniperArenaAutoOpenCases", state.AutoOpenCases)
            gui:SetAttribute("SniperArenaOwnedCases", caseTotal)
            gui:SetAttribute("SniperArenaCasesOpened", state.CasesOpened)
            gui:SetAttribute("SniperArenaSlideBoost", state.SlideBoost)
            gui:SetAttribute("SniperArenaSlideMultiplier", state.SlideMultiplier)
            gui:SetAttribute("SniperArenaBoostedSlides", state.BoostedSlides)
            gui:SetAttribute("SniperArenaNativeSlideAvailable", originalSlide ~= nil)
            gui:SetAttribute("SniperArenaJumpBoost", state.JumpBoost)
            gui:SetAttribute("SniperArenaJumpHeight", state.JumpHeight)
            gui:SetAttribute("SniperArenaFEUnlock", state.FEUnlock)
            gui:SetAttribute("SniperArenaFEAppliedCount", state.FEAppliedCount)
            gui:SetAttribute("SniperArenaFELocalAppliedCount", state.FELocalAppliedCount)
            gui:SetAttribute("SniperArenaFELocalStatus", state.FELocalStatus)
            gui:SetAttribute("SniperArenaFESniper", state.FESelections.Sniper or "")
            gui:SetAttribute("SniperArenaFEMelee", state.FESelections.Melee or "")
            gui:SetAttribute("SniperArenaFEGlove", state.FESelections.Glove or "")
            gui:SetAttribute("SniperArenaFECharm", state.FESelections.Charm or "")
            gui:SetAttribute("SniperArenaAimAssist", state.AimAssist)
            gui:SetAttribute("SniperArenaCursorAimbot", state.AimAssist)
            gui:SetAttribute("SniperArenaMouseMoverAvailable", moveMouseRelative ~= nil)
            gui:SetAttribute("SniperArenaAimRadius", state.AimRadius)
            gui:SetAttribute("SniperArenaAimSmoothness", state.AimSmoothness)
            gui:SetAttribute("SniperArenaTeamCheck", state.TeamCheck)
            gui:SetAttribute("SniperArenaHostileCount", #hostileModels())
            gui:SetAttribute("SniperArenaAimTarget", state.CurrentTarget and state.CurrentTarget:GetFullName() or "")
            gui:SetAttribute("SniperArenaSilentAim", state.SilentAim)
            gui:SetAttribute("SniperArenaSilentAimHooked", silentAimHooked)
            gui:SetAttribute("SniperArenaTriggerBot", state.TriggerBot)
            gui:SetAttribute("SniperArenaTriggerPausedByMenu", state.TriggerBot and menuBlocksTrigger())
            gui:SetAttribute("SniperArenaTriggerClicks", state.TriggerClicks)
            gui:SetAttribute("SniperArenaTriggerNativeAttempts", state.TriggerNativeAttempts)
            gui:SetAttribute("SniperArenaTriggerNativeShots", state.TriggerNativeShots)
            gui:SetAttribute("SniperArenaTriggerMouseFallbacks", state.TriggerMouseFallbacks)
            gui:SetAttribute("SniperArenaTriggerRaycastHits", state.TriggerRaycastHits)
            gui:SetAttribute("SniperArenaTriggerViewmodelBlocks", state.TriggerViewmodelBlocks)
            gui:SetAttribute("SniperArenaTriggerBlockReason", state.TriggerBlockReason)
            gui:SetAttribute("SniperArenaLastTriggerTarget", state.LastTriggerTarget)
            gui:SetAttribute("SniperArenaMouseClickAvailable", clickMouseOne ~= nil)
            gui:SetAttribute("SniperArenaNativeTriggerAvailable", CombatControllerApi ~= nil)
            gui:SetAttribute("SniperArenaHitboxExpand", state.HitboxExpand)
            gui:SetAttribute("SniperArenaHitboxSize", state.HitboxSize)
            gui:SetAttribute("SniperArenaHitboxAssistedShots", state.HitboxAssistedShots)
            gui:SetAttribute("SniperArenaNoRecoil", state.NoRecoil)
            gui:SetAttribute("SniperArenaNoSpread", state.NoSpread)
            gui:SetAttribute("SniperArenaFastReload", state.FastReload)
            gui:SetAttribute("SniperArenaModifiedWeaponValues", state.ModifiedWeaponValues)
            gui:SetAttribute("SniperArenaEnemyEsp", state.EnemyEsp)
            gui:SetAttribute("SniperArenaEspRefreshes", state.EspRefreshes)
            gui:SetAttribute("SniperArenaEspLastError", state.EspLastError)
            gui:SetAttribute("SniperArenaRTXRealism", state.RealismGraphics)
            gui:SetAttribute("SniperArenaRTXStrength", state.RealismStrength)
            gui:SetAttribute("SniperArenaRTXDepthOfField", state.RealismDepthOfField)
            gui:SetAttribute("SniperArenaRTXFutureApplied", state.RealismFutureApplied)
            gui:SetAttribute("SniperArenaRTXTechnology", tostring(Lighting.Technology))
            gui:SetAttribute("SniperArenaCosmeticBrowserStandalone", state.CosmeticBrowserGui ~= nil and state.CosmeticBrowserGui.Parent ~= nil)
            gui:SetAttribute("SniperArenaCosmeticBrowserVisible", state.CosmeticBrowserRoot ~= nil and state.CosmeticBrowserRoot.Visible)
            gui:SetAttribute("SniperArenaCosmeticBrowserMinimized", state.CosmeticBrowserMinimized == true)
            gui:SetAttribute("SniperArenaCosmeticBrowserMobileReady", true)
        end)
    end

    local renderStepName = "VORSniperArenaCamera_" .. tostring(LocalPlayer.UserId)
    local renderStepBound = false

    local ownedCleanup
    ownedCleanup = function()
        if not state.Alive then return end
        state.Alive = false
        state.AimAssist = false
        state.SilentAim = false
        state.EnemyEsp = false
        state.TriggerBot = false
        state.HitboxExpand = false
        state.NoRecoil = false
        state.NoSpread = false
        state.FastReload = false
        state.AutoOpenCases = false
        state.SlideBoost = false
        state.JumpBoost = false
        if state.CosmeticBrowserGui then
            state.CosmeticBrowserGui:Destroy()
            state.CosmeticBrowserGui = nil
            state.CosmeticBrowserRoot = nil
        elseif state.CosmeticBrowserRoot then
            state.CosmeticBrowserRoot:Destroy()
            state.CosmeticBrowserRoot = nil
        end
        restoreJumpBoost()
        restoreFECosmetics()
        state.FEUnlock = false
        releaseTriggerInput()
        restoreHitboxes()
        restoreWeaponValues()
        if originalSlide and boostedSlide and SlideHelper and SlideHelper.Slide == boostedSlide then
            SlideHelper.Slide = originalSlide
        end
        if renderStepBound then
            pcall(RunService.UnbindFromRenderStep, RunService, renderStepName)
            renderStepBound = false
        end
        if originalLocalShoot and silentCameraGetter and originalCameraGetter and silentTargetResolver and originalTargetResolver and type(debug) == "table"
            and type(debug.getupvalues) == "function" and type(debug.setupvalue) == "function" then
            local readOk, shotUpvalues = pcall(debug.getupvalues, originalLocalShoot)
            if readOk and shotUpvalues[2] == silentCameraGetter then
                pcall(debug.setupvalue, originalLocalShoot, 2, originalCameraGetter)
            end
            if readOk and shotUpvalues[4] == silentTargetResolver then
                pcall(debug.setupvalue, originalLocalShoot, 4, originalTargetResolver)
            end
        end
        for player in pairs(highlights) do clearEsp(player) end
        for _, object in ipairs(drawings) do pcall(function() object:Remove() end) end
        state.RestoreGraphicsDefaults()
        local camera = workspace.CurrentCamera
        if camera then camera.FieldOfView = defaults.CameraFov end
    end
    runtimeEnvironment.__VORSniperArenaCleanup = ownedCleanup
    if gui then track(gui.Destroying:Connect(function()
        -- A stale GUI can be destroyed after a replacement adapter is already
        -- running. It must never steal and invoke the replacement's cleanup.
        if runtimeEnvironment.__VORSniperArenaCleanup == ownedCleanup then
            runtimeEnvironment.__VORSniperArenaCleanup = nil
        end
        ownedCleanup()
    end)) end

    renderStepBound = pcall(function()
        RunService:BindToRenderStep(renderStepName, Enum.RenderPriority.Last.Value - 1, function(deltaTime)
            if not state.Alive then return end
            updateHitboxes()
            updateAim(deltaTime)
            updateFovCircle()
            updateEnvironment()
            applyJumpBoost()
        end)
    end)

    track(LocalMouse.Move:Connect(tryTrigger))

    local automationClock, statusClock, espClock, weaponClock, caseClock, cosmeticClock = 0, 0, 0, 0, 0, 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then return end
        statusClock = statusClock + deltaTime
        espClock = espClock + deltaTime
        weaponClock = weaponClock + deltaTime
        automationClock = automationClock + deltaTime
        caseClock = caseClock + deltaTime
        cosmeticClock = cosmeticClock + deltaTime
        if espClock >= 0.15 then espClock = 0 updateEsp() end
        tryTrigger()
        if weaponClock >= 0.1 then weaponClock = 0 updateWeaponModifiers() end
        if statusClock >= 0.5 then statusClock = 0 updateStatus() end
        if caseClock >= 0.85 then
            caseClock = 0
            if state.AutoOpenCases then openOwnedCases() end
        end
        if cosmeticClock >= 0.5 then
            cosmeticClock = 0
            if state.FEUnlock then
                tryApplyLocalCosmeticSlots()
                applyCombatCosmetics()
            end
        end
        if automationClock >= 5 then
            automationClock = 0
            if state.AutoUnlock then unlockEarned() end
            if state.AutoTasks then claimTasks() end
            if state.AutoMail then claimMail() end
            if state.AutoOnlineRewards then claimOnlineRewards() end
        end
    end))

    updateStatus()
    selectHomeCategory("Combat")
    notify("Sniper Arena module ready", COLORS.success)
end
