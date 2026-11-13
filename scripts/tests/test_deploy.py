"""Behavioural tests for scripts/deploy.sh (openspec cd-vps-deploy, Requirement: Safe deploy on the server).

Each test builds its own origin (bare) + server clone + fake docker/curl/git on PATH in tmp_path.
"""
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "deploy.sh"
REAL_GIT = shutil.which("git")
BACKUP_RE = re.compile(r"^diegomusic-\d{8}-\d{6}\.db$")

FAKE_DOCKER = """#!/bin/bash
head=$("{git}" rev-parse HEAD 2>/dev/null || echo none)
printf 'docker\\t%s\\t%s\\n' "$head" "$*" >> "$CALLS_LOG"
case " $* " in
  *" exec "*) [ "${{FAKE_DOCKER_EXEC_FAIL:-}}" = 1 ] && exit 1 ;;
  *" cp "*) [ "${{FAKE_DOCKER_CP_FAIL:-}}" = 1 ] && exit 1
            for a; do last=$a; done; : > "$last" ;;
esac
exit 0
"""
FAKE_CURL = """#!/bin/bash
printf 'curl\\t-\\t%s\\n' "$*" >> "$CALLS_LOG"
[ "${FAKE_CURL_FAIL:-}" = 1 ] && exit 22
exit 0
"""
FAKE_GIT = """#!/bin/bash
printf 'git\\t-\\t%s\\n' "$*" >> "$CALLS_LOG"
exec "{git}" "$@"
"""


