-- Extracted from VOR_HUB.lua. The builder receives shared services through context.
return function(context)
    local Window = assert(context.Window, "game module requires Window")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "game module requires CreateCategoryHomePage")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS
    local track = assert(context.Track, "game module requires Track")
    local gui = assert(context.Gui, "game module requires Gui")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer

local OvernightSection
local OvernightUpgradeSection
local LiveSection
local CombatSection
local CursedKingSection
local SpecialPrioritySection
local FarmSection
local TweenSection
local UpgradeSection
local WeaponInfoSection
local ChallengeSection
local RebirthSection
local SoulRingSection
local RewardSection
local VisualSection
local VisualInfoSection
local NotificationSection
local OutfitSection
local VoidArmorSection
local ToolsInfoSection

-- Page objects are only needed while the Revive layout is assembled. Keeping
-- them inside this scope releases their registers before feature construction.
do
    local _, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local ToolsPage = Window:AddPage("Tools")
    local OvernightPage = addHomeCategory("Overnight", 1, CATEGORY_DECALS.Overnight)
    local CombatPage = addHomeCategory("Combat", 2, CATEGORY_DECALS.Combat)
    local WeaponsPage = addHomeCategory("Weapons", 3, CATEGORY_DECALS.Weapons)
    local ProgressPage = addHomeCategory("Progress", 4, CATEGORY_DECALS.Progress)
    local VisualsPage = addHomeCategory("Visuals", 5, CATEGORY_DECALS.Visuals)

    OvernightSection = OvernightPage:AddSection("AFK Essentials", "Left")
    OvernightUpgradeSection = OvernightPage:AddSection("Overnight Upgrades", "Right")
    LiveSection = OvernightPage:AddSection("Live Status", "Right")
    CombatSection = CombatPage:AddSection("Combat Automation", "Left")
    CursedKingSection = CombatPage:AddSection("Special Bosses", "Left")
    SpecialPrioritySection = CombatPage:AddSection("Special Boss Priority", "Right")
    FarmSection = CombatPage:AddSection("Boss Progression Farm", "Right")
    TweenSection = CombatPage:AddSection("Enemy Tween", "Right")
    UpgradeSection = WeaponsPage:AddSection("Sword Automation", "Left")
    WeaponInfoSection = WeaponsPage:AddSection("Owned Weapons", "Right")
    ChallengeSection = ProgressPage:AddSection("Challenges", "Left")
    RebirthSection = ProgressPage:AddSection("Auto Rebirth", "Left")
    SoulRingSection = ProgressPage:AddSection("Soul Ring", "Right")
    RewardSection = ProgressPage:AddSection("Reward Automation", "Right")
    VisualSection = VisualsPage:AddSection("Character Visuals", "Left")
    VisualInfoSection = VisualsPage:AddSection("Visual Status", "Right")
    NotificationSection = VisualsPage:AddSection("Hub Notifications", "Right")
    OutfitSection = ToolsPage:AddSection("Local Outfit Preview", "Left")
    VoidArmorSection = ToolsPage:AddSection("VOR Void Armor", "Right")
    ToolsInfoSection = ToolsPage:AddSection("Tools Status", "Right")

    selectHomeCategory("Overnight")
end

local statusLabel = LiveSection:AddLabel("Status: Loading Revive remotes...")
local remoteLabel = LiveSection:AddLabel("Remotes: Loading...")
local farmStatusLabel = LiveSection:AddLabel("Farm: Waiting")
local multiHitStatusLabel = LiveSection:AddLabel("Multi Hit: Disabled")
local reaperStatusLabel = LiveSection:AddLabel("Reaper: Reading unlock state...")
local cursedKingStatusLabel = LiveSection:AddLabel("Cursed King: Reading unlock state...")
local nightmareStatusLabel = LiveSection:AddLabel("Nightmare: Reading Death Tower state...")
local deathKingStatusLabel = LiveSection:AddLabel("Death King: Reading unlock state...")
local priorityStatusLabel = LiveSection:AddLabel("Special Priority: Disabled")
local tweenStatusLabel = LiveSection:AddLabel("Tween: Enemy 1 selected")
local weaponStatusLabel = WeaponInfoSection:AddLabel("Sword: Reading inventory...")
local visualStatusLabel = VisualInfoSection:AddLabel("Visuals: Local-only and reversible")
VisualInfoSection:AddLabel("All character effects are local-only, reversible, and reapplied after respawn.")
local discordReminderStatusLabel = NotificationSection:AddLabel("Discord Reminder: Every 15 minutes")
local outfitStatusLabel = ToolsInfoSection:AddLabel("Outfit: Your Roblox avatar")
local soulRingStatusLabel = SoulRingSection:AddLabel("Soul Ring: Reading slot 1...")
local soulRingCurrencyLabel = SoulRingSection:AddLabel("Soul Stones: Reading... | Rerolls: Reading...")
ToolsInfoSection:AddLabel("Catalog previews and VOR Void Armor are client-only. Other players keep seeing your server avatar.")

local function setReviveStatus(message, success)
    statusLabel.Text = "Status: " .. tostring(message)
    statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
end

local REMOTE_NAMES = {
    "attack",
    "attackResult",
    "staticReaperReq",
    "staticReaperResp",
    "getGroupReward",
    "startTimeLimitChallengeReq",
    "timeLimitChallengeResult",
    "enterTimeLimitBossReq",
    "levelTimeLimitBossReq",
    "setAfkResumeReq",
    "enhanceWeapon",
    "equipWeapon",
    "getSignReward",
    "receiveOnlineTimeReward",
    "claimSoulSpawner",
    "claimTimeLimitBossReward",
    "claimChallengeReward",
    "rebirth",
    "SetAutoRebirth",
    "claimReaperPityReward",
    "rollSigil",
    "SetAutoSigilRarity",
    "enhanceSoulRing",
    "rerollSoulRing",
}

remoteLabel.Text = "Remotes: 0 / " .. tostring(#REMOTE_NAMES) .. " ready"

local remotes = {}
local confirmedAttackSerial = {}
local reaperLocalCooldownUntil = 0
local specialResultSerial = 0
local specialResultSuccess = false
local function getRemoContainer()
    local rbxtsInclude = ReplicatedStorage:WaitForChild("rbxts_include", 12)
    local nodeModules = rbxtsInclude and rbxtsInclude:WaitForChild("node_modules", 12)
    local rbxts = nodeModules and nodeModules:WaitForChild("@rbxts", 12)
    local remo = rbxts and rbxts:WaitForChild("remo", 12)
    local src = remo and remo:WaitForChild("src", 12)
    return src and src:WaitForChild("container", 12)
end

local function fireRemote(name, ...)
    local remote = remotes[name]
    if not remote or not remote.Parent then
        setReviveStatus(name .. " remote is not ready", false)
        return false
    end
    local arguments = table.pack(...)
    local ok, err = pcall(function()
        remote:FireServer(table.unpack(arguments, 1, arguments.n))
    end)
    if not ok then
        setReviveStatus(name .. " failed: " .. tostring(err), false)
    end
    return ok
end

task.spawn(function()
    local container = getRemoContainer()
    if not container then
        remoteLabel.Text = "Remotes: container not found"
        remoteLabel.TextColor3 = COLORS.error
        setReviveStatus("Revive remote container was not found", false)
        return
    end

    local ready = 0
    for _, name in ipairs(REMOTE_NAMES) do
        local remote = container:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            remotes[name] = remote
            ready = ready + 1
        end
    end
    if remotes.attackResult then
        track(remotes.attackResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local confirmedLevel = tonumber(arguments[arguments.n])
            if confirmedLevel and confirmedLevel >= 1 and confirmedLevel <= 15 then
                confirmedAttackSerial[confirmedLevel] = (confirmedAttackSerial[confirmedLevel] or 0) + 1
            end
        end))
    end
    if remotes.staticReaperResp then
        track(remotes.staticReaperResp.OnClientEvent:Connect(function(maxHpRemoved)
            reaperLocalCooldownUntil = workspace:GetServerTimeNow() + 20
            reaperStatusLabel.Text = "Reaper: Confirmed -" .. tostring(maxHpRemoved) .. " Max HP | 20s cooldown"
            reaperStatusLabel.TextColor3 = COLORS.success
        end))
    end
    if remotes.timeLimitChallengeResult then
        track(remotes.timeLimitChallengeResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local success = false
            for index = 1, arguments.n do
                if type(arguments[index]) == "boolean" then
                    success = arguments[index]
                    break
                end
            end
            specialResultSuccess = success
            specialResultSerial += 1
        end))
    end
    remoteLabel.Text = "Remotes: " .. tostring(ready) .. " / " .. tostring(#REMOTE_NAMES) .. " ready"
    remoteLabel.TextColor3 = ready == #REMOTE_NAMES and COLORS.success or COLORS.muted
    setReviveStatus("Revive-only controls are ready", true)
end)

local state = {
    antiAfk = false,
    autoAttack = false,
    multiHit = false,
    reaper = false,
    cursedKing = false,
    deathKing = false,
    nightmare = false,
    specialPriority = false,
    priorityMulti = false,
    groupReward = false,
    challengeOne = false,
    challengeFive = false,
    autoUpgrade = false,
    dailyReward = false,
    onlineReward = false,
    soulSpawner = false,
    starterRewards = false,
    bossRewards = false,
    bossFarm = false,
    autoTween = false,
    autoEquipBest = false,
    autoRebirth = false,
    autoSoulRing = false,
    demonRealm = false,
    discordReminder = true,
}

local discordReminderInterval = 15 * 60
local nextDiscordReminderAt = os.clock() + discordReminderInterval
local function showDiscordReminder()
    Window:Notify(
        "VOR Hub • Discord",
        "Enjoying VOR Hub? Join our Discord: " .. context.SETTINGS.Discord,
        8
    )
    nextDiscordReminderAt = os.clock() + discordReminderInterval
    discordReminderStatusLabel.Text = "Discord Reminder: Shown | Next in 15:00"
    discordReminderStatusLabel.TextColor3 = COLORS.success
end

NotificationSection:AddToggle({
    Name = "Discord Reminder",
    Description = "Shows the frozen bottom-right Discord invitation every 15 minutes",
    Default = true,
    Flag = "revive_discord_reminder",
    Callback = function(enabled)
        state.discordReminder = enabled
        nextDiscordReminderAt = os.clock() + discordReminderInterval
        discordReminderStatusLabel.Text = enabled and "Discord Reminder: Enabled | Next in 15:00" or "Discord Reminder: Disabled"
        discordReminderStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

NotificationSection:AddButton({
    Name = "Test Discord Reminder",
    Description = "Shows the themed bottom-right notification immediately",
    Persist = false,
    Callback = showDiscordReminder,
})

NotificationSection:AddLabel("The reminder stays visible even while the main hub is hidden with Right Ctrl.")

local antiAfkStatusLabel = OvernightSection:AddLabel("Anti-AFK: Disabled")
local antiAfkControl
antiAfkControl = OvernightSection:AddToggle({
    Name = "Anti-AFK / Anti-Idle",
    Description = "Responds when Roblox detects inactivity so overnight farming is not idle-kicked",
    Flag = "revive_anti_afk",
    Callback = function(enabled)
        state.antiAfk = enabled
        gui:SetAttribute("AntiAFKEnabled", enabled)
        antiAfkStatusLabel.Text = enabled and "Anti-AFK: Armed and waiting for an idle signal" or "Anti-AFK: Disabled"
        antiAfkStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Anti-AFK enabled" or "Anti-AFK disabled", enabled and true or nil)
    end,
})
gui:SetAttribute("AntiAFKEnabled", false)

task.spawn(function()
    while gui.Parent do
        statusWidgetLabels.General.Text = statusLabel.Text
        statusWidgetLabels.General.TextColor3 = context.ReadableStatusColor(statusLabel.TextColor3)
        statusWidgetLabels.AFK.Text = antiAfkStatusLabel.Text
        statusWidgetLabels.AFK.TextColor3 = context.ReadableStatusColor(antiAfkStatusLabel.TextColor3)
        if state.demonRealm and state.demonRealmStatusLabel then
            statusWidgetLabels.Special.Text = state.demonRealmStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = context.ReadableStatusColor(state.demonRealmStatusLabel.TextColor3)
        else
            statusWidgetLabels.Special.Text = priorityStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = context.ReadableStatusColor(priorityStatusLabel.TextColor3)
        end
        statusWidgetLabels.Multi.Text = multiHitStatusLabel.Text
        statusWidgetLabels.Multi.TextColor3 = context.ReadableStatusColor(multiHitStatusLabel.TextColor3)
        statusWidgetLabels.Farm.Text = farmStatusLabel.Text .. " | " .. nightmareStatusLabel.Text
        statusWidgetLabels.Farm.TextColor3 = context.ReadableStatusColor(farmStatusLabel.TextColor3)
        statusWidgetLabels.Weapon.Text = weaponStatusLabel.Text
        statusWidgetLabels.Weapon.TextColor3 = context.ReadableStatusColor(weaponStatusLabel.TextColor3)
        task.wait(0.20)
    end
end)

local function performAntiAfkPulse()
    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or CFrame.new()
    local ok = pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:Button2Down(Vector2.new(0, 0), cameraCFrame)
        task.wait(0.05)
        virtualUser:Button2Up(Vector2.new(0, 0), cameraCFrame)
    end)
    if ok then
        gui:SetAttribute("AntiAFKLastPulse", workspace:GetServerTimeNow())
        antiAfkStatusLabel.Text = "Anti-AFK: Idle pulse sent successfully"
        antiAfkStatusLabel.TextColor3 = COLORS.success
    else
        antiAfkStatusLabel.Text = "Anti-AFK: Virtual input was unavailable"
        antiAfkStatusLabel.TextColor3 = COLORS.error
    end
    return ok
end

track(LocalPlayer.Idled:Connect(function()
    if state.antiAfk and gui.Parent then
        performAntiAfkPulse()
    end
end))

OvernightSection:AddButton({
    Name = "Test Anti-AFK Pulse",
    Description = "Runs one harmless idle-protection pulse and updates the status above",
    Persist = false,
    Callback = function()
        if performAntiAfkPulse() then
            setReviveStatus("Anti-AFK test passed", true)
        else
            setReviveStatus("Anti-AFK test could not send virtual input", false)
        end
    end,
})

local overnightMultiHitControl
local overnightReaperControl
local overnightDeathKingControl
local overnightCursedKingControl
local overnightNightmareControl
local overnightSpecialPriorityControl
local overnightBossFarmControl
local overnightAutoEquipControl
local overnightAutoUpgradeControl
local overnightAutoRebirthControl
local overnightAutoSoulRingControl

local reaperBattleStore = nil
local rebirthStore = nil
local reaperUnlockLevel = 3
local reaperInterval = 20
local redDragonUnlockLevel = 5
local greenDragonUnlockLevel = 5
local nightmareUnlockLevel = 15
local rebirthTowerLevelRatio = 5
pcall(function()
    reaperBattleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    rebirthStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("rebirth"))
    local globalConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbglobalconfig"))
    reaperUnlockLevel = tonumber(globalConfig.unlock_reaper_main_level_require) or reaperUnlockLevel
    reaperInterval = tonumber(globalConfig.static_reaper_interval_time) or reaperInterval
    redDragonUnlockLevel = tonumber(globalConfig.unlock_red_dragon_main_level_require) or redDragonUnlockLevel
    greenDragonUnlockLevel = tonumber(globalConfig.unlock_green_dragon_main_level_require) or greenDragonUnlockLevel
    nightmareUnlockLevel = tonumber(globalConfig.unlock_tower_main_level_require) or nightmareUnlockLevel
    rebirthTowerLevelRatio = tonumber(globalConfig.rebirth_tower_level_ratio) or rebirthTowerLevelRatio
end)

