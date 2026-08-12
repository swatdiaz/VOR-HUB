param(
    [string]$Compiler = (Join-Path $env:TEMP "vor-luau-0.731\luau-compile.exe"),
    [string]$BaselineRef = "59547d8286ec2e130e9733cfddac3725b5875dbb"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$required = @(
    "loader.lua",
    "core/ui.lua",
    "core/settings.lua",
    "core/profiles.lua",
    "core/access.lua",
    "core/utilities.lua",
    "games/grow_a_garden_2.lua",
    "games/capybaras_vs_plants.lua",
    "games/murder_mystery_2.lua",
    "games/mypark.lua",
    "games/practical_basketball.lua",
    "games/anime_expeditions.lua",
    "games/bid_for_anime.lua",
    "games/mine_a_mountain.lua",
    "games/bee_swarm_simulator.lua",
    "games/gunfight_arena.lua",
    "games/sniper_arena.lua",
    "games/iron_man_reimagined.lua",
    "games/dog_race.lua",
    "games/dragon_ball_legendary_powers.lua",
    "games/blox_fruits.lua",
    "games/blox_fruits_experimental.lua",
    "games/blox_fruits_parity.lua",
    "games/blox_fruits_race.lua",
    "games/blox_fruits_pvp.lua",
    "games/blox_fruits_first_sea.lua",
    "games/blox_fruits_third_sea.lua",
    "games/blox_fruits_dungeons.lua"
)
$compileFiles = $required + @(
    "VOR_HUB.lua",
    "anime_expeditions.lua",
    "blox_fruits_dungeons.lua"
)

if (-not (Test-Path -LiteralPath $Compiler)) {
    $workspaceRoot = Split-Path $repo -Parent
    $workspaceCompiler = @(
        (Join-Path $workspaceRoot ".codex-tools\luau-0.731\luau-compile.exe"),
        (Join-Path $workspaceRoot ".codex-tools\luau-0.730\luau-compile.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($workspaceCompiler) {
        $Compiler = $workspaceCompiler
    } else {
        throw "Luau compiler was not found: $Compiler"
    }
}

foreach ($relative in $compileFiles) {
    $path = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required modular file is missing: $relative"
    }
    # -O0 matches the executor's strict 200-register ceiling. Optimized builds
    # can hide a module that the live loadstring compiler rejects.
    & $Compiler --null -O0 $path | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Luau compile failed: $relative"
    }
}

foreach ($relative in $required | Where-Object { $_ -like "games/*" }) {
    $text = Get-Content -LiteralPath (Join-Path $repo $relative) -Raw
    if ($text -notmatch '(?m)^return function\(context\)') {
        throw "Game module does not return one context builder: $relative"
    }
}

$baselineText = (& git -C $repo show "${BaselineRef}:VOR_HUB.lua") -join "`n"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($baselineText)) {
    throw "Could not read baseline VOR_HUB.lua from $BaselineRef"
}

$flagPattern = 'Flag\s*=\s*["'']([^"'']+)["'']'
$baselineFlags = [System.Collections.Generic.HashSet[string]]::new()
foreach ($match in [regex]::Matches($baselineText, $flagPattern)) {
    [void]$baselineFlags.Add($match.Groups[1].Value)
}

$modularFlags = [System.Collections.Generic.HashSet[string]]::new()
foreach ($relative in $required) {
    $text = Get-Content -LiteralPath (Join-Path $repo $relative) -Raw
    foreach ($match in [regex]::Matches($text, $flagPattern)) {
        [void]$modularFlags.Add($match.Groups[1].Value)
    }
}

# Alias strings count as transferred flags because they are deliberately
# accepted when loading old profiles even when the new control is canonical.
$settingsText = Get-Content -LiteralPath (Join-Path $repo "core/settings.lua") -Raw
foreach ($match in [regex]::Matches($settingsText, '["''](blox_[^"'']+)["'']')) {
    [void]$modularFlags.Add($match.Groups[1].Value)
}

$retiredFlags = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    # Explicitly removed because weapon-model replacement could corrupt the
    # character assembly and trigger security kicks.
    "blox_void_dark_blade_v3",
    # Retired when the separate multi-grab controls were replaced by the one
    # shared Auto Magnet controller.
    "blox_enemy_gather",
    "blox_gather_distance",
    "blox_multi_grab_enemy",
    "blox_raid_multi_grab",
    # Revive support and its standalone developer outfit controls were
    # deliberately removed when Murder Mystery 2 replaced that adapter.
    "codex_tools_frozen_everest_outfit",
    "codex_tools_marketplace_outfit_id"
))
$missing = @($baselineFlags | Where-Object {
    -not $modularFlags.Contains($_) -and
    -not $retiredFlags.Contains($_) -and
    -not $_.StartsWith("revive_")
} | Sort-Object)
if ($missing.Count -gt 0) {
    throw "Persistent flag parity failed. Missing: $($missing -join ', ')"
}

$bloxText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits.lua") -Raw
$canonicalPositionFlags = @(
    "blox_farm_position_x",
    "blox_farm_position_height",
    "blox_farm_position_z",
    "blox_farm_position_orbit",
    "blox_farm_position_orbit_radius",
    "blox_farm_position_orbit_speed",
    "blox_farm_position_random_square",
    "blox_farm_position_square_size",
    "blox_farm_position_square_interval"
)
foreach ($flag in $canonicalPositionFlags) {
    $count = ([regex]::Matches($bloxText, 'Flag\s*=\s*["'']' + [regex]::Escape($flag) + '["'']')).Count
    if ($count -ne 1) {
        throw "Shared Farm Position flag must have exactly one control: $flag (found $count)"
    }
}

$categoryMatches = [regex]::Matches($bloxText, 'addHomeCategory\("([^"]+)"')
$categoryNames = @($categoryMatches | ForEach-Object { $_.Groups[1].Value })
$expectedCategories = @("Farming", "Combat", "Mastery", "Shop", "Sea & Raids", "Player")
if (($categoryNames -join "|") -ne ($expectedCategories -join "|")) {
    throw "Blox Fruits categories are not canonical: $($categoryNames -join ', ')"
}

$nativeFruitShape = 'silentRemote:FireServer(direction.Unit, 1, grounded)'
if (([regex]::Matches($bloxText, [regex]::Escape($nativeFruitShape))).Count -ne 2) {
    throw "Fruit M1 calls must use the live direction/combo/grounded remote shape twice"
}
if ($bloxText -notmatch 'state\.IsAtSubmergedIsland and state\.IsAtSubmergedIsland\(\)' -or
    $bloxText -notmatch 'atSubmergedIsland and -2161\.889 or 0') {
    throw "Walk on Water must use the inner-water surface only while actually at Submerged Island"
}

$parityText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_parity.lua") -Raw
$firstSeaText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_first_sea.lua") -Raw
$pvpText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_pvp.lua") -Raw
$thirdSeaText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_third_sea.lua") -Raw
$routingChecks = @(
    @($bloxText, 'FarmingPage:AddSection\("Auto Magnet"'),
    @($bloxText, 'FarmingPage:AddSection\("Boss Farming"'),
    @($bloxText, 'ShopPage:AddSection\("Fighting Styles"'),
    @($bloxText, 'SeaPage:AddSection\("World Travel"'),
    @($parityText, 'pages\.Shop:AddSection\("Buso Color"'),
    @($parityText, 'pages\.Farming:AddSection\("Farming ESP & Alerts"'),
    @($parityText, 'pages\.Sea:AddSection\("Rare Island ESP & Alerts"'),
    @($firstSeaText, 'pages\.Farming:AddSection\("First Sea Unlocks"'),
    @($thirdSeaText, 'pages\.Player:AddSection\("Race Progression"'),
    @($thirdSeaText, 'pages\.Farming:AddSection\("Third Sea Bosses"')
)
foreach ($check in $routingChecks) {
    if ($check[0] -notmatch $check[1]) {
        throw "Blox Fruits menu routing contract failed: $($check[1])"
    }
}

$raidBossSelection = (
    $bloxText -match 'state\.IsBossEnemyName\s*=\s*function\(value\)' -and
    $bloxText -match '"\[raid boss\]"' -and
    $bloxText -match 'name:gsub\("%s\*%\[\[Rr\]\[Aa\]\[Ii\]\[Dd\]%s\+\[Bb\]\[Oo\]\[Ss\]\[Ss\]%\]"' -and
    $bloxText -match 'ReplicatedStorage:FindFirstChild\("Enemies"\)' -and
    $bloxText -match 'state\.RaidBossFallbacks\s*=\s*\{' -and
    $bloxText -match '\[2753915549\]\s*=\s*\{\s*"Greybeard"' -and
    $bloxText -match 'if state\.IsBossEnemyName\(enemy\.Name\) then\s*addBoss\(enemy\.Name\)'
)
if (-not $raidBossSelection) {
    throw "Blox Fruits boss selection must include active, replicated, and despawned raid bosses"
}

$autoSaber = (
    $parityText -match 'context\.LoadModule\("games/blox_fruits_first_sea\.lua"\)' -and
    $firstSeaText -match 'Name\s*=\s*"Auto Saber Unlock"' -and
    $firstSeaText -match 'Flag\s*=\s*"blox_auto_saber_unlock"' -and
    $firstSeaText -match 'getInventoryWeapons' -and
    $firstSeaText -match 'QuestPlates' -and
    $firstSeaText -match 'ProQuestProgress", "SickMan"' -and
    $firstSeaText -match 'ProQuestProgress", "RichSon"' -and
    $firstSeaText -match 'ProQuestProgress", "PlaceRelic"' -and
    $firstSeaText -match 'api\.FarmFirst\(\{"Mob Leader"\}' -and
    $firstSeaText -match 'api\.FarmFirst\(\{"Saber Expert"\}' -and
    $firstSeaText -match 'Window\.PersistentControls\["blox_double_attack"\]' -and
    $firstSeaText -match 'weapon:Set\("Melee"\)' -and
    $firstSeaText -match 'runtime\.Toggle:Set\(false\)'
)
if (-not $autoSaber) {
    throw "Auto Saber must resume every server-backed stage and stop only after verified ownership"
}

$spectate = (
    $pvpText -match 'Name\s*=\s*"Spectate Target"' -and
    $pvpText -match 'Camera\.CameraSubject = humanoid\(target\)' -and
    $pvpText -match 'Camera\.CameraSubject = body' -and
    $pvpText -match 'Players\.PlayerRemoving:Connect' -and
    $pvpText -match 'stopSpectating\(\)\s*\r?\n\s*state\.Alive = false'
)
if (-not $spectate) {
    throw "Spectate must follow respawns, stop on player removal, and restore the local camera"
}

$tyrantSkillBlock = [regex]::Match(
    $thirdSeaText,
    '(?s)local function useTyrantPotSkill\(pot\).*?\r?\n\s*end\r?\n\r?\n\s*local function stepTyrant'
).Value
$tyrantSummon = (
    $thirdSeaText -match '"Isle Outlaw"' -and
    $thirdSeaText -match '"Island Boy"' -and
    $thirdSeaText -match '"Isle Champion"' -and
    $thirdSeaText -match '"Sun-kissed Warrior"' -and
    $thirdSeaText -match '"Serpent Hunter"' -and
    $thirdSeaText -match '"Skull Slayer"' -and
    $thirdSeaText -match 'local function tyrantEyeProgress\(\)' -and
    $thirdSeaText -match 'runtime\.TyrantSessionKills >= 300' -and
    $thirdSeaText -match 'local function confirmTyrantKill\(record\)' -and
    $thirdSeaText -match 'body\.HealthChanged:Connect' -and
    $thirdSeaText -match 'enemy\.AncestryChanged:Connect' -and
    $thirdSeaText -match 'os\.clock\(\) - record\.LastDamageAt <= 8' -and
    $thirdSeaText -match '__VOR_TyrantProgress' -and
    $thirdSeaText -match 'tyrantProgressCache\.JobId ~= game\.JobId' -and
    $thirdSeaText -match 'BirdStatue' -and
    $thirdSeaText -match 'Cube\.010' -and
    $thirdSeaText -match 'TikiUrn' -and
    $thirdSeaText -match 'CuttableObject' -and
    $thirdSeaText -match 'not object:IsDescendantOf\(gui\)' -and
    $thirdSeaText -match 'local function recoverTyrantTeam\(\)' -and
    $bloxText -notmatch 'state\.ThirdSeaFarmActive and #targets > 1' -and
    $thirdSeaText -notmatch 'api\.SetGather|PersistentControls\["blox_weapon_type"\]' -and
    $bloxText -match 'FarmMobAura = function\(names\)' -and
    $bloxText -match 'state\.ThirdSeaUsesMobAura' -and
    $bloxText -match 'local searchRange = state\.ThirdSeaUsesMobAura and math\.huge' -and
    $thirdSeaText -match 'api\.FarmMobAura\(TYRANT_TIKI_ENEMIES\)' -and
    $thirdSeaText -match 'farmMobAura\(\{"Tyrant of the Skies", "Tyrant"\}\)' -and
    $thirdSeaText -match 'Flag\s*=\s*"blox_tyrant_progress_notifier"' -and
    $thirdSeaText -match 'TyrantProgressNotifier' -and
    $thirdSeaText -match 'UserInputService\.TouchEnabled' -and
    $thirdSeaText -match 'local function nearestTyrantPot\(excluded\)' -and
    $thirdSeaText -match 'local function stepTyrant\(\)' -and
    $tyrantSkillBlock -match 'Enum\.KeyCode\.Z' -and
    $tyrantSkillBlock -match 'Enum\.KeyCode\.X' -and
    $tyrantSkillBlock -match 'Enum\.KeyCode\.C' -and
    $tyrantSkillBlock -match 'Enum\.KeyCode\.F' -and
    $tyrantSkillBlock -notmatch 'Enum\.KeyCode\.V|0x56|keypress\(86\)'
)
if (-not $tyrantSummon) {
    throw "Auto Tyrant must charge four eyes, clear Tiki vases with Z/X/C/F, and never use transformation key V"
}

