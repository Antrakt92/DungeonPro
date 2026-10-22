# Changelog

## 0.3.1 - 22-Oct-2026 — Compact quest contacts Beta

### Quest contacts and layout

- Replace tall pickup and turn-in contact rows with compact buttons beside the
  faction information: an exclamation mark for pickup and a question mark for
  turn-in.
- Keep both buttons together at the right edge of the detail pane and remove
  the extra height previously reserved in the faction row.
- Show the contact name, known location and purpose in each button's tooltip,
  including when its exact location is unavailable and directions are disabled.
- Preserve separate pickup and turn-in destinations, alternative locations and
  the selected quest when opening source information.

### Quest-starting items

- Move known starter-item acquisition information beside the item, before
  rewards, so recorded drops and other sources are easier to find.
- Include the starter item and its known acquisition sources in the book
  inspection tooltip. Item drops remain distinct from NPC quest givers.
- Remove the generic item-requirements notice and omit an item minimum level
  when the quest already shows an equal or higher minimum. Stricter item levels
  and recorded class restrictions remain visible.
- Use consistent pickup classification across the preparation list, overview
  and contact actions, including item starts with alternative sources.

### Localization and stability

- Use localized NPC and place names in pickup descriptions and source labels.
- Reduce repeated hover updates in the language menu.
- Treat a zero portrait ID as unavailable and accept valid journal artwork
  returned as a texture path.
- Keep other interface refresh listeners running when one callback fails, and
  prevent listener changes from disrupting an update already in progress.
- Validate quest-history and portrait identifiers more strictly.

### Development checks

- Run independent Lua suites in isolated processes, automatically choosing up
  to four workers, with sequential execution still available for diagnosis.
- Add timing reports and regression coverage for worker limits, argument
  preservation, failures and interrupted runs.
- Strengthen catalogue bounds and source validation, version
  alignment, runtime-file membership and deterministic archive checks.
- Keep verification tools, tests and caches out of the installable addon.

This remains an early beta. Quest coverage, requirements and some locations are
incomplete. Unseen quest text depends on what the game client can provide;
interior dungeon maps are not included.

## 0.3.0 - 20-Oct-2026 — Quest details Beta

### New quests and catalogue updates

- Add six quest records, expanding the catalogue from 571 to 577 quests,
  including supporting preparation and story steps.
- Razorfen Kraul: add Fire Hardened Mail for Alliance warriors and Brutal Armor
  for Horde warriors, with recorded materials and quest-provided instructions.
- Uldaman: add the repeatable Indurium Ore quest, its four-ore objective and the
  recorded Indurium Mineral Vein source.
- Stratholme: add Sweet Serenity and Corruption, with blacksmithing labels and
  their recorded objective items.
- Stratholme: add Atiesh, Greatstaff of the Guardian and its cleansing event.
  Unverified acquisition requirements remain explicitly marked.
- Update 216 existing quest records, mainly pickup and turn-in contacts, NPC
  references and alternative locations; also expand recorded item sources and
  clarify supporting story relationships.
- Add reviewed giver portraits and recorded source locations for more quests.
- Extend translated quest titles for the newly added records.

### Scarlet Monastery wings

- Replace the single monastery card with Graveyard, Library, Armory and Cathedral.
- Graveyard: list Vorrel's Revenge.
- Library: list Mythology of the Titans, Test of Lore, Rituals of Power and
  Compendium of the Fallen.
- List Into The Scarlet Monastery and In the Name of the Light in Library,
  Armory and Cathedral because their objectives span those wings.
- Keep the monastery-wide quest index available separately, including Past Due
  and Hearts of Zeal, whose exact wing assignments remain unverified.
- Label assignments drawn from the Classic baseline. These are redistributed
  existing monastery quests, not additional new quest records or a claim of
  complete Forever coverage.

### Quest details and interface

- Read selected quest details in one stream, with objectives, items, rewards and
  practical source information before available quest text.
- Refresh the right pane with larger headings, highlighted objectives and clearer
  contact cards.
- Use separate pickup and turn-in contact rows, including recorded alternative
  locations and explanations when exact positions are missing.
- Keep quest selection in the middle list. Until a quest is selected, show only
  the dungeon illustration on the right, without a repeated title or prompt.
- Improve navigation and reading-position restoration when switching quests or
  changing filters.

### Filtering and navigation

- Apply the My Quests filter to expanded chains as well as the main quest list,
  while keeping quests already in your log visible.
