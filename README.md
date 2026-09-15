# Frog Pond

*(working title -- rename whenever)*

A 6-player Roblox pond game: catch frogs with a net, kiss them for a random
doll, and build up a passive-income doll collection that other players can
come visit. Full concept discussion (rarity systems, economy, monetization)
happened outside this repo; this file tracks the build itself.

## The concept, in one loop

Swim to the shared island (bigger, faster if you've bought swim-speed
upgrades) -> catch a frog (spotted by its rarity-hinted color/size, tracked
by its croak, sometimes hiding near trees/bushes/rocks) -> kiss it -> get a
random doll (rarity-based) -> doll sits in your display house, earning money
per second based on its rarity -> spend that money on more swim speed ->
repeat. It's a flex/collection game: other players can visit your house and
see your dolls.

**The pond is round-based, not a free-for-all:** the island is open for a
full 5 minutes (a shared 20-frog pool, refilling every 5 minutes), then
every player gets auto-recalled to their house and the island locks for a
10-second reset gap before the next round starts -- so no one player can
permanently camp it, and every round is a fresh race.

**Two independent personal timers** layer rarer frogs on top of that: every
30 minutes (Legendary) and every 60 minutes (Secret Frog), *per player*,
regardless of when other players' timers fire. When any player's timer
hits zero, that rare frog spawns into the *shared* pond -- anyone can catch
it, not just the player whose timer triggered it, which is what keeps
everyone racing even outside their own schedule.

## Status: Phase 0 (pond & island arena) complete

**Phase 0 (this build):**

- A large pond (`PondBuilder.build`) with lily pads, 12 lotus flowers, pond
  rocks, water ripples, and a decorative sailboat
- A central Frog Island with a big sakura tree, 18 path stones ringing it,
  two reed beds, and 6 bush/rock "visibility break" clusters at fixed
  positions (`visibilityBreakPositions` in the returned handle) -- Phase 1's
  frog hide/reveal mechanic hides frogs near these. A single
  `FrogSpawnRegion` marker covers the island for Phase 1's spawner to pick
  positions within, rather than a fixed grid of slots.
- 12 more sakura trees and falling sakura petals around the whole pond,
  plus atmosphere/lighting set up for the scene
- **6 player display houses**, one per player, arranged in a ring and
  **facing the pond** (each has a door, two windows, a roof, a "PLAYER N"
  billboard label, and a `SixDollDisplaySlots` folder with 6 doll slots
  inside -- Phase 3 will actually place dolls in them), assigned to
  players on join and freed on leave (a 7th player gets no house -- 6 is
  the server cap, matching the 6-player lobby design)
- **The island lock barrier**: a single solid Cylinder sized to the
  island's footprint. Its curved side IS the wall all the way around --
  no segmented ring needed, and toggling `CanCollide` locks/unlocks the
  whole island at once.
- **The round timer**: island open for 5 minutes, then every player is
  auto-recalled to their house and the island locks for a 10-second reset
  gap, forever. A `RoundState` RemoteEvent broadcasts `roundOpen`/
  `roundLocked` for a future HUD to listen to.

Not yet built (see the phase list below): actual frogs, the net/catch
interaction, the kiss mechanic, dolls actually sitting in the display
slots, the economy, upgrades, monetization, or any UI.

**A note on where this came from:** the environment (pond, island,
decoration, houses) was originally a standalone world-builder script,
adapted here into `PondBuilder.lua` as a proper Rojo module so it stays
testable and so GameInit can layer the island lock/round timer on top. One
real bug got fixed in the adaptation: the original computed a "face the
pond" rotation for each house (`CFrame.lookAt(...)`) but never actually
applied it, so every house's door/windows would have faced the same fixed
world direction regardless of where it sat on the ring. Fixed by threading
that CFrame through every part of the house instead of using raw
world-space offsets.

## Phase plan

0. **Pond & island arena** -- done, see above.
1. **Frog system** -- spawn real frogs within the island's frog spawn
   region: visible rarity (color/size), an audio cue (croak) so players
   can locate them by ear even when hidden, the hide/reveal-near-cover
   behavior using the 6 visibility-break positions, the shared 5-minute
   pool refill, the two personal timers (30-min Legendary / 60-min
   Secret) firing into the shared pond, and the net tool + catch
   interaction.
2. **Kiss & doll rewards** -- the kiss interaction, a rarity roll tied to
   the frog's rarity, doll inventory. A kiss-timing skill mini-game
   (better timing = better odds) is a candidate addition here.
3. **Player house economy** -- placing dolls into the 6 `DollSlot_N`
   slots already built into each house, $/sec passive income scaled by
   doll rarity, a currency + money HUD. Dolls are decoration + income
   only, no interactivity, by design.
