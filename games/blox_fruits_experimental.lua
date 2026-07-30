-- Isolated high-rate Double Attack runtime. The normal Combat toggle owns this
-- engine; keeping it in a separate module protects the main builder's register
-- budget and makes the aggressive cadence easy to replace without UI bloat.
return function(context)
    local Window = assert(context.Window, "Double Attack runtime requires Window")
    local gui = assert(context.Gui, "Double Attack runtime requires Gui")
    local track = assert(context.Track, "Double Attack runtime requires Track")
    local pages = assert(context.Pages, "Double Attack runtime requires Pages")
    local api = assert(context.API, "Double Attack runtime requires API")
    local colors = context.COLORS or {}
    local RunService = game:GetService("RunService")

    local runtime = {
        Alive = true,
        Active = false,
        MagnetBoost = false,
        Dragonstorm = false,
        LastSword = 0,
        LastFruit = 0,
        SwordBusy = false,
        FruitBusy = false,
        GunBusy = false,
        SwordRequests = 0,
        FruitRequests = 0,
        GunRequests = 0,
        SwordTargets = 0,
        FruitTargets = 0,
        GunTargets = 0,
        LastGun = 0,
        LastError = nil,
        LastUi = 0,
    }

    local section = pages.Combat:AddSection("Double Attack Engine", "Left")
    local statusLabel = section:AddLabel("Double Attack: Off")
    local detailLabel = section:AddLabel("Sword 0 | Fruit 0 | Waiting for Aura Kill")

    local function controlValue(flag)
        local controls = Window.PersistentControls
        local control = controls and controls[flag]
        return control and control:Get()
    end

    local function doubleEnabled()
        return controlValue("blox_double_attack") == true
    end

    local function armRequiredControls()
        for flag, value in pairs({
            blox_auto_attack = true,
            blox_auto_buso = true,
        }) do
            local controls = Window.PersistentControls
            local control = controls and controls[flag]
            if control and control:Get() ~= value then
                control:Set(value)
            end
        end
    end

    local function updateOverride()
        local active = runtime.Alive and doubleEnabled() and api.IsReady()
        if active ~= runtime.Active then
            runtime.Active = active
            runtime.LastSword = 0
            runtime.LastFruit = 0
            runtime.LastError = nil
            api.SetOverride(active)
            gui:SetAttribute("BloxFastDoubleAttack", active)
        end
        if active then
            armRequiredControls()
        end
        return active
    end

    local function dispatchSword()
        if runtime.SwordBusy then
            return
        end
        runtime.SwordBusy = true
        runtime.LastSword = os.clock()
        runtime.SwordRequests += 1
        task.spawn(function()
            local ok, sent, message, count = pcall(api.DispatchRegistered, "Sword", false, 0.13)
            runtime.SwordBusy = false
            if ok and sent then
                runtime.SwordTargets += math.max(tonumber(count) or 1, 1)
                return
            end
            local failure = tostring(ok and message or sent)
            if not failure:find("No enemy", 1, true)
                and not failure:find("left Aura range", 1, true) then
                runtime.LastError = "Sword: " .. failure
            end
        end)
    end

    local function dispatchFruit()
        if runtime.FruitBusy then
            return
        end
        runtime.FruitBusy = true
        runtime.LastFruit = os.clock()
        runtime.FruitRequests += 1
        task.spawn(function()
            local fruit = api.ToolForSelection("M1 Fruit")
            local ok, sent, message, count = pcall(api.DispatchFruit, fruit)
            runtime.FruitBusy = false
            if ok and sent then
                runtime.FruitTargets += math.max(tonumber(count) or 1, 1)
                return
            end
            local failure = tostring(ok and message or sent)
            if not failure:find("No enemy", 1, true)
                and not failure:find("left Aura range", 1, true) then
                runtime.LastError = "Fruit: " .. failure
            end
        end)
    end

    local function dispatchDragonstorm()
        if runtime.GunBusy then
            return
        end
        runtime.GunBusy = true
        runtime.LastGun = os.clock()
        runtime.GunRequests += 1
        task.spawn(function()
            local ok, sent, message, count = pcall(api.DispatchDragonstorm)
            runtime.GunBusy = false
            if ok and sent then
                runtime.GunTargets += math.max(tonumber(count) or 1, 1)
                return
            end
            local failure = tostring(ok and message or sent)
            if not failure:find("No enemy", 1, true) then
                runtime.LastError = "Dragonstorm: " .. failure
            end
        end)
    end

    section:AddToggle({
        Name = "Experimental Magnet Boost",
        Description = "Reacquires network ownership more often; Auto Magnet still controls range and target filtering",
        Flag = "blox_experimental_magnet_boost",
        Default = false,
        Callback = function(enabled)
            runtime.MagnetBoost = enabled == true
            api.SetMagnetBoost(runtime.MagnetBoost)
            gui:SetAttribute("BloxExperimentalMagnetBoost", runtime.MagnetBoost)
        end,
    })
    section:AddToggle({
        Name = "Dragonstorm Auto Track",
        Description = "Fires the loaded Dragonstorm at the nearest Aura target while Sword + Fruit Double Attack remains active",
        Flag = "blox_dragonstorm_auto_track",
        Default = false,
        Callback = function(enabled)
            runtime.Dragonstorm = enabled == true
            runtime.LastGun = 0
            gui:SetAttribute("BloxDragonstormAutoTrack", runtime.Dragonstorm)
        end,
    })
    section:AddLabel("The normal Double Attack toggle now runs the fastest validated Sword + Fruit M1 engine. Triple and Melee were removed.")

    track(RunService.Heartbeat:Connect(function()
        if not updateOverride() then
            return
        end
        api.EnsureBuso()
        local now = os.clock()
        if not runtime.SwordBusy and now - runtime.LastSword >= 0.13 then
            dispatchSword()
        end
        if not runtime.FruitBusy and now - runtime.LastFruit >= 0.055 then
            dispatchFruit()
        end
        if runtime.Dragonstorm and not runtime.GunBusy and now - runtime.LastGun >= 0.08 then
            dispatchDragonstorm()
        end
    end))

    track(RunService.Heartbeat:Connect(function()
        if os.clock() - runtime.LastUi < 0.25 then
            return
        end
        runtime.LastUi = os.clock()
        statusLabel.Text = runtime.Active
            and "Double Attack: Fast Sword + Fruit M1"
            or (doubleEnabled() and "Double Attack: Waiting for Aura Kill" or "Double Attack: Off")
        statusLabel.TextColor3 = runtime.Active and (colors.success or Color3.fromRGB(70, 225, 150))
            or (colors.muted or Color3.fromRGB(145, 135, 165))
        detailLabel.Text = string.format(
            "Requests S/F/G: %d/%d/%d | Targets: %d/%d/%d%s",
            runtime.SwordRequests,
            runtime.FruitRequests,
            runtime.GunRequests,
            runtime.SwordTargets,
            runtime.FruitTargets,
            runtime.GunTargets,
            runtime.LastError and (" | " .. runtime.LastError) or ""
        )
        gui:SetAttribute("BloxExperimentalMode", runtime.Active and "Fast Double" or "Off")
        gui:SetAttribute("BloxExperimentalSwordRequests", runtime.SwordRequests)
        gui:SetAttribute("BloxExperimentalFruitRequests", runtime.FruitRequests)
        gui:SetAttribute("BloxDragonstormRequests", runtime.GunRequests)
        gui:SetAttribute("BloxDragonstormTargets", runtime.GunTargets)
        gui:SetAttribute("BloxExperimentalLastError", runtime.LastError or "")
    end))

    gui:SetAttribute("BloxExperimentalModule", true)
    gui:SetAttribute("BloxExperimentalTripleAttack", false)
    gui:SetAttribute("BloxExperimentalMeleeRequests", 0)
    return function()
        runtime.Alive = false
        runtime.Active = false
        runtime.MagnetBoost = false
        runtime.Dragonstorm = false
        api.SetMagnetBoost(false)
        api.SetOverride(false)
    end
end
