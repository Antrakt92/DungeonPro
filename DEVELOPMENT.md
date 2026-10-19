# Development

Dungeon Pro targets WoW Forever. The runtime uses Lua 5.1; a different WoW
client needs its own API and data validation, not just a different TOC value.

## Source layout

- `Core/`: quest state, prerequisite planning, source information and client data.
- `UI/`: browsing, quest details, rewards, tooltips, maps and the direction guide.
- `Locales/`: interface strings and translations.
- `data/`: source facts and translation inputs.
- `Database/`: generated runtime data.
- `tests/` and `scripts/`: local regressions, generators and packaging.
- `screenshots/` and `Media/Branding/`: repository presentation only; excluded
  from the installable archive. The screenshots are native game captures.

## Local checks

Have Python 3, `lua5.1`, `luac5.1` and Git available on PATH. Run commands from
the repository root:

```text
python scripts/check.py
```

This checks Lua syntax, modeled behavior, translations, catalogue consistency,
generated-file drift and deterministic packaging. It does not install tools,
download dependencies or start the game. Passing it does not establish native
layout, quest availability or map accuracy; verify affected behavior in game.

## Quest data

Edit `data/catalog.json`, then regenerate:

```text
python scripts/catalog.py
```

Each quest has a Forever source link and a `requirementsKnown` flag. Story order
is separate from acceptance requirements. Requirement groups are AND across
groups and OR within a group; `mode: active` means acceptance is enough, while
the default requires completion. Preserve unknown requirements, quantities and
locations until supported by evidence. Catalogue coordinates are percentages
from 0 to 100.

Keep pickup, turn-in and starter-item acquisition sources separate. Record the
NPC, object or item identity, zone, exact percentage coordinates and quest stage
only when supported. A known zone does not supply a missing point or map ID.

Distinguish quest-starting, quest-provided, objective-required and reward items.
Record quantities only when observed; possession or a supplied item alone does
not prove a pickup requirement. Leave unverified quantities and locations unknown.

Describe the observation behind each requirement and its quest stage. A story
list or guide order alone is not an acceptance condition. Keep observations
separate from assumptions, and retain their Forever quest/source evidence.

Interface strings live in `Locales/`. Name translations and Unicode search data
have separate generators:

```text
python scripts/names.py --check
python scripts/casefold.py --check
```

## Development packages

```text
python scripts/package.py
```

The output is `dist/DungeonPro-<version>-Forever-dev.zip`, with a `DungeonPro/`
root. Only TOC-listed runtime files, player documentation and required resources
and notices are included. Repository screenshots, branding, tests, raw data and
tools stay out. This command builds locally; it does not publish a release.

## Optional layout preview

`scripts/render-detail-preview.py` renders modeled UI anchors with sample data.
It needs Pillow in addition to the tools above. Pillow is not required for the
normal checks or packaging. A generated preview is not an in-game screenshot.

To preview a dungeon overview with a simulated ready quest:

```text
python scripts/render-detail-preview.py --overview dm --ready-quest 155
```

The overview fixture is a level-60 Alliance Human Mage. It uses the catalogue
and a simulated quest log, without the quest preview's sample prose and rewards.
Use `--catalog-collapsed` to preview the wider quest list. Existing quest IDs
can be repeated with `--ready-quest`; they do not add catalogue associations.
Overview previews omit game artwork and approximate font metrics. Native fonts,
icons, interface scale and gameplay still require in-game verification.

## Reports and permissions

Use the issue templates for quest/source observations and reproducible interface
problems. Include the quest ID, dungeon, addon build and selected language when
known. For layout reports, include the view, Mine/All filter, collapsed-list state,
window size and interface scale. Redact account and character identifiers; do not
attach SavedVariables or character settings files.

Original code uses the Antrakt Attribution and CurseForge Rewards
License 1.2. Forks and substantial reuse require attribution, with reward-sharing
conditions for derivatives that earn CurseForge Reward Points; see the
[full license](LICENSE). Third-party material retains its separate terms.