def git(cwd: Path, *args: str) -> str:
    return subprocess.run([REAL_GIT, *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def commit(repo: Path, name: str) -> str:
    (repo / name).write_text(name)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", name)
    return git(repo, "rev-parse", "HEAD")


def setup(tmp_path: Path) -> dict:
    """GIVEN: origin with main, a server clone at the initial commit, fakes on PATH."""
    if not SCRIPT.is_file():
        pytest.fail("missing scripts/deploy.sh")
    origin, seed, server = tmp_path / "origin.git", tmp_path / "seed", tmp_path / "server"
    git(tmp_path, "init", "-q", "--bare", "-b", "main", str(origin))
    git(tmp_path, "clone", "-q", str(origin), str(seed))
    git(seed, "config", "user.email", "t@t")
    git(seed, "config", "user.name", "t")
    git(seed, "checkout", "-q", "-b", "main")
    (seed / "scripts").mkdir()
    shutil.copy(SCRIPT, seed / "scripts" / "deploy.sh")
    (seed / "compose.yml").write_text("services: {}\n")
    first = commit(seed, "first")
    git(seed, "push", "-q", "origin", "main")
    git(tmp_path, "clone", "-q", "-b", "main", str(origin), str(server))
    git(server, "config", "user.email", "t@t")
    git(server, "config", "user.name", "t")
    bindir = tmp_path / "bin"
    bindir.mkdir()
    for name, body in (("docker", FAKE_DOCKER), ("curl", FAKE_CURL), ("git", FAKE_GIT)):
        p = bindir / name
        p.write_text(body.format(git=REAL_GIT) if name != "curl" else body)
        p.chmod(0o755)
    log = tmp_path / "calls.log"
    log.write_text("")
    backups = tmp_path / "backups"
    env = {
        k: v for k, v in os.environ.items() if k not in ("SSH_ORIGINAL_COMMAND", "GIT_DIR", "GIT_WORK_TREE")
    }
    env.update(
        PATH=f"{bindir}:{env['PATH']}",
        CALLS_LOG=str(log),
        BACKUP_DIR=str(backups),
        HEALTH_URL="http://fake/health",
        HEALTH_TIMEOUT="1",
        HEALTH_INTERVAL="0",
    )
    return dict(tmp=tmp_path, seed=seed, server=server, log=log, backups=backups, env=env, first=first)


def push_new(fx: dict, name: str) -> str:
    sha = commit(fx["seed"], name)
    git(fx["seed"], "push", "-q", "origin", "main")
    return sha


def deploy(fx: dict, sha: str | None = None, **extra: str) -> subprocess.CompletedProcess:
    fx["log"].write_text("")
    env = {**fx["env"], **extra}
    args = ["bash", str(fx["server"] / "scripts" / "deploy.sh")] + ([sha] if sha is not None else [])
    return subprocess.run(args, cwd=fx["tmp"], env=env, capture_output=True, text=True, timeout=60)


def calls(fx: dict) -> list[tuple[str, str, str]]:
    return [tuple(line.split("\t", 2)) for line in fx["log"].read_text().splitlines() if line]


def idx(cs: list, tool: str, needle: str, last: bool = False) -> int:
    hits = [i for i, c in enumerate(cs) if c[0] == tool and needle in c[2]]
    assert hits, f"no {tool} call containing {needle!r}: {cs}"
    return hits[-1] if last else hits[0]


def head(fx: dict) -> str:
    return git(fx["server"], "rev-parse", "HEAD")


def backups(fx: dict) -> list[str]:
    d = fx["backups"]
    return sorted(p.name for p in d.iterdir()) if d.is_dir() else []


@pytest.mark.parametrize("bad", ["", "abc", "A" * 40, "a" * 39, "a" * 41, "g" * 40, "a" * 40 + "\n", "$(id)"])
def test_invalid_input_rejected(tmp_path, bad):
    fx = setup(tmp_path)
    r = deploy(fx, bad)
    assert r.returncode == 2, r.stderr
    assert "deploy: invalid sha" in r.stderr
    assert calls(fx) == [], "must not call git/docker/curl before validating"
    assert head(fx) == fx["first"]
    assert backups(fx) == []


def test_key_cannot_run_arbitrary_commands(tmp_path):
    """Script half: the forced command passes SSH_ORIGINAL_COMMAND, which must be a valid SHA."""
    fx = setup(tmp_path)
    r = deploy(fx, None, SSH_ORIGINAL_COMMAND="ls -la")
    assert r.returncode == 2, r.stderr
    assert "deploy: invalid sha" in r.stderr
    assert calls(fx) == []
    assert head(fx) == fx["first"]


def test_already_deployed_is_a_noop(tmp_path):
    fx = setup(tmp_path)
    second = push_new(fx, "second")
    git(fx["server"], "pull", "-q", "--ff-only", "origin", "main")
    for sha in (second, fx["first"]):  # the deployed commit and one of its ancestors
        r = deploy(fx, sha)
        assert r.returncode == 0, r.stderr
        assert "deploy: already deployed" in r.stdout + r.stderr
        assert [c for c in calls(fx) if c[0] in ("docker", "curl")] == []
        assert head(fx) == second
        assert backups(fx) == []


def test_non_fast_forward_rejected(tmp_path):
    fx = setup(tmp_path)
    local = commit(fx["server"], "server-only")  # server diverged from origin
    new = push_new(fx, "upstream")
    r = deploy(fx, new)
    assert r.returncode == 3, r.stderr
    assert "deploy: not a fast-forward" in r.stderr + r.stdout
    assert head(fx) == local
    assert [c for c in calls(fx) if c[0] == "docker"] == []
    assert backups(fx) == []


def test_backup_precedes_update(tmp_path):
    fx = setup(tmp_path)
    fx["backups"].mkdir()
    old = [f"diegomusic-202001{d:02d}-000000.db" for d in range(1, 16)]  # 15 old backups
    for n in old:
        (fx["backups"] / n).write_text("old")
    new = push_new(fx, "second")
    r = deploy(fx, new)
    assert r.returncode == 0, r.stderr
    cs = calls(fx)
    i_exec = idx(cs, "docker", "exec -T resolver python")
    i_cp = idx(cs, "docker", " cp resolver:/service/data/.deploy-backup.db")
    i_up = idx(cs, "docker", "up -d --build")
    assert i_exec < i_cp < i_up
    assert cs[i_cp][1] == fx["first"], "backup must be copied before the checkout changes"
    assert cs[i_exec][1] == fx["first"]
    files = backups(fx)
    assert all(BACKUP_RE.match(n) for n in files), files
    assert len(files) == 14
    fresh = [n for n in files if n not in old]
    assert len(fresh) == 1, "a new timestamped backup must be stored"
    assert old[0] not in files and old[1] not in files, "oldest backups must be pruned"
    assert set(old[2:]) <= set(files)


@pytest.mark.parametrize("knob", ["FAKE_DOCKER_EXEC_FAIL", "FAKE_DOCKER_CP_FAIL"])
def test_backup_failure_aborts_deploy(tmp_path, knob):
    fx = setup(tmp_path)
    new = push_new(fx, "second")
    r = deploy(fx, new, **{knob: "1"})
    assert r.returncode == 4, r.stderr
    assert head(fx) == fx["first"]
    cs = calls(fx)
    assert not any(c[0] == "docker" and (" up " in f" {c[2]} " or "config" in c[2]) for c in cs), cs
    assert not any(c[0] == "curl" for c in cs)
    assert not any(c[0] == "git" and ("merge --ff-only" in c[2] or "reset" in c[2]) for c in cs)


def test_healthy_deploy(tmp_path):
    fx = setup(tmp_path)
    new = push_new(fx, "second")
    r = deploy(fx, new)
    assert r.returncode == 0, r.stderr
    assert head(fx) == new
    assert f"deploy: {new} healthy" in r.stdout + r.stderr
    cs = calls(fx)
    i_cfg = idx(cs, "docker", "--file compose.yml config --quiet")
    i_up = idx(cs, "docker", "--file compose.yml up -d --build")
    i_curl = idx(cs, "curl", "http://fake/health")
    assert i_cfg < i_up < i_curl
    assert cs[i_up][1] == new, "services must be rebuilt from the new checkout"


def test_unhealthy_deploy_rolls_back(tmp_path):
    fx = setup(tmp_path)
    new = push_new(fx, "second")
    r = deploy(fx, new, FAKE_CURL_FAIL="1")
    assert r.returncode == 1, r.stderr
    assert head(fx) == fx["first"]
    assert f"deploy: rolled back to {fx['first']}" in r.stdout + r.stderr
    cs = calls(fx)
    last_curl = idx(cs, "curl", "http://fake/health", last=True)
    last_up = idx(cs, "docker", "up -d --build", last=True)
    assert last_up > last_curl, "services must be rebuilt after the failed health check"
    assert cs[last_up][1] == fx["first"], "rollback rebuild must use the previous commit"


def test_deploy_flow_healthy_then_noop_then_rollback(tmp_path):
    """Composite: deploy A ok, redeploy A no-op, deploy B unhealthy -> back on A, 2 backups."""
    fx = setup(tmp_path)
    a = push_new(fx, "a")
    assert deploy(fx, a).returncode == 0
    assert head(fx) == a and len(backups(fx)) == 1
    r = deploy(fx, a)
    assert r.returncode == 0 and "already deployed" in r.stdout + r.stderr
    assert len(backups(fx)) == 1
    b = push_new(fx, "b")
    time.sleep(1.1)  # backups are named per second
    r = deploy(fx, b, FAKE_CURL_FAIL="1")
    assert r.returncode == 1
    assert head(fx) == a
    assert len(backups(fx)) == 2
    assert deploy(fx, b).returncode == 0, "a later healthy deploy of B must still fast-forward"
    assert head(fx) == b
