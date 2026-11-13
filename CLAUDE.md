# Tjommie: Developer Notes

> General WoW Forever add-on know-how (platform, release pipeline, starter template) lives in `WOW_ADDON_PLAYBOOK.md` in OneDrive `App Dev\wow-forever-addons\` and in the App developer project knowledge.

Notes for future Claude sessions and for Harry: what Tjommie is, how it's built, the decisions behind it, and how to change and ship it. The code itself is the final word; this file explains why it is the way it is.

## What it is
A World of Warcraft: **Forever** add-on for two friends levelling apart ("tjommie" is South African slang for friend). Both players install it and link up. Each then sees the other's location, live activity, map trail, gear upgrades and head-to-head stats.

- **Owner:** Harry (CurseForge project ID 1786857, MIT licence)
- **Code:** GitHub `Radewest/tjommie` (the source of truth). The repo root is the add-on folder.
- **Local copy:** `OneDrive\Claude Projects\App Dev\wow-forever-addons\Tjommie\` (synced to Harry and his friend). Keep it in step with `main` after each release.
- **Releases:** pushing tag `vX.Y.Z` builds `Tjommie-vX.Y.Z.zip` (GitHub Release, plus CurseForge and Wago once configured). Old zips are kept for rollback.
- **Current version:** v0.6.1 (v0.3.2 was uploaded to CurseForge by hand; releases have been automatic since v0.4.0)

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
| Lifetime.lua | Whole-character stats from the game: /played (chat print-out suppressed), completed quest count, Blizzard Statistics (kills 1197, deaths 60, drinks 346) when `GetStatistic` exists |
| Fun.lua | Drinks / smashed (from drunk system messages), dance timer (hooks DoEmote, stops on movement), Gees Vuur time (aura) and campfires lit |
| Status.lua | Status at a glance: highest-priority status (dead/ghost, combat, instance name, flight + destination via a `TakeTaxiNode` hook, AFK, Gees Vuur, dancing, resting) sent as `ST` on change |
| Nav.lua | TomTom-style navigation: distance, compass heading, rotation and ETA (closing speed over 5s, smoothed). Aims at the meeting point when one is set, otherwise the tjommie, and always keeps `nav.buddyDist`. Optional TomTom arrow bridge |
| Meet.lua | Meet-here points: world map "Meet here" button (click to place; right-click or Shift-click to clear; Shift-drag to move, saved in `TjommieDB.meetButtonPos`), `/tj meet`, arrival toasts, clears itself when you're reunited (fires `REUNITED`). `ClearMeet` always refreshes the map |
| Route.lua | Remembers flight masters (`TAXIMAP_OPENED`, `TjommieCharDB.flightNodes`), `ns:PlanRoute` (run straight vs run → fly → run, rough speeds), `ns:RouteText`; mirrors meeting points into Blizzard's user waypoint + super-tracking |
| Pathing.lua | Optional **Shortest Path Forever** integration through its public API (`ShortestPathForever.API` v2): `ns:SPFPlan` / `EstimateDetail` for real routes in pin tooltips; `ns:GuideTo` / `Navigate` and `Cancel` (owner "Tjommie") for turn-by-turn guidance to the meet-up or the tjommie (re-routes as they move, stops on reunion); auto-guide on new meet-ups. `OptionalDeps: ShortestPathForever` |
| Dungeons.lua | Classic dungeon level ranges, `ns:GetDungeonSuggestions(myLevel, theirLevel)`, a one-time "both ready" pop-up per dungeon, "keen?" requests (`ns:AskDungeon`, DQ/DA pop-ups) |
| Badges.lua | Shared badges per tjommie (`TjommieCharDB.pairs[buddy]`), time together, fire and dance together, level races, badge-list sync (`BL`). Togetherness uses positions outdoors **and** the party unit (`ns:BuddyUnit`, `UnitIsVisible`, `UnitInRange`) so it works in dungeons; wraps the buddy DEAD and SMASHED handlers |
| Professions.lua | Professions + skill levels (`GetProfessions` or skill lines) and recipe lists read when a profession window opens (modern `C_TradeSkillUI`, Classic trade skill and craft APIs), chunked sharing, "can you make this?" requests |
| Toast.lua | Pop-ups styled like loot alerts (icon, rarity-coloured border, up to 3 stacked) |
| Bar.lua | Tracker bar under the minimap (portrait with an orbiting arrow, nav text, status + zone, XP, "Group up" button within 100 yd, `ns:InviteBuddy`) |
| Minimap.lua | Minimap button |
| MapPins.lua | World map overlay: buddy pin with a pulsing glow, meeting-point pin, fading breadcrumb trail(s) and the route on hover (white = run, gold = flight), projected via world coordinates so it works on zone and continent maps. Pins aren't hidden and re-shown during refresh (that would fire OnLeave) |
| Settings.lua | One settings panel builder used twice: the Settings tab and Blizzard Options → AddOns. Controls write `TjommieDB` and fire `SETTINGS_CHANGED` |
| UI.lua | Main window (650 wide, resizable, scalable): Overview (with meet buttons) / Together (clickable dungeons + badges) / Feed / Stats (Lifetime + Since Tjommie) / Upgrades / Crafting (theirs or mine, filter, search, ask to craft) / Wishlist / Settings tabs, plus the friend picker |
| Welcome.lua | First-install welcome guide (`/tj welcome`) |
| Demo.lua | `/tj demo` fake buddy for solo testing (saves and restores the real buddy data) |
| media/ | arrow.tga, dot.tga, icon.tga (generated with Python as 32-bit uncompressed TGA) |

### Saved variables
- `TjommieDB` (account-wide): buddy name, UI positions and sizes, all settings (chat level, `popups` per type, bar options, trail options, privacy), the bug log, `welcomed`.
- `TjommieCharDB` (per character): `lifetime` (game-provided totals), your own stats, zones seen, wishlist, your own trail, the feed, and `buddyData` (info, stats, wishlist, gear, trail, last position).

### Message protocol
- Prefix `Tjommie`, separator `~`. Never use `|` in messages, because chat treats it as an escape character.
- All sends go through a rate-limited queue in Comms.lua (burst 6, about 0.8 per second; P/ST/S/G/W/PF replace an older queued copy), because the game silently drops add-on message bursts. Tests set `TJOMMIE_TEST` so sends go out straight away.
- Messages are capped at 250 bytes. The stats message is about 150 bytes at worst (checked by the tests).
- **Transport:** if the buddy is an online Battle.net friend, use `BNSendGameData` (works across realms and factions). Otherwise use an addon whisper (needs the same realm and faction).
- **Trust:** messages from anyone other than the buddy are ignored, except the pairing messages.

| Type | Fields |
|---|---|
| HI | class, level, version, needReply |
| P | mapID, x, y, zone, subzone (position). `P~0` means "position paused" (privacy) and doubles as a heartbeat |
| E | kind (LVL, ZONE, DEAD, QUEST, LOOT, SMASHED, FIRE, ATFIRE), args |
| S | values in a fixed order (see `WIRE` in Tracker.lua); **only ever append new fields at the end**. v0.4 appended playedTotal, questsTotal, killsTotal, deathsTotal, drinksTotal. Gold is left out when "Share my gold" is off |
| W | wishlist itemIDs |
| G | slot:ilvl:quality list (equipped gear; quality appended in v0.5, old `slot:ilvl` still parses) |
| ST | status code (DEAD, GHOST, COMBAT, INSTANCE, TAXI, AFK, FIRE, DANCE, REST or empty), extra (instance / destination / place) |
| M / MC | meeting point set (mapID, x, y, zone) / cleared |
| B / BL | badge unlocked (id, winner for level races) / full badge list `id:winner,id,...` (sent on sync; received badges are unlocked quietly) |
| DQ / DA | "keen for this dungeon?" (name) / answer (name, 1 or 0) |
| PF | professions `Name:rank:max,...` |
| RC | recipe list chunk (profession, part, total, `i<itemID>`/`s<spellID>` entries) |
| CR / CA | "can you make this?" (entry) / answer (entry, 1 or 0) |
| U / UC | upgrade lead for the buddy (itemID, quest title, zone, why) / clear the old leads |
| PAIRQ / PAIRA / PAIRN | pairing request (class, level, version) / accept / decline |

## Key decisions (and why)
- **Our own arrow instead of depending on TomTom.** The friend needs nothing extra and it's made for following a friend. TomTom is an optional mirror (`/tj tomtom`).
- **Upgrade logic is rule-based, not item lists.** Class armour, weapon and stat rules plus item level compared with equipped gear. Nothing needs maintaining, and it works with Forever's changed items.
- **The upgrade finder only uses what the game can see** (quest log, quest-givers, vendors). A curated dungeon-drop route guide is a possible next step, but it needs researched data and both players' classes.
- **Distance uses world coordinates (yards);** direction projects onto the current map. The ETA is distance ÷ smoothed closing speed, and shows `--:--` when you're not getting closer.
- **"Drinks" counts drunk-level increases,** because the game only reports when you get tipsier, not every drink.
- **Chat output goes through `ns:Chat(msg, level)`:** pop-ups only echo to chat when the setting is Everything. `ns:Print` is only for direct replies to slash commands.
- **Upgrades ignore greys entirely.** A white only counts over an empty slot or another white or grey, because vendors are full of higher-item-level greys and whites that are worse (reported by a player in v0.4).
- **Inside dungeons, use the party, not messages.** Add-on messages and positions are blocked in instances, so togetherness and Dungeon Duo come from the party unit. Badge-list sync on login catches up anything missed.
- **Names are compared with `ns.SameName`** (case-insensitive; realms only compared when both names have one, with spaces and dashes ignored). Forever names can contain spaces (surnames).
- **Shortest Path Forever is used through its API only, never copied.** It's GPL-3 and about 9 MB of path data. Tjommie stays MIT and works without it. When it's guiding, Tjommie doesn't set the Blizzard waypoint itself.
- **Routes are estimates.** There's no pathfinding API: straight runs and known flight masters only, with rough speeds (run 7, mount 14, flight 30 yd/s).
- **Badges are shared:** whoever detects one sends `B` and the other side unlocks it too, without echoing it back. Level races are awarded by whoever gets there first.
- **Pairing needs consent:** a request plus an Accept/Decline pop-up, so no one can link to you silently.

## Conventions
- **Every change:** bump the version in both TOCs and `ns.VERSION` (Core.lua); add an entry at the top of `CHANGELOG.md`; run `python3 tests/run_tests.py`; commit and push `main`. **Releasing is automatic:** every push to `main` runs `.github/workflows/release.yml`. If the TOC version has no tag yet, it runs the tests, creates tag `vX.Y.Z` and starts `package.yml` (via workflow_dispatch, because bot-pushed tags don't trigger workflows), which publishes the zip to GitHub Releases and CurseForge with CHANGELOG.md as the changelog. If a tag exists without a GitHub Release, the next push retries the packaging. So bumping the version and pushing *is* the release. **Never push a version bump (or anything to `main`) without Harry's explicit go-ahead:** finish and test the change, tell him what will go out, and wait for "go". (Claude sessions can't push tags themselves, because the proxy returns 403, which is why the workflow creates them.) Copy the new zip into the OneDrive folder and update the OneDrive `Tjommie` folder.
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
- **Automated CurseForge uploads:** set up. Both TOCs have `## X-Curse-Project-ID: 1786857` and the repo has the `CF_API_KEY` secret. CurseForge's own "Automatic Packaging" stays off to avoid double uploads. For Wago, add `## X-Wago-ID` and `WAGO_API_TOKEN`. Confirmed with v0.4.0: the packager maps Interface 16001 to CurseForge game version **1.60.1 (Forever)** and names the file `Tjommie-vX.Y.Z-forever.zip`.

