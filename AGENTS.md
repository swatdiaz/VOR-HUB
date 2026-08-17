# VOR Hub Contributor Rules

These instructions apply to the entire repository. They are the default contract
for AI agents and human contributors working on VOR Hub.

## Mission

Contributors may:

- add support for a new game;
- update an existing game integration;
- fix a confirmed bug;
- add or repair game-specific controls using the existing VOR Hub UI APIs.

Do the smallest targeted change that satisfies the request. Do not perform an
unrequested redesign, framework replacement, broad cleanup, file shuffle, or
monolith rewrite.

## Mental model: framework plus game plugins

VOR Hub is a shared framework and a registry of isolated game plugins:

```text
loader.lua
  -> core/settings.lua identifies the current UniverseId/PlaceId
  -> core/* creates the shared UI, profiles, access, and utilities
  -> exactly one matching games/*.lua builder is downloaded and executed
```

The repository can support many games because it does **not** load every game at
startup. Preserve that property. A feature or bug belonging to one game belongs
in that game's module, not in the loader or global UI.

Game-module work is normal contributor work and does not require special owner
approval when it stays within the existing contracts. A contributor may:

- diagnose and fix behavior inside the supported game's module;
- add local functions, state, cleanup, pages, sections, and controls for that game;
- update remotes, object discovery, values, routes, and compatibility checks for
  that game;
- split an oversized game into game-specific helper modules loaded through
  `context.LoadModule`, while keeping the public builder contract unchanged;
- add a new isolated game plugin and its registry/validator entries.

Do not solve a game bug by changing the shared UI framework. First trace the bug
to its owning `games/*.lua` module and fix it there. Escalate to the owner only
when the evidence proves the defect is actually shared across games or requires a
protected core change.

## Protected architecture

The shared shell is already refactored. Treat these as protected files:

- `core/ui.lua`
- `core/profiles.lua`
- `core/access.lua`
- `core/utilities.lua`
- `loader.lua`
- `update-github.ps1`

Do not change the global visual language, navigation, window geometry, branding,
intro, access gate, theme system, profile system, minimize behavior, notifications,
or loader architecture unless the repository owner explicitly requests that exact
core change.

`core/settings.lua` may be edited only to register a verified game, add a required
backward-compatible flag alias, or make an explicitly requested settings change.
Do not rename or remove existing game records or profile flags casually.

## Adding a supported game

1. Verify the exact Roblox `UniverseId` (`game.GameId`) and every supported
   `PlaceId`. Do not guess identity from a title, screenshot, or similar copy.
2. Create one isolated module at `games/<game_slug>.lua`.
3. The module must begin with the standard contract and return exactly one builder:

   ```lua
   return function(context)
       local Window = assert(context.Window, "Game Name: Window is required")
       local createCategoryHomePage = assert(
           context.CreateCategoryHomePage,
           "Game Name: category builder is required"
       )
       local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
       local COLORS = context.Colors or context.COLORS or {}
       local track = context.Track or function(connection)
           return connection
       end
       local gui = context.Gui

       -- Build this game's pages and runtime here.
   end
   ```

4. Register the game in `core/settings.lua` with `Key`, `DisplayName`,
   `UniverseId`, `RootPlaceId`, `PlaceIds`, and `Module`.
5. Add the new module path to `$required` in
   `scripts/validate-refactor.ps1` so it is compiled and contract-checked.
6. Update `README.md` and `MODULAR_REFACTOR_REPORT.md` only where the supported
   game list or architecture map genuinely changed.

Never paste a second UI library into a game module. Never make the loader download
every game. The loader must resolve the current game and compile only its selected
module.

## Fixing or extending an existing game

1. Start in the registered `games/*.lua` module for that game.
2. Reproduce or trace the bug before editing. Identify the failing function,
   remote/object path, state transition, or cleanup path.
3. Keep new functions local to that module unless they are game-specific helper
   modules loaded through `context.LoadModule`.
4. Preserve existing control names, categories, flags, defaults, and saved-profile
   behavior unless the requested fix explicitly changes them.
5. Capability-check changed remotes and objects so a missing round/map/player
   object produces a useful status instead of killing the whole UI.
