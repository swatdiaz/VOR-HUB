# VOR Hub

GitHub-backed source for VOR Hub.

## Stable loader (recommended)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/VOR_HUB.lua"))()
```

This command stays the same across releases. `VOR_HUB.lua` follows the latest
reviewed loader commit published by the release script, so newly supported
games do not require users to replace their loadstring.

## Current immutable loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/330e281f330944f4036ff2cd509618e63ac8ce55/loader.lua"))()
```

Use this only when you intentionally want the current release frozen forever.
Commit-pinned URLs are immutable and will never gain support for games added in
later commits.

The visible commit SHA is a public identifier, not a GitHub credential. It
cannot grant push access. Only repository accounts explicitly given write or
admin permission can update the original VOR Hub repository.

## Files

- `loader.lua` - small immutable game router; it compiles only the detected game module
- `core/` - shared luxury UI, settings, profiles, access gate, and utilities
- `games/` - isolated Grow a Garden 2, Capybaras VS Plants, Murder Mystery 2, MyPark, Practical Basketball, Anime Expeditions, Bid for Anime, Mine a Mountain, Bee Swarm Simulator, Gunfight Arena, Sniper Arena, Iron Man: Reimagined, Dog Race, Dragon Ball Legendary Powers, Blox Fruits, and Dungeon builders
- Sniper Arena includes native shot-path silent aim, cursor aimbot, triggerbot, adjustable enemy-head hitboxes, optional minimal enemy ESP, server-checked sniper unlock progression, best-owned loadouts, ready reward claims, and matchmaking controls.
- Dog Race includes guided AFK progression, smart/manual egg targeting, fruit/trail/bone shops, birds, race-earned bone shoes, dog and partner unlocks, race/training automation, movement, rewards, and live currency/rebirth/Robux gates.
- `VOR_HUB.lua` - compatibility bootstrap pinned to the audited loader
- `scripts/validate-refactor.ps1` - Luau/register/flag/controller validation
- `update-github.ps1` - validates, creates the module and loader commits, updates the bootstrap, then pushes
- `MODULAR_REFACTOR_REPORT.md` - source-line transfer and parity report

## Publish an update

Run this from PowerShell after changing the modular source:

```powershell
& ".\codex-hub\update-github.ps1"
```