$tyrantNotifier = (
    $thirdSeaText -match 'UDim2\.fromOffset\(UserInputService\.TouchEnabled and 300 or 460, UserInputService\.TouchEnabled and 44 or 52\)' -and
    $thirdSeaText -match 'TextSize = UserInputService\.TouchEnabled and 16 or 19' -and
    $thirdSeaText -match 'string\.format\("Tyrant \| ~%d enemies left", remaining\)'
)
if (-not $tyrantNotifier) {
    throw "Tyrant notifier must be readable on PC/mobile and show only estimated enemies remaining"
}

$mobAuraEnemyHold = (
    $bloxText -match 'state\.PinMobAuraTarget = function\(enemy, anchor\)' -and
    $bloxText -match 'enemyRoot\.CFrame = CFrame\.new\(anchor\) \* original\.CFrame\.Rotation' -and
    $bloxText -match 'enemyRoot\.Anchored = true' -and
    $bloxText -match 'enemyRoot\.Anchored = original\.Anchored' -and
    $bloxText -match 'enemyBody:ChangeState\(Enum\.HumanoidStateType\.Physics\)' -and
    $bloxText -match 'SwordTargetLimit = 35' -and
    $bloxText -match 'FruitTargetLimit = 35' -and
    $bloxText -match 'state\.SendNativeControllerAttack = function\(tool\)' -and
    $bloxText -match 'setIdentity\(2\)' -and
    $bloxText -match 'combatController:Attack\(tool, nil, nil\)' -and
    $bloxText -match 'VOR_NativeWeaponHitbox' -and
    $bloxText -match 'temporaryHitbox\.Parent = hitboxParent or tool' -and
    $bloxText -match 'char and char:FindFirstChild\("EquippedWeapon"\)' -and
    $bloxText -match 'os\.clock\(\) - \(state\.NativeCombatBusyAt or 0\) < 1' -and
    $bloxText -match 'state\.NativeCombatBusy = true' -and
    $bloxText -match 'state\.NativeCombatBusy = false' -and
    $bloxText -match 'candidate\.Root\.Size = Vector3\.new\(60, 60, 60\)'
)
if (-not $mobAuraEnemyHold) {
    throw "Mob Aura must pin its active NPC while Magnet exposes every piled target to the attack hitbox"
}

$berryAutomation = (
    $bloxText -match 'Flag\s*=\s*"blox_auto_berry"' -and
    $bloxText -match 'Flag\s*=\s*"blox_berry_server_hop"' -and
    $bloxText -match 'CollectionService:GetTagged\("BerryBush"\)' -and
    $bloxText -match 'string\.sub\(slot, 1, 12\) == "_BerryCFrame"' -and
    $bloxText -match 'baseCFrame:ToWorldSpace\(slotCFrame\)' -and
    $bloxText -match 'berryPromptForTarget\(target\)' -and
    $bloxText -match 'keypress\(0x45\)' -and
    $bloxText -match 'VirtualInputManager:SendKeyEvent\(true, Enum\.KeyCode\.E' -and
    $bloxText -notmatch 'ClaimBerry:InvokeServer' -and
    $bloxText -match 'state\.BerriesClaimedThisServer \+= 1' -and
    $bloxText -match 'state\.AutoBerryServerHop and state\.BerriesClaimedThisServer == 0' -and
    $bloxText -match 'state\.HopServer\("No live berry spawned", true\)' -and
    $bloxText -match 'VORBerryResumeHop = true' -and
    $bloxText -match 'TeleportService:GetTeleportSetting\("VORBerryResumeHop"\)' -and
    $bloxText -match 'type\(resumeSetting\) == "boolean"' -and
    $bloxText -match 'TeleportService:SetTeleportSetting\("VORBerryResumeHop", true\)' -and
    $bloxText -match 'local travelCommand = fromFirstSea and "TravelZou" or "TravelMain"' -and
    $bloxText -match 'state\.RecoverBerryTeam = function\(\)' -and
    $bloxText -match 'pcall\(firesignal, button\.Activated\)' -and
    $bloxText -match 'Travel did not start; retrying " \.\. destination' -and
    $bloxText -match 'math\.ceil\(10 - \(os\.clock\(\) - state\.BerryEmptySince\)\)' -and
    $bloxText -match 'Cross-sea hop to random " \.\. destination \.\. " server' -and
    $bloxText -match 'Default = state\.AutoBerryServerHop' -and
    $bloxText -match 'game\.PlaceId == 2753915549 or game\.PlaceId == 85211729168715' -and
    $bloxText -match 'TeleportService\.TeleportInitFailed:Connect' -and
    $bloxText -match 'Roblox requires a valid server teleport token' -and
    $bloxText -match 'if state\.AutoBerry then\s+stepBerry\(\)' -and
    $thirdSeaText -match '\{"blox_berry_server_hop", "blox_auto_berry"\}'
)
if (-not $berryAutomation) {
    throw "Berry automation must read live BerryBush attributes server-wide, stream the real E prompt, alternate seas, and stay after a collection"
}

$fruitDoubleAttack = (
    $bloxText -match 'Flag\s*=\s*"blox_double_attack"' -and
    $bloxText -match 'Name\s*=\s*"Double Attack \(Weapon \+ Fruit M1\)"' -and
    $bloxText -match 'Options\s*=\s*\{"Sword", "Melee"\}' -and
    $bloxText -match 'plan = \{Double = doubleAttackActive\}' -and
    $bloxText -match 'DoubleAttackEngine\.SendSword\(' -and
    $bloxText -notmatch 'blox_dual_weapon_attack' -and
    $bloxText -notmatch 'DualWeaponAttack'
)
if (-not $fruitDoubleAttack) {
    throw "Weapon + Fruit M1 Double Attack must keep Sword/Melee selection while Sword + Melee is removed"
}

$fruitGachaRewardClose = (
    $bloxText -match 'SpinnerWindow' -and
    $bloxText -match 'AboveSpinner' -and
    $bloxText -match 'Navigation' -and
    $bloxText -match 'CloseButton' -and
    $bloxText -match 'BloxGachaRewardClosed' -and
    $bloxText -match 'pcall\(firesignal, closeButton\.Activated\)'
)
if (-not $fruitGachaRewardClose) {
    throw "Fruit Gacha must close the current SpinnerWindow reward UI after a successful roll"
}

$raidPurchaseGuards = (
    $bloxText -match 'RaidChipPurchaseReserved\s*=\s*false' -and
    $bloxText -match 'RaidChipPurchaseVerifyToken\s*=\s*0' -and
    $bloxText -match 'RaidChipSawActive\s*=\s*false' -and
    $bloxText -match 'not state\.RaidChipPurchaseReserved' -and
    $bloxText -match 'state\.RaidChipPurchaseReserved = true\s+state\.RaidChipPurchaseVerifyToken \+= 1' -and
    $bloxText -match 'local granted = RaidRuntime\.RaidChip\(\) ~= nil or RaidRuntime\.Active\(\)' -and
    $bloxText -match 'state\.RaidChipPurchaseReserved = granted' -and
    $parityText -match 'LawChipReserved\s*=\s*false' -and
    $parityText -match 'LawPurchaseBusy\s*=\s*false' -and
    $parityText -match 'not runtime\.LawChipReserved and not runtime\.LawPurchaseBusy' -and
    $parityText -match 'runtime\.LawChipReserved = true\s+runtime\.LawPurchaseBusy = true\s+task\.spawn'
)
if (-not $raidPurchaseGuards) {
    throw "Normal and Law raid chip automation must reserve exactly one purchase per observed raid cycle"
}

$raidRangeSafety = (
    $bloxText -match 'RaidHitMargin = 0\.5' -and
    $bloxText -match 'RaidMaxHitHeight = 37\.5' -and
    $bloxText -match 'RaidRecoveryPercent = 70' -and
    $bloxText -match 'RaidRecoveryHeight = 140' -and
    $bloxText -match 'RaidTweenSpeed = 150' -and
    $bloxText -match 'Flag\s*=\s*"blox_safe_tween"' -and
    $bloxText -match '(?s)Name\s*=\s*"Tween Speed".*?Max\s*=\s*300.*?Default\s*=\s*250' -and
    $bloxText -match 'if speedOverride == nil and state\.SafeTween then\s+effectiveSpeed = math\.min\(effectiveSpeed, 250\)' -and
    $bloxText -match '(?s)if speedOverride == nil and state\.AutoRaid.*?LocalPlayer:GetAttribute\("IslandRaiding"\) == true.*?effectiveSpeed = math\.min\(effectiveSpeed, DoubleAttackEngine\.RaidTweenSpeed\)' -and
    $bloxText -match '(?s)local function moveToFarmPosition\(targetCFrame\).*?state\.AutoRaid and LocalPlayer:GetAttribute\("IslandRaiding"\) == true.*?return moveTo\(targetCFrame\)' -and
    $bloxText -match 'state\.RaidFarmOffset = function\(\)' -and
    $bloxText -match 'allowedHorizontal = math\.sqrt\(math\.max\(0, maximum \* maximum - y \* y\)\)' -and
    $bloxText -match 'state\.PositionAnchorY = livePosition\.Y' -and
    $bloxText -match 'BloxRaidPositionClamped' -and
    $bloxText -match 'BloxRaidEffectivePositionX' -and
    $bloxText -match 'BloxRaidEffectivePositionY' -and
    $bloxText -match 'BloxRaidEffectivePositionZ' -and
    $bloxText -match 'LastRaidNativeFallback = -math\.huge' -and
    $bloxText -match '(?s)local raidCombatActive = state\.AutoRaid and state\.RaidMovementReady.*?local doubleAttackActive = state\.DoubleAttack and not raidCombatActive.*?local plan = \{Double = doubleAttackActive\}' -and
    $bloxText -match '(?s)local raidCombatActive = state\.AutoRaid and RaidRuntime\.Active\(\).*?local enabled = not raidVoidActive and not raidCombatActive.*?and \(multiGrabEnabled or state\.AutoMagnet\)' -and
    $bloxText -match '(?s)if not island then.*?if not state\.AutoStartRaid then\s+cancelMove\(false\)\s+end.*?Dungeon / Raid: Waiting to start' -and
    $bloxText -match '(?s)RaidClusterAnchor = nil.*?RaidClusterRadius = 7500.*?function RaidRuntime\.LatestIsland\(\).*?candidate\.Index == 1.*?nearestDistance > 5000.*?state\.RaidClusterAnchor = nearestEntry\.Part\.Position.*?candidate\.Part\.Position - state\.RaidClusterAnchor.*?state\.RaidClusterRadius' -and
    $bloxText -match 'Never write Humanoid\.Health directly' -and
    $bloxText -notmatch 'enemyBody\.Health\s*=\s*-9e9' -and
    $bloxText -match '(?s)damaged > 0.*?state\.AutoRaid and LocalPlayer:GetAttribute\("IslandRaiding"\) == true.*?fallbackTool:Activate\(\).*?BloxRaidNativeFallbackCount' -and
    $bloxText -match 'healthPercent\(\) <= DoubleAttackEngine\.RaidRecoveryPercent' -and
    $bloxText -match 'local safeModeRecovery = state\.SafeMode and currentHealth <= state\.SafeHealthPercent' -and
    $bloxText -match 'local emergencyRecovery = currentHealth <= DoubleAttackEngine\.RaidRecoveryPercent' -and
    $bloxText -match '(?s)if state\.RaidSafeModeActive then.*?state\.RaidVoidKill and island\.Index >= 5.*?RaidRuntime\.VoidKillStep\(island\).*?retreatHeight = math\.max\(DoubleAttackEngine\.RaidRecoveryHeight, safeHeight \+ 100\).*?state\.FarmHoldY = retreatCFrame\.Position\.Y' -and
    $bloxText -match 'RaidVoidFallbackActive = waitingForOwnership > 0 and nearestWaiting ~= nil' -and
    $bloxText -match 'RaidVoidFallbackDelay = 3\.5' -and
    $bloxText -match '(?s)aliveEnemyHealth < state\.RaidVoidFallbackHealth - 1.*?os\.clock\(\) - state\.RaidVoidFallbackLastProgress >= state\.RaidVoidFallbackDelay.*?state\.RaidVoidCombatFallback = true' -and
    $bloxText -match 'state\.RaidVoidActive = not state\.RaidVoidCombatFallback' -and
    $bloxText -match 'BloxRaidVoidCombatFallback' -and
    $bloxText -match 'local holdCFrame = island\.Part\.CFrame \+ Vector3\.new\(raidX, safeHeight, raidZ\)' -and
    $bloxText -match '(?s)if state\.RaidVoidActive then.*?state\.ActiveFarmTarget = nil.*?state\.RaidTargetName = nil.*?moveTo\(holdCFrame\).*?cancelMove\(false\)' -and
    $bloxText -match '(?s)state\.RaidVoidFallbackActive and root and waitingRoot.*?fallbackTool:Activate\(\).*?island-5-stationary-fallback' -and
    $bloxText -notmatch 'Native fallback:' -and
    $bloxText -match 'BloxRaidSafeModeActive' -and
    $bloxText -match 'BloxRaidVoidFallbackActive' -and
    $bloxText -match 'BloxSafeMode' -and
    $bloxText -match 'BloxSafeHealthPercent' -and
    $bloxText -match 'BloxSelectedRaid'
)
if (-not $raidRangeSafety) {
    throw "Raid farming must stay just inside registered hit range and retreat before burst damage becomes lethal"
}

