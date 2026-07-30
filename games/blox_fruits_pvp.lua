-- Focused PvP extension for Blox Fruits.
-- Separate from the farm/combat builder to preserve Luau register headroom.
return function(context)
    local Window = assert(context.Window, "PvP module requires Window")
    local gui = assert(context.Gui, "PvP module requires Gui")
    local track = assert(context.Track, "PvP module requires Track")
    local page = assert(context.Page, "PvP module requires a page")
    local helpers = assert(context.Helpers, "PvP module requires Helpers")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    local state = {
        Alive = true,
        SelectedPlayer = "None",
        Spectating = false,
        FollowTarget = false,
        AutoAttack = false,
        FruitM1 = false,
        AutoBounty = false,
        Weapon = "Best Available",
        Skills = {Z = true, X = true, C = true, V = true},
        AttackDistance = 10,
        FollowHeight = 5,
        TargetTimeout = 20,
        EscapeHealth = 25,
        ReturnHealth = 65,
        AimFov = 180,
        Prediction = 0.12,
        AimPart = "HumanoidRootPart",
        NearestToCursor = false,
        LastAttack = 0,
        LastSkill = 0,
        LastRefresh = 0,
        TargetStartedAt = 0,
        OriginalPosition = nil,
        Escaping = false,
        SkillIndex = 0,
    }

    local statusLabel
    local targetDropdown

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 3)
    end

    local function character(player)
        local value = player and player.Character
        return value and value.Parent and value or nil
    end

    local function humanoid(player)
        local model = character(player)
        return model and model:FindFirstChildOfClass("Humanoid") or nil
    end

    local function root(player)
        local model = character(player)
        return model and model:FindFirstChild("HumanoidRootPart") or nil
    end

    local function alive(player)
        local body = humanoid(player)
        return body and body.Health > 0 and root(player) ~= nil
    end

    local function playerOptions()
        local options = {"None"}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(options, player.Name)
            end
        end
        table.sort(options, function(a, b)
            if a == "None" then return true end
            if b == "None" then return false end
            return string.lower(a) < string.lower(b)
        end)
        return options
    end

    local function selectedPlayer()
        if state.SelectedPlayer == "None" then
            return nil
        end
        return Players:FindFirstChild(state.SelectedPlayer)
    end

    local function healthPercent(player)
        local body = humanoid(player)
        return body and body.MaxHealth > 0 and body.Health / body.MaxHealth * 100 or 0
    end

    local function safeZone(player)
        local model = character(player)
        if not model then
            return true
        end
        for _, name in ipairs({"SafeZone", "InSafeZone", "PvpDisabled", "PvPDisabled"}) do
            if player:GetAttribute(name) == true or model:GetAttribute(name) == true then
                return true
            end
            local value = model:FindFirstChild(name)
            if value and value:IsA("BoolValue") and value.Value then
                return true
            end
        end
        return false
    end

    local function screenDistance(player)
        local targetRoot = root(player)
        if not targetRoot then
            return math.huge
        end
        local point, visible = Camera:WorldToViewportPoint(targetRoot.Position)
        if not visible then
            return math.huge
        end
        local mouse = UserInputService:GetMouseLocation()
        return (Vector2.new(point.X, point.Y) - mouse).Magnitude
    end

    local function nearestTarget(useCursor)
        local localRoot = root(LocalPlayer)
        if not localRoot then
            return nil
        end
        local best, score
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and alive(player) and not safeZone(player) then
                local playerRoot = root(player)
                local candidate = useCursor and screenDistance(player)
                    or (localRoot.Position - playerRoot.Position).Magnitude
                if (not useCursor or candidate <= state.AimFov) and (not score or candidate < score) then
                    best, score = player, candidate
                end
            end
        end
        return best
    end

    local function activeTarget()
        local target = selectedPlayer()
        if alive(target) and not safeZone(target) then
            return target
        end
        if state.AutoBounty or state.NearestToCursor then
            target = nearestTarget(state.NearestToCursor)
            if target and state.SelectedPlayer ~= target.Name then
                state.SelectedPlayer = target.Name
                state.TargetStartedAt = os.clock()
                if targetDropdown then
                    targetDropdown:Set(target.Name)
                end
            end
            return target
        end
        return nil
    end

    local function toolKind(tool)
        local tooltip = string.lower(tostring(tool and tool.ToolTip or ""))
        if tooltip:find("sword", 1, true) then return "Sword" end
        if tooltip:find("gun", 1, true) then return "Gun" end
        if tooltip:find("fruit", 1, true) or tooltip:find("blox", 1, true) then return "Fruit" end
        if tooltip:find("melee", 1, true) then return "Melee" end
        return "Unknown"
    end

    local function allTools()
        local result = {}
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, container in ipairs({character(LocalPlayer), backpack}) do
            if container then
                for _, object in ipairs(container:GetChildren()) do
                    if object:IsA("Tool") then
                        table.insert(result, object)
                    end
                end
            end
        end
        return result
    end

    local function chooseTool()
        local fallback
        for _, tool in ipairs(allTools()) do
            local kind = toolKind(tool)
            if not fallback and kind ~= "Unknown" then
                fallback = tool
            end
            if state.Weapon == "Best Available"
                and (kind == "Sword" or kind == "Melee" or kind == "Fruit") then
                return tool
            elseif kind == state.Weapon then
                return tool
            end
        end
        return fallback
    end

    local function equip(tool)
        local body = humanoid(LocalPlayer)
        if body and tool and tool.Parent then
            pcall(function() body:EquipTool(tool) end)
            return tool.Parent == character(LocalPlayer)
        end
        return false
    end

    local function predictedPosition(target)
        local targetModel = character(target)
        local targetPart = targetModel and (targetModel:FindFirstChild(state.AimPart) or root(target))
        if not targetPart then
            return nil
        end
        return targetPart.Position + targetPart.AssemblyLinearVelocity * state.Prediction
    end

    local function aimAt(target)
        local position = predictedPosition(target)
        if not position then
            return
        end
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, position)
        gui:SetAttribute("BloxPvpAimTarget", target.Name)
    end

    local function moveNear(target)
        local localRoot = root(LocalPlayer)
        local targetRoot = root(target)
        if not localRoot or not targetRoot then
            return false
        end
        local desired = targetRoot.CFrame * CFrame.new(0, state.FollowHeight, state.AttackDistance)
        localRoot.AssemblyLinearVelocity = Vector3.zero
        localRoot.AssemblyAngularVelocity = Vector3.zero
        localRoot.CFrame = desired
        return true
    end

    local function attackTarget(target)
        if os.clock() - state.LastAttack < 0.08 then
            return
        end
        state.LastAttack = os.clock()
        local tool = chooseTool()
        if not tool or not equip(tool) then
            return
        end
        aimAt(target)
        pcall(function() tool:Activate() end)
        if type(mouse1click) == "function" then
            pcall(mouse1click)
        end
        if state.FruitM1 then
            for _, candidate in ipairs(allTools()) do
                if toolKind(candidate) == "Fruit" and equip(candidate) then
                    pcall(function() candidate:Activate() end)
                    break
                end
            end
        end
        if os.clock() - state.LastSkill >= 0.18 then
            state.LastSkill = os.clock()
            local enabled = {}
            for key, selected in pairs(state.Skills) do
                if (type(key) == "number" and type(selected) == "string") or selected == true then
                    table.insert(enabled, type(key) == "number" and selected or key)
                end
            end
            table.sort(enabled)
            if #enabled > 0 then
                state.SkillIndex = state.SkillIndex % #enabled + 1
                local keyCode = Enum.KeyCode[enabled[state.SkillIndex]]
                if keyCode then
                    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                    task.delay(0.08, function()
                        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                    end)
                end
            end
        end
    end

    local function stopSpectating()
        state.Spectating = false
        local body = humanoid(LocalPlayer)
        if body then Camera.CameraSubject = body end
    end

    local function setTarget(name)
        state.SelectedPlayer = tostring(name or "None")
        state.TargetStartedAt = os.clock()
        state.OriginalPosition = root(LocalPlayer) and root(LocalPlayer).CFrame or state.OriginalPosition
        if state.SelectedPlayer == "None" then
            stopSpectating()
        end
    end

    local function escapeIfNeeded()
        local localHealth = healthPercent(LocalPlayer)
        if localHealth <= state.EscapeHealth and not state.Escaping then
            state.Escaping = true
            local localRoot = root(LocalPlayer)
            if localRoot then
                localRoot.CFrame += Vector3.new(0, 350, 0)
            end
        elseif state.Escaping and localHealth >= state.ReturnHealth then
            state.Escaping = false
            if state.OriginalPosition and root(LocalPlayer) then
                root(LocalPlayer).CFrame = state.OriginalPosition
            end
        end
        return state.Escaping
    end

    local main = page:AddSection("Target Player", "Left")
    statusLabel = main:AddLabel("PvP: Idle")
    targetDropdown = main:AddDropdown({
        Name = "Player Selection",
        Flag = "blox_pvp_target",
        Options = playerOptions(),
        Default = "None",
        Callback = setTarget,
    })
    main:AddButton({
        Name = "Refresh Players",
        Callback = function()
            targetDropdown:SetOptions(playerOptions(), true)
            notify("PvP", "Player list refreshed")
        end,
    })
    main:AddToggle({
        Name = "Spectate Target",
        Flag = "blox_pvp_spectate",
        Default = false,
        Callback = function(enabled)
            state.Spectating = enabled == true
            if not state.Spectating then stopSpectating() end
        end,
    })
    main:AddButton({
        Name = "Teleport to Target",
        Callback = function()
            local target = activeTarget()
            notify("PvP", target and moveNear(target) and ("Teleported to " .. target.Name) or "Choose a valid player")
        end,
    })
    main:AddToggle({
        Name = "Follow Target",
        Flag = "blox_pvp_follow_target",
        Default = false,
        Callback = function(enabled) state.FollowTarget = enabled == true end,
    })

    local combat = page:AddSection("PvP Combat", "Right")
    combat:AddDropdown({
        Name = "Weapon",
        Flag = "blox_pvp_weapon",
        Options = {"Best Available", "Melee", "Sword", "Fruit", "Gun"},
        Default = "Best Available",
        Callback = function(value) state.Weapon = tostring(value) end,
    })
    combat:AddDropdown({
        Name = "Auto Use Skills",
        Flag = "blox_pvp_skills",
        Options = {"Z", "X", "C", "V", "F"},
        Multi = true,
        Default = {"Z", "X", "C", "V"},
        Callback = function(value) state.Skills = type(value) == "table" and value or {} end,
    })
    combat:AddSlider({
        Name = "Attack Distance",
        Flag = "blox_pvp_attack_distance",
        Min = 2, Max = 40, Step = 1, Default = 10,
        Callback = function(value) state.AttackDistance = tonumber(value) or 10 end,
    })
    combat:AddSlider({
        Name = "Follow Height",
        Flag = "blox_pvp_follow_height",
        Min = -10, Max = 40, Step = 1, Default = 5,
        Callback = function(value) state.FollowHeight = tonumber(value) or 5 end,
    })
    combat:AddToggle({
        Name = "Auto Attack Target",
        Flag = "blox_pvp_auto_attack",
        Default = false,
        Callback = function(enabled) state.AutoAttack = enabled == true end,
    })
    combat:AddToggle({
        Name = "Fruit M1 Hunter",
        Flag = "blox_pvp_fruit_m1",
        Default = false,
        Callback = function(enabled) state.FruitM1 = enabled == true end,
    })

    local bounty = page:AddSection("Auto Bounty Hunter", "Left")
    bounty:AddToggle({
        Name = "Auto Bounty Hunter",
        Flag = "blox_pvp_auto_bounty",
        Default = false,
        Callback = function(enabled)
            state.AutoBounty = enabled == true
            state.TargetStartedAt = os.clock()
            state.OriginalPosition = root(LocalPlayer) and root(LocalPlayer).CFrame or nil
        end,
    })
    bounty:AddSlider({
        Name = "Target Timeout",
        Flag = "blox_pvp_target_timeout",
        Min = 5, Max = 120, Step = 5, Default = 20,
        Suffix = "s",
        Callback = function(value) state.TargetTimeout = tonumber(value) or 20 end,
    })
    bounty:AddSlider({
        Name = "Escape Below Health",
        Flag = "blox_pvp_escape_health",
        Min = 5, Max = 75, Step = 5, Default = 25,
        Suffix = "%",
        Callback = function(value) state.EscapeHealth = tonumber(value) or 25 end,
    })
    bounty:AddSlider({
        Name = "Return At Health",
        Flag = "blox_pvp_return_health",
        Min = 25, Max = 100, Step = 5, Default = 65,
        Suffix = "%",
        Callback = function(value) state.ReturnHealth = tonumber(value) or 65 end,
    })

    local aim = page:AddSection("Target Selection", "Right")
    aim:AddToggle({
        Name = "Nearest to Cursor",
        Flag = "blox_pvp_nearest_cursor",
        Default = false,
        Callback = function(enabled) state.NearestToCursor = enabled == true end,
    })
    aim:AddDropdown({
        Name = "Aim Part",
        Flag = "blox_pvp_aim_part",
        Options = {"HumanoidRootPart", "Head"},
        Default = "HumanoidRootPart",
        Callback = function(value) state.AimPart = tostring(value) end,
    })
    aim:AddSlider({
        Name = "Aim FOV",
        Flag = "blox_pvp_aim_fov",
        Min = 30, Max = 600, Step = 10, Default = 180,
        Callback = function(value) state.AimFov = tonumber(value) or 180 end,
    })
    aim:AddSlider({
        Name = "Prediction",
        Flag = "blox_pvp_prediction",
        Min = 0, Max = 0.5, Step = 0.01, Default = 0.12,
        Callback = function(value) state.Prediction = tonumber(value) or 0.12 end,
    })

    track(Players.PlayerAdded:Connect(function()
        task.defer(function()
            if targetDropdown then targetDropdown:SetOptions(playerOptions(), true) end
        end)
    end))
    track(Players.PlayerRemoving:Connect(function(player)
        if state.SelectedPlayer == player.Name then setTarget("None") end
        task.defer(function()
            if targetDropdown then targetDropdown:SetOptions(playerOptions(), true) end
        end)
    end))

    track(RunService.RenderStepped:Connect(function()
        if not state.Alive then return end
        local target = activeTarget()
        if state.Spectating and alive(target) then
            Camera.CameraSubject = humanoid(target)
        end
    end))

    track(RunService.Heartbeat:Connect(function()
        if not state.Alive then return end
        local target = activeTarget()
        if state.AutoBounty and os.clock() - state.TargetStartedAt >= state.TargetTimeout then
            state.SelectedPlayer = "None"
            state.TargetStartedAt = os.clock()
            target = activeTarget()
        end
        local escaping = state.AutoBounty and escapeIfNeeded()
        if target and alive(target) and not escaping then
            if state.FollowTarget or state.AutoBounty then moveNear(target) end
            if state.AutoAttack or state.AutoBounty then attackTarget(target) end
            statusLabel.Text = string.format(
                "PvP: %s | HP %.0f%% | Distance %.0f",
                target.Name,
                healthPercent(target),
                root(LocalPlayer) and root(target) and (root(LocalPlayer).Position - root(target).Position).Magnitude or 0
            )
        elseif escaping then
            statusLabel.Text = "PvP: Escaping until health recovers"
        else
            statusLabel.Text = "PvP: Waiting for a valid target outside safe zone"
        end
        gui:SetAttribute("BloxPvpTarget", target and target.Name or "")
        gui:SetAttribute("BloxPvpAutoBounty", state.AutoBounty)
        gui:SetAttribute("BloxPvpAttacking", (state.AutoAttack or state.AutoBounty) and target ~= nil)
    end))

    gui:SetAttribute("BloxPvpSkillTracking", false)
    track(gui.Destroying:Connect(function()
        state.Alive = false
    end))
    gui:SetAttribute("BloxPvpModule", true)
    gui:SetAttribute("BloxPvpModuleVersion", "4")
end
