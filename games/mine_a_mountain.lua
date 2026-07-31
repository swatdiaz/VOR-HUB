-- Mine a Mountain adapter for VOR Hub.
-- Universe 10187294555 / root place 125927821145949.
--
-- This module follows the experience's native, server-credited loop:
-- crystal prompt -> carried crystal Tool -> seller teleport -> SellRequest.
-- It does not touch the game's admin remotes or fabricate local cash/stats.

return function(context)
    local Window = assert(context.Window, "game module requires Window")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "game module requires CreateCategoryHomePage")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = assert(context.Colors or context.COLORS, "game module requires colors")
    local track = assert(context.Track, "game module requires Track")
    local gui = assert(context.Gui, "game module requires Gui")

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmingPage = addHomeCategory("Farming", 1, CATEGORY_DECALS.Progress)
    local UpgradesPage = addHomeCategory("Upgrades", 2, CATEGORY_DECALS.Weapons or CATEGORY_DECALS.Progress)
    local ShopPage = addHomeCategory("Shop", 3, CATEGORY_DECALS.Player)
    local RewardsPage = addHomeCategory("Rewards", 4, CATEGORY_DECALS.Overnight)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Visuals)
    selectHomeCategory("Farming")

    local MainFarmSection = FarmingPage:AddSection("OP Mining Loop", "Left")
    local TargetSection = FarmingPage:AddSection("Crystal Targeting", "Right")
    local MiningStatusSection = FarmingPage:AddSection("Mining Status", "Right")
    local UpgradeSection = UpgradesPage:AddSection("Stat Upgrades", "Left")
    local AutoPurchaseSection = UpgradesPage:AddSection("Automatic Progression", "Right")
    local StoreSection = ShopPage:AddSection("Equipment Shop", "Left")
    local TravelSection = ShopPage:AddSection("Travel", "Right")
    local RewardSection = RewardsPage:AddSection("Reward Claims", "Left")
    local SafetySection = RewardsPage:AddSection("Safety & Session", "Right")
    local StatsSection = StatusPage:AddSection("Live Player Stats", "Left")
    local AdapterSection = StatusPage:AddSection("Adapter State", "Right")

    local state = {
        Alive = true,
        Master = false,
        AutoFarm = false,
        AutoSell = true,
        AutoWarmth = false,
        AutoWeight = false,
        AutoPickaxe = false,
        AutoBackpack = false,
        AutoRewards = false,
        AntiAfk = true,
        FreezeGuard = true,
        NoClipTravel = true,
        WalkSpeedEnabled = false,
        WalkSpeed = 24,
        TargetMode = "Best Value",
        MinimumTier = 1,
        TravelMode = "Tween",
        TravelSpeed = 240,
        FarmOffset = 4,
        SellPercent = 92,
        CashReserve = 0,
        Target = nil,
        TargetName = "None",
        Phase = "Idle",
        LastError = "None",
        LastSale = 0,
        LastPurchase = 0,
        LastReward = 0,
        LastStatus = 0,
        LastFarmCycle = 0,
        ConsecutiveFailures = 0,
        FailedTargets = setmetatable({}, {__mode = "k"}),
        OriginalCollision = setmetatable({}, {__mode = "k"}),
        OriginalWalkSpeed = nil,
    }

    local tierNames = {
        All = 1,
        Common = 1,
        Uncommon = 2,
        Rare = 3,
        Epic = 4,
        Legendary = 5,
        Mythic = 6,
        Divine = 7,
        Empyrean = 8,
        Zenith = 9,
        Infinity = 10,
        Ultima = 11,
    }

    local ShopCatalog
    pcall(function()
        ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
    end)

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 4)
    end

    local function realStats()
        local data = LocalPlayer:FindFirstChild("PlayerData")
        return data and data:FindFirstChild("RealStats")
    end

    local function statValue(name, fallback)
        local stats = realStats()
        local value = stats and stats:FindFirstChild(name)
        if value and value:IsA("ValueBase") then
            return value.Value
        end
        return fallback
    end

    local function characterParts()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    local function isCrystalTool(object)
        return object
            and object:IsA("Tool")
            and object:GetAttribute("Tier") ~= nil
            and object:GetAttribute("WeightKg") ~= nil
    end

    local function cargo()
        local weight, count, value = 0, 0, 0
        local function scan(container)
            if not container then
                return
            end
            for _, object in ipairs(container:GetChildren()) do
                if isCrystalTool(object) then
                    weight += tonumber(object:GetAttribute("WeightKg")) or 0
                    value += tonumber(object:GetAttribute("Value")) or 0
                    count += 1
                end
            end
        end
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
        scan(LocalPlayer.Character)
        return weight, count, value
    end

    local function ownsPass(name)
        local folder = LocalPlayer:FindFirstChild("GamepassesOwned")
        local value = folder and folder:FindFirstChild(name)
        return value and value:IsA("BoolValue") and value.Value == true
    end

    local function capacity()
        if LocalPlayer:GetAttribute("InfBackpack") == true then
            return math.huge
        end
        local result = tonumber(statValue("CarryWeight", 10)) or 10
        if ownsPass("CarryKgPlus4") then
            result *= 4
        end
        result += tonumber(statValue("CarryWeightBonus", 0)) or 0
        local playerData = LocalPlayer:FindFirstChild("PlayerData")
        local plotData = playerData and playerData:FindFirstChild("PlotData")
        local runes = plotData and plotData:FindFirstChild("Runes")
        if runes then
            for _, rune in ipairs(runes:GetChildren()) do
                local runeName = rune:GetAttribute("RuneName")
                local remaining = tonumber(rune:GetAttribute("Remaining")) or 0
                if type(runeName) == "string" and runeName:find("Weight", 1, true) and remaining > 0 then
                    result *= 2
                    break
                end
            end
        end
        return result
    end

    local function getCash()
        return tonumber(statValue("Cash", 0)) or 0
    end

    local function bestPickaxe()
        local best, power = nil, -math.huge
        local function scan(container)
            if not container then
                return
            end
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and (object:GetAttribute("IsPickaxe") or object:GetAttribute("DigPower")) then
                    local nextPower = tonumber(object:GetAttribute("DigPower")) or 0
                    if nextPower > power then
                        best, power = object, nextPower
                    end
                end
            end
        end
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
        scan(LocalPlayer.Character)
        return best, math.max(0, power)
    end

    local function equipBestPickaxe()
        local _, humanoid = characterParts()
        local tool = bestPickaxe()
        if humanoid and tool and tool.Parent ~= LocalPlayer.Character then
            pcall(function()
                humanoid:EquipTool(tool)
            end)
        end
        return tool ~= nil
    end

    local function promptFunction()
        if type(fireproximityprompt) == "function" then
            return fireproximityprompt
        end
        return nil
    end

    local function activatePrompt(prompt)
        if not prompt or not prompt.Parent then
            return false, "prompt missing"
        end
        local fn = promptFunction()
        if fn then
            local ok, err = pcall(fn, prompt, prompt.HoldDuration)
            return ok, err
        end
        local ok, err = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.max(0.05, tonumber(prompt.HoldDuration) or 0))
            prompt:InputHoldEnd()
        end)
        return ok, err
    end

    local function setTravelCollision(character, enabled)
        if not character or (enabled and not state.NoClipTravel) then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if enabled then
                    if state.OriginalCollision[part] == nil then
                        state.OriginalCollision[part] = part.CanCollide
                    end
                    part.CanCollide = false
                else
                    local original = state.OriginalCollision[part]
                    if original ~= nil then
                        part.CanCollide = original
                        state.OriginalCollision[part] = nil
                    end
                end
            end
        end
    end

    local function travelTo(position)
        local character, humanoid, root = characterParts()
        if not (character and humanoid and root) then
            return false, "character unavailable"
        end
        local goalPosition = position + Vector3.new(0, state.FarmOffset, 0)
        local distance = (root.Position - goalPosition).Magnitude
        state.Phase = string.format("Traveling (%.0f studs)", distance)
        setTravelCollision(character, true)

        local ok, err = pcall(function()
            if state.TravelMode == "Teleport" or distance <= 12 then
                character:PivotTo(CFrame.new(goalPosition))
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.12)
                return
            end

            local start = character:GetPivot()
            local goal = CFrame.new(goalPosition)
            local duration = math.clamp(distance / math.max(25, state.TravelSpeed), 0.08, 8)
            local started = os.clock()
            while state.Alive and (state.Master or state.AutoFarm) do
                local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
                character:PivotTo(start:Lerp(goal, alpha))
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if alpha >= 1 then
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end)

        setTravelCollision(character, false)
        if not ok then
            return false, err
        end
        return true
    end

    local function crystalRoots()
        local roots = {}
        local things = workspace:FindFirstChild("Things")
        local crystals = things and things:FindFirstChild("Crystals")
        if crystals then
            table.insert(roots, crystals)
        end
        local dropped = workspace:FindFirstChild("DroppedCrystals")
        if dropped then
            table.insert(roots, dropped)
        end
        return roots
    end

    local function chooseTarget()
        local _, _, root = characterParts()
        if not root then
            return nil, "character unavailable"
        end
        local carried = cargo()
        local room = capacity() - carried
        local now = os.clock()
        local candidates = {}

        for _, folder in ipairs(crystalRoots()) do
            for _, crystal in ipairs(folder:GetChildren()) do
                local part = crystal:IsA("BasePart") and crystal or crystal:FindFirstChildWhichIsA("BasePart")
                local prompt = crystal:FindFirstChildWhichIsA("ProximityPrompt", true)
                local tier = tonumber(crystal:GetAttribute("Tier") or (part and part:GetAttribute("Tier"))) or 0
                local weight = tonumber(crystal:GetAttribute("WeightKg") or (part and part:GetAttribute("WeightKg"))) or 0
                local value = tonumber(crystal:GetAttribute("Value") or (part and part:GetAttribute("Value"))) or 0
                local failedUntil = state.FailedTargets[crystal]
                if part
                    and prompt
                    and prompt.Enabled
                    and tier >= state.MinimumTier
                    and weight > 0
                    and weight <= room + 0.001
                    and crystal:GetAttribute("Collected") ~= true
                    and (not failedUntil or failedUntil <= now) then
                    local distance = (part.Position - root.Position).Magnitude
                    local score
                    if state.TargetMode == "Nearest" then
                        score = -distance
                    elseif state.TargetMode == "Highest Tier" then
                        score = tier * 1e12 + value * 1e3 - distance
                    elseif state.TargetMode == "Value per kg" then
                        score = (value / math.max(0.05, weight)) * 1e4 - distance
                    else
                        score = value * 1e4 - distance
                    end
                    table.insert(candidates, {
                        Crystal = crystal,
                        Part = part,
                        Prompt = prompt,
                        Name = tostring(crystal:GetAttribute("CrystalName") or part:GetAttribute("CrystalName") or crystal.Name),
                        Tier = tier,
                        Weight = weight,
                        Value = value,
                        Distance = distance,
                        Score = score,
                    })
                end
            end
        end

        table.sort(candidates, function(a, b)
            return a.Score > b.Score
        end)
        return candidates[1], #candidates == 0 and "no crystal fits remaining capacity" or nil
    end

    local function mineTarget(target)
        if not target or not target.Crystal.Parent then
            return false, "target vanished"
        end
        state.Target = target.Crystal
        state.TargetName = string.format("%s | T%d | $%s", target.Name, target.Tier, tostring(math.floor(target.Value)))
        equipBestPickaxe()
        local beforeWeight, beforeCount = cargo()
        local moved, moveError = travelTo(target.Part.Position)
        if not moved then
            return false, moveError
        end
        task.wait(0.12)
        local prompt = target.Crystal:FindFirstChildWhichIsA("ProximityPrompt", true) or target.Prompt
        local promptDeadline = os.clock() + 1.25
        while prompt
            and prompt.Parent
            and (not prompt.Enabled or prompt.MaxActivationDistance <= 0)
            and os.clock() < promptDeadline do
            task.wait(0.06)
        end
        if not prompt or not prompt.Parent or not prompt.Enabled or prompt.MaxActivationDistance <= 0 then
            state.FailedTargets[target.Crystal] = os.clock() + 6
            return false, "crystal did not become server-visible"
        end
        local deadline = os.clock() + 18
        local hit = 0
        while state.Alive
            and (state.Master or state.AutoFarm)
            and os.clock() < deadline
            and target.Crystal.Parent
            and target.Crystal:GetAttribute("Value") ~= nil do
            local nextWeight, nextCount = cargo()
            if nextCount > beforeCount
                or nextWeight > beforeWeight + 0.001
                or not target.Crystal.Parent
                or target.Crystal:GetAttribute("Value") == nil then
                state.ConsecutiveFailures = 0
                state.LastError = "None"
                return true
            end

            prompt = target.Crystal:FindFirstChildWhichIsA("ProximityPrompt", true) or prompt
            local readyDeadline = os.clock() + 1.5
            while prompt
                and prompt.Parent
                and (not prompt.Enabled or prompt.MaxActivationDistance <= 0)
                and os.clock() < readyDeadline do
                task.wait(0.05)
            end
            if not prompt or not prompt.Parent then
                break
            end
            if prompt.Enabled and prompt.MaxActivationDistance > 0 then
                hit += 1
                state.Phase = string.format("Mining %s (hit %d)", target.Name, hit)
                local activated, promptError = activatePrompt(prompt)
                if not activated then
                    return false, promptError
                end
            end
            task.wait(0.12)
        end

        local nextWeight, nextCount = cargo()
        if nextCount > beforeCount
            or nextWeight > beforeWeight + 0.001
            or not target.Crystal.Parent
            or target.Crystal:GetAttribute("Value") == nil then
            state.ConsecutiveFailures = 0
            state.LastError = "None"
            return true
        end
        state.FailedTargets[target.Crystal] = os.clock() + 4
        state.ConsecutiveFailures += 1
        return false, "server did not credit crystal"
    end

    local function sellCargo(manual)
        local weight, count, heldValue = cargo()
        if count <= 0 then
            if manual then
                notify("Mine a Mountain", "No crystals to sell.")
            end
            return false, "backpack empty"
        end
        state.Phase = "Returning to crystal buyer"
        Remotes.GoHome:FireServer("sell")
        local deadline = os.clock() + 2.5
        repeat
            task.wait(0.1)
            local _, _, root = characterParts()
            local sellProx = workspace:FindFirstChild("Things") and workspace.Things:FindFirstChild("SellProx")
            if root and sellProx and (root.Position - sellProx:GetPivot().Position).Magnitude <= 14 then
                break
            end
        until os.clock() >= deadline

        local cashBefore = getCash()
        state.Phase = "Selling " .. tostring(count) .. " crystal(s)"
        Remotes.SellRequest:FireServer("all")
        deadline = os.clock() + 2.5
        repeat
            task.wait(0.1)
            local nextWeight, nextCount = cargo()
            if nextCount == 0 or nextWeight <= 0 then
                local earned = math.max(0, getCash() - cashBefore)
                state.LastSale = earned
                state.LastError = "None"
                if manual then
                    notify("Crystals Sold", string.format("$%d credited (held value $%d)", earned, heldValue), 4)
                end
                return true
            end
        until os.clock() >= deadline
        state.LastError = "SellRequest was not credited"
        return false, state.LastError
    end

    local function inventoryCategory(name)
        local data = LocalPlayer:FindFirstChild("PlayerData")
        local inventory = data and data:FindFirstChild("Inventory")
        return inventory and inventory:FindFirstChild(name)
    end

    local function isOwned(category, id)
        local folder = inventoryCategory(category)
        local owned = folder and folder:FindFirstChild("Owned")
        return owned and owned:FindFirstChild(id) ~= nil
    end

    local function equippedId(category)
        local folder = inventoryCategory(category)
        local equipped = folder and folder:FindFirstChild("Equipped")
        return equipped and tostring(equipped.Value) or ""
    end

    local function bestCatalogItem(category, affordableOnly, unownedOnly)
        if not ShopCatalog or type(ShopCatalog.getCategory) ~= "function" then
            return nil
        end
        local list = ShopCatalog.getCategory(category) or {}
        local available = math.max(0, getCash() - state.CashReserve)
        local best, bestScore = nil, -math.huge
        for _, item in ipairs(list) do
            local price = tonumber(item.price) or 0
            local owned = isOwned(category, item.id)
            if not item.adminOnly
                and (not unownedOnly or price > 0)
                and (not affordableOnly or price <= available)
                and (not unownedOnly or not owned) then
                local stats = item.stats or {}
                local score = category == "Pickaxes"
                    and (tonumber(stats.DigPower) or 0)
                    or (tonumber(stats.WeightLimit) or tonumber(item.backpackIndex) or 0)
                if score > bestScore then
                    best, bestScore = item, score
                end
            end
        end
        return best
    end

    local function equipBestOwned(category)
        local item = bestCatalogItem(category, false, false)
        if not item then
            return false
        end
        local list = ShopCatalog.getCategory(category) or {}
        local best, bestScore = nil, -math.huge
        for _, candidate in ipairs(list) do
            if not candidate.adminOnly and isOwned(category, candidate.id) then
                local stats = candidate.stats or {}
                local score = category == "Pickaxes"
                    and (tonumber(stats.DigPower) or 0)
                    or (tonumber(stats.WeightLimit) or tonumber(candidate.backpackIndex) or 0)
                if score > bestScore then
                    best, bestScore = candidate, score
                end
            end
        end
        if best and equippedId(category) ~= best.id then
            Remotes.ShopEquip:FireServer(best.id)
            task.wait(0.25)
        end
        if category == "Pickaxes" then
            equipBestPickaxe()
        end
        return best ~= nil
    end

    local function buyBestEquipment(category, manual)
        local item = bestCatalogItem(category, true, true)
        if not item or (tonumber(item.price) or 0) <= 0 then
            equipBestOwned(category)
            if manual then
                notify("Equipment", "Nothing better is affordable yet.")
            end
            return false
        end
        local cashBefore = getCash()
        state.Phase = "Buying " .. tostring(item.name or item.id)
        Remotes.ShopBuy:FireServer(item.id)
        task.wait(0.45)
        local purchased = isOwned(category, item.id) or getCash() < cashBefore
        if purchased then
            Remotes.ShopEquip:FireServer(item.id)
            task.wait(0.25)
            state.LastPurchase = tonumber(item.price) or 0
            if category == "Pickaxes" then
                equipBestPickaxe()
            end
            if manual then
                notify("Equipment Upgraded", tostring(item.name or item.id) .. " purchased and equipped.")
            end
            return true
        end
        state.LastError = "Purchase was not credited"
        return false
    end

    local function buyStatUpgrade(kind, manual)
        local available = math.max(0, getCash() - state.CashReserve)
        local ok, prices = pcall(function()
            return Remotes.UpgradePrices:InvokeServer(kind)
        end)
        if not ok or type(prices) ~= "table" then
            state.LastError = "UpgradePrices unavailable"
            return false
        end
        local bundle
        for index = 3, 1, -1 do
            if tonumber(prices[index]) and prices[index] <= available then
                bundle = index
                break
            end
        end
        if not bundle then
            if manual then
                notify("Upgrade", "Not enough cash after reserve.")
            end
            return false
        end
        local cashBefore = getCash()
        Remotes.UpgradeBuy:FireServer(kind, bundle)
        task.wait(0.45)
        local credited = getCash() < cashBefore
        if credited then
            state.LastPurchase = tonumber(prices[bundle]) or 0
            if manual then
                notify("Upgrade Credited", string.format("%s bundle %d purchased.", kind, bundle))
            end
            return true
        end
        state.LastError = kind .. " upgrade was not credited"
        return false
    end

    local function runPurchases()
        if state.Master or state.AutoPickaxe then
            buyBestEquipment("Pickaxes", false)
        end
        if state.Master or state.AutoBackpack then
            buyBestEquipment("Backpacks", false)
        end
        if state.Master or state.AutoWarmth then
            buyStatUpgrade("Air", false)
        end
        if state.Master or state.AutoWeight then
            buyStatUpgrade("Weight", false)
        end
        equipBestOwned("Pickaxes")
        equipBestOwned("Backpacks")
    end

    local function claimRewards(manual)
        local claimedGroup = statValue("ClaimedGroupReward", false) == true
        local tutorialClaimed = statValue("TutorialRewardClaimed", false) == true
        if not claimedGroup and Remotes:FindFirstChild("ClaimGroupReward") then
            Remotes.ClaimGroupReward:FireServer()
            task.wait(0.25)
        end
        if not tutorialClaimed and Remotes:FindFirstChild("ClaimTutorialReward") then
            Remotes.ClaimTutorialReward:FireServer()
            task.wait(0.25)
        end
        state.LastReward = os.clock()
        if manual then
            notify("Rewards", "Requested every currently unclaimed native reward.")
        end
    end

    local function goHome(mode)
        Remotes.GoHome:FireServer(mode)
        state.Phase = "Travel request: " .. tostring(mode)
    end

    local targetHighlight = Instance.new("Highlight")
    targetHighlight.Name = "VORMineTarget"
    targetHighlight.FillColor = COLORS.accent
    targetHighlight.FillTransparency = 0.55
    targetHighlight.OutlineColor = COLORS.accentBright
    targetHighlight.OutlineTransparency = 0
    targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    targetHighlight.Enabled = false
    targetHighlight.Parent = gui

    local phaseLabel = MiningStatusSection:AddLabel("Phase: Idle")
    local targetLabel = MiningStatusSection:AddLabel("Target: None")
    local backpackLabel = MiningStatusSection:AddLabel("Backpack: 0 / 0 kg")
    local saleLabel = MiningStatusSection:AddLabel("Last sale: $0")
    local cashLabel = StatsSection:AddLabel("Cash: $0")
    local heightLabel = StatsSection:AddLabel("Height: 0m | Best: 0m")
    local warmthLabel = StatsSection:AddLabel("Warmth: 0 | Exposure: 0%")
    local equipmentLabel = StatsSection:AddLabel("Pickaxe: None | Power: 0")
    local cargoLabel = StatsSection:AddLabel("Cargo: 0 crystals | $0")
    local adapterLabel = AdapterSection:AddLabel("Adapter: Initializing")
    local errorLabel = AdapterSection:AddLabel("Last error: None")
    local purchaseLabel = AdapterSection:AddLabel("Last purchase: $0")
    local remoteLabel = AdapterSection:AddLabel("Server remotes: Waiting")

    MainFarmSection:AddToggle({
        Name = "Full OP Mining Loop",
        Description = "Mines, sells, buys best equipment, upgrades warmth/capacity, and repeats",
        Flag = "mam_full_op_loop",
        Default = false,
        Callback = function(enabled)
            state.Master = enabled
            state.Phase = enabled and "Starting full loop" or "Idle"
        end,
    })
    MainFarmSection:AddToggle({
        Name = "Auto Mine",
        Flag = "mam_auto_mine",
        Default = false,
        Callback = function(enabled)
            state.AutoFarm = enabled
            if not enabled and not state.Master then
                state.Phase = "Idle"
            end
        end,
    })
    MainFarmSection:AddToggle({
        Name = "Auto Sell",
        Description = "Uses GoHome then the game's credited SellRequest",
        Flag = "mam_auto_sell",
        Default = true,
        Callback = function(enabled)
            state.AutoSell = enabled
        end,
    })
    MainFarmSection:AddSlider({
        Name = "Sell At Backpack",
        Flag = "mam_sell_percent",
        Min = 50,
        Max = 100,
        Step = 1,
        Default = 92,
        Suffix = "%",
        Callback = function(value)
            state.SellPercent = tonumber(value) or 92
        end,
    })
    MainFarmSection:AddButton({
        Name = "Mine Best Crystal Once",
        Callback = function()
            task.spawn(function()
                local target, err = chooseTarget()
                if not target then
                    notify("Mining", err or "No valid target.")
                    return
                end
                local ok, message = mineTarget(target)
                notify("Mining", ok and ("Credited " .. target.Name) or tostring(message))
            end)
        end,
    })
    MainFarmSection:AddButton({
        Name = "Sell Backpack Now",
        Callback = function()
            task.spawn(sellCargo, true)
        end,
    })

    TargetSection:AddDropdown({
        Name = "Target Priority",
        Flag = "mam_target_priority",
        Options = {"Best Value", "Value per kg", "Highest Tier", "Nearest"},
        Default = "Best Value",
        Callback = function(value)
            state.TargetMode = value or "Best Value"
        end,
    })
    TargetSection:AddDropdown({
        Name = "Minimum Crystal Tier",
        Flag = "mam_minimum_tier",
        Options = {"All", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Empyrean", "Zenith", "Infinity", "Ultima"},
        Default = "All",
        Callback = function(value)
            state.MinimumTier = tierNames[value] or 1
        end,
    })
    TargetSection:AddDropdown({
        Name = "Travel Mode",
        Flag = "mam_travel_mode",
        Options = {"Tween", "Teleport"},
        Default = "Tween",
        Callback = function(value)
            state.TravelMode = value or "Tween"
        end,
    })
    TargetSection:AddSlider({
        Name = "Tween Speed",
        Flag = "mam_tween_speed",
        Min = 60,
        Max = 600,
        Step = 10,
        Default = 240,
        Suffix = " studs/s",
        Callback = function(value)
            state.TravelSpeed = tonumber(value) or 240
        end,
    })
    TargetSection:AddSlider({
        Name = "Crystal Offset",
        Flag = "mam_crystal_offset",
        Min = 2,
        Max = 10,
        Step = 0.5,
        Default = 4,
        Suffix = " studs",
        Callback = function(value)
            state.FarmOffset = tonumber(value) or 4
        end,
    })
    TargetSection:AddToggle({
        Name = "No Clip While Traveling",
        Flag = "mam_travel_noclip",
        Default = true,
        Callback = function(enabled)
            state.NoClipTravel = enabled
        end,
    })

    UpgradeSection:AddToggle({
        Name = "Auto Buy Warmth",
        Flag = "mam_auto_warmth",
        Default = false,
        Callback = function(enabled)
            state.AutoWarmth = enabled
        end,
    })
    UpgradeSection:AddToggle({
        Name = "Auto Buy Carry Weight",
        Flag = "mam_auto_weight",
        Default = false,
        Callback = function(enabled)
            state.AutoWeight = enabled
        end,
    })
    UpgradeSection:AddButton({
        Name = "Buy Best Warmth Bundle",
        Callback = function()
            task.spawn(buyStatUpgrade, "Air", true)
        end,
    })
    UpgradeSection:AddButton({
        Name = "Buy Best Weight Bundle",
        Callback = function()
            task.spawn(buyStatUpgrade, "Weight", true)
        end,
    })

    AutoPurchaseSection:AddToggle({
        Name = "Auto Buy Best Pickaxe",
        Flag = "mam_auto_pickaxe",
        Default = false,
        Callback = function(enabled)
            state.AutoPickaxe = enabled
        end,
    })
    AutoPurchaseSection:AddToggle({
        Name = "Auto Buy Best Backpack",
        Flag = "mam_auto_backpack",
        Default = false,
        Callback = function(enabled)
            state.AutoBackpack = enabled
        end,
    })
    AutoPurchaseSection:AddInput({
        Name = "Cash Reserve",
        Flag = "mam_cash_reserve",
        Placeholder = "Cash never spent",
        Default = "0",
        Callback = function(value)
            state.CashReserve = math.max(0, tonumber(value) or 0)
        end,
    })
    AutoPurchaseSection:AddButton({
        Name = "Run All Purchases Once",
        Callback = function()
            task.spawn(function()
                runPurchases()
                notify("Progression", "Finished one server-checked purchase pass.")
            end)
        end,
    })

    StoreSection:AddButton({
        Name = "Buy Best Affordable Pickaxe",
        Callback = function()
            task.spawn(buyBestEquipment, "Pickaxes", true)
        end,
    })
    StoreSection:AddButton({
        Name = "Buy Best Affordable Backpack",
        Callback = function()
            task.spawn(buyBestEquipment, "Backpacks", true)
        end,
    })
    StoreSection:AddButton({
        Name = "Equip Best Owned Gear",
        Callback = function()
            task.spawn(function()
                equipBestOwned("Pickaxes")
                equipBestOwned("Backpacks")
                notify("Equipment", "Best owned pickaxe and backpack equipped.")
            end)
        end,
    })
    StoreSection:AddLabel("Equipment choices come from the live ShopCatalog, not hard-coded guesses.")

    TravelSection:AddButton({
        Name = "Go to Crystal Buyer",
        Callback = function()
            goHome("sell")
        end,
    })
    TravelSection:AddButton({
        Name = "Go Home",
        Callback = function()
            goHome("home")
        end,
    })
    TravelSection:AddButton({
        Name = "Go to Plot",
        Callback = function()
            goHome("plot")
        end,
    })
    TravelSection:AddToggle({
        Name = "Walk Speed Override",
        Flag = "mam_walk_speed_enabled",
        Default = false,
        Callback = function(enabled)
            state.WalkSpeedEnabled = enabled
        end,
    })
    TravelSection:AddSlider({
        Name = "Walk Speed",
        Flag = "mam_walk_speed",
        Min = 16,
        Max = 80,
        Step = 1,
        Default = 24,
        Callback = function(value)
            state.WalkSpeed = tonumber(value) or 24
        end,
    })

    RewardSection:AddToggle({
        Name = "Auto Claim Available Rewards",
        Flag = "mam_auto_rewards",
        Default = false,
        Callback = function(enabled)
            state.AutoRewards = enabled
        end,
    })
    RewardSection:AddButton({
        Name = "Claim Available Rewards",
        Callback = function()
            task.spawn(claimRewards, true)
        end,
    })
    RewardSection:AddLabel("Group and tutorial rewards are still validated by the game server.")

    SafetySection:AddToggle({
        Name = "Freeze Guard",
        Description = "Returns to safety before the exposure bar finishes murdering you",
        Flag = "mam_freeze_guard",
        Default = true,
        Callback = function(enabled)
            state.FreezeGuard = enabled
        end,
    })
    SafetySection:AddToggle({
        Name = "Anti AFK",
        Flag = "mam_anti_afk",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })
    SafetySection:AddButton({
        Name = "Emergency Return Home",
        Callback = function()
            goHome("home")
        end,
    })

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.identity)
                task.wait(0.05)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.identity)
            end)
        end
    end))

    task.spawn(function()
        while state.Alive do
            local farmEnabled = state.Master or state.AutoFarm
            if farmEnabled then
                local weight = cargo()
                local cap = capacity()
                local currentAir = tonumber(statValue("CurrentAir", 0)) or 0
                local airCapacity = math.max(1, tonumber(statValue("AirCapacity", 1)) or 1)
                -- FreezeExposure rises while the player recovers at base and
                -- IsFreezing only means the cold zone is active. CurrentAir is
                -- the server-replicated danger signal that actually counts down.
                local mustEscape = state.FreezeGuard
                    and currentAir <= math.max(1, airCapacity * 0.12)
                local shouldSell = (state.Master or state.AutoSell)
                    and weight > 0
                    and (cap < math.huge and weight >= cap * (state.SellPercent / 100))

                if mustEscape then
                    state.Phase = "Freeze guard returning"
                    if weight > 0 then
                        sellCargo(false)
                        runPurchases()
                    else
                        goHome("home")
                        task.wait(0.8)
                    end
                elseif shouldSell then
                    if sellCargo(false) then
                        runPurchases()
                    end
                else
                    local target, targetError = chooseTarget()
                    if target then
                        local ok, mineError = mineTarget(target)
                        if not ok then
                            state.LastError = tostring(mineError)
                            task.wait(math.min(1.5, 0.2 + state.ConsecutiveFailures * 0.15))
                        end
                    elseif (state.Master or state.AutoSell) and weight > 0 then
                        if sellCargo(false) then
                            runPurchases()
                        end
                    else
                        state.Phase = "Waiting for crystals"
                        state.LastError = tostring(targetError or "No available crystals")
                        task.wait(0.5)
                    end
                end
            else
                state.Target = nil
                state.TargetName = "None"
                if state.Phase:find("Traveling", 1, true) or state.Phase:find("Mining", 1, true) then
                    state.Phase = "Idle"
                end
                task.wait(0.2)
            end
            state.LastFarmCycle = os.clock()
            task.wait(0.08)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            if (state.Master or state.AutoRewards) and now - state.LastReward >= 15 then
                claimRewards(false)
            end
            task.wait(1)
        end
    end)

    track(RunService.Heartbeat:Connect(function()
        if not state.Alive then
            return
        end
        local _, humanoid = characterParts()
        if humanoid then
            if state.OriginalWalkSpeed == nil then
                state.OriginalWalkSpeed = humanoid.WalkSpeed
            end
            if state.WalkSpeedEnabled then
                humanoid.WalkSpeed = state.WalkSpeed
            end
        end

        local now = os.clock()
        if now - state.LastStatus < 0.15 then
            return
        end
        state.LastStatus = now
        local weight, count, heldValue = cargo()
        local cap = capacity()
        local cash = getCash()
        local pickaxe, power = bestPickaxe()
        local exposure = tonumber(LocalPlayer:GetAttribute("FreezeExposure")) or 0
        local warmth = tonumber(statValue("AirCapacity", 0)) or 0

        phaseLabel.Text = "Phase: " .. state.Phase
        targetLabel.Text = "Target: " .. state.TargetName
        backpackLabel.Text = cap == math.huge
            and string.format("Backpack: %.1f / infinite kg", weight)
            or string.format("Backpack: %.1f / %.1f kg", weight, cap)
        saleLabel.Text = "Last sale: $" .. tostring(math.floor(state.LastSale))
        cashLabel.Text = "Cash: $" .. tostring(math.floor(cash))
        heightLabel.Text = string.format(
            "Height: %sm | Best: %sm",
            tostring(statValue("Height", 0)),
            tostring(statValue("Best", 0))
        )
        warmthLabel.Text = string.format("Warmth: %s | Exposure: %.0f%%", tostring(warmth), exposure * 100)
        equipmentLabel.Text = string.format("Pickaxe: %s | Power: %.1f", pickaxe and pickaxe.Name or "None", power)
        cargoLabel.Text = string.format("Cargo: %d crystal(s) | $%d", count, math.floor(heldValue))
        adapterLabel.Text = string.format(
            "Adapter: %s | Mode: %s",
            promptFunction() and "prompt ready" or "prompt fallback",
            state.Master and "Full OP" or (state.AutoFarm and "Auto Mine" or "Idle")
        )
        errorLabel.Text = "Last error: " .. state.LastError
        errorLabel.TextColor3 = state.LastError == "None" and COLORS.success or COLORS.warning
        purchaseLabel.Text = "Last purchase: $" .. tostring(math.floor(state.LastPurchase))
        remoteLabel.Text = string.format(
            "Server remotes: %s | Place: %s",
            Remotes:FindFirstChild("SellRequest") and "Ready" or "Missing",
            tostring(game.PlaceId)
        )

        local target = state.Target
        targetHighlight.Adornee = target and target.Parent and target or nil
        targetHighlight.Enabled = targetHighlight.Adornee ~= nil

        pcall(function()
            gui:SetAttribute("MineAMountainAdapter", true)
            gui:SetAttribute("MineAMountainPhase", state.Phase)
            gui:SetAttribute("MineAMountainTarget", state.TargetName)
            gui:SetAttribute("MineAMountainCash", cash)
            gui:SetAttribute("MineAMountainCargoWeight", weight)
            gui:SetAttribute("MineAMountainCargoValue", heldValue)
            gui:SetAttribute("MineAMountainCapacity", cap)
            gui:SetAttribute("MineAMountainLastError", state.LastError)
        end)
    end))

    track(gui.Destroying:Connect(function()
        state.Alive = false
        local character, humanoid = characterParts()
        setTravelCollision(character, false)
        if humanoid and state.OriginalWalkSpeed then
            humanoid.WalkSpeed = state.OriginalWalkSpeed
        end
        targetHighlight:Destroy()
    end))

    pcall(function()
        gui:SetAttribute("MineAMountainAdapter", true)
        gui:SetAttribute("MineAMountainUniverseId", 10187294555)
        gui:SetAttribute("MineAMountainPlaceId", 125927821145949)
        gui:SetAttribute("MineAMountainCreditedLoop", "CrystalPrompt>SellRequest>ShopBuy>UpgradeBuy")
    end)
end