- Hide foreign-faction and other known ineligible chain steps in My Quests;
  retain All quests for inspecting those alternatives without enabling them.
- Distinguish quest pickups, turn-ins and dungeon entrances with map icons.
- Keep pickup and turn-in destinations distinct, including when one NPC has
  different recorded locations.

### Reuse terms

- Update reuse terms: derivative authors choose a positive CurseForge reward
  share, with no fixed minimum.

This remains an early beta. Quest coverage, requirements and some locations are
incomplete. Unseen quest text depends on what the game client can provide;
interior dungeon maps are not included.

## 0.2.0 - 19-Oct-2026 — Quest planning and navigation Beta

- Organize quest details into Quest, Sources and Story tabs, with a visible back
  arrow that restores the previous quest, tab and reading position.
- Collapse the dungeon catalogue to give long quest chains more room.
- Show dungeon quest progress and relevant steps from your quest log. Ready
  turn-ins appear first; supporting steps are labelled separately. Expand or
  collapse longer lists, with gold ready statuses and blue in-progress statuses.
- Find more quests by recorded NPCs, places and objective enemies, including
  related chain steps. Add reviewed translations for source names and locations.
- Keep known prerequisites distinct from story steps and show useful actions for
  prerequisites already in your quest log or ready to turn in.
- Improve refresh, navigation and window cleanup so older updates do not replace
  the current quest, artwork, waypoint, copied link or reading position.
- Hide the experimental interior-map button: working Forever dungeon maps are
  not included. Known quest-location and dungeon-entrance directions remain.

This remains an early beta. Quest coverage and requirements are incomplete;
missing locations and conditions stay explicit. Unseen quest text depends on
what the client can supply. More data fixes and interface improvements will follow.

### 19-Oct-2026

- Hide the experimental dungeon-map button until interior maps work in Forever.
- Ignore dungeon-map controls when their action handlers change during validation.
- Highlight ready turn-ins in gold and in-progress steps in blue in the dungeon overview.
- Avoid retaining old quest-reading state after switching views or closing the planner.
- Expand quest-log steps in the dungeon overview in groups of six, or collapse them.
- Keep the back arrow anchored when quest details change during layout.
- Prevent an earlier map request from reopening an old area or hiding the newer quest marker.
- Add a back arrow beside quest tabs to revisit a previous quest or the dungeon overview.
- Keep the newer quest waypoint when an earlier guide finishes validating.
- Match filter tooltips and empty-list guidance to the Mine and All quests buttons.
- Show ready turn-ins before unfinished quests in the dungeon overview.
- Discard navigation diagnostic snapshots if their source changes during formatting.
- Label supporting quests separately in the dungeon overview without adding them to the main quest counts.
- Keep dungeon artwork aligned when the selected dungeon changes during a refresh.
- Prevent an older dungeon illustration from appearing over newer quest details.
- Keep the current dungeon artwork and map button when switching dungeons.
- Avoid retaining previous quest material details after switching quests.
- Keep newly shown quest portraits when an older refresh finishes.
- Preserve the turn-in arrow position when changing ready quests.
- Keep the quest-giver button and its destination in sync when changing quests.
- Keep source rows aligned when a quest changes during layout.
- Release obsolete turn-in navigation contexts after changing quests.
- Release retired quest-source callbacks and keep current source controls intact during refreshes.
- Release obsolete quest-detail text contexts after changing quests or closing the planner.
- Avoid repeating bag counts for quest-starting items also supplied by the quest.
- Explain missing exact positions for known turn-in sources.
- Release obsolete dungeon overview state when leaving or closing the map control.
- Show listed quest progress and known next steps above dungeon overview artwork.
- Keep the current copied link and keyboard focus when older close actions finish.
- Keep newly displayed reward and objective icons when an older refresh finishes.
- Preserve reopened quest details when an older window close finishes.
- Cancel catalogue clicks when the planner closes or a newer selection takes over.
- Ignore stale entrance clicks if the selected view changes during validation.
- Find quests by recorded enemy objective names, including related steps.
- Free unused map data after changing floors or closing the map, while keeping
  the current map and reused controls intact.
- Release unused quest-list calculations when changing dungeons or returning
  to the overview, preserving the current selection and controls.
- Reduce repeated work when quest or item details load, keeping search results
  and the selected dungeon in sync.
- Find reviewed Chinese NPC names with either common middle-dot separator,
  preserving their original spelling on screen.
