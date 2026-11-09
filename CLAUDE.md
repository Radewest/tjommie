# Tjommie: Developer Notes

Notes for future Claude sessions and for Harry: what Tjommie is, how it's built, the decisions behind it, and how to change and ship it. The code itself is the final word; this file explains why it is the way it is.

## What it is
A World of Warcraft: **Forever** add-on for two friends levelling apart ("tjommie" is South African slang for friend). Both players install it and link up. Each then sees the other's location, live activity, map trail, gear upgrades and head-to-head stats.

- **Owner:** Harry (CurseForge project ID 1786857, MIT licence)
- **Code:** GitHub `Radewest/tjommie` (the source of truth). The repo root is the add-on folder.
- **Local copy:** `OneDrive\Claude Projects\App Dev\wow-forever-addons\Tjommie\` (synced to Harry and his friend). Keep it in step with `main` after each release.
- **Releases:** pushing tag `vX.Y.Z` builds `Tjommie-vX.Y.Z.zip` (GitHub Release, plus CurseForge and Wago once configured). Old zips are kept for rollback.
- **Current version:** v0.3.2 (uploaded to CurseForge by hand, so it has no git tag; v0.3.3 will be the first automated release)

## The platform: WoW Forever
- Forever runs Classic content on the **modern Midnight-era client and API** (C_Map, C_Item, C_BattleNet, Menu API, BackdropTemplate and so on).
- **TOC:** `## Interface: 16001`. The file is named `Tjommie_Camelot.toc` ("Camelot" is Forever's internal game type), with an identical `Tjommie.toc` as a fallback.
- **Install folder:** `World of Warcraft\_classic_beta_\Interface\AddOns\Tjommie` (the folder name may change after launch).
- **Midnight add-on restrictions:** add-ons may show information but not make combat decisions. Some values are "secret" in combat or instances, so always guard with `ns.IsSecret(v)`. Player position is nil inside instances. Add-on messages can be blocked in instances, so wrap sends in pcall.
- **Campfires:** Forever's campsite system gives the buff **"Campfire Nearby"** (also "Welcoming Campfire"). Campfire spell IDs: 818 (Basic), 1283400 (Journeyman), 1291341 (Expert).

## Architecture
Single namespace `ns` (also global `Tjommie` for `/dump`). Load order follows the TOC:

| File | Role |
|---|---|
| Core.lua | Saved variables, event bus (`ns:On`), internal callbacks (`ns:Listen` / `ns:Fire`), `ns.SafeCall` error wrapper, helpers (formatting, class icons, map↔world conversion), slash commands |
| Bugs.lua | Self bug-logging into `TjommieDB.errors` (deduplicated, capped at 30); `/tj bugs` opens a copyable window; chains `seterrorhandler` for Tjommie-path errors |
| Comms.lua | Messaging: `ns:SendTo(name, ...)`, `ns:Send(...)` (to the buddy), receive and dispatch to `ns.msgHandlers[TYPE]`; handshake and keepalive; hides "player not found" spam |
| Pairing.lua | Link-up without typing: right-click "Add as Tjommie" (Menu.ModifyMenu), friend picker data, target + `/tj set`; PAIRQ/PAIRA/PAIRN request flow with a StaticPopup |
| Tracker.lua | Position loop (every 2s), trails, distance, stats (compact wire format), milestones (level, zone, death, quest) and the activity feed |
| Loot.lua | Class rules (armour type by level, weapon skills, main stats), `ns:EvaluateFor(itemID, who)`, gear sync, wishlist, loot alerts both ways |
| Upgrades.lua | Upgrade finder: quest log scan, quest-giver and hand-in checks, vendor scan; shares leads for the buddy (U/UC messages) |
| Fun.lua | Drinks / smashed (from drunk system messages), dance timer (hooks DoEmote, stops on movement), Gees Vuur time (aura) and campfires lit |
| Nav.lua | TomTom-style navigation: distance, compass heading, rotation and ETA (closing speed over 5s, smoothed); optional TomTom arrow bridge |
| Toast.lua | Pop-ups styled like loot alerts (icon, rarity-coloured border, up to 3 stacked) |
| Bar.lua | Tracker bar under the minimap (portrait with an orbiting arrow, nav text, zone, XP) |
| Minimap.lua | Minimap button |
| MapPins.lua | World map overlay: buddy pin with a pulsing glow, fading breadcrumb trail(s), projected via world coordinates so it works on zone and continent maps |
| UI.lua | Main window: Overview / Feed / Stats / Upgrades / Wishlist tabs, plus the friend picker |
| Demo.lua | `/tj demo` fake buddy for solo testing (saves and restores the real buddy data) |
| media/ | arrow.tga, dot.tga, icon.tga (generated with Python as 32-bit uncompressed TGA) |

### Saved variables
- `TjommieDB` (account-wide): buddy name, UI positions, toggles, the bug log.
- `TjommieCharDB` (per character): your own stats, zones seen, wishlist, your own trail, the feed, and `buddyData` (info, stats, wishlist, gear, trail, last position).

### Message protocol
- Prefix `Tjommie`, separator `~`. Never use `|` in messages, because chat treats it as an escape character.
- Messages are capped at 250 bytes. The stats message is about 115 bytes at worst.
- **Transport:** if the buddy is an online Battle.net friend, use `BNSendGameData` (works across realms and factions). Otherwise use an addon whisper (needs the same realm and faction).
- **Trust:** messages from anyone other than the buddy are ignored, except the pairing messages.

