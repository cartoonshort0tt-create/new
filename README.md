# Brikyard

A brick-built car collection and racing game for Roblox. Six racers a server,
six personal garages, three shared competitive tracks, and a rarity ladder
from a free starter hatchback up to a handful of Limited cars almost nobody
will ever own.

Full concept blueprint (rarity system, economy, matchmaking, monetization,
growth features) lives outside this repo as a design document; ask the
project owner for the current link.

## Status: Phase 0 and Phase 1 done, Phase 2 (alpha) mostly in

**Phase 0 (prototype):** one drivable car, one placeholder loop track,
server-authoritative lap timing.

**Phase 1 (vertical slice):**

- Cash economy: 25 Cash/practice lap, 60 Cash/competitive lap, awarded and
  tracked server-side only, persisted to DataStore (`PlayerProfile.lua`)
- Six personal garage plots — each player gets their own copy of the loop
  track, positioned far enough apart to never overlap, assigned on join
- One shared competitive track ("Speed Oval"), open to all players
- Three purchasable Common-tier cars plus a shop UI (`ShopUI.client.lua`)

**Phase 2 (alpha), so far:**

- Full five-branch upgrade tree (Engine/Tires/Nitro/Handling/Chassis, 8
  levels each, Cash-only, cost doubles every two levels) — up to +20%
  combined performance at max, applied live without a respawn
  (`UpgradeCatalog.lua`, `UpgradeUI.client.lua`)
- Blueprint Crates: Common/Rare/Epic/Legendary gacha, Crystal-priced,
  published odds, hard pity (guaranteed Epic+ within 50 pulls), duplicate
  compensation instead of a wasted pull (`CrateService.lua`,
  `CrateUI.client.lua`). Ultimate/Limited tiers are Phase 3 scope.
- Same-server matchmaking: players queue for the competitive track, a heat
  of 2-6 forms automatically, and finish order pays out by placement
  (100/75/55/40/28/18%), with a DNF consolation payout if the heat times
  out (`QueueUI.client.lua`) — see "Known simplifications" below for why
  this isn't the blueprint's real cross-server design yet

Not here yet: a real cross-server Rating-band matchmaker, Ultimate/Limited
rarity, Prestige/Rating leaderboards, and any actual Robux purchase flow
(Crystal packs, gamepasses) — those need MarketplaceService products
configured in the Creator Dashboard, which this repo can't do on its own.

## Project layout

This is a [Rojo](https://rojo.space) project, so the game lives as plain Lua
files in git and syncs into Roblox Studio rather than as a binary `.rbxl`.

```
default.project.json
src/
  ServerScriptService/
    GameInit.server.lua      -- track/plot build, car spawning, lap logic,
                                 shop, upgrades, crates, matchmaking, drive loop
    Modules/
      CarBuilder.lua         -- builds a car Model from brick parts
      TrackBuilder.lua       -- builds a loop track + checkpoints
      CarCatalog.lua         -- purchasable + crate-exclusive car definitions
      PlayerProfile.lua      -- DataStore-backed profile (currencies, cars, upgrades, pity)
      UpgradeCatalog.lua     -- 5-branch upgrade cost curve + stat bonus
      CrateService.lua       -- crate odds, pity, tier -> car pool
  StarterPlayer/
    StarterPlayerScripts/
      LapHud.client.lua      -- Cash/Crystals/lap HUD
      ShopUI.client.lua      -- car shop panel
      UpgradeUI.client.lua   -- upgrade tree panel
      CrateUI.client.lua     -- Blueprint Crate panel
      QueueUI.client.lua     -- race queue + results panel
```

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (or **Play Here**, with a few local test players, to
   exercise matchmaking) to test.

## Known simplifications

Deliberate scope cuts, not oversights — noted here so they're easy to find
when it's time to revisit them:

- **Matchmaking is same-server.** The blueprint's production design queues
  by Rating band across servers and teleports players into a dedicated race
  server (see the blueprint's Technical Architecture section). That needs a
  second Roblox Place configured in the Creator Dashboard. What's here
  instead is a same-server queue + race-session system that proves the
  mechanic (heat forms, placement payout, DNF handling) without that
  infrastructure.
- **No real currency purchases.** Crystals only trickle in from competitive
  laps right now (1/lap). Robux-priced Crystal packs and gamepasses need
  MarketplaceService developer products created in the Dashboard first.
- **Upgrade failure chance / Guarantee Token isn't implemented.** The
  blueprint's levels 7-8 risk-of-loss mechanic needs a real Robux dev
  product for the bypass; all 8 levels are currently Cash-only, no risk.
- **A mid-race disconnect doesn't close out early.** If a queued racer
  leaves mid-heat, the remaining racers' heat still resolves normally, but
  it won't formally close until everyone finishes or the 3-minute timeout
  hits — a minor gap, not a crash risk (see `GameInit.server.lua`'s
  Matchmaking section for the reasoning).
- `PlayerProfile.lua` has no cross-server session locking (comment in that
  file has details) — fine for a single-server prototype, worth revisiting
  before this runs on more than one server at once.

## Known rough edges

This was written without a running Studio session to test against, so a few
things are flagged for a first-pass check once it's actually synced in:

- Steering direction (`GameInit.server.lua`, the `turnRate` sign) may come
  out reversed — flip the sign if so.
- `MAX_FORWARD_SPEED` / `MAX_REVERSE_SPEED` / `MAX_TURN_RATE`, all Cash/
  Crystal reward amounts, and the crate/race economy numbers are starting
  guesses, not tuned values.
- The loop track is a plain rectangle, not the curved Speed Oval from the
  blueprint — placeholder geometry, swap for real track art later.
- No wrong-way detection — driving a checkpoint gap backwards isn't
  penalized yet.
- The five UI panels (Garage/Upgrades/Crates/Queue/HUD) are laid out with
  hardcoded screen positions and haven't been checked for overlap on
  smaller viewports.
- DataStore reads/writes will silently no-op to a fresh default profile in
  Studio unless *Enable Studio Access to API Services* is turned on under
  Game Settings → Security.

## Next up: rest of Phase 2 / Phase 3

Ultimate and Limited rarity tiers, the Prestige/Rating leaderboard split,
and — once the infrastructure exists — real cross-server matchmaking and
actual Robux purchase flows.
