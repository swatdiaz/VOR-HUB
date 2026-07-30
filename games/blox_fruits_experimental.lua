-- Isolated experimental combat laboratory. This module deliberately lives
-- outside the main Blox Fruits builder so aggressive prototypes cannot consume
-- its local-register budget or destabilize the normal Aura Kill engine.
return function(context)
    local Window = assert(context.Window, "Experimental combat requires Window")
    local gui = assert(context.Gui, "Experimental combat requires Gui")
    local track = assert(context.Track, "Experimental combat requires Track")
    local pages = assert(context.Pages, "Experimental combat requires Pages")
    local api = assert(context.API, "Experimental combat requires API")
    local colors = context.COLORS or {}
    local RunService = game:GetService("RunService")

    local runtime = {
        Alive = true,
        FastSword = false,
        FastFruit = false,
        FastMelee = false,
        Triple = false,
        Requested = {Sword = 0.13, Fruit = 0.075, Melee = 0.13},
        LastDispatch = {Sword = 0, Fruit = 0, Melee = 0},
        InFlight = {Sword = 0, Fruit = 0, Melee = 0},
        Requests = {Sword = 0, Fruit = 0, Melee = 0},
        SentTargets = {Sword = 0, Fruit = 0, Melee = 0},
        DamageWindows = {Sword = 0, Fruit = 0, Melee = 0},
        DamagedTargets = {Sword = 0, Fruit = 0, Melee = 0},
        LastAcceptedAt = {Sword = nil, Fruit = nil, Melee = nil},
        ObservedCadence = {Sword = nil, Fruit = nil, Melee = nil},
        LastError = nil,
        MaxInFlight = {Sword = 1, Fruit = 3, Melee = 1},
        RegisteredBusy = false,
        NextRegistered = "Sword",
        LastUi = 0,
    }

    local section = pages.Combat:AddSection("Experimental Combat Lab", "Left")
    local statusLabel = section:AddLabel("Experimental combat: Off")
    local detailLabel = section:AddLabel("Accepted damage telemetry is waiting")

    local function categoryEnabled(category)
        return runtime.Triple or runtime["Fast" .. category] == true
    end

    local function anyEnabled()
        return runtime.Triple or runtime.FastSword or runtime.FastFruit or runtime.FastMelee
    end

    local function armRequiredControls()
        for flag, value in pairs({
            blox_auto_attack = true,
            blox_auto_buso = true,
            blox_double_attack = false,
        }) do
            local control = Window.PersistentControls and Window.PersistentControls[flag]
            if control and control:Get() ~= value then
                control:Set(value)
            end
        end
    end

    local function syncOverride()
        local enabled = anyEnabled()
        api.SetOverride(enabled)
        if enabled then
            armRequiredControls()
        end
        gui:SetAttribute("BloxExperimentalCombat", enabled)
        gui:SetAttribute("BloxExperimentalTripleAttack", runtime.Triple)
    end

    local function restoreVisibleSword(delay)
        task.delay(delay or 0, function()
            if not runtime.Alive then
                return
            end
            local sword = api.ToolForSelection("Sword")
            if sword then
                api.EquipTool(sword)
            end
        end)
    end

    local function healthSnapshot(maximum)
        local snapshot = {}
        for _, target in ipairs(api.Targets(maximum or 12)) do
            local body = target.Enemy and target.Enemy:FindFirstChildOfClass("Humanoid")
            if body and body.Health > 0 then
                snapshot[body] = body.Health
            end
        end
        return snapshot
    end

    local function measureDamage(category, before)
        task.delay(0.24, function()
            if not runtime.Alive then
                return
            end
            local damaged = 0
            for body, oldHealth in pairs(before) do
                if body.Parent and body.Health < oldHealth then
                    damaged += 1
                end
            end
            if damaged > 0 then
                local now = os.clock()
                local previous = runtime.LastAcceptedAt[category]
                if previous then
                    local interval = now - previous
                    local observed = runtime.ObservedCadence[category]
                    runtime.ObservedCadence[category] = observed
                        and (observed * 0.72 + interval * 0.28) or interval
                end
                runtime.LastAcceptedAt[category] = now
                runtime.DamageWindows[category] += 1
                runtime.DamagedTargets[category] += damaged
            end
        end)
    end

    local function dispatchCategory(category)
        if runtime.InFlight[category] >= runtime.MaxInFlight[category] then
            return
        end
        if category ~= "Fruit" and runtime.RegisteredBusy then
            return
        end
        local before = healthSnapshot(category == "Fruit" and 3 or 12)
        if next(before) == nil then
            return
        end
        runtime.InFlight[category] += 1
        if category ~= "Fruit" then
            runtime.RegisteredBusy = true
        end
        runtime.Requests[category] += 1
        runtime.LastDispatch[category] = os.clock()
        task.spawn(function()
            local operationOk, sent, message, count
            if category == "Fruit" then
                local fruit = api.ToolForSelection("M1 Fruit")
                if runtime.Triple then
                    local sword = api.ToolForSelection("Sword")
                    if sword then
                        api.EquipTool(sword)
                    end
                end
                operationOk, sent, message, count = pcall(api.DispatchFruit, fruit)
            else
                operationOk, sent, message, count = pcall(
                    api.DispatchRegistered,
                    category,
                    category == "Melee",
                    runtime.Requested[category]
                )
            end
            if operationOk and sent then
                runtime.SentTargets[category] += math.max(tonumber(count) or 1, 1)
                if category ~= "Fruit" then
                    runtime.RegisteredBusy = false
                end
                runtime.InFlight[category] = math.max(runtime.InFlight[category] - 1, 0)
                measureDamage(category, before)
                return
            end
            if category ~= "Fruit" then
                runtime.RegisteredBusy = false
            end
            runtime.InFlight[category] = math.max(runtime.InFlight[category] - 1, 0)
            local failure = operationOk and message or sent
            local text = tostring(failure)
            if not text:find("No enemy", 1, true)
                and not text:find("left Aura range", 1, true) then
                runtime.LastError = category .. ": " .. text
            end
        end)
    end

    local function addCategoryControls(category, defaultCadence, flagPrefix)
        section:AddToggle({
            Name = "Experimental Fast " .. category,
            Description = "Runs the " .. category .. " M1 independently at the requested cadence",
            Flag = flagPrefix .. "_enabled",
            Default = false,
            Callback = function(enabled)
                runtime["Fast" .. category] = enabled == true
                runtime.LastDispatch[category] = 0
                syncOverride()
                if category == "Melee" and enabled then
                    restoreVisibleSword(0)
                end
            end,
        })
        section:AddSlider({
            Name = category .. " Requested Delay",
            Description = "0.00 requests every available frame; accepted damage is measured separately",
            Flag = flagPrefix .. "_delay",
            Min = 0,
            Max = 0.5,
            Step = 0.01,
            Default = defaultCadence,
            Callback = function(value)
                runtime.Requested[category] = math.clamp(tonumber(value) or defaultCadence, 0, 0.5)
                runtime.LastDispatch[category] = 0
            end,
        })
    end

    section:AddToggle({
        Name = "Experimental Triple Attack",
        Description = "Keeps Sword visible while Sword, Fruit M1, and Melee attack independently",
        Flag = "blox_experimental_triple_attack",
        Default = false,
        Callback = function(enabled)
            runtime.Triple = enabled == true
            runtime.LastDispatch.Sword = 0
            runtime.LastDispatch.Fruit = 0
            runtime.LastDispatch.Melee = 0
            syncOverride()
            if not runtime.Triple then
                restoreVisibleSword(0.3)
            end
        end,
    })
    addCategoryControls("Sword", 0.13, "blox_experimental_sword")
    addCategoryControls("Fruit", 0.075, "blox_experimental_fruit")
    addCategoryControls("Melee", 0.13, "blox_experimental_melee")

    section:AddButton({
        Name = "Reset Experimental Telemetry",
        Callback = function()
            for _, bucket in ipairs({
                runtime.Requests,
                runtime.SentTargets,
                runtime.DamageWindows,
                runtime.DamagedTargets,
            }) do
                bucket.Sword = 0
                bucket.Fruit = 0
                bucket.Melee = 0
            end
            runtime.LastAcceptedAt = {Sword = nil, Fruit = nil, Melee = nil}
            runtime.ObservedCadence = {Sword = nil, Fruit = nil, Melee = nil}
            runtime.LastError = nil
        end,
    })
    section:AddLabel("Requested delay is not proof of server acceptance. The live damage counters below are the proof.")

    track(RunService.Heartbeat:Connect(function()
        if not runtime.Alive or not anyEnabled() or not api.IsReady() then
            return
        end
        api.EnsureBuso()
        local now = os.clock()
        if categoryEnabled("Fruit")
            and now - runtime.LastDispatch.Fruit >= runtime.Requested.Fruit then
            dispatchCategory("Fruit")
        end
        local swordReady = categoryEnabled("Sword")
            and now - runtime.LastDispatch.Sword >= runtime.Requested.Sword
        local meleeReady = categoryEnabled("Melee")
            and now - runtime.LastDispatch.Melee >= runtime.Requested.Melee
        if not runtime.RegisteredBusy and (swordReady or meleeReady) then
            local category = runtime.NextRegistered
            if category == "Sword" and not swordReady then
                category = "Melee"
            elseif category == "Melee" and not meleeReady then
                category = "Sword"
            end
            if (category == "Sword" and swordReady) or (category == "Melee" and meleeReady) then
                runtime.NextRegistered = category == "Sword" and "Melee" or "Sword"
                dispatchCategory(category)
            end
        end
    end))

    track(RunService.Heartbeat:Connect(function()
        if os.clock() - runtime.LastUi < 0.25 then
            return
        end
        runtime.LastUi = os.clock()
        local enabled = anyEnabled()
        local mode = runtime.Triple and "Triple" or (enabled and "Custom" or "Off")
        statusLabel.Text = string.format(
            "Experimental combat: %s | Requests S/F/M: %d/%d/%d",
            mode,
            runtime.Requests.Sword,
            runtime.Requests.Fruit,
            runtime.Requests.Melee
        )
        statusLabel.TextColor3 = enabled and (colors.success or Color3.fromRGB(70, 225, 150))
            or (colors.muted or Color3.fromRGB(145, 135, 165))
        local function cadenceText(category)
            local observed = runtime.ObservedCadence[category]
            return observed and string.format("%.3fs", observed) or "--"
        end
        detailLabel.Text = string.format(
            "Damage windows S/F/M: %d/%d/%d | Observed: %s/%s/%s%s",
            runtime.DamageWindows.Sword,
            runtime.DamageWindows.Fruit,
            runtime.DamageWindows.Melee,
            cadenceText("Sword"),
            cadenceText("Fruit"),
            cadenceText("Melee"),
            runtime.LastError and (" | " .. runtime.LastError) or ""
        )
        gui:SetAttribute("BloxExperimentalMode", mode)
        gui:SetAttribute("BloxExperimentalSwordRequests", runtime.Requests.Sword)
        gui:SetAttribute("BloxExperimentalFruitRequests", runtime.Requests.Fruit)
        gui:SetAttribute("BloxExperimentalMeleeRequests", runtime.Requests.Melee)
        gui:SetAttribute("BloxExperimentalSwordDamageWindows", runtime.DamageWindows.Sword)
        gui:SetAttribute("BloxExperimentalFruitDamageWindows", runtime.DamageWindows.Fruit)
        gui:SetAttribute("BloxExperimentalMeleeDamageWindows", runtime.DamageWindows.Melee)
        gui:SetAttribute("BloxExperimentalSwordObservedCadence", runtime.ObservedCadence.Sword or 0)
        gui:SetAttribute("BloxExperimentalFruitObservedCadence", runtime.ObservedCadence.Fruit or 0)
        gui:SetAttribute("BloxExperimentalMeleeObservedCadence", runtime.ObservedCadence.Melee or 0)
        gui:SetAttribute("BloxExperimentalLastError", runtime.LastError or "")
    end))

    syncOverride()
    gui:SetAttribute("BloxExperimentalModule", true)
    return function()
        local sword = api.ToolForSelection("Sword")
        if sword then
            api.EquipTool(sword)
        end
        runtime.Alive = false
        runtime.FastSword = false
        runtime.FastFruit = false
        runtime.FastMelee = false
        runtime.Triple = false
        api.SetOverride(false)
    end
end
