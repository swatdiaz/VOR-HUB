-- VOR Hub - Bee Swarm Simulator adapter.
-- Universe 601130232 / root place 1537690962.
--
-- The adapter drives the experience's native client modules and credited
-- requests. Farming still moves the real character through fields and tokens;
-- it does not fabricate pollen, honey, quest progress, or inventory values.

return function(context)
    local Window = assert(context.Window, "Bee Swarm: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Bee Swarm: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    local Events = require(ReplicatedStorage:WaitForChild("Events"))
    local ClientStatCache = require(ReplicatedStorage:WaitForChild("ClientStatCache"))
    local LocalCollect = require(ReplicatedStorage:WaitForChild("Collectors"):WaitForChild("LocalCollect"))
    local Hives = require(ReplicatedStorage:WaitForChild("Activatables"):WaitForChild("Hives"))
    local NPCActivator = require(ReplicatedStorage.Activatables:WaitForChild("NPCs"))
    local ToyActivator = require(ReplicatedStorage.Activatables:WaitForChild("Toys"))
    local HoneycombTools = require(ReplicatedStorage:WaitForChild("HoneycombTools"))

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmingPage = addHomeCategory("Farming", 1, CATEGORY_DECALS.Progress or CATEGORY_DECALS.Overnight)
    local QuestPage = addHomeCategory("Quests", 2, CATEGORY_DECALS.Overnight or CATEGORY_DECALS.Progress)
    local ProgressPage = addHomeCategory("Progression", 3, CATEGORY_DECALS.Weapons or CATEGORY_DECALS.Progress)
    local UtilityPage = addHomeCategory("Utilities", 4, CATEGORY_DECALS.Player)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Visuals)
    selectHomeCategory("Farming")

    local MainSection = FarmingPage:AddSection("Full OP Bee Farm", "Left")
    local FieldSection = FarmingPage:AddSection("Field Targeting", "Right")
    local TokenSection = FarmingPage:AddSection("Tokens and Sprinklers", "Right")
    local QuestSection = QuestPage:AddSection("Native Quest Dialogue", "Left")
    local QuestInfoSection = QuestPage:AddSection("Quest Safety", "Right")
    local UpgradeSection = ProgressPage:AddSection("Equipment Progression", "Left")
    local HiveSection = ProgressPage:AddSection("Hive Progression", "Right")
    local ToySection = UtilityPage:AddSection("Toys and Dispensers", "Left")
    local SafetySection = UtilityPage:AddSection("Movement and Safety", "Right")
    local StatSection = StatusPage:AddSection("Live Account", "Left")
    local AdapterSection = StatusPage:AddSection("Adapter State", "Right")

    local FIELD_NAMES = {
        "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field", "Clover Field",
        "Strawberry Field", "Bamboo Field", "Spider Field", "Pineapple Patch", "Pumpkin Patch", "Cactus Field",
        "Rose Field", "Pine Tree Forest", "Stump Field", "Mountain Top Field", "Coconut Field", "Pepper Patch",
    }
    local QUEST_GIVERS = {
        "Black Bear", "Brown Bear", "Mother Bear", "Panda Bear", "Science Bear",
        "Polar Bear", "Riley Bee", "Bucko Bee", "Honey Bee", "Onett",
        "Spirit Bear", "Dapper Bear",
    }
    local TOY_NAMES = {
        "Honey Dispenser", "Treat Dispenser", "Free Ant Pass Dispenser",
        "Blueberry Dispenser", "Strawberry Dispenser", "Royal Jelly Dispenser",
        "Blue Field Booster", "Red Field Booster", "Wealth Clock",
    }
    local COLLECTOR_ORDER = {
        "Scooper", "Rake", "Magnet", "Vacuum", "Super-Scooper", "Pulsar",
        "Electro-Magnet", "Scissors", "Honey Dipper", "Bubble Wand", "Scythe",
        "Golden Rake", "Spark Staff", "Porcelain Dipper",
    }
    local BACKPACK_ORDER = {
        "Pouch", "Jar", "Backpack", "Canister", "Mega-Jug", "Compressor",
        "Elite Barrel", "Port-O-Hive", "Blue Port-O-Hive", "Red Port-O-Hive",
        "Porcelain Port-O-Hive", "Coconut Canister",
    }

    local state = {
        Alive = true,
        FullOP = false,
        AutoFarm = false,
        AutoConvert = true,
        AutoClaimHive = true,
        AutoHatchStarter = true,
        AutoTokens = true,
        AutoSprinkler = false,
        AutoQuest = false,
        AutoCollector = false,
        AutoBackpack = false,
        AutoToy = false,
        AntiAfk = true,
        NoClip = true,
        Field = "Sunflower Field",
        Pattern = "Wide Circle",
        QuestGiver = "Black Bear",
        Toy = "Honey Dispenser",
        ConvertAt = 90,
        TravelSpeed = 180,
        TokenRadius = 75,
        FieldRadius = 0.72,
        Phase = "Initializing",
        LastError = "None",
        Target = "None",
        OwnedHive = nil,
        Collecting = false,
        Traveling = false,
        ConversionStarted = false,
        LastQuest = 0,
        LastToy = 0,
        LastUpgrade = 0,
        LastSprinkler = 0,
        LastHatch = 0,
        LastStatus = 0,
        HoneySample = 0,
        PollenSample = 0,
        SampleAt = os.clock(),
        HoneyRate = 0,
        PollenRate = 0,
        OriginalCollision = setmetatable({}, {__mode = "k"}),
    }

    local phaseLabel = AdapterSection:AddLabel("Phase: Initializing")
    local targetLabel = AdapterSection:AddLabel("Target: None")
    local errorLabel = AdapterSection:AddLabel("Last error: None")
    local routeLabel = AdapterSection:AddLabel("Credited route: Resolving native modules")
    local honeyLabel = StatSection:AddLabel("Honey: 0")
    local pollenLabel = StatSection:AddLabel("Pollen: 0 / 0")
    local equipmentLabel = StatSection:AddLabel("Collector: Reading | Backpack: Reading")
    local hiveLabel = StatSection:AddLabel("Hive: Unclaimed")
    local rateLabel = StatSection:AddLabel("Rates: 0 pollen/min | 0 honey/min")

    local function notify(title, message, duration)
        pcall(function()
            Window:Notify(tostring(title), tostring(message), duration or 3)
        end)
    end

    local function setError(message)
        state.LastError = tostring(message or "Unknown error")
        errorLabel.Text = "Last error: " .. state.LastError
    end

    local function formatNumber(value)
        value = tonumber(value) or 0
        local absolute = math.abs(value)
        if absolute >= 1e12 then
            return string.format("%.2fT", value / 1e12)
        elseif absolute >= 1e9 then
            return string.format("%.2fB", value / 1e9)
        elseif absolute >= 1e6 then
            return string.format("%.2fM", value / 1e6)
        elseif absolute >= 1e3 then
            return string.format("%.1fK", value / 1e3)
        end
        return tostring(math.floor(value + 0.5))
    end

    local function stats()
        local ok, result = pcall(function()
            return ClientStatCache:Get()
        end)
        return ok and type(result) == "table" and result or {}
    end

    local function coreStat(name, fallback)
        local core = LocalPlayer:FindFirstChild("CoreStats")
        local value = core and core:FindFirstChild(name)
        if value and value:IsA("ValueBase") then
            return tonumber(value.Value) or fallback
        end
        local cached = stats()
        return tonumber(cached[name]) or fallback
    end

    local function characterParts()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        return character, humanoid, root
    end

    local function setTravelCollision(character, enabled)
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if enabled then
                    if state.OriginalCollision[part] ~= nil then
                        part.CanCollide = state.OriginalCollision[part]
                        state.OriginalCollision[part] = nil
                    end
                else
                    if state.OriginalCollision[part] == nil then
                        state.OriginalCollision[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end
    end

    local function travelTo(goal, label)
        local waitDeadline = os.clock() + 15
        while state.Alive and state.Traveling and os.clock() < waitDeadline do
            task.wait(0.05)
        end
        if state.Traveling then
            return false, "Travel controller is busy"
        end
        local character, humanoid, root = characterParts()
        if not (character and humanoid and root and humanoid.Health > 0) then
            return false, "Character is unavailable"
        end
        local goalCFrame = typeof(goal) == "CFrame" and goal or CFrame.new(goal)
        local distance = (root.Position - goalCFrame.Position).Magnitude
        state.Traveling = true
        state.Target = label or "Position"
        state.Phase = "Traveling"
        if state.NoClip then
            setTravelCollision(character, false)
        end
        local tween = TweenService:Create(
            root,
            TweenInfo.new(math.max(0.05, distance / math.max(40, state.TravelSpeed)), Enum.EasingStyle.Linear),
            {CFrame = goalCFrame}
        )
        tween:Play()
        local completed = false
        local connection
        connection = tween.Completed:Connect(function()
            completed = true
            if connection then
                connection:Disconnect()
            end
        end)
        local started = os.clock()
        while state.Alive and not completed and os.clock() - started < math.max(2, distance / 35 + 3) do
            if not root.Parent or humanoid.Health <= 0 then
                break
            end
            RunService.Heartbeat:Wait()
        end
        tween:Cancel()
        if connection then
            connection:Disconnect()
        end
        if root.Parent and (root.Position - goalCFrame.Position).Magnitude > 12 then
            for _ = 1, 3 do
                character:PivotTo(goalCFrame)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.12)
                if (root.Position - goalCFrame.Position).Magnitude <= 12 then
                    break
                end
            end
        end
        state.Traveling = false
        if state.NoClip then
            setTravelCollision(character, true)
        end
        return root.Parent ~= nil and (root.Position - goalCFrame.Position).Magnitude <= 12,
            "Travel did not reach " .. tostring(label or "target")
    end

    local function findField(name)
        local zones = workspace:FindFirstChild("FlowerZones")
        return zones and zones:FindFirstChild(name)
    end

    local function fieldPoint(zone, step)
        if not zone or not zone:IsA("BasePart") then
            return nil
        end
        local radiusX = math.max(4, zone.Size.X * 0.5 * state.FieldRadius)
        local radiusZ = math.max(4, zone.Size.Z * 0.5 * state.FieldRadius)
        local y = zone.Size.Y * 0.5 + 3.2
        local angle = step * 0.72
        local localPoint
        if state.Pattern == "Zigzag" then
            local row = step % 8
            local lane = math.floor(step / 8) % 5
            localPoint = Vector3.new((row / 7 - 0.5) * radiusX * 2, y, (lane / 4 - 0.5) * radiusZ * 2)
        elseif state.Pattern == "Tight Circle" then
            localPoint = Vector3.new(math.cos(angle) * radiusX * 0.45, y, math.sin(angle) * radiusZ * 0.45)
        else
            localPoint = Vector3.new(math.cos(angle) * radiusX, y, math.sin(angle) * radiusZ)
        end
        return zone.CFrame:PointToWorldSpace(localPoint)
    end

    local function ownedHive()
        local platforms = workspace:FindFirstChild("HivePlatforms")
        if not platforms then
            return nil
        end
        for _, platform in ipairs(platforms:GetChildren()) do
            local playerRef = platform:FindFirstChild("PlayerRef")
            if playerRef and playerRef.Value == LocalPlayer then
                state.OwnedHive = platform
                return platform
            end
        end
        state.OwnedHive = nil
        return nil
    end

    local function hivePosition(platform)
        local part = platform and platform:FindFirstChild("Platform")
        return part and (part.CFrame + Vector3.new(0, 4, 0)) or nil
    end

    local function claimHive()
        local existing = ownedHive()
        if existing then
            return true, existing
        end
        local platforms = workspace:FindFirstChild("HivePlatforms")
        if not platforms then
            return false, "HivePlatforms is unavailable"
        end
        local free
        for _, platform in ipairs(platforms:GetChildren()) do
            local playerRef = platform:FindFirstChild("PlayerRef")
            if not playerRef or playerRef.Value == nil then
                free = platform
                break
            end
        end
        if not free then
            return false, "No free hive is available"
        end
        local goal = hivePosition(free)
        if goal then
            travelTo(goal, "Free hive")
        end
        local ok, err = pcall(Hives.ButtonEffect, LocalPlayer, free)
        if not ok then
            return false, err
        end
        local deadline = os.clock() + 6
        repeat
            task.wait(0.2)
            existing = ownedHive()
        until existing or os.clock() >= deadline
        return existing ~= nil, existing or "Hive claim was not credited"
    end

    local function findStarterCell()
        for x = 1, 5 do
            for y = 1, 10 do
                local ok, cell = pcall(HoneycombTools.GetLocalPlayerCell, x, y)
                if ok and cell and not cell.Locked then
                    local cellType = cell.Type
                    if cell.Body and cell.Body:FindFirstChild("CellType") then
                        cellType = cell.Body.CellType.Value
                    end
                    if cellType == nil or cellType == "Empty" then
                        return x, y, cell
                    end
                end
            end
        end
        return nil
    end

    local function hatchStarterBee()
        local cached = stats()
        local eggs = cached.Eggs or {}
        if (tonumber(eggs.Basic) or 0) <= 0 then
            return false, "No Basic Egg available"
        end
        local x, y = findStarterCell()
        if not x then
            return false, "No unlocked empty hive cell"
        end
        local remaining, success, honeycomb, discovered, eggUses = Events.ClientCall(
            "ConstructHiveCellFromEgg",
            x,
            y,
            "Basic",
            1,
            false,
            nil
        )
        if success then
            ClientStatCache:Set({"Eggs", "Basic"}, remaining)
            ClientStatCache:Set("DiscoveredBees", discovered)
            ClientStatCache:Set("Honeycomb", honeycomb)
            ClientStatCache:Set({"Totals", "EggUses"}, eggUses)
            pcall(function()
                require(ReplicatedStorage:WaitForChild("GateManager")).UpdateGateColors()
            end)
        end
        state.LastHatch = os.clock()
        return success == true, success == true and "Starter bee hatched" or "Starter egg was not accepted"
    end

    local function beginCollection()
        if state.Collecting then
            return true
        end
        local ok, err = pcall(LocalCollect.StartCollection)
        if ok then
            state.Collecting = true
            return true
        end
        setError("Collector start: " .. tostring(err))
        return false
    end

    local function stopCollection()
        if not state.Collecting then
            return
        end
        pcall(LocalCollect.StopCollection)
        state.Collecting = false
    end

    local function tokenPosition(token)
        if not token or not token.Parent then
            return nil
        end
        if token:IsA("BasePart") then
            return token.Position
        end
        local part = token:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end

    local function nearestToken(zone)
        if not state.AutoTokens then
            return nil
        end
        local folder = workspace:FindFirstChild("Collectibles")
        local _, _, root = characterParts()
        if not (folder and root) then
            return nil
        end
        local best, bestDistance
        for _, token in ipairs(folder:GetChildren()) do
            local position = tokenPosition(token)
            if position then
                local distance = (position - root.Position).Magnitude
                local inField = not zone or (Vector3.new(position.X, zone.Position.Y, position.Z) - zone.Position).Magnitude
                    <= math.max(zone.Size.X, zone.Size.Z) * 0.8
                if inField and distance <= state.TokenRadius and (not bestDistance or distance < bestDistance) then
                    best = token
                    bestDistance = distance
                end
            end
        end
        return best
    end

    local function collectToken(token)
        local position = tokenPosition(token)
        if not position then
            return false
        end
        state.Phase = "Collecting token"
        local ok = travelTo(CFrame.new(position + Vector3.new(0, 2.2, 0)), "Token")
        local _, _, root = characterParts()
        if ok and root and token.Parent and type(firetouchinterest) == "function" then
            local part = token:IsA("BasePart") and token or token:FindFirstChildWhichIsA("BasePart", true)
            if part then
                pcall(firetouchinterest, root, part, 0)
                pcall(firetouchinterest, root, part, 1)
            end
        end
        return ok
    end

    local function placeSprinkler()
        local cached = stats()
        if tostring(cached.EquippedSprinkler or "None") == "None" then
            return false, "No sprinkler equipped"
        end
        local ok, result = pcall(Events.ClientCall, "PlayerSprinklerCommand", "Place")
        state.LastSprinkler = os.clock()
        return ok and result ~= false, result
    end

    local function convertPollen()
        stopCollection()
        local hive = ownedHive()
        if not hive then
            local claimed, result = claimHive()
            if not claimed then
                return false, result
            end
            hive = result
        end
        local goal = hivePosition(hive)
        if goal then
            local reached, err = travelTo(goal, "Owned hive")
            if not reached then
                return false, err
            end
        end
        state.Phase = "Converting pollen"
        local ok, err = pcall(Hives.ButtonEffect, LocalPlayer, hive)
        if not ok then
            return false, err
        end
        state.ConversionStarted = true
        local deadline = os.clock() + 120
        while state.Alive and (state.FullOP or state.AutoFarm) and coreStat("Pollen", 0) > 0 and os.clock() < deadline do
            task.wait(0.35)
        end
        state.ConversionStarted = false
        return coreStat("Pollen", 0) <= 0, "Conversion timed out"
    end

    local function findNPC(name)
        local folder = workspace:FindFirstChild("NPCs")
        return folder and folder:FindFirstChild(name)
    end

    local function talkToNPC(name)
        local npc = findNPC(name)
        if not npc then
            return false, name .. " is not streamed or unlocked"
        end
        local platform = npc:FindFirstChild("Platform", true) or npc:FindFirstChildWhichIsA("BasePart", true)
        if platform then
            local reached, err = travelTo(platform.CFrame + Vector3.new(0, 3, 0), name)
            if not reached then
                return false, err
            end
        end
        state.Traveling = true
        state.Phase = "Talking to " .. name
        local ok, err = pcall(NPCActivator.ButtonEffect, LocalPlayer, npc)
        if not ok then
            state.Traveling = false
            return false, err
        end
        task.wait(0.25)
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local camera = playerGui and playerGui:FindFirstChild("Camera")
        local controller = camera and camera:FindFirstChild("Controllers") and camera.Controllers:FindFirstChild("NPC")
        local active = controller and controller:FindFirstChild("ActiveNPC")
        local increment = controller and controller:FindFirstChild("IncrementDialogue")
        local turns = 0
        while state.Alive and active and active.Value and turns < 80 do
            turns += 1
            if increment and increment:IsA("BindableFunction") then
                pcall(function()
                    increment:Invoke()
                end)
            elseif increment and increment:IsA("BindableEvent") then
                increment:Fire()
            else
                break
            end
            task.wait(0.08)
        end
        state.Traveling = false
        state.LastQuest = os.clock()
        return turns > 0, turns > 0 and ("Finished " .. name .. " dialogue") or "Dialogue controller did not open"
    end

    local function useToy(name)
        local toys = workspace:FindFirstChild("Toys")
        local toy = toys and toys:FindFirstChild(name)
        if not toy then
            return false, name .. " is unavailable"
        end
        local platform = toy:FindFirstChild("Platform", true)
            or toy:FindFirstChild("Button", true)
            or toy:FindFirstChildWhichIsA("BasePart", true)
        if platform then
            local reached, err = travelTo(platform.CFrame + Vector3.new(0, 3, 0), name)
            if not reached then
                return false, err
            end
        end
        local ok, result = pcall(ToyActivator.ButtonEffect, LocalPlayer, toy)
        state.LastToy = os.clock()
        return ok, ok and ("Used " .. name) or result
    end

    local function itemIndex(order, name)
        for index, item in ipairs(order) do
            if item == name then
                return index
            end
        end
        return 0
    end

    local function buyNext(order, equipped)
        local start = math.max(1, itemIndex(order, equipped) + 1)
        for index = start, #order do
            local item = order[index]
            local ok = pcall(Events.ClientCall, "PlayerPurchase", item)
            task.wait(0.2)
            local cached = stats()
            local changed = tostring(cached.EquippedCollector or "") == item
                or tostring(cached.EquippedBackpack or "") == item
            if ok and changed then
                state.LastUpgrade = os.clock()
                return true, item
            end
        end
        state.LastUpgrade = os.clock()
        return false, "No affordable unlocked upgrade"
    end

    local function buyCollector()
        local cached = stats()
        return buyNext(COLLECTOR_ORDER, tostring(cached.EquippedCollector or "Scooper"))
    end

    local function buyBackpack()
        local cached = stats()
        return buyNext(BACKPACK_ORDER, tostring(cached.EquippedBackpack or "Pouch"))
    end

    local function farmStep(step)
        local zone = findField(state.Field)
        if not zone then
            return false, "Field is unavailable: " .. state.Field
        end
        state.Target = state.Field
        local token = nearestToken(zone)
        if token then
            collectToken(token)
        else
            local point = fieldPoint(zone, step)
            if point then
                local reached, err = travelTo(CFrame.new(point), state.Field)
                if not reached then
                    return false, err
                end
            end
        end
        beginCollection()
        if state.AutoSprinkler and os.clock() - state.LastSprinkler >= 30 then
            placeSprinkler()
        end
        state.Phase = "Farming " .. state.Field
        return true
    end

    MainSection:AddToggle({
        Name = "Full OP Bee Loop",
        Description = "Claims a hive, hatches the starter bee, farms, collects tokens, converts, quests, and upgrades",
        Flag = "bee_full_op_loop",
        Default = false,
        Callback = function(enabled)
            state.FullOP = enabled
            state.Phase = enabled and "Starting full loop" or "Idle"
        end,
    })
    MainSection:AddToggle({
        Name = "Auto Farm Field",
        Flag = "bee_auto_farm",
        Default = false,
        Callback = function(enabled)
            state.AutoFarm = enabled
            if not enabled and not state.FullOP then
                stopCollection()
            end
        end,
    })
    MainSection:AddToggle({
        Name = "Auto Convert Honey",
        Flag = "bee_auto_convert",
        Default = true,
        Callback = function(enabled)
            state.AutoConvert = enabled
        end,
    })
    MainSection:AddSlider({
        Name = "Convert At Backpack",
        Flag = "bee_convert_percent",
        Min = 40,
        Max = 100,
        Step = 1,
        Default = 90,
        Suffix = "%",
        Callback = function(value)
            state.ConvertAt = tonumber(value) or 90
        end,
    })
    MainSection:AddButton({
        Name = "Convert Backpack Now",
        Callback = function()
            task.spawn(function()
                local ok, message = convertPollen()
                notify("Bee Farm", ok and "Backpack converted" or message)
            end)
        end,
    })

    FieldSection:AddDropdown({
        Name = "Field",
        Flag = "bee_selected_field",
        Options = FIELD_NAMES,
        Default = "Sunflower Field",
        Callback = function(value)
            state.Field = tostring(value or "Sunflower Field")
        end,
    })
    FieldSection:AddDropdown({
        Name = "Farm Pattern",
        Flag = "bee_farm_pattern",
        Options = {"Wide Circle", "Tight Circle", "Zigzag"},
        Default = "Wide Circle",
        Callback = function(value)
            state.Pattern = value or "Wide Circle"
        end,
    })
    FieldSection:AddSlider({
        Name = "Tween Speed",
        Flag = "bee_tween_speed",
        Min = 60,
        Max = 500,
        Step = 10,
        Default = 180,
        Suffix = " studs/s",
        Callback = function(value)
            state.TravelSpeed = tonumber(value) or 180
        end,
    })
    FieldSection:AddSlider({
        Name = "Field Coverage",
        Flag = "bee_field_coverage",
        Min = 35,
        Max = 90,
        Step = 1,
        Default = 72,
        Suffix = "%",
        Callback = function(value)
            state.FieldRadius = math.clamp((tonumber(value) or 72) / 100, 0.35, 0.9)
        end,
    })

    TokenSection:AddToggle({
        Name = "Auto Collect Tokens",
        Description = "Moves through nearby field tokens so the server credits the pickup",
        Flag = "bee_auto_tokens",
        Default = true,
        Callback = function(enabled)
            state.AutoTokens = enabled
        end,
    })
    TokenSection:AddSlider({
        Name = "Token Search Radius",
        Flag = "bee_token_radius",
        Min = 20,
        Max = 250,
        Step = 5,
        Default = 75,
        Suffix = " studs",
        Callback = function(value)
            state.TokenRadius = tonumber(value) or 75
        end,
    })
    TokenSection:AddToggle({
        Name = "Auto Place Sprinkler",
        Flag = "bee_auto_sprinkler",
        Default = false,
        Callback = function(enabled)
            state.AutoSprinkler = enabled
        end,
    })

    QuestSection:AddToggle({
        Name = "Auto Quest Pickup + Turn-In",
        Description = "Uses the game's NPC controller and advances the real dialogue",
        Flag = "bee_auto_quests",
        Default = false,
        Callback = function(enabled)
            state.AutoQuest = enabled
        end,
    })
    QuestSection:AddDropdown({
        Name = "Quest Giver",
        Flag = "bee_quest_giver",
        Options = QUEST_GIVERS,
        Default = "Black Bear",
        Callback = function(value)
            state.QuestGiver = tostring(value or "Black Bear")
        end,
    })
    QuestSection:AddButton({
        Name = "Talk to Selected NPC Now",
        Callback = function()
            task.spawn(function()
                local ok, message = talkToNPC(state.QuestGiver)
                notify("Quests", message)
                if not ok then
                    setError(message)
                end
            end)
        end,
    })
    QuestInfoSection:AddLabel("VOR only advances dialogue the game actually opens.")
    QuestInfoSection:AddLabel("Locked NPCs and unfinished objectives stay server-controlled.")

    UpgradeSection:AddToggle({
        Name = "Auto Buy Next Collector",
        Flag = "bee_auto_collector",
        Default = false,
        Callback = function(enabled)
            state.AutoCollector = enabled
        end,
    })
    UpgradeSection:AddToggle({
        Name = "Auto Buy Next Backpack",
        Flag = "bee_auto_backpack",
        Default = false,
        Callback = function(enabled)
            state.AutoBackpack = enabled
        end,
    })
    UpgradeSection:AddButton({
        Name = "Buy Next Collector",
        Callback = function()
            local ok, message = buyCollector()
            notify("Progression", ok and ("Purchased " .. message) or message)
        end,
    })
    UpgradeSection:AddButton({
        Name = "Buy Next Backpack",
        Callback = function()
            local ok, message = buyBackpack()
            notify("Progression", ok and ("Purchased " .. message) or message)
        end,
    })

    HiveSection:AddToggle({
        Name = "Auto Claim Free Hive",
        Flag = "bee_auto_claim_hive",
        Default = true,
        Callback = function(enabled)
            state.AutoClaimHive = enabled
        end,
    })
    HiveSection:AddToggle({
        Name = "Auto Hatch Starter Egg",
        Flag = "bee_auto_hatch_starter",
        Default = true,
        Callback = function(enabled)
            state.AutoHatchStarter = enabled
        end,
    })
    HiveSection:AddButton({
        Name = "Claim Hive + Hatch Starter",
        Callback = function()
            task.spawn(function()
                local claimed, result = claimHive()
                if not claimed then
                    notify("Hive", result)
                    return
                end
                task.wait(0.5)
                local hatched, message = hatchStarterBee()
                notify("Hive", hatched and "Hive ready" or message)
            end)
        end,
    })

    ToySection:AddToggle({
        Name = "Auto Use Selected Toy",
        Flag = "bee_auto_toy",
        Default = false,
        Callback = function(enabled)
            state.AutoToy = enabled
        end,
    })
    ToySection:AddDropdown({
        Name = "Toy / Dispenser",
        Flag = "bee_selected_toy",
        Options = TOY_NAMES,
        Default = "Honey Dispenser",
        Callback = function(value)
            state.Toy = tostring(value or "Honey Dispenser")
        end,
    })
    ToySection:AddButton({
        Name = "Use Selected Toy Now",
        Callback = function()
            task.spawn(function()
                local ok, message = useToy(state.Toy)
                notify("Utilities", message)
                if not ok then
                    setError(message)
                end
            end)
        end,
    })

    SafetySection:AddToggle({
        Name = "No Clip During VOR Travel",
        Flag = "bee_travel_noclip",
        Default = true,
        Callback = function(enabled)
            state.NoClip = enabled
        end,
    })
    SafetySection:AddToggle({
        Name = "Anti AFK",
        Flag = "bee_anti_afk",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })
    SafetySection:AddButton({
        Name = "Stop Every Bee Automation",
        Callback = function()
            state.FullOP = false
            state.AutoFarm = false
            state.AutoQuest = false
            state.AutoToy = false
            stopCollection()
            state.Phase = "Stopped"
            notify("Bee Swarm", "All Bee Swarm automation stopped")
        end,
    })

    routeLabel.Text = "Credited route: ToolCollect > token touch > hive conversion"

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            pcall(function()
                local camera = workspace.CurrentCamera
                VirtualUser:Button2Down(Vector2.zero, camera and camera.CFrame or CFrame.identity)
                task.wait(0.05)
                VirtualUser:Button2Up(Vector2.zero, camera and camera.CFrame or CFrame.identity)
            end)
        end
    end))

    task.spawn(function()
        local step = 0
        while state.Alive do
            local enabled = state.FullOP or state.AutoFarm
            if enabled and state.Traveling then
                task.wait(0.1)
            elseif enabled then
                if state.AutoClaimHive and not ownedHive() then
                    state.Phase = "Claiming hive"
                    local ok, message = claimHive()
                    if not ok then
                        setError(message)
                        task.wait(1)
                    end
                end
                if state.AutoHatchStarter and ownedHive() and os.clock() - state.LastHatch >= 5 then
                    local cached = stats()
                    local eggs = cached.Eggs or {}
                    if (tonumber(eggs.Basic) or 0) > 0 then
                        local ok, message = hatchStarterBee()
                        if not ok and message ~= "No unlocked empty hive cell" then
                            setError(message)
                        end
                    end
                end
                local pollen = coreStat("Pollen", 0)
                local capacity = math.max(1, coreStat("Capacity", 1))
                if state.AutoConvert and pollen >= capacity * (state.ConvertAt / 100) then
                    local ok, message = convertPollen()
                    if not ok then
                        setError(message)
                        task.wait(0.5)
                    end
                else
                    step += 1
                    local ok, message = farmStep(step)
                    if not ok then
                        setError(message)
                        task.wait(0.35)
                    else
                        state.LastError = "None"
                    end
                end
            else
                stopCollection()
                if state.Phase:find("Farming", 1, true) or state.Phase == "Traveling" then
                    state.Phase = "Idle"
                end
                task.wait(0.2)
            end
            task.wait(0.08)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            if (state.FullOP or state.AutoQuest)
                and now - state.LastQuest >= 45
                and not state.Traveling
                and not state.ConversionStarted then
                local ok, message = talkToNPC(state.QuestGiver)
                if not ok then
                    setError(message)
                end
            end
            if state.AutoToy
                and now - state.LastToy >= 60
                and not state.Traveling
                and not state.ConversionStarted then
                local ok, message = useToy(state.Toy)
                if not ok then
                    setError(message)
                end
            end
            task.wait(1)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            if now - state.LastUpgrade >= 12 and not state.Traveling then
                if state.FullOP or state.AutoCollector then
                    buyCollector()
                end
                if state.FullOP or state.AutoBackpack then
                    buyBackpack()
                end
            end
            task.wait(1)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            local cached = stats()
            local honey = coreStat("Honey", tonumber(cached.Honey) or 0)
            local pollen = coreStat("Pollen", tonumber(cached.Pollen) or 0)
            local capacity = coreStat("Capacity", 0)
            local elapsed = math.max(0.1, now - state.SampleAt)
            if elapsed >= 5 then
                state.HoneyRate = math.max(0, honey - state.HoneySample) * 60 / elapsed
                state.PollenRate = math.max(0, pollen - state.PollenSample) * 60 / elapsed
                state.HoneySample = honey
                state.PollenSample = pollen
                state.SampleAt = now
            end
            local hive = ownedHive()
            honeyLabel.Text = "Honey: " .. formatNumber(honey)
            pollenLabel.Text = "Pollen: " .. formatNumber(pollen) .. " / " .. formatNumber(capacity)
            equipmentLabel.Text = "Collector: " .. tostring(cached.EquippedCollector or "None")
                .. " | Backpack: " .. tostring(cached.EquippedBackpack or "None")
            hiveLabel.Text = "Hive: " .. (hive and "Claimed" or "Unclaimed")
            rateLabel.Text = "Rates: " .. formatNumber(state.PollenRate) .. " pollen/min | "
                .. formatNumber(state.HoneyRate) .. " honey/min"
            phaseLabel.Text = "Phase: " .. state.Phase
            targetLabel.Text = "Target: " .. state.Target
            errorLabel.Text = "Last error: " .. state.LastError
            if gui then
                pcall(function()
                    gui:SetAttribute("BeeSwarmAdapter", true)
                    gui:SetAttribute("BeeSwarmUniverseId", 601130232)
                    gui:SetAttribute("BeeSwarmPhase", state.Phase)
                    gui:SetAttribute("BeeSwarmField", state.Field)
                    gui:SetAttribute("BeeSwarmHoney", honey)
                    gui:SetAttribute("BeeSwarmPollen", pollen)
                    gui:SetAttribute("BeeSwarmCapacity", capacity)
                    gui:SetAttribute("BeeSwarmHiveClaimed", hive ~= nil)
                    gui:SetAttribute("BeeSwarmCollecting", state.Collecting)
                    gui:SetAttribute("BeeSwarmLastError", state.LastError)
                end)
            end
            task.wait(0.5)
        end
    end)

    if gui then
        track(gui.Destroying:Connect(function()
            state.Alive = false
            stopCollection()
            setTravelCollision(LocalPlayer.Character, true)
        end))
    end
end