local function readAtomValue(store, name)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return nil
    end
    local ok, value = pcall(atom)
    if not ok then
        return nil
    end
    if type(value) == "function" then
        local readOk, currentValue = pcall(value)
        return readOk and currentValue or nil
    end
    return value
end

local function writeDirectAtom(store, name, value)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return false
    end
    return pcall(atom, value)
end

state.getDemonRealmState = function()
    local serverNow = workspace:GetServerTimeNow()
    local openEndTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossOpenEndTime")) or 0
    local nextOpenTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossNextOpenTime")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local expEfficiency = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossExpEfficiency")) or 0
    return {
        Open = openEndTime > serverNow,
        InRealm = battleState == 7,
        BattleState = battleState,
        OpenRemaining = math.max(0, math.ceil(openEndTime - serverNow)),
        NextRemaining = math.max(0, math.ceil(nextOpenTime - serverNow)),
        ExpEfficiency = expEfficiency,
    }
end

state.formatRealmCountdown = function(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainder = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remainder)
    end
    return string.format("%02d:%02d", minutes, remainder)
end

state.demonRealmStatusLabel = CursedKingSection:AddLabel("Demon Realm: Reading global event window...")
state.refreshDemonRealmStatus = function()
    local info = state.getDemonRealmState()
    if info.InRealm then
        state.demonRealmStatusLabel.Text = "Demon Realm: Inside | Auto farming | "
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    elseif info.Open then
        state.demonRealmStatusLabel.Text = (state.demonRealm and "Demon Realm: Open | Joining... | " or "Demon Realm: Open now | Auto join off | ")
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = state.demonRealm and COLORS.success or COLORS.muted
    elseif state.demonRealm then
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Armed | Next global event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Armed | Waiting for the next global event"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    else
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Disabled | Next event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Disabled | Global event is closed"
        state.demonRealmStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

state.demonRealmControl = CursedKingSection:AddToggle({
    Name = "Auto Demon Realm",
    Description = "Joins the global Demon Realm when it opens, attacks continuously, and re-enters while it stays open",
    Flag = "revive_auto_demon_realm",
    Callback = function(enabled)
        state.demonRealm = enabled
        state.refreshDemonRealmStatus()
        setReviveStatus(
            enabled and "Demon Realm armed; waiting for the server event window" or "Auto Demon Realm disabled",
            enabled and true or nil
        )
    end,
})
CursedKingSection:AddLabel("The realm timer and stat rewards are server-controlled; Auto Demon Realm waits and rejoins every valid opening.")
task.defer(state.refreshDemonRealmStatus)

local function getReaperState()
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local maxHp = tonumber(readAtomValue(reaperBattleStore, "AtomMaxHP")) or 0
    local nextValidTime = tonumber(readAtomValue(reaperBattleStore, "AtomReaperTime")) or 0
    return {
        Unlocked = mainLevel >= reaperUnlockLevel,
        MainLevel = mainLevel,
        MaxHP = maxHp,
        NextValidTime = nextValidTime,
        Remaining = math.max(0, math.ceil(nextValidTime - workspace:GetServerTimeNow())),
    }
end

local function refreshReaperStatus(prefix)
    local info = getReaperState()
    if not info.Unlocked then
        reaperStatusLabel.Text = "Reaper: Waiting for the game's unlock state"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.MaxHP <= 1 then
        reaperStatusLabel.Text = "Reaper: Unlocked | No more Max HP can be taken"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.Remaining > 0 then
        reaperStatusLabel.Text = "Reaper: Unlocked | Cooldown " .. info.Remaining .. "s"
        reaperStatusLabel.TextColor3 = COLORS.muted
    else
        reaperStatusLabel.Text = "Reaper: Unlocked | Ready"
        reaperStatusLabel.TextColor3 = COLORS.success
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

task.defer(refreshReaperStatus)

local RED_DRAGON_MODE = 1
local GREEN_DRAGON_MODE = 2
local NIGHTMARE_MODE = 3
local deathKingLevelAdd = 0
local cursedKingLevelAdd = 0
local nightmareLevelAdd = 0
local specialLastStart = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0}
local multiHitNeedsBootstrap = true
local nightmarePortalPrimeRunning = false
local nightmarePortalPrimedCharacter = nil
local priority = {
    target = "Nightmare",
    levelAdd = 0,
    winsPerCycle = 1,
    multiSeconds = 5,
    phase = "special",
    wins = 0,
    nextMode = NIGHTMARE_MODE,
    activeMode = nil,
    activeLevelBefore = 0,
    lastLevels = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0},
    seenResultSerial = 0,
    nextStartAt = 0,
    multiEndAt = 0,
    quitDeadline = 0,
}

local function levelAddText(levelAdd)
    return levelAdd == 2 and "+10" or (levelAdd == 1 and "+5" or "+1")
end

local function getSpecialBossState(mode)
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local highestRebirth = tonumber(readAtomValue(rebirthStore, "AtomHighestReachedRebirth")) or 0
    local autoMode = tonumber(readAtomValue(reaperBattleStore, "AtomAutoChallengeMode")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local isNightmare = mode == NIGHTMARE_MODE
    local isDeathKing = mode == RED_DRAGON_MODE
    local requiredMainLevel = isNightmare and nightmareUnlockLevel
        or (isDeathKing and redDragonUnlockLevel or greenDragonUnlockLevel)
    local atomName = isNightmare and "AtomTowerLevel"
        or (isDeathKing and "AtomRedDragonLevel" or "AtomGreenDragonLevel")
    return {
        Unlocked = mainLevel >= requiredMainLevel,
        MainLevel = mainLevel,
        RequiredMainLevel = requiredMainLevel,
        HighestRebirth = highestRebirth,
        NativeAutoAvailable = highestRebirth > 0,
        Level = tonumber(readAtomValue(reaperBattleStore, atomName)) or 0,
        RequiredTowerLevel = isNightmare and (rebirthTowerLevelRatio * (highestRebirth + 1)) or nil,
        AutoMode = autoMode,
        BattleState = battleState,
        Mode = mode,
    }
end

local function getDeathKingState()
    return getSpecialBossState(RED_DRAGON_MODE)
end

local function getCursedKingState()
    return getSpecialBossState(GREEN_DRAGON_MODE)
end

local function refreshDeathKingStatus()
    local info = getDeathKingState()
    if not info.Unlocked then
        deathKingStatusLabel.Text = "Death King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        deathKingStatusLabel.TextColor3 = COLORS.error
    elseif state.deathKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        deathKingStatusLabel.Text = "Death King: " .. method .. " " .. levelAddText(deathKingLevelAdd) .. " | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.success
    else
        deathKingStatusLabel.Text = "Death King: Unlocked | Auto disabled | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function getNightmareState()
    return getSpecialBossState(NIGHTMARE_MODE)
end

local function findNightmarePortalPart()
    local bestPart = nil
    local bestScore = -math.huge
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Transparency < 1 then
            local parentName = descendant.Parent and descendant.Parent.Name or ""
            local identity = string.lower(descendant.Name .. " " .. parentName)
            local hue, saturation = Color3.toHSV(descendant.Color)
            local isPurple = hue >= 0.68 and hue <= 0.90 and saturation >= 0.22
            local score = 0
            if string.find(identity, "portal", 1, true) then score += 7 end
            if string.find(identity, "nightmare", 1, true) then score += 5 end
            if string.find(identity, "death", 1, true) then score += 3 end
            if string.find(identity, "tower", 1, true) then score += 3 end
            if isPurple then score += 4 end
            if descendant.CanTouch then score += 1 end
            if score > bestScore and score >= 8 then
                bestPart = descendant
                bestScore = score
            end
        end
    end
    return bestPart
end

local function prepareNightmareChallengeScene()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local scene = workspace:FindFirstChild("TowerBattle")
    if not scene then
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local model = assets and assets:FindFirstChild("Model")
        local sceneFolder = model and model:FindFirstChild("Scene")
        scene = sceneFolder and sceneFolder:FindFirstChild("TowerBattle")
    end
    if not scene or not scene:IsA("Model") then
        return false
    end
    local ok = pcall(function()
        if scene.Parent ~= workspace then
            scene.Parent = workspace
        end
        scene:PivotTo(CFrame.new(0, 300, 0))
        local posFolder = scene:FindFirstChild("Pos", true)
        local playerPoint = posFolder and posFolder:FindFirstChild("Player")
        if not playerPoint or not playerPoint:IsA("BasePart") then
            error("TowerBattle.Pos.Player was not found")
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = playerPoint.CFrame
    end)
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Death Tower arena prepared automatically", true)
    end
    return ok
end

local function primeNightmarePortal()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not root then
        return false
    end
    if nightmarePortalPrimedCharacter == character then
        return true
    end
    if nightmarePortalPrimeRunning then
        return false
    end

    if prepareNightmareChallengeScene() then
        return true
    end

    local portalPart = findNightmarePortalPart()
    if not portalPart then
        setReviveStatus("Nightmare is waiting for the purple Death Tower portal", nil)
        return false
    end

    nightmarePortalPrimeRunning = true
    local originalCFrame = root.CFrame
    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, -2.2)
        if type(firetouchinterest) == "function" then
            firetouchinterest(root, portalPart, 0)
            firetouchinterest(root, portalPart, 1)
        end
        task.wait(0.18)
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, 2.2)
        task.wait(0.18)
        root.CFrame = originalCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    nightmarePortalPrimeRunning = false
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Purple Death Tower portal primed automatically", true)
    end
    return ok
end

local function refreshCursedKingStatus()
    local info = getCursedKingState()
    if not info.Unlocked then
        cursedKingStatusLabel.Text = "Cursed King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        cursedKingStatusLabel.TextColor3 = COLORS.error
    elseif state.cursedKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        cursedKingStatusLabel.Text = "Cursed King: " .. method .. " " .. levelAddText(cursedKingLevelAdd) .. " | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.success
    else
        cursedKingStatusLabel.Text = "Cursed King: Unlocked | Auto disabled | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function refreshNightmareStatus()
    local info = getNightmareState()
    if not info.Unlocked then
        nightmareStatusLabel.Text = "Nightmare: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        nightmareStatusLabel.TextColor3 = COLORS.error
    elseif state.nightmare then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        nightmareStatusLabel.Text = "Nightmare: " .. method .. " " .. levelAddText(nightmareLevelAdd)
            .. " | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.success
    else
        nightmareStatusLabel.Text = "Nightmare: Unlocked | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function startSpecialBoss(mode, levelAdd, nativeAuto)
    local info = getSpecialBossState(mode)
    if not info.Unlocked then
        if mode == NIGHTMARE_MODE then
            refreshNightmareStatus()
        elseif mode == RED_DRAGON_MODE then
            refreshDeathKingStatus()
        else
            refreshCursedKingStatus()
        end
        return false
    end
    if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
        primeNightmarePortal()
        task.wait(0.12)
    end
    local autoMode = nativeAuto and mode or 0
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", autoMode)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", levelAdd)
    local resumeOk = fireRemote("setAfkResumeReq", autoMode, levelAdd)
    local startOk = fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
    if resumeOk and startOk then
        specialLastStart[mode] = workspace:GetServerTimeNow()
        if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
            task.delay(0.9, function()
                if not gui.Parent or getNightmareState().BattleState ~= 0 then
                    return
                end
                if primeNightmarePortal() then
                    task.wait(0.15)
                    fireRemote("setAfkResumeReq", autoMode, levelAdd)
                    fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
                    specialLastStart[mode] = workspace:GetServerTimeNow()
                end
            end)
        end
        return true
    end
    return false
end

local function armDeathKingAuto()
    local info = getDeathKingState()
    local ok = startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Death King auto " .. levelAddText(deathKingLevelAdd) .. " armed", true)
    end
    refreshDeathKingStatus()
    return ok
end

local function armCursedKingAuto()
    local info = getCursedKingState()
    local ok = startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Cursed King auto " .. levelAddText(cursedKingLevelAdd) .. " armed", true)
    end
    refreshCursedKingStatus()
    return ok
end

local function armNightmareAuto()
    local info = getNightmareState()
    local ok = startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Nightmare auto " .. levelAddText(nightmareLevelAdd) .. " armed", true)
    end
    refreshNightmareStatus()
    return ok
end

local function disarmSpecialAuto()
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", 0)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", 0)
    fireRemote("setAfkResumeReq", 0, 0)
end

priority.modeName = function(mode)
    return mode == NIGHTMARE_MODE and "Nightmare"
        or (mode == RED_DRAGON_MODE and "Death King" or "Cursed King")
end

priority.reset = function()
    priority.phase = "special"
    priority.wins = 0
    priority.nextMode = priority.target == "Cursed King" and GREEN_DRAGON_MODE
        or (priority.target == "Death King" and RED_DRAGON_MODE or NIGHTMARE_MODE)
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.lastLevels[RED_DRAGON_MODE] = getDeathKingState().Level
    priority.lastLevels[GREEN_DRAGON_MODE] = getCursedKingState().Level
    priority.lastLevels[NIGHTMARE_MODE] = getNightmareState().Level
    priority.seenResultSerial = specialResultSerial
    priority.nextStartAt = 0
    priority.multiEndAt = 0
    priority.quitDeadline = 0
    state.priorityMulti = false
end

