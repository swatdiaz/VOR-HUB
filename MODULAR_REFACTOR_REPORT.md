# VOR Hub Modular Refactor Report

Baseline audited: `59547d8286ec2e130e9733cfddac3725b5875dbb` (`VOR_HUB.lua`, 18,247 lines).

## Source transfer map

| Original source | Modular destination | Notes |
| --- | --- | --- |
| `VOR_HUB.lua:1-5254` | `core/settings.lua`, `core/utilities.lua`, `core/ui.lua`, `core/profiles.lua`, `core/access.lua` | Shared registry, services, cleanup, luxury UI, profiles, access gate, intro, notifications, and appearance state were rebuilt behind context contracts. |
| MM2 adapter | `games/murder_mystery_2.lua` | Native role, combat, farm, movement, ESP, world, and server utilities. |
| Iron Man: Reimagined adapter | `games/iron_man_reimagined.lua` | Native suit selection/actions, flight and weapon input, conditional repair/flares, aim assist, ESP, and live suit telemetry. |
| Sniper Arena adapter | `games/sniper_arena.lua` | Native shot-path silent aim, visible aim assist, enemy ESP, server-checked kill unlocks, owned loadouts, ready reward claims, matchmaking, and live progression telemetry. |
| Dog Race adapter | `games/dog_race.lua` | One-click full progression; credited treadmill/race cycling; persistent single/triple auto hatching; timed online gifts and free pet eggs; automatic achievements and task rewards; fruit, trail, bone-upgrade, gear-crate, dog, and partner progression; best-pet/gear loadouts; rebirths; cleanup; and live gate telemetry. |
| `VOR_HUB.lua:8903-10566` | `games/mypark.lua` | Complete MyPark / Basketball builder. |
| `VOR_HUB.lua:10568-10596` plus legacy adapter | `games/anime_expeditions.lua` | Monolith wrapper removed; the complete isolated adapter is now selected directly. |
| `VOR_HUB.lua:10598-10625` plus legacy adapter | `games/blox_fruits_dungeons.lua` | Monolith wrapper removed; the complete isolated dungeon adapter is now selected directly. |
| `VOR_HUB.lua:10627-17189` | `games/blox_fruits.lua` | Complete Blox Fruits builder, split into nested functional scopes to stay below the register limit. |
| `VOR_HUB.lua:17244-17958` | `games/blox_fruits.lua` | Blox Fruits cosmetics (Void Kitsune, name mask, float, and Void Dark Blade V3) moved out of global settings and into the Blox module. |
| `VOR_HUB.lua:17191-17235` | `loader.lua` | Unsupported-game routing now avoids downloading any game module and shows PlaceId plus UniverseId. |
| `VOR_HUB.lua:17238-18247` | `core/profiles.lua`, `core/access.lua`, `core/ui.lua` | Global settings, saved flags, auto-load, access, appearance, and intro behavior moved to shared modules. |

## Routing guarantees

- `loader.lua` resolves one game path from `game.GameId` and `game.PlaceId`.
- Only the selected game module is downloaded and compiled.
- Every source download, compile, module return, and builder call is protected by `xpcall`.
- A game build failure opens a visible `Build Error` page with the full traceback.
- An unsupported place loads no game module and displays `Game not supported`, `PlaceId`, and `UniverseId`.
- The release loader uses a full immutable Git commit, never `main` and never a GitHub token.

## Blox Fruits shared Farm Position Controller

One controller on the Farming page owns:

- Position X
- Position Y / Height
- Position Z
- Random Orbit
- Orbit Radius
- Orbit Speed
- Random Square
- Square Size
- Square Step Delay

The same runtime state drives Auto Level, boss farming, raid farming, nearest Mob Aura, selected-mob farming, and spawn waiting. Existing `blox_mob_aura_*` and `blox_farm_height` profile keys remain accepted through aliases in `core/settings.lua`; no old profile requires conversion.

## Validation

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\validate-refactor.ps1"
```

Expected checks:

- Luau compile: 15/15 repository Lua files
- Game builder contract: 5/5
- Persistent flag parity: 151/151
- Shared Farm Position controls: 9/9, with no duplicate control flags

The analyzer's remaining unknown globals are Roblox/executor APIs such as `game`, `workspace`, `CFrame`, `Drawing`, and `getgenv`; no unresolved helper from the old monolith remains.
