-- VOR Hub - Blox Fruits Dungeons
-- Dedicated adapter for PlaceId 73902483975735. This place deliberately gets
-- only two visible pages: Dungeons and Player. Combat is server-credited Sword
-- M1 + Fruit M1; player characters and player-name clones are never targets.

return function(context)
    local Window = assert(context.Window, "Blox Fruits Dungeons: Window is required")
    local COLORS = assert(context.Colors, "Blox Fruits Dungeons: colors are required")
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    local DungeonPage = Window:AddPage("Dungeons")
    local PlayerPage = Window:AddPage("Player")

    local AutomationSection = DungeonPage:AddSection("Dungeon Automation", "Left")
    local PositionSection = DungeonPage:AddSection("Farm Position", "Left")
    local QueueSection = DungeonPage:AddSection("Queue Settings", "Right")
    local TrinketSection = DungeonPage:AddSection("Trinkets", "Right")
    local PrioritySection = DungeonPage:AddSection("Card Priority", "Left")
    local StatusSection = DungeonPage:AddSection("Live Dungeon Status", "Right")

    local AuraSection = PlayerPage:AddSection("Aura & Movement", "Left")
    local VisionSection = PlayerPage:AddSection("Player Vision", "Right")
    local SessionSection = PlayerPage:AddSection("Session", "Right")

    local state = {
        Alive = true,
        AutoJoin = false,
        AutoStart = false,
        AutoLeave = false,
        AutoFarm = false,
        AutoSelectCards = false,
        Difficulty = "Normal",
        MinimumPlayers = 1,
        TweenSpeed = 315,
        RandomPosition = true,
        PositionX = 1,
        PositionY = 1,
        PositionZ = 1,
        RandomRange = 10,
        AutoMagnet = true,
        MagnetRange = 500,
        AutoBuso = true,
        AntiAfk = true,
        ManualNoclip = false,
        PlayerESP = false,
        Status = "Initializing dungeon adapter...",
        LastError = nil,
        CurrentTarget = nil,
        CurrentTargetName = "None",
        CurrentTargetDistance = nil,
        CurrentPad = nil,
        InRun = false,
        WasInRun = false,
        RunFinished = false,
        LastQueueAction = 0,
        LastDifficultyRequest = 0,
        LastStartRequest = 0,
        LastBusoRequest = 0,
        LastTargetScan = 0,
        LastMagnet = 0,
        LastSimulationRadius = 0,
        LastSwordAttack = 0,
        LastFruitAttack = 0,
        SwordBusy = false,
        FruitBusy = false,
        SwordRequests = 0,
        FruitRequests = 0,
        MultiHitCount = 0,
        GatheredCount = 0,
        PositionIndex = 3,
        NextPositionChange = 0,
        MovementActive = false,
        OriginalCollision = {},
        OriginalEnemyCollision = {},
        OriginalAutoRotate = nil,
        RegisterHitClosure = nil,
        LastRegisterHitResolve = 0,
        SwordCombos = {},
        FruitCombos = {},
        Priority = {},
        CardRemote = nil,
        CardOriginalCallback = nil,
        CardCallback = nil,
        CardHooked = false,
        LastCardOffers = "Waiting for cards",
        LastCardChoice = "None",
        LastGuiCardClickAt = 0,
        ResultsRemote = nil,
        BuffRemote = nil,
        CurrentBuffCount = 0,
        PlayerEspObjects = {},
        PlayerEspLastTextUpdate = 0,
    }

    local statusLabel = StatusSection:AddLabel("Status: Initializing...")
    local runLabel = StatusSection:AddLabel("Run: Reading dungeon state...")
    local targetLabel = StatusSection:AddLabel("Target: None")
    local attackLabel = StatusSection:AddLabel("Attacks: Sword 0 | Fruit 0 | Multi 0")
    local cardLabel = StatusSection:AddLabel("Cards: Waiting for offers")
    local buffLabel = StatusSection:AddLabel("Buffs: Reading...")
    local queueLabel = QueueSection:AddLabel("Queue: Looking for Simulation pads...")
    local trinketDataLabel = TrinketSection:AddLabel("Simulation Data: Reading...")
    local trinketStatusLabel = TrinketSection:AddLabel("Trinket: Ready")
    local busoLabel = AuraSection:AddLabel("Aura Ability: Reading...")
    local espStatusLabel = VisionSection:AddLabel("ESP: Off")

    local function setStatus(message, success)
        state.Status = tostring(message or "")
        statusLabel.Text = "Status: " .. state.Status
        statusLabel.TextColor3 = success == false
            and COLORS.error
            or (success == true and COLORS.success or COLORS.muted)
    end

    local function setError(message)
        state.LastError = tostring(message or "Unknown error")
        setStatus(state.LastError, false)
    end

    local function character()
        return LocalPlayer.Character
    end

    local function humanoid(model)
        model = model or character()
        return model and model:FindFirstChildOfClass("Humanoid")
    end

    local function modelRoot(model)
        if not model or not model.Parent then
            return nil
        end
        return model.PrimaryPart
            or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChildWhichIsA("BasePart")
    end

    local function rootPart()
        return modelRoot(character())
    end

    local function modelAlive(model)
        local body = humanoid(model)
        return body ~= nil and body.Health > 0
    end

    local function safeRequire(instance)
        if not instance then
            return nil
        end
        local ok, result = pcall(require, instance)
        return ok and result or nil
    end

    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local Net = Modules and Modules:FindFirstChild("Net")
    local RegisterAttackEvent = Net and Net:FindFirstChild("RE/RegisterAttack")
    local CombatUtil = safeRequire(Modules and Modules:FindFirstChild("CombatUtil"))
    local FruitMouse = safeRequire(ReplicatedStorage:FindFirstChild("Mouse"))

    local function normalizeName(value)
        local name = tostring(value or "")
        name = name:gsub("%s*%[Lv[^%]]*%]", "")
        name = name:gsub("%s*%[Boss%]", "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        return string.lower(name)
    end

    local function isPlayerCharacterOrClone(model)
        local candidate = normalizeName(model and model.Name)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == model then
                return true
            end
            if candidate ~= "" and (candidate == normalizeName(player.Name)
                or candidate == normalizeName(player.DisplayName)) then
                return true
            end
        end
        return false
    end

    local HIT_PART_NAMES = {
        "ModelHitbox",
        "HumanoidRootPart",
        "UpperTorso",
        "LowerTorso",
        "Torso",
        "Head",
    }

    local function enemyHitPart(enemy)
        if not enemy then
            return nil
        end
        for _, partName in ipairs(HIT_PART_NAMES) do
            local part = enemy:FindFirstChild(partName, true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
        return modelRoot(enemy)
    end

    local function validEnemy(model)
        return model ~= nil
            and model:IsA("Model")
            and model.Parent ~= nil
            and modelAlive(model)
            and modelRoot(model) ~= nil
            and enemyHitPart(model) ~= nil
            and not isPlayerCharacterOrClone(model)
    end

    local function livingEnemies(origin)
        local enemiesFolder = workspace:FindFirstChild("Enemies")
        local enemies = {}
        if not enemiesFolder then
            return enemies
        end
        origin = origin or (rootPart() and rootPart().Position)
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if validEnemy(enemy) then
                local enemyRoot = modelRoot(enemy)
                table.insert(enemies, {
                    Enemy = enemy,
                    Root = enemyRoot,
                    HitPart = enemyHitPart(enemy),
                    Distance = origin and (enemyRoot.Position - origin).Magnitude or 0,
                })
            end
        end
        table.sort(enemies, function(left, right)
            return left.Distance < right.Distance
        end)
        return enemies
    end

    local function currentDungeonReplication()
        local objects = ReplicatedStorage:FindFirstChild("DungeonReplicationObjects")
        if not objects then
            return nil
        end

        local explorerGuid = LocalPlayer:GetAttribute("ExplorerGUID")
        if explorerGuid ~= nil then
            local direct = objects:FindFirstChild(tostring(explorerGuid))
            if direct then
                return direct
            end
        end

        for _, dungeon in ipairs(objects:GetChildren()) do
            local explorers = dungeon:FindFirstChild("Explorers")
            if explorers then
                for _, explorer in ipairs(explorers:GetChildren()) do
                    if tostring(explorer:GetAttribute("PlayerName") or "") == LocalPlayer.Name then
                        return dungeon
                    end
                end
            end
        end
        return nil
    end

    local function dungeonRunActive()
        return currentDungeonReplication() ~= nil
    end

    local function setCharacterNoclip(enabled)
        local char = character()
        if enabled and char then
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if state.OriginalCollision[descendant] == nil then
                        state.OriginalCollision[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
            local body = humanoid(char)
            if body then
                if state.OriginalAutoRotate == nil then
                    state.OriginalAutoRotate = body.AutoRotate
                end
                body.AutoRotate = false
                body.Sit = false
            end
            return
        end

        for part, original in pairs(state.OriginalCollision) do
            if part and part.Parent then
                part.CanCollide = original
            end
        end
        table.clear(state.OriginalCollision)
        local body = humanoid(char)
        if body and state.OriginalAutoRotate ~= nil then
            body.AutoRotate = state.OriginalAutoRotate
        end
        state.OriginalAutoRotate = nil
    end

    local function stepRootToward(goalCFrame, speed, deltaTime)
        local root = rootPart()
        if not root then
            return false, math.huge
        end
        local delta = goalCFrame.Position - root.Position
        local distance = delta.Magnitude
        local step = math.max(tonumber(speed) or 315, 1) * math.max(deltaTime, 1 / 240)
        local position = distance <= step and goalCFrame.Position or (root.Position + delta.Unit * step)
        local lookAt = goalCFrame.Position + goalCFrame.LookVector
        if (lookAt - position).Magnitude < 0.01 then
            lookAt = position + root.CFrame.LookVector
        end
        root.CFrame = CFrame.lookAt(position, lookAt)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return distance <= math.max(step, 1.5), distance
    end

    local function busoActive()
        local char = character()
        if not char then
            return false
        end
        local attribute = char:GetAttribute("BusoEnabled")
        if attribute ~= nil then
            return attribute == true
        end
        return char:FindFirstChild("HasBuso") ~= nil
    end

    local function sendBusoInput()
        local serviceOk, inputManager = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if serviceOk and inputManager then
            local sent = pcall(function()
                inputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
                inputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
            end)
            if sent then
                return true, "J key"
            end
        end
        if type(keypress) == "function" and type(keyrelease) == "function" then
            local sent = pcall(function()
                keypress(0x4A)
                keyrelease(0x4A)
            end)
            if sent then
                return true, "executor J"
            end
        end
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local commF = remotes and remotes:FindFirstChild("CommF_")
        if commF and commF:IsA("RemoteFunction") then
            local sent = pcall(function()
                commF:InvokeServer("Buso")
            end)
            if sent then
                return true, "legacy Buso request"
            end
        end
        return false, "no supported Aura input method"
    end

    local function ensureBuso()
        if busoActive() then
            return true
        end
        if not state.AutoBuso and not state.AutoFarm then
            return false
        end
        local now = os.clock()
        if now - state.LastBusoRequest < 1.25 then
            return false
        end
        state.LastBusoRequest = now
        local ok, method = sendBusoInput()
        if ok then
            busoLabel.Text = "Aura Ability: Activation requested via " .. method
        else
            busoLabel.Text = "Aura Ability: Activation failed"
            state.LastError = "Auto Aura failed: " .. tostring(method)
        end
        return false
    end

    local function weaponNameForTool(tool)
        if not tool then
            return nil
        end
        if type(CombatUtil) == "table" and type(CombatUtil.GetWeaponName) == "function" then
            local ok, name = pcall(function()
                return CombatUtil:GetWeaponName(tool)
            end)
            if ok and name then
                return tostring(name)
            end
        end
        return tostring(tool:GetAttribute("WeaponName") or tool.Name)
    end

    local function weaponDataForTool(tool)
        if not tool or type(CombatUtil) ~= "table" or type(CombatUtil.GetWeaponData) ~= "function" then
            return nil
        end
        local name = weaponNameForTool(tool)
        local ok, data = pcall(function()
            return CombatUtil:GetWeaponData(name)
        end)
        return ok and type(data) == "table" and data or nil
    end

    local function weaponTypeForTool(tool, weaponData)
        return tostring(
            (weaponData and weaponData.WeaponType)
                or (tool and tool:GetAttribute("WeaponType"))
                or (tool and tool.ToolTip)
                or ""
        )
    end

    local function findTool(wanted)
        local char = character()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local wantedLower = string.lower(wanted)
        for _, container in ipairs({char, backpack}) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        local data = weaponDataForTool(tool)
                        local weaponType = string.lower(weaponTypeForTool(tool, data))
                        local tooltip = string.lower(tostring(tool.ToolTip or ""))
                        if wantedLower == "sword" and (weaponType == "sword" or tooltip == "sword") then
                            return tool, data
                        end
                        if wantedLower == "fruit" and (
                            weaponType:find("fruit", 1, true)
                            or tooltip:find("fruit", 1, true)
                            or tool:FindFirstChild("LeftClickRemote", true)
                        ) then
                            return tool, data
                        end
                    end
                end
            end
        end
        return nil, nil
    end

    local function equipSword(tool)
        local char = character()
        local body = humanoid(char)
        if not tool or not char or not body then
            return false
        end
        if tool.Parent ~= char then
            pcall(function()
                body:EquipTool(tool)
            end)
        end
        return tool.Parent == char
    end

    local function resolveRegisterHitClosure()
        if type(state.RegisterHitClosure) == "function" then
            return state.RegisterHitClosure
        end
        if os.clock() - state.LastRegisterHitResolve < 3 then
            return nil
        end
        state.LastRegisterHitResolve = os.clock()
        if type(CombatUtil) ~= "table"
            or type(CombatUtil.RunHitDetection) ~= "function"
            or type(debug) ~= "table"
            or type(debug.getupvalue) ~= "function" then
            return nil
        end

        local currentBuildFallback = nil
        for index = 1, 16 do
            local ok, first, second = pcall(debug.getupvalue, CombatUtil.RunHitDetection, index)
            if not ok then
                break
            end
            local value = type(second) == "function" and second or first
            if type(value) == "function" then
                if index == 5 then
                    currentBuildFallback = value
                end
                local name = ""
                if type(debug.info) == "function" then
                    pcall(function()
                        name = debug.info(value, "n")
                    end)
                end
                if name == "registerHit" then
                    state.RegisterHitClosure = value
                    return value
                end
            end
        end
        state.RegisterHitClosure = currentBuildFallback
        return currentBuildFallback
    end

    local function swordAttackProfile(tool, weaponData)
        local moveset = type(weaponData) == "table" and weaponData.Moveset or nil
        local basics = type(moveset) == "table" and moveset.Basic or nil
        if type(basics) ~= "table" or #basics == 0 then
            return nil, "Sword M1 moveset was not found"
        end

        local weaponName = weaponNameForTool(tool)
        local comboKey = string.lower(tostring(weaponName or tool.Name))
        local combo = ((state.SwordCombos[comboKey] or 0) % #basics) + 1
        local duration = nil
        if type(CombatUtil) == "table"
            and type(CombatUtil.GetMovesetAnimCache) == "function"
            and type(CombatUtil.GetPureWeaponName) == "function" then
            pcall(function()
                local pureName = CombatUtil:GetPureWeaponName(weaponName)
                local cache = CombatUtil:GetMovesetAnimCache(humanoid())
                local animationTrack = cache and cache[pureName .. "-basic" .. combo]
                if animationTrack then
                    local speedMultiplier = math.max(tonumber(animationTrack:GetAttribute("SpeedMult")) or 1, 0.01)
                    duration = tonumber(animationTrack.Length) / speedMultiplier
                end
            end)
        end

        -- Solix uses a non-finite duration when an animation track is not
        -- available in Dungeons. Prefer the real duration; retain that exact
        -- compatibility fallback instead of sending zero, which is rejected.
        if not duration or duration <= 0 then
            duration = 0 / 0
        end
        return {
            Combo = combo,
            ComboKey = comboKey,
            Duration = duration,
        }
    end

    local function nearbyAttackTargets(maximum)
        local root = rootPart()
        local targets = {}
        if not root then
            return targets
        end
        for _, candidate in ipairs(livingEnemies(root.Position)) do
            if candidate.Distance <= 38 then
                table.insert(targets, candidate)
                if #targets >= maximum then
                    break
                end
            end
        end
        return targets
    end

    local function sendSwordAttack()
        local sword, weaponData = findTool("Sword")
        if not sword then
            return false, "No Sword Tool was found"
        end
        if not equipSword(sword) then
            return false, "The Sword could not be equipped"
        end
        weaponData = weaponData or weaponDataForTool(sword)
        if not weaponData then
            return false, "Sword combat data is unavailable"
        end

        local profile, profileError = swordAttackProfile(sword, weaponData)
        local registerHit = resolveRegisterHitClosure()
        if not profile then
            return false, profileError
        end
        if not RegisterAttackEvent or type(registerHit) ~= "function" then
            return false, "Dungeon combat registration is unavailable"
        end

        local initialTargets = nearbyAttackTargets(12)
        if #initialTargets == 0 then
            return false, "No enemy is inside Sword Aura range"
        end
        RegisterAttackEvent:FireServer(profile.Duration)
        task.wait(0.13)
        if not state.Alive or not state.AutoFarm then
            return false, "Farm stopped before the hit window"
        end

        local targets = nearbyAttackTargets(12)
        if #targets == 0 then
            return false, "Enemies left Sword Aura range"
        end
        local primary = targets[1]
        local extraHits = {}
        for index = 2, #targets do
            local hit = targets[index]
            table.insert(extraHits, {hit.Enemy, hit.HitPart})
        end
        registerHit(character(), primary.Enemy, primary.HitPart, weaponData, extraHits)
        registerHit(true)
        state.SwordCombos[profile.ComboKey] = profile.Combo
        state.SwordRequests += 1
        state.MultiHitCount = #targets
        return true
    end

    local function stopActionAnimations()
        if not state.AutoFarm then
            return
        end
        local body = humanoid()
        local animator = body and body:FindFirstChildOfClass("Animator")
        if not animator then
            return
        end
        pcall(function()
            for _, animationTrack in ipairs(animator:GetPlayingAnimationTracks()) do
                if animationTrack.Priority.Value >= Enum.AnimationPriority.Action.Value then
                    animationTrack:Stop(0)
                end
            end
        end)
    end

    local function sendFruitAttack()
        local fruit = findTool("Fruit")
        local root = rootPart()
        local targets = nearbyAttackTargets(3)
        if not fruit then
            return false, "No Blox Fruit Tool was found"
        end
        if not root or #targets == 0 then
            return false, "No enemy is inside Fruit M1 range"
        end

        local silentRemote = fruit:FindFirstChild("LeftClickRemote", true)
        silentRemote = silentRemote and silentRemote:IsA("RemoteEvent") and silentRemote or nil
        if silentRemote then
            local comboKey = string.lower(fruit.Name)
            local combo = ((state.FruitCombos[comboKey] or 0) % 5) + 1
            local sent = 0
            for _, target in ipairs(targets) do
                local direction = (target.Root.Position - root.Position) * Vector3.new(1, 0, 1)
                if direction.Magnitude < 0.05 then
                    direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                end
                if direction.Magnitude >= 0.05 then
                    silentRemote:FireServer(direction.Unit, combo)
                    sent += 1
                end
            end
            state.FruitCombos[comboKey] = combo
            state.FruitRequests += sent
            return sent > 0
        end

        if type(FruitMouse) ~= "table" then
            return false, "This Fruit has no silent M1 remote or native mouse controller"
        end
        local target = targets[1]
        local char = character()
        local originalParent = fruit.Parent
        if fruit.Parent ~= char then
            fruit.Parent = char
            task.wait()
        end
        local oldHit = FruitMouse.Hit
        local oldTarget = FruitMouse.Target
        FruitMouse.Hit = CFrame.new(target.HitPart.Position)
        FruitMouse.Target = target.HitPart
        local activated, activationError = pcall(function()
            fruit:Activate()
            fruit:Deactivate()
        end)
        FruitMouse.Hit = oldHit
        FruitMouse.Target = oldTarget
        if originalParent and fruit.Parent ~= originalParent then
            fruit.Parent = originalParent
        end
        local sword = findTool("Sword")
        if sword then
            equipSword(sword)
        end
        stopActionAnimations()
        if not activated then
            return false, activationError
        end
        state.FruitRequests += 1
        return true
    end

    local function chooseTarget()
        local root = rootPart()
        if not root then
            state.CurrentTarget = nil
            return nil
        end
        if validEnemy(state.CurrentTarget) then
            local currentRoot = modelRoot(state.CurrentTarget)
            if currentRoot and (currentRoot.Position - root.Position).Magnitude <= math.max(state.MagnetRange, 650) then
                return state.CurrentTarget
            end
        end
        local enemies = livingEnemies(root.Position)
        state.CurrentTarget = enemies[1] and enemies[1].Enemy or nil
        state.PositionIndex = 3
        state.NextPositionChange = 0
        return state.CurrentTarget
    end

    local function desiredFarmCFrame(target)
        local targetRoot = modelRoot(target)
        local root = rootPart()
        if not targetRoot or not root then
            return nil
        end
        local range = math.max(tonumber(state.RandomRange) or 10, 1)
        local x = range * (tonumber(state.PositionX) or 1)
        local y = range * (tonumber(state.PositionY) or 1)
        local z = range * (tonumber(state.PositionZ) or 1)
        local targetDistance = (targetRoot.Position - root.Position).Magnitude

        if state.RandomPosition and targetDistance <= math.max(35, range * 2.5) then
            if os.clock() >= state.NextPositionChange then
                local nextIndex = math.random(1, 4)
                if nextIndex == state.PositionIndex then
                    nextIndex = (nextIndex % 4) + 1
                end
                state.PositionIndex = nextIndex
                state.NextPositionChange = os.clock() + 0.15
            end
        else
            -- Keep one stable approach lane. Randomizing while hundreds of
            -- studs away is the zigzag garbage the old farm was doing.
            state.PositionIndex = 3
        end

        local offsets = {
            Vector3.new(x, y, 0),
            Vector3.new(-x, y, 0),
            Vector3.new(0, y, z),
            Vector3.new(0, y, -z),
        }
        local offset = state.RandomPosition
            and offsets[state.PositionIndex]
            or Vector3.new(x, y, z)
        local position = targetRoot.Position + offset
        return CFrame.lookAt(position, targetRoot.Position)
    end

    local function restoreEnemyCollision()
        for part, original in pairs(state.OriginalEnemyCollision) do
            if part and part.Parent then
                part.CanCollide = original
            end
        end
        table.clear(state.OriginalEnemyCollision)
        state.GatheredCount = 0
    end

    local function applyDungeonMagnet()
        if not state.AutoFarm or not state.AutoMagnet or not validEnemy(state.CurrentTarget) then
            restoreEnemyCollision()
            return
        end
        local now = os.clock()
        if now - state.LastMagnet < 0.075 then
            return
        end
        state.LastMagnet = now
        if now - state.LastSimulationRadius >= 1 then
            state.LastSimulationRadius = now
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                end
            end)
        end

        local anchorRoot = modelRoot(state.CurrentTarget)
        if not anchorRoot then
            return
        end
        local gathered = 0
        for _, candidate in ipairs(livingEnemies(anchorRoot.Position)) do
            if candidate.Distance <= state.MagnetRange then
                local owned = true
                if type(isnetworkowner) == "function" then
                    local checked, result = pcall(isnetworkowner, candidate.Root)
                    owned = checked and result == true
                end
                if owned then
                    if state.OriginalEnemyCollision[candidate.Root] == nil then
                        state.OriginalEnemyCollision[candidate.Root] = candidate.Root.CanCollide
                    end
                    candidate.Root.CanCollide = false
                    candidate.Root.CFrame = anchorRoot.CFrame
                    candidate.Root.AssemblyLinearVelocity = Vector3.zero
                    candidate.Root.AssemblyAngularVelocity = Vector3.zero
                    gathered += 1
                end
            end
        end
        state.GatheredCount = gathered
    end

    local function dungeonPads()
        local pads = {}
        local map = workspace:FindFirstChild("Map")
        if not map then
            return pads
        end
        local seen = {}
        for _, descendant in ipairs(map:GetDescendants()) do
            if descendant.Name:match("^DUNGEON_TELEPORTER%d+$") then
                local remote = descendant:FindFirstChild("DungeonSettingsChanged")
                local padPart = descendant:FindFirstChild("Pad")
                if remote and padPart and padPart:IsA("BasePart") and not seen[descendant] then
                    seen[descendant] = true
                    table.insert(pads, {
                        Object = descendant,
                        Part = padPart,
                        Remote = remote,
                        Count = tonumber(descendant:GetAttribute("NumPlayersOnPad")) or 0,
                        Maximum = tonumber(descendant:GetAttribute("MaxPlayers")) or 4,
                    })
                end
            end
        end
        table.sort(pads, function(left, right)
            if left.Count == right.Count then
                return left.Object.Name < right.Object.Name
            end
            return left.Count < right.Count
        end)
        return pads
    end

    local function referencedPad()
        local reference = LocalPlayer:FindFirstChild("TeleporterPadObjectReference")
        local value = reference and reference:IsA("ObjectValue") and reference.Value or nil
        if value then
            for _, pad in ipairs(dungeonPads()) do
                if value == pad.Object or value == pad.Part or value:IsDescendantOf(pad.Object) then
                    return pad
                end
            end
        end
        local root = rootPart()
        if root then
            for _, pad in ipairs(dungeonPads()) do
                if (pad.Part.Position - root.Position).Magnitude <= 8 then
                    return pad
                end
            end
        end
        return nil
    end

    local function openPad()
        for _, pad in ipairs(dungeonPads()) do
            if pad.Count < pad.Maximum then
                return pad
            end
        end
        return nil
    end

    local function updateQueueAutomation(deltaTime)
        if dungeonRunActive() then
            state.CurrentPad = nil
            return false
        end

        local pad = referencedPad()
        if not pad and state.AutoJoin then
            pad = openPad()
            if pad then
                state.CurrentPad = pad
                setCharacterNoclip(true)
                local goal = pad.Part.CFrame + Vector3.new(0, 2.6, 0)
                local reached, distance = stepRootToward(goal, state.TweenSpeed, deltaTime)
                queueLabel.Text = string.format("Queue: Joining %s | %.0f studs", pad.Object.Name, distance)
                if reached then
                    local root = rootPart()
                    if root then
                        root.CFrame = goal
                        root.AssemblyLinearVelocity = Vector3.zero
                    end
                end
                return true
            end
        end

        state.CurrentPad = pad
        if pad then
            local count = tonumber(pad.Object:GetAttribute("NumPlayersOnPad")) or pad.Count
            queueLabel.Text = string.format(
                "Queue: %s | %d/%d players | %s",
                pad.Object.Name,
                count,
                pad.Maximum,
                state.Difficulty
            )
            if state.AutoStart then
                local now = os.clock()
                if tostring(pad.Object:GetAttribute("Difficulty") or "") ~= state.Difficulty
                    and now - state.LastDifficultyRequest >= 1.5 then
                    state.LastDifficultyRequest = now
                    pcall(function()
                        pad.Remote:FireServer("Difficulty", state.Difficulty)
                    end)
                end
                if count >= state.MinimumPlayers and now - state.LastStartRequest >= 1.75 then
                    state.LastStartRequest = now
                    local started, startError = pcall(function()
                        pad.Remote:FireServer("Start")
                    end)
                    if started then
                        setStatus("Dungeon start requested", true)
                    else
                        setError("Dungeon start failed: " .. tostring(startError))
                    end
                end
            end
        else
            queueLabel.Text = state.AutoJoin
                and "Queue: Waiting for an open pad"
                or "Queue: Auto Join is off"
        end
        return false
    end

    local difficultyControl = nil

    local function readUnlockedDifficulties()
        local data = nil
        local dungeonClient = ReplicatedStorage:FindFirstChild("DungeonClient")
        local replicatedPlayerData = safeRequire(dungeonClient and dungeonClient:FindFirstChild("ReplicatedPlayerData"))
        if type(replicatedPlayerData) == "table" and type(replicatedPlayerData.get) == "function" then
            pcall(function()
                data = replicatedPlayerData.get()
            end)
        end
        if type(data) ~= "table" then
            local shared = ReplicatedStorage:FindFirstChild("DungeonShared")
            local dataRemote = shared and shared:FindFirstChild("DataRemote")
            if dataRemote and dataRemote:IsA("RemoteFunction") then
                pcall(function()
                    data = dataRemote:InvokeServer("GetData")
                end)
            end
        end

        local unlocked = data
            and data.DataForDungeonTypes
            and data.DataForDungeonTypes.Simulation
            and data.DataForDungeonTypes.Simulation.UnlockedDifficulties
        local options = {}
        if type(unlocked) == "table" then
            for name, value in pairs(unlocked) do
                if (type(name) == "string" and value ~= false) then
                    table.insert(options, name)
                elseif type(value) == "string" then
                    table.insert(options, value)
                end
            end
        end
        if #options == 0 then
            options = {"Normal"}
        end
        local ranks = {Normal = 1, Hard = 2, Nightmare = 3, Insane = 4}
        table.sort(options, function(left, right)
            return (ranks[left] or 99) < (ranks[right] or 99)
        end)
        return options
    end

    local function refreshDifficulties()
        local options = readUnlockedDifficulties()
        if difficultyControl then
            difficultyControl:SetOptions(options, true)
            local found = false
            for _, option in ipairs(options) do
                if option == state.Difficulty then
                    found = true
                    break
                end
            end
            if not found then
                state.Difficulty = options[1]
                difficultyControl:Set(state.Difficulty, true)
            end
        end
        queueLabel.Text = "Queue: Unlocked difficulty choices refreshed"
        return options
    end

    local CARD_LABEL_TO_KEY = {
        ["None"] = nil,
        ["Fruit"] = "Fruit",
        ["Fruit M1 Speed"] = "FruitTAPCooldown",
        ["All Cooldowns"] = "AllCooldown",
        ["Fruit Cooldowns"] = "FruitCooldown",
        ["HYPER! (M1 Speed)"] = "AttackSpeedMultiplier",
        ["Sword"] = "Sword",
        ["Sword Cooldowns"] = "SwordCooldown",
        ["Lifesteal"] = "Lifesteal",
        ["Armor"] = "Armor",
        ["Fortress"] = "Fortress",
        ["Unbreakable"] = "Unbreakable",
        ["Overflow"] = "Overflow",
        ["Defense"] = "Defense",
        ["Melee"] = "Melee",
        ["Skyjumps"] = "Skyjumps",
        ["Rage Gain"] = "RageGain",
    }

    local CARD_OPTIONS = {
        "None",
        "Fruit",
        "Fruit M1 Speed",
        "All Cooldowns",
        "Fruit Cooldowns",
        "HYPER! (M1 Speed)",
        "Sword",
        "Sword Cooldowns",
        "Lifesteal",
        "Armor",
        "Fortress",
        "Unbreakable",
        "Overflow",
        "Defense",
        "Melee",
        "Skyjumps",
        "Rage Gain",
    }

    local DEFAULT_PRIORITY = {
        "Fruit",
        "Fruit M1 Speed",
        "All Cooldowns",
        "Fruit Cooldowns",
        "HYPER! (M1 Speed)",
        "Sword",
        "Sword Cooldowns",
        "Lifesteal",
    }

    local function offerBuffName(offer)
        return type(offer) == "table" and tostring(offer.buffName or offer.Name or "") or tostring(offer or "")
    end

    local function chooseCard(offers)
        if type(offers) ~= "table" then
            return nil
        end
        local byName = {}
        local offeredNames = {}
        for _, offer in pairs(offers) do
            local name = offerBuffName(offer)
            if name ~= "" then
                byName[name] = offer
                table.insert(offeredNames, name)
            end
        end
        state.LastCardOffers = #offeredNames > 0 and table.concat(offeredNames, " / ") or "No card names"

        for index = 1, #state.Priority do
            local key = CARD_LABEL_TO_KEY[state.Priority[index]]
            if key and byName[key] then
                state.LastCardChoice = state.Priority[index]
                return byName[key], key
            end
        end
        if #offeredNames > 0 then
            local key = offeredNames[1]
            state.LastCardChoice = key .. " (fallback)"
            return byName[key], key
        end
        return nil
    end

    local function callbackValue(remote)
        if type(getcallbackvalue) ~= "function" then
            return nil
        end
        local ok, callback = pcall(getcallbackvalue, remote, "OnClientInvoke")
        return ok and type(callback) == "function" and callback or nil
    end

    local function restoreCardHook()
        local remote = state.CardRemote
        if remote and state.CardHooked then
            local current = callbackValue(remote)
            if current == state.CardCallback and type(state.CardOriginalCallback) == "function" then
                pcall(function()
                    remote.OnClientInvoke = state.CardOriginalCallback
                end)
            end
        end
        state.CardRemote = nil
        state.CardOriginalCallback = nil
        state.CardCallback = nil
        state.CardHooked = false
    end

    local function installCardHook()
        if not state.AutoSelectCards or type(getcallbackvalue) ~= "function" then
            return false
        end
        local shared = ReplicatedStorage:FindFirstChild("DungeonShared")
        local remote = shared and shared:FindFirstChild("BuffSelector")
        if not remote or not remote:IsA("RemoteFunction") then
            return false
        end

        if state.CardRemote == remote and state.CardHooked and callbackValue(remote) == state.CardCallback then
            return true
        end
        restoreCardHook()
        local original = callbackValue(remote)
        if type(original) ~= "function" then
            return false
        end

        local wrapper
        wrapper = function(...)
            local arguments = table.pack(...)
            if state.Alive and state.AutoSelectCards then
                local _, choice = chooseCard(arguments[1])
                if choice then
                    cardLabel.Text = "Cards: Chose " .. state.LastCardChoice
                    return choice
                end
            end
            return original(table.unpack(arguments, 1, arguments.n))
        end
        local installed, installError = pcall(function()
            remote.OnClientInvoke = wrapper
        end)
        if not installed then
            state.LastError = "Card hook failed: " .. tostring(installError)
            return false
        end
        state.CardRemote = remote
        state.CardOriginalCallback = original
        state.CardCallback = wrapper
        state.CardHooked = true
        return true
    end

    local function clickCardFallback()
        if not state.AutoSelectCards or state.CardHooked or os.clock() - state.LastGuiCardClickAt < 0.5 then
            return false
        end
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return false
        end

        for priorityIndex = 1, #state.Priority do
            local wantedLabel = state.Priority[priorityIndex]
            local wantedKey = CARD_LABEL_TO_KEY[wantedLabel]
            if wantedKey then
                for _, button in ipairs(playerGui:GetDescendants()) do
                    if button:IsA("GuiButton") and button.Visible then
                        local matched = false
                        for _, textObject in ipairs(button:GetDescendants()) do
                            if (textObject:IsA("TextLabel") or textObject:IsA("TextButton")) then
                                local text = string.lower(tostring(textObject.Text or ""))
                                if text == string.lower(wantedLabel)
                                    or text == string.lower(wantedKey) then
                                    matched = true
                                    break
                                end
                            end
                        end
                        if matched then
                            state.LastGuiCardClickAt = os.clock()
                            state.LastCardChoice = wantedLabel
                            cardLabel.Text = "Cards: Chose " .. wantedLabel .. " (UI fallback)"
                            pcall(function()
                                button:Activate()
                            end)
                            if type(firesignal) == "function" then
                                pcall(firesignal, button.MouseButton1Click)
                            end
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function returnToHub()
        local shared = ReplicatedStorage:FindFirstChild("DungeonShared")
        local remote = shared and shared:FindFirstChild("ReturnToHub")
        if not remote or not remote:IsA("RemoteEvent") then
            return false, "ReturnToHub remote is unavailable"
        end
        local ok, message = pcall(function()
            remote:FireServer()
        end)
        return ok, ok and "Returning to the Dungeon hub" or tostring(message)
    end

    local function bindDungeonRemotes()
        local shared = ReplicatedStorage:FindFirstChild("DungeonShared")
        if not shared then
            return
        end
        local results = shared:FindFirstChild("ResultsScreen")
        if results and results:IsA("RemoteEvent") and state.ResultsRemote ~= results then
            state.ResultsRemote = results
            track(results.OnClientEvent:Connect(function()
                state.RunFinished = true
                setStatus("Dungeon complete", true)
                if state.AutoLeave then
                    task.delay(1, function()
                        if state.Alive and state.AutoLeave then
                            local ok, message = returnToHub()
                            setStatus(message, ok)
                        end
                    end)
                end
            end))
        end
        local buffs = shared:FindFirstChild("BuffReplicator")
        if buffs and buffs:IsA("RemoteEvent") and state.BuffRemote ~= buffs then
            state.BuffRemote = buffs
            track(buffs.OnClientEvent:Connect(function(value)
                if type(value) == "table" then
                    local count = 0
                    for _ in pairs(value) do
                        count += 1
                    end
                    state.CurrentBuffCount = count
                end
            end))
        end
    end

    local function buyRandomTrinket()
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local remote = remotes and remotes:FindFirstChild("AccessoryInteract")
            if not remote or not remote:IsA("RemoteFunction") then
                trinketStatusLabel.Text = "Trinket: Purchase remote is unavailable"
                trinketStatusLabel.TextColor3 = COLORS.error
                return
            end
            trinketStatusLabel.Text = "Trinket: Sending purchase request..."
            local ok, result = pcall(function()
                return remote:InvokeServer("d")
            end)
            if not ok then
                trinketStatusLabel.Text = "Trinket: Request failed - " .. tostring(result)
                trinketStatusLabel.TextColor3 = COLORS.error
                return
            end
            if result == "CantAfford" then
                trinketStatusLabel.Text = "Trinket: Need 400 Simulation Data"
                trinketStatusLabel.TextColor3 = COLORS.error
            elseif result == "MaxTrinkets" then
                trinketStatusLabel.Text = "Trinket: Inventory is already full"
                trinketStatusLabel.TextColor3 = COLORS.error
            else
                trinketStatusLabel.Text = "Trinket: Purchase accepted"
                trinketStatusLabel.TextColor3 = COLORS.success
            end
        end)
    end

    local PlayerEsp = {
        Bones = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
            {"Head", "Torso"},
            {"Torso", "Left Arm"},
            {"Torso", "Right Arm"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
        },
    }

    function PlayerEsp.Remove(player)
        local record = state.PlayerEspObjects[player]
        if not record then
            return
        end
        if record.Highlight then
            pcall(function()
                record.Highlight:Destroy()
            end)
        end
        if record.Billboard then
            pcall(function()
                record.Billboard:Destroy()
            end)
        end
        for _, line in ipairs(record.Lines or {}) do
            pcall(function()
                line.Visible = false
                line:Remove()
            end)
        end
        state.PlayerEspObjects[player] = nil
    end

    function PlayerEsp.Clear()
        for player in pairs(state.PlayerEspObjects) do
            PlayerEsp.Remove(player)
        end
    end

    function PlayerEsp.Create(player, playerCharacter)
        PlayerEsp.Remove(player)
        local head = playerCharacter and playerCharacter:FindFirstChild("Head")
        local root = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
        if not head and not root then
            return nil
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "VOR_DungeonPlayerESP"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = COLORS.accent
        highlight.OutlineColor = COLORS.accent:Lerp(Color3.new(1, 1, 1), 0.45)
        highlight.FillTransparency = 0.78
        highlight.OutlineTransparency = 0.08
        highlight.Parent = playerCharacter

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "VOR_DungeonPlayerName_" .. tostring(player.UserId)
        billboard.Adornee = head or root
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = 10000000
        billboard.Size = UDim2.fromOffset(260, 48)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
        billboard.Parent = gui

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = COLORS.accent:Lerp(Color3.new(1, 1, 1), 0.28)
        label.TextSize = 14
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0.05
        label.TextWrapped = true
        label.Parent = billboard

        local lines = {}
        if type(Drawing) == "table" and type(Drawing.new) == "function" then
            for _ = 1, #PlayerEsp.Bones do
                local ok, line = pcall(Drawing.new, "Line")
                if ok and line then
                    line.Color = COLORS.accent
                    line.Thickness = 2
                    line.Transparency = 0.95
                    line.ZIndex = 9
                    line.Visible = false
                    table.insert(lines, line)
                end
            end
        end
        local record = {
            Character = playerCharacter,
            Highlight = highlight,
            Billboard = billboard,
            Label = label,
            Lines = lines,
        }
        state.PlayerEspObjects[player] = record
        return record
    end

    function PlayerEsp.Update(allowCreate)
        if not state.PlayerESP then
            PlayerEsp.Clear()
            return
        end
        local camera = workspace.CurrentCamera
        local localRoot = rootPart()
        local now = os.clock()
        local updateText = now - state.PlayerEspLastTextUpdate >= 0.15
        if updateText then
            state.PlayerEspLastTextUpdate = now
        end

        for player, record in pairs(state.PlayerEspObjects) do
            if player.Parent ~= Players or not player.Character or record.Character ~= player.Character then
                PlayerEsp.Remove(player)
            end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local record = state.PlayerEspObjects[player]
                if allowCreate and (not record or record.Character ~= player.Character) then
                    record = PlayerEsp.Create(player, player.Character)
                end
                if record then
                    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                    local head = player.Character:FindFirstChild("Head") or targetRoot
                    record.Billboard.Adornee = head
                    record.Billboard.Enabled = head ~= nil
                    if updateText and targetRoot and localRoot then
                        local distance = (targetRoot.Position - localRoot.Position).Magnitude
                        record.Label.Text = string.format(
                            "%s  (@%s)\n%.0f studs",
                            player.DisplayName,
                            player.Name,
                            distance
                        )
                    end
                    if camera and #record.Lines > 0 then
                        for index, bone in ipairs(PlayerEsp.Bones) do
                            local line = record.Lines[index]
                            if line then
                                local first = player.Character:FindFirstChild(bone[1])
                                local second = player.Character:FindFirstChild(bone[2])
                                if first and first:IsA("BasePart") and second and second:IsA("BasePart") then
                                    local firstPoint, firstVisible = camera:WorldToViewportPoint(first.Position)
                                    local secondPoint, secondVisible = camera:WorldToViewportPoint(second.Position)
                                    local visible = firstVisible and secondVisible
                                        and firstPoint.Z > 0 and secondPoint.Z > 0
                                    line.Visible = visible
                                    if visible then
                                        line.From = Vector2.new(firstPoint.X, firstPoint.Y)
                                        line.To = Vector2.new(secondPoint.X, secondPoint.Y)
                                    end
                                else
                                    line.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    AutomationSection:AddLabel("Dedicated Simulation Dungeon flow; no Sea or quest clutter in this place.")
    AutomationSection:AddToggle({
        Name = "Auto Join Dungeon",
        Flag = "blox_dungeon_auto_join",
        Default = false,
        Callback = function(enabled)
            state.AutoJoin = enabled
            if not enabled then
                state.CurrentPad = nil
            end
        end,
    })
    AutomationSection:AddToggle({
        Name = "Auto Start Dungeon",
        Flag = "blox_dungeon_auto_start",
        Default = false,
        Callback = function(enabled)
            state.AutoStart = enabled
        end,
    })
    AutomationSection:AddToggle({
        Name = "Auto Leave Dungeon",
        Flag = "blox_dungeon_auto_leave",
        Default = false,
        Callback = function(enabled)
            state.AutoLeave = enabled
            if enabled and state.RunFinished then
                local ok, message = returnToHub()
                setStatus(message, ok)
            end
        end,
    })
    AutomationSection:AddToggle({
        Name = "Auto Farm Dungeon",
        Description = "Smooth cardinal farm with silent Sword + Fruit M1",
        Flag = "blox_dungeon_auto_farm",
        Default = false,
        Callback = function(enabled)
            state.AutoFarm = enabled
            state.CurrentTarget = nil
            state.NextPositionChange = 0
            if not enabled and not state.ManualNoclip then
                setCharacterNoclip(false)
                restoreEnemyCollision()
            end
            setStatus(enabled and "Dungeon farm armed" or "Dungeon farm stopped", true)
        end,
    })
    AutomationSection:AddToggle({
        Name = "Auto Select Cards",
        Description = "Uses the ordered priority list below",
        Flag = "blox_dungeon_auto_cards",
        Default = false,
        Callback = function(enabled)
            state.AutoSelectCards = enabled
            if enabled then
                installCardHook()
            else
                restoreCardHook()
            end
        end,
    })
    AutomationSection:AddLabel("Attack Method: Sword + Fruit M1 together (fixed)")

    PositionSection:AddToggle({
        Name = "Random Position Farm",
        Description = "Four fast square/cardinal positions above the NPC",
        Flag = "blox_dungeon_random_position",
        Default = true,
        Callback = function(enabled)
            state.RandomPosition = enabled
            state.NextPositionChange = 0
        end,
    })
    PositionSection:AddSlider({
        Name = "Position Farm X",
        Flag = "blox_dungeon_position_x",
        Min = 0,
        Max = 3,
        Step = 1,
        Default = 1,
        Callback = function(value)
            state.PositionX = value
        end,
    })
    PositionSection:AddSlider({
        Name = "Position Farm Y",
        Flag = "blox_dungeon_position_y",
        Min = 0,
        Max = 3,
        Step = 1,
        Default = 1,
        Callback = function(value)
            state.PositionY = value
        end,
    })
    PositionSection:AddSlider({
        Name = "Position Farm Z",
        Flag = "blox_dungeon_position_z",
        Min = 0,
        Max = 3,
        Step = 1,
        Default = 1,
        Callback = function(value)
            state.PositionZ = value
        end,
    })
    PositionSection:AddSlider({
        Name = "Random Position Range",
        Flag = "blox_dungeon_random_range",
        Min = 4,
        Max = 30,
        Step = 1,
        Default = 10,
        Callback = function(value)
            state.RandomRange = value
        end,
    })
    PositionSection:AddToggle({
        Name = "Auto Magnet Enemy",
        Description = "Groups network-owned dungeon NPCs on the active target",
        Flag = "blox_dungeon_auto_magnet",
        Default = true,
        Callback = function(enabled)
            state.AutoMagnet = enabled
            if not enabled then
                restoreEnemyCollision()
            end
        end,
    })
    PositionSection:AddSlider({
        Name = "Magnet Range",
        Flag = "blox_dungeon_magnet_range",
        Min = 50,
        Max = 1000,
        Step = 25,
        Default = 500,
        Callback = function(value)
            state.MagnetRange = value
        end,
    })

    difficultyControl = QueueSection:AddDropdown({
        Name = "Difficulty Selection",
        Flag = "blox_dungeon_difficulty",
        Options = {"Normal"},
        Default = "Normal",
        Callback = function(value)
            state.Difficulty = tostring(value or "Normal")
            state.LastDifficultyRequest = 0
        end,
    })
    QueueSection:AddSlider({
        Name = "Minimum Players",
        Flag = "blox_dungeon_minimum_players",
        Min = 1,
        Max = 4,
        Step = 1,
        Default = 1,
        Callback = function(value)
            state.MinimumPlayers = value
        end,
    })
    QueueSection:AddSlider({
        Name = "Tween Speed",
        Flag = "blox_dungeon_tween_speed",
        Min = 50,
        Max = 650,
        Step = 5,
        Default = 315,
        Callback = function(value)
            state.TweenSpeed = value
        end,
    })
    QueueSection:AddButton({
        Name = "Refresh Unlocked Difficulties",
        Callback = function()
            task.spawn(function()
                local options = refreshDifficulties()
                Window:Notify("Dungeons", "Found " .. tostring(#options) .. " unlocked difficulty choice(s)", 3)
            end)
        end,
    })

    TrinketSection:AddButton({
        Name = "Buy Random Trinket Anywhere",
        Description = "Costs 400 Simulation Data; no NPC teleport required",
        Persist = false,
        Callback = buyRandomTrinket,
    })
    TrinketSection:AddLabel("Uses the Trinket Expert's real random-purchase request.")

    for index, default in ipairs(DEFAULT_PRIORITY) do
        state.Priority[index] = default
        PrioritySection:AddDropdown({
            Name = "Priority " .. tostring(index),
            Flag = "blox_dungeon_card_priority_" .. tostring(index),
            Options = CARD_OPTIONS,
            Default = default,
            Callback = function(value)
                state.Priority[index] = tostring(value or "None")
            end,
        })
    end
    PrioritySection:AddLabel("If none of your choices appear, the first offered card is selected so the run cannot stall.")

    AuraSection:AddToggle({
        Name = "Auto Aura Ability (Buso)",
        Description = "Uses J on PC/executor input; legacy request is fallback",
        Flag = "blox_dungeon_auto_buso",
        Default = true,
        Callback = function(enabled)
            state.AutoBuso = enabled
            if enabled then
                ensureBuso()
            end
        end,
    })
    AuraSection:AddToggle({
        Name = "Manual Noclip",
        Description = "Dungeon farming enables noclip only while actively moving",
        Flag = "blox_dungeon_manual_noclip",
        Default = false,
        Callback = function(enabled)
            state.ManualNoclip = enabled
            if not enabled and not state.MovementActive then
                setCharacterNoclip(false)
            end
        end,
    })
    AuraSection:AddToggle({
        Name = "Anti-AFK / Anti-Idle",
        Flag = "blox_dungeon_anti_afk",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })

    VisionSection:AddToggle({
        Name = "Player ESP",
        Description = "Unlimited-distance highlight, name, distance, and skeleton",
        Flag = "blox_dungeon_player_esp",
        Default = false,
        Callback = function(enabled)
            state.PlayerESP = enabled
            if not enabled then
                PlayerEsp.Clear()
            end
            espStatusLabel.Text = enabled
                and ((type(Drawing) == "table" and "ESP: Names + highlights + skeleton") or "ESP: Names + highlights (Drawing unavailable)")
                or "ESP: Off"
        end,
    })

    SessionSection:AddButton({
        Name = "Return to Dungeon Hub",
        Callback = function()
            local ok, message = returnToHub()
            setStatus(message, ok)
        end,
    })
    SessionSection:AddButton({
        Name = "Stop All Dungeon Automation",
        Callback = function()
            state.AutoJoin = false
            state.AutoStart = false
            state.AutoLeave = false
            state.AutoFarm = false
            state.AutoSelectCards = false
            state.CurrentTarget = nil
            restoreCardHook()
            restoreEnemyCollision()
            if not state.ManualNoclip then
                setCharacterNoclip(false)
            end
            setStatus("All dungeon automation stopped", true)
        end,
    })
    SessionSection:AddLabel("Farm never targets workspace.Characters or any model named after a player.")

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(
                    Vector2.new(0, 0),
                    workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new()
                )
            end)
        end
    end))

    track(RunService.Heartbeat:Connect(function(deltaTime)
        if not state.Alive then
            return
        end
        state.InRun = dungeonRunActive()
        if state.InRun then
            state.WasInRun = true
        end

        local movementActive = false
        if state.InRun and state.AutoFarm then
            if os.clock() - state.LastTargetScan >= 0.08 then
                state.LastTargetScan = os.clock()
                chooseTarget()
            end
            local target = chooseTarget()
            local goal = target and desiredFarmCFrame(target) or nil
            if goal then
                setCharacterNoclip(true)
                stepRootToward(goal, state.TweenSpeed, deltaTime)
                movementActive = true
                local targetRoot = modelRoot(target)
                local root = rootPart()
                state.CurrentTargetName = target.Name
                state.CurrentTargetDistance = targetRoot and root and (targetRoot.Position - root.Position).Magnitude or nil
            else
                state.CurrentTargetName = "Waiting for next wave"
                state.CurrentTargetDistance = nil
            end
            applyDungeonMagnet()
        else
            state.CurrentTarget = nil
            state.CurrentTargetName = "None"
            state.CurrentTargetDistance = nil
            restoreEnemyCollision()
            movementActive = updateQueueAutomation(deltaTime)
        end

        state.MovementActive = movementActive
        if not movementActive and not state.ManualNoclip then
            setCharacterNoclip(false)
        elseif state.ManualNoclip then
            setCharacterNoclip(true)
        end
    end))

    track(RunService.RenderStepped:Connect(function()
        if not state.Alive then
            return
        end
        stopActionAnimations()
        PlayerEsp.Update(true)
    end))

    task.spawn(function()
        while state.Alive do
            if state.AutoFarm and dungeonRunActive() and validEnemy(state.CurrentTarget) then
                if ensureBuso() then
                    local now = os.clock()
                    if not state.SwordBusy and now - state.LastSwordAttack >= 0.13 then
                        state.SwordBusy = true
                        state.LastSwordAttack = now
                        task.spawn(function()
                            local ok, sent, message = pcall(sendSwordAttack)
                            if not ok or not sent then
                                local failure = ok and message or sent
                                if not tostring(failure):find("left", 1, true)
                                    and not tostring(failure):find("No enemy", 1, true) then
                                    state.LastError = "Sword M1: " .. tostring(failure)
                                end
                            end
                            state.SwordBusy = false
                        end)
                    end
                    if not state.FruitBusy and now - state.LastFruitAttack >= 0.055 then
                        state.FruitBusy = true
                        state.LastFruitAttack = now
                        task.spawn(function()
                            local ok, sent, message = pcall(sendFruitAttack)
                            if not ok or not sent then
                                local failure = ok and message or sent
                                if not tostring(failure):find("No enemy", 1, true) then
                                    state.LastError = "Fruit M1: " .. tostring(failure)
                                end
                            end
                            state.FruitBusy = false
                        end)
                    end
                end
            end
            task.wait(0.025)
        end
    end)

    task.spawn(function()
        while state.Alive do
            bindDungeonRemotes()
            if state.AutoSelectCards then
                installCardHook()
                clickCardFallback()
            end

            local dungeon = currentDungeonReplication()
            if dungeon then
                local currentFloor = tonumber(dungeon:GetAttribute("CurrentExploredLevel")) or 0
                local dead = tonumber(dungeon:GetAttribute("DeadEnemies")) or 0
                local total = tonumber(dungeon:GetAttribute("TotalEnemies")) or 0
                local floors = dungeon:FindFirstChild("Floors")
                local floorCount = floors and #floors:GetChildren() or 0
                runLabel.Text = string.format(
                    "Run: Floor %d/%d | Enemies %d/%d | Loaded %d",
                    currentFloor,
                    floorCount,
                    dead,
                    total,
                    #livingEnemies()
                )
                runLabel.TextColor3 = COLORS.success
            else
                runLabel.Text = "Run: Dungeon hub / waiting for teleport"
                runLabel.TextColor3 = COLORS.muted
            end

            targetLabel.Text = state.CurrentTargetDistance
                and string.format("Target: %s | %.1f studs | Gathered %d", state.CurrentTargetName, state.CurrentTargetDistance, state.GatheredCount)
                or ("Target: " .. state.CurrentTargetName)
            attackLabel.Text = string.format(
                "Attacks: Sword %d | Fruit %d | Last multi-hit %d",
                state.SwordRequests,
                state.FruitRequests,
                state.MultiHitCount
            )
            cardLabel.Text = state.AutoSelectCards
                and ("Cards: " .. state.LastCardChoice .. " | Offers " .. state.LastCardOffers)
                or "Cards: Auto Select is off"
            buffLabel.Text = "Buffs: " .. tostring(state.CurrentBuffCount) .. " replicated"

            local data = tonumber(LocalPlayer:GetAttribute("SimulationData")) or 0
            trinketDataLabel.Text = string.format("Simulation Data: %d / 400", data)
            trinketDataLabel.TextColor3 = data >= 400 and COLORS.success or COLORS.muted
            local active = busoActive()
            busoLabel.Text = active
                and "Aura Ability: Active"
                or (state.AutoBuso and "Aura Ability: Activating..." or "Aura Ability: Off")
            busoLabel.TextColor3 = active and COLORS.success or COLORS.muted

            if state.LastError and state.LastError ~= "" then
                statusLabel.Text = "Status: " .. state.LastError
                statusLabel.TextColor3 = COLORS.error
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        local ok, message = pcall(refreshDifficulties)
        if not ok then
            state.LastError = "Difficulty refresh failed: " .. tostring(message)
        end
    end)

    if gui then
        gui:SetAttribute("BloxDungeonModule", true)
        gui:SetAttribute("BloxDungeonPlaceId", 73902483975735)
        gui:SetAttribute("BloxDungeonVisiblePages", "Dungeons,Player")
        gui:SetAttribute("BloxDungeonAttackMethod", "Sword + Fruit M1")
        gui:SetAttribute("BloxDungeonTrinketCost", 400)
        track(gui.Destroying:Connect(function()
            state.Alive = false
            state.AutoFarm = false
            state.AutoJoin = false
            state.AutoStart = false
            state.AutoLeave = false
            state.AutoSelectCards = false
            restoreCardHook()
            restoreEnemyCollision()
            setCharacterNoclip(false)
            PlayerEsp.Clear()
        end))
    end

    bindDungeonRemotes()
    ensureBuso()
    setStatus("Blox Fruits Dungeon module ready", true)
end
