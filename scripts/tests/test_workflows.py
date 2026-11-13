"""Structural tests for the CI workflows and Dependabot config (openspec ci-github-actions)."""
import re
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
WF_DIR = ROOT / ".github" / "workflows"
NAMES = ("resolver", "web", "android", "apple")
SHA_RE = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")


def text(path: Path) -> str:
    if not path.is_file():
        pytest.fail(f"missing {path.relative_to(ROOT)}")
    return path.read_text()


def load(name: str) -> dict:
    wf = yaml.safe_load(text(WF_DIR / f"{name}.yml"))
    assert isinstance(wf, dict), f"{name}.yml is not a mapping"
    return wf


def triggers(wf: dict) -> dict:
    on = wf.get("on", wf.get(True))
    assert isinstance(on, dict), "`on` must be a mapping with push/pull_request"
    return on


def glob_re(pattern: str) -> re.Pattern:
    out = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


def runs_on(wf: dict, path: str) -> bool:
    """True if `path` triggers the workflow on both push to main and pull_request."""
    on = triggers(wf)
    hits = []
    for event in ("push", "pull_request"):
        cfg = on.get(event) or {}
        hits.append(any(glob_re(p).match(path) for p in cfg.get("paths", [])))
    return all(hits)


def triggered_by(wf: dict, path: str) -> bool:
    """True if `path` triggers the workflow on either event."""
    on = triggers(wf)
    return any(
        any(glob_re(p).match(path) for p in (on.get(e) or {}).get("paths", []))
        for e in ("push", "pull_request")
    )


def test_job(wf: dict) -> dict:
    job = (wf.get("jobs") or {}).get("test")
    assert isinstance(job, dict), "workflow needs a job named `test`"
    return job


test_job.__test__ = False  # helper, not a test


def run_text(job: dict) -> str:
    return "\n".join(str(s.get("run", "")) for s in job.get("steps", []))


def runs_in(job: dict, directory: str) -> bool:
    wd = str(job.get("defaults", {}).get("run", {}).get("working-directory", ""))
    step_wds = [str(s.get("working-directory", "")) for s in job.get("steps", []) if "run" in s]
    return (
        wd.rstrip("/") == directory
        or any(w.rstrip("/") == directory for w in step_wds)
        or re.search(rf"\bcd\s+\.?/?{re.escape(directory)}\b", run_text(job)) is not None
    )


def assert_push_main(wf: dict) -> None:
    assert "main" in ((triggers(wf).get("push") or {}).get("branches") or [])


# --- Component checks on change ---

def test_resolver_change_runs_resolver_tests():
    wf = load("resolver")
    assert_push_main(wf)
    for p in ("ResolverService/app/main.py", "app/main.py"):
        assert runs_on(wf, p), p
    job = test_job(wf)
    assert job.get("runs-on") == "ubuntu-latest"
    assert "scripts/validate-resolver.sh" in run_text(job)


def test_web_change_runs_web_tests_and_build():
    wf = load("web")
    assert_push_main(wf)
    assert runs_on(wf, "web/src/App.tsx")
    job = test_job(wf)
    assert job.get("runs-on") == "ubuntu-latest"
    cmds = run_text(job)
    for c in ("npm ci", "npm test", "npm run build"):
        assert c in cmds, c
    assert runs_in(job, "web")


def test_android_change_runs_unit_tests_and_debug_build():
    wf = load("android")
    assert_push_main(wf)
    assert runs_on(wf, "android/app/build.gradle.kts")
    job = test_job(wf)
    assert job.get("runs-on") == "ubuntu-latest"
    cmds = run_text(job)
    assert ":app:testDebugUnitTest" in cmds and ":app:assembleDebug" in cmds
    assert runs_in(job, "android")
    java = [s for s in job.get("steps", []) if "actions/setup-java@" in str(s.get("uses", ""))]
    assert java, "missing setup-java step"
    assert str((java[0].get("with") or {}).get("java-version")) == "17"