$raidFruitInventory = (
    $parityText -match 'rawInvoke\("GetFruits"\)' -and
    $parityText -match 'require\(ReplicatedStorage\.Controllers\.UI\.Inventory\)' -and
    $parityText -match 'inventoryController:GetIfInitialized\(\)' -and
    $parityText -match 'type\(inventoryController\.init\) == "function"' -and
    $parityText -match 'pcall\(inventoryController\.init\)' -and
    $parityText -match 'local tilesDeadline = os\.clock\(\) \+ 6' -and
    $parityText -match 'inventoryController:GetTiles\(\)' -and
    $parityText -match 'itemConfig\.match\(tile\.ItemId\):unwrap\(\)' -and
    $parityText -match 'display\.Category == "Blox Fruit"' -and
    $parityText -match 'storage\.StorageMethod == "StoredFruits"' -and
    $parityText -match 'quality\.MoneyPrice' -and
    $parityText -match '\{"getInventoryFruits", "getInventory", "getInventoryWeapons"\}' -and
    $parityText -match 'category == "Blox Fruit"' -and
    $parityText -match 'rawget\(object, "IsPurchase"\) == false' -and
    $parityText -match 'rawget\(object, "IsPermanent"\) == false' -and
    $parityText -match 'rawget\(object, "Selectable"\) == true' -and
    $parityText -match 'table\.sort\(ordered, function\(left, right\)' -and
    $parityText -match '(?s)local candidate = ordered\[1\].*?runtime\.RaidFruitLoadRequested = true.*?rawInvoke\("LoadFruit", candidate\.Name\)' -and
    $parityText -match '(?s)if not invoked then\s+release\(generation\)\s+return false, "Load request for " .*?" lost its reply; awaiting server confirmation"\s+end\s+if result == false then\s+runtime\.RaidFruitLoadRequested = false' -and
    $parityText -match '(?s)if runtime\.RaidFruitLoadRequested then\s+local existingTool = fruitTool\(\s*runtime\.RaidFruitRequestedName,\s*runtime\.RaidFruitRequestedDisplayName,\s*runtime\.RaidFruitPreexistingTools\s*\)' -and
    $parityText -match '(?s)table\.clear\(runtime\.RaidFruitPreexistingTools\)\s+for _, tool in ipairs\(allTools\(\)\) do\s+runtime\.RaidFruitPreexistingTools\[tool\] = true\s+end\s+runtime\.RaidFruitLoadRequested = true' -and
    $parityText -match '(?s)local loadedTool = fruitTool\(\s*candidate\.Name,\s*candidate\.DisplayName,\s*runtime\.RaidFruitPreexistingTools\s*\).*?gui:SetAttribute\("BloxRaidLoadedFruit", loadedTool\.Name\)' -and
    $parityText -match '(?s)local physical = isFruitTool\(tool\).*?string\.find\(string\.lower\(tool\.Name\), "fruit", 1, true\).*?or originalName ~= nil' -and
    $parityText -match 'runtime\.RaidFruitGeneration ~= generation' -and
    $parityText -match 'local startingCharacter = helpers\.Character\(\)' -and
    $parityText -match 'helpers\.Character\(\) == startingCharacter' -and
    $parityText -match 'sharedState\.InventoryBusy = true' -and
    $parityText -match 'sharedState\.InventoryBusyOwner == inventoryOwner' -and
    $bloxText -match 'InventoryBusyOwner\s*=\s*nil' -and
    $bloxText -match 'state\.InventoryBusyOwner = inventoryOwner' -and
    $parityText -match 'track\(gui\.Destroying:Connect\(function\(\)' -and
    $parityText -match '(?s)track\(LocalPlayer\.CharacterAdded:Connect\(function\(\).*?runtime\.RaidFruitGeneration \+= 1.*?sharedState\.InventoryBusyOwner == inventoryOwner' -and
    $parityText -match '(?s)Name\s*=\s*"Get Cheap Fruit From Inventory".*?Callback\s*=\s*function\(\)\s+task\.spawn\(function\(\)'
)
if (-not $raidFruitInventory) {
    throw "Raid fruit loading must use exact owned tiles, cheapest-first selection, serialized work, and verified Tool replication"
}

$raidFruitCycle = (
    $bloxText -match 'RaidMovementReady\s*=\s*false' -and
    $bloxText -match 'MoveDeadline\s*=\s*0' -and
    $bloxText -match 'state\.MoveDeadline\s*=\s*os\.clock\(\)\s*\+\s*duration\s*\+\s*1\.25' -and
    $bloxText -match 'BloxMovementWatchdog' -and
    $bloxText -match '(?s)if not island then\s+state\.RaidMovementReady = false.*?cancelMove\(false\).*?FarmVertical\.Release\(\)' -and
    $bloxText -match 'local raidFarmEnabled = state\.AutoRaid and state\.RaidMovementReady and RaidRuntime\.Active\(\)' -and
    $bloxText -match 'RaidActive = RaidRuntime\.Active' -and
    $bloxText -match 'RaidChip = RaidRuntime\.RaidChip' -and
    $parityText -match 'RaidFruitReserved\s*=\s*false' -and
    $parityText -match 'RaidFruitSawActive\s*=\s*false' -and
    $parityText -match '(?s)if raidActive\(\) then.*?RaidFruitSawActive = true.*?next fruit waits until it finishes' -and
    $parityText -match '(?s)if raidChip\(\) then.*?no extra fruit withdrawn' -and
    $parityText -match '(?s)elseif runtime\.RaidFruitSawActive then\s+runtime\.RaidFruitReserved = false\s+runtime\.RaidFruitSawActive = false' -and
    $parityText -match '(?s)runtime\.AutoRaidFruit and not activeRaid and not chip\s+and not runtime\.RaidFruitReserved'
)
if (-not $raidFruitCycle) {
    throw "Raid fruit automation must reserve one fruit per completed raid and recover stalled raid movement"
}

$loaderText = Get-Content -LiteralPath (Join-Path $repo "loader.lua") -Raw
$uiText = Get-Content -LiteralPath (Join-Path $repo "core/ui.lua") -Raw
$profilesText = Get-Content -LiteralPath (Join-Path $repo "core/profiles.lua") -Raw
$versionText = Get-Content -LiteralPath (Join-Path $repo "core/settings.lua") -Raw
$semanticVersionMatch = [regex]::Match($versionText, 'Version\s*=\s*"(?<version>\d+\.\d+\.\d+)"')
$semanticVersionOk = $semanticVersionMatch.Success
$visibleVersionOk = $uiText -match '"v"\s*\.\.\s*tostring\(SETTINGS\.Version\)'
$cleanVersionOk = $loaderText -notmatch 'BuildVersion' -and $uiText -notmatch 'BuildVersion'
if (-not ($semanticVersionOk -and $visibleVersionOk -and $cleanVersionOk)) {
    throw "Visible VOR version must be a clean semantic version without a commit suffix"
}

$xenoExecutorDetection = $loaderText -match 'local IS_XENO\s*=\s*string\.find'
$xenoHttpRetry = $loaderText -match 'for attempt\s*=\s*1,\s*3 do'
$xenoRequestFallback = $loaderText -match 'addRequestFunction\(type\(Xeno\)'
$xenoRuntimeMarker = $loaderText -match 'VORXenoCompatibility'
$xenoHomeIdentity = $uiText -match 'Executor:\s*"\s*\.\.\s*tostring\(context\.Runtime'
$dungeonText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_dungeons.lua") -Raw
$xenoTeleportResume = $dungeonText -match '\(type\(getgenv\) == \\"function\\" and getgenv\(\) or _G\)\.VORDungeonResumeAll'
$xenoTeleportResume = $xenoTeleportResume -or (
    $dungeonText -match 'local environment = type\(getgenv\) == \\"function\\" and getgenv\(\) or _G' -and
    $dungeonText -match 'environment\.VORDungeonResumeAll = true'
)
if (-not ($xenoExecutorDetection -and $xenoHttpRetry -and $xenoRequestFallback -and $xenoRuntimeMarker -and $xenoHomeIdentity -and $xenoTeleportResume)) {
    throw "Xeno compatibility contract failed"
}

$dungeonDamageDebugDrain = (
    $dungeonText -match 'state\.DamageDebugConnection\s*=\s*track\(' -and
    $dungeonText -match 'damageDebugEvent\.OnClientEvent:Connect\(function\(\) end\)' -and
    $dungeonText -match 'state\.DamageDebugConnection:Disconnect\(\)' -and
    $dungeonText -match 'state\.DamageDebugConnection = nil'
)
if (-not $dungeonDamageDebugDrain) {
    throw "Blox Fruits Dungeons must drain DMGDEBUG and release the listener during module cleanup"
}

$manualFruitMaxOk = $bloxText -match 'DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION\s*=\s*1'
$automaticFruitCadenceOk = $bloxText -match 'state\.FruitM1ReadyAt\s*=\s*os\.clock\(\)\s*\+\s*DoubleAttackEngine\.FruitCadence'
if (-not ($manualFruitMaxOk -and $automaticFruitCadenceOk)) {
    throw "Manual Fruit M1 cooldown removal is not uncapped from Aura timing"
}

$magnetOwnershipGateRemoved = $bloxText -notmatch 'local networkOwned\s*=.*isnetworkowner'
$magnetSimulationRadius = $bloxText -match 'setsimulationradius\(math\.huge, math\.huge\)'
$magnetRangeCapped = $bloxText -match '(?s)Name\s*=\s*"Magnet Range".*?Min\s*=\s*0.*?Max\s*=\s*100.*?Default\s*=\s*100.*?state\.MagnetRange\s*=\s*math\.clamp\([^\r\n]+, 0, 100\)'
$typedMobSearchCount = ([regex]::Matches(
    $bloxText,
    '(?s)MobFarmSection:AddInput\(\{\s*Name\s*=\s*"(?:Mob Aura|Selected Mob) Search Distance"'
)).Count
if (-not $magnetOwnershipGateRemoved -or -not $magnetSimulationRadius -or -not $magnetRangeCapped -or $typedMobSearchCount -lt 2) {
    throw "Magnet range or typed mob-search contract failed"
}

$stableMagnetAnchor = $bloxText -match 'targetCFrame\s*=\s*CFrame\.new\(state\.MagnetAnchorCFrame\.Position\)'
$magnetDirectRetry = $bloxText -match '(?s)state\.MagnetTweens\[candidate\.Enemy\]\s*=\s*nil.*?candidate\.Root\.CFrame\s*=\s*targetCFrame.*?candidate\.Root\.AssemblyLinearVelocity\s*=\s*Vector3\.zero'
$oneShotMagnetTweenRemoved = $bloxText -notmatch 'distanceToAnchor\s*/\s*250'
$magnetMovementDecoupled = (
    $bloxText -notmatch 'squareMovement\s*=\s*state\.MobAuraRandomSquare\s*==\s*true\s+or\s+state\.AutoMagnet' -and
    $bloxText -notmatch 'if state\.AutoMagnet or state\.MobAuraRandomSquare then'
)
if (-not ($stableMagnetAnchor -and $magnetDirectRetry -and $oneShotMagnetTweenRemoved -and $magnetMovementDecoupled)) {
    throw "Auto Magnet must continuously reapply a stable pile without taking ownership of character movement"
}

$mobAuraSameTypeGather = $bloxText -match 'local targetName\s*=\s*raidGatherEnabled and nil or selectedGatherEnemyName\(\)'
$stickyMagnetCapture = $bloxText -match 'local captured\s*=\s*state\.AutoMagnet and state\.GatherOriginalStates\[enemy\] ~= nil'
$oldTypeRelease = $bloxText -match 'targetName and not enemyMatches\(enemy, targetName\)'
$animationFreeze = $bloxText -match 'state\.FreezeGatherAnimations = function\(enemy, enemyBody\)'
$rootFreeze = $bloxText -match 'candidate\.Root\.Size = Vector3\.new\(60, 60, 60\)' -and
    $bloxText -match 'Size = candidate\.Root\.Size' -and
    $bloxText -match 'enemyBody\.PlatformStand = true' -and
    $bloxText -match 'enemyRoot\.Size = original\.Size'
if (-not ($mobAuraSameTypeGather -and $stickyMagnetCapture -and $oldTypeRelease -and $animationFreeze -and $rootFreeze)) {
    throw "Mob Aura Magnet must group only the current NPC type, release old types, and freeze animations"
}

$autoMagnetAuraFilterRemoved = $bloxText -notmatch 'elseif state\.AutoMagnet and state\.CurrentEnemyName then'
$autoMagnetPairBatchRemoved = $bloxText -notmatch 'elseif \(state\.AutoMagnet or state\.GatherEnemies or \('
$creditedPairLimit = $bloxText -match 'MULTI_ATTACK_TARGET_LIMIT\s*=\s*2'
$thirdSeaConfiguredGroupGather = $bloxText -match 'matchesTarget = matchesTarget and state\.ThirdSeaEnemyAllowed\(enemy\)'
if (-not ($autoMagnetAuraFilterRemoved -and $autoMagnetPairBatchRemoved -and $creditedPairLimit -and $thirdSeaConfiguredGroupGather)) {
    throw "Auto Magnet must leave normal Aura target rotation independent from Double Attack"
}

$mobAuraTweenTravel = $bloxText -match 'moveTo\(CFrame\.lookAt\(goalPosition, goalPosition \+ facing\)\)'
$selectedSpawnTweenTravel = $bloxText -match 'moveTo\(CFrame\.new\(goalPosition\)\)'
if (-not ($mobAuraTweenTravel -and $selectedSpawnTweenTravel)) {
    throw "Mob Aura and selected-mob travel must use the shared tween controller instead of direct root teleports"
}

$experimentalText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_experimental.lua") -Raw
$creditedMainDouble = $experimentalText -match 'api\.SetOverride\(false\)'
$requestSpamRemoved = $experimentalText -notmatch '(?s)if not runtime\.SwordBusy.*?dispatchSword\(\).*?if not runtime\.FruitBusy.*?dispatchFruit\(\)'
$idempotentOverride = $bloxText -match '(?s)local desired\s*=\s*enabled == true\s+if state\.ExperimentalAttackOverride ~= desired then\s+state\.ExperimentalAttackOverride = desired\s+state\.AuraAttackGeneration \+= 1\s+state\.FruitDispatchGeneration \+= 1\s+state\.AuraAttackPending = false\s+state\.FruitDispatchPending = false\s+state\.FruitDispatchPendingAt = 0\s+state\.AuraFruitBusy = false\s+end'
if (-not ($creditedMainDouble -and $requestSpamRemoved -and $idempotentOverride)) {
    throw "Double Attack must leave combat ownership with the credited main Aura engine"
}

