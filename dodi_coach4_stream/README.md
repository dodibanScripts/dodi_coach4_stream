# DODI Coach4 Stream

The **client patch gate** for `dodi_cars`. It ships the `citizen` meta patch that turns the vanilla `coach4` into a real car, **verifies at runtime** that each player installed it, and blocks/kicks the ones who did not. It also hosts the Lua car profiles (top speed, acceleration, braking, drift, roll assist) shared by `dodi_cars`.

> **This resource is mandatory.** `dodi_cars` refuses to work correctly without it, and every player must merge the `citizen` patch into their own `RedM.app`. Patch download: **https://github.com/dodibanScripts/dodi_coach4_stream** (`client_patch/citizen.rar`). Read **[The citizen patch](#the-citizen-patch)** first.

---

## Why This Exists

RedM has **no cars**. Every vehicle in RDR2 multiplayer is a **draft vehicle** (wagon/stagecoach): wagon physics, wagon input, reins instead of a steering wheel.

`dodi_cars` builds cars on the `coach4` chassis — invisible chassis, custom body and wheel props attached on top. But the chassis only **drives like a car** after the vehicle meta files are patched on the **client**, because vehicle type, handling, seat layout and control bindings are all read from local `citizen` data. Server-side streaming **cannot** override them: RedM will not let a stream replace the vanilla `coach4`, which is why this resource does not ship a YFT.

So the deal is:

- the patch lives on the **player's machine**
- this resource **detects** whether the patch is there
- unpatched players get a **warning screen, frozen controls and a kick** — no desync, no wagon-physics abuse

---

## The citizen patch

The patch is a **merge of five vehicle meta files** into `%LOCALAPPDATA%\RedM\RedM.app\citizen`:

| File | What it changes |
|------|-----------------|
| `citizen/common/packs/base/data/levels/rdr3/vehicles.meta` | `COACH4` type → `VEHICLE_TYPE_CAR` |
| `citizen/common/data/handling.meta` | `COACH4` handling block: mass, grip, brakes, steering, centre of mass |
| `citizen/common/packs/base/data/ai/vehiclelayouts.meta` | car seat / entry / exit layout |
| `citizen/common/data/control/settings.meta` | `INPUT_VEH_CAR_*` bindings |
| `citizen/platform/data/control/default.meta` | default control map |

**Download (GitHub — this is the source of truth, pin this in Discord):**

