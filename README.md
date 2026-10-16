# Dungeon Pro

Prepare your dungeon quests before entering: see what you already carry, follow
prerequisite quests and find the next available step.

**Early development build for WoW Forever. Quest coverage is incomplete.**
The catalogue has 29 dungeon entries, including classic and new Forever dungeons.
Quest lists and preparation chains are still being reviewed. Entries without
quest data say so explicitly, and incomplete coverage stays visible in game.
Level ranges are provisional recommendations.

## Current features

- Dungeon browser with level filtering and game-provided artwork when available.
  A built-in finder image can be used when the client identifies the same dungeon
  map unambiguously; missing artwork keeps the map icon.
- Character-specific completed, active, ready-to-turn-in, available, locked and
  unknown quest states, with explanations for level gates, missing prerequisites,
  character restrictions and unverified data.
  Detail cards show the recorded minimum level and any listed class/race limits.
- Recursive prerequisite planning where acceptance conditions are verified;
  unverified chains remain available for inspection.
  Known prerequisite work can still be shown while other conditions are unknown.
- A next-step view collects the dungeon's preparation actions, combines shared
  prerequisites and groups pickups before entry, inside pickups, level gates,
  quests in progress and unresolved requirements.
- Switch between quests for your character and all character restrictions.
  Restricted quests stay available for inspection and do not add preparation
  actions. Character, level and preparation filters are remembered per character.
- Initial paladin and warlock quests are also listed for their associated
  dungeons, beyond the ordinary dungeon categories. Their preparation chains
  and some dungeon associations still need checking.
- Separate story order and shared story groups for chains whose hard
  prerequisites still need checking.
- Item-started quests show the known item and drop dungeon separately, including
  quests whose starter drops in a different dungeon. Multiple starting NPCs,
  objects or item-drop sources stay visible separately; a location visit does
  not confirm that your character can accept the quest there.
  Known item containers have separate location rows, including reported points.
- Related quests for completion materials appear separately from acceptance
  requirements. Their completion does not confirm you still hold the item.
- Starter and material items show a current carried count when the client
  provides it, excluding bank storage. Possession does not confirm quest eligibility.
- Sourced objective items show their required quantities and current carried
  counts separately. These are reference amounts, not quest-log progress.
- The window shows current quest-log occupancy and the client-provided standard
  quest limit when available, separately from dungeon preparation status.
- Explicitly sourced repeatable quests have their own label.
- Where prerequisites have alternatives, choose a branch or restore automatic
  planning. Choosing a route does not bypass requirements or confirm availability.
- World map, optional TomTom and a built-in direction arrow. The arrow points
  toward a coordinate; it does not find paths around terrain or plan transport.
- A separate quest-giver button opens a known zone or guides to a known location.
  Visiting a giver does not confirm that the quest is available to pick up.
- Expand reported positions when a giver has several sourced points, then choose
  a point to visit. Movement and quest phases may affect which position is current.
- Quest text saved when you open the quest at its giver. Complete unseen quest
  descriptions and verified quest-giver portraits are not yet included.
- Optional quest portraits from the current offer or selected quest log entry,
  when supplied by the client. These are journal portraits, not verified
  photographs of each NPC.
- Item rewards and choices for the currently selected active quest, when the
  client provides them. Unknown reward data is shown explicitly.
- Reward previews for other quests when the client confirms their reward data
  is already loaded. Missing data stays unknown.
- Reward items use native icons and item-ID hover tooltips when available.
  Missing icon or tooltip data leaves the reward text visible.
- A separate note shows a quest observed in the current NPC dialogue. It expires
  and does not replace prerequisite or availability checks.
- Rewards, choices, money and experience from the quest dialogue while you
  view an offer, including quests started by an item.
- A quest's objective summary from the open offer appears separately from
  quest-log progress. It clears when that dialogue ends.
- Quest objectives from the client appear when available. The window adjusts to
  screen width and height and recovers saved positions outside the visible area.
- A minimap button opens the browser. Drag it around the minimap to reposition it.
- Interface dictionaries for English, Russian, German, French, Spanish, Italian,
  Portuguese, Korean, Simplified Chinese and Traditional Chinese. enGB and esMX
  use English and Spanish. Translations and layout still need in-game review.
  Quest and item names use client data when available. The current NPC can also
  use its localized name; other quest-giver names use the source catalogue.

Unknown prerequisites or incomplete dungeon coverage never produce a green
preparation result. A quest listed in a storyline is not automatically treated
as a mandatory prerequisite.

## Try the development build

Build with `python scripts/package.py`. Extract the ZIP's `DungeonPro` folder
into your **Forever client's** `Interface/AddOns` folder, then reload the UI.
This build has not yet passed native-client or visual acceptance.

- `/DP` or `/DungeonPro`: open or close the browser.
- `/DP clear`: clear the built-in guide.
- `/DP minimap`: hide or show the minimap button.
- `/DP minimap reset`: show the button at its default position.
- `/DP probe`: save a small capability/quest-line report in this addon's own
  character settings. It does not export character identity or quest text.
- `/rl`: reload the interface, like `/reload`.

Development aliases `/dprep` and `/dungeonprep` are also supported.

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
