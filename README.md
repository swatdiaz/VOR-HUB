# VOR Hub

GitHub-backed source for VOR Hub.

## Audited immutable loader (recommended)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/7e66b01c1dc607b141841b325c8fe9d75e05a68c/loader.lua"))()
```

This entrypoint and the hub release it loads are both commit-pinned. Future
changes to `main` cannot alter what this exact command executes.

The visible commit SHA is a public identifier, not a GitHub credential. It
cannot grant push access. Only repository accounts explicitly given write or
admin permission can update the original VOR Hub repository.

## Files

- `loader.lua` - small immutable game router; it compiles only the detected game module
- `core/` - shared luxury UI, settings, profiles, access gate, and utilities
- `games/` - isolated Revive, MyPark, Practical Basketball, Anime Expeditions, Bid for Anime, Mine a Mountain, Blox Fruits, and Dungeon builders
- `VOR_HUB.lua` - compatibility bootstrap pinned to the audited loader
- `scripts/validate-refactor.ps1` - Luau/register/flag/controller validation
- `update-github.ps1` - validates, creates the module and loader commits, updates the bootstrap, then pushes
- `MODULAR_REFACTOR_REPORT.md` - source-line transfer and parity report

## Publish an update

Run this from PowerShell after changing the modular source:

```powershell
& ".\codex-hub\update-github.ps1"
```