- Release obsolete dungeon status calculations after a new search while keeping
  current results and reused controls intact.
- Add reviewed name translations for Deliana, Mokvar, Lorekeeper Lydros,
  Archmage Xylem and Alba Fairmoon in quest details, source search and guidance.
- Keep unchanged search results while quest or item details load, rebuilding when
  matching names, sources or character state change.
- Release snapshots from previous searches while keeping current results and
  reused controls intact.
- Keep search-result quest captions in the selected language when searching by
  original quest names, NPCs or places.
- Find dungeons by recorded NPCs and places in prerequisite or story steps,
  with a clear related-step label and a link to inspect the matching quest.
- Match map controls to the planner's button style and dim unavailable floor
  directions so they are easier to distinguish from active controls.
- Keep the quest list selection in sync when returning to a previous quest or
  the dungeon overview, while preserving the previous tab and reading position.
- Add a dungeon map view with floor controls when the game client supplies a
  verified map; unavailable maps have an explicit retry and return action.
- Translate Westfall into Russian consistently across quest locations and guidance.
- Expand reviewed NPC name translations in quest details, search and guidance.
- Show reviewed world-area translations in quest locations, search and guidance.
- Find quests by reviewed translated source names as well as their original names.
- Show selected-language names for reviewed quest-starting objects in details
  and navigation guidance.
- Organize quest details into Quest, Sources and Story tabs, with separate
  reading positions and a return to the previous view when going back.
- Let the dungeon list collapse to give quest names and expanded chains more
  room; searching reveals the catalogue again.
- Show an inspect link when a known prerequisite is already in the quest log
  or ready to turn in, while preserving unknown requirements on the target.
- Add a compact navigation action for a ready quest's distinct, known turn-in
  point, keeping it separate from the pickup location.

### 18-Oct-2026

- Explain when a long quest-chain preview reaches its display limit.
- Keep live quest progress prominent and make recorded kill, object and event
  objectives available through a compact inline disclosure.
- Match pasted curly apostrophes and common non-breaking or ideographic spaces
  in text searches without changing displayed names or exact quest-ID syntax.
- Label expanded quest-chain rows as dungeon targets, known prerequisites or
  story steps, while keeping alternative requirements and incomplete data distinct.
- Find quests by recorded containers that supply objective items, including the
  tools for Blueleaf Tubers in Razorfen Kraul.
- Separate navigation controls from the main window module while preserving
  existing quest-giver, entrance and source-inspection behavior.
- Keep reward loading moving through the whole quest list when item arrivals
  trigger frequent updates, instead of repeatedly restarting at the first rows.
- Find quests by source areas recorded on their reported locations, including
  Thunder Bluff pickups for Wailing Caverns preparation.

## 0.1.0 - 18-Oct-2026 — First public Beta

The first public beta brings dungeon quest browsing, prerequisite planning,
character quest states, rewards and navigation to WoW Forever. Quest coverage
and acceptance requirements remain incomplete; missing information is shown
explicitly.

### 18-Oct-2026 — Player-feedback fixes, data review and first public beta

- Refined the header, search placement, dungeon-card artwork and spacing. Replaced
  the menu-like All control with a plain All quests toggle and made dungeon
  counts follow Mine / All in both cards and overviews.
- Simplified quest details and separated story reading from objectives. Added
  complete reward-choice previews, native item tooltips and uncached-item loading;
  fixed money rewards when the legacy coin formatter is unavailable.
- Made quest-giver navigation a compact gold action in details and quest rows,
  added direct dungeon navigation and highlighted unknown giver locations with
  explanations. Kept item starters distinct from missing NPC coordinates.
- Colored quest and required levels relative to the current character and added
  class icons beside faction crests in quest rows.
- Completed selected-language quest and dungeon title coverage, prevented English
  client titles from overriding that selection and localized reviewed source
  areas. Recovered unsupported saved language choices.
- Reviewed and corrected quest objectives, materials, supplied items, class quest
  variants, story sources and giver/turn-in records across early and late dungeons.
  Restored reviewed object positions, city maps and alternative giver locations.
- Distinguished known source areas from unknown exact positions, explained
  item-created quest sources and made item/alternative source details accessible
  from quest rows. Kept incomplete requirements and locations explicit.
- Preserved player TomTom waypoints and newer navigation, reward, tooltip,
  language and scrolling state during delayed or overlapping updates.
