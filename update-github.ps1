param(
    [string]$Message = "Update VOR Hub $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$git = "C:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path -LiteralPath $git)) {
    $git = (Get-Command git -ErrorAction Stop).Source
}

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & $git -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

$validator = Join-Path $repo "scripts\validate-refactor.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator
if ($LASTEXITCODE -ne 0) {
    throw "Modular validation failed. Nothing was published."
}

$modulePaths = @(
    "core",
    "games",
    "scripts",
    "MODULAR_REFACTOR_REPORT.md",
    "update-github.ps1"
)
Invoke-Git add -- @modulePaths
& $git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    Invoke-Git diff --cached --check
    Invoke-Git commit -m "$Message - modules"
} elseif ($LASTEXITCODE -ne 0) {
    throw "Could not inspect staged module changes"
}
$moduleCommit = (& $git -C $repo rev-parse HEAD).Trim()

$loaderPath = Join-Path $repo "loader.lua"
$loader = Get-Content -LiteralPath $loaderPath -Raw
$loader = [regex]::Replace(
    $loader,
    'local COMMIT = "(?:__VOR_MODULE_COMMIT__|[0-9a-f]{40})"',
    'local COMMIT = "' + $moduleCommit + '"',
    1
)
Write-Utf8NoBom -Path $loaderPath -Text $loader
Invoke-Git add -- "loader.lua"
& $git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    Invoke-Git diff --cached --check
    Invoke-Git commit -m "$Message - pin loader"
} elseif ($LASTEXITCODE -ne 0) {
    throw "Could not inspect loader pin"
}
$loaderCommit = (& $git -C $repo rev-parse HEAD).Trim()

$bootstrap = @"
-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "$loaderCommit"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()
"@
Write-Utf8NoBom -Path (Join-Path $repo "VOR_HUB.lua") -Text $bootstrap

$readmePath = Join-Path $repo "README.md"
$readme = Get-Content -LiteralPath $readmePath -Raw
$readme = [regex]::Replace(
    $readme,
    'https://raw\.githubusercontent\.com/swatdiaz/VOR-HUB/[0-9a-f]{40}/loader\.lua',
    "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/$loaderCommit/loader.lua"
)
Write-Utf8NoBom -Path $readmePath -Text $readme

Invoke-Git add -- "VOR_HUB.lua" "README.md"
& $git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    Invoke-Git diff --cached --check
    Invoke-Git commit -m "$Message - publish bootstrap"
} elseif ($LASTEXITCODE -ne 0) {
    throw "Could not inspect compatibility bootstrap"
}

Invoke-Git push origin main
Write-Host "Published immutable loader: https://raw.githubusercontent.com/swatdiaz/VOR-HUB/$loaderCommit/loader.lua"
