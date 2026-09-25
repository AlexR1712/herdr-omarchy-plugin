import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch


ROOT = pathlib.Path(__file__).parents[1]
LOADER = importlib.machinery.SourceFileLoader("herdr_overview", str(ROOT / "bin" / "herdr-overview"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
overview = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(overview)


class SnapshotTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "tests" / "fixtures" / "snapshot.json").read_text())

    def test_groups_machine_space_worktrees_and_agents_from_explicit_metadata(self):
        result = overview.normalize(self.fixture(), updated_at="2026-09-24T00:00:00Z")
        self.assertTrue(result["available"])
        self.assertFalse(result["partial"])
        self.assertEqual(result["totals"], {"all": 5, "working": 1, "review": 1, "waiting": 1, "idle": 1, "other": 1})
        machine = result["machines"][0]
        self.assertEqual((machine["id"], machine["name"]), ("local", "Local"))
        self.assertEqual([space["name"] for space in machine["spaces"]], ["customer-portal", "misc"])
        portal = machine["spaces"][0]
        self.assertEqual(portal["id"], "repo-portal")
        self.assertEqual([worktree["id"] for worktree in portal["worktrees"]], ["ws-api", "ws-web"])
        self.assertEqual([worktree["kind"] for worktree in portal["worktrees"]], ["worktree", "worktree"])
        self.assertEqual(portal["worktrees"][0]["agents"][0]["state"], "attention")
        done = next(agent for agent in result["agents"] if agent["pane_id"] == "12")
        self.assertEqual((done["state"], done["relation"], done["worktree_id"]), ("review", "workspace", "ws-web"))

    def test_non_git_workspace_gets_clear_kind_and_nonduplicated_name(self):
        result = overview.normalize(self.fixture())
        machine = result["machines"][0]
        space = next(space for space in machine["spaces"] if space["name"] == "misc")
        worktree = space["worktrees"][0]
        self.assertEqual((worktree["id"], worktree["kind"], worktree["name"]), ("unassigned:/code/misc", "workspace", "Workspace"))

    def test_status_semantics_done_review_idle_seen_and_blocked_attention(self):
        result = overview.normalize(self.fixture())
        by_pane = {agent["pane_id"]: agent for agent in result["agents"]}
        self.assertEqual(by_pane["12"]["state"], "review")
        self.assertEqual(by_pane["15"]["state"], "idle")
        self.assertEqual(by_pane["session-blocked"]["state"], "attention")

    def test_strips_status_glyphs_and_uses_compact_unnamed_provider_label(self):
        result = overview.normalize(self.fixture())
        api_agent = next(agent for agent in result["agents"] if agent["pane_id"] == "11")
        web_agent = next(agent for agent in result["agents"] if agent["pane_id"] == "12")
        self.assertEqual(api_agent["name"], "API migration")
        self.assertEqual(api_agent["summary"], "Ignored title")
        self.assertEqual(web_agent["name"], "Codex · 12")
        self.assertEqual(web_agent["summary"], "Visual check")

    def test_duplicate_provider_ids_are_namespaced_by_machine(self):
        local = overview.normalize_machine(self.fixture(), "local", "Local")
        remote = overview.normalize_machine(self.fixture(), "remote", "Devbox")
        result = overview.overview_from_machines([local, remote])
        codex = [agent for agent in result["agents"] if agent["kind"] == "codex" and agent["pane_id"] == "11"]
        self.assertEqual({agent["id"] for agent in codex}, {"local:11", "remote:11"})

    def test_cwd_matches_longest_explicit_worktree_only_without_workspace_id(self):
        snapshot = self.fixture()
        snapshot["result"]["snapshot"]["agents"].append({"agent": "codex", "pane_id": "99", "agent_status": "working", "cwd": "/code/web/src"})
        result = overview.normalize(snapshot)
        agent = next(agent for agent in result["agents"] if agent["pane_id"] == "99")
        self.assertEqual((agent["relation"], agent["worktree_id"]), ("path", "ws-web"))

    def test_malformed_snapshot_is_machine_error_not_exception(self):
        with patch.object(overview, "run_json", return_value=({"result": None}, None)):
            machine = overview.collect_machine("remote", "Devbox", ["herdr", "--machine", "remote", "api", "snapshot"])
        self.assertFalse(machine["available"])
        self.assertEqual(machine["error"], "snapshot has unexpected shape")

    def test_partial_machine_failure_preserves_reachable_counts(self):
        good = overview.normalize_machine(self.fixture(), "local", "Local")
        failed = overview.empty_machine("remote", "Devbox", "snapshot timed out")
        result = overview.overview_from_machines([good, failed])
        self.assertTrue(result["available"])
        self.assertTrue(result["partial"])
        self.assertEqual(result["totals"]["all"], 5)
        self.assertEqual(result["machines"][1]["error"], "snapshot timed out")

    def test_machine_discovery_keeps_every_enabled_profile(self):
        profiles = [{"id": f"machine-{index}", "label": f"Machine {index}", "enabled": True} for index in range(12)]
        profiles.append({"id": "disabled", "label": "Disabled", "enabled": False})
        with patch.object(overview, "run_json", return_value=(profiles, None)):
            machines, error = overview.list_machines()
        self.assertEqual(len(machines), 12)
        self.assertIsNone(error)
        self.assertNotIn(("disabled", "Disabled"), machines)

    def test_machine_catalog_failure_is_explicit_partial_machine(self):
        with patch.object(overview, "list_machines", return_value=([], "machine catalog timed out")), patch.object(
            overview, "collect_machine", return_value=overview.normalize_machine(self.fixture(), "local", "Local")
        ):
            result = overview.collect_overview()
        self.assertTrue(result["available"])
        self.assertTrue(result["partial"])
        catalog = next(machine for machine in result["machines"] if machine["id"] == "machine-catalog")
        self.assertEqual(catalog["error"], "machine catalog timed out")

    def test_overview_does_not_mutate_machine_input(self):
        machine = overview.normalize_machine(self.fixture(), "local", "Local")
        overview.overview_from_machines([machine])
        self.assertIn("agents", machine)

    def test_cache_expires_without_returning_stale_data(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "overview.json"
            overview.write_cache(path, {"available": True})
            self.assertEqual(overview.read_cache(path), {"available": True})
            stale = json.loads(path.read_text())
            stale["created"] = 0
            path.write_text(json.dumps(stale))
            self.assertIsNone(overview.read_cache(path))


if __name__ == "__main__":
    unittest.main()
