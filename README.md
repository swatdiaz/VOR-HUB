# VOR Hub

GitHub-backed source for VOR Hub.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/loader.lua"))()
```

`loader.lua` resolves the latest `main` commit and then downloads the immutable
commit-pinned `VOR_HUB.lua`, avoiding Roblox/GitHub's stale branch-file cache.

## Files

- `VOR_HUB.lua` - complete hub source and supported-game router
- `anime_expeditions.lua` - Anime Expeditions integration
- `blox_fruits.lua` - Blox Fruits live legacy-runtime adapter
- `loader.lua` - stable one-line loader
- `update-github.ps1` - copies the parent source files, commits them, and pushes `main`

## Publish an update

Run this from PowerShell after changing any parent hub source file:

```powershell
& ".\codex-hub\update-github.ps1"
```