6. Test the changed feature plus toggle-off, reload, respawn, and any relevant
   round/map transition.
7. Do not touch unrelated games just because their code looks similar.

## UI contract

- Build game navigation through `context.CreateCategoryHomePage()`.
- Build sections and controls through the existing `Window`, page, and section
  methods. Follow a nearby game module as the style reference.
- Use `context.Colors`/`context.COLORS`, `context.CategoryDecals`, notifications,
  and existing control types. Do not hard-code a competing theme.
- Keep category names, page ordering, left/right section placement, control names,
  ranges, defaults, and status labels deliberate and readable.
- Give every persistent control a unique, stable, game-prefixed `Flag`, such as
  `<slug>_auto_farm`. Never reuse another game's flag.
- Do not rename an existing flag. When a rename is unavoidable, preserve the old
  key through `SETTINGS.FlagAliases` in `core/settings.lua` and verify old profiles
  still load.
- Do not create duplicate controls for one persistent flag.
- Do not edit `core/ui.lua` merely to make one game fit. Adapt the game module to
  the existing UI contract.

## Runtime and cleanup contract

- Capability-check game objects, remotes, modules, and executor APIs before use.
- Keep feature state inside the game module. Avoid new shared globals.
- Every toggle must be idempotent: enabling twice must not duplicate loops,
  connections, drawings, hooks, or instances.
- Track connections with `context.Track` where appropriate and provide explicit
  cleanup for loops, drawings, temporary instances, hooks, camera changes,
  lighting changes, movement changes, and synthetic inputs.
- On reload, disable the previous module instance before creating a new one.
- On toggle-off or unload, restore the exact native values captured before the
  feature changed them.
- Do not claim that a UI label proves a feature works. Verify the actual engine
  value or observable game state.
- Keep public-game work read-only unless ownership or server authorization is
  verified. Runtime validation belongs in an owned or explicitly authorized test
  environment.

## Compatibility and security

- Preserve ordinary Roblox/executor compatibility patterns already used by the
  loader, including Xeno fallbacks. Do not make one executor mandatory without an
  explicit requirement.
- Do not add GitHub tokens, Discord tokens, webhooks, keys, cookies, passwords, or
  local machine paths to source control.
- Do not add mutable third-party `loadstring` URLs or hidden remote payloads.
- Release URLs must remain pinned to full 40-character reviewed Git commit SHAs.
- Do not weaken error handling, `xpcall` boundaries, build-error pages, or the
  unsupported-game page.

## Required validation

Before describing work as complete, run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\validate-refactor.ps1"
git diff --check
```

Also inspect the diff and perform focused tests for the changed game:

- the correct `UniverseId`/`PlaceId` routes to the correct module;
- unsupported games remain unsupported and download no game module;
- pages and controls appear once and in the intended categories;
- saved flags restore correctly;
- toggles change the intended runtime behavior;
- toggle-off, reload, respawn, teleport failure, and unload clean up safely;
- native camera, lighting, movement, and input state are restored.

Static compilation is necessary but is not runtime proof. Report exactly what was
tested and what remains unverified.

## Git and publishing

- Work on a feature branch and open a pull request. Do not rewrite history or
  force-push shared branches.
- Keep commits scoped to one game or one confirmed fix. Do not mix unrelated
  formatting churn with functional changes.
- Never edit the pinned commit in `loader.lua`, `VOR_HUB.lua`, or `README.md` by
  hand.
- Contributors should stop after a validated pull request unless the owner
  explicitly authorizes a release.
- From a clean, reviewed `main`, publish only with:

  ```powershell
  .\update-github.ps1 -Message "Describe the reviewed update"
  ```

  That script validates the repository, commits the modules, pins the loader to
  the module commit, updates the compatibility bootstrap and README, and pushes
  the reviewed immutable release.

## Stop conditions

Stop and ask the owner before:

- modifying the protected core/UI/loader files;
- changing branding, layout, theme, access, profiles, or publishing behavior;
- deleting or renaming controls, flags, pages, or supported games;
- adding a dependency or remote code source;
- expanding a narrow bug fix into an architectural refactor;
- publishing a release.

When uncertain, preserve the existing architecture and make the smaller change.