priority.chooseMode = function()
    local deathInfo = getDeathKingState()
    local cursedInfo = getCursedKingState()
    local nightmareInfo = getNightmareState()
    if priority.target == "Nightmare" then
        return nightmareInfo.Unlocked and NIGHTMARE_MODE or nil
    end
    if priority.target == "Cursed King" then
        return cursedInfo.Unlocked and GREEN_DRAGON_MODE or nil
    end
    if priority.target == "Death King" then
        return deathInfo.Unlocked and RED_DRAGON_MODE or nil
    end
    if priority.target == "Cycle All" then
        local order = {RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}
        local startIndex = table.find(order, priority.nextMode) or 1
        for offset = 0, #order - 1 do
            local candidate = order[((startIndex + offset - 1) % #order) + 1]
            if getSpecialBossState(candidate).Unlocked then
                return candidate
            end
        end
        return nil
    end
    if nightmareInfo.Unlocked then
        return NIGHTMARE_MODE
    end
    if cursedInfo.Unlocked then
        return GREEN_DRAGON_MODE
    end
    return nil
end

priority.start = function()
    local mode = priority.chooseMode()
    if not mode then
        return false
    end
    local info = getSpecialBossState(mode)
    if startSpecialBoss(mode, priority.levelAdd, false) then
        priority.activeMode = mode
        priority.activeLevelBefore = info.Level
        priority.seenResultSerial = specialResultSerial
        priority.nextStartAt = os.clock() + 2.5
        priorityStatusLabel.Text = "Special Priority: Fighting " .. priority.modeName(mode)
        priorityStatusLabel.TextColor3 = COLORS.success
        return true
    end
    priority.nextStartAt = os.clock() + 2.5
    return false
end

priority.complete = function(success)
    local completedMode = priority.activeMode
    if not completedMode then
        return
    end
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.nextStartAt = os.clock() + 1
    if not success then
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " retry queued"
        priorityStatusLabel.TextColor3 = COLORS.error
        return
    end

    priority.wins += 1
    if priority.target == "Cycle All" then
        priority.nextMode = completedMode == RED_DRAGON_MODE and GREEN_DRAGON_MODE
            or (completedMode == GREEN_DRAGON_MODE and NIGHTMARE_MODE or RED_DRAGON_MODE)
    end
    if priority.wins >= priority.winsPerCycle then
        priority.phase = "quit"
        priority.wins = 0
        priority.quitDeadline = os.clock() + 3.5
        state.priorityMulti = false
        multiHitNeedsBootstrap = true
        disarmSpecialAuto()
        for attempt = 0, 2 do
            task.delay(attempt * 0.16, function()
                if gui.Parent and state.specialPriority and priority.phase == "quit" then
                    fireRemote("levelTimeLimitBossReq")
                end
            end)
        end
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " defeated | Exiting"
        priorityStatusLabel.TextColor3 = COLORS.success
    else
        priorityStatusLabel.Text = "Special Priority: " .. priority.wins .. " / " .. priority.winsPerCycle .. " special wins"
        priorityStatusLabel.TextColor3 = COLORS.success
    end
end

priority.observeProgress = function()
    for _, mode in ipairs({RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}) do
        local currentLevel = getSpecialBossState(mode).Level
        local previousLevel = priority.lastLevels[mode] or currentLevel
        priority.lastLevels[mode] = currentLevel
        if currentLevel < previousLevel then
            previousLevel = currentLevel
        end
        local matchesTarget = priority.target == "Cycle All"
            or (priority.target == "Nightmare" and mode == NIGHTMARE_MODE)
            or (priority.target == "Cursed King" and mode == GREEN_DRAGON_MODE)
            or (priority.target == "Death King" and mode == RED_DRAGON_MODE)
        if priority.phase == "special" and matchesTarget and currentLevel > previousLevel then
            if not priority.activeMode then
                priority.activeMode = mode
            end
            priority.complete(true)
            return true
        end
    end
    return false
end

priority.isMultiHitActive = function()
    if state.specialPriority then
        return state.priorityMulti
    end
    return state.multiHit
end

task.defer(refreshCursedKingStatus)
task.defer(refreshDeathKingStatus)
task.defer(refreshNightmareStatus)

local attackControl
local multiHitControl
local specialPriorityControl
local bossFarmControl
local multiHitDelay = 0.06
local multiHitTargetMode = "Unlocked Bosses Only"

attackControl = CombatSection:AddToggle({
    Name = "Auto Attack Latest Boss",
    Description = "Attacks your latest unlocked boss from anywhere",
    Flag = "revive_auto_attack",
    Callback = function(enabled)
        state.autoAttack = enabled
        if enabled and multiHitControl then
            state.multiHit = false
            multiHitControl:Set(false, true)
        end
        setReviveStatus(enabled and "Auto Attack Latest Boss enabled" or "Auto Attack Latest Boss disabled", enabled and true or nil)
    end,
})

multiHitControl = CombatSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Attacks every selected boss level each cycle without moving your character",
    Flag = "revive_multi_hit_all_bosses",
    Callback = function(enabled)
        state.multiHit = enabled
        if enabled then
            multiHitNeedsBootstrap = true
        end
        if overnightMultiHitControl and overnightMultiHitControl:Get() ~= enabled then
            overnightMultiHitControl:Set(enabled, true)
        end
        if enabled and attackControl then
            state.autoAttack = false
            attackControl:Set(false, true)
        end
        multiHitStatusLabel.Text = enabled and "Multi Hit: Starting confirmed round-robin..." or "Multi Hit: Disabled"
        multiHitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and ("Multi Hit enabled: " .. multiHitTargetMode) or "Multi Hit disabled", enabled and true or nil)
    end,
})

CombatSection:AddSlider({
    Name = "Multi Hit Retry Delay",
    Min = 0.03,
    Max = 0.30,
    Default = multiHitDelay,
    Step = 0.01,
    Flag = "revive_multi_hit_delay_fast_v3",
    Callback = function(value)
        multiHitDelay = math.clamp(tonumber(value) or 0.06, 0.03, 0.30)
    end,
})

CombatSection:AddDropdown({
    Name = "Multi Hit Targets",
    Options = {"Unlocked Bosses Only", "All 15 Bosses"},
    Default = "Unlocked Bosses Only",
    Flag = "revive_multi_hit_targets_v2",
    Callback = function(value)
        multiHitTargetMode = value == "All 15 Bosses" and value or "Unlocked Bosses Only"
        if state.multiHit then
            setReviveStatus("Multi Hit targets: " .. multiHitTargetMode, true)
        end
    end,
})

CombatSection:AddLabel("Waits for the server to confirm each boss before advancing. Your character never moves.")

local autoReaperControl
autoReaperControl = CombatSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Uses the companion Reaper only when unlocked and its 20-second cooldown is ready",
    Flag = "revive_auto_reaper",
    Callback = function(enabled)
        state.reaper = enabled
        if overnightReaperControl and overnightReaperControl:Get() ~= enabled then
            overnightReaperControl:Set(enabled, true)
        end
        refreshReaperStatus()
        setReviveStatus(enabled and "Auto Reaper enabled (cooldown-aware)" or "Auto Reaper disabled", enabled and true or nil)
    end,
})

CombatSection:AddToggle({
    Name = "Auto Group Reward",
    Description = "Checks the group reward every 30 seconds",
    Flag = "revive_group_reward",
    Callback = function(enabled)
        state.groupReward = enabled
        setReviveStatus(enabled and "Group Reward checks enabled" or "Group Reward checks disabled", enabled and true or nil)
    end,
})

