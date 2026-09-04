# Brikyard

A brick-built car collection and racing game for Roblox. Six racers a server,
six personal garages, three shared competitive tracks, and a rarity ladder
from a free starter hatchback up to a handful of Limited cars almost nobody
will ever own.

Full concept blueprint (rarity system, economy, matchmaking, monetization,
growth features) lives outside this repo as a design document; ask the
project owner for the current link.

## Status: Phase 0 — Prototype

What's here right now, per the roadmap's first milestone:

- One drivable car, procedurally built from brick parts (`CarBuilder.lua`)
- One placeholder loop track with four ordered checkpoints (`TrackBuilder.lua`)
- A server-authoritative lap timer — checkpoints must be hit in order, and
  only the server ever decides a lap counted (`GameInit.server.lua`)
- A minimal HUD showing lap count, last lap, and best lap (`LapHud.client.lua`)

Not here yet, by design: no economy, no upgrades, no rarity/gacha, no
matchmaking. Those are later phases.

## Project layout

This is a [Rojo](https://rojo.space) project, so the game lives as plain Lua
files in git and syncs into Roblox Studio rather than as a binary `.rbxl`.

```
default.project.json
src/
  ServerScriptService/
    GameInit.server.lua      -- track build, car spawning, lap logic, drive loop
    Modules/
      CarBuilder.lua         -- builds a car Model from brick parts
      TrackBuilder.lua       -- builds the loop track + checkpoints
  StarterPlayer/
    StarterPlayerScripts/
      LapHud.client.lua      -- lap timer HUD
```

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (or **Play Here**) to test.

## Known rough edges

This prototype was written without a running Studio session to test against,
so a few things are flagged for a first-pass check once it's actually synced
in:

- Steering direction (`GameInit.server.lua`, the `turnRate` sign) may come
  out reversed — flip the sign if so.
- `MAX_FORWARD_SPEED` / `MAX_REVERSE_SPEED` / `MAX_TURN_RATE` are starting
  guesses, not tuned values.
- The loop track is a plain rectangle, not the curved Speed Oval from the
  blueprint — placeholder geometry, swap for real track art later.
- No wrong-way detection — driving a checkpoint gap backwards isn't
  penalized yet.

## Next up: Phase 1

Vertical slice — one personal garage plot, the first competitive track,
three hand-built cars, and the Cash economy going live.
