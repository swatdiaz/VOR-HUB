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
    local GameDataUtil
    local EggsData = {}
    local FruitsData = {}
    local TrailsData = {}
    local HorsesData = {}
    local PrincessesData = {}
    local UpgradesData = {}
    pcall(function()
        Knit = require(ReplicatedStorage.Packages.Knit)
        Constants = require(ReplicatedStorage.Modules.Constants)
        GameDataUtil = require(ReplicatedStorage.Modules.GameDataUtil)
        TreadmillsDataHelper = require(ReplicatedFirst.DataHelper.TreadmillsDataHelper)
        RebirthDataHelper = require(ReplicatedFirst.DataHelper.RebirthDataHelper)
        PetsDataHelper = require(ReplicatedFirst.DataHelper.PetsDataHelper)
        PurchaseDataHelper = require(ReplicatedFirst.DataHelper.PurchaseDataHelper)
        UpgradesDataHelper = require(ReplicatedFirst.DataHelper.UpgradesDataHelper)
        EggsData = require(ReplicatedFirst.Data.EggsData)
        FruitsData = require(ReplicatedFirst.Data.FruitsData)
        TrailsData = require(ReplicatedFirst.Data.TrailsData)
        HorsesData = require(ReplicatedFirst.Data.HorsesData)
        PrincessesData = require(ReplicatedFirst.Data.PrincessesData)
        UpgradesData = require(ReplicatedFirst.Data.UpgradesData)
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

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local RacePage = addHomeCategory("Race", 1, CATEGORY_DECALS.Combat or CATEGORY_DECALS.Movement)
    local TrainingPage = addHomeCategory("Training", 2, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local ProgressionPage = addHomeCategory("Progression", 3, CATEGORY_DECALS.Progress)
    local EggsPage = addHomeCategory("Eggs", 4, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local ShopsPage = addHomeCategory("Shops", 5, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Player)
    local UnlocksPage = addHomeCategory("Unlocks", 6, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)
    local MovementPage = addHomeCategory("Movement", 7, CATEGORY_DECALS.Movement or CATEGORY_DECALS.Player)
    local StatusPage = addHomeCategory("Status", 8, CATEGORY_DECALS.Player or CATEGORY_DECALS.Progress)

    local RaceSection = RacePage:AddSection("Native Race", "Left")
    local RaceUtilitySection = RacePage:AddSection("Race Utility", "Right")
    local TrainingSection = TrainingPage:AddSection("Native Training", "Left")
    local TrainingStatusSection = TrainingPage:AddSection("Training Status", "Right")
    local RebirthSection = ProgressionPage:AddSection("Rebirth", "Left")
    local RewardsSection = ProgressionPage:AddSection("Pets & Rewards", "Right")
    local EggHatchSection = EggsPage:AddSection("Native Egg Hatch", "Left")
    local EggStatusSection = EggsPage:AddSection("Egg Access", "Right")
    local FruitSection = ShopsPage:AddSection("Fruit Shop", "Left")
    local TrailSection = ShopsPage:AddSection("Trail Shop", "Right")
    local UpgradeSection = ShopsPage:AddSection("Bone Upgrades", "Left")
    local DogSection = UnlocksPage:AddSection("Dogs", "Left")
    local PartnerSection = UnlocksPage:AddSection("Partners", "Right")
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
        AutoHatch = false,
        HatchCount = 1,
        SelectedEgg = "Egg_1_1",
        SelectedFruit = "Fruit_1",
        SelectedTrail = "White",
        SelectedUpgrade = "Upgrade_Wins",
        SelectedDog = "Dog_101",
        SelectedPartner = "Partner_1",
        LastHatch = 0,
        LastFruit = 0,
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
        if bones < price then
            return false, string.format("Need %s bones; have %s | level %d/%d",
                compactNumber(price), compactNumber(bones), level, maxLevel)
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
    local actionLabel = AdapterStatusSection:AddLabel("Last action: Ready")
    local servicesLabel = AdapterStatusSection:AddLabel("Native controllers: scanning...")
    AdapterStatusSection:AddLabel("UniverseId: " .. tostring(game.GameId))
    AdapterStatusSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))

    local autoTrainControl
    local autoRaceControl
    local autoDashControl
    local autoHatchControl
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

    EggHatchSection:AddDropdown({
        Name = "Egg",
        Description = "Every live native egg, including event and Robux eggs.",
        Flag = "dograce_selected_egg",
        Values = eggChoices,
        Default = choiceForId(eggChoices, eggChoiceIds, state.SelectedEgg),
        Callback = function(value)
            state.SelectedEgg = eggChoiceIds[value] or state.SelectedEgg
            if state.AutoHatch and autoHatchControl then
                autoHatchControl:Set(false)
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
            if state.AutoHatch and autoHatchControl then
                autoHatchControl:Set(false)
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
        Description = "Repeats the selected native hatch amount at the game's normal hatch delay.",
        Flag = "dograce_auto_hatch",
        Default = false,
        Callback = function(enabled)
            state.AutoHatch = enabled == true
            if state.AutoHatch then
                local allowed, reason = eggAccess(state.HatchCount)
                if not allowed then
                    state.AutoHatch = false
                    state.LastAction = reason
                    task.defer(function()
                        if autoHatchControl then
                            autoHatchControl:Set(false, true)
                        end
                    end)
                    notify(reason, COLORS.warning)
                else
                    state.LastHatch = 0
                end
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
        petsLabel.Text = string.format("Pets: %d | Equipped: %d", petCount, equippedPets)
        local function accessText(ready, reason)
            local owned = string.find(reason, "already owned", 1, true)
                or string.find(reason, "Owned;", 1, true)
            return string.format("%s: %s", ready and "READY" or owned and "OWNED" or "LOCKED", reason)
        end
        local eggReady, eggReason = eggAccess(state.HatchCount)
        eggAccessLabel.Text = accessText(eggReady, eggReason)
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
            gui:SetAttribute("DogRaceSelectedEgg", state.SelectedEgg)
            gui:SetAttribute("DogRaceSelectedFruit", state.SelectedFruit)
            gui:SetAttribute("DogRaceSelectedTrail", state.SelectedTrail)
            gui:SetAttribute("DogRaceSelectedDog", state.SelectedDog)
            gui:SetAttribute("DogRaceSelectedPartner", state.SelectedPartner)
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
        state.AutoHatch = false
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
            if state.AutoHatch then
                local fast = data and data.GamePasses and data.GamePasses.FastHatch
                local delay = fast and 1 or 5
                if now - state.LastHatch >= delay then
                    state.LastHatch = now
                    if not hatchSelected(state.HatchCount, false) then
                        state.AutoHatch = false
                        if autoHatchControl then
                            autoHatchControl:Set(false, true)
                        end
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
