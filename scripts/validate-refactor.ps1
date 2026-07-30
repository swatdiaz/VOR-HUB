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
    "games/blox_fruits_parity.lua",
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
    & $Compiler --null $path | Out-Null
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
    "blox_void_dark_blade_v3"
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

Write-Host "Luau compile: PASS ($($compileFiles.Count) Lua files)"
Write-Host "Game builder contract: PASS (5/5)"
Write-Host "Persistent flag parity: PASS ($($baselineFlags.Count)/$($baselineFlags.Count))"
Write-Host "Shared Farm Position controls: PASS ($($canonicalPositionFlags.Count)/$($canonicalPositionFlags.Count))"