local challengeOneControl
local challengeFiveControl
local deathKingControl
local cursedKingControl
local nightmareControl
challengeOneControl = ChallengeSection:AddToggle({
    Name = "Challenge +1 Level",
    Description = "Repeats startTimeLimitChallengeReq(1, 0)",
    Flag = "revive_challenge_one",
    Callback = function(enabled)
        state.challengeOne = enabled
        if enabled and challengeFiveControl then
            state.challengeFive = false
            challengeFiveControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

challengeFiveControl = ChallengeSection:AddToggle({
    Name = "Challenge +5 Levels",
    Description = "Repeats startTimeLimitChallengeReq(1, 1)",
    Flag = "revive_challenge_five",
    Callback = function(enabled)
        state.challengeFive = enabled
        if enabled and challengeOneControl then
            state.challengeOne = false
            challengeOneControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Death King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_death_king_level_gain",
    Callback = function(value)
        deathKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.deathKing and getDeathKingState().Unlocked then
            armDeathKingAuto()
        else
            refreshDeathKingStatus()
        end
    end,
})

deathKingControl = CursedKingSection:AddToggle({
    Name = "Auto Death King",
    Description = "Farms the RedDragon special boss continuously",
    Flag = "revive_auto_death_king",
    Callback = function(enabled)
        state.deathKing = enabled
        if overnightDeathKingControl and overnightDeathKingControl:Get() ~= enabled then
            overnightDeathKingControl:Set(enabled, true)
        end
        if enabled then
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshDeathKingStatus()
            if info.Unlocked then
                armDeathKingAuto()
            else
                setReviveStatus("Death King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.cursedKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshDeathKingStatus()
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Death King Once",
    Description = "Starts one Death King run with the selected level gain",
    Persist = false,
    Callback = function()
        local info = refreshDeathKingStatus()
        if info.Unlocked then
            startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, false)
        else
            Window:Notify("Death King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Cursed King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_cursed_king_level_gain",
    Callback = function(value)
        cursedKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.cursedKing and getCursedKingState().Unlocked then
            armCursedKingAuto()
        else
            refreshCursedKingStatus()
        end
    end,
})

cursedKingControl = CursedKingSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Farms GreenDragon continuously; hub-managed before Rebirth 1 and native auto afterward",
    Flag = "revive_auto_cursed_king",
    Callback = function(enabled)
        state.cursedKing = enabled
        if overnightCursedKingControl and overnightCursedKingControl:Get() ~= enabled then
            overnightCursedKingControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshCursedKingStatus()
            if info.Unlocked then
                armCursedKingAuto()
            else
                setReviveStatus("Cursed King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshCursedKingStatus()
            setReviveStatus("Auto Cursed King disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Cursed King Once",
    Description = "Starts one Cursed King run with the selected level gain when ownership is unlocked",
    Persist = false,
    Callback = function()
        local info = refreshCursedKingStatus()
        if info.Unlocked then
            startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, false)
        else
            Window:Notify("Cursed King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Nightmare Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_nightmare_level_gain",
    Callback = function(value)
        nightmareLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.nightmare and getNightmareState().Unlocked then
            armNightmareAuto()
        else
            refreshNightmareStatus()
        end
    end,
})

nightmareControl = CursedKingSection:AddToggle({
    Name = "Auto Nightmare",
    Description = "Farms Death Tower continuously so its level can reach the next Rebirth requirement",
    Flag = "revive_auto_nightmare",
    Callback = function(enabled)
        state.nightmare = enabled
        if overnightNightmareControl and overnightNightmareControl:Get() ~= enabled then
            overnightNightmareControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshNightmareStatus()
            if info.Unlocked then
                armNightmareAuto()
            else
                setReviveStatus("Nightmare armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.cursedKing and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshNightmareStatus()
            setReviveStatus("Auto Nightmare disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Nightmare Once",
    Description = "Starts one Death Tower run with the selected +1 / +5 / +10 level gain",
    Persist = false,
    Callback = function()
        local info = refreshNightmareStatus()
        if info.Unlocked then
            startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, false)
        else
            Window:Notify("Nightmare", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddLabel("Cursed King = GreenDragon mode 2 | Nightmare = Death Tower mode 3")

SpecialPrioritySection:AddDropdown({
    Name = "Priority Special Boss",
    Options = {"Nightmare", "Cursed King", "Death King", "Cycle All"},
    Default = "Nightmare",
    Flag = "revive_priority_special_target_v2",
    Callback = function(value)
        priority.target = (value == "Cursed King" or value == "Death King" or value == "Cycle All") and value or "Nightmare"
        if state.specialPriority then
            priority.reset()
            priorityStatusLabel.Text = "Special Priority: Target changed to " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

SpecialPrioritySection:AddDropdown({
    Name = "Priority Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_priority_level_gain_v2",
    Callback = function(value)
        priority.levelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.specialPriority then
            priority.reset()
            setReviveStatus("Special priority level gain set to " .. levelAddText(priority.levelAdd), true)
        end
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Special Wins Per Cycle",
    Min = 1,
    Max = 5,
    Default = 1,
    Step = 1,
    Flag = "revive_priority_special_wins_v2",
    Callback = function(value)
        priority.winsPerCycle = math.clamp(math.floor((tonumber(value) or 1) + 0.5), 1, 5)
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Multi Hit Window",
    Min = 1,
    Max = 60,
    Default = 5,
    Step = 1,
    Suffix = "s",
    Flag = "revive_priority_multi_seconds_v2",
    Callback = function(value)
        priority.multiSeconds = math.clamp(math.floor((tonumber(value) or 5) + 0.5), 1, 60)
    end,
})

specialPriorityControl = SpecialPrioritySection:AddToggle({
    Name = "Special Boss Priority",
    Description = "Kills the selected special boss, runs timed Multi Hit, then repeats while advancing tower sections",
    Flag = "revive_special_boss_priority_v2",
    Callback = function(enabled)
        state.specialPriority = enabled
        if overnightSpecialPriorityControl and overnightSpecialPriorityControl:Get() ~= enabled then
            overnightSpecialPriorityControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if attackControl then attackControl:Set(false) end
            if bossFarmControl then bossFarmControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            disarmSpecialAuto()
            priority.reset()
            multiHitNeedsBootstrap = true
            priorityStatusLabel.Text = "Special Priority: AFK climb armed for " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
            setReviveStatus("Special boss priority enabled: " .. priority.target, true)
        else
            priority.reset()
            if not state.deathKing and not state.cursedKing and not state.nightmare then
                disarmSpecialAuto()
            end
            priorityStatusLabel.Text = "Special Priority: Disabled"
            priorityStatusLabel.TextColor3 = COLORS.muted
            setReviveStatus("Special boss priority disabled", nil)
        end
    end,
})

SpecialPrioritySection:AddLabel("AFK loop: selected special wins -> timed Multi Hit -> next Death Tower / Cursed King section.")
SpecialPrioritySection:AddLabel("Nightmare progress raises Death Tower level; Rebirth 1 requires Death Tower 5.")

local dailyRewardControl
dailyRewardControl = RewardSection:AddToggle({
    Name = "Auto Daily Sign",
    Description = "Claims the daily sign reward when it becomes available",
    Flag = "revive_daily_sign",
    Callback = function(enabled)
        state.dailyReward = enabled
    end,
})

local onlineRewardControl
onlineRewardControl = RewardSection:AddToggle({
    Name = "Auto Online Rewards",
    Description = "Checks the online-time reward every five seconds",
    Flag = "revive_online_rewards",
    Callback = function(enabled)
        state.onlineReward = enabled
    end,
})

local soulSpawnerControl
soulSpawnerControl = RewardSection:AddToggle({
    Name = "Auto Soul Spawner",
    Description = "Claims accumulated Soul Spawner rewards when unlocked",
    Flag = "revive_soul_spawner",
    Callback = function(enabled)
        state.soulSpawner = enabled
    end,
})

local starterRewardControl
starterRewardControl = RewardSection:AddToggle({
    Name = "Auto Starter Rewards",
    Description = "Checks verified starter milestones 1 through 5",
    Flag = "revive_starter_rewards",
    Callback = function(enabled)
        state.starterRewards = enabled
    end,
})

local bossRewardControl
bossRewardControl = RewardSection:AddToggle({
    Name = "Auto Boss Rewards",
    Description = "Checks Time-Limit Boss reward indexes 1 through 6",
    Flag = "revive_boss_rewards",
    Callback = function(enabled)
        state.bossRewards = enabled
    end,
})

RewardSection:AddButton({
    Name = "Claim Available Rewards Now",
    Description = "Runs one safe claim pass without enabling any toggle",
    Persist = false,
    Callback = function()
        fireRemote("getSignReward")
        fireRemote("receiveOnlineTimeReward")
        fireRemote("claimSoulSpawner")
        fireRemote("getGroupReward")
        for index = 1, 5 do
            fireRemote("claimChallengeReward", index)
        end
        for index = 1, 6 do
            fireRemote("claimTimeLimitBossReward", index)
        end
        setReviveStatus("Reward claim pass sent", true)
    end,
})

local weaponStore = nil
local weaponConfig = nil
pcall(function()
    weaponStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("weapon"))
    weaponConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbweapon"))
end)

local function getOwnedWeapons()
    if not weaponStore or type(weaponStore.AtomWeapons) ~= "function" then
        return nil
    end
    local ok, owned = pcall(function()
        return weaponStore.AtomWeapons()()
    end)
    return ok and type(owned) == "table" and owned or nil
end

local function getEquippedWeaponId()
    if not weaponStore or type(weaponStore.AtomEquippedWeaponId) ~= "function" then
        return nil
    end
    local ok, equipped = pcall(function()
        return weaponStore.AtomEquippedWeaponId()()
    end)
    return ok and type(equipped) == "string" and equipped or nil
end

local function getWeaponInfo(weaponId)
    return weaponConfig and type(weaponConfig[weaponId]) == "table" and weaponConfig[weaponId] or nil
end

local function getWeaponDisplayName(weaponId)
    local info = getWeaponInfo(weaponId)
    return info and tostring(info.name or info.desc or weaponId) or tostring(weaponId or "N/A")
end

local function getLastUnlockedWeaponId()
    local owned = getOwnedWeapons()
    if not owned then
        return nil
    end
    local bestId = nil
    local bestSort = -math.huge
    for weaponId in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        local order = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0
        if order > bestSort then
            bestSort = order
            bestId = weaponId
        end
    end
    return bestId
end

local refreshWeaponStatus
local selectedOwnedWeaponId = nil
local ownedWeaponOptionToId = {}
local ownedWeaponDropdown = nil

local function refreshOwnedWeaponOptions()
    local owned = getOwnedWeapons() or {}
    local ordered = {}
    for weaponId, weaponState in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        table.insert(ordered, {
            Id = weaponId,
            Name = getWeaponDisplayName(weaponId),
            Level = type(weaponState) == "table" and tonumber(weaponState.Level) or nil,
            Sort = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0,
        })
    end
    table.sort(ordered, function(left, right)
        return left.Sort < right.Sort
    end)

    local options = {}
    ownedWeaponOptionToId = {}
    for _, entry in ipairs(ordered) do
        local label = entry.Name .. (entry.Level and (" | Lv." .. entry.Level) or "")
        table.insert(options, label)
        ownedWeaponOptionToId[label] = entry.Id
    end
    if #options == 0 then
        options = {"Inventory is still loading..."}
    end
    if ownedWeaponDropdown then
        ownedWeaponDropdown:SetOptions(options, false)
    end
    selectedOwnedWeaponId = nil
    return options
end

ownedWeaponDropdown = WeaponInfoSection:AddDropdown({
    Name = "Owned Weapon",
    Options = refreshOwnedWeaponOptions(),
    Placeholder = "Choose an owned weapon...",
    Persist = false,
    Callback = function(value)
        selectedOwnedWeaponId = ownedWeaponOptionToId[value]
    end,
})

WeaponInfoSection:AddButton({
    Name = "Equip Selected Weapon",
    Description = "Equips the owned sword selected above",
    Persist = false,
    Callback = function()
        if not selectedOwnedWeaponId then
            setReviveStatus("Choose an owned weapon first", false)
            return
        end
        if fireRemote("equipWeapon", selectedOwnedWeaponId) then
            refreshWeaponStatus("equipping " .. getWeaponDisplayName(selectedOwnedWeaponId))
            setReviveStatus("Selected sword equip request sent", true)
        end
    end,
})

WeaponInfoSection:AddButton({
    Name = "Refresh Owned Weapons",
    Description = "Refresh after a new sword unlocks while the hub is open",
    Persist = false,
    Callback = function()
        local options = refreshOwnedWeaponOptions()
        setReviveStatus("Found " .. tostring(#options) .. " owned weapon entries", true)
    end,
})

WeaponInfoSection:AddLabel("Only live inventory entries are listed, so locked swords are never auto-equipped.")

refreshWeaponStatus = function(extra)
    local equipped = getEquippedWeaponId()
    local best = getLastUnlockedWeaponId()
    local text = "Sword: " .. getWeaponDisplayName(equipped)
    if best then
        text ..= " | Last unlocked: " .. getWeaponDisplayName(best)
    end
    if extra then
        text ..= " | " .. tostring(extra)
    end
    weaponStatusLabel.Text = text
    weaponStatusLabel.TextColor3 = equipped and COLORS.success or COLORS.muted
end

local function equipLastUnlockedWeapon()
    local bestId = getLastUnlockedWeaponId()
    if not bestId then
        refreshWeaponStatus("inventory unavailable")
        return false
    end
    local equipped = getEquippedWeaponId()
    if equipped ~= bestId then
        if not fireRemote("equipWeapon", bestId) then
            return false
        end
        refreshWeaponStatus("equipping " .. getWeaponDisplayName(bestId))
    else
        refreshWeaponStatus("best equipped")
    end
    return true
end

local autoEquipBestControl
autoEquipBestControl = UpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Equips the owned weapon with the highest order in the game's weapon data",
    Flag = "revive_auto_equip_best",
    Callback = function(enabled)
        state.autoEquipBest = enabled
        if overnightAutoEquipControl and overnightAutoEquipControl:Get() ~= enabled then
            overnightAutoEquipControl:Set(enabled, true)
        end
        if enabled then
            equipLastUnlockedWeapon()
        else
            refreshWeaponStatus()
        end
    end,
})

UpgradeSection:AddButton({
    Name = "Equip Last Unlocked Now",
    Description = "Runs one inventory check and equips your newest owned weapon",
    Persist = false,
    Callback = function()
        if equipLastUnlockedWeapon() then
            setReviveStatus("Last unlocked sword equip request sent", true)
        end
    end,
})

local autoUpgradeControl
autoUpgradeControl = UpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Enhances the sword currently held; automatically follows equipment changes",
    Flag = "revive_auto_upgrade",
    Callback = function(enabled)
        state.autoUpgrade = enabled
        if overnightAutoUpgradeControl and overnightAutoUpgradeControl:Get() ~= enabled then
            overnightAutoUpgradeControl:Set(enabled, true)
        end
        refreshWeaponStatus(enabled and "auto upgrade on" or nil)
    end,
})

UpgradeSection:AddLabel("Special weapons marked non-enhanceable by the game are safely skipped.")
task.defer(refreshWeaponStatus)

local autoRebirthFloor = 1
local autoRebirthControl
local rebirthStatusLabel = RebirthSection:AddLabel("Auto Rebirth: Waiting for live Death Tower requirement")
RebirthSection:AddSlider({
    Name = "Rebirth Floor",
    Min = 1,
    Max = 100,
    Default = 1,
    Step = 1,
    Flag = "revive_rebirth_floor",
    Callback = function(value)
        autoRebirthFloor = math.floor(value)
        if state.autoRebirth then
            fireRemote("SetAutoRebirth", true, autoRebirthFloor)
        end
    end,
})

autoRebirthControl = RebirthSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Directly uses the game's rebirth request when your live Death Tower requirement is met",
    Flag = "revive_auto_rebirth",
    Callback = function(enabled)
        state.autoRebirth = enabled
        -- Also mirror the game's optional native setting when its gamepass exists,
        -- but the hub's direct requirement-aware loop does not depend on it.
        if remotes.SetAutoRebirth then
            fireRemote("SetAutoRebirth", enabled, autoRebirthFloor)
        end
        if overnightAutoRebirthControl and overnightAutoRebirthControl:Get() ~= enabled then
            overnightAutoRebirthControl:Set(enabled, true)
        end
        rebirthStatusLabel.Text = enabled and "Auto Rebirth: Armed" or "Auto Rebirth: Disabled"
        rebirthStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Auto Rebirth armed from live tower progress" or "Auto Rebirth disabled", enabled and true or nil)
    end,
})

RebirthSection:AddLabel("The server validates Death Tower progress. Native gamepass auto is mirrored when available.")

do
local soulRingStore = nil
local soulRingUIStore = nil
local soulRingConfig = nil
pcall(function()
    soulRingStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("soulring"))
    soulRingUIStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("ui-store")).GetUIStore()
    soulRingConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbsoulring"))
end)

local function getSoulRingResourceCount(itemId)
    local playerData = soulRingUIStore and soulRingUIStore.playerData and soulRingUIStore.playerData()
    for _, item in ipairs(playerData and playerData.Inventory or {}) do
        if tostring(item.id) == itemId then
            return tonumber(item.count) or 0
        end
    end
    return 0
end

local function getSoulRingInfo()
    local rings = {}
    pcall(function()
        local atom = soulRingStore and soulRingStore.AtomSoulRings and soulRingStore.AtomSoulRings(0)
        rings = type(atom) == "function" and atom() or {}
    end)
    local ring = rings[1]
    local configEntry = nil
    if ring and soulRingConfig then
        configEntry = soulRingConfig[ring.Id]
        if not configEntry and type(soulRingConfig.get) == "function" then
            pcall(function()
                configEntry = soulRingConfig:get(ring.Id)
            end)
        end
    end
    return {
        Available = ring ~= nil,
        Id = ring and tostring(ring.Id) or "Locked",
        Name = configEntry and tostring(configEntry.name) or (ring and tostring(ring.Id) or "Locked"),
        Description = configEntry and tostring(configEntry.desc) or "Rebirth once to unlock Soul Ring slot 1.",
        Level = ring and (tonumber(ring.Level) or 0) or 0,
        Value = ring and (tonumber(ring.Value) or 0) or 0,
        SoulStones = getSoulRingResourceCount("SkillStone"),
        Rerolls = getSoulRingResourceCount("SkillRerollStone"),
    }
end

local function refreshSoulRingStatus(prefix)
    local info = getSoulRingInfo()
    if info.Available then
        soulRingStatusLabel.Text = string.format(
            "Soul Ring: %s | Level %d | %.2f%%",
            info.Name,
            info.Level,
            info.Value * 100
        )
        soulRingStatusLabel.TextColor3 = COLORS.success
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
        soulRingCurrencyLabel.TextColor3 = COLORS.muted
    else
        soulRingStatusLabel.Text = "Soul Ring: Slot 1 is locked until Rebirth 1"
        soulRingStatusLabel.TextColor3 = COLORS.error
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

local soulRingUpgradeBatch = 1
state.soulRingUpgradeBatch = soulRingUpgradeBatch
SoulRingSection:AddDropdown({
    Name = "Upgrade Levels Per Request",
    Options = {"1", "10", "50", "100"},
    Default = "1",
    Flag = "revive_soul_ring_upgrade_batch",
    Callback = function(value)
        soulRingUpgradeBatch = tonumber(value) or 1
        state.soulRingUpgradeBatch = soulRingUpgradeBatch
    end,
})

SoulRingSection:AddButton({
    Name = "Upgrade Soul Ring Now",
    Description = "Upgrades page 1, slot 1 with the selected batch size",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available then
            Window:Notify("Soul Ring", "Slot 1 unlocks after your first Rebirth.", 4)
            return
        end
        if fireRemote("enhanceSoulRing", 0, 0, soulRingUpgradeBatch) then
            task.delay(0.4, refreshSoulRingStatus)
        end
    end,
})

state.autoSoulRingControl = SoulRingSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Continuously upgrades page 1, slot 1 using your selected batch",
    Flag = "revive_auto_soul_ring",
    Callback = function(enabled)
        state.autoSoulRing = enabled
        if overnightAutoSoulRingControl and overnightAutoSoulRingControl:Get() ~= enabled then
            overnightAutoSoulRingControl:Set(enabled, true)
        end
        setReviveStatus(enabled and "Auto Soul Ring upgrade enabled" or "Auto Soul Ring upgrade disabled", enabled and true or nil)
    end,
})

SoulRingSection:AddButton({
    Name = "Reroll Soul Ring Once",
    Description = "Spends one reroll stone on page 1, slot 1",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available or info.Rerolls < 1 then
            Window:Notify("Soul Ring", "No available Soul Ring reroll.", 4)
            return
        end
        if fireRemote("rerollSoulRing", 0, 0, 1) then
            task.delay(0.5, refreshSoulRingStatus)
        end
    end,
})

SoulRingSection:AddLabel("Tracks the live Soul Ring name, level, Soul Stones, and reroll stones. Reroll stays manual.")
state.refreshSoulRingStatus = refreshSoulRingStatus
task.defer(refreshSoulRingStatus)
end

local selectedEnemy = 1
local tweenSpeed = 90
local tweenOffsetX = 0
local tweenOffsetY = 0
local tweenOffsetZ = -4.5
local activeEnemyTween = nil
local controlledHumanoid = nil
local originalAutoRotate = nil
local lockedEnemyFacing = setmetatable({}, {__mode = "k"})
bossFarmControl = nil
local manualTweenControl = nil

local battleStore = nil
local mainChallengeConfig = nil
pcall(function()
    battleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    mainChallengeConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbmainchallenge"))
end)

local function getLatestUnlockedBossLevel()
    if battleStore and type(battleStore.AtomMainLevel) == "function" then
        local ok, value = pcall(function()
            return battleStore.AtomMainLevel()()
        end)
        if ok and tonumber(value) then
            -- The store reports the last completed stage; the active/latest boss is the next slot.
            return math.clamp(math.floor(tonumber(value)) + 1, 1, 15)
        end
    end
    return math.clamp(selectedEnemy, 1, 15)
end

local function getBossName(level)
    local info = mainChallengeConfig and mainChallengeConfig[level]
    return info and tostring(info.name or ("Boss " .. level)) or ("Boss " .. level)
end

local function stopEnemyTween()
    if activeEnemyTween then
        activeEnemyTween:Cancel()
        activeEnemyTween = nil
    end
    if controlledHumanoid and controlledHumanoid.Parent and originalAutoRotate ~= nil then
        controlledHumanoid.AutoRotate = originalAutoRotate
    end
    controlledHumanoid = nil
    originalAutoRotate = nil
end

local function findEnemyPart(number)
    local folder = workspace:FindFirstChild("Enemies")
    local enemy = folder and folder:FindFirstChild(tostring(number))
    if not enemy then
        return nil
    end
    if enemy:IsA("BasePart") then
        return enemy
    end
    local preferred = enemy:FindFirstChild("HumanoidRootPart", true)
        or enemy:FindFirstChild("RootPart", true)
    if preferred and preferred:IsA("BasePart") then
        return preferred
    end
    if enemy:IsA("Model") and enemy.PrimaryPart then
        return enemy.PrimaryPart
    end
    return enemy:FindFirstChildWhichIsA("BasePart", true)
end

