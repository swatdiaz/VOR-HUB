-- VOR Hub - Capybaras VS Plants adapter
-- UniverseId 8841437826 | PlaceId 104973076655377 | audited against build 6542

return function(context)
    local Window = assert(context.Window, "Capybaras VS Plants: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Capybaras VS Plants: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local environment = type(getgenv) == "function" and getgenv() or _G
    local previousCleanup = environment.__VORCapybarasVsPlantsCleanup
    environment.__VORCapybarasVsPlantsCleanup = nil
    if type(previousCleanup) == "function" then
        pcall(previousCleanup)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local Modules = ReplicatedStorage:WaitForChild("Modules")
    local ShopData = require(Modules:WaitForChild("ShopData"))
    local EggData = require(Modules:WaitForChild("EggData"))
    local GearData = require(Modules:WaitForChild("GearData"))
    local BossData = require(Modules:WaitForChild("BossData"))
    local PlantData = require(Modules:WaitForChild("PlantData"))
    local PurchasablePrices = require(Modules:WaitForChild("PurchasablePrices"))
    local GameInfo = require(Modules:WaitForChild("GameInfo"))
    local QuestData = require(Modules:WaitForChild("QuestData"))
    local ItemNameParser = require(Modules:WaitForChild("ItemNameParser"))
    local GetItemValue = require(Modules:WaitForChild("GetItemValue"))

    local eggOrder = table.clone(ShopData.ShopOrders.EggShop)
    local gearOrder = table.clone(ShopData.ShopOrders.GearShop)
    local bossOrder = table.clone(BossData.BossList)
    local bossNames = {}
    for _, name in ipairs(bossOrder) do
        bossNames[name] = true
    end

    local state = {
        Alive = true,
        SelectedEggs = {[eggOrder[1]] = true},
        SelectedGears = {[gearOrder[1]] = true},
        SelectedBoss = bossOrder[1],
        AutoBuyEgg = false,
        AutoBuyGear = false,
        AutoSummonBoss = false,
        AutoFarm = false,
        FarmRange = 150,
        FarmMinimumRarity = "Common",
        FarmMinimumSize = 0,
        FarmMaximumSize = 10,
        FarmFocusTime = 3,
        FarmStrafeRadius = 5,
        FarmStrafeSpeed = 4,
        FarmHoverHeight = 4,
        FarmReturnToPosition = true,
        FarmLoopDelay = 0.5,
        AutoEquipShovel = true,
        AutoHatch = false,
        AutoCollectMoney = false,
        AutoPlacePlants = false,
        AutoPlaceCapybaras = false,
        AutoClaimPlaytime = false,
        AutoClaimDaily = false,
        AutoClaimQuests = false,
        AutoGrowTree = false,
        AutoBuyLane = false,
        LaneMoneyReserve = 0,
        AutoTurnInBounty = false,
        BountyLoopDelay = 5,
        EggMoneyReserve = 0,
        EggRestartBuyingAt = 0,
        EggWaitingForRestart = false,
        EggPriorities = {},
        GearMoneyReserve = 0,
        GearRestartBuyingAt = 0,
        GearWaitingForRestart = false,
        GearPriorities = {},
        AntiAfk = true,
        BlinkBusy = false,
        Stock = {},
        BossState = nil,
        LastShopRefresh = 0,
        LastBossRefresh = 0,
        LastPurchase = 0,
        LastCollection = 0,
        LastHatch = 0,
        LastPlacePlant = 0,
        LastPlaceCapybara = 0,
        LastRewardClaim = 0,
        LastTreeGrowth = 0,
        LastLanePurchase = 0,
        LastBountyTurnIn = 0,
        LastBountyRefresh = 0,
        HatchBusy = false,
        CurrentTarget = nil,
        FarmOrigin = nil,
        FarmAngle = 0,
        FarmTargetStarted = 0,
        FarmNextTargetAt = 0,
        FarmCollisionState = {},
        PurchaseTurn = "Egg",
    }

    local _, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local ShopPage = addHomeCategory("🛒 Shop", 1, CATEGORY_DECALS.Shop or CATEGORY_DECALS.Progress)
    local BossPage = addHomeCategory("👹 Boss", 2, CATEGORY_DECALS.Combat)
    local ShovelPage = addHomeCategory("⛏️ Shovel", 3, CATEGORY_DECALS.Mastery or CATEGORY_DECALS.Combat)
    local UtilityPage = addHomeCategory("🌱 AFK", 4, CATEGORY_DECALS.Player)

    local EggSection = ShopPage:AddSection("Egg Shop", "Left")
    local GearSection = ShopPage:AddSection("Gear Shop", "Right")
    local ShopStatusSection = ShopPage:AddSection("Live Stock", "Left")
    local ShopInfoSection = ShopPage:AddSection("Purchase Route", "Right")
    local SummonSection = BossPage:AddSection("Boss Summoner", "Left")
    local BossStatusSection = BossPage:AddSection("Summon Status", "Right")
    local ReachSection = ShovelPage:AddSection("Orbit Auto Farm", "Left")
    local TurboSection = ShovelPage:AddSection("Target Settings", "Right")
    local AutomationSection = UtilityPage:AddSection("Garden Automation", "Left")
    local PlayerSection = UtilityPage:AddSection("Player Utilities", "Right")
    local RewardSection = UtilityPage:AddSection("Reward Claims", "Right")
    local ProgressionSection = UtilityPage:AddSection("Tree & Lanes", "Left")
    local BountySection = UtilityPage:AddSection("Auto Bounty", "Right")
    local RuntimeSection = UtilityPage:AddSection("Runtime", "Left")

    local eggStatus = ShopStatusSection:AddLabel("Egg stock: Reading...")
    local gearStatus = ShopStatusSection:AddLabel("Gear stock: Reading...")
    local moneyStatus = ShopStatusSection:AddLabel("Money: Reading...")
    local bossStatus = BossStatusSection:AddLabel("Boss: Reading state...")
    local unlockStatus = BossStatusSection:AddLabel("Access: Reading tree progress...")
    local shovelStatus = TurboSection:AddLabel("Shovel: Idle")
    local targetStatus = TurboSection:AddLabel("Target: None")
    local automationStatus = AutomationSection:AddLabel("Automation: Idle")
    local progressionStatus = ProgressionSection:AddLabel("Progression: Monitoring")
    local bountyStatus = BountySection:AddLabel("Bounties: Reading...")

    local function notify(message, color)
        Window:Notify("Capybaras VS Plants", tostring(message), 4, color or COLORS.accentBright)
    end

    local function setLabel(control, text)
        if control and type(control.Set) == "function" then
            control:Set(text)
        elseif control then
            control.Text = text
        end
    end

    local function valueOf(container, name, fallback)
        local object = container and container:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            return object.Value
        end
        return fallback
    end

    local function itemData(name)
        return EggData.getData(name) or GearData.getData(name) or ShopData.getData(name)
    end

    local function money()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        local value = leaderstats and leaderstats:FindFirstChild("Money")
        return value and tonumber(value.Value) or 0
    end

    local function refreshStock(force)
        if not force and os.clock() - state.LastShopRefresh < 1.5 then
            return state.Stock
        end
        state.LastShopRefresh = os.clock()
        local ok, personalStock = pcall(function()
            return Remotes.RequestPersonalStock:InvokeServer()
        end)
        if ok and type(personalStock) == "table" then
            state.Stock = personalStock
        end
        return state.Stock
    end

    local function stockOf(name)
        return tonumber(refreshStock(false)[name]) or 0
    end

    local function costOf(name)
        return tonumber(valueOf(itemData(name), "Cost", math.huge)) or math.huge
    end

    local function shopPolicy(source)
        if source == "Egg" then
            return state.EggMoneyReserve, state.EggRestartBuyingAt, "EggWaitingForRestart", state.EggPriorities
        end
        return state.GearMoneyReserve, state.GearRestartBuyingAt, "GearWaitingForRestart", state.GearPriorities
    end

    local function refreshPurchaseGate(source)
        local reserve, restart, waitingKey = shopPolicy(source)
        if state[waitingKey] and money() >= math.max(reserve, restart) then
            state[waitingKey] = false
        end
        return state[waitingKey]
    end

    local function policyAllows(name, source)
        local reserve, restart, waitingKey, priorities = shopPolicy(source)
        local balance = money()
        local cost = costOf(name)
        if balance - cost < reserve then
            state[waitingKey] = true
            return false
        end
        if state[waitingKey] then
            if balance >= math.max(reserve, restart) then
                state[waitingKey] = false
                return true
            end
            return priorities[name] == true
        end
        return true
    end

    local function canPurchase(name, source)
        return stockOf(name) > 0 and money() >= costOf(name) and policyAllows(name, source)
    end

    local function purchase(name, source)
        if not name or os.clock() - state.LastPurchase < 0.18 then
            return false
        end
        refreshStock(true)
        if stockOf(name) <= 0 then
            return false
        end
        if money() < costOf(name) or not policyAllows(name, source) then
            return false
        end
        state.LastPurchase = os.clock()
        Remotes.BuyItem:FireServer(name)
        state.Stock[name] = math.max(0, stockOf(name) - 1)
        setLabel(source == "Egg" and eggStatus or gearStatus, source .. " stock: Buying " .. name)
        return true
    end

    local function selectedSummary(order, selected)
        local names = {}
        local stock = 0
        for _, name in ipairs(order) do
            if selected[name] then
                names[#names + 1] = name
                stock += stockOf(name)
            end
        end
        if #names == 0 then
            return "none selected", 0
        end
        if #names <= 2 then
            return table.concat(names, ", "), stock
        end
        return tostring(#names) .. " selected", stock
    end

    local function buyNextSelected(order, selected, source)
        local _, _, _, priorities = shopPolicy(source)
        local candidates = refreshPurchaseGate(source) and priorities or selected
        for _, name in ipairs(order) do
            if candidates[name] and canPurchase(name, source) then
                return purchase(name, source), name
            end
        end
        return false
    end

    local function buySelectedOnce(order, selected, source)
        task.spawn(function()
            local bought = 0
            for _, name in ipairs(order) do
                if state.Alive and selected[name] and canPurchase(name, source) then
                    if purchase(name, source) then
                        bought += 1
                    end
                    task.wait(0.22)
                end
            end
            notify(bought > 0 and ("Bought " .. bought .. " selected " .. string.lower(source) .. " item(s)") or (source .. " selections are unavailable"), bought > 0 and COLORS.success or COLORS.warning)
        end)
    end

    local function updateShopLabels()
        refreshStock(false)
        local eggText, eggStock = selectedSummary(eggOrder, state.SelectedEggs)
        local gearText, gearStock = selectedSummary(gearOrder, state.SelectedGears)
        local eggGate = state.EggWaitingForRestart and (" | waiting for $" .. tostring(math.max(state.EggMoneyReserve, state.EggRestartBuyingAt))) or ""
        local gearGate = state.GearWaitingForRestart and (" | waiting for $" .. tostring(math.max(state.GearMoneyReserve, state.GearRestartBuyingAt))) or ""
        setLabel(eggStatus, string.format("Eggs: %s | stock %d%s", eggText, eggStock, eggGate))
        setLabel(gearStatus, string.format("Gear: %s | stock %d%s", gearText, gearStock, gearGate))
        setLabel(moneyStatus, "Money: $" .. tostring(money()))
    end

    local function refreshBossState(force)
        if not force and os.clock() - state.LastBossRefresh < 1.5 then
            return state.BossState
        end
        state.LastBossRefresh = os.clock()
        local ok, result = pcall(function()
            return Remotes.SummonBoss:InvokeServer("GetState")
        end)
        if ok and type(result) == "table" then
            state.BossState = result
        end
        return state.BossState
    end

    local function bossAvailable(name)
        local current = refreshBossState(false)
        if not current then
            return false, "State unavailable"
        end
        if current.ActiveBoss then
            return false, "Active: " .. tostring(current.ActiveBoss)
        end
        local cooldown = current.Cooldowns and tonumber(current.Cooldowns[name]) or 0
        if cooldown and cooldown > 0 then
            return false, "Cooldown: " .. BossData.formatCooldown(cooldown)
        end
        local meets = BossData.meetsRequirements(name, tonumber(current.TreeLevel) or 0, current.Defeated or {})
        if not meets then
            return false, "Locked"
        end
        return true, "Ready"
    end

    local function summonSelected()
        local available, reason = bossAvailable(state.SelectedBoss)
        if not available then
            return false, reason
        end
        local ok, result = pcall(function()
            return Remotes.SummonBoss:InvokeServer("Summon", state.SelectedBoss)
        end)
        state.LastBossRefresh = 0
        return ok and result ~= false, ok and "Summon requested" or tostring(result)
    end

    local function updateBossLabels()
        local current = refreshBossState(false)
        local available, reason = bossAvailable(state.SelectedBoss)
        setLabel(bossStatus, string.format("Boss: %s | %s", state.SelectedBoss, reason))
        setLabel(unlockStatus, "Tree level: " .. tostring(current and current.TreeLevel or "?"))
        if available then
            bossStatus.TextColor3 = COLORS.success or Color3.fromRGB(74, 225, 144)
        else
            bossStatus.TextColor3 = COLORS.muted or Color3.fromRGB(185, 177, 200)
        end
    end

    local function plantsFolder()
        local world = workspace:FindFirstChild("World")
        local map = world and world:FindFirstChild("Map")
        local plants = map and map:FindFirstChild("Plants")
        return plants and plants:FindFirstChild("Server")
    end

    local function placedItemsFolder()
        local world = workspace:FindFirstChild("World")
        local map = world and world:FindFirstChild("Map")
        local items = map and map:FindFirstChild("PlacedItems")
        return items and items:FindFirstChild("Server")
    end

    local function getCharacter()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    local function isShovel(tool)
        return tool and tool:IsA("Tool") and string.find(string.lower(tool.Name), "shovel", 1, true) ~= nil
    end

    local function getShovel(equippedOnly)
        local character = LocalPlayer.Character
        for _, item in ipairs(character and character:GetChildren() or {}) do
            if isShovel(item) then
                return item
            end
        end
        if equippedOnly then
            return nil
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, item in ipairs(backpack and backpack:GetChildren() or {}) do
            if isShovel(item) then
                return item
            end
        end
        return nil
    end

    local function equipShovel()
        local tool = getShovel(false)
        local _, humanoid = getCharacter()
        if tool and humanoid and tool.Parent ~= LocalPlayer.Character then
            humanoid:EquipTool(tool)
            task.wait()
        end
        return getShovel(true)
    end

    local function isBoss(model)
        return bossNames[model.Name:split(":")[1]] == true
    end

    local rarityOrder = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Godly = 6, Divine = 7, Secret = 8}

    local function ownPlot()
        local world = workspace:FindFirstChild("World")
        local map = world and world:FindFirstChild("Map")
        local plots = map and map:FindFirstChild("Plots")
        for _, plot in ipairs(plots and plots:GetChildren() or {}) do
            if plot:GetAttribute("Owner") == LocalPlayer.UserId then
                return plot
            end
        end
    end

    local function farmTargetRarity(model)
        local data = PlantData.getData(model.Name:split(":")[1])
        return tostring(valueOf(data, "Rarity", "Common"))
    end

    local function validFarmTarget(model, root)
        local configuration = model and model:FindFirstChild("ServerConfiguration")
        local health = configuration and configuration:FindFirstChild("CurrentHealth")
        local size = configuration and configuration:FindFirstChild("SizeScaling")
        local plotNumber = configuration and configuration:FindFirstChild("Plot")
        local plot = ownPlot()
        if not model or not model.PrimaryPart or not configuration or not health or tonumber(health.Value) <= 0 or isBoss(model) then
            return false
        end
        if plot and plotNumber and tostring(plotNumber.Value) ~= plot.Name then
            return false
        end
        local scale = tonumber(size and size.Value) or 1
        if scale < state.FarmMinimumSize or scale > state.FarmMaximumSize then
            return false
        end
        if (rarityOrder[farmTargetRarity(model)] or 0) < (rarityOrder[state.FarmMinimumRarity] or 1) then
            return false
        end
        return root and (model.PrimaryPart.Position - root.Position).Magnitude <= state.FarmRange
    end

    local function nearestFarmTarget()
        local _, _, root = getCharacter()
        local folder = plantsFolder()
        if not root or not folder then return nil end
        local best, bestDistance
        for _, model in ipairs(folder:GetChildren()) do
            if validFarmTarget(model, root) then
                local distance = (model.PrimaryPart.Position - root.Position).Magnitude
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = model, distance
                end
            end
        end
        return best, bestDistance
    end

    local function setFarmCollision(enabled)
        local character = LocalPlayer.Character
        if enabled then
            for _, part in ipairs(character and character:GetDescendants() or {}) do
                if part:IsA("BasePart") and state.FarmCollisionState[part] == nil then
                    state.FarmCollisionState[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
        else
            for part, old in pairs(state.FarmCollisionState) do
                if part.Parent then part.CanCollide = old end
            end
            table.clear(state.FarmCollisionState)
        end
    end

    local function stopOrbitFarm()
        local character, humanoid = getCharacter()
        if state.FarmReturnToPosition and state.FarmOrigin and character and humanoid and humanoid.Health > 0 then
            pcall(function() character:PivotTo(state.FarmOrigin) end)
        end
        setFarmCollision(false)
        state.FarmOrigin = nil
        state.CurrentTarget = nil
        state.FarmTargetStarted = 0
        state.FarmNextTargetAt = 0
        setLabel(shovelStatus, "Auto farm: Idle")
        setLabel(targetStatus, "Target: None")
    end

    local function stepOrbitFarm(deltaTime)
        if not state.AutoFarm or not state.Alive then return end
        local character, humanoid, root = getCharacter()
        if not character or not humanoid or humanoid.Health <= 0 or not root then return end
        if not state.FarmOrigin then
            state.FarmOrigin = character:GetPivot()
            setFarmCollision(true)
        end
        local now = os.clock()
        local target = state.CurrentTarget
        if target and (not validFarmTarget(target, root) or now - state.FarmTargetStarted >= state.FarmFocusTime) then
            state.CurrentTarget = nil
            state.FarmNextTargetAt = now + state.FarmLoopDelay
            target = nil
        end
        if not target and now >= state.FarmNextTargetAt then
            target = nearestFarmTarget()
            state.CurrentTarget = target
            state.FarmTargetStarted = now
        end
        if not target or not target.PrimaryPart then
            setLabel(shovelStatus, "Auto farm: Waiting")
            setLabel(targetStatus, "Target: No eligible plant")
            return
        end
        local tool = getShovel(true)
        if not tool and state.AutoEquipShovel then tool = equipShovel() end
        if not tool then
            setLabel(shovelStatus, "Auto farm: Shovel missing")
            return
        end
        state.FarmAngle = (state.FarmAngle + math.max(0.1, state.FarmStrafeSpeed) * deltaTime) % (math.pi * 2)
        local targetPosition = target.PrimaryPart.Position
        local offset = Vector3.new(math.cos(state.FarmAngle) * state.FarmStrafeRadius, state.FarmHoverHeight, math.sin(state.FarmAngle) * state.FarmStrafeRadius)
        local orbitPosition = targetPosition + offset
        pcall(function()
            character:PivotTo(CFrame.lookAt(orbitPosition, targetPosition))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            tool:Activate()
        end)
        setLabel(shovelStatus, "Auto farm: Orbiting + turbo shovel")
        setLabel(targetStatus, string.format("Target: %s | %s | %.1fx", target.Name:split(":")[1], farmTargetRarity(target), tonumber(valueOf(target.ServerConfiguration, "SizeScaling", 1)) or 1))
    end

    local function nextReadyEgg()
        local folder = placedItemsFolder()
        if not folder then
            return nil
        end
        local ready = {}
        for _, model in ipairs(folder:GetChildren()) do
            local configuration = model:FindFirstChild("ServerConfiguration")
            local kind = configuration and configuration:FindFirstChild("Type")
            local percentage = configuration and configuration:FindFirstChild("HatchPercentage")
            if model:GetAttribute("Owner") == LocalPlayer.UserId
                and kind and kind.Value == "Egg"
                and percentage and tonumber(percentage.Value) >= 100 then
                ready[#ready + 1] = model
            end
        end
        table.sort(ready, function(a, b) return a.Name < b.Name end)
        return ready[1]
    end

    local function processReadyEggs(single)
        if state.HatchBusy then
            return 0
        end
        state.HatchBusy = true
        local count = 0
        repeat
            local egg = nextReadyEgg()
            if not egg or not state.Alive then
                break
            end
            local oldName = egg.Name
            Remotes.Hatch:FireServer(oldName)
            count += 1
            local started = os.clock()
            repeat
                task.wait(0.15)
            until not state.Alive or not egg.Parent or egg.Name ~= oldName or os.clock() - started >= 8
            task.wait(0.65)
        until single
        state.HatchBusy = false
        return count
    end

    local Automation = (function()
        local function bestTool(attribute)
            local candidates = {}
            for _, parent in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character}) do
                for _, tool in ipairs(parent and parent:GetChildren() or {}) do
                    if tool:IsA("Tool") and tool:GetAttribute(attribute) then
                        local _, _, size, baseName = ItemNameParser(tool.Name)
                        local ok, value = pcall(GetItemValue, {itemName = baseName, SizeScaling = size})
                        candidates[#candidates + 1] = {Tool = tool, Value = ok and tonumber(value) or 0}
                    end
                end
            end
            table.sort(candidates, function(a, b) return a.Value > b.Value end)
            return candidates[1] and candidates[1].Tool
        end

        local function equip(tool)
            local _, humanoid = getCharacter()
            if tool and humanoid and tool.Parent ~= LocalPlayer.Character then
                humanoid:EquipTool(tool)
                task.wait(0.1)
            end
            return tool and tool.Parent == LocalPlayer.Character
        end

        local function occupiedPots()
            local occupied = {}
            local world = workspace:FindFirstChild("World")
            local map = world and world:FindFirstChild("Map")
            local potted = map and map:FindFirstChild("PottedPlants")
            local server = potted and potted:FindFirstChild("Server")
            for _, model in ipairs(server and server:GetChildren() or {}) do
                local config = model:FindFirstChild("ServerConfiguration")
                local pot = config and config:FindFirstChild("PotNumber")
                if model:GetAttribute("Owner") == LocalPlayer.UserId and pot and tonumber(pot.Value) > 0 then
                    occupied[tonumber(pot.Value)] = true
                end
            end
            return occupied
        end

        local function placeBestPlant()
            local occupied = occupiedPots()
            local empty
            for pot = 1, 3 do
                if not occupied[pot] then empty = pot break end
            end
            if not empty then return false, "all pots filled" end
            pcall(function() Remotes.EquipBestPlants:FireServer() end)
            task.wait(0.15)
            local tool = bestTool("isPlant")
            if not tool or not equip(tool) then return false, "no plant tool" end
            Remotes.PotInteract:FireServer(empty)
            return true, "pot " .. empty
        end

        local function freeTowerCFrame()
            local plot = ownPlot()
            if not plot then return nil end
            local placed = placedItemsFolder()
            local slots = {}
            local towerArea = plot:FindFirstChild("TowerArea")
            for _, lane in ipairs(towerArea and towerArea:GetChildren() or {}) do
                local laneNumber = tonumber(lane.Name:match("Purchased(%d+)$"))
                if laneNumber then
                    for _, part in ipairs(lane:GetChildren()) do
                        if part:IsA("BasePart") and part.Name == "TowerAreaPart" then
                            slots[#slots + 1] = {Lane = laneNumber, Part = part}
                        end
                    end
                end
            end
            table.sort(slots, function(a, b)
                if a.Lane == b.Lane then return a.Part.Position.Z < b.Part.Position.Z end
                return a.Lane < b.Lane
            end)
            for _, slot in ipairs(slots) do
                local point = slot.Part.Position
                local free = true
                for _, model in ipairs(placed and placed:GetChildren() or {}) do
                    if model:GetAttribute("Owner") == LocalPlayer.UserId and model.PrimaryPart then
                        local delta = model.PrimaryPart.Position - point
                        if Vector3.new(delta.X, 0, delta.Z).Magnitude < 4.5 then
                            free = false
                            break
                        end
                    end
                end
                if free then return slot.Part.CFrame, slot.Lane end
            end
        end

        local function placeBestCapybara()
            local tool = bestTool("isTower")
            local placement, lane = freeTowerCFrame()
            if not tool then return false, "no capybara tool" end
            if not placement then return false, "no free placement" end
            if not equip(tool) then return false, "equip failed" end
            local mouse = LocalPlayer:GetMouse()
            local oldInvoke = function() return mouse.Hit end
            if type(getcallbackvalue) == "function" then
                pcall(function()
                    local current = getcallbackvalue(Remotes.GetMouseCF, "OnClientInvoke")
                    if type(current) == "function" then oldInvoke = current end
                end)
            end
            local assigned = pcall(function()
                Remotes.GetMouseCF.OnClientInvoke = function() return placement end
            end)
            if not assigned then return false, "placement callback unavailable" end
            local beforeCount = 0
            for _, model in ipairs(placedItemsFolder() and placedItemsFolder():GetChildren() or {}) do
                if model:GetAttribute("Owner") == LocalPlayer.UserId then beforeCount += 1 end
            end
            pcall(function() tool:Activate() end)
            local started = os.clock()
            local placedCount = beforeCount
            repeat
                task.wait(0.1)
                placedCount = 0
                for _, model in ipairs(placedItemsFolder() and placedItemsFolder():GetChildren() or {}) do
                    if model:GetAttribute("Owner") == LocalPlayer.UserId then placedCount += 1 end
                end
            until placedCount > beforeCount or not tool.Parent or os.clock() - started >= 1.25
            pcall(function() Remotes.GetMouseCF.OnClientInvoke = oldInvoke end)
            return placedCount > beforeCount or not tool.Parent, "lane " .. tostring(lane)
        end

        local function claimPlaytime()
            local ok, elapsed, claimed = pcall(function()
                local a, b = Remotes.RequestPlaytime:InvokeServer()
                return a, b
            end)
            if not ok then return false end
            local claimedMap = {}
            for key, value in pairs(type(claimed) == "table" and claimed or {}) do
                claimedMap[type(key) == "number" and value or key] = value == true or type(key) == "number"
            end
            local order = {}
            for name, data in pairs(GameInfo.PlaytimeRewards) do
                order[#order + 1] = {Name = name, Time = tonumber(data.timeRequired) or math.huge}
            end
            table.sort(order, function(a, b) return a.Time < b.Time end)
            for _, reward in ipairs(order) do
                if tonumber(elapsed) >= reward.Time and not claimedMap[reward.Name] then
                    Remotes.ClaimPlaytimeReward:FireServer(reward.Name)
                    return true, reward.Name
                end
            end
            return false
        end

        local function claimDaily()
            local ok, daily = pcall(function() return Remotes.RequestDailyRewards:InvokeServer() end)
            if ok and type(daily) == "table" and not daily.ClaimedToday then
                Remotes.ClaimDailyReward:FireServer()
                return true
            end
            return false
        end

        local function claimQuest()
            local ok, data = pcall(function() return Remotes.RequestQuests:InvokeServer() end)
            if not ok or type(data) ~= "table" then return false end
            for _, id in ipairs(data.Daily and data.Daily.Active or {}) do
                local quest = QuestData.getById(id)
                local target = quest and QuestData.getScaledDailyTarget(quest, data.TreeLevel)
                if quest and not data.Daily.Claimed[id] and (data.Daily.Progress[id] or 0) >= target then
                    return Remotes.ClaimQuest:InvokeServer(id) == true, id
                end
            end
            if data.Bonus and not data.Bonus.Claimed and data.DailyClaimedCount >= #(data.Daily.Active or {}) then
                return Remotes.ClaimQuest:InvokeServer("DailyBonus") == true, "DailyBonus"
            end
            for level = 1, math.min(data.TreeLevel or 0, QuestData.MAX_LIFETIME_LEVEL) do
                local group = QuestData.Lifetime[level]
                if group then
                    local complete = true
                    for _, quest in ipairs(group.Quests) do
                        if not data.LifetimeClaimed[quest.Id] then
                            if (data.LifetimeStats[quest.Stat] or 0) >= quest.Target then
                                return Remotes.ClaimQuest:InvokeServer(quest.Id) == true, quest.Id
                            end
                            complete = false
                        end
                    end
                    local levelKey = tostring(level)
                    if complete and not data.LevelRewardClaimed[levelKey] then
                        local id = "LevelReward:" .. levelKey
                        return Remotes.ClaimQuest:InvokeServer(id) == true, id
                    end
                end
            end
            return false
        end

        local function growTree()
            local ok, level = pcall(function() return Remotes.RequestTreeLevel:InvokeServer() end)
            if not ok or type(level) ~= "number" then return false, "tree level unavailable" end
            local growth = GameInfo.GrowthInfo[level + 1]
            if not growth then return false, "maximum tree level" end
            if money() < (tonumber(growth.Cost) or 0) then return false, "money requirement" end
            if growth.RequiredBoss then
                local bossOk, defeated = pcall(function() return Remotes.RequestDefeatedBosses:InvokeServer() end)
                if not bossOk or type(defeated) ~= "table" or not defeated[growth.RequiredBoss] then
                    return false, "boss requirement"
                end
            end
            local available = {}
            for _, parent in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character}) do
                for _, tool in ipairs(parent and parent:GetChildren() or {}) do
                    if tool:IsA("Tool") and tool:GetAttribute("isPlant") then available[#available + 1] = tool end
                end
            end
            local used = {}
            for _, requirement in ipairs(growth.RequiredPlants or {}) do
                local found
                for _, tool in ipairs(available) do
                    local lower = string.lower(tool.Name)
                    local nameMatch = string.find(lower, string.lower(requirement.Name), 1, true) ~= nil
                    local mutation = tostring(requirement.Mutations or "")
                    local mutationMatch = mutation == "" or string.find(lower, string.lower(mutation), 1, true) ~= nil
                    if not used[tool] and nameMatch and mutationMatch then found = tool break end
                end
                if not found then return false, "plant requirement" end
                used[found] = true
            end
            local grew, result = pcall(function() return Remotes.RequestGrowth:InvokeServer() end)
            return grew and result == true, grew and "growth requested" or tostring(result)
        end

        local function buyLane()
            local plot = ownPlot()
            local _, _, root = getCharacter()
            local buttons = plot and plot:FindFirstChild("LaneButtons")
            if not buttons or not root or type(firetouchinterest) ~= "function" then return false, "lane route unavailable" end
            local choices = {}
            for lane = 1, 7 do
                local model = buttons:FindFirstChild("Lane" .. lane .. "Button")
                local part = model and model:FindFirstChild("ButtonPart")
                local price = tonumber(PurchasablePrices.LanePrices[lane]) or math.huge
                if part and part.CanTouch and part.Transparency < 1 then
                    choices[#choices + 1] = {Lane = lane, Part = part, Price = price}
                end
            end
            table.sort(choices, function(a, b) return a.Price < b.Price end)
            for _, choice in ipairs(choices) do
                if money() - choice.Price >= state.LaneMoneyReserve then
                    pcall(function()
                        firetouchinterest(root, choice.Part, 0)
                        task.wait(0.08)
                        firetouchinterest(root, choice.Part, 1)
                    end)
                    return true, "lane " .. choice.Lane
                end
            end
            return false, "reserve or price blocked"
        end

        local function turnInBounty()
            local ok, data = pcall(function() return Remotes.RequestBounties:InvokeServer() end)
            if not ok or type(data) ~= "table" or (data.EasyClaimed and data.HardClaimed) then return false end
            local turned, result, message = pcall(function() return Remotes.TurnInBounty:InvokeServer() end)
            return turned and result == true, message
        end

        return {
            PlaceBestPlant = placeBestPlant,
            PlaceBestCapybara = placeBestCapybara,
            ClaimPlaytime = claimPlaytime,
            ClaimDaily = claimDaily,
            ClaimQuest = claimQuest,
            GrowTree = growTree,
            BuyLane = buyLane,
            TurnInBounty = turnInBounty,
        }
    end)()

    EggSection:AddDropdown({
        Name = "Eggs",
        Description = "Multi-select in native Egg Shop order",
        Flag = "cvp_selected_eggs",
        Values = eggOrder,
        Multi = true,
        Default = state.SelectedEggs,
        Callback = function(value)
            state.SelectedEggs = type(value) == "table" and value or {}
            updateShopLabels()
        end,
    })
    EggSection:AddToggle({Name = "Auto Buy Selected Eggs", Flag = "cvp_auto_buy_egg", Default = false, Callback = function(value) state.AutoBuyEgg = value end})
    EggSection:AddInput({Name = "Money Reserve", Description = "Never spend below this amount", Flag = "cvp_egg_money_reserve", Placeholder = "0", Default = "0", Callback = function(value) state.EggMoneyReserve = math.max(0, tonumber(value) or 0) end})
    EggSection:AddInput({Name = "Start Buying Again At", Description = "After reserve stops buying, wait for this balance", Flag = "cvp_egg_restart_at", Placeholder = "0", Default = "0", Callback = function(value) state.EggRestartBuyingAt = math.max(0, tonumber(value) or 0) end})
    EggSection:AddDropdown({Name = "Priority Eggs", Description = "Can buy while waiting for restart, but never below reserve", Flag = "cvp_priority_eggs", Values = eggOrder, Multi = true, Default = state.EggPriorities, Callback = function(value) state.EggPriorities = type(value) == "table" and value or {} end})
    EggSection:AddButton({Name = "Buy Selected Eggs Once", Callback = function() buySelectedOnce(eggOrder, state.SelectedEggs, "Egg") end})

    GearSection:AddDropdown({
        Name = "Gear",
        Description = "Multi-select in native Gear Shop order",
        Flag = "cvp_selected_gears",
        Values = gearOrder,
        Multi = true,
        Default = state.SelectedGears,
        Callback = function(value)
            state.SelectedGears = type(value) == "table" and value or {}
            updateShopLabels()
        end,
    })
    GearSection:AddToggle({Name = "Auto Buy Selected Gear", Flag = "cvp_auto_buy_gear", Default = false, Callback = function(value) state.AutoBuyGear = value end})
    GearSection:AddInput({Name = "Money Reserve", Description = "Never spend below this amount", Flag = "cvp_gear_money_reserve", Placeholder = "0", Default = "0", Callback = function(value) state.GearMoneyReserve = math.max(0, tonumber(value) or 0) end})
    GearSection:AddInput({Name = "Start Buying Again At", Description = "After reserve stops buying, wait for this balance", Flag = "cvp_gear_restart_at", Placeholder = "0", Default = "0", Callback = function(value) state.GearRestartBuyingAt = math.max(0, tonumber(value) or 0) end})
    GearSection:AddDropdown({Name = "Priority Gear", Description = "Can buy while waiting for restart, but never below reserve", Flag = "cvp_priority_gears", Values = gearOrder, Multi = true, Default = state.GearPriorities, Callback = function(value) state.GearPriorities = type(value) == "table" and value or {} end})
    GearSection:AddButton({Name = "Buy Selected Gear Once", Callback = function() buySelectedOnce(gearOrder, state.SelectedGears, "Gear") end})
    ShopInfoSection:AddLabel("Uses RequestPersonalStock before every purchase.")
    ShopInfoSection:AddLabel("Priority items bypass restart waiting, never the reserve floor.")

    SummonSection:AddDropdown({
        Name = "Boss",
        Description = "Native Boss Summoner order",
        Flag = "cvp_selected_boss",
        Values = bossOrder,
        Default = state.SelectedBoss,
        Callback = function(value)
            state.SelectedBoss = value
            state.LastBossRefresh = 0
            updateBossLabels()
        end,
    })
    SummonSection:AddToggle({Name = "Auto Summon Boss", Flag = "cvp_auto_summon_boss", Default = false, Callback = function(value) state.AutoSummonBoss = value end})
    SummonSection:AddButton({Name = "Summon Selected Boss", Callback = function()
        local ok, message = summonSelected()
        notify(message, ok and COLORS.success or COLORS.warning)
    end})
    SummonSection:AddButton({Name = "Refresh Boss State", Callback = function()
        state.LastBossRefresh = 0
        updateBossLabels()
    end})

    ReachSection:AddToggle({
        Name = "Orbit Plant Auto Farm",
        Description = "Orbits one walking plant and turbo-clicks the shovel until it dies or focus time expires.",
        Flag = "cvp_orbit_auto_farm",
        Default = false,
        Callback = function(value)
            state.AutoFarm = value
            if not value then stopOrbitFarm() end
        end,
    })
    ReachSection:AddSlider({Name = "Range", Flag = "cvp_farm_range", Min = 25, Max = 500, Step = 5, Default = 150, Suffix = " studs", Callback = function(value) state.FarmRange = tonumber(value) or 150 end})
    ReachSection:AddDropdown({Name = "Minimum Rarity", Flag = "cvp_farm_minimum_rarity", Values = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Godly", "Divine", "Secret"}, Default = "Common", Callback = function(value) state.FarmMinimumRarity = value or "Common" end})
    ReachSection:AddSlider({Name = "Minimum Plant Size", Flag = "cvp_farm_minimum_size", Min = 0, Max = 10, Step = 0.1, Default = 0, Suffix = "x", Callback = function(value) state.FarmMinimumSize = tonumber(value) or 0 end})
    ReachSection:AddSlider({Name = "Maximum Plant Size", Flag = "cvp_farm_maximum_size", Min = 0, Max = 10, Step = 0.1, Default = 10, Suffix = "x", Callback = function(value) state.FarmMaximumSize = tonumber(value) or 10 end})

    TurboSection:AddSlider({Name = "Focus Time Per Target", Flag = "cvp_farm_focus_time", Min = 1, Max = 20, Step = 0.5, Default = 3, Suffix = "s", Callback = function(value) state.FarmFocusTime = tonumber(value) or 3 end})
    TurboSection:AddSlider({Name = "Strafe Radius", Flag = "cvp_farm_strafe_radius", Min = 2, Max = 7, Step = 0.25, Default = 5, Suffix = " studs", Callback = function(value) state.FarmStrafeRadius = tonumber(value) or 5 end})
    TurboSection:AddSlider({Name = "Strafe Speed", Flag = "cvp_farm_strafe_speed", Min = 1, Max = 20, Step = 0.5, Default = 4, Callback = function(value) state.FarmStrafeSpeed = tonumber(value) or 4 end})
    TurboSection:AddSlider({Name = "Hover Height", Flag = "cvp_farm_hover_height", Min = 0, Max = 15, Step = 0.5, Default = 4, Suffix = " studs", Callback = function(value) state.FarmHoverHeight = tonumber(value) or 4 end})
    TurboSection:AddToggle({Name = "Return To Position", Flag = "cvp_farm_return_position", Default = true, Callback = function(value) state.FarmReturnToPosition = value end})
    TurboSection:AddSlider({Name = "Loop Delay", Flag = "cvp_farm_loop_delay", Min = 0, Max = 10, Step = 0.1, Default = 0.5, Suffix = "s", Callback = function(value) state.FarmLoopDelay = tonumber(value) or 0.5 end})
    TurboSection:AddToggle({Name = "Auto Equip Shovel", Flag = "cvp_auto_equip_shovel", Default = true, Callback = function(value) state.AutoEquipShovel = value end})

    AutomationSection:AddToggle({Name = "Auto Hatch Ready Eggs", Flag = "cvp_auto_hatch", Default = false, Callback = function(value) state.AutoHatch = value end})
    AutomationSection:AddToggle({Name = "Auto Claim Plant Money", Flag = "cvp_auto_collect_money", Default = false, Callback = function(value) state.AutoCollectMoney = value end})
    AutomationSection:AddToggle({Name = "Auto Place Best Plants", Flag = "cvp_auto_place_plants", Default = false, Callback = function(value) state.AutoPlacePlants = value end})
    AutomationSection:AddToggle({Name = "Auto Place Best Capybaras", Flag = "cvp_auto_place_capybaras", Default = false, Callback = function(value) state.AutoPlaceCapybaras = value end})
    AutomationSection:AddButton({Name = "Equip Best Plants", Callback = function() Remotes.EquipBestPlants:FireServer() end})
    AutomationSection:AddButton({Name = "Hatch Ready Eggs Now", Callback = function()
        task.spawn(function()
            local count = processReadyEggs(false)
            notify("Hatched " .. tostring(count) .. " ready egg(s) sequentially", COLORS.success)
        end)
    end})

    PlayerSection:AddToggle({Name = "Anti AFK", Flag = "cvp_anti_afk", Default = true, Callback = function(value) state.AntiAfk = value end})
    PlayerSection:AddButton({Name = "Claim Plant Money Now", Callback = function() Remotes.CollectionMachine:FireServer() end})
    RewardSection:AddToggle({Name = "Auto Claim Playtime Rewards", Flag = "cvp_auto_claim_playtime", Default = false, Callback = function(value) state.AutoClaimPlaytime = value end})
    RewardSection:AddToggle({Name = "Auto Claim Daily Reward", Flag = "cvp_auto_claim_daily", Default = false, Callback = function(value) state.AutoClaimDaily = value end})
    RewardSection:AddToggle({Name = "Auto Claim Quests", Flag = "cvp_auto_claim_quests", Default = false, Callback = function(value) state.AutoClaimQuests = value end})
    ProgressionSection:AddToggle({Name = "Auto Level Up Tree", Flag = "cvp_auto_grow_tree", Default = false, Callback = function(value) state.AutoGrowTree = value end})
    ProgressionSection:AddToggle({Name = "Auto Buy Lane", Flag = "cvp_auto_buy_lane", Default = false, Callback = function(value) state.AutoBuyLane = value end})
    ProgressionSection:AddInput({Name = "Lane Money Reserve", Description = "Lane purchases never spend below this balance", Flag = "cvp_lane_money_reserve", Placeholder = "0", Default = "0", Callback = function(value) state.LaneMoneyReserve = math.max(0, tonumber(value) or 0) end})
    BountySection:AddToggle({Name = "Auto Turn In Bounty", Flag = "cvp_auto_turn_in_bounty", Default = false, Callback = function(value) state.AutoTurnInBounty = value end})
    BountySection:AddSlider({Name = "Loop Delay", Flag = "cvp_bounty_loop_delay", Min = 1, Max = 60, Step = 1, Default = 5, Suffix = "s", Callback = function(value) state.BountyLoopDelay = tonumber(value) or 5 end})
    RuntimeSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))
    RuntimeSection:AddLabel("UniverseId: " .. tostring(game.GameId))
    RuntimeSection:AddLabel("Game build: " .. tostring(game.PlaceVersion))
    RuntimeSection:AddLabel("Shop, boss, and shovel routes were live-audited.")

    track(LocalPlayer.Idled:Connect(function()
        if state.Alive and state.AntiAfk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end
    end))

    task.spawn(function()
        while state.Alive do
            updateShopLabels()
            if state.AutoBuyEgg and state.AutoBuyGear then
                if state.PurchaseTurn == "Egg" then
                    buyNextSelected(eggOrder, state.SelectedEggs, "Egg")
                    state.PurchaseTurn = "Gear"
                else
                    buyNextSelected(gearOrder, state.SelectedGears, "Gear")
                    state.PurchaseTurn = "Egg"
                end
            elseif state.AutoBuyEgg then
                buyNextSelected(eggOrder, state.SelectedEggs, "Egg")
            elseif state.AutoBuyGear then
                buyNextSelected(gearOrder, state.SelectedGears, "Gear")
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while state.Alive do
            updateBossLabels()
            if state.AutoSummonBoss then
                summonSelected()
            end
            task.wait(1.5)
        end
    end)

    task.spawn(function()
        local previous = os.clock()
        while state.Alive do
            local now = os.clock()
            local deltaTime = math.min(now - previous, 0.1)
            previous = now
            if state.AutoFarm then
                stepOrbitFarm(deltaTime)
                RunService.Heartbeat:Wait()
            else
                task.wait(0.1)
            end
        end
    end)

    task.spawn(function()
        while state.Alive do
            local activity = {}
            if state.AutoHatch and not state.HatchBusy and os.clock() - state.LastHatch >= 1 then
                state.LastHatch = os.clock()
                task.spawn(processReadyEggs, true)
                activity[#activity + 1] = "hatch queue"
            end
            if state.AutoCollectMoney and os.clock() - state.LastCollection >= 3 then
                state.LastCollection = os.clock()
                Remotes.CollectionMachine:FireServer()
                activity[#activity + 1] = "claimed money"
            end
            if state.AutoPlacePlants and os.clock() - state.LastPlacePlant >= 1.5 then
                state.LastPlacePlant = os.clock()
                local ok = Automation.PlaceBestPlant()
                if ok then activity[#activity + 1] = "placed plant" end
            end
            if state.AutoPlaceCapybaras and os.clock() - state.LastPlaceCapybara >= 1.25 then
                state.LastPlaceCapybara = os.clock()
                local ok = Automation.PlaceBestCapybara()
                if ok then activity[#activity + 1] = "placed capybara" end
            end
            if os.clock() - state.LastRewardClaim >= 1 then
                state.LastRewardClaim = os.clock()
                if state.AutoClaimPlaytime and Automation.ClaimPlaytime() then activity[#activity + 1] = "playtime reward" end
                if state.AutoClaimDaily and Automation.ClaimDaily() then activity[#activity + 1] = "daily reward" end
                if state.AutoClaimQuests and Automation.ClaimQuest() then activity[#activity + 1] = "quest reward" end
            end
            if state.AutoGrowTree and os.clock() - state.LastTreeGrowth >= 3 then
                state.LastTreeGrowth = os.clock()
                local ok, message = Automation.GrowTree()
                if ok then activity[#activity + 1] = "grew tree" end
                setLabel(progressionStatus, ok and "Tree: Leveled up" or ("Tree: " .. tostring(message)))
            end
            if state.AutoBuyLane and os.clock() - state.LastLanePurchase >= 1.5 then
                state.LastLanePurchase = os.clock()
                local ok, message = Automation.BuyLane()
                if ok then activity[#activity + 1] = "bought " .. tostring(message) end
                setLabel(progressionStatus, ok and ("Lane: Bought " .. tostring(message)) or ("Lane: " .. tostring(message)))
            end
            if state.AutoTurnInBounty and os.clock() - state.LastBountyTurnIn >= state.BountyLoopDelay then
                state.LastBountyTurnIn = os.clock()
                local ok, message = Automation.TurnInBounty()
                if ok then activity[#activity + 1] = "turned in bounty" end
                if message then setLabel(bountyStatus, ok and "Bounties: Turned in" or ("Bounties: " .. tostring(message))) end
            end
            if os.clock() - state.LastBountyRefresh >= 2 then
                state.LastBountyRefresh = os.clock()
                local ok, bounties = pcall(function() return Remotes.RequestBounties:InvokeServer() end)
                if ok and type(bounties) == "table" then
                    local easy = bounties.EasyClaimed and "Easy claimed" or (bounties.Easy and bounties.Easy.Description or "Easy unavailable")
                    local hard = bounties.HardClaimed and "Hard claimed" or (bounties.Hard and bounties.Hard.Description or "Hard unavailable")
                    setLabel(bountyStatus, "Easy: " .. tostring(easy) .. " | Hard: " .. tostring(hard))
                end
            end
            setLabel(automationStatus, #activity > 0 and ("Automation: " .. table.concat(activity, ", ")) or "Automation: Monitoring")
            task.wait(0.25)
        end
    end)

    environment.__VORCapybarasVsPlantsCleanup = function()
        if not state.Alive then
            return
        end
        state.Alive = false
        state.AutoBuyEgg = false
        state.AutoBuyGear = false
        state.AutoSummonBoss = false
        state.AutoFarm = false
        state.AutoHatch = false
        state.AutoCollectMoney = false
        state.AutoPlacePlants = false
        state.AutoPlaceCapybaras = false
        state.AutoClaimPlaytime = false
        state.AutoClaimDaily = false
        state.AutoClaimQuests = false
        state.AutoGrowTree = false
        state.AutoBuyLane = false
        state.AutoTurnInBounty = false
        stopOrbitFarm()
    end

    updateShopLabels()
    updateBossLabels()
    selectHomeCategory("🛒 Shop")
    pcall(function()
        gui:SetAttribute("CapybarasVsPlantsModuleReady", true)
        gui:SetAttribute("CapybarasVsPlantsUniverseId", 8841437826)
        gui:SetAttribute("CapybarasVsPlantsPlaceId", 104973076655377)
        gui:SetAttribute("CapybarasVsPlantsBuild", game.PlaceVersion)
    end)
    notify("Capybaras VS Plants module ready", COLORS.success)
end
