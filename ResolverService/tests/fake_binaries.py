"""Ejecutables falsos de `yt-dlp` y `ffmpeg` para las pruebas.

Son scripts de Python escritos en un directorio temporal: nunca contactan YouTube
ni Googlevideo. Cada invocación queda registrada para poder comprobar los argumentos.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path

_YTDLP_SCRIPT = """#!/usr/bin/env python3
import json, os, pathlib, sys, time

here = pathlib.Path(__file__).resolve().parent
config = json.loads((here / "{name}.json").read_text())
args = sys.argv[1:]
with (here / "{name}.calls").open("a", encoding="utf-8") as calls:
    calls.write(json.dumps(args) + "\\n")
(here / "{name}.pid").write_text(str(os.getpid()))

if config["payload_hex"] is not None and "-o" in args:
    template = args[args.index("-o") + 1]
    pathlib.Path(template.replace("%(ext)s", "m4a")).write_bytes(bytes.fromhex(config["payload_hex"]))
sys.stdout.write(config["stdout"])
sys.stdout.flush()
time.sleep(config["sleep"])
sys.exit(config["exit_code"])
"""

_FFMPEG_SCRIPT = """#!/usr/bin/env python3
import json, os, pathlib, sys

here = pathlib.Path(__file__).resolve().parent
config = json.loads((here / "{name}.json").read_text())
args = sys.argv[1:]
with (here / "{name}.calls").open("a", encoding="utf-8") as calls:
    calls.write(json.dumps(args) + "\\n")

source = pathlib.Path(args[args.index("-i") + 1])
target = pathlib.Path(args[-1])
if config["exit_code"] == 0:
    target.write_bytes(b"progressive:" + source.read_bytes())
else:
    target.write_bytes(b"broken")
sys.exit(config["exit_code"])
"""


@dataclass(frozen=True)
class FakeBinary:
    path: Path

    @property
    def _stem(self) -> Path:
        return self.path.with_suffix("")

    @property
    def calls(self) -> list[list[str]]:
        calls_file = self._stem.with_suffix(".calls")
        if not calls_file.exists():
            return []
        return [json.loads(line) for line in calls_file.read_text().splitlines()]

    @property
    def pid(self) -> int | None:
        pid_file = self._stem.with_suffix(".pid")
        return int(pid_file.read_text()) if pid_file.exists() else None


def _install(directory: Path, name: str, script: str, config: dict[str, object]) -> FakeBinary:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{name}.py"
    path.write_text(script.format(name=name))
    path.chmod(0o755)
    (directory / f"{name}.json").write_text(json.dumps(config))
    return FakeBinary(path)


def fake_ytdlp(
    directory: Path,
    *,
    payload: bytes | None = b"abcdefgh",
    exit_code: int = 0,
    sleep: float = 0.0,
    stdout: str = "",
    name: str = "fake-yt-dlp",
) -> FakeBinary:
    """`yt-dlp` falso: escribe `payload` en la plantilla `-o` (con `%(ext)s` -> `m4a`) y termina con `exit_code`."""
    return _install(
        directory,
        name,
        _YTDLP_SCRIPT,
        {
            "payload_hex": payload.hex() if payload is not None else None,
            "exit_code": exit_code,
            "sleep": sleep,
            "stdout": stdout,
        },
    )


def fake_ffmpeg(directory: Path, *, exit_code: int = 0, name: str = "fake-ffmpeg") -> FakeBinary:
    """`ffmpeg` falso: escribe `progressive:` + contenido de entrada, o un archivo roto si `exit_code != 0`."""
    return _install(directory, name, _FFMPEG_SCRIPT, {"exit_code": exit_code})


def process_exists(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True
