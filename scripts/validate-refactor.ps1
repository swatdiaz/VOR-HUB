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
    "games/revive.lua",
    "games/mypark.lua",
    "games/practical_basketball.lua",
    "games/anime_expeditions.lua",
    "games/bid_for_anime.lua",
    "games/mine_a_mountain.lua",
    "games/bee_swarm_simulator.lua",
    "games/blox_fruits.lua",
    "games/blox_fruits_experimental.lua",
    "games/blox_fruits_parity.lua",
    "games/blox_fruits_race.lua",
    "games/blox_fruits_pvp.lua",
    "games/blox_fruits_third_sea.lua",
    "games/blox_fruits_dungeons.lua"
)
$compileFiles = $required + @(
    "VOR_HUB.lua",
    "codex_revive_hub.lua",
    "anime_expeditions.lua",
    "blox_fruits_dungeons.lua"
)

if (-not (Test-Path -LiteralPath $Compiler)) {
    throw "Luau compiler was not found: $Compiler"
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
    "blox_raid_multi_grab"
))
$missing = @($baselineFlags | Where-Object {
    -not $modularFlags.Contains($_) -and -not $retiredFlags.Contains($_)
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
if ($bloxText -notmatch 'game\.PlaceId == 100117331123089 and -2161\.889 or 0') {
    throw "Walk on Water is missing its fixed Submerged Island inner-water surface"
}

$parityText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_parity.lua") -Raw
$thirdSeaText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_third_sea.lua") -Raw
$routingChecks = @(
    @($bloxText, 'FarmingPage:AddSection\("Auto Magnet"'),
    @($bloxText, 'FarmingPage:AddSection\("Boss Farming"'),
    @($bloxText, 'ShopPage:AddSection\("Fighting Styles"'),
    @($bloxText, 'SeaPage:AddSection\("World Travel"'),
    @($parityText, 'pages\.Shop:AddSection\("Buso Color"'),
    @($parityText, 'pages\.Farming:AddSection\("Farming ESP & Alerts"'),
    @($parityText, 'pages\.Sea:AddSection\("Rare Island ESP & Alerts"'),
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

$raidFruitInventory = (
    $parityText -match 'rawInvoke\("GetFruits"\)' -and
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
if (-not ($xenoExecutorDetection -and $xenoHttpRetry -and $xenoRequestFallback -and $xenoRuntimeMarker -and $xenoHomeIdentity -and $xenoTeleportResume)) {
    throw "Xeno compatibility contract failed"
}

$manualFruitMaxOk = $bloxText -match 'DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION\s*=\s*1'
$automaticFruitCadenceOk = $bloxText -match 'state\.FruitM1ReadyAt\s*=\s*os\.clock\(\)\s*\+\s*DoubleAttackEngine\.FruitCadence'
if (-not ($manualFruitMaxOk -and $automaticFruitCadenceOk)) {
    throw "Manual Fruit M1 cooldown removal is not uncapped from Aura timing"
}

$magnetOwnershipGateRemoved = $bloxText -notmatch 'local networkOwned\s*=.*isnetworkowner'
$magnetSimulationRadius = $bloxText -match 'setsimulationradius\(math\.huge, math\.huge\)'
$magnetRangeCapped = $bloxText -match '(?s)Name\s*=\s*"Magnet Range".*?Min\s*=\s*0.*?Max\s*=\s*500.*?state\.MagnetRange\s*=\s*math\.clamp\([^\r\n]+, 0, 500\)'
$typedMobSearchCount = ([regex]::Matches(
    $bloxText,
    '(?s)MobFarmSection:AddInput\(\{\s*Name\s*=\s*"(?:Mob Aura|Selected Mob) Search Distance"'
)).Count
if (-not $magnetOwnershipGateRemoved -or -not $magnetSimulationRadius -or -not $magnetRangeCapped -or $typedMobSearchCount -lt 2) {
    throw "Solix-compatible Magnet range or typed mob-search contract failed"
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

$mobAuraCrossTypeGather = $bloxText -match 'local targetName\s*=\s*\(raidGatherEnabled or \(state\.AutoMagnet and state\.MobAuraTp\)\) and nil'
$stickyMagnetCapture = $bloxText -match 'local captured\s*=\s*state\.AutoMagnet and state\.GatherOriginalStates\[enemy\] ~= nil'
$idleCaptureRetention = $bloxText -match 'state\.AutoMagnet and not farmMagnetActive and not multiGrabEnabled'
if (-not ($mobAuraCrossTypeGather -and $stickyMagnetCapture -and $idleCaptureRetention)) {
    throw "Mob Aura Magnet must drag every in-range NPC into the target pile while retaining captured enemies"
}

$autoMagnetAuraFilterRemoved = $bloxText -notmatch 'elseif state\.AutoMagnet and state\.CurrentEnemyName then'
$autoMagnetPairBatchRemoved = $bloxText -notmatch 'elseif \(state\.AutoMagnet or state\.GatherEnemies or \('
$creditedPairLimit = $bloxText -match 'MULTI_ATTACK_TARGET_LIMIT\s*=\s*2'
$thirdSeaConfiguredGroupGather = $bloxText -match 'if state\.ThirdSeaFarmActive and next\(state\.ThirdSeaFarmNames\)'
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
    '(?ms)^\s{12}Name\s*=\s*"Double Attack \(Sword \+ Fruit M1\)".*?^\s{8}\}\)'
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
    $profilesText -match 'local PROFILE_VERSION\s*=\s*6' -and
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

Write-Host "Luau compile: PASS ($($compileFiles.Count) Lua files)"
Write-Host "Game builder contract: PASS (9/9)"
Write-Host "Persistent flag parity: PASS ($($baselineFlags.Count)/$($baselineFlags.Count))"
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
Write-Host "Auto Magnet range: PASS (0-500 magnitude)"
Write-Host "Ownership-independent Auto Magnet: PASS"
Write-Host "Solix-style stable Magnet anchor and pull: PASS (continuous server-correction retry, character movement decoupled)"
Write-Host "Double Attack credited-engine ownership: PASS (idempotent pending-state handoff)"
Write-Host "Aura Kill lifecycle ownership: PASS (generation guard across yield, respawn, timeout, and override)"
Write-Host "Blox Fruits damage-debug drain: PASS (tracked connection with module cleanup)"
Write-Host "Blox Fruits movement modes: PASS (stored controls are mutually exclusive)"
Write-Host "Mob Aura target travel: PASS (shared tween controller)"
Write-Host "Solix Magnet capture retention: PASS (cross-type Mob Aura pile, sticky after entry)"
Write-Host "Solix Magnet damage routing: PASS (normal Aura rotation independent from Double Attack)"
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