bossFarmControl = FarmSection:AddToggle({
    Name = "Auto Farm Latest Boss",
    Description = "Targets Main Level + 1, then follows the next boss as soon as it unlocks",
    Flag = "revive_boss_progression_farm",
    Callback = function(enabled)
        state.bossFarm = enabled
        if overnightBossFarmControl and overnightBossFarmControl:Get() ~= enabled then
            overnightBossFarmControl:Set(enabled, true)
        end
        if enabled and manualTweenControl then
            state.autoTween = false
            manualTweenControl:Set(false, true)
        end
        if not enabled then
            stopEnemyTween()
            farmStatusLabel.Text = "Farm: Disabled"
            farmStatusLabel.TextColor3 = COLORS.muted
        else
            local level = getLatestUnlockedBossLevel()
            farmStatusLabel.Text = "Farm: Level " .. level .. " - " .. getBossName(level)
            farmStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

FarmSection:AddLabel("Uses Main Level + 1: store 5 targets boss 6, then store 6 targets boss 7.")
FarmSection:AddLabel("Combat position uses the Enemy Tween speed and X / Y / Z sliders below.")

local enemyOptions = {}
for index = 1, 15 do
    table.insert(enemyOptions, tostring(index))
end

TweenSection:AddDropdown({
    Name = "Enemy",
    Options = enemyOptions,
    Default = "1",
    Flag = "revive_enemy",
    Callback = function(value)
        selectedEnemy = tonumber(value) or 1
        tweenStatusLabel.Text = "Tween: Enemy " .. tostring(selectedEnemy) .. " selected"
    end,
})

manualTweenControl = TweenSection:AddToggle({
    Name = "Auto Tween",
    Description = "Smoothly follows the selected enemy, stays upright, and faces its center",
    Flag = "revive_auto_tween",
    Callback = function(enabled)
        state.autoTween = enabled
        if enabled and bossFarmControl then
            state.bossFarm = false
            bossFarmControl:Set(false, true)
            farmStatusLabel.Text = "Farm: Disabled (manual tween active)"
            farmStatusLabel.TextColor3 = COLORS.muted
        end
        if not enabled then
            stopEnemyTween()
        end
    end,
})

TweenSection:AddSlider({
    Name = "Tween Speed",
    Min = 20,
    Max = 240,
    Default = tweenSpeed,
    Step = 5,
    Flag = "revive_tween_speed",
    Callback = function(value)
        tweenSpeed = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset X",
    Min = -15,
    Max = 15,
    Default = tweenOffsetX,
    Step = 0.5,
    Flag = "revive_offset_x",
    Callback = function(value)
        tweenOffsetX = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Y",
    Min = -10,
    Max = 15,
    Default = tweenOffsetY,
    Step = 0.5,
    Flag = "revive_offset_y",
    Callback = function(value)
        tweenOffsetY = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Z",
    Min = -15,
    Max = 15,
    Default = tweenOffsetZ,
    Step = 0.5,
    Flag = "revive_offset_z",
    Callback = function(value)
        tweenOffsetZ = value
    end,
})

local VISUAL_COLORS = {
    ["Void Purple"] = Color3.fromRGB(151, 70, 255),
    ["Royal Amethyst"] = Color3.fromRGB(196, 92, 255),
    ["Abyss Violet"] = Color3.fromRGB(92, 32, 180),
    ["Eclipse Magenta"] = Color3.fromRGB(232, 62, 255),
}
local visualColor = VISUAL_COLORS["Void Purple"]
local visualState = {outline = false, aura = false, trail = false, glow = false, wings = false, halo = false, nameplate = false, voidArmor = false}
local visualConnections = {}

local function markVisual(object)
    object:SetAttribute("VorReviveVisual", true)
    object:SetAttribute("VorReviveVisual", true)
    return object
end

local function trackVisualConnection(connection)
    table.insert(visualConnections, connection)
    return connection
end

local function makeNeonPart(name, size, cframe, parent, color, transparency, shape)
    local part = markVisual(Instance.new("Part"))
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
    part.Material = Enum.Material.Neon
    part.Color = color or visualColor
    part.Transparency = transparency or 0
    part.Shape = shape or Enum.PartType.Block
    part.Parent = parent
    return part
end

local function weldVisualPart(part, basePart)
    local weld = markVisual(Instance.new("WeldConstraint"))
    weld.Name = "VORVisualWeld"
    weld.Part0 = basePart
    weld.Part1 = part
    weld.Parent = part
    return weld
end

local function makeWingSegment(model, core, localStart, localFinish, width, color, transparency)
    local worldStart = core.CFrame:PointToWorldSpace(localStart)
    local worldFinish = core.CFrame:PointToWorldSpace(localFinish)
    local length = (worldFinish - worldStart).Magnitude
    if length <= 0.01 then
        return nil
    end
    local segment = makeNeonPart(
        "IceFeather",
        Vector3.new(length, width, width),
        CFrame.lookAt((worldStart + worldFinish) * 0.5, worldFinish) * CFrame.Angles(0, math.rad(90), 0),
        model,
        color,
        transparency,
        Enum.PartType.Cylinder
    )
    weldVisualPart(segment, core)
    return segment
end

local function createVorVoidWings(character, torso)
    local wingModel = markVisual(Instance.new("Model"))
    wingModel.Name = "VORVoidWings"
    wingModel.Parent = character

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "WingVoidBloom"
    highlight.Adornee = wingModel
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = Color3.fromRGB(215, 150, 255)
    highlight.OutlineTransparency = 0.18
    highlight.Parent = wingModel

    local wingMotors = {}
    local featherTips = {
        Vector3.new(1.15, 1.75, 0.02),
        Vector3.new(2.05, 2.05, 0.06),
        Vector3.new(2.95, 1.72, 0.10),
        Vector3.new(3.55, 1.05, 0.14),
        Vector3.new(3.62, 0.25, 0.18),
        Vector3.new(3.15, -0.55, 0.22),
        Vector3.new(2.35, -1.20, 0.26),
    }

    for _, side in ipairs({-1, 1}) do
        local core = makeNeonPart(
            side == -1 and "LeftWingCore" or "RightWingCore",
            Vector3.new(0.2, 0.2, 0.2),
            torso.CFrame * CFrame.new(0, 0.25, 0.62),
            wingModel,
            visualColor,
            1,
            Enum.PartType.Ball
        )
        local motor = markVisual(Instance.new("Motor6D"))
        motor.Name = side == -1 and "LeftWingMotor" or "RightWingMotor"
        motor.Part0 = torso
        motor.Part1 = core
        motor.C0 = CFrame.new(0, 0.25, 0.62)
        motor.Parent = torso
        wingMotors[side] = motor

        local previousTip = nil
        for index, baseTip in ipairs(featherTips) do
            local tip = Vector3.new(baseTip.X * side, baseTip.Y, baseTip.Z)
            local root = Vector3.new((0.20 + index * 0.075) * side, 0.46 - index * 0.07, 0)
            local middle = root:Lerp(tip, 0.48) + Vector3.new(0.12 * side, 0.30, -0.07)
            local width = 0.24 - index * 0.012
            local featherColor = index % 2 == 0 and visualColor:Lerp(Color3.fromRGB(218, 151, 255), 0.40) or visualColor
            makeWingSegment(wingModel, core, root, middle, width, featherColor, 0.05)
            makeWingSegment(wingModel, core, middle, tip, width * 0.72, featherColor:Lerp(Color3.fromRGB(221, 158, 255), 0.28), 0.10)

            local ribbonRoot = markVisual(Instance.new("Attachment"))
            ribbonRoot.Name = "FeatherRibbonRoot"
            ribbonRoot.Position = root
            ribbonRoot.Parent = core
            local ribbonTip = markVisual(Instance.new("Attachment"))
            ribbonTip.Name = "FeatherRibbonTip"
            ribbonTip.Position = tip
            ribbonTip.Parent = core
            local ribbon = markVisual(Instance.new("Beam"))
            ribbon.Name = "LuminousVoidFeather"
            ribbon.Attachment0 = ribbonRoot
            ribbon.Attachment1 = ribbonTip
            ribbon.Color = ColorSequence.new(featherColor, Color3.fromRGB(218, 151, 255))
            ribbon.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.28),
                NumberSequenceKeypoint.new(0.72, 0.40),
                NumberSequenceKeypoint.new(1, 0.78),
            })
            ribbon.Width0 = width * 1.9
            ribbon.Width1 = width * 0.42
            ribbon.LightEmission = 1
            ribbon.LightInfluence = 0
            ribbon.Segments = 5
            ribbon.FaceCamera = true
            ribbon.Parent = core

            local crystal = makeNeonPart(
                "FeatherCrystal",
                Vector3.new(width * 1.35, width * 1.35, width * 1.35),
                core.CFrame * CFrame.new(tip),
                wingModel,
                Color3.fromRGB(211, 123, 255),
                0.12,
                Enum.PartType.Ball
            )
            weldVisualPart(crystal, core)
            if previousTip then
                makeWingSegment(wingModel, core, previousTip, tip, 0.075, visualColor:Lerp(Color3.fromRGB(225, 169, 255), 0.52), 0.22)
            end
            previousTip = tip
        end

        local rootLight = markVisual(Instance.new("PointLight"))
        rootLight.Name = "WingRootGlow"
        rootLight.Color = visualColor
        rootLight.Brightness = 1.4
        rootLight.Range = 10
        rootLight.Shadows = false
        rootLight.Parent = core

        local sparkleAttachment = markVisual(Instance.new("Attachment"))
        sparkleAttachment.Name = "WingSparkleAttachment"
        sparkleAttachment.Parent = core
        local sparkles = markVisual(Instance.new("ParticleEmitter"))
        sparkles.Name = "WingVoidMotes"
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
        sparkles.LightEmission = 1
        sparkles.Rate = 5
        sparkles.Lifetime = NumberRange.new(0.7, 1.35)
        sparkles.Speed = NumberRange.new(0.35, 1.1)
        sparkles.SpreadAngle = Vector2.new(80, 80)
        sparkles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.20),
            NumberSequenceKeypoint.new(1, 0),
        })
        sparkles.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.10),
            NumberSequenceKeypoint.new(1, 1),
        })
        sparkles.Parent = sparkleAttachment
    end

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if not wingModel.Parent then
            return
        end
        local phase = math.sin((os.clock() - animationStart) * 2.15)
        for side, motor in pairs(wingMotors) do
            if motor.Parent then
                motor.C0 = CFrame.new(0, 0.25, 0.62) * CFrame.Angles(
                    math.rad(phase * 1.2),
                    math.rad(side * phase * 4.2),
                    math.rad(side * phase * 2.4)
                )
            end
        end
    end))
end

local function createVorVoidHalo(character, head)
    local haloModel = markVisual(Instance.new("Model"))
    haloModel.Name = "VORVoidHalo"
    haloModel.Parent = character

    local haloHighlight = markVisual(Instance.new("Highlight"))
    haloHighlight.Name = "HaloVoidBloom"
    haloHighlight.Adornee = haloModel
    haloHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    haloHighlight.FillColor = visualColor
    haloHighlight.FillTransparency = 0.48
    haloHighlight.OutlineColor = Color3.fromRGB(220, 153, 255)
    haloHighlight.OutlineTransparency = 0.08
    haloHighlight.Parent = haloModel

    local core = makeNeonPart(
        "HaloCore",
        Vector3.new(0.16, 0.16, 0.16),
        head.CFrame * CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0),
        haloModel,
        visualColor,
        1,
        Enum.PartType.Ball
    )
    local motor = markVisual(Instance.new("Motor6D"))
    motor.Name = "VORVoidHaloMotor"
    motor.Part0 = head
    motor.Part1 = core
    motor.C0 = CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0)
    motor.Parent = head

    local segmentCount = 18
    local radius = 1.22
    local segmentLength = (math.pi * 2 * radius / segmentCount) * 1.12
    for index = 0, segmentCount - 1 do
        local angle = (index / segmentCount) * math.pi * 2
        local localPosition = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local segment = makeNeonPart(
            "HaloSegment",
            Vector3.new(segmentLength, 0.09, 0.14),
            core.CFrame * CFrame.new(localPosition) * CFrame.Angles(0, -angle - math.pi * 0.5, 0),
            haloModel,
            index % 2 == 0 and visualColor:Lerp(Color3.fromRGB(221, 154, 255), 0.42) or visualColor,
            0.04
        )
        weldVisualPart(segment, core)

        if index % 3 == 0 then
            local diamond = makeNeonPart(
                "HaloVoidDiamond",
                Vector3.new(0.16, 0.16, 0.16),
                core.CFrame * CFrame.new(localPosition * 1.08) * CFrame.Angles(math.rad(45), math.rad(45), 0),
                haloModel,
                Color3.fromRGB(213, 124, 255),
                0.05
            )
            weldVisualPart(diamond, core)
        end
    end

    local haloLight = markVisual(Instance.new("PointLight"))
    haloLight.Name = "HaloGlow"
    haloLight.Color = visualColor
    haloLight.Brightness = 1.65
    haloLight.Range = 9
    haloLight.Shadows = false
    haloLight.Parent = core

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "HaloVoidAttachment"
    attachment.Parent = core
    local snow = markVisual(Instance.new("ParticleEmitter"))
    snow.Name = "HaloVoidMotes"
    snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    snow.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
    snow.LightEmission = 1
    snow.Rate = 7
    snow.Lifetime = NumberRange.new(0.8, 1.5)
    snow.Speed = NumberRange.new(0.15, 0.55)
    snow.SpreadAngle = Vector2.new(180, 180)
    snow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.17),
        NumberSequenceKeypoint.new(1, 0),
    })
    snow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.04),
        NumberSequenceKeypoint.new(1, 1),
    })
    snow.Parent = attachment

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if motor.Parent and haloModel.Parent then
            local elapsed = os.clock() - animationStart
            motor.C0 = CFrame.new(0, 1.58 + math.sin(elapsed * 1.7) * 0.055, 0)
                * CFrame.Angles(math.rad(-32), 0, 0)
                * CFrame.Angles(0, elapsed * 0.48, 0)
        end
    end))
end

