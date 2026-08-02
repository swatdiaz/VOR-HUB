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
    local CollectionService = game:GetService("CollectionService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
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
        CakeLabel = nil,
        CakeRemaining = nil,
        CakePortalReady = false,
        TyrantEyes = 0,
        TyrantEyeParts = 0,
        TyrantSessionKills = 0,
        TyrantTracked = setmetatable({}, {__mode = "k"}),
        TyrantSkillIndex = 0,
        TyrantLastSkill = 0,
        TyrantPotRound = 0,
        TyrantLastPotSeen = 0,
        TyrantLastEmptyRoundAt = 0,
        TyrantLastTeamSelect = 0,
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
        local target, stage = api.FarmFirst(names, center, radius, height)
        setStatus(stage, target and (stage .. ": " .. target) or stage)
        return target ~= nil
    end

    local function farmMobAura(names)
        local target, stage = api.FarmMobAura(names)
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
        throttled("cake", 2.5, function()
            local ok, result = rawInvoke("CakePrinceSpawner", true)
            local text = tostring(result or "")
            local lower = string.lower(text)
            runtime.CakeRemaining = tonumber(string.match(text, "(%d+)"))
            runtime.CakePortalReady = ok
                and string.find(lower, "open the portal now", 1, true) ~= nil
            if runtime.CakeLabel then
                if runtime.CakePortalReady then
                    runtime.CakeLabel.Text = "Cake Prince Portal: READY"
                elseif runtime.CakeRemaining then
                    runtime.CakeLabel.Text = string.format(
                        "Cake Prince Portal: %d NPCs remaining",
                        runtime.CakeRemaining
                    )
                else
                    runtime.CakeLabel.Text = "Cake Prince Portal: Reading progress..."
                end
            end
            gui:SetAttribute("BloxCakePrinceRemaining", runtime.CakeRemaining or -1)
            gui:SetAttribute("BloxCakePrincePortalReady", runtime.CakePortalReady)
            setStatus("Cake Prince", text ~= "" and text or "Reading portal progress")
            if runtime.CakePortalReady then
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
            runtime.CakeRemaining = 0
            runtime.CakePortalReady = true
            if runtime.CakeLabel then
                runtime.CakeLabel.Text = "Cake Prince: BOSS SPAWNED"
            end
            gui:SetAttribute("BloxCakePrinceRemaining", 0)
            gui:SetAttribute("BloxCakePrincePortalReady", true)
            gui:SetAttribute("BloxCakePrinceRoute", "Boss room")
            farm({"Cake Prince", "Dough King"})
            return
        end
        gui:SetAttribute(
            "BloxCakePrinceRoute",
            runtime.CakePortalReady and "Opening portal" or "Farming portal requirement"
        )
        farm({"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"})
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

    local TYRANT_TIKI_ENEMIES = {
        "Isle Outlaw",
        "Island Boy",
        "Isle Champion",
        "Sun-kissed Warrior",
        "Serpent Hunter",
        "Skull Slayer",
    }

    local TYRANT_TIKI_LOOKUP = (function()
        local lookup = {}
        for _, name in ipairs(TYRANT_TIKI_ENEMIES) do
            lookup[string.lower(name)] = true
        end
        return lookup
    end)()

    local function normalizedEnemyName(name)
        return string.lower(tostring(name or "")
            :gsub("%s*%[Lv[^%]]*%]", "")
            :gsub("%s*%[[Rr][Aa][Ii][Dd]%s+[Bb][Oo][Ss][Ss]%]", "")
            :gsub("%s*%[[Bb][Oo][Ss][Ss]%]", "")
            :gsub("%s+$", ""))
    end

    local function loadedEnemy(names)
        local wanted = {}
        for _, name in ipairs(names) do
            wanted[normalizedEnemyName(name)] = true
        end
        local enemies = workspace:FindFirstChild("Enemies")
        if not enemies then
            return nil
        end
        for _, enemy in ipairs(enemies:GetChildren()) do
            local body = enemy:FindFirstChildOfClass("Humanoid")
            if body and body.Health > 0 and wanted[normalizedEnemyName(enemy.Name)] then
                return enemy
            end
        end
        return nil
    end

    local function trackTikiDeaths()
        local enemies = workspace:FindFirstChild("Enemies")
        if not enemies then
            return
        end
        for _, enemy in ipairs(enemies:GetChildren()) do
            local body = enemy:FindFirstChildOfClass("Humanoid")
            if body and TYRANT_TIKI_LOOKUP[normalizedEnemyName(enemy.Name)] and not runtime.TyrantTracked[body] then
                runtime.TyrantTracked[body] = true
                track(body.Died:Once(function()
                    runtime.TyrantSessionKills += 1
                    gui:SetAttribute("BloxTyrantSessionKills", runtime.TyrantSessionKills)
                end))
            end
        end
    end

    local function redColor(color)
        return typeof(color) == "Color3"
            and color.R >= 0.45
            and color.R >= color.G * 1.35
            and color.R >= color.B * 1.25
    end

    local function tyrantEyeProgress()
        local red = 0
        local total = 0
        local seen = {}
        local map = workspace:FindFirstChild("Map")
        if map then
            -- The live Tiki arena has two BirdStatue .010 meshes. Each mesh is
            -- one statue's pair of eyes, so the two parts represent all 4 eyes.
            for _, object in ipairs(map:GetDescendants()) do
                local statue = object.Parent
                if object:IsA("BasePart")
                    and statue and statue:IsA("Model") and statue.Name == "BirdStatue"
                    and string.find(object.Name, "Cube.010", 1, true) then
                    seen[object] = true
                    total += 2
                    if redColor(object.Color)
                        or string.find(string.lower(object.BrickColor.Name), "red", 1, true) then
                        red += 2
                    end
                end
            end
        end
        if map and total == 0 then
            for _, object in ipairs(map:GetDescendants()) do
                if object:IsA("BasePart") then
                    local path = string.lower(object:GetFullName())
                    local eyeNamed = string.find(path, "eye", 1, true)
                        or string.find(path, "owl", 1, true)
                        or string.find(path, "falcon", 1, true)
                        or string.find(path, "bird", 1, true)
                    local tikiRelated = string.find(path, "tiki", 1, true)
                        or string.find(path, "tyrant", 1, true)
                    if eyeNamed and tikiRelated and not seen[object] then
                        seen[object] = true
                        total += 1
                        if redColor(object.Color) or string.find(string.lower(object.BrickColor.Name), "red", 1, true) then
                            red += 1
                        end
                    end
                end
            end
        end
        local exactEyesDetected = total > 0
        if not exactEyesDetected then
            for name, value in pairs(LocalPlayer:GetAttributes()) do
                local lower = string.lower(tostring(name))
                if type(value) == "number" then
                    if string.find(lower, "tyrant", 1, true) or string.find(lower, "tiki", 1, true)
                        or string.find(lower, "eye", 1, true) then
                        if string.find(lower, "kill", 1, true) and value >= 300 then
                            red = math.max(red, 4)
                        elseif string.find(lower, "eye", 1, true) and value >= 4 then
                            red = math.max(red, 4)
                        end
                    end
                end
            end
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if playerGui then
                for _, object in ipairs(playerGui:GetDescendants()) do
                    if object:IsA("TextLabel") and object.Visible and not object:IsDescendantOf(gui) then
                        local text = string.lower(object.Text)
                        if string.find(text, "eye", 1, true) or string.find(text, "tyrant", 1, true)
                            or string.find(text, "owl", 1, true) or string.find(text, "bird", 1, true) then
                            local current = tonumber(string.match(text, "(%d+)%s*/%s*4"))
                            if current then
                                red = math.max(red, math.clamp(current, 0, 4))
                            end
                        end
                    end
                end
            end
            if runtime.TyrantSessionKills >= 300 then
                red = math.max(red, 4)
            end
        end
        runtime.TyrantEyes = math.clamp(red, 0, 4)
        runtime.TyrantEyeParts = total
        gui:SetAttribute("BloxTyrantRedEyes", runtime.TyrantEyes)
        gui:SetAttribute("BloxTyrantEyeParts", total)
        return runtime.TyrantEyes, total
    end

    local function tikiCenter()
        local origin = workspace:FindFirstChild("_WorldOrigin")
        local spawns = origin and origin:FindFirstChild("EnemySpawns")
        if not spawns then
            return nil
        end
        local sum = Vector3.zero
        local count = 0
        for _, object in ipairs(spawns:GetDescendants()) do
            if object:IsA("BasePart") and TYRANT_TIKI_LOOKUP[normalizedEnemyName(object.Name)] then
                sum += object.Position
                count += 1
            end
        end
        return count > 0 and (sum / count) or nil
    end

    local function isTyrantPot(object, center)
        if object:IsA("Model") and object:GetAttribute("TikiUrn") == true
            and CollectionService:HasTag(object, "CuttableObject") then
            return rootPosition(object) ~= nil
        end
        if not object:IsA("BasePart") or object.Transparency >= 0.98 or not object.CanQuery then
            return false
        end
        local path = string.lower(object:GetFullName())
        local named = string.find(path, "vase", 1, true)
            or string.find(path, "pot", 1, true)
            or string.find(path, "urn", 1, true)
        if not named then
            for _, tag in ipairs(CollectionService:GetTags(object)) do
                local lower = string.lower(tag)
                if string.find(lower, "vase", 1, true) or string.find(lower, "pot", 1, true)
                    or string.find(lower, "breakable", 1, true) or string.find(lower, "destroy", 1, true) then
                    named = true
                    break
                end
            end
        end
        if not named then
            return false
        end
        if string.find(path, "tiki", 1, true) or string.find(path, "tyrant", 1, true) then
            return true
        end
        return typeof(center) == "Vector3" and (object.Position - center).Magnitude <= 2200
    end

    local function nearestTyrantPot()
        local root = api.RootPart()
        local map = workspace:FindFirstChild("Map")
        if not root or not map then
            return nil, nil
        end
        local center = tikiCenter()
        local best = nil
        local bestDistance = math.huge
        local exactUrns = 0
        for _, object in ipairs(CollectionService:GetTagged("CuttableObject")) do
            if object.Parent and object:IsA("Model") and object:GetAttribute("TikiUrn") == true then
                local position = rootPosition(object)
                if position then
                    exactUrns += 1
                    local distance = (position - root.Position).Magnitude
                    if distance < bestDistance then
                        best = object
                        bestDistance = distance
                    end
                end
            end
        end
        if exactUrns > 0 then
            gui:SetAttribute("BloxTyrantUrns", exactUrns)
            return best, center
        end
        gui:SetAttribute("BloxTyrantUrns", 0)
        for _, object in ipairs(map:GetDescendants()) do
            if isTyrantPot(object, center) then
                local position = rootPosition(object)
                if position then
                    local distance = (position - root.Position).Magnitude
                    if distance < bestDistance then
                        best = object
                        bestDistance = distance
                    end
                end
            end
        end
        return best, center
    end

    local function equipTyrantSkillTool()
        local char = helpers.Character()
        local body = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not body then
            return nil
        end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                return child
            end
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.Name ~= "Holy Torch" and tool.Name ~= "God's Chalice" then
                    body:EquipTool(tool)
                    return tool
                end
            end
        end
        return nil
    end

    local function useTyrantPotSkill(pot)
        local root = api.RootPart()
        if not root or not pot then
            return
        end
        local potPosition = rootPosition(pot)
        if not potPosition then
            return
        end
        local distance = (root.Position - potPosition).Magnitude
        local destination = CFrame.lookAt(potPosition + Vector3.new(0, 7, 12), potPosition)
        if distance > 24 then
            api.MoveTo(destination)
            return
        end
        api.MoveTo(destination)
        if not equipTyrantSkillTool() or os.clock() - runtime.TyrantLastSkill < 0.22 then
            return
        end
        runtime.TyrantLastSkill = os.clock()
        local allowedSkills = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.F}
        runtime.TyrantSkillIndex = runtime.TyrantSkillIndex % #allowedSkills + 1
        local keyCode = allowedSkills[runtime.TyrantSkillIndex]
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.delay(0.07, function()
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
        end)
        gui:SetAttribute("BloxTyrantLastSkill", keyCode.Name)
    end

    local function recoverTyrantTeam()
        if LocalPlayer.Team then
            return false
        end
        if os.clock() - runtime.TyrantLastTeamSelect < 2 then
            return true
        end
        runtime.TyrantLastTeamSelect = os.clock()
        setStatus("Selecting Pirates", "Third Sea travel cleared the team; restoring Pirates automatically")
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main = playerGui and (playerGui:FindFirstChild("Main (minimal)") or playerGui:FindFirstChild("Main"))
        local chooseTeam = main and main:FindFirstChild("ChooseTeam")
        local container = chooseTeam and chooseTeam:FindFirstChild("Container")
        local pirates = container and container:FindFirstChild("Pirates")
        local frame = pirates and pirates:FindFirstChild("Frame")
        local button = frame and frame:FindFirstChildOfClass("TextButton")
        if button and type(firesignal) == "function" then
            pcall(firesignal, button.Activated)
            pcall(firesignal, button.MouseButton1Click)
        end
        return true
    end

    local function stepTyrant()
        if recoverTyrantTeam() then
            return
        end
        local boss = loadedEnemy({"Tyrant of the Skies", "Tyrant"})
        if boss then
            runtime.TyrantPotRound = 0
            farmMobAura({"Tyrant of the Skies", "Tyrant"})
            return
        end
        trackTikiDeaths()
        local eyes, eyeParts = tyrantEyeProgress()
        if eyes < 4 then
            local detail = string.format(
                "Tiki NPCs | red eyes %d/4%s | session kills %d/300",
                eyes,
                eyeParts > 0 and (" (detected " .. eyeParts .. " eye parts)") or "",
                runtime.TyrantSessionKills
            )
            setStatus("Charging owl eyes", detail)
            api.FarmMobAura(TYRANT_TIKI_ENEMIES)
            return
        end
        api.FarmMobAura({"__VOR_TYRANT_POTS__"})
        local pot, center = nearestTyrantPot()
        if pot then
            runtime.TyrantLastPotSeen = os.clock()
            runtime.TyrantLastEmptyRoundAt = 0
            setStatus(
                "Destroying Tiki vases",
                string.format("Round %d/3 | %s | skills Z/X/C/F only", math.min(runtime.TyrantPotRound + 1, 3), pot.Name)
            )
            useTyrantPotSkill(pot)
            return
        end
        if runtime.TyrantLastPotSeen > 0 and os.clock() - runtime.TyrantLastPotSeen >= 2
            and os.clock() - runtime.TyrantLastEmptyRoundAt >= 2 then
            runtime.TyrantPotRound = math.min(runtime.TyrantPotRound + 1, 3)
            runtime.TyrantLastEmptyRoundAt = os.clock()
            runtime.TyrantLastPotSeen = 0
        end
        setStatus(
            "Waiting for Tiki vases/boss",
            string.format("All 4 eyes red | vase rounds cleared %d/3", runtime.TyrantPotRound)
        )
        if typeof(center) == "Vector3" then
            api.MoveTo(CFrame.new(center + Vector3.new(0, 35, 0)))
        end
    end

    local function stepActive()
        local key = runtime.Active
        if not key or runtime.Busy then
            return
        end
        runtime.Busy = true
        local ok, message = xpcall(function()
            if key == "pirate" then stepPirateRaid()
            elseif key == "tyrant" then stepTyrant()
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
        addTask(dragon, "tyrant", "blox_third_auto_tyrant", "Kills Tiki NPCs for all four red owl eyes, destroys all vase rounds with Z/X/C/F skills only, then farms Tyrant.")

        local race = pages.Player:AddSection("Race Progression", "Right")
        addTask(race, "race", "blox_third_auto_race_v4", "Reads RaceV4Progress and enters the Temple of Time when prerequisites are complete.")

        local bosses = pages.Farming:AddSection("Third Sea Bosses", "Right")
        runtime.CakeLabel = bosses:AddLabel("Cake Prince Portal: Reading progress...")
        addTask(bosses, "cake", "blox_third_auto_cake_prince", "Reads the real Cake Prince portal counter, farms 500 Cake Land NPCs, enters BigMirror, then kills the boss.")
    end

    local function buildWeaponSections()
        local weapons = pages.Farming:AddSection("Third Sea Weapon Unlocks", "Left")
        addTask(weapons, "yama", "blox_third_auto_yama", "Builds Elite Hunter progress, then pulls Yama from Hydra Secret Temple.")
        addTask(weapons, "tushita", "blox_third_auto_tushita", "Reads TushitaProgress, lights the five torches in order, then farms Longma.")
        addTask(weapons, "cdk", "blox_third_auto_cdk", "Runs Good and Evil CDK trials and opens the final Cursed Skeleton boss room.")
        addTask(weapons, "guitar", "blox_third_auto_soul_guitar", "Starts the gravestone and ghost stages, follows puzzle objects, then crafts Soul Guitar.")

        local drops = pages.Farming:AddSection("Third Sea Boss Drops", "Right")
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
