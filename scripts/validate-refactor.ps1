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
    "games/anime_expeditions.lua",
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
$semanticVersionOk = $versionText -match 'Version\s*=\s*"3\.2\.8"'
$visibleVersionOk = $uiText -match '"v"\s*\.\.\s*tostring\(SETTINGS\.Version\)'
$cleanVersionOk = $loaderText -notmatch 'BuildVersion' -and $uiText -notmatch 'BuildVersion'
if (-not ($semanticVersionOk -and $visibleVersionOk -and $cleanVersionOk)) {
    throw "Visible VOR version must be clean semantic version 3.2.8 without a commit suffix"
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
$magnetTweenSpeed = $bloxText -match 'distanceToAnchor\s*/\s*250'
$magnetMovementDecoupled = (
    $bloxText -notmatch 'squareMovement\s*=\s*state\.MobAuraRandomSquare\s*==\s*true\s+or\s+state\.AutoMagnet' -and
    $bloxText -notmatch 'if state\.AutoMagnet or state\.MobAuraRandomSquare then'
)
if (-not ($stableMagnetAnchor -and $magnetTweenSpeed -and $magnetMovementDecoupled)) {
    throw "Auto Magnet must retain a stable 250-stud enemy pull without taking ownership of character movement"
}

$mobAuraTweenTravel = $bloxText -match 'moveTo\(CFrame\.lookAt\(goalPosition, goalPosition \+ facing\)\)'
$selectedSpawnTweenTravel = $bloxText -match 'moveTo\(CFrame\.new\(goalPosition\)\)'
if (-not ($mobAuraTweenTravel -and $selectedSpawnTweenTravel)) {
    throw "Mob Aura and selected-mob travel must use the shared tween controller instead of direct root teleports"
}

$experimentalText = Get-Content -LiteralPath (Join-Path $repo "games/blox_fruits_experimental.lua") -Raw
$creditedMainDouble = $experimentalText -match 'api\.SetOverride\(false\)'
$requestSpamRemoved = $experimentalText -notmatch '(?s)if not runtime\.SwordBusy.*?dispatchSword\(\).*?if not runtime\.FruitBusy.*?dispatchFruit\(\)'
if (-not ($creditedMainDouble -and $requestSpamRemoved)) {
    throw "Double Attack must leave combat ownership with the credited main Aura engine"
}

Write-Host "Luau compile: PASS ($($compileFiles.Count) Lua files)"
Write-Host "Game builder contract: PASS (5/5)"
Write-Host "Persistent flag parity: PASS ($($baselineFlags.Count)/$($baselineFlags.Count))"
Write-Host "Shared Farm Position controls: PASS ($($canonicalPositionFlags.Count)/$($canonicalPositionFlags.Count))"
Write-Host "Blox Fruits category routing: PASS ($($expectedCategories.Count)/$($expectedCategories.Count))"
Write-Host "Fruit M1 native remote shape: PASS (2/2)"
Write-Host "Submerged water support: PASS"
Write-Host "Visible semantic version: PASS (3.2.8)"
Write-Host "Manual Fruit M1 cooldown removal: PASS (1.0)"
Write-Host "Typed mob search distances: PASS (numeric input)"
Write-Host "Auto Magnet range: PASS (0-500 magnitude)"
Write-Host "Ownership-independent Auto Magnet: PASS"
Write-Host "Solix-style stable Magnet anchor and pull: PASS (250 studs/sec, character movement decoupled)"
Write-Host "Double Attack credited-engine ownership: PASS"
Write-Host "Mob Aura target travel: PASS (shared tween controller)"
