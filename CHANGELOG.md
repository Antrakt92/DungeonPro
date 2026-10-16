# Changelog

## 0.1.0 - 16-Oct-2026 — Development preview

- Added the dungeon browser, character quest states and prerequisite planning.
- Added map guidance, a direction arrow and optional TomTom support.
- Added initial quest facts for The Deadmines, Ragefire Chasm and The Hall of Thanes.
- Added explicit notices for incomplete data and interface translations.
- Added translated explanations for locked quests and missing information.
- Preserved saved descriptions after empty client responses and added bounded
  retries when localized quest-title loading fails.
- Added a next-step list for dungeon preparation and client-provided objectives.
- Grouped preparation steps by outside pickups, inside pickups, level gates,
  progress and unknown requirements, with translated headings.
- Added initial Wailing Caverns quests and corrected Rahauro's approach waypoint.
- Added sourced approach waypoints for four Wailing Caverns quest-givers and
  completed the known giver information for Nara Wildmane's story step.
- Kept unresolved locked quests visible and stopped unfinished quests from
  directing players to their turn-in NPC before objectives are complete.
- Improved window sizing on shorter screens and recovery of saved positions.
- Fixed preparation checks for inside quests with outside prerequisites and
  preserved available steps when an alternative branch has incomplete data.

Quest coverage, native-client behavior and visual layout are still being checked.
