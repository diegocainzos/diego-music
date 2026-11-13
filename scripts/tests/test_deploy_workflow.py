"""Tests for .github/workflows/deploy.yml (openspec cd-vps-deploy): structure + the CI gate step run with a fake `gh`."""
import json
import os
import re
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / ".github" / "workflows" / "deploy.yml"
RUN_SHA = "a" * 40
MAIN_SHA = "b" * 40

FAKE_GH = """#!/bin/bash
printf '%s\\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "api "*) echo "$FAKE_MAIN_SHA" ;;
  "run list") cat "$FAKE_RUNS" ;;
  *) echo "unexpected gh call: $*" >&2; exit 9 ;;
esac
"""


def load() -> dict:
    if not WF.is_file():
        pytest.fail("missing .github/workflows/deploy.yml")
    wf = yaml.safe_load(WF.read_text())
    assert isinstance(wf, dict)
    return wf


def job(wf: dict) -> dict:
    return wf["jobs"]["deploy"]


def step(wf: dict, sid: str) -> dict:
    hits = [s for s in job(wf)["steps"] if s.get("id") == sid]
    assert len(hits) == 1, f"need exactly one step with id {sid}"
    return hits[0]


def ssh_step(wf: dict) -> dict:
    hits = [s for s in job(wf)["steps"] if "ssh " in (s.get("run") or "")]
    assert len(hits) == 1, "need exactly one step running ssh"
    return hits[0]


def gate(tmp_path: Path, event: str, runs: list[dict]) -> dict:
    """Execute the `id: ci` run script; return its GITHUB_OUTPUT as a dict."""
    script = step(load(), "ci")["run"]
    bindir = tmp_path / "bin"
    bindir.mkdir()
    (bindir / "gh").write_text(FAKE_GH)
    (bindir / "gh").chmod(0o755)
    (tmp_path / "runs.json").write_text(json.dumps(runs))
    out = tmp_path / "out"
    out.write_text("")
    env = {**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}", "GH_LOG": str(tmp_path / "gh.log"),
           "FAKE_MAIN_SHA": MAIN_SHA, "FAKE_RUNS": str(tmp_path / "runs.json"), "EVENT": event,
           "RUN_SHA": RUN_SHA if event == "workflow_run" else "", "REPO": "owner/repo", "GH_TOKEN": "fake",
           "GITHUB_OUTPUT": str(out)}
    r = subprocess.run(["bash", "-euo", "pipefail", "-c", script], env=env, capture_output=True, text=True,
                       timeout=30)
    assert r.returncode == 0, f"gate must exit 0: {r.stderr}"
    return dict(line.split("=", 1) for line in out.read_text().splitlines() if "=" in line)


def run(name: str, status: str = "completed", conclusion: str = "success") -> dict:
    return {"workflowName": name, "status": status, "conclusion": conclusion if status == "completed" else ""}


def test_all_ci_green_triggers_deploy(tmp_path):
    wf = load()
    on = wf.get("on", wf.get(True))
    wr = on["workflow_run"]
    assert sorted(wr["workflows"]) == ["resolver", "web"]
    assert wr["types"] == ["completed"]
    assert wr["branches"] == ["main"]
    cond = job(wf)["if"]
    assert "github.event.workflow_run.conclusion == 'success'" in cond
    assert "steps.ci.outputs.ready == 'true'" in ssh_step(wf)["if"]
    assert ssh_step(wf)["env"]["SHA"].replace(" ", "") == "${{steps.ci.outputs.sha}}"
    out = gate(tmp_path, "workflow_run", [run("resolver"), run("web")])
    assert out == {"sha": RUN_SHA, "ready": "true"}


def test_all_ci_green_with_only_one_ci_run_triggers_deploy(tmp_path):
    out = gate(tmp_path, "workflow_run", [run("resolver"), run("android", conclusion="failure"),
                                          run("apple", status="in_progress"), run("deploy", conclusion="failure")])
    assert out == {"sha": RUN_SHA, "ready": "true"}, "only resolver/web runs count"


@pytest.mark.parametrize("bad", ["failure", "cancelled", "timed_out", "skipped"])
def test_failed_ci_blocks_deploy(tmp_path, bad):
    out = gate(tmp_path, "workflow_run", [run("resolver"), run("web", conclusion=bad)])
    assert out.get("ready") == "false"


def test_sibling_ci_still_running_defers_deploy(tmp_path):
    out = gate(tmp_path, "workflow_run", [run("resolver"), run("web", status="in_progress")])
    assert out.get("ready") == "false"
    later = tmp_path / "later"
    later.mkdir()
    out = gate(later, "workflow_run", [run("resolver"), run("web")])
    assert out == {"sha": RUN_SHA, "ready": "true"}, "deploy happens when the sibling completes green"


def test_manual_deploy(tmp_path):
    wf = load()
    on = wf.get("on", wf.get(True))
    assert "workflow_dispatch" in on
    assert "github.event_name == 'workflow_dispatch'" in job(wf)["if"]
    out = gate(tmp_path, "workflow_dispatch", [])
    assert out == {"sha": MAIN_SHA, "ready": "true"}
    assert "commits/main" in (tmp_path / "gh.log").read_text()


def test_deploys_never_overlap_or_get_cancelled():
    wf = load()
    conc = wf.get("concurrency") or job(wf).get("concurrency")
    assert isinstance(conc, dict) and conc.get("group"), "a fixed concurrency group is required"
    assert "${{" not in str(conc["group"]), "group must be constant so all deploys serialise"
    assert conc.get("cancel-in-progress") is False


def test_host_key_pinned():
    wf = load()
    s = ssh_step(wf)
    cmd = s["run"]
    assert "StrictHostKeyChecking=yes" in cmd
    assert not re.search(r"StrictHostKeyChecking=(no|accept-new)", WF.read_text())
    assert "ssh-keyscan" not in WF.read_text()
    assert s["env"]["KNOWN_HOSTS"].replace(" ", "") == "${{secrets.VPS_KNOWN_HOSTS}}"
    assert "known_hosts" in cmd


def _strings(node, path=()):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from _strings(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _strings(v, path + (i,))
    elif isinstance(node, str):
        yield path, node


def test_hardened_deploy_workflow():
    wf = load()
    j = job(wf)
    assert j.get("environment") == "production"
    assert wf.get("permissions") == {"contents": "read", "actions": "read"}
    assert "permissions" not in j or j["permissions"] == wf["permissions"]
    assert isinstance(j.get("timeout-minutes"), int) and 0 < j["timeout-minutes"] <= 30
    for s in j["steps"]:
        if "uses" in s:
            assert re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", s["uses"]), s["uses"]
    for path, val in _strings(wf):
        if path[-1] == "run":
            assert "${{" not in val, f"expression inside run: {path}"
        if "secrets." in val:
            assert len(path) == 6 and path[:3] == ("jobs", "deploy", "steps") and path[4] == "env", path
