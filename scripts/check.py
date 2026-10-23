"""Run the local verification matrix; no downloads or hosted jobs."""
import argparse
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


TIMINGS = []


# Generous per-invocation bound: the slowest Lua suites (beta_giver_names)
# take ~50s, so 600s never trips on a healthy tree but a hung tests/*.lua
# child fails the gate instead of hanging it forever.
COMMAND_TIMEOUT_SECONDS = 600


def execute(args):
    started = time.perf_counter()
    try:
        result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=COMMAND_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"command timed out after {COMMAND_TIMEOUT_SECONDS}s: {list(args)!r}") from error
    return result, time.perf_counter() - started


def report(args, result, seconds):
    print("> " + repr(list(map(str, args))), flush=True)
    if result.stdout:
        print(result.stdout.decode("utf-8", errors="replace"), end="", flush=True)
    TIMINGS.append({"argv": list(map(str, args)), "seconds": seconds,
                    "returncode": result.returncode})
    print(f"[{seconds:.3f}s; exit {result.returncode}]", flush=True)
    result.check_returncode()


def run(*args):
    result, seconds = execute(args)
    report(args, result, seconds)


def run_lua_checks(commands, jobs):
    """Keep each mutable Lua fixture in its own process; drain before later gates."""
    if not 1 <= jobs <= 4:
        raise ValueError("jobs must be between 1 and 4")
    remaining = iter(commands)
    # No queued backlog: a failure stops submission, then the context manager
    # waits for owned running children. Killing a launcher can orphan its child.
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        pending = {}
        def submit():
            args = next(remaining, None)
            if args is not None:
                pending[pool.submit(execute, args)] = args
        for _ in range(jobs):
            submit()
        failure = None
        while pending:
            finished, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in finished:
                args = pending.pop(future)
                try:
                    result, seconds = future.result()
                    report(args, result, seconds)
                except Exception as error:
                    if not isinstance(error, subprocess.CalledProcessError):
                        print(f"Could not run {list(args)!r}: {error}", flush=True)
                    if failure is None:
                        failure = error
            if failure is None:
                for _ in finished:
                    submit()
        if failure is not None:
            raise failure


