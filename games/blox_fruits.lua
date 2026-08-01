-- Extracted from VOR_HUB.lua lines 10629-17178.
return function(context)
    local Window = assert(context.Window, "Blox Fruits module requires Window")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Blox Fruits module requires CreateCategoryHomePage")
    local COLORS = context.Colors or context.COLORS
    local track = assert(context.Track, "Blox Fruits module requires Track")
    local gui = assert(context.Gui, "Blox Fruits module requires Gui")
    local tracebackError = context.Utilities and context.Utilities.Traceback or tostring
    local built, buildError = xpcall(function()
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local TeleportService = game:GetService("TeleportService")
        local VirtualUser = game:GetService("VirtualUser")
        local Lighting = game:GetService("Lighting")
        local HttpService = game:GetService("HttpService")
        local CollectionService = game:GetService("CollectionService")
        local LocalPlayer = Players.LocalPlayer

        local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage({TextOnly = true})
        local FarmingPage = addHomeCategory("Farming", 1)
        local CombatPage = addHomeCategory("Combat", 2)
        local MasteryPage = addHomeCategory("Mastery", 3)
        local ShopPage = addHomeCategory("Shop", 4)
        local SeaPage = addHomeCategory("Sea & Raids", 5)
        local PlayerPage = addHomeCategory("Player", 6)
        selectHomeCategory("Farming")

        local LevelSection = FarmingPage:AddSection("Auto Level", "Left")
        local FarmSettingsSection = FarmingPage:AddSection("Farm Settings", "Left")
        local MobFarmSection = FarmingPage:AddSection("Mob Aura & Selection", "Left")
        local FarmPositionSection = FarmingPage:AddSection("Farm Position Controller", "Right")
        local WorldFarmSection = FarmingPage:AddSection("World Farming", "Right")
        local FarmStatusSection = FarmingPage:AddSection("Live Farm Status", "Right")

        local ExploitSection = FarmingPage:AddSection("Auto Magnet", "Left")
        local AttackSection = CombatPage:AddSection("Attack Controller", "Right")
        local BossSection = FarmingPage:AddSection("Boss Farming", "Right")

        local StatsSection = MasteryPage:AddSection("Auto Stats", "Left")
        local FightingStyleSection = ShopPage:AddSection("Fighting Styles", "Right")
        local FruitSection = ShopPage:AddSection("Fruit Utilities", "Left")
        local TravelSection = SeaPage:AddSection("World Travel", "Right")

        local RaidSection = SeaPage:AddSection("Dungeon / Raid Automation", "Left")
        local SeaStatusSection = SeaPage:AddSection("Sea & Event Status", "Right")

        local PlayerStateSection = PlayerPage:AddSection("Player State", "Left")
        local VisualSection = PlayerPage:AddSection("Visuals", "Right")
        local SessionSection = PlayerPage:AddSection("Session", "Right")

        local function safeRequire(instance)
            if not instance then
                return nil
            end
            local ok, result = pcall(require, instance)
            return ok and result or nil
        end

        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local CommF = Remotes and Remotes:FindFirstChild("CommF_")
        local CommE = Remotes and Remotes:FindFirstChild("CommE")
        local Redeem = Remotes and Remotes:FindFirstChild("Redeem")
        local Net = ReplicatedStorage:FindFirstChild("Modules")
        Net = Net and Net:FindFirstChild("Net")
        local ClaimBerry = Net and (Net:FindFirstChild("ClaimBerry", true) or Net:FindFirstChild("RF/ClaimBerry"))
        local Quests = safeRequire(ReplicatedStorage:FindFirstChild("Quests")) or {}
        local Guide = safeRequire(ReplicatedStorage:FindFirstChild("GuideModule"))
        local CombatUtil = safeRequire(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("CombatUtil"))
        local FruitMouse = safeRequire(ReplicatedStorage:FindFirstChild("Mouse"))
        -- Calling Net:RemoteEvent from the executor's UI-building thread drops
        -- its CoreGui capability in current Blox Fruits, so the next control
        -- fails while parenting its Instance. RegisterAttack is non-virtual;
        -- use its already-replicated event directly and leave RegisterHit on
        -- CombatUtil's initialized internal sender.
        local RegisterAttackEvent = Net and Net:FindFirstChild("RE/RegisterAttack")
        local ShootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")
        local AURA_KILL_DEFAULT_RANGE = 10
        local AURA_KILL_MAX_RANGE = 70
        local AURA_KILL_HIT_DELAY = 0.13
        local AURA_KILL_NATIVE_COOLDOWN_SCALE = 0.8
        local NATIVE_FRUIT_M1_CADENCE = 0.32
        local NATIVE_FRUIT_MAX_RANGE = 25
        local DoubleAttackEngine = {
            HitRange = 38,
            SwordTargetLimit = 12,
            FruitTargetLimit = 3,
            FruitCadence = 0.075,
        }
        -- The live Fruit LocalScript subtracts this Character attribute from
        -- both its regular 0.3-second gate and its fifth-hit 1-second gate.
        -- A value of 1 removes both local manual-click cooldowns completely.
        local DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION = 1
        local NATIVE_FRUIT_SETTLE_TIME = 0.24
        local MULTI_GRAB_LIMIT = 3
        local MULTI_GRAB_RANGE = 600
        local MULTI_ATTACK_TARGET_LIMIT = 2

        local state = {
            Alive = true,
            Status = "Native Blox Fruits module ready",
            LastError = nil,
            AutoFarmLevel = false,
            SelectedLevelQuest = "Best for My Level",
            CurrentSeaName = "Detecting",
            CurrentSeaQuestCount = 0,
            CurrentSeaMinimumLevel = 0,
            CurrentSeaMaximumLevel = 0,
            AutoChest = false,
            AutoBerry = false,
            LastBerryClaim = 0,
            BerriesClaimed = 0,
            AutoBoss = false,
            SelectedBoss = "None",
            AutoRaid = false,
            AutoStartRaid = false,
            AutoBuyRaidChip = false,
            AutoAwaken = false,
            RaidMultiGrab = false,
            RaidGathered = 0,
            RaidVoidKill = false,
            RaidVoidActive = false,
            RaidVoidMoved = 0,
            RaidVoidStaged = 0,
            RaidVoidKillCount = 0,
            RaidVoidTargets = setmetatable({}, {__mode = "k"}),
            RaidVoidOriginalCFrames = setmetatable({}, {__mode = "k"}),
            LastRaidVoidStep = 0,
            RaidSafeHeight = 35,
            RaidEnteredAt = 0,
            RaidEntryGrace = 8,
            RaidHasEntered = false,
            RaidLastInactiveAt = os.clock(),
            RaidCastleStart = CFrame.new(-5064, 314, -2938),
            SelectedRaid = "Flame",
            RaidIslandIndex = 0,
            RaidIslandName = nil,
            RaidTargetName = nil,
            SeaEvent = {
                Enabled = false,
                AutoSail = false,
                AutoKill = false,
                AutoStopSail = false,
                SelectedEvents = {
                    ["Piranha"] = true,
                    ["Shark"] = true,
                    ["Terror Shark"] = true,
                    ["Fish Crew Member"] = true,
                    ["Enemy Boat"] = true,
                    ["Sea Beast"] = true,
                },
                StopConditions = {},
                StopMatch = nil,
                LastStopScan = 0,
                SelectedBoat = "Guardian",
                BoatTweenSpeed = 295,
                BoatFloatHeight = 0,
                CombatHeight = 24,
                SpamAllSkills = true,
                WaterGuard = true,
                ResetBrokenBoat = true,
                Boat = nil,
                BoatBaseY = nil,
                IgnoredBoats = setmetatable({}, {__mode = "k"}),
                ForceBoatPurchase = false,
                Target = nil,
                TargetKind = nil,
                TargetLostAt = nil,
                TargetLastSeenAt = 0,
                TargetLastHealth = nil,
                Heading = nil,
                NextHeadingAt = 0,
                LastPurchase = 0,
                LastSeat = 0,
                LastSkill = 0,
                ToolIndex = 0,
                SkillIndex = 0,
                EffectiveSpeed = 295,
                SafeSpeed = 80,
                RejectedSpeed = nil,
                StableSince = 0,
                PauseUntil = 0,
                LastCommandedPosition = nil,
                Rubberbacks = 0,
                BoatCollisions = setmetatable({}, {__mode = "k"}),
                SafetyPart = nil,
                Phase = "Off",
                DangerLevel = 0,
                DangerDistance = 0,
                EventsCompleted = 0,
                LastError = nil,
            },
            AuraKill = false,
            AuraRange = AURA_KILL_DEFAULT_RANGE,
            FastAttack = false,
            AttackInterval = 0,
            LastAttack = 0,
            LastAuraScan = 0,
            AuraTargetCursor = 0,
            AuraHits = 0,
            AuraRequests = 0,
            AuraSwordRequests = 0,
            AuraFruitRequests = 0,
            AuraTargetCount = 0,
            AuraMultiTargetCount = 0,
            AuraAttackPending = false,
            AuraAttackPendingAt = 0,
            AuraAttackGeneration = 0,
            AuraCombo = 0,
            AuraCombos = {},
            NativeFruitCombos = {},
            AuraStage = "idle",
            AuraPendingError = nil,
            AuraLastRequestAt = nil,
            AuraLastHitAt = nil,
            AuraWeaponName = nil,
            AuraWeaponType = nil,
            AuraAttackMode = nil,
            AuraFruitBusy = false,
            FruitDispatchPending = false,
            FruitDispatchPendingAt = 0,
            FruitDispatchGeneration = 0,
            LastDoubleFruitAttack = 0,
            AuraFruitInRange = nil,
            AuraFruitLastDistance = nil,
            FruitM1ReadyAt = 0,
            DoubleAttack = false,
            FruitM1CooldownReduction = DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
            OriginalFruitTapCooldown = nil,
            MobAuraTp = false,
            FarmPositionX = 0,
            FarmPositionZ = 0,
            MobAuraHeight = 20,
            MobAuraSearchRange = 500,
            MobAuraOrbit = false,
            MobAuraOrbitRadius = 8,
            MobAuraOrbitSpeed = 110,
            MobAuraOrbitStartedAt = os.clock(),
            MobAuraOrbitStartAngle = math.random() * math.pi * 2,
            MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1,
            MobAuraRandomSquare = false,
            MobAuraSquareSize = 8,
            MobAuraSquareInterval = 0.18,
            MobAuraSquareOffset = Vector3.zero,
            MobAuraSquareCorner = 0,
            MobAuraLastSquareStep = 0,
            MobAuraTarget = nil,
            MobAuraTargetName = nil,
            MobAuraDistance = nil,
            MobAuraPreTeleportDistance = nil,
            MobAuraAnchorTarget = nil,
            MobAuraStableAnchor = nil,
            SelectedMobFarm = false,
            SelectedMobName = "None",
            SelectedMobSearchRange = 30000,
            SelectedMobWaitingAtSpawn = false,
            RegisterHitClosure = nil,
            LastRegisterHitResolve = -math.huge,
            WeaponType = "Best Available",
            AutoBuso = true,
            LastBuso = 0,
            SubmarineWorkerSpeak = Net and Net:FindFirstChild("RF/SubmarineWorkerSpeak"),
            LastSubmergedTravel = -math.huge,
            SubmergedTravelRequestedAt = -math.huge,
            SubmarineWorkerFallback = Vector3.new(-16269, 5, 1373),
            AutoObservation = false,
            LastObservation = 0,
            GatherEnemies = false,
            GatherRange = MULTI_GRAB_RANGE,
            GatherDistance = 8,
            GatherQuestOnly = true,
            GatherMode = "Selected / Current Mob",
            GatherSelectedMob = "Current Farm Target",
            GatherLimit = MULTI_GRAB_LIMIT,
            Gathered = 0,
            GatherSingleFallbackEnemy = nil,
            GatherOriginalCFrames = setmetatable({}, {__mode = "k"}),
            GatherOriginalStates = setmetatable({}, {__mode = "k"}),
            AutoMagnet = false,
            ExperimentalMagnetBoost = false,
            DragonstormOwned = nil,
            LastDragonstormOwnershipCheck = 0,
            MagnetRange = 300,
            MagnetAnchorTarget = nil,
            MagnetAnchorCFrame = nil,
            MagnetAnchorName = nil,
            MagnetTweens = setmetatable({}, {__mode = "k"}),
            ThirdSeaFarmActive = false,
            ThirdSeaFarmNames = {},
            TweenSpeed = 300,
            LastPositionJitterAt = 0,
            PositionJitterCorner = 0,
            PositionTarget = nil,
            PositionBasis = nil,
            PositionAnchorWorld = nil,
            PositionLockVertical = false,
            PositionAnchorY = nil,
            PositionJitter = Vector3.zero,
            ActiveFarmTarget = nil,
            ActiveFarmVerticalLock = false,
            ActiveFarmHeightOverride = nil,
            AntiRagdollApplied = false,
            AntiRagdollHumanoid = nil,
            FarmAnimateScript = nil,
            FarmAnimateWasDisabled = nil,
            FarmAnimator = nil,
            FarmAnimationConnection = nil,
            SafeMode = false,
            SafeHealthPercent = 30,
            CurrentEnemyName = nil,
            CurrentQuestName = nil,
            MoveTween = nil,
            MoveGoal = nil,
            MoveToken = 0,
            MoveEffectiveSpeed = 300,
            MoveRoot = nil,
            MoveRootWasAnchored = false,
            MoveHumanoid = nil,
            MoveAutoRotate = nil,
            MovePlatformStand = nil,
            MoveVelocityGuard = nil,
            FarmHoldY = nil,
            Traveling = false,
            LastQuestRequest = 0,
            LastChestScan = 0,
            LastGatherScan = 0,
            LastStat = 0,
            AutoStats = false,
            StatBatch = 1,
            StatIndex = 0,
            Stats = {
                Melee = false,
                Defense = false,
                Sword = false,
                Gun = false,
                ["Demon Fruit"] = false,
            },
            AutoGacha = false,
            LastGacha = 0,
            GachaInterval = 30,
            GachaBusy = false,
            GachaRolls = 0,
            GachaStatus = "Ready anywhere",
            AutoStoreFruit = false,
            LastStore = 0,
            InventoryBusy = false,
            InventoryBusyOwner = nil,
            InventoryGeneration = 0,
            FruitsStored = 0,
            StoreStatus = "Waiting for a physical fruit",
            SelectedLocation = "None",
            SelectedNPC = "None",
            BypassTeleport = false,
            Noclip = false,
            InfiniteEnergy = false,
            WalkOnWater = true,
            AntiAfk = true,
            EnemyESP = false,
            PlayerESP = false,
            FpsBoost = false,
            LastGatherLabelText = nil,
            EnemyHighlights = setmetatable({}, {__mode = "k"}),
            PlayerHighlights = setmetatable({}, {__mode = "k"}),
            PlayerEspObjects = {},
            PlayerEspLastTextUpdate = 0,
            OriginalCollision = setmetatable({}, {__mode = "k"}),
            GraphicsBackup = setmetatable({}, {__mode = "k"}),
            WaterPlatform = nil,
            DamageDebugConnection = nil,
        }
        do
            -- Blox Fruits currently fires this debug-only event for every
            -- credited hit without installing a client listener. Aura Kill can
            -- otherwise fill the 512-event queue during a raid and destabilize
            -- the client even though the combat requests themselves succeed.
            local damageDebugEvent = Remotes and Remotes:FindFirstChild("DMGDEBUG")
            if damageDebugEvent and damageDebugEvent:IsA("RemoteEvent") then
                state.DamageDebugConnection = track(
                    damageDebugEvent.OnClientEvent:Connect(function() end)
                )
            end
        end
        -- PVP is player-facing combat, not a seventh junk-drawer category.
        -- Keep the existing section builders but mount them under Player.
        state.PVPPage = PlayerPage

        local statusLabel = FarmStatusSection:AddLabel("Status: Initializing...")
        local questLabel = FarmStatusSection:AddLabel("Quest: Reading live quest data...")
        local targetLabel = FarmStatusSection:AddLabel("Target: None")
        local berryLabel = FarmStatusSection:AddLabel("Berries: Ready")
        local magnetLabel = ExploitSection:AddLabel("Auto Magnet: Off | Stacked: 0")
        ExploitSection:AddLabel("One shared magnet for Auto Level, bosses, raids, Mob Aura, and selected-mob farming.")
        local raidLabel = SeaStatusSection:AddLabel("Raid: Idle")
        local seaLabel = SeaStatusSection:AddLabel("Sea: Detecting...")
        local playerLabel = PlayerStateSection:AddLabel("Player: Reading...")
        local auraLabel = AttackSection:AddLabel("Aura Kill: Off | Range: 10 studs")
        local mobAuraLabel = MobFarmSection:AddLabel("Mob Aura TP: Off | Distance: --")
        local selectedMobFarmLabel = MobFarmSection:AddLabel("Selected Mob Farm: Off | Enemy: None")
        local busoLabel = AttackSection:AddLabel("Buso: Detecting...")
        local observationLabel = AttackSection:AddLabel("Observation: Reading live state...")
        local fruitGachaLabel = FruitSection:AddLabel("Fruit Gacha: Ready anywhere")
        local fruitStoreLabel = FruitSection:AddLabel("Fruit Storage: Waiting for a physical fruit")

        local function setStatus(message, success)
            state.Status = tostring(message)
            statusLabel.Text = "Status: " .. state.Status
            statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
        end

        local function setError(message)
            state.LastError = tostring(message)
            setStatus(state.LastError, false)
        end

        local function character()
            local value = LocalPlayer.Character
            if not value or not value.Parent then
                return nil
            end
            return value
        end

        local function rootPart()
            local value = character()
            return value and value:FindFirstChild("HumanoidRootPart") or nil
        end

        local function humanoid()
            local value = character()
            return value and value:FindFirstChildOfClass("Humanoid") or nil
        end

        local function invoke(command, ...)
            if not CommF then
                return false, "CommF_ is unavailable"
            end
            local arguments = table.pack(...)
            local ok, result = pcall(function()
                return CommF:InvokeServer(command, table.unpack(arguments, 1, arguments.n))
            end)
            if not ok then
                state.LastError = tostring(result)
                return false, result
            end
            return true, result
        end

        local function busoActive()
            local char = character()
            if not char then
                return false
            end
            local enabledAttribute = char:GetAttribute("BusoEnabled")
            if enabledAttribute ~= nil then
                return enabledAttribute == true
            end
            -- The current Aura LocalScript uses the Buso tag for ownership and
            -- creates HasBuso only while the ability is actually enabled.
            return char:FindFirstChild("HasBuso") ~= nil
        end

        local function refreshBusoStatus()
            local active = busoActive()
            local char = character()
            local enabledAttribute = char and char:GetAttribute("BusoEnabled")
            state.BusoOwned = char ~= nil and (
                CollectionService:HasTag(char, "Buso")
                or enabledAttribute ~= nil
                or char:FindFirstChild("HasBuso") ~= nil
            )
            gui:SetAttribute("BloxBusoActive", active)
            gui:SetAttribute("BloxBusoOwned", state.BusoOwned == true)
            if not state.AutoBuso then
                busoLabel.Text = active and "Buso: Active | Auto: Off" or "Buso: Off | Auto: Off"
                busoLabel.TextColor3 = active and COLORS.success or COLORS.muted
            elseif active then
                busoLabel.Text = "Buso: Active | Auto: On"
                busoLabel.TextColor3 = COLORS.success
            elseif state.BusoOwned == false then
                busoLabel.Text = "Buso: Not owned | Starter attacks enabled"
                busoLabel.TextColor3 = COLORS.warning
            else
                busoLabel.Text = "Buso: Activating..."
                busoLabel.TextColor3 = COLORS.muted
            end
            return active
        end

        local function sendBusoInput()
            -- This is the exact action used by the current Aura LocalScript on
            -- both keyboard and mobile. Prefer it over simulated J input so a
            -- successful key injection cannot be mistaken for activation.
            local remoteOk, remoteResult = invoke("Buso")
            if remoteOk then
                return true, "Native CommF"
            end
            local okService, inputManager = pcall(function()
                return game:GetService("VirtualInputManager")
            end)
            if okService and inputManager then
                local ok, message = pcall(function()
                    inputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
                    inputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
                end)
                if ok then
                    return true, "Virtual J"
                end
                state.LastError = tostring(message)
            end
            if type(keypress) == "function" and type(keyrelease) == "function" then
                local ok, message = pcall(function()
                    keypress(0x4A)
                    keyrelease(0x4A)
                end)
                if ok then
                    return true, "Executor J"
                end
                state.LastError = tostring(message)
            end
            return false, remoteResult
        end

        local function ensureBuso(force)
            if refreshBusoStatus() then
                return true
            end
            -- Fresh accounts do not own Aura yet. Pressing J cannot activate an
            -- ability that is not owned, and normal starter NPCs do not require
            -- it. Keep Auto Buso armed for when ownership appears, but never let
            -- the missing ability hard-block Melee/Sword damage registration.
            if state.BusoOwned == false then
                return false
            end
            if not state.AutoBuso and not force and not state.AuraKill then
                return false
            end
            local now = os.clock()
            if now - state.LastBuso < 1.25 then
                return false
            end
            state.LastBuso = now
            gui:SetAttribute("BloxLastBusoAttemptAt", now)
            local ok, message = sendBusoInput()
            gui:SetAttribute("BloxLastBusoRequestSucceeded", ok)
            gui:SetAttribute("BloxLastBusoInputMethod", ok and tostring(message) or "Failed")
            if not ok then
                busoLabel.Text = "Buso: Activation failed"
                busoLabel.TextColor3 = COLORS.error
                setError("Auto Buso failed: " .. tostring(message))
                return false
            end
            -- HasBuso replicates asynchronously after the server toggles it.
            task.delay(0.35, function()
                local active = refreshBusoStatus()
                gui:SetAttribute("BloxLastBusoVerified", active)
            end)
            busoLabel.Text = "Buso: Activation requested"
            busoLabel.TextColor3 = COLORS.muted
            return true
        end

        local function normalizeEnemyName(value)
            local name = tostring(value or "")
            name = name:gsub("%s*%[Lv[^%]]*%]", "")
            name = name:gsub("%s*%[Boss%]", "")
            name = name:gsub("%s+$", "")
            return name
        end

        local function modelRoot(model)
            if not model or not model.Parent then
                return nil
            end
            return model.PrimaryPart
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart")
        end

        local function modelAlive(model)
            local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
            return targetHumanoid ~= nil and targetHumanoid.Health > 0
        end

        local function enemyMatches(model, targetName)
            return string.lower(normalizeEnemyName(model and model.Name)) == string.lower(normalizeEnemyName(targetName))
        end

        local function nearestEnemy(targetName, anyEnemy)
            local root = rootPart()
            local enemies = workspace:FindFirstChild("Enemies")
            if not root or not enemies then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            for _, enemy in ipairs(enemies:GetChildren()) do
                local enemyRoot = modelRoot(enemy)
                if enemyRoot and modelAlive(enemy) and (anyEnemy or enemyMatches(enemy, targetName)) then
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if distance < bestDistance then
                        best = enemy
                        bestDistance = distance
                    end
                end
            end
            return best, bestDistance
        end

        local function nearestEnemySpawn(enemyName)
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if not spawns then
                return nil
            end
            local root = rootPart()
            local best = nil
            local bestDistance = math.huge
            for _, descendant in ipairs(spawns:GetDescendants()) do
                if descendant:IsA("BasePart") and enemyMatches(descendant, enemyName) then
                    local distance = root and (descendant.Position - root.Position).Magnitude or 0
                    if distance < bestDistance then
                        best = descendant
                        bestDistance = distance
                    end
                end
            end
            return best, bestDistance
        end

        local function mobFarmOptions()
            local options = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if spawns then
                for _, descendant in ipairs(spawns:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        local name = normalizeEnemyName(descendant.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(options, name)
                        end
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local name = normalizeEnemyName(enemy.Name)
                    if name ~= "" and not seen[name] then
                        seen[name] = true
                        table.insert(options, name)
                    end
                end
            end
            table.sort(options, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return options
        end

        local CURRENT_GATHER_TARGET = "Current Farm Target"

        local function gatherMobOptions()
            local options = {CURRENT_GATHER_TARGET}
            for _, name in ipairs(mobFarmOptions()) do
                if name ~= "None" then
                    table.insert(options, name)
                end
            end
            return options
        end

        local function selectedGatherEnemyName()
            local selected = tostring(state.GatherSelectedMob or CURRENT_GATHER_TARGET)
            if selected ~= CURRENT_GATHER_TARGET and selected ~= "None" then
                return selected
            end
            if state.SelectedMobFarm and state.SelectedMobName ~= "None" then
                return state.SelectedMobName
            end
            return state.CurrentEnemyName
        end

        local function movementStillNeedsNoclip()
            return state.Noclip or state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
                or state.AutoChest or state.MobAuraTp or state.SelectedMobFarm
        end

        local FarmVertical = {}

        function FarmVertical.Release()
            state.FarmHoldY = nil
        end

        function FarmVertical.Ensure()
            local root = rootPart()
            if not root then
                FarmVertical.Release()
                return
            end
            if state.Traveling then
                state.FarmHoldY = nil
                return
            end
            state.FarmHoldY = state.FarmHoldY or root.Position.Y
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame += Vector3.new(0, state.FarmHoldY - root.Position.Y, 0)
        end

        function FarmVertical.RecoverBody()
            if state.Traveling then
                return
            end
            local root = rootPart()
            local body = humanoid()
            if not root or not body or body.Health <= 0 then
                return
            end
            local staleGuard = root:FindFirstChild("VORTravelVelocity")
            if staleGuard then
                pcall(function()
                    staleGuard:Destroy()
                end)
            end
            root.Anchored = false
            body.Sit = false
            body.PlatformStand = false
            body.AutoRotate = true
            local bodyState = body:GetState()
            if bodyState == Enum.HumanoidStateType.Physics
                or bodyState == Enum.HumanoidStateType.PlatformStanding
                or bodyState == Enum.HumanoidStateType.Ragdoll
                or bodyState == Enum.HumanoidStateType.FallingDown then
                pcall(function()
                    body:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
                task.defer(function()
                    if body.Parent and body.Health > 0 and not state.Traveling then
                        pcall(function()
                            body:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end
                end)
            end
        end

        function FarmVertical.SetAntiRagdoll(enabled)
            local body = humanoid()
            enabled = enabled == true and body ~= nil and body.Health > 0
            if state.AntiRagdollHumanoid == body and state.AntiRagdollApplied == enabled then
                return
            end
            if state.AntiRagdollHumanoid and state.AntiRagdollHumanoid.Parent then
                pcall(function()
                    state.AntiRagdollHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    state.AntiRagdollHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                end)
            end
            state.AntiRagdollHumanoid = body
            state.AntiRagdollApplied = enabled
            if body then
                pcall(function()
                    body:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
                    body:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled)
                end)
                if enabled then
                    FarmVertical.RecoverBody()
                end
            end
        end

        local function releaseMoveRide()
            local root = state.MoveRoot
            local body = state.MoveHumanoid
            local velocityGuard = state.MoveVelocityGuard
            if velocityGuard then
                pcall(function()
                    velocityGuard:Destroy()
                end)
            end
            if root and root.Parent then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if body and body.Parent and body.Health > 0 then
                    root.Anchored = false
                else
                    root.Anchored = state.MoveRootWasAnchored == true
                end
            end
            if body and body.Parent then
                body.Sit = false
                body.PlatformStand = false
                body.AutoRotate = state.MoveAutoRotate == nil and true or state.MoveAutoRotate
                if body.Health > 0 then
                    pcall(function()
                        body:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end)
                    task.defer(function()
                        if body.Parent and body.Health > 0 and not state.Traveling then
                            pcall(function()
                                body:ChangeState(Enum.HumanoidStateType.Running)
                            end)
                        end
                    end)
                end
            end
            state.MoveRoot = nil
            state.MoveHumanoid = nil
            state.MoveAutoRotate = nil
            state.MovePlatformStand = nil
            state.MoveVelocityGuard = nil
            state.MoveRootWasAnchored = false
            state.Traveling = false
            gui:SetAttribute("BloxTraveling", false)
            if not movementStillNeedsNoclip() then
                for part, original in pairs(state.OriginalCollision) do
                    if part and part.Parent then
                        part.CanCollide = original
                    end
                end
                table.clear(state.OriginalCollision)
            end
        end

        local function cancelMove(keepRide)
            state.MoveToken += 1
            local activeTween = state.MoveTween
            state.MoveTween = nil
            state.MoveGoal = nil
            if activeTween then
                pcall(function()
                    activeTween:Cancel()
                end)
            end
            if not keepRide then
                releaseMoveRide()
            end
        end

        local function moveTo(targetCFrame)
            local root = rootPart()
            if not root or typeof(targetCFrame) ~= "CFrame" then
                return false
            end
            local distance = (root.Position - targetCFrame.Position).Magnitude
            if distance <= 3 then
                cancelMove(false)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = targetCFrame
                return true
            end
            if state.MoveGoal and (state.MoveGoal - targetCFrame.Position).Magnitude < 5 and state.MoveTween then
                return true
            end

            if state.MoveRoot and state.MoveRoot ~= root then
                cancelMove(false)
            else
                cancelMove(true)
            end
            if not state.MoveRoot then
                state.MoveRoot = root
                state.MoveRootWasAnchored = root.Anchored
                state.MoveHumanoid = humanoid()
                state.MoveAutoRotate = state.MoveHumanoid and state.MoveHumanoid.AutoRotate or nil
                state.MovePlatformStand = state.MoveHumanoid and state.MoveHumanoid.PlatformStand or nil
            end
            state.Traveling = true
            gui:SetAttribute("BloxTraveling", true)
            gui:SetAttribute("BloxTravelGoal", targetCFrame.Position)
            if state.MoveHumanoid then
                state.MoveHumanoid.AutoRotate = false
                state.MoveHumanoid.Sit = false
                state.MoveHumanoid.PlatformStand = false
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            -- Keep the player's root network-owned and unanchored. Anchoring
            -- makes the local tween look perfect, but the server can retain
            -- the departure position and rubber-band the player back when the
            -- root is released. BodyVelocity cancels gravity without hiding
            -- the ride from replication.
            root.Anchored = state.MoveRootWasAnchored == true
            if not state.MoveRootWasAnchored and not state.MoveVelocityGuard then
                local velocityGuard = Instance.new("BodyVelocity")
                velocityGuard.Name = "VORTravelVelocity"
                velocityGuard.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                velocityGuard.P = 20000
                velocityGuard.Velocity = Vector3.zero
                velocityGuard.Parent = root
                state.MoveVelocityGuard = velocityGuard
            end

            state.MoveGoal = targetCFrame.Position
            -- Long CFrame rides above roughly 300 studs/second are where the
            -- server starts restoring an older replicated position. Preserve
            -- the selected speed for short hops, but cap only the risky long
            -- leg instead of letting a 650 slider value cause a full rollback.
            local effectiveSpeed = math.max(tonumber(state.TweenSpeed) or 300, 1)
            if distance >= 1200 then
                effectiveSpeed = math.min(effectiveSpeed, 300)
            elseif distance >= 450 then
                effectiveSpeed = math.min(effectiveSpeed, 400)
            end
            state.MoveEffectiveSpeed = effectiveSpeed
            gui:SetAttribute("BloxTweenEffectiveSpeed", effectiveSpeed)
            local duration = distance / effectiveSpeed
            if duration <= 0.08 then
                root.CFrame = targetCFrame
                cancelMove(false)
                return true
            end

            state.MoveToken += 1
            local moveToken = state.MoveToken
            local activeTween = TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                {CFrame = targetCFrame}
            )
            state.MoveTween = activeTween
            activeTween.Completed:Once(function(playbackState)
                if state.MoveToken ~= moveToken or state.MoveTween ~= activeTween then
                    return
                end
                state.MoveTween = nil
                state.MoveGoal = nil
                if playbackState == Enum.PlaybackState.Completed and root.Parent then
                    root.CFrame = targetCFrame
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    -- Keep the replicated, unanchored root settled at the
                    -- destination for a few frames before restoring normal
                    -- humanoid physics. This gives the server the final
                    -- position instead of a chance to restore the departure.
                    task.delay(0.22, function()
                        if state.MoveToken == moveToken and not state.MoveTween then
                            releaseMoveRide()
                        end
                    end)
                    return
                end
                releaseMoveRide()
            end)
            activeTween:Play()
            return true
        end

        local function groundLockedEnemyY(enemy, enemyRoot)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {LocalPlayer.Character, enemy}
            params.IgnoreWater = false
            local result = workspace:Raycast(
                enemyRoot.Position + Vector3.new(0, 30, 0),
                Vector3.new(0, -180, 0),
                params
            )
            if result then
                return result.Position.Y + math.max(enemyRoot.Size.Y * 0.5, 2.5)
            end
            return enemyRoot.Position.Y
        end

        local function positionAtEnemy(enemy, lockVertical, heightOverride)
            local enemyRoot = modelRoot(enemy)
            if not enemyRoot then
                return nil
            end
            -- Lock the enemy's facing basis once per target. Recomputing the
            -- offset from a boss that constantly turns toward the player is
            -- what caused the old circular/orbiting tween.
            lockVertical = lockVertical == true
            if state.PositionTarget ~= enemy
                or state.PositionBasis == nil
                or state.PositionLockVertical ~= lockVertical then
                state.PositionTarget = enemy
                state.PositionLockVertical = lockVertical
                if lockVertical then
                    local flatForward = Vector3.new(
                        enemyRoot.CFrame.LookVector.X,
                        0,
                        enemyRoot.CFrame.LookVector.Z
                    )
                    if flatForward.Magnitude < 0.05 then
                        flatForward = Vector3.new(0, 0, -1)
                    else
                        flatForward = flatForward.Unit
                    end
                    state.PositionBasis = CFrame.lookAt(Vector3.zero, flatForward)
                    state.PositionAnchorY = groundLockedEnemyY(enemy, enemyRoot)
                else
                    state.PositionBasis = enemyRoot.CFrame - enemyRoot.Position
                    state.PositionAnchorY = nil
                end
                state.PositionAnchorWorld = enemyRoot.Position
                state.PositionJitter = Vector3.zero
                state.PositionJitterCorner = 0
                state.LastPositionJitterAt = 0
            end
            local squareMovement = state.MobAuraRandomSquare == true
            local orbitMovement = state.MobAuraOrbit == true and not squareMovement
            local horizontalOffset = Vector3.zero
            if squareMovement then
                local now = os.clock()
                local interval = math.max(0.06, tonumber(state.MobAuraSquareInterval) or 0.18)
                if state.LastPositionJitterAt == 0 or now - state.LastPositionJitterAt >= interval then
                    local range = math.max(2, tonumber(state.MobAuraSquareSize) or 8)
                    local nextCorner = math.random(1, 4)
                    if nextCorner == state.PositionJitterCorner then
                        nextCorner = nextCorner % 4 + 1
                    end
                    local corners = {
                        Vector3.new(-range, 0, -range),
                        Vector3.new(range, 0, -range),
                        Vector3.new(range, 0, range),
                        Vector3.new(-range, 0, range),
                    }
                    state.PositionJitterCorner = nextCorner
                    state.PositionJitter = corners[nextCorner]
                    state.LastPositionJitterAt = now
                end
                horizontalOffset = state.PositionJitter
            elseif orbitMovement then
                state.PositionJitter = Vector3.zero
                local elapsed = os.clock() - state.MobAuraOrbitStartedAt
                local angle = state.MobAuraOrbitStartAngle
                    + elapsed * math.rad(state.MobAuraOrbitSpeed) * state.MobAuraOrbitDirection
                horizontalOffset = Vector3.new(
                    math.cos(angle) * state.MobAuraOrbitRadius,
                    0,
                    math.sin(angle) * state.MobAuraOrbitRadius
                )
            else
                state.PositionJitter = Vector3.zero
            end
            local localOffset = Vector3.new(
                state.FarmPositionX + horizontalOffset.X,
                math.max(3, tonumber(heightOverride) or tonumber(state.MobAuraHeight) or 20),
                state.FarmPositionZ + horizontalOffset.Z
            )
            local worldOffset = state.PositionBasis:VectorToWorldSpace(localOffset)
            local gatheredFrom = state.GatherOriginalCFrames[enemy]
            local useGatherAnchor = typeof(gatheredFrom) == "CFrame" and (
                state.GatherEnemies
                or (state.RaidMultiGrab and state.AutoRaid and LocalPlayer:GetAttribute("IslandRaiding") == true)
            )
            local livePosition = useGatherAnchor and gatheredFrom.Position or enemyRoot.Position
            if not squareMovement and not orbitMovement then
                local stableAnchor = state.PositionAnchorWorld or livePosition
                local reacquireDistance = math.max(
                    12,
                    math.min(50, (tonumber(state.AuraRange) or 70) * 0.65)
                )
                if (livePosition - stableAnchor).Magnitude > reacquireDistance then
                    stableAnchor = livePosition
                    state.PositionAnchorWorld = stableAnchor
                end
                livePosition = stableAnchor
            end
            local enemyAnchor = lockVertical and Vector3.new(
                livePosition.X,
                state.PositionAnchorY or livePosition.Y,
                livePosition.Z
            ) or livePosition
            local position = enemyAnchor + worldOffset
            -- Never pitch the whole avatar down at an NPC underneath it. With
            -- a zero X/Z offset, lookAt(position, enemyAnchor) produced a
            -- vertical LookVector (Y = -1); Roblox then tried to right the rig
            -- while the farm loop forced it downward again, causing the rapid
            -- two-pose seizure. Preserve an upright yaw-only facing instead.
            local flatLook = Vector3.new(
                enemyAnchor.X - position.X,
                0,
                enemyAnchor.Z - position.Z
            )
            if flatLook.Magnitude < 0.05 then
                local basisLook = state.PositionBasis.LookVector
                flatLook = Vector3.new(basisLook.X, 0, basisLook.Z)
            end
            if flatLook.Magnitude < 0.05 then
                flatLook = Vector3.new(0, 0, -1)
            end
            return CFrame.lookAt(position, position + flatLook.Unit)
        end

        local function moveToFarmPosition(targetCFrame)
            if not state.MobAuraRandomSquare and not state.MobAuraOrbit then
                return moveTo(targetCFrame)
            end
            local root = rootPart()
            if not root or typeof(targetCFrame) ~= "CFrame" then
                return false
            end
            -- Combat movement owns every farm mode. Square uses distinct aim
            -- updates for Fruit M1, while orbit is refreshed on Heartbeat so
            -- it remains a real circle instead of a chain of stale tweens.
            cancelMove()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = targetCFrame
            state.FarmHoldY = targetCFrame.Position.Y
            return true
        end

        local function syncFarmAuraRange(heightOverride)
            local radius = state.MobAuraRandomSquare and (state.MobAuraSquareSize * math.sqrt(2))
                or (state.MobAuraOrbit and state.MobAuraOrbitRadius or 0)
            local baseRadius = math.sqrt(state.FarmPositionX ^ 2 + state.FarmPositionZ ^ 2)
            local height = math.max(3, tonumber(heightOverride) or tonumber(state.MobAuraHeight) or 20)
            local required = math.min(
                AURA_KILL_MAX_RANGE,
                math.ceil(math.sqrt(height * height + (baseRadius + radius) ^ 2) + 8)
            )
            if state.AuraRange < required then
                local rangeControl = Window.PersistentControls["blox_aura_kill_range"]
                if rangeControl then
                    rangeControl:Set(required)
                else
                    state.AuraRange = required
                    gui:SetAttribute("BloxAuraKillRange", required)
                end
            end
            return required
        end

        local function healthPercent()
            local body = humanoid()
            if not body or body.MaxHealth <= 0 then
                return 100
            end
            return (body.Health / body.MaxHealth) * 100
        end

        local function safeModeRetreat(enemy)
            if not state.SafeMode or healthPercent() > state.SafeHealthPercent then
                return false
            end
            state.ActiveFarmTarget = nil
            local enemyRoot = modelRoot(enemy)
            if enemyRoot then
                local retreatPosition = enemyRoot.Position + Vector3.new(0, 45, 0)
                moveTo(CFrame.lookAt(retreatPosition, enemyRoot.Position))
            else
                cancelMove()
            end
            setStatus(string.format(
                "Safe mode: recovering at %.0f%% health",
                healthPercent()
            ), nil)
            return true
        end

        local function weaponNameForTool(tool)
            if not tool then
                return nil
            end
            if type(CombatUtil) == "table" and type(CombatUtil.GetWeaponName) == "function" then
                local ok, weaponName = pcall(function()
                    return CombatUtil:GetWeaponName(tool)
                end)
                if ok and weaponName then
                    return tostring(weaponName)
                end
            end
            return tostring(tool:GetAttribute("WeaponName") or tool.Name)
        end

        local function weaponDataForTool(tool)
            if not tool or type(CombatUtil) ~= "table" or type(CombatUtil.GetWeaponData) ~= "function" then
                return nil
            end
            local weaponName = weaponNameForTool(tool)
            if not weaponName then
                return nil
            end
            local ok, weaponData = pcall(function()
                return CombatUtil:GetWeaponData(weaponName)
            end)
            return ok and type(weaponData) == "table" and weaponData or nil
        end

        local function weaponTypeForTool(tool, weaponData)
            if not tool then
                return ""
            end
            return tostring(
                (weaponData and weaponData.WeaponType)
                    or tool:GetAttribute("WeaponType")
                    or tool.ToolTip
                    or ""
            )
        end

        local function isFruitWeaponType(weaponType)
            return string.find(string.lower(tostring(weaponType or "")), "fruit", 1, true) ~= nil
        end

        local function hasRegisteredBasicMoveset(weaponData)
            local moveset = type(weaponData) == "table" and weaponData.Moveset or nil
            local basics = type(moveset) == "table" and moveset.Basic or nil
            return type(basics) == "table" and #basics > 0
        end

        local function toolForSelection(selection)
            local char = character()
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local selected = string.lower(tostring(selection or ""))
            local selectingFruitM1 = selected == "m1 fruit" or selected == "blox fruit"
            local bestAvailable = nil
            for _, container in ipairs({char, backpack}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") then
                            local weaponData = weaponDataForTool(tool)
                            local weaponType = weaponTypeForTool(tool, weaponData)
                            local lowered = string.lower(weaponType)
                            local fruitTool = isFruitWeaponType(weaponType)
                            local registeredTool = hasRegisteredBasicMoveset(weaponData)
                            if not bestAvailable and (registeredTool or fruitTool) then
                                bestAvailable = tool
                            end
                            if selected == "best available" and (registeredTool or fruitTool) then
                                return tool
                            end
                            -- Fruit Tools such as Kitsune use their own LocalScript
                            -- and native click remote instead of WeaponData. They must
                            -- still be selected and equipped even when GetWeaponData
                            -- returns nil.
                            if selectingFruitM1 and fruitTool then
                                return tool
                            end
                            if selected == "gun" and lowered == "gun" then
                                return tool
                            end
                            if registeredTool and lowered == selected then
                                return tool
                            end
                        end
                    end
                end
            end
            -- Explicit Sword/Melee/Fruit choices never lie by returning another
            -- category. Best Available is the only mode allowed to fall back.
            return selected == "best available" and bestAvailable or nil
        end

        local function selectedTool()
            local selected = toolForSelection(state.WeaponType)
            if selected then
                return selected
            end
            -- Fresh accounts start with Combat instead of a Sword. Profiles
            -- created on another account can still request Sword, so fall back
            -- to the starter Melee tool instead of silently farming with no
            -- damage at all.
            if string.lower(tostring(state.WeaponType or "")) == "sword" then
                return toolForSelection("Melee") or toolForSelection("Best Available")
            end
            return nil
        end

        local function equipTool(tool)
            local char = character()
            local hum = humanoid()
            local changed = false
            if tool and char and hum and tool.Parent ~= char then
                local ok = pcall(function()
                    hum:EquipTool(tool)
                end)
                changed = ok and tool.Parent == char
            end
            return tool, changed
        end

        local function updateAuraWeaponState(tool, mode)
            local weaponData = weaponDataForTool(tool)
            state.AuraWeaponName = tool and tool.Name or nil
            state.AuraWeaponType = tool and weaponTypeForTool(tool, weaponData) or nil
            state.AuraAttackMode = mode
        end

        local function equipSelectedTool()
            if state.DoubleAttack then
                local sword = toolForSelection("Sword")
                local fruit = toolForSelection("M1 Fruit")
                equipTool(sword)
                state.AuraWeaponName = sword and fruit and (sword.Name .. " + " .. fruit.Name) or nil
                state.AuraWeaponType = sword and fruit and "Sword + Blox Fruit" or nil
                state.AuraAttackMode = "Double Attack"
                return sword
            end
            local tool = selectedTool()
            equipTool(tool)
            updateAuraWeaponState(tool, state.WeaponType)
            return tool
        end

        local function applyFruitM1CooldownReduction(value)
            value = math.clamp(
                tonumber(value) or DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
                0,
                DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION
            )
            state.FruitM1CooldownReduction = value
            local char = character()
            if char then
                if state.OriginalFruitTapCooldown == nil then
                    state.OriginalFruitTapCooldown = tonumber(char:GetAttribute("FruitTAPCooldown")) or 0
                end
                char:SetAttribute("FruitTAPCooldown", value)
            end
            return value
        end

        local HIT_PART_NAMES = {
            "ModelHitbox",
            "UpperTorso",
            "LowerTorso",
            "Head",
            "RightUpperArm",
            "LeftUpperArm",
            "RightUpperLeg",
            "LeftUpperLeg",
        }

        local function enemyHitPart(enemy)
            for _, partName in ipairs(HIT_PART_NAMES) do
                local part = enemy:FindFirstChild(partName, true)
                if part and part:IsA("BasePart") then
                    return part
                end
            end
            return nil
        end

        local function nearbyAuraTargets()
            local root = rootPart()
            local enemies = workspace:FindFirstChild("Enemies")
            local targets = {}
            if not root or not enemies then
                return targets
            end
            local selectedFilter = nil
            if state.GatherEnemies then
                selectedFilter = selectedGatherEnemyName()
            elseif state.SelectedMobFarm and state.SelectedMobName ~= "None" then
                selectedFilter = state.SelectedMobName
            elseif state.AutoFarmLevel then
                selectedFilter = state.CurrentEnemyName
            end
            for _, enemy in ipairs(enemies:GetChildren()) do
                local enemyRoot = modelRoot(enemy)
                local hitPart = enemyHitPart(enemy)
                if enemyRoot and hitPart and modelAlive(enemy)
                    and (not selectedFilter or enemyMatches(enemy, selectedFilter)) then
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if distance <= state.AuraRange then
                        table.insert(targets, {
                            Enemy = enemy,
                            HitPart = hitPart,
                            Distance = distance,
                        })
                    end
                end
            end
            table.sort(targets, function(left, right)
                return left.Distance < right.Distance
            end)
            return targets
        end

        function DoubleAttackEngine.Targets(maximum)
            local targets = {}
            local limit = math.max(math.floor(tonumber(maximum) or 1), 1)
            local hitRange = math.min(
                math.max(tonumber(state.AuraRange) or AURA_KILL_DEFAULT_RANGE, 0),
                DoubleAttackEngine.HitRange
            )
            for _, candidate in ipairs(nearbyAuraTargets()) do
                if candidate.Distance <= hitRange then
                    table.insert(targets, candidate)
                    if #targets >= limit then
                        break
                    end
                end
            end
            return targets
        end

        local function resolveRegisterHitClosure()
            if type(state.RegisterHitClosure) == "function" then
                return state.RegisterHitClosure
            end
            if os.clock() - state.LastRegisterHitResolve < 5 then
                return nil
            end
            state.LastRegisterHitResolve = os.clock()
            if type(CombatUtil) ~= "table"
                or type(CombatUtil.RunHitDetection) ~= "function"
                or type(debug) ~= "table"
                or type(debug.getupvalue) ~= "function" then
                return nil
            end
            local currentBuildFallback = nil
            for index = 1, 16 do
                local ok, first, second = pcall(debug.getupvalue, CombatUtil.RunHitDetection, index)
                if not ok then
                    break
                end
                -- Executor implementations return either the value alone or
                -- the stock name/value pair. Support both shapes.
                local value = type(second) == "function" and second or first
                if type(value) == "function" then
                    if index == 5 then
                        currentBuildFallback = value
                    end
                    local name = ""
                    if type(debug.info) == "function" then
                        pcall(function()
                            name = debug.info(value, "n")
                        end)
                    end
                    if name == "registerHit" then
                        state.RegisterHitClosure = value
                        return value
                    end
                end
            end
            -- Live Blox Fruits currently stores registerHit at upvalue 5. The
            -- named lookup above is preferred so updates do not depend on it.
            state.RegisterHitClosure = currentBuildFallback
            return currentBuildFallback
        end

        local function auraAttackProfile(tool, weaponData)
            if not tool or type(weaponData) ~= "table"
                or type(CombatUtil) ~= "table"
                or type(CombatUtil.GetMovesetAnimCache) ~= "function"
                or type(CombatUtil.GetWeaponName) ~= "function"
                or type(CombatUtil.GetPureWeaponName) ~= "function" then
                return nil, "combat animation data is unavailable"
            end

            local moveset = weaponData.Moveset
            local basics = type(moveset) == "table" and moveset.Basic or nil
            if type(basics) ~= "table" or #basics == 0 then
                return nil, "the equipped tool has no basic attack moveset"
            end

            local body = humanoid()
            if not body then
                return nil, "the local humanoid is unavailable"
            end
            local ok, profile = pcall(function()
                local weaponName = CombatUtil:GetWeaponName(tool)
                local pureName = CombatUtil:GetPureWeaponName(weaponName)
                local cache = CombatUtil:GetMovesetAnimCache(body)
                local comboKey = string.lower(tostring(weaponName))
                local combo = ((state.AuraCombos[comboKey] or 0) % #basics) + 1
                local track = cache and cache[pureName .. "-basic" .. combo]
                local duration
                local nativeCadence
                if track then
                    local speedMultiplier = track:GetAttribute("SpeedMult") or 1
                    duration = tonumber(track.Length) / math.max(tonumber(speedMultiplier) or 1, 0.01)
                    if duration <= 0 then
                        -- Freshly equipped tools can expose a zero-length track
                        -- for a few frames. RegisterAttack rejects zero, while
                        -- the native-compatible non-finite fallback keeps the
                        -- valid server hit window alive without a visible swing.
                        duration = 0 / 0
                        nativeCadence = 0.18
                    end
                elseif string.lower(weaponTypeForTool(tool, weaponData)) == "melee" then
                    -- Mobile/new-account Combat can have valid WeaponData
                    -- before its local animation cache is populated. Use the
                    -- same server-compatible registration window as the
                    -- verified Sword fallback so the first melee can deal
                    -- damage without requiring a manual swing first.
                    duration = 0 / 0
                    nativeCadence = 0.18
                else
                    error("basic attack track is not loaded")
                end
                local char = character()
                local attackSpeed = char and tonumber(char:GetAttribute("AttackSpeedMultiplier")) or 1
                attackSpeed = math.max(attackSpeed or 1, 0.01)
                return {
                    Combo = combo,
                    ComboKey = comboKey,
                    Duration = duration,
                    NativeCadence = nativeCadence or (duration * AURA_KILL_NATIVE_COOLDOWN_SCALE / attackSpeed),
                }
            end)
            if not ok then
                return nil, tostring(profile)
            end
            return profile
        end

        function DoubleAttackEngine.SwordProfile(tool, weaponData)
            local moveset = type(weaponData) == "table" and weaponData.Moveset or nil
            local basics = type(moveset) == "table" and moveset.Basic or nil
            if type(basics) ~= "table" or #basics == 0 then
                return nil, "the Sword M1 moveset was not found"
            end

            local weaponName = weaponNameForTool(tool)
            local comboKey = string.lower(tostring(weaponName or tool.Name))
            local combo = ((state.AuraCombos[comboKey] or 0) % #basics) + 1
            local duration = nil
            if type(CombatUtil) == "table"
                and type(CombatUtil.GetMovesetAnimCache) == "function"
                and type(CombatUtil.GetPureWeaponName) == "function" then
                pcall(function()
                    local pureName = CombatUtil:GetPureWeaponName(weaponName)
                    local cache = CombatUtil:GetMovesetAnimCache(humanoid())
                    local animationTrack = cache and cache[pureName .. "-basic" .. combo]
                    if animationTrack then
                        local speedMultiplier = math.max(
                            tonumber(animationTrack:GetAttribute("SpeedMult")) or 1,
                            0.01
                        )
                        duration = tonumber(animationTrack.Length) / speedMultiplier
                    end
                end)
            end

            -- This is the same compatibility value used by the verified
            -- Dungeon engine when the Sword animation cache is not loaded.
            -- Zero gets rejected; the non-finite duration keeps the native
            -- registration window alive without playing the swing locally.
            if not duration or duration <= 0 then
                duration = 0 / 0
            end
            return {
                Combo = combo,
                ComboKey = comboKey,
                Duration = duration,
            }
        end

        local function registeredAttackCadence(attackProfile)
            if state.FastAttack then
                -- The RegisterAttack -> RegisterHit window itself already
                -- consumes AURA_KILL_HIT_DELAY. Adding half the animation
                -- length here made the "Turbo" toggle visibly pause even with
                -- Extra Aura Delay at zero.
                return AURA_KILL_HIT_DELAY
            end
            return math.max(AURA_KILL_HIT_DELAY, attackProfile.NativeCadence)
        end

        local function nativeFruitAttackCadence()
            -- FruitTAPCooldown belongs to the player's manual Tool.Activated
            -- gate. Aura Kill keeps its own cadence so this UI setting cannot
            -- accidentally throttle or accelerate the automatic attack loop.
            return state.FastAttack and DoubleAttackEngine.FruitCadence or NATIVE_FRUIT_M1_CADENCE
        end

        local function transientAuraMiss(message)
            message = tostring(message or "")
            return message == "the target left before the hit window"
                or message == "the target left Aura range"
                or message == "the fruit M1 target left before activation"
        end

        local function sendRegisteredAuraHit(tool, weaponData, target, attackProfile, attackTargets, attackGeneration)
            local _, changed = equipTool(tool)
            if changed then
                task.wait(0.04)
            end
            if state.AuraAttackGeneration ~= attackGeneration then
                return false, "the attack lifecycle changed before the hit window"
            end
            if not tool or tool.Parent ~= character() then
                return false, "the combat Tool could not be equipped"
            end
            if not attackProfile then
                local profileError
                attackProfile, profileError = auraAttackProfile(tool, weaponData)
                if not attackProfile then
                    return false, profileError
                end
            end

            local registerHit = resolveRegisterHitClosure()
            if not RegisterAttackEvent or type(registerHit) ~= "function" then
                return false, "combat registration is unavailable in this server build"
            end

            -- Match the exact duration sent by the native combat controller.
            -- Zero is rejected by the server.
            RegisterAttackEvent:FireServer(attackProfile.Duration)
            state.AuraStage = "attack-started"
            task.wait(AURA_KILL_HIT_DELAY)
            if state.AuraAttackGeneration ~= attackGeneration
                or not state.Alive or not state.AuraKill then
                return false, "the target left before the hit window"
            end
            state.AuraStage = "hit-window"

            local currentRoot = rootPart()
            if not currentRoot then
                return false, "the target left Aura range"
            end

            -- One native attack can register every enemy touched by the same
            -- melee window. Multi Grab uses that window for the entire stack so
            -- two or more NPCs take real damage together instead of waiting for
            -- the Aura cursor to visit them one by one.
            state.AuraStage = "queue-build"
            local validHits = {}
            for _, candidate in ipairs(attackTargets or {target}) do
                local enemy = candidate.Enemy
                local enemyRoot = modelRoot(enemy)
                local hitPart = enemyHitPart(enemy)
                if enemy and enemy.Parent and enemyRoot and hitPart and modelAlive(enemy)
                    and (enemyRoot.Position - currentRoot.Position).Magnitude <= state.AuraRange then
                    table.insert(validHits, {
                        Enemy = enemy,
                        HitPart = hitPart,
                    })
                end
            end
            local registered = #validHits
            if registered == 0 then
                return false, "the target left Aura range"
            end

            -- Native combat queues every rig touched during one swing, then
            -- flushes the queue once. Sending one flush per NPC makes the
            -- server accept the first target and discard the rest as duplicate
            -- attacks. Mirror CombatUtil's real batching shape here instead.
            local primary = validHits[1]
            local extraHits = {}
            for index = 2, registered do
                local hit = validHits[index]
                table.insert(extraHits, {hit.Enemy, hit.HitPart})
            end
            registerHit(character(), primary.Enemy, primary.HitPart, weaponData, extraHits)
            state.AuraStage = "queue-flush"
            registerHit(true)
            state.AuraCombos[attackProfile.ComboKey] = attackProfile.Combo
            state.AuraCombo = attackProfile.Combo
            state.AuraStage = registered > 1 and "registered-multi-hit-sent" or "registered-hit-sent"
            return true, nil, registered
        end

        function DoubleAttackEngine.SendSword(tool, weaponData, attackProfile, attackGeneration)
            local _, changed = equipTool(tool)
            if changed then
                task.wait(0.04)
            end
            if state.AuraAttackGeneration ~= attackGeneration then
                return false, "the attack lifecycle changed before the Sword hit window"
            end
            if not tool or tool.Parent ~= character() then
                return false, "the Sword could not be equipped"
            end
            if not weaponData then
                return false, "Sword combat data is unavailable"
            end
            if not attackProfile then
                local profileError
                attackProfile, profileError = DoubleAttackEngine.SwordProfile(tool, weaponData)
                if not attackProfile then
                    return false, profileError
                end
            end

            local registerHit = resolveRegisterHitClosure()
            if not RegisterAttackEvent or type(registerHit) ~= "function" then
                return false, "Double Attack combat registration is unavailable"
            end
            if #DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit) == 0 then
                return false, "No enemy is inside Double Attack range"
            end

            RegisterAttackEvent:FireServer(attackProfile.Duration)
            state.AuraStage = "double-sword-started"
            task.wait(AURA_KILL_HIT_DELAY)
            if state.AuraAttackGeneration ~= attackGeneration
                or not state.Alive or not state.AuraKill or not state.DoubleAttack then
                return false, "the target left before the hit window"
            end

            -- Re-scan at the actual server hit window. The old sea loop kept a
            -- stale two-target list from before the delay; the verified
            -- Dungeon/Solix pattern batches every current rig in one flush.
            local targets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
            if #targets == 0 then
                return false, "the target left Aura range"
            end
            local primary = targets[1]
            local extraHits = {}
            for index = 2, #targets do
                local hit = targets[index]
                table.insert(extraHits, {hit.Enemy, hit.HitPart})
            end
            registerHit(character(), primary.Enemy, primary.HitPart, weaponData, extraHits)
            registerHit(true)
            state.AuraCombos[attackProfile.ComboKey] = attackProfile.Combo
            state.AuraCombo = attackProfile.Combo
            state.AuraMultiTargetCount = #targets
            state.AuraStage = #targets > 1 and "double-sword-multi-sent" or "double-sword-sent"
            return true, nil, #targets
        end

        state.ExperimentalDispatchRegistered = function(selection, keepSwordEquipped, hitDelay)
            local tool = toolForSelection(selection)
            local char = character()
            if not tool or not char then
                return false, "No " .. tostring(selection) .. " Tool was found"
            end
            local weaponData = weaponDataForTool(tool)
            if not hasRegisteredBasicMoveset(weaponData) then
                return false, tostring(selection) .. " combat data is unavailable"
            end
            local profile, profileError = DoubleAttackEngine.SwordProfile(tool, weaponData)
            if not profile then
                return false, profileError
            end
            local registerHit = resolveRegisterHitClosure()
            if not RegisterAttackEvent or type(registerHit) ~= "function" then
                return false, "experimental combat registration is unavailable"
            end
            local targets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
            if #targets == 0 then
                return false, "No enemy is inside experimental attack range"
            end

            if keepSwordEquipped and string.lower(tostring(selection)) ~= "sword" then
                local sword = toolForSelection("Sword")
                if not sword then
                    return false, "A Sword is required to keep the visible weapon equipped"
                end
                equipTool(sword)
            else
                local _, changed = equipTool(tool)
                if changed then
                    task.wait(0.04)
                end
            end
            if not keepSwordEquipped and tool.Parent ~= char then
                return false, tostring(selection) .. " could not be armed"
            end

            RegisterAttackEvent:FireServer(profile.Duration)
            local requestedHitDelay = math.clamp(
                tonumber(hitDelay) or AURA_KILL_HIT_DELAY,
                0,
                AURA_KILL_HIT_DELAY
            )
            if requestedHitDelay > 0 then
                task.wait(requestedHitDelay)
            end
            targets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
            if #targets == 0 then
                return false, "the experimental target left Aura range"
            end
            local primary = targets[1]
            local extraHits = {}
            for index = 2, #targets do
                local hit = targets[index]
                table.insert(extraHits, {hit.Enemy, hit.HitPart})
            end
            registerHit(char, primary.Enemy, primary.HitPart, weaponData, extraHits)
            registerHit(true)
            state.AuraCombos[profile.ComboKey] = profile.Combo
            local sword = keepSwordEquipped and toolForSelection("Sword") or nil
            if sword then
                equipTool(sword)
            end
            return true, nil, #targets
        end

        local function playingTrackSet()
            local tracks = {}
            local body = humanoid()
            local animator = body and body:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    tracks[track] = true
                end
            end
            return animator, tracks
        end

        local function stopNewActionTracks(animator, previousTracks)
            if not animator then
                return
            end
            pcall(function()
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if not previousTracks[track]
                        and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
                        track:Stop(0)
                    end
                end
            end)
        end

        local function holdRoot(root, goalCFrame, duration, animator, previousTracks)
            local deadline = os.clock() + duration
            repeat
                if not root.Parent then
                    break
                end
                root.CFrame = goalCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                stopNewActionTracks(animator, previousTracks)
                task.wait()
            until os.clock() >= deadline
        end

        local function sendNativeFruitM1(tool, target, keepEquippedTool, attackGeneration, fruitGeneration)
            local char = character()
            local root = rootPart()
            local enemyRoot = modelRoot(target.Enemy)
            local hitPart = enemyHitPart(target.Enemy)
            local function lifecycleChanged()
                return character() ~= char
                    or (attackGeneration and state.AuraAttackGeneration ~= attackGeneration)
                    or (fruitGeneration and state.FruitDispatchGeneration ~= fruitGeneration)
            end
            if not char or not root or not enemyRoot or not hitPart then
                return false, "the fruit M1 target is unavailable"
            end
            local nativeDistance = (enemyRoot.Position - root.Position).Magnitude
            state.AuraFruitLastDistance = nativeDistance
            state.AuraFruitInRange = nativeDistance <= NATIVE_FRUIT_MAX_RANGE
            if not state.AuraFruitInRange then
                return false, "fruit-out-of-range"
            end
            if os.clock() < (state.FruitM1ReadyAt or 0) then
                return false, "fruit-cooldown"
            end

            local silentRemote = tool:FindFirstChild("LeftClickRemote", true)
            silentRemote = silentRemote and silentRemote:IsA("RemoteEvent") and silentRemote or nil

            if silentRemote then
                if lifecycleChanged() then
                    return false, "the attack lifecycle changed before Fruit M1"
                end
                -- Solix-compatible native Fruit M1: fire the Backpack remote
                -- with the full 3D direction and combo 1. Flattening Y made
                -- attacks from above miss, cycling 1-5 introduced the long
                -- fifth-hit cooldown, and a third argument changed the native
                -- request shape. The equipped Sword never leaves Character.
                local comboKey = string.lower(tool.Name)
                local direction = enemyRoot.Position - root.Position
                if direction.Magnitude < 0.05 then
                    direction = root.CFrame.LookVector
                end
                local body = humanoid()
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {workspace._WorldOrigin, workspace.Characters, workspace.Enemies}
                local grounded = body and workspace:Raycast(
                    root.Position,
                    -(body.HipHeight + root.Size.Y * 0.5 + 4) * Vector3.yAxis,
                    params
                ) ~= nil or false
                local fired, fireError = pcall(function()
                    -- Match the live Fruit LocalScript exactly: direction,
                    -- combo index, then the player-on-ground boolean.
                    silentRemote:FireServer(direction.Unit, 1, grounded)
                end)
                if not fired then
                    return false, fireError
                end
                state.NativeFruitCombos[comboKey] = 1
                state.FruitM1ReadyAt = os.clock() + DoubleAttackEngine.FruitCadence
                state.AuraStage = "silent-fruit-m1-sent"
                return true
            end

            local originalParent = tool.Parent
            if keepEquippedTool then
                -- Parent the fruit beside the Sword instead of asking the
                -- Humanoid to equip it. The Sword never leaves Character.
                if tool.Parent ~= char then
                    tool.Parent = char
                    task.wait()
                end
            else
                local _, changed = equipTool(tool)
                if changed then
                    task.wait(0.04)
                end
            end
            if lifecycleChanged() then
                if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                    tool.Parent = originalParent
                end
                return false, "the attack lifecycle changed before Fruit activation"
            end
            if tool.Parent ~= char then
                return false, "the fruit Tool could not be armed"
            end

            local originalRootCFrame = root.CFrame
            local animator, previousTracks = playingTrackSet()

            -- Other native fruit controllers still need Tool.Activate. Keep the
            -- player at the current Mob Aura position only to cancel a local
            -- dash; the enemy is never written to or moved.
            if not state.Alive or not state.AuraKill or not modelAlive(target.Enemy) then
                if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                    tool.Parent = originalParent
                end
                return false, "the fruit M1 target left before activation"
            end

            if type(FruitMouse) ~= "table" then
                if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                    tool.Parent = originalParent
                end
                return false, "the native fruit mouse controller is unavailable"
            end

            state.AuraFruitBusy = true
            local oldHit = FruitMouse.Hit
            local oldTarget = FruitMouse.Target
            FruitMouse.Hit = CFrame.new(hitPart.Position)
            FruitMouse.Target = hitPart
            local activated, activationError = pcall(function()
                tool:Activate()
                tool:Deactivate()
            end)
            FruitMouse.Hit = oldHit
            FruitMouse.Target = oldTarget
            if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                tool.Parent = originalParent
            end
            if not activated then
                root.CFrame = originalRootCFrame
                if not lifecycleChanged() then
                    state.AuraFruitBusy = false
                end
                return false, activationError
            end

            state.AuraStage = "native-fruit-m1-sent"
            -- Fruit M1 LocalScripts often add a short dash and Action animation.
            -- Pinning only the original player position and stopping newly
            -- started Action tracks preserves the no-swing/no-movement Aura.
            holdRoot(root, originalRootCFrame, NATIVE_FRUIT_SETTLE_TIME, animator, previousTracks)
            if lifecycleChanged() then
                return false, "the Fruit lifecycle changed during activation"
            end
            state.AuraFruitBusy = false
            return true
        end

        function DoubleAttackEngine.SendFruit(tool, fruitGeneration)
            local root = rootPart()
            local targets = DoubleAttackEngine.Targets(DoubleAttackEngine.FruitTargetLimit)
            if fruitGeneration and state.FruitDispatchGeneration ~= fruitGeneration then
                return false, "the Fruit dispatch lifecycle changed"
            end
            if not tool then
                return false, "No Blox Fruit Tool was found"
            end
            if not root or #targets == 0 then
                return false, "No enemy is inside Fruit M1 range"
            end

            local silentRemote = tool:FindFirstChild("LeftClickRemote", true)
            silentRemote = silentRemote and silentRemote:IsA("RemoteEvent") and silentRemote or nil
            if silentRemote then
                local comboKey = string.lower(tool.Name)
                local sent = 0
                local closestDistance = math.huge
                local body = humanoid()
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {workspace._WorldOrigin, workspace.Characters, workspace.Enemies}
                local grounded = body and workspace:Raycast(
                    root.Position,
                    -(body.HipHeight + root.Size.Y * 0.5 + 4) * Vector3.yAxis,
                    params
                ) ~= nil or false
                for _, target in ipairs(targets) do
                    if fruitGeneration and state.FruitDispatchGeneration ~= fruitGeneration then
                        return false, "the Fruit dispatch lifecycle changed"
                    end
                    local enemyRoot = modelRoot(target.Enemy)
                    if enemyRoot and modelAlive(target.Enemy) then
                        local direction = enemyRoot.Position - root.Position
                        if direction.Magnitude < 0.05 then
                            direction = root.CFrame.LookVector
                        end
                        if direction.Magnitude >= 0.05 then
                            silentRemote:FireServer(direction.Unit, 1, grounded)
                            sent += 1
                            closestDistance = math.min(closestDistance, target.Distance)
                        end
                    end
                end
                if sent == 0 then
                    return false, "the fruit M1 targets left Aura range"
                end
                state.NativeFruitCombos[comboKey] = 1
                state.AuraFruitLastDistance = closestDistance
                state.AuraFruitInRange = true
                state.AuraStage = sent > 1 and "double-fruit-multi-sent" or "double-fruit-sent"
                return true, nil, sent
            end

            -- Fruits without a direct click remote retain the native fallback.
            -- It temporarily arms the Fruit beside the Sword, restores it, and
            -- suppresses the local dash/animation without moving the enemy.
            local sent, sendError = sendNativeFruitM1(tool, targets[1], true, nil, fruitGeneration)
            return sent, sendError, sent and 1 or 0
        end

        function DoubleAttackEngine.SendDragonstorm()
            if state.DragonstormOwned == nil
                or os.clock() - state.LastDragonstormOwnershipCheck >= 5 then
                state.LastDragonstormOwnershipCheck = os.clock()
                state.DragonstormOwned = false
                if CommF then
                    local checked, inventory = pcall(function()
                        return CommF:InvokeServer("getInventoryWeapons")
                    end)
                    if checked and type(inventory) == "table" then
                        for _, item in pairs(inventory) do
                            if type(item) == "table"
                                and string.lower(tostring(item.Name)) == "dragonstorm" then
                                state.DragonstormOwned = true
                                break
                            end
                        end
                    end
                end
                gui:SetAttribute("BloxDragonstormServerOwned", state.DragonstormOwned)
            end
            if not state.DragonstormOwned then
                return false, "Dragonstorm is not owned in the server inventory; visual copies cannot deal damage"
            end
            local gun = toolForSelection("Gun")
            local root = rootPart()
            local targets = DoubleAttackEngine.Targets(1)
            if not gun or not string.find(string.lower(gun.Name), "dragonstorm", 1, true) then
                return false, "Dragonstorm is not loaded in the Backpack"
            end
            if not ShootGunEvent then
                return false, "ShootGunEvent is unavailable"
            end
            if not root or #targets == 0 then
                return false, "No enemy is inside Dragonstorm tracking range"
            end
            local target = targets[1]
            local hitPart = target.HitPart
            local char = character()
            local originalParent = gun.Parent
            if not char or not hitPart or not hitPart.Parent then
                return false, "Dragonstorm target became invalid"
            end

            -- The live HitscanSingleShot client sends TargetPosition followed by
            -- a list of hit limbs. Parent the Gun beside the visible Sword long
            -- enough for server ownership validation; never Humanoid-equip it.
            if gun.Parent ~= char then
                gun.Parent = char
                RunService.Heartbeat:Wait()
            end
            local fired, fireError = pcall(function()
                ShootGunEvent:FireServer(hitPart.Position, {hitPart})
            end)
            task.wait(0.02)
            if originalParent and gun.Parent ~= originalParent then
                gun.Parent = originalParent
            end
            local sword = toolForSelection("Sword")
            if sword then
                equipTool(sword)
            end
            return fired, fireError, fired and 1 or 0
        end

        function DoubleAttackEngine.StepFruit()
            if state.FruitDispatchPending then
                if os.clock() - (state.FruitDispatchPendingAt or 0) < 1 then
                    return false
                end
                state.FruitDispatchGeneration += 1
                state.FruitDispatchPending = false
                state.FruitDispatchPendingAt = 0
                state.AuraFruitBusy = false
            end
            if not state.Alive
                or not state.AuraKill
                or not state.DoubleAttack
                or state.ExperimentalAttackOverride
                or state.InventoryBusy
                or state.FruitDispatchPending then
                return false
            end
            if not busoActive() then
                ensureBuso(true)
                if state.BusoOwned ~= false then
                    return false
                end
            end

            local now = os.clock()
            local cadence = DoubleAttackEngine.FruitCadence
                + math.max(tonumber(state.AttackInterval) or 0, 0)
            if now - (state.LastDoubleFruitAttack or 0) < cadence then
                return false
            end
            if #DoubleAttackEngine.Targets(1) == 0 then
                return false
            end

            local sword = toolForSelection("Sword")
            local fruit = toolForSelection("M1 Fruit")
            if not sword or not fruit then
                return false
            end
            equipTool(sword)
            state.LastDoubleFruitAttack = now
            state.FruitDispatchGeneration += 1
            local fruitGeneration = state.FruitDispatchGeneration
            state.FruitDispatchPending = true
            state.FruitDispatchPendingAt = os.clock()
            task.spawn(function()
                local operationOk, sent, message, sentCount = pcall(
                    DoubleAttackEngine.SendFruit,
                    fruit,
                    fruitGeneration
                )
                if state.FruitDispatchGeneration ~= fruitGeneration then
                    return
                end
                if operationOk and sent then
                    sentCount = math.max(tonumber(sentCount) or 1, 1)
                    state.AuraFruitRequests += sentCount
                    state.AuraRequests += sentCount
                else
                    local failure = operationOk and message or sent
                    local failureText = tostring(failure)
                    if not failureText:find("No enemy", 1, true)
                        and failure ~= "fruit-cooldown"
                        and not transientAuraMiss(failure) then
                        state.AuraPendingError = "Fruit M1 failed: " .. failureText
                    end
                end
                state.FruitDispatchPending = false
                state.FruitDispatchPendingAt = 0
            end)
            return true
        end

        local function auraKillOnce()
            if state.AuraAttackPending then
                if os.clock() - (state.AuraAttackPendingAt or 0) < 1 then
                    return false
                end
                state.AuraAttackGeneration += 1
                state.AuraAttackPending = false
                state.AuraAttackPendingAt = 0
                state.RegisterHitClosure = nil
                state.LastRegisterHitResolve = -math.huge
                if not state.FruitDispatchPending then
                    state.AuraFruitBusy = false
                end
                state.AuraStage = "pending-timeout-recovered"
            end
            if not state.AuraKill or state.InventoryBusy
                or state.ExperimentalAttackOverride then
                return false
            end
            local attackGeneration = state.AuraAttackGeneration
            if not busoActive() then
                ensureBuso(true)
                if state.BusoOwned ~= false then
                    state.AuraStage = "waiting-for-buso"
                    return false
                end
                state.AuraStage = "starter-no-buso"
            end
            local now = os.clock()
            if now - state.LastAuraScan < 0.04 then
                return false
            end
            state.LastAuraScan = now

            local targets = nearbyAuraTargets()
            state.AuraTargetCount = #targets
            if #targets == 0 then
                state.AuraTargetCursor = 0
                state.AuraMultiTargetCount = 0
                return false
            end

            state.AuraTargetCursor = (state.AuraTargetCursor % #targets) + 1
            local target = targets[state.AuraTargetCursor]
            local attackTargets = {target}
            if state.DoubleAttack then
                -- Double Attack mirrors the Dungeon engine: every eligible
                -- nearby rig is part of the same Sword window even when Multi
                -- Grab is off. Fruit independently covers its nearest three.
                attackTargets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
                target = attackTargets[1] or target
            elseif (state.GatherEnemies or (
                state.RaidMultiGrab
                and state.AutoRaid
                and LocalPlayer:GetAttribute("IslandRaiding") == true
            )) and #targets > 1 then
                attackTargets = {}
                -- Explicit Multi Grab and raids use the bundled two-rig window.
                -- Auto Magnet deliberately stays out of this branch: normal
                -- Aura rotates its selected target through the dragged pile,
                -- so Magnet works whether Double Attack is on or off.
                local multiLimit = math.min(#targets, MULTI_ATTACK_TARGET_LIMIT)
                for offset = 0, multiLimit - 1 do
                    local index = ((state.AuraTargetCursor - 1 + offset) % #targets) + 1
                    table.insert(attackTargets, targets[index])
                end
                target = attackTargets[1]
            end
            state.AuraMultiTargetCount = #attackTargets
            local extraDelay = math.max(tonumber(state.AttackInterval) or 0, 0)
            local plan = {Double = state.DoubleAttack}

            if state.DoubleAttack then
                plan.Sword = toolForSelection("Sword")
                plan.Fruit = toolForSelection("M1 Fruit")
                if not plan.Sword or not plan.Fruit then
                    state.AuraPendingError = "Double Attack requires both a Sword and a Blox Fruit Tool"
                    return false
                end
                plan.SwordData = weaponDataForTool(plan.Sword)
                if not hasRegisteredBasicMoveset(plan.SwordData) then
                    state.AuraPendingError = "Double Attack could not resolve the Sword M1 moveset"
                    return false
                end
                local _, swordChanged = equipTool(plan.Sword)
                if swordChanged then
                    task.wait(0.04)
                end
                local swordProfile, swordError = DoubleAttackEngine.SwordProfile(plan.Sword, plan.SwordData)
                if not swordProfile then
                    state.AuraPendingError = "Double Attack could not read the Sword: " .. tostring(swordError)
                    return false
                end
                plan.SwordProfile = swordProfile
                plan.FruitData = weaponDataForTool(plan.Fruit)
                plan.FruitRegistered = isFruitWeaponType(weaponTypeForTool(plan.Fruit, plan.FruitData))
                    and hasRegisteredBasicMoveset(plan.FruitData)
                plan.Cadence = AURA_KILL_HIT_DELAY + extraDelay
                state.AuraWeaponName = plan.Sword.Name .. " + " .. plan.Fruit.Name
                state.AuraWeaponType = "Sword + Blox Fruit"
                state.AuraAttackMode = "Double Attack"
            else
                plan.Tool = selectedTool()
                if not plan.Tool then
                    state.AuraPendingError = "No " .. tostring(state.WeaponType) .. " Tool was found"
                    return false
                end
                plan.WeaponData = weaponDataForTool(plan.Tool)
                plan.WeaponType = weaponTypeForTool(plan.Tool, plan.WeaponData)
                plan.NativeFruit = isFruitWeaponType(plan.WeaponType)
                    and not hasRegisteredBasicMoveset(plan.WeaponData)
                if not plan.NativeFruit then
                    if not hasRegisteredBasicMoveset(plan.WeaponData) then
                        state.AuraPendingError = "The selected Tool has no M1 attack moveset"
                        return false
                    end
                    if string.lower(plan.WeaponType) == "gun" then
                        state.AuraPendingError = "Aura Kill needs a Sword, Melee, or M1 Fruit Tool"
                        return false
                    end
                    local _, toolChanged = equipTool(plan.Tool)
                    if toolChanged then
                        task.wait(0.04)
                    end
                    local profileError
                    plan.Profile, profileError = auraAttackProfile(plan.Tool, plan.WeaponData)
                    if not plan.Profile then
                        state.AuraPendingError = "Aura Kill could not read the equipped Tool: " .. tostring(profileError)
                        return false
                    end
                    plan.Cadence = registeredAttackCadence(plan.Profile) + extraDelay
                    state.AuraAttackMode = isFruitWeaponType(plan.WeaponType)
                        and "Registered Fruit M1" or "Registered " .. plan.WeaponType
                else
                    plan.Cadence = nativeFruitAttackCadence() + extraDelay
                    state.AuraAttackMode = "Native Fruit M1"
                end
                updateAuraWeaponState(plan.Tool, state.AuraAttackMode)
            end

            if now - state.LastAttack < plan.Cadence then
                return false
            end
            if state.AuraAttackGeneration ~= attackGeneration then
                return false
            end

            state.AuraAttackGeneration += 1
            attackGeneration = state.AuraAttackGeneration
            state.AuraAttackPending = true
            state.AuraAttackPendingAt = os.clock()
            state.LastAttack = now
            state.AuraStage = state.DoubleAttack and "double-queued" or "queued"
            state.AuraLastRequestAt = now
            state.CurrentEnemyName = normalizeEnemyName(target.Enemy.Name)
            state.AuraLastDistance = target.Distance

            local healthBefore = {}
            for _, attackTarget in ipairs(attackTargets) do
                local targetHumanoid = attackTarget.Enemy:FindFirstChildOfClass("Humanoid")
                if targetHumanoid then
                    healthBefore[targetHumanoid] = targetHumanoid.Health
                end
            end
            local dispatched = 0
            local fruitOutOfRange = false
            local hitOk, hitError = pcall(function()
                if plan.Double then
                    local swordSent, swordSendError, swordHitCount = DoubleAttackEngine.SendSword(
                        plan.Sword,
                        plan.SwordData,
                        plan.SwordProfile,
                        attackGeneration
                    )
                    if not swordSent then
                        if transientAuraMiss(swordSendError) then
                            state.AuraStage = "target-left-before-hit"
                            return
                        end
                        error("Sword M1 failed: " .. tostring(swordSendError))
                    end
                    swordHitCount = math.max(tonumber(swordHitCount) or 1, 1)
                    dispatched += swordHitCount
                    state.AuraSwordRequests += swordHitCount
                elseif plan.NativeFruit then
                    local sent, sendError = sendNativeFruitM1(plan.Tool, target, nil, attackGeneration)
                    if not sent then
                        if sendError == "fruit-out-of-range" then
                            fruitOutOfRange = true
                            state.AuraStage = "fruit-out-of-range"
                            return
                        end
                        if sendError == "fruit-cooldown" then
                            state.AuraStage = "fruit-cooldown"
                            return
                        end
                        if transientAuraMiss(sendError) then
                            state.AuraStage = "target-left-before-fruit"
                            return
                        end
                        error(sendError)
                    end
                    dispatched = 1
                    state.AuraFruitRequests += 1
                else
                    local sent, sendError, registeredCount = sendRegisteredAuraHit(
                        plan.Tool,
                        plan.WeaponData,
                        target,
                        plan.Profile,
                        attackTargets,
                        attackGeneration
                    )
                    if not sent then
                        if transientAuraMiss(sendError) then
                            state.AuraStage = "target-left-before-hit"
                            return
                        end
                        error(sendError)
                    end
                    registeredCount = math.max(tonumber(registeredCount) or 1, 1)
                    dispatched = registeredCount
                    if isFruitWeaponType(plan.WeaponType) then
                        state.AuraFruitRequests += registeredCount
                    elseif string.lower(plan.WeaponType) == "sword" then
                        state.AuraSwordRequests += registeredCount
                    end
                end
            end)
            if state.AuraAttackGeneration ~= attackGeneration then
                return false
            end
            state.AuraAttackPending = false
            state.AuraAttackPendingAt = 0
            state.AuraRequests += dispatched
            if not hitOk then
                if plan.Double or not plan.NativeFruit then
                    state.RegisterHitClosure = nil
                    state.LastRegisterHitResolve = -math.huge
                end
                state.AuraPendingError = "Aura Kill attack failed: " .. tostring(hitError)
                state.AuraStage = "error"
                return false
            end
            if dispatched == 0 then
                state.AuraStage = fruitOutOfRange and "fruit-out-of-range" or "target-left-range"
                return false
            end

            task.delay(0.35, function()
                local damaged = 0
                if state.Alive then
                    for targetHumanoid, before in pairs(healthBefore) do
                        if targetHumanoid.Parent and targetHumanoid.Health < before then
                            damaged += 1
                        end
                    end
                end
                if damaged > 0 then
                    state.AuraHits += damaged
                    state.AuraLastHitAt = os.clock()
                end
                state.AuraStage = "idle"
            end)
            return true
        end

        local function stepMobAuraTp()
            local selectedMode = state.SelectedMobFarm
            if (not state.MobAuraTp and not selectedMode) or state.AuraFruitBusy then
                return false
            end
            local root = rootPart()
            if not root then
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                return false
            end

            local selectedName = selectedMode and state.SelectedMobName or nil
            if selectedMode and (not selectedName or selectedName == "None") then
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                return false
            end
            local searchRange = selectedMode and state.SelectedMobSearchRange or state.MobAuraSearchRange

            local target = state.MobAuraTarget
            local targetRoot = modelRoot(target)
            if not targetRoot or not modelAlive(target)
                or (selectedMode and not enemyMatches(target, selectedName))
                or (targetRoot.Position - root.Position).Magnitude > searchRange then
                target = nil
            end
            if not target then
                local nearest, distance = nearestEnemy(selectedName, not selectedMode)
                state.MobAuraPreTeleportDistance = distance
                if not nearest or not distance or distance > searchRange then
                    state.MobAuraTarget = nil
                    state.MobAuraTargetName = nil
                    state.MobAuraAnchorTarget = nil
                    state.MobAuraStableAnchor = nil
                    state.MobAuraDistance = distance ~= math.huge and distance or nil
                    if selectedMode then
                        state.CurrentEnemyName = selectedName
                        local spawn, spawnDistance = nearestEnemySpawn(selectedName)
                        state.SelectedMobWaitingAtSpawn = spawn ~= nil
                        if spawn then
                            local height = math.clamp(state.MobAuraHeight, 3, AURA_KILL_MAX_RANGE - 10)
                            local goalPosition = spawn.Position + Vector3.new(
                                state.FarmPositionX,
                                height,
                                state.FarmPositionZ
                            )
                            moveTo(CFrame.new(goalPosition))
                            state.MobAuraDistance = spawnDistance
                            return true
                        end
                    else
                        state.SelectedMobWaitingAtSpawn = false
                    end
                    return false
                end
                if nearest ~= state.MobAuraTarget then
                    state.MobAuraOrbitStartedAt = os.clock()
                    state.MobAuraOrbitStartAngle = math.random() * math.pi * 2
                    state.MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1
                end
                target = nearest
                state.MobAuraTarget = target
                targetRoot = modelRoot(target)
            end
            if not targetRoot then
                return false
            end

            local liveAnchor = targetRoot.Position
            local singleFallback = state.GatherSingleFallbackEnemy == target
                and modelAlive(state.GatherSingleFallbackEnemy)
            local fixedPosition = not state.MobAuraOrbit and not state.MobAuraRandomSquare
            if singleFallback then
                state.MobAuraAnchorTarget = target
                state.MobAuraStableAnchor = liveAnchor
            elseif state.MobAuraAnchorTarget ~= target then
                state.MobAuraAnchorTarget = target
                -- A replacement target may already be inside the grabbed pile.
                -- Retain the original ground anchor across target swaps or the
                -- new, raised NPC position feeds height back into the player.
                if not state.GatherEnemies or not state.MobAuraStableAnchor then
                    state.MobAuraStableAnchor = liveAnchor
                end
            elseif (not state.GatherEnemies and not fixedPosition) or not state.MobAuraStableAnchor then
                state.MobAuraStableAnchor = liveAnchor
            end
            if fixedPosition and state.MobAuraStableAnchor then
                local reacquireDistance = math.max(
                    12,
                    math.min(50, (tonumber(state.AuraRange) or 70) * 0.65)
                )
                if (liveAnchor - state.MobAuraStableAnchor).Magnitude > reacquireDistance then
                    state.MobAuraStableAnchor = liveAnchor
                end
            end
            -- Once Multi Grab moves the target underneath the player, keep
            -- using its original ground anchor. Following the moved NPC would
            -- add MobAuraHeight again every frame and launch the player upward.
            local anchor = ((state.GatherEnemies and not singleFallback) or fixedPosition)
                and state.MobAuraStableAnchor or liveAnchor
            local height = math.clamp(state.MobAuraHeight, 3, AURA_KILL_MAX_RANGE - 10)
            local orbitOffset = Vector3.zero
            if state.MobAuraRandomSquare then
                local now = os.clock()
                local interval = math.max(0.06, tonumber(state.MobAuraSquareInterval) or 0.18)
                if state.MobAuraLastSquareStep == 0 or now - state.MobAuraLastSquareStep >= interval then
                    local size = math.max(2, tonumber(state.MobAuraSquareSize) or 8)
                    local nextCorner = math.random(1, 4)
                    if nextCorner == state.MobAuraSquareCorner then
                        nextCorner = nextCorner % 4 + 1
                    end
                    local corners = {
                        Vector3.new(-size, 0, -size),
                        Vector3.new(size, 0, -size),
                        Vector3.new(size, 0, size),
                        Vector3.new(-size, 0, size),
                    }
                    state.MobAuraSquareCorner = nextCorner
                    state.MobAuraSquareOffset = corners[nextCorner]
                    state.MobAuraLastSquareStep = now
                end
                orbitOffset = state.MobAuraSquareOffset
            elseif state.MobAuraOrbit then
                local elapsed = os.clock() - state.MobAuraOrbitStartedAt
                local angle = state.MobAuraOrbitStartAngle
                    + elapsed * math.rad(state.MobAuraOrbitSpeed) * state.MobAuraOrbitDirection
                orbitOffset = Vector3.new(
                    math.cos(angle) * state.MobAuraOrbitRadius,
                    0,
                    math.sin(angle) * state.MobAuraOrbitRadius
                )
            end
            local facing = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
            if facing.Magnitude < 0.05 then
                facing = Vector3.new(0, 0, -1)
            else
                facing = facing.Unit
            end
            local facingBasis = CFrame.lookAt(Vector3.zero, facing)
            local fixedOffset = facingBasis:VectorToWorldSpace(Vector3.new(
                state.FarmPositionX,
                0,
                state.FarmPositionZ
            ))
            local goalPosition = anchor + Vector3.new(0, height, 0) + fixedOffset + orbitOffset

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if (state.MobAuraOrbit or state.MobAuraRandomSquare) and orbitOffset.Magnitude > 0.05 then
                cancelMove()
                root.CFrame = CFrame.lookAt(
                    goalPosition,
                    Vector3.new(anchor.X, goalPosition.Y, anchor.Z)
                )
            else
                moveTo(CFrame.lookAt(goalPosition, goalPosition + facing))
            end
            state.MobAuraTargetName = normalizeEnemyName(target.Name)
            state.MobAuraDistance = (targetRoot.Position - root.Position).Magnitude
            state.SelectedMobWaitingAtSpawn = false
            state.CurrentEnemyName = state.MobAuraTargetName
            return true
        end

        local function flushAuraTelemetry()
            gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
            gui:SetAttribute("BloxAuraKillTargets", state.AuraTargetCount)
            gui:SetAttribute("BloxAuraMultiTargetCount", state.AuraMultiTargetCount)
            gui:SetAttribute("BloxAuraKillStage", state.AuraStage)
            gui:SetAttribute("BloxAuraKillRequestCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraKillHitCount", state.AuraHits)
            gui:SetAttribute("BloxAuraSwordRequestCount", state.AuraSwordRequests)
            gui:SetAttribute("BloxAuraFruitRequestCount", state.AuraFruitRequests)
            gui:SetAttribute("BloxAttackCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraWeaponSelection", state.WeaponType)
            gui:SetAttribute("BloxAuraWeaponName", state.AuraWeaponName or "")
            gui:SetAttribute("BloxAuraWeaponType", state.AuraWeaponType or "")
            gui:SetAttribute("BloxAuraAttackMode", state.AuraAttackMode or "")
            gui:SetAttribute("BloxDoubleAttack", state.DoubleAttack)
            gui:SetAttribute("BloxFruitM1CooldownReduction", state.FruitM1CooldownReduction)
            gui:SetAttribute(
                "BloxAuraFruitNativeRange",
                state.DoubleAttack and DoubleAttackEngine.HitRange or NATIVE_FRUIT_MAX_RANGE
            )
            gui:SetAttribute("BloxAuraFruitInRange", state.AuraFruitInRange == true)
            gui:SetAttribute("BloxAuraFruitLastDistance", state.AuraFruitLastDistance or 0)
            if state.CurrentEnemyName then
                gui:SetAttribute("BloxAuraKillLastTarget", state.CurrentEnemyName)
            end
            if state.AuraLastDistance then
                gui:SetAttribute("BloxAuraKillLastDistance", state.AuraLastDistance)
            end
            if state.AuraLastRequestAt then
                gui:SetAttribute("BloxAuraKillLastRequestAt", state.AuraLastRequestAt)
                gui:SetAttribute("BloxLastAttackAt", state.AuraLastRequestAt)
            end
            if state.AuraLastHitAt then
                gui:SetAttribute("BloxAuraKillLastHitAt", state.AuraLastHitAt)
            end
            gui:SetAttribute("BloxMobAuraTp", state.MobAuraTp)
            gui:SetAttribute("BloxSelectedMobFarm", state.SelectedMobFarm)
            gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            gui:SetAttribute("BloxSelectedMobWaitingAtSpawn", state.SelectedMobWaitingAtSpawn)
            gui:SetAttribute("BloxMobAuraMode", state.SelectedMobFarm and "Selected" or (state.MobAuraTp and "Nearest" or "Off"))
            gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            gui:SetAttribute("BloxMobAuraOrbit", state.MobAuraOrbit)
            gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            gui:SetAttribute("BloxMobAuraOrbitDirection", state.MobAuraOrbitDirection)
            gui:SetAttribute("BloxMobAuraRandomSquare", state.MobAuraRandomSquare)
            gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            gui:SetAttribute("BloxMobAuraTarget", state.MobAuraTargetName or "")
            gui:SetAttribute("BloxMobAuraDistance", state.MobAuraDistance or 0)
            gui:SetAttribute("BloxMultiGrabEnemies", state.GatherEnemies)
            gui:SetAttribute("BloxMultiGrabFilter", state.GatherMode)
            gui:SetAttribute("BloxMultiGrabEnemy", state.GatherSelectedMob)
            gui:SetAttribute("BloxMultiGrabLimit", MULTI_GRAB_LIMIT)
            gui:SetAttribute("BloxMultiGrabRange", MULTI_GRAB_RANGE)
            gui:SetAttribute("BloxMultiGrabCount", state.Gathered)
            gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
            gui:SetAttribute("BloxRaidMultiGrabCount", state.RaidGathered)
            gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
            gui:SetAttribute("BloxRaidVoidActive", state.RaidVoidActive)
            gui:SetAttribute("BloxRaidVoidMoved", state.RaidVoidMoved)
            gui:SetAttribute("BloxRaidVoidStaged", state.RaidVoidStaged)
            gui:SetAttribute("BloxRaidVoidKillCount", state.RaidVoidKillCount)
            gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
            gui:SetAttribute(
                "BloxMultiGrabSingleFallback",
                state.GatherSingleFallbackEnemy and normalizeEnemyName(state.GatherSingleFallbackEnemy.Name) or ""
            )
            gui:SetAttribute("BloxSelectedLevelQuest", state.SelectedLevelQuest)
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
            gui:SetAttribute("BloxBossVerticalLocked", state.AutoBoss and state.PositionLockVertical)
            gui:SetAttribute("BloxBossAnchorY", state.PositionAnchorY or 0)
            gui:SetAttribute("BloxAutoGacha", state.AutoGacha)
            gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            gui:SetAttribute("BloxGachaBusy", state.GachaBusy)
            gui:SetAttribute("BloxGachaRollCount", state.GachaRolls)
            gui:SetAttribute("BloxGachaStatus", state.GachaStatus)
            gui:SetAttribute("BloxAutoStoreFruit", state.AutoStoreFruit)
            gui:SetAttribute("BloxFruitStoreBusy", state.InventoryBusy)
            gui:SetAttribute("BloxFruitStoredCount", state.FruitsStored)
            gui:SetAttribute("BloxFruitStoreStatus", state.StoreStatus)
            if state.AuraPendingError then
                local message = state.AuraPendingError
                state.AuraPendingError = nil
                setError(message)
            end
        end

        local function currentLevel()
            local data = LocalPlayer:FindFirstChild("Data")
            local level = data and data:FindFirstChild("Level")
            return level and tonumber(level.Value) or 0
        end

        local function currentPoints()
            local data = LocalPlayer:FindFirstChild("Data")
            local points = data and data:FindFirstChild("Points")
            return points and tonumber(points.Value) or 0
        end

        local function questNpcData(internalQuestName)
            local npcList = Guide and Guide.Data and Guide.Data.NPCList
            if type(npcList) ~= "table" then
                return nil
            end
            for _, data in pairs(npcList) do
                if type(data) == "table" and data.InternalQuestName == internalQuestName then
                    return data
                end
            end
            return nil
        end

        local AUTO_LEVEL_BEST_OPTION = "Best for My Level"
        local levelQuestByOption = {}

        local function questCandidate(internalName, index, quest)
            if type(quest) ~= "table" or type(quest.LevelReq) ~= "number" then
                return nil
            end
            local enemyName = type(quest.Task) == "table" and next(quest.Task) or nil
            if not enemyName then
                return nil
            end
            return {
                InternalName = internalName,
                Index = tonumber(index) or index,
                LevelReq = quest.LevelReq,
                DisplayName = tostring(quest.Name or enemyName),
                EnemyName = tostring(enemyName),
                Npc = questNpcData(internalName),
            }
        end

        local function bestQuest()
            local level = currentLevel()
            local best = nil
            for internalName, questList in pairs(Quests) do
                if type(questList) == "table" then
                    for index, quest in pairs(questList) do
                        local candidate = questCandidate(internalName, index, quest)
                        -- GuideModule only exposes quest givers from the current
                        -- sea. Requiring Npc prevents Auto Level from selecting a
                        -- higher-level quest whose giver exists in another sea.
                        local submerged = candidate
                            and string.find(candidate.InternalName, "SubmergedQuest", 1, true) == 1
                        if candidate and (candidate.Npc or submerged) and candidate.LevelReq <= level then
                            local candidateBoss = string.find(candidate.EnemyName, "Boss", 1, true) ~= nil
                            local bestBoss = best and string.find(best.EnemyName, "Boss", 1, true) ~= nil
                            if not best
                                or candidate.LevelReq > best.LevelReq
                                or (candidate.LevelReq == best.LevelReq and bestBoss and not candidateBoss) then
                                best = candidate
                            end
                        end
                    end
                end
            end
            return best
        end

        local function currentSeaQuestOptions()
            local options = {AUTO_LEVEL_BEST_OPTION}
            local candidates = {}
            local minimumLevel = math.huge
            local maximumLevel = 0
            table.clear(levelQuestByOption)
            for internalName, questList in pairs(Quests) do
                if type(questList) == "table" then
                    for index, quest in pairs(questList) do
                        local candidate = questCandidate(internalName, index, quest)
                        local submerged = candidate
                            and string.find(candidate.InternalName, "SubmergedQuest", 1, true) == 1
                        if candidate and (candidate.Npc or submerged) then
                            table.insert(candidates, candidate)
                            if candidate.LevelReq > 0 then
                                minimumLevel = math.min(minimumLevel, candidate.LevelReq)
                                maximumLevel = math.max(maximumLevel, candidate.LevelReq)
                            end
                        end
                    end
                end
            end
            table.sort(candidates, function(left, right)
                if left.LevelReq == right.LevelReq then
                    return string.lower(left.EnemyName) < string.lower(right.EnemyName)
                end
                return left.LevelReq < right.LevelReq
            end)
            for _, candidate in ipairs(candidates) do
                local label = string.format("Lv. %d | %s", candidate.LevelReq, candidate.EnemyName)
                if levelQuestByOption[label] then
                    label = string.format(
                        "Lv. %d | %s (%s:%s)",
                        candidate.LevelReq,
                        candidate.EnemyName,
                        candidate.InternalName,
                        tostring(candidate.Index)
                    )
                end
                levelQuestByOption[label] = candidate
                table.insert(options, label)
            end
            state.CurrentSeaQuestCount = #candidates
            state.CurrentSeaMinimumLevel = minimumLevel == math.huge and 0 or minimumLevel
            state.CurrentSeaMaximumLevel = maximumLevel
            if #candidates == 0 then
                state.CurrentSeaName = "Detecting"
            elseif maximumLevel <= 700 then
                state.CurrentSeaName = "First Sea"
            elseif state.CurrentSeaMinimumLevel >= 1500 then
                state.CurrentSeaName = "Third Sea"
            else
                state.CurrentSeaName = "Second Sea"
            end
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            return options
        end

        local function selectedLevelQuest()
            if state.SelectedLevelQuest == AUTO_LEVEL_BEST_OPTION then
                return bestQuest()
            end
            local selected = levelQuestByOption[state.SelectedLevelQuest]
            if not selected then
                currentSeaQuestOptions()
                selected = levelQuestByOption[state.SelectedLevelQuest]
            end
            return selected
        end

        state.IsSubmergedQuest = function(quest)
            return quest
                and type(quest.InternalName) == "string"
                and string.find(quest.InternalName, "SubmergedQuest", 1, true) == 1
        end

        state.IsAtSubmergedIsland = function()
            local data = LocalPlayer:FindFirstChild("Data")
            local lastSpawn = data and data:FindFirstChild("LastSpawnPoint")
            if lastSpawn and tostring(lastSpawn.Value) == "SubmergedIsland" then
                return true
            end
            local root = rootPart()
            return root ~= nil and root.Position.Y < -1200
        end

        state.StepSubmergedTravel = function()
            if state.IsAtSubmergedIsland() then
                state.SubmergedTravelRequestedAt = -math.huge
                gui:SetAttribute("BloxSubmergedTravelState", "Arrived")
                gui:SetAttribute("BloxSubmergedDialogueStage", "Complete")
                return false
            end

            local now = os.clock()
            if state.SubmergedTravelRequestedAt > 0 then
                local elapsed = now - state.SubmergedTravelRequestedAt
                if elapsed < 10 then
                    cancelMove(false)
                    setStatus("Waiting for the Submarine Worker transport", nil)
                    gui:SetAttribute("BloxSubmergedTravelState", "Awaiting underwater arrival")
                    return true
                end
                state.SubmergedTravelRequestedAt = -math.huge
                gui:SetAttribute("BloxSubmergedDialogueStage", "Retrying")
            end
            if not state.SubmarineWorkerSpeak and Net then
                state.SubmarineWorkerSpeak = Net:FindFirstChild("RF/SubmarineWorkerSpeak")
            end
            if not state.SubmarineWorkerSpeak then
                setError("Submarine Worker remote is unavailable")
                gui:SetAttribute("BloxSubmergedTravelState", "Remote unavailable")
                return true
            end

            local worldNpcs = workspace:FindFirstChild("NPCs")
            local replicatedNpcs = ReplicatedStorage:FindFirstChild("NPCs")
            local worker = (worldNpcs and worldNpcs:FindFirstChild("Submarine Worker"))
                or (replicatedNpcs and replicatedNpcs:FindFirstChild("Submarine Worker"))
            local root = rootPart()
            if not root then
                setError("Character is not ready for Submarine Worker travel")
                return true
            end

            local workerPosition = state.SubmarineWorkerFallback
            if worker then
                local pivotOk, pivot = pcall(function()
                    return worker:GetPivot()
                end)
                if pivotOk then
                    workerPosition = Vector3.new(
                        pivot.Position.X,
                        state.SubmarineWorkerFallback.Y,
                        pivot.Position.Z
                    )
                end
            end
            local distance = (Vector3.new(root.Position.X, 0, root.Position.Z)
                - Vector3.new(workerPosition.X, 0, workerPosition.Z)).Magnitude
            gui:SetAttribute("BloxSubmergedWorkerDistance", distance)
            if distance > 12 then
                moveTo(CFrame.new(workerPosition))
                setStatus("Traveling to the Submarine Worker", nil)
                gui:SetAttribute("BloxSubmergedTravelState", "Traveling to worker")
                gui:SetAttribute("BloxSubmergedDialogueStage", "Approaching NPC")
                return true
            end
            if not worker then
                setStatus("Waiting for the Submarine Worker to load", nil)
                gui:SetAttribute("BloxSubmergedTravelState", "Waiting for worker")
                gui:SetAttribute("BloxSubmergedDialogueStage", "Waiting for NPC")
                return true
            end

            if now - state.LastSubmergedTravel < 3 then
                setStatus("Waiting to speak with the Submarine Worker", nil)
                return true
            end
            state.LastSubmergedTravel = now
            cancelMove(false)
            local accessOk, unlocked = pcall(function()
                return state.SubmarineWorkerSpeak:InvokeServer("AskKilledTikiBoss")
            end)
            if not accessOk then
                setError("Submarine access check failed: " .. tostring(unlocked))
                gui:SetAttribute("BloxSubmergedTravelState", "Access check failed")
                return true
            end
            if unlocked == false then
                setError("Submerged Island is locked; defeat the required Tiki boss first")
                gui:SetAttribute("BloxSubmergedTravelState", "Locked")
                gui:SetAttribute("BloxSubmergedDialogueStage", "First Yes rejected")
                return true
            end

            gui:SetAttribute("BloxSubmergedDialogueStage", "First Yes confirmed")
            task.wait(0.2)

            local travelOk, result = pcall(function()
                return state.SubmarineWorkerSpeak:InvokeServer("TravelToSubmergedIsland")
            end)
            if not travelOk then
                setError("Submarine travel failed: " .. tostring(result))
                gui:SetAttribute("BloxSubmergedTravelState", "Travel failed")
                gui:SetAttribute("BloxSubmergedDialogueStage", "Second Yes failed")
                return true
            end
            state.ActiveFarmTarget = nil
            state.SubmergedTravelRequestedAt = os.clock()
            setStatus("Submarine Worker dialogue confirmed; waiting for transport", true)
            gui:SetAttribute("BloxSubmergedTravelState", "Transport requested")
            gui:SetAttribute("BloxSubmergedDialogueStage", "Second Yes confirmed")
            return true
        end

        local function questVisible()
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local main = playerGui and playerGui:FindFirstChild("Main")
            local quest = main and main:FindFirstChild("Quest")
            return quest and quest.Visible == true, quest
        end

        local function questMatches(questGui, enemyName)
            if not questGui then
                return false
            end
            local lowered = string.lower(normalizeEnemyName(enemyName))
            local sawText = false
            for _, descendant in ipairs(questGui:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Text ~= "" then
                    sawText = true
                    if string.find(string.lower(descendant.Text), lowered, 1, true) then
                        return true
                    end
                end
            end
            return not sawText
        end

        local function enemySpawn(enemyName)
            return nearestEnemySpawn(enemyName)
        end

        local function stepAutoLevel()
            state.ActiveFarmHeightOverride = nil
            local quest = selectedLevelQuest()
            if not quest then
                state.ActiveFarmTarget = nil
                setError("Choose a valid quest available in this sea")
                return
            end
            state.CurrentQuestName = quest.DisplayName
            state.CurrentEnemyName = quest.EnemyName
            questLabel.Text = string.format("Quest: %s (Lv. %s)", quest.DisplayName, tostring(quest.LevelReq))

            if state.IsSubmergedQuest(quest) and state.StepSubmergedTravel() then
                return
            end
            if state.IsSubmergedQuest(quest) and not quest.Npc then
                quest.Npc = questNpcData(quest.InternalName)
            end

            local visible, questGui = questVisible()
            if visible and not questMatches(questGui, quest.EnemyName) then
                if os.clock() - state.LastQuestRequest >= 1 then
                    state.LastQuestRequest = os.clock()
                    invoke("AbandonQuest")
                end
                return
            end

            if not visible then
                local npcPosition = quest.Npc and quest.Npc.Position
                if typeof(npcPosition) ~= "Vector3" then
                    setError("Quest giver data is still loading")
                    return
                end
                local root = rootPart()
                local target = CFrame.new(npcPosition + Vector3.new(0, 3, 0))
                moveTo(target)
                if root and (root.Position - npcPosition).Magnitude <= 18 and os.clock() - state.LastQuestRequest >= 1 then
                    state.LastQuestRequest = os.clock()
                    local ok, result = invoke("StartQuest", quest.InternalName, quest.Index)
                    setStatus(ok and ("Started " .. quest.DisplayName) or tostring(result), ok)
                end
                return
            end

            -- Keep one living target until it dies. Re-running nearestEnemy on
            -- every farm tick made equally-close NPCs trade places as the
            -- winner, so the character visibly ping-ponged while attacking.
            local enemy = state.ActiveFarmTarget
            local enemyRoot = modelRoot(enemy)
            if not modelAlive(enemy) or not enemyMatches(enemy, quest.EnemyName) or not enemyRoot then
                enemy = nil
            end
            local activeRoot = rootPart()
            local distance = enemy and activeRoot and (enemyRoot.Position - activeRoot.Position).Magnitude or nil
            if not enemy then
                enemy, distance = nearestEnemy(quest.EnemyName, false)
            end
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = false
                targetLabel.Text = string.format("Target: %s | %.0f studs", normalizeEnemyName(enemy.Name), distance or 0)
                if safeModeRetreat(enemy) then
                    return
                end
                syncFarmAuraRange()
                local targetCFrame = positionAtEnemy(enemy)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                setStatus("Farming " .. normalizeEnemyName(enemy.Name), true)
                return
            end

            state.ActiveFarmTarget = nil
            local spawn = enemySpawn(quest.EnemyName)
            if spawn then
                targetLabel.Text = "Target: Waiting at " .. normalizeEnemyName(spawn.Name) .. " spawn"
                moveTo(CFrame.new(spawn.Position + Vector3.new(
                    state.FarmPositionX,
                    math.max(5, state.MobAuraHeight),
                    state.FarmPositionZ
                )))
                setStatus("Waiting for quest enemies to spawn", nil)
            else
                setError("Enemy spawn data is still loading")
            end
        end

        local function bossNames()
            local names = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if spawns then
                for _, descendant in ipairs(spawns:GetDescendants()) do
                    if descendant:IsA("BasePart") and string.find(descendant.Name, "[Boss]", 1, true) then
                        local name = normalizeEnemyName(descendant.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(names, name)
                        end
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    if string.find(enemy.Name, "[Boss]", 1, true) then
                        local name = normalizeEnemyName(enemy.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(names, name)
                        end
                    end
                end
            end
            table.sort(names, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return names
        end

        local function stepBossFarm()
            state.ActiveFarmHeightOverride = nil
            if state.SelectedBoss == "None" then
                state.ActiveFarmTarget = nil
                setError("Choose a boss first")
                return
            end
            state.CurrentEnemyName = state.SelectedBoss
            local enemy = state.ActiveFarmTarget
            local enemyRoot = modelRoot(enemy)
            if not modelAlive(enemy) or not enemyMatches(enemy, state.SelectedBoss) or not enemyRoot then
                enemy = nil
            end
            local activeRoot = rootPart()
            local distance = enemy and activeRoot and (enemyRoot.Position - activeRoot.Position).Magnitude or nil
            if not enemy then
                enemy, distance = nearestEnemy(state.SelectedBoss, false)
            end
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = true
                targetLabel.Text = string.format("Boss: %s | %.0f studs", state.SelectedBoss, distance or 0)
                if safeModeRetreat(enemy) then
                    return
                end
                syncFarmAuraRange()
                local targetCFrame = positionAtEnemy(enemy, true)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                setStatus("Farming boss " .. state.SelectedBoss, true)
                return
            end
            state.ActiveFarmTarget = nil
            local spawn = enemySpawn(state.SelectedBoss)
            if spawn then
                moveTo(CFrame.new(spawn.Position + Vector3.new(0, 8, 0)))
                setStatus("Waiting for " .. state.SelectedBoss .. " to spawn", nil)
            else
                setError("Boss spawn is unavailable in this sea")
            end
        end

        local function loadedEnemies()
            local enemies = workspace:FindFirstChild("Enemies")
            return enemies and enemies:GetChildren() or {}
        end

        local RaidRuntime = {}

        function RaidRuntime.IslandParts()
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            local islands = {}
            if not locations then
                return islands
            end
            for _, child in ipairs(locations:GetChildren()) do
                local index = tonumber(string.match(string.lower(child.Name), "^island%s*(%d+)$"))
                local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                if index and index >= 1 and index <= 5 and part then
                    table.insert(islands, {
                        Index = index,
                        Name = child.Name,
                        Part = part,
                    })
                end
            end
            table.sort(islands, function(left, right)
                return left.Index < right.Index
            end)
            return islands
        end

        function RaidRuntime.Active()
            -- Numbered island markers are shared across the server, so another
            -- player's raid can leave Island 1 visible tens of thousands of
            -- studs away. Prefer the local raid state; otherwise Auto Raid
            -- happily kidnaps the player into somebody else's dungeon.
            local islandRaiding = LocalPlayer:GetAttribute("IslandRaiding")
            if islandRaiding ~= nil then
                return islandRaiding == true
            end
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local main = playerGui and playerGui:FindFirstChild("Main")
            local timer = main and (main:FindFirstChild("Timer")
                or (main:FindFirstChild("TopHUDList") and main.TopHUDList:FindFirstChild("RaidTimer")))
            if timer and timer:IsA("GuiObject") then
                return timer.Visible == true
            end
            return #RaidRuntime.IslandParts() > 0
        end

        function RaidRuntime.LatestIsland()
            if not RaidRuntime.Active() then
                return nil
            end
            local islands = RaidRuntime.IslandParts()
            return islands[#islands]
        end

        function RaidRuntime.NearestEnemy(island)
            local root = rootPart()
            if not root then
                return nil, math.huge
            end
            local nearest = nil
            local nearestDistance = math.huge
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                if enemyRoot and modelAlive(enemy) then
                    local insideRaidArea = not island
                        or (enemyRoot.Position - island.Part.Position).Magnitude <= 2500
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if insideRaidArea and distance < nearestDistance then
                        nearest = enemy
                        nearestDistance = distance
                    end
                end
            end
            return nearest, nearestDistance
        end

        function RaidRuntime.RaidChip()
            for _, container in ipairs({character(), LocalPlayer:FindFirstChildOfClass("Backpack")}) do
                if container then
                    for _, child in ipairs(container:GetChildren()) do
                        if child:IsA("Tool") then
                            local name = string.lower(child.Name)
                            if string.find(name, "microchip", 1, true)
                                or string.find(name, "raid chip", 1, true) then
                                return child
                            end
                        end
                    end
                end
            end
            return nil
        end

        function RaidRuntime.StartStation()
            local map = workspace:FindFirstChild("Map")
            local root = rootPart()
            if not map or not root then
                return nil
            end
            local bestYellow = nil
            local bestDetector = nil
            local bestDistance = math.huge
            for _, station in ipairs(map:GetDescendants()) do
                if station:IsA("Model") and station.Name == "RaidSummon2" then
                    local mainRaid = station:FindFirstChild("MainRaid")
                    local yellow = mainRaid and (mainRaid:FindFirstChild("Color")
                        or mainRaid:FindFirstChildWhichIsA("BasePart"))
                    local button = station:FindFirstChild("Button")
                    local buttonPart = button and (button:FindFirstChild("Main")
                        or button:FindFirstChildWhichIsA("BasePart"))
                    local detector = buttonPart and buttonPart:FindFirstChildOfClass("ClickDetector")
                    if yellow and yellow:IsA("BasePart") and detector then
                        local distance = (yellow.Position - root.Position).Magnitude
                        if distance < bestDistance then
                            bestYellow = yellow
                            bestDetector = detector
                            bestDistance = distance
                        end
                    end
                end
            end
            return bestYellow, bestDetector, bestDistance
        end

        function RaidRuntime.VoidKillStep(island)
            local enabled = state.AutoRaid
                and state.RaidVoidKill
                and RaidRuntime.Active()
                and island
                and island.Index >= 5
            if not enabled then
                for enemy, originalCFrame in pairs(state.RaidVoidOriginalCFrames) do
                    local enemyRoot = modelRoot(enemy)
                    local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                    if enemyRoot and enemyBody and enemyBody.Health > 0 then
                        pcall(function()
                            enemyBody.PlatformStand = false
                            enemyRoot.CFrame = originalCFrame
                            enemyRoot.AssemblyLinearVelocity = Vector3.zero
                            enemyRoot.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                end
                table.clear(state.RaidVoidOriginalCFrames)
                state.RaidVoidActive = false
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                return 0
            end
            state.RaidVoidActive = true
            if os.clock() - state.LastRaidVoidStep < 0.06 then
                return state.RaidVoidMoved
            end
            state.LastRaidVoidStep = os.clock()
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                end
            end)
            local playerRoot = rootPart()
            if not playerRoot then
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                return 0
            end
            -- Solix's live Island 5 sequence is ownership-gated, not a raw void
            -- teleport: a full-health raid boss becomes network-owned, Health
            -- reaches server-visible zero, and the replicated corpse then falls
            -- naturally for several seconds before removal.
            local killed = 0
            local waitingForOwnership = 0
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                if enemyRoot and enemyBody and enemyBody.Health > 0
                    and (enemyRoot.Position - island.Part.Position).Magnitude <= 2500 then
                    local owned = false
                    if type(isnetworkowner) == "function" then
                        local ownerOk, ownerResult = pcall(isnetworkowner, enemyRoot)
                        owned = ownerOk and ownerResult == true
                    end
                    local actionOk = pcall(function()
                        if owned then
                            enemyBody.Health = -9e9
                        end
                    end)
                    if owned and actionOk then
                        if not state.RaidVoidTargets[enemy] then
                            state.RaidVoidTargets[enemy] = true
                            state.RaidVoidKillCount += 1
                        end
                        killed += 1
                    else
                        waitingForOwnership += 1
                    end
                end
            end
            state.RaidVoidMoved = killed
            state.RaidVoidStaged = waitingForOwnership
            state.RaidGathered = 0
            return killed
        end

        local function fireRaidButton()
            if type(fireclickdetector) ~= "function" then
                return false, "fireclickdetector is unavailable"
            end
            if RaidRuntime.Active() then
                return true, "Raid is already active"
            end
            local root = rootPart()
            if not root then
                return false, "Character is unavailable"
            end
            local chip = RaidRuntime.RaidChip()
            if not chip then
                return false, "No raid microchip found; buy one first"
            end
            local yellow, detector, distance = RaidRuntime.StartStation()
            if not yellow or not detector then
                moveTo(state.RaidCastleStart)
                return true, "Moving to Castle on the Sea raid room"
            end
            local standingCFrame = CFrame.new(
                yellow.Position + Vector3.new(0, yellow.Size.Y * 0.5 + 2.8, 0)
            )
            if distance > 7 then
                moveTo(standingCFrame)
                return true, "Moving to the nearest yellow raid pad"
            end
            cancelMove(false)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = standingCFrame
            local body = humanoid()
            if body and chip.Parent ~= character() then
                pcall(function()
                    body:EquipTool(chip)
                end)
            end
            if type(firetouchinterest) == "function" then
                pcall(firetouchinterest, root, yellow, 0)
                pcall(firetouchinterest, root, yellow, 1)
            end
            task.wait(0.15)
            local ok, result = pcall(fireclickdetector, detector)
            return ok, ok and "Green raid button activated" or result
        end

        local function stepRaid()
            local island = RaidRuntime.LatestIsland()
            if not island then
                state.ActiveFarmTarget = nil
                state.ActiveFarmHeightOverride = nil
                state.RaidIslandIndex = 0
                state.RaidIslandName = nil
                state.RaidTargetName = nil
                RaidRuntime.VoidKillStep(nil)
                raidLabel.Text = "Dungeon / Raid: Waiting to start"
                return
            end
            local entryRemaining = state.RaidEntryGrace - (os.clock() - state.RaidEnteredAt)
            if state.RaidEnteredAt > 0 and entryRemaining > 0 then
                state.ActiveFarmTarget = nil
                state.ActiveFarmHeightOverride = nil
                state.RaidIslandIndex = 0
                state.RaidIslandName = nil
                state.RaidTargetName = nil
                RaidRuntime.VoidKillStep(nil)
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Waiting for server teleport | %.1fs",
                    entryRemaining
                )
                return
            end
            state.RaidIslandIndex = island.Index
            state.RaidIslandName = island.Name
            local safeHeight = math.max(state.RaidSafeHeight, tonumber(state.MobAuraHeight) or 20)
            state.ActiveFarmHeightOverride = safeHeight
            local voided = RaidRuntime.VoidKillStep(island)
            if state.RaidVoidActive then
                state.ActiveFarmTarget = nil
                state.ActiveFarmVerticalLock = false
                state.RaidTargetName = nil
                moveTo(island.Part.CFrame + Vector3.new(0, safeHeight, 0))
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Island %d FORCE KILL | Waiting ownership: %d | Killed: %d | Total: %d",
                    island.Index,
                    state.RaidVoidStaged,
                    voided,
                    state.RaidVoidKillCount
                )
                return
            end
            local enemy = state.ActiveFarmTarget
            local enemyRoot = modelRoot(enemy)
            if not modelAlive(enemy) or not enemyRoot
                or (enemyRoot.Position - island.Part.Position).Magnitude > 2500 then
                enemy = nil
            end
            local activeRoot = rootPart()
            local distance = enemy and activeRoot and (enemyRoot.Position - activeRoot.Position).Magnitude or nil
            if not enemy then
                enemy, distance = RaidRuntime.NearestEnemy(island)
            end
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = true
                state.CurrentEnemyName = normalizeEnemyName(enemy.Name)
                state.RaidTargetName = state.CurrentEnemyName
                if healthPercent() <= 50 then
                    state.ActiveFarmTarget = nil
                    local enemyRoot = modelRoot(enemy)
                    if enemyRoot then
                        local retreatHeight = math.max(55, safeHeight + 15)
                        moveTo(CFrame.lookAt(
                            enemyRoot.Position + Vector3.new(0, retreatHeight, 0),
                            enemyRoot.Position
                        ))
                    end
                    raidLabel.Text = string.format(
                        "Dungeon / Raid: Emergency recovery at %.0f%% health",
                        healthPercent()
                    )
                    return
                end
                if safeModeRetreat(enemy) then
                    raidLabel.Text = "Dungeon / Raid: Safe mode recovery"
                    return
                end
                syncFarmAuraRange(safeHeight)
                local targetCFrame = positionAtEnemy(enemy, true, safeHeight)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Island %d | Attacking %s | %.0f studs",
                    island.Index,
                    normalizeEnemyName(enemy.Name),
                    distance or 0
                )
            else
                state.ActiveFarmTarget = nil
                state.RaidTargetName = nil
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Moving to latest island %d",
                    island.Index
                )
                moveTo(island.Part.CFrame + Vector3.new(0, safeHeight, 0))
            end
        end

        state.RestoreGatherEnemy = function(enemy, restorePosition)
            local magnetTween = state.MagnetTweens[enemy]
            if magnetTween and magnetTween.Tween then
                pcall(function()
                    magnetTween.Tween:Cancel()
                end)
            end
            state.MagnetTweens[enemy] = nil
            local original = state.GatherOriginalStates[enemy]
            local enemyRoot = modelRoot(enemy)
            local enemyBody = enemy and enemy:FindFirstChildOfClass("Humanoid")
            if original and enemyRoot and enemyBody and enemyBody.Health > 0 then
                pcall(function()
                    if restorePosition and typeof(original.CFrame) == "CFrame" then
                        enemyRoot.CFrame = original.CFrame
                    end
                    enemyRoot.AssemblyLinearVelocity = Vector3.zero
                    enemyRoot.AssemblyAngularVelocity = Vector3.zero
                    enemyRoot.CanCollide = original.CanCollide
                    enemyBody.WalkSpeed = original.WalkSpeed
                    enemyBody.JumpPower = original.JumpPower
                    enemyBody.AutoRotate = original.AutoRotate
                    enemyBody.PlatformStand = original.PlatformStand
                end)
            end
            state.GatherOriginalStates[enemy] = nil
            state.GatherOriginalCFrames[enemy] = nil
        end

        state.HoldGatherEnemy = function(enemy)
            local enemyRoot = modelRoot(enemy)
            local enemyBody = enemy and enemy:FindFirstChildOfClass("Humanoid")
            if not enemyRoot or not enemyBody or enemyBody.Health <= 0 then
                state.RestoreGatherEnemy(enemy, false)
                return false
            end
            local magnetTween = state.MagnetTweens[enemy]
            if magnetTween and magnetTween.Tween then
                pcall(function()
                    magnetTween.Tween:Cancel()
                end)
            end
            state.MagnetTweens[enemy] = nil
            pcall(function()
                enemyRoot.AssemblyLinearVelocity = Vector3.zero
                enemyRoot.AssemblyAngularVelocity = Vector3.zero
                enemyRoot.CanCollide = false
                enemyBody.WalkSpeed = 0
                enemyBody.JumpPower = 0
                enemyBody.AutoRotate = false
            end)
            return true
        end

        local function gatherStep()
            local now = os.clock()
            local scanInterval = state.ExperimentalMagnetBoost and 0.03 or 0.08
            if now - state.LastGatherScan < scanInterval then
                return
            end
            state.LastGatherScan = now
            local root = rootPart()
            if not root then
                return
            end
            local raidIsland = state.AutoRaid and RaidRuntime.LatestIsland() or nil
            local raidVoidActive = state.RaidVoidKill and raidIsland and raidIsland.Index >= 5
            local raidGatherEnabled = state.RaidMultiGrab and state.AutoRaid
                and RaidRuntime.Active() and not raidVoidActive
            local multiGrabEnabled = state.GatherEnemies or raidGatherEnabled
            local farmMagnetActive = state.AutoMagnet and (
                state.AutoFarmLevel
                or state.AutoBoss
                or state.AutoRaid
                or state.MobAuraTp
                or state.SelectedMobFarm
                or state.ThirdSeaFarmActive
            )
            -- Solix keeps already-captured NPCs frozen while Auto Magnet stays
            -- enabled, even when the farm temporarily travels or turns off.
            -- New captures still require an active farm target.
            local enabled = not raidVoidActive and (multiGrabEnabled or state.AutoMagnet)
            if not enabled then
                state.Gathered = 0
                state.RaidGathered = 0
                gui:SetAttribute("BloxAutoMagnetCount", 0)
                state.GatherSingleFallbackEnemy = nil
                for enemy in pairs(state.GatherOriginalStates) do
                    state.RestoreGatherEnemy(enemy, true)
                end
                table.clear(state.GatherOriginalCFrames)
                table.clear(state.GatherOriginalStates)
                state.MagnetAnchorTarget = nil
                state.MagnetAnchorCFrame = nil
                state.MagnetAnchorName = nil
                return
            end
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                    sethiddenproperty(LocalPlayer, "MaximumSimulationRadius", math.huge)
                end
                if type(setsimulationradius) == "function" then
                    setsimulationradius(math.huge, math.huge)
                end
            end)
            if state.AutoMagnet and not farmMagnetActive and not multiGrabEnabled then
                local retained = 0
                for enemy in pairs(state.GatherOriginalStates) do
                    if state.HoldGatherEnemy(enemy) then
                        retained += 1
                    end
                end
                state.Gathered = retained
                state.RaidGathered = 0
                gui:SetAttribute("BloxAutoMagnetCount", retained)
                gui:SetAttribute("BloxAutoMagnetRange", state.MagnetRange)
                return
            end
            local gatherRange = multiGrabEnabled and MULTI_GRAB_RANGE or state.MagnetRange
            -- Mob Aura supplies the anchor target while Auto Magnet drags every
            -- living NPC inside its configured range into that target's pile.
            -- The normal Aura cursor then rotates damage through the pile; it
            -- does not depend on Double Attack or a same-name filter.
            local targetName = (raidGatherEnabled or (state.AutoMagnet and state.MobAuraTp)) and nil
                or (state.GatherEnemies and selectedGatherEnemyName() or state.CurrentEnemyName)
            local candidates = {}
            local candidateSet = {}
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                local distance = enemyRoot and (enemyRoot.Position - root.Position).Magnitude or math.huge
                local insideRaid = not raidGatherEnabled or (
                    raidIsland and enemyRoot
                        and (enemyRoot.Position - raidIsland.Part.Position).Magnitude <= 2500
                )
                local matchesTarget = not targetName or enemyMatches(enemy, targetName)
                if state.ThirdSeaFarmActive and next(state.ThirdSeaFarmNames) ~= nil then
                    matchesTarget = false
                    local normalized = string.lower(normalizeEnemyName(enemy.Name))
                    for expected in pairs(state.ThirdSeaFarmNames) do
                        if normalized == expected
                            or string.find(normalized, expected, 1, true)
                            or string.find(expected, normalized, 1, true) then
                            matchesTarget = true
                            break
                        end
                    end
                end
                local captured = state.AutoMagnet and state.GatherOriginalStates[enemy] ~= nil
                if enemyRoot and modelAlive(enemy) and (distance <= gatherRange or captured) and insideRaid then
                    if matchesTarget then
                        table.insert(candidates, {Enemy = enemy, Root = enemyRoot, Distance = distance})
                        candidateSet[enemy] = true
                    end
                end
            end
            for enemy in pairs(state.GatherOriginalStates) do
                if not candidateSet[enemy] then
                    if not state.AutoMagnet then
                        state.RestoreGatherEnemy(enemy, true)
                    else
                        state.HoldGatherEnemy(enemy)
                    end
                end
            end
            table.sort(candidates, function(left, right)
                return left.Distance < right.Distance
            end)
            -- Multi Grab follows the player. Auto Magnet instead keeps the farm
            -- target's original world CFrame as a stable Solix-style pile anchor.
            local targetCFrame = CFrame.new(root.Position - Vector3.new(0, state.GatherDistance, 0))
            if not multiGrabEnabled then
                local anchorCandidate = nil
                for _, candidate in ipairs(candidates) do
                    if candidate.Enemy == state.ActiveFarmTarget
                        or candidate.Enemy == state.MobAuraTarget then
                        anchorCandidate = candidate
                        break
                    end
                end
                if not anchorCandidate then
                    anchorCandidate = candidates[1]
                end
                if not anchorCandidate then
                    state.MagnetAnchorTarget = nil
                    state.MagnetAnchorCFrame = nil
                    state.MagnetAnchorName = nil
                    state.Gathered = 0
                    gui:SetAttribute("BloxAutoMagnetCount", 0)
                    return
                end
                if state.MagnetAnchorTarget ~= anchorCandidate.Enemy
                    or state.MagnetAnchorName ~= targetName
                    or typeof(state.MagnetAnchorCFrame) ~= "CFrame" then
                    state.MagnetAnchorTarget = anchorCandidate.Enemy
                    state.MagnetAnchorCFrame = anchorCandidate.Root.CFrame
                    state.MagnetAnchorName = targetName
                end
                targetCFrame = CFrame.new(state.MagnetAnchorCFrame.Position)
            end
            if multiGrabEnabled then
                for _, candidate in ipairs(candidates) do
                    if state.GatherOriginalCFrames[candidate.Enemy] == nil then
                        state.GatherOriginalCFrames[candidate.Enemy] = candidate.Root.CFrame
                    end
                end
                if #candidates == 1 then
                    local remaining = candidates[1]
                    local originalCFrame = state.GatherOriginalCFrames[remaining.Enemy]
                    if originalCFrame then
                        pcall(function()
                            remaining.Root.CFrame = originalCFrame
                            remaining.Root.AssemblyLinearVelocity = Vector3.zero
                            remaining.Root.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                    state.GatherSingleFallbackEnemy = remaining.Enemy
                    state.MobAuraAnchorTarget = nil
                    state.MobAuraStableAnchor = nil
                    state.Gathered = 0
                    gui:SetAttribute("BloxAutoMagnetCount", 0)
                    return
                elseif #candidates > 1 then
                    state.GatherSingleFallbackEnemy = nil
                elseif not modelAlive(state.GatherSingleFallbackEnemy) then
                    state.GatherSingleFallbackEnemy = nil
                end
            end
            local gathered = 0
            local limit = multiGrabEnabled and MULTI_GRAB_LIMIT or math.huge
            for index, candidate in ipairs(candidates) do
                if index > limit then
                    break
                end
                local enemyBody = candidate.Enemy:FindFirstChildOfClass("Humanoid")
                if enemyBody then
                    if state.GatherOriginalStates[candidate.Enemy] == nil then
                        state.GatherOriginalStates[candidate.Enemy] = {
                            CFrame = candidate.Root.CFrame,
                            CanCollide = candidate.Root.CanCollide,
                            WalkSpeed = enemyBody.WalkSpeed,
                            JumpPower = enemyBody.JumpPower,
                            AutoRotate = enemyBody.AutoRotate,
                            PlatformStand = enemyBody.PlatformStand,
                        }
                    end
                    local moved = pcall(function()
                        local activeMagnetTween = state.MagnetTweens[candidate.Enemy]
                        if activeMagnetTween and activeMagnetTween.Tween then
                            activeMagnetTween.Tween:Cancel()
                        end
                        state.MagnetTweens[candidate.Enemy] = nil

                        -- Reapply the pile CFrame every scan. A one-shot client
                        -- tween can remain "Playing" after the server restores
                        -- an unowned NPC, which left that mob frozen at its old
                        -- position while the UI falsely counted it as stacked.
                        candidate.Root.CFrame = targetCFrame
                        candidate.Root.AssemblyLinearVelocity = Vector3.zero
                        candidate.Root.AssemblyAngularVelocity = Vector3.zero
                        candidate.Root.CanCollide = false
                        enemyBody.WalkSpeed = 0
                        enemyBody.JumpPower = 0
                        enemyBody.AutoRotate = false
                    end)
                    if moved then
                        gathered += 1
                    end
                end
            end
            state.Gathered = gathered
            state.RaidGathered = raidGatherEnabled and gathered or 0
            gui:SetAttribute("BloxAutoMagnetCount", gathered)
            gui:SetAttribute("BloxAutoMagnetRange", gatherRange)
        end

        state.SeaEvent.BoatNames = {
            "Guardian",
            "Pirate Grand Brigade",
            "Marine Grand Brigade",
            "Pirate Brigade",
            "Marine Brigade",
            "Pirate Sloop",
            "Marine Sloop",
            "Beast Hunter",
            "Lantern",
            "Miracle",
            "Sentinel",
            "Sleigh",
        }
        state.SeaEvent.BoatPurchaseNames = {
            ["Guardian"] = "Guardian",
            ["Pirate Grand Brigade"] = "PirateGrandBrigade",
            ["Marine Grand Brigade"] = "MarineGrandBrigade",
            ["Pirate Brigade"] = "PirateBrigade",
            ["Marine Brigade"] = "MarineBrigade",
            ["Pirate Sloop"] = "PirateBasic",
            ["Marine Sloop"] = "MarineBasic",
            ["Beast Hunter"] = "BeastHunter",
            ["Lantern"] = "Lantern",
            ["Miracle"] = "Miracle",
            ["Sentinel"] = "Sentinel",
            ["Sleigh"] = "Sleigh",
        }
        state.SeaEvent.SkillKeys = {
            Enum.KeyCode.Z,
            Enum.KeyCode.X,
            Enum.KeyCode.C,
            Enum.KeyCode.V,
            Enum.KeyCode.F,
        }
        state.SeaEvent.StopConditionPatterns = {
            ["Kitsune Island"] = {"kitsune island", "kitsune shrine"},
            ["Prehistoric Island"] = {"prehistoric island", "prehistoric"},
            ["Mirage Island"] = {"mirage island", "mystic island"},
            ["Frozen Dimension"] = {"frozen dimension", "frozen island"},
        }
        state.SeaEvent.TransformationSkillKeys = {
            ["kitsune"] = {V = true},
            ["leopard"] = {V = true},
            ["mammoth"] = {V = true},
            ["t-rex"] = {V = true},
            ["trex"] = {V = true},
            ["dragon"] = {V = true},
            ["gas"] = {V = true},
            ["yeti"] = {V = true},
            ["phoenix"] = {V = true},
            ["buddha"] = {Z = true},
            ["venom"] = {F = true},
            ["falcon"] = {Z = true},
        }
        state.SeaEvent.DangerDistanceFn = safeRequire(ReplicatedStorage:FindFirstChild("DangerDistance"))
        state.SeaEvent.GetDangerLevelFn = safeRequire(
            ReplicatedStorage:FindFirstChild("Util")
                and ReplicatedStorage.Util:FindFirstChild("GetDangerLevel")
        )

        function state.SeaEvent.TargetPart(target)
            if not target or not target.Parent then
                return nil
            end
            if target:IsA("BasePart") then
                return target
            end
            return (target:IsA("Model") and target.PrimaryPart or nil)
                or target:FindFirstChild("HumanoidRootPart", true)
                or target:FindFirstChild("RootPart", true)
                or target:FindFirstChild("Engine", true)
                or target:FindFirstChildWhichIsA("BasePart", true)
        end

        function state.SeaEvent.Health(target)
            if not target then
                return nil, nil
            end
            local body = target:FindFirstChildWhichIsA("Humanoid", true)
            if body then
                return body.Health, body.MaxHealth
            end
            for _, name in ipairs({"Humanoid", "Health", "HP"}) do
                local value = target:FindFirstChild(name, true)
                if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
                    local maximum = tonumber(target:GetAttribute("MaxHealth"))
                        or tonumber(target:GetAttribute("OriginalMaxHealth"))
                        or tonumber(value:GetAttribute("MaxHealth"))
                    return tonumber(value.Value), maximum
                end
            end
            local health = tonumber(target:GetAttribute("Health")) or tonumber(target:GetAttribute("HP"))
            local maximum = tonumber(target:GetAttribute("MaxHealth"))
            return health, maximum
        end

        function state.SeaEvent.IsAlive(target)
            if not target or not target.Parent then
                return false
            end
            local health = state.SeaEvent.Health(target)
            return health == nil or health > 0
        end

        function state.SeaEvent.Kind(target, sourceName)
            local name = string.lower(tostring(target and target.Name or ""))
            local fullName = string.lower(tostring(target and target:GetFullName() or ""))
            local combined = name .. " " .. fullName .. " " .. string.lower(tostring(sourceName or ""))
            if combined:find("leviathan", 1, true) then
                return "Sea Beast", 3
            end
            if combined:find("terror shark", 1, true) or combined:find("terrorshark", 1, true) then
                return "Terror Shark", 1
            end
            if combined:find("sea beast", 1, true)
                or combined:find("seabeast", 1, true)
                or string.lower(tostring(sourceName or "")) == "seabeasts" then
                return "Sea Beast", 2
            end
            if combined:find("piranha", 1, true) then
                return "Piranha", 4
            end
            if combined:find("shark", 1, true) then
                return "Shark", 4
            end
            if combined:find("fish crew", 1, true) then
                return "Fish Crew Member", 5
            end
            if combined:find("ship", 1, true)
                or combined:find("boat", 1, true)
                or combined:find("brigade", 1, true) then
                return "Enemy Boat", 6
            end
            return "Sea Event", 7
        end

        function state.SeaEvent.FindTarget()
            local origin = rootPart()
            local boat = state.SeaEvent.Boat
            local originPosition = origin and origin.Position
                or (boat and boat.Parent and boat:GetPivot().Position)
            if not originPosition then
                return nil
            end
            local candidates = {}
            local seen = setmetatable({}, {__mode = "k"})
            local function addCandidate(candidate, sourceName)
                if not candidate or seen[candidate] or candidate == boat then
                    return
                end
                local part = state.SeaEvent.TargetPart(candidate)
                local kind, priority = state.SeaEvent.Kind(candidate, sourceName)
                local allowed = state.SeaEvent.SelectedEvents[kind] == true
                if part and allowed and state.SeaEvent.IsAlive(candidate) then
                    seen[candidate] = true
                    table.insert(candidates, {
                        Target = candidate,
                        Part = part,
                        Kind = kind,
                        Priority = priority,
                        Distance = (part.Position - originPosition).Magnitude,
                    })
                end
            end

            for _, folderName in ipairs({"SeaBeasts", "SeaEvents"}) do
                local folder = workspace:FindFirstChild(folderName)
                if folder then
                    for _, child in ipairs(folder:GetChildren()) do
                        addCandidate(child, folderName)
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local lowered = string.lower(enemy.Name)
                    if lowered:find("terror", 1, true)
                        or lowered:find("shark", 1, true)
                        or lowered:find("piranha", 1, true)
                        or lowered:find("fish crew", 1, true)
                        or lowered:find("sea beast", 1, true) then
                        addCandidate(enemy, "Enemies")
                    end
                end
            end
            table.sort(candidates, function(left, right)
                if left.Priority == right.Priority then
                    return left.Distance < right.Distance
                end
                return left.Priority < right.Priority
            end)
            return candidates[1]
        end

        function state.SeaEvent.OwnedBoat()
            local boats = workspace:FindFirstChild("Boats")
            if not boats then
                return nil
            end
            local root = rootPart()
            local best, bestDistance = nil, math.huge
            for _, boat in ipairs(boats:GetChildren()) do
                local owner = boat:FindFirstChild("Owner")
                if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer
                    and not state.SeaEvent.IgnoredBoats[boat] then
                    local distance = root and (boat:GetPivot().Position - root.Position).Magnitude or 0
                    if distance < bestDistance then
                        best, bestDistance = boat, distance
                    end
                end
            end
            return best
        end

        function state.SeaEvent.BoatAlive(boat)
            if not boat or not boat.Parent then
                return false
            end
            local health = state.SeaEvent.Health(boat)
            return health == nil or health > 0
        end

        function state.SeaEvent.StopBoat(boat)
            if not boat or not boat.Parent then
                return
            end
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end

        function state.SeaEvent.ApplyBoatNoclip(boat)
            if not boat or not boat.Parent then
                return
            end
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then
                    if state.SeaEvent.BoatCollisions[part] == nil then
                        state.SeaEvent.BoatCollisions[part] = {
                            CanCollide = part.CanCollide,
                        }
                    end
                    part.CanCollide = false
                end
            end
        end

        function state.SeaEvent.RestoreBoatNoclip()
            for part, original in pairs(state.SeaEvent.BoatCollisions) do
                if part and part.Parent then
                    part.CanCollide = original.CanCollide
                end
            end
            state.SeaEvent.BoatCollisions = setmetatable({}, {__mode = "k"})
        end

        function state.SeaEvent.FindStopCondition()
            if not state.SeaEvent.AutoStopSail then
                state.SeaEvent.StopMatch = nil
                return nil
            end
            if os.clock() - state.SeaEvent.LastStopScan < 0.5 then
                return state.SeaEvent.StopMatch
            end
            state.SeaEvent.LastStopScan = os.clock()
            state.SeaEvent.StopMatch = nil
            local candidates = workspace:GetChildren()
            local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
            local locations = worldOrigin and worldOrigin:FindFirstChild("Locations")
            local map = workspace:FindFirstChild("Map")
            local seaEvents = workspace:FindFirstChild("SeaEvents")
            for _, container in ipairs({locations, map, seaEvents}) do
                if container then
                    for _, child in ipairs(container:GetChildren()) do
                        table.insert(candidates, child)
                    end
                end
            end
            for condition, enabled in pairs(state.SeaEvent.StopConditions) do
                if enabled then
                    for _, candidate in ipairs(candidates) do
                        local lowered = string.lower(candidate.Name)
                        for _, pattern in ipairs(state.SeaEvent.StopConditionPatterns[condition] or {}) do
                            if lowered:find(pattern, 1, true) then
                                state.SeaEvent.StopMatch = condition
                                return condition
                            end
                        end
                    end
                end
            end
            return nil
        end

        function state.SeaEvent.DestroySafety()
            local part = state.SeaEvent.SafetyPart
            if part and part.Parent then
                part:Destroy()
            end
            state.SeaEvent.SafetyPart = nil
        end

        function state.SeaEvent.UpdateSafety(position)
            local part = state.SeaEvent.SafetyPart
            if not part or not part.Parent then
                part = Instance.new("Part")
                part.Name = "VORSeaEventWaterSafety"
                part.Size = Vector3.new(34, 1, 34)
                part.Anchored = true
                part.CanCollide = true
                part.CanTouch = false
                part.CanQuery = false
                part.Transparency = 1
                part.Parent = workspace
                state.SeaEvent.SafetyPart = part
            end
            part.CFrame = CFrame.new(position - Vector3.new(0, 4.5, 0))
        end

        function state.SeaEvent.ResetAdaptiveSpeed()
            state.SeaEvent.EffectiveSpeed = math.max(0, tonumber(state.SeaEvent.BoatTweenSpeed) or 295)
            state.SeaEvent.SafeSpeed = math.min(80, state.SeaEvent.EffectiveSpeed)
            state.SeaEvent.RejectedSpeed = nil
            state.SeaEvent.StableSince = os.clock()
            state.SeaEvent.PauseUntil = 0
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.Rubberbacks = 0
        end

        function state.SeaEvent.NearestDealer()
            local root = rootPart()
            local npcs = workspace:FindFirstChild("NPCs")
            local best, bestPart, bestDistance = nil, nil, math.huge
            if not root or not npcs then
                return nil
            end
            for _, npc in ipairs(npcs:GetChildren()) do
                local lowered = string.lower(npc.Name)
                if lowered == "boat dealer" or lowered == "luxury boat dealer" then
                    local part = npc:FindFirstChild("HumanoidRootPart")
                        or npc:FindFirstChild("Head")
                        or npc:FindFirstChildWhichIsA("BasePart")
                    local distance = part and (part.Position - root.Position).Magnitude or math.huge
                    if distance < bestDistance then
                        best, bestPart, bestDistance = npc, part, distance
                    end
                end
            end
            return best, bestPart, bestDistance
        end

        function state.SeaEvent.ResetCharacter(reason)
            if os.clock() - (state.SeaEvent.LastReset or 0) < 5 then
                return
            end
            state.SeaEvent.LastReset = os.clock()
            state.SeaEvent.Phase = reason or "Resetting for a new boat"
            state.SeaEvent.Boat = nil
            state.SeaEvent.BoatBaseY = nil
            state.SeaEvent.Heading = nil
            state.SeaEvent.LastCommandedPosition = nil
            local body = humanoid()
            if body then
                body.Health = 0
            end
        end

        function state.SeaEvent.RequestNewBoat()
            local boats = workspace:FindFirstChild("Boats")
            if boats then
                for _, boat in ipairs(boats:GetChildren()) do
                    local owner = boat:FindFirstChild("Owner")
                    if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
                        state.SeaEvent.IgnoredBoats[boat] = true
                    end
                end
            end
            state.SeaEvent.ForceBoatPurchase = true
            state.SeaEvent.Boat = nil
            state.SeaEvent.BoatBaseY = nil
            state.SeaEvent.Heading = nil
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.LastPurchase = 0
            state.SeaEvent.Target = nil
            state.SeaEvent.TargetKind = nil
            state.SeaEvent.TargetLostAt = nil
            state.SeaEvent.DestroySafety()
            state.SeaEvent.Phase = "Going to Boat Dealer for a new boat"
        end

        function state.SeaEvent.EnsureBoat()
            local current = state.SeaEvent.OwnedBoat()
            if current and state.SeaEvent.BoatAlive(current) then
                state.SeaEvent.ForceBoatPurchase = false
                if current ~= state.SeaEvent.Boat then
                    state.SeaEvent.Boat = current
                    -- Solix keeps the spawned boat at its exact native pivot Y.
                    -- WaterOrigin is not the model pivot and was lifting VOR boats
                    -- high enough for the server's movement security to reject them.
                    state.SeaEvent.BoatBaseY = current:GetPivot().Position.Y
                    state.SeaEvent.Heading = nil
                    state.SeaEvent.ResetAdaptiveSpeed()
                end
                return current
            end
            if current and not state.SeaEvent.BoatAlive(current) then
                if state.SeaEvent.ResetBrokenBoat then
                    state.SeaEvent.ResetCharacter("Boat destroyed - resetting")
                end
                return nil
            end
            state.SeaEvent.Boat = nil
            if os.clock() - state.SeaEvent.LastPurchase < 3 then
                state.SeaEvent.Phase = "Waiting for " .. state.SeaEvent.SelectedBoat
                return nil
            end

            local _, dealerPart, dealerDistance = state.SeaEvent.NearestDealer()
            if dealerPart and dealerDistance > 24 then
                state.SeaEvent.Phase = "Moving to Boat Dealer"
                moveTo(CFrame.new(dealerPart.Position + Vector3.new(0, 5, 8), dealerPart.Position))
                return nil
            end
            if not dealerPart then
                if state.SeaEvent.ResetBrokenBoat then
                    state.SeaEvent.ResetCharacter("Returning to Boat Dealer")
                end
                return nil
            end

            state.SeaEvent.LastPurchase = os.clock()
            state.SeaEvent.Phase = (state.SeaEvent.ForceBoatPurchase and "Buying new " or "Buying ")
                .. state.SeaEvent.SelectedBoat
            local purchaseName = state.SeaEvent.BoatPurchaseNames[state.SeaEvent.SelectedBoat]
                or state.SeaEvent.SelectedBoat
            local ok, result = invoke("BuyBoat", purchaseName)
            if not ok then
                state.SeaEvent.LastError = tostring(result)
            end
            return nil
        end

        function state.SeaEvent.SeatBoat(boat)
            local body = humanoid()
            local char = character()
            local seat = boat and boat:FindFirstChildWhichIsA("VehicleSeat", true)
            if not body or not char or not seat then
                return false
            end
            if seat.Occupant ~= body and os.clock() - state.SeaEvent.LastSeat >= 0.15 then
                state.SeaEvent.LastSeat = os.clock()
                char:PivotTo(seat.CFrame + Vector3.new(0, 2.5, 0))
                body.Sit = false
                seat:Sit(body)
            end
            return seat.Occupant == body
        end

        function state.SeaEvent.ChooseHeading(boat)
            local position = boat:GetPivot().Position
            local dangerDistance = state.SeaEvent.DangerDistanceFn
            local previous = state.SeaEvent.Heading
            local bestDirection = previous or Vector3.new(0, 0, 1)
            local bestScore = -math.huge
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {workspace:FindFirstChild("Map")}
            params.IgnoreWater = true
            for index = 0, 15 do
                local angle = index * math.pi / 8
                local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
                local probe = position + direction * 8000
                local score = type(dangerDistance) == "function" and dangerDistance(probe) or 0
                if previous then
                    score += direction:Dot(previous) * 220
                end
                if workspace:FindFirstChild("Map")
                    and workspace:Raycast(position + Vector3.new(0, 18, 0), direction * 900, params) then
                    score -= 100000
                end
                if score > bestScore then
                    bestScore = score
                    bestDirection = direction
                end
            end
            state.SeaEvent.Heading = bestDirection
            state.SeaEvent.NextHeadingAt = os.clock() + 2.5
            return bestDirection
        end

        function state.SeaEvent.DetectRubberband(currentPosition, deltaTime)
            local commanded = state.SeaEvent.LastCommandedPosition
            if not commanded then
                return false
            end
            local horizontalError = ((currentPosition - commanded) * Vector3.new(1, 0, 1)).Magnitude
            local allowed = math.max(35, state.SeaEvent.EffectiveSpeed * math.max(deltaTime, 1 / 60) * 8)
            if horizontalError <= allowed then
                return false
            end

            state.SeaEvent.Rubberbacks += 1
            local rejected = math.max(tonumber(state.SeaEvent.EffectiveSpeed) or 0, 1)
            state.SeaEvent.RejectedSpeed = math.min(state.SeaEvent.RejectedSpeed or rejected, rejected)
            state.SeaEvent.EffectiveSpeed = math.max(
                25,
                math.floor((state.SeaEvent.SafeSpeed + state.SeaEvent.RejectedSpeed) * 0.5)
            )
            state.SeaEvent.PauseUntil = os.clock() + 0.85
            state.SeaEvent.StableSince = os.clock()
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.Heading = nil
            state.SeaEvent.Phase = string.format(
                "Snap-back stopped - testing %.0f speed",
                state.SeaEvent.EffectiveSpeed
            )
            return true
        end

        function state.SeaEvent.RaiseSafeSpeed()
            local requested = math.max(0, tonumber(state.SeaEvent.BoatTweenSpeed) or 0)
            if os.clock() - state.SeaEvent.StableSince < 4
                or state.SeaEvent.EffectiveSpeed >= requested then
                return
            end
            state.SeaEvent.SafeSpeed = math.max(state.SeaEvent.SafeSpeed, state.SeaEvent.EffectiveSpeed)
            if state.SeaEvent.RejectedSpeed then
                local nextSpeed = math.floor(
                    (state.SeaEvent.SafeSpeed + state.SeaEvent.RejectedSpeed) * 0.5
                )
                if nextSpeed <= state.SeaEvent.SafeSpeed + 1 then
                    state.SeaEvent.EffectiveSpeed = state.SeaEvent.SafeSpeed
                else
                    state.SeaEvent.EffectiveSpeed = math.min(requested, nextSpeed)
                end
            else
                state.SeaEvent.EffectiveSpeed = math.min(requested, state.SeaEvent.EffectiveSpeed + 25)
            end
            state.SeaEvent.StableSince = os.clock()
        end

        function state.SeaEvent.Sail(boat, deltaTime)
            state.SeaEvent.DestroySafety()
            state.SeaEvent.ApplyBoatNoclip(boat)
            state.SeaEvent.SeatBoat(boat)
            local pivot = boat:GetPivot()
            if state.SeaEvent.DetectRubberband(pivot.Position, deltaTime) then
                state.SeaEvent.StopBoat(boat)
                return
            end
            if os.clock() < state.SeaEvent.PauseUntil then
                state.SeaEvent.StopBoat(boat)
                return
            end
            state.SeaEvent.RaiseSafeSpeed()
            local direction = state.SeaEvent.Heading
            if not direction then
                direction = state.SeaEvent.ChooseHeading(boat)
            end
            local speed = math.max(0, tonumber(state.SeaEvent.EffectiveSpeed) or 0)
            local baseY = tonumber(state.SeaEvent.BoatBaseY) or pivot.Position.Y
            local nextPosition = pivot.Position + direction * speed * math.min(deltaTime, 0.05)
            nextPosition = Vector3.new(
                nextPosition.X,
                baseY + math.max(0, tonumber(state.SeaEvent.BoatFloatHeight) or 0),
                nextPosition.Z
            )
            local goal = CFrame.lookAt(nextPosition, nextPosition + direction)
            boat:PivotTo(goal)
            state.SeaEvent.StopBoat(boat)
            state.SeaEvent.LastCommandedPosition = nextPosition
            state.SeaEvent.SeatBoat(boat)

            local danger = type(state.SeaEvent.DangerDistanceFn) == "function"
                and state.SeaEvent.DangerDistanceFn(nextPosition) or 0
            local dangerData = type(state.SeaEvent.GetDangerLevelFn) == "function"
                and state.SeaEvent.GetDangerLevelFn(danger) or nil
            state.SeaEvent.DangerDistance = danger
            state.SeaEvent.DangerLevel = dangerData
                and math.max((tonumber(dangerData.level) or 1) - 1, 0) or 0
            state.SeaEvent.Phase = string.format(
                "Sailing | Danger %d | %.0f speed | +%.0f height",
                state.SeaEvent.DangerLevel,
                speed,
                state.SeaEvent.BoatFloatHeight
            )
        end

        function state.SeaEvent.CombatTools()
            local result = {}
            local seen = setmetatable({}, {__mode = "k"})
            for _, container in ipairs({character(), LocalPlayer:FindFirstChildOfClass("Backpack")}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") and not seen[tool] then
                            local weaponData = weaponDataForTool(tool)
                            local weaponType = string.lower(weaponTypeForTool(tool, weaponData))
                            if weaponType:find("melee", 1, true)
                                or weaponType:find("sword", 1, true)
                                or weaponType:find("gun", 1, true)
                                or weaponType:find("fruit", 1, true) then
                                seen[tool] = true
                                table.insert(result, tool)
                            end
                        end
                    end
                end
            end
            return result
        end

        function state.SeaEvent.SpamSkill(targetPart)
            if not state.SeaEvent.SpamAllSkills
                or os.clock() - state.SeaEvent.LastSkill < 0.055 then
                return
            end
            local tools = state.SeaEvent.CombatTools()
            if #tools == 0 then
                state.SeaEvent.LastError = "No combat Tools found"
                return
            end
            state.SeaEvent.LastSkill = os.clock()
            state.SeaEvent.SkillIndex = state.SeaEvent.SkillIndex % #state.SeaEvent.SkillKeys + 1
            if state.SeaEvent.SkillIndex == 1 then
                state.SeaEvent.ToolIndex = state.SeaEvent.ToolIndex % #tools + 1
            end
            if state.SeaEvent.ToolIndex == 0 then
                state.SeaEvent.ToolIndex = 1
            end
            local tool = tools[state.SeaEvent.ToolIndex]
            local keyCode = state.SeaEvent.SkillKeys[state.SeaEvent.SkillIndex]
            local loweredToolName = string.lower(tool.Name)
            for pattern, blockedKeys in pairs(state.SeaEvent.TransformationSkillKeys) do
                if loweredToolName:find(pattern, 1, true) and blockedKeys[keyCode.Name] then
                    return
                end
            end
            equipTool(tool)
            if type(FruitMouse) == "table" and targetPart then
                FruitMouse.Hit = CFrame.new(targetPart.Position)
                FruitMouse.Target = targetPart
            end
            pcall(function()
                tool:Activate()
                tool:Deactivate()
            end)
            task.spawn(function()
                local input = game:GetService("VirtualInputManager")
                input:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.045)
                input:SendKeyEvent(false, keyCode, false, game)
            end)
        end

        function state.SeaEvent.ConfigureAuraCombat()
            local required = {
                {"blox_auto_attack", true},
                {"blox_aura_kill_range", AURA_KILL_MAX_RANGE},
                {"blox_fast_attack", true},
                {"blox_double_attack", true},
                {"blox_fruit_m1_cooldown_reduction", 0},
                {"blox_walk_water", true},
            }
            for _, setting in ipairs(required) do
                local control = Window.PersistentControls[setting[1]]
                if control and control:Get() ~= setting[2] then
                    control:Set(setting[2])
                end
            end
            -- Direct fallbacks cover the short window before a late control is
            -- registered and keep old saved profiles from weakening sea combat.
            state.AuraKill = true
            state.AuraRange = AURA_KILL_MAX_RANGE
            state.FastAttack = true
            state.DoubleAttack = true
            state.WalkOnWater = true
            applyFruitM1CooldownReduction(0)
            ensureBuso(true)
        end

        function state.SeaEvent.Fight(candidate)
            local target = candidate and candidate.Target
            local targetPart = candidate and state.SeaEvent.TargetPart(target)
            local root = rootPart()
            local body = humanoid()
            if not targetPart or not root or not body then
                return
            end
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.StopBoat(state.SeaEvent.Boat)
            state.SeaEvent.TargetLastSeenAt = os.clock()
            state.SeaEvent.TargetLostAt = nil
            if body.SeatPart then
                body.Sit = false
                body.Jump = true
            end

            local height = math.max(8, tonumber(state.SeaEvent.CombatHeight) or 24)
            if candidate.Kind == "Sea Beast" then
                height = math.max(9, height * 0.5)
            elseif candidate.Kind == "Enemy Boat" then
                height = math.max(12, height * 0.65)
            end
            local position = targetPart.Position + Vector3.new(0, height, 0)
            if state.SeaEvent.WaterGuard then
                local safeWaterY = (tonumber(state.SeaEvent.BoatBaseY) or 19) + 5
                position = Vector3.new(position.X, math.max(position.Y, safeWaterY), position.Z)
            end
            root.CFrame = CFrame.lookAt(position, targetPart.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if state.SeaEvent.WaterGuard then
                state.SeaEvent.UpdateSafety(position)
            else
                state.SeaEvent.DestroySafety()
            end
            ensureBuso(true)
            local health, maximum = state.SeaEvent.Health(target)
            state.SeaEvent.TargetLastHealth = health
            local useAllSkills = candidate.Kind == "Sea Beast" or candidate.Kind == "Enemy Boat"
            if useAllSkills then
                state.SeaEvent.SpamSkill(targetPart)
            end
            state.SeaEvent.Phase = string.format(
                "Fighting %s [%s]%s",
                candidate.Kind,
                useAllSkills and "All Skills" or "Aura + Double Attack",
                health and string.format(" | %.0f / %.0f", health, maximum or health) or ""
            )
        end

        function state.SeaEvent.UpdateStatus()
            if os.clock() - (state.SeaEvent.LastStatusUpdate or 0) < 0.15 then
                return
            end
            state.SeaEvent.LastStatusUpdate = os.clock()
            if state.SeaEvent.StatusLabel then
                state.SeaEvent.StatusLabel.Text = "Sea Events: " .. tostring(state.SeaEvent.Phase)
                state.SeaEvent.StatusLabel.TextColor3 = state.SeaEvent.LastError and COLORS.warning
                    or (state.SeaEvent.Enabled and COLORS.success or COLORS.muted)
            end
            if state.SeaEvent.DetailLabel then
                state.SeaEvent.DetailLabel.Text = string.format(
                    "Boat: %s | Event: %s | Snap-backs: %d | Completed: %d",
                    state.SeaEvent.Boat and state.SeaEvent.Boat.Name or state.SeaEvent.SelectedBoat,
                    state.SeaEvent.TargetKind or "Searching",
                    state.SeaEvent.Rubberbacks,
                    state.SeaEvent.EventsCompleted
                )
            end
            gui:SetAttribute("BloxSeaEventAutoFarm", state.SeaEvent.Enabled)
            gui:SetAttribute("BloxSeaEventPhase", state.SeaEvent.Phase)
            gui:SetAttribute("BloxSeaEventBoat", state.SeaEvent.Boat and state.SeaEvent.Boat.Name or "")
            gui:SetAttribute("BloxSeaEventTarget", state.SeaEvent.Target and state.SeaEvent.Target.Name or "")
            gui:SetAttribute("BloxSeaEventTargetKind", state.SeaEvent.TargetKind or "")
            gui:SetAttribute("BloxSeaEventDangerLevel", state.SeaEvent.DangerLevel)
            gui:SetAttribute("BloxSeaEventEffectiveSpeed", state.SeaEvent.EffectiveSpeed)
            gui:SetAttribute("BloxSeaEventRubberbacks", state.SeaEvent.Rubberbacks)
        end

        function state.SeaEvent.Step(deltaTime)
            if not state.SeaEvent.Enabled then
                state.SeaEvent.Phase = "Off"
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                state.SeaEvent.DestroySafety()
                state.SeaEvent.UpdateStatus()
                return
            end
            local stopCondition = state.SeaEvent.FindStopCondition()
            if stopCondition then
                state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                state.SeaEvent.Phase = "Stopped at " .. stopCondition
                state.SeaEvent.UpdateStatus()
                return
            end
            local candidate = nil
            if state.SeaEvent.AutoKill and state.SeaEvent.Target then
                local lockedTarget = state.SeaEvent.Target
                local lockedPart = state.SeaEvent.TargetPart(lockedTarget)
                local lockedHealth = state.SeaEvent.Health(lockedTarget)
                local confirmedDead = lockedHealth ~= nil and lockedHealth <= 0
                if lockedPart and not confirmedDead then
                    candidate = {
                        Target = lockedTarget,
                        Part = lockedPart,
                        Kind = state.SeaEvent.TargetKind or state.SeaEvent.Kind(lockedTarget),
                    }
                    state.SeaEvent.TargetLostAt = nil
                elseif not confirmedDead then
                    state.SeaEvent.TargetLostAt = state.SeaEvent.TargetLostAt or os.clock()
                    if os.clock() - state.SeaEvent.TargetLostAt < 4 then
                        -- Streaming can hide a live sea enemy for a few frames.
                        -- Hold the fight position instead of snapping 30k studs
                        -- back to the boat and tripping movement security.
                        local root = rootPart()
                        if root then
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            if state.SeaEvent.WaterGuard then
                                state.SeaEvent.UpdateSafety(root.Position)
                            end
                        end
                        state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                        state.SeaEvent.Phase = "Holding target lock - waiting for sea enemy stream"
                        state.SeaEvent.UpdateStatus()
                        return
                    end
                end
                if not candidate then
                    state.SeaEvent.EventsCompleted += 1
                    state.SeaEvent.Target = nil
                    state.SeaEvent.TargetKind = nil
                    state.SeaEvent.TargetLostAt = nil
                    state.SeaEvent.TargetLastHealth = nil
                end
            end
            if state.SeaEvent.AutoKill and not candidate then
                candidate = state.SeaEvent.FindTarget()
            end
            if candidate then
                state.SeaEvent.Target = candidate.Target
                state.SeaEvent.TargetKind = candidate.Kind
                state.SeaEvent.Fight(candidate)
                state.SeaEvent.UpdateStatus()
                return
            end
            if not state.SeaEvent.AutoSail then
                state.SeaEvent.Phase = "Auto Kill waiting for a selected sea enemy"
                state.SeaEvent.UpdateStatus()
                return
            end
            local boat = state.SeaEvent.EnsureBoat()
            if boat then
                state.SeaEvent.Sail(boat, deltaTime)
            end
            state.SeaEvent.UpdateStatus()
        end

        local function chestPart()
            local root = rootPart()
            if not root then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            -- Blox Fruits registers live server chests with this tag. Reading
            -- that registry avoids a full Workspace descendant scan every
            -- second and skips chests already marked IsDisabled.
            for _, serverChest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
                if serverChest:IsDescendantOf(workspace) and serverChest:GetAttribute("IsDisabled") ~= true then
                    local part = serverChest:IsA("BasePart") and serverChest
                        or serverChest:FindFirstChild("PushBox", true)
                        or serverChest:FindFirstChildWhichIsA("BasePart", true)
                    if part and part:IsA("BasePart") then
                        local distance = (part.Position - root.Position).Magnitude
                        if distance < bestDistance then
                            best = part
                            bestDistance = distance
                        end
                    end
                end
            end
            return best, bestDistance
        end

        local function stepChest()
            if os.clock() - state.LastChestScan < 1 then
                return
            end
            state.LastChestScan = os.clock()
            local chest, distance = chestPart()
            if not chest then
                setStatus("Waiting for a chest", nil)
                return
            end
            moveTo(chest.CFrame + Vector3.new(0, 3, 0))
            if distance and distance <= 10 and type(firetouchinterest) == "function" then
                local root = rootPart()
                if root then
                    pcall(firetouchinterest, root, chest, 0)
                    pcall(firetouchinterest, root, chest, 1)
                end
            end
            setStatus("Collecting nearest chest", true)
        end

        local function berryTarget()
            local root = rootPart()
            if not root then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            for _, streamed in ipairs(CollectionService:GetTagged("BerryBushStreamed")) do
                local berries = streamed:IsA("Configuration") and streamed
                    or streamed:FindFirstChild("Berries")
                    or streamed:FindFirstChildWhichIsA("Configuration")
                local bush = berries and berries.Parent
                if berries and bush and bush:IsDescendantOf(workspace) then
                    for key, berryName in pairs(berries:GetAttributes()) do
                        if string.sub(tostring(key), 1, 12) == "_BerryCFrame" and tostring(berryName) ~= "" then
                            local localCFrame = bush:GetAttribute(key)
                            if typeof(localCFrame) == "CFrame" then
                                local pivot = bush:IsA("Model") and bush:GetPivot()
                                    or (bush:IsA("BasePart") and bush.CFrame)
                                if pivot then
                                    local worldCFrame = pivot * localCFrame
                                    local distance = (worldCFrame.Position - root.Position).Magnitude
                                    if distance < bestDistance then
                                        bestDistance = distance
                                        best = {
                                            Bush = bush,
                                            Key = key,
                                            Name = tostring(berryName),
                                            CFrame = worldCFrame,
                                            Distance = distance,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return best
        end

        local function stepBerry()
            if os.clock() - state.LastBerryClaim < 0.35 then
                return
            end
            local target = berryTarget()
            if not target then
                berryLabel.Text = "Berries: Waiting for a streamed berry bush"
                setStatus("Waiting for a berry to spawn", nil)
                return
            end
            moveTo(target.CFrame + Vector3.new(0, 3, 0))
            berryLabel.Text = string.format("Berry: %s | %.0f studs", target.Name, target.Distance)
            if target.Distance <= 14 and ClaimBerry and ClaimBerry:IsA("RemoteFunction") then
                state.LastBerryClaim = os.clock()
                local ok, claimed = pcall(function()
                    return ClaimBerry:InvokeServer(target.Bush.Name, target.Key)
                end)
                if ok and claimed ~= false then
                    state.BerriesClaimed += 1
                    berryLabel.Text = string.format("Berries claimed: %d | Last: %s", state.BerriesClaimed, target.Name)
                    setStatus("Claimed " .. target.Name, true)
                elseif not ok then
                    setError("Berry claim failed: " .. tostring(claimed))
                end
            end
        end

        local function enabledStats()
            local values = {}
            for _, name in ipairs({"Melee", "Defense", "Sword", "Gun", "Demon Fruit"}) do
                if state.Stats[name] then
                    table.insert(values, name)
                end
            end
            return values
        end

        local function stepStats()
            if not state.AutoStats or currentPoints() <= 0 or os.clock() - state.LastStat < 0.35 then
                return
            end
            local stats = enabledStats()
            if #stats == 0 then
                return
            end
            state.LastStat = os.clock()
            state.StatIndex = state.StatIndex % #stats + 1
            invoke("AddPoint", stats[state.StatIndex], math.min(state.StatBatch, currentPoints()))
        end

        local function fruitTools()
            local result = {}
            for _, container in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), character()}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") then
                            local name = string.lower(tool.Name)
                            if string.find(name, "fruit", 1, true) or tool:GetAttribute("OriginalName") then
                                table.insert(result, tool)
                            end
                        end
                    end
                end
            end
            return result
        end

        local function storeFruits()
            if state.InventoryBusy then
                return 0, "Fruit storage is already busy"
            end
            local tools = fruitTools()
            if #tools == 0 then
                state.StoreStatus = "No physical fruit is being carried"
                return 0, state.StoreStatus
            end

            state.InventoryGeneration += 1
            local inventoryGeneration = state.InventoryGeneration
            local inventoryOwner = "auto-store:" .. tostring(inventoryGeneration)
            state.InventoryBusy = true
            state.InventoryBusyOwner = inventoryOwner
            local stored = 0
            local lastMessage = nil
            local operationOk, operationError = xpcall(function()
                local deadline = os.clock() + 0.75
                while state.AuraAttackPending and os.clock() < deadline do
                    task.wait()
                end
                local char = character()
                local body = humanoid()
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if not char or not body or not backpack then
                    error("character inventory is unavailable")
                end
                local previousTool = nil
                for _, child in ipairs(char:GetChildren()) do
                    if child:IsA("Tool") then
                        previousTool = child
                        break
                    end
                end

                for _, tool in ipairs(tools) do
                    if tool.Parent then
                        body:UnequipTools()
                        task.wait(0.10)
                        body:EquipTool(tool)
                        task.wait(0.18)
                        if tool.Parent and tool.Parent ~= char then
                            tool.Parent = char
                            task.wait(0.10)
                        end
                        if tool.Parent == char then
                            local originalName = tostring(tool:GetAttribute("OriginalName") or tool.Name)
                            local requestOk, requestResult = invoke("StoreFruit", originalName, tool)
                            task.wait(0.65)
                            local stillCarried = tool.Parent == char or tool.Parent == backpack
                            if requestOk and not stillCarried then
                                stored += 1
                                state.FruitsStored += 1
                                lastMessage = "Stored " .. originalName
                            else
                                lastMessage = stillCarried
                                    and ("Server kept " .. tool.Name .. " (storage full or duplicate)")
                                    or tostring(requestResult)
                            end
                        else
                            lastMessage = "Could not equip " .. tool.Name .. " for storage"
                        end
                    end
                end

                body:UnequipTools()
                task.wait(0.08)
                if previousTool and previousTool.Parent then
                    body:EquipTool(previousTool)
                elseif state.DoubleAttack then
                    local sword = toolForSelection("Sword")
                    if sword then
                        body:EquipTool(sword)
                    end
                end
            end, tracebackError)
            if state.InventoryGeneration ~= inventoryGeneration
                or state.InventoryBusyOwner ~= inventoryOwner then
                return stored, "Fruit storage was cancelled by an inventory lifecycle change"
            end
            state.InventoryBusy = false
            state.InventoryBusyOwner = nil
            if not operationOk then
                state.StoreStatus = "Storage failed: " .. tostring(operationError)
                return stored, state.StoreStatus
            end
            state.StoreStatus = lastMessage or string.format("Stored %d fruit(s)", stored)
            return stored, state.StoreStatus
        end

        local function rollFruitOnce()
            if state.GachaBusy then
                return false, "Fruit Gacha is already checking the server"
            end
            state.GachaBusy = true
            local before = {}
            for _, tool in ipairs(fruitTools()) do
                before[tool] = true
            end
            local operationOk, requestOk, requestResult = pcall(function()
                -- The current server requires the gacha box name on CheckTime.
                -- The old missing argument raised "boxName is nil" and stopped
                -- every automatic roll before the purchase request.
                local timeOk, timeResult = invoke("Cousin", "CheckTime", "DLCBoxData")
                if not timeOk then
                    return false, timeResult
                end
                local loweredTime = string.lower(tostring(timeResult or ""))
                if string.find(loweredTime, "must wait", 1, true)
                    or string.find(loweredTime, "wait ", 1, true) then
                    return false, timeResult
                end

                local buyOk, buyResult = invoke("Cousin", "DLCBoxData")
                if not buyOk then
                    return false, buyResult
                end
                task.wait(0.45)
                local wonTool = nil
                for _, tool in ipairs(fruitTools()) do
                    if not before[tool] then
                        wonTool = tool
                        break
                    end
                end
                state.GachaRolls += 1
                return true, wonTool and ("Won " .. wonTool.Name) or tostring(buyResult)
            end)
            state.GachaBusy = false
            if not operationOk then
                state.GachaStatus = "Gacha failed: " .. tostring(requestOk)
                return false, state.GachaStatus
            end
            state.GachaStatus = tostring(requestResult)
            if requestOk and state.AutoStoreFruit then
                task.defer(storeFruits)
            end
            return requestOk, requestResult
        end

        local function locationOptions()
            local result = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            if locations then
                for _, location in ipairs(locations:GetChildren()) do
                    if location.Name ~= "" and not seen[location.Name] then
                        seen[location.Name] = true
                        table.insert(result, location.Name)
                    end
                end
            end
            table.sort(result, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return result
        end

        local function npcOptions()
            local result = {"None"}
            local npcs = workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    table.insert(result, npc.Name)
                end
            end
            table.sort(result)
            return result
        end

        local function prepareManualTravel()
            -- A manual destination must own player movement until arrival.
            -- Leaving Auto Level or Mob Aura active makes those loops overwrite
            -- the travel tween every frame and produces the visible stutter.
            for _, flag in ipairs({
                "blox_auto_level",
                "blox_auto_boss",
                "blox_auto_raid",
                "blox_auto_chest",
                "blox_mob_aura_tp",
                "blox_selected_mob_farm",
                "blox_enemy_gather",
            }) do
                local control = Window.PersistentControls[flag]
                if control and control:Get() then
                    control:Set(false)
                end
            end
            state.AutoFarmLevel = false
            state.AutoBoss = false
            state.AutoRaid = false
            state.AutoChest = false
            state.MobAuraTp = false
            state.SelectedMobFarm = false
            state.GatherEnemies = false
            state.ActiveFarmTarget = nil
            FarmVertical.Release()
            state.MobAuraTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            cancelMove(false)
        end

        local function teleportToLocation(name)
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            local target = locations and locations:FindFirstChild(name)
            if not target then
                return false
            end
            local targetCFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
            -- Location markers are often island centers floating far above the
            -- actual ground. Ending at marker Y makes the player fall after a
            -- perfectly good tween, which looks like another snap-back. Land
            -- on the map surface at that X/Z whenever one is available.
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {
                workspace.Terrain,
                workspace:FindFirstChild("Map"),
            }
            params.IgnoreWater = true
            params.RespectCanCollide = true
            local ground = nil
            local groundScore = math.huge
            local markerPosition = targetCFrame.Position
            -- A marker can sit directly inside a tree, tower, or giant vine.
            -- Sample nearby columns and prefer a walkable surface close to the
            -- marker's intended elevation instead of landing on scenery.
            for _, offsetX in ipairs({0, -30, 30, -60, 60}) do
                for _, offsetZ in ipairs({0, -30, 30, -60, 60}) do
                    local result = workspace:Raycast(
                        markerPosition + Vector3.new(offsetX, 400, offsetZ),
                        Vector3.new(0, -1000, 0),
                        params
                    )
                    if result
                        and result.Normal.Y >= 0.45
                        and result.Position.Y >= markerPosition.Y - 300
                        and result.Position.Y <= markerPosition.Y + 180 then
                        local horizontalDistance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
                        local score = math.abs(result.Position.Y - markerPosition.Y) + horizontalDistance * 0.15
                        if score < groundScore then
                            ground = result
                            groundScore = score
                        end
                    end
                end
            end
            if ground then
                local root = rootPart()
                local body = humanoid()
                local clearance = (body and body.HipHeight or 2)
                    + (root and root.Size.Y * 0.5 or 1)
                    + 1
                local rotation = targetCFrame - targetCFrame.Position
                targetCFrame = CFrame.new(
                    ground.Position.X,
                    ground.Position.Y + clearance,
                    ground.Position.Z
                ) * rotation
            else
                targetCFrame += Vector3.new(0, 8, 0)
            end
            prepareManualTravel()
            if state.BypassTeleport and type(state.BypassWarp) == "function" then
                if state.BypassWarp(targetCFrame) then
                    return true
                end
            end
            return moveTo(targetCFrame)
        end

        local function teleportToNpc(name)
            local npcs = workspace:FindFirstChild("NPCs")
            local target = npcs and npcs:FindFirstChild(name)
            if not target then
                return false
            end
            prepareManualTravel()
            if state.BypassTeleport and type(state.BypassWarp) == "function" then
                if state.BypassWarp(target:GetPivot() * CFrame.new(0, 0, -4)) then
                    return true
                end
            end
            return moveTo(target:GetPivot() * CFrame.new(0, 0, -4))
        end

        local function applyNoclip()
            local char = character()
            if not char then
                return
            end
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if state.OriginalCollision[descendant] == nil then
                        state.OriginalCollision[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
        end

        local function restoreCollision()
            for part, original in pairs(state.OriginalCollision) do
                if part and part.Parent then
                    part.CanCollide = original
                end
            end
            table.clear(state.OriginalCollision)
        end

        local function updateEnergy()
            if not state.InfiniteEnergy then
                return
            end
            local char = character()
            local energy = char and char:FindFirstChild("Energy")
            if energy and energy:IsA("NumberValue") then
                energy.Value = math.max(energy.Value, energy:GetAttribute("MaxValue") or 10000)
            end
        end

        local function updateWaterPlatform()
            local automaticFarmSafety = state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
                or state.MobAuraTp or state.SelectedMobFarm or state.Traveling
            local shouldSupportWater = state.WalkOnWater or automaticFarmSafety
            if shouldSupportWater and not state.WaterPlatform then
                -- Build this once from the privileged startup/UI callback even
                -- when the character is still on the team-selection screen.
                -- Heartbeat may update Instances but some executors refuse to
                -- create them from an event-resumed coroutine.
                local platform = Instance.new("Part")
                platform.Name = "VOR_WaterPlatform"
                platform.Size = Vector3.new(30, 1, 30)
                platform.Anchored = true
                platform.CanCollide = false
                platform.Transparency = 1
                platform.CFrame = CFrame.new(0, -10000, 0)
                platform.Parent = workspace
                state.WaterPlatform = platform
            end
            if not shouldSupportWater then
                if state.WaterPlatform then
                    state.WaterPlatform.CanCollide = false
                    state.WaterPlatform.CFrame = CFrame.new(0, -10000, 0)
                end
                return
            end
            local root = rootPart()
            if not root then
                return
            end
            state.WaterPlatform.CanCollide = true
            -- Third Sea's outer ocean is Y=0. The separate sea inside the
            -- Submerged Island place has a fixed surface: the live dock/rope
            -- floor under the player's feet reads Y=-2161.389. Keep the
            -- invisible one-stud platform's TOP at that waterline. Only X/Z
            -- follows the player; following root.Y would make the floor sink
            -- along with a falling character and provide no support at all.
            local supportY = game.PlaceId == 100117331123089 and -2161.889 or 0
            state.WaterPlatform.CFrame = CFrame.new(root.Position.X, supportY, root.Position.Z)
        end

        local function backup(instance, values)
            if state.GraphicsBackup[instance] == nil then
                state.GraphicsBackup[instance] = values
            end
        end

        local function optimizeInstance(instance)
            if instance:IsA("BasePart") then
                backup(instance, {Material = instance.Material, Reflectance = instance.Reflectance})
                instance.Material = Enum.Material.Plastic
                instance.Reflectance = 0
            elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
                or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
                backup(instance, {Enabled = instance.Enabled})
                instance.Enabled = false
            end
        end

        local function setFpsBoost(enabled)
            state.FpsBoost = enabled == true
            if state.FpsBoost then
                backup(Lighting, {GlobalShadows = Lighting.GlobalShadows, EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale})
                Lighting.GlobalShadows = false
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
                for _, descendant in ipairs(workspace:GetDescendants()) do
                    pcall(optimizeInstance, descendant)
                end
            else
                for instance, values in pairs(state.GraphicsBackup) do
                    if instance and instance.Parent then
                        for property, value in pairs(values) do
                            pcall(function()
                                instance[property] = value
                            end)
                        end
                    end
                end
                table.clear(state.GraphicsBackup)
            end
        end

        local function clearHighlights(registry)
            for highlight in pairs(registry) do
                if highlight and highlight.Parent then
                    highlight:Destroy()
                end
                registry[highlight] = nil
            end
        end

        local function ensureHighlight(model, name, color, registry)
            if not model or not model.Parent then
                return
            end
            local highlight = model:FindFirstChild(name)
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = name
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillTransparency = 0.72
                highlight.OutlineTransparency = 0.08
                highlight.Parent = model
            end
            registry[highlight] = true
            highlight.FillColor = color
            highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
        end

        local PlayerEsp = {Bones = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
            {"Head", "Torso"},
            {"Torso", "Left Arm"},
            {"Torso", "Right Arm"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
        }}

        function PlayerEsp.Remove(player)
            local record = state.PlayerEspObjects[player]
            if not record then
                return
            end
            if record.Billboard then
                pcall(function()
                    record.Billboard:Destroy()
                end)
            end
            for _, line in ipairs(record.Lines or {}) do
                pcall(function()
                    line.Visible = false
                    line:Remove()
                end)
            end
            state.PlayerEspObjects[player] = nil
        end

        function PlayerEsp.Clear()
            for player in pairs(state.PlayerEspObjects) do
                PlayerEsp.Remove(player)
            end
        end

        function PlayerEsp.Count()
            local count = 0
            for _ in pairs(state.PlayerEspObjects) do
                count += 1
            end
            return count
        end

        function PlayerEsp.Create(player, playerCharacter)
            PlayerEsp.Remove(player)
            local head = playerCharacter and playerCharacter:FindFirstChild("Head")
            local root = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
            if not head and not root then
                return nil
            end

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "VOR_PlayerNameESP_" .. tostring(player.UserId)
            billboard.Adornee = head or root
            billboard.AlwaysOnTop = true
            billboard.LightInfluence = 0
            billboard.MaxDistance = 10000000
            billboard.Size = UDim2.fromOffset(260, 48)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
            billboard.Parent = gui

            local label = Instance.new("TextLabel")
            label.Name = "NameTag"
            label.BackgroundTransparency = 1
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextColor3 = COLORS.accent:Lerp(Color3.new(1, 1, 1), 0.28)
            label.TextSize = 14
            label.TextStrokeColor3 = Color3.new(0, 0, 0)
            label.TextStrokeTransparency = 0.05
            label.TextWrapped = true
            label.Parent = billboard

            local lines = {}
            if type(Drawing) == "table" and type(Drawing.new) == "function" then
                for _ = 1, #PlayerEsp.Bones do
                    local ok, line = pcall(Drawing.new, "Line")
                    if ok and line then
                        line.Color = COLORS.accent
                        line.Thickness = 2
                        line.Transparency = 0.95
                        line.ZIndex = 9
                        line.Visible = false
                        table.insert(lines, line)
                    end
                end
            end

            local record = {
                Character = playerCharacter,
                Billboard = billboard,
                Label = label,
                Lines = lines,
            }
            state.PlayerEspObjects[player] = record
            return record
        end

        function PlayerEsp.Update(allowCreate)
            if not state.PlayerESP then
                PlayerEsp.Clear()
                return
            end
            local camera = workspace.CurrentCamera
            local localRoot = rootPart()
            local now = os.clock()
            local updateText = now - state.PlayerEspLastTextUpdate >= 0.15
            if updateText then
                state.PlayerEspLastTextUpdate = now
            end

            for player, record in pairs(state.PlayerEspObjects) do
                if player.Parent ~= Players or not player.Character or record.Character ~= player.Character then
                    PlayerEsp.Remove(player)
                end
            end

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local record = state.PlayerEspObjects[player]
                    if allowCreate and (not record or record.Character ~= player.Character) then
                        record = PlayerEsp.Create(player, player.Character)
                    end
                    if record then
                        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                        local head = player.Character:FindFirstChild("Head") or targetRoot
                        record.Billboard.Adornee = head
                        record.Billboard.Enabled = head ~= nil
                        if updateText and targetRoot and localRoot then
                            local distance = (targetRoot.Position - localRoot.Position).Magnitude
                            record.Label.Text = string.format(
                                "%s  (@%s)\n%.0f studs",
                                player.DisplayName,
                                player.Name,
                                distance
                            )
                        end

                        if camera and #record.Lines > 0 then
                            for index, bone in ipairs(PlayerEsp.Bones) do
                                local line = record.Lines[index]
                                if line then
                                    local first = player.Character:FindFirstChild(bone[1])
                                    local second = player.Character:FindFirstChild(bone[2])
                                    if first and first:IsA("BasePart") and second and second:IsA("BasePart") then
                                        local firstPoint, firstVisible = camera:WorldToViewportPoint(first.Position)
                                        local secondPoint, secondVisible = camera:WorldToViewportPoint(second.Position)
                                        local visible = firstVisible and secondVisible
                                            and firstPoint.Z > 0 and secondPoint.Z > 0
                                        line.Visible = visible
                                        if visible then
                                            line.From = Vector2.new(firstPoint.X, firstPoint.Y)
                                            line.To = Vector2.new(secondPoint.X, secondPoint.Y)
                                        end
                                    else
                                        line.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local function updateEsp()
            if state.EnemyESP then
                for _, enemy in ipairs(loadedEnemies()) do
                    if modelAlive(enemy) then
                        ensureHighlight(enemy, "VOR_EnemyESP", COLORS.error, state.EnemyHighlights)
                    end
                end
            else
                clearHighlights(state.EnemyHighlights)
            end
            if state.PlayerESP then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        ensureHighlight(player.Character, "VOR_PlayerESP", COLORS.accent, state.PlayerHighlights)
                    end
                end
                PlayerEsp.Update(true)
            else
                clearHighlights(state.PlayerHighlights)
                PlayerEsp.Clear()
            end
        end

        local auraToggle
        local bossDropdown
        bossDropdown = BossSection:AddDropdown({
            Name = "Boss",
            Flag = "blox_boss",
            Options = bossNames(),
            Default = "None",
            Callback = function(value)
                state.SelectedBoss = tostring(value or "None")
                state.PositionTarget = nil
                state.PositionBasis = nil
                state.PositionAnchorY = nil
            end,
        })

        local levelQuestDropdown
        levelQuestDropdown = LevelSection:AddDropdown({
            Name = "Quest to Farm",
            Description = "Best automatically follows your level; manual choices list every quest giver available in this sea",
            Flag = "blox_level_quest",
            Options = currentSeaQuestOptions(),
            Default = AUTO_LEVEL_BEST_OPTION,
            Callback = function(value)
                state.SelectedLevelQuest = tostring(value or AUTO_LEVEL_BEST_OPTION)
                local quest = selectedLevelQuest()
                if quest then
                    questLabel.Text = string.format(
                        "Quest: %s | Target: %s | Lv. %d",
                        quest.DisplayName,
                        quest.EnemyName,
                        quest.LevelReq
                    )
                end
            end,
        })
        LevelSection:AddToggle({
            Name = "Auto Farm Level",
            Description = "Starts the selected current-sea quest and farms its required enemy",
            Flag = "blox_auto_level",
            Default = false,
            Callback = function(enabled)
                state.AutoFarmLevel = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                if enabled then
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.MobAuraTp = false
                    state.SelectedMobFarm = false
                    state.AutoChest = false
                    state.PositionTarget = nil
                    state.LastPositionJitterAt = 0
                    for _, flag in ipairs({
                        "blox_auto_boss",
                        "blox_auto_raid",
                        "blox_mob_aura_tp",
                        "blox_selected_mob_farm",
                        "blox_auto_chest",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                else
                    state.CurrentQuestName = nil
                    state.CurrentEnemyName = nil
                    cancelMove()
                end
            end,
        })
        LevelSection:AddToggle({
            Name = "Auto Collect Chests",
            Description = "Moves to the nearest loaded chest and collects it",
            Flag = "blox_auto_chest",
            Default = false,
            Callback = function(enabled)
                state.AutoChest = enabled
                if enabled then
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.MobAuraTp = false
                    state.SelectedMobFarm = false
                    for _, flag in ipairs({
                        "blox_auto_level",
                        "blox_auto_boss",
                        "blox_auto_raid",
                        "blox_mob_aura_tp",
                        "blox_selected_mob_farm",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                end
            end,
        })

        FarmSettingsSection:AddSlider({
            Name = "Tween Speed",
            Flag = "blox_tween_speed",
            Min = 50,
            Max = 650,
            Step = 10,
            Default = 300,
            Callback = function(value)
                state.TweenSpeed = value
            end,
        })
        FarmSettingsSection:AddLabel("The shared Farm Position Controller drives Auto Level, bosses, raids, Mob Aura, and selected-mob farming.")
        FarmSettingsSection:AddToggle({
            Name = "Safe Mode",
            Description = "Retreats above the target until health recovers past the selected threshold",
            Flag = "blox_safe_mode",
            Default = false,
            Callback = function(enabled)
                state.SafeMode = enabled
            end,
        })
        FarmSettingsSection:AddSlider({
            Name = "Safe Mode Health %",
            Flag = "blox_safe_health",
            Min = 5,
            Max = 95,
            Step = 1,
            Default = 30,
            Callback = function(value)
                state.SafeHealthPercent = value
            end,
        })
        WorldFarmSection:AddButton({
            Name = "Refresh Live Quest Data",
            Description = "Refreshes every quest available in this sea and re-reads the selected quest",
            Callback = function()
                local options = currentSeaQuestOptions()
                if levelQuestDropdown then
                    levelQuestDropdown:SetOptions(options, true)
                end
                local quest = selectedLevelQuest()
                if quest then
                    questLabel.Text = string.format("Quest: %s | %s", quest.DisplayName, quest.EnemyName)
                    Window:Notify("Blox Fruits", "Selected quest: " .. quest.DisplayName, 3)
                else
                    setError("The selected quest is not available in this sea")
                end
            end,
        })

        ExploitSection:AddToggle({
            Name = "Auto Magnet",
            Description = "Continuously locks every eligible NPC into the farm target's pile so server corrections cannot leave mobs behind",
            Flag = "blox_auto_magnet",
            Default = false,
            Callback = function(enabled)
                state.AutoMagnet = enabled
                if not enabled then
                    state.Gathered = 0
                end
                gui:SetAttribute("BloxAutoMagnet", enabled)
            end,
        })
        ExploitSection:AddSlider({
            Name = "Magnet Range",
            Description = "Pull magnitude from 0 to 500 studs, matching Solix Hub's range",
            Flag = "blox_magnet_range",
            Min = 0,
            Max = 500,
            Step = 10,
            Default = 300,
            Callback = function(value)
                state.MagnetRange = math.clamp(tonumber(value) or 300, 0, 500)
                state.LastGatherScan = 0
                gui:SetAttribute("BloxMagnetRange", state.MagnetRange)
            end,
        })
        ExploitSection:AddLabel("Mob Aura anchors the target while Auto Magnet drags every nearby NPC into its pile; normal Aura rotates damage through them.")
        local auraRangeSlider
        local mobAuraHeightSlider
        local mobAuraToggle
        local mobAuraSquareToggle
        local selectedMobFarmToggle
        local selectedMobDropdown

        local function resetMobAuraOrbit()
            state.MobAuraOrbitStartedAt = os.clock()
            state.MobAuraOrbitStartAngle = math.random() * math.pi * 2
            state.MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1
            state.MobAuraSquareOffset = Vector3.zero
            state.MobAuraSquareCorner = 0
            state.MobAuraLastSquareStep = 0
            state.PositionJitter = Vector3.zero
            state.PositionJitterCorner = 0
            state.LastPositionJitterAt = 0
        end

        local function requiredMobAuraRange()
            local radius = state.MobAuraRandomSquare and (state.MobAuraSquareSize * math.sqrt(2))
                or (state.MobAuraOrbit and state.MobAuraOrbitRadius or 0)
            local baseRadius = math.sqrt(state.FarmPositionX ^ 2 + state.FarmPositionZ ^ 2)
            local pathDistance = math.sqrt(state.MobAuraHeight ^ 2 + (baseRadius + radius) ^ 2)
            return math.min(AURA_KILL_MAX_RANGE, math.ceil(pathDistance + 8))
        end

        function FarmVertical.SetCalmPose(enabled)
            local char = character()
            local animate = char and char:FindFirstChild("Animate")
            if not enabled or not animate or not animate:IsA("LocalScript") then
                if state.FarmAnimationConnection then
                    pcall(function()
                        state.FarmAnimationConnection:Disconnect()
                    end)
                end
                local previous = state.FarmAnimateScript
                if previous and previous.Parent and state.FarmAnimateWasDisabled ~= nil then
                    pcall(function()
                        previous.Disabled = state.FarmAnimateWasDisabled
                    end)
                end
                state.FarmAnimateScript = nil
                state.FarmAnimateWasDisabled = nil
                state.FarmAnimator = nil
                state.FarmAnimationConnection = nil
                gui:SetAttribute("BloxFarmCalmPose", false)
                return
            end

            if state.FarmAnimateScript ~= animate then
                state.FarmAnimateScript = animate
                state.FarmAnimateWasDisabled = animate.Disabled
            end
            -- Solix-style calm travel: keep Roblox's animator alive so the rig
            -- retains its natural idle pose, but remove movement/attack tracks
            -- that flicker when CFrame tweening reports a fake Running state.
            animate.Disabled = false
            local body = humanoid()
            local animator = body and body:FindFirstChildOfClass("Animator")
            if body then
                body:Move(Vector3.zero, false)
            end
            if animator then
                if state.FarmAnimator ~= animator then
                    if state.FarmAnimationConnection then
                        pcall(function()
                            state.FarmAnimationConnection:Disconnect()
                        end)
                    end
                    state.FarmAnimator = animator
                    state.FarmAnimationConnection = animator.AnimationPlayed:Connect(function(animationTrack)
                        if gui:GetAttribute("BloxFarmCalmPose") ~= true then
                            return
                        end
                        local trackName = string.lower(tostring(animationTrack.Name))
                        local isIdle = animationTrack.Priority == Enum.AnimationPriority.Idle
                            or trackName == "idle"
                            or trackName == "animation1"
                            or trackName == "animation2"
                        if not isIdle then
                            pcall(function()
                                animationTrack:Stop(0)
                            end)
                        end
                    end)
                end
                local idleAnimationIds = {}
                local idleFolder = animate:FindFirstChild("idle")
                if idleFolder then
                    for _, descendant in ipairs(idleFolder:GetDescendants()) do
                        if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
                            idleAnimationIds[descendant.AnimationId] = true
                        end
                    end
                end
                for _, animationTrack in ipairs(animator:GetPlayingAnimationTracks()) do
                    local trackName = string.lower(tostring(animationTrack.Name))
                    local animation = animationTrack.Animation
                    local animationId = animation and animation.AnimationId or ""
                    local isIdle = idleAnimationIds[animationId] == true
                        or animationTrack.Priority == Enum.AnimationPriority.Idle
                        or trackName == "idle"
                        or trackName == "animation1"
                        or trackName == "animation2"
                    if not isIdle then
                        pcall(function()
                            animationTrack:Stop(0)
                        end)
                    end
                end
            end
            gui:SetAttribute("BloxFarmCalmPose", true)
        end

        local function syncMobAuraRange()
            local requiredRange = requiredMobAuraRange()
            if (state.MobAuraTp or state.SelectedMobFarm)
                and state.AuraRange < requiredRange and auraRangeSlider then
                auraRangeSlider:Set(requiredRange)
            end
        end

        auraToggle = AttackSection:AddToggle({
            Name = "Aura Kill",
            Description = "Rapid silent tool hits on living NPCs inside the selected range; never swings your character",
            -- Keep the legacy flag so profiles that enabled Auto Attack now
            -- enable its Aura Kill replacement instead of losing the setting.
            Flag = "blox_auto_attack",
            Default = false,
            Callback = function(enabled)
                if state.AuraKill ~= enabled then
                    state.AuraAttackGeneration += 1
                    state.FruitDispatchGeneration += 1
                    state.AuraAttackPending = false
                    state.AuraAttackPendingAt = 0
                    state.FruitDispatchPending = false
                    state.FruitDispatchPendingAt = 0
                    state.AuraFruitBusy = false
                end
                state.AuraKill = enabled
                state.LastAttack = 0
                state.LastAuraScan = 0
                state.AuraTargetCursor = 0
                if enabled then
                    resolveRegisterHitClosure()
                    local busoControl = Window.PersistentControls["blox_auto_buso"]
                    if busoControl and not busoControl:Get() then
                        busoControl:Set(true, true)
                    end
                    state.AutoBuso = true
                    task.defer(function()
                        if state.Alive and state.AutoBuso then
                            ensureBuso(true)
                        end
                    end)
                end
                auraLabel.Text = enabled
                    and string.format("Aura Kill: Armed | Range: %.0f studs", state.AuraRange)
                    or string.format("Aura Kill: Off | Range: %.0f studs", state.AuraRange)
                auraLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
                gui:SetAttribute("BloxAuraKill", enabled)
                gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
                -- Compatibility for existing external status readers.
                gui:SetAttribute("BloxAutoAttack", enabled)
            end,
        })
        auraRangeSlider = AttackSection:AddSlider({
            Name = "Aura Kill Range",
            Description = "Server-tested silent-hit range in studs (70 is the safe maximum)",
            Flag = "blox_aura_kill_range",
            Min = 5,
            Max = AURA_KILL_MAX_RANGE,
            Step = 1,
            Default = AURA_KILL_DEFAULT_RANGE,
            Callback = function(value)
                state.AuraRange = math.clamp(tonumber(value) or AURA_KILL_DEFAULT_RANGE, 5, AURA_KILL_MAX_RANGE)
                if (state.MobAuraTp or state.SelectedMobFarm)
                    and state.MobAuraHeight > state.AuraRange - 8 then
                    local adjustedHeight = math.max(3, state.AuraRange - 8)
                    if mobAuraHeightSlider then
                        mobAuraHeightSlider:Set(adjustedHeight)
                    else
                        state.MobAuraHeight = adjustedHeight
                    end
                end
                auraLabel.Text = state.AuraKill
                    and string.format("Aura Kill: Armed | Range: %.0f studs", state.AuraRange)
                    or string.format("Aura Kill: Off | Range: %.0f studs", state.AuraRange)
                gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
                if state.MobAuraTp or state.SelectedMobFarm then
                    task.defer(syncMobAuraRange)
                end
            end,
        })
        AttackSection:AddToggle({
            Name = "Aura Kill Turbo",
            Description = "Uses the shortest validated silent-hit cadence instead of the tool's native cooldown",
            Flag = "blox_fast_attack",
            Default = false,
            Callback = function(enabled)
                state.FastAttack = enabled
                gui:SetAttribute("BloxFastAttack", enabled)
            end,
        })
        local weaponStatusLabel
        AttackSection:AddDropdown({
            Name = "Weapon",
            Description = "Best Available automatically uses starter Combat on fresh accounts, then upgrades with your inventory",
            Flag = "blox_weapon_type",
            Options = {"Sword", "Melee", "M1 Fruit", "Best Available"},
            Default = "Best Available",
            Callback = function(value)
                state.AuraAttackGeneration += 1
                state.FruitDispatchGeneration += 1
                state.AuraAttackPending = false
                state.AuraAttackPendingAt = 0
                state.FruitDispatchPending = false
                state.FruitDispatchPendingAt = 0
                state.AuraFruitBusy = false
                state.WeaponType = tostring(value)
                state.AuraCombo = 0
                table.clear(state.AuraCombos)
                local tool = selectedTool()
                if not tool then
                    state.AuraPendingError = "No " .. state.WeaponType .. " Tool was found"
                else
                    updateAuraWeaponState(tool, state.WeaponType)
                end
            end,
        })
        weaponStatusLabel = AttackSection:AddLabel("Weapon: waiting for selection")
        AttackSection:AddToggle({
            Name = "Double Attack (Sword + Fruit M1)",
            Description = "Dungeon-style engine: silent 12-target Sword batches plus independent 3-target Fruit M1",
            Flag = "blox_double_attack",
            Default = false,
            Callback = function(enabled)
                if state.DoubleAttack ~= enabled then
                    state.AuraAttackGeneration += 1
                    state.FruitDispatchGeneration += 1
                    state.AuraAttackPending = false
                    state.AuraAttackPendingAt = 0
                    state.FruitDispatchPending = false
                    state.FruitDispatchPendingAt = 0
                    state.AuraFruitBusy = false
                end
                state.DoubleAttack = enabled
                state.LastAttack = 0
                state.LastDoubleFruitAttack = 0
                table.clear(state.AuraCombos)
                -- Write executor-owned GUI telemetry before touching live Tool
                -- Instances. Some executors downgrade the resumed coroutine's
                -- UI capability after crossing back into game-owned objects.
                gui:SetAttribute("BloxDoubleAttack", enabled)
                if enabled then
                    local sword = toolForSelection("Sword")
                    local fruit = toolForSelection("M1 Fruit")
                    if sword and fruit then
                        state.AuraWeaponName = sword.Name .. " + " .. fruit.Name
                        state.AuraWeaponType = "Sword + Blox Fruit"
                        state.AuraAttackMode = "Double Attack"
                    else
                        state.AuraPendingError = "Double Attack requires both a Sword and a Blox Fruit Tool"
                    end
                else
                    local tool = selectedTool()
                    updateAuraWeaponState(tool, state.WeaponType)
                end
            end,
        })
        AttackSection:AddSlider({
            Name = "Fruit M1 Cooldown Reduction",
            Description = "Manual left-click cooldown removal; 1.0 removes both the normal 0.3s gate and the fifth-hit 1.0s gate",
            Flag = "blox_fruit_m1_cooldown_reduction",
            Min = 0,
            Max = DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
            Step = 0.01,
            Default = DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
            Callback = function(value)
                local reduction = applyFruitM1CooldownReduction(value)
                state.LastAttack = 0
                gui:SetAttribute("BloxFruitM1CooldownReduction", reduction)
            end,
        })
        applyFruitM1CooldownReduction(state.FruitM1CooldownReduction)
        AttackSection:AddSlider({
            Name = "Extra Aura Delay",
            Flag = "blox_attack_interval",
            Min = 0,
            Max = 0.50,
            Step = 0.01,
            Default = 0,
            Callback = function(value)
                state.AttackInterval = value
            end,
        })
        mobAuraToggle = MobFarmSection:AddToggle({
            Name = "Mob Aura TP",
            Description = "Teleports above the nearest living workspace.Enemies NPC and keeps Aura Kill armed",
            Flag = "blox_mob_aura_tp",
            Default = false,
            Callback = function(enabled)
                if enabled and state.SelectedMobFarm and selectedMobFarmToggle then
                    selectedMobFarmToggle:Set(false)
                end
                state.MobAuraTp = enabled
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                if enabled then
                    resetMobAuraOrbit()
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.AutoChest = false
                    for _, flag in ipairs({
                        "blox_auto_level",
                        "blox_auto_boss",
                        "blox_auto_raid",
                        "blox_auto_chest",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                    cancelMove()
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                    syncMobAuraRange()
                    mobAuraLabel.Text = "Mob Aura TP: Searching for nearest NPC..."
                    mobAuraLabel.TextColor3 = COLORS.success
                else
                    mobAuraLabel.Text = "Mob Aura TP: Off | Distance: --"
                    mobAuraLabel.TextColor3 = COLORS.muted
                    if not state.SelectedMobFarm and not state.Noclip and not state.AutoFarmLevel and not state.AutoBoss
                        and not state.AutoRaid and not state.AutoChest then
                        restoreCollision()
                    end
                end
                gui:SetAttribute("BloxMobAuraTp", enabled)
            end,
        })
        MobFarmSection:AddInput({
            Name = "Mob Aura Search Distance",
            Description = "Type the exact nearest-NPC search distance you want, such as 630",
            Flag = "blox_mob_aura_search_range",
            Default = 500,
            Placeholder = "Example: 630",
            Callback = function(value)
                state.MobAuraSearchRange = math.clamp(
                    tonumber(value) or state.MobAuraSearchRange,
                    25,
                    1000000000
                )
                state.MobAuraTarget = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            end,
        })
        selectedMobDropdown = MobFarmSection:AddDropdown({
            Name = "Mob Farm Enemy",
            Flag = "blox_selected_mob_name",
            Options = mobFarmOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedMobName = tostring(value or "None")
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            end,
        })
        selectedMobFarmToggle = MobFarmSection:AddToggle({
            Name = "Selected Mob Farm TP",
            Description = "Farms only the chosen enemy and waits above its spawn when none are currently loaded",
            Flag = "blox_selected_mob_farm",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraTp and mobAuraToggle then
                    mobAuraToggle:Set(false)
                end
                state.SelectedMobFarm = enabled
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                if enabled then
                    resetMobAuraOrbit()
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.AutoChest = false
                    for _, flag in ipairs({
                        "blox_auto_level",
                        "blox_auto_boss",
                        "blox_auto_raid",
                        "blox_auto_chest",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                    cancelMove()
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                    syncMobAuraRange()
                    selectedMobFarmLabel.Text = state.SelectedMobName == "None"
                        and "Selected Mob Farm: Choose an enemy"
                        or ("Selected Mob Farm: Searching for " .. state.SelectedMobName)
                    selectedMobFarmLabel.TextColor3 = state.SelectedMobName == "None"
                        and COLORS.warning or COLORS.success
                else
                    selectedMobFarmLabel.Text = "Selected Mob Farm: Off | Enemy: " .. state.SelectedMobName
                    selectedMobFarmLabel.TextColor3 = COLORS.muted
                    if not state.MobAuraTp and not state.Noclip and not state.AutoFarmLevel and not state.AutoBoss
                        and not state.AutoRaid and not state.AutoChest then
                        restoreCollision()
                    end
                end
                gui:SetAttribute("BloxSelectedMobFarm", enabled)
            end,
        })
        MobFarmSection:AddInput({
            Name = "Selected Mob Search Distance",
            Description = "Type the exact chosen-enemy search distance instead of fighting a giant slider",
            Flag = "blox_selected_mob_search_range",
            Default = 30000,
            Placeholder = "Example: 630",
            Callback = function(value)
                state.SelectedMobSearchRange = math.clamp(
                    tonumber(value) or state.SelectedMobSearchRange,
                    25,
                    1000000000
                )
                state.MobAuraTarget = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            end,
        })
        MobFarmSection:AddButton({
            Name = "Refresh Mob Farm Enemies",
            Description = "Re-reads enemy spawns and currently loaded workspace.Enemies names",
            Callback = function()
                selectedMobDropdown:SetOptions(mobFarmOptions(), true)
                if gatherMobDropdown then
                    gatherMobDropdown:SetOptions(gatherMobOptions(), true)
                end
                Window:Notify("Mob Farm", "Enemy list refreshed", 2.5)
            end,
        })
        FarmPositionSection:AddLabel("One position state for every farm mode. Old profile flags migrate automatically.")
        FarmPositionSection:AddSlider({
            Name = "Position X",
            Description = "Shared left/right offset from the current target",
            Flag = "blox_farm_position_x",
            Min = -30,
            Max = 30,
            Step = 1,
            Default = 0,
            Callback = function(value)
                state.FarmPositionX = math.clamp(tonumber(value) or 0, -30, 30)
                syncMobAuraRange()
                gui:SetAttribute("BloxFarmPositionX", state.FarmPositionX)
            end,
        })
        mobAuraHeightSlider = FarmPositionSection:AddSlider({
            Name = "Position Y / Height",
            Description = "Shared height for Auto Level, Boss, Raid, Mob Aura, and Selected Mob Farm",
            Flag = "blox_farm_position_height",
            Min = 3,
            Max = AURA_KILL_MAX_RANGE - 10,
            Step = 1,
            Default = 20,
            Callback = function(value)
                state.MobAuraHeight = math.clamp(tonumber(value) or 20, 3, AURA_KILL_MAX_RANGE - 10)
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            end,
        })
        FarmPositionSection:AddSlider({
            Name = "Position Z",
            Description = "Shared forward/back offset from the current target",
            Flag = "blox_farm_position_z",
            Min = -30,
            Max = 30,
            Step = 1,
            Default = 0,
            Callback = function(value)
                state.FarmPositionZ = math.clamp(tonumber(value) or 0, -30, 30)
                syncMobAuraRange()
                gui:SetAttribute("BloxFarmPositionZ", state.FarmPositionZ)
            end,
        })
        FarmPositionSection:AddToggle({
            Name = "Random Orbit",
            Description = "Shared circular movement for every farm mode; the NPC itself never moves",
            Flag = "blox_farm_position_orbit",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraRandomSquare and mobAuraSquareToggle then
                    mobAuraSquareToggle:Set(false)
                end
                state.MobAuraOrbit = enabled
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraOrbit", enabled)
            end,
        })
        FarmPositionSection:AddSlider({
            Name = "Orbit Radius",
            Description = "Shared horizontal circle size while Combat Farm Height controls elevation",
            Flag = "blox_farm_position_orbit_radius",
            Min = 2,
            Max = 25,
            Step = 1,
            Default = 8,
            Callback = function(value)
                state.MobAuraOrbitRadius = math.clamp(tonumber(value) or 8, 2, 25)
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            end,
        })
        FarmPositionSection:AddSlider({
            Name = "Orbit Speed",
            Description = "Degrees per second to spin around the NPC",
            Flag = "blox_farm_position_orbit_speed",
            Min = 20,
            Max = 720,
            Step = 10,
            Default = 110,
            Callback = function(value)
                state.MobAuraOrbitSpeed = math.clamp(tonumber(value) or 110, 20, 720)
                resetMobAuraOrbit()
                gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            end,
        })
        mobAuraSquareToggle = FarmPositionSection:AddToggle({
            Name = "Random Square",
            Description = "Shared square movement for reliable Fruit M1 aim in Auto Level, Boss, Raid, and Mob Aura",
            Flag = "blox_farm_position_random_square",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraOrbit then
                    local orbitControl = Window.PersistentControls["blox_farm_position_orbit"]
                        or Window.PersistentControls["blox_mob_aura_orbit"]
                    if orbitControl then
                        orbitControl:Set(false)
                    end
                end
                state.MobAuraRandomSquare = enabled
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraRandomSquare", enabled)
            end,
        })
        FarmPositionSection:AddSlider({
            Name = "Square Size",
            Description = "Distance from the NPC center to each square corner",
            Flag = "blox_farm_position_square_size",
            Min = 2,
            Max = 15,
            Step = 1,
            Default = 8,
            Callback = function(value)
                state.MobAuraSquareSize = math.clamp(tonumber(value) or 8, 2, 15)
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            end,
        })
        FarmPositionSection:AddSlider({
            Name = "Square Step Delay",
            Description = "Seconds between square corner teleports; lower is faster",
            Flag = "blox_farm_position_square_interval",
            Min = 0.06,
            Max = 0.80,
            Step = 0.02,
            Default = 0.18,
            Callback = function(value)
                state.MobAuraSquareInterval = math.clamp(tonumber(value) or 0.18, 0.06, 0.80)
                resetMobAuraOrbit()
                gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            end,
        })
        AttackSection:AddToggle({
            Name = "Auto Buso",
            Description = "Uses the game's native Aura action, verifies HasBuso, and restores it after respawn on PC and mobile",
            Flag = "blox_auto_buso",
            Default = true,
            Callback = function(enabled)
                state.AutoBuso = enabled
                gui:SetAttribute("BloxAutoBuso", enabled)
                state.LastBuso = -math.huge
                if enabled then
                    task.defer(function()
                        if state.Alive and state.AutoBuso then
                            ensureBuso(true)
                        end
                    end)
                else
                    refreshBusoStatus()
                end
            end,
        })
        AttackSection:AddToggle({
            Name = "Auto Observation (Ken)",
            Description = "Keeps Instinct active with E input, mobile HUD button, and verified state fallback",
            Flag = "blox_auto_observation",
            Default = false,
            Callback = function(enabled)
                state.AutoObservation = enabled
                state.LastObservation = 0
                if not enabled and LocalPlayer:GetAttribute("KenActive") == true then
                    task.defer(function()
                        pcall(function()
                            local input = game:GetService("VirtualInputManager")
                            input:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.04)
                            input:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end)
                    end)
                end
            end,
        })

        BossSection:AddButton({
            Name = "Refresh Boss List",
            Callback = function()
                bossDropdown:SetOptions(bossNames(), false)
                Window:Notify("Boss Farm", "Boss list refreshed", 2.5)
            end,
        })
        BossSection:AddToggle({
            Name = "Auto Farm Selected Boss",
            Description = "Moves to the boss spawn, waits for it, and attacks when available",
            Flag = "blox_auto_boss",
            Default = false,
            Callback = function(enabled)
                state.AutoBoss = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                state.PositionBasis = nil
                state.PositionAnchorY = nil
                if enabled then
                    state.AutoFarmLevel = false
                    state.AutoRaid = false
                    state.MobAuraTp = false
                    state.SelectedMobFarm = false
                    state.AutoChest = false
                    for _, flag in ipairs({
                        "blox_auto_level",
                        "blox_auto_raid",
                        "blox_mob_aura_tp",
                        "blox_selected_mob_farm",
                        "blox_auto_chest",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                else
                    cancelMove()
                end
                gui:SetAttribute("BloxAutoBoss", enabled)
            end,
        })

        StatsSection:AddToggle({
            Name = "Auto Stats",
            Flag = "blox_auto_stats",
            Default = false,
            Callback = function(enabled)
                state.AutoStats = enabled
            end,
        })
        StatsSection:AddSlider({
            Name = "Points Per Request",
            Flag = "blox_stat_batch",
            Min = 1,
            Max = 100,
            Step = 1,
            Default = 1,
            Callback = function(value)
                state.StatBatch = value
            end,
        })
        for _, statName in ipairs({"Melee", "Defense", "Sword", "Gun", "Demon Fruit"}) do
            StatsSection:AddToggle({
                Name = statName,
                Flag = "blox_stat_" .. string.lower((statName:gsub("%s+", "_"))),
                Default = state.Stats[statName] == true,
                Callback = function(enabled)
                    state.Stats[statName] = enabled
                end,
            })
        end

        FruitSection:AddButton({
            Name = "Roll Blox Fruit Once",
            Description = "Rolls remotely from your current position; no dealer teleport",
            Callback = function()
                task.spawn(function()
                    local ok, result = rollFruitOnce()
                    Window:Notify("Fruit Gacha", ok and tostring(result) or tostring(result), 4)
                end)
            end,
        })
        FruitSection:AddToggle({
            Name = "Auto Fruit Gacha",
            Description = "Checks and rolls remotely from anywhere without moving your character",
            Flag = "blox_auto_gacha",
            Default = false,
            Callback = function(enabled)
                state.AutoGacha = enabled
                if enabled then
                    state.LastGacha = -math.huge
                    state.GachaStatus = "Checking remote gacha..."
                end
                gui:SetAttribute("BloxAutoGacha", enabled)
            end,
        })
        FruitSection:AddSlider({
            Name = "Gacha Retry Seconds",
            Description = "How often Auto Gacha checks the server cooldown",
            Flag = "blox_gacha_interval",
            Min = 10,
            Max = 120,
            Step = 5,
            Default = 30,
            Callback = function(value)
                state.GachaInterval = math.clamp(tonumber(value) or 30, 10, 120)
                gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            end,
        })
        FruitSection:AddButton({
            Name = "Store Carried Fruits",
            Callback = function()
                task.spawn(function()
                    local stored, message = storeFruits()
                    Window:Notify("Fruit Storage", string.format("Stored: %d | %s", stored, tostring(message)), 4)
                end)
            end,
        })
        FruitSection:AddToggle({
            Name = "Auto Store Fruits",
            Flag = "blox_auto_store_fruit",
            Default = false,
            Callback = function(enabled)
                state.AutoStoreFruit = enabled
                if enabled then
                    state.LastStore = -math.huge
                end
                gui:SetAttribute("BloxAutoStoreFruit", enabled)
            end,
        })

        local locationDropdown
        local npcDropdown
        locationDropdown = TravelSection:AddDropdown({
            Name = "Island / Location",
            Flag = "blox_location",
            Options = locationOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedLocation = tostring(value or "None")
            end,
        })
        npcDropdown = TravelSection:AddDropdown({
            Name = "Loaded NPC",
            Flag = "blox_npc",
            Options = npcOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedNPC = tostring(value or "None")
            end,
        })
        TravelSection:AddButton({
            Name = "Teleport to Selected Location",
            Callback = function()
                local ok = state.SelectedLocation ~= "None" and teleportToLocation(state.SelectedLocation)
                Window:Notify("Travel", ok and ("Traveling to " .. state.SelectedLocation) or "Choose a valid location", 3)
            end,
        })
        TravelSection:AddButton({
            Name = "Teleport to Selected NPC",
            Callback = function()
                local ok = state.SelectedNPC ~= "None" and teleportToNpc(state.SelectedNPC)
                Window:Notify("Travel", ok and ("Traveling to " .. state.SelectedNPC) or "Choose a loaded NPC", 3)
            end,
        })
        TravelSection:AddButton({
            Name = "Refresh Travel Lists",
            Callback = function()
                locationDropdown:SetOptions(locationOptions(), false)
                npcDropdown:SetOptions(npcOptions(), false)
                Window:Notify("Travel", "Locations and NPCs refreshed", 2.5)
            end,
        })
        TravelSection:AddButton({Name = "Travel to First Sea", Callback = function() invoke("TravelMain") end})
        TravelSection:AddButton({Name = "Travel to Second Sea", Callback = function() invoke("TravelDressrosa") end})
        TravelSection:AddButton({Name = "Travel to Third Sea", Callback = function() invoke("TravelZou") end})

        local fightingStyles = {
            {"Superhuman", "BuySuperhuman"},
            {"Death Step", "BuyDeathStep"},
            {"Sharkman Karate", "BuySharkmanKarate"},
            {"Electric Claw", "BuyElectricClaw"},
            {"Dragon Talon", "BuyDragonTalon"},
            {"Godhuman", "BuyGodhuman"},
        }
        for _, entry in ipairs(fightingStyles) do
            FightingStyleSection:AddButton({
                Name = "Check / Buy " .. entry[1],
                Description = "Uses the game's own purchase endpoint; requirements still apply",
                Callback = function()
                    local ok, result = invoke(entry[2], true)
                    Window:Notify(entry[1], ok and tostring(result or "Request sent") or tostring(result), 3)
                end,
            })
        end

        local raidTypes = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Quake", "Buddha", "Spider", "Rumble", "Phoenix", "Dough"}
        RaidSection:AddDropdown({
            Name = "Raid Chip",
            Flag = "blox_raid_chip",
            Options = raidTypes,
            Default = "Flame",
            Callback = function(value)
                state.SelectedRaid = tostring(value)
            end,
        })
        RaidSection:AddButton({
            Name = "Buy Selected Raid Chip",
            Callback = function()
                local ok, result = invoke("RaidsNpc", "Select", state.SelectedRaid)
                Window:Notify("Raid Chip", ok and "Purchase request sent" or tostring(result), 3)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Buy Raid Chip",
            Flag = "blox_auto_buy_raid_chip",
            Default = false,
            Callback = function(enabled)
                state.AutoBuyRaidChip = enabled
            end,
        })
        RaidSection:AddButton({
            Name = "Start Dungeon / Raid Once",
            Callback = function()
                task.spawn(function()
                    local ok, result = fireRaidButton()
                    Window:Notify("Raid", tostring(result), 3)
                end)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Start Dungeon / Raid",
            Flag = "blox_auto_start_raid",
            Default = false,
            Callback = function(enabled)
                state.AutoStartRaid = enabled
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Farm Dungeon / Raid",
            Flag = "blox_auto_raid",
            Default = false,
            Callback = function(enabled)
                state.AutoRaid = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                if enabled then
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.MobAuraTp = false
                    state.SelectedMobFarm = false
                    state.AutoChest = false
                    for _, flag in ipairs({
                        "blox_auto_level",
                        "blox_auto_boss",
                        "blox_mob_aura_tp",
                        "blox_selected_mob_farm",
                        "blox_auto_chest",
                    }) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                else
                    state.RaidIslandIndex = 0
                    state.RaidIslandName = nil
                    state.RaidTargetName = nil
                    state.ActiveFarmHeightOverride = nil
                    state.RaidVoidActive = false
                    state.RaidVoidMoved = 0
                    cancelMove()
                end
                gui:SetAttribute("BloxAutoRaid", enabled)
                gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
                gui:SetAttribute("BloxRaidIslandName", state.RaidIslandName or "")
                gui:SetAttribute("BloxRaidTarget", state.RaidTargetName or "")
            end,
        })
        RaidSection:AddLabel("Raid farm stays at least 35 studs above NPCs. Combat Height can raise it, never lower it.")
        RaidSection:AddLabel("Auto Magnet in Combat handles raid NPC stacking and yields to final-island Void Kill automatically.")
        RaidSection:AddToggle({
            Name = "Force Kill Aura [Island 5]",
            Description = "Matches Solix: network-finishes Island 5 NPCs at full health and leaves each corpse replicated to fall naturally",
            Flag = "blox_raid_void_kill",
            Default = false,
            Callback = function(enabled)
                state.RaidVoidKill = enabled
                state.RaidVoidActive = false
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                if enabled then
                    state.LastRaidVoidStep = 0
                    state.RaidVoidKillCount = 0
                    table.clear(state.RaidVoidTargets)
                    table.clear(state.RaidVoidOriginalCFrames)
                end
                gui:SetAttribute("BloxRaidVoidKill", enabled)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Awakening",
            Flag = "blox_auto_awaken",
            Default = false,
            Callback = function(enabled)
                state.AutoAwaken = enabled
            end,
        })

        state.SeaEvent.Section = SeaPage:AddSection("Sea Event Automation", "Right")
        state.SeaEvent.Section:AddDropdown({
            Name = "Sea Monster Selection",
            Description = "Select several sea enemies; VOR kills each active target and returns to the boat",
            Flag = "blox_sea_event_priority",
            Options = {
                "Piranha",
                "Shark",
                "Terror Shark",
                "Fish Crew Member",
                "Enemy Boat",
                "Sea Beast",
            },
            Multi = true,
            Default = {
                "Piranha",
                "Shark",
                "Terror Shark",
                "Fish Crew Member",
                "Enemy Boat",
                "Sea Beast",
            },
            Callback = function(value)
                state.SeaEvent.SelectedEvents = type(value) == "table" and value or {}
            end,
        })
        state.SeaEvent.Section:AddDropdown({
            Name = "Selected Boat",
            Description = "The server must show this boat as owned/unlocked",
            Flag = "blox_sea_event_boat",
            Options = state.SeaEvent.BoatNames,
            Default = "Guardian",
            Callback = function(value)
                state.SeaEvent.SelectedBoat = tostring(value)
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Boat Tween Speed",
            Description = "Requested speed from 0-500; snap-back detection automatically finds a lower server-safe limit",
            Flag = "blox_sea_event_boat_speed",
            Min = 0,
            Max = 500,
            Step = 10,
            Default = 295,
            Callback = function(value)
                state.SeaEvent.BoatTweenSpeed = math.clamp(tonumber(value) or 295, 0, 500)
                state.SeaEvent.ResetAdaptiveSpeed()
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Boat Float Height",
            Description = "Extra height above the boat's native waterline; keep 0 for the server-safe Solix path",
            Flag = "blox_sea_event_boat_height",
            Min = 0,
            Max = 10,
            Step = 1,
            Default = 0,
            Callback = function(value)
                state.SeaEvent.BoatFloatHeight = math.clamp(tonumber(value) or 0, 0, 10)
            end,
        })
        state.SeaEvent.Section:AddDropdown({
            Name = "Stop Sail Condition",
            Description = "Select any event islands where Auto Stop Sail should freeze the boat",
            Flag = "blox_sea_event_stop_conditions",
            Options = {"Kitsune Island", "Prehistoric Island", "Mirage Island", "Frozen Dimension"},
            Multi = true,
            Default = {},
            Callback = function(value)
                state.SeaEvent.StopConditions = type(value) == "table" and value or {}
                state.SeaEvent.StopMatch = nil
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Stop Sail",
            Description = "Stops the boat when any selected island condition is detected",
            Flag = "blox_sea_event_auto_stop",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoStopSail = enabled == true
                state.SeaEvent.StopMatch = nil
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Sea Combat Height",
            Description = "Terror Sharks and boats stay below you; Sea Beasts use half this height to keep you inside their hitbox",
            Flag = "blox_sea_event_combat_height",
            Min = 8,
            Max = 70,
            Step = 1,
            Default = 24,
            Callback = function(value)
                state.SeaEvent.CombatHeight = math.clamp(tonumber(value) or 24, 8, 70)
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Spam Every Tool Skill",
            Description = "Used only for Sea Beasts and enemy boats; sharks use Aura Kill + Double Attack",
            Flag = "blox_sea_event_all_skills",
            Default = true,
            Callback = function(enabled)
                state.SeaEvent.SpamAllSkills = enabled == true
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Sea Water Damage Guard",
            Description = "Keeps your fight position above the water plane and maintains an invisible safety floor",
            Flag = "blox_sea_event_water_guard",
            Default = true,
            Callback = function(enabled)
                state.SeaEvent.WaterGuard = enabled == true
                if not enabled then
                    state.SeaEvent.DestroySafety()
                end
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Reset When Boat Breaks",
            Description = "Respawns at the dock, buys the selected boat again, reseats, and resumes sailing",
            Flag = "blox_sea_event_reset_boat",
            Default = true,
            Callback = function(enabled)
                state.SeaEvent.ResetBrokenBoat = enabled == true
            end,
        })
        state.SeaEvent.Section:AddButton({
            Name = "Buy / Replace Boat at NPC",
            Description = "Goes to the Boat Dealer, speaks to the NPC, and buys a fresh selected boat even if the old one is bugged",
            Callback = function()
                local sailControl = Window.PersistentControls["blox_auto_sea_events"]
                if sailControl and not sailControl:Get() then
                    sailControl:Set(true)
                else
                    state.SeaEvent.AutoSail = true
                    state.SeaEvent.Enabled = true
                end
                state.SeaEvent.RequestNewBoat()
                Window:Notify("Sea Events", "Replacing the bugged boat at the dealer.", 3)
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Kill Sea Enemy",
            Description = "Leaves the boat, kills every selected sea enemy without touching water, then reseats",
            Flag = "blox_auto_kill_sea_enemy",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoKill = enabled == true
                state.SeaEvent.Enabled = state.SeaEvent.AutoSail or state.SeaEvent.AutoKill
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                if enabled then
                    prepareManualTravel()
                    state.SeaEvent.ConfigureAuraCombat()
                    state.SeaEvent.Phase = "Searching for selected sea enemies"
                else
                    state.SeaEvent.DestroySafety()
                    if not state.SeaEvent.Enabled then
                        state.SeaEvent.Phase = "Off"
                        state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                        state.SeaEvent.RestoreBoatNoclip()
                        state.SeaEvent.LastCommandedPosition = nil
                    end
                end
                state.SeaEvent.UpdateStatus()
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Sail",
            Description = "Buys the selected boat, seats normally, and sails straight at the server-safe waterline",
            Flag = "blox_auto_sea_events",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoSail = enabled == true
                state.SeaEvent.Enabled = state.SeaEvent.AutoSail or state.SeaEvent.AutoKill
                state.SeaEvent.LastError = nil
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                if enabled then
                    prepareManualTravel()
                    state.SeaEvent.Phase = "Finding Boat Dealer"
                    state.SeaEvent.ResetAdaptiveSpeed()
                else
                    state.SeaEvent.Phase = state.SeaEvent.AutoKill and "Auto Kill waiting" or "Off"
                    state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                    state.SeaEvent.RestoreBoatNoclip()
                    if not state.SeaEvent.AutoKill then
                        state.SeaEvent.DestroySafety()
                    end
                    state.SeaEvent.LastCommandedPosition = nil
                end
                state.SeaEvent.UpdateStatus()
            end,
        })
        state.SeaEvent.StatusLabel = state.SeaEvent.Section:AddLabel("Sea Events: Off")
        state.SeaEvent.DetailLabel = state.SeaEvent.Section:AddLabel(
            "Boat: Guardian | Event: Searching | Snap-backs: 0 | Completed: 0"
        )

        track(RunService.Heartbeat:Connect(function(deltaTime)
            if not state.Alive then
                return
            end
            local ok, message = pcall(state.SeaEvent.Step, deltaTime)
            if not ok then
                state.SeaEvent.LastError = tostring(message)
                state.SeaEvent.Phase = "Error: " .. tostring(message)
                state.SeaEvent.UpdateStatus()
            end
        end))

        PlayerStateSection:AddToggle({
            Name = "Noclip",
            Flag = "blox_noclip",
            Default = false,
            Callback = function(enabled)
                state.Noclip = enabled
                if not enabled then
                    restoreCollision()
                end
            end,
        })
        updateWaterPlatform()
        PlayerStateSection:AddToggle({
            Name = "Infinite Energy",
            Flag = "blox_infinite_energy",
            Default = false,
            Callback = function(enabled)
                state.InfiniteEnergy = enabled
            end,
        })
        PlayerStateSection:AddToggle({
            Name = "Walk on Water",
            Flag = "blox_walk_water",
            Default = true,
            Callback = function(enabled)
                state.WalkOnWater = enabled
                gui:SetAttribute("BloxWalkOnWater", enabled)
                updateWaterPlatform()
            end,
        })
        PlayerStateSection:AddToggle({
            Name = "Anti-AFK / Anti-Idle",
            Flag = "blox_anti_afk",
            Default = true,
            Callback = function(enabled)
                state.AntiAfk = enabled
            end,
        })

        VisualSection:AddToggle({
            Name = "Enemy ESP",
            Flag = "blox_enemy_esp",
            Default = false,
            Callback = function(enabled)
                state.EnemyESP = enabled
                updateEsp()
            end,
        })
        VisualSection:AddToggle({
            Name = "Player ESP",
            Description = "Unlimited-distance highlight, name and distance tag, plus an on-screen joint skeleton",
            Flag = "blox_player_esp",
            Default = false,
            Callback = function(enabled)
                state.PlayerESP = enabled
                gui:SetAttribute("BloxPlayerESP", enabled)
                updateEsp()
            end,
        })
        VisualSection:AddToggle({
            Name = "Reversible FPS Boost",
            Description = "Disables world effects and restores them when switched off",
            Flag = "blox_fps_boost",
            Default = false,
            Callback = function(enabled)
                setFpsBoost(enabled)
            end,
        })

        SessionSection:AddButton({
            Name = "Rejoin Current Server",
            Callback = function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end,
        })
        SessionSection:AddButton({
            Name = "Server Hop",
            Description = "Finds a different non-full public server",
            Callback = function()
                task.spawn(function()
                    local ok, message = pcall(function()
                        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
                        local data = HttpService:JSONDecode(game:HttpGet(url))
                        for _, server in ipairs(data.data or {}) do
                            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                                return
                            end
                        end
                        error("No open server was found")
                    end)
                    if not ok then
                        Window:Notify("Server Hop", tostring(message), 4)
                    end
                end)
            end,
        })

        track(LocalPlayer.Idled:Connect(function()
            if state.AntiAfk then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                    task.wait(0.05)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                end)
            end
        end))

        track(LocalPlayer.CharacterAdded:Connect(function(newCharacter)
            cancelMove(false)
            FarmVertical.Release()
            state.LastAttack = 0
            state.LastAuraScan = 0
            state.AuraAttackGeneration += 1
            state.FruitDispatchGeneration += 1
            state.AuraAttackPending = false
            state.AuraAttackPendingAt = 0
            state.RegisterHitClosure = nil
            state.LastRegisterHitResolve = -math.huge
            state.LastBuso = -math.huge
            state.AuraTargetCursor = 0
            state.AuraCombo = 0
            table.clear(state.AuraCombos)
            table.clear(state.NativeFruitCombos)
            state.FruitM1ReadyAt = 0
            state.AuraFruitBusy = false
            state.FruitDispatchPending = false
            state.FruitDispatchPendingAt = 0
            state.LastDoubleFruitAttack = 0
            state.InventoryGeneration += 1
            state.InventoryBusy = false
            state.InventoryBusyOwner = nil
            state.AuraFruitInRange = nil
            state.AuraFruitLastDistance = nil
            state.OriginalFruitTapCooldown = tonumber(newCharacter:GetAttribute("FruitTAPCooldown")) or 0
            newCharacter:SetAttribute("FruitTAPCooldown", state.FruitM1CooldownReduction)
            resetMobAuraOrbit()
            state.MobAuraTarget = nil
            state.MobAuraTargetName = nil
            state.MobAuraDistance = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.GatherSingleFallbackEnemy = nil
            table.clear(state.GatherOriginalCFrames)
            table.clear(state.GatherOriginalStates)
            state.MagnetAnchorTarget = nil
            state.MagnetAnchorCFrame = nil
            state.MagnetAnchorName = nil
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.AntiRagdollApplied = false
            state.AntiRagdollHumanoid = nil
            state.FarmAnimateScript = nil
            state.FarmAnimateWasDisabled = nil
            state.FarmAnimator = nil
            state.FarmAnimationConnection = nil
            if state.AutoBuso then
                task.delay(0.5, function()
                    if state.Alive and state.AutoBuso then
                        ensureBuso(true)
                    end
                end)
            end
            task.delay(0.15, function()
                if state.Alive and newCharacter.Parent then
                    FarmVertical.RecoverBody()
                end
            end)
        end))

        track(LocalPlayer:GetAttributeChangedSignal("IslandRaiding"):Connect(function()
            cancelMove(false)
            FarmVertical.Release()
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.PositionTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.RaidVoidActive = false
            state.RaidVoidMoved = 0
            state.RaidVoidStaged = 0
            state.RaidGathered = 0
            if LocalPlayer:GetAttribute("IslandRaiding") == true then
                local now = os.clock()
                local freshRaid = not state.RaidHasEntered
                    or now - state.RaidLastInactiveAt >= 3
                state.RaidHasEntered = true
                state.RaidEnteredAt = freshRaid and now or 0
                if freshRaid then
                    state.RaidVoidKillCount = 0
                    state.LastRaidVoidStep = 0
                    table.clear(state.RaidVoidTargets)
                    table.clear(state.RaidVoidOriginalCFrames)
                end
            else
                state.RaidEnteredAt = 0
                state.RaidLastInactiveAt = os.clock()
            end
            task.defer(function()
                if state.Alive then
                    FarmVertical.RecoverBody()
                end
            end)
        end))

        track(RunService.Heartbeat:Connect(function()
            if not state.Alive then
                return
            end
            if state.MobAuraTp or state.SelectedMobFarm then
                applyNoclip()
                stepMobAuraTp()
            end
            local attackBlocked = state.SafeMode and healthPercent() <= state.SafeHealthPercent
            if not attackBlocked and state.AuraKill then
                if state.DoubleAttack then
                    DoubleAttackEngine.StepFruit()
                end
                auraKillOnce()
            end
            local combatFarmEnabled = state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
                or state.ThirdSeaFarmActive
            FarmVertical.SetAntiRagdoll(combatFarmEnabled)
            FarmVertical.SetCalmPose(state.AuraKill and (
                combatFarmEnabled or state.MobAuraTp or state.SelectedMobFarm
            ))
            local activeCombatFarm = combatFarmEnabled and modelAlive(state.ActiveFarmTarget)
            -- Noclip remains enabled while waiting at a quest/boss/raid spawn.
            -- Keep a vertical hold for that entire session or gravity sends the
            -- player through the map the moment the current NPC disappears.
            if combatFarmEnabled then
                applyNoclip()
                if not state.Traveling then
                    FarmVertical.RecoverBody()
                end
            end
            if activeCombatFarm
                and not attackBlocked
                and not state.AuraFruitBusy then
                local farmTarget = state.ActiveFarmTarget
                if modelAlive(farmTarget) then
                    local targetCFrame = positionAtEnemy(
                        farmTarget,
                        state.ActiveFarmVerticalLock,
                        state.ActiveFarmHeightOverride
                    )
                    if targetCFrame then
                        if state.MobAuraOrbit or state.MobAuraRandomSquare then
                            moveToFarmPosition(targetCFrame)
                        elseif not state.Traveling then
                            -- The fixed-above mode still needs to own the exact
                            -- farm altitude. Otherwise FarmVertical can remember
                            -- a gravity-sagged frame and fight the main farm loop,
                            -- which was the visible boss up/down bounce.
                            state.FarmHoldY = targetCFrame.Position.Y
                        end
                    end
                end
            end
            if combatFarmEnabled then
                FarmVertical.Ensure()
            else
                FarmVertical.Release()
            end
            gatherStep()
            if state.Noclip or state.Traveling or state.MobAuraTp or state.SelectedMobFarm
                or state.AutoFarmLevel or state.AutoBoss or state.AutoRaid or state.AutoChest
                or state.ThirdSeaFarmActive then
                applyNoclip()
            end
            updateEnergy()
            updateWaterPlatform()
        end))

        track(RunService.RenderStepped:Connect(function()
            if state.Alive and state.PlayerESP then
                PlayerEsp.Update(false)
            end
        end))

        track(workspace.DescendantAdded:Connect(function(descendant)
            if state.FpsBoost then
                task.defer(function()
                    if descendant.Parent then
                        pcall(optimizeInstance, descendant)
                    end
                end)
            end
        end))

        task.spawn(function()
            local lastRaidPurchase = 0
            local lastRaidStart = 0
            local lastAwaken = 0
            local lastEsp = 0
            local lastQuestDataRefresh = 0
            local lastQuestDataFingerprint = ""
            while state.Alive do
                local ok, message = pcall(function()
                    flushAuraTelemetry()
                    gui:SetAttribute("BloxAutoLevel", state.AutoFarmLevel)
                    gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
                    gui:SetAttribute("BloxAutoRaid", state.AutoRaid)
                    gui:SetAttribute("BloxAutoBuso", state.AutoBuso)
                    gui:SetAttribute("BloxWalkOnWater", state.WalkOnWater)
                    gui:SetAttribute("BloxPlayerESP", state.PlayerESP)
                    if os.clock() - lastQuestDataRefresh >= 6 then
                        lastQuestDataRefresh = os.clock()
                        local options = currentSeaQuestOptions()
                        local fingerprint = table.concat({
                            state.CurrentSeaName,
                            tostring(state.CurrentSeaQuestCount),
                            tostring(state.CurrentSeaMinimumLevel),
                            tostring(state.CurrentSeaMaximumLevel),
                        }, "|")
                        if fingerprint ~= lastQuestDataFingerprint then
                            lastQuestDataFingerprint = fingerprint
                            if levelQuestDropdown then
                                levelQuestDropdown:SetOptions(options, true)
                            end
                            if state.SelectedLevelQuest ~= AUTO_LEVEL_BEST_OPTION
                                and not levelQuestByOption[state.SelectedLevelQuest] then
                                state.SelectedLevelQuest = AUTO_LEVEL_BEST_OPTION
                                if levelQuestDropdown then
                                    levelQuestDropdown:Set(AUTO_LEVEL_BEST_OPTION)
                                end
                            end
                        end
                    end
                    if weaponStatusLabel then
                        if state.AuraWeaponName then
                            local weaponText = string.format(
                                "Weapon: %s | %s",
                                state.AuraWeaponName,
                                state.AuraAttackMode or state.AuraWeaponType or state.WeaponType
                            )
                            local mode = string.lower(tostring(state.AuraAttackMode or state.WeaponType))
                            local fruitActive = state.DoubleAttack or string.find(mode, "fruit", 1, true) ~= nil
                            if fruitActive then
                                if state.AuraFruitLastDistance then
                                    weaponText = weaponText .. string.format(
                                        state.AuraFruitInRange
                                            and " | Fruit %.1f / %d studs"
                                            or " | Fruit OUT OF RANGE %.1f / %d studs",
                                        state.AuraFruitLastDistance,
                                        NATIVE_FRUIT_MAX_RANGE
                                    )
                                else
                                    weaponText = weaponText .. string.format(
                                        " | Fruit native reach: %d studs",
                                        NATIVE_FRUIT_MAX_RANGE
                                    )
                                end
                            end
                            weaponStatusLabel.Text = weaponText
                            weaponStatusLabel.TextColor3 = fruitActive and state.AuraFruitInRange == false
                                and COLORS.warning or COLORS.success
                        else
                            weaponStatusLabel.Text = "Weapon: No " .. tostring(state.WeaponType) .. " Tool found"
                            weaponStatusLabel.TextColor3 = COLORS.muted
                        end
                    end
                    if state.SelectedMobFarm then
                        if state.SelectedMobName == "None" then
                            selectedMobFarmLabel.Text = "Selected Mob Farm: Choose an enemy"
                            selectedMobFarmLabel.TextColor3 = COLORS.warning
                        elseif state.MobAuraTargetName and state.MobAuraDistance then
                            selectedMobFarmLabel.Text = string.format(
                                "Selected Mob Farm: %s | Distance: %.1f | Height: %.0f%s",
                                state.MobAuraTargetName,
                                state.MobAuraDistance,
                                state.MobAuraHeight,
                                state.MobAuraRandomSquare and string.format(" | Square: %.0f", state.MobAuraSquareSize)
                                    or (state.MobAuraOrbit and string.format(" | Orbit: %.0f", state.MobAuraOrbitRadius) or "")
                            )
                            selectedMobFarmLabel.TextColor3 = COLORS.success
                        elseif state.SelectedMobWaitingAtSpawn then
                            selectedMobFarmLabel.Text = string.format(
                                "Selected Mob Farm: Waiting above %s spawn | Height: %.0f",
                                state.SelectedMobName,
                                state.MobAuraHeight
                            )
                            selectedMobFarmLabel.TextColor3 = COLORS.muted
                        else
                            selectedMobFarmLabel.Text = "Selected Mob Farm: No spawn found for " .. state.SelectedMobName
                            selectedMobFarmLabel.TextColor3 = COLORS.warning
                        end
                    elseif state.MobAuraTp then
                        if state.MobAuraTargetName and state.MobAuraDistance then
                            if state.MobAuraRandomSquare then
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Square: %.0f @ %.2fs",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight,
                                    state.MobAuraSquareSize,
                                    state.MobAuraSquareInterval
                                )
                            elseif state.MobAuraOrbit then
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Orbit: %.0f @ %.0f deg/s",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight,
                                    state.MobAuraOrbitRadius,
                                    state.MobAuraOrbitSpeed
                                )
                            else
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Fixed above",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight
                                )
                            end
                            mobAuraLabel.TextColor3 = COLORS.success
                        elseif state.MobAuraDistance then
                            mobAuraLabel.Text = string.format(
                                "Mob Aura TP: No NPC within %.0f | Nearest: %.1f",
                                state.MobAuraSearchRange,
                                state.MobAuraDistance
                            )
                            mobAuraLabel.TextColor3 = COLORS.muted
                        else
                            mobAuraLabel.Text = string.format(
                                "Mob Aura TP: Waiting for NPC | Search: %.0f",
                                state.MobAuraSearchRange
                            )
                            mobAuraLabel.TextColor3 = COLORS.muted
                        end
                    end
                    if state.AutoRaid then
                        stepRaid()
                    elseif state.AutoBoss then
                        stepBossFarm()
                    elseif state.AutoFarmLevel then
                        stepAutoLevel()
                    elseif state.AutoChest then
                        stepChest()
                    elseif state.AuraKill then
                        local targets = nearbyAuraTargets()
                        local target = targets[1]
                        if target then
                            state.CurrentEnemyName = normalizeEnemyName(target.Enemy.Name)
                            targetLabel.Text = string.format("Aura target: %s | %.1f / %.0f studs", state.CurrentEnemyName, target.Distance, state.AuraRange)
                        else
                            targetLabel.Text = string.format("Aura target: No living NPC within %.0f studs", state.AuraRange)
                        end
                        auraLabel.Text = string.format(
                            "Aura Kill: Armed | In range: %d | Damage hits: %d | Requests: %d",
                            #targets,
                            state.AuraHits,
                            state.AuraRequests
                        )
                        auraLabel.TextColor3 = #targets > 0 and COLORS.success or COLORS.muted
                    end

                    if state.AutoBuso then
                        ensureBuso(false)
                    else
                        refreshBusoStatus()
                    end

                    if state.AutoObservation
                        and LocalPlayer:GetAttribute("KenActive") ~= true
                        and os.clock() - state.LastObservation >= 1 then
                        state.LastObservation = os.clock()
                        pcall(function()
                            local input = game:GetService("VirtualInputManager")
                            input:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.04)
                            input:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end)
                        task.delay(0.2, function()
                            if not state.Alive or not state.AutoObservation
                                or LocalPlayer:GetAttribute("KenActive") == true then
                                return
                            end
                            pcall(function()
                                local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                                local main = playerGui and playerGui:FindFirstChild("Main")
                                local hud = main and main:FindFirstChild("BottomHUDList")
                                local buttons = hud and hud:FindFirstChild("UniversalContextButtons")
                                local ken = buttons and buttons:FindFirstChild("BoundActionKen")
                                local button = ken and (ken:FindFirstChild("Button") or ken:FindFirstChild("CaptureInput"))
                                if button and type(firesignal) == "function" then
                                    firesignal(button.Activated)
                                    firesignal(button.MouseButton1Click)
                                elseif CommE then
                                    CommE:FireServer("Ken", true)
                                end
                            end)
                        end)
                    end

                    stepStats()

                    if state.AutoGacha and os.clock() - state.LastGacha >= state.GachaInterval then
                        state.LastGacha = os.clock()
                        task.spawn(rollFruitOnce)
                    end
                    if state.AutoStoreFruit and os.clock() - state.LastStore >= 8 then
                        state.LastStore = os.clock()
                        task.spawn(storeFruits)
                    end
                    fruitGachaLabel.Text = string.format(
                        "Fruit Gacha: %s | Rolls this session: %d | Retry: %.0fs",
                        state.GachaStatus,
                        state.GachaRolls,
                        state.GachaInterval
                    )
                    fruitGachaLabel.TextColor3 = state.GachaBusy and COLORS.warning
                        or (state.GachaRolls > 0 and COLORS.success or COLORS.muted)
                    fruitStoreLabel.Text = string.format(
                        "Fruit Storage: %s | Stored this session: %d",
                        state.StoreStatus,
                        state.FruitsStored
                    )
                    fruitStoreLabel.TextColor3 = state.InventoryBusy and COLORS.warning
                        or (state.FruitsStored > 0 and COLORS.success or COLORS.muted)

                    if state.AutoBuyRaidChip and not RaidRuntime.Active()
                        and not RaidRuntime.RaidChip()
                        and os.clock() - lastRaidPurchase >= 15 then
                        lastRaidPurchase = os.clock()
                        invoke("RaidsNpc", "Select", state.SelectedRaid)
                    end
                    if state.AutoStartRaid and not RaidRuntime.Active() and os.clock() - lastRaidStart >= 5 then
                        lastRaidStart = os.clock()
                        fireRaidButton()
                    end
                    if state.AutoAwaken and os.clock() - lastAwaken >= 4 then
                        lastAwaken = os.clock()
                        invoke("Awakener", "Awaken")
                    end

                    local magnetText = string.format(
                        "Auto Magnet: %s | Stacked: %d | Range: %d",
                        state.AutoMagnet and "On" or "Off",
                        state.Gathered,
                        state.MagnetRange
                    )
                    if magnetText ~= state.LastGatherLabelText then
                        state.LastGatherLabelText = magnetText
                        magnetLabel.Text = magnetText
                    end

                    if os.clock() - lastEsp >= 1 then
                        lastEsp = os.clock()
                        if state.EnemyESP or state.PlayerESP then
                            updateEsp()
                        end
                        seaLabel.Text = string.format(
                            "Sea: %s | Quests: %d (Lv. %d-%d) | Loaded enemies: %d",
                            state.CurrentSeaName,
                            state.CurrentSeaQuestCount,
                            state.CurrentSeaMinimumLevel,
                            state.CurrentSeaMaximumLevel,
                            #loadedEnemies()
                        )
                        playerLabel.Text = string.format("Player: Level %d | Stat points %d", currentLevel(), currentPoints())
                        observationLabel.Text = string.format(
                            "Observation: %s | Dodges: %s / %s",
                            state.AutoObservation and "Auto" or "Manual",
                            tostring(LocalPlayer:GetAttribute("KenDodgesLeft") or "N/A"),
                            tostring(LocalPlayer:GetAttribute("KenMaxDodges") or "N/A")
                        )
                        gui:SetAttribute("BloxPlayerESPCount", PlayerEsp.Count())
                        gui:SetAttribute(
                            "BloxPlayerESPSkeletonSupported",
                            type(Drawing) == "table" and type(Drawing.new) == "function"
                        )
                        gui:SetAttribute("BloxRaidActive", RaidRuntime.Active())
                        gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
                        gui:SetAttribute("BloxRaidIslandName", state.RaidIslandName or "")
                        gui:SetAttribute("BloxRaidTarget", state.RaidTargetName or "")
                        gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
                        gui:SetAttribute("BloxRaidMultiGrabCount", state.RaidGathered)
                        gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
                        gui:SetAttribute("BloxRaidVoidActive", state.RaidVoidActive)
                        gui:SetAttribute("BloxRaidVoidMoved", state.RaidVoidMoved)
                        gui:SetAttribute("BloxRaidVoidStaged", state.RaidVoidStaged)
                        gui:SetAttribute("BloxRaidVoidKillCount", state.RaidVoidKillCount)
                        gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
                    end
                end)
                if not ok then
                    setError(message)
                end
                task.wait(0.12)
            end
        end)

        local cleaned = false
        local function cleanup()
            if cleaned then
                return
            end
            cleaned = true
            if state.DamageDebugConnection then
                pcall(function()
                    state.DamageDebugConnection:Disconnect()
                end)
                state.DamageDebugConnection = nil
            end
            state.Alive = false
            state.AuraAttackGeneration += 1
            state.FruitDispatchGeneration += 1
            state.AuraAttackPending = false
            state.AuraAttackPendingAt = 0
            state.AuraKill = false
            state.MobAuraTp = false
            state.SelectedMobFarm = false
            state.AuraFruitBusy = false
            state.FruitDispatchPending = false
            state.FruitDispatchPendingAt = 0
            state.GachaBusy = false
            state.InventoryGeneration += 1
            state.InventoryBusy = false
            state.InventoryBusyOwner = nil
            state.MobAuraTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.GatherSingleFallbackEnemy = nil
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.RaidMultiGrab = false
            state.RaidVoidKill = false
            state.RaidVoidActive = false
            state.RaidVoidMoved = 0
            state.RaidVoidStaged = 0
            state.SeaEvent.Enabled = false
            state.SeaEvent.StopBoat(state.SeaEvent.Boat)
            state.SeaEvent.RestoreBoatNoclip()
            state.SeaEvent.DestroySafety()
            FarmVertical.SetAntiRagdoll(false)
            FarmVertical.SetCalmPose(false)
            FarmVertical.Release()
            for enemy in pairs(state.GatherOriginalStates) do
                state.RestoreGatherEnemy(enemy, true)
            end
            table.clear(state.GatherOriginalCFrames)
            table.clear(state.GatherOriginalStates)
            for enemy, originalCFrame in pairs(state.RaidVoidOriginalCFrames) do
                local enemyRoot = modelRoot(enemy)
                local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                if enemyRoot and enemyBody and enemyBody.Health > 0 then
                    pcall(function()
                        enemyBody.PlatformStand = false
                        enemyRoot.CFrame = originalCFrame
                        enemyRoot.AssemblyLinearVelocity = Vector3.zero
                        enemyRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
            table.clear(state.RaidVoidTargets)
            table.clear(state.RaidVoidOriginalCFrames)
            local char = character()
            if char and state.OriginalFruitTapCooldown ~= nil then
                char:SetAttribute("FruitTAPCooldown", state.OriginalFruitTapCooldown)
            end
            cancelMove()
            restoreCollision()
            state.WalkOnWater = false
            updateWaterPlatform()
            if state.WaterPlatform then
                pcall(function()
                    state.WaterPlatform:Destroy()
                end)
                state.WaterPlatform = nil
            end
            PlayerEsp.Clear()
            if state.AutoObservation and CommE then
                pcall(function()
                    CommE:FireServer("Ken", false)
                end)
            end
            if state.FpsBoost then
                setFpsBoost(false)
            end
            clearHighlights(state.EnemyHighlights)
            clearHighlights(state.PlayerHighlights)
        end

        if gui then
            gui:SetAttribute("BloxFruitsModule", true)
            gui:SetAttribute("BloxFruitsNative", true)
            gui:SetAttribute("BloxFruitsUniverseId", 994732206)
            gui:SetAttribute("BloxFruitsRuntimeDependency", "None")
            gui:SetAttribute("RuntimeDependency", "None")
            gui:SetAttribute("BloxFruitsEnemyGatherSource", "NativeVOR")
            gui:SetAttribute("BloxTraveling", false)
            gui:SetAttribute("BloxTravelGoal", Vector3.zero)
            gui:SetAttribute("BloxAuraKill", state.AuraKill)
            gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
            gui:SetAttribute("BloxAuraKillTargets", 0)
            gui:SetAttribute("BloxAuraMultiTargetCount", 0)
            gui:SetAttribute("BloxAuraKillHitCount", state.AuraHits)
            gui:SetAttribute("BloxAuraKillRequestCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraKillStage", state.AuraStage)
            gui:SetAttribute("BloxAuraSwordRequestCount", state.AuraSwordRequests)
            gui:SetAttribute("BloxAuraFruitRequestCount", state.AuraFruitRequests)
            gui:SetAttribute("BloxAuraKillLastTarget", "")
            gui:SetAttribute("BloxAuraKillLastDistance", 0)
            gui:SetAttribute("BloxAuraKillLastRequestAt", 0)
            gui:SetAttribute("BloxAuraKillLastHitAt", 0)
            gui:SetAttribute("BloxAuraWeaponSelection", state.WeaponType)
            gui:SetAttribute("BloxAuraWeaponName", state.AuraWeaponName or "")
            gui:SetAttribute("BloxAuraWeaponType", state.AuraWeaponType or "")
            gui:SetAttribute("BloxAuraAttackMode", state.AuraAttackMode or "")
            gui:SetAttribute("BloxDoubleAttack", state.DoubleAttack)
            gui:SetAttribute("BloxFruitM1CooldownReduction", state.FruitM1CooldownReduction)
            gui:SetAttribute("BloxAuraFruitNativeRange", NATIVE_FRUIT_MAX_RANGE)
            gui:SetAttribute("BloxAuraFruitInRange", false)
            gui:SetAttribute("BloxAuraFruitLastDistance", 0)
            gui:SetAttribute("BloxMobAuraTp", state.MobAuraTp)
            gui:SetAttribute("BloxSelectedMobFarm", state.SelectedMobFarm)
            gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            gui:SetAttribute("BloxSelectedMobWaitingAtSpawn", false)
            gui:SetAttribute("BloxMobAuraMode", "Off")
            gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            gui:SetAttribute("BloxMobAuraOrbit", state.MobAuraOrbit)
            gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            gui:SetAttribute("BloxMobAuraOrbitDirection", state.MobAuraOrbitDirection)
            gui:SetAttribute("BloxMobAuraRandomSquare", state.MobAuraRandomSquare)
            gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            gui:SetAttribute("BloxMobAuraTarget", "")
            gui:SetAttribute("BloxMobAuraDistance", 0)
            gui:SetAttribute("BloxMultiGrabEnemies", state.GatherEnemies)
            gui:SetAttribute("BloxMultiGrabFilter", state.GatherMode)
            gui:SetAttribute("BloxMultiGrabEnemy", state.GatherSelectedMob)
            gui:SetAttribute("BloxMultiGrabLimit", MULTI_GRAB_LIMIT)
            gui:SetAttribute("BloxMultiGrabRange", MULTI_GRAB_RANGE)
            gui:SetAttribute("BloxMultiGrabCount", 0)
            gui:SetAttribute("BloxMultiGrabSingleFallback", "")
            gui:SetAttribute("BloxSelectedLevelQuest", state.SelectedLevelQuest)
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
            gui:SetAttribute("BloxAutoLevel", state.AutoFarmLevel)
            gui:SetAttribute("BloxAutoRaid", state.AutoRaid)
            gui:SetAttribute("BloxRaidActive", false)
            gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
            gui:SetAttribute("BloxRaidIslandName", "")
            gui:SetAttribute("BloxRaidTarget", "")
            gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
            gui:SetAttribute("BloxRaidMultiGrabCount", 0)
            gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
            gui:SetAttribute("BloxRaidVoidActive", false)
            gui:SetAttribute("BloxRaidVoidMoved", 0)
            gui:SetAttribute("BloxRaidVoidStaged", 0)
            gui:SetAttribute("BloxRaidVoidKillCount", 0)
            gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
            gui:SetAttribute("BloxBossVerticalLocked", false)
            gui:SetAttribute("BloxBossAnchorY", 0)
            gui:SetAttribute("BloxAutoBuso", state.AutoBuso)
            gui:SetAttribute("BloxWalkOnWater", state.WalkOnWater)
            gui:SetAttribute("BloxPlayerESP", state.PlayerESP)
            gui:SetAttribute("BloxPlayerESPCount", 0)
            gui:SetAttribute(
                "BloxPlayerESPSkeletonSupported",
                type(Drawing) == "table" and type(Drawing.new) == "function"
            )
            gui:SetAttribute("BloxAutoGacha", state.AutoGacha)
            gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            gui:SetAttribute("BloxGachaBusy", false)
            gui:SetAttribute("BloxGachaRollCount", 0)
            gui:SetAttribute("BloxGachaStatus", state.GachaStatus)
            gui:SetAttribute("BloxAutoStoreFruit", state.AutoStoreFruit)
            gui:SetAttribute("BloxFruitStoreBusy", false)
            gui:SetAttribute("BloxFruitStoredCount", 0)
            gui:SetAttribute("BloxFruitStoreStatus", state.StoreStatus)
            gui:SetAttribute("BloxAutoAttack", false)
            gui:SetAttribute("BloxLastAttackAt", 0)
            gui:SetAttribute("BloxAttackCount", state.AuraRequests)
            track(gui.Destroying:Connect(cleanup))
        end

        (function()
        local CosmeticsSection = PlayerPage:AddSection("Blox Fruits Cosmetics", "Left")
        local voidKitsuneState = {
            Enabled = false,
            Originals = setmetatable({}, {__mode = "k"}),
            GalaxyMarkers = setmetatable({}, {__mode = "k"}),
            GalaxyRigs = setmetatable({}, {__mode = "k"}),
            Accumulator = 0,
        }
        local identityMaskState = {
            Mode = "Original",
            Humanoids = setmetatable({}, {__mode = "k"}),
            Labels = setmetatable({}, {__mode = "k"}),
            Accumulator = 0,
        }
        local kitsuneFloatState = {
            Enabled = false,
            Motors = setmetatable({}, {__mode = "k"}),
            StartedAt = 0,
        }
        local VOID_KITSUNE_COLORS = {
            Color3.fromRGB(151, 70, 255),
            Color3.fromRGB(31, 7, 54),
            Color3.fromRGB(205, 77, 255),
        }

        local function collectKitsuneTools()
            local tools = {}
            local seen = setmetatable({}, {__mode = "k"})
            local function scanTools(container)
                if not container then
                    return
                end
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool")
                        and string.find(string.lower(child.Name), "kitsune", 1, true)
                        and not seen[child] then
                        seen[child] = true
                        table.insert(tools, child)
                    end
                end
            end
            scanTools(LocalPlayer:FindFirstChildOfClass("Backpack"))
            scanTools(LocalPlayer.Character)
            return tools
        end

        local function collectKitsuneShiftedFolders(kitsuneTools)
            local found = {}
            local seen = setmetatable({}, {__mode = "k"})
            local function addColorFolder(colorFolder)
                local shifted = colorFolder and colorFolder:FindFirstChild("Shifted")
                if shifted and shifted:IsA("Folder") and not seen[shifted] then
                    seen[shifted] = true
                    table.insert(found, shifted)
                end
            end

            addColorFolder(LocalPlayer:FindFirstChild("KitsuneFruitVFXColor"))
            for _, tool in ipairs(kitsuneTools) do
                addColorFolder(tool:FindFirstChild("VFXColor"))
            end
            return found
        end

        local function enableGalaxyTool(tool)
            local marker = tool:FindFirstChild("IsGalaxy")
            if marker and not marker:IsA("BoolValue") then
                return
            end
            if not marker then
                marker = Instance.new("BoolValue")
                marker.Name = "IsGalaxy"
                marker.Value = true
                marker.Parent = tool
                voidKitsuneState.GalaxyMarkers[marker] = {Created = true}
            elseif not voidKitsuneState.GalaxyMarkers[marker] then
                voidKitsuneState.GalaxyMarkers[marker] = {Created = false, Value = marker.Value}
                marker.Value = true
            elseif marker.Value ~= true then
                marker.Value = true
            end
        end

        local function applyGalaxyTransformation(tool)
            local transformedObject = tool:FindFirstChild("TransformedRigObject")
            local rig = transformedObject and transformedObject:IsA("ObjectValue") and transformedObject.Value or nil
            if not rig or not rig.Parent or voidKitsuneState.GalaxyRigs[rig] then
                return
            end

            local visualNames = {"Body", "Accessory", "Mouth", "Eyes", "Neon"}
            local record = {
                Parts = {},
                Glow = nil,
                GalaxyApplied = false,
            }
            for _, part in ipairs(rig:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency < 0.95 then
                    local appearances = {}
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("SurfaceAppearance") then
                            table.insert(appearances, child:Clone())
                        end
                    end
                    record.Parts[part] = {
                        Color = part.Color,
                        Material = part.Material,
                        Appearances = appearances,
                    }
                end
            end

            local compatible = false
            for _, name in ipairs(visualNames) do
                local part = rig:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    compatible = true
                end
            end

            if compatible then
                record.GalaxyApplied = pcall(function()
                    local SkinUtil = require(ReplicatedStorage.Modules.SkinUtil)
                    SkinUtil.applySkin("Galaxy", {
                        [rig] = "Transformations.Empyrean (Kitsune)-Empyrean (Kitsune)",
                    })
                end)
            end

            for part in pairs(record.Parts) do
                if part and part.Parent then
                    local isArmor = string.find(string.lower(part.Name), "armor", 1, true) ~= nil
                    local color = isArmor and VOID_KITSUNE_COLORS[3] or VOID_KITSUNE_COLORS[1]
                    part.Material = Enum.Material.Neon
                    part.Color = color
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("SurfaceAppearance") then
                            pcall(function()
                                child.Color = color
                            end)
                            pcall(function()
                                child.EmissiveStrength = isArmor and 2.5 or 1.8
                            end)
                        end
                    end
                end
            end

            local glow = Instance.new("Folder")
            glow.Name = "VORVoidGalaxyGlow"
            glow.Parent = rig
            record.Glow = glow

            local highlight = Instance.new("Highlight")
            highlight.Name = "VORVoidOutline"
            highlight.Adornee = rig
            highlight.FillColor = VOID_KITSUNE_COLORS[1]
            highlight.FillTransparency = 0.72
            highlight.OutlineColor = VOID_KITSUNE_COLORS[3]
            highlight.OutlineTransparency = 0.05
            highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            highlight.Parent = glow

            local root = rig:FindFirstChild("RootPart", true) or rig:FindFirstChildWhichIsA("BasePart", true)
            if root and root:IsA("BasePart") then
                local anchor = Instance.new("Part")
                anchor.Name = "VORVoidEmitterAnchor"
                anchor.Size = Vector3.new(0.2, 0.2, 0.2)
                anchor.Transparency = 1
                anchor.Anchored = false
                anchor.CanCollide = false
                anchor.CanTouch = false
                anchor.CanQuery = false
                anchor.Massless = true
                anchor.CFrame = root.CFrame
                anchor.Parent = glow
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = root
                weld.Part1 = anchor
                weld.Parent = anchor

                local attachment = Instance.new("Attachment")
                attachment.Name = "VORVoidEmitter"
                attachment.Parent = anchor
                local source = ReplicatedStorage:FindFirstChild("FX")
                source = source and source:FindFirstChild("Kitsune")
                source = source and source:FindFirstChild("KitsuneTailSpawn")
                source = source and source:FindFirstChildWhichIsA("ParticleEmitter", true)
                if source then
                    local emitter = source:Clone()
                    emitter.Name = "VORVoidEmbers"
                    emitter.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, VOID_KITSUNE_COLORS[1]),
                        ColorSequenceKeypoint.new(0.55, VOID_KITSUNE_COLORS[3]),
                        ColorSequenceKeypoint.new(1, VOID_KITSUNE_COLORS[2]),
                    })
                    emitter.LightEmission = 1
                    emitter.Rate = math.max(18, emitter.Rate)
                    emitter.Enabled = true
                    emitter.Parent = attachment
                end

                local light = Instance.new("PointLight")
                light.Name = "VORVoidLight"
                light.Color = VOID_KITSUNE_COLORS[1]
                light.Brightness = 2.4
                light.Range = 20
                light.Shadows = false
                light.Parent = anchor
            end

            voidKitsuneState.GalaxyRigs[rig] = record
            gui:SetAttribute(
                "BloxVoidKitsuneGalaxyRigStatus",
                record.GalaxyApplied and "Galaxy model + void glow active" or "Void glow active on standard Kitsune rig"
            )
        end

        local function applyVoidKitsuneColors()
            local kitsuneTools = collectKitsuneTools()
            for _, shifted in ipairs(collectKitsuneShiftedFolders(kitsuneTools)) do
                if not voidKitsuneState.Originals[shifted] then
                    voidKitsuneState.Originals[shifted] = {
                        shifted:GetAttribute("Shifted_Color1"),
                        shifted:GetAttribute("Shifted_Color2"),
                        shifted:GetAttribute("Shifted_Color3"),
                    }
                end
                for index, color in ipairs(VOID_KITSUNE_COLORS) do
                    local attribute = "Shifted_Color" .. tostring(index)
                    if shifted:GetAttribute(attribute) ~= color then
                        shifted:SetAttribute(attribute, color)
                    end
                end
            end
            for _, tool in ipairs(kitsuneTools) do
                enableGalaxyTool(tool)
                applyGalaxyTransformation(tool)
            end
            gui:SetAttribute("BloxVoidKitsuneTheme", true)
        end

        local function restoreKitsuneColors()
            for shifted, originals in pairs(voidKitsuneState.Originals) do
                if shifted and shifted.Parent then
                    for index = 1, 3 do
                        shifted:SetAttribute("Shifted_Color" .. tostring(index), originals[index])
                    end
                end
            end
            voidKitsuneState.Originals = setmetatable({}, {__mode = "k"})
            for marker, original in pairs(voidKitsuneState.GalaxyMarkers) do
                if marker and marker.Parent then
                    if original.Created then
                        marker:Destroy()
                    else
                        marker.Value = original.Value == true
                    end
                end
            end
            voidKitsuneState.GalaxyMarkers = setmetatable({}, {__mode = "k"})
            for rig, record in pairs(voidKitsuneState.GalaxyRigs) do
                if rig and rig.Parent then
                    if record.Glow and record.Glow.Parent then
                        record.Glow:Destroy()
                    end
                    for part, data in pairs(record.Parts) do
                        if part and part.Parent then
                            part.Color = data.Color
                            part.Material = data.Material
                            for _, child in ipairs(part:GetChildren()) do
                                if child:IsA("SurfaceAppearance") then
                                    child:Destroy()
                                end
                            end
                            for _, appearance in ipairs(data.Appearances) do
                                appearance.Parent = part
                            end
                        end
                    end
                end
            end
            voidKitsuneState.GalaxyRigs = setmetatable({}, {__mode = "k"})
            gui:SetAttribute("BloxVoidKitsuneTheme", false)
            gui:SetAttribute("BloxVoidKitsuneGalaxyRigStatus", "Off")
        end

        local function restoreIdentityMask()
            for humanoid, original in pairs(identityMaskState.Humanoids) do
                if humanoid and humanoid.Parent then
                    humanoid.DisplayName = original.DisplayName
                    humanoid.NameDisplayDistance = original.NameDisplayDistance
                end
            end
            for label, originalText in pairs(identityMaskState.Labels) do
                if label and label.Parent then
                    label.Text = originalText
                end
            end
            identityMaskState.Humanoids = setmetatable({}, {__mode = "k"})
            identityMaskState.Labels = setmetatable({}, {__mode = "k"})
            gui:SetAttribute("BloxIdentityMask", "Original")
        end

        local function restoreKitsuneFloat()
            for motor, originalTransform in pairs(kitsuneFloatState.Motors) do
                if motor and motor.Parent then
                    motor.Transform = originalTransform
                end
            end
            kitsuneFloatState.Motors = setmetatable({}, {__mode = "k"})
            gui:SetAttribute("BloxVoidKitsuneFloat", false)
            gui:SetAttribute("BloxVoidKitsuneFloatStatus", "Off")
        end

        local function animateKitsuneFloat()
            if not kitsuneFloatState.Enabled then
                return
            end
            local foundMotor = false
            for _, tool in ipairs(collectKitsuneTools()) do
                local transformedObject = tool:FindFirstChild("TransformedRigObject")
                local rig = transformedObject and transformedObject:IsA("ObjectValue") and transformedObject.Value or nil
                if rig and rig.Parent then
                    for _, descendant in ipairs(rig:GetDescendants()) do
                        if descendant:IsA("Motor6D")
                            and (descendant.Name == "KitsuneMotor6D" or descendant.Name == "ArmorMotor6D") then
                            foundMotor = true
                            if kitsuneFloatState.Motors[descendant] == nil then
                                kitsuneFloatState.Motors[descendant] = descendant.Transform
                            end
                        end
                    end
                end
            end

            local elapsed = os.clock() - kitsuneFloatState.StartedAt
            local height = 0.85 + math.sin(elapsed * 2.15) * 0.24
            local pitch = math.rad(math.sin(elapsed * 1.45) * 1.8)
            local roll = math.rad(math.sin(elapsed * 1.8) * 2.5)
            local offset = CFrame.new(0, height, 0) * CFrame.Angles(pitch, 0, roll)
            for motor, originalTransform in pairs(kitsuneFloatState.Motors) do
                if motor and motor.Parent then
                    motor.Transform = originalTransform * offset
                end
            end
            gui:SetAttribute("BloxVoidKitsuneFloat", true)
            gui:SetAttribute(
                "BloxVoidKitsuneFloatStatus",
                foundMotor and "Floating transformed rig" or "Waiting for Kitsune transformation"
            )
        end

        local function applyIdentityMask()
            if identityMaskState.Mode == "Original" then
                return
            end
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if not identityMaskState.Humanoids[humanoid] then
                    identityMaskState.Humanoids[humanoid] = {
                        DisplayName = humanoid.DisplayName,
                        NameDisplayDistance = humanoid.NameDisplayDistance,
                    }
                end
                local original = identityMaskState.Humanoids[humanoid]
                if identityMaskState.Mode == "Hide Name" then
                    humanoid.NameDisplayDistance = 0
                else
                    humanoid.DisplayName = "VOR Hub"
                    humanoid.NameDisplayDistance = original.NameDisplayDistance
                end
            end

            if character then
                local username = string.lower(LocalPlayer.Name)
                local displayName = string.lower(LocalPlayer.DisplayName)
                for _, descendant in ipairs(character:GetDescendants()) do
                    if descendant:IsA("TextLabel") then
                        local currentText = string.lower(tostring(descendant.Text))
                        if identityMaskState.Labels[descendant]
                            or currentText == username
                            or currentText == displayName then
                            if not identityMaskState.Labels[descendant] then
                                identityMaskState.Labels[descendant] = descendant.Text
                            end
                            descendant.Text = identityMaskState.Mode == "Hide Name" and "" or "VOR Hub"
                        end
                    end
                end
            end
            gui:SetAttribute("BloxIdentityMask", identityMaskState.Mode)
        end

        CosmeticsSection:AddLabel("Uses Kitsune's native three-channel VFX system plus its Galaxy mutation hooks, so the model, tails, and local abilities stay synchronized.")
        CosmeticsSection:AddToggle({
            Name = "Void Kitsune Theme",
            Description = "Galaxy mutation model with VOR violet, abyss purple, and void magenta VFX",
            Flag = "blox_void_kitsune_theme",
            Default = false,
            Callback = function(enabled)
                voidKitsuneState.Enabled = enabled == true
                if voidKitsuneState.Enabled then
                    applyVoidKitsuneColors()
                    Window:Notify("Void Kitsune", "Your fox has joined the evil purple department.", 3)
                else
                    restoreKitsuneColors()
                end
            end,
        })
        TravelSection:AddToggle({
            Name = "Bypass TP / Instant Travel",
            Description = "Uses the game's entrance path and a final instant placement instead of tweening",
            Flag = "blox_bypass_teleport",
            Default = false,
            Callback = function(enabled)
                state.BypassTeleport = enabled == true
                gui:SetAttribute("BloxBypassTeleport", state.BypassTeleport)
            end,
        })
        CosmeticsSection:AddToggle({
            Name = "VOR Hub Name Mask",
            Description = "Replace your overhead display name with VOR Hub on this client",
            Flag = "blox_vor_name_mask",
            Default = false,
            Callback = function(enabled)
                restoreIdentityMask()
                identityMaskState.Mode = enabled and "VOR Hub" or "Original"
                applyIdentityMask()
            end,
        })
        CosmeticsSection:AddToggle({
            Name = "Void Kitsune Float",
            Description = "Smooth visual hover for the transformed fox without moving your real root",
            Flag = "blox_void_kitsune_float",
            Default = false,
            Callback = function(enabled)
                restoreKitsuneFloat()
                kitsuneFloatState.Enabled = enabled == true
                kitsuneFloatState.StartedAt = os.clock()
                if kitsuneFloatState.Enabled then
                    animateKitsuneFloat()
                end
            end,
        })
        track(RunService.RenderStepped:Connect(function()
            animateKitsuneFloat()
        end))

        track(RunService.Heartbeat:Connect(function(deltaTime)
            if voidKitsuneState.Enabled then
                voidKitsuneState.Accumulator = voidKitsuneState.Accumulator + deltaTime
                if voidKitsuneState.Accumulator >= 0.35 then
                    voidKitsuneState.Accumulator = 0
                    applyVoidKitsuneColors()
                end
            end
            if identityMaskState.Mode ~= "Original" then
                identityMaskState.Accumulator = identityMaskState.Accumulator + deltaTime
                if identityMaskState.Accumulator >= 0.35 then
                    identityMaskState.Accumulator = 0
                    applyIdentityMask()
                end
            end
        end))
        end)()

        if type(context.LoadModule) ~= "function" or type(context.RunBuilder) ~= "function" then
            error("Blox Fruits parity loader is unavailable")
        end
        state.ParityLoaded, state.ParityBuilder = context.LoadModule("games/blox_fruits_parity.lua")
        if not state.ParityLoaded then
            error("Blox Fruits parity compile failed: " .. tostring(state.ParityBuilder))
        end
        state.ParityOk, state.ParityError = context.RunBuilder(
            "games/blox_fruits_parity.lua",
            state.ParityBuilder,
            {
                Window = Window,
                Gui = gui,
                Track = track,
                COLORS = COLORS,
                Pages = {
                    Farming = FarmingPage,
                    Combat = CombatPage,
                    Mastery = MasteryPage,
                    Shop = ShopPage,
                    Sea = SeaPage,
                    Player = PlayerPage,
                    PVP = state.PVPPage,
                },
                LoadModule = context.LoadModule,
                RunBuilder = context.RunBuilder,
                State = state,
                Remotes = {CommF = CommF, CommE = CommE, Redeem = Redeem},
                ExperimentalAPI = {
                    SetOverride = function(enabled)
                        local desired = enabled == true
                        if state.ExperimentalAttackOverride ~= desired then
                            state.ExperimentalAttackOverride = desired
                            state.AuraAttackGeneration += 1
                            state.FruitDispatchGeneration += 1
                            state.AuraAttackPending = false
                            state.FruitDispatchPending = false
                            state.FruitDispatchPendingAt = 0
                            state.AuraFruitBusy = false
                        end
                        if not state.AuraAttackPending then
                            state.AuraAttackPendingAt = 0
                        end
                        gui:SetAttribute("BloxExperimentalAttackOverride", desired)
                    end,
                    IsReady = function()
                        return state.Alive and state.AuraKill and not state.InventoryBusy
                    end,
                    EnsureBuso = ensureBuso,
                    Targets = DoubleAttackEngine.Targets,
                    DispatchRegistered = state.ExperimentalDispatchRegistered,
                    DispatchFruit = DoubleAttackEngine.SendFruit,
                    DispatchDragonstorm = DoubleAttackEngine.SendDragonstorm,
                    ToolForSelection = toolForSelection,
                    EquipTool = equipTool,
                    SetMagnetBoost = function(enabled)
                        state.ExperimentalMagnetBoost = enabled == true
                        state.LastGatherScan = 0
                        gui:SetAttribute("BloxExperimentalMagnetBoost", state.ExperimentalMagnetBoost)
                    end,
                    Character = character,
                    Humanoid = humanoid,
                    RootPart = rootPart,
                    ModelAlive = modelAlive,
                },
                ThirdSeaAPI = {
                    -- StreamingEnabled can unload Turtle even while the player
                    -- is in Third Sea or its Submerged Island place. PlaceId is
                    -- the stable router; map children are not.
                    IsThirdSea = game.PlaceId == 7449423635
                        or game.PlaceId == 100117331123089,
                    SetCombat = function(enabled)
                        local desired = enabled == true
                        state.ThirdSeaFarmActive = desired
                        if not desired then
                            table.clear(state.ThirdSeaFarmNames)
                        end
                        for flag, value in pairs({
                            blox_auto_attack = desired,
                            blox_fast_attack = desired,
                            blox_double_attack = desired,
                            blox_auto_buso = desired,
                            blox_aura_kill_range = desired and AURA_KILL_MAX_RANGE or state.AuraRange,
                        }) do
                            local control = Window.PersistentControls[flag]
                            if control then
                                control:Set(value)
                            end
                        end
                        if desired then
                            state.AutoAttack = true
                            state.FastAttack = true
                            state.DoubleAttack = true
                            state.AutoBuso = true
                            state.AuraRange = AURA_KILL_MAX_RANGE
                            ensureBuso()
                        end
                        gui:SetAttribute("BloxThirdSeaCombat", desired)
                        gui:SetAttribute("BloxThirdSeaFarmActive", desired)
                    end,
                    FarmFirst = function(names, center, radius, heightOverride)
                        local root = rootPart()
                        if not root then
                            return nil, "Character is not ready"
                        end
                        local wanted = {}
                        for _, name in ipairs(type(names) == "table" and names or {}) do
                            wanted[string.lower(normalizeEnemyName(name))] = true
                        end
                        state.ThirdSeaFarmActive = true
                        state.ThirdSeaFarmNames = wanted
                        gui:SetAttribute("BloxThirdSeaFarmActive", true)
                        local function allowed(enemy)
                            if not modelAlive(enemy) then
                                return false
                            end
                            local normalized = string.lower(normalizeEnemyName(enemy.Name))
                            local matches = next(wanted) == nil
                            for expected in pairs(wanted) do
                                if normalized == expected or string.find(normalized, expected, 1, true) then
                                    matches = true
                                    break
                                end
                            end
                            if not matches then
                                return false
                            end
                            local enemyRoot = modelRoot(enemy)
                            local centerPosition = typeof(center) == "CFrame" and center.Position or center
                            return enemyRoot ~= nil and (typeof(centerPosition) ~= "Vector3"
                                or (enemyRoot.Position - centerPosition).Magnitude <= (tonumber(radius) or math.huge))
                        end
                        local enemy = state.ActiveFarmTarget
                        if not allowed(enemy) then
                            enemy = nil
                        end
                        local bestDistance = math.huge
                        if not enemy then
                            for _, candidate in ipairs(loadedEnemies()) do
                                if allowed(candidate) then
                                    local candidateRoot = modelRoot(candidate)
                                    local distance = (candidateRoot.Position - root.Position).Magnitude
                                    if distance < bestDistance then
                                        enemy = candidate
                                        bestDistance = distance
                                    end
                                end
                            end
                        end
                        if enemy then
                            state.ActiveFarmTarget = enemy
                            state.CurrentEnemyName = normalizeEnemyName(enemy.Name)
                            state.ActiveFarmVerticalLock = true
                            state.ActiveFarmHeightOverride = tonumber(heightOverride)
                            applyNoclip()
                            syncFarmAuraRange(heightOverride)
                            local targetCFrame = positionAtEnemy(enemy, true, heightOverride)
                            if targetCFrame then
                                moveToFarmPosition(targetCFrame)
                            end
                            return normalizeEnemyName(enemy.Name), "Farming"
                        end
                        state.ActiveFarmTarget = nil
                        state.CurrentEnemyName = type(names) == "table" and names[1]
                            and normalizeEnemyName(names[1]) or nil
                        for _, name in ipairs(type(names) == "table" and names or {}) do
                            local spawn = enemySpawn(name)
                            if spawn then
                                local spawnHeight = tonumber(heightOverride) or tonumber(state.MobAuraHeight) or 20
                                moveTo(CFrame.new(spawn.Position + Vector3.new(0, spawnHeight, 0)))
                                return normalizeEnemyName(name), "Waiting for spawn"
                            end
                        end
                        if typeof(center) == "CFrame" then
                            moveTo(center)
                        elseif typeof(center) == "Vector3" then
                            moveTo(CFrame.new(center))
                        end
                        return nil, "No matching enemy loaded"
                    end,
                    MoveTo = function(target)
                        return moveTo(target)
                    end,
                    Stop = function()
                        state.ThirdSeaFarmActive = false
                        table.clear(state.ThirdSeaFarmNames)
                        state.ActiveFarmTarget = nil
                        state.CurrentEnemyName = nil
                        state.ActiveFarmHeightOverride = nil
                        cancelMove(false)
                        gui:SetAttribute("BloxThirdSeaFarmActive", false)
                    end,
                    RootPart = rootPart,
                },
                Helpers = {
                    Invoke = invoke,
                    Character = character,
                    RootPart = rootPart,
                    Humanoid = humanoid,
                    TeleportToNpc = teleportToNpc,
                    TeleportToLocation = teleportToLocation,
                    PrepareManualTravel = prepareManualTravel,
                },
            }
        )
        state.ParityBuilder = nil
        if not state.ParityOk then
            error("Blox Fruits parity builder failed: " .. tostring(state.ParityError))
        end

        setStatus("Native Blox Fruits functions and Solix parity ready", true)
        refreshBusoStatus()
        questLabel.Text = (function(quest)
            if quest then
                return string.format("Quest: %s | Target: %s", quest.DisplayName, quest.EnemyName)
            end
            return "Quest: Waiting for live quest data"
        end)(selectedLevelQuest())
    end, tracebackError)
    if not built then
        error(buildError, 0)
    end
end
