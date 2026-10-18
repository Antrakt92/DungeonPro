# Dungeon Pro

Prepare your dungeon quests before entering: check your quest progress, follow
known prerequisites and find the next step.

**0.1.0 Beta for WoW Forever.** The catalogue includes 29 dungeon entries,
including classic dungeons and new Forever locations. Coverage is incomplete;
unknown requirements and missing locations are shown explicitly.

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

## Install

Download the ZIP from [GitHub Releases](https://github.com/Antrakt92/DungeonPro/releases)
or [CurseForge](https://www.curseforge.com/wow/addons/dungeon-pro). Extract its `DungeonPro` folder into
your **Forever client's** `Interface/AddOns` folder, then reload the interface.
TomTom is optional.

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

## Beta limitations

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
Include the quest or dungeon, your interface language and a screenshot when useful.

## Development and data

Quest facts are stored in `data/catalog.json`. Every quest has a Forever source
link and an explicit `requirementsKnown` flag. Story order is separate from
prerequisites: appearing next to another quest does not establish a requirement.

Generate runtime data with `python scripts/catalog.py`, run local checks with
`python scripts/check.py` (Python and Lua 5.1), and build a ZIP with
`python scripts/package.py`. Checks and packaging need no network access.

The addon is all rights reserved; official downloads may be installed and used
under [LICENSE](LICENSE). Noto Sans has its own SIL Open Font License, and Unicode
data retains its separate notice. See `Media/Fonts/`, `Media/Icons/NOTICE.txt` and
`Database/SearchCaseFold.lua` for third-party attribution.
