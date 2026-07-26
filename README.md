# VOR Hub

GitHub-backed source for VOR Hub.

## Audited immutable loader (recommended)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/01c3111d917ef395f207221648ccad985fc6888d/loader.lua"))()
```

This entrypoint and the hub release it loads are both commit-pinned. Future
changes to `main` cannot alter what this exact command executes.

The visible commit SHA is a public identifier, not a GitHub credential. It
cannot grant push access. Only repository accounts explicitly given write or
admin permission can update the original VOR Hub repository.

## Files

- `VOR_HUB.lua` - complete hub source and supported-game router
- `anime_expeditions.lua` - Anime Expeditions integration
- `blox_fruits_dungeons.lua` - Blox Fruits dungeon integration
- `loader.lua` - audited commit-pinned loader
- `update-github.ps1` - copies the parent source files, commits them, and pushes `main`

## Publish an update

Run this from PowerShell after changing any parent hub source file:

```powershell
& ".\codex-hub\update-github.ps1"
```
