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
    local ContextActionService = game:GetService("ContextActionService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local Modules = ReplicatedStorage:WaitForChild("Modules")
    local ShopData = require(Modules:WaitForChild("ShopData"))
    local EggData = require(Modules:WaitForChild("EggData"))
    local GearData = require(Modules:WaitForChild("GearData"))
    local BossData = require(Modules:WaitForChild("BossData"))
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
        PlantReach = false,
        BossReach = false,
        ShovelRange = 120,
        TurboShovel = false,
        AutoEquipShovel = true,
        AutoHatch = false,
        AutoCollectMoney = false,
        AutoPlacePlants = false,
        AutoPlaceCapybaras = false,
        AutoClaimPlaytime = false,
        AutoClaimDaily = false,
        AutoClaimQuests = false,
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
        HatchBusy = false,
        CurrentTarget = nil,
        PurchaseTurn = "Egg",
        AttackCharacter = nil,
        AttackOriginalPivot = nil,
        AttackVisualRestore = nil,
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
    local ReachSection = ShovelPage:AddSection("Extended Shovel Reach", "Left")
    local TurboSection = ShovelPage:AddSection("Shovel Combat", "Right")
    local AutomationSection = UtilityPage:AddSection("Garden Automation", "Left")
    local PlayerSection = UtilityPage:AddSection("Player Utilities", "Right")
    local RewardSection = UtilityPage:AddSection("Reward Claims", "Right")
    local RuntimeSection = UtilityPage:AddSection("Runtime", "Left")

    local eggStatus = ShopStatusSection:AddLabel("Egg stock: Reading...")
    local gearStatus = ShopStatusSection:AddLabel("Gear stock: Reading...")
    local moneyStatus = ShopStatusSection:AddLabel("Money: Reading...")
    local bossStatus = BossStatusSection:AddLabel("Boss: Reading state...")
    local unlockStatus = BossStatusSection:AddLabel("Access: Reading tree progress...")
    local shovelStatus = TurboSection:AddLabel("Shovel: Idle")
    local targetStatus = TurboSection:AddLabel("Target: None")
    local automationStatus = AutomationSection:AddLabel("Automation: Idle")

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

    local function canPurchase(name)
        return stockOf(name) > 0 and money() >= costOf(name)
    end

    local function purchase(name, source)
        if not name or os.clock() - state.LastPurchase < 0.18 then
            return false
        end
        refreshStock(true)
        if stockOf(name) <= 0 then
            return false
        end
        if money() < costOf(name) then
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
        for _, name in ipairs(order) do
            if selected[name] and canPurchase(name) then
                return purchase(name, source), name
            end
        end
        return false
    end

    local function buySelectedOnce(order, selected, source)
        task.spawn(function()
            local bought = 0
            for _, name in ipairs(order) do
                if state.Alive and selected[name] and canPurchase(name) then
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
        setLabel(eggStatus, string.format("Eggs: %s | stock %d", eggText, eggStock))
        setLabel(gearStatus, string.format("Gear: %s | stock %d", gearText, gearStock))
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

    local function validShovelTarget(model)
        local configuration = model and model:FindFirstChild("ServerConfiguration")
        local health = configuration and configuration:FindFirstChild("CurrentHealth")
        if not model or not model.PrimaryPart or not health or tonumber(health.Value) <= 0 then
            return false
        end
        return isBoss(model) and state.BossReach or (not isBoss(model) and state.PlantReach)
    end

    local function nearestShovelTarget()
        local _, _, root = getCharacter()
        local folder = plantsFolder()
        if not root or not folder then
            return nil
        end
        local best, bestDistance
        for _, model in ipairs(folder:GetChildren()) do
            if validShovelTarget(model) then
                local distance = (model.PrimaryPart.Position - root.Position).Magnitude
                if distance <= state.ShovelRange and (not bestDistance or distance < bestDistance) then
                    best = model
                    bestDistance = distance
                end
            end
        end
        return best, bestDistance
    end

    local function beginSilentVisual(character)
        local camera = workspace.CurrentCamera
        local cameraCFrame = camera and camera.CFrame
        local renderName = "VOR_CVP_SilentCamera"
        local clone
        local transparency = {}
        pcall(function()
            local oldArchivable = character.Archivable
            character.Archivable = true
            clone = character:Clone()
            character.Archivable = oldArchivable
            clone.Name = "VOR_SilentShovelMask"
            for _, object in ipairs(clone:GetDescendants()) do
                if object:IsA("LuaSourceContainer") or object:IsA("Tool") then
                    object:Destroy()
                elseif object:IsA("BasePart") then
                    object.Anchored = true
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                end
            end
            clone.Parent = workspace
        end)
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("BasePart") then
                transparency[object] = object.LocalTransparencyModifier
                object.LocalTransparencyModifier = 1
            end
        end
        pcall(function()
            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 50, function()
                if camera and cameraCFrame then
                    camera.CFrame = cameraCFrame
                end
            end)
        end)
        local cleaned = false
        return function()
            if cleaned then return end
            cleaned = true
            pcall(function() RunService:UnbindFromRenderStep(renderName) end)
            for object, old in pairs(transparency) do
                if object.Parent then
                    object.LocalTransparencyModifier = old
                end
            end
            if clone then
                clone:Destroy()
            end
        end
    end

    local function silentShovelAttack(target, turbo)
        if state.BlinkBusy or not state.Alive or not target or not target.Parent then
            return false
        end
        local character, humanoid, root = getCharacter()
        local tool = getShovel(true)
        if not tool and state.AutoEquipShovel then
            tool = equipShovel()
        end
        if not character or not humanoid or humanoid.Health <= 0 or not root or not tool or not target.PrimaryPart then
            return false
        end
        state.BlinkBusy = true
        state.CurrentTarget = target
        local originalPivot = character:GetPivot()
        local restoreVisual = beginSilentVisual(character)
        state.AttackCharacter = character
        state.AttackOriginalPivot = originalPivot
        state.AttackVisualRestore = restoreVisual
        local targetPosition = target.PrimaryPart.Position
        local flatAway = Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z)
        flatAway = flatAway.Magnitude > 0.01 and flatAway.Unit or Vector3.zAxis
        local attackPosition = targetPosition + flatAway * 4 + Vector3.new(0, 2.5, 0)
        local started = os.clock()
        repeat
            if not target.Parent or not target.PrimaryPart then
                break
            end
            targetPosition = target.PrimaryPart.Position
            attackPosition = targetPosition + flatAway * 4 + Vector3.new(0, 2.5, 0)
            pcall(function()
                character:PivotTo(CFrame.lookAt(attackPosition, targetPosition))
            end)
            RunService.Heartbeat:Wait()
            pcall(function()
                tool:Activate()
            end)
            if not turbo then
                break
            end
            task.wait()
        until not state.Alive or (turbo and not state.TurboShovel) or os.clock() - started >= 0.82
        task.wait(turbo and 0.04 or 0.13)
        if state.Alive and character.Parent and humanoid.Health > 0 then
            pcall(function()
                character:PivotTo(originalPivot)
            end)
        end
        restoreVisual()
        state.AttackCharacter = nil
        state.AttackOriginalPivot = nil
        state.AttackVisualRestore = nil
        state.BlinkBusy = false
        state.CurrentTarget = nil
        return true
    end

    local RANGE_ACTION = "VOR_CVP_ExtendedShovel"
    ContextActionService:BindActionAtPriority(RANGE_ACTION, function(_, inputState)
        if inputState ~= Enum.UserInputState.Begin or not state.Alive then
            return Enum.ContextActionResult.Pass
        end
        if not state.PlantReach and not state.BossReach then
            return Enum.ContextActionResult.Pass
        end
        if not getShovel(true) then
            return Enum.ContextActionResult.Pass
        end
        local target = nearestShovelTarget()
        if not target then
            return Enum.ContextActionResult.Pass
        end
        task.spawn(silentShovelAttack, target, false)
        return Enum.ContextActionResult.Sink
    end, false, 3000, Enum.UserInputType.MouseButton1)

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
            local center = plot:GetPivot().Position
            local placed = placedItemsFolder()
            for zOffset = -31, 21, 5 do
                for _, xOffset in ipairs({0, -5, 5, -10, 10}) do
                    local point = Vector3.new(center.X + xOffset, 7.6, center.Z + zOffset)
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
                    if free then return CFrame.new(point) end
                end
            end
        end

        local function placeBestCapybara()
            local tool = bestTool("isTower")
            local placement = freeTowerCFrame()
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
            pcall(function() tool:Activate() end)
            task.wait(0.35)
            pcall(function() Remotes.GetMouseCF.OnClientInvoke = oldInvoke end)
            return true, tool.Name
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

        return {
            PlaceBestPlant = placeBestPlant,
            PlaceBestCapybara = placeBestCapybara,
            ClaimPlaytime = claimPlaytime,
            ClaimDaily = claimDaily,
            ClaimQuest = claimQuest,
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
    GearSection:AddButton({Name = "Buy Selected Gear Once", Callback = function() buySelectedOnce(gearOrder, state.SelectedGears, "Gear") end})
    ShopInfoSection:AddLabel("Uses RequestPersonalStock before every purchase.")
    ShopInfoSection:AddLabel("Only items currently in stock are requested.")

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
        Name = "Plant Silent Shovel",
        Description = "Redirects the shovel to the nearest plant while masking camera and body movement.",
        Flag = "cvp_plant_reach",
        Default = false,
        Callback = function(value) state.PlantReach = value end,
    })
    ReachSection:AddToggle({
        Name = "Boss Silent Shovel",
        Description = "Redirects shovel hits to the nearest native boss target.",
        Flag = "cvp_boss_reach",
        Default = false,
        Callback = function(value) state.BossReach = value end,
    })
    ReachSection:AddSlider({Name = "Shovel Range", Flag = "cvp_shovel_range", Min = 8, Max = 300, Step = 2, Default = 120, Suffix = " studs", Callback = function(value) state.ShovelRange = tonumber(value) or 120 end})

    TurboSection:AddToggle({
        Name = "Turbo Shovel",
        Description = "Activates every frame so every server-accepted 0.25s hit window is used.",
        Flag = "cvp_turbo_shovel",
        Default = false,
        Callback = function(value) state.TurboShovel = value end,
    })
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
        while state.Alive do
            if state.TurboShovel and not state.BlinkBusy then
                if state.PlantReach or state.BossReach then
                    local target = nearestShovelTarget()
                    if target then
                        setLabel(shovelStatus, "Shovel: Turbo redirecting")
                        setLabel(targetStatus, "Target: " .. target.Name:split(":")[1])
                        silentShovelAttack(target, true)
                    else
                        setLabel(shovelStatus, "Shovel: Turbo ready")
                        setLabel(targetStatus, "Target: None in range")
                        local tool = getShovel(true)
                        if not tool and state.AutoEquipShovel then tool = equipShovel() end
                        if tool then pcall(function() tool:Activate() end) end
                        RunService.Heartbeat:Wait()
                    end
                else
                    setLabel(shovelStatus, "Shovel: Turbo native range")
                    setLabel(targetStatus, "Target: Native shovel targeting")
                    local tool = getShovel(true)
                    if not tool and state.AutoEquipShovel then tool = equipShovel() end
                    if tool then pcall(function() tool:Activate() end) end
                    RunService.Heartbeat:Wait()
                end
            else
                if not state.BlinkBusy then
                    setLabel(shovelStatus, "Shovel: Idle")
                    setLabel(targetStatus, "Target: None")
                end
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
        state.TurboShovel = false
        state.AutoHatch = false
        state.AutoCollectMoney = false
        state.AutoPlacePlants = false
        state.AutoPlaceCapybaras = false
        state.AutoClaimPlaytime = false
        state.AutoClaimDaily = false
        state.AutoClaimQuests = false
        if state.AttackCharacter and state.AttackCharacter.Parent and state.AttackOriginalPivot then
            pcall(function() state.AttackCharacter:PivotTo(state.AttackOriginalPivot) end)
        end
        if state.AttackVisualRestore then
            pcall(state.AttackVisualRestore)
        end
        state.AttackCharacter = nil
        state.AttackOriginalPivot = nil
        state.AttackVisualRestore = nil
        ContextActionService:UnbindAction(RANGE_ACTION)
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
