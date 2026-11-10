# Tjommie changelog

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