4. **Upgrades** -- swim-speed upgrades (cost curve, speed scaling) as the
   primary money sink, since speed determines who reaches the island (and
   any rare spawn) first each round.
5. **Social & multiplayer polish** -- visiting friends' houses, a trading
   system, leaderboards.
6. **Retention systems** -- daily login streak, a quest board, a season
   pass (free + premium track).
7. **Monetization** -- gamepasses (2x money, extra display slots, VIP
   pond area, faster net/swim), consumable dev products (luck boosts,
   instant cooldown reset, reroll), and cosmetics (net/house skins, kiss
   VFX) -- deliberately *not* selling guaranteed rare dolls/frogs
   directly, to keep it convenience/vanity rather than pay-to-win.
8. **Live-ops** -- server-wide FOMO events (e.g. a rare frog announced to
   the whole server), seasonal ponds/content.

## Project layout

This is a [Rojo](https://rojo.space) project: the game lives as plain Lua
files in git and syncs into Roblox Studio rather than as a binary `.rbxl`.

```
default.project.json
src/
  ServerScriptService/
    GameInit.server.lua      -- builds the world, assigns each player a
                                 house on join, runs the round timer
                                 (5 min open, 10 sec locked reset)
    Modules/
      PondBuilder.lua         -- the whole environment (pond, island,
                                 decoration, 6 player houses), plus the
                                 island lock barrier
tests/
  mock_roblox.lua             -- a hand-built mock of the Roblox API that
                                 actually loads and executes the real
                                 files in src/, not a reimplementation
  game_harness.lua            -- boots GameInit.server.lua under the mock
  luau_compat.lua             -- desugars Luau's += / -= / *= // for
                                 vanilla Lua 5.3 (only src/ files are
                                 desugared -- test files must use plain
                                 `x = x + 1`, since they run directly)
  helpers.lua                 -- tiny assertion library used by every test
  test_pond_builder.lua       -- structural tests for PondBuilder (every
                                 deterministic count/position; the
                                 randomly-scattered decoration -- lily
                                 pads, pond rocks -- isn't asserted exactly
                                 since it's genuinely randomized)
  test_game_smoke.lua         -- boots the real game, drives 6+ players
                                 through house assignment and a full
                                 round-timer open/locked/open cycle
  run_tests.sh                -- runs every tests/test_*.lua file
```

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (or **Play Here** with a few local test players) to see
   the pond, the island, the 6 houses, and the round timer locking/
   unlocking the island every 5 minutes/10 seconds.

## Testing without Studio

There's no Roblox Studio available in the environment this was built in,
so `tests/` is a Lua-level simulation instead: a mock of the Roblox API
that loads and executes the real `src/` files (not a reimplementation) and
drives them through simulated sessions with real assertions. Run it with:

```
./tests/run_tests.sh
```

This proves the deterministic structure/counts and the round-timer/house-
assignment logic are internally consistent -- it does **not** model real
rotation, real physics, or real rendering (see the code comments in
`PondBuilder.lua` around `CFrame.Angles`/`CFrame.lookAt` usage for the
rotation-dependent geometry worth double-checking on first Studio look --
the same class of bug a previous project hit with car wheels, and the
exact class of bug this module's house-facing fix addresses). A real
Studio playtest is still needed to confirm it looks and plays right.

## Known simplifications

- **Pond and island are plain circles**, not a fully hand-sculpted organic
  shoreline. Still has real decoration density (sakura, lotus, reeds,
  rocks) -- what's missing is terrain-level shaping, not dressing.
- **No real swim physics yet.** There's no Terrain water and no custom
  swim controller in this phase -- players just walk to the island like
  normal ground for now. Swim speed as an actual stat, and however
  "swimming" actually feels (Terrain water's built-in buoyancy vs. a
  scripted swim zone), is a Phase 1/4 decision once upgrades exist.
- **Fish aren't in this version.** The pond has lily pads/lotus/ripples
  but no swimming fish yet -- worth adding back in a later pass.
- **Decorative element counts are randomized** (lily pads, pond rocks,
  falling petal positions, small flowers) using `math.random` with no
  fixed seed, so the exact look differs slightly each time the world is
  built. Structural things (house count, doll slot count, path stone
  count, reed count) are fully deterministic.
- **Rotation-dependent geometry is unverified.** The mock can't model
  real rotation math (noted above, under Testing), so every disc's "flat
  face up" orientation and every house's "faces the pond" orientation are
  reasoned through but not visually confirmed -- worth a first look in
  Studio, especially the house-facing fix.
