-- Solix feature-parity extension for the modular Blox Fruits builder.
-- Kept separate so the main game builder stays below Luau's register ceiling.
return function(context)
    local Window = assert(context.Window, "parity module requires Window")
    local gui = assert(context.Gui, "parity module requires Gui")
    local track = assert(context.Track, "parity module requires Track")
    local pages = assert(context.Pages, "parity module requires Pages")
    local sharedState = assert(context.State, "parity module requires State")
    local remotes = assert(context.Remotes, "parity module requires Remotes")
    local helpers = assert(context.Helpers, "parity module requires Helpers")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer

    local runtime = {
        Alive = true,
        AutoBuyBusoColor = false,
        SelectedSwords = {},
        SwordTargetMastery = 600,
        AutoSwitchSword = false,
        AutoUse = {Library = false, Water = false, Hidden = false, Fire = false},
        MasteryEnabled = false,
        MasteryType = "Devil Fruit",
        MasteryHealthPercent = 35,
        MasteryHoldTime = 0.15,
        AutoGrabFruit = false,
        RaidFruitValue = 1000000,
        AutoRaidFruit = false,
        AutoLawChip = false,
        AutoStartLaw = false,
        AutoLawRaid = false,
        BetterAwakening = false,
        Esp = {Fruit = false, Berry = false, Flower = false, Islands = {}},
        BossNotifications = false,
        IslandNotifications = false,
        EspObjects = setmetatable({}, {__mode = "k"}),
        LastLoop = 0,
        LastSlowLoop = 0,
        LastBusoBuy = 0,
        LastSwordSwitch = 0,
        LastKeyUse = 0,
        LastRaidFruit = 0,
        LastLaw = 0,
        LastGrab = 0,
        LastProfileProgress = 0,
        CachedMeleeProgress = "Reading...",
        MasteryKeyIndex = 0,
    }

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 3)
    end

    local function rawInvoke(command, ...)
        if not remotes.CommF then
            return false, "CommF_ unavailable"
        end
        local arguments = table.pack(...)
        return pcall(function()
            return remotes.CommF:InvokeServer(command, table.unpack(arguments, 1, arguments.n))
        end)
    end

    local function bypassWarp(targetCFrame)
        if typeof(targetCFrame) ~= "CFrame" then
            return false
        end
        local startingRoot = helpers.RootPart()
        if not startingRoot then
            return false
        end
        if (startingRoot.Position - targetCFrame.Position).Magnitude <= 8 then
            startingRoot.CFrame = targetCFrame
            return true
        end

        local data = LocalPlayer:FindFirstChild("Data")
        local spawnValue = data and data:FindFirstChild("SpawnPoint")
        local oldSpawn = spawnValue and tostring(spawnValue.Value) or ""
        gui:SetAttribute("BloxBypassTeleportStage", "Portal request")

        -- Third Sea only accepts requestEntrance for real portals. Try that
        -- cheap path first, then use the death/respawn island warp Solix uses
        -- for arbitrary destinations and verify the server kept the arrival.
        rawInvoke("requestEntrance", targetCFrame.Position)
        task.wait(0.65)
        local portalRoot = helpers.RootPart()
        if portalRoot and (portalRoot.Position - targetCFrame.Position).Magnitude <= 150 then
            portalRoot.CFrame = targetCFrame
            task.wait(0.45)
            local verifiedRoot = helpers.RootPart()
            local portalArrived = verifiedRoot ~= nil
                and (verifiedRoot.Position - targetCFrame.Position).Magnitude <= 180
            gui:SetAttribute("BloxBypassTeleportArrived", portalArrived)
            gui:SetAttribute("BloxBypassTeleportStage", portalArrived and "Portal verified" or "Portal snap-back")
            if portalArrived then
                return true
            end
        end

        local oldCharacter = helpers.Character()
        local oldHumanoid = helpers.Humanoid()
        local warpRoot = helpers.RootPart()
        if not oldCharacter or not oldHumanoid or not warpRoot then
            return false
        end
        gui:SetAttribute("BloxBypassTeleportStage", "Replicating destination")
        for _ = 1, 20 do
            warpRoot.AssemblyLinearVelocity = Vector3.zero
            warpRoot.AssemblyAngularVelocity = Vector3.zero
            warpRoot.CFrame = targetCFrame
            task.wait(0.06)
        end
        local expectedLocation = tostring(LocalPlayer:GetAttribute("CurrentLocation") or "")
        local spawnCommitted = expectedLocation == "" or expectedLocation == "Default"
        for _ = 1, 4 do
            rawInvoke("SetSpawnPoint")
            task.wait(0.25)
            local currentSpawn = spawnValue and tostring(spawnValue.Value) or ""
            if currentSpawn ~= "" and currentSpawn ~= "Default"
                and (expectedLocation == "" or currentSpawn == expectedLocation) then
                spawnCommitted = true
                break
            end
            if currentSpawn == oldSpawn and currentSpawn == expectedLocation then
                spawnCommitted = true
                break
            end
        end
        if not spawnCommitted then
            gui:SetAttribute("BloxBypassTeleportStage", "Spawn rejected; using smooth travel")
            gui:SetAttribute("BloxBypassTeleportArrived", false)
            return false
        end

        gui:SetAttribute("BloxBypassTeleportStage", "Respawning at destination")
        pcall(function()
            oldHumanoid.Health = 0
            oldHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
        end)

        local deadline = os.clock() + 10
        repeat
            task.wait(0.1)
        until os.clock() >= deadline
            or (helpers.Character() ~= oldCharacter and helpers.RootPart() ~= nil)

        local newCharacter = helpers.Character()
        local newRoot = helpers.RootPart()
        local newHumanoid = helpers.Humanoid()
        if not newCharacter or newCharacter == oldCharacter or not newRoot or not newHumanoid or newHumanoid.Health <= 0 then
            gui:SetAttribute("BloxBypassTeleportStage", "Respawn timed out; using smooth travel")
            return false
        end
        task.wait(0.55)
        gui:SetAttribute("BloxBypassTeleportStage", "Confirming server position")
        for _ = 1, 24 do
            newRoot.AssemblyLinearVelocity = Vector3.zero
            newRoot.AssemblyAngularVelocity = Vector3.zero
            newRoot.CFrame = targetCFrame
            task.wait(0.06)
        end
        rawInvoke("SetSpawnPoint")
        task.wait(0.65)
        local finalRoot = helpers.RootPart()
        local arrived = finalRoot ~= nil and (finalRoot.Position - targetCFrame.Position).Magnitude <= 180
        gui:SetAttribute("BloxBypassTeleportArrived", arrived)
        gui:SetAttribute("BloxBypassTeleportStage", arrived and "Server position verified" or "Snap-back detected; using smooth travel")
        return arrived
    end
    sharedState.BypassWarp = bypassWarp

    local function valueFrom(parent, name, fallback)
        local object = parent and parent:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            return object.Value
        end
        return fallback
    end

    local function playerData()
        return LocalPlayer:FindFirstChild("Data")
    end

    local function allTools()
        local result = {}
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, container in ipairs({helpers.Character(), backpack}) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") then
                        table.insert(result, child)
                    end
                end
            end
        end
        return result
    end

    local function toolKind(tool)
        local tooltip = string.lower(tostring(tool and tool.ToolTip or ""))
        if tooltip:find("sword", 1, true) then
            return "Sword"
        elseif tooltip:find("gun", 1, true) then
            return "Gun"
        elseif tooltip:find("fruit", 1, true) or tooltip:find("blox", 1, true) then
            return "Devil Fruit"
        elseif tooltip:find("melee", 1, true) then
            return "Melee"
        end
        return "Unknown"
    end

    local function equipTool(tool)
        local humanoid = helpers.Humanoid()
        if humanoid and tool and tool.Parent then
            pcall(function()
                humanoid:EquipTool(tool)
            end)
            return tool.Parent == helpers.Character()
        end
        return false
    end

    local function masteryOf(tool)
        if not tool then
            return 0
        end
        for _, name in ipairs({"Level", "Mastery", "Mas"}) do
            local object = tool:FindFirstChild(name)
            if object and object:IsA("ValueBase") then
                return tonumber(object.Value) or 0
            end
        end
        return tonumber(tool:GetAttribute("Mastery")) or 0
    end

    local function inventory()
        local ok, result = rawInvoke("getInventory")
        if ok and type(result) == "table" then
            return result
        end
        return {}
    end

    local function inventorySwordNames()
        local names = {}
        local seen = {}
        for _, tool in ipairs(allTools()) do
            if toolKind(tool) == "Sword" and not seen[tool.Name] then
                seen[tool.Name] = true
                table.insert(names, tool.Name)
            end
        end
        for _, item in pairs(inventory()) do
            if type(item) == "table" and tostring(item.Type) == "Sword" then
                local name = tostring(item.Name or item.ItemName or "")
                if name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(names, name)
                end
            end
        end
        table.sort(names)
        return #names > 0 and names or {"No swords found"}
    end

    local function loadAndEquip(name)
        for _, tool in ipairs(allTools()) do
            if tool.Name == name then
                return equipTool(tool)
            end
        end
        rawInvoke("LoadItem", name)
        task.wait(0.25)
        for _, tool in ipairs(allTools()) do
            if tool.Name == name then
                return equipTool(tool)
            end
        end
        return false
    end

    local function selectedSwordList()
        local result = {}
        for key, value in pairs(runtime.SelectedSwords) do
            if (type(key) == "number" and type(value) == "string") or value == true then
                table.insert(result, type(key) == "number" and value or key)
            end
        end
        table.sort(result)
        return result
    end

    local function stepSwordMastery()
        if not runtime.AutoSwitchSword or os.clock() - runtime.LastSwordSwitch < 1 then
            return
        end
        runtime.LastSwordSwitch = os.clock()
        local selected = selectedSwordList()
        if #selected == 0 then
            return
        end
        local equipped
        for _, tool in ipairs(allTools()) do
            if tool.Parent == helpers.Character() and toolKind(tool) == "Sword" then
                equipped = tool
                break
            end
        end
        if equipped and table.find(selected, equipped.Name)
            and masteryOf(equipped) < runtime.SwordTargetMastery then
            return
        end
        for _, swordName in ipairs(selected) do
            local mastered = false
            for _, item in pairs(inventory()) do
                if type(item) == "table" and tostring(item.Name) == swordName then
                    mastered = (tonumber(item.Mastery or item.Level) or 0) >= runtime.SwordTargetMastery
                    break
                end
            end
            if not mastered and loadAndEquip(swordName) then
                gui:SetAttribute("BloxMasterySword", swordName)
                return
            end
        end
    end

    local function findToolContaining(needle)
        needle = string.lower(needle)
        for _, tool in ipairs(allTools()) do
            if string.find(string.lower(tool.Name), needle, 1, true) then
                return tool
            end
        end
        return nil
    end

    local function useKey(kind)
        local definitions = {
            Library = {Name = "library key", Command = "BuyDeathStep"},
            Water = {Name = "water key", Command = "BuySharkmanKarate"},
            Hidden = {Name = "hidden key", Command = nil},
            Fire = {Name = "fire essence", Command = "BuyDragonTalon"},
        }
        local definition = definitions[kind]
        local tool = definition and findToolContaining(definition.Name)
        if not tool then
            return false
        end
        equipTool(tool)
        pcall(function()
            tool:Activate()
        end)
        if definition.Command then
            rawInvoke(definition.Command, true)
            rawInvoke(definition.Command)
        end
        gui:SetAttribute("BloxAutoUseLastItem", tool.Name)
        return true
    end

    local function stepAutoUseItems()
        if os.clock() - runtime.LastKeyUse < 2 then
            return
        end
        runtime.LastKeyUse = os.clock()
        for _, kind in ipairs({"Library", "Water", "Hidden", "Fire"}) do
            if runtime.AutoUse[kind] and useKey(kind) then
                return
            end
        end
    end

    local function nearestMasteryTarget()
        local root = helpers.RootPart()
        local enemies = workspace:FindFirstChild("Enemies")
        if not root or not enemies then
            return nil
        end
        local best, bestDistance
        for _, enemy in ipairs(enemies:GetChildren()) do
            local humanoid = enemy:FindFirstChildOfClass("Humanoid")
            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            if humanoid and enemyRoot and humanoid.Health > 0 then
                local distance = (root.Position - enemyRoot.Position).Magnitude
                if distance <= math.max(sharedState.AuraRange or 70, 70)
                    and (not bestDistance or distance < bestDistance) then
                    best, bestDistance = enemy, distance
                end
            end
        end
        return best
    end

    local function masteryTool()
        for _, tool in ipairs(allTools()) do
            if toolKind(tool) == runtime.MasteryType then
                return tool
            end
        end
        return nil
    end

    local function stepMastery()
        if not runtime.MasteryEnabled then
            return
        end
        local target = nearestMasteryTarget()
        local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
        if not targetHumanoid or targetHumanoid.MaxHealth <= 0
            or targetHumanoid.Health / targetHumanoid.MaxHealth * 100 > runtime.MasteryHealthPercent then
            return
        end
        local tool = masteryTool()
        if not tool or not equipTool(tool) then
            return
        end
        runtime.MasteryKeyIndex = runtime.MasteryKeyIndex % 4 + 1
        local key = ({Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V})[runtime.MasteryKeyIndex]
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.delay(runtime.MasteryHoldTime, function()
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)
    end

    local function isFruitTool(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        local lower = string.lower(tool.Name)
        return toolKind(tool) == "Devil Fruit"
            or lower:find("fruit", 1, true) ~= nil
            or lower:match("%-[Ff]ruit$") ~= nil
    end

    local function stepAutoGrabFruit()
        if not runtime.AutoGrabFruit or os.clock() - runtime.LastGrab < 0.75 then
            return
        end
        runtime.LastGrab = os.clock()
        local root = helpers.RootPart()
        if not root then
            return
        end
        for _, object in ipairs(workspace:GetChildren()) do
            if isFruitTool(object) then
                local handle = object:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    root.CFrame = handle.CFrame + Vector3.new(0, 2, 0)
                    if type(firetouchinterest) == "function" then
                        firetouchinterest(root, handle, 0)
                        firetouchinterest(root, handle, 1)
                    end
                    return
                end
            end
        end
    end

    local function fruitPrice(item)
        return tonumber(item and (item.Price or item.Value or item.Cost or item.FruitValue)) or math.huge
    end

    local function loadCheapRaidFruit()
        for _, item in pairs(inventory()) do
            if type(item) == "table" and tostring(item.Type):lower():find("fruit", 1, true) then
                local price = fruitPrice(item)
                if price <= runtime.RaidFruitValue then
                    local name = tostring(item.Name or item.ItemName or "")
                    if name ~= "" then
                        local ok = rawInvoke("LoadFruit", name)
                        if ok then
                            gui:SetAttribute("BloxRaidLoadedFruit", name)
                            return true, name
                        end
                    end
                end
            end
        end
        return false, "No stored fruit under the value cap"
    end

    local function lawRaidButton()
        local map = workspace:FindFirstChild("Map")
        if not map then
            return nil
        end
        for _, object in ipairs(map:GetDescendants()) do
            if object:IsA("ClickDetector") then
                local ancestry = string.lower(object:GetFullName())
                if ancestry:find("raidsummon2", 1, true)
                    or ancestry:find("ordersummon", 1, true)
                    or ancestry:find("lawraid", 1, true) then
                    return object
                end
            end
        end
        return nil
    end

    local function buyLawChip()
        local ok, result = rawInvoke("BlackbeardReward", "Microchip", "2")
        return ok, result
    end

    local function startLawRaid()
        local detector = lawRaidButton()
        if detector and type(fireclickdetector) == "function" then
            fireclickdetector(detector)
            return true
        end
        return false
    end

    local function stepRaidExtras()
        if runtime.AutoRaidFruit and os.clock() - runtime.LastRaidFruit >= 10 then
            runtime.LastRaidFruit = os.clock()
            loadCheapRaidFruit()
        end
        if os.clock() - runtime.LastLaw < 4 then
            return
        end
        runtime.LastLaw = os.clock()
        if runtime.AutoLawChip then
            buyLawChip()
        end
        if runtime.AutoStartLaw then
            startLawRaid()
        end
        if runtime.AutoLawRaid then
            runtime.AutoLawChip = true
            runtime.AutoStartLaw = true
            local control = Window.PersistentControls["blox_auto_raid"]
            if control and not control:Get() then
                control:Set(true)
            end
        end
        if runtime.BetterAwakening then
            for _, npcName in ipairs({"Mysterious Entity", "Awakener"}) do
                if helpers.TeleportToNpc(npcName) then
                    rawInvoke("Awakener", "Awaken")
                    break
                end
            end
        end
    end

    local function removeEsp(object)
        local record = runtime.EspObjects[object]
        if record then
            if record.Parent then
                record:Destroy()
            end
            runtime.EspObjects[object] = nil
        end
    end

    local function addEsp(object, text, color)
        if runtime.EspObjects[object] and runtime.EspObjects[object].Parent then
            runtime.EspObjects[object].TextLabel.Text = text
            return
        end
        local adornee = object:IsA("BasePart") and object
            or object:FindFirstChild("Handle")
            or object:FindFirstChildWhichIsA("BasePart", true)
        if not adornee then
            return
        end
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "VORParityESP"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(220, 28)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Adornee = adornee
        billboard.Parent = gui
        local label = Instance.new("TextLabel")
        label.Name = "TextLabel"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextStrokeTransparency = 0.35
        label.TextColor3 = color
        label.Text = text
        label.Parent = billboard
        runtime.EspObjects[object] = billboard
    end

    local function islandSelected(name)
        local lower = string.lower(name)
        for key, value in pairs(runtime.Esp.Islands) do
            local selected = type(key) == "number" and value or (value == true and key or nil)
            if selected and lower:find(string.lower(selected):gsub(" island", ""), 1, true) then
                return true
            end
        end
        return false
    end

    local function stepEsp()
        local root = helpers.RootPart()
        for object in pairs(runtime.EspObjects) do
            if not object.Parent then
                removeEsp(object)
            end
        end
        if runtime.Esp.Fruit then
            for _, object in ipairs(workspace:GetChildren()) do
                if isFruitTool(object) then
                    local handle = object:FindFirstChild("Handle")
                    local distance = root and handle and math.floor((root.Position - handle.Position).Magnitude) or 0
                    addEsp(object, object.Name .. " [" .. distance .. "m]", Color3.fromRGB(200, 96, 255))
                end
            end
        end
        if runtime.Esp.Berry or runtime.Esp.Flower then
            for _, object in ipairs(workspace:GetDescendants()) do
                local lower = string.lower(object.Name)
                if runtime.Esp.Berry and lower:find("berry", 1, true) then
                    addEsp(object, object.Name, Color3.fromRGB(255, 96, 190))
                elseif runtime.Esp.Flower and lower:find("flower", 1, true) then
                    addEsp(object, object.Name, Color3.fromRGB(96, 220, 255))
                end
            end
        end
        local origin = workspace:FindFirstChild("_WorldOrigin")
        local locations = origin and origin:FindFirstChild("Locations")
        if locations then
            for _, location in ipairs(locations:GetChildren()) do
                if islandSelected(location.Name) then
                    addEsp(location, location.Name, Color3.fromRGB(172, 77, 255))
                end
            end
        end
    end

    local function buildPlayerInfo()
        local section = pages.Player:AddSection("Player Info & Progress", "Left")
        section:AddLabel("Privacy mode: username intentionally hidden")
        local levelLabel = section:AddLabel("Level: Reading...")
        local moneyLabel = section:AddLabel("Beli: Reading...")
        local fragmentLabel = section:AddLabel("Fragments: Reading...")
        local fruitLabel = section:AddLabel("Devil Fruit: Reading...")
        local raceLabel = section:AddLabel("Race: Reading...")
        local meleeLabel = section:AddLabel("Melee unlocks: Reading...")
        runtime.UpdatePlayerInfo = function()
            local data = playerData()
            levelLabel.Text = "Level: " .. tostring(valueFrom(data, "Level", "N/A"))
            moneyLabel.Text = "Beli: " .. tostring(valueFrom(data, "Beli", valueFrom(data, "Money", "N/A")))
            fragmentLabel.Text = "Fragments: " .. tostring(valueFrom(data, "Fragments", "N/A"))
            fruitLabel.Text = "Devil Fruit: " .. tostring(valueFrom(data, "DevilFruit", "None"))
            raceLabel.Text = "Race: " .. tostring(valueFrom(data, "Race", "N/A"))
            if os.clock() - runtime.LastProfileProgress >= 15 then
                runtime.LastProfileProgress = os.clock()
                local unlocked = {}
                for _, entry in ipairs({
                    {"Superhuman", "BuySuperhuman"}, {"Death Step", "BuyDeathStep"},
                    {"Sharkman", "BuySharkmanKarate"}, {"Electric Claw", "BuyElectricClaw"},
                    {"Dragon Talon", "BuyDragonTalon"}, {"Godhuman", "BuyGodhuman"},
                }) do
                    local ok, result = rawInvoke(entry[2], true)
                    if ok and (result == 1 or result == 2 or result == true) then
                        table.insert(unlocked, entry[1])
                    end
                end
                runtime.CachedMeleeProgress = #unlocked > 0 and table.concat(unlocked, ", ") or "None detected"
            end
            meleeLabel.Text = "Melee unlocks: " .. runtime.CachedMeleeProgress
        end
    end

    local function buildBusoAndMastery()
        local buso = pages.Mastery:AddSection("Buso Color", "Left")
        local status = buso:AddLabel("Current Buso: Reading dealer...")
        local function refreshBusoColor(showToast)
            local ok, colorName, rarity = rawInvoke("ColorsDealer", "1")
            status.Text = ok
                and string.format("Current Buso: %s | Rarity: %s", tostring(colorName), tostring(rarity or "?"))
                or "Current Buso: Dealer unavailable"
            if showToast then
                notify("Buso Color", status.Text)
            end
        end
        runtime.RefreshBusoColor = refreshBusoColor
        buso:AddButton({Name = "Refresh Current Buso Color", Callback = function() refreshBusoColor(true) end})
        buso:AddButton({
            Name = "Teleport to Barista Cousin",
            Callback = function()
                local moved = false
                for _, name in ipairs({"Barista Cousin", "Barista Cousin.", "Master of Auras", "Color Specialist"}) do
                    if helpers.TeleportToNpc(name) then
                        moved = true
                        break
                    end
                end
                notify("Buso Color", moved and "Traveling to the color dealer" or "Dealer is not loaded in this sea")
            end,
        })
        buso:AddToggle({
            Name = "Auto Buy Buso Color",
            Flag = "blox_auto_buy_buso_color",
            Default = false,
            Callback = function(enabled) runtime.AutoBuyBusoColor = enabled == true end,
        })

        local sword = pages.Mastery:AddSection("Sword Mastery", "Right")
        local swordDropdown
        swordDropdown = sword:AddDropdown({
            Name = "Sword Selection",
            Flag = "blox_mastery_swords",
            Options = inventorySwordNames(),
            Multi = true,
            Default = {},
            Callback = function(value) runtime.SelectedSwords = type(value) == "table" and value or {} end,
        })
        sword:AddButton({
            Name = "Refresh Sword Inventory",
            Callback = function()
                swordDropdown:SetOptions(inventorySwordNames(), true)
                notify("Sword Mastery", "Inventory refreshed")
            end,
        })
        sword:AddSlider({
            Name = "Target Mastery Level",
            Flag = "blox_mastery_sword_target",
            Min = 1, Max = 600, Step = 1, Default = 600,
            Callback = function(value) runtime.SwordTargetMastery = tonumber(value) or 600 end,
        })
        sword:AddToggle({
            Name = "Auto Switch Swords",
            Flag = "blox_mastery_auto_switch_sword",
            Default = false,
            Callback = function(enabled) runtime.AutoSwitchSword = enabled == true end,
        })

        local mastery = pages.Mastery:AddSection("Fruit / Gun Mastery", "Left")
        mastery:AddToggle({
            Name = "Enable Mastery Finisher",
            Flag = "blox_mastery_finisher",
            Default = false,
            Callback = function(enabled) runtime.MasteryEnabled = enabled == true end,
        })
        mastery:AddDropdown({
            Name = "Mastery Type",
            Flag = "blox_mastery_type",
            Options = {"Devil Fruit", "Gun", "Sword", "Melee"},
            Default = "Devil Fruit",
            Callback = function(value) runtime.MasteryType = tostring(value) end,
        })
        mastery:AddSlider({
            Name = "Use Skills Below Health",
            Flag = "blox_mastery_health_percent",
            Min = 5, Max = 95, Step = 5, Default = 35,
            Suffix = "%",
            Callback = function(value) runtime.MasteryHealthPercent = tonumber(value) or 35 end,
        })
        mastery:AddSlider({
            Name = "Skill Hold Time",
            Flag = "blox_mastery_hold_time",
            Min = 0, Max = 2, Step = 0.05, Default = 0.15,
            Suffix = "s",
            Callback = function(value) runtime.MasteryHoldTime = tonumber(value) or 0.15 end,
        })
    end

    local function buildItemsAndCodes()
        local section = pages.Shop:AddSection("Auto Use Items", "Left")
        for _, entry in ipairs({
            {"Library Key", "Library", "blox_auto_use_library_key"},
            {"Water Key", "Water", "blox_auto_use_water_key"},
            {"Hidden Key", "Hidden", "blox_auto_use_hidden_key"},
            {"Fire Essence", "Fire", "blox_auto_use_fire_essence"},
        }) do
            section:AddToggle({
                Name = "Auto Use " .. entry[1],
                Flag = entry[3],
                Default = false,
                Callback = function(enabled) runtime.AutoUse[entry[2]] = enabled == true end,
            })
        end
        section:AddToggle({
            Name = "Auto Grab Dropped Fruit",
            Flag = "blox_auto_grab_fruit",
            Default = false,
            Callback = function(enabled) runtime.AutoGrabFruit = enabled == true end,
        })

        local codes = pages.Shop:AddSection("Codes", "Right")
        codes:AddButton({
            Name = "Redeem All Loaded Codes",
            Description = "Reads the game's replicated code list when available; no stale internet list",
            Callback = function()
                local sent, seen = 0, {}
                for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
                    if object:IsA("StringValue") and string.find(string.lower(object.Name), "code", 1, true) then
                        local code = tostring(object.Value)
                        if code ~= "" and not seen[code] and remotes.Redeem then
                            seen[code] = true
                            pcall(function() remotes.Redeem:InvokeServer(code) end)
                            sent += 1
                        end
                    end
                end
                notify("Codes", sent > 0 and ("Submitted " .. sent .. " loaded codes") or "No replicated code list was exposed")
            end,
        })
    end

    local function buildRaidExtras()
        local section = pages.Sea:AddSection("Advanced Raid Settings", "Left")
        section:AddSlider({
            Name = "Maximum Raid Fruit Value",
            Flag = "blox_raid_max_fruit_value",
            Min = 50000, Max = 5000000, Step = 50000, Default = 1000000,
            Callback = function(value) runtime.RaidFruitValue = tonumber(value) or 1000000 end,
        })
        section:AddButton({
            Name = "Get Cheap Fruit From Inventory",
            Callback = function()
                local ok, message = loadCheapRaidFruit()
                notify("Raid Fruit", ok and ("Loaded " .. tostring(message)) or message)
            end,
        })
        section:AddToggle({
            Name = "Auto Get Raid Fruit",
            Flag = "blox_raid_auto_get_fruit",
            Default = false,
            Callback = function(enabled) runtime.AutoRaidFruit = enabled == true end,
        })
        section:AddToggle({
            Name = "Better Auto Awakening",
            Description = "Travels to the real loaded Awakener NPC before requesting awakening",
            Flag = "blox_better_auto_awakening",
            Default = false,
            Callback = function(enabled) runtime.BetterAwakening = enabled == true end,
        })

        local law = pages.Sea:AddSection("Law Raid", "Left")
        law:AddButton({Name = "Buy Law Microchip", Callback = function()
            local ok, result = buyLawChip()
            notify("Law Raid", ok and tostring(result or "Chip request sent") or result)
        end})
        law:AddToggle({
            Name = "Auto Buy Law Chip", Flag = "blox_auto_buy_law_chip", Default = false,
            Callback = function(enabled) runtime.AutoLawChip = enabled == true end,
        })
        law:AddToggle({
            Name = "Auto Start Law Raid", Flag = "blox_auto_start_law_raid", Default = false,
            Callback = function(enabled) runtime.AutoStartLaw = enabled == true end,
        })
        law:AddToggle({
            Name = "Auto Law Raid", Flag = "blox_auto_law_raid", Default = false,
            Callback = function(enabled) runtime.AutoLawRaid = enabled == true end,
        })
    end

    local function buildVisuals()
        local section = pages.Player:AddSection("World ESP & Alerts", "Right")
        section:AddToggle({Name = "Devil Fruit ESP", Flag = "blox_fruit_esp", Default = false,
            Callback = function(enabled) runtime.Esp.Fruit = enabled == true end})
        section:AddToggle({Name = "Berry ESP", Flag = "blox_berry_esp", Default = false,
            Callback = function(enabled) runtime.Esp.Berry = enabled == true end})
        section:AddToggle({Name = "Flower ESP", Flag = "blox_flower_esp", Default = false,
            Callback = function(enabled) runtime.Esp.Flower = enabled == true end})
        section:AddDropdown({
            Name = "Rare Island ESP",
            Flag = "blox_rare_island_esp",
            Options = {"Mirage Island", "Prehistoric Island", "Kitsune Island", "Frozen Dimension"},
            Multi = true, Default = {},
            Callback = function(value) runtime.Esp.Islands = type(value) == "table" and value or {} end,
        })
        section:AddToggle({Name = "Boss Spawn Notification", Flag = "blox_boss_spawn_notify", Default = false,
            Callback = function(enabled) runtime.BossNotifications = enabled == true end})
        section:AddToggle({Name = "Rare Island Notification", Flag = "blox_island_spawn_notify", Default = false,
            Callback = function(enabled) runtime.IslandNotifications = enabled == true end})
    end

    local function shopButton(section, name, command, ...)
        local arguments = table.pack(...)
        section:AddButton({
            Name = name,
            Callback = function()
                local ok, result = rawInvoke(command, table.unpack(arguments, 1, arguments.n))
                notify("Shop", ok and (name .. ": " .. tostring(result or "request sent")) or result)
            end,
        })
    end

    local function buildShopParity()
        local basics = pages.Shop:AddSection("Melee & Abilities", "Left")
        for _, entry in ipairs({
            {"Buy Black Leg", "BuyBlackLeg"}, {"Buy Electro", "BuyElectro"},
            {"Buy Fishman Karate", "BuyFishmanKarate"}, {"Buy Dragon Claw", "BlackbeardReward", "DragonClaw", "2"},
            {"Buy Haki", "BuyHaki", "Buso"}, {"Buy Geppo", "BuyHaki", "Geppo"},
            {"Buy Soru", "BuyHaki", "Soru"}, {"Buy Observation", "KenTalk", "Buy"},
        }) do
            shopButton(basics, entry[1], entry[2], table.unpack(entry, 3))
        end
        local weapons = pages.Shop:AddSection("Classic Weapons", "Right")
        for _, entry in ipairs({
            {"Katana", "BuyItem", "Katana"}, {"Cutlass", "BuyItem", "Cutlass"},
            {"Dual Katana", "BuyItem", "Dual Katana"}, {"Iron Mace", "BuyItem", "Iron Mace"},
            {"Pipe", "BuyItem", "Pipe"}, {"Triple Katana", "BuyItem", "Triple Katana"},
            {"Bisento", "BuyItem", "Bisento"}, {"Soul Cane", "BuyItem", "Soul Cane"},
            {"Slingshot", "BuyItem", "Slingshot"}, {"Musket", "BuyItem", "Musket"},
            {"Flintlock", "BuyItem", "Flintlock"}, {"Cannon", "BuyItem", "Cannon"},
            {"Kabucha", "BlackbeardReward", "Slingshot", "2"},
        }) do
            shopButton(weapons, "Buy " .. entry[1], entry[2], table.unpack(entry, 3))
        end
        local fragments = pages.Shop:AddSection("Fragments", "Right")
        shopButton(fragments, "Refund Stats", "BlackbeardReward", "Refund", "2")
        shopButton(fragments, "Reroll Race", "BlackbeardReward", "Reroll", "2")
        shopButton(fragments, "Random Surprise", "Bones", "Buy", 1, 1)
    end

    buildPlayerInfo()
    buildBusoAndMastery()
    buildItemsAndCodes()
    buildRaidExtras()
    buildVisuals()
    buildShopParity()

    if pages.PVP and type(context.LoadModule) == "function" and type(context.RunBuilder) == "function" then
        runtime.PvpLoaded, runtime.PvpBuilder = context.LoadModule("games/blox_fruits_pvp.lua")
        if not runtime.PvpLoaded then
            error("PvP module compile failed: " .. tostring(runtime.PvpBuilder))
        end
        runtime.PvpOk, runtime.PvpError = context.RunBuilder(
            "games/blox_fruits_pvp.lua",
            runtime.PvpBuilder,
            {
                Window = Window,
                Gui = gui,
                Track = track,
                Page = pages.PVP,
                Helpers = context.Helpers,
            }
        )
        runtime.PvpBuilder = nil
        if not runtime.PvpOk then
            error("PvP module builder failed: " .. tostring(runtime.PvpError))
        end
    end

    if context.ThirdSeaAPI and context.ThirdSeaAPI.IsThirdSea
        and type(context.LoadModule) == "function" and type(context.RunBuilder) == "function" then
        runtime.ThirdSeaLoaded, runtime.ThirdSeaBuilder = context.LoadModule("games/blox_fruits_third_sea.lua")
        if not runtime.ThirdSeaLoaded then
            error("Third Sea module compile failed: " .. tostring(runtime.ThirdSeaBuilder))
        end
        runtime.ThirdSeaOk, runtime.ThirdSeaError = context.RunBuilder(
            "games/blox_fruits_third_sea.lua",
            runtime.ThirdSeaBuilder,
            {
                Window = Window,
                Gui = gui,
                Track = track,
                Pages = pages,
                Remotes = remotes,
                Helpers = helpers,
                ThirdSeaAPI = context.ThirdSeaAPI,
            }
        )
        runtime.ThirdSeaBuilder = nil
        if not runtime.ThirdSeaOk then
            error("Third Sea module builder failed: " .. tostring(runtime.ThirdSeaError))
        end
    end

    track(workspace.ChildAdded:Connect(function(child)
        if runtime.IslandNotifications then
            local lower = string.lower(child.Name)
            if lower:find("mirage", 1, true) or lower:find("prehistoric", 1, true)
                or lower:find("kitsune", 1, true) or lower:find("frozen", 1, true) then
                notify("Rare Island Spawned", child.Name, 6)
            end
        end
    end))
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        track(enemies.ChildAdded:Connect(function(enemy)
            if runtime.BossNotifications then
                local lower = string.lower(enemy.Name)
                if lower:find("boss", 1, true) or lower:find("order", 1, true) then
                    notify("Boss Spawned", enemy.Name, 6)
                end
            end
        end))
    end

    track(RunService.Heartbeat:Connect(function()
        if not runtime.Alive or os.clock() - runtime.LastLoop < 0.15 then
            return
        end
        runtime.LastLoop = os.clock()
        stepSwordMastery()
        stepAutoUseItems()
        stepMastery()
        stepAutoGrabFruit()
        stepRaidExtras()
        if runtime.AutoBuyBusoColor and os.clock() - runtime.LastBusoBuy >= 8 then
            runtime.LastBusoBuy = os.clock()
            rawInvoke("ColorsDealer", "2")
            runtime.RefreshBusoColor(false)
        end
        if os.clock() - runtime.LastSlowLoop >= 1 then
            runtime.LastSlowLoop = os.clock()
            runtime.UpdatePlayerInfo()
            stepEsp()
        end
    end))

    runtime.RefreshBusoColor(false)
    runtime.UpdatePlayerInfo()
    gui:SetAttribute("BloxSolixParityModule", true)
    gui:SetAttribute("BloxSolixParityVersion", "1")
end
