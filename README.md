# Brikyard

A brick-built car collection and racing game for Roblox. Everyone spawns in
a shared showroom (garage/shop/upgrades/crates), drives through a teleport
pad onto one of three walled competitive tracks either solo or in a matched
multiplayer heat, and works up a rarity ladder from a free starter hatchback
to a handful of Limited cars almost nobody will ever own.

Full concept blueprint (rarity system, economy, matchmaking, monetization,
growth features) lives outside this repo as a design document; ask the
project owner for the current link.

## Status: Phase 0, 1, and 2 (alpha) complete per the roadmap

**Phase 0 (prototype):** one drivable car, one placeholder loop track,
server-authoritative lap timing.

**Phase 1 (vertical slice):**

- Cash economy: 55-70 Cash per freeform (solo) lap depending on track,
  awarded and tracked server-side only, persisted to DataStore
  (`PlayerProfile.lua`)
- A shared showroom/lobby everyone spawns into, with a teleport pad to each
  competitive track (see "The showroom rework" below)
- Three purchasable Common-tier cars plus a shop UI (`ShopUI.client.lua`),
  gated by a Garage Slot cap (starts at 4, buyable up to 30, Cash-only for
  now — see Known simplifications)

**Phase 2 (alpha):**

- **All three competitive tracks** from the blueprint's Track Design section
  — Speed Oval, Technical Circuit, Stunt Yard — each its own loop, freeform
  Cash rate, and race payout multiplier (4.5x/4.0x/6.0x at 1st place)
- Full five-branch upgrade tree (Engine/Tires/Nitro/Handling/Chassis, 8
  levels each, Cash-only, cost doubles every two levels) — up to +20%
  combined performance at max, applied live without a respawn
  (`UpgradeCatalog.lua`, `UpgradeUI.client.lua`)
- Blueprint Crates: Common/Rare/Epic/Legendary gacha, Crystal-priced,
  published odds *and* published pity rule in-UI (guaranteed Epic+ within 50
  pulls), duplicate and garage-full compensation instead of a wasted pull
  (`CrateService.lua`, `CrateUI.client.lua`). Ultimate/Limited tiers are
  Phase 3 scope.
