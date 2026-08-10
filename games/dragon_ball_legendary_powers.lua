-- VOR Hub - Dragon Ball Legendary Powers progression adapter
-- Universe 4501539222 / place 12860709641.
--
-- The automation layer uses the experience's native, range-validated combat,
-- training, transform, shop, and wish remotes.

return function(context)
    local Window = assert(context.Window, "Dragon Ball Legendary Powers: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Dragon Ball Legendary Powers: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local environment = type(getgenv) == "function" and getgenv() or _G
    local resumeFastRoute = environment.VORDBLPResumeFastRoute == true
    local resumeGuardUntil = resumeFastRoute and (os.clock() + 15) or 0
    local visitedServers = type(environment.VORDBLPVisitedServers) == "table"
        and environment.VORDBLPVisitedServers or {}
    environment.VORDBLPVisitedServers = visitedServers

    local Training = ReplicatedStorage:WaitForChild("Training")
    local Combat = ReplicatedStorage:WaitForChild("Combat")
    local TrainRemote = Training:WaitForChild("Train")
    local PunchRemote = Combat:WaitForChild("Punch")
    local DamageRemote = Combat:WaitForChild("Damage")
    local BlastRemote = Combat:WaitForChild("Blast")
    local ChargeRemote = Combat:WaitForChild("Charge")
    local TransformRemote = ReplicatedStorage:WaitForChild("Transform")
    local ShopRemote = ReplicatedStorage:WaitForChild("Shop")
    local WishRemote = ReplicatedStorage:WaitForChild("ShenronWish")

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local PowerPage = addHomeCategory("⚡ Fastest OP", 1, CATEGORY_DECALS.Progress)
    local FarmPage = addHomeCategory("🥊 Autofarm", 2, CATEGORY_DECALS.Overnight)
    local TrainingPage = addHomeCategory("🏋️ Training", 3, CATEGORY_DECALS.Progress)
    local FormsPage = addHomeCategory("🔥 Forms & Skills", 4, CATEGORY_DECALS.Combat)
    local TravelPage = addHomeCategory("🚀 Travel", 5, CATEGORY_DECALS.Player)
    local StatusPage = addHomeCategory("📊 Status", 6, CATEGORY_DECALS.Visuals)
    selectHomeCategory("⚡ Fastest OP")

    local PowerRouteSection = PowerPage:AddSection("⚡ Shenron Capsule Route", "Left")
    local PowerBoostSection = PowerPage:AddSection("🛰️ Best Passive Gains", "Right")
    local PowerProgressSection = PowerPage:AddSection("📈 Route Progress", "Right")
    local FarmSection = FarmPage:AddSection("🥊 Native NPC Farm", "Left")
    local FarmSafetySection = FarmPage:AddSection("🛡️ Farm Safety", "Right")
    local FarmStatusSection = FarmPage:AddSection("🎯 Farm Status", "Right")
    local StatTrainingSection = TrainingPage:AddSection("🏋️ Automatic Training", "Left")
    local TrainerSection = TrainingPage:AddSection("🧙 Master Trainers", "Right")
    local ShopSection = TrainingPage:AddSection("🛒 Progression Shop", "Right")
    local TransformSection = FormsPage:AddSection("🔥 Transformations", "Left")
    local SkillSection = FormsPage:AddSection("✨ Learned Skills", "Right")
    local WishSection = FormsPage:AddSection("🐉 Shenron Wishes", "Right")
    local TeleportSection = TravelPage:AddSection("🚀 Locations", "Left")
    local MovementSection = TravelPage:AddSection("🏃 Movement", "Right")
    local LiveStatsSection = StatusPage:AddSection("📊 Live Stats", "Left")
    local AdapterStatusSection = StatusPage:AddSection("🧪 Runtime Evidence", "Right")

    local state = {
        Alive = true,
        AutoOPRoute = resumeFastRoute,
        AutoWeightTraining = false,
        PersistentGravity = false,
        AutoMilestones = false,
        AutoProgressionShop = false,
        AutoShenron = false,
        PreferredWish = "Power First",
        RouteStartedAt = 0,
        RouteStartPL = 0,
        RouteStartPhysical = 0,
        RoutePhase = "Ready",
        LastGravityAttempt = 0,
        LastWeightActivation = 0,
        LastMilestoneAttempt = 0,
        LastShopAttempt = 0,
        LastWishAttempt = 0,
        WeightInterval = 0.25,
        ShopBusy = false,
        CapsulesBought = tonumber(environment.VORDBLPCapsulesBought) or 0,
        ZeniClaims = tonumber(environment.VORDBLPZeniClaims) or 0,
        TargetBasePower = tonumber(environment.VORDBLPTargetBasePower) or 10000000,
        ServerClaimBusy = false,
        ServerClaimResolved = false,
        ServerClaimAttempts = 0,
        ServerClaimDelta = 0,
        HopBusy = false,
        LastHopAttempt = 0,
        TeleportResumeQueued = false,
        TeleportQueueMethod = "Unavailable",
        HopStatus = "Ready",
        BoughtPotara = false,
        AbilityBarrage = false,
        AbilityBusy = false,
        AbilityIndex = 0,
        AbilityNext = {},
        LastAbility = "None",
        AutoFarm = false,
        AttackMode = "Punch",
        TargetMode = "Power Ladder",
        SelectedNpc = "Saibaman",
        FarmHeight = 5,
        FarmDistance = 2,
        FarmInterval = 0.48,
        MultiHitCount = 1,
        HoldFarmPosition = false,
        HeldRoot = nil,
        AutoCharge = true,
        ChargeBelow = 25,
        ChargeUntil = 90,
        Charging = false,
        AutoTransform = false,
        TransformMode = "Ascend",
        StopLowHealth = true,
        LowHealthPercent = 25,
        RecoveringHealth = false,
        AntiAfk = true,
        NoClip = true,
        WalkSpeedEnabled = false,
        WalkSpeed = 32,
        Target = nil,
        LastAttack = 0,
        LastBlast = 0,
        LastTransform = 0,
        PunchIndex = 0,
        BlastBusy = false,
        Phase = "Idle",
        LastError = "None",
        LastTargetHealth = 0,
    }

    local punchKeys = {"q", "e", "r", "t"}
    local damageAbilities = {
        {Name = "Spirit", Display = "Spirit Bomb", Energy = 50, FallbackCooldown = 25, GainScore = 400},
        {Name = "Kamehameha", Display = "Kamehameha", Energy = 20, FallbackCooldown = 3, GainScore = 50},
        {Name = "SpecialBeam", Display = "Special Beam Cannon", Energy = 40, FallbackCooldown = 10, GainScore = 25},
        {Name = "EnergyWave", Display = "Energy Wave", Energy = 10, FallbackCooldown = 1, GainScore = 25},
        {Name = "Masenko", Display = "Masenko", Energy = 15, FallbackCooldown = 25, GainScore = 1},
    }
    local teleportTargets = {
        ["City"] = "cityIT",
        ["Kame House"] = "kameIT",
        ["The Lookout"] = "lookoutTP",
        ["King Kai"] = "otherworldPortal",
        ["Wilderness"] = "desertIT",
        ["Namek"] = "namekTP",
        ["Gravity Machine"] = "gravityMachine",
    }

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 4)
    end

    local function getCharacter()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
        return character, humanoid, root
    end

    local function getStatsModel(player)
        return (player or LocalPlayer):FindFirstChild("statsModel")
    end

    local function getEnergy()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local statsGui = playerGui and playerGui:FindFirstChild("stats")
        local energy = statsGui and statsGui:FindFirstChild("energy")
        return energy and tonumber(energy.Value) or nil
    end

    local function getBasePower(statsModel)
        statsModel = statsModel or getStatsModel()
        local power = statsModel and statsModel:FindFirstChild("PL")
        local multiplier = statsModel and statsModel:FindFirstChild("mult")
        return power and power.Value / math.max(1, multiplier and multiplier.Value or 1) or 0
    end

    local function aliveNpc(model)
        if not model or not model:IsA("Model") then
            return false
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
    end

    local function npcOptions()
        local names = {}
        local seen = {}
        local folder = workspace:FindFirstChild("NPCS")
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if aliveNpc(model) and not seen[model.Name] then
                    seen[model.Name] = true
                    names[#names + 1] = model.Name
                end
            end
        end
        table.sort(names)
        return names
    end

    local function npcPower(model)
        local value = model and model:FindFirstChild("Powerlevel")
        return value and tonumber(value.Value) or 0
    end

    local function npcDefense(model)
        local value = model and model:FindFirstChild("Defense")
        return value and tonumber(value.Value) or 0
    end

    local function selectNpc()
        local folder = workspace:FindFirstChild("NPCS")
        local _, _, localRoot = getCharacter()
        if not folder or not localRoot then
            return nil
        end

        local candidates = {}
        local statsModel = getStatsModel()
        local physical = statsModel and statsModel:FindFirstChild("phys")
        local physicalLevel = physical and tonumber(physical.Value) or 1
        local ladderLimit = math.max(2.5, physicalLevel * 1.5)
        for _, model in ipairs(folder:GetChildren()) do
            if aliveNpc(model) then
                if state.TargetMode == "Power Ladder" and npcDefense(model) <= ladderLimit then
                    candidates[#candidates + 1] = model
                elseif state.TargetMode ~= "Selected" and state.TargetMode ~= "Power Ladder" then
                    candidates[#candidates + 1] = model
                elseif state.TargetMode == "Selected" and model.Name == state.SelectedNpc then
                    candidates[#candidates + 1] = model
                end
            end
        end
        if #candidates == 0 and state.TargetMode == "Selected" then
            for _, model in ipairs(folder:GetChildren()) do
                if aliveNpc(model) then
                    candidates[#candidates + 1] = model
                end
            end
        end

        table.sort(candidates, function(a, b)
            if state.TargetMode == "Power Ladder" then
                return npcDefense(a) > npcDefense(b)
            elseif state.TargetMode == "Strongest" then
                return npcPower(a) > npcPower(b)
            end
            local aRoot = a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("Torso")
            local bRoot = b:FindFirstChild("HumanoidRootPart") or b:FindFirstChild("Torso")
            return (localRoot.Position - aRoot.Position).Magnitude < (localRoot.Position - bRoot.Position).Magnitude
        end)
        return candidates[1]
    end

    local function stopCharging()
        if state.Charging then
            pcall(function()
                ChargeRemote:FireServer("Stop")
            end)
        end
        state.Charging = false
    end

    local function updateCharge()
        if not state.AutoCharge then
            stopCharging()
            return false
        end
        local energy = getEnergy()
        if energy == nil then
            return false
        end
        if not state.Charging and energy <= state.ChargeBelow then
            state.Charging = true
            ChargeRemote:FireServer("Start")
        elseif state.Charging and energy >= state.ChargeUntil then
            stopCharging()
        end
        return state.Charging
    end

    local function releaseFarmPosition()
        local heldRoot = state.HeldRoot
        if heldRoot and heldRoot.Parent then
            heldRoot.Anchored = false
        end
        state.HeldRoot = nil
    end

    local function holdRootAt(root, targetCFrame)
        if state.HeldRoot and state.HeldRoot ~= root then
            releaseFarmPosition()
        end
        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if state.HoldFarmPosition then
            root.Anchored = true
            state.HeldRoot = root
        else
            root.Anchored = false
            state.HeldRoot = nil
        end
    end

    local function positionAtNpc(target)
        local _, humanoid, root = getCharacter()
        local targetRoot = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
        if not humanoid or humanoid.Health <= 0 or not root or not targetRoot then
            return false
        end
        holdRootAt(root, targetRoot.CFrame * CFrame.new(0, state.FarmHeight, state.FarmDistance))
        return true
    end

    local function punchTarget(target)
        state.PunchIndex = state.PunchIndex % #punchKeys + 1
        PunchRemote:FireServer("Punch", punchKeys[state.PunchIndex])
        task.wait(0.02)
        for _ = 1, state.MultiHitCount do
            if not aliveNpc(target) then
                break
            end
            DamageRemote:FireServer("Punch", target)
            task.wait(0.01)
        end
    end

    local function blastTarget(target)
        if state.BlastBusy or os.clock() - state.LastBlast < 0.7 then
            return
        end
        local targetRoot = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
        if not targetRoot then
            return
        end
        state.BlastBusy = true
        state.LastBlast = os.clock()
        task.spawn(function()
            local ok, errorMessage = pcall(function()
                BlastRemote:InvokeServer("EnergyWave", targetRoot.Position)
            end)
            if not ok then
                state.LastError = tostring(errorMessage)
            end
            state.BlastBusy = false
        end)
    end

    local function attackTarget(target)
        if state.AutoOPRoute then
            punchTarget(target)
        elseif state.AttackMode == "Hybrid" then
            punchTarget(target)
            blastTarget(target)
        elseif state.AttackMode == "Energy Wave" then
            blastTarget(target)
        else
            punchTarget(target)
        end
    end

    local function shouldPauseForHealth()
        if not state.StopLowHealth then
            state.RecoveringHealth = false
            return false
        end
        local _, humanoid = getCharacter()
        if not humanoid or humanoid.MaxHealth <= 0 then
            state.RecoveringHealth = true
            return true
        end
        local healthPercent = humanoid.Health / humanoid.MaxHealth * 100
        if healthPercent <= state.LowHealthPercent then
            state.RecoveringHealth = true
        elseif state.RecoveringHealth and healthPercent >= 85 then
            state.RecoveringHealth = false
        end
        return state.RecoveringHealth
    end

    local function stepFarm()
        if not state.AutoFarm then
            state.Target = nil
            state.Phase = "Idle"
            if not state.AutoOPRoute then
                stopCharging()
            end
            releaseFarmPosition()
            return
        end
        if shouldPauseForHealth() then
            local _, humanoid, root = getCharacter()
            if humanoid and humanoid.Health > 0 and root then
                if state.Phase ~= "Paused: recovering health" then
                    holdRootAt(root, root.CFrame * CFrame.new(0, 50, 0))
                end
            else
                releaseFarmPosition()
            end
            state.Phase = "Paused: recovering health"
            stopCharging()
            return
        end
        local target = state.Target
        if not aliveNpc(target) then
            target = selectNpc()
            state.Target = target
        end
        if not target then
            state.Phase = "Waiting for NPC"
            releaseFarmPosition()
            return
        end

        if updateCharge() then
            state.Phase = "Charging energy"
            positionAtNpc(target)
            return
        end
        if not positionAtNpc(target) then
            state.Phase = "Waiting for character"
            return
        end
        if os.clock() - state.LastAttack >= state.FarmInterval then
            state.LastAttack = os.clock()
            state.Phase = "Attacking " .. target.Name
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            state.LastTargetHealth = humanoid and humanoid.Health or 0
            attackTarget(target)
        end
    end

    local function stepTransform()
        if not state.AutoTransform then
            return
        end
        if os.clock() - state.LastTransform < 1.1 then
            return
        end
        state.LastTransform = os.clock()
        local statsModel = getStatsModel()
        local multiplier = statsModel and statsModel:FindFirstChild("mult")
        if multiplier and multiplier.Value > 1 then
            return
        end
        TransformRemote:FireServer(state.TransformMode)
    end

    local function teleportTo(locationName)
        local trainers = workspace:FindFirstChild("Trainers")
        local targetName = teleportTargets[locationName]
        local target = trainers and targetName and trainers:FindFirstChild(targetName)
        local _, humanoid, root = getCharacter()
        if not target or not root or not humanoid or humanoid.Health <= 0 then
            return false, "Location or character unavailable"
        end
        TrainRemote:FireServer("Reset")
        root.CFrame = target.CFrame * CFrame.new(0, 4, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        return true, "Teleported to " .. locationName
    end

    local function touchServerPart(part)
        local _, humanoid, root = getCharacter()
        if not part or not root or not humanoid or humanoid.Health <= 0 then
            return false
        end
        if type(firetouchinterest) == "function" then
            local wasAnchored = root.Anchored
            root.Anchored = false
            task.wait(0.04)
            firetouchinterest(root, part, 0)
            task.wait(0.12)
            firetouchinterest(root, part, 1)
            task.wait(0.08)
            root.Anchored = wasAnchored
            return true
        end
        local previous = root.CFrame
        local wasAnchored = root.Anchored
        root.Anchored = false
        root.CFrame = part.CFrame * CFrame.new(0, 2, 0)
        task.wait(0.25)
        root.CFrame = previous
        root.Anchored = wasAnchored
        return true
    end

    local function gravityEnabled()
        local statsModel = getStatsModel()
        local gravity = statsModel and statsModel:FindFirstChild("grav")
        return gravity and gravity.Value == true
    end

    local function enablePersistentGravity()
        local capsule = workspace:FindFirstChild("C")
        capsule = capsule and capsule:FindFirstChild("capsule corp spaceship")
        local trigger = capsule and capsule:FindFirstChild("addGrav")
        if not trigger then
            return false, "Spaceship gravity trigger is unavailable"
        end
        local ok = touchServerPart(trigger)
        task.wait(0.15)
        return ok and gravityEnabled(), gravityEnabled() and "Persistent gravity multiplier enabled" or "Need Physical 15 for spaceship gravity"
    end

    local function findTrainingWeight()
        local character = LocalPlayer.Character
        return (character and character:FindFirstChild("Training Weight"))
            or LocalPlayer.Backpack:FindFirstChild("Training Weight")
    end

    local function ensureTrainingWeight()
        local tool = findTrainingWeight()
        if tool then
            return tool
        end
        local statsModel = getStatsModel()
        local zeni = statsModel and statsModel:FindFirstChild("zeni")
        if zeni and zeni.Value >= 100 and os.clock() - state.LastShopAttempt >= 1 then
            state.LastShopAttempt = os.clock()
            ShopRemote:FireServer("weight")
        end
        return nil
    end

    local function stepWeightTraining()
        if not state.AutoWeightTraining and not state.AutoOPRoute then
            return
        end
        if os.clock() - state.LastWeightActivation < state.WeightInterval then
            return
        end
        state.LastWeightActivation = os.clock()
        local character, humanoid = getCharacter()
        if not character or not humanoid or humanoid.Health <= 0 then
            state.RoutePhase = "Waiting for respawn"
            return
        end
        local tool = ensureTrainingWeight()
        if not tool then
            state.RoutePhase = "Buying Training Weight"
            return
        end
        if tool.Parent ~= character then
            humanoid:EquipTool(tool)
        end
        tool:Activate()
        state.RoutePhase = gravityEnabled() and "6-8x remote gravity weight training" or "Normal weight training"
    end

    local function stepGravityBoost()
        if not state.PersistentGravity and not state.AutoOPRoute then
            return
        end
        if gravityEnabled() or os.clock() - state.LastGravityAttempt < 2 then
            return
        end
        local statsModel = getStatsModel()
        local physical = statsModel and statsModel:FindFirstChild("phys")
        if not physical or physical.Value < 15 then
            state.RoutePhase = "Building Physical 15 for spaceship gravity"
            return
        end
        state.LastGravityAttempt = os.clock()
        local ok, message = enablePersistentGravity()
        state.RoutePhase = message
        if not ok then
            state.LastError = message
        end
    end

    local function stepMilestones()
        if not state.AutoMilestones and not state.AutoOPRoute then
            return
        end
        if os.clock() - state.LastMilestoneAttempt < 1.5 then
            return
        end
        state.LastMilestoneAttempt = os.clock()
        local statsModel = getStatsModel()
        if not statsModel then
            return
        end
        local physical = statsModel.phys.Value
        local ki = statsModel.ki.Value
        local agility = statsModel.agi.Value
        local requests = {
            {"kame", ki >= 10 and agility >= 10, "Roshi"},
            {"korin", ki >= 15 and agility >= 15, "Korin"},
            {"kami", ki >= 15 and agility >= 15, "Kami"},
            {"kai", physical >= 5 and ki >= 20 and agility >= 25, "King Kai"},
        }
        for _, request in ipairs(requests) do
            local flag = statsModel:FindFirstChild(request[1])
            if request[2] and flag and not flag.Value then
                TrainRemote:FireServer(request[3])
                state.RoutePhase = "Unlocking trainer: " .. request[3]
                return
            end
        end
    end

    local function stepProgressionShop(force)
        if not force and not state.AutoProgressionShop and not state.AutoOPRoute then
            return
        end
        if state.ShopBusy or os.clock() - state.LastShopAttempt < 0.75 then
            return
        end
        local statsModel = getStatsModel()
        if not statsModel then
            return
        end
        if not findTrainingWeight() and statsModel.zeni.Value >= 100 then
            state.LastShopAttempt = os.clock()
            ShopRemote:FireServer("weight")
            state.RoutePhase = "Buying Training Weight"
        elseif statsModel.zeni.Value >= 5000 then
            state.ShopBusy = true
            state.LastShopAttempt = os.clock()
            task.spawn(function()
                local beforeZeni = statsModel.zeni.Value
                local beforePower = getBasePower(statsModel)
                ShopRemote:FireServer("stats")
                task.wait(0.8)
                local spent = beforeZeni - statsModel.zeni.Value
                local gained = getBasePower(statsModel) - beforePower
                if spent >= 5000 and gained > 0 then
                    state.CapsulesBought += 1
                    environment.VORDBLPCapsulesBought = state.CapsulesBought
                    state.RoutePhase = string.format("Capsule #%d: +%d base power", state.CapsulesBought, math.floor(gained))
                else
                    state.LastError = "Stat capsule purchase was not credited"
                end
                state.ShopBusy = false
            end)
        elseif not state.BoughtPotara and statsModel.PL.Value >= 15000000 and statsModel.zeni.Value >= 50000 then
            state.LastShopAttempt = os.clock()
            ShopRemote:FireServer("potara")
            state.BoughtPotara = true
            state.RoutePhase = "Buying Potara Earrings"
        end
    end

    local function summonShenron()
        local island = workspace:FindFirstChild("KI")
        local summoner = island and island:FindFirstChild("summoner")
        if not summoner then
            return false, "Shenron summoner is unavailable"
        end
        local ok = touchServerPart(summoner)
        task.wait(0.2)
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local wishGui = playerGui and playerGui:FindFirstChild("wish")
        local frame = wishGui and wishGui:FindFirstChild("Frame")
        return ok and frame and frame.Visible, frame and frame.Visible and "Shenron summoned" or "Shenron is not ready"
    end

    local function performWish(wishName)
        local ok, message = summonShenron()
        if not ok then
            return false, message
        end
        WishRemote:FireServer(wishName)
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local wishGui = playerGui and playerGui:FindFirstChild("wish")
        local frame = wishGui and wishGui:FindFirstChild("Frame")
        if frame then
            frame.Visible = false
        end
        return true, "Wished for " .. wishName
    end

    local function stepAutoShenron()
        if not state.AutoShenron then
            return
        end
        if os.clock() - state.LastWishAttempt < 30 then
            return
        end
        state.LastWishAttempt = os.clock()
        local statsModel = getStatsModel()
        if not statsModel then
            return
        end
        local powerClaimed = statsModel:FindFirstChild("shenron")
        local wishName = state.PreferredWish
        if wishName == "Power First" then
            wishName = powerClaimed and powerClaimed.Value and "Zeni" or "Power"
        end
        local ok, message = performWish(wishName)
        if ok then
            state.RoutePhase = message
        end
    end

    local function stepAbilityBarrage()
        if not state.AbilityBarrage and not state.AutoOPRoute then
            return
        end
        if state.AbilityBusy then
            return
        end
        local character = LocalPlayer.Character
        local usingMove = character and character:FindFirstChild("UsingMove")
        if not character or (usingMove and usingMove.Value) then
            return
        end
        local target = state.Target
        if not aliveNpc(target) then
            target = selectNpc()
        end
        if not aliveNpc(target) then
            return
        end
        local targetRoot = target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart")
        local energy = getEnergy() or 0
        if not targetRoot then
            return
        end
        local now = os.clock()
        local selected
        for index, ability in ipairs(damageAbilities) do
            if energy >= ability.Energy and now >= (state.AbilityNext[ability.Name] or 0)
                and (not selected or ability.GainScore > selected.GainScore) then
                selected = ability
                state.AbilityIndex = index
            end
        end
        if not selected then
            return
        end
        state.AbilityBusy = true
        state.LastAbility = selected.Display
        task.spawn(function()
            local ok, cooldown = pcall(function()
                return BlastRemote:InvokeServer(selected.Name, targetRoot.Position)
            end)
            local delaySeconds = tonumber(cooldown) or selected.FallbackCooldown
            state.AbilityNext[selected.Name] = os.clock() + math.max(0.5, delaySeconds)
            if not ok then
                state.LastError = tostring(cooldown)
                state.AbilityNext[selected.Name] = os.clock() + 2
            end
            state.AbilityBusy = false
        end)
    end

    local function queueFunction()
        if type(queue_on_teleport) == "function" then
            return queue_on_teleport, "queue_on_teleport"
        end
        if type(queueonteleport) == "function" then
            return queueonteleport, "queueonteleport"
        end
        if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
            return syn.queue_on_teleport, "syn.queue_on_teleport"
        end
        if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
            return fluxus.queue_on_teleport, "fluxus.queue_on_teleport"
        end
        return nil, "Unavailable"
    end

    local function queueFastRouteResume()
        if state.TeleportResumeQueued then
            return true
        end
        local queue, method = queueFunction()
        state.TeleportQueueMethod = method
        if type(queue) ~= "function" then
            return false, "This executor does not expose a teleport queue"
        end

        local visitedEntries = {}
        for jobId, seen in pairs(visitedServers) do
            if seen and type(jobId) == "string" and #visitedEntries < 75 then
                visitedEntries[#visitedEntries + 1] = string.format("[%q]=true", jobId)
            end
        end
        table.sort(visitedEntries)
        local loaderUrl = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/loader.lua?dblphop="
            .. tostring(os.time())
        local payload = table.concat({
            "repeat task.wait() until game:IsLoaded()",
            "local p=game:GetService(\"Players\").LocalPlayer",
            "repeat task.wait(0.1) until p:FindFirstChild(\"statsModel\") and p.statsModel:FindFirstChild(\"loaded\") and p.statsModel.loaded.Value",
            "local e=type(getgenv)==\"function\" and getgenv() or _G",
            "e.VORDBLPResumeFastRoute=true",
            "e.VORDBLPTargetBasePower=" .. tostring(state.TargetBasePower),
            "e.VORDBLPCapsulesBought=" .. tostring(state.CapsulesBought),
            "e.VORDBLPZeniClaims=" .. tostring(state.ZeniClaims),
            "e.VORDBLPVisitedServers={" .. table.concat(visitedEntries, ",") .. "}",
            "loadstring(game:HttpGet(" .. string.format("%q", loaderUrl) .. "))()",
        }, "\n")
        local ok, message = pcall(queue, payload)
        if not ok then
            return false, tostring(message)
        end
        state.TeleportResumeQueued = true
        state.TeleportQueueMethod = method
        return true
    end

    local function openFreshServers()
        local servers = {}
        local cursor
        for _ = 1, 3 do
            local url = "https://games.roblox.com/v1/games/"
                .. tostring(game.PlaceId)
                .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor and cursor ~= "" then
                url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
            end
            local data = HttpService:JSONDecode(game:HttpGet(url))
            for _, server in ipairs(data.data or {}) do
                if server.id ~= game.JobId
                    and server.playing < server.maxPlayers
                    and not visitedServers[server.id] then
                    servers[#servers + 1] = server
                end
            end
            cursor = data.nextPageCursor
            if #servers > 0 or not cursor then
                break
            end
        end
        return servers
    end

    local function hopFreshServer(reason)
        if state.HopBusy or os.clock() - state.LastHopAttempt < 15 then
            return false
        end
        state.HopBusy = true
        state.LastHopAttempt = os.clock()
        local ok, servers = pcall(openFreshServers)
        if not ok or #servers == 0 then
            state.HopBusy = false
            state.HopStatus = "No unused public server; checking again"
            state.LastError = ok and "None" or tostring(servers)
            return false
        end
        table.sort(servers, function(a, b)
            local aPlayers = tonumber(a.playing) or math.huge
            local bPlayers = tonumber(b.playing) or math.huge
            if aPlayers == bPlayers then
                return tostring(a.id) < tostring(b.id)
            end
            return aPlayers < bPlayers
        end)
        local selected = servers[1]
        visitedServers[game.JobId] = true
        visitedServers[selected.id] = true
        environment.VORDBLPVisitedServers = visitedServers
        local queued, queueError = queueFastRouteResume()
        if not queued then
            visitedServers[selected.id] = nil
            state.HopBusy = false
            state.HopStatus = "Auto-resume unavailable"
            state.LastError = "Server hop: " .. tostring(queueError)
            return false
        end
        state.HopStatus = "Hopping: " .. tostring(reason or "fresh Shenron session")
        state.RoutePhase = state.HopStatus
        TeleportService:TeleportToPlaceInstance(game.PlaceId, selected.id, LocalPlayer)
        return true
    end

    local function claimServerZeni()
        if state.ServerClaimBusy or state.ServerClaimResolved then
            return
        end
        state.ServerClaimBusy = true
        task.spawn(function()
            local statsModel = getStatsModel()
            local loaded = statsModel and statsModel:FindFirstChild("loaded")
            local deadline = os.clock() + 15
            while state.Alive and (not statsModel or not loaded or not loaded.Value) and os.clock() < deadline do
                task.wait(0.1)
                statsModel = getStatsModel()
                loaded = statsModel and statsModel:FindFirstChild("loaded")
            end
            if not statsModel or not loaded or not loaded.Value then
                state.ServerClaimBusy = false
                state.LastError = "Timed out waiting for saved stats"
                return
            end

            local beforeZeni = statsModel.zeni.Value
            state.ServerClaimAttempts += 1
            local island = workspace:FindFirstChild("KI")
            local summoner = island and island:FindFirstChild("summoner")
            if not summoner or not touchServerPart(summoner) then
                state.ServerClaimBusy = false
                state.LastError = "Shenron summoner is unavailable"
                return
            end
            task.wait(0.25)
            for _ = 1, 5 do
                WishRemote:FireServer("Zeni")
            end
            task.wait(1.25)
            local gained = math.max(0, statsModel.zeni.Value - beforeZeni)
            state.ServerClaimDelta = gained
            state.ServerClaimBusy = false
            if gained >= 2500 then
                state.ServerClaimResolved = true
                state.ZeniClaims += 1
                environment.VORDBLPZeniClaims = state.ZeniClaims
                visitedServers[game.JobId] = true
                environment.VORDBLPVisitedServers = visitedServers
                state.RoutePhase = string.format("Fresh-server Zeni claim #%d: +%d", state.ZeniClaims, gained)
            elseif state.ServerClaimAttempts >= 2 then
                state.ServerClaimResolved = true
                visitedServers[game.JobId] = true
                environment.VORDBLPVisitedServers = visitedServers
                state.RoutePhase = "Shenron already consumed here"
            else
                state.RoutePhase = "Retrying Shenron claim once"
            end
        end)
    end

    local function stepCapsuleRoute()
        if not state.AutoOPRoute then
            return
        end
        local statsModel = getStatsModel()
        local loaded = statsModel and statsModel:FindFirstChild("loaded")
        if not statsModel or not loaded or not loaded.Value then
            state.RoutePhase = "Waiting for saved stats"
            return
        end
        local basePower = getBasePower(statsModel)
        if state.TargetBasePower > 0 and basePower >= state.TargetBasePower then
            state.AutoOPRoute = false
            environment.VORDBLPResumeFastRoute = false
            state.RoutePhase = "Target reached"
            stopCharging()
            notify("Fastest OP Route", "Target base power reached", 5)
            return
        end
        if state.ShopBusy or statsModel.zeni.Value >= 5000 then
            return
        end
        if not state.ServerClaimResolved then
            claimServerZeni()
            return
        end
        hopFreshServer(state.ServerClaimDelta >= 2500 and "claim banked" or "claim already used")
    end

    local function stepOPRoute()
        if not state.AutoOPRoute then
            return
        end
        stepGravityBoost()
        stepWeightTraining()
        stepMilestones()
        stepProgressionShop()
        updateCharge()
        stepCapsuleRoute()
    end

    local routePhaseLabel = PowerProgressSection:AddLabel("Route: Ready")
    local routeBoostLabel = PowerProgressSection:AddLabel("Gravity boost: --")
    local routeGainLabel = PowerProgressSection:AddLabel("Power gained: 0")
    local routeTimeLabel = PowerProgressSection:AddLabel("Elapsed: 00:00")
    local routeClaimLabel = PowerProgressSection:AddLabel("Zeni claims: 0 | Capsules: 0")
    local routeHopLabel = PowerProgressSection:AddLabel("Server route: Ready")
    PowerProgressSection:AddParagraph({
        Title = "🧪 Live-tested route",
        Content = "A fresh server pays 2,500 Zeni. Every 5,000-Zeni stat capsule gave about 100,350 base power in live testing. Spirit Bomb adds about 10,000 Ki EXP per accepted cast.",
    })

    local autoOPToggle
    autoOPToggle = PowerRouteSection:AddToggle({
        Name = "🐉 Auto Zeni Server Hop + Capsules",
        Description = "Claims 2,500 Zeni per unused server, transfers VOR Hub, and buys every 5,000-Zeni stat capsule",
        Flag = "dblp_auto_op_route",
        Default = state.AutoOPRoute,
        Callback = function(enabled)
            if not enabled and resumeFastRoute and os.clock() < resumeGuardUntil then
                task.defer(function()
                    if autoOPToggle and type(autoOPToggle.Set) == "function" then
                        autoOPToggle:Set(true, true)
                    end
                end)
                return
            end
            resumeFastRoute = false
            state.AutoOPRoute = enabled
            environment.VORDBLPResumeFastRoute = enabled
            state.LastAttack = 0
            state.LastWeightActivation = 0
            if enabled then
                local statsModel = getStatsModel()
                state.RouteStartedAt = os.clock()
                state.RouteStartPL = getBasePower(statsModel)
                state.RouteStartPhysical = statsModel and statsModel.phys.Value or 0
                state.ServerClaimBusy = false
                state.ServerClaimResolved = false
                state.ServerClaimAttempts = 0
                state.ServerClaimDelta = 0
                state.HopBusy = false
                state.LastHopAttempt = 0
                state.RoutePhase = "Starting verified capsule route"
            else
                state.RoutePhase = "Stopped"
                state.HopBusy = false
                state.Target = nil
                stopCharging()
                releaseFarmPosition()
            end
        end,
    })
    PowerRouteSection:AddDropdown({
        Name = "Target Base Power",
        Options = {"10 Million", "100 Million", "1 Billion", "Endless"},
        Default = state.TargetBasePower == 0 and "Endless"
            or state.TargetBasePower >= 1000000000 and "1 Billion"
            or state.TargetBasePower >= 100000000 and "100 Million"
            or "10 Million",
        Callback = function(value)
            local targets = {
                ["10 Million"] = 10000000,
                ["100 Million"] = 100000000,
                ["1 Billion"] = 1000000000,
                ["Endless"] = 0,
            }
            state.TargetBasePower = targets[value] or 10000000
            environment.VORDBLPTargetBasePower = state.TargetBasePower
        end,
    })
    PowerRouteSection:AddButton({
        Name = "Claim Zeni + Buy Capsule Now",
        Callback = function()
            state.ServerClaimBusy = false
            state.ServerClaimResolved = false
            state.ServerClaimAttempts = 0
            state.ServerClaimDelta = 0
            claimServerZeni()
            task.delay(2, function()
                stepProgressionShop(true)
                task.wait(1)
                stepProgressionShop(true)
            end)
        end,
    })
    PowerRouteSection:AddButton({
        Name = "Hop To Fresh Public Server",
        Callback = function()
            state.LastHopAttempt = 0
            hopFreshServer("manual fresh-session request")
        end,
    })
    PowerRouteSection:AddToggle({
        Name = "🏋️ Efficient Gravity Weight Training",
        Description = "Uses the fastest measured server-credited cadence without flooding rejected reps",
        Flag = "dblp_auto_weight_training",
        Default = false,
        Callback = function(enabled)
            state.AutoWeightTraining = enabled
            state.LastWeightActivation = 0
        end,
    })
    PowerRouteSection:AddToggle({
        Name = "☄️ Ability Barrage",
        Description = "Prioritizes Spirit Bomb's measured 10,000 Ki EXP, then uses the best ready fallback",
        Flag = "dblp_ability_barrage",
        Default = false,
        Callback = function(enabled)
            state.AbilityBarrage = enabled
            state.AbilityBusy = false
        end,
    })
    PowerRouteSection:AddToggle({
        Name = "🧙 Auto Trainer Milestones",
        Default = false,
        Flag = "dblp_auto_milestones",
        Callback = function(enabled)
            state.AutoMilestones = enabled
        end,
    })
    PowerRouteSection:AddToggle({
        Name = "🛒 Auto Progression Purchases",
        Description = "Buys the Training Weight and every affordable 5,000-Zeni stat capsule",
        Default = false,
        Flag = "dblp_auto_progression_shop",
        Callback = function(enabled)
            state.AutoProgressionShop = enabled
        end,
    })

    PowerBoostSection:AddToggle({
        Name = "🛰️ Persistent Gravity Multiplier",
        Description = "Keeps the spaceship/chamber multiplier active while training anywhere",
        Default = false,
        Flag = "dblp_persistent_gravity",
        Callback = function(enabled)
            state.PersistentGravity = enabled
            state.LastGravityAttempt = 0
        end,
    })
    PowerBoostSection:AddButton({
        Name = "⚡ Enable Gravity Boost Now",
        Callback = function()
            local ok, message = enablePersistentGravity()
            notify("Gravity Training", message, ok and 3 or 5)
        end,
    })
    PowerBoostSection:AddDropdown({
        Name = "🐉 Automatic Shenron Wish",
        Options = {"Power First", "Zeni", "Food", "Senzu"},
        Default = state.PreferredWish,
        Callback = function(value)
            state.PreferredWish = value or "Power First"
        end,
    })
    PowerBoostSection:AddToggle({
        Name = "🐲 Auto Summon Shenron",
        Description = "Current-server wish only. The Fastest OP Route handles fresh-server Zeni automatically",
        Default = false,
        Flag = "dblp_auto_shenron",
        Callback = function(enabled)
            state.AutoShenron = enabled
            state.LastWishAttempt = 0
        end,
    })

    local targetDropdown
    targetDropdown = FarmSection:AddDropdown({
        Name = "🎯 NPC Target",
        Options = npcOptions(),
        Default = state.SelectedNpc,
        Callback = function(value)
            state.SelectedNpc = value or "Saibaman"
            state.Target = nil
        end,
    })
    FarmSection:AddDropdown({
        Name = "🧠 Target Mode",
        Options = {"Power Ladder", "Selected", "Nearest", "Strongest"},
        Default = state.TargetMode,
        Callback = function(value)
            state.TargetMode = value or "Selected"
            state.Target = nil
        end,
    })
    FarmSection:AddDropdown({
        Name = "💥 Attack Method",
        Options = {"Punch", "Energy Wave", "Hybrid"},
        Default = state.AttackMode,
        Callback = function(value)
            state.AttackMode = value or "Punch"
        end,
    })
    FarmSection:AddToggle({
        Name = "🥊 Auto Farm NPCs",
        Description = "Native punches require real contact. Ability Barrage is the reliable ranged training path",
        Flag = "dblp_auto_farm",
        Default = false,
        Callback = function(enabled)
            state.AutoFarm = enabled
            state.LastAttack = 0
            if not enabled then
                stopCharging()
                state.Target = nil
                releaseFarmPosition()
            end
        end,
    })
    FarmSection:AddButton({
        Name = "🔄 Refresh NPC List",
        Callback = function()
            targetDropdown:SetOptions(npcOptions(), true)
        end,
    })
    FarmSection:AddSlider({
        Name = "Attack Interval",
        Min = 0.03,
        Max = 0.75,
        Step = 0.01,
        Default = state.FarmInterval,
        Flag = "dblp_attack_interval",
        Callback = function(value)
            state.FarmInterval = value
        end,
    })
    FarmSection:AddSlider({
        Name = "⚔️ Multi-Hit Burst",
        Description = "Sends extra credited hit attempts per native punch; the server rejects wasteful overflow",
        Min = 1,
        Max = 6,
        Step = 1,
        Default = state.MultiHitCount,
        Flag = "dblp_multi_hit_count",
        Callback = function(value)
            state.MultiHitCount = math.floor(value)
        end,
    })

    FarmSafetySection:AddSlider({
        Name = "⬆️ Height Above NPC",
        Min = 2,
        Max = 20,
        Step = 0.5,
        Default = state.FarmHeight,
        Flag = "dblp_farm_height",
        Callback = function(value)
            state.FarmHeight = value
        end,
    })
    FarmSafetySection:AddSlider({
        Name = "Distance From NPC",
        Min = 0,
        Max = 10,
        Step = 0.5,
        Default = state.FarmDistance,
        Flag = "dblp_farm_distance",
        Callback = function(value)
            state.FarmDistance = value
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "🛡️ Hold Safe Aerial Position",
        Description = "Prevents gravity from dropping you into the NPC between hits",
        Default = state.HoldFarmPosition,
        Flag = "dblp_hold_farm_position",
        Callback = function(enabled)
            state.HoldFarmPosition = enabled
            if not enabled then
                releaseFarmPosition()
            end
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "❤️ Pause On Low Health",
        Default = true,
        Flag = "dblp_pause_low_health",
        Callback = function(enabled)
            state.StopLowHealth = enabled
        end,
    })
    FarmSafetySection:AddSlider({
        Name = "Low Health Percent",
        Min = 5,
        Max = 75,
        Step = 5,
        Default = state.LowHealthPercent,
        Flag = "dblp_low_health_percent",
        Callback = function(value)
            state.LowHealthPercent = value
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "👻 No Collision While Farming",
        Default = true,
        Flag = "dblp_farm_noclip",
        Callback = function(enabled)
            state.NoClip = enabled
        end,
    })

    local farmPhaseLabel = FarmStatusSection:AddLabel("Phase: Idle")
    local farmTargetLabel = FarmStatusSection:AddLabel("Target: None")
    local farmEnergyLabel = FarmStatusSection:AddLabel("Energy: --")
    local farmAbilityLabel = FarmStatusSection:AddLabel("Ability: None")
    FarmStatusSection:AddLabel("Verified: native Punch deals server damage only at valid range.")

    StatTrainingSection:AddToggle({
        Name = "⚡ Auto Charge Energy",
        Description = "Charges below the low threshold and resumes at the high threshold",
        Default = true,
        Flag = "dblp_auto_charge",
        Callback = function(enabled)
            state.AutoCharge = enabled
            if not enabled then
                stopCharging()
            end
        end,
    })
    StatTrainingSection:AddSlider({
        Name = "Charge Below",
        Min = 0,
        Max = 80,
        Step = 5,
        Default = state.ChargeBelow,
        Flag = "dblp_charge_below",
        Callback = function(value)
            state.ChargeBelow = math.min(value, state.ChargeUntil - 5)
        end,
    })
    StatTrainingSection:AddSlider({
        Name = "Charge Until",
        Min = 20,
        Max = 100,
        Step = 5,
        Default = state.ChargeUntil,
        Flag = "dblp_charge_until",
        Callback = function(value)
            state.ChargeUntil = math.max(value, state.ChargeBelow + 5)
        end,
    })
    StatTrainingSection:AddParagraph({
        Title = "🏋️ Training behavior",
        Content = "Training Weight builds Physical and Agility. Punch builds Physical and Defense. Energy Wave builds Ki Control. The full OP route combines all four instead of wasting thirty minutes on one stat.",
    })
    StatTrainingSection:AddButton({
        Name = "🏋️ Buy / Equip Training Weight",
        Callback = function()
            local tool = ensureTrainingWeight()
            local character, humanoid = getCharacter()
            if tool and character and humanoid and tool.Parent ~= character then
                humanoid:EquipTool(tool)
            end
            notify("Training Weight", tool and "Equipped" or "Purchase requested", 3)
        end,
    })

    local trainerActions = {
        ["🥋 Train With Master Roshi"] = "Roshi",
        ["🐈 Train With Korin"] = "Korin",
        ["🟢 Train With Kami"] = "Kami",
        ["🪐 Train With King Kai"] = "King Kai",
    }
    for buttonName, action in pairs(trainerActions) do
        TrainerSection:AddButton({
            Name = buttonName,
            Callback = function()
                TrainRemote:FireServer(action)
            end,
        })
    end

    local shopActions = {
        ["🏋️ Buy Training Weight"] = "weight",
        ["🥋 Buy Weighted Clothing"] = "gi",
        ["💊 Buy Stat Capsule"] = "stats",
        ["💎 Buy Potara Earrings"] = "potara",
    }
    for buttonName, action in pairs(shopActions) do
        ShopSection:AddButton({
            Name = buttonName,
            Callback = function()
                ShopRemote:FireServer(action)
            end,
        })
    end

    TransformSection:AddDropdown({
        Name = "Automatic Form",
        Options = {"Ascend", "Kaioken"},
        Default = state.TransformMode,
        Callback = function(value)
            state.TransformMode = value or "Ascend"
        end,
    })
    TransformSection:AddToggle({
        Name = "Maintain Automatic Form",
        Default = false,
        Flag = "dblp_auto_transform",
        Callback = function(enabled)
            state.AutoTransform = enabled
        end,
    })
    TransformSection:AddButton({Name = "🔥 Ascend", Callback = function() TransformRemote:FireServer("Ascend") end})
    TransformSection:AddButton({Name = "⬇️ Descend", Callback = function() TransformRemote:FireServer("Descend") end})
    TransformSection:AddButton({Name = "🔴 Kaioken", Callback = function() TransformRemote:FireServer("Kaioken") end})
    for _, potaraName in ipairs({"potara", "potaraG", "potaraV"}) do
        TransformSection:AddButton({
            Name = "Use " .. potaraName,
            Callback = function()
                TransformRemote:FireServer("potara", potaraName)
            end,
        })
    end

    local skillActions = {
        ["Equip Korin Moves"] = "getKorin",
        ["Equip Roshi Moves"] = "getRoshi",
        ["Equip Kami Moves"] = "getKami",
        ["Equip King Kai Moves"] = "getKai",
        ["Equip Shenron Moves"] = "getShenron",
    }
    for buttonName, action in pairs(skillActions) do
        SkillSection:AddButton({
            Name = buttonName,
            Callback = function()
                TrainRemote:FireServer(action)
            end,
        })
    end

    for _, wishName in ipairs({"Power", "Zeni", "Food", "Senzu"}) do
        WishSection:AddButton({
            Name = "🐉 Summon + Wish For " .. wishName,
            Callback = function()
                local ok, message = performWish(wishName)
                notify("Shenron", message, ok and 3 or 5)
            end,
        })
    end

    for locationName in pairs(teleportTargets) do
        TeleportSection:AddButton({
            Name = locationName,
            Callback = function()
                local ok, message = teleportTo(locationName)
                notify("Travel", message, ok and 3 or 5)
            end,
        })
    end

    MovementSection:AddToggle({
        Name = "Walk Speed Override",
        Default = false,
        Flag = "dblp_walk_speed_enabled",
        Callback = function(enabled)
            state.WalkSpeedEnabled = enabled
        end,
    })
    MovementSection:AddSlider({
        Name = "Walk Speed",
        Min = 16,
        Max = 150,
        Step = 2,
        Default = state.WalkSpeed,
        Flag = "dblp_walk_speed",
        Callback = function(value)
            state.WalkSpeed = value
        end,
    })
    MovementSection:AddToggle({
        Name = "Anti AFK",
        Default = true,
        Flag = "dblp_anti_afk",
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })

    local statLabels = {}
    for _, statName in ipairs({"PL", "phys", "ki", "agi", "def", "zeni", "ssj", "kaio"}) do
        statLabels[statName] = LiveStatsSection:AddLabel(statName .. ": --")
    end
    local errorLabel = AdapterStatusSection:AddLabel("Last error: None")
    AdapterStatusSection:AddParagraph({
        Title = "✅ Runtime validation",
        Content = "Uses the game's native remotes and tools. Gravity, Training Weight gains, ability rewards, trainer requirements, stat capsules, Shenron claims, and server-session limits were measured live.",
    })

    if state.AutoOPRoute then
        local statsModel = getStatsModel()
        state.RouteStartedAt = os.clock()
        state.RouteStartPL = getBasePower(statsModel)
        state.RouteStartPhysical = statsModel and statsModel.phys.Value or 0
        state.RoutePhase = "Resumed after server transfer"
    end

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end
    end))

    track(RunService.Stepped:Connect(function()
        local character, humanoid = getCharacter()
        if character and state.AutoFarm and state.NoClip then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        if humanoid and state.WalkSpeedEnabled then
            humanoid.WalkSpeed = state.WalkSpeed
        end
    end))

    task.spawn(function()
        while state.Alive do
            local ok, errorMessage = pcall(function()
                stepOPRoute()
                stepAutoShenron()
                stepFarm()
                stepAbilityBarrage()
                stepTransform()
            end)
            if not ok then
                state.LastError = tostring(errorMessage)
            end
            task.wait(0.05)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local statsModel = getStatsModel()
            for statName, label in pairs(statLabels) do
                local value = statsModel and statsModel:FindFirstChild(statName)
                label.Text = statName .. ": " .. (value and tostring(value.Value) or "--")
            end
            farmPhaseLabel.Text = "Phase: " .. state.Phase
            farmTargetLabel.Text = "Target: " .. (state.Target and state.Target.Name or "None")
                .. (state.LastTargetHealth > 0 and " | HP " .. math.floor(state.LastTargetHealth) or "")
            farmEnergyLabel.Text = "Energy: " .. tostring(getEnergy() or "--")
            farmAbilityLabel.Text = "Ability: " .. state.LastAbility
            routePhaseLabel.Text = "Route: " .. state.RoutePhase
            routeBoostLabel.Text = "Gravity boost: " .. (gravityEnabled() and "ACTIVE" or "Inactive")
            routeClaimLabel.Text = string.format("Zeni claims: %d | Capsules: %d", state.ZeniClaims, state.CapsulesBought)
            routeHopLabel.Text = "Server route: " .. state.HopStatus .. " | Queue: " .. state.TeleportQueueMethod
            if state.RouteStartedAt > 0 then
                local elapsed = math.max(0, os.clock() - state.RouteStartedAt)
                local gained = statsModel and math.max(0, getBasePower(statsModel) - state.RouteStartPL) or 0
                routeGainLabel.Text = "Power gained: " .. tostring(math.floor(gained))
                routeTimeLabel.Text = string.format("Elapsed: %02d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60))
            else
                routeGainLabel.Text = "Power gained: 0"
                routeTimeLabel.Text = "Elapsed: 00:00"
            end
            errorLabel.Text = "Last error: " .. state.LastError
            task.wait(0.5)
        end
    end)

    if gui and gui.Destroying then
        track(gui.Destroying:Connect(function()
            state.Alive = false
            state.AutoFarm = false
            stopCharging()
            releaseFarmPosition()
        end))
    end

    Window:SetContextStatus("Dragon Ball Legendary Powers | ⚡ rapid progression ready")
    return {
        State = state,
    }
end