- Reduced startup scans, bounded large-list rendering and reward work, reused
  validated planning data and loaded translated titles only when needed.
  Removed obsolete detail-chain work and consolidated metadata retry handling.
- Strengthened catalogue and translation validation, Unicode handling and package
  membership checks. Improved font-asset recovery and minimap resize behavior.
- Prepared and published the first 0.1.0 beta on GitHub after the user's in-game
  check; submitted the Forever beta to CurseForge for review.
- After the release, updated the repository README, added approved gameplay
  screenshots, development instructions, reporting templates and support links.
  These repository-documentation changes are newer than the original beta archive.

### 17-Oct-2026 — Illustrated interface, richer details and compact quest chains

- Introduced the dark visual theme, illustrated dungeon cards and an overview
  before selecting a quest. Improved artwork proportions, fallback previews,
  title hierarchy, scrolling and reading-position recovery.
- Expanded collection, creature, object and event objectives, quest-provided
  supplies, starter-item drops and source locations across the catalogue.
  Added further NPC reference portraits and pickup/turn-in locations.
- Distinguished quest payments from rewards and collection materials from items
  supplied by a quest. Showed live progress and current turn-in dialogue, with
  rewards and preparation costs ahead of lengthy source references.
- Added starter-item acquisition explanations, source-location visits and a
  direct action to open a held quest in the native quest journal.
- Added case-insensitive Unicode search, quest-name and exact-ID search, recorded
  NPC/source-place search and direct selection of matching quests. Improved
  empty-result explanations, search focus and refresh performance.
- Added compact expandable preparation details and inline quest trees, with
  connected branches and distinct dungeon targets. Kept the planner open during
  navigation and native quest-journal actions.
- Added faction and class audience icons. Removed race-based exclusions and
  restriction labels while retaining faction, class and level conditions.
- Distinguished quest level from minimum pickup level. Improved multilingual
  typography, preserved native alphabet fonts and enlarged readable quest text.
- Added explicit language selection and hover previews. Replaced the temporary
  flag picker with a neutral language control and readable native language names.
- Added client-backed dungeon entrance navigation, clearer destination markers
  and a floating guide showing the quest, destination and distance.
- Simplified the toolbar and detail actions, improved window focus and screen
  fitting, and repaired minimap visibility, placement and recovery.
- Hardened quest, item, portrait and navigation refreshes against selection or
  context changes. Expanded regression coverage and reduced repeated search,
  title-loading and language-preview work.

### 16-Oct-2026 — First working browser, planning and quest catalogue

- Added the dungeon browser, character quest states and a preparation action list,
  starting with Deadmines, Ragefire Chasm and The Hall of Thanes.
- Added prerequisite groups, acceptance-versus-completion conditions, alternative
  branch choices and explanations for locked or unverified quests. Kept story
  sequences separate from mandatory acceptance requirements.
- Expanded the catalogue through Wailing Caverns, Shadowfang Keep, Blackfathom
  Deeps, The Stockade, Gnomeregan, Razorfen Kraul and Downs, Scarlet Monastery,
  Uldaman, Zul'Farrak, Temple of Atal'Hakkar, Dire Maul, Scholomance, Stratholme,
  Blackrock Spire and Depths, plus several new Forever dungeons.
- Added supporting faction and class quest stories, quest-starting items,
  acquisition sources and containers, reported NPC positions and turn-in points.
  Added VanCleef's letter to Deadmines and corrected Hidden Enemies giver data.
- Added map guidance, a direction arrow and optional TomTom support. Added
  separate visits to known quest givers and a choice of reported locations.
- Added current quest-offer objectives, rewards, money and experience, cached
  reward previews, item icons and native item tooltips.
- Added carried-item counts, sourced objective quantities, quest-log occupancy,
  starter-item requirements, quest levels and recorded character restrictions.
- Added optional client-provided dungeon artwork and portraits, localized NPC
  names and clearer notices for missing data and unsupported client features.
- Renamed the addon to Dungeon Pro, added `/DP`, `/DungeonPro` and `/rl`, and
  introduced the movable minimap launcher.
- Improved saved-data protection, quest-title loading and description caching.
  Kept current quest progress separate from past completion history and guarded
  navigation against stale callbacks, failed APIs and changes to player map pins.
- Added catalogue validation, local Lua checks, planning regressions and clean
  addon packaging. Hid unnecessary scrollbars and supported wrapped list rows.

Quest coverage, native-client behavior and visual layout continue to be improved.