$auraGenerationOwned = (
    $bloxText -match 'AuraAttackGeneration\s*=\s*0' -and
    $bloxText -match 'local attackGeneration\s*=\s*state\.AuraAttackGeneration' -and
    ([regex]::Matches($bloxText, 'state\.AuraAttackGeneration\s*~=\s*attackGeneration')).Count -ge 5 -and
    $bloxText -match '(?s)sendRegisteredAuraHit\(\s*plan\.Tool,\s*plan\.WeaponData,\s*target,\s*plan\.Profile,\s*attackTargets,\s*attackGeneration\s*\)' -and
    $bloxText -match '(?s)DoubleAttackEngine\.SendSword\(\s*plan\.Sword,\s*plan\.SwordData,\s*plan\.SwordProfile,\s*attackGeneration\s*\)'
)
if (-not $auraGenerationOwned) {
    throw "Aura Kill pending recovery must use generation-owned attack windows"
}

$registeredWeaponDamageFirst = (
    $bloxText -match '(?s)local function sendRegisteredAuraHit\(.*?local registerHit = resolveRegisterHitClosure\(\).*?if not RegisterAttackEvent or type\(registerHit\) ~= "function" then\s+local nativeSent, nativeError = state\.SendNativeControllerAttack\(tool\)' -and
    $bloxText -match '(?s)function DoubleAttackEngine\.SendSword\(.*?local registerHit = resolveRegisterHitClosure\(\).*?if not RegisterAttackEvent or type\(registerHit\) ~= "function" then\s+local nativeSent, nativeError = state\.SendNativeControllerAttack\(tool\)'
)
if (-not $registeredWeaponDamageFirst) {
    throw "Sword and Melee attacks must prefer the health-verified registered-hit path before native fallback"
}

$fruitGenerationOwned = (
    $bloxText -match 'FruitDispatchGeneration\s*=\s*0' -and
    $bloxText -match 'state\.FruitDispatchGeneration \+= 1\s+local fruitGeneration = state\.FruitDispatchGeneration' -and
    $bloxText -match '(?s)task\.spawn\(function\(\)\s+local operationOk, sent, message, sentCount = pcall\(\s*DoubleAttackEngine\.SendFruit,\s*fruit,\s*fruitGeneration\s*\)\s+if state\.FruitDispatchGeneration ~= fruitGeneration then\s+return\s+end.*?state\.FruitDispatchPending = false\s+state\.FruitDispatchPendingAt = 0\s+end\)' -and
    $bloxText -match 'sendNativeFruitM1\(tool, targets\[1\], true, nil, fruitGeneration\)' -and
    $bloxText -match 'or \(fruitGeneration and state\.FruitDispatchGeneration ~= fruitGeneration\)'
)
if (-not $fruitGenerationOwned) {
    throw "Double Attack Fruit dispatch recovery must use generation-owned work"
}

$doubleToggleBlock = [regex]::Match(
    $bloxText,
    '(?ms)^\s{12}Name\s*=\s*"Double Attack \(Weapon \+ Fruit M1\)".*?^\s{8}\}\)'
)
$doubleToggleInvalidatesBoth = (
    $doubleToggleBlock.Success -and
    $doubleToggleBlock.Value -match 'state\.AuraAttackGeneration \+= 1' -and
    $doubleToggleBlock.Value -match 'state\.FruitDispatchGeneration \+= 1' -and
    $doubleToggleBlock.Value -match 'state\.AuraAttackPending = false' -and
    $doubleToggleBlock.Value -match 'state\.FruitDispatchPending = false' -and
    $doubleToggleBlock.Value -match 'state\.AuraFruitBusy = false'
)
if (-not $doubleToggleInvalidatesBoth) {
    throw "Double Attack mode changes must invalidate both Aura dispatch lifecycles"
}

$doubleAttackWeaponModes = (
    $bloxText -match 'Name\s*=\s*"Double Attack Weapon"' -and
    $bloxText -match 'Options\s*=\s*\{"Sword", "Melee"\}' -and
    $bloxText -match 'Flag\s*=\s*"blox_double_attack_weapon"' -and
    $bloxText -match 'state\.DoubleAttackWeaponSelection = function\(\)' -and
    ([regex]::Matches($bloxText, 'toolForSelection\(state\.DoubleAttackWeaponSelection\(\)\)')).Count -ge 2 -and
    $bloxText -match 'plan\.SwordSelection = state\.DoubleAttackWeaponSelection\(\)' -and
    $bloxText -match 'gui:SetAttribute\("BloxDoubleAttackWeapon", selection\)'
)
if (-not $doubleAttackWeaponModes) {
    throw "Double Attack must support explicit Sword plus Fruit and Melee plus Fruit modes"
}

$auraTimeoutReleasesFruitBusy = $bloxText -match '(?s)if state\.AuraAttackPending then\s+if os\.clock\(\) - \(state\.AuraAttackPendingAt or 0\) < 1 then\s+return false\s+end.*?state\.LastRegisterHitResolve = -math\.huge\s+if not state\.FruitDispatchPending then\s+state\.AuraFruitBusy = false\s+end\s+state\.AuraStage = "pending-timeout-recovered"'
if (-not $auraTimeoutReleasesFruitBusy) {
    throw "Aura Kill timeout recovery must release stale native Fruit movement ownership"
}

$damageDebugDrain = (
    $bloxText -match 'state\.DamageDebugConnection\s*=\s*track\(' -and
    $bloxText -match 'state\.DamageDebugConnection:Disconnect\(\)'
)
if (-not $damageDebugDrain) {
    throw "Blox Fruits DMGDEBUG must be drained and disconnected during module cleanup"
}

$dashLengthChanger = (
    $bloxText -match 'Name\s*=\s*"Dash Length Changer"' -and
    $bloxText -match 'Flag\s*=\s*"blox_dash_length_modifier"' -and
    $bloxText -match 'Min\s*=\s*-50' -and
    $bloxText -match 'Max\s*=\s*500' -and
    $bloxText -match 'GetAttributeChangedSignal\("DashLength"\)' -and
    $bloxText -match 'dashCharacter:SetAttribute\("DashLength", applied\)' -and
    $bloxText -match 'state\.ApplyDashLengthModifier\s*=\s*function\(\)' -and
    $bloxText -match 'task\.defer\(state\.ApplyDashLengthModifier\)' -and
    $bloxText -match 'state\.RestoreDashLength\(\)' -and
    $bloxText -match 'BloxDashLengthModifier'
)
if (-not $dashLengthChanger) {
    throw "Dash Length Changer must use the native Dodge DashLength attribute, survive respawn, and restore the original value"
}

$movementModes = @{
    "Auto Farm Level" = @("blox_auto_boss", "blox_auto_raid", "blox_mob_aura_tp", "blox_selected_mob_farm", "blox_auto_chest")
    "Auto Collect Chests" = @("blox_auto_level", "blox_auto_boss", "blox_auto_raid", "blox_mob_aura_tp", "blox_selected_mob_farm")
    "Mob Aura TP" = @("blox_auto_level", "blox_auto_boss", "blox_auto_raid", "blox_auto_chest")
    "Selected Mob Farm TP" = @("blox_auto_level", "blox_auto_boss", "blox_auto_raid", "blox_auto_chest")
    "Auto Farm Selected Boss" = @("blox_auto_level", "blox_auto_raid", "blox_mob_aura_tp", "blox_selected_mob_farm", "blox_auto_chest")
    "Auto Farm Dungeon / Raid" = @("blox_auto_level", "blox_auto_boss", "blox_mob_aura_tp", "blox_selected_mob_farm", "blox_auto_chest")
}
foreach ($mode in $movementModes.GetEnumerator()) {
    $blockMatch = [regex]::Match(
        $bloxText,
        '(?ms)^\s{12}Name\s*=\s*"' + [regex]::Escape($mode.Key) + '".*?^\s{8}\}\)'
    )
    if (-not $blockMatch.Success) {
        throw "Could not inspect movement-mode callback: $($mode.Key)"
    }
    foreach ($flag in $mode.Value) {
        if ($blockMatch.Value -notmatch [regex]::Escape('"' + $flag + '"')) {
            throw "$($mode.Key) does not disable competing movement control: $flag"
        }
    }
}

$bidAnimeText = Get-Content -LiteralPath (Join-Path $repo "games/bid_for_anime.lua") -Raw
$bidAnimeRouted = $settingsText -match '(?s)BidForAnime\s*=\s*\{.*?UniverseId\s*=\s*10448083800.*?87274635966213.*?games/bid_for_anime\.lua'
$bidAnimeAuctionShape = $bidAnimeText -match '(?s)action\s*=\s*"bid".*?auctionId\s*=\s*prompt\.auctionId.*?promptId\s*=\s*prompt\.promptId.*?amount\s*=\s*option\.amount'
$bidAnimeAutoFarm = $bidAnimeText -match 'Name\s*=\s*"Full Auto Farm"' -and $bidAnimeText -match 'PlayWithAIRequest'
$bidAnimeAdminKitAbsent = $bidAnimeText -notmatch 'AdminKit'
$bidAnimeNavigationIcons = (
    $uiText -match '\["Auto Farm"\]\s*=\s*"[^"]+"' -and
    $uiText -match '(?m)^\s*Economy\s*=\s*"[^"]+"' -and
    $uiText -match '(?m)^\s*Upgrades\s*=\s*"[^"]+"' -and
    $uiText -match '(?m)^\s*Rewards\s*=\s*"[^"]+"' -and
    $uiText -match '(?m)^\s*Status\s*=\s*("[^"]+"|utf8\.char\(0x1F4CA\))'
)
if (-not ($bidAnimeRouted -and $bidAnimeAuctionShape -and $bidAnimeAutoFarm -and $bidAnimeAdminKitAbsent -and $bidAnimeNavigationIcons)) {
    throw "Bid for Anime routing, auction payload, auto-farm, or AdminKit exclusion contract failed"
}