def lua_checks(lua, run):
    run(lua, "tests/planner.lua")
    run(lua, "tests/dungeon_overview.lua")
    run(lua, "tests/preparation_priority_model.lua")
    run(lua, "tests/preparation_limits_model.lua")
    run(lua, "tests/compact_dungeon_overview_ui.lua")
    run(lua, "tests/dungeon_status.lua")
    run(lua, "tests/quest_tree.lua")
    run(lua, "tests/quest_row_info.lua")
    run(lua, "tests/model_snapshot_ownership.lua")
    run(lua, "tests/context.lua")
    run(lua, "tests/event_context.lua")
    run(lua, "tests/event_refresh.lua")
    run(lua, "tests/diagnostics_module.lua")
    run(lua, "tests/navigation_diagnostics_ownership.lua")
    run(lua, "tests/catalog_contexts.lua")
    run(lua, "tests/client_ui.lua")
    run(lua, "tests/detail_journal_theme.lua")
    run(lua, "tests/detail_journal_ui.lua")
    run(lua, "tests/dungeon_map.lua")
    run(lua, "tests/dungeon_map_retirement.lua")
    run(lua, "tests/dungeon_map_ui.lua")
    run(lua, "tests/dungeon_map_release_ui.lua")
    run(lua, "tests/dungeon_map_theme_ui.lua")
    run(lua, "tests/dungeon_map_integration_ui.lua")
    run(lua, "tests/dungeon_map_default_off_ui.lua")
    run(lua, "tests/dungeon_map_input_ownership_ui.lua")
    run(lua, "tests/overview_kinds_ui.lua")
    run(lua, "tests/art_painter_publication_ui.lua")
    run(lua, "tests/startup_events.lua")
    run(lua, "tests/client_retry_refresh.lua")
    run(lua, "tests/startup_performance.lua")
    run(lua, "tests/large_dungeon_performance.lua", "missing")
    run(lua, "tests/large_dungeon_performance.lua", "items")
    run(lua, "tests/large_dungeon_performance.lua", "chain")
    run(lua, "tests/brd_ui_workload.lua")
    run(lua, "tests/locales.lua")
    run(lua, "tests/language.lua")
    run(lua, "tests/language_hover.lua")
    run(lua, "tests/search.lua")
    run(lua, "tests/search_relations.lua")
    run(lua, "tests/related_search_ui.lua")
    run(lua, "tests/source_search_titles_ui.lua")
    run(lua, "tests/catalog_search_release_ui.lua")
    run(lua, "tests/catalog_click_retirement_ui.lua")
    run(lua, "tests/window_hide_retirement_ui.lua")
    run(lua, "tests/reward_reset_retirement_ui.lua")
    run(lua, "tests/copy_close_retirement_ui.lua")
    run(lua, "tests/catalog_status_release_ui.lua")
    run(lua, "tests/catalog_search_data_ui.lua")
    run(lua, "tests/catalog_data_batch_ui.lua")
    run(lua, "tests/overnight_search_reported_places.lua")
    run(lua, "tests/objective_source_search_ui.lua")
    run(lua, "tests/objective_target_search.lua")
    run(lua, "tests/objective_target_search_ui.lua")
    run(lua, "tests/search_typography_ui.lua")
    run(lua, "tests/source_separator_search_ui.lua")
    run(lua, "tests/quest_id_search_localization_ui.lua")
    run(lua, "tests/ui_preparation.lua")
    run(lua, "tests/preparation_overview_module.lua")
    run(lua, "tests/filter_label_guidance_ui.lua")
    run(lua, "tests/recorded_objectives_ui.lua")
    run(lua, "tests/ready_turnin_navigation_ui.lua")
    run(lua, "tests/ready_turnin_retirement_ui.lua")
    run(lua, "tests/ancestor_action_cue_ui.lua")
    run(lua, "tests/ancestor_action_retirement_ui.lua")
    run(lua, "tests/catalogue_layout_ui.lua")
    run(lua, "tests/catalogue_layout_retirement_ui.lua")
    run(lua, "tests/detail_tabs_ui.lua")
    run(lua, "tests/detail_back_control_ui.lua")
    run(lua, "tests/detail_back_geometry_ui.lua")
    run(lua, "tests/back_quest_selection_ui.lua")
    run(lua, "tests/quest_history_module.lua")
    run(lua, "tests/detail_tabs_retirement_ui.lua")
    run(lua, "tests/detail_tabs_work_ui.lua")
    run(lua, "tests/quest_tree_ui.lua")
    run(lua, "tests/quest_tree_character_filter_ui.lua")
    run(lua, "tests/detail_role_caption_ui.lua")
    run(lua, "tests/detail_contact_binding.lua")
    run(lua, "tests/detail_contact_rows_ui.lua")
    run(lua, "tests/compact_contacts_ui.lua")
    run(lua, "tests/starter_detail_hierarchy_ui.lua")
    run(lua, "tests/starter_source_hint_ui.lua")
    run(lua, "tests/single_stream_detail_ui.lua")
    run(lua, "tests/single_stream_history_ui.lua")
    run(lua, "tests/quest_tree_limit_notice_ui.lua")
    run(lua, "tests/hidden_enemies_storyline_ui.lua")
    run(lua, "tests/quest_row_markers_ui.lua")
    run(lua, "tests/quest_class_icons_ui.lua")
    run(lua, "tests/quest_row_navigation_ui.lua")
    run(lua, "tests/quest_row_release_ui.lua")
    run(lua, "tests/quest_row_sources_ui.lua")
    run(lua, "tests/source_location_warnings_ui.lua")
    run(lua, "tests/finish_location_warning_ui.lua")
    run(lua, "tests/identity_finish_warning_ui.lua")
    run(lua, "tests/summon_sources_ui.lua")
    run(lua, "tests/missing_start_sources_ui.lua")
    run(lua, "tests/reviewed_object_locations_ui.lua")
    run(lua, "tests/reviewed_npc_source_areas_ui.lua")
    run(lua, "tests/alternative_source_warnings_ui.lua")
    run(lua, "tests/navigation_tooltip_retirement_ui.lua")
    run(lua, "tests/quest_target_path_ui.lua")
    run(lua, "tests/quest_relation_labels_ui.lua")
    run(lua, "tests/reviewed_quest_sources_ui.lua")
    run(lua, "tests/class_trainer_navigation_ui.lua")
    run(lua, "tests/city_announcer_navigation_ui.lua")
    run(lua, "tests/windsor_navigation_ui.lua")
    run(lua, "tests/localized_names_ui.lua")
    run(lua, "tests/source_area_names_ui.lua")
    run(lua, "tests/header_controls_ui.lua")
    run(lua, "tests/dungeon_cards_ui.lua")
    run(lua, "tests/dungeon_count_filter_ui.lua")
    run(lua, "tests/theme.lua")
    run(lua, "tests/font_ownership_ui.lua")
    run(lua, "tests/font_cache_drift_ui.lua")
    run(lua, "tests/tooltip_lease.lua")
    run(lua, "tests/shared_tooltip_retirement_ui.lua")
    run(lua, "tests/quest_status.lua")
    run(lua, "tests/quest_status_retirement_ui.lua")
    run(lua, "tests/quest_list_rewards.lua")
    run(lua, "tests/reward_cache.lua")
    run(lua, "tests/overnight_reward_cache_fairness.lua")
    run(lua, "tests/reward_item_hydration.lua")
    run(lua, "tests/quest_rewards_ui.lua")
    run(lua, "tests/quest_detail_ui.lua")
    run(lua, "tests/detail_scroll_ownership_ui.lua")
    run(lua, "tests/detail_scroll_retention_ui.lua")
    run(lua, "tests/detail_text_retention_ui.lua")
    run(lua, "tests/source_controls_retention_ui.lua")
    run(lua, "tests/source_geometry_retirement_ui.lua")
    run(lua, "tests/inline_turnin_retention_ui.lua")
    run(lua, "tests/primary_giver_retirement_ui.lua")
    run(lua, "tests/portrait_cleanup_retirement_ui.lua")
    run(lua, "tests/material_controls_retention_ui.lua")
    run(lua, "tests/minimal_detail_ui.lua")
    run(lua, "tests/right_pane_ui.lua")
    run(lua, "tests/item_starter_copy_ui.lua")
    run(lua, "tests/starter_provided_count_ui.lua")
    run(lua, "tests/inline_giver_ui.lua")
    run(lua, "tests/overnight_window_navigation.lua")
    run(lua, "tests/quest_level_colors_ui.lua")
    run(lua, "tests/detail_sources_ui.lua")
    run(lua, "tests/detail_visual.lua", "check")
    run(lua, "tests/detail_visual.lua", "overview:dm", "enUS", "", "", "", "155", "check")
    run(lua, "tests/detail_visual.lua", "overview:dm", "ruRU", "", "collapsed", "", "155", "check")
    run(lua, "tests/quest_payment.lua")
    run(lua, "tests/held_quest_payment.lua")
    run(lua, "tests/held_quest_waypoint.lua")
    run(lua, "tests/quest_details.lua")
    run(lua, "tests/text_capture_ownership.lua")
    run(lua, "tests/selected_log_locale.lua")
    run(lua, "tests/dialogue_text.lua")
    run(lua, "tests/rewards.lua")
    run(lua, "tests/cached_rewards.lua")
    run(lua, "tests/portraits.lua")
    run(lua, "tests/giver_portraits.lua")
    run(lua, "tests/offered_portraits.lua")
    run(lua, "tests/dungeon_art.lua")
    run(lua, "tests/dungeon_art_module.lua")
    run(lua, "tests/dungeon_names.lua")
    run(lua, "tests/source_area_names.lua")
    run(lua, "tests/npc_names.lua")
    run(lua, "tests/source_names.lua")
    run(lua, "tests/source_names_ui.lua")
    run(lua, "tests/source_names_retirement_ui.lua")
    run(lua, "tests/npc_source_names.lua")
    run(lua, "tests/npc_source_names_ui.lua")
    run(lua, "tests/additional_npc_names_ui.lua")
    run(lua, "tests/beta_giver_names_ui.lua")
    run(lua, "tests/localized_source_search.lua")
    run(lua, "tests/localized_source_search_ui.lua")
    run(lua, "tests/world_area_names.lua")
    run(lua, "tests/world_area_search.lua")
    run(lua, "tests/world_area_names_ui.lua")
    run(lua, "tests/world_area_retirement_ui.lua")
    run(lua, "tests/world_area_case_variant_ui.lua")
    run(lua, "tests/restriction_names.lua")
    run(lua, "tests/items.lua")
    run(lua, "tests/carried_items.lua")
    run(lua, "tests/quest_log_capacity.lua")
    run(lua, "tests/quest_log_open.lua")
    run(lua, "tests/cached_quest_names.lua")
    run(lua, "tests/lazy_name_translations.lua")
    run(lua, "tests/offers.lua")
    run(lua, "tests/offered_rewards.lua")
    run(lua, "tests/offered_objectives.lua")
    run(lua, "tests/probe.lua")
    run(lua, "tests/navigation.lua")
    run(lua, "tests/native_navigation_supersession_ui.lua")
    run(lua, "tests/map_request_supersession_ui.lua")
    run(lua, "tests/tomtom_ownership.lua")
    run(lua, "tests/map_marker.lua")
    run(lua, "tests/map_marker_entrance_ui.lua")
    run(lua, "tests/map_marker_purpose_ui.lua")
    run(lua, "tests/scarlet_wings_ui.lua")
    run(lua, "tests/scarlet_classic_membership_ui.lua")
    run(lua, "tests/audit_quest_additions_ui.lua")
    run(lua, "tests/scarlet_discovery_view_ui.lua")
    run(lua, "tests/map_clicks.lua")
    run(lua, "tests/entrances.lua")
    run(lua, "tests/entrance_action_retirement_ui.lua")
    run(lua, "tests/minimap.lua")