- Same-server matchmaking, one queue per competitive track: players queue,
  a heat of 2-6 forms automatically on that track, and finish order pays out
  by placement (100/75/55/40/28/18% of that track's multiplier), with a DNF
  consolation payout if the heat times out (`QueueUI.client.lua`) — see
  "Known simplifications" below for why this isn't the blueprint's real
  cross-server design yet

Not here yet (correctly out of scope until Phase 3+ per the roadmap): a real
cross-server Rating-band matchmaker, Ultimate/Limited rarity, Prestige/Rating
leaderboards, the Race Ticket/energy system, and any actual Robux purchase
flow (Crystal packs, gamepasses) — those need MarketplaceService products
configured in the Creator Dashboard, which this repo can't do on its own.

## The showroom rework (post-first-playtest)

The first real Studio playtest surfaced three real bugs (see "Fixed after
the first Studio playtest" below) and one piece of direct feedback: the
original design — six always-visible personal practice plots lined up next
to three competitive tracks, all in one open field — looked and felt rough.
Reworked into:

- **A single shared showroom/lobby** (`TrackBuilder.buildShowroom`) with a
  neutral `SpawnLocation` everyone spawns at. The Garage/Upgrades/Crates
  panels are just always-on-screen UI, so they already worked from anywhere
  — the showroom mainly needed to exist as a place to stand and a way to
  reach a track.
- **Three physical teleport pads** in the showroom, one per track, each
  labeled and colored to match that track's theme — drive onto one to
  travel there (server-validated, not a client-side jump). Getting back is
  a **"RETURN TO SHOWROOM" UI button** instead of a pad: every point on a
  walled loop is on the main driving line, so a physical return pad risked
  yanking a racer back to the showroom mid-lap if they clipped it during a
  real race.
- **Barrier walls on both edges of every straight**, so a car physically
  can't drive off a track anymore — it wasn't walled at all before.
- **Bigger tracks** — every competitive track's footprint grew (e.g. Speed
  Oval's half-length went from 70 to 130 studs) — and **per-track color
  theming** (road/wall/centerline colors distinct per archetype) plus a
  painted centerline, instead of one flat grey rectangle for all three.
- The personal-plot system (`assignPlot`/`releasePlot`/6 practice tracks) is
  gone entirely. "Solo racing" is now just freeform (non-matched) driving on
  any of the 3 real tracks, which already paid a lower rate than a matched
  race — the low-reward/high-reward split the redesign asked for was already
  there, it just needed a real place to happen.

Track shape is still a placeholder rectangle, not the blueprint's real
curved layouts — that's still a genuine art task, not something proportions
and color alone fix. See "Known simplifications" below.

## Fixed after the first Studio playtest

None of these were caught by the Lua test suite — each is exactly the kind
of thing `tests/README.md` warns it can't check (real Roblox runtime
behavior, real rotation, a genuinely unpublished place):

- **A player's Character can already exist when `PlayerAdded` runs**
  (common in Studio's solo Play mode), so `CharacterAdded:Connect` never
  fired and no car ever spawned. Fixed by also spawning directly when
  `player.Character` is already set.
- **`DataStoreService:GetDataStore()` throws for an unpublished place**
  ("You must publish this place to the web to access DataStore"), which
  crashed `PlayerProfile.lua` at module-load time, which crashed
  `GameInit.server.lua`'s `require` of it before a single RemoteEvent got
  created — the entire game looked like a stock baseplate. Fixed with a
  pcall and an in-memory fallback so the rest of the game still works that
  session; Cash/Crystals just won't persist.
- **Wheels rendered flat, lying on their side like a coin.** A Cylinder's
  round faces sit perpendicular to its local X-axis by default, which was
  already the correct orientation for a wheel offset sideways from the
  chassis — an extra 90-degree rotation moved that axis onto Y instead.
  Removed the rotation.

## Fixed after the showroom rework's first playtest

Three more real bugs, found immediately after the showroom rework above went
into Studio:

- **Track corners were sealed shut, trapping the car.** The wall-building
  code built each of the 4 road segments' flanking walls independently,
  each sized to that segment's *full* length — including the zone where it
  overlaps the next segment at a corner. Both segments meeting at a corner
  then extended walls into that same corner square from different
  directions, boxing it in instead of leaving a driveable turn. Fixed by
  replacing per-segment walls with `TrackBuilder`'s `addWallRectangle`: two
  independent, concentric rectangular perimeters (an outer ring and an
  inner ring) built the same corner-overlap way the road itself is, which
  leaves the same open corridor all the way around, corners included.
  Locked in with new geometry tests in `tests/test_track_builder.lua` that
  check every wall sits on exactly one of the two rings, with a length that
  matches that ring.
- **"RETURN TO SHOWROOM" didn't work if you'd gotten out of the car.** The
  handler moved the *car* with `PivotTo` but never re-seated the *player*,
  so someone who'd exited to walk around (as in the reported bug) stayed on
  foot in the showroom. The same gap existed on the outbound teleport pads.
  Fixed with a shared `seatPlayerInCar` helper called after every teleport,
  covered by `tests/test_game_return_to_showroom.lua`.
- **UI panels didn't close and could stack on screen.** Garage/Upgrades/
  Crates each toggled their own panel's `Visible` independently, so opening
  one never closed another, and there was no way to back out of one once
  open. Fixed with a shared `PanelCoordinator` module
  (`src/ReplicatedStorage/Modules/PanelCoordinator.lua`): each panel
  registers itself and toggles through it, so opening one always closes the
  others, and each panel also got an explicit CLOSE button.

## Project layout

This is a [Rojo](https://rojo.space) project, so the game lives as plain Lua
files in git and syncs into Roblox Studio rather than as a binary `.rbxl`.

```
default.project.json
src/
  ServerScriptService/
    GameInit.server.lua      -- showroom/track build, teleport pads, car
                                 spawning, lap logic, shop, garage slots,
                                 upgrades, crates, matchmaking, drive loop
    Modules/
      CarBuilder.lua         -- builds a car Model from brick parts
      TrackBuilder.lua       -- builds a walled, themed loop track +
                                 checkpoints, and the showroom/lobby
      CarCatalog.lua         -- purchasable + crate-exclusive car definitions
      PlayerProfile.lua      -- DataStore-backed profile (currencies, cars, garage slots, upgrades, pity)
      UpgradeCatalog.lua     -- 5-branch upgrade cost curve + stat bonus
      CrateService.lua       -- crate odds, pity, tier -> car pool
  ReplicatedStorage/
    Modules/
      PanelCoordinator.lua   -- shared "only one UI panel open at a time"
                                 coordinator used by Garage/Upgrades/Crates
  StarterPlayer/
    StarterPlayerScripts/
      LapHud.client.lua      -- Cash/Crystals/lap HUD
      ShopUI.client.lua      -- car shop + garage slot panel
      UpgradeUI.client.lua   -- upgrade tree panel
      CrateUI.client.lua     -- Blueprint Crate panel (odds + pity)
      QueueUI.client.lua     -- per-track race queue, results, and the
                                 "return to showroom" button
tests/
  (see tests/README.md)      -- a Lua-level simulation of the server logic,
                                 since there's no Studio available here to
                                 actually playtest in -- run with
                                 `./tests/run_tests.sh`
```

## Running it in Studio

1. Install the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/)
   and the Rojo Studio plugin.
2. From the repo root: `rojo serve`
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (or **Play Here**, with a few local test players, to
   exercise matchmaking) to test.

## Testing without Studio

There's no Roblox Studio available in the environment this was built in, so
`tests/` is a Lua-level simulation instead: a hand-built mock of the Roblox
API (`tests/mock_roblox.lua`) that actually loads and executes the real
files in `src/` -- not a reimplementation -- and drives them through
simulated multiplayer scenarios (joining, driving laps, buying cars,
upgrading, pulling crates, queuing into matchmaking heats) with real
assertions on the results. It already caught and fixed one real bug
(`PurchaseCar` accepting a crate-exclusive car ID). Run it with:

```
./tests/run_tests.sh
```

See `tests/README.md` for exactly what this does and doesn't prove -- in
short, the logic is verified; a real Studio playtest is still needed to
confirm it plays well (steering feel, tuning, UI layout).

## Known simplifications

Deliberate scope cuts, not oversights — noted here so they're easy to find
when it's time to revisit them:

- **Matchmaking is same-server.** The blueprint's production design queues
  by Rating band across servers and teleports players into a dedicated race
  server (see the blueprint's Technical Architecture section). That needs a
  second Roblox Place configured in the Creator Dashboard. What's here
  instead is a same-server queue + race-session system, one queue per
  track, that proves the mechanic (heat forms, placement payout, DNF
  handling) without that infrastructure.
- **Track archetypes differ in size, color theme, and economy, not real
  terrain.** Speed Oval/Technical Circuit/Stunt Yard are three differently
  sized, differently colored, walled rectangular loops with different
  rewards — no real chicanes, jumps, or drift ribbons yet. That's real
  level art, deferred until it exists.
- **No real currency purchases.** Crystals only trickle in from competitive
  laps right now (1/lap). Robux-priced Crystal packs, gamepasses, and the
  Garage Slot cap's "instant Robux unlock" all need MarketplaceService
  developer products created in the Dashboard first — slots are Cash-only
  for now.
- **Upgrade levels are simplified.** The blueprint calls for levels 5-6 to
  also require a rare part dropped from races, and levels 7-8 to carry a
  failure chance with a Robux Guarantee Token bypass. All 8 levels are
  currently Cash-only, no material requirement, no risk — the Guarantee
  Token specifically needs a Dashboard-configured dev product; the part-drop
  requirement was cut for scope, not blocked by infrastructure.
- **No Race Ticket/energy system.** The blueprint's competitive-race gating
  (§06) is bundled with Phase 3 "monetization surfaces" in the roadmap, not
  Phase 2 — competitive tracks are currently unlimited/free to queue for.
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

- Steering direction (`GameInit.server.lua`, the `turnRate` sign) still
  hasn't been confirmed either way — flip the sign if it comes out reversed.
- `MAX_FORWARD_SPEED` / `MAX_REVERSE_SPEED` / `MAX_TURN_RATE`, all Cash/
  Crystal reward amounts, garage slot costs, and the crate/race economy
  numbers are starting guesses, not tuned values.
- No wrong-way detection — driving a checkpoint gap backwards isn't
  penalized yet.
- The showroom's 3 outbound pads and the wall placement on every track were
  computed, not visually checked — a pad could in principle sit too close
  to a wall or to the `SpawnLocation`. Worth a look once this is actually
  in Studio.
- The UI panels (Garage/Upgrades/Crates/Queue-and-Return/HUD) are laid out
  with hardcoded screen positions and haven't been checked for overlap on
  smaller viewports.
- DataStore reads/writes will silently no-op to a fresh default profile in
  Studio unless *Enable Studio Access to API Services* is turned on under
  Game Settings → Security.

## Next up: Phase 3

Ultimate and Limited rarity tiers, the Prestige/Rating leaderboard split,
the Race Ticket/energy system, and — once the infrastructure exists — real
cross-server matchmaking and actual Robux purchase flows.
