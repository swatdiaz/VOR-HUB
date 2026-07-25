# VOR Hub

GitHub-backed source for VOR Hub.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/VOR_HUB.lua"))()
```

The loader URL stays the same when `VOR_HUB.lua` is updated on the `main` branch.

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
