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

Screenshots below show an earlier beta.

![Earlier dungeon browser with character quest filtering](https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/screenshots/dungeon-browser.png)

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

Search also finds NPCs and places in recorded prerequisite and story
steps, marked as **Related step**. Use **View quest** to inspect the matching step.
Recorded enemy objectives are also searchable and labelled **Quest objective**.
These matches identify the quest; directions remain tied to its known sources.

Select a quest in the chain to read its details in one place. Objectives, useful
items, rewards and known pickup or turn-in sources appear before available quest
text. Pickup and turn-in contacts have separate rows, with location choices where
recorded. Missing information stays marked.

Use the small arrow beside the dungeon list to collapse it and give long quest
chains more room; use the arrow again to restore the list.

Selecting a dungeon shows its name and levels on the right. Choose a quest or
chain step in the middle list to open its details; the right pane does not repeat
the quest list. Progress and preparation information remain with the middle list.
Unverified conditions stay marked.

Interior dungeon maps are not currently available. Quest-location and
dungeon-entrance directions remain separate navigation actions.

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

The browser lists classic dungeons and new Forever locations, with separate
entries for Scarlet Monastery's four wings. Quest coverage is incomplete: some pickup locations,
requirements and other details are still missing. The addon marks those gaps,
and a listed quest does not guarantee that your character can accept it.

Scarlet wing assignments marked **Classic** use the original Classic quest
layout as a starting point for Forever. Some quests span several wings; faction
and class filters still apply. Unassigned quests remain in the monastery quest
index. The four wing cards share the monastery illustration.

Profession labels describe recorded quest requirements. Skill ranks,
specializations and character eligibility may still be unverified.

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
Reward Points, allocate a **positive share of that project's points** to `antrakt92`
through Members. You choose the percentage, considering the extent and significance
of the reused work; there is no fixed minimum. One share covers all my projects
reused in it. No points earned means no payment. Personal income, donations and
other revenue are excluded. Permission applies automatically: no prior contact,
negotiation or approval is needed, and contacting me is optional. A pending Members
invitation awaiting my acceptance does not block permission.

See the [full license](LICENSE). This is the Antrakt Attribution and CurseForge
Rewards License 1.3, based on MIT with additional conditions; it is not the
standard MIT License. Earlier grants remain; this permission replaces my fixed-minimum
and separate-share requirements in all earlier custom versions with the same
self-selected positive share. Other earlier terms, MIT grants and third-party
rights remain unchanged.

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
