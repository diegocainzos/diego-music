#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env"
EXCLUDED_PARTS = {
    ".git",
    ".pi-subagents",
    ".pytest_cache",
    ".venv",
    "DerivedData",
    "build",
    "node_modules",
    "xcuserdata",
}
SENSITIVE_NAMES = {"YOUTUBE_DATA_KEY", "AUDIO_RESOLVER_API_TOKEN"}
PLACEHOLDER_PREFIXES = ("REEMPLAZAR", "EL_MISMO", "test-")


def local_sensitive_values() -> list[bytes]:
    if not ENV.exists():
        return []
    values: list[bytes] = []
    for raw in ENV.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("export "):
            line = line[7:].lstrip()
        match = re.match(r"^([A-Z0-9_]+)\s*=\s*(.*)$", line)
        if not match or match.group(1) not in SENSITIVE_NAMES:
            continue
        value = match.group(2).strip().strip("\"'")
        if len(value) >= 8 and not value.startswith(PLACEHOLDER_PREFIXES):
            values.append(value.encode("utf-8"))
    return values


values = local_sensitive_values()
if not values:
    print("No hay credenciales locales configuradas que comparar.")
    raise SystemExit(0)

leaks: list[Path] = []
for path in ROOT.rglob("*"):
    if not path.is_file() or path.name == ".env" or path == ROOT / "Config/Secrets.xcconfig":
        continue
    if any(part in EXCLUDED_PARTS for part in path.parts):
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    if b"\0" in data[:4096]:
        continue
    if any(value in data for value in values):
        leaks.append(path.relative_to(ROOT))

if leaks:
    print("Una credencial local aparece en archivos no permitidos:")
    for path in leaks:
        print(f"- {path}")
    raise SystemExit(1)

print("Comprobación superada: las credenciales locales no aparecen en archivos versionables.")
