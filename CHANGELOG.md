# Tjommie changelog

## v0.6.1 (2026-11-13)
- **Fixed: recipes not showing for your tjommie.** The game quietly drops add-on messages sent in a burst, and recipe lists go out in several pieces, so one lost piece meant nothing showed. Tjommie now queues its messages and sends them at a pace the game allows.
- **Fixed:** recipe scanning now tries every profession window type the client offers (modern, Classic, and the separate Enchanting window), so an empty first try no longer stops it.
- **New: `/tj share`** sends your professions and saved recipes to your tjommie again.
- `/tj bugs` now shows recipe counts (yours, theirs, half-received) and the last recipe scan, to make problems easier to spot.

## v0.6.0 (2026-11-13)
- **Fixed: badges.** Being near each other, partying up and dungeon runs now count inside dungeons and groups too: the game blocks add-on messages and positions there, so Tjommie now asks the game about your party instead. Names are matched more reliably (realm spelling, Forever surnames), and both sides re-sync their badges when you come online, so missed ones catch up.
- **New: "Keen for this dungeon?"** Click a dungeon in the Together tab. Your tjommie gets a pop-up ("I'm in!" / "Not now"), and when they say yes you can invite them straight away.
- **New: Crafting tab.** See each other's professions and skill levels, and browse and search each other's recipes (they're shared once you've opened a profession window). Click a recipe to ask "can you make this for me?". Your tjommie gets an Accept/Decline pop-up.
- **New: route to the meeting point or your tjommie.** Hover over a pin on the world map to see the fastest route: run straight there, or run to a flight master, fly, and run the rest. The route is drawn on the map (white = run, gold = flight), with a time estimate. Flight masters are remembered when you open a flight map. There's a setting to always show the route to a meet-up.
- **New: works with Shortest Path Forever** (optional; install it separately from CurseForge). If you have it:
  - Hovering a pin shows its real route (walking paths, flights, boats, portals) with times.
  - **Click a pin, use "Take me there" on the Overview, or type `/tj go`** for turn-by-turn guidance to the meeting point or your tjommie. It follows your tjommie as they move and stops when you meet.
  - New meeting points start guidance automatically (setting: "Auto-guide to meet-ups").
  - Without it, Tjommie uses its own simple estimate as before.
- **New: Blizzard waypoint.** Meeting points also place the game's own map pin and on-screen marker, if your client has them. Can be switched off in Settings.
- **Fixed: the meeting-point pin could stay on the map after clearing it.** Clearing now always refreshes the map straight away.
- **Clearing is easier:** right-click or Shift-click the **Meet here** button, or right-click or Shift-click the pin itself.
- **New: move the Meet here button.** Shift-drag it anywhere on the map. It stays inside the map when you switch between windowed and maximised, and **Settings → Reset positions** puts it back.
- The window is a bit wider to fit the new tab.
- **Both players need v0.6.0** for dungeon requests, recipes and badge sync.

## v0.5.0 (2026-11-10)
- **Fixed: grey items no longer show up as upgrades.** Vendors are full of greys with a higher item level that are actually worse. Plain white items also no longer count as upgrades over greens or better. Thanks for the report!
- **New: status at a glance.** See what your tjommie is up to: "On a flight to Stormwind", "In The Deadmines", "In combat", "AFK", "At the Gees Vuur", "Dancing", "Resting in Goldshire", "Running back as a ghost". It shows on the tracker bar, the Overview card and the map pin.
- **New: Group up button** on the tracker bar when you're within 100 yards and not grouped yet (or `/tj invite`).
- **New: Meet here.** Click **Meet here** on the world map and then a spot, or use `/tj meet` for your own position. Both your arrows point to the meeting point with your own arrival time, and it clears itself when you're reunited.
- **New: Together tab.**
  - **Dungeons for you two:** what you're both ready for, and what's coming up. You get a pop-up when a new one opens up for both of you.
  - **Tjommie badges:** 13 shared badges (Finally Met, Party Up, Gees Vuur Gesels, Dance-off, Drinking Buddies, Same Fate, Dungeon Duo...) plus level races to 10, 20, 30, 40, 50 and 60.
- New "Meet-ups, badges & dungeons" pop-up setting.
- **Both players need v0.5.0** for status, meet-ups and badges.

## v0.4.0 (2026-11-09)
- **Less chat spam.** Pop-ups are no longer echoed into chat. A new **Chat messages** setting picks Off, Important only (default) or Everything.
- **New Settings tab**, also under Options → AddOns → Tjommie (or `/tj settings`):
  - Pop-ups: switch each type on or off (level-ups, deaths, loot and upgrades, fun stuff, tjommie online), plus sounds.
  - Tracker bar: show, lock, size, opacity, hide in dungeons and raids, fade in combat.
  - Window: size. Map: your tjommie's trail, your own trail, trail length.
  - Privacy: pause sharing your position (your tjommie sees "Location paused"), hide your gold.
  - Buttons for the welcome guide, bug log, demo and resetting positions.
- **Resizable window:** drag the bottom-right corner.
- **Lifetime stats:** the Stats tab now has two halves. **Lifetime** comes from the game: time played, quests completed, and kills, deaths and drinks if Forever keeps Blizzard's Statistics. **Since Tjommie** is everything the add-on counts.
- **Version warning:** you're told when you or your tjommie are on an older version.
- **Welcome guide** on first install (`/tj welcome` any time).
- New pop-ups when your tjommie comes online, gets smashed or lights a Gees Vuur (each can be switched off).

## v0.3.2 (2026-11-06)
- **New: link up without typing names.** Right-click a player anywhere and choose **Add as Tjommie**, pick from your online friends (**Choose tjommie** button, or `/tj pick`), or target them and type `/tj set`.
- Your friend gets an **Accept / Decline** pop-up. Accepting links you both automatically.
- `/tj set Name` still works, and now sends the request too.

## v0.3.1 (2026-11-06)
- **New: bug log.** Tjommie now records its own errors with details. Type `/tj bugs` to open a window with everything selected, ready to copy and send. `/tj bugs clear` empties it.
- Errors still show in BugSack or the default error window as before.

## v0.3.0 (2026-11-06)
- **New: Upgrades tab.** Finds gear upgrades for both of you in your quest logs, from quest-givers ("accept this quest"), at hand-ins ("pick this reward") and at vendors. Leads from your tjommie's quest log are shared with you.
- **New fun stats:** drinks, times completely smashed, time dancing, time at the Gees Vuur (campfire) and campfires lit. Campfires and smashed moments show in the feed.
- Stats are now sent in a smaller format. **Both players need v0.3 or later.**
- Time stats now show seconds when under a minute.

## v0.2.0 (2026-11-06)
- **New tracker bar** (replaces the compass): class portrait with an arrow circling it, distance, compass heading, how long until you reach them, zone and XP bar.
- **New TomTom option** (`/tj tomtom`, or right-click the tracker bar) to point TomTom's arrow at your tjommie.
- **New layout:** pop-ups styled like loot alerts, a redesigned window with an Overview tab, a minimap button, and a glowing map pin.
- XP is now shared between you.
- Added an icon.

## v0.1.0 (2026-11-06)
- First version (as BuddyBond, renamed to Tjommie): compass, live feed, map trail, loot wishlist with class-aware upgrade alerts, stats board and demo mode.