local function createVorVoidArmor(character)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    if not torso or not head then
        return
    end

    local model = markVisual(Instance.new("Model"))
    model.Name = "VORVoidArmor"
    model.Parent = character

    local function armorPart(name, basePart, size, localCFrame, color, transparency, shape, material)
        if not basePart then return nil end
        local part = makeNeonPart(name, size, basePart.CFrame * localCFrame, model, color, transparency, shape)
        part.Material = material or Enum.Material.Metal
        weldVisualPart(part, basePart)
        return part
    end

    local voidBlack = Color3.fromRGB(5, 2, 11)
    local obsidian = Color3.fromRGB(15, 7, 27)
    local voidMetal = Color3.fromRGB(40, 15, 68)
    local voidViolet = visualColor
    local voidEnergy = Color3.fromRGB(208, 101, 255)

    -- The armor follows the avatar silhouette: blackened metal carries the
    -- weight while narrow violet seams supply the living VOR energy.
    armorPart(
        "VORVoidUndersuit",
        torso,
        torso.Size + Vector3.new(0.12, 0.10, 0.10),
        CFrame.new(0, -0.02, 0.02),
        voidBlack,
        0.30,
        nil,
        Enum.Material.SmoothPlastic
    )
    armorPart(
        "VORObsidianBreastplate",
        torso,
        Vector3.new(math.max(1.12, torso.Size.X * 0.62), math.max(1.12, torso.Size.Y * 0.60), 0.16),
        CFrame.new(0, 0.08, -(torso.Size.Z * 0.5 + 0.09)),
        obsidian,
        0.04
    )
    armorPart(
        "LeftVoidChestBlade",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(-torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(-16)),
        voidMetal,
        0.06
    )
    armorPart(
        "RightVoidChestBlade",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(16)),
        voidMetal,
        0.06
    )
    local chestCore = armorPart(
        "VORVoidCore",
        torso,
        Vector3.new(0.34, 0.34, 0.13),
        CFrame.new(0, 0.10, -(torso.Size.Z * 0.5 + 0.20)) * CFrame.Angles(0, 0, math.rad(45)),
        voidEnergy,
        0.00,
        nil,
        Enum.Material.Neon
    )
    armorPart(
        "VORObsidianBelt",
        torso,
        Vector3.new(torso.Size.X + 0.18, 0.22, torso.Size.Z + 0.16),
        CFrame.new(0, -(torso.Size.Y * 0.5 - 0.13), 0.02),
        voidBlack,
        0.04
    )

    for _, sideInfo in ipairs({{"Left", -1}, {"Right", 1}}) do
        local side = sideInfo[1]
        local sign = sideInfo[2]
        armorPart(
            side .. "VORPauldron",
            torso,
            Vector3.new(0.58, 0.28, 0.72),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.22), torso.Size.Y * 0.32, -0.01)
                * CFrame.Angles(0, 0, math.rad(sign * 18)),
            obsidian,
            0.02
        )
        armorPart(
            side .. "VoidShoulderSpike",
            torso,
            Vector3.new(0.16, 0.54, 0.22),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.48), torso.Size.Y * 0.42, -0.05)
                * CFrame.Angles(0, 0, math.rad(sign * 32)),
            voidViolet,
            0.02,
            nil,
            Enum.Material.Neon
        )

        local lowerArm = character:FindFirstChild(side .. "LowerArm") or character:FindFirstChild(side .. " Arm")
        if lowerArm then
            armorPart(
                side .. "VORVoidBracer",
                lowerArm,
                lowerArm.Size + Vector3.new(0.12, -math.min(0.10, lowerArm.Size.Y * 0.08), 0.14),
                CFrame.new(0, -lowerArm.Size.Y * 0.12, -0.02),
                voidMetal,
                0.08
            )
        end

        local upperLeg = character:FindFirstChild(side .. "UpperLeg")
        if upperLeg then
            armorPart(
                side .. "VORLegArmor",
                upperLeg,
                Vector3.new(upperLeg.Size.X + 0.10, upperLeg.Size.Y * 0.72, upperLeg.Size.Z + 0.12),
                CFrame.new(0, -upperLeg.Size.Y * 0.08, -0.03),
                voidBlack,
                0.10
            )
        end

        local lowerLeg = character:FindFirstChild(side .. "LowerLeg") or character:FindFirstChild(side .. " Leg")
        if lowerLeg then
            armorPart(
                side .. "VORVoidBoot",
                lowerLeg,
                lowerLeg.Size + Vector3.new(0.16, 0.08, 0.22),
                CFrame.new(0, -lowerLeg.Size.Y * 0.16, -0.05),
                obsidian,
                0.06
            )
            armorPart(
                side .. "BootVoidRune",
                lowerLeg,
                Vector3.new(math.max(0.18, lowerLeg.Size.X * 0.30), math.max(0.38, lowerLeg.Size.Y * 0.32), 0.13),
                CFrame.new(0, -lowerLeg.Size.Y * 0.25, -(lowerLeg.Size.Z * 0.5 + 0.08)),
                voidViolet,
                0.03,
                nil,
                Enum.Material.Neon
            )
        end
    end

    -- A narrow crown sits above the eyes and keeps the avatar face readable.
    armorPart(
        "VORVoidCrownBand",
        head,
        Vector3.new(math.max(1.35, head.Size.X * 0.82), 0.12, 0.10),
        CFrame.new(0, head.Size.Y * 0.30, -(head.Size.Z * 0.5 + 0.04)),
        obsidian,
        0.02
    )
    for crownIndex = -2, 2 do
        local crownHeight = crownIndex == 0 and 0.50 or (math.abs(crownIndex) == 1 and 0.38 or 0.27)
        armorPart(
            "VORCrownSpike" .. tostring(crownIndex + 3),
            head,
            Vector3.new(0.12, crownHeight, 0.12),
            CFrame.new(crownIndex * 0.25, head.Size.Y * 0.5 + crownHeight * 0.32, -0.08)
                * CFrame.Angles(0, 0, math.rad(crownIndex * -7)),
            crownIndex == 0 and voidEnergy or voidViolet,
            0.02,
            nil,
            Enum.Material.Neon
        )
    end

    if chestCore then
        local coreLight = markVisual(Instance.new("PointLight"))
        coreLight.Name = "SuitCoreGlow"
        coreLight.Color = voidEnergy
        coreLight.Brightness = 1.65
        coreLight.Range = 9
        coreLight.Shadows = false
        coreLight.Parent = chestCore
        local glowStart = os.clock()
        trackVisualConnection(RunService.RenderStepped:Connect(function()
            if coreLight.Parent then
                coreLight.Brightness = 1.25 + (math.sin((os.clock() - glowStart) * 2.8) + 1) * 0.34
            end
        end))
    end

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "VORVoidBloom"
    highlight.Adornee = model
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.82
    highlight.OutlineColor = voidEnergy
    highlight.OutlineTransparency = 0.14
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = model

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "VORVoidMoteAttachment"
    attachment.Position = Vector3.new(0, torso.Size.Y * 0.5, 0)
    attachment.Parent = torso
    local voidMotes = markVisual(Instance.new("ParticleEmitter"))
    voidMotes.Name = "VORVoidMotes"
    voidMotes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    voidMotes.Color = ColorSequence.new(voidViolet, voidEnergy)
    voidMotes.LightEmission = 1
    voidMotes.Rate = 12
    voidMotes.Lifetime = NumberRange.new(0.9, 1.8)
    voidMotes.Speed = NumberRange.new(0.25, 1.15)
    voidMotes.Acceleration = Vector3.new(0, 1.8, 0)
    voidMotes.SpreadAngle = Vector2.new(180, 180)
    voidMotes.Rotation = NumberRange.new(0, 360)
    voidMotes.RotSpeed = NumberRange.new(-55, 55)
    voidMotes.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.10),
        NumberSequenceKeypoint.new(0.48, 0.22),
        NumberSequenceKeypoint.new(1, 0),
    })
    voidMotes.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.28),
        NumberSequenceKeypoint.new(0.45, 0.08),
        NumberSequenceKeypoint.new(1, 1),
    })
    voidMotes.Parent = attachment

    -- Four light shards orbit the torso like fragments pulled into the core.
    local orbitCore = makeNeonPart(
        "VOROrbitCore",
        Vector3.new(0.10, 0.10, 0.10),
        torso.CFrame,
        model,
        voidViolet,
        1,
        Enum.PartType.Ball
    )
    local orbitMotor = markVisual(Instance.new("Motor6D"))
    orbitMotor.Name = "VORVoidOrbitMotor"
    orbitMotor.Part0 = torso
    orbitMotor.Part1 = orbitCore
    orbitMotor.C0 = CFrame.new()
    orbitMotor.Parent = torso
    for shardIndex = 0, 3 do
        local angle = shardIndex * math.pi * 0.5
        local shard = makeNeonPart(
            "VOROrbitShard" .. tostring(shardIndex + 1),
            Vector3.new(0.10, 0.38, 0.10),
            orbitCore.CFrame
                * CFrame.new(math.cos(angle) * 1.35, (shardIndex % 2 == 0) and 0.42 or -0.30, math.sin(angle) * 1.35)
                * CFrame.Angles(math.rad(24), 0, math.rad(45)),
            model,
            shardIndex % 2 == 0 and voidEnergy or voidViolet,
            0.05
        )
        weldVisualPart(shard, orbitCore)
    end
    local orbitStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if orbitMotor.Parent and model.Parent then
            local elapsed = os.clock() - orbitStart
            orbitMotor.C0 = CFrame.new(0, math.sin(elapsed * 1.6) * 0.07, 0)
                * CFrame.Angles(0, elapsed * 0.72, 0)
        end
    end))
end

local function clearCharacterVisuals(character)
    character = character or LocalPlayer.Character
    if not character then
        return
    end
    for index = #visualConnections, 1, -1 do
        local connection = visualConnections[index]
        pcall(function()
            connection:Disconnect()
        end)
        visualConnections[index] = nil
    end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:GetAttribute("VorReviveVisual") == true or descendant:GetAttribute("CodexReviveVisual") == true then
            descendant:Destroy()
        end
    end
end

local function getLocalNameplateRoot()
    local worldGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    worldGui = worldGui and worldGui:FindFirstChild("World")
    return worldGui and worldGui:FindFirstChild(LocalPlayer.Name)
end

local function applyVorNameplate()
    local nameplateRoot = getLocalNameplateRoot()
    if not nameplateRoot then
        return false
    end
    local changed = false
    for _, descendant in ipairs(nameplateRoot:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local managed = descendant:GetAttribute("VORNameplateManaged") == true
                or descendant:GetAttribute("CodexNameplateManaged") == true
            local isPlayerName = descendant.Text == LocalPlayer.Name or descendant.Text == LocalPlayer.DisplayName
            if managed or isPlayerName then
                if not managed then
                    descendant:SetAttribute("VOROriginalNameplateText", descendant.Text)
                    descendant:SetAttribute("VORNameplateManaged", true)
                end
                if descendant.Text ~= "VOR" then
                    descendant.Text = "VOR"
                end
                changed = true
            end
        end
    end
    return changed
end

local function restoreVorNameplate()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local worldGui = playerGui and playerGui:FindFirstChild("World")
    if not worldGui then
        return
    end
    for _, descendant in ipairs(worldGui:GetDescendants()) do
        if descendant:IsA("TextLabel")
            and (descendant:GetAttribute("VORNameplateManaged") == true
                or descendant:GetAttribute("CodexNameplateManaged") == true) then
            descendant.Text = tostring(
                descendant:GetAttribute("VOROriginalNameplateText")
                or descendant:GetAttribute("CodexOriginalNameplateText")
                or LocalPlayer.DisplayName
            )
            descendant:SetAttribute("VOROriginalNameplateText", nil)
            descendant:SetAttribute("VORNameplateManaged", nil)
            descendant:SetAttribute("CodexOriginalNameplateText", nil)
            descendant:SetAttribute("CodexNameplateManaged", nil)
        end
    end
end

local function applyCharacterVisuals()
    if visualState.nameplate then
        applyVorNameplate()
    else
        restoreVorNameplate()
    end
    local character = LocalPlayer.Character
    if not character then
        return
    end
    clearCharacterVisuals(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    if visualState.outline then
        local highlight = markVisual(Instance.new("Highlight"))
        highlight.Name = "VORVoidOutline"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = visualColor
        highlight.FillTransparency = 0.78
        highlight.OutlineColor = Color3.fromRGB(220, 151, 255)
        highlight.OutlineTransparency = 0.08
        highlight.Parent = character
    end

    if visualState.aura then
        local attachment = markVisual(Instance.new("Attachment"))
        attachment.Name = "VORVoidAuraAttachment"
        attachment.Parent = root
        local emitter = markVisual(Instance.new("ParticleEmitter"))
        emitter.Name = "VORVoidAura"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(visualColor, Color3.fromRGB(221, 151, 255))
        emitter.LightEmission = 0.75
        emitter.Rate = 22
        emitter.Lifetime = NumberRange.new(0.7, 1.4)
        emitter.Speed = NumberRange.new(1.5, 4)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.RotSpeed = NumberRange.new(-80, 80)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.28),
            NumberSequenceKeypoint.new(0.55, 0.16),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Parent = attachment
    end

    if visualState.trail then
        local attachment0 = markVisual(Instance.new("Attachment"))
        attachment0.Name = "VORTrailTop"
        attachment0.Position = Vector3.new(0, 1.7, 0)
        attachment0.Parent = root
        local attachment1 = markVisual(Instance.new("Attachment"))
        attachment1.Name = "VORTrailBottom"
        attachment1.Position = Vector3.new(0, -1.7, 0)
        attachment1.Parent = root
        local trail = markVisual(Instance.new("Trail"))
        trail.Name = "VORVoidTrail"
        trail.Attachment0 = attachment0
        trail.Attachment1 = attachment1
        trail.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
        trail.LightEmission = 0.8
        trail.Lifetime = 0.32
        trail.MinLength = 0.12
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Parent = root
    end

    if visualState.glow then
        local light = markVisual(Instance.new("PointLight"))
        light.Name = "VORVoidGlow"
        light.Color = visualColor
        light.Brightness = 1.35
        light.Range = 12
        light.Shadows = false
        light.Parent = root
    end

    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
    local head = character:FindFirstChild("Head")
    if visualState.wings and torso then
        createVorVoidWings(character, torso)
    end
    if visualState.halo and head then
        createVorVoidHalo(character, head)
    end
    if visualState.voidArmor then
        createVorVoidArmor(character)
    end

    local activeVisuals = {}
    for key, enabled in pairs(visualState) do
        if enabled then
            table.insert(activeVisuals, key)
        end
    end
    table.sort(activeVisuals)
    visualStatusLabel.Text = #activeVisuals > 0
        and ("Visuals: " .. table.concat(activeVisuals, ", "))
        or "Visuals: All effects disabled"
    visualStatusLabel.TextColor3 = COLORS.success
end

VisualSection:AddDropdown({
    Name = "Visual Color",
    Options = {"Void Purple", "Royal Amethyst", "Abyss Violet", "Eclipse Magenta"},
    Default = "Void Purple",
    Flag = "revive_visual_color",
    Callback = function(value)
        visualColor = VISUAL_COLORS[value] or VISUAL_COLORS["Void Purple"]
        applyCharacterVisuals()
    end,
})

for _, option in ipairs({
    {Name = "Void Outline", Key = "outline", Description = "Violet VOR character highlight"},
    {Name = "Void Aura", Key = "aura", Description = "Glowing purple void particles around your body"},
    {Name = "Void Trail", Key = "trail", Description = "Leaves a dark-violet energy trail while moving"},
    {Name = "Body Glow", Key = "glow", Description = "Soft colored light around your character"},
    {Name = "VOR Void Wings", Key = "wings", Description = "Layered violet energy wings with a gentle living motion"},
    {Name = "VOR Void Halo", Key = "halo", Description = "Floating rotating void halo with purple motes"},
    {Name = "VOR Nameplate", Key = "nameplate", Description = "Locally changes your overhead in-game name to VOR; your Roblox account name is untouched"},
}) do
    VisualSection:AddToggle({
        Name = option.Name,
        Description = option.Description,
        Flag = "revive_visual_" .. option.Key,
        Callback = function(enabled)
            visualState[option.Key] = enabled
            applyCharacterVisuals()
        end,
    })
end

VisualInfoSection:AddLabel("VOR wings, halo, and armor use asset-free local geometry, so every purple preset stays compatible.")
VisualInfoSection:AddLabel("VOR Nameplate is local-only and restores your real display name when disabled.")

local catalogOutfitId = ""
local originalAvatarDescription = nil
local activeCatalogDescription = nil
local voidArmorControl

local function getCharacterHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildWhichIsA("Humanoid") or nil
end

local function applyLocalDescription(description, statusText)
    local humanoid = getCharacterHumanoid()
    if not humanoid or not description then
        outfitStatusLabel.Text = "Outfit: Waiting for your character"
        outfitStatusLabel.TextColor3 = COLORS.error
        return false
    end
    if not originalAvatarDescription then
        local captured, currentDescription = pcall(function()
            return humanoid:GetAppliedDescription()
        end)
        if captured then
            originalAvatarDescription = currentDescription
        end
    end
    local ok = pcall(function()
        humanoid:ApplyDescription(description:Clone())
    end)
    outfitStatusLabel.Text = ok and ("Outfit: " .. statusText) or "Outfit: Preview was blocked by this game"
    outfitStatusLabel.TextColor3 = ok and COLORS.success or COLORS.error
    if ok then
        task.delay(0.55, function()
            if gui.Parent then applyCharacterVisuals() end
        end)
    end
    return ok
end

OutfitSection:AddInput({
    Name = "Marketplace Outfit ID",
    Placeholder = "Enter a public Roblox outfit ID...",
    Default = "",
    Flag = "codex_tools_marketplace_outfit_id",
    Callback = function(value)
        catalogOutfitId = tostring(value or ""):match("%d+") or ""
    end,
})

OutfitSection:AddButton({
    Name = "Preview Outfit Locally",
    Description = "Loads a public Roblox avatar outfit for your screen only; it does not grant ownership",
    Persist = false,
    Callback = function()
        local outfitId = tonumber(catalogOutfitId)
        if not outfitId or outfitId <= 0 then
            Window:Notify("Outfit Tools", "Enter a valid public outfit ID first", 4)
            return
        end
        outfitStatusLabel.Text = "Outfit: Loading marketplace outfit " .. outfitId .. "..."
        outfitStatusLabel.TextColor3 = COLORS.muted
        task.spawn(function()
            local ok, description = pcall(function()
                return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
            end)
            if not ok or not description then
                outfitStatusLabel.Text = "Outfit: ID could not be loaded"
                outfitStatusLabel.TextColor3 = COLORS.error
                return
            end
            activeCatalogDescription = description:Clone()
            if applyLocalDescription(activeCatalogDescription, "Local marketplace preview " .. outfitId) then
                Window:Notify("Outfit Tools", "Local preview applied; no item was purchased", 4)
            end
        end)
    end,
})

OutfitSection:AddButton({
    Name = "Restore My Roblox Avatar",
    Description = "Removes the local marketplace preview and restores your real avatar appearance",
    Persist = false,
    Callback = function()
        task.spawn(function()
            activeCatalogDescription = nil
            local description = originalAvatarDescription
            if not description then
                local ok, fetched = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
                end)
                description = ok and fetched or nil
            end
            if voidArmorControl then voidArmorControl:Set(false) end
            if applyLocalDescription(description, "Your Roblox avatar restored") then
                originalAvatarDescription = nil
            end
        end)
    end,
})

