# Changelog

## 0.1.0 - 16-Oct-2026 — Development preview

- Added case-insensitive Unicode search for localized dungeon names.
- Made quest titles and section headings easier to distinguish from body text.
- Added missing reported locations for several early dungeon quest givers.
- Restored quest selection when preparation section headings are present.
- Explained faction, class and race restrictions directly in quest rows.
- Added native dungeon artwork for 24 catalogue entries and safer image fallback.
- Refined the window, controls and selected rows with a cohesive dark theme.
- Added a dungeon overview before selecting a quest, with artwork and coverage notes.
- Let Back return from the first quest to its dungeon overview.
- Showed a clear copy instruction beside the selected Wowhead link.
- Preserved map pins when their native API context changes during guidance.
- Added the dungeon browser, character quest states and prerequisite planning.
- Added map guidance, a direction arrow and optional TomTom support.
- Added initial quest facts for The Deadmines, Ragefire Chasm and The Hall of Thanes.
- Added explicit notices for incomplete data and interface translations.
- Renamed the addon to Dungeon Pro, with `/DP` and `/DungeonPro` commands.
- Added current quest-offer rewards, experience and objective summaries, kept
  separate from quest-log progress and preparation requirements.
- Clarified prerequisite groups and whether a step needs acceptance or completion.
- Added Back navigation for supporting quest cards and optional client-provided
  dungeon images and current-offer portraits.
- Expanded later dungeon quest lists and sourced quest-giver locations.
- Added expandable reported giver positions with navigation to a chosen point.
- Added sourced item containers separately from the items that begin quests.
- Preserved the current guide when TomTom or map callbacks replace an older request.
- Kept early quests unverified where the full acceptance conditions lack evidence,
  with a clearer label for quests absent from the current quest log.
- Corrected a Hidden Enemies starting NPC and updated Neeru's reported positions.
- Kept known prerequisite work visible while other acceptance conditions are unknown.
- Listed VanCleef's quest-starting letter under Deadmines as well as its later story.
- Added reward previews by quest ID when the client confirms loaded reward data.
- Kept lower and upper Blackrock Spire distinct when using localized map names.
- Added current carried counts for quest-starting items and completion materials.
- Added the current quest-log count and its client-provided capacity.
- Added optional item icons and native hover tooltips to quest rewards.
- Showed minimum level and listed class/race limits on quest detail cards.
- Added `/rl` as a shortcut for reloading the interface.
- Added a movable minimap button, with commands to hide or reset it.
- Showed sourced objective-item quantities separately from current carried counts.
- Hid scrollbars when a list or quest card fits without scrolling.
- Started the quest list at the top when switching dungeons.
- Kept item names and quest details tied to the current client data and selection.
- Cleared an old copied quest link when switching to another quest.
- Kept known objective items visible when their required quantity is unverified.
- Added missing dungeon quests and their supporting mage and faction story chains.
- Kept newly accepted quests visible alongside past completion history, and
  retained that history when checking prerequisite chains.
- Added localized names for the current quest NPC, with catalogue names as fallback.
- Added translated explanations for locked quests and missing information.
- Added character filtering with an option to inspect restricted quests, and
  remembered browsing filters per character.
- Preserved saved settings when their schema is invalid or newer than supported.
- Preserved saved descriptions after empty client responses and added bounded
  retries when localized quest-title loading fails.
- Added a next-step list for dungeon preparation and client-provided objectives.
- Grouped preparation steps by outside pickups, inside pickups, level gates,
  progress and unknown requirements, with translated headings.
- Added initial Wailing Caverns quests and corrected Rahauro's approach waypoint.
- Added initial Shadowfang Keep quests and supporting Wailing Caverns chain steps.
- Added initial Blackfathom Deeps and shared paladin/warlock quests, plus sourced
  waypoints for three Shadowfang Keep quest-givers.
- Extended Blackfathom's Horde quest list and its known story sequences.
- Added The Stockade and the paladin's Kor Gem support quest.
- Added initial Scarlet Monastery, Uldaman and City of Dalaran quest lists,
  supporting story records and sourced Scarlet Monastery giver locations.
- Listed distinct sources when a quest-starting item drops from several creatures.
- Added initial Zul’Farrak, Temple of Atal’Hakkar and Excavation Site quest lists.
- Kept source-grouped story quests together without turning them into mandatory
  prerequisite steps.
- Preserved multiple possible NPC/object starting points and known source zones
  without inventing map coordinates.
- Preserved the correct quest and language when the selected quest changes during
  a description read.
- Completed the known shared story variants around Anthion and added sourced
  locations for early-chain and Blackrock quest-givers.
- Showed rewards, choices, money and experience from the open quest dialogue.
- Kept quests already in your log visible when catalogue restrictions are stale.
- Added a short-lived note for quests observed in the current NPC dialogue,
  with cleanup when the dialogue or character context changes.
- Added Dire Maul quests, book starters and acquisition sources, plus further
  Blackrock Spire story steps.
- Added the Treaty of Understanding in Hall of Thanes and corrected sourced
  giver locations and Dark Iron Map acquisition information.
- Showed class and level requirements of quest-starting items separately from
  the quest’s own availability.
- Added early travel and story steps for dungeon chains, plus seven sourced
  Lordaeron quest-giver locations.
- Added corroborated prerequisite links where compatible sources agree; unknown
  full requirements continue to show as unverified.
- Added initial Scholomance, Stratholme and Blackrock Spire quest lists with
  separate wing evidence, shared story variants and a confirmed dragon-scale starter.
- Added Ruins of Lordaeron, Maraudon, Drowned City and Blackrock Depths quest
  lists, reviewed story steps and confirmed quest-starting items.
- Added initial Razorfen Kraul and Razorfen Downs quests, item starters and
  four sourced Razorfen quest-giver locations.
- Added optional native quest-log portraits when the client provides one.
- Expanded the client capability report and kept missing storyline data distinct
  from confirmed empty results.
- Added initial Gnomeregan quests, Stockade giver waypoints and the Horde
  paladin's Kor Gem support quest.
- Added client-provided item rewards, reward choices and money to quest details.
- Improved localized dungeon search, added a clear button and explained empty
  search results.
- Extended Gnomeregan with separate object-quest variants, repeatable labels and
  seven sourced giver locations.
- Separated quests that provide completion materials from acceptance requirements.
- Recovered quest-title requests that receive no result event, with bounded retries.
- Preserved nearby player map pins and new guides started during waypoint cleanup.
- Added saved choices for alternative prerequisite branches, with an automatic
  planning option and safe fallback when a branch is unavailable.
- Adjusted row and chain-button heights for wrapped text and kept navigation
  active when unrelated quests change.
- Improved navigation fallback after TomTom failures and protected the guide
  against unavailable map/vector constructors and invalid positions.
- Preserved player map pins when the client rejects a new waypoint.
- Added separate quest-giver location guidance while keeping prerequisite guidance.
- Added sourced approach waypoints for four Wailing Caverns quest-givers and
  completed the known giver information for Nara Wildmane's story step.
- Kept unresolved locked quests visible and stopped unfinished quests from
  directing players to their turn-in NPC before objectives are complete.
- Improved window sizing on shorter screens and recovery of saved positions.
- Fixed preparation checks for inside quests with outside prerequisites and
  preserved available steps when an alternative branch has incomplete data.

Quest coverage, native-client behavior and visual layout are still being checked.
