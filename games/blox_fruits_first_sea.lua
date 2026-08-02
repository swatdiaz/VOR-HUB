-- First Sea progression extension. The main Blox Fruits module owns combat and
-- movement; this builder only reads quest state and selects the next real step.
return function(context)
    local Window = assert(context.Window, "First Sea module requires Window")
    local gui = assert(context.Gui, "First Sea module requires Gui")
    local track = assert(context.Track, "First Sea module requires Track")
    local pages = assert(context.Pages, "First Sea module requires Pages")
    local api = assert(context.AutomationAPI, "First Sea module requires automation API")
    local remotes = assert(context.Remotes, "First Sea module requires remotes")
    local helpers = assert(context.Helpers, "First Sea module requires helpers")
    local sharedState = assert(context.State, "First Sea module requires shared state")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    local map = workspace:FindFirstChild("Map")
    local jungle = map and map:FindFirstChild("Jungle")
    local desert = map and map:FindFirstChild("Desert")
    if not jungle or not desert then
        return
    end

    local runtime = {
        Alive = true,
        Enabled = false,
        Busy = false,
        Stage = "Idle",
        LastStep = 0,
        LastRemote = {},
        CachedRemote = {},
        LastInventory = 0,
        SaberOwned = false,
        RelicPlacementRequestedAt = 0,
        RelicPlaced = false,
        StatusLabel = nil,
        Toggle = nil,
    }

    local function notify(message, duration)
        Window:Notify("Auto Saber", tostring(message), duration or 4)
    end

    local function setStatus(stage, detail, color)
        runtime.Stage = tostring(stage or "Waiting")
        if runtime.StatusLabel then
            runtime.StatusLabel.Text = "Saber: " .. runtime.Stage .. (detail and (" | " .. tostring(detail)) or "")
            runtime.StatusLabel.TextColor3 = color or context.COLORS.muted
        end
        gui:SetAttribute("BloxAutoSaber", runtime.Enabled)
        gui:SetAttribute("BloxAutoSaberStage", runtime.Stage)
        gui:SetAttribute("BloxAutoSaberDetail", tostring(detail or ""))
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

    local function cachedInvoke(key, delay, command, ...)
        local now = os.clock()
        if now - (runtime.LastRemote[key] or 0) >= delay then
            runtime.LastRemote[key] = now
            local ok, result = rawInvoke(command, ...)
            if ok then
                runtime.CachedRemote[key] = result == nil and "__NIL__" or result
            end
        end
        local cached = runtime.CachedRemote[key]
        return cached == "__NIL__" and nil or cached
    end

    local function character()
        return helpers.Character()
    end

    local function rootPart()
        return helpers.RootPart()
    end

    local function toolNamed(name)
        local char = character()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        return (char and char:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
    end

    local function equip(tool)
        local body = helpers.Humanoid()
        if not tool or not body then
            return false
        end
        if tool.Parent ~= character() then
            body:EquipTool(tool)
        end
        return tool.Parent == character()
    end

    local function saberOwned(force)
        if toolNamed("Saber") then
            runtime.SaberOwned = true
            return true
        end
        if not force and os.clock() - runtime.LastInventory < 6 then
            return runtime.SaberOwned
        end
        runtime.LastInventory = os.clock()
        local ok, inventory = rawInvoke("getInventoryWeapons")
        runtime.SaberOwned = false
        if ok and type(inventory) == "table" then
            for _, item in pairs(inventory) do
                local name = type(item) == "table" and (item.Name or item.name) or item
                if tostring(name) == "Saber" then
                    runtime.SaberOwned = true
                    break
                end
            end
        end
        return runtime.SaberOwned
    end

    local function moveNear(target, offset, radius)
        local root = rootPart()
        if not root or not target then
            return false
        end
        local targetCFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
        local destination = targetCFrame + (offset or Vector3.new(0, 3, 0))
        if (root.Position - destination.Position).Magnitude > (radius or 7) then
            api.MoveTo(destination)
            return false
        end
        return true
    end

    local function touchPart(part)
        local root = rootPart()
        if not root or not part then
            return false
        end
        if not moveNear(part, Vector3.new(0, 3, 0), 7) then
            return false
        end
        if type(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(root, part, 0)
                firetouchinterest(root, part, 1)
            end)
        else
            root.CFrame = part.CFrame + Vector3.new(0, 2.5, 0)
        end
        return true
    end

    local function setExclusive()
        sharedState.AutoFarmLevel = false
        sharedState.AutoBoss = false
        sharedState.AutoRaid = false
        sharedState.AutoChest = false
        sharedState.MobAuraTp = false
        sharedState.SelectedMobFarm = false
        for _, flag in ipairs({
            "blox_auto_level",
            "blox_auto_boss",
            "blox_auto_raid",
            "blox_auto_chest",
            "blox_mob_aura_tp",
            "blox_selected_mob_farm",
        }) do
            local control = Window.PersistentControls[flag]
            if control and control:Get() then
                control:Set(false)
            end
        end
    end

    local function finish(message)
        runtime.Enabled = false
        api.Stop()
        api.SetCombat(false)
        if runtime.Toggle and runtime.Toggle:Get() then
            runtime.Toggle:Set(false)
        end
        setStatus("Complete", message, context.COLORS.success)
        notify(message, 6)
    end

    local function stepPlates(plates)
        local door = plates and plates:FindFirstChild("Door")
        if not door or door.Transparency ~= 0 then
            return false
        end
        for index = 1, 5 do
            local plate = plates:FindFirstChild("Plate" .. index)
            local button = plate and plate:FindFirstChild("Button")
            if button and button:IsA("BasePart") then
                setStatus("Jungle plates", "Activating plate " .. index, context.COLORS.warning)
                touchPart(button)
                return true
            end
        end
        setStatus("Jungle plates", "Waiting for plate buttons", context.COLORS.warning)
        return true
    end

    local function stepTorch()
        local burn = desert:FindFirstChild("Burn")
        local burnPart = burn and burn:FindFirstChild("Part")
        if not burnPart or burnPart.Transparency ~= 0 then
            return false
        end
        local torch = toolNamed("Torch")
        if not torch then
            setStatus("Torch", "Collecting Jungle torch", context.COLORS.warning)
            touchPart(jungle:FindFirstChild("Torch"))
            return true
        end
        equip(torch)
        setStatus("Torch", "Burning the Desert curtain", context.COLORS.warning)
        if moveNear(burnPart, Vector3.new(0, 3, 0), 8) then
            touchPart(burnPart)
        end
        return true
    end

    local function stepSickMan()
        local sick = tonumber(cachedInvoke("sick", 1.25, "ProQuestProgress", "SickMan"))
        if sick == 0 then
            return false
        end
        local cup = toolNamed("Cup")
        if not cup then
            setStatus("Sick Man", "Collecting the Desert cup", context.COLORS.warning)
            local cupPart = desert:FindFirstChild("Cup")
            if not touchPart(cupPart) then
                rawInvoke("ProQuestProgress", "GetCup")
            end
            return true
        end
        equip(cup)
        local handle = cup:FindFirstChild("Handle")
        local empty = handle and handle:FindFirstChildOfClass("TouchTransmitter") ~= nil
        if empty then
            local water = CFrame.new(1397.0614, 37.348, -1321.0396)
            local root = rootPart()
            setStatus("Sick Man", "Filling the cup", context.COLORS.warning)
            if root and (root.Position - water.Position).Magnitude > 8 then
                api.MoveTo(water)
            else
                rawInvoke("ProQuestProgress", "FillCup", cup)
                runtime.LastRemote.sick = 0
            end
            return true
        end
        local sickMan = CFrame.new(1457.8798, 88.2522, -1390.3958)
        local root = rootPart()
        setStatus("Sick Man", "Delivering water", context.COLORS.warning)
        if root and (root.Position - sickMan.Position).Magnitude > 8 then
            api.MoveTo(sickMan)
        else
            rawInvoke("ProQuestProgress", "SickMan")
            runtime.LastRemote.sick = 0
        end
        return true
    end

    local function stepRichSon()
        local result = cachedInvoke("rich", 1.25, "ProQuestProgress", "RichSon")
        local stage = tonumber(result)
        if result == nil then
            local richMan = CFrame.new(-909.1067, 13.752, 4077.3489)
            local root = rootPart()
            setStatus("Rich Man", "Starting Rich Son quest", context.COLORS.warning)
            if root and (root.Position - richMan.Position).Magnitude > 8 then
                api.MoveTo(richMan)
            else
                rawInvoke("ProQuestProgress", "RichSon")
                runtime.LastRemote.rich = 0
            end
            return true
        end
        if stage == 0 then
            setStatus("Mob Leader", "Defeating Mob Leader", context.COLORS.warning)
            api.FarmFirst({"Mob Leader"}, CFrame.new(-2852.9, 7.56, 5367.72), 900, 22)
            return true
        end
        if stage == 1 then
            local relic = toolNamed("Relic")
            if runtime.RelicPlacementRequestedAt > 0 then
                if relic then
                    runtime.RelicPlacementRequestedAt = 0
                    runtime.RelicPlaced = false
                    gui:SetAttribute("BloxAutoSaberRelicPlaced", false)
                    return false
                end
                if os.clock() - runtime.RelicPlacementRequestedAt < 1.5 then
                    setStatus("Relic", "Verifying personal Relic consumption", context.COLORS.warning)
                    return true
                end
                runtime.RelicPlaced = true
                gui:SetAttribute("BloxAutoSaberRelicPlaced", true)
                return false
            end
            if runtime.RelicPlaced then
                return false
            end
            if relic then
                return false
            end
            local richMan = CFrame.new(-909.1067, 13.752, 4077.3489)
            local root = rootPart()
            setStatus("Rich Man", "Collecting the Relic", context.COLORS.warning)
            if root and (root.Position - richMan.Position).Magnitude > 8 then
                api.MoveTo(richMan)
            else
                rawInvoke("ProQuestProgress", "RichSon")
                rawInvoke("ProQuestProgress")
                runtime.LastRemote.rich = 0
            end
            return true
        end
        return false
    end

    local function stepFinalDoor()
        local final = jungle:FindFirstChild("Final")
        local finalPart = final and final:FindFirstChild("Part")
        if not finalPart then
            return false
        end
        if runtime.RelicPlaced then
            return false
        end
        local relic = toolNamed("Relic")
        -- Final.Part is shared world geometry and can already be transparent
        -- because another player opened the room. The player's Relic is the
        -- authoritative personal-stage signal: keep placing until it is
        -- consumed, even if the shared door already looks open.
        if relic then
            equip(relic)
            setStatus("Relic", "Placing personal Relic in the Jungle door", context.COLORS.warning)
            local root = rootPart()
            local relicSlot = CFrame.new(-1404.915, 29.9773, 3.806)
            if root and (root.Position - relicSlot.Position).Magnitude > 3 then
                api.MoveTo(relicSlot)
            else
                local ok = rawInvoke("ProQuestProgress", "PlaceRelic")
                if ok then
                    runtime.RelicPlacementRequestedAt = os.clock()
                    gui:SetAttribute("BloxAutoSaberRelicRequestAt", runtime.RelicPlacementRequestedAt)
                end
            end
            return true
        end
        if finalPart.Transparency ~= 0 then
            return false
        end
        runtime.LastRemote.rich = 0
        setStatus("Relic", "Waiting for Rich Man to give the Relic", context.COLORS.warning)
        return true
    end

    local function stepSaber()
        if saberOwned(false) then
            finish("Saber is owned; automation stopped")
            return
        end
        setExclusive()
        local level = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
        if level and tonumber(level.Value) and tonumber(level.Value) < 200 then
            setStatus("Locked", "Requires level 200", context.COLORS.error)
            return
        end
        if stepPlates(jungle:FindFirstChild("QuestPlates")) then return end
        if stepTorch() then return end
        if stepSickMan() then return end
        if stepRichSon() then return end
        if stepFinalDoor() then return end
        setStatus("Saber Expert", "Defeating Saber Expert", context.COLORS.warning)
        api.FarmFirst({"Saber Expert"}, CFrame.new(-1405, 30, 5), 900, 24)
    end

    local section = pages.Farming:AddSection("First Sea Unlocks", "Right")
    runtime.StatusLabel = section:AddLabel("Saber: Ready")
    runtime.Toggle = section:AddToggle({
        Name = "Auto Saber Unlock",
        Description = "Resumes the live Saber quest stage, kills Mob Leader, places the Relic, and farms Saber Expert",
        Flag = "blox_auto_saber_unlock",
        Default = false,
        Callback = function(enabled)
            runtime.Enabled = enabled == true
            runtime.CachedRemote = {}
            runtime.LastRemote = {}
            runtime.RelicPlacementRequestedAt = 0
            runtime.RelicPlaced = false
            gui:SetAttribute("BloxAutoSaberRelicPlaced", false)
            if runtime.Enabled then
                setExclusive()
                api.SetCombat(true)
                setStatus("Starting", "Reading live quest progress", context.COLORS.warning)
            else
                api.Stop()
                setStatus("Idle", "Off", context.COLORS.muted)
            end
        end,
    })
    section:AddButton({
        Name = "Refresh Saber Progress",
        Callback = function()
            runtime.CachedRemote = {}
            runtime.LastRemote = {}
            runtime.LastInventory = 0
            notify(saberOwned(true) and "Saber is already owned" or "Saber progress refreshed")
        end,
    })

    track(RunService.Heartbeat:Connect(function()
        if not runtime.Alive or not runtime.Enabled or runtime.Busy or os.clock() - runtime.LastStep < 0.28 then
            return
        end
        runtime.LastStep = os.clock()
        runtime.Busy = true
        local ok, message = xpcall(stepSaber, debug.traceback)
        runtime.Busy = false
        if not ok then
            setStatus("Error", message, context.COLORS.error)
            gui:SetAttribute("BloxAutoSaberError", tostring(message))
        end
    end))

    track(gui.Destroying:Connect(function()
        runtime.Alive = false
        runtime.Enabled = false
        api.Stop()
    end))

    gui:SetAttribute("BloxFirstSeaModule", true)
    gui:SetAttribute("BloxFirstSeaVersion", "1")
    setStatus("Ready", "Current quest stage will be resumed", context.COLORS.success)
end
