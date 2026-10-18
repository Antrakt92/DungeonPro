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
  Search by dungeon, listed quest, recorded NPC or source place, or enter an exact
  quest ID. ID searches show only dungeons that directly list that quest. Matches identify
  the related quest on the dungeon card; View quest opens its details directly.
  Search includes bundled translated quest names and names already available from the client.
  NPC and place references keep their recorded language. An NPC match may be a
  quest giver, turn-in NPC or starter-item drop source; it does not confirm pickup
  availability.
  Search ignores letter case, including
  Cyrillic and accented Latin letters. Accents and spelling still matter; search
  does not normalize different Unicode spellings or transliterate names.
- A dark, restrained interface with distinct dungeon and quest selection accents,
  quieter controls and clearer text hierarchy. Visual refinement is ongoing.
- Selecting a dungeon opens an illustrated overview with its level range, listed
  quest count and coverage notice before you choose an individual quest.
  Supporting quest cards link directly to the dungeon quest they prepare.
  Returning to a quest restores your reading position when it is still available.
- Character-specific completed, active, ready-to-turn-in, available, locked and
  unknown quest states, with explanations for level gates, missing prerequisites,
  character restrictions and unverified data.
  Detail cards distinguish the recorded quest level from its minimum pickup level,
  and show listed class limits. Race does not filter or block dungeon quests.
  Level alone does not confirm availability.
  Quests in progress and ready to turn in use familiar quest icons when available.
- Recursive prerequisite planning where acceptance conditions are verified;
  unverified chains remain available for inspection.
  View any alternative quest separately without changing your preferred branch.
  Known prerequisite work can still be shown while other conditions are unknown.
- Each quest card shows its giver and known prerequisites before other details.
  Inspect supporting quests without changing the dungeon target. Long related
  story lists have a short preview and can be expanded separately.
- Hover the language button (globe and language code) in the top corner to open the language menu.
  Hover a language to preview immediately, click to save, or move away to cancel.
- Switch between quests for your character and all character restrictions.
  Restricted quests stay available for inspection and do not add preparation
  actions. Character and level filters are remembered per character.
  Restricted rows identify the recorded faction and class instead of only
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
  The planner stays open; move its window if it covers the quest log.
- Explicitly sourced repeatable quests have their own label.
- Where prerequisites have alternatives, choose a branch or restore automatic
  planning. Choosing a route does not bypass requirements or confirm availability.
- World map, optional TomTom and a built-in direction arrow. The arrow points
  toward a coordinate; it does not find paths around terrain or plan transport.
- Browse compact quest rows with status icons and cached item reward previews.
  Hover over a reward icon for the game's item tooltip with its statistics,
  followed by known guaranteed rewards and choices where you pick one.
  A +N mark indicates additional items.
  Search sits on the right of the header, beside the language selector.
  The level tab beside the app title filters the dungeon catalogue. The larger
  quest filter beside the dungeon heading switches between your character's
  quests and all quests, using a portrait or list symbol and a short mode label.
  Hover for the current mode and click to switch.
  The message and heart icons offer issue-report and project-support links for copying.
  Quest-log occupancy sits in the top bar; navigation and Wowhead actions sit
  beside the quest title and scroll with the details.
  Select a quest to expand its related steps in place, then select any step to
  read its details without losing the opened list. Completed steps remain visible.
  A faction crest follows faction-specific quest names. A chevron identifies
  expandable quest chains and changes direction while their steps are open.
  Indented branches connect to their target; inside an expanded branch, a map
  badge identifies quests listed for the selected dungeon.
  The target stays at its recorded story position and has a dungeon label.
  Highlighted connectors show its earlier steps; this does not turn story order
  into required prerequisites. Same-named steps show their quest IDs.
  Quest icons show journal progress and completion; hover for the status reason.
  Required prerequisites and source-listed story quests are labelled separately.
  The detail pane keeps the giver, objectives and rewards together with compact
  level information. Story text has its own reading section; long passages expand
  on demand. More details opens full conditions, availability notes and references.
- When available, follow the game's next waypoint for a quest in your log.
  It may mark a route point, an entrance or a turn-in. Quest-giver locations
  and preparation steps remain separate.
- The quest icon opens the giver's known zone or guides to a known location.
  Known coordinates appear as a Dungeon Pro marker on the map, even without native waypoint support.
  The Wowhead icon offers the quest link for copying. Hover over either icon
  for its action description.
  Visiting a giver does not confirm that the quest is available to pick up.
  The quest icon always refers to the selected quest's giver.
  Alternative givers have separate actions; missing coordinates are explained.
  A low-level character can still visit a known giver without treating the quest
  as available. The planner stays open; move it if it covers the map.
  Viewing a location or expanding its choices does not start a guide.
