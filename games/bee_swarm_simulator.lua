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
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer

    local Events = require(ReplicatedStorage:WaitForChild("Events"))
    local ClientStatCache = require(ReplicatedStorage:WaitForChild("ClientStatCache"))
    local LocalCollect = require(ReplicatedStorage:WaitForChild("Collectors"):WaitForChild("LocalCollect"))
    local Hives = require(ReplicatedStorage:WaitForChild("Activatables"):WaitForChild("Hives"))
    local NPCActivator = require(ReplicatedStorage.Activatables:WaitForChild("NPCs"))
    local HoneycombTools = require(ReplicatedStorage:WaitForChild("HoneycombTools"))
    local ItemPackages = require(ReplicatedStorage:WaitForChild("ItemPackages"))
    local Quests = require(ReplicatedStorage:WaitForChild("Quests"))
    local StatTools = require(ReplicatedStorage:WaitForChild("StatTools"))

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
    local BeeItemSection = ProgressPage:AddSection("Eggs and Bee Items", "Left")
    local RewardSection = ProgressPage:AddSection("Badges and Codes", "Right")
    local ToySection = UtilityPage:AddSection("Toys and Dispensers", "Left")
    local SafetySection = UtilityPage:AddSection("Movement and Safety", "Right")
    local StatSection = StatusPage:AddSection("Live Account", "Left")
    local AdapterSection = StatusPage:AddSection("Adapter State", "Right")

    local FIELD_NAMES = {
        "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field", "Clover Field",
        "Strawberry Field", "Bamboo Field", "Spider Field", "Pineapple Patch", "Pumpkin Patch", "Cactus Field",
        "Rose Field", "Pine Tree Forest", "Stump Field", "Mountain Top Field", "Coconut Field", "Pepper Patch",
    }
    local QUEST_COLOR_FIELDS = {
        Red = "Mushroom Field",
        Blue = "Blue Flower Field",
        White = "Sunflower Field",
    }
    local FIELD_BEE_REQUIREMENTS = {
        ["Strawberry Field"] = 5,
        ["Bamboo Field"] = 5,
        ["Spider Field"] = 5,
        ["Pineapple Patch"] = 10,
        ["Pumpkin Patch"] = 10,
        ["Cactus Field"] = 10,
        ["Stump Field"] = 10,
        ["Rose Field"] = 15,
        ["Pine Tree Forest"] = 15,
        ["Mountain Top Field"] = 15,
        ["Coconut Field"] = 35,
        ["Pepper Patch"] = 35,
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
        "Scooper", "Rake", "Clippers", "Magnet", "Vacuum", "Super-Scooper", "Pulsar",
        "Electro-Magnet", "Scissors", "Honey Dipper", "Bubble Wand", "Scythe",
        "Golden Rake", "Spark Staff", "Porcelain Dipper",
    }
    local BACKPACK_ORDER = {
        "Pouch", "Jar", "Backpack", "Canister", "Mega-Jug", "Compressor",
        "Elite Barrel", "Port-O-Hive", "Blue Port-O-Hive", "Red Port-O-Hive",
        "Porcelain Port-O-Hive", "Coconut Canister",
    }
    local HATCH_EGGS = {"Basic", "Silver", "Gold", "Diamond", "Mythic"}
    local BEE_FEED_ITEMS = {"Treat", "SunflowerSeed", "Strawberry", "Pineapple", "Blueberry"}

    local state = {
        Alive = true,
        FullOP = false,
        AutoFarm = false,
        AutoConvert = true,
        AutoClaimHive = true,
        AutoHatchStarter = true,
        AutoBuyBasicEgg = true,
        AutoHiveSlot = false,
        AutoBadgeRewards = true,
        AutoFeedTreats = false,
        AutoFeedSelected = false,
        AutoRoyalJelly = false,
        HatchEgg = "Basic",
        FeedItem = "Treat",
        FeedAmount = 10,
        PromoCode = "",
        AutoTokens = true,
        PollenPriority = true,
        AutoSprinkler = false,
        AutoQuest = false,
        AutoCollector = false,
        AutoBackpack = false,
        AutoToy = false,
        AntiAfk = true,
        LastAntiAfkPulse = 0,
        AntiAfkPulseCount = 0,
        NoClip = true,
        UnderField = false,
        UnderFieldDepth = 2,
        Field = "Sunflower Field",
        ActiveField = "Sunflower Field",
        ActiveQuest = "None",
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
        TravelSerial = 0,
        ActiveTween = nil,
        ConversionStarted = false,
        LastQuest = 0,
        LastToy = 0,
        LastUpgrade = 0,
        LastSprinkler = 0,
        LastHatch = 0,
        LastCollectorPulse = 0,
        LastHiveSlot = 0,
        LastBadge = 0,
        LastFeed = 0,
        LastStatus = 0,
        HoneySample = 0,
        PollenSample = 0,
        SampleAt = os.clock(),
        HoneyRate = 0,
        PollenRate = 0,
        OriginalCollision = setmetatable({}, {__mode = "k"}),
        UnderMover = nil,
        UnderRoot = nil,
        UnderWasAnchored = false,
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
    local activeQuestLabel = QuestInfoSection:AddLabel("Active quest: Reading...")
    local questFieldLabel = QuestInfoSection:AddLabel("Quest field: Reading...")

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

    local function ownedBeeCount(cached)
        local count = 0
        for _, column in pairs((cached or stats()).Honeycomb or {}) do
            if type(column) == "table" then
                for _, cell in pairs(column) do
                    if type(cell) == "table" and type(cell.Type) == "string" and cell.Type ~= "" then
                        count += 1
                    end
                end
            end
        end
        return count
    end

    local function fieldIsAccessible(fieldName, cached)
        return ownedBeeCount(cached) >= (FIELD_BEE_REQUIREMENTS[fieldName] or 0)
    end

    local function bestAccessibleField(cached)
        for index = #FIELD_NAMES, 1, -1 do
            local fieldName = FIELD_NAMES[index]
            if fieldIsAccessible(fieldName, cached) then
                return fieldName
            end
        end
        return "Sunflower Field"
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

    local function clearUnderFieldHold()
        if state.UnderMover then
            state.UnderMover:Destroy()
        end
        if state.UnderRoot and state.UnderRoot.Parent then
            state.UnderRoot.Anchored = state.UnderWasAnchored
            state.UnderRoot.AssemblyLinearVelocity = Vector3.zero
            state.UnderRoot.AssemblyAngularVelocity = Vector3.zero
        end
        local _, _, root = characterParts()
        if root then
            for _, child in ipairs(root:GetChildren()) do
                if child.Name == "VORBeeUnderFieldHeight" then
                    child:Destroy()
                end
            end
        end
        state.UnderMover = nil
        state.UnderRoot = nil
        state.UnderWasAnchored = false
    end

    local function holdUnderFieldHeight(root, worldY)
        if state.Traveling then
            clearUnderFieldHold()
            return
        end
        if not root then
            clearUnderFieldHold()
            return
        end
        clearUnderFieldHold()
        state.UnderRoot = root
        state.UnderWasAnchored = root.Anchored
        root.CFrame = CFrame.new(root.Position.X, worldY, root.Position.Z) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
    end

    local function travelTo(goal, label, settleOnArrival)
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
        local keepUnderFieldCollision = state.UnderField and label == state.ActiveField
        state.TravelSerial += 1
        local travelSerial = state.TravelSerial
        state.Traveling = true
        state.Target = label or "Position"
        state.Phase = "Traveling"
        if state.NoClip or state.UnderField then
            setTravelCollision(character, false)
        end
        -- Never let the vertical under-field mover fight the travel tween.
        -- The mover is attached only after arrival, once tween velocity is cleared.
        clearUnderFieldHold()
        -- Tweening an unanchored root lets Roblox physics/network ownership add
        -- launch velocity while CFrame is changing. Lock the root for the whole
        -- trip, then restore its original state after the arrival is settled.
        local travelWasAnchored = root.Anchored
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
        local tween = TweenService:Create(
            root,
            TweenInfo.new(math.max(0.05, distance / math.max(40, state.TravelSpeed)), Enum.EasingStyle.Linear),
            {CFrame = goalCFrame}
        )
        if state.ActiveTween then
            pcall(state.ActiveTween.Cancel, state.ActiveTween)
        end
        state.ActiveTween = tween
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
        while state.Alive
            and state.TravelSerial == travelSerial
            and not completed
            and os.clock() - started < math.max(2, distance / 35 + 3) do
            if not root.Parent or humanoid.Health <= 0 then
                break
            end
            RunService.Heartbeat:Wait()
        end
        tween:Cancel()
        if state.ActiveTween == tween then
            state.ActiveTween = nil
        end
        if connection then
            connection:Disconnect()
        end
        if not state.Alive then
            if state.TravelSerial == travelSerial then
                state.Traveling = false
            end
            if root.Parent then
                root.Anchored = travelWasAnchored
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
            clearUnderFieldHold()
            return false, "Adapter stopped"
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
        if root.Parent and state.TravelSerial == travelSerial then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if settleOnArrival and root.Parent and state.TravelSerial == travelSerial then
            character:PivotTo(goalCFrame)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.2)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.1)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if state.TravelSerial ~= travelSerial then
            if root.Parent then
                root.Anchored = travelWasAnchored
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
            return false, "Travel was superseded"
        end
        state.Traveling = false
        if root.Parent then
            root.Anchored = travelWasAnchored
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if not travelWasAnchored then
                pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.GettingUp)
            end
        end
        if keepUnderFieldCollision then
            holdUnderFieldHeight(root, goalCFrame.Position.Y)
        elseif state.NoClip or state.UnderField then
            setTravelCollision(character, true)
        end
        return root.Parent ~= nil and (root.Position - goalCFrame.Position).Magnitude <= 12,
            "Travel did not reach " .. tostring(label or "target")
    end

    local function findField(name)
        local zones = workspace:FindFirstChild("FlowerZones")
        return zones and zones:FindFirstChild(name)
    end

    local function activeQuestField()
        local cached = stats()
        local active = cached.Quests and cached.Quests.Active or {}
        for _, activeData in ipairs(active) do
            local questOk, quest = pcall(Quests.Get, Quests, activeData.Name)
            quest = questOk and quest or nil
            if quest then
                local tasksOk, tasks = pcall(Quests.ResolveTasks, quest, cached)
                tasks = tasksOk and tasks or {}
                for index, taskData in ipairs(tasks or {}) do
                    local taskProgress
                    if taskData.Type == "Collect Pollen" then
                        local progressOk, current = pcall(function()
                            local value = StatTools.GetRawPollenTotal(cached, taskData)
                            if not taskData.Challenge then
                                value -= StatTools.GetPollenTotal(cached, taskData, true)
                            end
                            return value
                        end)
                        if progressOk then
                            local startValue = tonumber((activeData.StartValues or {})[index]) or 0
                            local goal = tonumber(taskData.Amount) or 1
                            local value = math.max(0, (tonumber(current) or 0) - startValue)
                            taskProgress = {math.min(1, value / math.max(1, goal)), value, goal}
                        end
                    end
                    local incomplete = taskProgress and (tonumber(taskProgress[1]) or 0) < 1
                    local zoneName = type(taskData.Zone) == "string" and taskData.Zone or nil
                    if not zoneName and type(taskData.Color) == "string" then
                        zoneName = QUEST_COLOR_FIELDS[taskData.Color]
                    end
                    if not zoneName and taskData.Type == "Collect Pollen" then
                        zoneName = state.Field
                    end
                    if incomplete and zoneName and findField(zoneName) then
                        return zoneName, activeData.Name, taskProgress
                    end
                end
            end
        end
        return nil
    end

    local function questDialogueNeeded()
        local cached = stats()
        local active = cached.Quests and cached.Quests.Active or {}
        if #active == 0 then
            return true
        end
        return activeQuestField() == nil
    end

    local function fieldPoint(zone, step)
        if not zone or not zone:IsA("BasePart") then
            return nil
        end
        local radiusX = math.max(4, zone.Size.X * 0.5 * state.FieldRadius)
        local radiusZ = math.max(4, zone.Size.Z * 0.5 * state.FieldRadius)
        -- Root height that actually overlaps the field's touch volume. Higher
        -- offsets can look fine while CurrentZone never changes.
        local y = zone.Size.Y * 0.5 + 2
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
        local point = zone.CFrame:PointToWorldSpace(localPoint)
        if state.UnderField then
            point = Vector3.new(
                point.X,
                zone.Position.Y + zone.Size.Y * 0.5 - state.UnderFieldDepth,
                point.Z
            )
        end
        return point
    end

    local function enterFieldBeforeHiding(zone, fieldName, targetPoint)
        if not state.UnderField or LocalPlayer:GetAttribute("CurrentZone") == fieldName then
            return true
        end
        local surfacePoint = Vector3.new(
            targetPoint.X,
            zone.Position.Y + zone.Size.Y * 0.5 + 1.9,
            targetPoint.Z
        )
        local reached, err = travelTo(CFrame.new(surfacePoint), "Entering " .. fieldName, true)
        if not reached then
            return false, err
        end
        local deadline = os.clock() + 1.5
        while state.Alive
            and LocalPlayer:GetAttribute("CurrentZone") ~= fieldName
            and os.clock() < deadline do
            task.wait(0.05)
        end
        if LocalPlayer:GetAttribute("CurrentZone") ~= fieldName then
            return false, fieldName .. " did not credit as entered"
        end
        return true
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
        local freeDistance
        local _, _, root = characterParts()
        for _, platform in ipairs(platforms:GetChildren()) do
            local playerRef = platform:FindFirstChild("PlayerRef")
            if not playerRef or playerRef.Value == nil then
                local part = platform:FindFirstChild("Platform")
                local distance = root and part and (root.Position - part.Position).Magnitude or math.huge
                if not freeDistance or distance < freeDistance then
                    free = platform
                    freeDistance = distance
                end
            end
        end
        if not free then
            return false, "No free hive is available"
        end
        local goal = hivePosition(free)
        if goal then
            local reached, travelError = travelTo(goal, "Free hive", true)
            if not reached then
                return false, travelError
            end
        end
        local hiveReference = free:FindFirstChild("Hive")
        local hiveModel = hiveReference and hiveReference.Value
        local hiveId = hiveModel and hiveModel:FindFirstChild("HiveID")
        local claimCharacter, _, claimRoot = characterParts()
        local wasAnchored = claimRoot and claimRoot.Anchored or false
        if claimRoot then
            claimRoot.AssemblyLinearVelocity = Vector3.zero
            claimRoot.AssemblyAngularVelocity = Vector3.zero
            claimRoot.Anchored = true
        end
        local ok, err
        if hiveId then
            ok, err = pcall(Events.ClientCall, "ClaimHive", hiveId.Value)
        else
            ok, err = pcall(Hives.ButtonEffect, LocalPlayer, free)
        end
        if not ok then
            if claimRoot and claimRoot.Parent then
                claimRoot.Anchored = wasAnchored
                claimRoot.AssemblyLinearVelocity = Vector3.zero
                claimRoot.AssemblyAngularVelocity = Vector3.zero
            end
            return false, err
        end
        local deadline = os.clock() + 6
        repeat
            task.wait(0.2)
            existing = ownedHive()
        until existing or os.clock() >= deadline
        if claimRoot and claimRoot.Parent then
            if goal and claimCharacter then
                claimCharacter:PivotTo(goal)
            end
            claimRoot.AssemblyLinearVelocity = Vector3.zero
            claimRoot.AssemblyAngularVelocity = Vector3.zero
            claimRoot.Anchored = wasAnchored
            task.wait(0.15)
            claimRoot.AssemblyLinearVelocity = Vector3.zero
            claimRoot.AssemblyAngularVelocity = Vector3.zero
        end
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

    local function buyPackage(category, itemType, amount)
        local package = {Category = category, Type = itemType, Amount = amount or 1}
        local ok, purchased = pcall(Events.ClientCall, "ItemPackageEvent", "Purchase", package)
        if ok and purchased then
            pcall(ClientStatCache.Update, ClientStatCache)
            task.wait(0.3)
            return true, package
        end
        return false, ok and "Purchase was not accepted" or tostring(purchased)
    end

    local function buyBasicEgg()
        if not ownedHive() then
            return false, "Claim a hive first"
        end
        if not findStarterCell() then
            return false, "No unlocked empty hive cell"
        end
        local before = tonumber((stats().Eggs or {}).Basic) or 0
        if before > 0 then
            return true, "Basic Egg already available"
        end
        local ok, result = buyPackage("Eggs", "Basic", 1)
        if not ok then
            return false, result
        end
        local after = tonumber((stats().Eggs or {}).Basic) or 0
        return after > before, after > before and "Basic Egg purchased" or "Basic Egg purchase was not credited"
    end

    local function buyHiveSlot()
        local ok, result = buyPackage("HiveSlot", "Hive Slot", 1)
        state.LastHiveSlot = os.clock()
        return ok, ok and "Hive slot purchased" or result
    end

    local function applyHiveItem(x, y, itemType, amount)
        local ok, remaining, success, honeycomb, discovered, eggUses = pcall(
            Events.ClientCall,
            "ConstructHiveCellFromEgg",
            x,
            y,
            itemType,
            math.max(1, math.floor(tonumber(amount) or 1)),
            false,
            nil
        )
        if not ok then
            return false, tostring(remaining)
        end
        if success then
            ClientStatCache:Set({"Eggs", itemType}, remaining)
            if discovered ~= nil then
                ClientStatCache:Set("DiscoveredBees", discovered)
            end
            if honeycomb ~= nil then
                ClientStatCache:Set("Honeycomb", honeycomb)
            end
            if eggUses ~= nil then
                ClientStatCache:Set({"Totals", "EggUses"}, eggUses)
            end
            pcall(function()
                require(ReplicatedStorage:WaitForChild("GateManager")).UpdateGateColors()
            end)
        end
        return success == true, success == true and (itemType .. " used") or (itemType .. " was not accepted")
    end

    local function hatchSelectedEgg()
        local itemType = state.HatchEgg
        if (tonumber((stats().Eggs or {})[itemType]) or 0) <= 0 then
            return false, "No " .. itemType .. " Egg available"
        end
        local x, y = findStarterCell()
        if not x then
            return false, "No unlocked empty hive cell"
        end
        local ok, message = applyHiveItem(x, y, itemType, 1)
        state.LastHatch = os.clock()
        return ok, message
    end

    local function lowestLevelBeeCell()
        local bestX, bestY, bestLevel, bestBond
        for xKey, column in pairs(stats().Honeycomb or {}) do
            if type(column) == "table" then
                for yKey, cell in pairs(column) do
                    if type(cell) == "table" and cell.Type and cell.Type ~= "Empty" then
                        local level = tonumber(cell.Level) or 0
                        local bond = tonumber(cell.Bond) or 0
                        if not bestLevel or level < bestLevel or (level == bestLevel and bond < bestBond) then
                            bestX = tonumber(tostring(xKey):match("%d+"))
                            bestY = tonumber(tostring(yKey):match("%d+"))
                            bestLevel = level
                            bestBond = bond
                        end
                    end
                end
            end
        end
        return bestX, bestY
    end

    local function feedSelectedItem(itemType, amount)
        itemType = itemType or state.FeedItem
        amount = math.max(1, math.floor(tonumber(amount) or state.FeedAmount))
        local available = tonumber((stats().Eggs or {})[itemType]) or 0
        if available <= 0 then
            return false, "No " .. itemType .. " available"
        end
        amount = math.min(amount, available)
        local x, y = lowestLevelBeeCell()
        if not x then
            return false, "No bee is available to feed"
        end
        local ok, message = applyHiveItem(x, y, itemType, amount)
        state.LastFeed = os.clock()
        return ok, message
    end

    local function claimBadgeRewards()
        local badges = require(ReplicatedStorage:WaitForChild("Badges"))
        local cached = stats()
        local claimed = 0
        for _, badgeSet in ipairs(badges.GetOrderedSets()) do
            local before = tonumber((cached.Badges or {})[badgeSet.Name]) or 0
            local claimOk = pcall(Events.ClientCall, "BadgeEvent", "Collect", badgeSet.Name)
            if claimOk then
                task.wait(0.12)
                pcall(ClientStatCache.Update, ClientStatCache)
                cached = stats()
                local after = tonumber((cached.Badges or {})[badgeSet.Name]) or 0
                if after > before then
                    claimed += after - before
                end
            end
        end
        state.LastBadge = os.clock()
        return claimed > 0, claimed > 0 and ("Claimed " .. tostring(claimed) .. " badge reward(s)") or "No badge rewards are ready"
    end

    local function redeemPromoCode(code)
        code = tostring(code or ""):match("^%s*(.-)%s*$")
        if code == "" or #code > 100 then
            return false, "Enter a valid promo code"
        end
        local ok, err = pcall(function()
            require(ReplicatedStorage:WaitForChild("PromoCodes")).Redeem(code)
        end)
        return ok, ok and ("Submitted " .. code .. " for server validation") or tostring(err)
    end

    local function beginCollection()
        local function pulseCollectorInput()
            if os.clock() - state.LastCollectorPulse < 0.18 then
                return
            end
            state.LastCollectorPulse = os.clock()
            local executorClicked = false
            pcall(function()
                if type(mouse1click) == "function" then
                    mouse1click()
                    executorClicked = true
                end
            end)
            if executorClicked then
                return
            end
            pcall(function()
                local camera = workspace.CurrentCamera
                local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
                local point = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(point, camera and camera.CFrame or CFrame.identity)
                task.wait(0.035)
                VirtualUser:Button1Up(point, camera and camera.CFrame or CFrame.identity)
            end)
        end
        if state.Collecting then
            -- A manual mouse release can stop Bee Swarm's private collection
            -- loop without changing VOR's state. Run is safe to pulse because
            -- the native module enforces the equipped collector cooldown.
            pcall(LocalCollect.Run)
            pulseCollectorInput()
            return true
        end
        local ok, err = pcall(LocalCollect.StartCollection)
        if ok then
            state.Collecting = true
            pulseCollectorInput()
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
                local inField = true
                if zone then
                    local localPosition = zone.CFrame:PointToObjectSpace(position)
                    local safeRadius = math.clamp(state.FieldRadius, 0.2, 0.9) * 0.5
                    inField = math.abs(localPosition.X) <= zone.Size.X * safeRadius
                        and math.abs(localPosition.Z) <= zone.Size.Z * safeRadius
                end
                if inField and distance <= state.TokenRadius and (not bestDistance or distance < bestDistance) then
                    best = token
                    bestDistance = distance
                end
            end
        end
        return best
    end

    local function collectToken(token, zone)
        local position = tokenPosition(token)
        if not position then
            return false
        end
        state.Phase = "Collecting token"
        local goal = position + Vector3.new(0, 2.2, 0)
        local label = "Token"
        if state.UnderField and zone then
            goal = Vector3.new(
                position.X,
                zone.Position.Y + zone.Size.Y * 0.5 - state.UnderFieldDepth,
                position.Z
            )
            label = state.ActiveField
        end
        local ok = travelTo(CFrame.new(goal), label)
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

    local function currentHivePhase()
        local reference = LocalPlayer:FindFirstChild("Honeycomb")
        local honeycomb = reference and reference.Value
        local phase = honeycomb and honeycomb:FindFirstChild("Phase")
        return phase and tostring(phase.Value) or nil
    end

    local function toggleHoneyMaking()
        return pcall(Events.ClientCall, "PlayerHiveCommand", "ToggleHoneyMaking")
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
            local reached, err = travelTo(goal, "Owned hive", true)
            if not reached then
                return false, err
            end
        end
        clearUnderFieldHold()
        local character, humanoid, root = characterParts()
        setTravelCollision(character, true)
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if humanoid then
            humanoid.Sit = false
            humanoid.PlatformStand = false
            pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.GettingUp)
        end
        state.Phase = "Converting pollen"
        local phase = currentHivePhase()
        if phase == nil or phase == "Idle" then
            local beforeStart = coreStat("Pollen", 0)
            local ok, err = toggleHoneyMaking()
            if not ok then
                return false, err
            end
            local startDeadline = os.clock() + 3
            while state.Alive
                and (currentHivePhase() == nil or currentHivePhase() == "Idle")
                and coreStat("Pollen", 0) >= beforeStart
                and os.clock() < startDeadline do
                task.wait(0.1)
            end
            if (currentHivePhase() == nil or currentHivePhase() == "Idle")
                and coreStat("Pollen", 0) >= beforeStart then
                return false, "Hive reached, but Make Honey was not accepted"
            end
        end
        state.ConversionStarted = true
        local deadline = os.clock() + 600
        local previousPollen = coreStat("Pollen", 0)
        local lastDecrease = os.clock()
        while state.Alive
            and (state.FullOP or (state.AutoFarm and (state.AutoConvert or state.AutoQuest)))
            and coreStat("Pollen", 0) > 0
            and os.clock() < deadline do
            local pollen = coreStat("Pollen", 0)
            if pollen < previousPollen then
                previousPollen = pollen
                lastDecrease = os.clock()
            elseif os.clock() - lastDecrease >= 10 then
                local stalledPhase = currentHivePhase()
                if stalledPhase ~= nil and stalledPhase ~= "Idle" then
                    toggleHoneyMaking()
                    local idleDeadline = os.clock() + 3
                    while state.Alive and currentHivePhase() ~= "Idle" and os.clock() < idleDeadline do
                        task.wait(0.15)
                    end
                end
                if currentHivePhase() == nil or currentHivePhase() == "Idle" then
                    toggleHoneyMaking()
                end
                previousPollen = coreStat("Pollen", 0)
                lastDecrease = os.clock()
            end
            task.wait(0.35)
        end
        local converted = coreStat("Pollen", 0) <= 0
        if currentHivePhase() ~= nil and currentHivePhase() ~= "Idle" then
            if converted then
                state.Phase = "Stopping honey maker"
            else
                state.Phase = "Stopping interrupted conversion"
            end
            toggleHoneyMaking()
            local stopDeadline = os.clock() + 4
            while state.Alive and currentHivePhase() ~= "Idle" and os.clock() < stopDeadline do
                task.wait(0.15)
            end
        end
        state.ConversionStarted = false
        if converted then
            return true
        end
        if not state.AutoConvert and not state.AutoQuest and not state.FullOP then
            return false, "Conversion stopped"
        end
        return false, "Conversion timed out"
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
        local ok, result = pcall(Events.ClientCall, "ToyEvent", toy.Name)
        state.LastToy = os.clock()
        return ok and result ~= false, ok and result ~= false and ("Requested " .. name) or (result or (name .. " is locked or cooling down"))
    end

    local function itemIndex(order, name)
        for index, item in ipairs(order) do
            if item == name then
                return index
            end
        end
        return 0
    end

    local function equippedPackageType(cached, category)
        if category == "Collector" then
            return tostring(cached.EquippedCollector or "Scooper")
        end
        local accessories = cached.EquippedAccessories or {}
        return tostring(accessories.Container or cached.EquippedBackpack or "Pouch")
    end

    local function buyNext(category, order, equipped)
        local start = math.max(1, itemIndex(order, equipped) + 1)
        for index = start, #order do
            local item = order[index]
            local package = {Category = category, Type = item}
            local ok, purchased = pcall(Events.ClientCall, "ItemPackageEvent", "Purchase", package)
            if ok and purchased then
                pcall(ClientStatCache.Update, ClientStatCache)
                task.wait(0.25)
            end
            local cached = stats()
            local hasItem = false
            pcall(function()
                hasItem = ItemPackages.PlayerHas(package, cached) == true
            end)
            if hasItem then
                local equipOk, equippedNow = pcall(Events.ClientCall, "ItemPackageEvent", "Equip", package)
                if equipOk and equippedNow then
                    package.Mute = false
                    pcall(ItemPackages.Equip, package, ClientStatCache:Get())
                    task.wait(0.15)
                end
            end
            local changed = equippedPackageType(stats(), category) == item
            if ok and changed then
                state.LastUpgrade = os.clock()
                return true, item
            end
            if not purchased and not hasItem then
                break
            end
        end
        state.LastUpgrade = os.clock()
        return false, "No affordable unlocked upgrade"
    end

    local function buyCollector()
        local cached = stats()
        return buyNext("Collector", COLLECTOR_ORDER, equippedPackageType(cached, "Collector"))
    end

    local function buyBackpack()
        local cached = stats()
        return buyNext("Accessory", BACKPACK_ORDER, equippedPackageType(cached, "Accessory"))
    end

    local function farmStep(step)
        local fieldName = state.Field
        local questName = "None"
        local cached = stats()
        if state.FullOP or state.AutoQuest then
            local questField, activeQuest = activeQuestField()
            if questField then
                if fieldIsAccessible(questField, cached) then
                    fieldName = questField
                    questName = activeQuest or "Quest"
                else
                    fieldName = (not state.FullOP and fieldIsAccessible(state.Field, cached))
                            and state.Field
                        or bestAccessibleField(cached)
                    questName = tostring(activeQuest or "Quest")
                        .. " waiting for "
                        .. tostring(FIELD_BEE_REQUIREMENTS[questField] or 0)
                        .. " bees"
                end
            end
        end
        state.ActiveField = fieldName
        state.ActiveQuest = questName
        local zone = findField(fieldName)
        if not zone then
            return false, "Field is unavailable: " .. fieldName
        end
        state.Target = questName ~= "None" and (questName .. " > " .. fieldName) or fieldName
        local token = (not state.PollenPriority or step % 4 == 0) and nearestToken(zone) or nil
        if token then
            collectToken(token, zone)
        else
            local point = fieldPoint(zone, step)
            if point then
                local entered, enterError = enterFieldBeforeHiding(zone, fieldName, point)
                if not entered then
                    return false, enterError
                end
                local reached, err = travelTo(CFrame.new(point), fieldName)
                if not reached then
                    return false, err
                end
            end
        end
        beginCollection()
        if state.AutoSprinkler and os.clock() - state.LastSprinkler >= 30 then
            placeSprinkler()
        end
        state.Phase = "Farming " .. fieldName
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
    TokenSection:AddToggle({
        Name = "Pollen Priority Mode",
        Description = "Keeps three of every four moves harvesting; the fourth move may collect a nearby token",
        Flag = "bee_pollen_priority",
        Default = true,
        Callback = function(enabled)
            state.PollenPriority = enabled
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
        Name = "Auto Complete Quests",
        Description = "Targets required fields, completes objectives, turns in, accepts the next quest, and repeats",
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
    HiveSection:AddToggle({
        Name = "Auto Buy Basic Eggs",
        Description = "Buys the next Basic Egg only when an unlocked empty hive cell exists",
        Flag = "bee_auto_buy_basic_eggs",
        Default = true,
        Callback = function(enabled)
            state.AutoBuyBasicEgg = enabled
        end,
    })
    HiveSection:AddToggle({
        Name = "Auto Buy Hive Slots",
        Description = "Purchases the next server-priced hive slot when affordable",
        Flag = "bee_auto_buy_hive_slots",
        Default = false,
        Callback = function(enabled)
            state.AutoHiveSlot = enabled
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

    BeeItemSection:AddDropdown({
        Name = "Egg to Hatch",
        Flag = "bee_hatch_egg_type",
        Options = HATCH_EGGS,
        Default = "Basic",
        Callback = function(value)
            state.HatchEgg = tostring(value or "Basic")
        end,
    })
    BeeItemSection:AddButton({
        Name = "Hatch Selected Egg",
        Description = "Uses one owned egg in the next unlocked empty hive cell",
        Callback = function()
            task.spawn(function()
                local ok, message = hatchSelectedEgg()
                notify("Eggs", message)
                if not ok then
                    setError(message)
                end
            end)
        end,
    })
    BeeItemSection:AddDropdown({
        Name = "Bee Food",
        Flag = "bee_feed_item",
        Options = BEE_FEED_ITEMS,
        Default = "Treat",
        Callback = function(value)
            state.FeedItem = tostring(value or "Treat")
        end,
    })
    BeeItemSection:AddInput({
        Name = "Feed Amount",
        Description = "Uses up to this many owned items on the lowest-level bee",
        Flag = "bee_feed_amount",
        Placeholder = "10",
        Default = "10",
        Callback = function(value)
            state.FeedAmount = math.max(1, math.floor(tonumber(value) or 10))
        end,
    })
    BeeItemSection:AddToggle({
        Name = "Auto Feed Plain Treats",
        Description = "Feeds owned Treats in batches; valuable fruits stay manual",
        Flag = "bee_auto_feed_treats",
        Default = false,
        Callback = function(enabled)
            state.AutoFeedTreats = enabled
        end,
    })
    BeeItemSection:AddToggle({
        Name = "Auto Feed Selected Bee Food",
        Description = "Repeats the selected Treat, Seed, or Fruit in the chosen batch size",
        Flag = "bee_auto_feed_selected",
        Default = false,
        Callback = function(enabled)
            state.AutoFeedSelected = enabled
        end,
    })
    BeeItemSection:AddButton({
        Name = "Feed Selected Item Now",
        Callback = function()
            task.spawn(function()
                local ok, message = feedSelectedItem()
                notify("Bee Items", message)
                if not ok then
                    setError(message)
                end
            end)
        end,
    })
    BeeItemSection:AddButton({
        Name = "Use 1 Royal Jelly",
        Description = "Rerolls the lowest-level bee; manual because this destroys its current type",
        Callback = function()
            task.spawn(function()
                local ok, message = feedSelectedItem("RoyalJelly", 1)
                notify("Royal Jelly", message)
                if not ok then
                    setError(message)
                end
            end)
        end,
    })
    BeeItemSection:AddToggle({
        Name = "Auto Use Royal Jelly",
        Description = "Destructive: repeatedly rerolls the lowest-level bee until disabled or Jelly runs out",
        Flag = "bee_auto_royal_jelly",
        Default = false,
        Callback = function(enabled)
            state.AutoRoyalJelly = enabled
        end,
    })

    RewardSection:AddToggle({
        Name = "Auto Claim Badge Rewards",
        Flag = "bee_auto_claim_badges",
        Default = true,
        Callback = function(enabled)
            state.AutoBadgeRewards = enabled
        end,
    })
    RewardSection:AddButton({
        Name = "Claim Ready Badges Now",
        Callback = function()
            task.spawn(function()
                local ok, message = claimBadgeRewards()
                notify("Badges", message)
                if not ok and message ~= "No badge rewards are ready" then
                    setError(message)
                end
            end)
        end,
    })
    RewardSection:AddInput({
        Name = "Promo Code",
        Description = "Uses Bee Swarm's native PromoCodeEvent; the server validates the code",
        Flag = "bee_promo_code",
        Placeholder = "Enter code",
        Default = "",
        Callback = function(value)
            state.PromoCode = tostring(value or "")
        end,
    })
    RewardSection:AddButton({
        Name = "Redeem Promo Code",
        Callback = function()
            local ok, message = redeemPromoCode(state.PromoCode)
            notify("Promo Codes", message)
            if not ok then
                setError(message)
            end
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
        Name = "Under-Field Farming",
        Description = "Keeps the character below flower tiles while native ToolCollect continues crediting pollen",
        Flag = "bee_under_field_farming",
        Default = false,
        Callback = function(enabled)
            state.UnderField = enabled
            if not enabled then
                clearUnderFieldHold()
                setTravelCollision(LocalPlayer.Character, true)
            end
        end,
    })
    SafetySection:AddSlider({
        Name = "Under-Field Depth",
        Flag = "bee_under_field_depth",
        Min = 1.5,
        Max = 2.5,
        Step = 0.5,
        Default = 2,
        Suffix = " studs",
        Callback = function(value)
            state.UnderFieldDepth = math.clamp(tonumber(value) or 2, 1.5, 2.5)
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
    local antiAfkStatusLabel = SafetySection:AddLabel("Anti AFK: Armed (55s heartbeat)")
    SafetySection:AddButton({
        Name = "Test Anti AFK Pulse",
        Description = "Sends one harmless keep-alive pulse and updates the status label",
        Persist = false,
        Callback = function()
            state.LastAntiAfkPulse = 0
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
            clearUnderFieldHold()
            setTravelCollision(LocalPlayer.Character, true)
            state.Phase = "Stopped"
            notify("Bee Swarm", "All Bee Swarm automation stopped")
        end,
    })

    routeLabel.Text = "Credited route: ToolCollect > token touch > hive conversion"

    track(RunService.Heartbeat:Connect(function()
        if state.Traveling then
            local _, _, root = characterParts()
            if state.UnderMover
                or state.UnderRoot
                or (root and root:FindFirstChild("VORBeeUnderFieldHeight")) then
                clearUnderFieldHold()
            end
        end
    end))

    local function performAntiAfkPulse(reason)
        local camera = workspace.CurrentCamera
        local cameraCFrame = camera and camera.CFrame or CFrame.identity
        local virtualUserOk = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.zero, cameraCFrame)
            task.wait(0.08)
            VirtualUser:Button2Up(Vector2.zero, cameraCFrame)
        end)
        local virtualInputOk = pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            task.wait(0.04)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        state.LastAntiAfkPulse = os.clock()
        state.AntiAfkPulseCount += 1
        local succeeded = virtualUserOk or virtualInputOk
        antiAfkStatusLabel.Text = succeeded
            and ("Anti AFK: Pulse #" .. tostring(state.AntiAfkPulseCount) .. " sent (" .. tostring(reason) .. ")")
            or "Anti AFK: Virtual input unavailable"
        if gui then
            pcall(function()
                gui:SetAttribute("BeeSwarmAntiAfkPulseCount", state.AntiAfkPulseCount)
                gui:SetAttribute("BeeSwarmAntiAfkLastPulse", workspace:GetServerTimeNow())
                gui:SetAttribute("BeeSwarmAntiAfkHealthy", succeeded)
            end)
        end
        return succeeded
    end

    track(LocalPlayer.Idled:Connect(function()
        if state.Alive and state.AntiAfk then
            task.spawn(performAntiAfkPulse, "idle signal")
        end
    end))

    task.spawn(function()
        while state.Alive do
            if state.AntiAfk and os.clock() - state.LastAntiAfkPulse >= 55 then
                performAntiAfkPulse("heartbeat")
            end
            task.wait(5)
        end
    end)

    task.spawn(function()
        local step = 0
        while state.Alive do
            local enabled = state.FullOP or state.AutoFarm
            if enabled and state.Traveling then
                task.wait(0.1)
            elseif enabled then
                if (state.FullOP or state.AutoClaimHive) and not ownedHive() then
                    state.Phase = "Claiming hive"
                    local ok, message = claimHive()
                    if not ok then
                        setError(message)
                        task.wait(1)
                    end
                end
                if ownedHive() then
                    if (state.FullOP or state.AutoHatchStarter) and os.clock() - state.LastHatch >= 5 then
                        local eggs = stats().Eggs or {}
                        if (tonumber(eggs.Basic) or 0) <= 0
                            and (state.FullOP or state.AutoBuyBasicEgg)
                            and findStarterCell() then
                            local bought, buyMessage = buyBasicEgg()
                            if not bought
                                and buyMessage ~= "No unlocked empty hive cell"
                                and buyMessage ~= "Purchase was not accepted"
                                and buyMessage ~= "Basic Egg purchase was not credited" then
                                setError(buyMessage)
                            end
                            eggs = stats().Eggs or {}
                        end
                        if (tonumber(eggs.Basic) or 0) > 0 then
                            local ok, message = hatchStarterBee()
                            if not ok and message ~= "No unlocked empty hive cell" then
                                setError(message)
                            end
                        end
                    end
                    local pollen = coreStat("Pollen", 0)
                    local capacity = math.max(1, coreStat("Capacity", 1))
                    local convertForFarm = state.AutoConvert and pollen >= capacity * (state.ConvertAt / 100)
                    local convertForQuest = (state.FullOP or state.AutoQuest) and pollen >= capacity
                    if convertForFarm or convertForQuest then
                        local ok, message = convertPollen()
                        if not ok then
                            setError(message)
                            task.wait(0.5)
                        end
                    elseif pollen >= capacity then
                        stopCollection()
                        state.Phase = "Backpack full"
                        state.Target = "Enable Auto Convert Honey or Auto Complete Quests"
                        task.wait(0.5)
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
                    state.Phase = "Waiting for a credited hive claim"
                    state.Target = "Nearest free hive"
                    task.wait(0.5)
                end
            else
                stopCollection()
                clearUnderFieldHold()
                setTravelCollision(LocalPlayer.Character, true)
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
                and now - state.LastQuest >= 8
                and not state.Traveling
                and not state.ConversionStarted
                and questDialogueNeeded() then
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
            if (state.FullOP or state.AutoHiveSlot)
                and now - state.LastHiveSlot >= 15
                and not state.Traveling
                and ownedHive() then
                buyHiveSlot()
            end
            if state.AutoRoyalJelly
                and now - state.LastFeed >= 10
                and not state.Traveling
                and ownedHive()
                and (tonumber((stats().Eggs or {}).RoyalJelly) or 0) > 0 then
                feedSelectedItem("RoyalJelly", 1)
            elseif state.AutoFeedSelected
                and now - state.LastFeed >= 10
                and not state.Traveling
                and ownedHive()
                and (tonumber((stats().Eggs or {})[state.FeedItem]) or 0) > 0 then
                feedSelectedItem(state.FeedItem, state.FeedAmount)
            elseif (state.FullOP or state.AutoFeedTreats)
                and now - state.LastFeed >= 10
                and not state.Traveling
                and ownedHive()
                and (tonumber((stats().Eggs or {}).Treat) or 0) > 0 then
                feedSelectedItem("Treat", state.FeedAmount)
            end
            if (state.FullOP or state.AutoBadgeRewards)
                and now - state.LastBadge >= 60
                and not state.Traveling then
                claimBadgeRewards()
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
            equipmentLabel.Text = "Collector: " .. equippedPackageType(cached, "Collector")
                .. " | Backpack: " .. equippedPackageType(cached, "Accessory")
            hiveLabel.Text = "Hive: " .. (hive and "Claimed" or "Unclaimed")
            rateLabel.Text = "Rates: " .. formatNumber(state.PollenRate) .. " pollen/min | "
                .. formatNumber(state.HoneyRate) .. " honey/min"
            local questField, questName, questProgress = activeQuestField()
            local progressText = questProgress
                and (formatNumber(questProgress[2]) .. "/" .. formatNumber(questProgress[3]))
                or ""
            activeQuestLabel.Text = "Active quest: " .. tostring(questName or "None")
                .. (progressText ~= "" and (" | " .. progressText) or "")
            questFieldLabel.Text = "Quest field: " .. tostring(questField or "No unfinished field objective")
            phaseLabel.Text = "Phase: " .. state.Phase
            targetLabel.Text = "Target: " .. state.Target
            errorLabel.Text = "Last error: " .. state.LastError
            if gui then
                pcall(function()
                    gui:SetAttribute("BeeSwarmAdapter", true)
                    gui:SetAttribute("BeeSwarmUniverseId", 601130232)
                    gui:SetAttribute("BeeSwarmPhase", state.Phase)
                    gui:SetAttribute("BeeSwarmField", state.ActiveField or state.Field)
                    gui:SetAttribute("BeeSwarmSelectedField", state.Field)
                    gui:SetAttribute("BeeSwarmActiveQuest", state.ActiveQuest)
                    gui:SetAttribute("BeeSwarmHoney", honey)
                    gui:SetAttribute("BeeSwarmPollen", pollen)
                    gui:SetAttribute("BeeSwarmCapacity", capacity)
                    gui:SetAttribute("BeeSwarmHiveClaimed", hive ~= nil)
                    gui:SetAttribute("BeeSwarmCollecting", state.Collecting)
                    gui:SetAttribute("BeeSwarmUnderField", state.UnderField)
                    gui:SetAttribute("BeeSwarmUnderFieldDepth", state.UnderFieldDepth)
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
            clearUnderFieldHold()
            setTravelCollision(LocalPlayer.Character, true)
        end))
    end
end
