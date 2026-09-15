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
random doll (rarity-based) -> doll sits in your 1-floor display building,
earning money per second based on its rarity -> spend that money on more
swim speed -> repeat. It's a flex/collection game: other players can visit
your building and see your dolls.

**The pond is round-based, not a free-for-all:** the island is open for a
full 5 minutes (a shared 20-frog pool, refilling every 5 minutes), then
every player gets auto-recalled to their dock and the island locks for a
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

- A big circular pond (`PondBuilder.buildPond`) with lotus pads/blooms,
  water plants, and fish scattered around it
- A big central island (`PondBuilder.buildIsland`) with a tree cluster,
  3 reed-bed hiding clumps, rocky paths, and **20 reserved frog spawn
  points** -- half tagged `HasCover = true` (near trees/reeds/rocks, for
  the later hide/reveal mechanic), half in the open. No frogs occupy them
  yet -- that's Phase 1.
- **6 evenly-spaced player docks** around the shore, each facing the pond
  center, assigned to players on join and freed on leave (a 7th player
  gets no dock -- 6 is the server cap, matching the 6-player lobby design)
- **The island lock barrier**: a single solid Cylinder sized to the
  island's footprint. Its curved side IS the wall all the way around --
  no segmented ring needed, and toggling `CanCollide` locks/unlocks the
  whole island at once.
- **The round timer**: island open for 5 minutes, then every player is
  auto-recalled to their dock and the island locks for a 10-second reset
  gap, forever. A `RoundState` RemoteEvent broadcasts `roundOpen`/
  `roundLocked` for a future HUD to listen to.

Not yet built (see the phase list below): actual frogs, the net/catch
interaction, the kiss mechanic, dolls, the display building, the economy,
upgrades, monetization, or any UI.

## Phase plan

0. **Pond & island arena** -- done, see above.
1. **Frog system** -- fill the 20 spawn points with real frogs: visible
   rarity (color/size), an audio cue (croak) so players can locate them by
   ear even when hidden, the hide/reveal-near-cover behavior on the
   `HasCover` markers, the shared 5-minute pool refill, the two personal
   timers (30-min Legendary / 60-min Secret) firing into the shared pond,
   and the net tool + catch interaction.
2. **Kiss & doll rewards** -- the kiss interaction, a rarity roll tied to
   the frog's rarity, doll inventory. A kiss-timing skill mini-game
   (better timing = better odds) is a candidate addition here.
3. **Player building & economy** -- a 1-floor display building per player
   (visitable by others), doll placement, $/sec passive income scaled by
   doll rarity, a currency + money HUD. Dolls are decoration + income
   only, no interactivity, by design.
4. **Upgrades** -- swim-speed upgrades (cost curve, speed scaling) as the
   primary money sink, since speed determines who reaches the island (and
   any rare spawn) first each round.
5. **Social & multiplayer polish** -- visiting friends' buildings, a
   trading system, leaderboards.
6. **Retention systems** -- daily login streak, a quest board, a season
   pass (free + premium track).
7. **Monetization** -- gamepasses (2x money, extra display slots, VIP
   pond area, faster net/swim), consumable dev products (luck boosts,
   instant cooldown reset, reroll), and cosmetics (net/building skins,
   kiss VFX) -- deliberately *not* selling guaranteed rare dolls/frogs
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
    GameInit.server.lua      -- builds the pond/island/docks/barrier,
                                 assigns docks on join, runs the round
                                 timer (5 min open, 10 sec locked reset)
    Modules/
      PondBuilder.lua         -- pond, island, spawn-point markers,
                                 island lock barrier, and dock geometry
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
  test_pond_builder.lua       -- geometry/attribute tests for PondBuilder
  test_game_smoke.lua         -- boots the real game, drives 6+ players
                                 through dock assignment and a full
                                 round-timer open/locked/open cycle
  run_tests.sh                -- runs every tests/test_*.lua file
```

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (or **Play Here** with a few local test players) to see
   the pond, the island, the 6 docks, and the round timer locking/
   unlocking the island every 5 minutes/10 seconds.

## Testing without Studio

There's no Roblox Studio available in the environment this was built in,
so `tests/` is a Lua-level simulation instead: a mock of the Roblox API
that loads and executes the real `src/` files (not a reimplementation) and
drives them through simulated sessions with real assertions. Run it with:

```
./tests/run_tests.sh
```

This proves the geometry math and the round-timer/dock-assignment logic
are internally consistent -- it does **not** model real rotation, real
physics, or real rendering (see the code comment above `addDisc` in
`PondBuilder.lua` for the one rotation-dependent piece of geometry worth
double-checking on first Studio look, the same class of bug a previous
project hit with car wheels). A real Studio playtest is still needed to
confirm it looks and plays right.

## Known simplifications

- **Pond and island are plain circles**, not the organic/curved shape a
  real art pass would give them. Proves the layout and the round
  mechanic; real shaping is later scope.
- **No real swim physics yet.** There's no Terrain water and no custom
  swim controller in this phase -- players just walk to the island like
  normal ground for now. Swim speed as an actual stat, and however
  "swimming" actually feels (Terrain water's built-in buoyancy vs. a
  scripted swim zone), is a Phase 1/4 decision once upgrades exist.
- **Fish are static**, not animated/swimming yet.
- **The lock barrier's rotation is unverified.** The mock can't model
  real rotation math (noted above, under Testing), so the barrier/water/
  island discs' "flat face up" orientation is reasoned through but not
  visually confirmed -- worth a first look in Studio.
