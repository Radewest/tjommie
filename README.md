# Tjommie (WoW Forever)

Stay connected with your duo partner while you level in different parts of the world.

- **Tracker bar:** sits under the minimap and works like TomTom's arrow. It shows your buddy's class portrait with an arrow circling it to point their way, plus distance in yards, compass heading, how long until you reach them, their zone and their XP bar. Left-click opens the window, drag moves it, and right-click switches the TomTom arrow on or off.
- **TomTom option (`/tj tomtom`):** if you use TomTom, its big arrow points at your buddy instead.
- **Pop-ups:** styled like WoW's loot alerts, with the item icon and a border in the item's rarity colour.
- **Window:** Overview (the two of you side by side, recent activity, head-to-head bars), Feed, Stats and Wishlist.
- **Minimap button:** left-click opens the window, right-click shows or hides the tracker bar, drag moves it.
- **Live feed:** shows your buddy's level-ups, new zones, quests, deaths and loot (green and above).
- **Map trail:** your buddy's live pin plus a breadcrumb trail on the world map, on both zone and continent maps.
- **Loot wishlist:** shift-click items to add them. When either of you loots something:
  - If it's on the other person's wishlist, you both get an alert.
  - If it's an upgrade for the other person, you both get an alert. "Upgrade" checks their class's armour type (Plate/Mail unlock at 40), weapon skills, main stats and the item level of what they're wearing. No item lists to maintain.
  - Each alert also says whether the item is tradeable, so you know to mail it rather than vendor it.
- **Upgrade finder (Upgrades tab):** finds gear upgrades for both of you in your quest logs, from quest-givers (pop-up: "accept this quest, it rewards an upgrade"), at quest hand-ins (pop-up: "pick this reward") and at vendors you open. Upgrades for your buddy found in your quest log get sent to them, so each of you sees the other's leads.
- **Fun stats:** drinks, times you got completely smashed, time spent dancing, time at the **Gees Vuur** (the campfire's "Campfire Nearby" buff) and campfires lit. The feed announces campfires and smashed moments.
- **Settings:** pop-ups and sounds for each type, chat messages (Off / Important / Everything), tracker bar size, opacity and lock, hide in dungeons, fade in combat, a resizable window, map trail options, and privacy (pause your position, hide your gold).
- **Stats board:** the two of you side by side (level, gold, gold earned, kills, deaths, quests, zones, distance, blues and epics looted, time played). Whoever is ahead shows in green.

## How long until you reach them
Tjommie measures how fast the distance between you is shrinking over the last few seconds. It shows `--:--` when you're not getting closer.

## Install
1. Copy the `Tjommie` folder to `World of Warcraft\_classic_beta_\Interface\AddOns\` (use whichever folder your Forever install uses).
2. **You and your buddy both need it.**
3. Link up: **right-click your friend** (their name in chat, the friends list, their portrait) and choose **Add as Tjommie**. You can also click **Choose tjommie** in the window, or target them and type `/tj set`. They click **Accept**, and you're both linked.
4. If it shows as "out of date" on the character screen, tick **Load out of date AddOns**.

**Connection:** Tjommie connects through your Battle.net friends list if your buddy is on it, which works across realms and factions. Otherwise it uses a hidden whisper, which needs the same realm and faction.

## Commands
| Command | What it does |
|---|---|
| `/tj` | Open the window (Feed / Stats / Wishlist) |
| `/tj set Name` | Set your buddy |
| `/tj bar` | Show or hide the tracker bar |
| `/tj tomtom` | Point TomTom's arrow at your buddy (needs TomTom installed) |
| `/tj minimap` | Show or hide the minimap button |
| `/tj wish [item]` / `/tj unwish [item]` | Add an item to / remove an item from your wishlist (shift-click the item in, or use its ID) |
| `/tj trail mine` | Show your own trail too |
| `/tj trail clear` | Clear the trails |
| `/tj sound` / `/tj toasts` | Turn alert sounds / pop-ups on or off |
| `/tj settings` | Open settings (also under Options → AddOns → Tjommie) |
| `/tj welcome` | Show the welcome guide again |
| `/tj demo` | Fake buddy for testing on your own |

## Limits
Following Blizzard's rules, the game hides positions inside dungeons and blocks add-on messages during some instanced content. When that happens, the tracker bar shows "Location hidden here".

Kills only count mobs that give XP. Stats start from the moment you install the add-on.