$mineMountainText = Get-Content -LiteralPath (Join-Path $repo "games/mine_a_mountain.lua") -Raw
$mineMountainRouted = $settingsText -match '(?s)MineAMountain\s*=\s*\{.*?UniverseId\s*=\s*10187294555.*?125927821145949.*?games/mine_a_mountain\.lua'
$mineMountainCreditedLoop = (
    $mineMountainText -match 'activatePrompt\(prompt\)' -and
    $mineMountainText -match 'Remotes\.GoHome:FireServer\("sell"\)' -and
    $mineMountainText -match 'Remotes\.SellRequest:FireServer\("all"\)' -and
    $mineMountainText -match 'Remotes\.ShopBuy:FireServer\(item\.id\)' -and
    $mineMountainText -match 'Remotes\.UpgradeBuy:FireServer\(kind,\s*bundle\)'
)
$mineMountainFullAuto = (
    $mineMountainText -match 'Name\s*=\s*"Full OP Mining Loop"' -and
    $mineMountainText -match 'TargetMode\s*=\s*"Best Value"' -and
    $mineMountainText -match 'MaximumTier\s*=\s*0' -and
    $mineMountainText -match 'catalogScore\(category,\s*item\)\s*<=\s*ownedBestScore'
)
$mineMountainPages = (
    $mineMountainText -match 'addHomeCategory\("Farming"' -and
    $mineMountainText -match 'addHomeCategory\("Upgrades"' -and
    $mineMountainText -match 'addHomeCategory\("Shop"' -and
    $mineMountainText -match 'addHomeCategory\("Rewards"' -and
    $mineMountainText -match 'addHomeCategory\("Status"' -and
    $mineMountainText -match 'addHomeCategory\("Fundamentals"' -and
    $mineMountainText -match 'FundamentalsPage:AddSection\("Character Fundamentals"' -and
    $mineMountainText -match 'No fake local-only transparency toggle is included' -and
    $mineMountainText -match 'Name\s*=\s*"Stealth Session \(Solo Server\)"' -and
    $mineMountainText -match 'VORMountainResumeSoloSession' -and
    $mineMountainText -match 'Name\s*=\s*"Under-Crystal Mining"' -and
    $mineMountainText -match 'VORMountainResumeUnderCrystalMining' -and
    $mineMountainText -match 'local function repairNearbyPromptRange\(prompt, part, root\)'
)
$mineMountainIndependentPurchases = (
    $mineMountainText -match 'local independentAutoBuy\s*=\s*state\.AutoPickaxe' -and
    $mineMountainText -match 'os\.clock\(\)\s*-\s*state\.LastAutoPurchase\s*>=\s*1\.25' -and
    $mineMountainText -match 'PurchaseBusy'
)
$mineMountainGodspeed = (
    $mineMountainText -match 'Name\s*=\s*"Godspeed Multi-Mine"' -and
    $mineMountainText -match 'local function nearbyGodspeedPrompts\(\)' -and
    $mineMountainText -match 'local function runGodspeedBatch\(\)' -and
    $mineMountainText -match 'task\.spawn\(function\(\)\s*\r?\n\s*local ok = activatePrompt\(candidate\.Prompt\)' -and
    $mineMountainText -match 'Godspeed credited %d/%d crystals' -and
    $mineMountainText -match 'reservedWeight \+ candidate\.Weight <= room' -and
    $mineMountainText -match 'local deadline\s*=\s*os\.clock\(\) \+ maximumHold \+ 0\.75'
)
$mineMountainPickaxeSpeed = (
    $mineMountainText -match 'Name\s*=\s*"Godspeed Pickaxe"' -and
    $mineMountainText -match 'local function setGodspeedPickaxe\(enabled\)' -and
    $mineMountainText -match 'tool:SetAttribute\("NoSwingCooldown",\s*true\)' -and
    $mineMountainText -match 'setGodspeedPickaxe\(false\)'
)
$mineMountainPlotLuck = (
    $mineMountainText -match 'Name\s*=\s*"Auto Upgrade Plot Slots"' -and
    $mineMountainText -match 'Remotes\.UpgradePlotCapacity:FireServer\(\)' -and
    $mineMountainText -match 'local function plotUpgradePrice\(\)' -and
    $mineMountainText -match 'state\.AutoPlotCapacity' -and
    $mineMountainText -notmatch 'Auto Place Best Crystals|PlotPlaceRequest'
)
$mineMountainMovementSafety = (
    $mineMountainText -match 'Name\s*=\s*"Farm Float"' -and
    $mineMountainText -match 'VORMountainHeightHold' -and
    $mineMountainText -match 'Instance\.new\("BodyVelocity"\)' -and
    $mineMountainText -match 'mover\.MaxForce\s*=\s*Vector3\.new\(0,\s*math\.huge,\s*0\)' -and
    $mineMountainText -notmatch 'VORMountainFarmFloat' -and
    $mineMountainText -match 'Name\s*=\s*"Anti Ragdoll"' -and
    $mineMountainText -match 'DeactivateRagdoll:FireServer\(\)' -and
    $mineMountainText -match 'BindToRenderStep\(speedBindName,\s*Enum\.RenderPriority\.Last\.Value' -and
    $mineMountainText -match 'root\.AssemblyLinearVelocity\s*=\s*Vector3\.new\(horizontal\.X'
)
$mineMountainBuriedCrystalGuard = (
    $mineMountainText -match 'local BELOW_MOUNTAIN_MARGIN\s*=\s*8' -and
    $mineMountainText -match 'local function isBelowMountainMap\(part\)' -and
    $mineMountainText -match 'local function crystalTargetPartAndPrompt\(crystal\)' -and
    $mineMountainText -match 'local function isInvalidCrystal\(crystal, part, prompt\)' -and
    ([regex]::Matches($mineMountainText, 'not isInvalidCrystal\(crystal, part, prompt\)').Count -ge 2) -and
    $mineMountainText -match 'if isInvalidCrystal\(crystal, part, prompt\) then' -and
    $mineMountainText -match 'root\.Position\.Y\s*<\s*baseY\s*-\s*8' -and
    $mineMountainText -match 'now\s*-\s*state\.LastFloorRecoveryAt\s*>=\s*0\.25' -and
    $mineMountainText -match 'humanoid\.FloorMaterial\s*~=\s*Enum\.Material\.Air' -and
    $mineMountainText -match 'state\.InvalidTargets\[badTarget\]\s*=\s*true' -and
    $mineMountainText -match 'state\.RejectedTarget\s*=\s*badTarget' -and
    $mineMountainText -match 'MineAMountainBuriedCrystalCount' -and
    $mineMountainText -match 'MineAMountainFloorRecoveries'
)
$mineMountainRareHop = (
    $mineMountainText -match 'Name\s*=\s*"Auto High-Tier Hunt \+ Hop"' -and
    $mineMountainText -match 'Flag\s*=\s*"mam_high_tier_hunt_hop"' -and
    $mineMountainText -match '\[5\]\s*=\s*"Legendary"' -and
    $mineMountainText -match '\[6\]\s*=\s*"Mythic"' -and
    $mineMountainText -match '\[7\]\s*=\s*"Divine"' -and
    $mineMountainText -match '\[8\]\s*=\s*"Empyrean"' -and
    $mineMountainText -match '\[9\]\s*=\s*"Zenith"' -and
    $mineMountainText -match '\[10\]\s*=\s*"Infinity"' -and
    $mineMountainText -match '\[11\]\s*=\s*"Ultima"' -and
    $mineMountainText -match 'state\.HighTierHunt\s*and\s*tierNames\.Legendary' -and
    $mineMountainText -match 'state\.HighTierHunt\s*and\s*tierNames\.Ultima' -and
    $mineMountainText -match 'local function rareCrystalCounts\(\)' -and
    $mineMountainText -match 'local generationSettled\s*=\s*mountainGenerating\s*==\s*false' -and
    $mineMountainText -match 'elseif generationSettled then\s*\r?\n\s*state\.GenerationReady\s*=\s*true' -and
    $mineMountainText -match 'groundStrataBaked\s*~=\s*false' -and
    $mineMountainText -match '"StreamingTargetRadius",\s*\r?\n\s*desiredTarget' -and
    $mineMountainText -match '"StreamingMinRadius",\s*\r?\n\s*desiredMinimum' -and
    $mineMountainText -match 'LocalPlayer:RequestStreamAroundAsync\(center,\s*15\)' -and
    $mineMountainText -match 'state\.StreamingStableFor\s*>=\s*15' -and
    $mineMountainText -match 'replicationReady\s*and\s*highTierTotal\s*==\s*0' -and
    $mineMountainText -match 'HopCountdownDuration\s*=\s*15' -and
    $mineMountainText -match 'local function ensureHopCountdown\(\)' -and
    $mineMountainText -match 'overlay\.DisplayOrder\s*=\s*1000000' -and
    $mineMountainText -match 'VORMountainHopOverlay' -and
    $mineMountainText -match 'local function updateHopCountdown\(remaining\)' -and
    $mineMountainText -match 'local function closeHopCountdown\(\)' -and
    $mineMountainText -match 'finalHighTierTotal\s*==\s*0' -and
    $mineMountainText -match 'MineAMountainHopCountdownRemaining' -and
    $mineMountainText -match 'local function queueMountainResume\(\)' -and
    $mineMountainText -match 'VORMountainResumeHighTierHunt' -and
    $mineMountainText -match 'TeleportService:TeleportToPlaceInstance\(game\.PlaceId,\s*selected\.id,\s*LocalPlayer\)'
)
$mineMountainAdminAbsent = $mineMountainText -notmatch 'AdminCmd|AdminQuery'
if (-not ($mineMountainRouted -and $mineMountainCreditedLoop -and $mineMountainFullAuto -and $mineMountainPages -and $mineMountainIndependentPurchases -and $mineMountainGodspeed -and $mineMountainPickaxeSpeed -and $mineMountainPlotLuck -and $mineMountainMovementSafety -and $mineMountainBuriedCrystalGuard -and $mineMountainRareHop -and $mineMountainAdminAbsent)) {
    throw "Mine a Mountain routing, credited loop, Godspeed batching, pickaxe speed, rare-crystal hopping, plot luck, progression, purchases, movement safety, navigation, or admin-remote exclusion contract failed"
}

$beeSwarmText = Get-Content -LiteralPath (Join-Path $repo "games/bee_swarm_simulator.lua") -Raw
$beeSwarmRouted = $settingsText -match '(?s)BeeSwarm\s*=\s*\{.*?UniverseId\s*=\s*601130232.*?1537690962.*?games/bee_swarm_simulator\.lua'
$beeSwarmNativeLoop = (
    $beeSwarmText -match 'Collectors.*LocalCollect' -and
    $beeSwarmText -match 'LocalCollect\.StartCollection' -and
    $beeSwarmText -match 'Hives\.ButtonEffect' -and
    $beeSwarmText -match 'ConstructHiveCellFromEgg' -and
    $beeSwarmText -match 'ItemPackageEvent' -and
    $beeSwarmText -match 'EquippedAccessories' -and
    $beeSwarmText -match 'pcall\(LocalCollect\.Run\)' -and
    $beeSwarmText -match 'local function activeQuestField\(\)' -and
    $beeSwarmText -match 'StatTools\.GetRawPollenTotal' -and
    $beeSwarmText -match 'Name\s*=\s*"Auto Complete Quests"' -and
    $beeSwarmText -match 'questDialogueNeeded\(\)' -and
    $beeSwarmText -match 'local function currentHivePhase\(\)' -and
    $beeSwarmText -match 'state\.Phase\s*=\s*"Stopping honey maker"' -and
    $beeSwarmText -match 'Events\.ClientCall, "ToyEvent"' -and
    $beeSwarmText -match 'NPCActivator\.ButtonEffect'
)
$beeSwarmPages = (
    $beeSwarmText -match 'addHomeCategory\("Farming"' -and
    $beeSwarmText -match 'addHomeCategory\("Quests"' -and
    $beeSwarmText -match 'addHomeCategory\("Progression"' -and
    $beeSwarmText -match 'addHomeCategory\("Utilities"' -and
    $beeSwarmText -match 'addHomeCategory\("Status"'
)
$beeSwarmCreditedSafety = (
    $beeSwarmText -match 'Moves through nearby field tokens so the server credits the pickup' -and
    $beeSwarmText -match 'Name\s*=\s*"Under-Field Farming"' -and
    $beeSwarmText -match 'UnderFieldDepth\s*=\s*2' -and
    $beeSwarmText -match 'VORBeeUnderFieldHeight' -and
    $beeSwarmText -match 'BeeSwarmUnderField' -and
    $beeSwarmText -notmatch 'hookmetamethod|hookfunction|sethiddenproperty' -and
    $beeSwarmText -notmatch 'Pollen\s*=\s*math\.huge|Honey\s*=\s*math\.huge'
)
$beeSwarmNavigation = (
    $uiText -match 'Quests\s*=\s*utf8\.char\(0x1F4DC\)' -and
    $uiText -match 'Progression\s*=\s*utf8\.char\(0x2B06,\s*0xFE0F\)' -and
    $uiText -match 'Utilities\s*=\s*utf8\.char\(0x1F9F0\)' -and
    $uiText -match 'Status\s*=\s*utf8\.char\(0x1F4CA\)' -and
    $uiText -match 'ActiveGame\.Key\s*==\s*"BeeSwarm"' -and
    $uiText -match '\{"Farming",\s*"Quests",\s*"Progression",\s*"Utilities",\s*"Status"\}'
)
if (-not ($beeSwarmRouted -and $beeSwarmNativeLoop -and $beeSwarmPages -and $beeSwarmCreditedSafety -and $beeSwarmNavigation)) {
    throw "Bee Swarm routing, credited farming loop, navigation, or safety contract failed"
}

