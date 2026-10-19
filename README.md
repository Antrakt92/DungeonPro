<p align="center">
  <img src="https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/Media/Branding/Logo.png" alt="Dungeon Pro logo" width="112" height="112">
</p>

<h1 align="center">Dungeon Pro</h1>

Get your dungeon quests sorted before the run. Browse quests for your character,
follow their prerequisites and find the next pickup or turn-in.

[Download the Forever beta](https://github.com/Antrakt92/DungeonPro/releases)
· [CurseForge](https://www.curseforge.com/wow/addons/dungeon-pro)
· [Report a problem](https://github.com/Antrakt92/DungeonPro/issues)

**For WoW Forever. Early beta. TomTom is optional.**

![Dungeon browser with character quest filtering and a Wailing Caverns overview](https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/screenshots/dungeon-browser.png)

## Plan your next dungeon

- **Browse by dungeon.** Filter by level and switch between **Mine** and
  **All quests** to see quests for your character or all listed quests.
- **Follow the chain.** Expand prerequisite quests and related story steps,
  check your progress and see what to do next.
- **Find the pickup.** Check quest givers, objects and starter items, with
  alternative locations where known.
- **Check objectives and rewards.** See quest goals, items you need or receive,
  carried counts and reward choices. Some details depend on what the game
  client can provide.
- **Get directions.** Open known quest locations on the map or follow the
  built-in arrow, with optional TomTom support. Dungeon entrances have their
  own button; missing entrance locations are marked.

Search by dungeon, quest name, known NPC or place. You can also enter a quest ID
to find dungeons that list it.

Development builds also find NPCs and places in recorded prerequisite and story
steps, marked as **Related step**. Use **View quest** to inspect the matching step.
Recorded enemy objectives are also searchable and labelled **Quest objective**.
These matches identify the quest; directions remain tied to its known sources.

Development builds split quest details into three tabs: **Quest** for objectives,
rewards and the next action; **Sources** for known pickup methods and alternative
locations; **Story** for available or previously saved quest text. Each tab
keeps its reading position. Use the back arrow to revisit the previous quest, tab
and reading position. With no earlier quest in the window's history, it opens the
dungeon overview. Use the small arrow beside the dungeon list to
collapse it and give long quest chains more room; use the arrow again to restore
the list.

Dungeon overviews in development builds show progress for the listed quests and
known steps already in your quest log. Open a step to inspect its details; shared
steps appear once. Ready turn-ins appear first. The compact view shows up to six
steps; use **Show more** to reveal up to six more or **Show fewer** to return to
the compact list. Supporting quests have their own label; progress counts cover
only the main listed quests. Unverified conditions remain marked, and a short or empty
step list does not mean that every quest is ready to pick up.

Interior dungeon maps are not currently available. Dungeon overviews show an
illustration, not a floor map. Quest-location and dungeon-entrance directions
remain separate navigation actions.

<details>
<summary>Quest chains, objectives and rewards in game</summary>

![Expanded Deadmines quest chain with quest-giver location, objectives and rewards](https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/screenshots/quest-chain.png)

</details>

## Open the planner

Click the minimap button or type `/DP` and pick a dungeon.

## Commands

- `/DP` or `/DungeonPro` — open or close the planner.
- `/DP clear` — stop the current guide and remove the waypoint it created.
- `/DP minimap` — hide or show the minimap button.
- `/DP minimap reset` — show the button at its default position.
- `/rl` — reload the interface, like `/reload`.

Drag the minimap button to reposition it. If the button is hidden, use
`/DP minimap` to show it again; use `/DP minimap reset` to restore its position.

## Languages

Hover the globe to open the language menu, move over a language to preview it,
then click to keep it. Leave the menu without clicking to return to your saved
choice. **Auto** follows your game language.

English, Russian, German, French, Spanish, Italian, Portuguese, Korean,
Simplified Chinese and Traditional Chinese are supported. British English and
Latin American Spanish use the English and Spanish translations.

Dungeon, quest, NPC and place names use reviewed translations where available.
Missing translations fall back to original names. Item names, map and floor
names, and quest text supplied by the game stay in your client's language.

## Still in beta

The browser currently lists **29 dungeons**, including classic dungeons and
new Forever locations. Quest coverage is incomplete: some pickup locations,
requirements and other details are still missing. The addon marks those gaps,
and a listed quest does not guarantee that your character can accept it.

I'm still adding and checking quest data, fixing bugs and refining the interface.
If a quest is missing, a location looks wrong or a control is confusing, please
let me know through [GitHub Issues](https://github.com/Antrakt92/DungeonPro/issues).

A few things to keep in mind:

- Dungeon level ranges are recommendations. Your level, class or faction may
  rule a quest out, but meeting those checks alone does not confirm availability.
- Related story steps are not always required prerequisites. Dungeon card counts
  cover the main listed quests, not every step in an expanded chain.
- Quest descriptions are saved when you open their offers. Full descriptions
  for unseen quests are not bundled. Unknown item quantities stay unknown.
- The arrow points towards a location; it does not plan a route around terrain.
  A recorded position may depend on movement or quest phase. Navigation does not
  accept quests for you.
- Some newer dungeons still lack artwork. Translations and layout are also
  being refined during the beta.

## Help & links

When reporting a problem, include the dungeon, quest name or ID, addon version
and interface language. A screenshot helps with display or location problems.
Please leave account details and character settings files out of reports.

[Report a problem](https://github.com/Antrakt92/DungeonPro/issues)
· [Changelog](CHANGELOG.md)
· [Development guide](DEVELOPMENT.md)

The development guide covers source data, local checks and development packages.
Players only need the release ZIP.

## License and credits

Free to use. Public forks, ports and substantial reuse of my original code
require credit and a link to **Dungeon Pro**. If the derivative earns CurseForge
Reward Points, share at least **10% of that project's points** with `antrakt92`;
one share covers all my projects reused in it. No points earned means no payment.

See the [full license](LICENSE). This is the Antrakt Attribution and CurseForge
Rewards License 1.2, based on MIT with additional conditions; it is not the
standard MIT License. Earlier copies retain their original license grants.

Noto Sans retains its SIL Open Font License, and Unicode data retains its separate
notice. See [font credits](Media/Fonts/NOTICE.txt), [icon credits](Media/Icons/NOTICE.txt)
and [Unicode attribution](Database/SearchCaseFold.lua). Game assets belong to Blizzard.

## More by antrakt92

- [StatsPro](https://www.curseforge.com/wow/addons/statspro) — character stats and
  gear information on screen.
- [ApplicantScout](https://www.curseforge.com/wow/addons/applicantscout-lfg-overlay)
  — Warcraft Logs and RaiderIO for applicants and your group; requires the
  Windows Companion.
- [Do You Need It?](https://www.curseforge.com/wow/addons/do-you-need-it) — compare
  group loot and ask for items.

If you enjoy Dungeon Pro, add it to your favorites and follow it on CurseForge.
You can also [support my work on Ko-fi](https://ko-fi.com/antrakt92) or find my
other mods on [Nexus Mods](https://www.nexusmods.com/profile/Antrakt92).