- Repo: [dodibanScripts/dodi_coach4_stream](https://github.com/dodibanScripts/dodi_coach4_stream)
- Patch folder: [dodi_coach4_stream/client_patch/citizen](https://github.com/dodibanScripts/dodi_coach4_stream/tree/main/dodi_coach4_stream/client_patch/citizen)
- Ready zip: [citizen.rar](https://github.com/dodibanScripts/dodi_coach4_stream/raw/main/dodi_coach4_stream/client_patch/citizen.rar)

The same files also ship inside the Tebex pack at `dodi_coach4_stream/client_patch/`. GitHub is easier for players.

### Install (every player)

1. **Close RedM completely.**
2. Download **[citizen.rar](https://github.com/dodibanScripts/dodi_coach4_stream/raw/main/dodi_coach4_stream/client_patch/citizen.rar)** (or clone the repo and open `dodi_coach4_stream/client_patch/citizen`).
3. Extract the archive. You should have a `citizen` folder with `common/` and `platform/` inside.
4. Open your RedM install folder: paste `%LOCALAPPDATA%\RedM\RedM.app` into the Windows Explorer address bar.
5. **Back up** the existing `citizen` folder — copy it next to itself and rename it `citizen_backup`.
6. Copy the patch `citizen` contents **over** `RedM.app\citizen` and confirm **Replace / Merge** (folders merge, the five files above are replaced).
7. Launch RedM and join the server.
8. Still broken? Delete `RedM.app\data\cache` and launch again.

Nothing is automated on purpose: it is five file replacements, and a manual copy with a backup is safer than a script touching the player's RedM install.

### What players should be told

- Download is public: **https://github.com/dodibanScripts/dodi_coach4_stream**
- It is a **client-side file patch**, like a RedM addon — it does not touch RDR2 itself
- It has to be redone if RedM **reinstalls or wipes** `RedM.app`
- RedM must be **fully closed** during the copy
- A **full RedM restart** is required after installing — reconnecting is not enough

---

## How the gate works

1. At join (after `NetworkIsSessionStarted` + 3s) the client runs `RunCoach4MetaGate()`
2. `MetaLib.isCoach4DraftModel()` asks the engine whether `coach4` is still a draft model
3. If it is, the client **spawns a hidden `coach4` 40 m below the player**, checks whether the entity is a car type, then deletes it
4. The result is reported to the server (`dodi_coach4:metaStatus`)
5. Patched → gate opens. Unpatched → NUI warning, `DisableAllControlActions`, frozen ped, and a kick request after `Config.KickAfterMs`
6. Every `Config.RecheckMs` a blocked client retries, so a player who patches mid-session is released without rejoining
7. Players who never report at all are dropped 65s after joining (server-side timeout)

Server side keeps a per-player flag so other resources can check it before handing out a car.

---

## Convars

```cfg
setr coach4_meta_enforce 1      # 1 = gate on (production), 0 = gate off (local dev)
```

Client-side bypass for testing (your own machine only):

```
setr coach4_meta_force_ok 1     # MetaLib.hasCarMeta() always returns true
```

---

## Commands

Admin only (ACE `god`, `admin` or `command`):

```
/coach4_meta_recheck     re-run the gate and print the result
/coach4_meta_debug       dump meta detection details to F8
```

Server console only:

```
coach4_meta_kick [playerId]     drop a player with the patch message
```

---

## Verifying in game

```
/coach4_meta_debug
/drive_car union_pickup_blue
/engine 1 1
/drive_car_status
```

- F8 shows `meta COACH4 OK — gate opens` when the patch is detected
- `entityDraft=false` in `/drive_car_status` means the meta loaded
- If F8 says `coach4 is still a DRAFT model`, the patch did not apply: confirm you copied into `RedM.app\citizen` (not `RedM.app\data`), fully restarted RedM, and cleared `RedM.app\data\cache`

---

## Car profiles (`Config.CarProfiles`)

Lua-side tuning applied on top of the patched handling. Each `dodi_cars` car points at a profile with `carProfile = '<id>'`.

| Profile | Character |
|---------|-----------|
| `stock` | baseline |
| `sedan` | slower, softer throttle |
| `sport` | high top speed, quick pickup |
| `truck` | heavy, slow, with roll/turn assists |

What Lua **can** change: top speed multiplier, hard speed cap, acceleration ramp, coast deceleration, brake behaviour, handbrake/drift, turn assist, anti-wheelie, roll recovery, burnout.

What Lua **cannot** change: mass, traction, suspension — those live in `handling.meta`. For genuinely different physics per car, duplicate the `COACH4` block as `COACH4_SPORT` in the patch and ship an **addon model** with its own `handlingId` (you cannot have two `coach4` entries in `vehicles.meta`).

Every knob is documented inline at the top of `config.lua`.

---

## Notifications

This resource uses our notify system:

**dodi_notifys** — In-game notifications ([repo / install](https://github.com/dodibanScripts/dodi_notifys/tree/main/dodi_notifys))

The block screen itself is a self-contained NUI page (`html/`), so it works even before anything else loads.

---

## Framework Support

Standalone. No framework, no database, no items.

Optional:

- `dodi_notifys` — release tip when a blocked player patches mid-session
- `dodi_cars` — the consumer of this gate and of `Config.CarProfiles`

---

## Installation

1. Place the resource in your server resources folder
2. Add to `server.cfg` — **before `dodi_cars`**:

```cfg
setr coach4_meta_enforce 1
ensure dodi_coach4_stream
# ensure yourmaps_cars      # only if you bought the extra car pack
ensure dodi_cars
ensure dodi_gaspumps
```

3. Point players at **GitHub** (do not make them hunt inside the Tebex zip):
   [citizen.rar](https://github.com/dodibanScripts/dodi_coach4_stream/raw/main/dodi_coach4_stream/client_patch/citizen.rar)
   Repo: https://github.com/dodibanScripts/dodi_coach4_stream
4. Tune `Config.Messages` so the block screen shows that GitHub link
5. Restart — no SQL, no items

---

## Exports

### Client

```lua
exports['dodi_coach4_stream']:RunMetaGate()          -- re-run the check, returns true if patched
exports['dodi_coach4_stream']:IsMetaBlocked()        -- is this client currently blocked
exports['dodi_coach4_stream']:HasCoach4CarMeta()
exports['dodi_coach4_stream']:IsCoach4DraftModel()
exports['dodi_coach4_stream']:IsCoach4EntityCar(veh)
exports['dodi_coach4_stream']:ApplyCarProfile(veh, 'sport', overrides)
exports['dodi_coach4_stream']:PrintMetaDebug()
```

### Server

```lua
-- gate other systems: never hand a car to an unpatched client
if exports['dodi_coach4_stream']:PlayerHasCarMeta(src) then
    -- safe to spawn / deliver / sell a vehicle
end
```

---

## Config Highlights

- `Config.EnforceMeta` — master switch (overridden by `coach4_meta_enforce`)
- `Config.KickWithoutMeta` / `Config.KickAfterMs` — kick behaviour and grace period (90s)
- `Config.RecheckMs` — retry interval for blocked clients (15s)
- `Config.BlockControls` — also block firing while blocked
- `Config.Messages` — block screen title/lines and kick reason (**GitHub link already set**)
- `Config.CarProfiles` — per-profile speed, acceleration, braking, drift and roll tuning

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Block screen on a patched machine | Copied into the wrong folder, or RedM was not fully restarted. Copy the files again, then clear `RedM.app\data\cache` |
| `entityDraft=1` in `/drive_car_status` | Patch not applied. Server-side streaming cannot fix this — the client patch is the only way |
| Engine starts but keys do nothing | `settings.meta` / `default.meta` did not merge — copy those two files again |
| Car body invisible, chassis visible | Not a patch issue: that is a `dodi_cars` streaming problem (YTYP must be inside `stream/`) |
| Everything blocked on your own dev box | `setr coach4_meta_enforce 0` |

---

## Credits

Gate, profiles and packaging by **Dodiban Scripts**.
`citizen` meta patch based on the public **RedM drivable coach4** research.