$practicalBasketballText = Get-Content -LiteralPath (Join-Path $repo "games/practical_basketball.lua") -Raw
$practicalBasketballRouted = $settingsText -match '(?s)PracticalBasketball\s*=\s*\{.*?UniverseId\s*=\s*7529591378.*?85576197307056.*?80681221431821.*?106120159518740.*?137269396533485.*?games/practical_basketball\.lua'
$practicalBasketballCharacter = $practicalBasketballText -match 'workspace:FindFirstChild\("Characters"\)'
$practicalBasketballAero = $practicalBasketballText -match 'AeroRemoteServices' -and $practicalBasketballText -match 'InputService'
$practicalBasketballBallTag = $practicalBasketballText -match 'GetTagged\("Basketballs"\)'
$practicalBasketballSafeRelease = (
    $practicalBasketballText -notmatch 'GetService\("VirtualInputManager"\)|SendKeyEvent|keyrelease' -and
    $practicalBasketballText -notmatch 'hookmetamethod|hookfunction' -and
    $practicalBasketballText -match 'child:GetAttribute\("Active"\)\s*==\s*true' -and
    $practicalBasketballText -match 'serverReleased\s*==\s*false' -and
    $practicalBasketballText -match 'shootInputHeld\(\)' -and
    $practicalBasketballText -match 'Description\s*=\s*"Releases held E or native mobile Shoot input' -and
    $practicalBasketballText -match 'if input\.KeyCode\s*~=\s*Enum\.KeyCode\.E then' -and
    $practicalBasketballText -notmatch 'or UserInputService:IsKeyDown\(Enum\.KeyCode\.Space\)\s*\n\s*end\s*\n\s*\n\s*local function resetShot'
)
$practicalBasketballReliableGreen = (
    $practicalBasketballText -notmatch 'task\.delay\(state\.ReleaseDelay' -and
    $practicalBasketballText -notmatch 'Name\s*=\s*"Extra Release Lead"' -and
    $practicalBasketballText -notmatch 'Name\s*=\s*"Vertical Perfect Offset"' -and
    $practicalBasketballText -match 'PerfectTravels\s*=\s*\{' -and
    $practicalBasketballText -match 'Vertical\s*=\s*Vector2\.new\(0,\s*-1\.415\)' -and
    $practicalBasketballText -match 'targetTravel\s*=\s*\(targetOffset\s*-\s*state\.ShotStartOffset\):Dot\(state\.ShotDirection\)' -and
    $practicalBasketballText -match 'state\.ShotTravel\s*>=\s*targetTravel' -and
    $practicalBasketballText -match '\(offset\s*-\s*previousOffset\)\.Magnitude\s*>\s*0\.000001' -and
    $practicalBasketballText -match 'if offsetChanged then\s*state\.LastMeterSampleAt\s*=\s*sampleAt' -and
    $practicalBasketballText -match 'observedSpeed\s*>\s*0\s*and\s*observedSpeed\s*<\s*5' -and
    $practicalBasketballText -match 'state\.MeterSpeed\s*\*\s*0\.7\s*\+\s*observedSpeed\s*\*\s*0\.3' -and
    $practicalBasketballText -match 'predictedDelay\s*<=\s*0\.025' -and
    $practicalBasketballText -match 'ScheduledReleaseId\s*=\s*nil' -and
    $practicalBasketballText -match 'RenderStepDuration\s*=\s*1\s*/\s*60' -and
    $practicalBasketballText -match 'state\.RenderStepDuration\s*\*\s*1\.5' -and
    $practicalBasketballText -match 'task\.delay\(math\.max\(0,\s*releaseDelay\s*-\s*schedulerLead\)' -and
    $practicalBasketballText -match 'repeat until os\.clock\(\)\s*>=\s*deadline' -and
    $practicalBasketballText -match 'character:GetAttribute\("ShotStartTime"\)\s*==\s*expectedShotToken' -and
    $practicalBasketballText -match 'commitScheduledRelease\(' -and
    $practicalBasketballText -match 'state\.PendingReleaseTravel\s*=\s*releaseTravel' -and
    $practicalBasketballText -match 'state\.PendingReleaseDirection\s*=\s*releaseDirection' -and
    $practicalBasketballText -notmatch 'local travelCorrection\s*=\s*\(\{' -and
    $practicalBasketballText -notmatch 'TargetLowerTravels\s*=\s*\{' -and
    $practicalBasketballText -notmatch 'TargetUpperTravels\s*=\s*\{' -and
    $practicalBasketballText -match 'ShotProfiles\s*=\s*\{' -and
    $practicalBasketballText -match 'ReleaseRecords\s*=\s*\{' -and
    $practicalBasketballText -match 'Name\s*=\s*"Release Fine-Tune"' -and
    $practicalBasketballText -match 'Min\s*=\s*-50' -and
    $practicalBasketballText -match 'Max\s*=\s*50' -and
    $practicalBasketballText -match 'Step\s*=\s*0\.05' -and
    $practicalBasketballText -match 'Name\s*=\s*"Later \+0\.05 ms"' -and
    $practicalBasketballText -match 'Name\s*=\s*"Earlier -0\.05 ms"' -and
    $practicalBasketballText -match 'Name\s*=\s*"Reset Fine-Tune"' -and
    $practicalBasketballText -match 'predictedDelay\s*=\s*remainingTravel\s*/\s*state\.MeterSpeed\s*\+\s*\(state\.ManualReleaseDelayMs\s*/\s*1000\)' -and
    $practicalBasketballText -match 'Name\s*=\s*"Adaptive Timing"' -and
    $practicalBasketballText -match 'local function buildShotSignature\(character,\s*meterName\)' -and
    $practicalBasketballText -match 'character:GetAttribute\("BaseAnimation"\)' -and
    $practicalBasketballText -match 'quantize\(character:GetAttribute\("ShotSpeed"\),\s*0\.05\)' -and
    $practicalBasketballText -match 'quantize\(character:GetAttribute\("deltaTime"\),\s*0\.001\)' -and
    $practicalBasketballText -match 'quantize\(character:GetAttribute\("meterRotation"\),\s*1\)' -and
    $practicalBasketballText -match 'profileCount\s*>=\s*128' -and
    $practicalBasketballText -match '#state\.ReleaseRecords\s*>\s*4' -and
    $practicalBasketballText -match 'now\s*-\s*state\.ReleaseRecords\[1\]\.At\s*>\s*3' -and
    $practicalBasketballText -match 'state\.CurrentShotSignature\s*==\s*expectedShotSignature' -and
    $practicalBasketballText -match 'math\.abs\(state\.ActiveTargetOffset\.Y\s*-\s*expectedTargetY\)\s*<\s*0\.00001' -and
    $practicalBasketballText -match 'profile\.EarlyY\s*>=\s*profile\.LateY' -and
    $practicalBasketballText -match 'profile\.Locked\s*=\s*true' -and
    $practicalBasketballText -match 'profile\.MissStreak\s*<\s*2' -and
    $practicalBasketballText -match 'profile\.TargetY\s*=\s*math\.clamp\(profile\.TargetY,\s*-1\.440,\s*-1\.390\)' -and
    $practicalBasketballText -match 'ShotFurthestOffset\s*=\s*nil' -and
    $practicalBasketballText -match 'FullOffsets\s*=\s*\{' -and
    $practicalBasketballText -match 'Vertical\s*=\s*Vector2\.new\(0,\s*-1\.46824694\)' -and
    $practicalBasketballText -match 'syncVisibleMeter\(' -and
    $practicalBasketballText -match 'state\.FullOffsets\[releaseMeter\]' -and
    $practicalBasketballText -notmatch 'previousTarget:Lerp\(correctedTarget' -and
    $practicalBasketballText -match 'Shoot remote unavailable; retrying'
)
$practicalBasketballStuckRecovery = (
    $practicalBasketballText -match '"DropBall"' -and
    $practicalBasketballText -match 'local function recoverStuckPossession\(character,\s*now\)' -and
    $practicalBasketballText -match 'character:GetAttribute\("CanMove"\)\s*==\s*false' -and
    $practicalBasketballText -match 'local staleShootingPossession\s*=\s*carryingBasketball' -and
    $practicalBasketballText -match 'action\s*==\s*"Shooting"\s*\n\s*and keysReleased' -and
    $practicalBasketballText -match 'state\.PossessionRecoveryStage\s*==\s*0\s*and\s*stuckFor\s*>=\s*0\.75' -and
    $practicalBasketballText -match 'fireRemote\("DropBall"\)'
)
$practicalBasketballReliableGuard = (
    $practicalBasketballText -match 'GuardRefreshAt\s*=\s*0' -and
    $practicalBasketballText -match 'character:GetAttribute\("HoldingG"\)' -and
    $practicalBasketballText -match 'local carryingBasketball\s*=\s*hasBasketball\(character\)' -and
    $practicalBasketballText -match 'state\.AutoGuard\s*and\s*inGame\s*and\s*not carryingBasketball' -and
    $practicalBasketballText -match 'setGuardHeld\(true,\s*true\)' -and
    $practicalBasketballText -match 'setGuardHeld\(false,\s*true\)'
)
$practicalBasketballSharedProfiles = (
    $settingsText -match 'activeGame\s*~=\s*nil\s*and\s*activeGame\.Key\s*==\s*"PracticalBasketball"' -and
    $settingsText -match 'settings\.ConfigScopeId\s*=\s*sharesUniverseProfiles\s*and\s*universeId\s*or\s*placeId' -and
    $settingsText -match 'settings\.LegacyConfigRoots\s*=\s*\{\}' -and
    $practicalBasketballText -match 'Flag\s*=\s*"practical_basketball_auto_green"' -and
    $profilesText -match 'local function migrateLegacyConfigs\(\)' -and
    $profilesText -match 'metadata\.scopeId\s*=\s*SETTINGS\.ConfigScopeId' -and
    $profilesText -match 'not isfile\(destination\)' -and
    $profilesText -match 'migrateLegacyConfigs\(\)'
)
$practicalBasketballTimingMigration = (
    $profilesText -match 'local PROFILE_VERSION\s*=\s*7' -and
    $profilesText -match 'local function normalizeProfileData\(metadata\)' -and
    $profilesText -match 'practical_basketball_vertical_perfect_offset\s*=\s*nil' -and
    $profilesText -match 'practical_basketball_release_delay\s*=\s*nil' -and
    $profilesText -match 'version\s*=\s*PROFILE_VERSION' -and
    $profilesText -match 'if normalizeProfileData\(data\) then'
)
$practicalBasketballRailIcons = (
    $uiText -match 'Offense\s*=\s*utf8\.char\(0x1F3C0\)' -and
    $uiText -match 'Defense\s*=\s*utf8\.char\(0x1F6E1,\s*0xFE0F\)'
)
$practicalBasketballPages = (
    $practicalBasketballText -match 'addHomeCategory\("[^"]*Shooting"' -and
    $practicalBasketballText -match 'addHomeCategory\("[^"]*Offense"' -and
    $practicalBasketballText -match 'addHomeCategory\("[^"]*Defense"' -and
    $practicalBasketballText -match 'addHomeCategory\("[^"]*Dribble"' -and
    $practicalBasketballText -match 'addHomeCategory\("[^"]*Visuals"'
)
$practicalBasketballDribbleChains = (
    $practicalBasketballText -match 'Name\s*=\s*"Auto Dribble Chain"' -and
    $practicalBasketballText -match 'Options\s*=\s*\{"Guarded Only",\s*"Always"\}' -and
    $practicalBasketballText -match 'DRIBBLE_MOVE_INPUTS' -and
    $practicalBasketballText -match '\["All Moves"\]' -and
    $practicalBasketballText -match 'resolveValueObject\(character,\s*"Basketball"\)' -and
    $practicalBasketballText -notmatch 'Auto Dribbling Tutorial'
)
$practicalBasketballAutoSprint = (
    $practicalBasketballText -match 'if state\.AutoSprint then' -and
    $practicalBasketballText -match 'movementInputHeld\(character\)' -and
    $practicalBasketballText -match 'humanoid\.MoveDirection\.Magnitude\s*>\s*0\.05' -and
    $practicalBasketballText -notmatch 'if state\.AutoSprint and inGame then'
)
$practicalBasketballFovLock = (
    $practicalBasketballText -match 'GetPropertyChangedSignal\("FieldOfView"\)' -and
    $practicalBasketballText -match 'updateVisionAndStatus\(character,\s*now\)\s*\r?\n\s*applyCamera\(\)' -and
    $practicalBasketballText -match 'Name\s*=\s*"Reset Camera FOV"' -and
    $practicalBasketballText -match 'fovConnection:Disconnect\(\)'
)
$practicalBasketballFHotkey = (
    $practicalBasketballText -match 'Name\s*=\s*"F Chain Hotkey"' -and
    $practicalBasketballText -match 'BindActionAtPriority\(' -and
    $practicalBasketballText -match 'Enum\.KeyCode\.F' -and
    $practicalBasketballText -match 'Enum\.ContextActionResult\.Sink' -and
    $practicalBasketballText -match 'ContextActionService:UnbindAction\(comboHotkeyAction\)'
)
$practicalBasketballCustomPreview = (
    $practicalBasketballText -match 'Window\.AvatarCharacterResolver\s*=\s*resolveCharacter' -and
    $uiText -match 'local customResolver\s*=\s*self\.AvatarCharacterResolver' -and
    $uiText -match 'resolveAvatarCharacter\(\)'
)
$practicalBasketballMobileSupport = (
    $practicalBasketballText -match 'state\.MobileShootHeld' -and
    $practicalBasketballText -match 'OffenseButton.*OffenseThumbstick' -and
    $practicalBasketballText -match 'Name\s*=\s*"Mobile Basketball Button"' -and
    $practicalBasketballText -match 'PracticalBasketballMobileDribble' -and
    $practicalBasketballText -match 'triggerSelectedChain\("Mobile"\)'
)
$practicalBasketballQuickLaunch = (
    $uiText -match 'self\.Pages\.Shooting' -and
    $uiText -match '\{"Shooting",\s*"Offense",\s*"Defense",\s*"Dribble",\s*"Visuals"\}'
)
if (-not ($practicalBasketballRouted -and $practicalBasketballCharacter -and $practicalBasketballAero -and $practicalBasketballBallTag -and $practicalBasketballSafeRelease -and $practicalBasketballReliableGreen -and $practicalBasketballReliableGuard -and $practicalBasketballStuckRecovery -and $practicalBasketballSharedProfiles -and $practicalBasketballTimingMigration -and $practicalBasketballRailIcons -and $practicalBasketballPages -and $practicalBasketballDribbleChains -and $practicalBasketballAutoSprint -and $practicalBasketballFovLock -and $practicalBasketballFHotkey -and $practicalBasketballCustomPreview -and $practicalBasketballMobileSupport -and $practicalBasketballQuickLaunch)) {
    throw "Practical Basketball routing or Aero adapter contract failed"
}

$mm2Text = Get-Content -LiteralPath (Join-Path $repo "games/murder_mystery_2.lua") -Raw
$reviveRemoved = (
    -not (Test-Path -LiteralPath (Join-Path $repo "games/revive.lua")) -and
    -not (Test-Path -LiteralPath (Join-Path $repo "codex_revive_hub.lua")) -and
    $settingsText -notmatch 'Key\s*=\s*"Revive"' -and
    $settingsText -notmatch 'games/revive\.lua'
)
$mm2Routing = (
    $settingsText -match 'Key\s*=\s*"MurderMystery2"' -and
    $settingsText -match 'DisplayName\s*=\s*"Murder Mystery 2"' -and
    $settingsText -match 'UniverseId\s*=\s*66654135' -and
    $settingsText -match 'RootPlaceId\s*=\s*142823291' -and
    $settingsText -match 'Module\s*=\s*"games/murder_mystery_2\.lua"'
)
$mm2NativeBehavior = (
    $mm2Text -match 'CurrentRoundClient' -and
    $mm2Text -match 'CollectionService:HasTag\(tool,\s*"Weapon_Gun"\)' -and
    $mm2Text -match 'CollectionService:HasTag\(tool,\s*"Weapon_Knife"\)' -and
    $mm2Text -match 'remote:FireServer\(origin,\s*CFrame\.new\(targetRoot\.Position\)\)' -and
    $mm2Text -match 'KnifeStabbed' -and
    $mm2Text -match 'HandleTouched:FireServer\(targetRoot\)' -and
    $mm2Text -match 'FindFirstChild\("CoinContainer"\)' -and
    $mm2Text -match 'OpenCrate' -and
    $mm2Text -match 'InvokeServer\(state\.SelectedBox,\s*"MysteryBox",\s*"Coins"\)' -and
    $mm2Text -match 'FindFirstChild\("Prestige"\)'
)
$mm2Pages = @("Combat", "Autofarm", "Character", "Visuals", "World", "Misc")
foreach ($page in $mm2Pages) {
    if ($mm2Text -notmatch ('addHomeCategory\("' + [regex]::Escape($page) + '"')) {
        throw "Murder Mystery 2 page is missing: $page"
    }
}
if (-not ($reviveRemoved -and $mm2Routing -and $mm2NativeBehavior)) {
    throw "Murder Mystery 2 routing/native adapter contract failed"
}

$gunfightText = Get-Content -LiteralPath (Join-Path $repo "games/gunfight_arena.lua") -Raw
$gunfightRouting = (
    $settingsText -match 'Key\s*=\s*"GunfightArena"' -and
    $settingsText -match 'UniverseId\s*=\s*5012222382' -and
    $settingsText -match 'RootPlaceId\s*=\s*15514727567' -and
    $settingsText -match 'Module\s*=\s*"games/gunfight_arena\.lua"'
)
$gunfightNativeBehavior = (
    $gunfightText -match 'FindFirstChild\("Vortex"\)' -and
    $gunfightText -match 'require\(ReplicatedStorage:WaitForChild\("MovementData"\)\)' -and
    $gunfightText -match 'LocalPlayer:GetAttribute\("Team"\)' -and
    $gunfightText -match 'mode == "BNTY" or mode == "GUN" or mode == "FFA" or mode == "ALL"' -and
    $gunfightText -match 'steadiness\.Value = 0' -and
    $gunfightText -notmatch 'steadiness\.Value = 100' -and
    $gunfightText -match '__VORGunfightArenaCleanup' -and
    $gunfightText -match 'resetMovement\(\)' -and
    $gunfightText -match 'GetPropertyChangedSignal\("Brightness"\)' -and
    $gunfightText -match 'workspace:Raycast' -and
    $gunfightText -match 'Enum\.KeyCode\.ButtonL2' -and
    $gunfightText -match 'Flag\s*=\s*"gfa_enemy_esp"'
)
if (-not ($gunfightRouting -and $gunfightNativeBehavior)) {
    throw "Gunfight Arena routing/native adapter contract failed"
}

