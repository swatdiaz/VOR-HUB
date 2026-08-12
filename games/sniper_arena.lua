-- VOR Hub - Sniper Arena adapter
-- UniverseId 9534705677 | observed places 122446657157717, 126042865144779

return function(context)
    local Window = assert(context.Window, "Sniper Arena: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Sniper Arena: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection) return connection end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local CollectionService = game:GetService("CollectionService")
    local LocalPlayer = Players.LocalPlayer
    local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G

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
    local StatusService = safeRequire(Remote and Remote:FindFirstChild("StatusService"))
    local StatsStore = safeRequire(Remote and Remote:FindFirstChild("StatsService") and Remote.StatsService:FindFirstChild("LocalStatsStore"))
    local QuestService = safeRequire(Remote and Remote:FindFirstChild("QuestService"))
    local MailboxService = safeRequire(Remote and Remote:FindFirstChild("MailboxService"))
    local MailboxStore = safeRequire(Remote and Remote:FindFirstChild("MailboxService") and Remote.MailboxService:FindFirstChild("LocalMailboxStore"))
    local MatchmakingService = safeRequire(Remote and Remote:FindFirstChild("MatchmakingService"))
    local CareerStore = safeRequire(Remote and Remote:FindFirstChild("CareerStatsService") and Remote.CareerStatsService:FindFirstChild("LocalCareerStatsStore"))
    local CombatController = Client and Client:FindFirstChild("CombatController")
    local ClientComponent = CombatController and CombatController:FindFirstChild("ClientComponent")
    local ClientShootableComponent = safeRequire(ClientComponent and ClientComponent:FindFirstChild("ClientShootableComponent"))
    local WeaponConfig = safeRequire(Config and Config:FindFirstChild("Config") and Config.Config:FindFirstChild("Weapon")) or {}
    local MatchConfig = safeRequire(Config and Config:FindFirstChild("Config") and Config.Config:FindFirstChild("Matchmaking")) or {}

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local CombatPage = addHomeCategory("Combat", 1, CATEGORY_DECALS.Combat)
    local InventoryPage = addHomeCategory("Inventory", 2, CATEGORY_DECALS.Mastery or CATEGORY_DECALS.Progress)
    local ProgressPage = addHomeCategory("Progress", 3, CATEGORY_DECALS.Progress)
    local VisualsPage = addHomeCategory("Visuals", 4, CATEGORY_DECALS.Visuals)
    local WorldPage = addHomeCategory("World", 5, CATEGORY_DECALS.World or CATEGORY_DECALS.Player)

    local AimSection = CombatPage:AddSection("Aim Assist", "Left")
    local CombatStatusSection = CombatPage:AddSection("Combat Status", "Right")
    local WeaponSection = InventoryPage:AddSection("Owned Snipers", "Left")
    local UnlockSection = InventoryPage:AddSection("Server Unlock Progress", "Right")
    local ClaimSection = ProgressPage:AddSection("Claims", "Left")
    local CoachSection = ProgressPage:AddSection("What To Do Next", "Right")
    local EspSection = VisualsPage:AddSection("Enemy ESP", "Left")
    local VisibilitySection = VisualsPage:AddSection("Visibility", "Right")
    local QueueSection = WorldPage:AddSection("Matchmaking", "Left")
    local WorldStatusSection = WorldPage:AddSection("Server Status", "Right")

    HomePage:AddSection("Sniper Arena Support", "Left"):AddParagraph({
        Title = "Native, server-checked progression",
        Content = "VOR uses the game's owned weapon store, kill-gated unlock service, loadouts, tasks, mailbox, queues, and match state. Locked inventory is never presented as owned.",
    })
    local guide = HomePage:AddSection("Quick Start", "Right")
    guide:AddParagraph({Title = "Combat", Content = "Silent Aim redirects native shot rays without moving the camera. Aim Assist visibly tracks targets; both share the radius, target-part, team, and wall checks."})
    guide:AddParagraph({Title = "Progress", Content = "Use Auto Unlock Earned Snipers and Auto Claim. The server still enforces kill requirements and reward readiness."})
    guide:AddButton({Name = "Open Combat", Persist = false, Callback = function() selectHomeCategory("Combat") end})
    guide:AddButton({Name = "Open Progress", Persist = false, Callback = function() selectHomeCategory("Progress") end})

    local defaults = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        CameraFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
    }
    local state = {
        Alive = true,
        AimAssist = false,
        SilentAim = false,
        SilentAimChance = 100,
        SilentAimPrediction = 0,
        AimActivation = "While Aiming",
        AimPart = "Head",
        AimRadius = 180,
        AimStrength = 24,
        TeamCheck = true,
        WallCheck = true,
        ShowFov = true,
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
        SelectedFamily = "SSG",
        LastClaim = 0,
        LastUnlock = 0,
        LastStatus = 0,
        LastAction = "Ready",
        CurrentTarget = nil,
    }
    local drawings = {}
    local highlights = {}

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

    local function sameTeam(player)
        local mode = serverMode()
        if mode == "Arcade" or string.find(mode, "FFA", 1, true) then return false end
        local mine, theirs = LocalPlayer:GetAttribute("Team"), player:GetAttribute("Team")
        if mine ~= nil and theirs ~= nil then return mine == theirs end
        return LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team
    end

    local function isEnemy(player)
        local _, humanoid, root = character(player)
        return player ~= LocalPlayer and humanoid ~= nil and humanoid.Health > 0 and root ~= nil
            and (not state.TeamCheck or not sameTeam(player))
    end

    local function modelHealth(model, humanoid)
        local attributed = model and tonumber(model:GetAttribute("Health"))
        if attributed ~= nil then return attributed end
        return humanoid and humanoid.Health or 0
    end

    local function addHostile(records, seen, model, displayName, kind)
        if not model or not model:IsA("Model") or seen[model] or model == LocalPlayer.Character then return end
        local tempRoot = workspace:FindFirstChild("_Temp")
        if tempRoot and model:IsDescendantOf(tempRoot) then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
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
                    local role = tostring(model:GetAttribute("Role") or "")
                    local kind = role == "Boss" and "BOSS" or (CollectionService:HasTag(model, "Bot") and "BOT" or "ENEMY")
                    addHostile(records, seen, model, model:GetAttribute("DisplayName") or model.Name, kind)
                end
            end
        end
        for _, tagged in ipairs(CollectionService:GetTagged("Boss")) do
            local model = tagged:IsA("Model") and tagged or tagged:FindFirstAncestorOfClass("Model")
            addHostile(records, seen, model, model and (model:GetAttribute("DisplayName") or model.Name), "BOSS")
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if isEnemy(player) then addHostile(records, seen, player.Character, player.DisplayName, "PLAYER") end
        end
        return records
    end

    local function targetPart(model)
        if not model then return nil end
        if state.AimPart == "Head" then return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") end
        if state.AimPart == "Torso" then return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart") end
        return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    end

    local function lineOfSight(part)
        if not state.WallCheck then return true end
        local camera = workspace.CurrentCamera
        if not camera or not part then return false end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
        params.IgnoreWater = true
        local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
        return result == nil or result.Instance:IsDescendantOf(part.Parent)
    end

    local function acquireTarget()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
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

    local function aimActive()
        if not state.AimAssist then return false end
        if state.AimActivation == "Always" then return true end
        if state.AimActivation == "While Firing" then return state.IsFiring end
        return state.IsAiming
    end

    local function updateAim(deltaTime)
        if not aimActive() then state.CurrentTarget = nil return end
        local camera = workspace.CurrentCamera
        local part = acquireTarget()
        state.CurrentTarget = part
        if not camera or not part then return end
        local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
        local alpha = 1 - math.exp(-math.clamp(state.AimStrength, 1, 100) * deltaTime / 7)
        camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
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
        fovCircle.Visible = state.Alive and state.AimAssist and state.ShowFov and camera ~= nil
        if camera then
            fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            fovCircle.Radius = state.AimRadius
        end
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
                    entry.Label.Text = hostile.Kind == "BOT" and "BOT" or (hostile.Kind == "BOSS" and "BOSS" or hostile.Name)
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

    local function queue(name)
        if not MatchmakingService or type(MatchmakingService.Match) ~= "function" then notify("Matchmaking unavailable", COLORS.warning) return end
        local ok, result = pcall(MatchmakingService.Match, name)
        state.LastAction = ok and result ~= false and ("Queued for " .. name) or ("Queue failed: " .. tostring(result))
        notify(state.LastAction, ok and COLORS.success or COLORS.warning)
    end

    local families = ownedFamilies()
    if #families == 0 then families = {"SSG"} end
    state.SelectedFamily = bestOwnedPrimary() or families[1]

    AimSection:AddToggle({Name = "Aim Assist", Flag = "sniper_arena_aim", Default = false, Callback = function(v) state.AimAssist = v == true end})
    AimSection:AddToggle({Name = "Silent Aim", Description = "Redirects the native LocalShoot ray without moving your camera.", Flag = "sniper_arena_silent_aim", Default = false, Callback = function(v) state.SilentAim = v == true end})
    AimSection:AddSlider({Name = "Silent Hit Chance", Flag = "sniper_arena_silent_chance", Min = 1, Max = 100, Step = 1, Default = 100, Suffix = "%", Callback = function(v) state.SilentAimChance = tonumber(v) or 100 end})
    AimSection:AddSlider({Name = "Target Prediction", Flag = "sniper_arena_silent_prediction", Min = 0, Max = 0.3, Step = 0.01, Default = 0, Suffix = "s", Callback = function(v) state.SilentAimPrediction = tonumber(v) or 0 end})
    AimSection:AddDropdown({Name = "Activation", Flag = "sniper_arena_aim_activation", Options = {"While Aiming", "While Firing", "Always"}, Default = "While Aiming", Callback = function(v) state.AimActivation = v or "While Aiming" end})
    AimSection:AddDropdown({Name = "Target Part", Flag = "sniper_arena_aim_part", Options = {"Head", "Torso", "Root"}, Default = "Head", Callback = function(v) state.AimPart = v or "Head" end})
    AimSection:AddSlider({Name = "Aim Strength", Flag = "sniper_arena_aim_strength", Min = 1, Max = 100, Step = 1, Default = 24, Suffix = "%", Callback = function(v) state.AimStrength = tonumber(v) or 24 end})
    AimSection:AddSlider({Name = "Aim Radius", Flag = "sniper_arena_aim_radius", Min = 30, Max = 600, Step = 10, Default = 180, Suffix = "px", Callback = function(v) state.AimRadius = tonumber(v) or 180 end})
    AimSection:AddToggle({Name = "Team Check", Flag = "sniper_arena_team_check", Default = true, Callback = function(v) state.TeamCheck = v == true end})
    AimSection:AddToggle({Name = "Wall Check", Flag = "sniper_arena_wall_check", Default = true, Callback = function(v) state.WallCheck = v == true end})
    AimSection:AddToggle({Name = "Show Aim Radius", Flag = "sniper_arena_show_fov", Default = true, Callback = function(v) state.ShowFov = v == true end})

    local combatLabel = CombatStatusSection:AddLabel("Target: none")
    local ammoLabel = CombatStatusSection:AddLabel("Combat: scanning...")

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
    UnlockSection:AddLabel("FE unlock-all is not faked: ownership stays server-authoritative.")
    local unlockLabel = UnlockSection:AddLabel("Unlocks: scanning...")

    ClaimSection:AddToggle({Name = "Auto Claim Tasks", Flag = "sniper_arena_auto_tasks", Default = false, Callback = function(v) state.AutoTasks = v == true end})
    ClaimSection:AddToggle({Name = "Auto Claim Mail", Flag = "sniper_arena_auto_mail", Default = false, Callback = function(v) state.AutoMail = v == true end})
    ClaimSection:AddToggle({Name = "Auto Claim Online Rewards", Flag = "sniper_arena_auto_online", Default = false, Callback = function(v) state.AutoOnlineRewards = v == true end})
    ClaimSection:AddButton({Name = "Claim Ready Rewards", Callback = function() claimTasks() claimMail() claimOnlineRewards() notify(state.LastAction, COLORS.success) end})
    local claimLabel = ClaimSection:AddLabel("Claims: scanning...")
    local coachLabel = CoachSection:AddLabel("Scanning progression...")
    local actionLabel = CoachSection:AddLabel("Last action: Ready")

    EspSection:AddToggle({Name = "Enemy ESP", Flag = "sniper_arena_esp", Default = false, Callback = function(v) state.EnemyEsp = v == true if not state.EnemyEsp then for p in pairs(highlights) do clearEsp(p) end end end})
    EspSection:AddToggle({Name = "Minimal Name Text", Description = "Optional transparent text only. Bots show BOT and bosses show BOSS.", Flag = "sniper_arena_esp_minimal_names", Default = false, Callback = function(v) state.EspNameText = v == true end})
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
        actionLabel.Text = "Last action: " .. state.LastAction
        pcall(function()
            gui:SetAttribute("SniperArenaModuleReady", true)
            gui:SetAttribute("SniperArenaUniverseId", game.GameId)
            gui:SetAttribute("SniperArenaPlaceId", game.PlaceId)
            gui:SetAttribute("SniperArenaMode", serverMode())
            gui:SetAttribute("SniperArenaCreditedKills", kills)
            gui:SetAttribute("SniperArenaOwnedWeapons", count)
            gui:SetAttribute("SniperArenaBestOwnedFamily", bestOwnedPrimary() or "")
            gui:SetAttribute("SniperArenaAutoUnlock", state.AutoUnlock)
            gui:SetAttribute("SniperArenaAimAssist", state.AimAssist)
            gui:SetAttribute("SniperArenaSilentAim", state.SilentAim)
            gui:SetAttribute("SniperArenaSilentAimHooked", silentAimHooked)
            gui:SetAttribute("SniperArenaEnemyEsp", state.EnemyEsp)
        end)
    end

    local renderStepName = "VORSniperArenaCamera_" .. tostring(LocalPlayer.UserId)
    local renderStepBound = false

    runtimeEnvironment.__VORSniperArenaCleanup = function()
        if not state.Alive then return end
        state.Alive = false
        state.AimAssist = false
        state.SilentAim = false
        state.EnemyEsp = false
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
    if gui then track(gui.Destroying:Connect(function()
        local cleanup = runtimeEnvironment.__VORSniperArenaCleanup
        runtimeEnvironment.__VORSniperArenaCleanup = nil
        if type(cleanup) == "function" then cleanup() end
    end)) end

    renderStepBound = pcall(function()
        RunService:BindToRenderStep(renderStepName, Enum.RenderPriority.Last.Value - 1, function(deltaTime)
            if not state.Alive then return end
            updateAim(deltaTime)
            updateFovCircle()
            updateEnvironment()
        end)
    end)

    local automationClock, statusClock, espClock = 0, 0, 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then return end
        statusClock = statusClock + deltaTime
        espClock = espClock + deltaTime
        automationClock = automationClock + deltaTime
        if espClock >= 0.15 then espClock = 0 updateEsp() end
        if statusClock >= 0.5 then statusClock = 0 updateStatus() end
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
