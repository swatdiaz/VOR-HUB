-- Race ability automation extension for the normal Blox Fruits module.
-- Kept isolated so the main builder stays below the executor's 200-register ceiling.
return function(context)
    local Window = assert(context.Window, "race module requires Window")
    local gui = assert(context.Gui, "race module requires Gui")
    local track = assert(context.Track, "race module requires Track")
    local page = assert(context.Page, "race module requires Player page")
    local helpers = assert(context.Helpers, "race module requires Helpers")
    local remotes = assert(context.Remotes, "race module requires Remotes")
    local COLORS = assert(context.COLORS, "race module requires colors")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local CommE = remotes.CommE

    local section = page:AddSection("Race Abilities", "Left")
    local statusLabel = section:AddLabel("Race Ability: Ready")
    local runtime = {
        Alive = true,
        AutoV3 = false,
        AutoV4 = false,
        LastV3Request = 0,
        LastV4Request = 0,
        V3Requests = 0,
        V4Requests = 0,
        LastStatusRefresh = 0,
    }

    local function character()
        return helpers.Character()
    end

    local function universalContextButtons()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main = playerGui and playerGui:FindFirstChild("Main")
        local bottom = main and main:FindFirstChild("BottomHUDList")
        return bottom and bottom:FindFirstChild("UniversalContextButtons")
    end

    local function hudAction(name)
        local buttons = universalContextButtons()
        return buttons and buttons:FindFirstChild(name)
    end

    local function fireHudAction(action)
        if not action or type(firesignal) ~= "function" then
            return false
        end
        local button = action:FindFirstChild("Button") or action:FindFirstChild("CaptureInput")
        if not button or not button:IsA("GuiButton") then
            return false
        end
        return pcall(function()
            firesignal(button.Activated)
            firesignal(button.MouseButton1Click)
        end)
    end

    local function sendActionInput(actionName, keyCode, virtualKey)
        local action = hudAction(actionName)
        if UserInputService.TouchEnabled and fireHudAction(action) then
            return true, "mobile HUD"
        end
        local inputOk, inputManager = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if inputOk and inputManager then
            local sent = pcall(function()
                inputManager:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.04)
                inputManager:SendKeyEvent(false, keyCode, false, game)
            end)
            if sent then
                return true, keyCode.Name .. " key"
            end
        end
        if type(keypress) == "function" and type(keyrelease) == "function" then
            local sent = pcall(function()
                keypress(virtualKey)
                task.wait(0.04)
                keyrelease(virtualKey)
            end)
            if sent then
                return true, "executor " .. keyCode.Name
            end
        end
        if fireHudAction(action) then
            return true, "HUD fallback"
        end
        return false, "no supported input method"
    end

    local function v3Ready()
        local action = hudAction("BoundActionRaceAbility")
        if not action then
            return false
        end
        local locked = action:FindFirstChild("LockedFrame")
        if locked and locked:IsA("GuiObject") and locked.Visible then
            return false
        end
        local cooldown = action:FindFirstChild("CooldownLabel")
        local seconds = cooldown and tonumber(cooldown.Text)
        return not seconds or seconds <= 0.05
    end

    local function transformed()
        local char = character()
        if not char then
            return false
        end
        local value = char:FindFirstChild("RaceTransformed")
        return (value and value:IsA("ValueBase") and value.Value == true)
            or char:GetAttribute("RaceTransformed") == true
            or LocalPlayer:GetAttribute("RaceTransformed") == true
    end

    local function v4Ready()
        if transformed() then
            return false
        end
        local char = character()
        local energy = char and char:FindFirstChild("RaceEnergy")
        local awakening = char and char:FindFirstChild("Awakening")
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        awakening = awakening or (backpack and backpack:FindFirstChild("Awakening"))
        return energy ~= nil and energy:IsA("ValueBase")
            and tonumber(energy.Value) ~= nil and tonumber(energy.Value) >= 1
            and awakening ~= nil
    end

    local function step()
        local now = os.clock()
        if runtime.AutoV4 and v4Ready() and now - runtime.LastV4Request >= 1.5 then
            runtime.LastV4Request = now
            local events = ReplicatedStorage:FindFirstChild("Events")
            local activate = events and events:FindFirstChild("ActivateRaceV4")
            local ok = activate ~= nil and activate:IsA("BindableEvent") and pcall(function()
                activate:Fire()
            end)
            local method = ok and "native ActivateRaceV4" or nil
            if not ok then
                ok, method = sendActionInput("ActivateRaceV4", Enum.KeyCode.Y, 0x59)
            end
            if ok then
                runtime.V4Requests += 1
                statusLabel.Text = "Race V4: Awakening requested via " .. method
                statusLabel.TextColor3 = COLORS.success
                return
            end
            statusLabel.Text = "Race V4: Activation failed - " .. tostring(method)
            statusLabel.TextColor3 = COLORS.error
        end
        if runtime.AutoV3 and v3Ready() and now - runtime.LastV3Request >= 0.75 then
            runtime.LastV3Request = now
            local ok = CommE ~= nil and CommE:IsA("RemoteEvent") and pcall(function()
                CommE:FireServer("ActivateAbility")
            end)
            local method = ok and "native race remote" or nil
            if not ok then
                ok, method = sendActionInput("BoundActionRaceAbility", Enum.KeyCode.T, 0x54)
            end
            if ok then
                runtime.V3Requests += 1
                statusLabel.Text = "Race V3: Ability requested via " .. method
                statusLabel.TextColor3 = COLORS.success
            else
                statusLabel.Text = "Race V3: Activation failed - " .. tostring(method)
                statusLabel.TextColor3 = COLORS.error
            end
        end
    end

    section:AddToggle({
        Name = "Auto Race V3 Ability",
        Description = "Uses the equipped race ability whenever its T/mobile cooldown is ready in any sea",
        Flag = "blox_auto_race_v3",
        Default = false,
        Callback = function(enabled)
            runtime.AutoV3 = enabled == true
            runtime.LastV3Request = 0
            gui:SetAttribute("BloxAutoRaceV3", runtime.AutoV3)
        end,
    })
    section:AddToggle({
        Name = "Auto Race V4 Awakening",
        Description = "Activates Race V4 with Y/mobile input when the awakening meter is full in any sea",
        Flag = "blox_auto_race_v4",
        Default = false,
        Callback = function(enabled)
            runtime.AutoV4 = enabled == true
            runtime.LastV4Request = 0
            gui:SetAttribute("BloxAutoRaceV4", runtime.AutoV4)
        end,
    })

    track(RunService.Heartbeat:Connect(function()
        if not runtime.Alive then
            return
        end
        step()
        local now = os.clock()
        if now - runtime.LastStatusRefresh < 1 then
            return
        end
        runtime.LastStatusRefresh = now
        if transformed() then
            statusLabel.Text = "Race V4: Awakened"
            statusLabel.TextColor3 = COLORS.success
        elseif not runtime.AutoV3 and not runtime.AutoV4 then
            statusLabel.Text = "Race Ability: Off"
            statusLabel.TextColor3 = COLORS.muted
        elseif runtime.AutoV4 and not v4Ready() then
            statusLabel.Text = "Race V4: Armed | Waiting for full awakening meter"
            statusLabel.TextColor3 = COLORS.muted
        elseif runtime.AutoV3 and not v3Ready() then
            statusLabel.Text = "Race V3: Armed | Waiting for ability cooldown"
            statusLabel.TextColor3 = COLORS.muted
        end
        gui:SetAttribute("BloxRaceV3Requests", runtime.V3Requests)
        gui:SetAttribute("BloxRaceV4Requests", runtime.V4Requests)
        gui:SetAttribute("BloxRaceV4Ready", v4Ready())
        gui:SetAttribute("BloxRaceTransformed", transformed())
    end))

    gui:SetAttribute("BloxAutoRaceV3", false)
    gui:SetAttribute("BloxAutoRaceV4", false)
    gui:SetAttribute("BloxRaceV3Requests", 0)
    gui:SetAttribute("BloxRaceV4Requests", 0)
    gui:SetAttribute("BloxRaceV4Ready", false)
    gui:SetAttribute("BloxRaceTransformed", false)
    track(gui.Destroying:Connect(function()
        runtime.Alive = false
        runtime.AutoV3 = false
        runtime.AutoV4 = false
    end))
end
