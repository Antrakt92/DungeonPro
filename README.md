<p align="center">
  <img src="https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/Media/Branding/Logo.png" alt="Dungeon Pro logo" width="112" height="112">
</p>

<h1 align="center">Dungeon Pro</h1>

Prepare your dungeon quests before entering: check your quest progress, follow
known prerequisites and find the next step.

[Download the Forever beta](https://github.com/Antrakt92/DungeonPro/releases)
· [CurseForge](https://www.curseforge.com/wow/addons/dungeon-pro)
· [Report a problem](https://github.com/Antrakt92/DungeonPro/issues)

**0.1.0 Beta for WoW Forever.** The catalogue includes 29 dungeon entries,
including classic dungeons and new Forever locations. Coverage is incomplete;
unknown requirements and missing locations are shown explicitly.

![Dungeon browser with character quest filtering and a Wailing Caverns overview](https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/screenshots/dungeon-browser.png)

## Features

- Browse illustrated dungeon cards, filter by level and switch between quests
  for your character and all quests. Counts include main listed quests, not
  expanded story steps.
- Search by dungeon, quest, recorded NPC or source place. Enter an exact quest ID
  to find dungeons that directly list it.
- See completed, active, ready, available, locked and unknown quest states, with
  explanations for level, faction, class and prerequisite restrictions.
- Expand prerequisite chains and related story steps in the quest list. Story
  order stays separate from confirmed acceptance requirements.
- Read objectives, starter items, supplied items, known payments and rewards.
  Reward choices and guaranteed items are separate; native item tooltips and
  carried counts appear when the client provides them.
- Inspect each known NPC, object or starter-item source. Unknown locations are
  highlighted; alternative sources and reported positions remain manual choices.
  Item-created objects show their known summoning item instead of a guessed route.
- Open known maps or follow a coordinate with the built-in direction arrow and
  optional TomTom support. Dungeon entrance and quest-giver actions are separate.
- Choose from ten interface languages, preview them on hover and click to save.
  Dungeon and quest titles follow that selection; item names and live quest text
  follow the game client.

<details>
<summary>Quest chains, objectives and rewards in game</summary>

![Expanded Deadmines quest chain with quest-giver location, objectives and rewards](https://raw.githubusercontent.com/Antrakt92/DungeonPro/main/screenshots/quest-chain.png)

</details>

## Install

Download the ZIP from [GitHub Releases](https://github.com/Antrakt92/DungeonPro/releases)
or [CurseForge](https://www.curseforge.com/wow/addons/dungeon-pro). Choose the file
labelled **Forever**. On GitHub, download `DungeonPro-0.1.0-Forever.zip` from the
release's **Assets**, rather than the automatic **Source code** ZIP.

Extract its `DungeonPro` folder into your **Forever client's** `Interface/AddOns`
folder, then reload the interface. The TOC should be at
`Interface/AddOns/DungeonPro/DungeonPro.toc`. TomTom is optional; Retail and other
Classic branches are not supported by this build.

Open Dungeon Pro with its minimap button or `/DP`. Select a dungeon, then a quest
or related step. Hover navigation icons for the destination or the reason an
action is unavailable. Clicking a location does not accept a quest.

## Commands

- `/DP` or `/DungeonPro`: open or close the browser.
- `/DP clear`: clear the current guide and its owned waypoint.
- `/DP minimap`: hide or show the minimap button.
- `/DP minimap reset`: show the button at its default position.
- `/rl`: reload the interface, like `/reload`.

Drag the minimap button to reposition it. The language button opens its menu on
hover; hover a language to preview, click to save, or leave to restore your saved
choice. Automatic follows the game language. English, Russian, German, French,
Spanish, Italian, Portuguese, Korean, Simplified Chinese and Traditional Chinese
are supported; enGB and esMX use English and Spanish.

## An early beta, with more to come

This is one of Dungeon Pro's first public betas. My goal is to make it one of the
best addons for dungeon quests: clear information, useful guidance and an
interface that feels easy to use. I plan to keep adding and correcting data,
fixing bugs and improving the way you interact with the addon.

Many quest details are still missing because reliable information has not been
found or verified yet. The visuals and interactions are also being refined, so
expect rough edges and changes between updates. Reports of missing data, bugs or
confusing controls help me decide what to improve next.

### Current limitations

- Dungeon coverage, source locations and acceptance requirements are still being
  reviewed. Unknown requirements never produce a green preparation result.
  Listed level ranges are provisional recommendations.
- Quest availability can depend on conditions the catalogue cannot verify.
  Visiting a source, carrying an item or meeting the level requirement does not
  confirm that a quest is available.
- Missing quantities stay unknown. Quest rewards and carried counts depend on
  data available from the client; an unavailable count is not treated as zero.
- Original quest descriptions are saved when you open their offers. Complete
  descriptions for unseen quests are not bundled.
- The direction arrow gives a bearing, not a path around terrain or transport.
  Reported positions may depend on movement or quest phase.
- Some newer dungeons lack verified artwork. Interface translations and layout
  will continue to improve with player feedback.

Report problems through [GitHub Issues](https://github.com/Antrakt92/DungeonPro/issues).
Include the quest name or ID, dungeon, addon version, your interface language and
a screenshot when useful. Do not upload account details or unedited character
settings files.

## Development

See the [development guide](https://github.com/Antrakt92/DungeonPro/blob/main/DEVELOPMENT.md)
for source data, local checks and development packaging. Players only need the
release ZIP.

## License and credits

The addon is all rights reserved; official downloads may be installed and used
under [LICENSE](LICENSE). Noto Sans has its own SIL Open Font License, and Unicode
data retains its separate notice. See `Media/Fonts/`, `Media/Icons/NOTICE.txt` and
`Database/SearchCaseFold.lua` for third-party attribution.

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