voidArmorControl = VoidArmorSection:AddToggle({
    Name = "VOR Void Armor",
    Description = "Blackened metal armor, violet core, crown spikes, bracers, boots, void motes, and orbiting shards",
    Flag = "codex_tools_frozen_everest_outfit",
    Callback = function(enabled)
        visualState.voidArmor = enabled
        if enabled then
            visualColor = VISUAL_COLORS["Void Purple"]
        end
        applyCharacterVisuals()
        outfitStatusLabel.Text = enabled and "Outfit: VOR Void Armor equipped" or "Outfit: VOR Void Armor removed"
        outfitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

VoidArmorSection:AddButton({
    Name = "Equip Full VOR Armor",
    Description = "Equips the complete black-metal and violet-energy armor preset in one click",
    Persist = false,
    Callback = function()
        voidArmorControl:Set(true)
        Window:Notify("VOR Void Armor", "VOR Void Armor equipped locally", 4)
    end,
})

VoidArmorSection:AddLabel("Marketplace previews and VOR Void Armor are cosmetic only; they do not add items to your Roblox inventory.")

track(LocalPlayer.PlayerGui.DescendantAdded:Connect(function(descendant)
    if visualState.nameplate and descendant:IsA("TextLabel") then
        task.defer(applyVorNameplate)
    end
end))

-- Linked overnight controls mirror the real categorized controls. They are not
-- saved twice; the underlying controls keep the single persistent profile flag.
overnightMultiHitControl = OvernightSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Fast confirmed round-robin combat while you remain anywhere",
    Persist = false,
    Callback = function(enabled)
        if multiHitControl and multiHitControl:Get() ~= enabled then
            multiHitControl:Set(enabled)
        end
    end,
})

overnightBossFarmControl = OvernightSection:AddToggle({
    Name = "Follow Latest Boss",
    Description = "Keeps your character positioned at the newest progression boss",
    Persist = false,
    Callback = function(enabled)
        if bossFarmControl and bossFarmControl:Get() ~= enabled then
            bossFarmControl:Set(enabled)
        end
    end,
})

overnightReaperControl = OvernightSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Cooldown-aware companion Reaper automation without duplicate requests",
    Persist = false,
    Callback = function(enabled)
        if autoReaperControl and autoReaperControl:Get() ~= enabled then
            autoReaperControl:Set(enabled)
        end
    end,
})

overnightDeathKingControl = OvernightSection:AddToggle({
    Name = "Auto Death King",
    Description = "Continuously advances the Death King special boss",
    Persist = false,
    Callback = function(enabled)
        if deathKingControl and deathKingControl:Get() ~= enabled then
            deathKingControl:Set(enabled)
        end
    end,
})

overnightCursedKingControl = OvernightSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Continuously advances Cursed King levels, including before native auto-resume unlocks",
    Persist = false,
    Callback = function(enabled)
        if cursedKingControl and cursedKingControl:Get() ~= enabled then
            cursedKingControl:Set(enabled)
        end
    end,
})

overnightNightmareControl = OvernightSection:AddToggle({
    Name = "Auto Nightmare / Death Tower",
    Description = "AFK climbs each Death Tower section toward the next rebirth requirement",
    Persist = false,
    Callback = function(enabled)
        if nightmareControl and nightmareControl:Get() ~= enabled then
            nightmareControl:Set(enabled)
        end
    end,
})

overnightSpecialPriorityControl = OvernightSection:AddToggle({
    Name = "Special Boss Priority Loop",
    Description = "Runs the selected special wins, timed Multi Hit, and next tower section automatically",
    Persist = false,
    Callback = function(enabled)
        if specialPriorityControl and specialPriorityControl:Get() ~= enabled then
            specialPriorityControl:Set(enabled)
        end
    end,
})

overnightAutoEquipControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Follows the newest sword in your live owned inventory",
    Persist = false,
    Callback = function(enabled)
        if autoEquipBestControl and autoEquipBestControl:Get() ~= enabled then
            autoEquipBestControl:Set(enabled)
        end
    end,
})

overnightAutoUpgradeControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Continuously upgrades the sword currently being held",
    Persist = false,
    Callback = function(enabled)
        if autoUpgradeControl and autoUpgradeControl:Get() ~= enabled then
            autoUpgradeControl:Set(enabled)
        end
    end,
})

overnightAutoRebirthControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Rebirths as soon as the live Death Tower requirement is met",
    Persist = false,
    Callback = function(enabled)
        if autoRebirthControl and autoRebirthControl:Get() ~= enabled then
            autoRebirthControl:Set(enabled)
        end
    end,
})

overnightAutoSoulRingControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Uses the Soul Ring batch selected in Progress",
    Persist = false,
    Callback = function(enabled)
        if state.autoSoulRingControl and state.autoSoulRingControl:Get() ~= enabled then
            state.autoSoulRingControl:Set(enabled)
        end
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Tower AFK",
    Description = "Enables only Anti-AFK and Auto Nightmare; every non-tower feature stays optional",
    Persist = false,
    Callback = function()
        if specialPriorityControl:Get() then
            specialPriorityControl:Set(false)
        end
        if cursedKingControl:Get() then
            cursedKingControl:Set(false)
        end
        if deathKingControl:Get() then
            deathKingControl:Set(false)
        end
        antiAfkControl:Set(true)
        nightmareControl:Set(true)
        setReviveStatus("Tower-only AFK enabled", true)
        Window:Notify("Tower AFK", "Anti-AFK and Auto Nightmare are running; other features remain optional", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Multi-Hit AFK",
    Description = "Runs Anti-AFK plus standalone Multi Hit for the ground bosses",
    Persist = false,
    Callback = function()
        specialPriorityControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        antiAfkControl:Set(true)
        multiHitControl:Set(true)
        setReviveStatus("Standalone Multi-Hit AFK enabled", true)
        Window:Notify("Multi-Hit AFK", "Anti-AFK and all-boss Multi Hit are running", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Priority AFK",
    Description = "Runs Anti-AFK plus the selected special boss and its built-in Multi Hit phase",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(true)
        specialPriorityControl:Set(true)
        setReviveStatus("Special Priority AFK enabled for " .. priority.target, true)
        Window:Notify("Priority AFK", priority.target .. " will alternate with timed Multi Hit", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Stop Overnight Automation",
    Description = "Stops the linked overnight features without changing visual settings",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(false)
        specialPriorityControl:Set(false)
        multiHitControl:Set(false)
        bossFarmControl:Set(false)
        autoReaperControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        autoEquipBestControl:Set(false)
        autoUpgradeControl:Set(false)
        state.autoSoulRingControl:Set(false)
        dailyRewardControl:Set(false)
        onlineRewardControl:Set(false)
        soulSpawnerControl:Set(false)
        starterRewardControl:Set(false)
        bossRewardControl:Set(false)
        setReviveStatus("Overnight automation stopped", nil)
    end,
})

OvernightUpgradeSection:AddLabel("Choose Tower AFK, standalone Multi-Hit AFK, or Priority AFK. Auto Rebirth remains optional.")

track(LocalPlayer.CharacterAdded:Connect(function()
    multiHitNeedsBootstrap = true
    nightmarePortalPrimedCharacter = nil
    task.wait(0.55)
    if activeCatalogDescription then
        local humanoid = getCharacterHumanoid()
        if humanoid then
            pcall(function()
                humanoid:ApplyDescription(activeCatalogDescription:Clone())
            end)
            task.wait(0.35)
        end
    end
    applyCharacterVisuals()
end))

local lastRun = {}
local function isDue(key, interval)
    local now = os.clock()
    if now - (lastRun[key] or 0) < interval then
        return false
    end
    lastRun[key] = now
    return true
end

task.spawn(function()
    while gui.Parent do
        if not state.specialPriority
            and (state.autoAttack or state.bossFarm)
            and not priority.isMultiHitActive()
            and (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) ~= 7
            and isDue("attack", 0.12)
        then
            fireRemote("attack", getLatestUnlockedBossLevel())
        end
        if state.demonRealm and isDue("demonRealmPoll", 0.10) then
            state.demonRealmInfo = state.refreshDemonRealmStatus()
            if state.demonRealmInfo.InRealm then
                if isDue("demonRealmAttack", 0.08) then
                    fireRemote("attack", nil)
                end
            elseif state.demonRealmInfo.Open and isDue("demonRealmEnter", 1.25) then
                if fireRemote("enterTimeLimitBossReq") then
                    state.demonRealmStatusLabel.Text = "Demon Realm: Entry requested | Waiting for server confirmation"
                    state.demonRealmStatusLabel.TextColor3 = COLORS.success
                end
            end
        elseif isDue("demonRealmStatusRefresh", 1) then
            state.refreshDemonRealmStatus()
        end
        if state.reaper and isDue("reaperPoll", 0.25) then
            local reaperInfo = refreshReaperStatus()
            local serverNow = workspace:GetServerTimeNow()
            if reaperInfo.Unlocked
                and reaperInfo.MaxHP > 1
                and reaperInfo.Remaining <= 0
                and serverNow >= reaperLocalCooldownUntil
                and isDue("reaperSend", 1)
            then
                if fireRemote("staticReaperReq") then
                    -- The battle atom can update a moment after the response. This local
                    -- gate prevents duplicate requests and the game's false locked toast.
                    reaperLocalCooldownUntil = serverNow + reaperInterval
                    reaperStatusLabel.Text = "Reaper: Request sent | Waiting for confirmation"
                    reaperStatusLabel.TextColor3 = COLORS.muted
                end
            end
        end
        if state.specialPriority then
            -- Priority owns combat while enabled. Persisted or newly-clicked
            -- conflicting controls are silently returned to off instead of
            -- being allowed to cancel the requested priority loop.
            if state.autoAttack then state.autoAttack = false; attackControl:Set(false, true) end
            if state.deathKing then state.deathKing = false; deathKingControl:Set(false, true) end
            if state.cursedKing then state.cursedKing = false; cursedKingControl:Set(false, true) end
            if state.nightmare then state.nightmare = false; nightmareControl:Set(false, true) end
            if state.challengeOne then state.challengeOne = false; challengeOneControl:Set(false, true) end
            if state.challengeFive then state.challengeFive = false; challengeFiveControl:Set(false, true) end
            if state.bossFarm then
                state.bossFarm = false
                bossFarmControl:Set(false, true)
                if overnightBossFarmControl then overnightBossFarmControl:Set(false, true) end
                stopEnemyTween()
            end
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local progressChanged = priority.observeProgress()
            if progressChanged then
                -- Let the multi-hit worker observe the new phase before doing more special work.
            elseif priority.phase == "quit" then
                local exitTimedOut = os.clock() >= priority.quitDeadline
                if battleState == 0 or exitTimedOut then
                    priority.phase = "multi"
                    priority.multiEndAt = os.clock() + priority.multiSeconds
                    state.priorityMulti = true
                    multiHitNeedsBootstrap = true
                    priorityStatusLabel.Text = (exitTimedOut and "Special Priority: Exit timeout | " or "Special Priority: Arena exited | ")
                        .. "Multi Hit for " .. priority.multiSeconds .. "s"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityQuitRetry", 0.35) then
                    fireRemote("levelTimeLimitBossReq")
                    priorityStatusLabel.Text = "Special Priority: Quitting Tower before bridge Multi Hit"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif priority.phase == "multi" then
                local remaining = math.max(0, priority.multiEndAt - os.clock())
                state.priorityMulti = remaining > 0
                priorityStatusLabel.Text = string.format("Special Priority: Multi Hit %.1fs remaining", remaining)
                priorityStatusLabel.TextColor3 = COLORS.success
                if remaining <= 0 then
                    state.priorityMulti = false
                    priority.phase = "special"
                    priority.nextStartAt = os.clock() + 0.5
                    priorityStatusLabel.Text = "Special Priority: Returning to " .. priority.target
                end
            elseif priority.activeMode then
                local activeInfo = getSpecialBossState(priority.activeMode)
                if activeInfo.Level > priority.activeLevelBefore then
                    -- Death Tower and Cursed King can replace a defeated boss with the
                    -- next section without ever returning AtomBattleState to zero.
                    priority.complete(true)
                elseif specialResultSerial > priority.seenResultSerial then
                    priority.seenResultSerial = specialResultSerial
                    priority.complete(specialResultSuccess)
                elseif battleState == priority.activeMode then
                    if isDue("prioritySpecialAttack", 0.10) then
                        fireRemote("attack", nil)
                    end
                elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                    priority.complete(false)
                end
            elseif battleState == RED_DRAGON_MODE or battleState == GREEN_DRAGON_MODE or battleState == NIGHTMARE_MODE then
                local matchesTarget = priority.target == "Cycle All"
                    or (priority.target == "Nightmare" and battleState == NIGHTMARE_MODE)
                    or (priority.target == "Cursed King" and battleState == GREEN_DRAGON_MODE)
                    or (priority.target == "Death King" and battleState == RED_DRAGON_MODE)
                if matchesTarget then
                    local activeInfo = getSpecialBossState(battleState)
                    priority.activeMode = battleState
                    priority.activeLevelBefore = activeInfo.Level
                    priority.seenResultSerial = specialResultSerial
                    priority.nextStartAt = os.clock() + 2.5
                    priorityStatusLabel.Text = "Special Priority: Resumed " .. priority.modeName(battleState) .. " section"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityWrongSpecial", 1) then
                    priorityStatusLabel.Text = "Special Priority: Waiting for the selected special battle"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                if not priority.start() and isDue("priorityWaiting", 2) then
                    local required = priority.target == "Cursed King" and greenDragonUnlockLevel
                        or (priority.target == "Death King" and redDragonUnlockLevel or nightmareUnlockLevel)
                    priorityStatusLabel.Text = "Special Priority: Waiting for Main Level " .. required
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif isDue("priorityBattleWait", 1) then
                priorityStatusLabel.Text = "Special Priority: Waiting for current battle to finish"
                priorityStatusLabel.TextColor3 = COLORS.muted
            end
        elseif state.deathKing and isDue("deathKingPoll", 0.25) then
            local deathInfo = refreshDeathKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if deathInfo.BattleState == RED_DRAGON_MODE and isDue("deathKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif deathInfo.Unlocked
                and deathInfo.BattleState == 0
                and serverNow - specialLastStart[RED_DRAGON_MODE] >= (deathInfo.NativeAutoAvailable and 5 or 2)
            then
                armDeathKingAuto()
            end
        elseif state.cursedKing and isDue("cursedKingPoll", 0.25) then
            local cursedInfo = refreshCursedKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if cursedInfo.BattleState == GREEN_DRAGON_MODE and isDue("cursedKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif cursedInfo.Unlocked
                and cursedInfo.BattleState == 0
                and serverNow - specialLastStart[GREEN_DRAGON_MODE] >= (cursedInfo.NativeAutoAvailable and 5 or 2)
            then
                armCursedKingAuto()
            end
        elseif state.nightmare and isDue("nightmarePoll", 0.25) then
            local nightmareInfo = refreshNightmareStatus()
            local serverNow = workspace:GetServerTimeNow()
            if nightmareInfo.BattleState == NIGHTMARE_MODE and isDue("nightmareAttack", 0.10) then
                fireRemote("attack", nil)
            elseif nightmareInfo.Unlocked
                and nightmareInfo.BattleState == 0
                and serverNow - specialLastStart[NIGHTMARE_MODE] >= (nightmareInfo.NativeAutoAvailable and 5 or 2)
            then
                armNightmareAuto()
            end
        end
        if state.autoRebirth and isDue("hubAutoRebirth", 0.75) then
            local currentRebirth = tonumber(readAtomValue(rebirthStore, "AtomRebirth")) or 0
            local towerLevel = tonumber(readAtomValue(reaperBattleStore, "AtomTowerLevel")) or 0
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local requiredTower = rebirthTowerLevelRatio * (currentRebirth + 1)
            rebirthStatusLabel.Text = string.format(
                "Auto Rebirth: Rebirth %d | Tower %d / %d",
                currentRebirth,
                towerLevel,
                requiredTower
            )
            rebirthStatusLabel.TextColor3 = towerLevel >= requiredTower and COLORS.success or COLORS.muted
            if towerLevel >= requiredTower and battleState == 0 and isDue("hubAutoRebirthSend", 2) then
                if fireRemote("rebirth") then
                    rebirthStatusLabel.Text = "Auto Rebirth: Requirement met | Request sent"
                    setReviveStatus("Rebirth request sent at Death Tower " .. towerLevel, true)
                end
            end
        end
        if state.autoSoulRing and isDue("autoSoulRingUpgrade", 0.75) then
            local ringInfo = state.refreshSoulRingStatus()
            if ringInfo.Available and ringInfo.SoulStones > 0 then
                fireRemote("enhanceSoulRing", 0, 0, state.soulRingUpgradeBatch)
            end
        elseif isDue("soulRingStatusRefresh", 2) then
            state.refreshSoulRingStatus()
        end
        if visualState.nameplate and isDue("codexNameplate", 0.25) then
            applyVorNameplate()
        end
        if state.discordReminder and isDue("discordReminder", 1) then
            local remaining = math.max(0, math.ceil(nextDiscordReminderAt - os.clock()))
            if remaining <= 0 then
                showDiscordReminder()
            else
                discordReminderStatusLabel.Text = string.format(
                    "Discord Reminder: Enabled | Next in %02d:%02d",
                    math.floor(remaining / 60),
                    remaining % 60
                )
                discordReminderStatusLabel.TextColor3 = COLORS.success
            end
        end
        if state.groupReward and isDue("group", 30) then
            fireRemote("getGroupReward")
        end
        if state.challengeOne and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 0)
        elseif state.challengeFive and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 1)
        end
        if state.autoEquipBest and isDue("equipBest", 0.80) then
            equipLastUnlockedWeapon()
        end
        if state.autoUpgrade and isDue("upgrade", 0.35) then
            local equippedId = getEquippedWeaponId()
            local info = equippedId and getWeaponInfo(equippedId) or nil
            if equippedId and (not info or info.canEnhance ~= false) then
                fireRemote("enhanceWeapon", equippedId)
            elseif equippedId and isDue("upgradeSkippedStatus", 2) then
                refreshWeaponStatus("not enhanceable")
            end
        end
        if state.dailyReward and isDue("daily", 30) then
            fireRemote("getSignReward")
        end
        if state.onlineReward and isDue("online", 5) then
            fireRemote("receiveOnlineTimeReward")
        end
        if state.soulSpawner and isDue("soul", 3) then
            fireRemote("claimSoulSpawner")
        end
        if state.starterRewards and isDue("starter", 10) then
            for index = 1, 5 do
                fireRemote("claimChallengeReward", index)
            end
        end
        if state.bossRewards and isDue("boss", 10) then
            for index = 1, 6 do
                fireRemote("claimTimeLimitBossReward", index)
            end
        end
        task.wait(0.05)
    end
end)

priority.waitForBossConfirmation = function(level, startingSerial, duration)
    local deadline = os.clock() + duration
    repeat
        if (confirmedAttackSerial[level] or 0) > startingSerial then
            return true
        end
        task.wait(0.01)
    until not priority.isMultiHitActive() or not gui.Parent or os.clock() >= deadline
    return (confirmedAttackSerial[level] or 0) > startingSerial
end

local function bootstrapMultiHitSession()
    if not multiHitNeedsBootstrap then
        return true
    end

    local bootstrapLevel = 1
    local startingSerial = confirmedAttackSerial[bootstrapLevel] or 0
    multiHitStatusLabel.Text = "Multi Hit: Priming the bridge session automatically..."
    multiHitStatusLabel.TextColor3 = COLORS.muted

    for _ = 1, 3 do
        fireRemote("attack", bootstrapLevel)
        if priority.waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
            multiHitNeedsBootstrap = false
            multiHitStatusLabel.Text = "Multi Hit: Remote session primed"
            multiHitStatusLabel.TextColor3 = COLORS.success
            return true
        end
    end

    local enemyPart = findEnemyPart(bootstrapLevel)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not enemyPart or not root then
        multiHitStatusLabel.Text = "Multi Hit: Waiting for Enemy 1 to load"
        multiHitStatusLabel.TextColor3 = COLORS.muted
        return false
    end

    local originalCFrame = root.CFrame
    local moved = pcall(function()
        local flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
        if flatForward.Magnitude < 0.05 then
            flatForward = Vector3.new(0, 0, -1)
        else
            flatForward = flatForward.Unit
        end
        local targetPosition = enemyPart.Position + flatForward * 5 + Vector3.new(0, 0.5, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(targetPosition, enemyPart.Position)
    end)

    local confirmed = false
    if moved then
        task.wait(0.10)
        for _ = 1, 5 do
            fireRemote("attack", bootstrapLevel)
            if priority.waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
                confirmed = true
                break
            end
        end
        pcall(function()
            root.CFrame = originalCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    multiHitNeedsBootstrap = not confirmed
    multiHitStatusLabel.Text = confirmed
        and "Multi Hit: Bridge session primed; attacking from anywhere"
        or "Multi Hit: Bridge activation retry queued"
    multiHitStatusLabel.TextColor3 = confirmed and COLORS.success or COLORS.error
    return confirmed
end

task.spawn(function()
    local currentBoss = 1
    while gui.Parent do
        if (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) == 7 then
            currentBoss = 1
            multiHitStatusLabel.Text = "Multi Hit: Paused while Demon Realm is active"
            multiHitStatusLabel.TextColor3 = COLORS.muted
            task.wait(0.20)
            continue
        end
        if priority.isMultiHitActive() then
            if multiHitNeedsBootstrap and not bootstrapMultiHitSession() then
                task.wait(0.25)
                continue
            end
            local maxBoss = multiHitTargetMode == "Unlocked Bosses Only"
                and getLatestUnlockedBossLevel()
                or 15
            if currentBoss > maxBoss then
                currentBoss = 1
            end

            local startingSerial = confirmedAttackSerial[currentBoss] or 0
            local confirmationDeadline = os.clock() + 0.45
            local confirmed = false
            local multiPrefix = state.priorityMulti and "Priority Multi" or "Multi Hit"
            multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " / " .. maxBoss .. " - waiting for server"
            multiHitStatusLabel.TextColor3 = COLORS.muted

            repeat
                fireRemote("attack", currentBoss)
                local retryDeadline = math.min(confirmationDeadline, os.clock() + multiHitDelay)
                repeat
                    task.wait(0.01)
                    confirmed = (confirmedAttackSerial[currentBoss] or 0) > startingSerial
                until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= retryDeadline
            until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= confirmationDeadline

            if not priority.isMultiHitActive() or not gui.Parent then
                currentBoss = 1
                multiHitStatusLabel.Text = state.specialPriority and "Multi Hit: Waiting for special-boss phase" or "Multi Hit: Disabled"
                multiHitStatusLabel.TextColor3 = COLORS.muted
                continue
            end

            if confirmed then
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " confirmed - advancing"
                multiHitStatusLabel.TextColor3 = COLORS.success
            else
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " did not confirm - skipped"
                multiHitStatusLabel.TextColor3 = COLORS.error
            end

            currentBoss += 1
            if currentBoss > maxBoss then
                currentBoss = 1
                if priority.isMultiHitActive() then
                    setReviveStatus("Multi Hit completed a confirmed boss round", true)
                end
            end
            task.wait(0.01)
        else
            currentBoss = 1
            if state.specialPriority then
                multiHitStatusLabel.Text = "Multi Hit: Waiting for special-boss phase"
                multiHitStatusLabel.TextColor3 = COLORS.muted
            end
            task.wait(0.05)
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        if not state.autoTween and not state.bossFarm then
            task.wait(0.10)
            continue
        end

        local targetEnemy = state.bossFarm and getLatestUnlockedBossLevel() or selectedEnemy
        local enemyPart = findEnemyPart(targetEnemy)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        if not enemyPart or not root then
            stopEnemyTween()
            tweenStatusLabel.Text = not enemyPart and ("Tween: Waiting for Enemy " .. targetEnemy) or "Tween: Waiting for respawn"
            tweenStatusLabel.TextColor3 = COLORS.error
            if state.bossFarm then
                farmStatusLabel.Text = "Farm: Waiting for Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
                farmStatusLabel.TextColor3 = COLORS.error
            end
            task.wait(0.25)
            continue
        end

        if controlledHumanoid ~= humanoid then
            stopEnemyTween()
            controlledHumanoid = humanoid
            if humanoid then
                originalAutoRotate = humanoid.AutoRotate
                humanoid.AutoRotate = false
            end
        end

        local flatForward = lockedEnemyFacing[enemyPart]
        if not flatForward then
            flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
            flatForward = flatForward.Magnitude > 0.001 and flatForward.Unit or Vector3.new(0, 0, 1)
            lockedEnemyFacing[enemyPart] = flatForward
        end
        local stableEnemyCFrame = CFrame.lookAt(enemyPart.Position, enemyPart.Position + flatForward)
        local horizontalTarget = (stableEnemyCFrame * CFrame.new(tweenOffsetX, 0, tweenOffsetZ)).Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {character, workspace:FindFirstChild("Enemies")}
        raycastParams.IgnoreWater = true
        local ground = workspace:Raycast(horizontalTarget + Vector3.new(0, 35, 0), Vector3.new(0, -100, 0), raycastParams)
        local standingY = enemyPart.Position.Y
        if ground and humanoid then
            standingY = ground.Position.Y + humanoid.HipHeight + (root.Size.Y * 0.5)
        end
        local targetPosition = Vector3.new(horizontalTarget.X, standingY + tweenOffsetY, horizontalTarget.Z)
        local lookAt = Vector3.new(enemyPart.Position.X, targetPosition.Y, enemyPart.Position.Z)
        local goal = (lookAt - targetPosition).Magnitude > 0.05
            and CFrame.lookAt(targetPosition, lookAt, Vector3.yAxis)
            or CFrame.new(targetPosition)
        local distance = (targetPosition - root.Position).Magnitude
        local duration = math.clamp(distance / math.max(tweenSpeed, 1), 0.05, 1.25)

        if activeEnemyTween then
            activeEnemyTween:Cancel()
        end
        if distance <= 0.12 then
            root.CFrame = goal
            root.AssemblyAngularVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.05)
        else
            activeEnemyTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = goal})
            activeEnemyTween:Play()
        end
        tweenStatusLabel.Text = "Tween: Enemy " .. targetEnemy .. " | Front stance | " .. math.floor(distance + 0.5) .. " studs"
        tweenStatusLabel.TextColor3 = COLORS.success
        if state.bossFarm then
            farmStatusLabel.Text = "Farm: Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
            farmStatusLabel.TextColor3 = COLORS.success
        end
        if activeEnemyTween then
            activeEnemyTween.Completed:Wait()
            if root.Parent and (state.autoTween or state.bossFarm) then
                root.CFrame = goal
                root.AssemblyAngularVelocity = Vector3.zero
            end
            activeEnemyTween = nil
        end
    end
end)

track(gui.Destroying:Connect(function()
    local hadSpecialAutomation = state.cursedKing or state.nightmare or state.specialPriority
    state.autoTween = false
    state.bossFarm = false
    state.multiHit = false
    state.priorityMulti = false
    state.cursedKing = false
    state.nightmare = false
    state.specialPriority = false
    stopEnemyTween()
    clearCharacterVisuals()
    restoreVorNameplate()
    if state.autoRebirth and remotes.SetAutoRebirth then
        pcall(function()
            remotes.SetAutoRebirth:FireServer(false, autoRebirthFloor)
        end)
    end
    if hadSpecialAutomation and remotes.setAfkResumeReq then
        pcall(function()
            remotes.setAfkResumeReq:FireServer(0, 0)
        end)
    end
end))

end
