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
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local environment = type(getgenv) == "function" and getgenv() or _G

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmingPage = addHomeCategory("Farming", 1, CATEGORY_DECALS.Progress)
    local UpgradesPage = addHomeCategory("Upgrades", 2, CATEGORY_DECALS.Weapons or CATEGORY_DECALS.Progress)
    local ShopPage = addHomeCategory("Shop", 3, CATEGORY_DECALS.Player)
    local RewardsPage = addHomeCategory("Rewards", 4, CATEGORY_DECALS.Overnight)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Visuals)
    local FundamentalsPage = addHomeCategory("Fundamentals", 6, CATEGORY_DECALS.Player)
    selectHomeCategory("Farming")

    local MainFarmSection = FarmingPage:AddSection("OP Mining Loop", "Left")
    local TargetSection = FarmingPage:AddSection("Crystal Targeting", "Right")
    local MiningStatusSection = FarmingPage:AddSection("Mining Status", "Right")
    local ServerHopSection = FarmingPage:AddSection("Rare Crystal Server Hop", "Right")
    local UpgradeSection = UpgradesPage:AddSection("Stat Upgrades", "Left")
    local AutoPurchaseSection = UpgradesPage:AddSection("Automatic Progression", "Right")
    local PlotSection = UpgradesPage:AddSection("Plot Luck Farm", "Right")
    local StoreSection = ShopPage:AddSection("Equipment Shop", "Left")
    local TravelSection = ShopPage:AddSection("Travel", "Right")
    local RewardSection = RewardsPage:AddSection("Reward Claims", "Left")
    local SafetySection = FundamentalsPage:AddSection("Character Fundamentals", "Left")
    local VisibilitySection = FundamentalsPage:AddSection("Visibility Research", "Right")
    local StatsSection = StatusPage:AddSection("Live Player Stats", "Left")
    local AdapterSection = StatusPage:AddSection("Adapter State", "Right")

    local state = {
        Alive = true,
        Master = false,
        AutoFarm = false,
        AutoSell = true,
        GodspeedMining = true,
        GodspeedRadius = 18,
        GodspeedBatchSize = 8,
        GodspeedPickaxe = false,
        AutoWarmth = false,
        AutoWeight = false,
        AutoPickaxe = false,
        AutoBackpack = false,
        AutoPlotCapacity = false,
        AutoRewards = false,
        AntiAfk = true,
        FreezeGuard = true,
        NoClipTravel = true,
        FarmFloat = true,
        AntiRagdoll = true,
        WalkSpeedEnabled = false,
        WalkSpeed = 24,
        TargetMode = "Best Value",
        MinimumTier = 1,
        MaximumTier = 0,
        TravelMode = "Tween",
        TravelSpeed = 240,
        FarmOffset = 4,
        SellPercent = 92,
        CashReserve = 0,
        Target = nil,
        RejectedTarget = nil,
        LastSafeCFrame = nil,
        FloorRecoveries = 0,
        LastFloorRecoveryAt = -math.huge,
        TargetName = "None",
        Phase = "Idle",
        LastError = "None",
        LastSale = 0,
        LastPurchase = 0,
        LastReward = 0,
        LastStatus = 0,
        LastFarmCycle = 0,
        LastAutoPurchase = 0,
        LastGodspeedCredited = 0,
        HighTierHunt = environment.VORMountainResumeHighTierHunt == true,
        SoloSession = environment.VORMountainResumeSoloSession == true,
        LastSoloHopAttempt = -math.huge,
        HopBusy = false,
        HopMissingScans = 0,
        HopCountdownDuration = 15,
        HopCountdownEndsAt = nil,
        HopCountdownRemaining = 0,
        HopCountdownFrame = nil,
        HopCountdownOverlay = nil,
        HopCountdownTimerLabel = nil,
        HopCountdownMessageLabel = nil,
        HopCountdownBar = nil,
        HopStartedAt = os.clock(),
        LastCrystalGrowthAt = os.clock(),
        LastObservedCrystalTotal = 0,
        GenerationReady = false,
        StreamingStableFor = 0,
        StreamingExpanded = false,
        StreamingRadius = 0,
        OriginalStreamingTarget = nil,
        OriginalStreamingMinimum = nil,
        HopStatus = "Watching crystal inventory",
        HighTierCount = 0,
        HighTierCounts = {},
        BuriedCrystalCount = 0,
        TeleportResumeQueued = false,
        TeleportQueueMethod = "Unavailable",
        ConsecutiveFailures = 0,
        PurchaseBusy = false,
        FailedTargets = setmetatable({}, {__mode = "k"}),
        InvalidTargets = setmetatable({}, {__mode = "k"}),
        OriginalCollision = setmetatable({}, {__mode = "k"}),
        OriginalWalkSpeed = nil,
        OriginalFallingDownEnabled = nil,
        OriginalRagdollEnabled = nil,
        StateCharacter = nil,
        FloatMover = nil,
        FloatRoot = nil,
        OriginalPickaxeAttributes = setmetatable({}, {__mode = "k"}),
    }
    local visitedServers = environment.VORMountainVisitedServers
    if type(visitedServers) ~= "table" then
        visitedServers = {}
        environment.VORMountainVisitedServers = visitedServers
    end
    visitedServers[game.JobId] = true

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
    local highTierNames = {
        [5] = "Legendary",
        [6] = "Mythic",
        [7] = "Divine",
        [8] = "Empyrean",
        [9] = "Zenith",
        [10] = "Infinity",
        [11] = "Ultima",
    }

    local function expandMountainStreaming()
        if type(gethiddenproperty) ~= "function"
            or type(sethiddenproperty) ~= "function" then
            return false
        end
        if state.OriginalStreamingTarget == nil then
            pcall(function()
                state.OriginalStreamingTarget = gethiddenproperty(
                    workspace,
                    "StreamingTargetRadius"
                )
                state.OriginalStreamingMinimum = gethiddenproperty(
                    workspace,
                    "StreamingMinRadius"
                )
            end)
        end

        local mountainRadius = tonumber(workspace:GetAttribute("MountainRadius")) or 800
        local desiredTarget = math.max(4096, math.ceil(mountainRadius * 3))
        local desiredMinimum = math.min(desiredTarget, math.max(2048, math.ceil(mountainRadius * 1.5)))
        local targetOk = pcall(
            sethiddenproperty,
            workspace,
            "StreamingTargetRadius",
            desiredTarget
        )
        local minimumOk = pcall(
            sethiddenproperty,
            workspace,
            "StreamingMinRadius",
            desiredMinimum
        )
        state.StreamingExpanded = targetOk and minimumOk
        state.StreamingRadius = state.StreamingExpanded and desiredTarget or 0

        if state.StreamingExpanded then
            task.spawn(function()
                local center = Vector3.new(
                    tonumber(workspace:GetAttribute("MountainCenterX")) or 0,
                    tonumber(workspace:GetAttribute("MountainActualPeakY")) or 0,
                    tonumber(workspace:GetAttribute("MountainCenterZ")) or 0
                )
                pcall(function()
                    LocalPlayer:RequestStreamAroundAsync(center, 15)
                end)
            end)
        end
        return state.StreamingExpanded
    end

    expandMountainStreaming()

    local ShopCatalog
    pcall(function()
        ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
    end)
    local RagdollSystem
    pcall(function()
        RagdollSystem = require(ReplicatedStorage.RagdollSystemPackage.RagdollSystem)
    end)

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 4)
    end

    local function addCorner(instance, radius)
        local object = Instance.new("UICorner")
        object.CornerRadius = UDim.new(0, radius or 10)
        object.Parent = instance
        return object
    end

    local function addStroke(instance, color, thickness, transparency)
        local object = Instance.new("UIStroke")
        object.Color = color
        object.Thickness = thickness or 1
        object.Transparency = transparency or 0
        object.Parent = instance
        return object
    end

    local function hopCountdownLabel(parent, text, size, position, color, textSize, font)
        local object = Instance.new("TextLabel")
        object.BackgroundTransparency = 1
        object.BorderSizePixel = 0
        object.Size = size
        object.Position = position
        object.Font = font or Enum.Font.GothamMedium
        object.Text = text
        object.TextColor3 = color
        object.TextSize = textSize
        object.TextXAlignment = Enum.TextXAlignment.Left
        object.TextYAlignment = Enum.TextYAlignment.Center
        object.ZIndex = 1203
        object.Parent = parent
        return object
    end

    local function ensureHopCountdown()
        if state.HopCountdownFrame and state.HopCountdownFrame.Parent then
            return state.HopCountdownFrame
        end

        local overlay = Instance.new("ScreenGui")
        overlay.Name = "VORMountainHopOverlay"
        overlay.DisplayOrder = 1000000
        overlay.IgnoreGuiInset = true
        overlay.ResetOnSpawn = false
        overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        overlay.Parent = LocalPlayer:WaitForChild("PlayerGui")
        state.HopCountdownOverlay = overlay

        local frame = Instance.new("Frame")
        frame.Name = "VORMountainHopCountdown"
        frame.AnchorPoint = Vector2.new(1, 1)
        frame.Position = UDim2.new(1, 450, 1, -24)
        frame.Size = UDim2.fromOffset(430, 108)
        frame.BackgroundColor3 = COLORS.surfaceRaised
        frame.BorderSizePixel = 0
        frame.ZIndex = 1200
        frame.Parent = overlay
        addCorner(frame, 14)
        addStroke(frame, COLORS.accentBright, 1.4, 0.12)

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, COLORS.surfaceRaised),
            ColorSequenceKeypoint.new(1, COLORS.surface),
        })
        gradient.Rotation = 12
        gradient.Parent = frame

        local accent = Instance.new("Frame")
        accent.Name = "Accent"
        accent.Size = UDim2.new(0, 5, 1, -18)
        accent.Position = UDim2.fromOffset(0, 9)
        accent.BackgroundColor3 = COLORS.accentBright
        accent.BorderSizePixel = 0
        accent.ZIndex = 1202
        accent.Parent = frame
        addCorner(accent, 4)

        local iconPlate = Instance.new("Frame")
        iconPlate.Name = "IconPlate"
        iconPlate.Size = UDim2.fromOffset(54, 54)
        iconPlate.Position = UDim2.fromOffset(18, 16)
        iconPlate.BackgroundColor3 = COLORS.accent
        iconPlate.BackgroundTransparency = 0.76
        iconPlate.BorderSizePixel = 0
        iconPlate.ZIndex = 1202
        iconPlate.Parent = frame
        addCorner(iconPlate, 12)
        addStroke(iconPlate, COLORS.accentBright, 1, 0.45)

        local icon = hopCountdownLabel(
            iconPlate,
            utf8.char(0x26A1),
            UDim2.fromScale(1, 1),
            UDim2.fromOffset(0, 0),
            COLORS.text,
            27,
            Enum.Font.GothamBold
        )
        icon.TextXAlignment = Enum.TextXAlignment.Center

        hopCountdownLabel(
            frame,
            "HIGH-TIER SWEEP COMPLETE",
            UDim2.fromOffset(270, 22),
            UDim2.fromOffset(86, 12),
            COLORS.text,
            13,
            Enum.Font.GothamBold
        )
        state.HopCountdownMessageLabel = hopCountdownLabel(
            frame,
            "Rescanning Legendary through Ultima...",
            UDim2.fromOffset(280, 32),
            UDim2.fromOffset(86, 34),
            COLORS.text,
            11,
            Enum.Font.GothamMedium
        )
        state.HopCountdownMessageLabel.TextWrapped = true

        state.HopCountdownTimerLabel = hopCountdownLabel(
            frame,
            "15s",
            UDim2.fromOffset(62, 42),
            UDim2.new(1, -76, 0, 22),
            COLORS.warning,
            24,
            Enum.Font.GothamBold
        )
        state.HopCountdownTimerLabel.TextXAlignment = Enum.TextXAlignment.Right

        local barTrack = Instance.new("Frame")
        barTrack.Name = "CountdownTrack"
        barTrack.Size = UDim2.new(1, -36, 0, 5)
        barTrack.Position = UDim2.new(0, 18, 1, -17)
        barTrack.BackgroundColor3 = COLORS.surface
        barTrack.BackgroundTransparency = 0.12
        barTrack.BorderSizePixel = 0
        barTrack.ZIndex = 1202
        barTrack.Parent = frame
        addCorner(barTrack, 4)

        local bar = Instance.new("Frame")
        bar.Name = "CountdownFill"
        bar.Size = UDim2.fromScale(1, 1)
        bar.BackgroundColor3 = COLORS.accentBright
        bar.BorderSizePixel = 0
        bar.ZIndex = 1203
        bar.Parent = barTrack
        addCorner(bar, 4)
        local barGradient = Instance.new("UIGradient")
        barGradient.Color = ColorSequence.new(COLORS.accentBright, COLORS.warning)
        barGradient.Parent = bar

        state.HopCountdownFrame = frame
        state.HopCountdownBar = bar
        TweenService:Create(
            frame,
            TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = UDim2.new(1, -24, 1, -24)}
        ):Play()
        return frame
    end

    local function updateHopCountdown(remaining)
        ensureHopCountdown()
        local seconds = math.max(0, math.ceil(remaining))
        state.HopCountdownRemaining = seconds
        if state.HopCountdownTimerLabel then
            state.HopCountdownTimerLabel.Text = string.format("%02ds", seconds)
        end
        if state.HopCountdownMessageLabel then
            state.HopCountdownMessageLabel.Text = "Rescanning Legendary through Ultima. A new crystal cancels this hop."
        end
        if state.HopCountdownBar then
            local ratio = math.clamp(remaining / state.HopCountdownDuration, 0, 1)
            TweenService:Create(
                state.HopCountdownBar,
                TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(ratio, 0, 1, 0)}
            ):Play()
        end
    end

    local function closeHopCountdown()
        state.HopCountdownEndsAt = nil
        state.HopCountdownRemaining = 0
        state.HopCountdownTimerLabel = nil
        state.HopCountdownMessageLabel = nil
        state.HopCountdownBar = nil
        local frame = state.HopCountdownFrame
        local overlay = state.HopCountdownOverlay
        state.HopCountdownFrame = nil
        state.HopCountdownOverlay = nil
        if not (frame and frame.Parent) then
            if overlay and overlay.Parent then
                overlay:Destroy()
            end
            return
        end
        local animation = TweenService:Create(
            frame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 450, 1, -24), BackgroundTransparency = 1}
        )
        animation.Completed:Once(function()
            if frame.Parent then
                frame:Destroy()
            end
            if overlay and overlay.Parent then
                overlay:Destroy()
            end
        end)
        animation:Play()
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

    local BELOW_MOUNTAIN_MARGIN = 8

    local function isBelowMountainMap(part)
        if not part then
            return false
        end
        local baseY = tonumber(workspace:GetAttribute("MountainBaseY"))
        return baseY ~= nil and part.Position.Y < baseY - BELOW_MOUNTAIN_MARGIN
    end

    local function crystalTargetPartAndPrompt(crystal)
        if not crystal then
            return nil, nil
        end

        local prompt = crystal:IsA("ProximityPrompt")
            and crystal
            or crystal:FindFirstChildWhichIsA("ProximityPrompt", true)
        local promptPart
        local cursor = prompt and prompt.Parent
        while cursor and cursor ~= crystal.Parent do
            if cursor:IsA("BasePart") then
                promptPart = cursor
                break
            end
            if cursor == crystal then
                break
            end
            cursor = cursor.Parent
        end

        local part = promptPart
            or (crystal:IsA("BasePart") and crystal)
            or (crystal:IsA("Model") and crystal.PrimaryPart)
            or crystal:FindFirstChildWhichIsA("BasePart", true)
        return part, prompt
    end

    local function isInvalidCrystal(crystal, part, prompt)
        if not crystal or state.InvalidTargets[crystal] then
            return true
        end

        local promptPart
        local cursor = prompt and prompt.Parent
        while cursor and cursor ~= crystal.Parent do
            if cursor:IsA("BasePart") then
                promptPart = cursor
                break
            end
            if cursor == crystal then
                break
            end
            cursor = cursor.Parent
        end

        if isBelowMountainMap(promptPart or part)
            or (promptPart and part ~= promptPart and isBelowMountainMap(part)) then
            return true
        end

        if crystal:IsA("Model") then
            local ok, boundsCFrame, boundsSize = pcall(crystal.GetBoundingBox, crystal)
            local baseY = tonumber(workspace:GetAttribute("MountainBaseY"))
            if ok and baseY
                and boundsCFrame.Position.Y + boundsSize.Y * 0.5 < baseY - BELOW_MOUNTAIN_MARGIN then
                return true
            end
        end

        return false
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

    local function setGodspeedPickaxe(enabled)
        local function apply(container)
            if not container then
                return
            end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool")
                    and (tool:GetAttribute("IsPickaxe") or tool:GetAttribute("DigPower")) then
                    if state.OriginalPickaxeAttributes[tool] == nil then
                        local original = tool:GetAttribute("NoSwingCooldown")
                        state.OriginalPickaxeAttributes[tool] = {
                            HadValue = original ~= nil,
                            Value = original,
                        }
                    end
                    if enabled then
                        tool:SetAttribute("NoSwingCooldown", true)
                    else
                        local original = state.OriginalPickaxeAttributes[tool]
                        local restoredValue = nil
                        if original and original.HadValue then
                            restoredValue = original.Value
                        end
                        tool:SetAttribute("NoSwingCooldown", restoredValue)
                        state.OriginalPickaxeAttributes[tool] = nil
                    end
                end
            end
        end
        apply(LocalPlayer:FindFirstChildOfClass("Backpack"))
        apply(LocalPlayer.Character)
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

    local function configureRagdollStates(character, humanoid)
        if state.StateCharacter ~= character then
            state.StateCharacter = character
            state.OriginalFallingDownEnabled = nil
            state.OriginalRagdollEnabled = nil
            state.OriginalWalkSpeed = humanoid and humanoid.WalkSpeed or nil
        end
        if not humanoid then
            return
        end
        if state.OriginalFallingDownEnabled == nil then
            pcall(function()
                state.OriginalFallingDownEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.FallingDown)
            end)
        end
        if state.OriginalRagdollEnabled == nil then
            pcall(function()
                state.OriginalRagdollEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Ragdoll)
            end)
        end
        if state.AntiRagdoll then
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end)
        end
    end

    local function clearActiveRagdoll(character, humanoid)
        if not state.AntiRagdoll or not (character and humanoid) then
            return
        end
        configureRagdollStates(character, humanoid)
        local ragdoll
        if RagdollSystem and type(RagdollSystem.getLocalRagdoll) == "function" then
            pcall(function()
                ragdoll = RagdollSystem:getLocalRagdoll()
            end)
        end
        local active = character:GetAttribute("Ragdolled") == true
            or (ragdoll and ragdoll:isRagdolled())
        if not active then
            return
        end
        pcall(function()
            if ragdoll and ragdoll:isRagdolled() then
                ragdoll:deactivateRagdollPhysics()
            end
        end)
        pcall(function()
            character:SetAttribute("Ragdolled", false)
        end)
        pcall(function()
            if RagdollSystem and RagdollSystem.Remotes and RagdollSystem.Remotes.DeactivateRagdoll then
                RagdollSystem.Remotes.DeactivateRagdoll:FireServer()
            end
        end)
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.defer(function()
            if humanoid.Parent then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end

    local function updateFarmFloat(character, humanoid, root)
        local enabled = state.FarmFloat
            and (state.Master or state.AutoFarm)
            and character ~= nil
            and humanoid ~= nil
            and root ~= nil
            and humanoid.Health > 0
        if not enabled then
            if state.FloatMover then
                state.FloatMover:Destroy()
                state.FloatMover = nil
                state.FloatRoot = nil
            end
            return
        end

        if state.FloatRoot ~= root or not (state.FloatMover and state.FloatMover.Parent == root) then
            if state.FloatMover then
                state.FloatMover:Destroy()
            end
            local mover = Instance.new("BodyVelocity")
            mover.Name = "VORMountainHeightHold"
            mover.MaxForce = Vector3.new(0, math.huge, 0)
            mover.P = 50000
            mover.Velocity = Vector3.zero
            mover.Parent = root
            state.FloatMover = mover
            state.FloatRoot = root
        end

        -- Hold vertical velocity at zero. Horizontal movement and tweened CFrame
        -- changes remain untouched, so wall crystals do not make the player rise.
        state.FloatMover.Velocity = Vector3.zero
        local velocity = root.AssemblyLinearVelocity
        if math.abs(velocity.Y) > 0.01 then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        end
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
            while state.Alive
                and (state.Master or state.AutoFarm)
                and state.RejectedTarget ~= state.Target do
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
        if state.RejectedTarget == state.Target then
            return false, "target crossed below the mountain floor"
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
        local _, pickaxePower = bestPickaxe()
        local minimumTier = state.HighTierHunt and tierNames.Legendary
            or state.MinimumTier
        local efficientMaximum = state.HighTierHunt and tierNames.Ultima
            or (state.MaximumTier > 0
                and state.MaximumTier
                or math.clamp(math.floor(pickaxePower + 0.6), 1, 11))

        for _, folder in ipairs(crystalRoots()) do
            for _, crystal in ipairs(folder:GetChildren()) do
                local part, prompt = crystalTargetPartAndPrompt(crystal)
                local tier = tonumber(crystal:GetAttribute("Tier") or (part and part:GetAttribute("Tier"))) or 0
                local weight = tonumber(crystal:GetAttribute("WeightKg") or (part and part:GetAttribute("WeightKg"))) or 0
                local value = tonumber(crystal:GetAttribute("Value") or (part and part:GetAttribute("Value"))) or 0
                local failedUntil = state.FailedTargets[crystal]
                if part
                    and prompt
                    and prompt.Enabled
                    and not isInvalidCrystal(crystal, part, prompt)
                    and tier >= minimumTier
                    and tier <= efficientMaximum
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

    local function nearbyGodspeedPrompts()
        local _, humanoid, root = characterParts()
        if not (humanoid and root and humanoid.Health > 0) then
            return {}
        end
        local carried = cargo()
        local room = math.max(0, capacity() - carried)
        local candidates = {}
        local now = os.clock()
        for _, folder in ipairs(crystalRoots()) do
            for _, crystal in ipairs(folder:GetChildren()) do
                local part, prompt = crystalTargetPartAndPrompt(crystal)
                local weight = tonumber(
                    crystal:GetAttribute("WeightKg")
                        or (part and part:GetAttribute("WeightKg"))
                ) or 0
                local value = tonumber(
                    crystal:GetAttribute("Value")
                        or (part and part:GetAttribute("Value"))
                ) or 0
                local failedUntil = state.FailedTargets[crystal]
                if part
                    and prompt
                    and prompt.Enabled
                    and not isInvalidCrystal(crystal, part, prompt)
                    and prompt.MaxActivationDistance > 0
                    and weight > 0
                    and crystal:GetAttribute("Collected") ~= true
                    and (not failedUntil or failedUntil <= now) then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= state.GodspeedRadius
                        and distance <= prompt.MaxActivationDistance + 0.5 then
                        table.insert(candidates, {
                            Crystal = crystal,
                            Prompt = prompt,
                            Weight = weight,
                            Value = value,
                            Distance = distance,
                        })
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            if a.Value == b.Value then
                return a.Distance < b.Distance
            end
            return a.Value > b.Value
        end)

        local selected = {}
        local reservedWeight = 0
        for _, candidate in ipairs(candidates) do
            if #selected >= state.GodspeedBatchSize then
                break
            end
            if reservedWeight + candidate.Weight <= room + 0.001 then
                reservedWeight += candidate.Weight
                table.insert(selected, candidate)
            end
        end
        return selected
    end

    local function runGodspeedBatch()
        if not state.GodspeedMining then
            return false
        end
        local batch = nearbyGodspeedPrompts()
        if #batch < 2 then
            return false
        end

        local beforeWeight, beforeCount = cargo()
        local maximumHold = 0
        for _, candidate in ipairs(batch) do
            maximumHold = math.max(
                maximumHold,
                tonumber(candidate.Prompt.HoldDuration) or 0
            )
            task.spawn(function()
                local ok = activatePrompt(candidate.Prompt)
                if not ok and candidate.Crystal.Parent then
                    state.FailedTargets[candidate.Crystal] = os.clock() + 2
                end
            end)
        end

        state.Phase = string.format("Godspeed mining %d crystals", #batch)
        local deadline = os.clock() + maximumHold + 0.75
        repeat
            task.wait(0.05)
        until not state.Alive
            or not (state.Master or state.AutoFarm)
            or os.clock() >= deadline

        local nextWeight, nextCount = cargo()
        local credited = math.max(0, nextCount - beforeCount)
        state.LastGodspeedCredited = credited
        if credited > 0 or nextWeight > beforeWeight + 0.001 then
            state.ConsecutiveFailures = 0
            state.LastError = "None"
            state.Phase = string.format(
                "Godspeed credited %d/%d crystals",
                credited,
                #batch
            )
            return true
        end
        return false
    end

    local function mineTarget(target)
        if not target or not target.Crystal.Parent then
            return false, "target vanished"
        end
        state.Target = target.Crystal
        state.RejectedTarget = nil
        state.TargetName = string.format("%s | T%d | $%s", target.Name, target.Tier, tostring(math.floor(target.Value)))
        equipBestPickaxe()
        local beforeWeight, beforeCount = cargo()
        local moved, moveError = travelTo(target.Part.Position)
        if not moved then
            return false, moveError
        end
        if state.RejectedTarget == target.Crystal then
            return false, "crystal pulled character below the map"
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
        if runGodspeedBatch() then
            return true
        end
        local deadline = os.clock() + 18
        local hit = 0
        while state.Alive
            and (state.Master or state.AutoFarm)
            and os.clock() < deadline
            and target.Crystal.Parent
            and state.RejectedTarget ~= target.Crystal
            and target.Crystal:GetAttribute("Value") ~= nil do
            local currentAir = tonumber(statValue("CurrentAir", 0)) or 0
            local airCapacity = math.max(1, tonumber(statValue("AirCapacity", 1)) or 1)
            if state.FreezeGuard
                and LocalPlayer:GetAttribute("IsFreezing") == true
                and currentAir <= math.max(1, airCapacity * 0.12) then
                return false, "freeze guard interrupted mining"
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

    local function queueMountainResume()
        if state.TeleportResumeQueued
            or environment.VORMountainTeleportQueuedJob == game.JobId then
            state.TeleportResumeQueued = true
            return true
        end
        local queue, method = queueFunction()
        state.TeleportQueueMethod = method
        if type(queue) ~= "function" then
            return false, "This executor does not expose a teleport queue"
        end

        local visitedEntries = {}
        for jobId, seen in pairs(visitedServers) do
            if seen and type(jobId) == "string" and #visitedEntries < 50 then
                table.insert(visitedEntries, string.format("[%q]=true", jobId))
            end
        end
        table.sort(visitedEntries)
        local loaderUrl = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/loader.lua?mountainhop="
            .. tostring(game.JobId):gsub("[^%w%-]", "")
        local payload = table.concat({
            "repeat task.wait() until game:IsLoaded()",
            "task.wait(0.2)",
            "local e = type(getgenv) == \"function\" and getgenv() or _G",
            "e.VORMountainResumeHopLegendary = false",
            "e.VORMountainResumeHopMythic = false",
            "e.VORMountainResumeHighTierHunt = " .. tostring(state.HighTierHunt),
            "e.VORMountainResumeSoloSession = " .. tostring(state.SoloSession),
            "e.VORMountainVisitedServers = {" .. table.concat(visitedEntries, ",") .. "}",
            "loadstring(game:HttpGet(" .. string.format("%q", loaderUrl) .. "))()",
        }, "\n")
        local ok, message = pcall(queue, payload)
        if not ok then
            return false, tostring(message)
        end
        state.TeleportResumeQueued = true
        state.TeleportQueueMethod = method
        environment.VORMountainTeleportQueuedJob = game.JobId
        return true
    end

    local function rareCrystalCounts()
        local counts, highTierTotal, total, buried = {}, 0, 0, 0
        local roots = crystalRoots()
        for _, folder in ipairs(roots) do
            for _, crystal in ipairs(folder:GetChildren()) do
                local part, prompt = crystalTargetPartAndPrompt(crystal)
                local tier = tonumber(
                    crystal:GetAttribute("Tier")
                        or (part and part:GetAttribute("Tier"))
                ) or 0
                local available = crystal:GetAttribute("Collected") ~= true
                    and crystal:GetAttribute("Value") ~= nil
                    and part ~= nil
                if available then
                    if isInvalidCrystal(crystal, part, prompt) then
                        buried += 1
                    else
                        total += 1
                        if highTierNames[tier] then
                            counts[tier] = (counts[tier] or 0) + 1
                            highTierTotal += 1
                        end
                    end
                end
            end
        end
        return counts, highTierTotal, total, #roots, buried
    end

    local function openPublicServers()
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
                    table.insert(servers, server)
                end
            end
            cursor = data.nextPageCursor
            if #servers > 0 or not cursor then
                break
            end
        end
        return servers
    end

    local function hopToFreshServer(reason)
        if state.HopBusy then
            return
        end
        state.HopBusy = true
        closeHopCountdown()
        state.HopStatus = "Selling cargo before server hop"
        local _, count = cargo()
        if count > 0 then
            sellCargo(false)
        end

        local queued, queueError = queueMountainResume()
        if not queued then
            state.HopBusy = false
            state.HopStatus = "Auto-resume unavailable"
            state.LastError = "Server hop: " .. tostring(queueError)
            notify("Rare Crystal Hop", state.LastError, 6)
            return
        end

        local ok, result = pcall(openPublicServers)
        if not ok or #result == 0 then
            state.HopBusy = false
            state.HopMissingScans = 0
            state.HopStatus = "No fresh public server found"
            state.LastError = ok and state.HopStatus or tostring(result)
            return
        end

        table.sort(result, function(a, b)
            local aPlayers = tonumber(a.playing) or math.huge
            local bPlayers = tonumber(b.playing) or math.huge
            if aPlayers == bPlayers then
                return tostring(a.id) < tostring(b.id)
            end
            return aPlayers < bPlayers
        end)
        local selected = state.SoloSession and result[1] or result[math.random(1, #result)]
        visitedServers[selected.id] = true
        state.HopStatus = "Hopping: " .. tostring(reason)
        state.Phase = state.HopStatus
        TeleportService:TeleportToPlaceInstance(game.PlaceId, selected.id, LocalPlayer)
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

    local function catalogScore(category, item)
        local stats = item and item.stats or {}
        if category == "Pickaxes" then
            return tonumber(stats.DigPower) or 0
        end
        return tonumber(stats.WeightLimit) or tonumber(item and item.backpackIndex) or 0
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
                local score = catalogScore(category, item)
                if score > bestScore then
                    best, bestScore = item, score
                end
            end
        end
        return best
    end

    local function equipBestOwned(category)
        if not ShopCatalog or type(ShopCatalog.getCategory) ~= "function" then
            return false
        end
        local list = ShopCatalog.getCategory(category) or {}
        local best, bestScore = nil, -math.huge
        for _, candidate in ipairs(list) do
            if not candidate.adminOnly and isOwned(category, candidate.id) then
                local score = catalogScore(category, candidate)
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
        local ownedBestScore = -math.huge
        if ShopCatalog and type(ShopCatalog.getCategory) == "function" then
            for _, ownedItem in ipairs(ShopCatalog.getCategory(category) or {}) do
                if not ownedItem.adminOnly and isOwned(category, ownedItem.id) then
                    ownedBestScore = math.max(ownedBestScore, catalogScore(category, ownedItem))
                end
            end
        end
        if not item
            or (tonumber(item.price) or 0) <= 0
            or catalogScore(category, item) <= ownedBestScore then
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

    local function ownedPlot()
        local things = workspace:FindFirstChild("Things")
        local plots = things and things:FindFirstChild("Plots")
        local slots = plots and plots:FindFirstChild("Slots")
        return slots and slots:FindFirstChild(LocalPlayer.Name)
    end

    local function parseMoneyText(value)
        local clean = tostring(value or ""):gsub("[^%d%.KkMmBbTt]", "")
        local amount, suffix = clean:match("([%d%.]+)([KkMmBbTt]?)")
        amount = tonumber(amount)
        if not amount then
            return nil
        end
        local multipliers = {
            K = 1e3,
            M = 1e6,
            B = 1e9,
            T = 1e12,
        }
        return amount * (multipliers[string.upper(suffix or "")] or 1)
    end

    local function plotUpgradePrice()
        local plot = ownedPlot()
        local upgrade = plot and plot:FindFirstChild("Upgrade")
        local text = upgrade and upgrade:FindFirstChild("Text")
        local surface = text and text:FindFirstChild("SurfaceGui")
        local buyButton = surface and surface:FindFirstChild("BuyButton")
        local priceLabel = buyButton and buyButton:FindFirstChild("Label")
        return priceLabel and parseMoneyText(priceLabel.Text) or nil
    end

    local function upgradePlotCapacity(manual)
        if not Remotes:FindFirstChild("UpgradePlotCapacity") then
            state.LastError = "UpgradePlotCapacity remote missing"
            return false
        end
        local beforeCapacity = tonumber(statValue("PlotCapacity", 0)) or 0
        local beforeCash = getCash()
        local price = plotUpgradePrice()
        if price and beforeCash - state.CashReserve + 0.001 < price then
            if manual then
                notify("Plot Upgrade", "Not enough cash after reserve.")
            end
            return false
        end
        Remotes.UpgradePlotCapacity:FireServer()
        task.wait(0.5)
        local nextCapacity = tonumber(statValue("PlotCapacity", 0)) or 0
        local credited = nextCapacity > beforeCapacity or getCash() < beforeCash
        if credited then
            state.LastPurchase = price or math.max(0, beforeCash - getCash())
            state.LastError = "None"
            if manual then
                notify(
                    "Plot Upgraded",
                    string.format("%d to %d crystal slots.", beforeCapacity, nextCapacity)
                )
            end
            return true
        end
        if manual then
            notify("Plot Upgrade", "Server did not credit the slot purchase.")
        end
        return false
    end

    local function runPurchases()
        if state.PurchaseBusy then
            return false
        end
        state.PurchaseBusy = true
        local ok, err = xpcall(function()
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
            if state.Master or state.AutoPlotCapacity then
                upgradePlotCapacity(false)
            end
            equipBestOwned("Pickaxes")
            equipBestOwned("Backpacks")
        end, function(message)
            return debug.traceback(tostring(message), 2)
        end)
        state.PurchaseBusy = false
        state.LastAutoPurchase = os.clock()
        if not ok then
            state.LastError = "Auto purchase error: " .. tostring(err)
        end
        return ok
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

    local function emergencyReviveAtBase()
        local _, humanoid = characterParts()
        state.Phase = "Emergency cold reset"
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
            task.wait(0.15)
        end
        if Remotes:FindFirstChild("ReviveBase") then
            Remotes.ReviveBase:FireServer()
        end
        local deadline = os.clock() + 6
        repeat
            task.wait(0.15)
            local _, nextHumanoid = characterParts()
            if nextHumanoid and nextHumanoid.Health > 0
                and LocalPlayer:GetAttribute("IsFreezing") ~= true then
                state.LastError = "None"
                return true
            end
        until os.clock() >= deadline
        state.LastError = "base revive was not credited"
        return false
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
    local serverHopLabel = ServerHopSection:AddLabel("High-tier crystals: ?")
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
    MainFarmSection:AddToggle({
        Name = "Godspeed Multi-Mine",
        Description = "Overlaps server-timed E holds for several credited crystals around you",
        Flag = "mam_godspeed_mining",
        Default = true,
        Callback = function(enabled)
            state.GodspeedMining = enabled
        end,
    })
    MainFarmSection:AddToggle({
        Name = "Godspeed Pickaxe",
        Description = "Uses the pickaxe's built-in NoSwingCooldown path while you hold mine",
        Flag = "mam_godspeed_pickaxe",
        Default = false,
        Callback = function(enabled)
            state.GodspeedPickaxe = enabled
            setGodspeedPickaxe(enabled)
        end,
    })
    MainFarmSection:AddSlider({
        Name = "Godspeed Radius",
        Flag = "mam_godspeed_radius",
        Min = 5,
        Max = 40,
        Step = 1,
        Default = 18,
        Suffix = " studs",
        Callback = function(value)
            state.GodspeedRadius = math.clamp(tonumber(value) or 18, 5, 40)
        end,
    })
    MainFarmSection:AddSlider({
        Name = "Godspeed Batch Size",
        Flag = "mam_godspeed_batch_size",
        Min = 2,
        Max = 25,
        Step = 1,
        Default = 8,
        Suffix = " crystals",
        Callback = function(value)
            state.GodspeedBatchSize = math.clamp(math.floor(tonumber(value) or 8), 2, 25)
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

    ServerHopSection:AddToggle({
        Name = "Auto High-Tier Hunt + Hop",
        Description = "Hunts Legendary through Ultima, switches tiers automatically, and hops only when all seven tiers are gone",
        Flag = "mam_high_tier_hunt_hop",
        Default = state.HighTierHunt,
        Callback = function(enabled)
            state.HighTierHunt = enabled
            state.HopMissingScans = 0
            if not enabled then
                closeHopCountdown()
            end
            environment.VORMountainResumeHopLegendary = false
            environment.VORMountainResumeHopMythic = false
            environment.VORMountainResumeHighTierHunt = enabled
        end,
    })
    ServerHopSection:AddLabel(
        "Pool: Legendary, Mythic, Divine, Empyrean (Imperium), Zenith, Infinity, Ultima"
    )

    TargetSection:AddLabel("Auto Mine Search: Entire mountain (expanded streaming radius)")
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
        Name = "Maximum Crystal Tier",
        Description = "Auto avoids high-HP rocks that waste time with the current pickaxe",
        Flag = "mam_maximum_tier",
        Options = {"Auto", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Empyrean", "Zenith", "Infinity", "Ultima"},
        Default = "Auto",
        Callback = function(value)
            state.MaximumTier = value == "Auto" and 0 or (tierNames[value] or 0)
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

    PlotSection:AddToggle({
        Name = "Auto Upgrade Plot Slots",
        Description = "Buys the next server-priced crystal slot when cash reserve allows it",
        Flag = "mam_auto_plot_capacity",
        Default = false,
        Callback = function(enabled)
            state.AutoPlotCapacity = enabled
        end,
    })
    PlotSection:AddButton({
        Name = "Upgrade Plot Once",
        Callback = function()
            task.spawn(upgradePlotCapacity, true)
        end,
    })
    PlotSection:AddLabel("The game server prices and credits every additional plot slot.")

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
            if not enabled then
                local _, humanoid = characterParts()
                if humanoid and state.OriginalWalkSpeed then
                    humanoid.WalkSpeed = state.OriginalWalkSpeed
                end
                state.OriginalWalkSpeed = nil
            end
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

    VisibilitySection:AddLabel("Server invisibility: unavailable in the current game build.")
    VisibilitySection:AddLabel("No fake local-only transparency toggle is included.")
    VisibilitySection:AddLabel("The game must expose a replicated hidden state before other players can truly stop rendering you.")
    VisibilitySection:AddToggle({
        Name = "Stealth Session (Solo Server)",
        Description = "Uses the emptiest public server and leaves again if another player joins",
        Flag = "mam_solo_session",
        Default = state.SoloSession,
        Callback = function(enabled)
            state.SoloSession = enabled
            environment.VORMountainResumeSoloSession = enabled
            if enabled and #Players:GetPlayers() > 1 then
                state.LastSoloHopAttempt = os.clock()
                notify("Stealth Session", "Other players detected. Moving to the emptiest fresh server.", 4)
                task.spawn(hopToFreshServer, "stealth session player guard")
            end
        end,
    })

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
        Name = "Farm Float",
        Description = "Holds your current height without lifting you, so wall crystals cannot drop you",
        Flag = "mam_farm_float",
        Default = true,
        Callback = function(enabled)
            state.FarmFloat = enabled
            if not enabled and state.FloatMover then
                state.FloatMover:Destroy()
                state.FloatMover = nil
                state.FloatRoot = nil
            end
        end,
    })
    SafetySection:AddToggle({
        Name = "Anti Ragdoll",
        Description = "Immediately cancels fall ragdoll during the mining loop",
        Flag = "mam_anti_ragdoll",
        Default = true,
        Callback = function(enabled)
            state.AntiRagdoll = enabled
            local character, humanoid = characterParts()
            if enabled then
                configureRagdollStates(character, humanoid)
                clearActiveRagdoll(character, humanoid)
            elseif humanoid then
                pcall(function()
                    if state.OriginalFallingDownEnabled ~= nil then
                        humanoid:SetStateEnabled(
                            Enum.HumanoidStateType.FallingDown,
                            state.OriginalFallingDownEnabled
                        )
                    end
                    if state.OriginalRagdollEnabled ~= nil then
                        humanoid:SetStateEnabled(
                            Enum.HumanoidStateType.Ragdoll,
                            state.OriginalRagdollEnabled
                        )
                    end
                end)
            end
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

    track(Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer and state.SoloSession then
            state.LastSoloHopAttempt = os.clock()
            notify("Stealth Session", player.DisplayName .. " joined. Leaving before they can watch the farm.", 4)
            task.delay(1, function()
                if state.Alive and state.SoloSession then
                    hopToFreshServer("another player entered the stealth session")
                end
            end)
        end
    end))

    task.spawn(function()
        while state.Alive do
            if state.SoloSession
                and #Players:GetPlayers() > 1
                and not state.HopBusy
                and os.clock() - state.LastSoloHopAttempt >= 15 then
                state.LastSoloHopAttempt = os.clock()
                task.spawn(hopToFreshServer, "stealth session population guard")
            end
            task.wait(3)
        end
    end)

    track(TeleportService.TeleportInitFailed:Connect(function(player, _, message)
        if player ~= LocalPlayer or not state.HopBusy then
            return
        end
        state.HopBusy = false
        state.HopMissingScans = 0
        state.TeleportResumeQueued = false
        environment.VORMountainTeleportQueuedJob = nil
        state.HopStatus = "Teleport failed; retrying scan"
        state.LastError = "Server hop: " .. tostring(message)
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
                    and LocalPlayer:GetAttribute("IsFreezing") == true
                    and currentAir <= math.max(1, airCapacity * 0.12)
                local recovering = state.FreezeGuard
                    and LocalPlayer:GetAttribute("IsFreezing") ~= true
                    and currentAir < airCapacity * 0.85
                local shouldSell = (state.Master or state.AutoSell)
                    and weight > 0
                    and (cap < math.huge and weight >= cap * (state.SellPercent / 100))

                if recovering then
                    state.Phase = string.format(
                        "Recovering warmth (%d/%d)",
                        math.floor(currentAir),
                        math.floor(airCapacity)
                    )
                    task.wait(0.5)
                elseif mustEscape then
                    state.Phase = "Freeze guard returning"
                    if weight > 0 then
                        if sellCargo(false) then
                            runPurchases()
                        else
                            emergencyReviveAtBase()
                        end
                    else
                        emergencyReviveAtBase()
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
            local enabled = state.HighTierHunt
            local tierCounts, highTierTotal, total, rootCount, buried = rareCrystalCounts()
            state.HighTierCounts = tierCounts
            state.HighTierCount = highTierTotal
            state.BuriedCrystalCount = buried
            local now = os.clock()
            if total > state.LastObservedCrystalTotal then
                state.LastCrystalGrowthAt = now
            end
            state.LastObservedCrystalTotal = total
            state.StreamingStableFor = now - state.LastCrystalGrowthAt
            local mountainGenerating = workspace:GetAttribute("MountainGenerating")
            local groundStrataBaked = workspace:GetAttribute("GroundStrataBaked")
            local generationSettled = mountainGenerating == false
                and groundStrataBaked ~= false
                and rootCount > 0
                and state.StreamingStableFor >= 15
                and (state.StreamingExpanded
                    or now - state.HopStartedAt >= 30)
            if mountainGenerating ~= false or groundStrataBaked == false then
                state.GenerationReady = false
            elseif generationSettled then
                state.GenerationReady = true
            end
            if enabled and not state.HopBusy then
                local replicationReady = state.GenerationReady
                if replicationReady and highTierTotal == 0 then
                    if not state.HopCountdownEndsAt then
                        state.HopCountdownEndsAt = now + state.HopCountdownDuration
                    end
                    local remaining = math.max(0, state.HopCountdownEndsAt - now)
                    updateHopCountdown(remaining)
                    state.HopStatus = string.format(
                        "No high tiers detected - rescanning before hop (%ds)",
                        math.max(0, math.ceil(remaining))
                    )
                    if remaining <= 0 then
                        local _, finalHighTierTotal = rareCrystalCounts()
                        if finalHighTierTotal == 0 then
                            closeHopCountdown()
                            task.spawn(hopToFreshServer, "all high tiers gone after 15-second rescan")
                        else
                            closeHopCountdown()
                            state.HopStatus = string.format(
                                "Hop canceled - %d new high-tier crystal(s)",
                                finalHighTierTotal
                            )
                        end
                    end
                else
                    state.HopMissingScans = 0
                    if state.HopCountdownEndsAt or state.HopCountdownFrame then
                        closeHopCountdown()
                    end
                    if not replicationReady then
                        if mountainGenerating ~= false
                            or groundStrataBaked == false then
                            state.HopStatus = "Waiting for mountain generation"
                        elseif not state.StreamingExpanded
                            and now - state.HopStartedAt < 30 then
                            state.HopStatus = "Waiting for full mountain stream"
                        else
                            state.HopStatus = string.format(
                                "Loading full mountain (%.0f/15s stable)",
                                math.min(15, state.StreamingStableFor)
                            )
                        end
                    else
                        state.HopStatus = string.format(
                            "Watching %d high-tier / %d total",
                            highTierTotal,
                            total
                        )
                    end
                end
            elseif not enabled then
                state.HopMissingScans = 0
                if state.HopCountdownEndsAt or state.HopCountdownFrame then
                    closeHopCountdown()
                end
                state.HopStatus = "High-tier hunt and hop disabled"
            end
            task.wait(1)
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

    task.spawn(function()
        while state.Alive do
            local independentAutoBuy = state.AutoPickaxe
                or state.AutoBackpack
                or state.AutoWarmth
                or state.AutoWeight
                or state.AutoPlotCapacity
            if independentAutoBuy
                and not state.PurchaseBusy
                and os.clock() - state.LastAutoPurchase >= 1.25 then
                runPurchases()
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while state.Alive do
            if state.GodspeedPickaxe then
                setGodspeedPickaxe(true)
            end
            task.wait(0.5)
        end
    end)

    local speedBindName = "VORMountainSpeedLock_" .. tostring(LocalPlayer.UserId)
    RunService:BindToRenderStep(speedBindName, Enum.RenderPriority.Last.Value, function()
        if not state.Alive or not state.WalkSpeedEnabled then
            return
        end
        local _, humanoid, root = characterParts()
        if not (humanoid and root and humanoid.Health > 0) then
            return
        end
        if state.OriginalWalkSpeed == nil then
            state.OriginalWalkSpeed = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = state.WalkSpeed
        local direction = humanoid.MoveDirection
        local currentState = humanoid:GetState()
        if direction.Magnitude > 0.05
            and currentState ~= Enum.HumanoidStateType.Physics
            and currentState ~= Enum.HumanoidStateType.FallingDown
            and currentState ~= Enum.HumanoidStateType.Dead then
            local velocity = root.AssemblyLinearVelocity
            local horizontal = direction.Unit * state.WalkSpeed
            root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
        end
    end)

    track(RunService.Heartbeat:Connect(function()
        if not state.Alive then
            return
        end
        local character, humanoid, root = characterParts()
        configureRagdollStates(character, humanoid)
        clearActiveRagdoll(character, humanoid)
        updateFarmFloat(character, humanoid, root)
        if character and humanoid and root and humanoid.Health > 0 then
            local baseY = tonumber(workspace:GetAttribute("MountainBaseY"))
            local now = os.clock()
            if baseY and root.Position.Y < baseY - 8
                and (state.Master or state.AutoFarm)
                and now - state.LastFloorRecoveryAt >= 0.25 then
                local badTarget = state.Target
                if badTarget and badTarget.Parent then
                    state.InvalidTargets[badTarget] = true
                    state.FailedTargets[badTarget] = os.clock() + 120
                    state.RejectedTarget = badTarget
                end
                local fallback = state.LastSafeCFrame
                if not fallback then
                    local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
                    fallback = CFrame.new(
                        spawn and spawn.Position + Vector3.new(0, 4, 0)
                            or Vector3.new(0, baseY + 8, 0)
                    )
                end
                character:PivotTo(fallback)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                state.FloorRecoveries += 1
                state.LastFloorRecoveryAt = now
                state.Phase = badTarget and "Skipped crystal below map"
                    or "Recovered above mountain floor"
                state.LastError = badTarget
                    and "Crystal path crossed below the mountain floor"
                    or "Recovered character from below the mountain floor"
            elseif baseY
                and root.Position.Y >= baseY + 2
                and humanoid.FloorMaterial ~= Enum.Material.Air then
                state.LastSafeCFrame = character:GetPivot()
            end
        end
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
        local tierCounts = state.HighTierCounts
        serverHopLabel.Text = string.format(
            "High-tier: %d | L%d M%d D%d E%d Z%d I%d U%d\nSkipped invalid/below map: %d | %s",
            state.HighTierCount,
            tierCounts[5] or 0,
            tierCounts[6] or 0,
            tierCounts[7] or 0,
            tierCounts[8] or 0,
            tierCounts[9] or 0,
            tierCounts[10] or 0,
            tierCounts[11] or 0,
            state.BuriedCrystalCount,
            state.HopStatus
        )
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
            gui:SetAttribute("MineAMountainAutoPurchaseActive", state.AutoPickaxe
                or state.AutoBackpack
                or state.AutoWarmth
                or state.AutoWeight
                or state.AutoPlotCapacity)
            gui:SetAttribute("MineAMountainPurchaseBusy", state.PurchaseBusy)
            gui:SetAttribute("MineAMountainLastAutoPurchase", state.LastAutoPurchase)
            gui:SetAttribute("MineAMountainGodspeed", state.GodspeedMining)
            gui:SetAttribute("MineAMountainGodspeedCredited", state.LastGodspeedCredited)
            gui:SetAttribute("MineAMountainGodspeedPickaxe", state.GodspeedPickaxe)
            gui:SetAttribute("MineAMountainHighTierCount", state.HighTierCount)
            gui:SetAttribute("MineAMountainLegendaryCount", tierCounts[5] or 0)
            gui:SetAttribute("MineAMountainMythicCount", tierCounts[6] or 0)
            gui:SetAttribute("MineAMountainDivineCount", tierCounts[7] or 0)
            gui:SetAttribute("MineAMountainEmpyreanCount", tierCounts[8] or 0)
            gui:SetAttribute("MineAMountainZenithCount", tierCounts[9] or 0)
            gui:SetAttribute("MineAMountainInfinityCount", tierCounts[10] or 0)
            gui:SetAttribute("MineAMountainUltimaCount", tierCounts[11] or 0)
            gui:SetAttribute("MineAMountainHighTierHunt", state.HighTierHunt)
            gui:SetAttribute("MineAMountainBuriedCrystalCount", state.BuriedCrystalCount)
            gui:SetAttribute("MineAMountainFloorRecoveries", state.FloorRecoveries)
            gui:SetAttribute("MineAMountainHopStatus", state.HopStatus)
            gui:SetAttribute("MineAMountainHopCountdownActive", state.HopCountdownEndsAt ~= nil)
            gui:SetAttribute("MineAMountainHopCountdownRemaining", state.HopCountdownRemaining)
            gui:SetAttribute("MineAMountainSoloSession", state.SoloSession)
            gui:SetAttribute("MineAMountainGenerationReady", state.GenerationReady)
            gui:SetAttribute("MineAMountainStreamingStableFor", state.StreamingStableFor)
            gui:SetAttribute("MineAMountainStreamingExpanded", state.StreamingExpanded)
            gui:SetAttribute("MineAMountainStreamingRadius", state.StreamingRadius)
            gui:SetAttribute("MineAMountainTeleportResumeQueued", state.TeleportResumeQueued)
            gui:SetAttribute("MineAMountainTeleportQueueMethod", state.TeleportQueueMethod)
            gui:SetAttribute("MineAMountainPlotCapacity", tonumber(statValue("PlotCapacity", 0)) or 0)
            gui:SetAttribute("MineAMountainPlotLuck", tonumber(statValue("PlotLuck", 0)) or 0)
            gui:SetAttribute("MineAMountainAntiRagdoll", state.AntiRagdoll)
            gui:SetAttribute("MineAMountainFarmFloat", state.FloatMover ~= nil
                and state.FloatMover.Parent == root)
            gui:SetAttribute("MineAMountainWalkSpeedLock", state.WalkSpeedEnabled)
        end)
    end))

    track(gui.Destroying:Connect(function()
        state.Alive = false
        closeHopCountdown()
        RunService:UnbindFromRenderStep(speedBindName)
        local character, humanoid = characterParts()
        setTravelCollision(character, false)
        if humanoid then
            if state.OriginalWalkSpeed then
                humanoid.WalkSpeed = state.OriginalWalkSpeed
            end
            pcall(function()
                if state.OriginalFallingDownEnabled ~= nil then
                    humanoid:SetStateEnabled(
                        Enum.HumanoidStateType.FallingDown,
                        state.OriginalFallingDownEnabled
                    )
                end
                if state.OriginalRagdollEnabled ~= nil then
                    humanoid:SetStateEnabled(
                        Enum.HumanoidStateType.Ragdoll,
                        state.OriginalRagdollEnabled
                    )
                end
            end)
        end
        if state.FloatMover then
            state.FloatMover:Destroy()
            state.FloatMover = nil
            state.FloatRoot = nil
        end
        if type(sethiddenproperty) == "function" then
            if state.OriginalStreamingMinimum ~= nil then
                pcall(
                    sethiddenproperty,
                    workspace,
                    "StreamingMinRadius",
                    state.OriginalStreamingMinimum
                )
            end
            if state.OriginalStreamingTarget ~= nil then
                pcall(
                    sethiddenproperty,
                    workspace,
                    "StreamingTargetRadius",
                    state.OriginalStreamingTarget
                )
            end
        end
        setGodspeedPickaxe(false)
        targetHighlight:Destroy()
    end))

    pcall(function()
        gui:SetAttribute("MineAMountainAdapter", true)
        gui:SetAttribute("MineAMountainUniverseId", 10187294555)
        gui:SetAttribute("MineAMountainPlaceId", 125927821145949)
        gui:SetAttribute("MineAMountainCreditedLoop", "CrystalPrompt>SellRequest>ShopBuy>UpgradeBuy")
    end)
end