# Every top-level tests/*.lua file must run through lua_checks above, or be
# named here with a one-line reason. Fixture-only helpers that must never
# execute standalone belong in this allow-list; an undocumented new test file
# fails the gate below instead of silently skipping coverage. The set is
# currently empty: each tests/*.lua file on disk has a registered runner call.
LUA_CHECK_FIXTURE_EXCEPTIONS = frozenset()


def check_lua_roster_completeness(commands=None, exceptions=None):
    """Fail when a tests/*.lua file has no registered lua_checks invocation."""
    if commands is None:
        collected = []
        lua_checks("<lua>", lambda *args: collected.append(args))
        commands = collected
    if exceptions is None:
        exceptions = LUA_CHECK_FIXTURE_EXCEPTIONS
    registered = {args[1] for args in commands
                  if len(args) >= 2 and isinstance(args[1], str)
                  and args[1].startswith("tests/") and args[1].endswith(".lua")}
    on_disk = {"tests/" + path.name for path in sorted((ROOT / "tests").glob("*.lua"))}
    allowed = {"tests/" + name for name in exceptions}
    missing = sorted(on_disk - registered - allowed)
    if missing:
        raise SystemExit(
            "Lua checks missing tests/*.lua files "
            "(register in lua_checks or document in LUA_CHECK_FIXTURE_EXCEPTIONS): "
            + ", ".join(missing))