## Roadmap (agreed with Harry, 2026-11-09)
1. **v0.4: polish (done in v0.4.0).** Stop mirroring pop-ups to chat (add a chat setting: Off / Important / All); settings panel (own tab plus Blizzard AddOns options) covering pop-ups and sounds per type, tracker bar (show, scale, lock, opacity), map trails, minimap button and privacy (pause position sharing, hide gold); resizable/scalable main window and bar; lifetime stats (/played, gold, total quests completed, exploration, plus Blizzard Statistics if Forever has them), labelled Lifetime vs Since Tjommie.
2. **v0.5.0 (done): together features.** Grey/white upgrade fix, status at a glance, Group up button, Meet here, dungeon suggestions, Tjommie badges.
3. **v0.6.0 (built 2026-11-13): badge fixes, "keen for this dungeon?", professions and recipes with ask-to-craft, flight-path routes, Shortest Path Forever integration, Blizzard waypoint, movable Meet here button.**
4. **v0.7: rest of helping each other.** Share professions; nudges when you loot materials your tjommie's professions use; a needs list from recipe reagents, matched against the other's bags; Waylaid Crates (which options either of you can fill from combined bags, alerts when the other loots something a crate needs, hand-in NPCs Marcy Baker / Dokimi); mailbox "Send to tjommie" helper (prefill only, the player clicks send).
5. **Later: multiple tjommies.** Up to 4. You pick a **main tjommie**, who is shown on the tracker bar and the Overview; others get mini bars, map pins, a feed tag and a stats column.

## Ideas not built yet
- Route guide: best dungeon drops and quest rewards for each level range for both classes (needs both players' classes and researched Forever item data).
- A big arrow in the middle of the screen when you head to your friend (declined for now).
- Postcards, daily duo challenges, quest-overlap meetup finder, cross-world pings (from the original brainstorm).
- From the 2026-11-10 brainstorm, not picked yet: quick canned messages, pings and emotes, level race chart and XP per hour, gear view, bag search, end-of-session recap and scrapbook.