$sniperArenaText = Get-Content -LiteralPath (Join-Path $repo "games/sniper_arena.lua") -Raw
$sniperArenaRouting = (
    $settingsText -match 'Key\s*=\s*"SniperArena"' -and
    $settingsText -match 'UniverseId\s*=\s*9534705677' -and
    $settingsText -match 'RootPlaceId\s*=\s*122446657157717' -and
    $settingsText -match '\[126042865144779\]\s*=\s*true' -and
    $settingsText -match 'Module\s*=\s*"games/sniper_arena\.lua"'
)
$sniperArenaNativeBehavior = (
    $sniperArenaText -match '__VORSniperArenaCleanup' -and
    $sniperArenaText -match 'local ownedCleanup' -and
    $sniperArenaText -match '__VORSniperArenaCleanup == ownedCleanup' -and
    $sniperArenaText -notmatch 'local cleanup = runtimeEnvironment\.__VORSniperArenaCleanup' -and
    $sniperArenaText -match 'WeaponService' -and
    $sniperArenaText -match 'StatusService\.GetStatus,\s*"Killed"' -and
    $sniperArenaText -match 'KilledUnlock' -and
    $sniperArenaText -match 'LoadoutService\.SetSlot' -and
    $sniperArenaText -match 'QuestService' -and
    $sniperArenaText -match 'MailboxService' -and
    $sniperArenaText -match 'OnlineRewardClaim' -and
    $sniperArenaText -match 'MatchmakingService\.Match' -and
    $sniperArenaText -match 'debug\.setupvalue,\s*originalLocalShoot,\s*2,\s*silentCameraGetter' -and
    $sniperArenaText -match 'debug\.setupvalue,\s*originalLocalShoot,\s*4,\s*silentTargetResolver' -and
    $sniperArenaText -match 'CFrame\.lookAt\(cameraFrame\.Position,\s*predictedPosition\(part\)\)' -and
    $sniperArenaText -match 'BindToRenderStep\(renderStepName,\s*Enum\.RenderPriority\.Last\.Value - 1' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_silent_aim"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_cursor_aimbot"[^\r\n]*Default\s*=\s*true' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_cursor_smoothness"' -and
    $sniperArenaText -match 'Max\s*=\s*30[^\r\n]*Default\s*=\s*10' -and
    $sniperArenaText -match 'local response = 30 / smoothness' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_cursor_radius"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_target_part_v2"' -and
    $sniperArenaText -match 'moveMouseRelative' -and
    $sniperArenaText -match 'UserInputService:GetMouseLocation\(\)' -and
    $sniperArenaText -notmatch 'mode == "Arcade" or string\.find\(mode, "FFA"' -and
    $sniperArenaText -match 'local function sameTeamModel\(model\)' -and
    $sniperArenaText -match 'if sameTeamModel\(model\) then return end' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_triggerbot"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_trigger_delay_ms"' -and
    $sniperArenaText -match 'track\(LocalMouse\.Move:Connect\(tryTrigger\)\)' -and
    $sniperArenaText -match 'local firstHover = target ~= lastTriggerTarget' -and
    $sniperArenaText -match 'LocalPlayer:GetAttribute\("GameRoom"\)' -and
    $sniperArenaText -match 'room:FindFirstChild\("Entities"\)' -and
    $sniperArenaText -match 'local function menuBlocksTrigger\(\)' -and
    $sniperArenaText -match 'GuiService\.MenuIsOpen' -and
    $sniperArenaText -match 'mainWindow == nil or mainWindow\.Visible' -and
    $sniperArenaText -match '(?s)not isActiveMatch\(\).*?or menuBlocksTrigger\(\)' -and
    $sniperArenaText -match 'SniperArenaTriggerPausedByMenu' -and
    $sniperArenaText -match 'hostileForTarget\(target\)' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_hitbox_visible_body_v3"[^\r\n]*Persist\s*=\s*false[^\r\n]*Default\s*=\s*false' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_hitbox_size_v3"[^\r\n]*Persist\s*=\s*false[^\r\n]*Max\s*=\s*30' -and
    $sniperArenaText -match 'local function hasVisibleBody\(model\)' -and
    $sniperArenaText -match 'distance < bestDistance and hasVisibleBody\(hostile\.Model\)' -and
    $sniperArenaText -match 'state\.HitboxExpand and not hasVisibleBody\(hostile\.Model\)' -and
    $sniperArenaText -match 'head\.Size = Vector3\.new\(size, size, size\)' -and
    $sniperArenaText -match 'head\.CanQuery = true' -and
    $sniperArenaText -match 'updateHitboxes\(\)\s*\r?\n\s*updateAim\(deltaTime\)' -and
    $sniperArenaText -match 'acquireExpandedHitboxTarget\(\)' -and
    $sniperArenaText -match 'CollectionService:GetTagged\("Bot"\)' -and
    $sniperArenaText -match 'if model and not sameTeamModel\(model\) then expandModelHead\(model\) end' -and
    $sniperArenaText -match 'FindFirstChild\("Head", true\)' -and
    $sniperArenaText -match 'restoreHitboxes\(\)' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_no_recoil"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_no_spread"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_fast_reload"' -and
    $sniperArenaText -match 'valueObject\.Value = replacement' -and
    $sniperArenaText -match 'restoreWeaponValues\(\)' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_auto_unlock"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_auto_open_cases"' -and
    $sniperArenaText -match 'GachaService\.Gacha' -and
    $sniperArenaText -notmatch 'sniper_arena_movement_boost' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_native_slide_speed"' -and
    $sniperArenaText -match 'SlideHelper\.Slide = boostedSlide' -and
    $sniperArenaText -match 'GameConfig\.Movement\.SlideSpeed' -and
    $sniperArenaText -match 'adjusted\.Speed = .*\* multiplier' -and
    $sniperArenaText -notmatch 'root\.CFrame = root\.CFrame \+' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_esp"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_esp_color"' -and
    $sniperArenaText -match 'Flag\s*=\s*"sniper_arena_esp_minimal_names"[^\r\n]*Default\s*=\s*false' -and
    $settingsText -match 'activeGame\.Key == "SniperArena"' -and
    $sniperArenaText -match 'hostile\.Kind == "BOT" and "BOT"' -and
    $sniperArenaText -match 'HighlightHolder' -and
    $sniperArenaText -notmatch 'GetTagged\("Boss"\)' -and
    $sniperArenaText -match 'model:IsDescendantOf\(tempRoot\)' -and
    $sniperArenaText -match 'addHomeCategory\("[^\"]* Combat"' -and
    $sniperArenaText -match 'addHomeCategory\("[^\"]* Inventory"' -and
    $sniperArenaText -match 'addHomeCategory\("[^\"]* Progress"' -and
    $sniperArenaText -match 'addHomeCategory\("[^\"]* Visuals"' -and
    $sniperArenaText -match 'addHomeCategory\("[^\"]* World"' -and
    $sniperArenaText -match 'installSniperArenaBackground\(\)' -and
    $sniperArenaText -match 'thumbnails\.roblox\.com/v1/games/icons\?universeIds=9534705677' -and
    $sniperArenaText -match 'SETTINGS\.DefaultPanelBackground = "[^\"]* Sniper Arena"' -and
    $profilesText -match 'for name, image in pairs\(SETTINGS\.PanelBackgrounds or \{\}\)' -and
    $profilesText -match 'table\.sort\(backgroundOptions\)' -and
    $profilesText -match 'table\.find\(backgroundOptions, SETTINGS\.DefaultPanelBackground\)' -and
    $profilesText -match '(?s)Name\s*=\s*"Hub Transparency".*?Min\s*=\s*0,' -and
    $uiText -match 'local lowEndSolidify = math\.clamp\(\(0\.15 - value\) / 0\.15, 0, 1\)' -and
    $uiText -match 'base \* \(1 - 0\.35 \* lowEndSolidify\)' -and
    $sniperArenaText -match 'SniperArenaModuleReady'
)
if (-not ($sniperArenaRouting -and $sniperArenaNativeBehavior)) {
    throw "Sniper Arena routing/native adapter contract failed"
}

$dragonBallText = Get-Content -LiteralPath (Join-Path $repo "games/dragon_ball_legendary_powers.lua") -Raw
$dragonBallRouting = (
    $settingsText -match 'Key\s*=\s*"DragonBallLegendaryPowers"' -and
    $settingsText -match 'UniverseId\s*=\s*4501539222' -and
    $settingsText -match 'RootPlaceId\s*=\s*12860709641' -and
    $settingsText -match 'Module\s*=\s*"games/dragon_ball_legendary_powers\.lua"'
)
$dragonBallNativeBehavior = (
    $dragonBallText -match 'Combat:WaitForChild\("Punch"\)' -and
    $dragonBallText -match 'Combat:WaitForChild\("Damage"\)' -and
    $dragonBallText -match 'DamageRemote:FireServer\("Punch", target\)' -and
    $dragonBallText -match 'Options\s*=\s*\{"Power Ladder"' -and
    $dragonBallText -match 'Flag\s*=\s*"dblp_auto_farm"' -and
    $dragonBallText -match 'Flag\s*=\s*"dblp_auto_op_route"' -and
    $dragonBallText -match 'Persistent Gravity' -and
    $dragonBallText -match 'Training Weight' -and
    $dragonBallText -match 'Ability Barrage' -and
    $dragonBallText -match 'Spirit' -and
    $dragonBallText -match 'SpecialBeam' -and
    $dragonBallText -match 'Multi-Hit Burst' -and
    $dragonBallText -match 'summoner'
)
if (-not ($dragonBallRouting -and $dragonBallNativeBehavior)) {
    throw "Dragon Ball Legendary Powers routing/native/progression contract failed"
}

$capybarasText = Get-Content -LiteralPath (Join-Path $repo "games/capybaras_vs_plants.lua") -Raw
$capybarasRouting = (
    $settingsText -match 'Key\s*=\s*"CapybarasVsPlants"' -and
    $settingsText -match 'UniverseId\s*=\s*8841437826' -and
    $settingsText -match 'RootPlaceId\s*=\s*104973076655377' -and
    $settingsText -match 'Module\s*=\s*"games/capybaras_vs_plants\.lua"'
)
$capybarasNativeBehavior = (
    $capybarasText -match 'RequestPersonalStock:InvokeServer' -and
    $capybarasText -match 'Remotes\.BuyItem:FireServer\(name\)' -and
    $capybarasText -match 'Remotes\.SummonBoss:InvokeServer\("Summon", state\.SelectedBoss\)' -and
    $capybarasText -match 'local function processReadyEggs\(single\)' -and
    $capybarasText -match 'Multi\s*=\s*true' -and
    $capybarasText -match 'Remotes\.CollectionMachine:FireServer\(\)' -and
    $capybarasText -match 'Remotes\.ClaimQuest:InvokeServer' -and
    $capybarasText -match 'only have 5 capybaras in one lane' -and
    $capybarasText -match 'laneLimitPopupVisible\(\)' -and
    $capybarasText -match 'autoPlaceCapybarasToggle:Set\(false, true\)' -and
    $capybarasText -match 'MutationData\.calculateDamage' -and
    $capybarasText -match 'damage / attackSpeed' -and
    $capybarasText -match 'if a\.Dps ~= b\.Dps then return a\.Dps > b\.Dps end' -and
    $capybarasText -match '__VORCapybarasVsPlantsCleanup'
)
if (-not ($capybarasRouting -and $capybarasNativeBehavior)) {
    throw "Capybaras VS Plants routing/native adapter contract failed"
}

$gag2Text = Get-Content -LiteralPath (Join-Path $repo "games/grow_a_garden_2.lua") -Raw
$gag2Routing = (
    $settingsText -match 'Key\s*=\s*"GrowAGarden2"' -and
    $settingsText -match 'UniverseId\s*=\s*10200395747' -and
    $settingsText -match 'RootPlaceId\s*=\s*97598239454123' -and
    $settingsText -match 'Module\s*=\s*"games/grow_a_garden_2\.lua"'
)
$gag2NativeBehavior = (
    $gag2Text -match 'stockNameSet\("SeedShop"\)' -and
    $gag2Text -match 'SharedModules\.GearShopData' -and
    $gag2Text -match 'FindFirstChild\("PetData"\)' -and
    $gag2Text -match 'cost>0 and spawnChance>0' -and
    $gag2Text -match 'SeedPackSpawnServerLocations' -and
    $gag2Text -match 'SeedPackSpawnClient' -and
    $gag2Text -match 'prompt:InputHoldBegin\(\)' -and
    $gag2Text -match 'prompt\.HoldDuration' -and
    $gag2Text -match 'marker:GetAttribute\("MegaSeed"\)' -and
    $gag2Text -match 'marker:GetAttribute\("RainbowSeed"\)' -and
    $gag2Text -match 'marker:GetAttribute\("GoldSeed"\)' -and
    $gag2Text -match 'GardenZoneData' -and
    $gag2Text -match 'Net\.Shovel\.HitPlayer:Fire\(player\.UserId\)' -and
    $gag2Text -match 'GrowAGarden2ModuleReady' -and
    $gag2Text -notmatch 'Net\.Steal|StealFlags|Auto Steal at Night|Highest Value Steal First'
)
if (-not ($gag2Routing -and $gag2NativeBehavior)) {
    throw "Grow a Garden 2 routing/native adapter contract failed"
}

