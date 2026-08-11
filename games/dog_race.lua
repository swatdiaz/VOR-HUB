-- VOR Hub - [AA] Dog Race adapter
-- UniverseId 10350558449 | PlaceId 119609933650338
--
-- Uses the game's live Knit controllers so training, racing, dashing, rewards,
-- pets, and rebirths keep the native client/server state synchronized.

return function(context)
    local Window = assert(context.Window, "Dog Race: Window is required")
    local createCategoryHomePage = assert(
        context.CreateCategoryHomePage,
        "Dog Race: category builder is required"
    )
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G
    local previousCleanup = runtimeEnvironment.__VORDogRaceCleanup
    runtimeEnvironment.__VORDogRaceCleanup = nil
    if type(previousCleanup) == "function" then
        pcall(previousCleanup)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ReplicatedFirst = game:GetService("ReplicatedFirst")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    local Knit
    local Constants
    local TreadmillsDataHelper
    local RebirthDataHelper
    pcall(function()
        Knit = require(ReplicatedStorage.Packages.Knit)
        Constants = require(ReplicatedStorage.Modules.Constants)
        TreadmillsDataHelper = require(ReplicatedFirst.DataHelper.TreadmillsDataHelper)
        RebirthDataHelper = require(ReplicatedFirst.DataHelper.RebirthDataHelper)
    end)

    local function getController(name)
        if not Knit then
            return nil
        end
        local ok, controller = pcall(Knit.GetController, name)
        return ok and controller or nil
    end

    local function getService(name)
        if not Knit then
            return nil
        end
        local ok, service = pcall(Knit.GetService, name)
        return ok and service or nil
    end

    local PlayerDataController = getController("PlayerDataController")
    local AreaController = getController("AreaController")
    local TrainController = getController("TrainController")
    local AutoController = getController("AutoController")
    local FightController = getController("FightController")
    local DashController = getController("DashController")
    local ChestController = getController("ChestController")

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local RacePage = addHomeCategory("Race", 1, CATEGORY_DECALS.Combat or CATEGORY_DECALS.Movement)
    local TrainingPage = addHomeCategory("Training", 2, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local ProgressionPage = addHomeCategory("Progression", 3, CATEGORY_DECALS.Progress)
    local MovementPage = addHomeCategory("Movement", 4, CATEGORY_DECALS.Movement or CATEGORY_DECALS.Player)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)

    local RaceSection = RacePage:AddSection("Native Race", "Left")
    local RaceUtilitySection = RacePage:AddSection("Race Utility", "Right")
    local TrainingSection = TrainingPage:AddSection("Native Training", "Left")
    local TrainingStatusSection = TrainingPage:AddSection("Training Status", "Right")
    local RebirthSection = ProgressionPage:AddSection("Rebirth", "Left")
    local RewardsSection = ProgressionPage:AddSection("Pets & Rewards", "Right")
    local MovementSection = MovementPage:AddSection("Movement", "Left")
    local MovementStatusSection = MovementPage:AddSection("Runtime", "Right")
    local PlayerStatusSection = StatusPage:AddSection("Player Data", "Left")
    local AdapterStatusSection = StatusPage:AddSection("Adapter", "Right")

    local state = {
        Alive = true,
        AutoTrain = false,
        AutoRace = false,
        AutoDash = false,
        DashInterval = 1,
        SpeedMultiplier = 1,
        AutoRebirth = false,
        AutoEquipBest = false,
        AutoDailyChest = false,
        LastDash = 0,
        LastTrainRetry = 0,
        LastRaceRetry = 0,
        LastRebirth = 0,
        LastEquipBest = 0,
        LastDailyChest = 0,
        LastAction = "Ready",
        SpeedHumanoid = nil,
        NativeWalkSpeed = nil,
        AppliedWalkSpeed = nil,
        OwnsAutoTrain = false,
        OwnsAutoRace = false,
        OwnsContest = false,
    }

    local function notify(message, color)
        Window:Notify("Dog Race", message, 4, color or COLORS.accentBright)
    end

    local function getData()
        if not PlayerDataController or type(PlayerDataController.GetData) ~= "function" then
            return nil
        end
        local ok, data = pcall(PlayerDataController.GetData, PlayerDataController)
        return ok and data or nil
    end

    local function getCharacter()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    local function getCurrentArea()
        if not AreaController or type(AreaController.GetCurrentArea) ~= "function" then
            return nil
        end
        local ok, area = pcall(AreaController.GetCurrentArea, AreaController)
        return ok and area or nil
    end

    local function isTraining()
        if not TrainController or type(TrainController.IsTraining) ~= "function" then
            return false
        end
        local ok, value = pcall(TrainController.IsTraining, TrainController)
        return ok and value == true
    end

    local function isFighting()
        if not FightController or type(FightController.IsFighting) ~= "function" then
            return false
        end
        local ok, value = pcall(FightController.IsFighting, FightController)
        return ok and value == true
    end

    local function hasTrainingPosture()
        local _, humanoid, root = getCharacter()
        return isTraining()
            and humanoid ~= nil
            and root ~= nil
            and humanoid.PlatformStand == true
            and root.Anchored == true
    end

    local function isPathFinding()
        if not AutoController or type(AutoController.IsPathFinding) ~= "function" then
            return false
        end
        local ok, value = pcall(AutoController.IsPathFinding, AutoController)
        return ok and value == true
    end

    local initialData = getData()
    local originalAutoTrain = initialData and initialData.AutoTrain == true or false
    local originalAutoRace = initialData and initialData.AutoFight == true or false

    local function newestTreadmill(data, area)
        if not data or not area or not TreadmillsDataHelper then
            return nil
        end
        local ok, treadmillId = pcall(
            TreadmillsDataHelper.GetNewestTreadmillId,
            data,
            area
        )
        return ok and treadmillId or nil
    end

    local function stopAutoTrain()
        local data = getData()
        local ok = false
        if AutoController and type(AutoController.StopAutoTrain) == "function" then
            ok = pcall(AutoController.StopAutoTrain, AutoController)
        elseif TrainController and type(TrainController.StopAutoTrain) == "function" then
            ok = pcall(TrainController.StopAutoTrain, TrainController)
            if data then
                data.AutoTrain = false
            end
        end
        state.AutoTrain = false
        state.OwnsAutoTrain = false
        state.LastAction = ok and "Stopped native training" or "Could not stop native training"
        return ok
    end

    local function startAutoTrain()
        local data = getData()
        local area = getCurrentArea()
        local treadmillId = newestTreadmill(data, area)
        if not data or not treadmillId or not TrainController
            or type(TrainController.StartAutoTrain) ~= "function" then
            state.LastAction = "No unlocked treadmill in the current area"
            return false
        end
        if data.AutoFight and AutoController and type(AutoController.StopAutoFight) == "function" then
            pcall(AutoController.StopAutoFight, AutoController)
            state.AutoRace = false
            state.OwnsAutoRace = false
        end
        data.AutoFight = false
        data.AutoTrain = true
        data.AutoTrainTreadmillId = treadmillId
        local ok, result = pcall(TrainController.StartAutoTrain, TrainController, treadmillId)
        if not ok then
            data.AutoTrain = false
            state.LastAction = "Training failed: " .. tostring(result)
            return false
        end
        state.AutoTrain = true
        state.OwnsAutoTrain = not originalAutoTrain
        state.LastAction = "Training on " .. treadmillId
        return true
    end

    local function stopAutoRace()
        local ok = false
        if AutoController and type(AutoController.StopAutoFight) == "function" then
            ok = pcall(AutoController.StopAutoFight, AutoController)
        end
        state.AutoRace = false
        state.OwnsAutoRace = false
        state.LastAction = ok and "Stopped native auto-race loop" or "Could not stop native auto race"
        return ok
    end

    local function startAutoRace()
        local area = getCurrentArea()
        if not area or not AutoController or type(AutoController.StartAutoFight) ~= "function" then
            state.LastAction = "Native auto race controller unavailable"
            return false
        end
        if isTraining() then
            stopAutoTrain()
        end
        local wasFighting = isFighting()
        local ok, result = pcall(AutoController.StartAutoFight, AutoController, area)
        if not ok then
            state.LastAction = "Auto race failed: " .. tostring(result)
            return false
        end
        state.AutoRace = true
        state.OwnsAutoRace = not originalAutoRace
        if not wasFighting then
            state.OwnsContest = true
        end
        state.LastAction = "Auto racing in " .. tostring(area)
        return true
    end

    local function giveUpContest()
        if not isFighting() then
            state.OwnsContest = false
            state.LastAction = "No active contest"
            return false
        end
        stopAutoRace()
        local area = getCurrentArea()
        RunService:UnbindFromRenderStep("fight")
        if DashController and type(DashController.StopDash) == "function" then
            pcall(DashController.StopDash, DashController)
        end
        local rideController = getController("RideController")
        if rideController then
            if type(rideController.ClearEffect) == "function" then
                pcall(rideController.ClearEffect, rideController)
            end
            if type(rideController.DisableWindStreaks) == "function" then
                pcall(rideController.DisableWindStreaks, rideController)
            end
        end
        local resetOk = pcall(FightController.ResetFightState, FightController)
        local signal = FightController.QuitContestClientEvent
        if signal and type(signal.Fire) == "function" then
            pcall(signal.Fire, signal, area)
        end
        local service = getService("FightService")
        local remote = service and service.QuitContestEvent
        if remote and type(remote.Fire) == "function" then
            pcall(remote.Fire, remote, area)
        end
        state.OwnsContest = false
        state.LastAction = resetOk and "Gave up current contest" or "Contest reset failed"
        return resetOk
    end

    local function isFiniteNumber(value)
        return type(value) == "number"
            and value == value
            and value > -math.huge
            and value < math.huge
    end

    local function parseMultiplier(value)
        local multiplier = tonumber(value)
        if not isFiniteNumber(multiplier) then
            return nil
        end
        return math.max(1, multiplier)
    end

    local function clearSpeedOverride()
        local humanoid = state.SpeedHumanoid
        if humanoid and humanoid.Parent and isFiniteNumber(state.NativeWalkSpeed) then
            pcall(function()
                humanoid.WalkSpeed = state.NativeWalkSpeed
            end)
        end
        state.SpeedHumanoid = nil
        state.NativeWalkSpeed = nil
        state.AppliedWalkSpeed = nil
    end

    local function updateSpeedOverride()
        local multiplier = parseMultiplier(state.SpeedMultiplier) or 1
        if multiplier <= 1 then
            clearSpeedOverride()
            return
        end
        local _, humanoid = getCharacter()
        if not humanoid then
            clearSpeedOverride()
            return
        end
        if humanoid ~= state.SpeedHumanoid then
            clearSpeedOverride()
            state.SpeedHumanoid = humanoid
        end
        local current = humanoid.WalkSpeed
        local nativeSpeed = current
        if state.AppliedWalkSpeed and math.abs(current - state.AppliedWalkSpeed) <= 0.05 then
            nativeSpeed = state.NativeWalkSpeed or current
        end
        local applied = nativeSpeed * multiplier
        if not isFiniteNumber(applied) then
            state.SpeedMultiplier = 1
            state.LastAction = "Speed multiplier overflow; reset to 1x"
            clearSpeedOverride()
            return
        end
        state.NativeWalkSpeed = nativeSpeed
        state.AppliedWalkSpeed = applied
        humanoid.WalkSpeed = applied
    end

    local function dashNow()
        if not DashController or type(DashController.Dash) ~= "function"
            or isTraining() or isFighting() then
            return false
        end
        local ok, result = pcall(DashController.Dash, DashController, 0.3, false)
        state.LastAction = ok and "Native dash" or ("Dash failed: " .. tostring(result))
        return ok
    end

    local function rebirthCost(data)
        if not data or not RebirthDataHelper then
            return nil
        end
        local ok, cost = pcall(RebirthDataHelper.GetRebirthCost, (data.Rebirths or 0) + 1)
        return ok and tonumber(cost) or nil
    end

    local function requestRebirth()
        local data = getData()
        local cost = rebirthCost(data)
        if not data or not cost then
            state.LastAction = "Rebirth data unavailable"
            return false
        end
        if (tonumber(data.Strength) or 0) < cost then
            state.LastAction = string.format("Rebirth needs %.0f power", cost)
            return false
        end
        local service = getService("RebirthService")
        if not service or type(service.Rebirth) ~= "function" then
            state.LastAction = "Rebirth service unavailable"
            return false
        end
        local ok, promise = pcall(service.Rebirth, service)
        if not ok then
            state.LastAction = "Rebirth failed: " .. tostring(promise)
            return false
        end
        state.LastAction = "Requested eligible rebirth"
        if promise and type(promise.andThen) == "function" then
            promise:andThen(function(success, message)
                state.LastAction = success and "Rebirth complete"
                    or ("Rebirth rejected: " .. tostring(message))
            end):catch(function(message)
                state.LastAction = "Rebirth error: " .. tostring(message)
            end)
        end
        return true
    end

    local function equipBestPets()
        local service = getService("PetService")
        local remote = service and service.EquipBestPets
        if not remote or type(remote.Fire) ~= "function" then
            state.LastAction = "Equip Best Pets remote unavailable"
            return false
        end
        local ok, result = pcall(remote.Fire, remote)
        state.LastAction = ok and "Requested best pet loadout"
            or ("Equip Best failed: " .. tostring(result))
        return ok
    end

    local function dailyChestReady(data)
        local cooldown = Constants and tonumber(Constants.CHEST_OPEN_COOLDOWN)
        local lastOpen = data and tonumber(data.DailyChestLastOpenTime)
        return cooldown and lastOpen and os.time() - lastOpen > cooldown
    end

    local function claimDailyChest()
        local data = getData()
        if not dailyChestReady(data) then
            state.LastAction = "Daily chest is still cooling down"
            return false
        end
        if not ChestController or type(ChestController.OpenDailyChest) ~= "function" then
            state.LastAction = "Daily chest controller unavailable"
            return false
        end
        local ok, result = pcall(ChestController.OpenDailyChest, ChestController)
        state.LastAction = ok and "Requested daily chest"
            or ("Daily chest failed: " .. tostring(result))
        return ok
    end

    local function claimOfflineWins()
        local data = getData()
        if not data or (tonumber(data.OfflineWins) or 0) <= 0 then
            state.LastAction = "No offline wins waiting"
            return false
        end
        local service = getService("OfflineRaceService")
        local remote = service and service.ClaimOfflineWinsEvent
        if not remote or type(remote.Fire) ~= "function" then
            state.LastAction = "Offline wins remote unavailable"
            return false
        end
        local ok, result = pcall(remote.Fire, remote)
        state.LastAction = ok and "Requested offline wins"
            or ("Offline claim failed: " .. tostring(result))
        return ok
    end

    local raceModeLabel = RaceUtilitySection:AddLabel("Race mode: scanning...")
    local treadmillLabel = TrainingStatusSection:AddLabel("Treadmill: scanning...")
    local strengthLabel = PlayerStatusSection:AddLabel("Power: --")
    local winsLabel = PlayerStatusSection:AddLabel("Wins: --")
    local rebirthLabel = PlayerStatusSection:AddLabel("Rebirths: --")
    local areaLabel = PlayerStatusSection:AddLabel("Area: --")
    local petsLabel = PlayerStatusSection:AddLabel("Pets: --")
    local speedLabel = MovementStatusSection:AddLabel("Speed: --")
    local actionLabel = AdapterStatusSection:AddLabel("Last action: Ready")
    local servicesLabel = AdapterStatusSection:AddLabel("Native controllers: scanning...")
    AdapterStatusSection:AddLabel("UniverseId: " .. tostring(game.GameId))
    AdapterStatusSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))

    local autoTrainControl
    local autoRaceControl
    local autoDashControl
    local speedInputControl

    autoRaceControl = RaceSection:AddToggle({
        Name = "Auto Race",
        Description = "Uses the game's native AutoController pathfinding and contest flow.",
        Flag = "dograce_auto_race",
        Default = false,
        Callback = function(enabled)
            if enabled then
                if state.AutoTrain and autoTrainControl then
                    autoTrainControl:Set(false)
                end
                if not startAutoRace() then
                    notify(state.LastAction, COLORS.warning)
                end
            else
                stopAutoRace()
            end
        end,
    })
    RaceSection:AddButton({
        Name = "Start Native Auto Race",
        Callback = function()
            autoRaceControl:Set(true)
        end,
    })
    RaceSection:AddButton({Name = "Stop Auto-Race Loop", Callback = function() autoRaceControl:Set(false) end})
    RaceSection:AddButton({Name = "Give Up Current Contest", Callback = giveUpContest})

    autoTrainControl = TrainingSection:AddToggle({
        Name = "Auto Train",
        Description = "Uses the newest unlocked treadmill in the current area and native training ticks.",
        Flag = "dograce_auto_train",
        Default = false,
        Callback = function(enabled)
            if enabled then
                if state.AutoRace and autoRaceControl then
                    autoRaceControl:Set(false)
                end
                if not startAutoTrain() then
                    notify(state.LastAction, COLORS.warning)
                end
            else
                stopAutoTrain()
            end
        end,
    })
    TrainingSection:AddButton({
        Name = "Train on Best Treadmill",
        Callback = function()
            autoTrainControl:Set(true)
        end,
    })
    TrainingSection:AddButton({Name = "Stop Training", Callback = function() autoTrainControl:Set(false) end})

    RebirthSection:AddToggle({
        Name = "Auto Rebirth",
        Description = "Requests rebirth only after replicated power reaches the exact next native cost.",
        Flag = "dograce_auto_rebirth",
        Default = false,
        Callback = function(enabled)
            state.AutoRebirth = enabled == true
        end,
    })
    RebirthSection:AddButton({
        Name = "Rebirth When Eligible",
        Callback = function()
            if not requestRebirth() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })

    RewardsSection:AddToggle({
        Name = "Auto Equip Best Pets",
        Flag = "dograce_auto_equip_best",
        Default = false,
        Callback = function(enabled)
            state.AutoEquipBest = enabled == true
            if state.AutoEquipBest then
                equipBestPets()
            end
        end,
    })
    RewardsSection:AddButton({Name = "Equip Best Pets", Callback = equipBestPets})
    RewardsSection:AddToggle({
        Name = "Auto Daily Chest",
        Description = "Claims only when the replicated native cooldown has expired.",
        Flag = "dograce_auto_daily_chest",
        Default = false,
        Callback = function(enabled)
            state.AutoDailyChest = enabled == true
        end,
    })
    RewardsSection:AddButton({Name = "Claim Daily Chest", Callback = claimDailyChest})
    RewardsSection:AddButton({Name = "Claim Offline Wins", Callback = claimOfflineWins})

    speedInputControl = MovementSection:AddInput({
        Name = "Speed Multiplier",
        Description = "Multiplies native lobby and race WalkSpeed; 1 restores the exact native value.",
        Flag = "dograce_speed_multiplier",
        Default = "1",
        Placeholder = "Example: 2, 10, 100",
        Callback = function(value)
            local multiplier = parseMultiplier(value)
            if not multiplier then
                state.SpeedMultiplier = 1
                clearSpeedOverride()
                if speedInputControl then
                    speedInputControl:Set("1", true)
                end
                notify("Speed multiplier must be finite; reset to 1x", COLORS.warning)
                return
            end
            state.SpeedMultiplier = multiplier
            if multiplier ~= tonumber(value) and speedInputControl then
                speedInputControl:Set(tostring(multiplier), true)
            end
            if multiplier <= 1 then
                clearSpeedOverride()
            end
        end,
    })
    MovementSection:AddButton({Name = "Native Dash", Callback = dashNow})
    autoDashControl = MovementSection:AddToggle({
        Name = "Auto Dash",
        Description = "Uses DashController only while outside training and contests.",
        Flag = "dograce_auto_dash",
        Default = false,
        Callback = function(enabled)
            state.AutoDash = enabled == true
        end,
    })
    MovementSection:AddSlider({
        Name = "Dash Interval",
        Flag = "dograce_dash_interval",
        Min = 0.5,
        Max = 10,
        Step = 0.1,
        Default = 1,
        Suffix = "s",
        Callback = function(value)
            state.DashInterval = math.clamp(tonumber(value) or 1, 0.5, 10)
        end,
    })
    MovementSection:AddButton({
        Name = "Reset Movement",
        Callback = function()
            speedInputControl:Set("1")
            autoDashControl:Set(false)
            clearSpeedOverride()
            if DashController and type(DashController.StopDash) == "function" then
                pcall(DashController.StopDash, DashController)
            end
            state.LastAction = "Movement restored"
        end,
    })

    RaceUtilitySection:AddButton({
        Name = "Stop Race & Training",
        Callback = function()
            if autoRaceControl then
                autoRaceControl:Set(false)
            end
            if autoTrainControl then
                autoTrainControl:Set(false)
            end
            state.LastAction = "Race and training stopped"
        end,
    })

    local function updateStatus()
        local data = getData()
        local area = getCurrentArea()
        local _, humanoid, root = getCharacter()
        local petCount, equippedPets = 0, 0
        if data and type(data.Pets) == "table" then
            for _, pet in pairs(data.Pets) do
                petCount = petCount + 1
                if pet.Equipped then
                    equippedPets = equippedPets + 1
                end
            end
        end
        local treadmillId = data and newestTreadmill(data, area)
        local cost = data and rebirthCost(data)
        raceModeLabel.Text = string.format(
            "Auto %s | Path %s | Contest %s",
            data and data.AutoFight and "ON" or "OFF",
            isPathFinding() and "ON" or "OFF",
            isFighting() and "ON" or "OFF"
        )
        treadmillLabel.Text = string.format(
            "Training %s | Posture %s | Best: %s",
            isTraining() and "ON" or "OFF",
            hasTrainingPosture() and "OK" or "IDLE",
            tostring(treadmillId or "None")
        )
        strengthLabel.Text = "Power: " .. tostring(data and data.Strength or "--")
        winsLabel.Text = "Wins: " .. tostring(data and data.Wins or "--")
        rebirthLabel.Text = string.format(
            "Rebirths: %s | Next: %s",
            tostring(data and data.Rebirths or "--"),
            tostring(cost or "--")
        )
        areaLabel.Text = "Area: " .. tostring(area or "--")
        petsLabel.Text = string.format("Pets: %d | Equipped: %d", petCount, equippedPets)
        speedLabel.Text = string.format(
            "WalkSpeed: %.1f | %.3gx | Velocity: %.1f",
            humanoid and humanoid.WalkSpeed or 0,
            state.SpeedMultiplier,
            root and root.AssemblyLinearVelocity.Magnitude or 0
        )
        actionLabel.Text = "Last action: " .. state.LastAction
        local controllers = {
            PlayerDataController,
            AreaController,
            TrainController,
            AutoController,
            FightController,
            DashController,
            ChestController,
        }
        local ready = 0
        for _, controller in ipairs(controllers) do
            if controller then
                ready = ready + 1
            end
        end
        servicesLabel.Text = string.format("Native controllers: %d / %d ready", ready, #controllers)
        pcall(function()
            gui:SetAttribute("DogRaceModuleReady", true)
            gui:SetAttribute("DogRaceArea", tostring(area or ""))
            gui:SetAttribute("DogRaceStrength", tonumber(data and data.Strength) or 0)
            gui:SetAttribute("DogRaceWins", tonumber(data and data.Wins) or 0)
            gui:SetAttribute("DogRaceRebirths", tonumber(data and data.Rebirths) or 0)
            gui:SetAttribute("DogRaceAutoTrain", hasTrainingPosture())
            gui:SetAttribute("DogRaceAutoRace", data and data.AutoFight == true or false)
            gui:SetAttribute("DogRaceSpeedMultiplier", state.SpeedMultiplier)
        end)
    end

    local function restoreNativeAutomation()
        local data = getData()
        local ownedContest = state.OwnsContest
        if state.OwnsAutoRace and not originalAutoRace then
            stopAutoRace()
        end
        if ownedContest and isFighting() then
            giveUpContest()
        end
        if state.OwnsAutoTrain and not originalAutoTrain then
            stopAutoTrain()
        end
        if data and originalAutoRace and not data.AutoFight then
            startAutoRace()
        elseif data and originalAutoTrain and not data.AutoTrain then
            startAutoTrain()
        end
    end

    runtimeEnvironment.__VORDogRaceCleanup = function()
        if not state.Alive then
            return
        end
        state.Alive = false
        state.AutoDash = false
        state.AutoRebirth = false
        state.AutoEquipBest = false
        state.AutoDailyChest = false
        clearSpeedOverride()
        if DashController and type(DashController.StopDash) == "function" then
            pcall(DashController.StopDash, DashController)
        end
        restoreNativeAutomation()
    end

    if gui then
        track(gui.Destroying:Connect(function()
            local cleanup = runtimeEnvironment.__VORDogRaceCleanup
            runtimeEnvironment.__VORDogRaceCleanup = nil
            if type(cleanup) == "function" then
                cleanup()
            end
        end))
    end

    local statusAccumulator = 0
    local automationAccumulator = 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then
            return
        end
        updateSpeedOverride()
        statusAccumulator = statusAccumulator + deltaTime
        automationAccumulator = automationAccumulator + deltaTime
        local now = os.clock()

        if state.AutoDash and now - state.LastDash >= state.DashInterval then
            state.LastDash = now
            dashNow()
        end
        if statusAccumulator >= 0.25 then
            statusAccumulator = 0
            updateStatus()
        end
        if automationAccumulator >= 0.5 then
            automationAccumulator = 0
            local data = getData()
            if state.AutoTrain and not hasTrainingPosture() and not isFighting()
                and now - state.LastTrainRetry >= 3 then
                state.LastTrainRetry = now
                startAutoTrain()
            end
            if state.AutoRace and data and data.AutoFight ~= true
                and now - state.LastRaceRetry >= 3 then
                state.LastRaceRetry = now
                startAutoRace()
            end
            if state.AutoRebirth and now - state.LastRebirth >= 1 then
                local cost = rebirthCost(data)
                if cost and (tonumber(data and data.Strength) or 0) >= cost then
                    state.LastRebirth = now
                    requestRebirth()
                end
            end
            if state.AutoEquipBest and now - state.LastEquipBest >= 10 then
                state.LastEquipBest = now
                equipBestPets()
            end
            if state.AutoDailyChest and now - state.LastDailyChest >= 5
                and dailyChestReady(data) then
                state.LastDailyChest = now
                claimDailyChest()
            end
        end
    end))

    updateStatus()
    selectHomeCategory("Race")
    notify("Dog Race module ready", COLORS.success)
end
