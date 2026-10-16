# Changelog

## 0.1.0 - 16-Oct-2026 — Development preview

- Added the dungeon browser, character quest states and prerequisite planning.
- Added map guidance, a direction arrow and optional TomTom support.
- Added initial quest facts for The Deadmines, Ragefire Chasm and The Hall of Thanes.
- Added explicit notices for incomplete data and interface translations.
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