| Type | Fields |
|---|---|
| HI | class, level, version, needReply |
| P | mapID, x, y, zone, subzone (position) |
| E | kind (LVL, ZONE, DEAD, QUEST, LOOT, SMASHED, FIRE, ATFIRE), args |
| S | values in a fixed order (see `WIRE` in Tracker.lua); **changing the order breaks compatibility** |
| W | wishlist itemIDs |
| G | slot:ilvl list (equipped gear) |
| U / UC | upgrade lead for the buddy (itemID, quest title, zone, why) / clear the old leads |
| PAIRQ / PAIRA / PAIRN | pairing request (class, level, version) / accept / decline |

## Key decisions (and why)
- **Our own arrow instead of depending on TomTom.** The friend needs nothing extra and it's made for following a friend. TomTom is an optional mirror (`/tj tomtom`).
- **Upgrade logic is rule-based, not item lists.** Class armour, weapon and stat rules plus item level compared with equipped gear. Nothing needs maintaining, and it works with Forever's changed items.
- **The upgrade finder only uses what the game can see** (quest log, quest-givers, vendors). A curated dungeon-drop route guide is a possible next step, but it needs researched data and both players' classes.
- **Distance uses world coordinates (yards);** direction projects onto the current map. The ETA is distance ÷ smoothed closing speed, and shows `--:--` when you're not getting closer.
- **"Drinks" counts drunk-level increases,** because the game only reports when you get tipsier, not every drink.
- **Pairing needs consent:** a request plus an Accept/Decline pop-up, so no one can link to you silently.

## Conventions
- **Every change:** bump the version in both TOCs and `ns.VERSION` (Core.lua); add an entry at the top of `CHANGELOG.md`; run `python3 tests/run_tests.py`; commit; then `git tag vX.Y.Z && git push --tags` to release. Copy the new zip into the OneDrive folder and update the OneDrive `Tjommie` folder.
- **Add new files to both TOCs** (the tests load files in TOC order, so a missing TOC entry shows up as a failure).
- **New features get a check in `tests/smoke.lua`.**
- Keep the README and the `/tj help` text in sync with features.
- Guard every modern API call (`if C_X and C_X.Fn`); wrap risky calls in pcall; check `ns.IsSecret`.
- Use `ns:On` for game events and `ns:Listen` / `ns:Fire` for internal events (both run through SafeCall, so errors land in the bug log).
- User-facing tone: friendly, light South African flavour ("Lekker", "Gesondheid!", "boet").

## Testing
- **Outside the game:** `pip install lupa luaparser && python3 tests/run_tests.py`. This runs a syntax check of every .lua file plus `tests/smoke.lua`, which loads the add-on in TOC order against WoW API stubs (`tests/stubs.lua`), fires events, simulates buddy messages (HI/P/S/E/W/G/U/PAIR*) and asserts nav and ETA, loot evaluation, the upgrade scan, fun stats, the bug log and pairing. GitHub Actions runs it on every push and before every release. This doesn't replace in-game testing.
- **In the game:** `/tj demo` (a fake buddy drifting in and out so the ETA shows), BugSack + BugGrabber, `/tj bugs`, `/reload` after changes.
- **Bug reports:** ask for the `/tj bugs` output (version, client build and stack traces, from both players).

## Releasing (CurseForge)
- **Game:** World of Warcraft. Tick the Forever version when uploading a file. Release type: Beta while testing.
- **Main category:** Quests & Leveling. **Additional:** Map & Minimap, Chat & Communication, Miscellaneous.
- **Distribution:** allow third-party apps. **Licence:** MIT.
- **Logo:** `Tjommie_icon_400.png` (two map pins and a dotted trail that look like a smiley face).
- Paste that version's CHANGELOG section into the upload's changelog box (manual uploads only; the packager does it automatically).
- **Automated CurseForge uploads:** set up. Both TOCs have `## X-Curse-Project-ID: 1786857` and the repo has the `CF_API_KEY` secret. CurseForge's own "Automatic Packaging" stays off to avoid double uploads. For Wago, add `## X-Wago-ID` and `WAGO_API_TOKEN`. Forever's interface number (16001) is new, so check the first automated upload lands on the Forever game version; if not, upload manually.

## Roadmap (agreed with Harry, 2026-11-09)
1. **v0.4: polish.** Stop mirroring pop-ups to chat (add a chat setting: Off / Important / All); settings panel (own tab plus Blizzard AddOns options) covering pop-ups and sounds per type, tracker bar (show, scale, lock, opacity), map trails, minimap button and privacy (pause position sharing, hide gold); resizable/scalable main window and bar; lifetime stats (/played, gold, total quests completed, exploration, plus Blizzard Statistics if Forever has them), labelled Lifetime vs Since Tjommie.
2. **v0.5: helping each other.** Share professions; nudges when you loot materials your tjommie's professions use; a needs list from recipe reagents, matched against the other's bags; Waylaid Crates (which options either of you can fill from combined bags, alerts when the other loots something a crate needs, hand-in NPCs Marcy Baker / Dokimi); mailbox "Send to tjommie" helper (prefill only, the player clicks send).
3. **Later: multiple tjommies.** Up to 4. You pick a **main tjommie**, who is shown on the tracker bar and the Overview; others get mini bars, map pins, a feed tag and a stats column.

## Ideas not built yet
- Route guide: best dungeon drops and quest rewards for each level range for both classes (needs both players' classes and researched Forever item data).
- A big arrow in the middle of the screen when you head to your friend (declined for now).
- Postcards, daily duo challenges, quest-overlap meetup finder, cross-world pings (from the original brainstorm).
