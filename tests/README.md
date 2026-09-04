# Tests

Since there's no Roblox Studio available to actually playtest in, this is
the next best thing: a hand-built Roblox API mock (`mock_roblox.lua`) that
lets plain Lua 5.3 actually *load and execute* the game's real source files
-- not a copy, not a reimplementation, the exact files in `src/` -- and
drive them through simulated multiplayer scenarios with real assertions on
the outcome.

## What this proves

- **Pure logic is genuinely correct**, not just syntactically valid:
  `UpgradeCatalog`'s cost curve and +20% ceiling, `CrateService`'s odds
  (checked via a 20,000-pull empirical distribution) and pity boundary.
- **Geometry math is right**: `TrackBuilder`'s checkpoints are numbered
  1-4 with no gaps or duplicates, non-solid, correctly offset by track
  size; `CarBuilder` produces a car with the right attributes, seat, and
  wheel count.
- **Persistence round-trips correctly**, including the schema-migration
  path for a profile saved before a field (like `GarageSlots`) existed.
- **The actual server orchestration behaves correctly end to end**: a
  full `GameInit.server.lua` boot, multiple simulated players joining,
  driving laps, buying cars, hitting the garage cap, upgrading, pulling
  crates, and queuing into matchmaking heats with correct placement-based
  payouts -- against the real remotes, the real validation, the real
  reward math.

This process already found and fixed two real bugs this way: `PurchaseCar`
never checked a car was actually shop-sourced (a crate-exclusive car ID
would have hit a `nil` price comparison), and a missing `table.find`
Luau-ism the mock needed to add support for.

## What this does NOT prove

This is a logic simulation, not Roblox. It does not model real physics,
real rendering, real networking/replication, or real player input --
`CFrame` rotation isn't modeled (only position and a straight-line
`LookVector`), `WeldConstraint`s don't actually hold parts together, and
nothing here can tell you if the car *feels* good to drive, if the UI
panels overlap on screen, or if steering direction is actually correct
(that one's flagged as a known rough edge in the main README precisely
*because* it can't be checked this way). A passing test suite here is a
strong signal the logic is sound; it is not a substitute for an actual
Studio playtest.

Client-side scripts (`*.client.lua`) aren't exercised here -- they're
straightforward UI wiring against the same remotes the server tests
already prove work, and meaningfully simulating a client (PlayerGui,
LocalPlayer, an actual UI framework) wasn't judged worth the added mock
complexity versus just syntax-checking them.

## Running the tests

Requires `lua5.3` (or point `LUA=` at another Lua 5.3 interpreter).

```
./tests/run_tests.sh
```

Each test file runs as its own process -- `mock_roblox.lua`'s `workspace`
and `ReplicatedStorage` are process-wide singletons, so a single process
can only safely `game_harness.boot()` once (see the comment on `boot()`).

## Layout

```
helpers.lua              -- tiny assertion helpers (assertEqual, assertNear, ...)
luau_compat.lua           -- lets plain Lua 5.3 load the game's Luau source
                              (desugars += -= *= /=, the only Luau syntax used here)
mock_roblox.lua            -- the Roblox API mock: Instance, Vector3, CFrame,
                              Signal, task scheduling, DataStoreService, etc.
game_harness.lua           -- boots GameInit.server.lua under the mock and
                              exposes its remotes/module handles to a test

test_upgrade_catalog.lua   -- pure logic, no mocking needed
test_crate_service.lua     -- pure logic, no mocking needed
test_track_builder.lua     -- geometry, via the mock
test_car_builder.lua       -- car construction, via the mock
test_player_profile.lua    -- persistence + schema migration, via the mock
test_game_smoke.lua        -- smallest full-boot sanity check
test_game_shop.lua         -- car shop + garage slot cap
test_game_upgrades.lua     -- upgrade tree, incl. live stat application
test_game_crates.lua       -- crate disclosure, currency checks, duplicates
test_game_matchmaking.lua  -- full heat, grace-timeout heat, payouts, DNF
```