def main(argv=()):
    parser = argparse.ArgumentParser(description=__doc__)
    default_jobs = min(4, max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=default_jobs,
                        help=f"isolated Lua processes (1-4, default: {default_jobs})")
    parser.add_argument("--timings", type=Path, help="write per-command JSON timing report")
    options = parser.parse_args(argv)
    TIMINGS.clear()
    started = time.perf_counter()
    passed = False
    try:
        check(options)
        passed = True
    finally:
        if options.timings:
            options.timings.write_text(json.dumps({"jobs": options.jobs,
                "elapsed_seconds": time.perf_counter() - started,
                "passed": passed,
                "lua_elapsed_seconds": getattr(options, "lua_elapsed_seconds", None),
                "commands": TIMINGS}, indent=2) + "\n", encoding="utf-8")


def check(options):
    lua, luac = shutil.which("lua5.1"), shutil.which("luac5.1")
    if not lua or not luac:
        raise SystemExit("Lua 5.1 and luac5.1 are required; no automatic install is performed")
    run(sys.executable, "scripts/catalog.py", "--check")
    run(sys.executable, "scripts/casefold.py", "--check")
    run(sys.executable, "scripts/names.py", "--check")
    run(sys.executable, "scripts/check_toc.py")
    run(sys.executable, "scripts/check_version.py")
    syntax_paths = [str(path) for path in sorted(ROOT.rglob("*.lua")) if "dist" not in path.parts]
    for offset in range(0, len(syntax_paths), 32):
        run(luac, "-p", *syntax_paths[offset:offset + 32])
    commands = []
    lua_checks(lua, lambda *args: commands.append(args))
    print(f"Lua checks: {len(commands)} invocations; {options.jobs} isolated processes", flush=True)
    check_lua_roster_completeness(commands)
    lua_started = time.perf_counter()
    try:
        run_lua_checks(commands, options.jobs)
    finally:
        options.lua_elapsed_seconds = time.perf_counter() - lua_started
    run(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v")
    run(sys.executable, "scripts/package.py")
    run("git", "diff", "--check")
    print("Local checks passed. Native client and visual acceptance remain separate.")


if __name__ == "__main__":
    main(sys.argv[1:])
