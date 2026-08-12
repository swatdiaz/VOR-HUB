-- VOR Hub - [AA] Dog Race adapter
-- UniverseId 10350558449 | PlaceId 119609933650338
--
-- Uses the game's live Knit controllers and services so training, racing,
-- hatching, shops, unlocks, upgrades, rewards, pets, and rebirths keep native
-- client/server state synchronized.

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
    local MarketplaceService = game:GetService("MarketplaceService")
    local LocalPlayer = Players.LocalPlayer

    local Knit
    local Constants
    local TreadmillsDataHelper
    local RebirthDataHelper
    local PetsDataHelper
    local PurchaseDataHelper
    local UpgradesDataHelper
    local AchievementsDataHelper
    local QuestsDataHelper
    local CratesDataHelper
    local ItemsDataHelper
    local GameDataUtil
    local EggsData = {}
    local FruitsData = {}
    local TrailsData = {}
    local HorsesData = {}
    local PrincessesData = {}
    local UpgradesData = {}
    local CratesData = {}
    local Equipment = {BirdsData = {}, ShoesData = {}}
    pcall(function()
        Knit = require(ReplicatedStorage.Packages.Knit)
        Constants = require(ReplicatedStorage.Modules.Constants)
        GameDataUtil = require(ReplicatedStorage.Modules.GameDataUtil)
        TreadmillsDataHelper = require(ReplicatedFirst.DataHelper.TreadmillsDataHelper)
        RebirthDataHelper = require(ReplicatedFirst.DataHelper.RebirthDataHelper)
        PetsDataHelper = require(ReplicatedFirst.DataHelper.PetsDataHelper)
        PurchaseDataHelper = require(ReplicatedFirst.DataHelper.PurchaseDataHelper)
        UpgradesDataHelper = require(ReplicatedFirst.DataHelper.UpgradesDataHelper)
        AchievementsDataHelper = require(ReplicatedFirst.DataHelper.AchievementsDataHelper)
        QuestsDataHelper = require(ReplicatedFirst.DataHelper.QuestsDataHelper)
        CratesDataHelper = require(ReplicatedFirst.DataHelper.CratesDataHelper)
        ItemsDataHelper = require(ReplicatedFirst.DataHelper.ItemsDataHelper)
        Equipment.BirdsDataHelper = require(ReplicatedFirst.DataHelper.BirdsDataHelper)
        Equipment.ShoesDataHelper = require(ReplicatedFirst.DataHelper.ShoesDataHelper)
        Equipment.HorsesDataHelper = require(ReplicatedFirst.DataHelper.HorsesDataHelper)
        Equipment.PrincessesDataHelper = require(ReplicatedFirst.DataHelper.PrincessesDataHelper)
        Equipment.FruitsDataHelper = require(ReplicatedFirst.DataHelper.FruitsDataHelper)
        EggsData = require(ReplicatedFirst.Data.EggsData)
        FruitsData = require(ReplicatedFirst.Data.FruitsData)
        TrailsData = require(ReplicatedFirst.Data.TrailsData)
        HorsesData = require(ReplicatedFirst.Data.HorsesData)
        PrincessesData = require(ReplicatedFirst.Data.PrincessesData)
        UpgradesData = require(ReplicatedFirst.Data.UpgradesData)
        CratesData = require(ReplicatedFirst.Data.CratesData)
        Equipment.BirdsData = require(ReplicatedFirst.Data.BirdsData)
        Equipment.ShoesData = require(ReplicatedFirst.Data.ShoesData)
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
    local EggHatchGuiController = getController("EggHatchGuiController")
    local OnlineRewardGuiController = getController("OnlineRewardGuiController")

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local RacePage = addHomeCategory("🏁 Race", 1, CATEGORY_DECALS.Combat or CATEGORY_DECALS.Movement)
    local TrainingPage = addHomeCategory("⚡ Training", 2, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local ProgressionPage = addHomeCategory("📈 Progression", 3, CATEGORY_DECALS.Progress)
    local AutomationPage = addHomeCategory("🤖 Full Auto", 4, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local EggsPage = addHomeCategory("🥚 Eggs", 5, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local ShopsPage = addHomeCategory("🛒 Shops", 6, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local UnlocksPage = addHomeCategory("🐕 Unlocks", 7, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)
    Equipment.Page = addHomeCategory("🐦 Equipment", 8, CATEGORY_DECALS.Player or CATEGORY_DECALS.Shop)
    local MovementPage = addHomeCategory("🚀 Movement", 9, CATEGORY_DECALS.Movement or CATEGORY_DECALS.Player)
    local StatusPage = addHomeCategory("📊 Status", 10, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)

    local RaceSection = RacePage:AddSection("Native Race", "Left")
    local RaceUtilitySection = RacePage:AddSection("Race Utility", "Right")
    local TrainingSection = TrainingPage:AddSection("Native Training", "Left")
    local TrainingStatusSection = TrainingPage:AddSection("Training Status", "Right")
    local RebirthSection = ProgressionPage:AddSection("Rebirth", "Left")
    local RewardsSection = ProgressionPage:AddSection("Pets & Rewards", "Right")
    local FullAutoSection = AutomationPage:AddSection("One-Click Progression", "Left")
    local ClaimAutoSection = AutomationPage:AddSection("Claims & Tasks", "Right")
    local HybridSection = AutomationPage:AddSection("Race + Power Hybrid", "Left")
    local EggHatchSection = EggsPage:AddSection("Native Egg Hatch", "Left")
    local EggStatusSection = EggsPage:AddSection("Egg Access", "Right")
    local FruitSection = ShopsPage:AddSection("Fruit Shop", "Left")
    local TrailSection = ShopsPage:AddSection("Trail Shop", "Right")
    local UpgradeSection = ShopsPage:AddSection("Bone Upgrades", "Left")
    local GearSection = ShopsPage:AddSection("Gear Crates", "Right")
    Equipment.PotionSection = ShopsPage:AddSection("Owned Potions", "Left")
    local DogSection = UnlocksPage:AddSection("Dogs", "Left")
    local PartnerSection = UnlocksPage:AddSection("Partners", "Right")
    Equipment.BirdSection = Equipment.Page:AddSection("Birds", "Left")
    Equipment.ShoeSection = Equipment.Page:AddSection("Shoes", "Right")
    local MovementSection = MovementPage:AddSection("Movement", "Left")
    local MovementStatusSection = MovementPage:AddSection("Runtime", "Right")
    local PlayerStatusSection = StatusPage:AddSection("Player Data", "Left")
    local AdapterStatusSection = StatusPage:AddSection("Adapter", "Right")

    Equipment.HomeGuideSection = HomePage:AddSection("🧭 Dog Race Instructions", "Right")
    Equipment.HomeGuideSection:AddParagraph({
        Title = "🤖 AFK everything",
        Content = "Open Full Auto and enable FULL PROGRESSION. It trains between native races, hatches, claims rewards and tasks, uses every owned potion, buys eligible upgrades, crafts duplicate pets before storage blocks hatching, equips the best loadout, and waits when currency is short.",
    })
    Equipment.HomeGuideSection:AddParagraph({
        Title = "🥚 Smart or manual eggs",
        Content = "Best Affordable Egg ON selects the most expensive unlocked egg your current Wins can buy. Full Progression hatches it once per training cycle instead of draining Wins nonstop. Turn it OFF to keep the exact selected egg.",
    })
    Equipment.HomeGuideSection:AddParagraph({
        Title = "🦴 Bones, birds, and shoes",
        Content = "Bones are the game's Diamonds currency and are awarded by native races. Full Progression keeps racing for them, then buys and equips eligible bone shoes. Birds are bought with Wins and improve top speed.",
    })
    Equipment.HomeGuideSection:AddButton({Name = "🤖 Open Full Auto", Persist = false, Callback = function()
        selectHomeCategory("🤖 Full Auto")
    end})
    Equipment.HomeGuideSection:AddButton({Name = "🐦 Open Birds & Shoes", Persist = false, Callback = function()
        selectHomeCategory("🐦 Equipment")
    end})

    local state = {
        Alive = true,
        AutoTrain = false,
        AutoRace = false,
        AutoDash = false,
        DashInterval = 1,
        SpeedMultiplier = 1,
        AutoRebirth = false,
        AutoEquipBest = false,
        AutoCraftPets = false,
        PetCraftThreshold = 75,
        PetCraftHeadroom = 10,
        AutoPotions = false,
        PotionUsing = false,
        PotionRunId = 0,
        BirdSavingsTarget = nil,
        BirdSavingsHighWater = 0,
        AutoDailyChest = false,
        FullProgression = false,
        SmartBestEgg = true,
        HybridMode = false,
        HybridPhase = "Idle",
        HybridPhaseStarted = 0,
        HybridSawFight = false,
        HybridRaceEnded = false,
        HybridTrainSeconds = 30,
        AutoOnlineRewards = false,
        AutoFreeEgg = false,
        AutoAchievements = false,
        AutoTasks = false,
        AutoFruit = false,
        AutoTrail = false,
        AutoUpgrade = false,
        AutoDog = false,
        AutoPartner = false,
        AutoGearCrate = false,
        AutoEquipGear = false,
        AutoMergeGear = false,
        AutoBird = false,
        AutoShoe = false,
        AutoWheel = false,
        WheelSpinning = false,
        SelectedCrate = "Crate_1",
        SelectedBird = "Bird_101",
        SelectedShoe = "Shoes_101",
        GearBoneReserve = 5,
        AutoHatch = false,
        HatchCount = 1,
        SelectedEgg = "Egg_1_1",
        SelectedFruit = "Fruit_1",
        SelectedTrail = "White",
        SelectedUpgrade = "Upgrade_Wins",
        SelectedDog = "Dog_101",
        SelectedPartner = "Partner_1",
        LastHatch = 0,
        LastHybridHatchPhase = -1,
        LastHybridFruitPhase = -1,
        LastFruit = 0,
        LastClaimSweep = 0,
        LastShopSweep = 0,
        LastGearSweep = 0,
        LastDash = 0,
        LastTrainRetry = 0,
        LastRaceRetry = 0,
        LastRebirth = 0,
        LastEquipBest = 0,
        LastPetCraft = 0,
        LastPotionSweep = 0,
        LastWheelSpin = 0,
        LastDailyChest = 0,
        LastAction = "Ready",
        SpeedHumanoid = nil,
        NativeWalkSpeed = nil,
        AppliedWalkSpeed = nil,
        OwnsAutoTrain = false,
        OwnsAutoRace = false,
        OwnsContest = false,
    }
    if EggHatchGuiController and type(EggHatchGuiController.ShowHatchResult) == "function" then
        Equipment.OriginalShowHatchResult = EggHatchGuiController.ShowHatchResult
        EggHatchGuiController.ShowHatchResult = function(controller, eggId, pets)
            if state.Alive and state.AutoHatch then
                state.LastAction = string.format(
                    "Silently hatched %d pet(s) from %s",
                    type(pets) == "table" and #pets or 0,
                    tostring(eggId)
                )
                return
            end
            return Equipment.OriginalShowHatchResult(controller, eggId, pets)
        end
    end
    local eggDropdownControl

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

    local function startHybridTraining()
        if isFighting() then
            return false
        end
        if getData() and getData().AutoFight then
            stopAutoRace()
        end
        local started = hasTrainingPosture() or startAutoTrain()
        state.AutoTrain = false
        if started then
            state.HybridPhase = "Training"
            state.HybridPhaseStarted = os.clock()
            state.HybridSawFight = false
            state.HybridRaceEnded = false
            state.LastAction = "Hybrid: earning treadmill power"
        end
        return started
    end

    local function startHybridRace()
        if isTraining() then
            stopAutoTrain()
        end
        local started = startAutoRace()
        state.AutoRace = false
        if started then
            state.HybridPhase = "Racing"
            state.HybridPhaseStarted = os.clock()
            state.HybridSawFight = isFighting()
            state.HybridRaceEnded = false
            state.LastAction = "Hybrid: entering the next race"
        end
        return started
    end

    local function stopHybrid()
        state.HybridMode = false
        state.HybridPhase = "Idle"
        state.HybridSawFight = false
        state.HybridRaceEnded = false
        local data = getData()
        if data and data.AutoFight then
            stopAutoRace()
        end
        if isTraining() or (data and data.AutoTrain) then
            stopAutoTrain()
        end
        state.LastAction = "Race + power hybrid stopped"
    end

    local function updateHybrid(now)
        if not state.HybridMode then
            return
        end
        if state.HybridPhase == "Idle" then
            startHybridTraining()
            return
        end
        if state.HybridPhase == "Training" then
            if isFighting() then
                state.HybridPhase = "Racing"
                state.HybridPhaseStarted = now
                state.HybridSawFight = true
                return
            end
            if not hasTrainingPosture() and now - state.LastTrainRetry >= 3 then
                state.LastTrainRetry = now
                startHybridTraining()
                return
            end
            if now - state.HybridPhaseStarted >= state.HybridTrainSeconds then
                startHybridRace()
            end
            return
        end
        if state.HybridPhase == "Racing" then
            if state.HybridRaceEnded then
                stopAutoRace()
                startHybridTraining()
            elseif isFighting() then
                state.HybridSawFight = true
            elseif state.HybridSawFight then
                stopAutoRace()
                startHybridTraining()
            elseif now - state.HybridPhaseStarted >= 120 then
                stopAutoRace()
                state.LastAction = "Hybrid race timed out; returning to power"
                startHybridTraining()
            end
        end
    end

    local fightService = getService("FightService")
    if fightService and fightService.EndContest and type(fightService.EndContest.Connect) == "function" then
        track(fightService.EndContest:Connect(function()
            if state.HybridMode and state.HybridPhase == "Racing" then
                state.HybridRaceEnded = true
                state.LastAction = "Hybrid: contest finished; returning to power"
            end
        end))
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

    local function compactNumber(value)
        local number = tonumber(value) or 0
        local suffixes = {
            {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"},
            {1e6, "M"}, {1e3, "K"},
        }
        for _, entry in ipairs(suffixes) do
            if math.abs(number) >= entry[1] then
                return string.format("%.3g%s", number / entry[1], entry[2])
            end
        end
        return tostring(math.floor(number + 0.5))
    end

    local function buildChoices(source, labelBuilder)
        local records = {}
        for id, config in pairs(source or {}) do
            records[#records + 1] = {Id = id, Config = config}
        end
        table.sort(records, function(a, b)
            local left = tonumber(a.Config.Index or a.Config.LayoutOrder) or 999999
            local right = tonumber(b.Config.Index or b.Config.LayoutOrder) or 999999
            if left == right then
                return a.Id < b.Id
            end
            return left < right
        end)
        local values, ids = {}, {}
        for _, record in ipairs(records) do
            local label = labelBuilder(record.Id, record.Config)
            values[#values + 1] = label
            ids[label] = record.Id
        end
        return values, ids
    end

    local eggChoices, eggChoiceIds = buildChoices(EggsData, function(id, config)
        return string.format("%s — %s %s", id, compactNumber(config.Price), tostring(config.Currency))
    end)
    local fruitChoices, fruitChoiceIds = buildChoices(FruitsData, function(id, config)
        return string.format("%s [%s] — %s %s | R%d", tostring(config.DisplayName), id,
            compactNumber(config.Price), tostring(config.Currency), tonumber(config.UnlockRebirthCount) or 0)
    end)
    local trailChoices, trailChoiceIds = buildChoices(TrailsData, function(id, config)
        return string.format("%s [%s] — %s %s | +%s%% acc | R%d", tostring(config.Name), id,
            compactNumber(config.Price), tostring(config.Currency), tostring(config.AccBoost or 0),
            tonumber(config.UnlockRebirthCount) or 0)
    end)
    local upgradeChoices, upgradeChoiceIds = buildChoices(UpgradesData, function(id, config)
        return string.format("%s [%s]", tostring(config.Name), id)
    end)
    local dogChoices, dogChoiceIds = buildChoices(HorsesData, function(id, config)
        return string.format("%s [%s] — %s %s", tostring(config.DisplayName), id,
            compactNumber(config.UnlockCount), tostring(config.UnlockCurrency))
    end)
    local partnerChoices, partnerChoiceIds = buildChoices(PrincessesData, function(id, config)
        return string.format("%s [%s] — %s %s", tostring(config.DisplayName), id,
            compactNumber(config.UnlockValue), tostring(config.UnlockType))
    end)
    local crateChoices, crateChoiceIds = buildChoices(CratesData, function(id, config)
        return string.format("%s [%s] — %s %s", tostring(config.Name or config.DisplayName or id), id,
            compactNumber(config.Price), tostring(config.Currency or "Bones"))
    end)

    Equipment.BirdChoices, Equipment.BirdChoiceIds = buildChoices(Equipment.BirdsData, function(id, config)
        local boost = 0
        pcall(function() boost = Equipment.BirdsDataHelper.GetBoostValue(id) end)
        return string.format("%s [%s] - %s %s | +%s%% top speed",
            tostring(config.DisplayName or config.Name or id), id,
            compactNumber(config.UnlockCount), tostring(config.UnlockCurrency),
            tostring(boost))
    end)
    Equipment.ShoeChoices, Equipment.ShoeChoiceIds = buildChoices(Equipment.ShoesData, function(id, config)
        local boost = 0
        pcall(function() boost = Equipment.ShoesDataHelper.GetAccBoost(id) end)
        return string.format("%s [%s] - %s %s | +%s%% acceleration",
            tostring(config.Name or config.DisplayName or id), id,
            compactNumber(config.UnlockCount), tostring(config.Currency),
            tostring(boost))
    end)

    local function choiceForId(values, ids, targetId)
        for _, value in ipairs(values) do
            if ids[value] == targetId then
                return value
            end
        end
        return values[1]
    end

    local function fireServiceRemote(serviceName, remoteName, ...)
        local service = getService(serviceName)
        local remote = service and service[remoteName]
        if not remote or type(remote.Fire) ~= "function" then
            return false, serviceName .. "." .. remoteName .. " unavailable"
        end
        local arguments = table.pack(...)
        local ok, result = pcall(function()
            return remote:Fire(table.unpack(arguments, 1, arguments.n))
        end)
        return ok, result
    end

    local function promptProduct(purchaseKey)
        if not PurchaseDataHelper then
            state.LastAction = "Purchase helper unavailable"
            return false
        end
        local ok, productId = pcall(PurchaseDataHelper.GetProductId, purchaseKey)
        if not ok or not productId then
            state.LastAction = "No native product for " .. tostring(purchaseKey)
            return false
        end
        local promptOk, promptError = pcall(
            MarketplaceService.PromptProductPurchase,
            MarketplaceService,
            LocalPlayer,
            productId
        )
        state.LastAction = promptOk and ("Opened Robux prompt for " .. tostring(purchaseKey))
            or ("Robux prompt failed: " .. tostring(promptError))
        return promptOk
    end

    local function promptTripleHatchPass()
        if not PurchaseDataHelper then
            return false
        end
        local passKey = Constants and Constants.GAMEPASS and Constants.GAMEPASS.TRIPLE_HATCH or "TripleHatch"
        local ok, productId = pcall(PurchaseDataHelper.GetProductId, passKey)
        if not ok or not productId then
            state.LastAction = "Triple Hatch gamepass product unavailable"
            return false
        end
        local promptOk, promptError = pcall(
            MarketplaceService.PromptGamePassPurchase,
            MarketplaceService,
            LocalPlayer,
            productId
        )
        state.LastAction = promptOk and "Opened Triple Hatch gamepass prompt"
            or ("Triple Hatch prompt failed: " .. tostring(promptError))
        return promptOk
    end

    local function currencyAmount(data, currency)
        if not data then
            return 0
        end
        if currency == "Wins" then
            return tonumber(data.Wins) or 0
        elseif currency == "Diamond" or currency == "Diamonds" then
            return tonumber(data.Diamonds) or 0
        elseif currency == "JurassicToken" then
            return tonumber(data.JurassicTokens) or 0
        elseif currency == "TowerTokens" then
            return tonumber(data.FruitTokens or data.TowerTokens) or 0
        elseif currency == "ChristmasTokens" then
            return tonumber(data.ChristmasTokens) or 0
        end
        return tonumber(data[currency]) or 0
    end

    local function eggArea(eggId)
        local areas = workspace:FindFirstChild("Areas")
        if not areas then
            return nil
        end
        for _, area in ipairs(areas:GetChildren()) do
            local eggs = area:FindFirstChild("Eggs")
            if eggs then
                for _, model in ipairs(eggs:GetChildren()) do
                    if model:GetAttribute("EggId") == eggId then
                        return area.Name
                    end
                end
            end
        end
        return nil
    end

    local function hatchPrice(data, eggId)
        local config = EggsData[eggId]
        if not config then
            return nil
        end
        if config.Currency == "Wins" and GameDataUtil then
            local ok, price = pcall(GameDataUtil.CalculateHatchPrice, data, eggId)
            if ok and tonumber(price) then
                return tonumber(price)
            end
        end
        return tonumber(config.Price) or 0
    end

    local function storedPetCount(data)
        if PetsDataHelper then
            local ok, count = pcall(PetsDataHelper.GetStoredPetsNum, data)
            if ok and tonumber(count) then
                return tonumber(count)
            end
        end
        local count = 0
        for _ in pairs(data and data.Pets or {}) do
            count = count + 1
        end
        return count
    end

    local function maxPetStorage(data)
        if GameDataUtil then
            local ok, count = pcall(GameDataUtil.GetMaxPetStorageNum, data)
            if ok and tonumber(count) then
                return tonumber(count)
            end
        end
        return math.huge
    end

    function Equipment.hasCraftablePets(data)
        if not data or not PetsDataHelper or type(data.Pets) ~= "table" then
            return false
        end
        for _, pet in pairs(data.Pets) do
            if (tonumber(pet.Size) or 0) < 2 then
                local ok, count = pcall(PetsDataHelper.GetSameSizeCount, pet, data)
                if ok and (tonumber(count) or 0) >= 3 then
                    return true
                end
            end
        end
        return false
    end

    function Equipment.petCraftNeeded(data, incomingCount)
        if not data then
            return false
        end
        local stored = storedPetCount(data)
        local maximum = maxPetStorage(data)
        if maximum == math.huge or maximum <= 0 then
            return false
        end
        local threshold = math.floor(maximum * state.PetCraftThreshold / 100)
        local safeLimit = math.max(0, maximum - state.PetCraftHeadroom)
        return stored + math.max(0, tonumber(incomingCount) or 0) >= math.min(threshold, safeLimit)
    end

    function Equipment.craftAllPets(force)
        local data = getData()
        if not data or (not force and not Equipment.hasCraftablePets(data)) then
            state.LastAction = "Pets: no duplicate set is ready to craft"
            return false
        end
        local service = getService("PetService")
        local remote = service and service.EnlargeAllPets
        if not remote or type(remote.Fire) ~= "function" then
            state.LastAction = "Craft All Pets remote unavailable"
            return false
        end
        local ok, result = pcall(remote.Fire, remote)
        state.LastAction = ok and "Craft All requested; refreshing best pet loadout"
            or ("Craft All failed: " .. tostring(result))
        if ok then
            task.delay(2, equipBestPets)
        end
        return ok
    end

    function Equipment.useAllPotions()
        if state.PotionUsing then
            state.LastAction = "Owned potions are already being consumed"
            return false
        end
        local data = getData()
        local service = getService("PotionService")
        local remote = service and service.UsePotion
        if not data or not remote or type(remote.Fire) ~= "function" then
            state.LastAction = "Potion service unavailable"
            return false
        end
        local queue = {}
        for potionId, potion in pairs(data.Potions or {}) do
            for _ = 1, math.max(0, tonumber(potion.Count) or 0) do
                table.insert(queue, potionId)
            end
        end
        if #queue == 0 then
            state.LastAction = "Potions: owned inventory is empty"
            return false
        end
        state.PotionRunId = state.PotionRunId + 1
        local runId = state.PotionRunId
        state.PotionUsing = true
        state.LastAction = string.format("Using all %d owned potion(s)", #queue)
        task.spawn(function()
            local used = 0
            for _, potionId in ipairs(queue) do
                if not state.Alive or state.PotionRunId ~= runId then
                    break
                end
                if pcall(remote.Fire, remote, potionId) then
                    used = used + 1
                end
                task.wait(0.2)
            end
            if state.PotionRunId == runId then
                state.PotionUsing = false
                state.LastAction = string.format("Used %d owned potion(s)", used)
            end
        end)
        return true
    end

    function Equipment.updatePotionStatus(data)
        local count, active = 0, 0
        for _, potion in pairs(data and data.Potions or {}) do
            count = count + math.max(0, tonumber(potion.Count) or 0)
            if (tonumber(potion.LastTime) or 0) > os.time() then
                active = active + 1
            end
        end
        if Equipment.PotionStatusLabel then
            Equipment.PotionStatusLabel.Text = string.format(
                "Owned: %d | Active types: %d | Auto %s",
                count,
                active,
                state.AutoPotions and "ON" or "OFF"
            )
        end
        if gui then
            gui:SetAttribute("DogRaceOwnedPotionCount", count)
            gui:SetAttribute("DogRaceActivePotionTypes", active)
        end
    end

    function Equipment.nextBirdWinsTarget(data)
        if not data or not Equipment.BirdsDataHelper then
            return nil, 0
        end
        if GameDataUtil and type(GameDataUtil.IsBirdSystemLocked) == "function" then
            local ok, locked = pcall(GameDataUtil.IsBirdSystemLocked, data)
            if ok and locked then
                return nil, 0
            end
        end
        local targetId, reserve = nil, math.huge
        for birdId in pairs(Equipment.BirdsData) do
            if not (data.Birds and data.Birds[birdId]) then
                local okCurrency, currency = pcall(Equipment.BirdsDataHelper.GetUnlockCurrency, birdId)
                local okPrice, price = pcall(Equipment.BirdsDataHelper.GetUnlockCount, birdId)
                if okCurrency and currency == "Wins" and okPrice and tonumber(price)
                    and tonumber(price) < reserve then
                    targetId, reserve = birdId, tonumber(price)
                end
            end
        end
        return targetId, reserve < math.huge and reserve or 0
    end

    function Equipment.nextBirdWinsReserve(data)
        local _, reserve = Equipment.nextBirdWinsTarget(data)
        return reserve
    end

    function Equipment.eggSpendableWins(data)
        local balance = currencyAmount(data, "Wins")
        if not state.FullProgression or not state.AutoBird then
            return balance, 0
        end
        local targetId, targetPrice = Equipment.nextBirdWinsTarget(data)
        if not targetId or targetPrice <= 0 then
            return balance, 0
        end
        if state.BirdSavingsTarget ~= targetId then
            state.BirdSavingsTarget = targetId
            state.BirdSavingsHighWater = balance
        else
            state.BirdSavingsHighWater = math.max(state.BirdSavingsHighWater, balance)
        end
        local savingsFloor = math.min(targetPrice, math.floor(state.BirdSavingsHighWater * 0.9))
        return math.max(0, balance - savingsFloor), savingsFloor
    end

    local function eggAccess(count)
        local data = getData()
        local eggId = state.SelectedEgg
        local config = EggsData[eggId]
        count = tonumber(count) or 1
        if not data or not config then
            return false, "Egg data unavailable"
        end
        local area = eggArea(eggId)
        if area and data.Areas and data.Areas[area] == false then
            return false, "Locked area: " .. area
        end
        if config.Currency == "Robux" then
            return false, string.format("Robux egg: %s R$ (prompt only)", compactNumber(config.Price))
        end
        if config.Currency == "Season" then
            return false, "Season reward egg; native season claim required"
        end
        if count == 3 and not (data.GamePasses and data.GamePasses.TripleHatch) then
            return false, "Triple Hatch gamepass required"
        end
        if storedPetCount(data) + count > maxPetStorage(data) then
            return false, "Pet storage full"
        end
        local price = hatchPrice(data, eggId) or 0
        local balance = currencyAmount(data, config.Currency)
        if balance < price * count then
            return false, string.format("Need %s %s; have %s", compactNumber(price * count),
                tostring(config.Currency), compactNumber(balance))
        end
        return true, string.format("Ready: %sx %s costs %s %s", count, eggId,
            compactNumber(price * count), tostring(config.Currency))
    end

    local function bestAffordableWinsEgg(count)
        local data = getData()
        count = tonumber(count) or 1
        if not data or storedPetCount(data) + count > maxPetStorage(data) then
            return nil
        end
        if count == 3 and not (data.GamePasses and data.GamePasses.TripleHatch) then
            return nil
        end

        local balance = currencyAmount(data, "Wins")
        local bestId, bestPrice = nil, -math.huge
        for eggId, config in pairs(EggsData) do
            if config.Currency == "Wins" then
                local area = eggArea(eggId)
                local unlocked = not (area and data.Areas and data.Areas[area] == false)
                local price = hatchPrice(data, eggId)
                if unlocked and price and balance >= price * count and price > bestPrice then
                    bestId, bestPrice = eggId, price
                end
            end
        end
        return bestId, bestPrice
    end

    local function retargetBestAffordableWinsEgg()
        local eggId, price = bestAffordableWinsEgg(state.HatchCount)
        if not eggId or eggId == state.SelectedEgg then
            return eggId ~= nil
        end

        local dropdownValue = choiceForId(eggChoices, eggChoiceIds, eggId)
        if eggDropdownControl and dropdownValue then
            eggDropdownControl:Set(dropdownValue)
        else
            state.SelectedEgg = eggId
            state.LastHatch = 0
        end
        state.LastAction = string.format(
            "Auto hatch retargeted to best affordable egg: %s (%s Wins)",
            eggId,
            compactNumber((price or 0) * state.HatchCount)
        )
        return true
    end

    local function hatchSelected(count, promptLockedPurchase)
        local eggId = state.SelectedEgg
        local config = EggsData[eggId]
        count = tonumber(count) or 1
        if not config then
            state.LastAction = "Select a valid egg"
            return false
        end
        if config.Currency == "Robux" then
            local purchaseKey = eggId .. (count == 3 and "x3" or count == 10 and "x10" or "")
            return promptLockedPurchase and promptProduct(purchaseKey) or false
        end
        local data = getData()
        if data and state.AutoCraftPets and Equipment.petCraftNeeded(data, count)
            and Equipment.hasCraftablePets(data) then
            Equipment.craftAllPets(false)
            state.LastAction = string.format(
                "Maintaining pet capacity before hatch (%d/%d)",
                storedPetCount(data),
                maxPetStorage(data)
            )
            return false
        end
        if data and GameDataUtil and type(GameDataUtil.CheckStorageFull) == "function" then
            local okFull, full = pcall(GameDataUtil.CheckStorageFull, data, count)
            if okFull and full then
                if state.AutoCraftPets then
                    Equipment.craftAllPets(true)
                    state.LastAction = "Pet storage full; crafting duplicates before hatching"
                else
                    state.LastAction = "Pet storage full; enable Auto Craft Pets"
                end
                return false
            end
        end
        if count == 3 and data and not (data.GamePasses and data.GamePasses.TripleHatch) then
            state.LastAction = "Triple Hatch gamepass required"
            if promptLockedPurchase then
                promptTripleHatchPass()
            end
            return false
        end
        local allowed, reason = eggAccess(count)
        if not allowed then
            state.LastAction = reason
            return false
        end
        if EggHatchGuiController and type(EggHatchGuiController.IsHatching) == "function" then
            local ok, active = pcall(EggHatchGuiController.IsHatching, EggHatchGuiController)
            if ok and active then
                if state.AutoHatch and type(EggHatchGuiController.CloseResultGui) == "function" then
                    local closeOk, closeError = pcall(
                        EggHatchGuiController.CloseResultGui,
                        EggHatchGuiController
                    )
                    if not closeOk then
                        state.LastAction = "Could not close hatch result: " .. tostring(closeError)
                        return false
                    end
                else
                    state.LastAction = "Native hatch animation still active"
                    return false
                end
            end
        end
        local ok, result = fireServiceRemote("EggHatchService", "Hatch", eggId, count)
        state.LastAction = ok and string.format("Requested %sx %s hatch", count, eggId)
            or ("Hatch failed: " .. tostring(result))
        return ok
    end

    local function selectedHorseId(data)
        for id, horse in pairs(data and data.Horses or {}) do
            if horse.Equipped then
                return id
            end
        end
        return nil
    end

    local function fruitAccess()
        local data = getData()
        local config = FruitsData[state.SelectedFruit]
        if not data or not config then
            return false, "Fruit data unavailable"
        end
        if config.Currency == "Robux" then
            return false, string.format("Robux fruit: %s R$ (prompt only)", compactNumber(config.Price))
        end
        local rebirths = tonumber(data.Rebirths) or 0
        local required = tonumber(config.UnlockRebirthCount) or 0
        if rebirths < required then
            return false, string.format("Need %d rebirths; have %d", required, rebirths)
        end
        if not selectedHorseId(data) then
            return false, "Equip a dog first"
        end
        local balance = currencyAmount(data, config.Currency)
        local price = tonumber(config.Price) or 0
        if state.FullProgression and config.Currency == "Wins" then
            local reserve = Equipment.nextBirdWinsReserve(data)
            if balance - price < reserve then
                return false, string.format("Saving %s Wins for the next bird", compactNumber(reserve))
            end
        end
        if balance < price then
            return false, string.format("Need %s %s; have %s", compactNumber(price),
                tostring(config.Currency), compactNumber(balance))
        end
        return true, string.format("Ready: +%s XP for %s %s", compactNumber(config.Exp),
            compactNumber(price), tostring(config.Currency))
    end

    local function buySelectedFruit()
        local config = FruitsData[state.SelectedFruit]
        if not config then
            return false
        end
        if config.Currency == "Robux" then
            return promptProduct(state.SelectedFruit)
        end
        local allowed, reason = fruitAccess()
        if not allowed then
            state.LastAction = reason
            return false
        end
        local cooldown = tonumber(Constants and Constants.FEED_FRUIT_COOLDOWN) or 0.5
        if os.clock() - state.LastFruit < cooldown then
            state.LastAction = "Fruit feed cooldown active"
            return false
        end
        state.LastFruit = os.clock()
        local ok, result = fireServiceRemote("FruitShopService", "BuyFruitEvent", state.SelectedFruit)
        state.LastAction = ok and ("Bought and fed " .. tostring(config.DisplayName))
            or ("Fruit purchase failed: " .. tostring(result))
        return ok
    end

    local function trailAccess(requireOwned)
        local data = getData()
        local id = state.SelectedTrail
        local config = TrailsData[id]
        if not data or not config then
            return false, "Trail data unavailable"
        end
        local owned = data.Trails and data.Trails[id] ~= nil
        if requireOwned then
            return owned, owned and "Owned; ready to equip" or "Buy this trail first"
        end
        if owned then
            return false, "Trail already owned"
        end
        if config.Currency == "Robux" then
            return false, string.format("Robux trail: %s R$ (prompt only)", compactNumber(config.Price))
        elseif config.Currency == "HalloweenEvent" then
            return false, "Event trail; native event unlock required"
        end
        local rebirths = tonumber(data.Rebirths) or 0
        local required = tonumber(config.UnlockRebirthCount) or 0
        if rebirths < required then
            return false, string.format("Need %d rebirths; have %d", required, rebirths)
        end
        local balance = currencyAmount(data, config.Currency)
        local price = tonumber(config.Price) or 0
        if balance < price then
            return false, string.format("Need %s %s; have %s", compactNumber(price),
                tostring(config.Currency), compactNumber(balance))
        end
        return true, string.format("Ready: +%s%% acceleration for %s %s",
            tostring(config.AccBoost or 0), compactNumber(price), tostring(config.Currency))
    end

    local function buySelectedTrail()
        local config = TrailsData[state.SelectedTrail]
        if not config then
            return false
        end
        if config.Currency == "Robux" then
            return promptProduct(state.SelectedTrail)
        end
        local allowed, reason = trailAccess(false)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("TrailService", "BuyTrailEvent", state.SelectedTrail)
        state.LastAction = ok and ("Requested trail purchase: " .. state.SelectedTrail)
            or ("Trail purchase failed: " .. tostring(result))
        return ok
    end

    local function equipSelectedTrail()
        local allowed, reason = trailAccess(true)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("TrailService", "EquipTrailEvent", state.SelectedTrail)
        state.LastAction = ok and ("Equipped trail: " .. state.SelectedTrail)
            or ("Trail equip failed: " .. tostring(result))
        return ok
    end

    local function unequipSelectedTrail()
        local ok, result = fireServiceRemote("TrailService", "UnequipTrailEvent", state.SelectedTrail)
        state.LastAction = ok and ("Unequipped trail: " .. state.SelectedTrail)
            or ("Trail unequip failed: " .. tostring(result))
        return ok
    end

    function Equipment.nextShoeBoneReserve(data)
        if not data or not Equipment.ShoesDataHelper then
            return 0
        end
        if GameDataUtil and type(GameDataUtil.IsShoeSystemLocked) == "function" then
            local ok, locked = pcall(GameDataUtil.IsShoeSystemLocked, data)
            if ok and locked then
                return 0
            end
        end
        local reserve = math.huge
        for shoeId in pairs(Equipment.ShoesData) do
            if not (data.Shoes and data.Shoes[shoeId]) then
                local okCurrency, currency = pcall(Equipment.ShoesDataHelper.GetCurrency, shoeId)
                local okPrice, price = pcall(Equipment.ShoesDataHelper.GetUnlockCount, shoeId)
                if okCurrency and currency == "Diamond" and okPrice and tonumber(price) then
                    reserve = math.min(reserve, tonumber(price))
                end
            end
        end
        return reserve < math.huge and reserve or 0
    end

    local function upgradeAccess()
        local data = getData()
        local config = UpgradesData[state.SelectedUpgrade]
        if not data or not config or not UpgradesDataHelper then
            return false, "Upgrade data unavailable"
        end
        local level = tonumber(data.Upgrades and data.Upgrades[state.SelectedUpgrade]) or 0
        local maxLevel = tonumber(config.MaxLevel) or 0
        if level >= maxLevel then
            return false, string.format("Max level %d/%d", level, maxLevel)
        end
        local ok, price = pcall(UpgradesDataHelper.GetPrice, state.SelectedUpgrade, level + 1)
        price = ok and tonumber(price) or math.huge
        local bones = tonumber(data.Diamonds) or 0
        local reserve = state.FullProgression and Equipment.nextShoeBoneReserve(data) or 0
        if bones < price + reserve then
            return false, string.format("Need %s bones plus %s shoe reserve; have %s | level %d/%d",
                compactNumber(price), compactNumber(reserve), compactNumber(bones), level, maxLevel)
        end
        return true, string.format("Ready: %s bones | level %d -> %d/%d",
            compactNumber(price), level, level + 1, maxLevel)
    end

    local function buySelectedUpgrade()
        local allowed, reason = upgradeAccess()
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("UpgradeService", "Upgrade", state.SelectedUpgrade)
        state.LastAction = ok and ("Requested bone upgrade: " .. state.SelectedUpgrade)
            or ("Upgrade failed: " .. tostring(result))
        return ok
    end

    local function dogAccess(requireOwned)
        local data = getData()
        local id = state.SelectedDog
        local config = HorsesData[id]
        if not data or not config then
            return false, "Dog data unavailable"
        end
        local owned = data.Horses and data.Horses[id] ~= nil
        if requireOwned then
            return owned, owned and "Owned; ready to equip" or "Unlock this dog first"
        end
        if owned then
            return false, "Dog already owned"
        end
        if config.LocatedArea and data.Areas and data.Areas[config.LocatedArea] == false then
            return false, "Locked area: " .. tostring(config.LocatedArea)
        end
        if config.UnlockCurrency == "Robux" then
            return false, string.format("Robux dog: %s R$ (prompt only)", compactNumber(config.UnlockCount))
        end
        local balance = currencyAmount(data, config.UnlockCurrency)
        local price = tonumber(config.UnlockCount) or 0
        if balance < price then
            return false, string.format("Need %s %s; have %s", compactNumber(price),
                tostring(config.UnlockCurrency), compactNumber(balance))
        end
        return true, string.format("Ready: speed %s | cost %s %s", tostring(config.RaceSpeed),
            compactNumber(price), tostring(config.UnlockCurrency))
    end

    local function unlockSelectedDog()
        local config = HorsesData[state.SelectedDog]
        if not config then
            return false
        end
        if config.UnlockCurrency == "Robux" then
            return promptProduct(state.SelectedDog)
        end
        local allowed, reason = dogAccess(false)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("HorseService", "UnlockHorseEvent", state.SelectedDog,
            config.UnlockCurrency == "JurassicToken" and "JurassicToken" or nil)
        state.LastAction = ok and ("Requested dog unlock: " .. state.SelectedDog)
            or ("Dog unlock failed: " .. tostring(result))
        return ok
    end

    local function equipSelectedDog()
        local allowed, reason = dogAccess(true)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("HorseService", "EquipHorseEvent", state.SelectedDog)
        state.LastAction = ok and ("Equipped dog: " .. state.SelectedDog)
            or ("Dog equip failed: " .. tostring(result))
        return ok
    end

    local function partnerAccess(requireOwned)
        local data = getData()
        local id = state.SelectedPartner
        local config = PrincessesData[id]
        if not data or not config then
            return false, "Partner data unavailable"
        end
        local owned = data.Princesses and data.Princesses[id] ~= nil
        if requireOwned then
            return owned, owned and "Owned; ready to equip" or "Unlock this partner first"
        end
        if owned then
            return false, "Partner already owned"
        end
        if config.UnlockType == "Robux" then
            return false, string.format("Robux partner: %s R$ (prompt only)", compactNumber(config.UnlockValue))
        end
        local wins = tonumber(data.Wins) or 0
        local price = tonumber(config.UnlockValue) or 0
        if wins < price then
            return false, string.format("Need %s Wins; have %s", compactNumber(price), compactNumber(wins))
        end
        return true, string.format("Ready: +%s%% wins | +%s%% luck | cost %s Wins",
            tostring(config.WinsBoost or 0), tostring(config.LuckBoost or 0), compactNumber(price))
    end

    local function unlockSelectedPartner()
        local config = PrincessesData[state.SelectedPartner]
        if not config then
            return false
        end
        if config.UnlockType == "Robux" then
            return promptProduct(state.SelectedPartner)
        end
        local allowed, reason = partnerAccess(false)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("PrincessService", "UnlockPrincess", state.SelectedPartner, "Wins")
        state.LastAction = ok and ("Requested partner unlock: " .. state.SelectedPartner)
            or ("Partner unlock failed: " .. tostring(result))
        return ok
    end

    local function equipSelectedPartner()
        local allowed, reason = partnerAccess(true)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("PrincessService", "EquipPrincess", state.SelectedPartner)
        state.LastAction = ok and ("Equipped partner: " .. state.SelectedPartner)
            or ("Partner equip failed: " .. tostring(result))
        return ok
    end

    local function unequipSelectedPartner()
        local ok, result = fireServiceRemote("PrincessService", "UnequipPrincess", state.SelectedPartner)
        state.LastAction = ok and ("Unequipped partner: " .. state.SelectedPartner)
            or ("Partner unequip failed: " .. tostring(result))
        return ok
    end

    function Equipment.bestDogStep()
        local data = getData()
        if not data or not Equipment.HorsesDataHelper then
            return false
        end
        local bestOwned, bestOwnedIndex, buyId, buyIndex = nil, -math.huge, nil, -math.huge
        for dogId, config in pairs(HorsesData) do
            if string.sub(dogId, 1, 4) == "Dog_" then
                local okIndex, index = pcall(Equipment.HorsesDataHelper.GetIndex, dogId)
                index = okIndex and tonumber(index) or 0
                if data.Horses and data.Horses[dogId] then
                    if index > bestOwnedIndex then
                        bestOwned, bestOwnedIndex = dogId, index
                    end
                elseif config.UnlockCurrency ~= "Robux"
                    and not (config.LocatedArea and data.Areas and data.Areas[config.LocatedArea] == false)
                    and currencyAmount(data, config.UnlockCurrency) >= (tonumber(config.UnlockCount) or math.huge)
                    and index > buyIndex then
                    buyId, buyIndex = dogId, index
                end
            end
        end
        if bestOwned and selectedHorseId(data) ~= bestOwned then
            state.SelectedDog = bestOwned
            return equipSelectedDog()
        end
        if buyId then
            state.SelectedDog = buyId
            return unlockSelectedDog()
        end
        return false
    end

    function Equipment.bestPartnerStep()
        local data = getData()
        if not data or not Equipment.PrincessesDataHelper then
            return false
        end
        local bestOwned, bestOwnedIndex, buyId, buyIndex = nil, -math.huge, nil, -math.huge
        local equipped
        for partnerId, partner in pairs(data.Princesses or {}) do
            if partner.Equipped then
                equipped = partnerId
            end
        end
        for partnerId, config in pairs(PrincessesData) do
            local okIndex, index = pcall(Equipment.PrincessesDataHelper.GetIndex, partnerId)
            index = okIndex and tonumber(index) or 0
            if data.Princesses and data.Princesses[partnerId] then
                if index > bestOwnedIndex then
                    bestOwned, bestOwnedIndex = partnerId, index
                end
            elseif config.UnlockType == "Wins"
                and (tonumber(data.Wins) or 0) >= (tonumber(config.UnlockValue) or math.huge)
                and index > buyIndex then
                buyId, buyIndex = partnerId, index
            end
        end
        if bestOwned and equipped ~= bestOwned then
            state.SelectedPartner = bestOwned
            return equipSelectedPartner()
        end
        if buyId then
            state.SelectedPartner = buyId
            return unlockSelectedPartner()
        end
        return false
    end

    function Equipment.bestFruitStep()
        local data = getData()
        if not data then
            return false
        end
        local bestId, bestPrice = nil, -math.huge
        for fruitId, config in pairs(FruitsData) do
            local price = tonumber(config.Price) or math.huge
            if config.Currency ~= "Robux"
                and (tonumber(data.Rebirths) or 0) >= (tonumber(config.UnlockRebirthCount) or 0)
                and currencyAmount(data, config.Currency) >= price
                and price > bestPrice then
                bestId, bestPrice = fruitId, price
            end
        end
        if bestId then
            state.SelectedFruit = bestId
            return buySelectedFruit()
        end
        return false
    end

    function Equipment.bestUpgradeStep()
        local data = getData()
        if not data or not UpgradesDataHelper then
            return false
        end
        local bones = tonumber(data.Diamonds) or 0
        local shoeReserve = Equipment.nextShoeBoneReserve(data)
        if shoeReserve > 0 and bones >= shoeReserve then
            return false
        end
        local budget = shoeReserve > 0 and math.max(1, math.floor(bones * 0.2)) or bones
        local bestId, bestPrice = nil, math.huge
        for upgradeId, config in pairs(UpgradesData) do
            local level = tonumber(data.Upgrades and data.Upgrades[upgradeId]) or 0
            if level < (tonumber(config.MaxLevel) or 0) then
                local ok, price = pcall(UpgradesDataHelper.GetPrice, upgradeId, level + 1)
                price = ok and tonumber(price) or math.huge
                if price <= budget and price < bestPrice then
                    bestId, bestPrice = upgradeId, price
                end
            end
        end
        if bestId then
            state.SelectedUpgrade = bestId
            local ok, result = fireServiceRemote("UpgradeService", "Upgrade", bestId)
            state.LastAction = ok and ("Requested balanced bone upgrade: " .. bestId)
                or ("Upgrade failed: " .. tostring(result))
            return ok
        end
        return false
    end

    function Equipment.spinFreeWheel()
        local data = getData()
        local cooldown = tonumber(Constants and Constants.SPINNING_WHEEL_TIME) or 86400
        if not data or state.WheelSpinning
            or os.time() - (tonumber(data.SpinningWheelLastCheckTime) or os.time()) <= cooldown then
            return false
        end
        local service = getService("SpinningWheelService")
        if not service or type(service.StartSpin) ~= "function" then
            return false
        end
        local ok, promise = pcall(service.StartSpin, service)
        if not ok then
            return false
        end
        state.WheelSpinning = true
        state.LastAction = "Started free wheel spin"
        if promise and type(promise.andThen) == "function" then
            promise:andThen(function(result)
                state.WheelSpinning = false
                state.LastAction = result and result.resultIndex ~= 0
                    and ("Wheel reward: " .. tostring(result.resultText))
                    or "Free wheel spin rejected"
            end):catch(function(message)
                state.WheelSpinning = false
                state.LastAction = "Wheel error: " .. tostring(message)
            end)
        else
            state.WheelSpinning = false
        end
        return true
    end

    local function claimAvailableOnlineRewards()
        local data = getData()
        local times = Constants and Constants.ONLINE_REWARDS_TIME
        local startTime = OnlineRewardGuiController and tonumber(OnlineRewardGuiController._OnlineStartTime)
        if not data or type(times) ~= "table" or not startTime then
            state.LastAction = "Online reward timer is not ready"
            return 0
        end
        local elapsed = os.time() - startTime
        local claimed = data.OnlineRewardsClaimLog or {}
        local count = 0
        for index, unlockTime in ipairs(times) do
            if elapsed >= (tonumber(unlockTime) or math.huge) and claimed[index] ~= true then
                local ok = fireServiceRemote("OnlineRewardService", "ClaimOnlineReward", index)
                if ok then
                    count = count + 1
                end
            end
        end
        state.LastAction = count > 0 and string.format("Claimed %d online gift(s)", count)
            or "Online gifts: waiting for the next timer"
        return count
    end

    local function claimFreeOnlineEgg()
        local data = getData()
        if not data or data.OnlineQuestTaskDown ~= true then
            state.LastAction = "Free online egg: waiting for the timer"
            return false
        end
        local onlineQuestGui = LocalPlayer:FindFirstChild("PlayerGui")
            and LocalPlayer.PlayerGui:FindFirstChild("OnlineQuestGui")
        local claimButton = onlineQuestGui and onlineQuestGui:FindFirstChild("ClaimButton", true)
        if claimButton and claimButton:IsA("GuiButton") and type(firesignal) == "function" then
            local ok, result = pcall(firesignal, claimButton.MouseButton1Click)
            state.LastAction = ok and "Claimed the timed free pet egg through the native reward flow"
                or ("Free online egg button failed: " .. tostring(result))
            return ok
        end
        state.LastAction = "Native free egg claim signal unavailable"
        return false
    end

    local function claimAvailableAchievements()
        local data = getData()
        if not data or not AchievementsDataHelper then
            state.LastAction = "Achievement data unavailable"
            return 0
        end
        local okTypes, achievementTypes = pcall(AchievementsDataHelper.GetChievementTypes)
        if not okTypes or type(achievementTypes) ~= "table" then
            state.LastAction = "Achievement types unavailable"
            return 0
        end
        local count = 0
        for _, achievementType in ipairs(achievementTypes) do
            local rank = tonumber(data.AchievementRanks and data.AchievementRanks[achievementType]) or 0
            local okMax, maxRank = pcall(AchievementsDataHelper.GetAchievementMaxRank, achievementType)
            if okMax and rank < (tonumber(maxRank) or 0) then
                local okId, achievementId = pcall(
                    AchievementsDataHelper.GetAchievementIdByRank,
                    achievementType,
                    rank + 1
                )
                local okProgress, progress = pcall(
                    AchievementsDataHelper.GetProgressValueByType,
                    data,
                    achievementType
                )
                local okRequirement, requirement = false, nil
                if achievementId then
                    okRequirement, requirement = pcall(
                        AchievementsDataHelper.GetRequirementValue,
                        achievementId
                    )
                end
                if okId and okProgress and okRequirement
                    and (tonumber(progress) or 0) >= (tonumber(requirement) or math.huge) then
                    local fired = fireServiceRemote(
                        "AchievementService",
                        "ClaimAchievementEvent",
                        achievementId
                    )
                    if fired then
                        count = count + 1
                    end
                end
            end
        end
        state.LastAction = count > 0 and string.format("Claimed %d achievement(s)", count)
            or "Achievements: nothing claimable yet"
        return count
    end

    local function claimAvailableTasks()
        local data = getData()
        if not data or not QuestsDataHelper then
            state.LastAction = "Task data unavailable"
            return 0
        end
        local count = 0
        for _, questType in ipairs({"Defeat", "Distance", "Strength"}) do
            local okId, questId = pcall(QuestsDataHelper.GetFirstUnclaimedQuestId, data, questType)
            if okId and questId then
                local okTarget, target = pcall(QuestsDataHelper.GetTarget, questId)
                local progress = tonumber(data.QuestProgress and data.QuestProgress[questType]) or 0
                if okTarget and progress >= (tonumber(target) or math.huge) then
                    local fired = fireServiceRemote("QuestService", "ClaimQuestReward", questType)
                    if fired then
                        count = count + 1
                    end
                end
            end
        end
        for dayIndex = 1, 15 do
            local reward = data.LongDailyRewards and data.LongDailyRewards[dayIndex]
            if reward and reward.CompleteDate ~= nil and reward.IsClaimed ~= true then
                local fired = fireServiceRemote(
                    "LongDailyRewardService",
                    "ClaimLongDailyReward",
                    dayIndex
                )
                if fired then
                    count = count + 1
                end
            end
        end
        state.LastAction = count > 0 and string.format("Claimed %d task reward(s)", count)
            or "Tasks: progressing toward the next reward"
        return count
    end

    local function crateAccess()
        local data = getData()
        local crateId = state.SelectedCrate
        if not data or not CratesDataHelper or not CratesData[crateId] then
            return false, "Crate data unavailable"
        end
        local okRobux, isRobux = pcall(CratesDataHelper.IsRobuxCrate, crateId)
        local okPrice, price = pcall(CratesDataHelper.GetPrice, crateId)
        local okArea, locatedArea = pcall(CratesDataHelper.GetLocatedArea, crateId)
        if okRobux and isRobux then
            return false, string.format("Robux crate: %s R$ (manual prompt only)", compactNumber(price))
        end
        if okArea and locatedArea and locatedArea ~= "All"
            and data.Areas and data.Areas[locatedArea] == false then
            return false, "Locked area: " .. tostring(locatedArea)
        end
        local bones = tonumber(data.Diamonds) or 0
        price = okPrice and tonumber(price) or math.huge
        local reserve = state.FullProgression
            and math.max(state.GearBoneReserve, Equipment.nextShoeBoneReserve(data))
            or state.GearBoneReserve
        if bones < price + reserve then
            return false, string.format("Need %s bones plus %s reserve; have %s",
                compactNumber(price), compactNumber(reserve), compactNumber(bones))
        end
        return true, string.format("Ready: %s bones (%s reserved)",
            compactNumber(price), compactNumber(reserve))
    end

    local function buySelectedCrate(promptRobux)
        local crateId = state.SelectedCrate
        if CratesDataHelper then
            local okRobux, isRobux = pcall(CratesDataHelper.IsRobuxCrate, crateId)
            if okRobux and isRobux then
                return promptRobux and promptProduct(crateId) or false
            end
        end
        local allowed, reason = crateAccess()
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("ItemCrateService", "BuyCrateWithDiamonds", crateId, 1)
        state.LastAction = ok and ("Bought gear crate: " .. crateId)
            or ("Gear crate failed: " .. tostring(result))
        return ok
    end

    local function equipBestGear()
        local data = getData()
        if not data or not ItemsDataHelper then
            state.LastAction = "Gear data unavailable"
            return false
        end
        local best
        for _, stack in pairs(data.Items or {}) do
            if (tonumber(stack.Num) or 0) > 0 and (not best
                or (tonumber(stack.RarityIndex) or 0) > (tonumber(best.RarityIndex) or 0)) then
                best = stack
            end
        end
        if not best then
            state.LastAction = "No unequipped dog gear"
            return false
        end
        local okSlot, emptySlot = pcall(ItemsDataHelper.GetFirstEmptySlotIndex, data)
        if okSlot and emptySlot then
            local ok, result = fireServiceRemote(
                "ItemService",
                "EquipItem",
                best.ItemId,
                best.RarityIndex
            )
            state.LastAction = ok and string.format("Equipped %s rarity %s", best.ItemId, best.RarityIndex)
                or ("Gear equip failed: " .. tostring(result))
            return ok
        end
        local weakestSlot, weakest
        for slot, item in pairs(data.EquippedItems or {}) do
            if not weakest or (tonumber(item.RarityIndex) or 0) < (tonumber(weakest.RarityIndex) or 0) then
                weakestSlot, weakest = slot, item
            end
        end
        if weakest and (tonumber(best.RarityIndex) or 0) > (tonumber(weakest.RarityIndex) or 0) then
            local ok, result = fireServiceRemote("ItemService", "UnequipItem", tonumber(weakestSlot))
            state.LastAction = ok and "Unequipped weakest gear for an upgrade"
                or ("Gear unequip failed: " .. tostring(result))
            return ok
        end
        state.LastAction = "Best dog gear is already equipped"
        return false
    end

    local function mergeAvailableGear()
        local data = getData()
        local amount = tonumber(Constants and Constants.ITEMS_MERGE_AMOUNT) or 3
        if not data then
            return 0
        end
        local count = 0
        for _, stack in pairs(data.Items or {}) do
            local owned = tonumber(stack.Num) or 0
            if ItemsDataHelper and type(ItemsDataHelper.GetUnequippedNum) == "function" then
                local ok, value = pcall(
                    ItemsDataHelper.GetUnequippedNum,
                    data,
                    stack.ItemId,
                    stack.RarityIndex
                )
                if ok then
                    owned = tonumber(value) or owned
                end
            end
            if owned >= amount and (tonumber(stack.RarityIndex) or 0) < 6 then
                local ok = fireServiceRemote("ItemService", "MergeItems", stack.ItemId, stack.RarityIndex)
                if ok then
                    count = count + 1
                end
            end
        end
        state.LastAction = count > 0 and string.format("Merged %d gear stack(s)", count)
            or string.format("Gear merge: waiting for %d matching pieces", amount)
        return count
    end

    function Equipment.birdBoost(birdId)
        if not Equipment.BirdsDataHelper then
            return 0
        end
        local ok, value = pcall(Equipment.BirdsDataHelper.GetBoostValue, birdId)
        return ok and tonumber(value) or 0
    end

    function Equipment.birdAccess(birdId, requireOwned)
        local data = getData()
        local config = Equipment.BirdsData[birdId]
        if not data or not config or not Equipment.BirdsDataHelper then
            return false, "Bird data unavailable"
        end
        local locked = false
        if GameDataUtil and type(GameDataUtil.IsBirdSystemLocked) == "function" then
            local ok, value = pcall(GameDataUtil.IsBirdSystemLocked, data)
            locked = ok and value == true
        end
        if locked then
            return false, "Bird system is still locked"
        end
        local owned = data.Birds and data.Birds[birdId] ~= nil
        if requireOwned then
            return owned, owned and "Owned; ready to equip" or "Buy this bird first"
        end
        if owned then
            return false, "Bird already owned"
        end
        local currency = Equipment.BirdsDataHelper.GetUnlockCurrency(birdId)
        local price = tonumber(Equipment.BirdsDataHelper.GetUnlockCount(birdId)) or math.huge
        if currency == "Robux" then
            return false, string.format("Robux bird: %s R$ (prompt only)", compactNumber(price))
        end
        local balance = currencyAmount(data, currency)
        if balance < price then
            return false, string.format("Need %s %s; have %s", compactNumber(price),
                tostring(currency), compactNumber(balance))
        end
        return true, string.format("Ready: +%s%% top speed for %s %s",
            tostring(Equipment.birdBoost(birdId)), compactNumber(price), tostring(currency))
    end

    function Equipment.buySelectedBird()
        local allowed, reason = Equipment.birdAccess(state.SelectedBird, false)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("BirdService", "BuyBirdEvent", state.SelectedBird)
        state.LastAction = ok and ("Bought bird: " .. state.SelectedBird)
            or ("Bird purchase failed: " .. tostring(result))
        return ok
    end

    function Equipment.equipSelectedBird()
        local allowed, reason = Equipment.birdAccess(state.SelectedBird, true)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("BirdService", "EquipBirdEvent", state.SelectedBird)
        state.LastAction = ok and ("Equipped bird: " .. state.SelectedBird)
            or ("Bird equip failed: " .. tostring(result))
        return ok
    end

    function Equipment.bestBirdStep()
        local data = getData()
        if not data then
            return false
        end
        local bestOwnedId, bestOwnedBoost = nil, -math.huge
        for birdId in pairs(data.Birds or {}) do
            local boost = Equipment.birdBoost(birdId)
            if boost > bestOwnedBoost then
                bestOwnedId, bestOwnedBoost = birdId, boost
            end
        end
        local candidateId, candidateBoost = nil, bestOwnedBoost
        for birdId in pairs(Equipment.BirdsData) do
            local ready = Equipment.birdAccess(birdId, false)
            local boost = Equipment.birdBoost(birdId)
            if ready and boost > candidateBoost then
                candidateId, candidateBoost = birdId, boost
            end
        end
        if candidateId then
            state.SelectedBird = candidateId
            if Equipment.BirdDropdown then
                Equipment.BirdDropdown:Set(choiceForId(Equipment.BirdChoices, Equipment.BirdChoiceIds, candidateId), true)
            end
            return Equipment.buySelectedBird()
        end
        if bestOwnedId and not (data.Birds[bestOwnedId] and data.Birds[bestOwnedId].Equipped) then
            state.SelectedBird = bestOwnedId
            return Equipment.equipSelectedBird()
        end
        state.LastAction = "Birds: waiting for the next top-speed upgrade"
        return false
    end

    function Equipment.shoeAccBoost(shoeId)
        if not Equipment.ShoesDataHelper then
            return 0
        end
        local ok, value = pcall(Equipment.ShoesDataHelper.GetAccBoost, shoeId)
        return ok and tonumber(value) or 0
    end

    function Equipment.shoeAccess(shoeId, requireOwned)
        local data = getData()
        local config = Equipment.ShoesData[shoeId]
        if not data or not config or not Equipment.ShoesDataHelper then
            return false, "Shoe data unavailable"
        end
        local locked = false
        if GameDataUtil and type(GameDataUtil.IsShoeSystemLocked) == "function" then
            local ok, value = pcall(GameDataUtil.IsShoeSystemLocked, data)
            locked = ok and value == true
        end
        if locked then
            return false, "Shoe system is still locked"
        end
        local owned = data.Shoes and data.Shoes[shoeId] ~= nil
        if requireOwned then
            return owned, owned and "Owned; ready to equip" or "Buy these shoes first"
        end
        if owned then
            return false, "Shoes already owned"
        end
        local currency = Equipment.ShoesDataHelper.GetCurrency(shoeId)
        local price = tonumber(Equipment.ShoesDataHelper.GetUnlockCount(shoeId)) or math.huge
        if currency == "Robux" then
            return false, string.format("Robux shoes: %s R$ (prompt only)", compactNumber(price))
        end
        local balance = currencyAmount(data, currency)
        if balance < price then
            return false, string.format("Need %s bones; have %s", compactNumber(price), compactNumber(balance))
        end
        return true, string.format("Ready: +%s%% acceleration for %s bones",
            tostring(Equipment.shoeAccBoost(shoeId)), compactNumber(price))
    end

    function Equipment.buySelectedShoe()
        local allowed, reason = Equipment.shoeAccess(state.SelectedShoe, false)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("ShoeService", "BuyShoeEvent", state.SelectedShoe)
        state.LastAction = ok and ("Bought shoes: " .. state.SelectedShoe)
            or ("Shoe purchase failed: " .. tostring(result))
        return ok
    end

    function Equipment.equipSelectedShoe()
        local allowed, reason = Equipment.shoeAccess(state.SelectedShoe, true)
        if not allowed then
            state.LastAction = reason
            return false
        end
        local ok, result = fireServiceRemote("ShoeService", "EquipShoeEvent", state.SelectedShoe)
        state.LastAction = ok and ("Equipped shoes: " .. state.SelectedShoe)
            or ("Shoe equip failed: " .. tostring(result))
        return ok
    end

    function Equipment.bestShoeStep()
        local data = getData()
        if not data then
            return false
        end
        local bestOwnedId, bestOwnedBoost = nil, -math.huge
        for shoeId in pairs(data.Shoes or {}) do
            local boost = Equipment.shoeAccBoost(shoeId)
            if boost > bestOwnedBoost then
                bestOwnedId, bestOwnedBoost = shoeId, boost
            end
        end
        local candidateId, candidateBoost = nil, bestOwnedBoost
        for shoeId in pairs(Equipment.ShoesData) do
            local ready = Equipment.shoeAccess(shoeId, false)
            local boost = Equipment.shoeAccBoost(shoeId)
            if ready and boost > candidateBoost then
                candidateId, candidateBoost = shoeId, boost
            end
        end
        if candidateId then
            state.SelectedShoe = candidateId
            if Equipment.ShoeDropdown then
                Equipment.ShoeDropdown:Set(choiceForId(Equipment.ShoeChoices, Equipment.ShoeChoiceIds, candidateId), true)
            end
            return Equipment.buySelectedShoe()
        end
        if bestOwnedId and not (data.Shoes[bestOwnedId] and data.Shoes[bestOwnedId].Equipped) then
            state.SelectedShoe = bestOwnedId
            return Equipment.equipSelectedShoe()
        end
        state.LastAction = "Shoes: racing for bones toward the next upgrade"
        return false
    end

    local raceModeLabel = RaceUtilitySection:AddLabel("Race mode: scanning...")
    local treadmillLabel = TrainingStatusSection:AddLabel("Treadmill: scanning...")
    local strengthLabel = PlayerStatusSection:AddLabel("Power: --")
    local winsLabel = PlayerStatusSection:AddLabel("Wins: --")
    local bonesLabel = PlayerStatusSection:AddLabel("Bones: --")
    local rebirthLabel = PlayerStatusSection:AddLabel("Rebirths: --")
    local areaLabel = PlayerStatusSection:AddLabel("Area: --")
    local petsLabel = PlayerStatusSection:AddLabel("Pets: --")
    local speedLabel = MovementStatusSection:AddLabel("Speed: --")
    local eggAccessLabel = EggStatusSection:AddLabel("Egg: scanning...")
    local eggInventoryLabel = EggStatusSection:AddLabel("Pet storage: scanning...")
    EggStatusSection:AddLabel("Three-at-once uses the native Triple Hatch gamepass gate.")
    EggStatusSection:AddLabel("Robux eggs open an official purchase prompt only.")
    local fruitAccessLabel = FruitSection:AddLabel("Fruit: scanning...")
    local trailAccessLabel = TrailSection:AddLabel("Trail: scanning...")
    local upgradeAccessLabel = UpgradeSection:AddLabel("Upgrade: scanning...")
    local dogAccessLabel = DogSection:AddLabel("Dog: scanning...")
    local partnerAccessLabel = PartnerSection:AddLabel("Partner: scanning...")
    local crateAccessLabel = GearSection:AddLabel("Gear crate: scanning...")
    local gearInventoryLabel = GearSection:AddLabel("Dog gear: scanning...")
    Equipment.PotionStatusLabel = Equipment.PotionSection:AddLabel("Potions: scanning...")
    Equipment.PotionSection:AddLabel("Uses owned quantities only. It never opens a Robux purchase prompt.")
    Equipment.BirdAccessLabel = Equipment.BirdSection:AddLabel("Bird: scanning...")
    Equipment.ShoeAccessLabel = Equipment.ShoeSection:AddLabel("Shoes: scanning...")
    Equipment.ShoeSection:AddLabel("Bones come from native race rewards. The game calls them Diamonds internally.")
    local fullAutoLabel = FullAutoSection:AddLabel("Full progression: OFF")
    local hybridLabel = HybridSection:AddLabel("Hybrid: idle")
    local claimsLabel = ClaimAutoSection:AddLabel("Claims: scanning...")
    local actionLabel = AdapterStatusSection:AddLabel("Last action: Ready")
    local servicesLabel = AdapterStatusSection:AddLabel("Native controllers: scanning...")
    AdapterStatusSection:AddLabel("UniverseId: " .. tostring(game.GameId))
    AdapterStatusSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))

    local autoTrainControl
    local autoRaceControl
    local autoDashControl
    local autoHatchControl
    local speedInputControl
    local automationControls = {}

    local function setFullProgressionMembers(enabled)
        local controls = {
            automationControls.Hybrid,
            autoHatchControl,
            automationControls.Rebirth,
            automationControls.EquipBest,
            automationControls.CraftPets,
            automationControls.Potions,
            automationControls.DailyChest,
            automationControls.OnlineRewards,
            automationControls.FreeEgg,
            automationControls.Achievements,
            automationControls.Tasks,
            automationControls.Wheel,
            automationControls.Fruit,
            automationControls.Trail,
            automationControls.Upgrade,
            automationControls.Dog,
            automationControls.Partner,
            automationControls.GearCrate,
            automationControls.EquipGear,
            automationControls.MergeGear,
            automationControls.Bird,
            automationControls.Shoe,
        }
        for _, control in ipairs(controls) do
            if control and (type(control.Get) ~= "function" or control:Get() ~= enabled) then
                control:Set(enabled)
            end
        end
    end

    autoRaceControl = RaceSection:AddToggle({
        Name = "Auto Race",
        Description = "Uses the game's native AutoController pathfinding and contest flow.",
        Flag = "dograce_auto_race",
        Default = false,
        Callback = function(enabled)
            if enabled then
                if state.HybridMode and automationControls.Hybrid then
                    automationControls.Hybrid:Set(false)
                end
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
                if state.HybridMode and automationControls.Hybrid then
                    automationControls.Hybrid:Set(false)
                end
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

    automationControls.Rebirth = RebirthSection:AddToggle({
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

    automationControls.EquipBest = RewardsSection:AddToggle({
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
    automationControls.CraftPets = RewardsSection:AddToggle({
        Name = "Auto Craft Pets",
        Description = "Lets duplicates build, then proactively crafts them at the selected storage threshold or before the next hatch would exhaust safe headroom.",
        Flag = "dograce_auto_craft_pets",
        Default = false,
        Callback = function(enabled)
            state.AutoCraftPets = enabled == true
            if state.AutoCraftPets and Equipment.petCraftNeeded(getData(), state.HatchCount) then
                Equipment.craftAllPets(false)
            end
        end,
    })
    RewardsSection:AddSlider({
        Name = "Craft At Storage",
        Description = "Starts native Craft All at this inventory percentage instead of waiting until full.",
        Flag = "dograce_pet_craft_threshold",
        Min = 50,
        Max = 95,
        Step = 5,
        Default = 75,
        Suffix = "%",
        Callback = function(value)
            state.PetCraftThreshold = math.clamp(tonumber(value) or 75, 50, 95)
        end,
    })
    RewardsSection:AddButton({Name = "Craft All Duplicate Pets", Callback = function()
        Equipment.craftAllPets(true)
    end})
    automationControls.DailyChest = RewardsSection:AddToggle({
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

    automationControls.Hybrid = HybridSection:AddToggle({
        Name = "Auto Race + Treadmill Power",
        Description = "Trains between contests, races natively, then returns to the treadmill immediately. The server rejects power ticks during an active contest.",
        Flag = "dograce_hybrid_progress",
        Default = false,
        Callback = function(enabled)
            if enabled then
                if state.AutoRace and autoRaceControl then
                    autoRaceControl:Set(false)
                end
                if state.AutoTrain and autoTrainControl then
                    autoTrainControl:Set(false)
                end
                state.HybridMode = true
                state.HybridPhase = "Idle"
                state.HybridPhaseStarted = os.clock()
                updateHybrid(os.clock())
            else
                stopHybrid()
            end
        end,
    })
    HybridSection:AddSlider({
        Name = "Power Time Between Races",
        Flag = "dograce_hybrid_train_seconds",
        Min = 10,
        Max = 120,
        Step = 5,
        Default = 30,
        Suffix = "s",
        Callback = function(value)
            state.HybridTrainSeconds = math.clamp(tonumber(value) or 30, 10, 120)
        end,
    })
    HybridSection:AddButton({Name = "Stop Hybrid", Callback = function() automationControls.Hybrid:Set(false) end})

    automationControls.OnlineRewards = ClaimAutoSection:AddToggle({
        Name = "Auto Online Gifts",
        Description = "Claims every matured online gift and waits for the next timer.",
        Flag = "dograce_auto_online_rewards",
        Default = false,
        Callback = function(enabled) state.AutoOnlineRewards = enabled == true end,
    })
    automationControls.FreeEgg = ClaimAutoSection:AddToggle({
        Name = "Auto Free Egg",
        Description = "Claims the timed free pet egg (including the Ghost Egg pool) whenever its online timer finishes.",
        Flag = "dograce_auto_free_egg",
        Default = false,
        Callback = function(enabled) state.AutoFreeEgg = enabled == true end,
    })
    automationControls.Achievements = ClaimAutoSection:AddToggle({
        Name = "Auto Achievements",
        Flag = "dograce_auto_achievements",
        Default = false,
        Callback = function(enabled) state.AutoAchievements = enabled == true end,
    })
    automationControls.Tasks = ClaimAutoSection:AddToggle({
        Name = "Auto Tasks",
        Description = "Claims both progress quests and the native 15-day Tasks rewards as soon as each becomes claimable.",
        Flag = "dograce_auto_tasks",
        Default = false,
        Callback = function(enabled) state.AutoTasks = enabled == true end,
    })
    automationControls.Wheel = ClaimAutoSection:AddToggle({
        Name = "Auto Free Wheel",
        Description = "Uses only matured free spins. It never opens the Robux spin purchase.",
        Flag = "dograce_auto_wheel",
        Default = false,
        Callback = function(enabled)
            state.AutoWheel = enabled == true
            if state.AutoWheel then
                Equipment.spinFreeWheel()
            end
        end,
    })
    ClaimAutoSection:AddButton({Name = "Claim Online Gifts Now", Callback = claimAvailableOnlineRewards})
    ClaimAutoSection:AddButton({Name = "Claim Free Egg Now", Callback = claimFreeOnlineEgg})
    ClaimAutoSection:AddButton({Name = "Claim Achievements Now", Callback = claimAvailableAchievements})
    ClaimAutoSection:AddButton({Name = "Claim Task Rewards Now", Callback = claimAvailableTasks})
    ClaimAutoSection:AddButton({Name = "Use Free Wheel Spin Now", Callback = Equipment.spinFreeWheel})

    automationControls.SmartBestEgg = FullAutoSection:AddToggle({
        Name = "Best Affordable Egg",
        Description = "Targets the most expensive unlocked egg your current Wins can buy. Full Progression hatches once per training cycle instead of chain-spending.",
        Flag = "dograce_smart_best_egg",
        Default = true,
        Callback = function(enabled)
            state.SmartBestEgg = enabled == true
            if state.FullProgression and state.SmartBestEgg then
                retargetBestAffordableWinsEgg()
            else
                state.LastAction = state.SmartBestEgg
                    and "Best affordable egg selection armed"
                    or ("Manual egg target locked: " .. tostring(state.SelectedEgg))
            end
        end,
    })

    automationControls.Full = FullAutoSection:AddToggle({
        Name = "FULL PROGRESSION",
        Description = "One switch: power/race cycle, eggs, rewards, tasks, shops, unlocks, pets, gear, chest, and rebirth.",
        Flag = "dograce_full_progression",
        Default = false,
        Callback = function(enabled)
            state.FullProgression = enabled == true
            setFullProgressionMembers(enabled == true)
            if enabled and state.SmartBestEgg then
                retargetBestAffordableWinsEgg()
            end
            state.LastAction = enabled and "Full progression armed; locked systems will wait"
                or "Full progression stopped"
        end,
    })
    FullAutoSection:AddButton({Name = "STOP EVERYTHING", Callback = function()
        automationControls.Full:Set(false)
        if autoRaceControl then autoRaceControl:Set(false) end
        if autoTrainControl then autoTrainControl:Set(false) end
        if autoDashControl then autoDashControl:Set(false) end
    end})

    eggDropdownControl = EggHatchSection:AddDropdown({
        Name = "Egg",
        Description = "Every live native egg, including event and Robux eggs.",
        Flag = "dograce_selected_egg",
        Values = eggChoices,
        Default = choiceForId(eggChoices, eggChoiceIds, state.SelectedEgg),
        Callback = function(value)
            state.SelectedEgg = eggChoiceIds[value] or state.SelectedEgg
            if state.AutoHatch then
                state.LastHatch = 0
                state.LastAction = "Auto hatch retargeted to " .. state.SelectedEgg
            end
        end,
    })
    EggHatchSection:AddDropdown({
        Name = "Auto Hatch Amount",
        Flag = "dograce_hatch_amount",
        Values = {"One", "Three"},
        Default = "One",
        Callback = function(value)
            state.HatchCount = value == "Three" and 3 or 1
            if state.AutoHatch then
                state.LastHatch = 0
                state.LastAction = string.format("Auto hatch amount changed to %sx", state.HatchCount)
            end
        end,
    })
    EggHatchSection:AddButton({
        Name = "Hatch One",
        Callback = function()
            if not hatchSelected(1, true) then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    EggHatchSection:AddButton({
        Name = "Hatch Three / Prompt Pass",
        Callback = function()
            if not hatchSelected(3, true) then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    autoHatchControl = EggHatchSection:AddToggle({
        Name = "Auto Hatch",
        Description = "Stays enabled while short on currency and resumes automatically when the next hatch is affordable.",
        Flag = "dograce_auto_hatch",
        Default = false,
        Callback = function(enabled)
            state.AutoHatch = enabled == true
            if state.AutoHatch then
                local allowed, reason = eggAccess(state.HatchCount)
                state.LastHatch = 0
                state.LastAction = allowed and "Auto hatch armed"
                    or ("Auto hatch waiting: " .. reason)
            else
                state.LastAction = "Auto hatch stopped"
            end
        end,
    })
    EggHatchSection:AddButton({Name = "Stop Auto Hatch", Callback = function() autoHatchControl:Set(false) end})

    FruitSection:AddDropdown({
        Name = "Fruit",
        Description = "Buying immediately feeds the equipped dog, exactly like the native shop.",
        Flag = "dograce_selected_fruit",
        Values = fruitChoices,
        Default = choiceForId(fruitChoices, fruitChoiceIds, state.SelectedFruit),
        Callback = function(value)
            state.SelectedFruit = fruitChoiceIds[value] or state.SelectedFruit
        end,
    })
    FruitSection:AddButton({
        Name = "Buy & Feed Selected Fruit",
        Callback = function()
            if not buySelectedFruit() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    automationControls.Fruit = FruitSection:AddToggle({
        Name = "Auto Buy Selected Fruit",
        Description = "Waits for wins/rebirths and never auto-prompts Robux.",
        Flag = "dograce_auto_fruit",
        Default = false,
        Callback = function(enabled) state.AutoFruit = enabled == true end,
    })

    TrailSection:AddDropdown({
        Name = "Trail",
        Description = "Shows exact acceleration, price, currency, and rebirth gate.",
        Flag = "dograce_selected_trail",
        Values = trailChoices,
        Default = choiceForId(trailChoices, trailChoiceIds, state.SelectedTrail),
        Callback = function(value)
            state.SelectedTrail = trailChoiceIds[value] or state.SelectedTrail
        end,
    })
    TrailSection:AddButton({
        Name = "Buy Selected Trail",
        Callback = function()
            if not buySelectedTrail() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    TrailSection:AddButton({
        Name = "Equip Selected Trail",
        Callback = function()
            if not equipSelectedTrail() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    TrailSection:AddButton({Name = "Unequip Selected Trail", Callback = unequipSelectedTrail})
    automationControls.Trail = TrailSection:AddToggle({
        Name = "Auto Buy / Equip Trail",
        Description = "Waits at the native gate, then buys and equips the selected trail.",
        Flag = "dograce_auto_trail",
        Default = false,
        Callback = function(enabled) state.AutoTrail = enabled == true end,
    })

    UpgradeSection:AddDropdown({
        Name = "Upgrade",
        Description = "The native upgrade shop spends bones (Diamonds in replicated data).",
        Flag = "dograce_selected_upgrade",
        Values = upgradeChoices,
        Default = choiceForId(upgradeChoices, upgradeChoiceIds, state.SelectedUpgrade),
        Callback = function(value)
            state.SelectedUpgrade = upgradeChoiceIds[value] or state.SelectedUpgrade
        end,
    })
    UpgradeSection:AddButton({
        Name = "Buy Selected Bone Upgrade",
        Callback = function()
            if not buySelectedUpgrade() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    automationControls.Upgrade = UpgradeSection:AddToggle({
        Name = "Auto Selected Bone Upgrade",
        Flag = "dograce_auto_upgrade",
        Default = false,
        Callback = function(enabled) state.AutoUpgrade = enabled == true end,
    })

    GearSection:AddDropdown({
        Name = "Gear Crate",
        Description = "Bone crates can auto-buy. Robux crates only open an official prompt from the manual button.",
        Flag = "dograce_selected_crate",
        Values = crateChoices,
        Default = choiceForId(crateChoices, crateChoiceIds, state.SelectedCrate),
        Callback = function(value)
            state.SelectedCrate = crateChoiceIds[value] or state.SelectedCrate
        end,
    })
    GearSection:AddSlider({
        Name = "Bone Reserve",
        Flag = "dograce_gear_bone_reserve",
        Min = 0,
        Max = 100,
        Step = 1,
        Default = 5,
        Callback = function(value)
            state.GearBoneReserve = math.max(0, tonumber(value) or 5)
        end,
    })
    GearSection:AddButton({Name = "Buy One Gear Crate", Callback = function()
        if not buySelectedCrate(true) then notify(state.LastAction, COLORS.warning) end
    end})
    GearSection:AddButton({Name = "Equip Best Dog Gear", Callback = equipBestGear})
    GearSection:AddButton({Name = "Merge Available Gear", Callback = mergeAvailableGear})
    automationControls.GearCrate = GearSection:AddToggle({
        Name = "Auto Buy Selected Crate",
        Flag = "dograce_auto_gear_crate",
        Default = false,
        Callback = function(enabled) state.AutoGearCrate = enabled == true end,
    })
    automationControls.EquipGear = GearSection:AddToggle({
        Name = "Auto Equip Best Gear",
        Flag = "dograce_auto_equip_gear",
        Default = false,
        Callback = function(enabled) state.AutoEquipGear = enabled == true end,
    })
    automationControls.MergeGear = GearSection:AddToggle({
        Name = "Auto Merge Gear",
        Description = "Merges each three-piece matching unequipped stack into the next rarity, then checks again every three seconds.",
        Flag = "dograce_auto_merge_gear",
        Default = false,
        Callback = function(enabled) state.AutoMergeGear = enabled == true end,
    })

    Equipment.PotionSection:AddButton({Name = "Use All Owned Potions", Callback = Equipment.useAllPotions})
    automationControls.Potions = Equipment.PotionSection:AddToggle({
        Name = "Auto Use All Owned Potions",
        Description = "Consumes every owned potion quantity through the native Use button. Never buys Robux potions.",
        Flag = "dograce_auto_potions",
        Default = false,
        Callback = function(enabled)
            state.AutoPotions = enabled == true
            if state.AutoPotions then
                Equipment.useAllPotions()
            else
                state.PotionRunId = state.PotionRunId + 1
                state.PotionUsing = false
            end
        end,
    })

    DogSection:AddDropdown({
        Name = "Dog",
        Description = "Wins, Jurassic-token, area, and Robux gates stay server-authoritative.",
        Flag = "dograce_selected_dog",
        Values = dogChoices,
        Default = choiceForId(dogChoices, dogChoiceIds, state.SelectedDog),
        Callback = function(value)
            state.SelectedDog = dogChoiceIds[value] or state.SelectedDog
        end,
    })
    DogSection:AddButton({
        Name = "Unlock Selected Dog",
        Callback = function()
            if not unlockSelectedDog() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    DogSection:AddButton({
        Name = "Equip Selected Dog",
        Callback = function()
            if not equipSelectedDog() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    automationControls.Dog = DogSection:AddToggle({
        Name = "Auto Unlock / Equip Dog",
        Flag = "dograce_auto_dog",
        Default = false,
        Callback = function(enabled) state.AutoDog = enabled == true end,
    })

    PartnerSection:AddDropdown({
        Name = "Partner",
        Description = "Unlock, equip, or unequip through PrincessService's native partner contract.",
        Flag = "dograce_selected_partner",
        Values = partnerChoices,
        Default = choiceForId(partnerChoices, partnerChoiceIds, state.SelectedPartner),
        Callback = function(value)
            state.SelectedPartner = partnerChoiceIds[value] or state.SelectedPartner
        end,
    })
    PartnerSection:AddButton({
        Name = "Unlock Selected Partner",
        Callback = function()
            if not unlockSelectedPartner() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    PartnerSection:AddButton({
        Name = "Equip Selected Partner",
        Callback = function()
            if not equipSelectedPartner() then
                notify(state.LastAction, COLORS.warning)
            end
        end,
    })
    PartnerSection:AddButton({Name = "Unequip Selected Partner", Callback = unequipSelectedPartner})
    automationControls.Partner = PartnerSection:AddToggle({
        Name = "Auto Unlock / Equip Partner",
        Flag = "dograce_auto_partner",
        Default = false,
        Callback = function(enabled) state.AutoPartner = enabled == true end,
    })

    Equipment.BirdDropdown = Equipment.BirdSection:AddDropdown({
        Name = "Bird",
        Description = "Birds use Wins for permanent top-speed boosts. Robux birds remain prompt-only.",
        Flag = "dograce_selected_bird",
        Values = Equipment.BirdChoices,
        Default = choiceForId(Equipment.BirdChoices, Equipment.BirdChoiceIds, state.SelectedBird),
        Callback = function(value)
            state.SelectedBird = Equipment.BirdChoiceIds[value] or state.SelectedBird
        end,
    })
    Equipment.BirdSection:AddButton({Name = "Buy Selected Bird", Callback = function()
        if not Equipment.buySelectedBird() then notify(state.LastAction, COLORS.warning) end
    end})
    Equipment.BirdSection:AddButton({Name = "Equip Selected Bird", Callback = function()
        if not Equipment.equipSelectedBird() then notify(state.LastAction, COLORS.warning) end
    end})
    automationControls.Bird = Equipment.BirdSection:AddToggle({
        Name = "Auto Best Bird",
        Description = "Buys the strongest affordable Wins bird and equips the strongest bird you own.",
        Flag = "dograce_auto_bird",
        Default = false,
        Callback = function(enabled) state.AutoBird = enabled == true end,
    })

    Equipment.ShoeDropdown = Equipment.ShoeSection:AddDropdown({
        Name = "Shoes",
        Description = "Normal shoes use bones. Robux shoes remain prompt-only.",
        Flag = "dograce_selected_shoe",
        Values = Equipment.ShoeChoices,
        Default = choiceForId(Equipment.ShoeChoices, Equipment.ShoeChoiceIds, state.SelectedShoe),
        Callback = function(value)
            state.SelectedShoe = Equipment.ShoeChoiceIds[value] or state.SelectedShoe
        end,
    })
    Equipment.ShoeSection:AddButton({Name = "Buy Selected Shoes", Callback = function()
        if not Equipment.buySelectedShoe() then notify(state.LastAction, COLORS.warning) end
    end})
    Equipment.ShoeSection:AddButton({Name = "Equip Selected Shoes", Callback = function()
        if not Equipment.equipSelectedShoe() then notify(state.LastAction, COLORS.warning) end
    end})
    automationControls.Shoe = Equipment.ShoeSection:AddToggle({
        Name = "Auto Best Shoes",
        Description = "Waits for race-earned bones, then buys and equips the strongest affordable acceleration shoes.",
        Flag = "dograce_auto_shoe",
        Default = false,
        Callback = function(enabled) state.AutoShoe = enabled == true end,
    })

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
        bonesLabel.Text = "Bones: " .. tostring(data and data.Diamonds or "--")
        rebirthLabel.Text = string.format(
            "Rebirths: %s | Next: %s",
            tostring(data and data.Rebirths or "--"),
            tostring(cost or "--")
        )
        areaLabel.Text = "Area: " .. tostring(area or "--")
        petsLabel.Text = string.format("Pets: %d / %s | Equipped: %d | Craft %s @ %d%%",
            petCount, compactNumber(maxPetStorage(data or {})), equippedPets,
            state.AutoCraftPets and "AUTO" or "OFF", state.PetCraftThreshold)
        local function accessText(ready, reason)
            local owned = string.find(reason, "already owned", 1, true)
                or string.find(reason, "Owned;", 1, true)
            return string.format("%s: %s", ready and "READY" or owned and "OWNED" or "LOCKED", reason)
        end
        local eggReady, eggReason = eggAccess(state.HatchCount)
        eggAccessLabel.Text = state.AutoHatch and not eggReady
            and ("WAITING: " .. eggReason)
            or accessText(eggReady, eggReason)
        eggInventoryLabel.Text = string.format("Pet storage: %s / %s", compactNumber(storedPetCount(data or {})),
            compactNumber(maxPetStorage(data or {})))
        local fruitReady, fruitReason = fruitAccess()
        fruitAccessLabel.Text = accessText(fruitReady, fruitReason)
        local trailReady, trailReason = trailAccess(false)
        trailAccessLabel.Text = accessText(trailReady, trailReason)
        local upgradeReady, upgradeReason = upgradeAccess()
        upgradeAccessLabel.Text = accessText(upgradeReady, upgradeReason)
        local dogReady, dogReason = dogAccess(false)
        dogAccessLabel.Text = accessText(dogReady, dogReason)
        local partnerReady, partnerReason = partnerAccess(false)
        partnerAccessLabel.Text = accessText(partnerReady, partnerReason)
        local crateReady, crateReason = crateAccess()
        crateAccessLabel.Text = accessText(crateReady, crateReason)
        local birdReady, birdReason = Equipment.birdAccess(state.SelectedBird, false)
        if data and data.Birds and data.Birds[state.SelectedBird] then
            birdReady, birdReason = Equipment.birdAccess(state.SelectedBird, true)
        end
        Equipment.BirdAccessLabel.Text = accessText(birdReady, birdReason)
        local shoeReady, shoeReason = Equipment.shoeAccess(state.SelectedShoe, false)
        if data and data.Shoes and data.Shoes[state.SelectedShoe] then
            shoeReady, shoeReason = Equipment.shoeAccess(state.SelectedShoe, true)
        end
        Equipment.ShoeAccessLabel.Text = accessText(shoeReady, shoeReason)
        local equippedGear, storedGear = 0, 0
        if data and ItemsDataHelper then
            local okEquipped, equipped = pcall(ItemsDataHelper.GetEquippedItemsNum, data)
            local okStored, stored = pcall(ItemsDataHelper.GetUnequippedItemsNum, data)
            equippedGear = okEquipped and tonumber(equipped) or 0
            storedGear = okStored and tonumber(stored) or 0
        end
        gearInventoryLabel.Text = string.format("Dog gear: %d equipped | %d stored", equippedGear, storedGear)
        Equipment.updatePotionStatus(data)
        fullAutoLabel.Text = state.FullProgression
            and string.format("Full progression: ON — egg target %s",
                state.SmartBestEgg and "BEST AFFORDABLE" or "MANUAL")
            or "Full progression: OFF"
        hybridLabel.Text = string.format("Hybrid: %s | %ss power window",
            state.HybridPhase, tostring(state.HybridTrainSeconds))
        local freeEggReady = data and data.OnlineQuestTaskDown == true
        claimsLabel.Text = string.format("Free egg: %s | Gifts %s | Tasks %s | Achievements %s",
            freeEggReady and "READY" or "WAITING",
            state.AutoOnlineRewards and "AUTO" or "OFF",
            state.AutoTasks and "AUTO" or "OFF",
            state.AutoAchievements and "AUTO" or "OFF")
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
            EggHatchGuiController,
            OnlineRewardGuiController,
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
            gui:SetAttribute("DogRaceAutoHatch", state.AutoHatch)
            gui:SetAttribute("DogRaceAutoHatchWaiting", state.AutoHatch and not eggReady)
            gui:SetAttribute("DogRaceSelectedEgg", state.SelectedEgg)
            gui:SetAttribute("DogRaceSelectedFruit", state.SelectedFruit)
            gui:SetAttribute("DogRaceSelectedTrail", state.SelectedTrail)
            gui:SetAttribute("DogRaceSelectedDog", state.SelectedDog)
            gui:SetAttribute("DogRaceSelectedPartner", state.SelectedPartner)
            gui:SetAttribute("DogRaceSelectedCrate", state.SelectedCrate)
            gui:SetAttribute("DogRaceSelectedBird", state.SelectedBird)
            gui:SetAttribute("DogRaceSelectedShoe", state.SelectedShoe)
            gui:SetAttribute("DogRaceSpeedMultiplier", state.SpeedMultiplier)
            gui:SetAttribute("DogRaceFullProgression", state.FullProgression)
            gui:SetAttribute("DogRaceSmartBestEgg", state.SmartBestEgg)
            gui:SetAttribute("DogRaceHybridMode", state.HybridMode)
            gui:SetAttribute("DogRaceHybridPhase", state.HybridPhase)
            gui:SetAttribute("DogRaceAutoOnlineRewards", state.AutoOnlineRewards)
            gui:SetAttribute("DogRaceAutoFreeEgg", state.AutoFreeEgg)
            gui:SetAttribute("DogRaceFreeEggReady", freeEggReady == true)
            gui:SetAttribute("DogRaceAutoAchievements", state.AutoAchievements)
            gui:SetAttribute("DogRaceAutoTasks", state.AutoTasks)
            gui:SetAttribute("DogRaceAutoWheel", state.AutoWheel)
            gui:SetAttribute("DogRaceSilentHatch", true)
            gui:SetAttribute("DogRaceAutoCraftPets", state.AutoCraftPets)
            gui:SetAttribute("DogRaceAutoPotions", state.AutoPotions)
            gui:SetAttribute("DogRacePetCount", petCount)
            gui:SetAttribute("DogRacePetStorageMax", maxPetStorage(data or {}))
            gui:SetAttribute("DogRacePetCraftThreshold", state.PetCraftThreshold)
            gui:SetAttribute("DogRacePetCraftNeeded", Equipment.petCraftNeeded(data, state.HatchCount))
            gui:SetAttribute("DogRaceAutoGearCrate", state.AutoGearCrate)
            gui:SetAttribute("DogRaceAutoMergeGear", state.AutoMergeGear)
            gui:SetAttribute("DogRaceAutoEquipGear", state.AutoEquipGear)
            gui:SetAttribute("DogRaceAutoBird", state.AutoBird)
            gui:SetAttribute("DogRaceAutoShoe", state.AutoShoe)
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
        state.AutoCraftPets = false
        state.AutoPotions = false
        state.PotionRunId = state.PotionRunId + 1
        state.PotionUsing = false
        state.AutoDailyChest = false
        state.AutoHatch = false
        state.FullProgression = false
        state.AutoOnlineRewards = false
        state.AutoFreeEgg = false
        state.AutoAchievements = false
        state.AutoTasks = false
        state.AutoFruit = false
        state.AutoTrail = false
        state.AutoUpgrade = false
        state.AutoDog = false
        state.AutoPartner = false
        state.AutoGearCrate = false
        state.AutoEquipGear = false
        state.AutoMergeGear = false
        state.AutoBird = false
        state.AutoShoe = false
        state.AutoWheel = false
        state.WheelSpinning = false
        if Equipment.OriginalShowHatchResult and EggHatchGuiController then
            EggHatchGuiController.ShowHatchResult = Equipment.OriginalShowHatchResult
        end
        if state.HybridMode then
            stopHybrid()
        end
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

    Equipment.StatusAccumulator = 0
    Equipment.AutomationAccumulator = 0
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then
            return
        end
        updateSpeedOverride()
        Equipment.StatusAccumulator = Equipment.StatusAccumulator + deltaTime
        Equipment.AutomationAccumulator = Equipment.AutomationAccumulator + deltaTime
        local now = os.clock()

        if state.AutoDash and now - state.LastDash >= state.DashInterval then
            state.LastDash = now
            dashNow()
        end
        if Equipment.StatusAccumulator >= 0.25 then
            Equipment.StatusAccumulator = 0
            updateStatus()
        end
        if Equipment.AutomationAccumulator >= 0.5 then
            Equipment.AutomationAccumulator = 0
            local data = getData()
            if state.FullProgression then
                -- Profiles and individual toggles can be applied in any order. The master
                -- switch owns its children and repairs any drift instead of silently lying.
                setFullProgressionMembers(true)
                if state.SmartBestEgg then
                    retargetBestAffordableWinsEgg()
                end
            end
            updateHybrid(now)
            if state.AutoHatch then
                local fast = data and data.GamePasses and data.GamePasses.FastHatch
                local delay = fast and 1 or 5
                local cycleReady = not (state.FullProgression and state.HybridMode)
                    or (state.HybridPhase == "Training"
                        and state.LastHybridHatchPhase ~= state.HybridPhaseStarted)
                if cycleReady and now - state.LastHatch >= delay then
                    state.LastHatch = now
                    if hatchSelected(state.HatchCount, false) then
                        if state.FullProgression and state.HybridMode then
                            state.LastHybridHatchPhase = state.HybridPhaseStarted
                        end
                    else
                        state.LastAction = "Auto hatch waiting: " .. state.LastAction
                    end
                end
            end
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
            if state.AutoCraftPets and now - state.LastPetCraft >= 5 then
                state.LastPetCraft = now
                if Equipment.petCraftNeeded(data, state.HatchCount)
                    and Equipment.hasCraftablePets(data) then
                    Equipment.craftAllPets(false)
                end
            end
            if state.AutoPotions and not state.PotionUsing
                and now - state.LastPotionSweep >= 5 then
                state.LastPotionSweep = now
                Equipment.useAllPotions()
            end
            if state.AutoEquipBest and now - state.LastEquipBest >= 3 then
                state.LastEquipBest = now
                equipBestPets()
            end
            if state.AutoDailyChest and now - state.LastDailyChest >= 5
                and dailyChestReady(data) then
                state.LastDailyChest = now
                claimDailyChest()
            end
            if now - state.LastClaimSweep >= 2 then
                state.LastClaimSweep = now
                if state.AutoOnlineRewards then
                    claimAvailableOnlineRewards()
                end
                if state.AutoFreeEgg then
                    claimFreeOnlineEgg()
                end
                if state.AutoAchievements then
                    claimAvailableAchievements()
                end
                if state.AutoTasks then
                    claimAvailableTasks()
                end
                if state.AutoWheel then
                    Equipment.spinFreeWheel()
                end
            end
            if now - state.LastShopSweep >= 2 then
                state.LastShopSweep = now
                if state.AutoFruit then
                    if state.FullProgression then
                        if not state.HybridMode or (state.HybridPhase == "Training"
                            and state.LastHybridFruitPhase ~= state.HybridPhaseStarted) then
                            if Equipment.bestFruitStep() and state.HybridMode then
                                state.LastHybridFruitPhase = state.HybridPhaseStarted
                            end
                        end
                    else
                        local config = FruitsData[state.SelectedFruit]
                        if config and config.Currency ~= "Robux" then
                            buySelectedFruit()
                        end
                    end
                end
                if state.AutoTrail then
                    local config = TrailsData[state.SelectedTrail]
                    if config and config.Currency ~= "Robux" then
                        local owned = data and data.Trails and data.Trails[state.SelectedTrail]
                        if owned then
                            local equipped = data.EquippedTrail == state.SelectedTrail
                                or (type(owned) == "table" and owned.Equipped == true)
                            if not equipped then
                                equipSelectedTrail()
                            end
                        else
                            buySelectedTrail()
                        end
                    end
                end
                if state.AutoUpgrade then
                    if state.FullProgression then
                        Equipment.bestUpgradeStep()
                    else
                        buySelectedUpgrade()
                    end
                end
                if state.AutoDog then
                    if state.FullProgression then
                        Equipment.bestDogStep()
                    else
                        local horse = data and data.Horses and data.Horses[state.SelectedDog]
                        if horse then
                            if horse.Equipped ~= true then
                                equipSelectedDog()
                            end
                        else
                            local config = HorsesData[state.SelectedDog]
                            if config and config.UnlockCurrency ~= "Robux" then
                                unlockSelectedDog()
                            end
                        end
                    end
                end
                if state.AutoPartner then
                    if state.FullProgression then
                        Equipment.bestPartnerStep()
                    else
                        local partner = data and data.Princesses and data.Princesses[state.SelectedPartner]
                        if partner then
                            if partner.Equipped ~= true then
                                equipSelectedPartner()
                            end
                        else
                            local config = PrincessesData[state.SelectedPartner]
                            if config and config.UnlockType ~= "Robux" then
                                unlockSelectedPartner()
                            end
                        end
                    end
                end
                if state.AutoBird then
                    Equipment.bestBirdStep()
                end
                if state.AutoShoe then
                    Equipment.bestShoeStep()
                end
            end
            if now - state.LastGearSweep >= 3 then
                state.LastGearSweep = now
                if state.AutoGearCrate then
                    buySelectedCrate(false)
                end
                if state.AutoMergeGear then
                    mergeAvailableGear()
                end
                if state.AutoEquipGear then
                    equipBestGear()
                end
            end
        end
    end))

    updateStatus()
    selectHomeCategory("🏁 Race")
    notify("Dog Race module ready", COLORS.success)
end
