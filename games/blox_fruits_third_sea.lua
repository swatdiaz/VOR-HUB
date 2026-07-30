-- Third Sea progression extension. Combat and movement stay in blox_fruits.lua;
-- this module only coordinates server-backed quest stages and target selection.
return function(context)
    local Window = assert(context.Window, "Third Sea module requires Window")
    local gui = assert(context.Gui, "Third Sea module requires Gui")
    local track = assert(context.Track, "Third Sea module requires Track")
    local pages = assert(context.Pages, "Third Sea module requires Pages")
    local api = assert(context.ThirdSeaAPI, "Third Sea module requires combat API")
    local remotes = assert(context.Remotes, "Third Sea module requires remotes")
    local helpers = assert(context.Helpers, "Third Sea module requires helpers")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    if not api.IsThirdSea then
        return
    end

    local runtime = {
        Alive = true,
        Active = nil,
        Busy = false,
        LastStep = 0,
        LastRemote = {},
        LastInventory = 0,
        Inventory = {},
        Cache = {},
        Controls = {},
        ControlFlags = {},
        StatusLabel = nil,
        DetailLabel = nil,
        DojoLabel = nil,
        DragonLabel = nil,
    }

    local taskNames = {
        pirate = "Pirate Raid",
        tyrant = "Tyrant of the Skies",
        yama = "Yama",
        tushita = "Tushita",
        hallow = "Hallow Scythe",
        canvander = "Canvander",
        twin = "Twin Hooks",
        dagger = "Dark Dagger",
        venom = "Venom Bow",
        buddy = "Buddy Sword",
        cdk = "Cursed Dual Katana",
        guitar = "Soul Guitar",
        race = "Race V4",
        elite = "Elite Hunter",
        dojo = "Dojo Trainer Quest",
        dragon = "Dragon Hunter Quest",
        cake = "Cake Prince",
        citizen = "Citizen Quest",
        rainbow = "Rainbow Haki",
    }

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 4)
    end

    local function setStatus(message, detail)
        local title = runtime.Active and (taskNames[runtime.Active] or runtime.Active) or "Idle"
        if runtime.StatusLabel then
            runtime.StatusLabel.Text = "Active: " .. title
        end
        if runtime.DetailLabel then
            runtime.DetailLabel.Text = tostring(detail or message or "Waiting")
        end
        gui:SetAttribute("BloxThirdSeaTask", title)
        gui:SetAttribute("BloxThirdSeaStatus", tostring(detail or message or "Waiting"))
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

    local function throttled(key, delay, callback)
        local now = os.clock()
        if now - (runtime.LastRemote[key] or 0) < delay then
            return false, nil
        end
        runtime.LastRemote[key] = now
        return pcall(callback)
    end

    local function cachedInvoke(key, delay, command, ...)
        local arguments = table.pack(...)
        throttled(key, delay, function()
            local ok, result = rawInvoke(command, table.unpack(arguments, 1, arguments.n))
            if ok then
                runtime.Cache[key] = result
            end
        end)
        return runtime.Cache[key]
    end

    local function netInvoke(name, payload)
        return pcall(function()
            local net = require(ReplicatedStorage.Modules.Net)
            return net:RemoteFunction(name):InvokeServer(payload)
        end)
    end

    local function netEvent(name)
        return pcall(function()
            local net = require(ReplicatedStorage.Modules.Net)
            net:RemoteEvent(name):FireServer()
        end)
    end

    local function refreshInventory(force)
        if not force and os.clock() - runtime.LastInventory < 7 then
            return
        end
        runtime.LastInventory = os.clock()
        local inventory = {}
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, container in ipairs({helpers.Character(), backpack}) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") then
                        inventory[string.lower(child.Name)] = true
                    end
                end
            end
        end
        local ok, result = rawInvoke("getInventoryWeapons")
        if not ok or type(result) ~= "table" then
            ok, result = rawInvoke("getInventory")
        end
        if ok and type(result) == "table" then
            for _, entry in pairs(result) do
                if type(entry) == "table" and entry.Name then
                    inventory[string.lower(tostring(entry.Name))] = true
                end
            end
        end
        runtime.Inventory = inventory
    end

    local function hasItem(...)
        refreshInventory(false)
        for index = 1, select("#", ...) do
            local wanted = string.lower(tostring(select(index, ...)))
            for name in pairs(runtime.Inventory) do
                if name == wanted or string.find(name, wanted, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    local function finishTask(message)
        local key = runtime.Active
        runtime.Active = nil
        if key and runtime.Controls[key] then
            runtime.Controls[key]:Set(false)
        end
        api.Stop()
        setStatus("Complete", message)
        notify("Third Sea", message, 6)
    end

    local function selectTask(key, enabled)
        if not enabled then
            if runtime.Active == key then
                runtime.Active = nil
                api.Stop()
                setStatus("Stopped", "Automation stopped")
            end
            return
        end
        for other in pairs(runtime.Controls) do
            local flag = runtime.ControlFlags[other]
            if other ~= key and flag and Window.PersistentControls[flag] then
                Window.PersistentControls[flag]:Set(false)
            end
        end
        runtime.Active = key
        api.SetCombat(true)
        setStatus("Started", "Reading live quest state...")
    end

    local function farm(names, center, radius, height)
        local target, stage = api.FarmFirst(names, center, radius, height or 22)
        setStatus(stage, target and (stage .. ": " .. target) or stage)
        return target ~= nil
    end

    local function rootPosition(object)
        if object:IsA("BasePart") then
            return object.Position
        end
        local part = object:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end

    local function interactMatching(words, maxDistance)
        local root = api.RootPart()
        if not root then
            return false
        end
        for _, object in ipairs(workspace:GetDescendants()) do
            local lower = string.lower(object.Name)
            local matched = false
            for _, word in ipairs(words) do
                if string.find(lower, string.lower(word), 1, true) then
                    matched = true
                    break
                end
            end
            if matched then
                local position = rootPosition(object)
                if position and (root.Position - position).Magnitude <= (maxDistance or 20) then
                    if object:IsA("ProximityPrompt") and fireproximityprompt then
                        pcall(fireproximityprompt, object)
                        return true
                    elseif object:IsA("ClickDetector") and fireclickdetector then
                        pcall(fireclickdetector, object)
                        return true
                    elseif object:IsA("BasePart") and firetouchinterest then
                        pcall(firetouchinterest, root, object, 0)
                        pcall(firetouchinterest, root, object, 1)
                        return true
                    end
                end
            end
        end
        return false
    end

    local function stepDrop(itemNames, bossNames)
        if hasItem(table.unpack(itemNames)) then
            finishTask(itemNames[1] .. " is already owned")
            return
        end
        farm(bossNames)
    end

    local function stepPirateRaid()
        local castle = CFrame.new(-5078, 318, -3155)
        farm({}, castle, 1550, 28)
    end

    local function stepElite()
        if hasItem("God's Chalice", "God Chalice") then
            if runtime.Active == "elite" then
                finishTask("Stopped: God's Chalice was found")
            else
                setStatus("Elite Hunter", "God's Chalice found; preserving the active unlock task")
            end
            return
        end
        throttled("elite", 4, function()
            local ok, result = rawInvoke("EliteHunter")
            if ok and result then
                setStatus("Elite Hunter", tostring(result))
            end
        end)
        farm({"Deandre", "Diablo", "Urban"}, nil, nil, 24)
    end

    local function stepCake()
        local ready = false
        throttled("cake", 2.5, function()
            local ok, result = rawInvoke("CakePrinceSpawner", true)
            local text = tostring(result or "")
            ready = ok and string.find(string.lower(text), "open the portal now", 1, true) ~= nil
            setStatus("Cake Prince", text ~= "" and text or "Reading portal progress")
            if ready then
                rawInvoke("CakePrinceSpawner")
            end
        end)
        local root = api.RootPart()
        local bossLoaded = false
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                local lower = string.lower(enemy.Name)
                local body = enemy:FindFirstChildOfClass("Humanoid")
                if body and body.Health > 0 and (
                    string.find(lower, "cake prince", 1, true)
                    or string.find(lower, "dough king", 1, true)
                ) then
                    bossLoaded = true
                    break
                end
            end
        end
        if bossLoaded and root and root.Position.Y < 3500 then
            local map = workspace:FindFirstChild("Map")
            local cakeLoaf = map and map:FindFirstChild("CakeLoaf")
            local mirror = cakeLoaf and cakeLoaf:FindFirstChild("BigMirror")
            local portal = mirror and mirror:FindFirstChild("Main")
            if portal and portal:IsA("BasePart") then
                api.Stop()
                local distance = (root.Position - portal.Position).Magnitude
                setStatus("Entering Cake Prince portal", string.format("Portal distance: %.0f", distance))
                gui:SetAttribute("BloxCakePrincePortalDistance", distance)
                gui:SetAttribute("BloxCakePrinceRoute", "Portal")
                if distance <= 10 and firetouchinterest then
                    pcall(firetouchinterest, root, portal, 0)
                    pcall(firetouchinterest, root, portal, 1)
                else
                    api.MoveTo(portal.CFrame)
                end
                return
            end
            setStatus("Waiting for Cake Prince portal", "BigMirror.Main is not loaded yet")
            return
        end
        if bossLoaded then
            gui:SetAttribute("BloxCakePrinceRoute", "Boss room")
            farm({"Cake Prince", "Dough King"}, nil, nil, 28)
            return
        end
        gui:SetAttribute("BloxCakePrinceRoute", ready and "Opening portal" or "Farming portal requirement")
        farm({"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}, nil, nil, 22)
    end

    local function stepYama()
        if hasItem("Yama") then
            finishTask("Yama is already owned")
            return
        end
        local progress = tonumber(cachedInvoke("yamaProgress", 2, "EliteHunter", "Progress"))
        if not progress or progress < 30 then
            setStatus("Yama prerequisite", "Elite Hunter progress: " .. tostring(progress or "unknown") .. "/30")
            stepElite()
            return
        end
        api.MoveTo(CFrame.new(5226, 8, 1100))
        interactMatching({"yama", "sealed katana", "secret temple"}, 45)
        setStatus("Yama", "Pulling the sword in Hydra Secret Temple")
    end

    local function stepTushita()
        if hasItem("Tushita") then
            finishTask("Tushita is already owned")
            return
        end
        local progress = cachedInvoke("tushitaProgress", 1, "TushitaProgress")
        if type(progress) ~= "table" then
            setStatus("Tushita", "Could not read Tushita progress")
            return
        end
        if progress.KilledLongma then
            refreshInventory(true)
            setStatus("Tushita", "Longma defeated; waiting for inventory replication")
            return
        end
        if progress.OpenedDoor then
            farm({"Longma"}, nil, nil, 26)
            return
        end
        if not hasItem("Holy Torch") then
            farm({"rip_indra True Form", "rip_indra"}, nil, nil, 28)
            setStatus("Tushita", "Holy Torch required; waiting for rip_indra door access")
            return
        end
        local torchFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Turtle")
        torchFolder = torchFolder and torchFolder:FindFirstChild("QuestTorches")
        for index = 1, 5 do
            if not progress.Torches or progress.Torches[index] ~= true then
                local torch = torchFolder and torchFolder:FindFirstChild("Torch" .. index)
                local position = torch and rootPosition(torch)
                if position then
                    api.MoveTo(CFrame.new(position + Vector3.new(0, 4, 0)))
                    if api.RootPart() and (api.RootPart().Position - position).Magnitude <= 15 then
                        rawInvoke("TushitaProgress", "Torch", index)
                        interactMatching({"torch" .. index}, 18)
                    end
                    setStatus("Tushita", "Lighting torch " .. index .. "/5")
                    return
                end
            end
        end
    end

    local function stepHallow()
        if hasItem("Hallow Scythe") then
            finishTask("Hallow Scythe is already owned")
            return
        end
        if farm({"Soul Reaper"}, nil, nil, 28) then
            return
        end
        if hasItem("Hallow Essence") then
            api.MoveTo(CFrame.new(-9515, 172, 6078))
            interactMatching({"altar", "hallow", "essence"}, 35)
            setStatus("Hallow Scythe", "Using Hallow Essence at Haunted Castle")
            return
        end
        throttled("hallowRoll", 2.5, function()
            rawInvoke("Bones", "Buy", 1, 1)
        end)
        setStatus("Hallow Scythe", "Rolling Bones for Hallow Essence")
    end

    local function stepCDK()
        if hasItem("Cursed Dual Katana") then
            finishTask("Cursed Dual Katana is already owned")
            return
        end
        local good = cachedInvoke("cdkGood", 1.5, "CDKQuest", "Progress", "Good")
        local evil = cachedInvoke("cdkEvil", 1.5, "CDKQuest", "Progress", "Evil")
        local goodValue = type(good) == "table" and tonumber(good.Good) or 0
        local evilValue = type(evil) == "table" and tonumber(evil.Evil) or 0
        if goodValue < 4 then
            rawInvoke("CDKQuest", "StartTrial", "Good")
            farm({}, nil, nil, 24)
            setStatus("CDK Good trial", tostring(goodValue) .. "/4 - following the live trial target")
            return
        end
        if evilValue < 4 then
            rawInvoke("CDKQuest", "StartTrial", "Evil")
            farm({}, nil, nil, 24)
            setStatus("CDK Evil trial", tostring(evilValue) .. "/4 - following the live trial target")
            return
        end
        rawInvoke("CDKQuest", "OpenDoor")
        rawInvoke("CDKQuest", "OpenDoor", true)
        rawInvoke("CDKQuest", "StartTrial", "Boss")
        farm({"Cursed Skeleton Boss", "Cursed Skeleton"}, nil, nil, 28)
        setStatus("CDK", "Both scrolls complete; opening the final boss room")
    end

    local function stepGuitar()
        if hasItem("Soul Guitar", "Skull Guitar") then
            finishTask("Soul Guitar is already owned")
            return
        end
        local result = cachedInvoke("guitar", 2, "soulGuitarBuy", true)
        local text = result ~= nil and tostring(result) or "Puzzle is not craft-ready yet"
        if result == nil then
            rawInvoke("gravestoneEvent", 2)
            rawInvoke("gravestoneEvent", 2, true)
            rawInvoke("GuitarPuzzleProgress", "Ghost")
            setStatus("Soul Guitar puzzle", "Started gravestone and ghost stages; completing server-visible puzzle objects")
            interactMatching({"trophy", "pipe", "tile", "gravestone"}, 25)
            return
        end
        if string.find(string.lower(text), "craft", 1, true)
            or string.find(string.lower(text), "500 bones", 1, true) then
            rawInvoke("soulGuitarBuy")
        end
        setStatus("Soul Guitar", text)
    end

    local function stepRace()
        local templeStage = cachedInvoke("raceTemple", 1.5, "RaceV4Progress", "Check")
        if templeStage == nil then
            setStatus("Race V4", "Could not read Race V4 progress")
            return
        end
        templeStage = tonumber(templeStage) or -1
        if templeStage < 2 then
            farm({"rip_indra True Form", "Dough King"}, nil, nil, 28)
            setStatus("Race V4", "Temple prerequisite incomplete (stage " .. templeStage .. ")")
            return
        end
        rawInvoke("RaceV4Progress", "Teleport")
        local upgradeOk, upgradeStage, training, price = false, nil, nil, nil
        if os.clock() - (runtime.LastRemote.raceUpgrade or 0) >= 1.5 then
            runtime.LastRemote.raceUpgrade = os.clock()
            upgradeOk, upgradeStage, training, price = rawInvoke("UpgradeRace", "Check")
            if upgradeOk then
                runtime.Cache.raceUpgrade = table.pack(upgradeStage, training, price)
            end
        elseif runtime.Cache.raceUpgrade then
            upgradeOk = true
            upgradeStage, training, price = table.unpack(runtime.Cache.raceUpgrade, 1, runtime.Cache.raceUpgrade.n)
        end
        if upgradeOk and (upgradeStage == 2 or upgradeStage == 4 or upgradeStage == 7) then
            local buyOk, bought = rawInvoke("UpgradeRace", "Buy")
            setStatus("Race V4", buyOk and bought and "Purchased the available Race V4 gear upgrade"
                or ("Upgrade ready; needs " .. tostring(price or "fragments")))
            return
        end
        if upgradeOk and upgradeStage == 5 then
            finishTask("Race V4 is fully evolved for the current race")
            return
        end
        setStatus("Race V4", string.format(
            "Temple stage %s | Upgrade stage %s | Training %s",
            tostring(templeStage), tostring(upgradeStage or "unknown"), tostring(training or "unknown")
        ))
        interactMatching({"lever", "clock", "trial", "ancient"}, 30)
    end

    local function stepDojo()
        throttled("dojo", 2, function()
            local ok, response = netInvoke("InteractDragonQuest", {NPC = "Dojo Trainer", Command = "RequestQuest"})
            if ok then runtime.Cache.dojo = response end
        end)
        local response = runtime.Cache.dojo
        if type(response) ~= "table" then
            setStatus("Dojo", "Dojo Trainer request failed")
            return
        end
        local quest = response.Quest or response
        local progress = tonumber(quest.Progress) or 0
        local goal = tonumber(quest.Goal) or 0
        if runtime.DojoLabel then
            runtime.DojoLabel.Text = string.format("Dojo: %s | %d/%d", tostring(quest.QuestName or quest.BeltName or "Active"), progress, goal)
        end
        if goal > 0 and progress >= goal then
            netInvoke("InteractDragonQuest", {NPC = "Dojo Trainer", Command = "ClaimQuest"})
            setStatus("Dojo", "Claiming completed belt quest")
            return
        end
        if interactMatching({"ember"}, 35) then
            netEvent("DragonDojoEmber")
            setStatus("Dojo", "Collecting Dragon Dojo Ember")
        else
            farm({}, CFrame.new(5665, 1200, 867), 2200, 24)
        end
    end

    local function stepDragon()
        throttled("dragon", 2, function()
            local ok, response = netInvoke("DragonHunter", {Context = "Check"})
            if ok then runtime.Cache.dragon = response end
        end)
        local response = runtime.Cache.dragon
        if response == nil then
            setStatus("Dragon Hunter", "Dragon Hunter status request failed")
            return
        end
        if response == false or response == nil then
            netInvoke("DragonHunter", {Context = "RequestQuest"})
            setStatus("Dragon Hunter", "Requesting a Dragon Hunter quest")
            return
        end
        if runtime.DragonLabel then
            runtime.DragonLabel.Text = "Dragon Hunter: " .. tostring(type(response) == "table" and (response.Description or response.Progress or "Active") or response)
        end
        if interactMatching({"ember"}, 45) then
            netEvent("DragonDojoEmber")
        else
            farm({}, CFrame.new(5665, 1200, 867), 2600, 24)
        end
    end

    local function stepCitizen()
        local stage = tonumber(cachedInvoke("citizen", 1.5, "CitizenQuestProgress", "Citizen")) or -1
        if stage == 0 then
            rawInvoke("StartQuest", "CitizenQuest", 1)
            farm({"Forest Pirate"}, nil, nil, 22)
        elseif stage == 1 then
            farm({"Captain Elephant"}, nil, nil, 28)
        elseif stage == 2 then
            interactMatching({"citizen", "treasure", "musketeer"}, 35)
            setStatus("Citizen", "Finding the hidden treasure")
        elseif stage >= 3 then
            finishTask("Citizen quest is complete")
        else
            setStatus("Citizen", "Unable to read Citizen quest stage")
        end
    end

    local function stepRainbow()
        local result = cachedInvoke("rainbow", 1.5, "HornedMan")
        if result == nil then
            setStatus("Rainbow Haki", "Horned Man status unavailable")
            return
        end
        if tonumber(result) == 1 then
            finishTask("Rainbow Haki quest is complete")
            return
        end
        rawInvoke("HornedMan", "Bet")
        local text = string.lower(tostring(result or ""))
        local bosses = {"Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate"}
        for _, boss in ipairs(bosses) do
            if string.find(text, string.lower(boss), 1, true) then
                farm({boss}, nil, nil, 28)
                return
            end
        end
        farm(bosses, nil, nil, 28)
    end

    local function stepActive()
        local key = runtime.Active
        if not key or runtime.Busy then
            return
        end
        runtime.Busy = true
        local ok, message = xpcall(function()
            if key == "pirate" then stepPirateRaid()
            elseif key == "tyrant" then farm({"Tyrant of the Skies", "Tyrant"}, nil, nil, 28)
            elseif key == "yama" then stepYama()
            elseif key == "tushita" then stepTushita()
            elseif key == "hallow" then stepHallow()
            elseif key == "canvander" then stepDrop({"Canvander"}, {"Beautiful Pirate"})
            elseif key == "twin" then stepDrop({"Twin Hooks", "Twin Hook"}, {"Captain Elephant"})
            elseif key == "dagger" then stepDrop({"Dark Dagger"}, {"rip_indra True Form", "rip_indra"})
            elseif key == "venom" then stepDrop({"Venom Bow"}, {"Tyrant of the Skies", "Tyrant"})
            elseif key == "buddy" then stepDrop({"Buddy Sword"}, {"Cake Queen"})
            elseif key == "cdk" then stepCDK()
            elseif key == "guitar" then stepGuitar()
            elseif key == "race" then stepRace()
            elseif key == "elite" then stepElite()
            elseif key == "dojo" then stepDojo()
            elseif key == "dragon" then stepDragon()
            elseif key == "cake" then stepCake()
            elseif key == "citizen" then stepCitizen()
            elseif key == "rainbow" then stepRainbow()
            end
        end, debug.traceback)
        runtime.Busy = false
        if not ok then
            setStatus("Error", message)
            gui:SetAttribute("BloxThirdSeaError", tostring(message))
        end
    end

    local function addTask(section, key, flag, description)
        local control = section:AddToggle({
            Name = "Auto " .. taskNames[key],
            Flag = flag,
            Default = false,
            Description = description,
            Callback = function(value)
                selectTask(key, value)
            end,
        })
        runtime.Controls[key] = control
        runtime.ControlFlags[key] = flag
    end

    local function buildQuestSections()
        local main = pages.Farming:AddSection("Third Sea Automation", "Left")
        runtime.StatusLabel = main:AddLabel("Active: Idle")
        runtime.DetailLabel = main:AddLabel("Waiting for a Third Sea task")
        addTask(main, "pirate", "blox_third_auto_pirate_raid", "Farms the live Castle on the Sea pirate raid without stealing movement from other tasks.")
        addTask(main, "elite", "blox_third_auto_elite_hunter", "Requests Elite Hunter quests, farms Deandre, Diablo, or Urban, and stops for God's Chalice.")
        addTask(main, "citizen", "blox_third_auto_citizen", "Completes Forest Pirates, Captain Elephant, and the Citizen treasure stage.")
        addTask(main, "rainbow", "blox_third_auto_rainbow_haki", "Reads Horned Man progress and farms the currently required boss.")

        local dragon = pages.Farming:AddSection("Dragon Dojo & Hunter", "Right")
        runtime.DojoLabel = dragon:AddLabel("Dojo: No active quest")
        runtime.DragonLabel = dragon:AddLabel("Dragon Hunter: Not checked")
        addTask(dragon, "dojo", "blox_third_auto_dojo_trainer", "Requests and claims the live Dojo Trainer quest; collects Embers or farms its targets.")
        addTask(dragon, "dragon", "blox_third_auto_dragon_hunter", "Requests the current Dragon Hunter quest and follows its live progress.")
        addTask(dragon, "tyrant", "blox_third_auto_tyrant", "Farms Tyrant of the Skies when the boss exists; otherwise waits without fake progress.")
        addTask(dragon, "race", "blox_third_auto_race_v4", "Reads RaceV4Progress and enters the Temple of Time when prerequisites are complete.")

        local bosses = pages.Sea:AddSection("Third Sea Bosses", "Right")
        addTask(bosses, "cake", "blox_third_auto_cake_prince", "Reads the real Cake Prince portal counter, farms 500 Cake Land NPCs, enters BigMirror, then kills the boss.")
    end

    local function buildWeaponSections()
        local weapons = pages.Mastery:AddSection("Third Sea Weapon Unlocks", "Left")
        addTask(weapons, "yama", "blox_third_auto_yama", "Builds Elite Hunter progress, then pulls Yama from Hydra Secret Temple.")
        addTask(weapons, "tushita", "blox_third_auto_tushita", "Reads TushitaProgress, lights the five torches in order, then farms Longma.")
        addTask(weapons, "cdk", "blox_third_auto_cdk", "Runs Good and Evil CDK trials and opens the final Cursed Skeleton boss room.")
        addTask(weapons, "guitar", "blox_third_auto_soul_guitar", "Starts the gravestone and ghost stages, follows puzzle objects, then crafts Soul Guitar.")

        local drops = pages.Mastery:AddSection("Third Sea Boss Drops", "Right")
        addTask(drops, "hallow", "blox_third_auto_hallow_scythe", "Rolls Bones for Hallow Essence, summons Soul Reaper, and farms the drop.")
        addTask(drops, "canvander", "blox_third_auto_canvander", "Farms Beautiful Pirate until Canvander is owned.")
        addTask(drops, "twin", "blox_third_auto_twin_hooks", "Farms Captain Elephant until Twin Hooks are owned.")
        addTask(drops, "dagger", "blox_third_auto_dark_dagger", "Farms rip_indra True Form until Dark Dagger is owned.")
        addTask(drops, "venom", "blox_third_auto_venom_bow", "Farms Tyrant of the Skies until Venom Bow is owned.")
        addTask(drops, "buddy", "blox_third_auto_buddy_sword", "Farms Cake Queen until Buddy Sword is owned.")
    end

    buildQuestSections()
    buildWeaponSections()

    track(RunService.Heartbeat:Connect(function()
        if not runtime.Alive or not runtime.Active or os.clock() - runtime.LastStep < 0.28 then
            return
        end
        runtime.LastStep = os.clock()
        stepActive()
    end))

    gui:SetAttribute("BloxThirdSeaModule", true)
    gui:SetAttribute("BloxThirdSeaVersion", "1")
    setStatus("Ready", "Third Sea server-backed automation ready")
end
