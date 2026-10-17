# Dungeon Pro

Prepare your dungeon quests before entering: see what you already carry, follow
prerequisite quests and find the next available step.

**Early development build for WoW Forever. Quest coverage is incomplete.**
The catalogue has 29 dungeon entries, including classic and new Forever dungeons.
Quest lists and preparation chains are still being reviewed. Entries without
quest data say so explicitly, and incomplete coverage stays visible in game.
Level ranges are provisional recommendations.

## Current features

- Dungeon browser with level filtering and native loading artwork for 24 entries,
  including Hall of Thanes, Ruins of Lordaeron, Excavation Site and City of Dalaran.
  Blackrock Spire wings share their instance's image. Five newer entries still
  need verified artwork; missing client images keep a fallback icon.
  Search by dungeon name or a listed quest name. Quest matches identify the
  matching quest on the dungeon card. Localized quest names are included when
  already available from the client. Search ignores letter case, including
  Cyrillic and accented Latin letters. Accents and spelling still matter; search
  does not normalize different Unicode spellings or transliterate names.
- A dark, restrained interface with distinct dungeon and quest selection accents,
  quieter controls and clearer text hierarchy. Visual refinement is ongoing.
- Selecting a dungeon opens an illustrated overview with its level range, listed
  quest count and coverage notice before you choose an individual quest.
  Back retraces supporting quests, then returns to the selected dungeon's overview.
  Returning to a quest restores your reading position when it is still available.
- Character-specific completed, active, ready-to-turn-in, available, locked and
  unknown quest states, with explanations for level gates, missing prerequisites,
  character restrictions and unverified data.
  Detail cards show the recorded minimum level and any listed class/race limits.
  Quests in progress and ready to turn in use familiar quest icons when available.
- Recursive prerequisite planning where acceptance conditions are verified;
  unverified chains remain available for inspection.
  View any alternative quest separately without changing your preferred branch.
  Known prerequisite work can still be shown while other conditions are unknown.
- A next-step view collects the dungeon's preparation actions, combines shared
  prerequisites and groups pickups before entry, inside pickups, level gates,
  quests in progress and unresolved requirements.
  A quest card lets you choose which independent next step to show on the map or
  follow with the guide, and inspect its quest without changing the target.
- Switch between quests for your character and all character restrictions.
  Restricted quests stay available for inspection and do not add preparation
  actions. Character, level and preparation filters are remembered per character.
  Restricted rows identify the recorded faction, class and race instead of only
  saying that a quest is not for your character.
- Initial paladin and warlock quests are also listed for their associated
  dungeons, beyond the ordinary dungeon categories. Their preparation chains
  and some dungeon associations still need checking.
- Separate story order and shared story groups for chains whose hard
  prerequisites still need checking.
  Long story lists start compact and expand to show their quests. Known
  prerequisites and preparation actions stay visible independently.
- Item-started quests show the known item and drop dungeon separately, including
  quests whose starter drops in a different dungeon. Multiple starting NPCs,
  objects or item-drop sources stay visible separately; a location visit does
  not confirm that your character can accept the quest there.
  Known item containers have separate location rows, including reported points.
  Mapped drop creatures also have explicit visit choices; expand their reported
  positions to choose a point without treating a drop source as the quest giver.
- Related quests for completion materials appear separately from acceptance
  requirements. Their completion does not confirm you still hold the item.
- Starter and material items show a current carried count when the client
  provides it, excluding bank storage. Possession does not confirm quest eligibility.
- Sourced objective items show confirmed quantities; an unverified amount is
  labeled explicitly. Current carried counts appear separately from these
  reference objectives and do not replace objectives reported by the game.
- Sourced creature objectives show the listed targets and any verified counts
  before pickup, separately from objectives reported by the game.
- Other sourced tasks, including event and discovery objectives or burning
  remains, share a separate reference section. Event tasks are distinct from
  kill objectives. Objectives reported by the game appear separately.
- Items supplied by a quest have their own section. They may already have been
  used or consumed, so an empty bag count does not mean preparation has failed.
  Starter, collection and supplied items can show native icons and hover tooltips;
  unavailable images leave their names and quantities visible.
- Known quest payments are listed separately from rewards. Payments reported
  for quests in your log have their own label, alongside any source reference.
  These amounts do not determine whether you can accept a quest.
- The window shows current quest-log occupancy and the client-provided standard
  quest limit when available, separately from dungeon preparation status.
  A held quest can be opened in the native quest log from its detail card when
  the client provides the action. Opening it changes the selected native quest.
- Explicitly sourced repeatable quests have their own label.
- Where prerequisites have alternatives, choose a branch or restore automatic
  planning. Choosing a route does not bypass requirements or confirm availability.
- World map, optional TomTom and a built-in direction arrow. The arrow points
  toward a coordinate; it does not find paths around terrain or plan transport.
- When available, follow the game's next waypoint for a quest in your log.
  It may mark a route point, an entrance or a turn-in. Quest-giver locations
  and preparation steps remain separate.
- A separate quest-giver button opens a known zone or guides to a known location.
  Visiting a giver does not confirm that the quest is available to pick up.
- Expand reported positions when a giver has several sourced points, then choose
  a point to visit. Movement and quest phases may affect which position is current.
- Quest text saved when you open the quest at its giver. Complete unseen quest
  descriptions are not yet included.
- Optional quest portraits from the current offer or selected quest log entry,
  when supplied by the client.
- Known single-NPC quest starters can also show their own giver portrait using
  client models. The appearance is a reference and may differ by quest phase.
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
  objectives reported by the game. It clears when that dialogue ends.
- Quest objectives from the client appear when available. The window adjusts to
  screen width and height and recovers saved positions outside the visible area.
- The floating guide keeps its quest and destination visible when your position
  is unavailable. Its arrow gives a bearing, rather than a route around obstacles.
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
Run `/DP minimap` again to restore a hidden button. `reset` only returns it to
its default position and makes it visible.

The language button opens a menu of interface languages, with an automatic option
that follows the game language. If the client menu is unavailable, clicking the
button cycles through the choices. Search checks both
localized and English dungeon names without distinguishing letter case, including
Cyrillic and accented Latin letters. Accents and spelling still matter. Use the ×
button to clear the search.

## Contributing data

`data/catalog.json` is the source of quest facts. Every quest has a Forever source
link and an explicit `requirementsKnown` flag. Requirement groups are OR within a
group and AND between groups; `mode: active` means accepting a prerequisite is
enough, while the default requires completion. Storyline order is stored separately.
Never mark a requirement known solely because two quests appear next to each other.

Generate the runtime data with `python scripts/catalog.py`.
Run all local checks with `python scripts/check.py` (Python and Lua 5.1 required).
No package installation or network access is needed for those checks.
