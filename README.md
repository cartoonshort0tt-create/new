# Frog Game

Rojo project for a 6-player Roblox pond game: catch frogs on the central
island, kiss them for a random doll, and build up a collection back at
your own player base. This build is the environment pass -- a large
swimmable pond (real Roblox Terrain water, not a flat part) with a central
island, a torii-gated bridge, six colored player bases, gardens, lanterns,
koi, and a frog statue/emblem, laid out to match the reference concept art.

## Current build

Four scripts run in sequence (each waits for the previous one's output
before touching it, so it doesn't matter which order Roblox actually
starts them in):

1. **V13 -- Complete Reference**: builds everything from scratch --
   terrain pond and land, the outer stone promenade, the central island
   with shore rocks and paths, sakura trees, dense grass/bush/flower
   fields, the six player bases (each with its own color, doll slots, and
   SpawnLocation), the frog emblem plaza, the main bridge to the island,
   lily pads/lotus, animated fish, docks and boats, and a frog statue.
2. **V14 -- Fix**: removes any leftover default baseplate/floor geometry,
   restores the terrain water's color/waves, assigns each joining player
   their own base (see "Bug fixed" below), and nudges the island and
   decoration layers to sit flush with the water.
3. **V15 -- Beautification**: adds a Japanese-garden pass on top -- a
   fountain/frog shrine, a torii gate at the bridge entrance, lanterns,
   benches, mushrooms, bamboo, flower beds, and pond-edge detail.
4. **V17 -- Decoration Expansion**: a second landmark (a larger frog
   statue plaza), sakura arches, a garden gazebo, more lily pads and koi,
   paper lanterns, signposts, and ambient fireflies.

## Bug fixed

V14 originally force-teleported **every** joining player to the same
`Spawn_1`, regardless of which of the six bases Roblox's own random
SpawnLocation pick had used -- so all 6 players would end up piled on top
of each other at one base, and the other five would always sit empty no
matter how many players joined. Fixed by assigning each player their own
base index on join (freed when they leave, so the next joiner reuses it),
and moving them to their own `Spawn_N` instead of a hardcoded one.

## Not in this repo

The zip this was built from also contained several earlier draft
environment scripts (`V6` through `V12`, `V8_OuterPath`,
`V10_OuterPath_Expanded`, and an original `v5` labeled
`FrogGameServer.server.lua`) that V13 superseded. They weren't wired into
`default.project.json` there either, so they were left out here to keep
the repo to what actually runs.

## Not built yet

Frog spawning, movement, net catching, the kiss interaction, frog-to-doll
rolling, the round/reset loop, currency/economy, and any UI. This repo is
the environment only.

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play**. The four scripts generate the pond and island into
   Workspace on their own -- there's nothing to place by hand.

Since this uses real Terrain water instead of a flat part, give it a
second or two after Play for the terrain to fill in before judging how it
looks.

## Known rough edges

- No Lua-level test suite for this build. The previous approach in this
  repo's history (a hand-built mock of the Roblox API to test game logic
  without Studio) doesn't cover what these scripts actually need to be
  checked against -- real Terrain water, real lighting/atmosphere, real
  part placement at a glance -- so verifying this is a Studio-only task
  for now.
- The four scripts coordinate via `WaitForChild` rather than an explicit
  single entry point, which works but means a typo in an instance name in
  any of them fails silently (the waiting script just times out). If
  something doesn't appear, check the Output window for a `warn(...)`
  from V15 or V17 first.
