-- VOR Hub - Catch 1 Billion Ducks
-- UniverseId 10516888336 | Lobby 100293509865504 | Match 120617974337690
-- Uses the experience's own server-validated weapon, economy, dog, and reward routes.

local DUCK_VALUES = {
    Duck_BaseDuck = 10,
    Duck_Colored = 35,
    Duck_Rouen = 100,
    Duck_Wigeon = 180,
    Duck_ChineseGoose = 300,
    Duck_Silver = 800,
    Duck_Golden = 1400,
    Duck_Ghost = 2200,
    Duck_Void = 3500,
    Duck_Rubber = 5000,
    Duck_Rainbow = 8000,
    Duck_BBQ = 20000,
}

local DUCK_RESUME_FLAGS = {
    "duckb_full_progression",
    "duckb_anti_afk",
    "duckb_auto_hunt",
    "duckb_target_mode",
    "duckb_visibility_check",
    "duckb_prediction",
    "duckb_auto_sell",
    "duckb_sell_interval",
    "duckb_auto_weapons",
    "duckb_auto_upgrades",
    "duckb_cash_reserve",
    "duckb_feather_reserve",
    "duckb_auto_dogs",
    "duckb_auto_crates",
    "duckb_auto_achievements",
    "duckb_auto_freezer",
    "duckb_auto_skip_day",
    "duckb_auto_queue",
    "duckb_auto_daily_quests",
    "duckb_auto_last_session",
}

local DUCK_RESUME_TUNING_ORDER = {
    "duckb_cash_reserve",
    "duckb_feather_reserve",
    "duckb_target_mode",
    "duckb_prediction",
    "duckb_sell_interval",
}

local DUCK_RESUME_TOGGLE_ORDER = {
    "duckb_anti_afk",
    "duckb_visibility_check",
    "duckb_auto_hunt",
    "duckb_auto_sell",
    "duckb_auto_achievements",
    "duckb_auto_freezer",
    "duckb_auto_skip_day",
    "duckb_auto_daily_quests",
    "duckb_auto_last_session",
    "duckb_auto_weapons",
    "duckb_auto_upgrades",
    "duckb_auto_dogs",
    "duckb_auto_crates",
    "duckb_auto_queue",
    "duckb_full_progression",
}

local DUCK_RESUME_FLAG_SET = {}
for _, flag in ipairs(DUCK_RESUME_FLAGS) do
    DUCK_RESUME_FLAG_SET[flag] = true
end

local function resumeEnvironment()
    return type(getgenv) == "function" and getgenv() or _G
end

local function validResumeScalar(value)
    local kind = type(value)
    return kind == "boolean" or kind == "number" or kind == "string"
end

local function snapshotResumeFlags(window)
    local values = {}
    for _, flag in ipairs(DUCK_RESUME_FLAGS) do
        local control = window.PersistentControls and window.PersistentControls[flag]
        if not control or type(control.Get) ~= "function" then
            return nil, "missing resume control: " .. flag
        end
        local ok, value = pcall(control.Get, control)
        if not ok or not validResumeScalar(value) then
            return nil, "invalid resume value: " .. flag
        end
        values[flag] = value
    end
    return values
end

local function luaQuote(value)
    return string.format("%q", tostring(value))
end

