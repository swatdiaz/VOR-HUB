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
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
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
        LastTriggerTarget = "",
        HitboxAssistedShots = 0,
        HitboxExpand = false,
        HitboxSize = 5,
        NoRecoil = false,
        NoSpread = false,
        FastReload = false,
        ModifiedWeaponValues = 0,
        EnemyEsp = false,
        EspNameText = false,
        EspNameRange = 350,
        EspMaxDistance = 2000,
        EspColor = Color3.fromRGB(72, 205, 255),
        EspAccent = Color3.fromRGB(155, 103, 255),
        EspFillTransparency = 0.78,
        Fullbright = false,
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

    local lastTriggerTarget, lastTriggerAt = nil, -math.huge
    local function tryTrigger()
        if not state.Alive or not state.TriggerBot or not isActiveMatch()
            or menuBlocksTrigger() or UserInputService:GetFocusedTextBox() ~= nil then
            lastTriggerTarget = nil
            return false
        end
        local target = LocalMouse.Target
        local hostile = hostileForTarget(target)
        if hostile and state.HitboxExpand and not hasVisibleBody(hostile.Model) then
            target, hostile = nil, nil
        end
        if not hostile and state.HitboxExpand then
            target = acquireExpandedHitboxTarget()
            hostile = hostileForTarget(target)
        end
        if not target or not hostile then
            lastTriggerTarget = nil
            return false
        end
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
            local model, humanoid, root = hostile.Model, hostile.Humanoid, hostile.Root
            active[model] = true
            if state.EnemyEsp then
                local distance = localRoot and (root.Position - localRoot.Position).Magnitude or math.huge
                if distance <= state.EspMaxDistance then
                    local entry = highlights[model]
                    if not entry or not entry.Highlight.Parent then
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
        end
        for model in pairs(highlights) do
            if not active[model] then clearEsp(model) end
        end
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
            end
        end
    end
    for _, familiesByType in pairs(cosmeticCatalog) do
        for _, labels in pairs(familiesByType) do
            table.sort(labels, function(a, b) return string.lower(a) < string.lower(b) end)
        end
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
    local sniperSkinControl, meleeSkinControl

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
    local combatLabel = CombatStatusSection:AddLabel("Target: none")
    local ammoLabel = CombatStatusSection:AddLabel("Combat: scanning...")

    WeaponModsSection:AddToggle({Name = "No Recoil", Description = "Zeros recoil and kick values on the equipped tool.", Flag = "sniper_arena_no_recoil", Default = false, Callback = function(v) state.NoRecoil = v == true if not state.NoRecoil then updateWeaponModifiers() end end})
    WeaponModsSection:AddToggle({Name = "No Spread", Description = "Zeros spread and accuracy values on the equipped tool.", Flag = "sniper_arena_no_spread", Default = false, Callback = function(v) state.NoSpread = v == true if not state.NoSpread then updateWeaponModifiers() end end})
    WeaponModsSection:AddToggle({Name = "Fast Reload", Description = "Sets equipped-tool reload/time values to 0.05 and restores them on toggle-off.", Flag = "sniper_arena_fast_reload", Default = false, Callback = function(v) state.FastReload = v == true if not state.FastReload then updateWeaponModifiers() end end})
    local weaponModsLabel = WeaponModsSection:AddLabel("Modified weapon values: 0")

    WeaponSection:AddDropdown({Name = "Owned Family", Flag = "sniper_arena_family", Options = families, Default = state.SelectedFamily, Callback = function(v) state.SelectedFamily = v or state.SelectedFamily end})
    WeaponSection:AddButton({Name = "Equip Selected Family", Callback = function() if not equipFamily(state.SelectedFamily) then notify(state.LastAction, COLORS.warning) end end})
    WeaponSection:AddButton({Name = "Equip Best Owned Sniper", Callback = function()
        local family = bestOwnedPrimary()
        if family then state.SelectedFamily = family equipFamily(family) else notify("No owned primary sniper found", COLORS.warning) end
    end})
    WeaponSection:AddLabel("Only server-owned weapon IDs are accepted by loadouts.")
    local inventoryLabel = WeaponSection:AddLabel("Inventory: scanning...")

    UnlockSection:AddToggle({Name = "Auto Unlock Earned Snipers", Description = "Calls the native unlock only after credited kills meet the server requirement.", Flag = "sniper_arena_auto_unlock", Default = false, Callback = function(v) state.AutoUnlock = v == true end})
    UnlockSection:AddButton({Name = "Unlock Everything Earned", Callback = function() local n = unlockEarned() notify(state.LastAction, n > 0 and COLORS.success or COLORS.warning) end})
    UnlockSection:AddLabel("Server ownership stays untouched. The FE showcase below is local-only.")
    local unlockLabel = UnlockSection:AddLabel("Unlocks: scanning...")

    CosmeticSection:AddParagraph({
        Title = "Soft unlock — only you see it",
        Content = "Choose any sniper, melee, glove, or charm model. VOR swaps the local inventory/first-person presentation while every real server weapon ID and ownership record stays unchanged.",
    })
    CosmeticSection:AddToggle({Name = "FE Unlock All Cosmetics", Description = "Enables client-only inventory and viewmodel swaps. Toggle off restores the exact server-equipped cosmetics.", Flag = "sniper_arena_fe_unlock_all", Default = false, Callback = function(v)
        local enabled = v == true
        if not enabled then restoreFECosmetics() end
        state.FEUnlock = enabled
        if enabled then
            tryApplyLocalCosmeticSlots()
            applyCombatCosmetics()
        end
    end})
    CosmeticSection:AddDropdown({Name = "Sniper Family", Flag = "sniper_arena_fe_sniper_family", Options = sniperFamilies, Default = state.FESniperFamily, Callback = function(v)
        state.FESniperFamily = v or state.FESniperFamily
        state.FESelections.Sniper = nil
        if sniperSkinControl then
            sniperSkinControl:SetOptions(cosmeticOptions("Sniper", state.FESniperFamily))
            sniperSkinControl:Set(ORIGINAL_COSMETIC)
        end
    end})
    sniperSkinControl = CosmeticSection:AddDropdown({Name = "Sniper Model / Skin", Flag = "sniper_arena_fe_sniper_skin", Options = cosmeticOptions("Sniper", state.FESniperFamily), Default = ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Sniper = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() applyCombatCosmetics() end
    end})
    CosmeticSection:AddDropdown({Name = "Melee Family", Flag = "sniper_arena_fe_melee_family", Options = meleeFamilies, Default = state.FEMeleeFamily, Callback = function(v)
        state.FEMeleeFamily = v or state.FEMeleeFamily
        state.FESelections.Melee = nil
        if meleeSkinControl then
            meleeSkinControl:SetOptions(cosmeticOptions("Melee", state.FEMeleeFamily))
            meleeSkinControl:Set(ORIGINAL_COSMETIC)
        end
    end})
    meleeSkinControl = CosmeticSection:AddDropdown({Name = "Knife / Melee Model", Flag = "sniper_arena_fe_melee_skin", Options = cosmeticOptions("Melee", state.FEMeleeFamily), Default = ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Melee = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() applyCombatCosmetics() end
    end})
    CosmeticSection:AddDropdown({Name = "Glove Model", Flag = "sniper_arena_fe_glove", Options = cosmeticOptions("Glove"), Default = ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Glove = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() end
    end})
    CosmeticSection:AddDropdown({Name = "Charm Model", Flag = "sniper_arena_fe_charm", Options = cosmeticOptions("Charm"), Default = ORIGINAL_COSMETIC, Callback = function(v)
        state.FESelections.Charm = cosmeticKeyByLabel[v]
        if state.FEUnlock then tryApplyLocalCosmeticSlots() end
    end})
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

    VisibilitySection:AddToggle({Name = "Fullbright", Flag = "sniper_arena_fullbright", Default = false, Callback = function(v)
        state.Fullbright = v == true
        if not state.Fullbright then
            Lighting.Brightness = defaults.Brightness
            Lighting.ClockTime = defaults.ClockTime
            Lighting.FogEnd = defaults.FogEnd
            Lighting.GlobalShadows = defaults.GlobalShadows
        end
    end})
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
    track(Players.PlayerRemoving:Connect(clearEsp))

    local function updateEnvironment()
        if state.Fullbright then
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
        inventoryLabel.Text = string.format("Owned: %d items | %d families | %s best", count, familyCount, tostring(bestOwnedPrimary() or "none"))
        local nextFamily, nextRequired = nil, math.huge
        for family, required in pairs(WeaponConfig.KilledUnlock or {}) do
            local owned = WeaponService and type(WeaponService.HasWeapon) == "function" and WeaponService.HasWeapon(family)
            required = tonumber(required) or math.huge
            if not owned and required < nextRequired then nextFamily, nextRequired = family, required end
        end
        unlockLabel.Text = nextFamily and string.format("Kills: %d | Next: %s at %d (%d left)", kills, nextFamily, nextRequired, math.max(0, nextRequired - kills))
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
        combatLabel.Text = "Target: " .. (state.CurrentTarget and state.CurrentTarget.Parent and state.CurrentTarget.Parent.Name or "none")
        ammoLabel.Text = string.format("Team %s | Health %s | Ping %sms", tostring(LocalPlayer:GetAttribute("Team") or "--"), tostring(LocalPlayer:GetAttribute("Health") or "--"), tostring(LocalPlayer:GetAttribute("Ping") or "--"))
        weaponModsLabel.Text = string.format("Modified weapon values: %d", state.ModifiedWeaponValues)
        local cases = ownedCases()
        local caseTotal = 0
        for _, entry in ipairs(cases) do caseTotal += entry.Owned end
        caseLabel.Text = string.format("Owned %d across %d case type(s) | Opened %d", caseTotal, #cases, state.CasesOpened)
        cosmeticLabel.Text = "FE: " .. state.FELastApply .. " | " .. state.FELocalStatus
        local _, humanoid = character()
        playerStatusLabel.Text = string.format("Health %s | Jump %.1f | Slide %.1fx", tostring(LocalPlayer:GetAttribute("Health") or "--"),
            humanoid and humanoid.JumpHeight or 0, state.SlideMultiplier)
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
        Lighting.Brightness = defaults.Brightness
        Lighting.ClockTime = defaults.ClockTime
        Lighting.FogEnd = defaults.FogEnd
        Lighting.GlobalShadows = defaults.GlobalShadows
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