- A map-pin icon on each dungeon card starts its entrance route without changing
  the quest you are reading. Hover for the destination and source details.
  A separate quest icon summarizes listed quests for your current character:
  ready to turn in, available, in progress, blocked or unconfirmed. Red means
  all remaining listed quests need more levels; a green check means all matching
  listed quests are completed. Hover for the meaning and scope.
  Matching client portal points are preferred, with recorded locations as a fallback.
  Recorded locations, shared entrances and outside approaches are labelled separately;
  missing or ambiguous destinations stay unavailable.
- Expand reported positions when a giver has several sourced points, then choose
  a point to visit. Movement and quest phases may affect which position is current.
- Original quest text is saved when you open its quest offer, including
  item-started offers. Complete unseen quest descriptions are not yet included.
- Text from the current progress or turn-in conversation appears separately
  while its matching quest dialogue is open. It does not replace the saved original
  description or mark the quest completed.
- Optional quest portraits from the current offer or selected quest log entry,
  when supplied by the client.
- Known single-NPC quest starters can also show their own giver portrait using
  client models. The appearance is a reference and may differ by quest phase.
  A ready quest can instead show its known distinct turn-in NPC, with a separate
  caption. Missing or ambiguous finish portraits keep any known starter portrait.
- Item rewards, choices and experience for the currently selected active quest,
  when the client provides them. Unknown reward data is shown explicitly.
- Reward previews for other quests when the client confirms their reward data
  is loaded. Visible lists make a bounded preload attempt when supported;
  missing data stays unknown.
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
  Dungeon and quest names follow the selected language where a verified title is
  available. Missing translations retain their source names. Item names follow
  the game client. The current NPC can also use its localized name; other
  quest-giver names use the source catalogue.

Unknown prerequisites or incomplete dungeon coverage never produce a green
preparation result. A quest listed in a storyline is not automatically treated
as a mandatory prerequisite.

## Try the development build

Build with `python scripts/package.py`. Extract the ZIP's `DungeonPro` folder
into your **Forever client's** `Interface/AddOns` folder, then reload the UI.
This build has not yet passed native-client or visual acceptance.

- `/DP` or `/DungeonPro`: open or close the browser.
- `/DP clear`: clear the guide and its map or TomTom waypoint.
- `/DP minimap`: hide or show the minimap button.
- `/DP minimap reset`: show the button at its default position.
- `/DP probe`: save a small capability/quest-line report in this addon's own
  character settings. It does not export character identity or quest text.
- `/DP probe nav`: print a visibility and geometry sample for the guide, browser
  and world map in chat, plus the shown map's stored ID. Coordinates use UI units;
  unavailable values show `unknown`.
- `/DP probe minimap`: print whether the existing launcher and minimap are shown,
  their geometry and the saved hide preference, without changing settings.
- `/rl`: reload the interface, like `/reload`.

Development aliases `/dprep` and `/dungeonprep` are also supported.
Run `/DP minimap` again to restore a hidden button. `reset` only returns it to
its default position and makes it visible.

The language button shows the current interface language. Hover over it to open
its menu, then hover over a language to preview the interface. Click to save the
choice; leaving the menu restores your saved language. The automatic option
follows the game language. Search checks localized and English dungeon
names, listed quests, and recorded NPCs and source places. Enter a quest ID such as
`166` to find its listed dungeons without matching similarly numbered quests or
supporting chain steps. It ignores letter case,
including Cyrillic and accented Latin letters; accents and spelling still matter.
Results update after a short pause in typing. Press Enter to apply the current
search immediately, or use the × button to clear it. A different search starts
at the top of its results; refreshing the same search keeps your place.

## Contributing data

`data/catalog.json` is the source of quest facts. Every quest has a Forever source
link and an explicit `requirementsKnown` flag. Requirement groups are OR within a
group and AND between groups; `mode: active` means accepting a prerequisite is
enough, while the default requires completion. Storyline order is stored separately.
Never mark a requirement known solely because two quests appear next to each other.

Generate the runtime data with `python scripts/catalog.py`.
Run all local checks with `python scripts/check.py` (Python and Lua 5.1 required).
No package installation or network access is needed for those checks.

Noto Sans is included under the SIL Open Font License, Version 1.1.
See Media/Fonts/OFL.txt and Media/Fonts/NOTICE.txt for its license and attribution.