$ironManText = Get-Content -LiteralPath (Join-Path $repo "games/iron_man_reimagined.lua") -Raw
$ironManRouting = (
    $settingsText -match 'Key\s*=\s*"IronManReimagined"' -and
    $settingsText -match 'UniverseId\s*=\s*5813007850' -and
    $settingsText -match 'RootPlaceId\s*=\s*16929212566' -and
    $settingsText -match 'Module\s*=\s*"games/iron_man_reimagined\.lua"'
)
$ironManNativeBehavior = (
    $ironManText -match '__VORIronManReimaginedCleanup' -and
    $ironManText -match 'FindFirstChild\("IronMan"\)' -and
    $ironManText -match 'fireRemote\("Piece",\s*"RepairAll"\)' -and
    $ironManText -match 'fireRemote\("Flight",\s*"Flares"\)' -and
    $ironManText -match 'GetAttribute\("TargetName"\)' -and
    $ironManText -match 'VirtualInputManager:SendKeyEvent' -and
    $ironManText -match '\["War Machine"\]\s*=\s*773087650' -and
    $ironManText -match 'Scavver\s*=\s*773087650' -and
    $ironManText -match '\["Mark 85"\]\s*=\s*791792311' -and
    $ironManText -match 'Endosym\s*=\s*791792311' -and
    $ironManText -match 'UserOwnsGamePassAsync' -and
    $ironManText -match 'PromptGamePassPurchase' -and
    $ironManText -match 'Flag\s*=\s*"imr_flight_speed_multiplier"' -and
    $ironManText -match 'FlightAutomationSection:AddInput\(\{\s*Name\s*=\s*"Flight Speed Multiplier"' -and
    $ironManText -match 'parseFlightSpeedMultiplier' -and
    $ironManText -match 'isFiniteVelocity' -and
    $ironManText -match 'findNativeFlightVelocity' -and
    $ironManText -match 'velocity\.VectorVelocity\s*=\s*state\.FlightAppliedVelocity' -and
    $ironManText -match 'Flag\s*=\s*"imr_auto_repair"' -and
    $ironManText -match 'Flag\s*=\s*"imr_auto_flares"' -and
    $ironManText -match 'Flag\s*=\s*"imr_aim_assist"' -and
    $ironManText -match 'Flag\s*=\s*"imr_player_esp"'
)
if (-not ($ironManRouting -and $ironManNativeBehavior)) {
    throw "Iron Man: Reimagined routing/native adapter contract failed"
}

$dogRaceText = Get-Content -LiteralPath (Join-Path $repo "games/dog_race.lua") -Raw
$dogRaceRouting = (
    $settingsText -match 'Key\s*=\s*"DogRace"' -and
    $settingsText -match 'UniverseId\s*=\s*10350558449' -and
    $settingsText -match 'RootPlaceId\s*=\s*119609933650338' -and
    $settingsText -match 'Module\s*=\s*"games/dog_race\.lua"'
)
$dogRaceNativeBehavior = (
    $dogRaceText -match '__VORDogRaceCleanup' -and
    $dogRaceText -match 'GetController\("TrainController"\)' -and
    $dogRaceText -match 'StartAutoTrain' -and
    $dogRaceText -match 'GetController\("AutoController"\)' -and
    $dogRaceText -match 'StartAutoFight' -and
    $dogRaceText -match 'QuitContestEvent' -and
    $dogRaceText -match 'UnbindFromRenderStep\("fight"\)' -and
    $dogRaceText -match 'GetController\("DashController"\)' -and
    $dogRaceText -match 'hasTrainingPosture' -and
    $dogRaceText -match 'GetRebirthCost' -and
    $dogRaceText -match 'ClaimOfflineWinsEvent' -and
    $dogRaceText -match 'EggHatchService.*Hatch' -and
    $dogRaceText -match 'FruitShopService.*BuyFruitEvent' -and
    $dogRaceText -match 'TrailService.*BuyTrailEvent' -and
    $dogRaceText -match 'UpgradeService.*Upgrade' -and
    $dogRaceText -match 'HorseService.*UnlockHorseEvent' -and
    $dogRaceText -match 'PrincessService.*UnlockPrincess' -and
    $dogRaceText -match 'PromptProductPurchase' -and
    $dogRaceText -match 'PromptGamePassPurchase' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_train"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_race"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_hatch"' -and
    $dogRaceText -match 'Auto hatch waiting:' -and
    $dogRaceText -match 'DogRaceAutoHatchWaiting' -and
    $dogRaceText -notmatch 'hatchSelected\(state\.HatchCount,\s*false\)\s*then\s*\r?\n\s*state\.AutoHatch\s*=\s*false' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_selected_fruit"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_selected_trail"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_selected_dog"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_selected_partner"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_full_progression"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_smart_best_egg"' -and
    $dogRaceText -match 'retargetBestAffordableWinsEgg' -and
    $dogRaceText -match 'nextBirdWinsReserve' -and
    $dogRaceText -match 'LastHybridHatchPhase' -and
    $dogRaceText -match 'most expensive unlocked egg' -and
    $dogRaceText -match 'OriginalShowHatchResult' -and
    $dogRaceText -match 'Silently hatched' -and
    $dogRaceText -match 'RaceBodyVelocity' -and
    $dogRaceText -match 'dograce_race_speed_multiplier_v2' -and
    $dogRaceText -match 'dograce_lag_proof_race' -and
    $dogRaceText -match 'DogRaceRaceDeliveryRatio' -and
    $dogRaceText -match 'RaceFallbackSteps' -and
    $dogRaceText -match 'DogRaceSilentHatchCount' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_hybrid_progress"' -and
    $dogRaceText -match 'updateHybrid' -and
    $dogRaceText -match 'fightService\.EndContest:Connect' -and
    $dogRaceText -match 'OnlineRewardService.*ClaimOnlineReward' -and
    $dogRaceText -match 'OnlineQuestGui' -and
    $dogRaceText -match 'claimButton\.MouseButton1Click' -and
    $dogRaceText -match '(?s)AchievementService.*?ClaimAchievementEvent' -and
    $dogRaceText -match 'QuestService.*ClaimQuestReward' -and
    $dogRaceText -match '(?s)LongDailyRewardService.*ClaimLongDailyReward' -and
    $dogRaceText -match 'PetService' -and
    $dogRaceText -match 'EnlargeAllPets' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_craft_pets"' -and
    $dogRaceText -match 'DogRaceAutoCraftPets' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_pet_craft_threshold"' -and
    $dogRaceText -match 'petCraftNeeded' -and
    $dogRaceText -match 'DogRacePetCraftNeeded' -and
    $dogRaceText -match 'PotionService' -and
    $dogRaceText -match 'UsePotion' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_potions"' -and
    $dogRaceText -match 'DogRaceAutoPotions' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_wheel"' -and
    $dogRaceText -match 'SpinningWheelService' -and
    $dogRaceText -match 'bestDogStep' -and
    $dogRaceText -match 'bestPartnerStep' -and
    $dogRaceText -match 'bestFruitStep' -and
    $dogRaceText -match 'bestUpgradeStep' -and
    $dogRaceText -match 'ItemCrateService.*BuyCrateWithDiamonds' -and
    $dogRaceText -match '(?s)ItemService.*?EquipItem' -and
    $dogRaceText -match '(?s)ItemService.*?MergeItems' -and
    $dogRaceText -match 'BirdService.*BuyBirdEvent' -and
    $dogRaceText -match 'BirdService.*EquipBirdEvent' -and
    $dogRaceText -match 'ShoeService.*BuyShoeEvent' -and
    $dogRaceText -match 'ShoeService.*EquipShoeEvent' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_bird"' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_shoe"' -and
    $dogRaceText -match 'nextShoeBoneReserve' -and
    $dogRaceText -match 'Dog Race Instructions' -and
    $dogRaceText -match 'Equipment\.Page' -and
    $dogRaceText -match 'Open Birds & Shoes' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_auto_free_egg"' -and
    $dogRaceText -match 'DogRaceFullProgression' -and
    $dogRaceText -match 'DogRaceHybridPhase' -and
    $dogRaceText -match 'Flag\s*=\s*"dograce_race_speed_multiplier_v2"' -and
    $dogRaceText -match 'clearSpeedOverride\(\)'
)
if (-not ($dogRaceRouting -and $dogRaceNativeBehavior)) {
    throw "Dog Race routing/native adapter contract failed"
}

Write-Host "Luau compile: PASS ($($compileFiles.Count) Lua files)"
Write-Host "Game builder contract: PASS (16/16)"
Write-Host "Persistent flag parity: PASS ($($baselineFlags.Count)/$($baselineFlags.Count))"
Write-Host "Revive removal: PASS (routing, module, and standalone builder removed)"
Write-Host "Murder Mystery 2 support: PASS (native roles, tagged weapons, gun/knife remotes, coins, boxes, prestige)"
Write-Host "Murder Mystery 2 pages: PASS ($($mm2Pages.Count)/$($mm2Pages.Count))"
Write-Host "Gunfight Arena support: PASS (Vortex modifiers, custom teams, movement data, PC/controller/mobile aim modes)"
Write-Host "Sniper Arena support: PASS (silent aim shot-ray hook, cursor aimbot, auto-fire trigger, enemy-head hitbox, recoil/spread/reload controls, optional ESP, server-checked unlocks, loadouts, claims, queues)"
Write-Host "Iron Man: Reimagined support: PASS (native actions, paid-suit ownership, custom finite flight speed, repair/flares, aim assist, ESP)"
Write-Host "Dog Race support: PASS (guided full progression, smart/manual eggs, race/train hybrid, birds, bone shoes, rewards, shops, gear, unlocks, cleanup)"
Write-Host "Dragon Ball Legendary Powers support: PASS (power ladder, rapid training, persistent gravity, milestones, proper Shenron flow)"
Write-Host "Capybaras VS Plants support: PASS (native shops, bosses, sequential hatching, rewards, placement, and shovel adapter)"
Write-Host "Grow a Garden 2 support: PASS (live catalogs, natural pets, event seeds, planting, shops, and anti-steal defense)"
Write-Host "Shared Farm Position controls: PASS ($($canonicalPositionFlags.Count)/$($canonicalPositionFlags.Count))"
Write-Host "Blox Fruits category routing: PASS ($($expectedCategories.Count)/$($expectedCategories.Count))"
Write-Host "Blox Fruits raid boss selection: PASS (raid tags, replicated catalog, and sea fallbacks)"
Write-Host "Blox Fruits raid fruit inventory: PASS (owned React tiles, cheapest-first, serialized verified load)"
Write-Host "Blox Fruits raid cycle: PASS (one fruit per raid, completion reset, movement watchdog)"
Write-Host "Fruit M1 native remote shape: PASS (2/2)"
Write-Host "Submerged water support: PASS"
Write-Host "Visible semantic version: PASS ($($semanticVersionMatch.Groups['version'].Value))"
Write-Host "Xeno compatibility: PASS (executor identity, HTTP retry/fallback, teleport resume)"
Write-Host "Manual Fruit M1 cooldown removal: PASS (1.0)"
Write-Host "Typed mob search distances: PASS (numeric input)"
Write-Host "Auto Magnet range: PASS (0-100 magnitude)"
Write-Host "Ownership-independent Auto Magnet: PASS"
Write-Host "Stable Magnet anchor and pull: PASS (continuous server-correction retry, character movement decoupled)"
Write-Host "Double Attack credited-engine ownership: PASS (idempotent pending-state handoff)"
Write-Host "Aura Kill lifecycle ownership: PASS (generation guard across yield, respawn, timeout, and override)"
Write-Host "Sword and Melee damage routing: PASS (registered hit first, native fallback only)"
Write-Host "Blox Fruits damage-debug drain: PASS (tracked connection with module cleanup)"
Write-Host "Blox Fruits Dungeon crash guard: PASS (DMGDEBUG queue drained with cleanup)"
Write-Host "Blox Fruits Dash Length Changer: PASS (native DashLength attribute, respawn and cleanup safe)"
Write-Host "Blox Fruits movement modes: PASS (stored controls are mutually exclusive)"
Write-Host "Mob Aura target travel: PASS (shared tween controller)"
Write-Host "Magnet target filter: PASS (same-type pile, old-type release, frozen animations)"
Write-Host "Mob Aura enemy hold: PASS (fixed ground anchor, stopped animation and physics)"
Write-Host "Magnet hit registration: PASS (35 normal-sea targets, original grouped routing)"
Write-Host "Magnet damage routing: PASS (normal Aura rotation independent from Double Attack)"
Write-Host "Sea-wide berry automation: PASS (live-spawn claim, First/Third Sea random rotation, teleport resume, stay after collection)"
Write-Host "Tyrant notifier: PASS (readable PC/mobile chip, enemies-left text)"
Write-Host "Bid for Anime support: PASS (native auto-farm, semantic navigation icons, no AdminKit)"
Write-Host "Mine a Mountain support: PASS (baseline Godspeed mining, rare-crystal auto-hop/resume, purchases, movement safety, no admin remotes)"
Write-Host "Bee Swarm Simulator support: PASS (native collector, hive, quest, toy, and progression routes)"
Write-Host "Practical Basketball support: PASS (native Aero character, safe meter release, rail icons, and ball tag)"
Write-Host "Practical Basketball Auto Green: PASS (frame-aware release with bounded per-shot profiles)"
Write-Host "Practical Basketball Auto Guard: PASS (authoritative HoldingG reassertion and cleanup)"
Write-Host "Practical Basketball profiles: PASS (shared universe scope with non-destructive legacy migration)"
Write-Host "Practical Basketball timing profiles: PASS (legacy manual offset and delay controls are discarded)"
Write-Host "Practical Basketball dribble chains: PASS (guard trigger, hand-aware presets, custom chain, no tutorial completer)"
Write-Host "Practical Basketball Auto Sprint: PASS (tutorial/free-roam support and movement-vector detection)"
Write-Host "Practical Basketball camera FOV: PASS (change listener, late render lock, and clean reset)"
Write-Host "Practical Basketball F hotkey: PASS (optional high-priority chain action with native-input restore)"
Write-Host "Practical Basketball character preview: PASS (custom Aero character resolver)"
Write-Host "Practical Basketball mobile support: PASS (native Shoot Auto Green and floating chain button)"
Write-Host "Practical Basketball Quick Launch: PASS (Shooting, Offense, Defense, Dribble, Visuals)"