def test_apple_change_runs_macos_tests_and_ios_build():
    wf = load("apple")
    assert_push_main(wf)
    for p in (
        "DiegoMusic/App/DiegoMusicApp.swift",
        "Tests/SomeTests.swift",
        "project.yml",
        "Config/Base.xcconfig",
        "DiegoMusic.xcodeproj/project.pbxproj",
    ):
        assert runs_on(wf, p), p
    job = test_job(wf)
    assert str(job.get("runs-on", "")).startswith("macos")
    xc = [l for l in run_text(job).replace("\\\n", " ").splitlines() if "xcodebuild" in l]
    macos = [l for l in xc if "platform=macOS,arch=arm64" in l]
    ios = [l for l in xc if "generic/platform=iOS Simulator" in l]
    assert macos and re.search(r"\btest\b", macos[0]) and "CODE_SIGNING_ALLOWED=NO" in macos[0]
    assert ios and "build-for-testing" in ios[0] and "CODE_SIGNING_ALLOWED=NO" in ios[0]


def test_unrelated_change_skips_other_components():
    sample = "web/src/App.tsx"
    matched = {n for n in NAMES if triggered_by(load(n), sample)}
    assert matched == {"web"}


def test_only_the_apple_workflow_uses_macos():
    for n in NAMES:
        on_mac = [
            j for j in (load(n).get("jobs") or {}).values()
            if "macos" in str(j.get("runs-on", "")).lower()
        ]
        assert bool(on_mac) == (n == "apple"), n


# --- Hardened workflows ---

def test_read_only_token():
    for n in NAMES:
        wf = load(n)
        assert wf.get("permissions") == {"contents": "read"}, n
        for jn, job in (wf.get("jobs") or {}).items():
            perms = job.get("permissions")
            if perms == "write-all" or (isinstance(perms, dict) and "write" in perms.values()):
                pytest.fail(f"{n}.{jn} grants write")


def test_actions_pinned_by_sha():
    for n in NAMES:
        for job in (load(n).get("jobs") or {}).values():
            for s in job.get("steps", []):
                if "uses" in s:
                    assert SHA_RE.match(s["uses"]), f"{n}: {s['uses']}"


def test_jobs_time_out():
    for n in NAMES:
        jobs = load(n).get("jobs") or {}
        assert jobs, n
        for jn, job in jobs.items():
            t = job.get("timeout-minutes")
            assert isinstance(t, int) and 0 < t <= 30, f"{n}.{jn}: {t}"


def test_superseded_runs_are_cancelled():
    for n in NAMES:
        c = load(n).get("concurrency") or {}
        assert c.get("cancel-in-progress") is True, n
        group = str(c.get("group", ""))
        assert "github.workflow" in group and "github.ref" in group, n


def test_no_secrets_reach_ci_checks():
    for n in NAMES:
        assert "secrets." not in text(WF_DIR / f"{n}.yml"), n


# --- Automated dependency updates ---

def test_weekly_update_prs_per_ecosystem():
    cfg = yaml.safe_load(text(ROOT / ".github" / "dependabot.yml"))
    assert cfg.get("version") == 2
    updates = {(u.get("package-ecosystem"), u.get("directory")): u for u in cfg.get("updates", [])}
    for key in (("github-actions", "/"), ("pip", "/ResolverService"), ("npm", "/web"), ("gradle", "/android")):
        assert key in updates, key
        assert (updates[key].get("schedule") or {}).get("interval") == "weekly", key


# --- Composed flow: one web-only commit across every workflow ---

def test_web_only_commit_flow_triggers_one_hardened_linux_job():
    sample = "web/src/components/Player.tsx"
    fired = [n for n in NAMES if triggered_by(load(n), sample)]
    assert fired == ["web"]
    wf = load("web")
    job = test_job(wf)
    assert runs_on(wf, sample) and job.get("runs-on") == "ubuntu-latest"
    assert wf.get("permissions") == {"contents": "read"}
    assert job.get("timeout-minutes", 999) <= 30
    assert all(SHA_RE.match(s["uses"]) for s in job.get("steps", []) if "uses" in s)
    assert "npm run build" in run_text(job)
