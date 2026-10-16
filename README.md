# DungeonPrep

Prepare your dungeon quests before entering: see what you already carry, follow
prerequisite quests and find the next available step.

**Early development build for WoW Forever. Quest coverage is incomplete.**
The catalogue has 29 dungeon entries; initial quest data covers The Deadmines,
Ragefire Chasm, The Hall of Thanes, Wailing Caverns, Shadowfang Keep,
Blackfathom Deeps, The Stockade and Gnomeregan.
Other entries explicitly show that their
quests have not been added. Level ranges are provisional recommendations.

## Current features

- Dungeon browser with level filtering and game-provided artwork when available.
- Character-specific completed, active, ready-to-turn-in, available, locked and
  unknown quest states, with explanations for level gates, missing prerequisites,
  character restrictions and unverified data.
- Recursive prerequisite planning: a final quest can lead you to the beginning
  of its unfinished chain, rather than another locked step.
- A next-step view collects the dungeon's preparation actions, combines shared
  prerequisites and groups pickups before entry, inside pickups, level gates,
  quests in progress and unresolved requirements.
- Switch between quests for your character and all character restrictions.
  Restricted quests stay available for inspection and do not add preparation
  actions. Character, level and preparation filters are remembered per character.
- Initial paladin and warlock quests are also listed for their associated
  dungeons, beyond the ordinary dungeon categories. Their preparation chains
  and some dungeon associations still need checking.
- Separate story order for chains whose hard prerequisites still need checking.
- Where prerequisites have alternatives, choose a branch or restore automatic
  planning. Choosing a route does not bypass requirements or confirm availability.
- World map, optional TomTom and a built-in direction arrow. The arrow points
  toward a coordinate; it does not find paths around terrain or plan transport.
- A separate quest-giver button opens a known zone or guides to a known location.
  Visiting a giver does not confirm that the quest is available to pick up.
- Quest text saved when you open the quest at its giver. Complete unseen quest
  descriptions and quest-giver portraits are not yet included.
- Item rewards and choices for the currently selected active quest, when the
  client provides them. Unknown reward data is shown explicitly.
- Quest objectives from the client appear when available. The window adjusts to
  screen width and height and recovers saved positions outside the visible area.
- Interface dictionaries for English, Russian, German, French, Spanish, Italian,
  Portuguese, Korean, Simplified Chinese and Traditional Chinese. enGB and esMX
  use English and Spanish. Translations and layout still need in-game review.
  Quest and NPC names follow the game client when available.

Unknown prerequisites or incomplete dungeon coverage never produce a green
preparation result. A quest listed in a storyline is not automatically treated
as a mandatory prerequisite.

## Try the development build

Build with `python scripts/package.py`. Extract the ZIP's `DungeonPrep` folder
into your **Forever client's** `Interface/AddOns` folder, then reload the UI.
This build has not yet passed native-client or visual acceptance.

- `/dprep` or `/dungeonprep`: open or close the browser.
- `/dprep clear`: clear the built-in guide.
- `/dprep probe`: save a small capability/quest-line report in this addon's own
  character settings. It does not export character identity or quest text.

The language button cycles through the interface languages. Search checks both
localized and English dungeon names. English A–Z matches ignore letter case;
other characters currently match exactly. Use the × button to clear the search.

## Contributing data

`data/catalog.json` is the source of quest facts. Every quest has a Forever source
link and an explicit `requirementsKnown` flag. Requirement groups are OR within a
group and AND between groups; `mode: active` means accepting a prerequisite is
enough, while the default requires completion. Storyline order is stored separately.
Never mark a requirement known solely because two quests appear next to each other.

Generate the runtime data with `python scripts/catalog.py`.
Run all local checks with `python scripts/check.py` (Python and Lua 5.1 required).
No package installation or network access is needed for those checks.