local function validateResumeFlags(values)
    if type(values) ~= "table" then
        return false, "resume flags are missing"
    end
    local count = 0
    for flag, value in pairs(values) do
        if not DUCK_RESUME_FLAG_SET[flag] then
            return false, "unexpected resume flag: " .. tostring(flag)
        end
        if not validResumeScalar(value) then
            return false, "invalid resume flag value: " .. tostring(flag)
        end
        count = count + 1
    end
    if count ~= #DUCK_RESUME_FLAGS then
        return false, "resume flag count is " .. tostring(count) .. ", expected " .. tostring(#DUCK_RESUME_FLAGS)
    end
    for _, flag in ipairs(DUCK_RESUME_FLAGS) do
        if values[flag] == nil then
            return false, "resume flag is missing: " .. flag
        end
    end
    return true
end

local function pauseResumeToggles(runtime)
    local paused = {}
    for _, flag in ipairs(DUCK_RESUME_TOGGLE_ORDER) do
        local control = runtime.Window.PersistentControls and runtime.Window.PersistentControls[flag]
        if not control or type(control.Set) ~= "function" or type(control.SetRuntimePaused) ~= "function" then
            for _, previous in ipairs(paused) do
                pcall(previous.SetRuntimePaused, previous, false)
            end
            return false, "resume toggle is unavailable: " .. flag
        end
        control:SetRuntimePaused(true)
        paused[#paused + 1] = control
    end
    runtime.ResumePausedControls = paused
    return true
end

local function releaseResumeToggles(runtime, failClosed)
    if failClosed then
        for _, flag in ipairs(DUCK_RESUME_TOGGLE_ORDER) do
            local control = runtime.Window.PersistentControls and runtime.Window.PersistentControls[flag]
            if control and type(control.Set) == "function" then
                pcall(control.Set, control, false)
            end
        end
    end
    for _, control in ipairs(runtime.ResumePausedControls or {}) do
        pcall(control.SetRuntimePaused, control, false)
    end
    runtime.ResumePausedControls = nil
end

local function applyClaimedResume(runtime)
    if runtime.ResumeApplied or type(runtime.PendingResumeFlags) ~= "table" then
        return runtime.ResumeApplied == true
    end
    local values = runtime.PendingResumeFlags
    local valid, reason = validateResumeFlags(values)
    if not valid then
        releaseResumeToggles(runtime, true)
        runtime.PendingResumeFlags = nil
        runtime.TeleportResumeError = reason
        runtime:SetError("Teleport resume: " .. reason)
        return false
    end

    runtime.AutomationReadyAt = math.huge
    local ok, applyError = xpcall(function()
        for _, flag in ipairs(DUCK_RESUME_TUNING_ORDER) do
            local control = runtime.Window.PersistentControls[flag]
            assert(control and type(control.Set) == "function", "resume control is unavailable: " .. flag)
            control:Set(values[flag])
        end
        for _, flag in ipairs(DUCK_RESUME_TOGGLE_ORDER) do
            local control = runtime.Window.PersistentControls[flag]
            assert(control and type(control.Set) == "function", "resume toggle is unavailable: " .. flag)
            control:Set(values[flag])
        end
    end, function(message)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(message, 2)
        end
        return tostring(message)
    end)
    if not ok then
        releaseResumeToggles(runtime, true)
        runtime.PendingResumeFlags = nil
        runtime.TeleportResumeError = tostring(applyError)
        runtime:SetError("Teleport resume: " .. tostring(applyError))
        return false
    end

    -- Releasing in this order applies every saved toggle only after reserves and
    -- tuning are restored. Full Progression is deliberately released last.
    releaseResumeToggles(runtime, false)
    runtime.PendingResumeFlags = nil
    runtime.ResumeApplied = true
    runtime.AutomationReadyAt = os.clock() + 1
    runtime.TeleportResumeError = nil
    runtime:SetStatus("Cross-place duck shift restored", true)

    local environment = resumeEnvironment()
    local nonce = runtime.ResumeNonce
    if nonce then
        environment.__VORCatchBillionDucksResumeConsumed = nonce
        task.delay(180, function()
            if environment.__VORCatchBillionDucksResumeConsumed == nonce then
                environment.__VORCatchBillionDucksResumeConsumed = nil
            end
            if environment.__VORCatchBillionDucksResumeClaimed == nonce then
                environment.__VORCatchBillionDucksResumeClaimed = nil
            end
        end)
    end
    return true
end

local function claimDestinationResume(runtime)
    local environment = resumeEnvironment()
    local envelope = environment.__VORCatchBillionDucksResume
    if type(envelope) ~= "table" then
        return false
    end

    local nonce = tostring(envelope.Nonce or "")
    local function reject(reason)
        if environment.__VORCatchBillionDucksResume == envelope then
            environment.__VORCatchBillionDucksResume = nil
        end
        if environment.__VORCatchBillionDucksResumeExecuting == nonce then
            environment.__VORCatchBillionDucksResumeExecuting = nil
        end
        runtime.TeleportResumeError = reason
        return false
    end

    if envelope.Version ~= 1 or nonce == "" then
        return reject("invalid resume envelope")
    end
    if (tonumber(envelope.ExpiresAt) or 0) < os.time() then
        return reject("resume envelope expired")
    end
    if (tonumber(envelope.UniverseId) or 0) ~= 10516888336 or game.GameId ~= 10516888336 then
        return reject("resume universe mismatch")
    end
    if (tonumber(envelope.DestinationPlaceId) or 0) ~= game.PlaceId then
        return reject("resume destination mismatch")
    end
    if environment.__VORCatchBillionDucksResumeConsumed == nonce
        or environment.__VORCatchBillionDucksResumeClaimed == nonce then
        return reject("resume envelope was already consumed")
    end
    local valid, reason = validateResumeFlags(envelope.Flags)
    if not valid then
        return reject(reason)
    end
    local paused, pauseReason = pauseResumeToggles(runtime)
    if not paused then
        return reject(pauseReason)
    end

    local copied = {}
    for _, flag in ipairs(DUCK_RESUME_FLAGS) do
        copied[flag] = envelope.Flags[flag]
    end
    runtime.PendingResumeFlags = copied
    runtime.ResumeNonce = nonce
    environment.__VORCatchBillionDucksResume = nil
    environment.__VORCatchBillionDucksResumeClaimed = nonce
    if environment.__VORCatchBillionDucksResumeExecuting == nonce then
        environment.__VORCatchBillionDucksResumeExecuting = nil
    end
    return true
end

local function installDestinationResume(runtime)
    if not claimDestinationResume(runtime) then
        return false
    end

    local window = runtime.Window
    local applied = false
    local originalLoadProfile = window.LoadProfile
    local restored = false
    local function restoreLoadProfile()
        if not restored and window.LoadProfile ~= originalLoadProfile then
            window.LoadProfile = originalLoadProfile
        end
        restored = true
    end
    local function applyOnce()
        if applied or not runtime.Alive then
            return
        end
        applied = true
        restoreLoadProfile()
        applyClaimedResume(runtime)
    end

    local autoLoadEnabled = false
    if type(window.GetAutoLoad) == "function" then
        local ok, enabled, profileName = pcall(window.GetAutoLoad, window)
        autoLoadEnabled = ok and enabled == true and tostring(profileName or "") ~= ""
    end
    if autoLoadEnabled and type(originalLoadProfile) == "function" then
        window.LoadProfile = function(self, ...)
            local results = table.pack(originalLoadProfile(self, ...))
            restoreLoadProfile()
            task.defer(function()
                task.wait()
                applyOnce()
            end)
            return table.unpack(results, 1, results.n)
        end
        runtime.Connections[#runtime.Connections + 1] = {
            Disconnect = restoreLoadProfile,
        }
        task.delay(4, applyOnce)
    else
        applyOnce()
    end
    return true
end

local function toNumber(value)
    return tonumber(value) or 0
end

local function compactNumber(value)
    value = toNumber(value)
    local absolute = math.abs(value)
    if absolute >= 1e12 then
        return string.format("%.2fT", value / 1e12)
    elseif absolute >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif absolute >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif absolute >= 1e3 then
        return string.format("%.1fK", value / 1e3)
    end
    return tostring(math.floor(value + 0.5))
end

local function disconnectAll(connections)
    for index = #connections, 1, -1 do
        local connection = connections[index]
        connections[index] = nil
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function countEntries(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do
        count = count + 1
    end
    return count
end

local function hasMethod(value, method)
    return type(value) == "table" and type(value[method]) == "function"
end

local function createRuntime(context)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer
    local runtime = {
        Context = context,
        Window = context.Window,
        Gui = context.Gui,
        Colors = context.Colors or context.COLORS or {},
        Track = context.Track or function(connection)
            return connection
        end,
        LocalPlayer = LocalPlayer,
        VirtualUser = VirtualUser,
        Alive = true,
        Ready = false,
        FullProgression = false,
        AutoHunt = false,
        AutoSell = false,
        AutoWeapons = false,
        AutoUpgrades = false,
        AutoDogs = false,
        AutoCrates = false,
        AutoAchievements = false,
        AutoFreezer = false,
        AutoLastSession = false,
        AutoDailyQuests = false,
        AutoSkipDay = false,
        AutoQueue = false,
        AntiAfk = true,
        VisibilityCheck = true,
        TargetMode = "Boss > Value",
        Prediction = 0.13,
        SellInterval = 4,
        CashReserve = 0,
        FeatherReserve = 0,
        Shots = 0,
        Hits = 0,
        KillsAtStart = nil,
        Reloads = 0,
        Sales = 0,
        Purchases = 0,
        Claims = 0,
        TargetName = "None",
        Status = "Resolving game framework...",
        LastError = "None",
        LastShot = 0,
        LastSell = 0,
        LastProgress = 0,
        LastReward = 0,
        LastDog = 0,
        LastSkip = 0,
        LastLobbyChore = 0,
        AutomationReadyAt = os.clock() + 1.25,
        LobbyChoresReady = false,
        LobbyChoresBusy = false,
        LobbySettleUntil = os.clock() + 1.25,
        LastSessionChecked = false,
        DailyQuestStatus = "Not checked",
        QueueToken = nil,
        QueueChoosing = false,
        QueueZone = nil,
        QueueBusy = false,
        TeleportResumeQueued = false,
        TeleportResumeError = nil,
        SellBusy = false,
        ShotSequence = math.floor(workspace:GetServerTimeNow() * 1000) % 1000000000,
        ReloadSequence = math.floor(workspace:GetServerTimeNow() * 1000) % 1000000000,
        Connections = {},
        WeaponCatalog = {},
        DuckSnapshot = {},
        DuckSnapshotById = {},
        DuckSnapshotAt = 0,
        BossSnapshot = {},
        BossSnapshotById = {},
        BossSnapshotAt = 0,
        WeaponState = nil,
        WeaponStateAt = 0,
        WeaponStateTTL = 0.08,
        Capabilities = {},
    }

    local frameworkDeadline = os.clock() + 8
    repeat
        local pointer = ReplicatedStorage:FindFirstChild("UmePointer")
        if pointer and pointer.Value then
            local ok, value = pcall(require, pointer.Value)
            if ok and type(value) == "table" then
                runtime.V = value
                break
            end
            runtime.LastError = "Ume framework failed: " .. tostring(value)
        else
            runtime.LastError = "UmePointer is unavailable in this place"
        end
        task.wait(0.1)
    until runtime.V or os.clock() >= frameworkDeadline

    function runtime:SetStatus(message, success)
        self.Status = tostring(message)
        if self.StatusLabel then
            self.StatusLabel.Text = "Status: " .. self.Status
            self.StatusLabel.TextColor3 = success == false
                    and (self.Colors.error or Color3.fromRGB(255, 95, 125))
                or success == true
                    and (self.Colors.success or Color3.fromRGB(85, 255, 170))
                or (self.Colors.muted or Color3.fromRGB(190, 180, 210))
        end
    end

    function runtime:SetError(message)
        self.LastError = tostring(message)
        self:SetStatus(self.LastError, false)
    end

    function runtime:Call(callback, label)
        local ok, first, second = pcall(callback)
        if not ok then
            self:SetError((label or "Action") .. ": " .. tostring(first))
            return false, first
        end
        return true, first, second
    end

    function runtime:Currency(name)
        if not self.Capabilities.Currency then
            return 0
        end
        local ok, value = pcall(self.V.Currency.Get, name)
        return ok and toNumber(value) or 0
    end

    function runtime:IsLobby()
        return game.PlaceId == 100293509865504
            or self.V and self.V.Config and self.V.Config.PlaceLoader
                and self.V.Config.PlaceLoader.MapId == "Game_Lobby"
    end

    function runtime:RefreshCapabilities()
        local value = self.V or {}
        local network = type(value.Network) == "table"
            and type(value.Network.Invoke) == "function"
            and type(value.Network.Fire) == "function"
        self.Capabilities = {
            Network = network,
            Currency = hasMethod(value.Currency, "Get"),
            Weapons = hasMethod(value.Weapons, "GetState") and hasMethod(value.Weapons, "Equip"),
            Dogs = hasMethod(value.Dogs, "GetState"),
            Freezer = hasMethod(value.FreezerSkins, "GetState")
                and hasMethod(value.FreezerSkins, "GetCatalog")
                and hasMethod(value.FreezerSkins, "Equip"),
            Queue = hasMethod(value.Queue, "ChooseSize") and hasMethod(value.Queue, "CreateParty"),
            Sell = hasMethod(value.DuckController, "SellDucks"),
            Bosses = hasMethod(value.Bosses, "VoteSkipDay"),
        }
        if self:IsLobby() then
            self.Ready = network and self.Capabilities.Currency and self.Capabilities.Weapons
                and self.Capabilities.Dogs and self.Capabilities.Freezer and self.Capabilities.Queue
        else
            self.Ready = network and self.Capabilities.Currency
                and self.Capabilities.Sell and self.Capabilities.Bosses
        end
        return self.Capabilities
    end

    function runtime:CapabilitySummary()
        if self:IsLobby() then
            return self.Ready
                and "Lobby routes ready: weapons, dogs, freezer, rewards, and queue"
                or "Lobby framework is still resolving required routes"
        end
        return self.Ready
            and "Match routes ready: hunt, reload, sell, upgrades, and bosses"
            or "Match framework is still resolving required routes"
    end

    function runtime:Invoke(name, ...)
        if not self.Capabilities.Network then
            return nil
        end
        return self.V.Network.Invoke(name, ...)
    end

    runtime:RefreshCapabilities()

    function runtime:CharacterRoot()
        local character = LocalPlayer.Character
        return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    end

    function runtime:RefreshDuckSnapshot()
        if os.clock() - self.DuckSnapshotAt < 0.2 then
            return self.DuckSnapshot
        end
        self.DuckSnapshotAt = os.clock()
        local ok, snapshot = pcall(self.Invoke, self, "DuckController_GetSnapshot")
        local source = ok and type(snapshot) == "table" and (snapshot.Ducks or snapshot) or {}
        local list = {}
        local byId = {}
        for key, item in pairs(source) do
            if type(item) == "table" then
                list[#list + 1] = item
                local id = item.Id or item.InstanceId or item.DuckInstanceId or key
                if id ~= nil then
                    byId[tostring(id)] = item
                end
            end
        end
        self.DuckSnapshot = list
        self.DuckSnapshotById = byId
        return self.DuckSnapshot
    end

    function runtime:DuckInfoByModel(model)
        self:RefreshDuckSnapshot()
        local numericId = string.match(model.Name, "(%d+)$")
            or model:GetAttribute("Id") or model:GetAttribute("InstanceId")
        local duckId = model:GetAttribute("DuckId") or model:GetAttribute("AssetName")
        local state = model:GetAttribute("State")
        local item = numericId ~= nil and self.DuckSnapshotById[tostring(numericId)] or nil
        if item then
            duckId = item.DuckId or item.AssetName or duckId
            state = item.State or state
        end
        return duckId or "Duck", state
    end

    function runtime:RefreshBossSnapshot()
        if os.clock() - self.BossSnapshotAt < 0.2 then
            return self.BossSnapshot
        end
        self.BossSnapshotAt = os.clock()
        local ok, snapshot = pcall(self.Invoke, self, "BossController_GetSnapshot")
        local list = {}
        local byId = {}
        local fallback
        if ok and type(snapshot) == "table" then
            local source = snapshot.Bosses or snapshot
            if source == snapshot and (snapshot.State ~= nil or snapshot.Health ~= nil or snapshot.BossId ~= nil) then
                source = {snapshot}
            end
            for key, item in pairs(source) do
                if type(item) == "table" then
                    list[#list + 1] = item
                    fallback = fallback or item
                    local id = item.Id or item.InstanceId or item.BossInstanceId or item.BossId or key
                    if id ~= nil then
                        byId[tostring(id)] = item
                    end
                end
            end
        end
        self.BossSnapshot = list
        self.BossSnapshotById = byId
        self.BossSnapshotFallback = #list == 1 and fallback or nil
        return self.BossSnapshot
    end

    function runtime:BossInfoByModel(model)
        self:RefreshBossSnapshot()
        local numericId = string.match(model.Name, "(%d+)$")
            or model:GetAttribute("Id") or model:GetAttribute("InstanceId")
        local item = numericId ~= nil and self.BossSnapshotById[tostring(numericId)] or nil
        item = item or self.BossSnapshotFallback
        local name = model:GetAttribute("BossId") or model:GetAttribute("AssetName") or model.Name
        local state = model:GetAttribute("State")
        local health = model:GetAttribute("Health")
        if item then
            name = item.BossId or item.AssetName or item.Name or name
            state = item.State or state
            health = item.Health or item.CurrentHealth or health
        end
        return name, state, health
    end

    function runtime:Visible(origin, part, model)
        if not self.VisibilityCheck then
            return true
        end
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Exclude
        parameters.IgnoreWater = true
        parameters.FilterDescendantsInstances = {LocalPlayer.Character}
        local result = workspace:Raycast(origin, part.Position - origin, parameters)
        return result == nil or result.Instance:IsDescendantOf(model)
    end

    function runtime:FindTarget()
        local ume = workspace:FindFirstChild("Ume")
        local camera = workspace.CurrentCamera
        local root = self:CharacterRoot()
        local origin = camera and camera.CFrame.Position or root and root.Position
        if not ume or not origin then
            return nil, "None"
        end

        local bosses = {}
        local ducks = {}
        self:RefreshDuckSnapshot()
        self:RefreshBossSnapshot()
        for _, model in ipairs(ume:GetChildren()) do
            if model:IsA("Model") then
                local isBoss = string.find(model.Name, "BossController_Client_", 1, true) ~= nil
                local isDuck = string.find(model.Name, "DuckController_Client_", 1, true) ~= nil
                if isBoss or isDuck then
                    local part = model:FindFirstChild("Hitbox", true) or model.PrimaryPart
                    if part and part:IsA("BasePart") and self:Visible(origin, part, model) then
                        local distance = (part.Position - origin).Magnitude
                        if distance <= 1000 then
                            if isBoss then
                                local bossName, bossState, bossHealth = self:BossInfoByModel(model)
                                local bossAlive = bossHealth == nil or toNumber(bossHealth) > 0
                                if bossAlive and (bossState == "Flying" or bossState == "Attacking") then
                                    bosses[#bosses + 1] = {
                                        Part = part,
                                        Model = model,
                                        Distance = distance,
                                        Name = bossName,
                                    }
                                end
                            else
                                local duckId, duckState = self:DuckInfoByModel(model)
                                if duckState == nil or duckState == "Flying" or duckState == "Attacking" then
                                    ducks[#ducks + 1] = {
                                        Part = part,
                                        Model = model,
                                        Distance = distance,
                                        Name = duckId,
                                        Value = DUCK_VALUES[duckId] or 0,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end

        local function closest(list)
            table.sort(list, function(a, b)
                return a.Distance < b.Distance
            end)
            return list[1]
        end
        local function valuable(list)
            table.sort(list, function(a, b)
                if a.Value == b.Value then
                    return a.Distance < b.Distance
                end
                return a.Value > b.Value
            end)
            return list[1]
        end

        local selected
        if self.TargetMode == "Closest" then
            local all = {}
            for _, item in ipairs(bosses) do
                all[#all + 1] = item
            end
            for _, item in ipairs(ducks) do
                all[#all + 1] = item
            end
            selected = closest(all)
        elseif self.TargetMode == "Most Valuable" then
            selected = valuable(ducks) or closest(bosses)
        else
            selected = closest(bosses) or valuable(ducks)
        end
        return selected and selected.Part, selected and selected.Name or "None"
    end

    function runtime:GetWeaponState(force)
        local now = os.clock()
        if not force and type(self.WeaponState) == "table"
            and now - self.WeaponStateAt < self.WeaponStateTTL then
            return self.WeaponState
        end
        local ok, result = pcall(self.Invoke, self, "WeaponController_GetState")
        if not ok or type(result) ~= "table" then
            return self.WeaponState
        end
        local copy = {}
        for key, value in pairs(result) do
            copy[key] = value
        end
        if type(result.Stats) == "table" then
            copy.Stats = {}
            for key, value in pairs(result.Stats) do
                copy.Stats[key] = value
            end
        end
        self.WeaponState = copy
        self.WeaponStateAt = now
        return copy
    end

    function runtime:HuntStep()
        local now = os.clock()
        if now < (self.NextShotAt or 0) then
            return
        end
        local weapon = self:GetWeaponState(false)
        if type(weapon) ~= "table" then
            return
        end
        local stats = weapon.Stats or {}
        if weapon.Reloading then
            return
        end
        local ammo = toNumber(weapon.Ammo or weapon.CurrentAmmo)
        if ammo <= 0 then
            self.ReloadSequence = self.ReloadSequence + 1
            self.V.Network.Fire("WeaponController_Reload", self.ReloadSequence)
            self.Reloads = self.Reloads + 1
            weapon.Reloading = true
            self.NextShotAt = now + math.max(toNumber(stats.ReloadSpeed), 0.15)
            return
        end
        local attackSpeed = math.max(toNumber(stats.AttackSpeed), 0.04)
        local target, targetName = self:FindTarget()
        self.TargetName = targetName
        if not target then
            return
        end
        local camera = workspace.CurrentCamera
        local root = self:CharacterRoot()
        local origin = camera and camera.CFrame.Position or root and root.Position
        if not origin then
            return
        end
        local velocity = target.AssemblyLinearVelocity or Vector3.zero
        local delta = target.Position + velocity * self.Prediction - origin
        if delta.Magnitude < 0.1 then
            return
        end
        self.ShotSequence = self.ShotSequence + 1
        self.V.Network.Fire(
            "WeaponController_Shoot",
            origin,
            delta.Unit,
            self.ShotSequence,
            workspace:GetServerTimeNow()
        )
        self.Shots = self.Shots + 1
        weapon.Ammo = math.max(0, ammo - 1)
        if weapon.CurrentAmmo ~= nil then
            weapon.CurrentAmmo = weapon.Ammo
        end
        self.LastShot = now
        self.NextShotAt = now + attackSpeed
    end

    function runtime:SellNow(manual)
        if self.SellBusy or not self.Capabilities.Sell then
            return false
        end
        self.SellBusy = true
        local beforeState = self:Invoke("DuckController_GetInteractionState") or {}
        local beforeStorage = toNumber(beforeState.StorageCount)
        local beforeCash = self:Currency("Cash")
        local ok = self:Call(function()
            return self.V.DuckController.SellDucks()
        end, "Sell ducks")
        self.LastSell = os.clock()
        if ok then
            task.wait(0.25)
        end
        local afterState = self:Invoke("DuckController_GetInteractionState") or {}
        local sold = ok and beforeStorage > 0 and (
            toNumber(afterState.StorageCount) < beforeStorage or self:Currency("Cash") > beforeCash
        )
        self.SellBusy = false
        if sold then
            self.Sales = self.Sales + 1
            if manual then
                self:SetStatus("Storage sale verified by the server state", true)
            end
        elseif manual then
            self:SetStatus(beforeStorage <= 0 and "Storage is already empty" or "Sell request was not confirmed", false)
        end
        return sold
    end

    function runtime:LoadWeaponCatalog()
        if #self.WeaponCatalog > 0 then
            return self.WeaponCatalog
        end
        local data = game:GetService("ReplicatedStorage").Instance.Modules.Main.Weapons.Data.Weapons
        for _, module in ipairs(data:GetChildren()) do
            if module:IsA("ModuleScript") then
                local ok, config = pcall(require, module)
                if ok and type(config) == "table" and config.PurchaseType == "Feathers"
                    and config.AvailableForPurchase ~= false then
                    self.WeaponCatalog[#self.WeaponCatalog + 1] = config
                end
            end
        end
        table.sort(self.WeaponCatalog, function(a, b)
            return toNumber(a.Price) > toNumber(b.Price)
        end)
        return self.WeaponCatalog
    end

    function runtime:NextMissingWeaponCost()
        if not self.Ready or not self.V.Weapons then
            return nil
        end
        local state = self.V.Weapons.GetState()
        local owned = {}
        for _, item in ipairs(state and state.Owned or {}) do
            owned[item.Id] = true
        end
        local nextCost
        for _, config in ipairs(self:LoadWeaponCatalog()) do
            if not owned[config.Id] then
                local price = toNumber(config.Price)
                if not nextCost or price < nextCost then
                    nextCost = price
                end
            end
        end
        return nextCost
    end

    function runtime:BuyAndEquipBestWeapon(manual)
        if not self.Ready or not self.V.Weapons then
            return false
        end
        local weaponState = self.V.Weapons.GetState()
        local ownedById = {}
        for _, owned in ipairs(weaponState and weaponState.Owned or {}) do
            ownedById[owned.Id] = owned
        end
        local feathers = self:Currency("Feathers") - self.FeatherReserve
        local selected
        for _, config in ipairs(self:LoadWeaponCatalog()) do
            if ownedById[config.Id] or toNumber(config.Price) <= feathers then
                selected = config
                break
            end
        end
        if not selected then
            return false
        end
        local owned = ownedById[selected.Id]
        if not owned then
            if not self:IsLobby() then
                if manual then
                    self:SetStatus("Weapon purchases are queued for the lobby; hunting continues here")
                end
                return false
            end
            local result = self.V.Weapons.Buy(selected.Id)
            if not result then
                return false
            end
            task.wait(0.15)
            weaponState = self.V.Weapons.GetState()
            for _, item in ipairs(weaponState and weaponState.Owned or {}) do
                if item.Id == selected.Id then
                    owned = item
                    break
                end
            end
            if owned then
                self.Purchases = self.Purchases + 1
            end
        end
        if owned and weaponState.EquippedUUID ~= owned.UUID then
            local requested = self.V.Weapons.Equip(owned.UUID)
            if requested ~= false then
                task.wait(0.1)
                weaponState = self.V.Weapons.GetState()
            end
        end
        local equipped = owned and weaponState and weaponState.EquippedUUID == owned.UUID
        if manual then
            self:SetStatus(
                equipped and ("Best weapon equipped: " .. tostring(selected.Name))
                    or ("Weapon equip was not confirmed: " .. tostring(selected.Name)),
                equipped
            )
        end
        return equipped
    end

    function runtime:UpgradeCandidates()
        local upgradeState = self:Invoke("Upgrades_GetState")
        if type(upgradeState) ~= "table" then
            return {}
        end
        local candidates = {}
        local function add(category, stat, entry, uuid)
            if type(entry) == "table" and toNumber(entry.Level) < toNumber(entry.MaxLevel)
                and toNumber(entry.Price) > 0 then
                candidates[#candidates + 1] = {
                    Category = category,
                    Stat = stat,
                    Price = toNumber(entry.Price),
                    UUID = uuid,
                }
            end
        end
        if type(upgradeState.Duck) == "table" then
            add("Duck", "SpawnRate", upgradeState.Duck)
            add("Duck", "Luck", upgradeState.Duck.Luck)
        end
        if type(upgradeState.Weapon) == "table" then
            local stats = upgradeState.Weapon.Stats or {}
            add("Weapon", "Damage", stats.Damage, upgradeState.Weapon.UUID)
            add("Weapon", "AmmoCount", stats.AmmoCount, upgradeState.Weapon.UUID)
            add("Weapon", "ReloadSpeed", stats.ReloadSpeed, upgradeState.Weapon.UUID)
        end
        if type(upgradeState.Dog) == "table" then
            local stats = upgradeState.Dog.Stats or {}
            add("Dog", "Speed", stats.Speed, upgradeState.Dog.UUID)
            add("Dog", "Strength", stats.Strength, upgradeState.Dog.UUID)
            add("Dog", "Dexterity", stats.Dexterity, upgradeState.Dog.UUID)
        end
        table.sort(candidates, function(a, b)
            return a.Price < b.Price
        end)
        return candidates
    end

    function runtime:BuyCheapestUpgrade(manual)
        local spendable = self:Currency("Cash") - self.CashReserve
        for _, candidate in ipairs(self:UpgradeCandidates()) do
            if candidate.Price <= spendable then
                local success = self:Invoke(
                    "Upgrades_Purchase",
                    candidate.Category,
                    candidate.Stat,
                    candidate.UUID
                )
                if success then
                    self.Purchases = self.Purchases + 1
                    if manual then
                        self:SetStatus(
                            string.format("Bought %s %s for %s", candidate.Category, candidate.Stat, compactNumber(candidate.Price)),
                            true
                        )
                    end
                    return true
                end
            end
        end
        if manual then
            self:SetStatus("No useful cash upgrade is currently affordable")
        end
        return false
    end

    function runtime:ManageDogs(manual)
        if not self.Ready or not self.V.Dogs then
            return false
        end
        local dogState = self.V.Dogs.GetState()
        local slots = dogState and dogState.UnlockedSlots or {}
        local weaponReserve = self:NextMissingWeaponCost() or 0
        local feathers = self:Currency("Feathers") - math.max(self.FeatherReserve, weaponReserve)
        if #slots < 2 and feathers >= 900 and self.V.Dogs.UnlockSlotWithFeathers then
            local unlocked = self.V.Dogs.UnlockSlotWithFeathers()
            if unlocked then
                self.Purchases = self.Purchases + 1
                feathers = feathers - 900
            end
        end
        if self.V.Dogs.EquipBest then
            self.V.Dogs.EquipBest()
        elseif self.V.Dogs.EquipBestInventory then
            self.V.Dogs.EquipBestInventory()
        end
        if manual then
            self:SetStatus("Best dogs equipped; feather slot checked", true)
        end
        return true
    end

    function runtime:BuyDogCrate(manual, progressionSafe)
        if progressionSafe then
            local dogState = self.V.Dogs and self.V.Dogs.GetState and self.V.Dogs.GetState()
            local slots = dogState and dogState.UnlockedSlots or {}
            if self:NextMissingWeaponCost() or #slots < 2 then
                if manual then
                    self:SetStatus("Crates wait until non-Robux weapons and dog slot 2 are secured")
                end
                return false
            end
        end
        if self:Currency("Feathers") - self.FeatherReserve < 150 then
            if manual then
                self:SetStatus("Dog crate needs 150 spendable feathers")
            end
            return false
        end
        local results, reason = self:Invoke("Gacha_BuyCrate", "Dogs_Crate")
        if results then
            self.Purchases = self.Purchases + 1
            if self.V.Dogs and self.V.Dogs.EquipBest then
                task.defer(self.V.Dogs.EquipBest)
            end
            if manual then
                self:SetStatus("Dog crate opened and best team refreshed", true)
            end
            return true
        end
        if manual then
            self:SetError("Dog crate: " .. tostring(reason or "not available"))
        end
        return false
    end

    function runtime:EquipBestFreezer(manual)
        if not self.Ready or not self.V.FreezerSkins then
            return false
        end
        local state = self.V.FreezerSkins.GetState()
        local catalog = self.V.FreezerSkins.GetCatalog()
        local selected
        for id, config in pairs(catalog or {}) do
            if state and state.OwnedSkinIds and state.OwnedSkinIds[id]
                and (not selected or toNumber(config.CashMultiplier) > toNumber(selected.CashMultiplier)) then
                selected = config
            end
        end
        if not selected then
            return false
        end
        if state.EquippedSkinId ~= selected.Id then
            local equipped = self.V.FreezerSkins.Equip(selected.Id)
            if not equipped then
                return false
            end
        end
        if manual then
            self:SetStatus("Best owned freezer: " .. tostring(selected.Name), true)
        end
        return true
    end

    function runtime:ClaimAchievements(manual)
        local achievementState = self:Invoke("Achievements_GetState")
        local claimed = 0
        for _, achievement in ipairs(achievementState and achievementState.Achievements or {}) do
            if achievement.Completed and not achievement.Claimed then
                local success = self:Invoke("Achievements_ClaimReward", achievement.Id)
                if success then
                    claimed = claimed + 1
                end
            end
        end
        self.Claims = self.Claims + claimed
        if manual then
            self:SetStatus(claimed > 0 and ("Claimed " .. claimed .. " achievement reward(s)") or "No achievement reward is ready", claimed > 0)
        end
        return claimed
    end

    function runtime:ClaimLastSession(manual)
        if not self:IsLobby() or not self.Capabilities.Network then
            return false
        end
        local session = self:Invoke("Respawn_Controller_GetLastSession")
        self.LastSessionChecked = true
        if type(session) ~= "table" then
            if manual then
                self:SetStatus("No previous-session feathers are waiting")
            end
            return true
        end
        local success = self:Invoke("Respawn_Controller_ClaimLastSession")
        if success then
            self.Claims = self.Claims + 1
            self.LobbySettleUntil = os.clock() + 0.75
            if manual then
                self:SetStatus("Previous-session feathers claimed", true)
            end
            return true
        end
        if manual then
            self:SetStatus("Previous-session reward was not confirmed", false)
        end
        return false
    end

    function runtime:DailyQuestsActive()
        local state = self:Invoke("DailyQuests_GetState")
        local active = type(state) == "table" and countEntries(state.Quests) > 0
        return active, state
    end

    function runtime:RollDailyQuests(manual)
        if not self:IsLobby() or not self.Capabilities.Network then
            return false
        end
        local active, state = self:DailyQuestsActive()
        if active then
            self.DailyQuestStatus = string.format("%d quests active", countEntries(state.Quests))
            if manual then
                self:SetStatus("Daily quests are already active", true)
            end
            return true
        end
        if type(fireproximityprompt) ~= "function" then
            self.DailyQuestStatus = "Executor cannot fire quest prompt"
            if manual then
                self:SetStatus(self.DailyQuestStatus, false)
            end
            return false
        end
        local prompt
        for _, machine in ipairs(game:GetService("CollectionService"):GetTagged("Quest_Machine")) do
            prompt = machine:FindFirstChild("DailyQuestPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") then
                break
            end
            prompt = nil
        end
        local root = self:CharacterRoot()
        local promptPart = prompt and prompt.Parent
        if not root or not promptPart or not promptPart:IsA("BasePart") then
            self.DailyQuestStatus = "Daily quest machine unavailable"
            return false
        end
        local character = LocalPlayer.Character
        local original = root.CFrame
        local moved = (root.Position - promptPart.Position).Magnitude > math.max(prompt.MaxActivationDistance - 1, 3)
        if moved then
            root.CFrame = promptPart.CFrame * CFrame.new(0, 0, -2)
            task.wait(0.2)
        end
        local fired = pcall(fireproximityprompt, prompt)
        local verified = false
        local deadline = os.clock() + 5
        repeat
            task.wait(0.25)
            verified = self:DailyQuestsActive()
        until verified or os.clock() >= deadline or not self.Alive
        if moved and LocalPlayer.Character == character and root.Parent
            and (root.Position - promptPart.Position).Magnitude <= 12 and not self.QueueBusy then
            root.CFrame = original
        end
        self.DailyQuestStatus = verified and "3 quests active" or "Daily roll was not confirmed"
        if manual then
            self:SetStatus(self.DailyQuestStatus, verified)
        end
        if fired and verified then
            self.LobbySettleUntil = os.clock() + 0.75
        end
        return fired and verified
    end

    function runtime:RunLobbyChores()
        if self.LobbyChoresBusy or not self:IsLobby() then
            return self.LobbyChoresReady
        end
        self.LobbyChoresBusy = true
        local changed = false
        local ok, errorMessage = xpcall(function()
            local lastSessionReady = true
            if self.FullProgression or self.AutoLastSession then
                local beforeClaims = self.Claims
                local callOk, result = pcall(self.ClaimLastSession, self, false)
                lastSessionReady = callOk and result == true
                changed = changed or self.Claims > beforeClaims
            end
            local dailyReady = true
            if self.FullProgression or self.AutoDailyQuests then
                local callOk, result = pcall(self.RollDailyQuests, self, false)
                dailyReady = callOk and result == true
            end
            local weaponReady = true
            if self.FullProgression or self.AutoWeapons then
                local beforePurchases = self.Purchases
                local callOk, result = pcall(self.BuyAndEquipBestWeapon, self, false)
                weaponReady = callOk and result == true
                changed = changed or self.Purchases > beforePurchases
            end
            local dogsReady = true
            if self.FullProgression or self.AutoDogs then
                local callOk, result = pcall(self.ManageDogs, self, false)
                dogsReady = callOk and result == true
            end
            local freezerReady = true
            if self.FullProgression or self.AutoFreezer then
                local callOk, result = pcall(self.EquipBestFreezer, self, false)
                freezerReady = callOk and result == true
            end
            self.LobbyChoresReady = lastSessionReady and dailyReady and weaponReady and dogsReady and freezerReady
        end, function(message)
            return type(debug) == "table" and type(debug.traceback) == "function"
                and debug.traceback(message, 2) or tostring(message)
        end)
        if changed then
            self.LobbySettleUntil = os.clock() + 1
        end
        self.LobbyChoresBusy = false
        if not ok then
            self.LobbyChoresReady = false
            self:SetError("Lobby chores: " .. tostring(errorMessage))
            return false
        end
        return self.LobbyChoresReady and os.clock() >= self.LobbySettleUntil
    end

    function runtime:VoteSkip(manual)
        local voteState = self:Invoke("BossController_GetSkipVoteState")
        if not voteState or not voteState.Available then
            return false
        end
        for _, player in ipairs(voteState.Players or {}) do
            if tonumber(player.UserId) == LocalPlayer.UserId and player.Voted then
                return false
            end
        end
        local ok = self:Call(function()
            return self.V.Bosses.VoteSkipDay()
        end, "Skip vote")
        local verified = false
        if ok then
            local deadline = os.clock() + 1.5
            repeat
                task.wait(0.15)
                voteState = self:Invoke("BossController_GetSkipVoteState")
                for _, player in ipairs(voteState and voteState.Players or {}) do
                    if tonumber(player.UserId) == LocalPlayer.UserId and player.Voted then
                        verified = true
                        break
                    end
                end
            until verified or os.clock() >= deadline
        end
        if manual then
            self:SetStatus(
                verified and "Day skip vote verified" or "Day skip vote was not confirmed",
                verified
            )
        end
        return verified
    end

    function runtime:IsQueueWidgetOpen()
        local widgetManager = self.V and self.V.WidgetManager
        if widgetManager and type(widgetManager.GetCurrent) == "function" then
            local ok, current = pcall(widgetManager.GetCurrent)
            if ok and current and tostring(current.Name) == "Party_Queue" then
                return true
            end
        end
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local leave = playerGui and playerGui:FindFirstChild("S_QueueLeave", true)
        return leave and leave:IsA("GuiObject") and leave.Visible == true or false
    end

    function runtime:IsLocallyQueued()
        local root = self:CharacterRoot()
        local zone = self.QueueZone
        return (self.QueueToken ~= nil or self:IsQueueWidgetOpen())
            and root ~= nil and zone ~= nil and zone.Parent ~= nil and zone.PrimaryPart ~= nil
            and (root.Position - zone.PrimaryPart.Position).Magnitude <= 8
            and toNumber(zone:GetAttribute("Queue_PlayersIn")) > 0
    end

    function runtime:ResolveTeleportQueue()
        local environment = type(getgenv) == "function" and getgenv() or _G
        if type(environment.queue_on_teleport) == "function" then
            return environment.queue_on_teleport
        elseif type(environment.queueonteleport) == "function" then
            return environment.queueonteleport
        elseif type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
            return syn.queue_on_teleport
        elseif type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
            return fluxus.queue_on_teleport
        end
        return nil
    end

    function runtime:PrepareTeleportResume(destinationPlaceId)
        destinationPlaceId = toNumber(destinationPlaceId)
        if destinationPlaceId ~= 100293509865504 and destinationPlaceId ~= 120617974337690 then
            return false, "unsupported resume destination"
        end
        if self.TeleportResumeQueued then
            return true
        end
        local queue = self:ResolveTeleportQueue()
        if type(queue) ~= "function" then
            return false, "executor has no teleport queue API"
        end

        local commit = tostring(self.Context.Commit or "")
        if #commit ~= 40 or not commit:match("^[0-9a-f]+$") then
            return false, "reviewed module commit is invalid"
        end
        local values, snapshotReason = snapshotResumeFlags(self.Window)
        if not values then
            return false, snapshotReason
        end

        local HttpService = game:GetService("HttpService")
        local json = HttpService:JSONEncode(values)
        local nonce = HttpService:GenerateGUID(false)
        local expiresAt = os.time() + (destinationPlaceId == 120617974337690 and 90 or 60)
        local allowRows = {}
        for _, flag in ipairs(DUCK_RESUME_FLAGS) do
            allowRows[#allowRows + 1] = "[" .. luaQuote(flag) .. "]=true"
        end
        local payload = table.concat({
            "local NONCE=" .. luaQuote(nonce),
            "local EXPIRES_AT=" .. tostring(expiresAt),
            "local EXPECTED_UNIVERSE=10516888336",
            "local EXPECTED_PLACE=" .. tostring(destinationPlaceId),
            "local COMMIT=" .. luaQuote(commit),
            "local FLAG_JSON=" .. luaQuote(json),
            "local ALLOWED={" .. table.concat(allowRows, ",") .. "}",
            "repeat task.wait() until game:IsLoaded()",
            "local Players=game:GetService(\"Players\")",
            "local deadline=os.clock()+30",
            "while not Players.LocalPlayer and os.clock()<deadline do task.wait(0.05) end",
            "if not Players.LocalPlayer or os.time()>EXPIRES_AT then return end",
            "if game.GameId~=EXPECTED_UNIVERSE or game.PlaceId~=EXPECTED_PLACE then return end",
            "local env=type(getgenv)==\"function\" and getgenv() or _G",
            "if env.__VORCatchBillionDucksResumeExecuting==NONCE or env.__VORCatchBillionDucksResumeConsumed==NONCE then return end",
            "env.__VORCatchBillionDucksResumeExecuting=NONCE",
            "local function clearFailed(message)",
            " local saved=env.__VORCatchBillionDucksResume",
            " if type(saved)==\"table\" and saved.Nonce==NONCE then env.__VORCatchBillionDucksResume=nil end",
            " if env.__VORCatchBillionDucksResumeExecuting==NONCE then env.__VORCatchBillionDucksResumeExecuting=nil end",
            " warn(\"[VOR Hub] Duck resume aborted: \"..tostring(message))",
            "end",
            "local trace=type(debug)==\"table\" and type(debug.traceback)==\"function\" and debug.traceback or tostring",
            "local ok,err=xpcall(function()",
            " local decoded=game:GetService(\"HttpService\"):JSONDecode(FLAG_JSON)",
            " if type(decoded)~=\"table\" then error(\"resume flags did not decode\") end",
            " local count=0",
            " for flag in pairs(ALLOWED) do",
            "  local kind=type(decoded[flag])",
            "  if kind~=\"boolean\" and kind~=\"number\" and kind~=\"string\" then error(\"missing/invalid flag: \"..flag) end",
            "  count+=1",
            " end",
            " for flag in pairs(decoded) do if not ALLOWED[flag] then error(\"unexpected flag: \"..tostring(flag)) end end",
            " if count~=" .. tostring(#DUCK_RESUME_FLAGS) .. " then error(\"resume allowlist count mismatch\") end",
            " env.__VORCatchBillionDucksResume={Version=1,Nonce=NONCE,ExpiresAt=EXPIRES_AT,UniverseId=EXPECTED_UNIVERSE,DestinationPlaceId=EXPECTED_PLACE,Flags=decoded}",
            " local url=\"https://raw.githubusercontent.com/swatdiaz/VOR-HUB/\"..COMMIT..\"/loader.lua\"",
            " local source=game:HttpGet(url)",
            " if type(source)~=\"string\" or source==\"\" then error(\"pinned loader download was empty\") end",
            [=[ local patched,replacements=source:gsub('local COMMIT = "%x+"','local COMMIT = "'..COMMIT..'"')]=],
            " if replacements~=1 then error(\"expected exactly one loader COMMIT literal; got \"..tostring(replacements)) end",
            " local chunk,compileError=loadstring(patched)",
            " if not chunk then error(\"pinned loader compile failed: \"..tostring(compileError)) end",
            " chunk()",
            "end,trace)",
            "if not ok then clearFailed(err) return end",
            "local leftover=env.__VORCatchBillionDucksResume",
            "if type(leftover)==\"table\" and leftover.Nonce==NONCE then clearFailed(\"destination module did not claim resume state\") return end",
            "if env.__VORCatchBillionDucksResumeExecuting==NONCE then env.__VORCatchBillionDucksResumeExecuting=nil end",
        }, "\n")

        local queued, queueError = pcall(queue, payload)
        if not queued then
            return false, "teleport resume queue failed: " .. tostring(queueError)
        end
        self.TeleportResumeQueued = true
        self.TeleportResumeNonce = nonce
        self.TeleportResumeExpiresAt = expiresAt
        self.TeleportResumeError = nil
        return true
    end

    function runtime:QueueSolo(manual)
        if self.QueueBusy or not self:IsLobby() or not self.Capabilities.Queue then
            return false
        end
        if self:IsLocallyQueued() and self.QueueZone
            and tostring(self.QueueZone:GetAttribute("Queue_State")) == "Party"
            and toNumber(self.QueueZone:GetAttribute("Queue_PartySize")) == 1 then
            return true
        end
        local root = self:CharacterRoot()
        if not root then
            return false
        end
        local candidates = {}
        for _, model in ipairs(game:GetService("CollectionService"):GetTagged("Queue_Zone")) do
            if model:GetAttribute("Queue_ZoneId") == "Main_Game" and model:IsA("Model") and model.PrimaryPart
                and tostring(model:GetAttribute("Queue_State") or "Idle") == "Idle"
                and toNumber(model:GetAttribute("Queue_PlayersIn")) == 0 then
                candidates[#candidates + 1] = model
            end
        end
        table.sort(candidates, function(a, b)
            return (a.PrimaryPart.Position - root.Position).Magnitude < (b.PrimaryPart.Position - root.Position).Magnitude
        end)
        local queueZone = candidates[1]
        if not queueZone then
            if manual then
                self:SetStatus("Every solo queue pad is busy; waiting")
            end
            return false
        end
        if not self:ResolveTeleportQueue() then
            self.TeleportResumeError = "executor has no teleport queue API"
            if manual then
                self:SetStatus("Cannot queue safely: " .. self.TeleportResumeError, false)
            end
            return false
        end
        self.QueueBusy = true
        self.QueueZone = queueZone
        root.CFrame = queueZone.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
        local opened = false
        local openDeadline = os.clock() + 5
        repeat
            task.wait(0.1)
            opened = self.QueueToken ~= nil or self:IsQueueWidgetOpen()
        until opened or os.clock() >= openDeadline or not self.Alive
        if not opened then
            self.QueueBusy = false
            self.QueueZone = nil
            if manual then
                self:SetStatus("Queue pad did not recognize the player", false)
            end
            return false
        end
        local resumeOk, resumeReason = self:PrepareTeleportResume(120617974337690)
        if not resumeOk then
            self.TeleportResumeError = resumeReason
            pcall(self.V.Queue.Leave)
            self.QueueBusy = false
            self.QueueZone = nil
            if manual then
                self:SetStatus("Cannot queue safely: " .. tostring(resumeReason), false)
            end
            return false
        end
        local ok = self:Call(function()
            self.V.Queue.ChooseSize(1)
            task.wait(0.15)
            self.V.Queue.CreateParty()
        end, "Solo queue")
        local verified = false
        local deadline = os.clock() + 4
        repeat
            task.wait(0.1)
            verified = self:IsLocallyQueued()
                and tostring(queueZone:GetAttribute("Queue_State")) == "Party"
                and toNumber(queueZone:GetAttribute("Queue_PartySize")) == 1
        until verified or os.clock() >= deadline or not self.Alive
        self.QueueBusy = false
        if not verified then
            self.QueueZone = nil
        end
        if manual then
            self:SetStatus(verified and "Solo run queue verified" or "Solo queue was not confirmed", verified)
        end
        return ok and verified
    end

    function runtime:UpdateTelemetry()
        local interaction = self:Invoke("DuckController_GetInteractionState") or {}
        local boss = self:Invoke("BossController_GetSnapshot") or {}
        local weapon = self:GetWeaponState(false) or {}
        local run = self:Invoke("Respawn_Controller_GetCurrentStats") or {}
        local duckCount = #self:RefreshDuckSnapshot()
        local kills = toNumber(run.DucksKilled)
        if self.KillsAtStart == nil then
            self.KillsAtStart = kills
        end
        if self.HuntLabel then
            self.HuntLabel.Text = string.format(
                "Target: %s | Shot requests: %d | Confirmed hits: %d",
                tostring(self.TargetName),
                self.Shots,
                self.Hits
            )
            self.WorldLabel.Text = string.format(
                "Day %s | %s | Ducks: %d | Storage: %s",
                tostring(boss.Day or "?"),
                tostring(boss.Phase or boss.State or "Day"),
                duckCount,
                tostring(interaction.StorageCount or 0)
            )
            self.EconomyLabel.Text = string.format(
                "Cash: %s | Feathers: %s | Weapon: %s | Ammo: %s",
                compactNumber(self:Currency("Cash")),
                compactNumber(self:Currency("Feathers")),
                tostring(weapon.EquippedWeaponId or weapon.Equipped or "Equipped"),
                tostring(weapon.Ammo or weapon.CurrentAmmo or "?")
            )
            self.ProgressLabel.Text = string.format(
                "Run kills: %s | Module kills: %s | Purchases: %d | Claims: %d",
                compactNumber(kills),
                compactNumber(math.max(kills - (self.KillsAtStart or kills), 0)),
                self.Purchases,
                self.Claims
            )
            self.ErrorLabel.Text = "Last error: " .. self.LastError
        end
        if self.Gui then
            pcall(function()
                self.Gui:SetAttribute("CatchBillionDucksAdapter", true)
                self.Gui:SetAttribute("CatchBillionDucksFullProgression", self.FullProgression)
                self.Gui:SetAttribute("CatchBillionDucksShots", self.Shots)
                self.Gui:SetAttribute("CatchBillionDucksHits", self.Hits)
                self.Gui:SetAttribute("CatchBillionDucksTarget", self.TargetName)
                self.Gui:SetAttribute("CatchBillionDucksDay", boss.Day or 0)
                self.Gui:SetAttribute("CatchBillionDucksCash", self:Currency("Cash"))
                self.Gui:SetAttribute("CatchBillionDucksFeathers", self:Currency("Feathers"))
                self.Gui:SetAttribute("CatchBillionDucksLastError", self.LastError)
            end)
        end
    end

    function runtime:Stop()
        if not self.Alive then
            return
        end
        self.Alive = false
        disconnectAll(self.Connections)
        if getgenv then
            local environment = getgenv()
            if environment.__VORCatchBillionDucksCleanup then
                environment.__VORCatchBillionDucksCleanup = nil
            end
        end
    end

    function runtime:Start()
        local capabilityDeadline = os.clock() + 8
        repeat
            self:RefreshCapabilities()
            if self.Ready then
                break
            end
            task.wait(0.1)
        until os.clock() >= capabilityDeadline
        if not self.Ready then
            self:SetError(self:CapabilitySummary())
            return
        end
        self:SetStatus(self:CapabilitySummary(), self.Ready)
        if self:IsLobby() then
            local okOpen, openConnection = pcall(function()
                return self.V.Network.Fired("Queue_OpenPartyQueue", function(token, choosing)
                    self.QueueToken = token
                    self.QueueChoosing = choosing == true
                end)
            end)
            if okOpen and openConnection then
                self.Connections[#self.Connections + 1] = openConnection
            end
            local okClose, closeConnection = pcall(function()
                return self.V.Network.Fired("Queue_ClosePartyQueue", function(token)
                    if token == nil or self.QueueToken == token then
                        self.QueueToken = nil
                        self.QueueChoosing = false
                        self.QueueZone = nil
                    end
                end)
            end)
            if okClose and closeConnection then
                self.Connections[#self.Connections + 1] = closeConnection
            end
        end
        local ok, hitConnection = pcall(function()
            return self.V.Network.Fired("WeaponController_HitConfirm", function()
                self.Hits = self.Hits + 1
            end)
        end)
        if ok and hitConnection then
            self.Connections[#self.Connections + 1] = hitConnection
        end
        self.Connections[#self.Connections + 1] = LocalPlayer.Idled:Connect(function()
            if self.Alive and self.AntiAfk then
                pcall(function()
                    self.VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
                    task.wait(0.1)
                    self.VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
                end)
            end
        end)
        self.Connections[#self.Connections + 1] = LocalPlayer.CharacterAdded:Connect(function()
            self.WeaponState = nil
            self.WeaponStateAt = 0
            self.DuckSnapshotAt = 0
            self.BossSnapshotAt = 0
            self.AutomationReadyAt = os.clock() + 1
        end)
        self.Connections[#self.Connections + 1] = LocalPlayer.OnTeleport:Connect(function(teleportState, placeId)
            if teleportState == Enum.TeleportState.Started and (self.FullProgression or self.AutoQueue) then
                placeId = toNumber(placeId)
                if placeId == 100293509865504 or placeId == 120617974337690 then
                    local ok, reason = self:PrepareTeleportResume(placeId)
                    if not ok then
                        self.TeleportResumeError = tostring(reason)
                        self:SetError("Teleport resume: " .. tostring(reason))
                    end
                end
            end
        end)
        task.spawn(function()
            while self.Alive do
                local now = os.clock()
                local full = self.FullProgression
                local automationReady = now >= self.AutomationReadyAt
                local lobby = self:IsLobby()
                if automationReady and lobby and (full or self.AutoLastSession or self.AutoDailyQuests)
                    and now - self.LastLobbyChore >= 2 then
                    self.LastLobbyChore = now
                    pcall(self.RunLobbyChores, self)
                end
                if automationReady and not lobby and (full or self.AutoHunt) then
                    local okHunt, errorMessage = pcall(self.HuntStep, self)
                    if not okHunt then
                        self:SetError("Auto Hunt: " .. tostring(errorMessage))
                    end
                end
                if automationReady and not lobby and (full or self.AutoSell) and now - self.LastSell >= self.SellInterval then
                    self:SellNow(false)
                end
                if automationReady and not (lobby and full) and now - self.LastProgress >= 2 then
                    self.LastProgress = now
                    if full or self.AutoWeapons then
                        pcall(self.BuyAndEquipBestWeapon, self, false)
                    end
                    if not lobby and (full or self.AutoUpgrades) then
                        pcall(self.BuyCheapestUpgrade, self, false)
                    end
                end
                if automationReady and not (lobby and full) and now - self.LastDog >= 5 then
                    self.LastDog = now
                    if full or self.AutoDogs then
                        pcall(self.ManageDogs, self, false)
                    end
                    if full then
                        pcall(self.BuyDogCrate, self, false, true)
                    elseif self.AutoCrates then
                        pcall(self.BuyDogCrate, self, false, false)
                    end
                end
                if automationReady and not (lobby and full) and now - self.LastReward >= 10 then
                    self.LastReward = now
                    if full or self.AutoAchievements then
                        pcall(self.ClaimAchievements, self, false)
                    end
                    if full or self.AutoFreezer then
                        pcall(self.EquipBestFreezer, self, false)
                    end
                end
                if automationReady and now - self.LastSkip >= 3 then
                    self.LastSkip = now
                    if lobby and (full or self.AutoQueue) then
                        if not full or self:RunLobbyChores() then
                            pcall(self.QueueSolo, self, false)
                        end
                    end
                    if not lobby and (full or self.AutoSkipDay) then
                        pcall(self.VoteSkip, self, false)
                    end
                end
                task.wait(0.03)
            end
        end)
        task.spawn(function()
            while self.Alive do
                local okTelemetry, errorMessage = pcall(self.UpdateTelemetry, self)
                if not okTelemetry then
                    self.LastError = "Telemetry: " .. tostring(errorMessage)
                end
                task.wait(0.5)
            end
        end)
    end

    if getgenv then
        local environment = getgenv()
        if type(environment.VOR_DuckShift) == "table" and environment.VOR_DuckShift.Stop then
            pcall(environment.VOR_DuckShift.Stop)
            environment.VOR_DuckShift = nil
        end
        if environment.__VORCatchBillionDucksCleanup then
            pcall(environment.__VORCatchBillionDucksCleanup)
        end
        environment.__VORCatchBillionDucksCleanup = function()
            runtime:Stop()
        end
    end
    return runtime
end

local function buildInterface(runtime)
    local context = runtime.Context
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Catch 1 Billion Ducks: category builder is required")
    local decals = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local HuntPage = addHomeCategory("🦆 Hunt", 1, decals.Farming or decals.Overnight)
    local ProgressPage = addHomeCategory("📈 Progress", 2, decals.Progress)
    local DogsPage = addHomeCategory("🐕 Dogs", 3, decals.Player)
    local RewardPage = addHomeCategory("🎁 Rewards", 4, decals.Visuals)
    local StatusPage = addHomeCategory("📊 Status", 5, decals.Server or decals.Player)
    selectHomeCategory("🦆 Hunt")

    local FullSection = HuntPage:AddSection("One-Button Duck Factory", "Left")
    local AimSection = HuntPage:AddSection("Permanent Smart Aim", "Right")
    local SellSection = HuntPage:AddSection("Storage & Selling", "Left")
    local GuideSection = HuntPage:AddSection("How To Use", "Right")
    local WeaponSection = ProgressPage:AddSection("Weapons", "Left")
    local UpgradeSection = ProgressPage:AddSection("Cash Upgrades", "Right")
    local ReserveSection = ProgressPage:AddSection("Spending Rules", "Left")
    local DogSection = DogsPage:AddSection("Dog Team", "Left")
    local CrateSection = DogsPage:AddSection("Dog Crates", "Right")
    local AchievementSection = RewardPage:AddSection("Achievements", "Left")
    local DaySection = RewardPage:AddSection("Days & Bosses", "Right")
    local LiveSection = StatusPage:AddSection("Live Run", "Left")
    local AdapterSection = StatusPage:AddSection("Adapter", "Right")

    runtime.StatusLabel = LiveSection:AddLabel("Status: " .. runtime.Status)
    runtime.HuntLabel = LiveSection:AddLabel("Target: None | Shot requests: 0 | Confirmed hits: 0")
    runtime.WorldLabel = LiveSection:AddLabel("Day: Reading... | Ducks: Reading...")
    runtime.EconomyLabel = LiveSection:AddLabel("Cash: Reading... | Feathers: Reading...")
    runtime.ProgressLabel = LiveSection:AddLabel("Run kills: Reading... | Purchases: 0")
    runtime.ErrorLabel = AdapterSection:AddLabel("Last error: " .. runtime.LastError)
    AdapterSection:AddLabel("Universe: 10516888336")
    AdapterSection:AddLabel("Lobby + reserved match routing enabled")
    AdapterSection:AddLabel("Shots, reloads, purchases, selling, and rewards use native server validation.")

    FullSection:AddToggle({
        Name = "🔥 Full Progression",
        Description = "Lobby chores, queue/reload, hunt, sell, buy/equip, upgrade, dogs, crates, rewards, and skip",
        Flag = "duckb_full_progression",
        Default = false,
        Callback = function(enabled)
            runtime.FullProgression = enabled
            runtime.LastSell = 0
            runtime.LastProgress = 0
            runtime.LastDog = 0
            runtime.LastReward = 0
            runtime.LastLobbyChore = 0
            runtime.LobbyChoresReady = false
            runtime.AutomationReadyAt = os.clock() + 1
            runtime:SetStatus(enabled and "Full Progression owns the duck shift" or "Full Progression disabled", true)
        end,
    })
    FullSection:AddToggle({
        Name = "🛡️ Anti AFK",
        Flag = "duckb_anti_afk",
        Default = true,
        Callback = function(enabled)
            runtime.AntiAfk = enabled
        end,
    })
    FullSection:AddLabel("Full Progression includes every automation below; individual toggles remain optional.")

    AimSection:AddToggle({
        Name = "🎯 Permanent Auto Hunt",
        Description = "Independent continuous version of the game's limited Q assist; camera never moves",
        Flag = "duckb_auto_hunt",
        Default = false,
        Callback = function(enabled)
            runtime.AutoHunt = enabled
        end,
    })
    AimSection:AddDropdown({
        Name = "Target Priority",
        Flag = "duckb_target_mode",
        Options = {"Boss > Value", "Most Valuable", "Closest"},
        Default = "Boss > Value",
        Callback = function(value)
            runtime.TargetMode = value or "Boss > Value"
        end,
    })
    AimSection:AddToggle({
        Name = "Visibility Check",
        Description = "Matches the native Q assist line-of-sight rule",
        Flag = "duckb_visibility_check",
        Default = true,
        Callback = function(enabled)
            runtime.VisibilityCheck = enabled
        end,
    })
    AimSection:AddSlider({
        Name = "Target Prediction",
        Flag = "duckb_prediction",
        Min = 0,
        Max = 0.35,
        Step = 0.01,
        Default = 0.13,
        Suffix = "s",
        Callback = function(value)
            runtime.Prediction = tonumber(value) or 0.13
        end,
    })

    SellSection:AddToggle({
        Name = "💰 Auto Sell Storage",
        Flag = "duckb_auto_sell",
        Default = false,
        Callback = function(enabled)
            runtime.AutoSell = enabled
            runtime.LastSell = 0
        end,
    })
    SellSection:AddSlider({
        Name = "Sell Interval",
        Flag = "duckb_sell_interval",
        Min = 1,
        Max = 15,
        Step = 0.5,
        Default = 4,
        Suffix = "s",
        Callback = function(value)
            runtime.SellInterval = tonumber(value) or 4
        end,
    })
    SellSection:AddButton({Name = "Sell Ducks Now", Callback = function() runtime:SellNow(true) end})

    GuideSection:AddLabel("Phone/AFK: enable 🔥 Full Progression. That is the whole damn point.")
    GuideSection:AddLabel("Manual style: enable only Auto Hunt and whichever progression systems you want.")
    GuideSection:AddLabel("Boss > Value kills bosses first, then selects the most valuable visible duck.")
    GuideSection:AddLabel("Feather Reserve protects currency from weapons, slot 2, and dog crates.")

    WeaponSection:AddToggle({
        Name = "🔫 Auto Buy & Equip Best",
        Description = "Strongest owned or currently affordable non-Robux weapon",
        Flag = "duckb_auto_weapons",
        Default = false,
        Callback = function(enabled) runtime.AutoWeapons = enabled end,
    })
    WeaponSection:AddButton({Name = "Buy / Equip Best Now", Callback = function() runtime:BuyAndEquipBestWeapon(true) end})

    UpgradeSection:AddToggle({
        Name = "⚙️ Smart Auto Upgrades",
        Description = "Buys the cheapest useful duck, weapon, or dog stat without breaking the cash reserve",
        Flag = "duckb_auto_upgrades",
        Default = false,
        Callback = function(enabled) runtime.AutoUpgrades = enabled end,
    })
    UpgradeSection:AddButton({Name = "Buy Cheapest Upgrade", Callback = function() runtime:BuyCheapestUpgrade(true) end})

    ReserveSection:AddInput({
        Name = "Cash Reserve",
        Flag = "duckb_cash_reserve",
        Placeholder = "Cash never spent on upgrades",
        Default = "0",
        Callback = function(value) runtime.CashReserve = math.max(0, tonumber(value) or 0) end,
    })
    ReserveSection:AddInput({
        Name = "Feather Reserve",
        Flag = "duckb_feather_reserve",
        Placeholder = "Feathers never spent",
        Default = "0",
        Callback = function(value) runtime.FeatherReserve = math.max(0, tonumber(value) or 0) end,
    })
    ReserveSection:AddLabel("Robux weapons are ignored. This hub does not ambush your wallet like a little bastard.")

    DogSection:AddToggle({
        Name = "🐕 Auto Best Dogs & Slot 2",
        Description = "Equips the best team and unlocks the 900-feather second slot when affordable",
        Flag = "duckb_auto_dogs",
        Default = false,
        Callback = function(enabled) runtime.AutoDogs = enabled end,
    })
    DogSection:AddButton({Name = "Manage Dogs Now", Callback = function() runtime:ManageDogs(true) end})

    CrateSection:AddToggle({
        Name = "📦 Auto Open Dog Crates",
        Description = "Uses feathers only; never opens a Robux prompt",
        Flag = "duckb_auto_crates",
        Default = false,
        Callback = function(enabled) runtime.AutoCrates = enabled end,
    })
    CrateSection:AddButton({Name = "Open One Feather Crate", Callback = function() runtime:BuyDogCrate(true, false) end})
    CrateSection:AddLabel("Duplicates are handled by the game's normal refund system; inventory limits stay server-owned.")

    AchievementSection:AddToggle({
        Name = "🏆 Auto Claim Achievements",
        Flag = "duckb_auto_achievements",
        Default = false,
        Callback = function(enabled) runtime.AutoAchievements = enabled end,
    })
    AchievementSection:AddButton({Name = "Claim Ready Achievements", Callback = function() runtime:ClaimAchievements(true) end})
    AchievementSection:AddToggle({
        Name = "🧊 Auto Equip Best Freezer",
        Description = "Equips the highest cash multiplier you actually own",
        Flag = "duckb_auto_freezer",
        Default = false,
        Callback = function(enabled) runtime.AutoFreezer = enabled end,
    })
    AchievementSection:AddButton({Name = "Equip Best Freezer", Callback = function() runtime:EquipBestFreezer(true) end})
    AchievementSection:AddToggle({
        Name = "🪶 Auto Claim Last Session",
        Description = "Claims the normal previous-session feather payout; never opens the Robux double prompt",
        Flag = "duckb_auto_last_session",
        Default = false,
        Callback = function(enabled)
            runtime.AutoLastSession = enabled
            runtime.LastSessionChecked = false
            runtime.AutomationReadyAt = os.clock() + 1
        end,
    })
    AchievementSection:AddButton({Name = "Claim Last Session", Callback = function() runtime:ClaimLastSession(true) end})
    AchievementSection:AddToggle({
        Name = "📋 Auto Roll Daily Quests",
        Description = "Rolls only when no active daily quests exist and restores your lobby position afterward",
        Flag = "duckb_auto_daily_quests",
        Default = false,
        Callback = function(enabled)
            runtime.AutoDailyQuests = enabled
            runtime.LobbyChoresReady = false
            runtime.AutomationReadyAt = os.clock() + 1
        end,
    })
    AchievementSection:AddButton({Name = "Check / Roll Daily Quests", Callback = function() runtime:RollDailyQuests(true) end})

    DaySection:AddToggle({
        Name = "⏩ Auto Vote Skip Day",
        Description = "Votes when the server allows it so boss progression keeps moving",
        Flag = "duckb_auto_skip_day",
        Default = false,
        Callback = function(enabled) runtime.AutoSkipDay = enabled end,
    })
    DaySection:AddToggle({
        Name = "🚪 Auto Queue Solo",
        Description = "Starts the next one-player run from the lobby",
        Flag = "duckb_auto_queue",
        Default = false,
        Callback = function(enabled) runtime.AutoQueue = enabled end,
    })
    DaySection:AddButton({Name = "Queue Solo Now", Callback = function() runtime:QueueSolo(true) end})
    DaySection:AddButton({Name = "Vote Skip Now", Callback = function() runtime:VoteSkip(true) end})
    DaySection:AddLabel("Bosses always override ducks in the default target mode.")

    if runtime.Gui then
        runtime.Connections[#runtime.Connections + 1] = runtime.Gui.Destroying:Connect(function()
            runtime:Stop()
        end)
    end
end

local function buildCatchOneBillionDucks(context)
    assert(context and context.Window, "Catch 1 Billion Ducks: Window is required")
    local runtime = createRuntime(context)
    buildInterface(runtime)
    installDestinationResume(runtime)
    runtime:Start()
    return runtime
end

-- The executor-MCP smoke harness supplies this only while validating an
-- unpublished local build. Normal loaders never set it.
if getgenv then
    local environment = getgenv()
    if type(environment.__VORCatchBillionDucksSmokeContext) == "table" then
        local ok, result = xpcall(function()
            return buildCatchOneBillionDucks(environment.__VORCatchBillionDucksSmokeContext)
        end, debug.traceback)
        environment.__VORCatchBillionDucksSmokeResult = ok and result or tostring(result)
        environment.__VORCatchBillionDucksSmokeOkay = ok
    end
end

return function(context)
    return buildCatchOneBillionDucks(context)
end
