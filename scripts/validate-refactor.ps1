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

$loaderText = Get-Content -LiteralPath (Join-Path $repo "loader.lua") -Raw
$uiText = Get-Content -LiteralPath (Join-Path $repo "core/ui.lua") -Raw
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
$idempotentOverride = $bloxText -match '(?s)local desired\s*=\s*enabled == true\s+if state\.ExperimentalAttackOverride ~= desired then\s+state\.ExperimentalAttackOverride = desired\s+state\.AuraAttackPending = false\s+state\.FruitDispatchPending = false\s+end'
if (-not ($creditedMainDouble -and $requestSpamRemoved -and $idempotentOverride)) {
    throw "Double Attack must leave combat ownership with the credited main Aura engine"
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
    $uiText -match '(?m)^\s*Status\s*=\s*"[^"]+"'
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
    $mineMountainText -match 'addHomeCategory\("Status"'
)
$mineMountainAdminAbsent = $mineMountainText -notmatch 'AdminCmd|AdminQuery'
if (-not ($mineMountainRouted -and $mineMountainCreditedLoop -and $mineMountainFullAuto -and $mineMountainPages -and $mineMountainAdminAbsent)) {
    throw "Mine a Mountain routing, credited loop, progression, navigation, or admin-remote exclusion contract failed"
}

$practicalBasketballText = Get-Content -LiteralPath (Join-Path $repo "games/practical_basketball.lua") -Raw
$practicalBasketballRouted = $settingsText -match '(?s)PracticalBasketball\s*=\s*\{.*?UniverseId\s*=\s*7529591378.*?85576197307056.*?80681221431821.*?106120159518740.*?games/practical_basketball\.lua'
$practicalBasketballCharacter = $practicalBasketballText -match 'workspace:FindFirstChild\("Characters"\)'
$practicalBasketballAero = $practicalBasketballText -match 'AeroRemoteServices' -and $practicalBasketballText -match 'InputService'
$practicalBasketballBallTag = $practicalBasketballText -match 'GetTagged\("Basketballs"\)'
$practicalBasketballSafeRelease = (
    $practicalBasketballText -notmatch 'GetService\("VirtualInputManager"\)|SendKeyEvent|keyrelease' -and
    $practicalBasketballText -notmatch 'hookmetamethod|hookfunction' -and
    $practicalBasketballText -match 'child:GetAttribute\("Active"\)\s*==\s*true' -and
    $practicalBasketballText -match 'serverReleased\s*==\s*false' -and
    $practicalBasketballText -match 'shootInputHeld\(\)'
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
if (-not ($practicalBasketballRouted -and $practicalBasketballCharacter -and $practicalBasketballAero -and $practicalBasketballBallTag -and $practicalBasketballSafeRelease -and $practicalBasketballRailIcons -and $practicalBasketballPages -and $practicalBasketballDribbleChains -and $practicalBasketballAutoSprint -and $practicalBasketballFovLock -and $practicalBasketballFHotkey -and $practicalBasketballCustomPreview -and $practicalBasketballMobileSupport -and $practicalBasketballQuickLaunch)) {
    throw "Practical Basketball routing or Aero adapter contract failed"
}

Write-Host "Luau compile: PASS ($($compileFiles.Count) Lua files)"
Write-Host "Game builder contract: PASS (8/8)"
Write-Host "Persistent flag parity: PASS ($($baselineFlags.Count)/$($baselineFlags.Count))"
Write-Host "Shared Farm Position controls: PASS ($($canonicalPositionFlags.Count)/$($canonicalPositionFlags.Count))"
Write-Host "Blox Fruits category routing: PASS ($($expectedCategories.Count)/$($expectedCategories.Count))"
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
Write-Host "Mob Aura target travel: PASS (shared tween controller)"
Write-Host "Solix Magnet capture retention: PASS (cross-type Mob Aura pile, sticky after entry)"
Write-Host "Solix Magnet damage routing: PASS (normal Aura rotation independent from Double Attack)"
Write-Host "Bid for Anime support: PASS (native auto-farm, semantic navigation icons, no AdminKit)"
Write-Host "Mine a Mountain support: PASS (credited mining/selling, efficient tiering, upgrade-only spending, no admin remotes)"
Write-Host "Practical Basketball support: PASS (native Aero character, safe meter release, rail icons, and ball tag)"
Write-Host "Practical Basketball dribble chains: PASS (guard trigger, hand-aware presets, custom chain, no tutorial completer)"
Write-Host "Practical Basketball Auto Sprint: PASS (tutorial/free-roam support and movement-vector detection)"
Write-Host "Practical Basketball camera FOV: PASS (change listener, late render lock, and clean reset)"
Write-Host "Practical Basketball F hotkey: PASS (optional high-priority chain action with native-input restore)"
Write-Host "Practical Basketball character preview: PASS (custom Aero character resolver)"
Write-Host "Practical Basketball mobile support: PASS (native Shoot Auto Green and floating chain button)"
Write-Host "Practical Basketball Quick Launch: PASS (Shooting, Offense, Defense, Dribble, Visuals)"
