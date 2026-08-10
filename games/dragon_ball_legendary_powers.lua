-- VOR Hub - Dragon Ball Legendary Powers owner adapter
-- Universe 4501539222 / place 12860709641.
--
-- The automation layer uses the experience's native, range-validated combat,
-- training, transform, shop, and wish remotes. Privileged player/stat actions
-- are sent only through the optional server-owned VOROwnerAdmin bridge.

return function(context)
    local Window = assert(context.Window, "Dragon Ball Legendary Powers: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Dragon Ball Legendary Powers: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    local Training = ReplicatedStorage:WaitForChild("Training")
    local Combat = ReplicatedStorage:WaitForChild("Combat")
    local TrainRemote = Training:WaitForChild("Train")
    local PunchRemote = Combat:WaitForChild("Punch")
    local DamageRemote = Combat:WaitForChild("Damage")
    local BlastRemote = Combat:WaitForChild("Blast")
    local ChargeRemote = Combat:WaitForChild("Charge")
    local TransformRemote = ReplicatedStorage:WaitForChild("Transform")
    local ShopRemote = ReplicatedStorage:WaitForChild("Shop")
    local WishRemote = ReplicatedStorage:WaitForChild("ShenronWish")

    local OWNER_USER_IDS = {
        [433080653] = true, -- lTomiii / experience creator
        [33876608] = true, -- HEISON12 / owner test account
    }
    local isOwner = OWNER_USER_IDS[LocalPlayer.UserId] == true

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmPage = addHomeCategory("Autofarm", 1, CATEGORY_DECALS.Overnight)
    local TrainingPage = addHomeCategory("Training", 2, CATEGORY_DECALS.Progress)
    local FormsPage = addHomeCategory("Forms & Skills", 3, CATEGORY_DECALS.Combat)
    local TravelPage = addHomeCategory("Travel", 4, CATEGORY_DECALS.Player)
    local AdminPage = addHomeCategory("Owner Admin", 5, CATEGORY_DECALS.Exploits)
    local StatusPage = addHomeCategory("Status", 6, CATEGORY_DECALS.Visuals)
    selectHomeCategory("Autofarm")

    local FarmSection = FarmPage:AddSection("Native NPC Farm", "Left")
    local FarmSafetySection = FarmPage:AddSection("Farm Safety", "Right")
    local FarmStatusSection = FarmPage:AddSection("Farm Status", "Right")
    local StatTrainingSection = TrainingPage:AddSection("Automatic Training", "Left")
    local TrainerSection = TrainingPage:AddSection("Master Trainers", "Right")
    local ShopSection = TrainingPage:AddSection("Shop", "Right")
    local TransformSection = FormsPage:AddSection("Transformations", "Left")
    local SkillSection = FormsPage:AddSection("Learned Skills", "Right")
    local WishSection = FormsPage:AddSection("Shenron Wishes", "Right")
    local TeleportSection = TravelPage:AddSection("Locations", "Left")
    local MovementSection = TravelPage:AddSection("Movement", "Right")
    local AdminTargetSection = AdminPage:AddSection("Player Target", "Left")
    local AdminStatsSection = AdminPage:AddSection("Server Stats", "Left")
    local AdminUtilitySection = AdminPage:AddSection("Server Utilities", "Right")
    local AdminUnlockSection = AdminPage:AddSection("Unlock Flags", "Right")
    local LiveStatsSection = StatusPage:AddSection("Live Stats", "Left")
    local AdapterStatusSection = StatusPage:AddSection("Adapter", "Right")

    local state = {
        Alive = true,
        AutoFarm = false,
        AttackMode = "Punch",
        TargetMode = "Power Ladder",
        SelectedNpc = "Saibaman",
        FarmHeight = 18,
        FarmDistance = 0,
        FarmInterval = 0.48,
        HoldFarmPosition = true,
        HeldRoot = nil,
        AutoCharge = true,
        ChargeBelow = 25,
        ChargeUntil = 90,
        Charging = false,
        AutoTransform = false,
        TransformMode = "Ascend",
        StopLowHealth = true,
        LowHealthPercent = 25,
        RecoveringHealth = false,
        AntiAfk = true,
        NoClip = true,
        WalkSpeedEnabled = false,
        WalkSpeed = 32,
        Target = nil,
        LastAttack = 0,
        LastBlast = 0,
        LastTransform = 0,
        PunchIndex = 0,
        BlastBusy = false,
        Phase = "Idle",
        LastError = "None",
        LastTargetHealth = 0,
        SelectedPlayer = LocalPlayer.Name,
        SelectedStat = "PL",
        StatAmount = 1000,
        SelectedUnlock = "kame",
        AdminBridge = nil,
    }

    local punchKeys = {"q", "e", "r", "t"}
    local statNames = {
        "PL", "phys", "ki", "agi", "def", "physEX", "kiEX",
        "agiEX", "defEX", "ssj", "kaio", "mult", "zeni",
    }
    local unlockNames = {
        "kame", "korin", "kami", "kai", "shenron", "grav", "potara",
        "god", "nova", "highMax", "weightedGi", "isLeg", "hasGodded",
    }
    local teleportTargets = {
        ["City"] = "cityIT",
        ["Kame House"] = "kameIT",
        ["The Lookout"] = "lookoutTP",
        ["King Kai"] = "otherworldPortal",
        ["Wilderness"] = "desertIT",
        ["Namek"] = "namekTP",
        ["Gravity Machine"] = "gravityMachine",
    }

    local function notify(title, message, duration)
        Window:Notify(title, tostring(message), duration or 4)
    end

    local function getCharacter()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
        return character, humanoid, root
    end

    local function getStatsModel(player)
        return (player or LocalPlayer):FindFirstChild("statsModel")
    end

    local function getEnergy()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local statsGui = playerGui and playerGui:FindFirstChild("stats")
        local energy = statsGui and statsGui:FindFirstChild("energy")
        return energy and tonumber(energy.Value) or nil
    end

    local function aliveNpc(model)
        if not model or not model:IsA("Model") then
            return false
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
    end

    local function npcOptions()
        local names = {}
        local seen = {}
        local folder = workspace:FindFirstChild("NPCS")
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if aliveNpc(model) and not seen[model.Name] then
                    seen[model.Name] = true
                    names[#names + 1] = model.Name
                end
            end
        end
        table.sort(names)
        return names
    end

    local function playerOptions()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            names[#names + 1] = player.Name
        end
        table.sort(names)
        return names
    end

    local function npcPower(model)
        local value = model and model:FindFirstChild("Powerlevel")
        return value and tonumber(value.Value) or 0
    end

    local function npcDefense(model)
        local value = model and model:FindFirstChild("Defense")
        return value and tonumber(value.Value) or 0
    end

    local function selectNpc()
        local folder = workspace:FindFirstChild("NPCS")
        local _, _, localRoot = getCharacter()
        if not folder or not localRoot then
            return nil
        end

        local candidates = {}
        local statsModel = getStatsModel()
        local physical = statsModel and statsModel:FindFirstChild("phys")
        local physicalLevel = physical and tonumber(physical.Value) or 1
        local ladderLimit = math.max(2.5, physicalLevel * 1.5)
        for _, model in ipairs(folder:GetChildren()) do
            if aliveNpc(model) then
                if state.TargetMode == "Power Ladder" and npcDefense(model) <= ladderLimit then
                    candidates[#candidates + 1] = model
                elseif state.TargetMode ~= "Selected" and state.TargetMode ~= "Power Ladder" then
                    candidates[#candidates + 1] = model
                elseif state.TargetMode == "Selected" and model.Name == state.SelectedNpc then
                    candidates[#candidates + 1] = model
                end
            end
        end
        if #candidates == 0 and state.TargetMode == "Selected" then
            for _, model in ipairs(folder:GetChildren()) do
                if aliveNpc(model) then
                    candidates[#candidates + 1] = model
                end
            end
        end

        table.sort(candidates, function(a, b)
            if state.TargetMode == "Power Ladder" then
                return npcDefense(a) > npcDefense(b)
            elseif state.TargetMode == "Strongest" then
                return npcPower(a) > npcPower(b)
            end
            local aRoot = a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("Torso")
            local bRoot = b:FindFirstChild("HumanoidRootPart") or b:FindFirstChild("Torso")
            return (localRoot.Position - aRoot.Position).Magnitude < (localRoot.Position - bRoot.Position).Magnitude
        end)
        return candidates[1]
    end

    local function stopCharging()
        if state.Charging then
            pcall(function()
                ChargeRemote:FireServer("Stop")
            end)
        end
        state.Charging = false
    end

    local function updateCharge()
        if not state.AutoCharge then
            stopCharging()
            return false
        end
        local energy = getEnergy()
        if energy == nil then
            return false
        end
        if not state.Charging and energy <= state.ChargeBelow then
            state.Charging = true
            ChargeRemote:FireServer("Start")
        elseif state.Charging and energy >= state.ChargeUntil then
            stopCharging()
        end
        return state.Charging
    end

    local function releaseFarmPosition()
        local heldRoot = state.HeldRoot
        if heldRoot and heldRoot.Parent then
            heldRoot.Anchored = false
        end
        state.HeldRoot = nil
    end

    local function holdRootAt(root, targetCFrame)
        if state.HeldRoot and state.HeldRoot ~= root then
            releaseFarmPosition()
        end
        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if state.HoldFarmPosition then
            root.Anchored = true
            state.HeldRoot = root
        else
            root.Anchored = false
            state.HeldRoot = nil
        end
    end

    local function positionAtNpc(target)
        local _, humanoid, root = getCharacter()
        local targetRoot = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
        if not humanoid or humanoid.Health <= 0 or not root or not targetRoot then
            return false
        end
        holdRootAt(root, targetRoot.CFrame * CFrame.new(0, state.FarmHeight, state.FarmDistance))
        return true
    end

    local function punchTarget(target)
        state.PunchIndex = state.PunchIndex % #punchKeys + 1
        PunchRemote:FireServer("Punch", punchKeys[state.PunchIndex])
        task.wait(0.12)
        if aliveNpc(target) then
            DamageRemote:FireServer("Punch", target)
        end
    end

    local function blastTarget(target)
        if state.BlastBusy or os.clock() - state.LastBlast < 0.7 then
            return
        end
        local targetRoot = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
        if not targetRoot then
            return
        end
        state.BlastBusy = true
        state.LastBlast = os.clock()
        task.spawn(function()
            local ok, errorMessage = pcall(function()
                BlastRemote:InvokeServer("EnergyWave", targetRoot.Position)
            end)
            if not ok then
                state.LastError = tostring(errorMessage)
            end
            state.BlastBusy = false
        end)
    end

    local function attackTarget(target)
        if state.AttackMode == "Energy Wave" then
            blastTarget(target)
        elseif state.AttackMode == "Hybrid" then
            punchTarget(target)
            blastTarget(target)
        else
            punchTarget(target)
        end
    end

    local function shouldPauseForHealth()
        if not state.StopLowHealth then
            state.RecoveringHealth = false
            return false
        end
        local _, humanoid = getCharacter()
        if not humanoid or humanoid.MaxHealth <= 0 then
            state.RecoveringHealth = true
            return true
        end
        local healthPercent = humanoid.Health / humanoid.MaxHealth * 100
        if healthPercent <= state.LowHealthPercent then
            state.RecoveringHealth = true
        elseif state.RecoveringHealth and healthPercent >= 85 then
            state.RecoveringHealth = false
        end
        return state.RecoveringHealth
    end

    local function stepFarm()
        if not state.AutoFarm then
            state.Target = nil
            state.Phase = "Idle"
            stopCharging()
            releaseFarmPosition()
            return
        end
        if shouldPauseForHealth() then
            local _, humanoid, root = getCharacter()
            if humanoid and humanoid.Health > 0 and root then
                if state.Phase ~= "Paused: recovering health" then
                    holdRootAt(root, root.CFrame * CFrame.new(0, 50, 0))
                end
            else
                releaseFarmPosition()
            end
            state.Phase = "Paused: recovering health"
            stopCharging()
            return
        end
        local target = state.Target
        if not aliveNpc(target) then
            target = selectNpc()
            state.Target = target
        end
        if not target then
            state.Phase = "Waiting for NPC"
            releaseFarmPosition()
            return
        end

        if updateCharge() then
            state.Phase = "Charging energy"
            positionAtNpc(target)
            return
        end
        if not positionAtNpc(target) then
            state.Phase = "Waiting for character"
            return
        end
        if os.clock() - state.LastAttack >= state.FarmInterval then
            state.LastAttack = os.clock()
            state.Phase = "Attacking " .. target.Name
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            state.LastTargetHealth = humanoid and humanoid.Health or 0
            attackTarget(target)
        end
    end

    local function stepTransform()
        if not state.AutoTransform or os.clock() - state.LastTransform < 1.1 then
            return
        end
        state.LastTransform = os.clock()
        TransformRemote:FireServer(state.TransformMode)
    end

    local function teleportTo(locationName)
        local trainers = workspace:FindFirstChild("Trainers")
        local targetName = teleportTargets[locationName]
        local target = trainers and targetName and trainers:FindFirstChild(targetName)
        local _, humanoid, root = getCharacter()
        if not target or not root or not humanoid or humanoid.Health <= 0 then
            return false, "Location or character unavailable"
        end
        TrainRemote:FireServer("Reset")
        root.CFrame = target.CFrame * CFrame.new(0, 4, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        return true, "Teleported to " .. locationName
    end

    local function findAdminBridge()
        local remote = ReplicatedStorage:FindFirstChild("VOROwnerAdmin")
        if remote and remote:IsA("RemoteFunction") then
            state.AdminBridge = remote
            return remote
        end
        state.AdminBridge = nil
        return nil
    end

    local function selectedPlayer()
        return Players:FindFirstChild(state.SelectedPlayer) or LocalPlayer
    end

    local function invokeAdmin(operation, payload)
        if not isOwner then
            return false, "This account is not owner-authorized"
        end
        local bridge = findAdminBridge()
        if not bridge then
            return false, "Install the VOROwnerAdmin server bridge in Studio first"
        end
        payload = payload or {}
        payload.Operation = operation
        payload.TargetUserId = selectedPlayer().UserId
        local ok, result = pcall(function()
            return bridge:InvokeServer(payload)
        end)
        if not ok then
            return false, tostring(result)
        end
        if type(result) == "table" then
            return result.Success == true, result.Message or operation
        end
        return result == true, tostring(result)
    end

    local function reportAdmin(operation, payload)
        local ok, message = invokeAdmin(operation, payload)
        notify("Owner Admin", message, ok and 3 or 6)
        return ok
    end

    local targetDropdown
    targetDropdown = FarmSection:AddDropdown({
        Name = "NPC Target",
        Options = npcOptions(),
        Default = state.SelectedNpc,
        Callback = function(value)
            state.SelectedNpc = value or "Saibaman"
            state.Target = nil
        end,
    })
    FarmSection:AddDropdown({
        Name = "Target Mode",
        Options = {"Power Ladder", "Selected", "Nearest", "Strongest"},
        Default = state.TargetMode,
        Callback = function(value)
            state.TargetMode = value or "Selected"
            state.Target = nil
        end,
    })
    FarmSection:AddDropdown({
        Name = "Attack Method",
        Options = {"Punch", "Energy Wave", "Hybrid"},
        Default = state.AttackMode,
        Callback = function(value)
            state.AttackMode = value or "Punch"
        end,
    })
    FarmSection:AddToggle({
        Name = "Auto Farm NPCs",
        Description = "Power Ladder safely trains weak accounts on the strongest NPC they can damage",
        Flag = "dblp_auto_farm",
        Default = false,
        Callback = function(enabled)
            state.AutoFarm = enabled
            if not enabled then
                stopCharging()
                state.Target = nil
                releaseFarmPosition()
            end
        end,
    })
    FarmSection:AddButton({
        Name = "Refresh NPC List",
        Callback = function()
            targetDropdown:SetOptions(npcOptions(), true)
        end,
    })
    FarmSection:AddSlider({
        Name = "Attack Interval",
        Min = 0.2,
        Max = 1.5,
        Step = 0.02,
        Default = state.FarmInterval,
        Flag = "dblp_attack_interval",
        Callback = function(value)
            state.FarmInterval = value
        end,
    })

    FarmSafetySection:AddSlider({
        Name = "Height Above NPC",
        Min = 2,
        Max = 20,
        Step = 0.5,
        Default = state.FarmHeight,
        Flag = "dblp_farm_height",
        Callback = function(value)
            state.FarmHeight = value
        end,
    })
    FarmSafetySection:AddSlider({
        Name = "Distance From NPC",
        Min = 0,
        Max = 10,
        Step = 0.5,
        Default = state.FarmDistance,
        Flag = "dblp_farm_distance",
        Callback = function(value)
            state.FarmDistance = value
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "Hold Safe Aerial Position",
        Description = "Prevents gravity from dropping you into the NPC between hits",
        Default = true,
        Flag = "dblp_hold_farm_position",
        Callback = function(enabled)
            state.HoldFarmPosition = enabled
            if not enabled then
                releaseFarmPosition()
            end
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "Pause On Low Health",
        Default = true,
        Flag = "dblp_pause_low_health",
        Callback = function(enabled)
            state.StopLowHealth = enabled
        end,
    })
    FarmSafetySection:AddSlider({
        Name = "Low Health Percent",
        Min = 5,
        Max = 75,
        Step = 5,
        Default = state.LowHealthPercent,
        Flag = "dblp_low_health_percent",
        Callback = function(value)
            state.LowHealthPercent = value
        end,
    })
    FarmSafetySection:AddToggle({
        Name = "No Collision While Farming",
        Default = true,
        Flag = "dblp_farm_noclip",
        Callback = function(enabled)
            state.NoClip = enabled
        end,
    })

    local farmPhaseLabel = FarmStatusSection:AddLabel("Phase: Idle")
    local farmTargetLabel = FarmStatusSection:AddLabel("Target: None")
    local farmEnergyLabel = FarmStatusSection:AddLabel("Energy: --")
    FarmStatusSection:AddLabel("Verified: native Punch deals server damage only at valid range.")

    StatTrainingSection:AddToggle({
        Name = "Auto Charge Energy",
        Description = "Charges below the low threshold and resumes at the high threshold",
        Default = true,
        Flag = "dblp_auto_charge",
        Callback = function(enabled)
            state.AutoCharge = enabled
            if not enabled then
                stopCharging()
            end
        end,
    })
    StatTrainingSection:AddSlider({
        Name = "Charge Below",
        Min = 0,
        Max = 80,
        Step = 5,
        Default = state.ChargeBelow,
        Flag = "dblp_charge_below",
        Callback = function(value)
            state.ChargeBelow = math.min(value, state.ChargeUntil - 5)
        end,
    })
    StatTrainingSection:AddSlider({
        Name = "Charge Until",
        Min = 20,
        Max = 100,
        Step = 5,
        Default = state.ChargeUntil,
        Flag = "dblp_charge_until",
        Callback = function(value)
            state.ChargeUntil = math.max(value, state.ChargeBelow + 5)
        end,
    })
    StatTrainingSection:AddParagraph({
        Title = "Training behavior",
        Content = "Punch farming trains Physical and Defense. Energy Wave trains Ki Control. Movement during the route contributes Agility according to the game's own trainer instructions.",
    })

    local trainerActions = {
        ["Train With Master Roshi"] = "Roshi",
        ["Train With Korin"] = "Korin",
        ["Train With Kami"] = "Kami",
        ["Train With King Kai"] = "King Kai",
    }
    for buttonName, action in pairs(trainerActions) do
        TrainerSection:AddButton({
            Name = buttonName,
            Callback = function()
                TrainRemote:FireServer(action)
            end,
        })
    end

    local shopActions = {
        ["Buy Training Weight"] = "weight",
        ["Buy Weighted Clothing"] = "gi",
        ["Buy Stat Capsule"] = "stats",
        ["Buy Potara Earrings"] = "potara",
    }
    for buttonName, action in pairs(shopActions) do
        ShopSection:AddButton({
            Name = buttonName,
            Callback = function()
                ShopRemote:FireServer(action)
            end,
        })
    end

    TransformSection:AddDropdown({
        Name = "Automatic Form",
        Options = {"Ascend", "Kaioken"},
        Default = state.TransformMode,
        Callback = function(value)
            state.TransformMode = value or "Ascend"
        end,
    })
    TransformSection:AddToggle({
        Name = "Maintain Automatic Form",
        Default = false,
        Flag = "dblp_auto_transform",
        Callback = function(enabled)
            state.AutoTransform = enabled
        end,
    })
    TransformSection:AddButton({Name = "Ascend", Callback = function() TransformRemote:FireServer("Ascend") end})
    TransformSection:AddButton({Name = "Descend", Callback = function() TransformRemote:FireServer("Descend") end})
    TransformSection:AddButton({Name = "Kaioken", Callback = function() TransformRemote:FireServer("Kaioken") end})
    for _, potaraName in ipairs({"potara", "potaraG", "potaraV"}) do
        TransformSection:AddButton({
            Name = "Use " .. potaraName,
            Callback = function()
                TransformRemote:FireServer("potara", potaraName)
            end,
        })
    end

    local skillActions = {
        ["Equip Korin Moves"] = "getKorin",
        ["Equip Roshi Moves"] = "getRoshi",
        ["Equip Kami Moves"] = "getKami",
        ["Equip King Kai Moves"] = "getKai",
        ["Equip Shenron Moves"] = "getShenron",
    }
    for buttonName, action in pairs(skillActions) do
        SkillSection:AddButton({
            Name = buttonName,
            Callback = function()
                TrainRemote:FireServer(action)
            end,
        })
    end

    for _, wishName in ipairs({"Power", "Zeni", "Food", "Senzu"}) do
        WishSection:AddButton({
            Name = "Wish For " .. wishName,
            Callback = function()
                WishRemote:FireServer(wishName)
            end,
        })
    end

    for locationName in pairs(teleportTargets) do
        TeleportSection:AddButton({
            Name = locationName,
            Callback = function()
                local ok, message = teleportTo(locationName)
                notify("Travel", message, ok and 3 or 5)
            end,
        })
    end

    MovementSection:AddToggle({
        Name = "Walk Speed Override",
        Default = false,
        Flag = "dblp_walk_speed_enabled",
        Callback = function(enabled)
            state.WalkSpeedEnabled = enabled
        end,
    })
    MovementSection:AddSlider({
        Name = "Walk Speed",
        Min = 16,
        Max = 150,
        Step = 2,
        Default = state.WalkSpeed,
        Flag = "dblp_walk_speed",
        Callback = function(value)
            state.WalkSpeed = value
        end,
    })
    MovementSection:AddToggle({
        Name = "Anti AFK",
        Default = true,
        Flag = "dblp_anti_afk",
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })

    local adminAccessLabel = AdminTargetSection:AddLabel(isOwner and "Owner account verified" or "Access denied: owner accounts only")
    local adminBridgeLabel = AdminTargetSection:AddLabel(findAdminBridge() and "Server bridge: Ready" or "Server bridge: Not installed")
    local playerDropdown
    playerDropdown = AdminTargetSection:AddDropdown({
        Name = "Target Player",
        Options = playerOptions(),
        Default = state.SelectedPlayer,
        Persist = false,
        Callback = function(value)
            state.SelectedPlayer = value or LocalPlayer.Name
        end,
    })
    AdminTargetSection:AddButton({
        Name = "Refresh Players / Bridge",
        Callback = function()
            playerDropdown:SetOptions(playerOptions(), true)
            adminBridgeLabel.Text = findAdminBridge() and "Server bridge: Ready" or "Server bridge: Not installed"
        end,
    })

    AdminStatsSection:AddDropdown({
        Name = "Stat",
        Options = statNames,
        Default = state.SelectedStat,
        Callback = function(value)
            state.SelectedStat = value or "PL"
        end,
    })
    local statAmountInput = AdminStatsSection:AddInput({
        Name = "Amount",
        Placeholder = "1000",
        Default = tostring(state.StatAmount),
        Persist = false,
        Callback = function(value)
            state.StatAmount = tonumber(value) or state.StatAmount
        end,
    })
    AdminStatsSection:AddButton({
        Name = "Set Stat",
        Callback = function()
            state.StatAmount = tonumber(statAmountInput:Get()) or state.StatAmount
            reportAdmin("SetStat", {Stat = state.SelectedStat, Value = state.StatAmount})
        end,
    })
    AdminStatsSection:AddButton({
        Name = "Add To Stat",
        Callback = function()
            state.StatAmount = tonumber(statAmountInput:Get()) or state.StatAmount
            reportAdmin("AddStat", {Stat = state.SelectedStat, Value = math.abs(state.StatAmount)})
        end,
    })
    AdminStatsSection:AddButton({
        Name = "Subtract From Stat",
        Callback = function()
            state.StatAmount = tonumber(statAmountInput:Get()) or state.StatAmount
            reportAdmin("AddStat", {Stat = state.SelectedStat, Value = -math.abs(state.StatAmount)})
        end,
    })

    AdminUtilitySection:AddButton({Name = "Heal Player", Callback = function() reportAdmin("Heal") end})
    AdminUtilitySection:AddButton({Name = "Refill Energy", Callback = function() reportAdmin("RefillEnergy") end})
    AdminUtilitySection:AddButton({Name = "Bring Player", Callback = function() reportAdmin("Bring") end})
    AdminUtilitySection:AddButton({Name = "Go To Player", Callback = function() reportAdmin("Goto") end})
    AdminUtilitySection:AddButton({Name = "Freeze Player", Callback = function() reportAdmin("Freeze") end})
    AdminUtilitySection:AddButton({Name = "Unfreeze Player", Callback = function() reportAdmin("Unfreeze") end})
    local kickReasonInput = AdminUtilitySection:AddInput({
        Name = "Kick Reason",
        Placeholder = "Removed by the owner",
        Default = "Removed by the owner",
        Persist = false,
    })
    AdminUtilitySection:AddButton({
        Name = "Kick Player",
        Callback = function()
            reportAdmin("Kick", {Reason = kickReasonInput:Get()})
        end,
    })

    AdminUnlockSection:AddDropdown({
        Name = "Unlock Flag",
        Options = unlockNames,
        Default = state.SelectedUnlock,
        Callback = function(value)
            state.SelectedUnlock = value or "kame"
        end,
    })
    AdminUnlockSection:AddButton({
        Name = "Enable Unlock",
        Callback = function()
            reportAdmin("SetUnlock", {Unlock = state.SelectedUnlock, Value = true})
        end,
    })
    AdminUnlockSection:AddButton({
        Name = "Disable Unlock",
        Callback = function()
            reportAdmin("SetUnlock", {Unlock = state.SelectedUnlock, Value = false})
        end,
    })
    AdminUnlockSection:AddButton({Name = "Enable All Safe Unlocks", Callback = function() reportAdmin("UnlockAll") end})

    local statLabels = {}
    for _, statName in ipairs({"PL", "phys", "ki", "agi", "def", "zeni", "ssj", "kaio"}) do
        statLabels[statName] = LiveStatsSection:AddLabel(statName .. ": --")
    end
    local ownerLabel = AdapterStatusSection:AddLabel("Owner gate: " .. (isOwner and "Authorized" or "Denied"))
    local bridgeStatusLabel = AdapterStatusSection:AddLabel("Admin bridge: " .. (findAdminBridge() and "Ready" or "Missing"))
    local errorLabel = AdapterStatusSection:AddLabel("Last error: None")
    AdapterStatusSection:AddParagraph({
        Title = "Server security",
        Content = "Automation uses native game remotes. Stat and moderation controls require the separate server bridge, which validates the caller by numeric UserId on every request.",
    })

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end
    end))

    track(RunService.Stepped:Connect(function()
        local character, humanoid = getCharacter()
        if character and state.AutoFarm and state.NoClip then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        if humanoid and state.WalkSpeedEnabled then
            humanoid.WalkSpeed = state.WalkSpeed
        end
    end))

    task.spawn(function()
        while state.Alive do
            local ok, errorMessage = pcall(function()
                stepFarm()
                stepTransform()
            end)
            if not ok then
                state.LastError = tostring(errorMessage)
            end
            task.wait(0.05)
        end
    end)

    task.spawn(function()
        while state.Alive do
            local statsModel = getStatsModel()
            for statName, label in pairs(statLabels) do
                local value = statsModel and statsModel:FindFirstChild(statName)
                label.Text = statName .. ": " .. (value and tostring(value.Value) or "--")
            end
            farmPhaseLabel.Text = "Phase: " .. state.Phase
            farmTargetLabel.Text = "Target: " .. (state.Target and state.Target.Name or "None")
                .. (state.LastTargetHealth > 0 and " | HP " .. math.floor(state.LastTargetHealth) or "")
            farmEnergyLabel.Text = "Energy: " .. tostring(getEnergy() or "--")
            adminAccessLabel.Text = isOwner and "Owner account verified" or "Access denied: owner accounts only"
            ownerLabel.Text = "Owner gate: " .. (isOwner and "Authorized" or "Denied")
            bridgeStatusLabel.Text = "Admin bridge: " .. (findAdminBridge() and "Ready" or "Missing")
            errorLabel.Text = "Last error: " .. state.LastError
            task.wait(0.5)
        end
    end)

    track(Players.PlayerAdded:Connect(function()
        playerDropdown:SetOptions(playerOptions(), true)
    end))
    track(Players.PlayerRemoving:Connect(function(player)
        if state.SelectedPlayer == player.Name then
            state.SelectedPlayer = LocalPlayer.Name
        end
        playerDropdown:SetOptions(playerOptions(), true)
    end))

    if gui and gui.Destroying then
        track(gui.Destroying:Connect(function()
            state.Alive = false
            state.AutoFarm = false
            stopCharging()
            releaseFarmPosition()
        end))
    end

    Window:SetContextStatus("Dragon Ball Legendary Powers | owner automation ready")
    return {
        State = state,
        IsOwner = isOwner,
        RefreshAdminBridge = findAdminBridge,
    }
end
